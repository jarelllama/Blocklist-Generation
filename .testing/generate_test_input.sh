#!/bin/bash

# Extract the top 2000 domains from Tranco TOP1M
wget -q https://tranco-list.eu/top-1m.csv.zip
unzip top-1m.csv.zip
head -n 2000 top-1m.csv
    | cut -d ',' -f 2 \
    | sed 's/\r//' > top2000.txt

# Extract the top 2000 domains from DomCop TOP10M
get -q https://www.domcop.com/files/top/top10milliondomains.csv.zip
unzip top10milliondomains.csv.zip
tail -n +2 top10milliondomains.csv \
    | head  -n 2000 \
    | cut -d ',' -f 2 \
    | awk '{gsub(/"/ ,""); print}' >> top2000.txt

# Collate the two to get the top 2000 domains list
sort -u top2000.txt \
    | head -n 2000 > top2000.tmp
mv top2000.tmp top2000.txt