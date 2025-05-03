#!/bin/bash --login
#SBATCH --account=pawsey1018
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=128G
#SBATCH --time=0-4
#SBATCH -o event_align-%j.out
#SBATCH -e event_align-%j.err

if [[ $# -ne 5 ]]; then 
	echo "$0 <reads fastq> <reads blow5 file> <reference fasta> <reads.v.ref bam> <output file .tsv>" 
	exit 1;
fi


# # for S/BLOW5 (R9.4 DNA/RNA or R10.4 DNA data)
# f5c eventalign -b [reads.sorted.bam] -g [ref.fa] -r [reads.fastq|fasta] --slow5 [slow5_file] > [events.tsv]

F5C=/home/edwa0468/scratch_1018/slorado/f5c-v1.5/f5c_x86_64_linux
# 
#  Here is the history. 
#  2255  samtools fastq RB10_RB04_phage_comp_20.bam > RB10.fastq
# samtools fqidx RB10.fastq
# F5C=/home/edwa0468/scratch_1018/slorado/f5c-v1.5/f5c_x86_64_linux
# $F5C index --slow5 RB04.blow5 RB04.fastq
# $F5C eventalign -r RB04.fastq --slow5 RB04.blow5 -g RB04_phage_comp_20.fasta -b RB04_RB04_phage_comp_20.bam  > RB04.events.tsv

samtools fqindex $1
$F5C index --slow5 $2 $1
$F5C eventalign -r $1 --slow5 $2 -g $3 -b $4 > $5


# New try. We need to get the raw adn phi29 into the same blow5 and bam files.
