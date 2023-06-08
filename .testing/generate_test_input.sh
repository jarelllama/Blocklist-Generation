#!/bin/bash

# Extract the top 2000 domains from Tranco TOP1M
wget -q https://tranco-list.eu/top-1m.csv.zip
unzip top-1m.csv.zip
head -n 2000 top-1m.csv
    | cut -d ',' -f 2 \
    | sed 's/\r//' \
    > top2000.txt

# Extract 2000 random domains from Hagezi's TIF Light blocklist
wget -q https://raw.githubusercontent.com/hagezi/dns-blocklists/main/domains/tif.light.txt
grep -v '^#' tif.light.txt > tif.light.tmp
shuf tif.light.tmp \
    | head -n 2000 \
    > malicious.txt