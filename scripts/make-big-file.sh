#!/bin/bash
# Creates demo/big.py (4,000 lines) and demo/small.py (20 lines).
cd "$(dirname "$0")/../demo" || exit 1
for i in $(seq 1 4000); do echo "def func_$i(x): return x * $i  # filler line"; done > big.py
head -20 big.py > small.py
wc -l big.py small.py
