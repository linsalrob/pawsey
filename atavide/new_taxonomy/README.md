# Generate a better taxonomy information for atavide

We're going to use [taxonkit](https://bioinf.shenwei.me/taxonkit/) since they have put the work in to make it work

# taxonkit

## data

You need to download the NCBI data. You should then set the $TAXONKIT_DB environment 

taxonkit only requires names.dmp, nodes.dmp, delnodes.dmp and merged.dmp

## set an  env

```
DATE=`date +%Y%m`
TAXONKIT_DB=~/Databases/NCBI/taxonomy/taxonomy.$DATE
mkdir -p $TAXONKIT_DB
cp names.dmp nodes.dmp delnodes.dmp merged.dmp $TAXONKIT_DB
```

