#!/bin/bash
set -e

echo "===== Gemini Security Scan Step Started ====="

TARGET_DIR="/bp/workspace/codebase"

if [ -z "$GEMINI_API_KEY" ]; then
  echo "ERROR: GEMINI_API_KEY not set"
  exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
  echo "Directory $TARGET_DIR does not exist"
  exit 1
fi

echo " Collecting files from: $TARGET_DIR"

SCAN_FILE="/tmp/combined_scan_input.txt"
rm -f "$SCAN_FILE"
touch "$SCAN_FILE"

while IFS= read -r -d '' file; do
  echo "===== FILE: $file =====" >> "$SCAN_FILE"
  cat "$file" >> "$SCAN_FILE"
  echo -e "\n\n" >> "$SCAN_FILE"
done < <(find "$TARGET_DIR" -type f -print0)

echo " Combined file created at $SCAN_FILE"
echo " Running Gemini scan..."

PROMPT=$(cat << 'EOF'
You are a professional security analysis engine.
Return ONLY valid JSON. DO NOT include markdown, comments, explanation, backticks, or code fences.

Respond strictly with a JSON array of findings like:

[
  {
    "severity": "HIGH | MEDIUM | LOW",
    "file": "path/to/file",
    "issue": "short title",
    "description": "long explanation",
    "recommendation": "fix instructions"
  }
]

If no issues, return: []
Codebase:
EOF
)

RAW_OUTPUT=$(gemini --sandbox -y -p "$PROMPT $(cat "$SCAN_FILE")" 2>&1)

# -------------------------------------------------------
# CLEAN GEMINI OUTPUT (remove ```json, ``` and garbage)
# -------------------------------------------------------
CLEAN_JSON=$(echo "$RAW_OUTPUT" \
  | sed 's/```json//g' \
  | sed 's/```//g' \
  | sed 's/^[[:space:]]*//g' \
  | sed 's/[[:space:]]*$//g')

echo "$CLEAN_JSON" > /tmp/scan_raw.json

echo "===== Validating JSON ====="

# Validate JSON
if ! jq empty /tmp/scan_raw.json 2>/tmp/jq_error.log; then
  echo "❌ Gemini output is NOT valid JSON!"
  echo ""
  echo "jq error:"
  cat /tmp/jq_error.log
  echo ""
  echo "Raw output (saved at /tmp/scan_raw.json):"
  echo "----------------------------------------"
  cat /tmp/scan_raw.json
  echo "----------------------------------------"
  exit 1
fi

echo "✓ JSON is valid"

echo "===== Formatting Results ====="

echo ""
echo "===== Security Findings (Table) ====="
jq -r '
  "SEVERITY|FILE|ISSUE|RECOMMENDATION",
  (.[] | "\(.severity)|\(.file)|\(.issue)|\(.recommendation)")
' /tmp/scan_raw.json | column -t -s "|"

# -------------------------------------------------------
# SAVE MARKDOWN REPORT
# -------------------------------------------------------
MD_REPORT="/bp/workspace/gemini_security_report.md"

{
echo "# Gemini Security Scan Report"
echo ""
echo "Generated: $(date)"
echo ""
echo "## Summary Table"
echo ""
jq -r '
  "| Severity | File | Issue | Recommendation |",
  "|---------|------|--------|----------------|",
  (.[] | "| \(.severity) | \(.file) | \(.issue) | \(.recommendation) |")
' /tmp/scan_raw.json

echo ""
echo "## Full JSON Output"
echo "\`\`\`json"
cat /tmp/scan_raw.json
echo "\`\`\`"
} > "$MD_REPORT"

echo ""
echo " Report saved to: $MD_REPORT"
echo "===== Scan Complete ====="
