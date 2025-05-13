# Using pygenetic code on pawsey

[PyGenetic Code](https://github.com/linsalrob/genetic_codes) is a robust library for translating DNA sequences.


Note that I had an issue running the python library. I have not tracked it down yet, but compiling the C code from source
worked and so I skipped that problem!

Install cmake

```
mamba install cmake
```

(you can also use the module system to load cmake, but I prefer mamba because its uptodate and I can use it in my own environment).


Install the C code:

```
cd ~/GitHubs
git clone https://github.com/linsalrob/get_orfs
cd get_orfs/
mkdir build
cd build/
cmake ..
make
cmake --install . --prefix ..
cd ..
ls
bin/get_orfs 
```

Now run get_orfs on your fasta file (you can probably do this on the head node, because its pretty quick!)

```
~/GitHubs/get_orfs/bin/get_orfs -f fasta/RB01.fasta.gz -l 20 > translation/RB01.20.faa
```






