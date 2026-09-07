#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=rescue_checks
#SBATCH --partition=work
#SBATCH --time=12:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=64
#SBATCH --mem=128G
#SBATCH -o logs/%x-%j.out
#SBATCH -e logs/%x-%j.err

# Structural-concordance and mixture checks that must pass before any rejected
# Autocycler cluster is promoted to a chromosome.
#
#   1. do the candidate chromosomes from different assemblers agree in
#      sequence and structure, not merely in length?
#   2. do the reads support a single clonal genome, or a mixture?
#
# Usage: rescue_checks.slurm <sample name, e.g. 04>

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

SAMPLE=$1
BASE=${PROJECT_DIR:-$PWD}
R=$BASE/${RESDIR:-rescue}/$SAMPLE
READS=$BASE/${READDIR:-reads}/$SAMPLE.fastq.gz
THREADS=${SLURM_CPUS_PER_TASK:-8}

eval "$(mamba shell hook --shell bash)"
mamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/assembly_qc

cd "$R"
mkdir -p concordance mixture

# reference = the longest candidate
REF=$(awk -F'\t' 'NR==2{print $1}' candidates.tsv).fasta
echo "### reference: $REF"

############################################################
# 1. structural concordance
############################################################
echo "### pairwise dnadiff against $REF"
for q in *.fasta; do
	[[ "$q" == "$REF" ]] && continue
	dnadiff -p "concordance/$(basename "$q" .fasta)_vs_ref" "$REF" "$q" > /dev/null 2>&1 \
		|| echo "dnadiff failed for $q" >&2
done
bash "$(dirname "$0")/parse_dnadiff.sh" concordance

############################################################
# 2. mixture checks
############################################################
BAM=mixture/reads_vs_ref.bam
if [[ ! -s $BAM ]]; then
	echo "### mapping all reads to $REF"
	minimap2 -ax map-ont -t "$THREADS" "$REF" "$READS" 2> mixture/minimap2.log \
		| samtools sort -@ 8 -o "$BAM" -
	samtools index -@ 8 "$BAM"
fi

echo "### flagstat"
samtools flagstat -@ 8 "$BAM" > mixture/flagstat.txt
cat mixture/flagstat.txt

echo "### coverage"
samtools depth -a -Q 10 "$BAM" > mixture/depth.txt
awk '{d[NR]=$3; s+=$3} END{
	n=NR; mean=s/n; asort_unused=0;
	for(i=1;i<=n;i++){v+=(d[i]-mean)^2}
	sd=sqrt(v/n);
	printf "positions\t%d\nmean_depth\t%.1f\nsd_depth\t%.1f\ncoefficient_of_variation\t%.3f\n", n, mean, sd, sd/mean;
	z=0; for(i=1;i<=n;i++) if(d[i]==0) z++;
	printf "zero_coverage_positions\t%d\nzero_coverage_pct\t%.4f\n", z, 100*z/n
}' mixture/depth.txt > mixture/coverage_stats.tsv

# windowed coverage, to look for multimodality rather than just spread
awk '{w=int($2/10000); s[w]+=$3; c[w]++} END{for(k in s) printf "%d\t%.1f\n", k*10000, s[k]/c[k]}' \
	mixture/depth.txt | sort -n > mixture/coverage_10kb.tsv
awk -F'\t' '{print $2}' mixture/coverage_10kb.tsv | sort -n > mixture/win.txt
awk '{a[NR]=$1} END{
	printf "windows_10kb\t%d\nwin_median\t%.1f\nwin_p05\t%.1f\nwin_p95\t%.1f\nwin_p95_over_p05\t%.2f\n",
	NR, a[int(NR*0.5)], a[int(NR*0.05)+1], a[int(NR*0.95)], a[int(NR*0.95)]/(a[int(NR*0.05)+1]+0.0001)
}' mixture/win.txt >> mixture/coverage_stats.tsv
cat mixture/coverage_stats.tsv

echo "### variant allele frequencies (strain-mixture signature)"
bcftools mpileup -f "$REF" -a FORMAT/AD -B -Q 10 -q 10 --max-depth 200 --threads 8 "$BAM" 2> mixture/mpileup.log \
	| bcftools call -mv --threads 8 -Ov 2>> mixture/mpileup.log \
	| bcftools view -v snps -i 'QUAL>=20' -Ov -o mixture/snps.vcf
bcftools query -f '%POS\t[%AD]\n' mixture/snps.vcf \
	| awk -F'\t' '{split($2,a,","); ref=a[1]; alt=a[2]; dp=ref+alt;
		if(dp>=30){vaf=alt/dp; printf "%s\t%d\t%.4f\n", $1, dp, vaf}}' > mixture/vaf.tsv
awk '{n++; if($3>=0.20 && $3<=0.80) mid++; if($3>=0.35 && $3<=0.65) core++}
	END{printf "snp_sites_dp30\t%d\nvaf_0.20_0.80\t%d\nvaf_0.35_0.65\t%d\nvaf_mid_pct\t%.2f\n",
	n, mid+0, core+0, (n?100*mid/n:0)}' mixture/vaf.tsv > mixture/vaf_stats.tsv
cat mixture/vaf_stats.tsv

echo "### taxonomic composition of the reads"
SKETCH=/home/edwa0468/Databases/mash/refseq.genomes.k21s1000.msh
if [[ -s $SKETCH ]]; then
	# write to a file first: piping mash straight into head closes the pipe
	# early and pipefail turns the resulting SIGPIPE into a job failure.
	# mash lives in microbial_annotations, not assembly_qc.
	mamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/microbial_annotations
	mash screen -p "$THREADS" -w "$SKETCH" "$READS" > mixture/mash_screen_all.tsv 2> mixture/mash.log
	sort -gr mixture/mash_screen_all.tsv > mixture/mash_screen_sorted.tsv
	head -25 mixture/mash_screen_sorted.tsv > mixture/mash_screen_top25.tsv
	cut -f1,5 mixture/mash_screen_top25.tsv | head -15 || true
else
	echo "RefSeq mash sketch not available; taxonomic composition NOT assessed" \
		| tee mixture/mash_screen_top25.tsv
fi

echo "### done $SAMPLE"
