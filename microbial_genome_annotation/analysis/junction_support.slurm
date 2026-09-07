#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=junction_support
#SBATCH --partition=work
#SBATCH --time=04:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=64G
#SBATCH -o logs/%x-%j.out
#SBATCH -e logs/%x-%j.err

# Quantify spanning-read support for each alternative circularisation junction.
# Every construct carries the same 5 kb flanks, so a read is assigned to
# whichever spacer it matches best, and only reads that cross the junction with
# a decent anchor on both sides are counted.
# Usage: junction_support.slurm <sample name> <flank length>

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

SAMPLE=$1
FLANK=${2:-5000}
ANCHOR=1000          # bp required on each side of the junction
BASE=${PROJECT_DIR:-$PWD}
J=$BASE/${RESDIR:-rescue}/$SAMPLE/junction
THREADS=${SLURM_CPUS_PER_TASK:-8}

eval "$(mamba shell hook --shell bash)"
mamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/assembly_qc
cd "$J"

minimap2 -ax map-ont -t "$THREADS" --secondary=no candidates.fasta \
	"$BASE/${READDIR:-reads}/$SAMPLE.fastq.gz" 2> minimap2.log \
	| samtools sort -@ 8 -o reads_vs_junctions.bam -
samtools index reads_vs_junctions.bam

# a spanning read must have a primary alignment covering junction +/- ANCHOR
samtools view -F 0x904 reads_vs_junctions.bam \
	| awk -v fl="$FLANK" -v anc="$ANCHOR" '
	{
		ref=$3; pos=$4; cig=$6; qlen=0; rlen=0
		n=""
		for(i=1;i<=length(cig);i++){
			ch=substr(cig,i,1)
			if(ch ~ /[0-9]/){ n=n ch; continue }
			v=n+0; n=""
			if(ch=="M"||ch=="D"||ch=="N"||ch=="="||ch=="X") rlen+=v
		}
		endp=pos+rlen-1
		if(pos <= fl-anc && endp >= fl+anc+1) span[ref]++
		cov[ref]++
	}
	END{
		printf "construct\tspanning_reads\tprimary_alignments\n"
		for(r in cov) printf "%s\t%d\t%d\n", r, span[r]+0, cov[r]
	}' | sort -k2,2nr > junction_support.tsv

column -t junction_support.tsv
echo
echo "### total primary alignments: $(samtools view -c -F 0x904 reads_vs_junctions.bam)"
