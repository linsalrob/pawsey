SLOW5TOOLS=/scratch/pawsey1018/edwa0468/slorado/slow5/slow5tools-v1.3.0/slow5tools
F5C=/home/edwa0468/scratch_1018/slorado/f5c-v1.5/f5c_x86_64_linux
SQUIG=/home/edwa0468/scratch_1018/slorado/squigualiser/squigualiser

1. We start with the component and the fastq files.
2. Map the reads -> fasta using minimap: slurm/minimap_reads.slurm reads contigs reads.contigs.bam. Note this also limits to only real matches.
3. Extract the read ids: samtools view reads.contigs.bam | awk '{print $1}' > RB01.bam.reads.txt
4. Extract those reads from the blow5 file: slurm/slow5_extract_reads.slurm  <slow5 file> <list of read ids> <output file>
5. Merge the fastq files into 1:  cat RB01.fastq RB11.fastq  > RB01_11.fastq
7. Merge those blow5 files into 1: $SLOW5TOOLS merge RB01.blow5 RB11.blow5 > RB01_11.blow5
8. Index the fastq and blow5: $F5C index RB01_11.fastq --slow RB01_11.blow
9. Remap the combined reads against the contigs to get a new BAM file: minimap2 -t 64 -ax map-ont RB01_phage_comp_9.fasta RB01_11.fastq | samtools view -F 3588 -b --threads 16  | samtools sort -@ 16 -o RB01_11_comp9.bam
10. Index that file: samtools index RB01_11_comp9.bam
11. Use f5c to do the eventalign:  $F5C eventalign -r RB01_11.fastq --slow5 RB01_11.blow5 -g RB01_phage_comp_9.fasta -b RB01_11_comp9.bam --sam | samtools view -b |  samtools sort -@ 16 -o RB01_11.eventalign.bam
12. Make a pileup plot $SQUIG plot_pileup -f RB01_phage_comp_9.fasta -s RB01_11.blow5 -a RB01_11.eventalign.bam -o RB01_11_pileip --region $REGION --tag_name "AE3_$REGION"
13. Make read map files so we can edit the HTML: python slurm/id_map.py -f RB11.bam.reads.txt -t phi >  RB11.bam.read_map.json; python slurm/id_map.py -f RB01.bam.reads.txt -t raw >  RB01.bam.read_map.json


Now to plot a whole genome in 100bp fragments: 
for S in $(seq 0 100 36300); do E=$((S+100)); echo "$S -> $E"; REGION="edge_115:$S-$E"; $SQUIG plot_pileup -f RB01_phage_comp_9.fasta -s RB01_11.blow5 -a RB01_11.eventalign.bam -o RB01_11_pileip --region $REGION --tag_name "AE3_$REGION"; done

Or for 1000bp fragments:
for S in $(seq 0 1000 36300); do E=$((S+1000)); echo "$S -> $E"; REGION="edge_115:$S-$E"; $SQUIG plot_pileup -f RB01_phage_comp_9.fasta -s RB01_11.blow5 -a RB01_11.eventalign.bam -o RB01_11_pileup1000  --region $REGION --tag_name "AE3_$REGION"; done

Note: $SQUIG plot_pileup only plots the fwd mapping reads, but you can add the --plot_reverse to add the reverse reads in a separate track (see https://github.com/hiruna72/squigualiser?tab=readme-ov-file#plot-multiple-tracks)

14. Find the html files with the most number of plots because they look. the best: find RB01_11_pileip/ -type f -exec perl -ne 'if (m/num reads:(\d+)/) {print "$1  $ARGV\n"}' {} + | sort -nr | less
15. Rename those plots, appending either raw or phi to the names.

for F in $(find RB01_11_pileup1000 -type f -printf "%f\n"); do echo $F; python bin/replace_html_tags.py --html RB01_11_pileup1000/$F --raw RB01.bam.reads.txt --phi29 RB11.bam.reads.txt --output comp9_renamed_1000/$F; done

16. Next, we can count how many -phi or -raw reads there are per file and summarise those:

find comp9_renamed_1000/ -type f -exec  perl -ne 'BEGIN {$raw=$phi=0} while (s/-raw//) {$raw++} while (s/-phi//) {$phi++} END {$t=$raw+$phi; print join("\t", $t, $raw, $phi, $ARGV), "\n"}' {} \; > raw-phi-counts-1000.tsv
sort -nr -k 3 raw-phi-counts-1000.tsv | less

