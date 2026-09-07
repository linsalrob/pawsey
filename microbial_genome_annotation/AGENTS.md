# AGENTS.md — microbial genome assembly and annotation

Operating notes for an agent running the scripts in this directory. They apply
to any long-read microbial assembly project, whatever the organism, sample
type, sequencing run or barcode layout. Nothing here assumes a particular
dataset.

The nearest repository or subdirectory `AGENTS.md` and any explicit user
instruction take precedence over this file.

## What this directory is

A set of Slurm scripts, not a pipeline:

| stage | script | purpose |
| --- | --- | --- |
| assemble an isolate | `autocycler_run.slurm` | consensus of many assemblers |
| assemble a plasmid prep | `plassembler_run.slurm` | plasmids, `--no_chromosome` |
| reorient | `dnaappler_run.slurm` | put the origin at a sensible place |
| annotate | `bakta_run.slurm` | gene calling and functional annotation |
| improve | `baktfold_run.slurm` | structure-informed refinement, needs a GPU |
| install | `*_install.slurm` | environments and databases |

Each `_run.slurm` takes an input file and an output directory. Read the script
before running it; several take a meaningful third argument.

## Before you run anything

**Verify the environment and databases actually exist.** Do not trust that a
previous install succeeded. On a purged filesystem an environment can lose
most of its files while still looking installed, and a `conda-meta` record is
not evidence that the binaries are present. Check the specific executables and
database files you are about to use:

```bash
for x in autocycler flye canu raven myloasm plassembler dnaapler bakta; do
    printf '%-12s ' "$x"; command -v "$x" >/dev/null && echo OK || echo MISSING
done
```

Databases are equally fragile. Confirm the expected files and sizes, not just
that the directory exists. A reference database that has been reduced to a
fraction of its size will fail deep inside a run, after hours of compute.

**Check tool/database version compatibility.** A bundled database can be older
than the binary that reads it will accept. Where a tool wraps another tool and
passes it a database path, that inner pair can be mismatched even when the
outer tool is fine. Resolve it before submitting a fleet of jobs, not after
they all fail identically.

**Record versions and database releases** for anything that reaches a result.
On a purged filesystem the environment is not reproducible from the filesystem
alone, so provenance has to be written down.

## Read handling

**Establish what the reads are before merging anything.** When additional
sequencing arrives, do not assume it is a separate batch. Compare file names,
sizes and checksums against what you already have. A "new" directory is
frequently a re-export that *contains* the old data, and concatenating the two
then duplicates every original read.

Duplicated reads are not a harmless inflation. They corrupt k-mer genome-size
estimation, break read subsampling, roughly double apparent depth and give
every duplicated position false support. The resulting assembly can look
better while being worse.

Verify containment programmatically and make the merge refuse to proceed if the
relationship does not hold, so the check cannot rot:

```bash
for f in "$OLD"/*.fastq.gz; do
    n="$NEW/$(basename "$f")"
    [[ -f "$n" && "$(stat -c %s "$f")" == "$(stat -c %s "$n")" ]] || echo "NOT CONTAINED: $f"
done
```

**Snapshot the read inventory before and after new data arrives** — per unit
file count, bytes, reads, bases, read-length distribution and quality — plus a
file-level manifest so an added chunk is identifiable by name rather than only
as a larger total.

**Subsample plasmid preparations.** Plasmid assembly of a small molecule needs
a tiny fraction of a modern library. Feeding the whole thing in can take orders
of magnitude longer *and produce a worse result*, because read-correction steps
degrade or fail outright at extreme depth and the assembler then proceeds with
uncorrected reads. A few hundred Mbp is already tens of thousands of fold
coverage for a few-kb plasmid. Record the sampling fraction and seed.

## Judging an assembly

**Never use contig or cluster count as the quality criterion.** A consensus
assembler emits whatever passed its internal QC. If the chromosome fails QC and
only a small plasmid survives, the output is a tidy, fully-resolved, one-contig
assembly containing a fraction of a percent of the genome. Any rule of the form
"fewer than N contigs, therefore annotate" will pass exactly that case and
reject genuinely closed genomes whose extra replicons push them over N.

Use the size-completeness gate built into `autocycler_run.slurm`:

```text
recovered_fraction = consensus_assembly_bases / estimated_genome_size
```

and require **both** that the assembly is fully resolved **and** that the
fraction lies inside an explicit interval (default 0.75–1.25, overridable via
`MIN_RECOVERED_FRACTION` / `MAX_RECOVERED_FRACTION`). The gate writes
`autocycler_out/assembly_gate.tsv` and **exits 3** on failure so that a
downstream job chained with `--dependency=afterok` will not annotate an
incomplete assembly.

A closed genome should ordinarily be far closer to the estimate than the gate
demands. The interval exists to stop catastrophic output being accepted
automatically, not to define acceptable quality.

Report clusters and unitigs separately. One unresolved cluster can contribute
thousands of unitigs, so a raw sequence count conflates a closed replicon with
a fragmented one.

## When a consensus assembly fails

Consensus-of-assemblers methods are conservative by construction: material the
input assemblies do not agree on is discarded rather than reported. So assembly
failure usually means "not agreed", not "not present". Establish which before
concluding anything.

1. **Ask whether the data are there.** Tabulate contig count and total length
   for every input assembly. If they independently recover a consistent total
   close to the genome-size estimate, the genome exists and the consensus step
   discarded it. Compare against the assemblies that *succeeded* in the same
   run — that is the only calibration available.
2. **Inventory what was rejected.** Report the largest rejected cluster, how
   many assemblies contributed, and their contig lengths. Several assemblers
   agreeing closely on a near-complete chromosome is strong evidence.
3. **Check structural concordance, not just length.** Agreement in length says
   little. Align the candidates pairwise and require high identity, near-total
   mutual coverage and no translocations. Note that comparing circular contigs
   with different start points reports one relocation as an artefact; that is
   not a rearrangement.
4. **Beware the longest contig.** The longest candidate is not automatically
   the most complete — it may be a chimera that has concatenated a second
   replicon onto the chromosome. Always check whether a smaller replicon maps
   inside it at high identity. Curating around an unchecked chimera bakes a
   misassembly into the final result.
5. **Rule out a mixed or non-clonal sample** before promoting anything: mapped
   coverage uniformity, variant density, and taxonomic composition of the
   reads.
6. **Curate the input set, do not lower the support threshold globally.**
   Retain the assemblies carrying a concordant chromosome, drop the fragmented
   contributions, preserve independently validated smaller replicons, and rerun
   `compress → cluster → trim → resolve → combine`. Restricting the input set
   is not the same as relaxing `--min_assemblies`, which also admits fragmented
   and contaminant clusters.

## Distinguishing real variation from sequencing error

Long-read basecalling error is not random, so a frequency cutoff alone will not
separate signal from noise.

**Use a within-run control.** Take a sample that assembled cleanly through the
normal path, run the identical analysis on it, and treat its variant density as
the error floor for that run. Absolute counts are uninterpretable without it —
a number that looks alarming may be below what a genome you fully trust
produces.

**Look at the spatial distribution, not just the count.** Compute an index of
dispersion in fixed windows. Variants scattered genome-wide look like a mixed
sample; variants concentrated in a small number of loci look like collapsed
repeats. These have completely different consequences, and the raw density does
not distinguish them. Report density inside and outside hotspot windows
separately.

**Take strand bias from the observation that drives the call** — the sample
with the strongest signal. Taking a maximum across samples lets one with a
couple of stray reads, where strand balance is extreme by chance, veto a site
that is cleanly supported elsewhere.

**Separate "detectable" from "carrying".** A sample sitting near the error
floor is background, not a carrier. Using one threshold for both makes a real
difference between samples look like an error shared by all of them.

**Exploit recurrence across samples.** Where the same molecule appears in
several samples, a systematic basecalling error should appear at the same
position in all of them, while genuine variation is restricted to a subset.
Map every sample to one common reference *including the sample the reference
came from*: that self-mapping is the control, since at a truly variable site
the reference sample's own reads agree with its own assembly.

## Testing whether two contigs are one molecule

Test the junctions **where the sequences actually meet**, not merely the ends
of the contigs as assembled. An element integrated internally has its real
junctions in the middle of a contig, and a test built from contig ends will
find no support for joins that genuinely do not exist while saying nothing
about the joins that do.

Build candidate constructs that share identical flanks and differ only in the
sequence between them, map all reads, and count only reads anchored well on
both sides. Then compare support across the alternatives.

Expect the answer to be "both". A mobile element can be integrated in most
molecules and excised and circularised in a minority, and both states will show
read support. That is a biological result, not an assembly error, and it should
be reported as such rather than forced into one representation.

## Manual graph correction

Only correct an assembly graph when the read evidence clearly supports one
path. Enumerate the alternatives from the graph topology first: dead-end tips
cannot lie on a circular path regardless of how much read support they attract,
and that is a topological fact worth establishing before measuring anything.

Get the GFA link convention right. `L a oa b ob` joins the **end** of `a` in
orientation `oa` to the **beginning** of `b` in orientation `ob`. For the
from-segment `+` means its right end; for the to-segment `+` means its **left**
end. Reading the to-segment backwards turns dead-end tips into bridges and
invents circular paths that do not exist. Verify any hand-derived topology with
a script.

Where a correction is applied, use the tool's supported mechanism, record
exactly which sequences were removed and why, and classify the result as
manually curated rather than automated.

## Provenance classification

Every assembly that reaches a result needs a stated classification, because
these are not equivalent and must not be reported as though they were:

- **automated consensus** — produced by the normal pipeline, gate passed;
- **curated consensus** — input set restricted by hand, with the evidence
  recorded;
- **read-validated single-assembler assembly** — only one assembler, or several
  subsamples of one assembler, supported the structure. This *looks* like a
  consensus once it has been through the consensus tool but has no independent
  corroboration, and must be reported as single-assembler;
- **validated draft** — genuinely this organism and well supported, but not
  closed. Usable for gene-level work with caveats, not a genome to close;
- **unresolved / draft only** — recovered but not resolvable on current
  evidence. Do not annotate as a closed genome.

Distinguish "several assemblies" from "several assemblers". Multiple subsamples
of one assembler are one algorithm, and that limits what the agreement is worth.

## Annotation checks

Annotation will run happily on a fragmentary or chimeric assembly and produce
confident, wrong gene calls. Gate on assembly quality first, then sanity-check
the output before drawing conclusions:

- **rRNA operon balance.** rRNA genes occur in operons, so 16S, 23S and 5S
  counts should match. An imbalance indicates a collapsed repeat or a genuine
  orphan gene; either way it needs explaining. A high operon count also
  explains, independently, why a genome was hard to assemble — rRNA operons are
  the classic long-read breakpoint.
- **Coding density and genes per Mb** against normal ranges for the organism
  group.
- **tRNA count**, which should cover the amino acids.
- **Hypothetical protein fraction**, as an outlier signal rather than a
  threshold.

Prefix contig headers with the sample identifier before annotating and use
`--keep-contig-headers`, or provenance is lost in the output.

## Failure modes that look like results

- **A gate failure is not a crash.** `autocycler_run.slurm` exits 3 when the
  completeness gate fails, so Slurm reports `FAILED`. Check the exit code and
  the gate file before diagnosing a fault.
- **An out-of-memory kill can be reported as a biological finding.** When an
  inner assembler is killed, the wrapper may observe "assembled 0 contigs" and
  conclude the sample has none. Check `MaxRSS` against the request before
  believing a negative result.
- **A read-correction step can fail and be continued past.** Warnings about
  failing to correct reads mean the assembler proceeded with uncorrected input.
  That is a quality problem, not just a warning.
- **`SIGPIPE` under `pipefail`.** Piping a long-running producer into `head`
  fails the whole pipeline. Write to a file, then take the head.
- **Interactive aliases.** `cp` and `rm` may be aliased to prompt, which in a
  non-interactive context hangs or silently skips. Use `/bin/cp`, `/bin/rm` or
  explicit flags in scripts.

## Compute

Run everything substantial through the scheduler; never assemble or annotate on
a login node. Derive thread counts from the allocation
(`SLURM_CPUS_PER_TASK`) rather than hardcoding them — a tool defaulting to one
thread will run for hours inside a large allocation doing nothing with it.

Use `sbatch --wait` when the next decision depends on inspecting the result,
and `--parsable` with `--dependency=afterok` when the next step is already
known. Submit full job arrays and let the scheduler decide concurrency.

Diagnose before escalating resources. Increase memory in response to an
observed `MaxRSS`, not as a guess, and consider whether less input would be
better than more memory.

## Definition of done

- Every sample has a stated outcome, backed by evidence, including the ones
  that failed.
- Assembly quality is judged on recovered fraction and resolution, never on
  sequence count.
- Every assembly carries a provenance classification.
- Consequential decisions and their evidence are recorded, including decisions
  not to promote something.
- Negative and inconclusive results are reported rather than omitted.
- Tool and database versions behind any result are written down.

Working code and completed jobs are not completion.
