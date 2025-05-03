# Looking for DNA mods

We are comparing Nanopore sequences that have been treated with phi29 to those that are native. 

In the processing steps, we extracted DNA from our phages, and then split the aliquout in two. We treated one half with phi29, and the other was left as-is. Then we barcoded them both and sequenced them on the same minion chip.

Here, we are developing the tools and approaches to find interesting regions and compare them.

# Credit

The phi29 sequencing was done by Abbey
The protocol and approaches are by Hasindu.

The rest is Rob's mess.

Suggestions to get started from Hasindu

### Pipeline one:

- Convert the POD5>BLOW5 using blue-crab
- Basecall BLOW5. Hasindu originally suggested using buttery-eel that uses ONT’s Dorado-server, but I used slorado because I have it running
- do the alignment of to the reference using minimap2
- Align the signals to reference using f5c
- Then attempt to plot a region using https://github.com/hiruna72/squigualiser?tab=readme-ov-file#signal-to-reference-visualisation
- If things work, create a pileup plot https://github.com/hiruna72/squigualiser?tab=readme-ov-file#pileup-view
- See if you can see two separate current levels like for the “C” in here https://github.com/hiruna72/squigualiser/blob/main/docs/pipeline_methylation_detection_DNA.md#using-methylation-frequency-information
 
### Pipeline two:
- Do the basecalling of POD5 files using ONT’s Dorado
- Convert the POD5>BLOW5 using blue-crab
- Perform 3 to 7 in the pipeline one
 
Because of the complexity in signal data, initial visualisation would need a number of manual steps like above to get started. But once we observe any interesting differences in the signal, scripts can automate these. Let me know how it goes, we are happy to go over the steps over a zoom call if you get stuck.


# Real steps (so far):

1. Convert the POD5>BLOW5 using blue-crab
2. Merge all the BLOW5 files into one using slow5tools
3. Basecalling with slorado
4. Demultiplex with cutadapt. This was somewhat better than dorado.
5. Assemble using flye
6. Use phables to identify interesting phage-like regions
7. Explore the assembly with bandage
8. Use blastn to map all the reads back to the interesting edges.
9. From the m8 format blast output, create a list of read IDs.
10. Use slow5tools to extract the reads from the BLOW5 file using the read IDs and create a new BLOW5 file, one for each interesting region and one for each barcode



# Installing software

Most of the tools are installed with conda, except for the slorado/dorado/slow5tools/f5c. See the [slorado readme](../slorado/README.md) for installation details.
