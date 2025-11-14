#!/bin/bash
set -e

echo "===== Gemini Security Scan Step Started ====="

TARGET_DIR="/bp/workspace/codebase"

if [ -z "$GEMINI_API_KEY" ]; then
  echo " ERROR: GEMINI_API_KEY not set"
  exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
  echo "Directory $TARGET_DIR does not exist"
  exit 1
fi

echo " Collecting files from: $TARGET_DIR"

# Build a combined file list for scanning
SCAN_FILE="/tmp/combined_scan_input.txt"
rm -f "$SCAN_FILE"
touch "$SCAN_FILE"

# Collect file contents
while IFS= read -r -d '' file; do
  echo "===== FILE: $file =====" >> "$SCAN_FILE"
  cat "$file" >> "$SCAN_FILE"
  echo -e "\n\n" >> "$SCAN_FILE"
done < <(find "$TARGET_DIR" -type f -print0)

echo " Combined file created at $SCAN_FILE"
echo " Running Gemini scan..."

OUTPUT=$(gemini --sandbox -y -p "You are a security analysis engine. Carefully review all code blocks below for vulnerabilities, secrets, misconfigurations, and insecure coding.

Here is the complete codebase:

$(cat "$SCAN_FILE")

Provide a detailed security report." 2>&1)

echo "===== Gemini Security Scan Output ====="
echo "$OUTPUT"

# Save report
echo "$OUTPUT" > /bp/workspace/gemini_security_report.txt
echo " Report saved to /bp/workspace/gemini_security_report.txt"

echo "===== Scan Complete ====="
