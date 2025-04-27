
if [[ -e ~/GitHubs/atavide/atavide_lite.yaml ]]; then 
	mamba env create --prefix /scratch/pawsey1018/edwa0468/software/miniconda3/atavide_lite --file ~/GitHubs/atavide/atavide_lite.yaml
fi

mamba create -y --prefix=/scratch/pawsey1018/edwa0468/software/miniconda3/phables bioconda::phables
mamba create -y --prefix=/scratch/pawsey1018/edwa0468/software/miniconda3/flye bioconda::flye
mamba create -y --prefix=/scratch/pawsey1018/edwa0468/software/miniconda3/checkv bioconda::checkv
mamba create -y --prefix=/scratch/pawsey1018/edwa0468/software/miniconda3/minimap bioconda::minimap2 bioconda::samtools

