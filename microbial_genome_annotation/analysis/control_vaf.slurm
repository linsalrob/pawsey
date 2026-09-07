#!/bin/bash
#SBATCH --account=pawsey1018
#SBATCH --job-name=control_vaf
#SBATCH --partition=work
#SBATCH --time=08:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=64
#SBATCH --mem=128G
#SBATCH -o logs/%x-%j.out
#SBATCH -e logs/%x-%j.err

# Baseline control: run the identical mixture analysis on a sample whose
# genome closed cleanly through the normal Autocycler consensus. Without this
# there is no way to tell whether the variant count seen in a rescued genome is
# abnormal or is just the ONT error floor for this run.
# Usage: control_vaf.slurm <sample name>

set -euo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

SAMPLE=$1
BASE=${PROJECT_DIR:-$PWD}
R=$BASE/${RESDIR:-rescue}/control_$SAMPLE
THREADS=${SLURM_CPUS_PER_TASK:-8}

eval "$(mamba shell hook --shell bash)"
mamba activate /scratch/$PAWSEY_PROJECT/$USER/software/miniconda3/assembly_qc
cd "$R"

minimap2 -ax map-ont -t "$THREADS" ref.fasta "$BASE/${READDIR:-reads}/$SAMPLE.fastq.gz" 2> minimap2.log \
	| samtools sort -@ 8 -o reads_vs_ref.bam -
samtools index -@ 8 reads_vs_ref.bam
samtools flagstat -@ 8 reads_vs_ref.bam > flagstat.txt

samtools depth -a -Q 10 reads_vs_ref.bam > depth.txt
awk '{d[NR]=$3; s+=$3} END{n=NR; mean=s/n;
	for(i=1;i<=n;i++) v+=(d[i]-mean)^2; sd=sqrt(v/n);
	z=0; for(i=1;i<=n;i++) if(d[i]==0) z++;
	printf "positions\t%d\nmean_depth\t%.1f\ncoefficient_of_variation\t%.3f\nzero_coverage_pct\t%.4f\n",
	n, mean, sd/mean, 100*z/n}' depth.txt > coverage_stats.tsv
cat coverage_stats.tsv

bcftools mpileup -f ref.fasta -a FORMAT/AD -B -Q 10 -q 10 --max-depth 200 --threads 8 reads_vs_ref.bam 2> mpileup.log \
	| bcftools call -mv --threads 8 -Ov 2>> mpileup.log \
	| bcftools view -v snps -i 'QUAL>=20' -Ov -o snps.vcf
bcftools query -f '%POS\t[%AD]\n' snps.vcf \
	| awk -F'\t' '{split($2,a,","); r=a[1]; v=a[2]; dp=r+v;
		if(dp>=30){printf "%s\t%d\t%.4f\n", $1, dp, v/dp}}' > vaf.tsv
awk '{n++; if($3>=0.20 && $3<=0.80) mid++} END{
	printf "snp_sites_dp30\t%d\nvaf_0.20_0.80\t%d\n", n, mid+0}' vaf.tsv > vaf_stats.tsv
cat vaf_stats.tsv
echo "### done control $SAMPLE"
