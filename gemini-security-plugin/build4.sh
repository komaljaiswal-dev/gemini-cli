#!/bin/bash
set -e
echo "===== Gemini Security Scan Step Started ====="

# Detect what folder to scan
if [ -d "/bp/workspace/codebase" ]; then
    SCAN_DIR="/bp/workspace/codebase"
else
    SCAN_DIR="/bp/workspace"
fi

echo "Collecting files from: $SCAN_DIR"

# Combine all files into one scan input
find "$SCAN_DIR" -type f -name "*" > /tmp/filelist.txt
> /tmp/combined_scan_input.txt

while read -r file; do
    echo "===== FILE: $file =====" >> /tmp/combined_scan_input.txt
    cat "$file" >> /tmp/combined_scan_input.txt
    echo -e "\n\n" >> /tmp/combined_scan_input.txt
done < /tmp/filelist.txt

echo "Combined file created at /tmp/combined_scan_input.txt"
echo "Running Gemini scan..."

gemini --sandbox -y -p "$(cat /tmp/combined_scan_input.txt)" > /bp/workspace/gemini_security_report.txt

echo "===== Scan Complete ====="
