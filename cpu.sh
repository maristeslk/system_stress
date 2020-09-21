#!/bin/bash
apt-get install linux-tools-$(uname -r)
wget https://s3.amazonaws.com/cloudbench/software/UnixBench5.1.3.tgz
cd UnixBench/
sed -i "s/GRAPHIC_TESTS = defined/#GRAPHIC_TESTS = defined/g" ./Makefile
make all
sed -i "s/\"System Benchmarks\", 'maxCopies' => 16/\"System Benchmarks\", 'maxCopies' => 0/" Run
sed -i 's/$copies > $maxCopies/$maxCopies > 0 \&\& $copies > $maxCopies/' Run
chmod + Run
./Run 