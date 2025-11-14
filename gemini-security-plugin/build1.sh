#!/bin/bash
set -e

echo "===== Gemini Security Scan Step Started ====="

if [ -z "$GEMINI_API_KEY" ]; then
  echo " ERROR: GEMINI_API_KEY is required."
  exit 1
fi

TARGET_DIR="/bp/workspace/codebase"

if [ ! -d "$TARGET_DIR" ]; then
  echo " ERROR: Directory $TARGET_DIR does not exist."
  exit 1
fi

echo " Scanning directory: $TARGET_DIR"
echo " Running Gemini sandbox scan..."

# WORKING FIXED VERSION
OUTPUT=$(gemini --sandbox -y -p "You are a security scanner. Scan ALL files inside this directory: $TARGET_DIR. 
Identify vulnerabilities, secrets, insecure coding patterns, and provide a severity rating." 2>&1)

echo "$OUTPUT"
echo "$OUTPUT" > /bp/workspace/gemini_security_report.txt

echo "===== Scan Complete ====="
echo " Report saved to /bp/workspace/gemini_security_report.txt"
