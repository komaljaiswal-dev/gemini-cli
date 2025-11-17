#!/bin/bash
set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Print header
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                    🔒 GEMINI SECURITY SCANNER                                ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

TARGET_DIR="/bp/workspace/codebase"

# Validate API Key
if [ -z "$GEMINI_API_KEY" ]; then
  echo -e "${RED}✗ ERROR: GEMINI_API_KEY not set${NC}"
  exit 1
fi

# Validate Target Directory
if [ ! -d "$TARGET_DIR" ]; then
  echo -e "${RED}✗ Directory $TARGET_DIR does not exist${NC}"
  exit 1
fi

# Check for files
FILE_COUNT=$(find "$TARGET_DIR" -type f 2>/dev/null | wc -l)
echo -e "${BLUE}📁 Target Directory: ${BOLD}$TARGET_DIR${NC}"
echo -e "${CYAN}   Files Found: ${BOLD}$FILE_COUNT${NC}"

if [ "$FILE_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}⚠  No files found to scan${NC}"
  exit 0
fi

echo ""
echo -e "${YELLOW}⏳ Collecting and analyzing files...${NC}"

# Collect files
SCAN_FILE="/tmp/combined_scan_input.txt"
rm -f "$SCAN_FILE"
touch "$SCAN_FILE"

find "$TARGET_DIR" -type f 2>/dev/null | while read -r file; do
  echo "===== FILE: $file =====" >> "$SCAN_FILE"
  cat "$file" >> "$SCAN_FILE" 2>/dev/null || echo "[Cannot read file]" >> "$SCAN_FILE"
  echo -e "\n\n" >> "$SCAN_FILE"
done

# Security scan prompt
PROMPT="You are a security scanner. Analyze this code and return ONLY a JSON array of security issues. Format: [{\"severity\":\"HIGH|MEDIUM|LOW\",\"file\":\"path\",\"issue\":\"title\",\"description\":\"details\",\"recommendation\":\"fix\"}]. If no issues, return []. Code follows:"

# Run Gemini scan
RAW_OUTPUT=$(gemini --sandbox -y -p "$PROMPT $(cat "$SCAN_FILE")" 2>&1)

# Clean output
CLEAN_JSON=$(echo "$RAW_OUTPUT" \
  | sed 's/```json//g' \
  | sed 's/```//g' \
  | sed 's/^[[:space:]]*//g' \
  | sed 's/[[:space:]]*$//g')

echo "$CLEAN_JSON" > /tmp/scan_raw.json

# Validate JSON
if ! jq empty /tmp/scan_raw.json 2>/dev/null; then
  echo -e "${RED}✗ Invalid JSON response from Gemini${NC}"
  exit 1
fi

# Count findings by severity
HIGH_COUNT=$(jq '[.[] | select(.severity == "HIGH")] | length' /tmp/scan_raw.json)
MEDIUM_COUNT=$(jq '[.[] | select(.severity == "MEDIUM")] | length' /tmp/scan_raw.json)
LOW_COUNT=$(jq '[.[] | select(.severity == "LOW")] | length' /tmp/scan_raw.json)
TOTAL_COUNT=$(jq 'length' /tmp/scan_raw.json)

echo -e "${GREEN}✓ Analysis Complete${NC}"
echo ""

# Display summary banner
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                          📊 SCAN SUMMARY                                     ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${RED}${BOLD}🔴 HIGH:    $HIGH_COUNT issue(s)${NC}"
echo -e "  ${YELLOW}${BOLD}🟡 MEDIUM:  $MEDIUM_COUNT issue(s)${NC}"
echo -e "  ${GREEN}${BOLD}🟢 LOW:     $LOW_COUNT issue(s)${NC}"
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${BOLD}   TOTAL:   $TOTAL_COUNT finding(s)${NC}"
echo ""

if [ "$TOTAL_COUNT" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}✓ No security issues detected! Your code looks good.${NC}"
  echo ""
else
  # Display detailed findings table
  echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}${CYAN}║                        🔍 DETAILED FINDINGS                                  ║${NC}"
  echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
  echo ""
  
  # Create formatted table with proper alignment
  printf "${BOLD}%-10s %-40s %-30s${NC}\n" "SEVERITY" "FILE" "ISSUE"
  printf "${CYAN}%s${NC}\n" "$(printf '─%.0s' {1..80})"
  
  jq -r '.[] | "\(.severity)|\(.file)|\(.issue)"' /tmp/scan_raw.json | while IFS='|' read -r severity file issue; do
    # Truncate long values
    file_short=$(echo "$file" | sed 's|/bp/workspace/codebase/||' | cut -c1-40)
    issue_short=$(echo "$issue" | cut -c1-30)
    
    # Color code based on severity
    case "$severity" in
      HIGH)
        printf "${RED}${BOLD}%-10s${NC} ${BOLD}%-40s${NC} %-30s\n" "$severity" "$file_short" "$issue_short"
        ;;
      MEDIUM)
        printf "${YELLOW}${BOLD}%-10s${NC} ${BOLD}%-40s${NC} %-30s\n" "$severity" "$file_short" "$issue_short"
        ;;
      LOW)
        printf "${GREEN}${BOLD}%-10s${NC} ${BOLD}%-40s${NC} %-30s\n" "$severity" "$file_short" "$issue_short"
        ;;
    esac
  done
  
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  
  # Display each finding with details
  echo -e "${BOLD}${MAGENTA}📋 DETAILED RECOMMENDATIONS${NC}"
  echo ""
  
  jq -c '.[]' /tmp/scan_raw.json | while read -r finding; do
    severity=$(echo "$finding" | jq -r '.severity')
    file=$(echo "$finding" | jq -r '.file' | sed 's|/bp/workspace/codebase/||')
    issue=$(echo "$finding" | jq -r '.issue')
    description=$(echo "$finding" | jq -r '.description')
    recommendation=$(echo "$finding" | jq -r '.recommendation')
    
    # Icon based on severity
    case "$severity" in
      HIGH)
        icon="🔴"
        color="$RED"
        ;;
      MEDIUM)
        icon="🟡"
        color="$YELLOW"
        ;;
      LOW)
        icon="🟢"
        color="$GREEN"
        ;;
    esac
    
    echo -e "${color}${BOLD}${icon} [$severity] $issue${NC}"
    echo -e "${BOLD}📄 File:${NC} $file"
    echo -e "${BOLD}📝 Description:${NC}"
    echo "$description" | fold -w 75 -s | sed 's/^/   /'
    echo -e "${BOLD}💡 Recommendation:${NC}"
    echo "$recommendation" | fold -w 75 -s | sed 's/^/   /'
    echo ""
    echo -e "${CYAN}$(printf '─%.0s' {1..80})${NC}"
    echo ""
  done
fi

# Save enhanced markdown report
MD_REPORT="/bp/workspace/gemini_security_report.md"
{
  echo "# 🔒 Gemini Security Scan Report"
  echo ""
  echo "**Generated:** $(date '+%Y-%m-%d %H:%M:%S')"
  echo "**Target:** $TARGET_DIR"
  echo "**Files Scanned:** $FILE_COUNT"
  echo ""
  echo "---"
  echo ""
  echo "## 📊 Executive Summary"
  echo ""
  echo "| Severity Level | Count |"
  echo "|---------------|-------|"
  echo "| 🔴 **HIGH**   | **$HIGH_COUNT** |"
  echo "| 🟡 **MEDIUM** | **$MEDIUM_COUNT** |"
  echo "| 🟢 **LOW**    | **$LOW_COUNT** |"
  echo "| **TOTAL**     | **$TOTAL_COUNT** |"
  echo ""
  
  if [ "$TOTAL_COUNT" -gt 0 ]; then
    echo "---"
    echo ""
    echo "## 🔍 Findings Overview"
    echo ""
    echo "| Severity | File | Issue |"
    echo "|----------|------|-------|"
    jq -r '.[] | "| \(.severity) | `\(.file)` | \(.issue) |"' /tmp/scan_raw.json | sed 's|/bp/workspace/codebase/||g'
    echo ""
    echo "---"
    echo ""
    echo "## 📋 Detailed Findings"
    echo ""
    
    jq -c '.[]' /tmp/scan_raw.json | while read -r finding; do
      severity=$(echo "$finding" | jq -r '.severity')
      file=$(echo "$finding" | jq -r '.file' | sed 's|/bp/workspace/codebase/||')
      issue=$(echo "$finding" | jq -r '.issue')
      description=$(echo "$finding" | jq -r '.description')
      recommendation=$(echo "$finding" | jq -r '.recommendation')
      
      case "$severity" in
        HIGH) icon="🔴" ;;
        MEDIUM) icon="🟡" ;;
        LOW) icon="🟢" ;;
      esac
      
      echo "### ${icon} [$severity] $issue"
      echo ""
      echo "**📄 File:** \`$file\`"
      echo ""
      echo "**📝 Description:**"
      echo ""
      echo "$description"
      echo ""
      echo "**💡 Recommendation:**"
      echo ""
      echo "$recommendation"
      echo ""
      echo "---"
      echo ""
    done
  else
    echo "---"
    echo ""
    echo "## ✅ Results"
    echo ""
    echo "**No security vulnerabilities detected!**"
    echo ""
    echo "Your codebase appears to be secure based on the current analysis."
    echo ""
  fi
  
  echo "---"
  echo ""
  echo "## 📎 Raw JSON Output"
  echo ""
  echo '```json'
  jq '.' /tmp/scan_raw.json
  echo '```'
  echo ""
  echo "---"
  echo ""
  echo "_Report generated by Gemini Security Scanner_"
} > "$MD_REPORT"

echo -e "${GREEN}${BOLD}✓ Detailed report saved to:${NC} ${BOLD}$MD_REPORT${NC}"
echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                    ✅ SCAN COMPLETED SUCCESSFULLY                            ║${NC}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
echo ""
