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

# Validate API Key
if [ -z "$GEMINI_API_KEY" ]; then
  echo -e "${RED}✗ ERROR: GEMINI_API_KEY not set${NC}"
  exit 1
fi

# Smart directory detection
TARGET_DIR=""
SCAN_TYPE=""

echo -e "${YELLOW}🔍 Detecting scan target...${NC}"
echo ""

# Priority 1: Check for /bp/workspace/codebase
if [ -d "/bp/workspace/codebase" ]; then
    TARGET_DIR="/bp/workspace/codebase"
    SCAN_TYPE="Standard Codebase Directory"
    echo -e "${GREEN}✓ Found: /bp/workspace/codebase${NC}"

# Priority 2: Check for /bp/workspace/code
elif [ -d "/bp/workspace/code" ]; then
    TARGET_DIR="/bp/workspace/code"
    SCAN_TYPE="Code Directory"
    echo -e "${GREEN}✓ Found: /bp/workspace/code${NC}"

# Priority 3: Check for $CODEBASE environment variable
elif [ -n "$CODEBASE" ] && [ -d "$CODEBASE" ]; then
    TARGET_DIR="$CODEBASE"
    SCAN_TYPE="Custom CODEBASE Directory"
    echo -e "${GREEN}✓ Found: \$CODEBASE = $CODEBASE${NC}"

# Priority 4: Check for Git repository
elif [ -d "/bp/workspace/.git" ]; then
    TARGET_DIR="/bp/workspace"
    SCAN_TYPE="Git Repository"
    echo -e "${GREEN}✓ Found: Git repository${NC}"
    
    # Show Git info
    if command -v git &> /dev/null; then
        cd /bp/workspace
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        echo -e "${CYAN}   Branch: ${BOLD}$CURRENT_BRANCH${NC}"
        
        # List branches
        BRANCHES=$(git branch -a 2>/dev/null | grep -v HEAD | sed 's/^[* ]*//g' | wc -l)
        echo -e "${CYAN}   Total Branches: ${BOLD}$BRANCHES${NC}"
    fi

# Priority 5: Default to /bp/workspace
else
    TARGET_DIR="/bp/workspace"
    SCAN_TYPE="Default Workspace"
    echo -e "${YELLOW}⚠  No specific directory found, using: /bp/workspace${NC}"
fi

echo -e "${BLUE}📂 Scan Type: ${BOLD}$SCAN_TYPE${NC}"
echo -e "${BLUE}📁 Target Directory: ${BOLD}$TARGET_DIR${NC}"
echo ""

# Validate that directory exists and is readable
if [ ! -d "$TARGET_DIR" ]; then
  echo -e "${RED}✗ Target directory does not exist: $TARGET_DIR${NC}"
  exit 1
fi

if [ ! -r "$TARGET_DIR" ]; then
  echo -e "${RED}✗ Target directory is not readable: $TARGET_DIR${NC}"
  exit 1
fi

# Count files (exclude .git directory for cleaner count)
FILE_COUNT=$(find "$TARGET_DIR" -type f -not -path "*/.git/*" 2>/dev/null | wc -l)
echo -e "${CYAN}   Files to Scan: ${BOLD}$FILE_COUNT${NC}"

if [ "$FILE_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}⚠  No files found to scan in $TARGET_DIR${NC}"
  exit 0
fi

echo ""
echo -e "${YELLOW}⏳ Collecting and analyzing files...${NC}"

# Collect files (exclude .git directory contents but scan git config files)
SCAN_FILE="/tmp/combined_scan_input.txt"
rm -f "$SCAN_FILE"
touch "$SCAN_FILE"

# Create file list excluding binary files and .git internals
find "$TARGET_DIR" -type f \
  -not -path "*/.git/objects/*" \
  -not -path "*/.git/logs/*" \
  -not -path "*/.git/refs/*" \
  -not -path "*/.git/hooks/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/.npm/*" \
  -not -path "*/.cache/*" \
  -not -path "*/dist/*" \
  -not -path "*/build/*" \
  -not -name "*.pyc" \
  -not -name "*.pyo" \
  -not -name "*.so" \
  -not -name "*.dll" \
  -not -name "*.exe" \
  -not -name "*.bin" \
  -not -name "*.ico" \
  -not -name "*.pdf" \
  -not -name "*.zip" \
  -not -name "*.tar" \
  -not -name "*.gz" \
  2>/dev/null > /tmp/filelist.txt

ACTUAL_FILE_COUNT=$(wc -l < /tmp/filelist.txt)

if [ "$ACTUAL_FILE_COUNT" -eq 0 ]; then
  echo -e "${YELLOW}⚠  No scannable files found (after filtering binaries)${NC}"
  exit 0
fi

echo -e "${CYAN}   Processing ${BOLD}$ACTUAL_FILE_COUNT${NC}${CYAN} files...${NC}"

# Combine files
PROCESSED=0
while read -r file; do
  echo "===== FILE: $file =====" >> "$SCAN_FILE"
  
  # Check if file is readable and text-based
  if [ -r "$file" ] && file "$file" 2>/dev/null | grep -q "text"; then
    cat "$file" >> "$SCAN_FILE" 2>/dev/null || echo "[Cannot read file]" >> "$SCAN_FILE"
  elif [ -r "$file" ]; then
    # For other readable files, try to cat them (like config files without extension)
    cat "$file" >> "$SCAN_FILE" 2>/dev/null || echo "[Binary or unreadable file]" >> "$SCAN_FILE"
  else
    echo "[Cannot access file]" >> "$SCAN_FILE"
  fi
  
  echo -e "\n\n" >> "$SCAN_FILE"
  PROCESSED=$((PROCESSED + 1))
  
  # Show progress every 10 files
  if [ $((PROCESSED % 10)) -eq 0 ]; then
    echo -ne "\r   Processed: $PROCESSED/$ACTUAL_FILE_COUNT files"
  fi
done < /tmp/filelist.txt

echo -ne "\r   Processed: $PROCESSED/$ACTUAL_FILE_COUNT files\n"

# Include Git-specific information if it's a Git repo
if [ -d "$TARGET_DIR/.git" ]; then
  echo ""
  echo -e "${CYAN}📦 Including Git repository information...${NC}"
  
  echo "===== GIT CONFIGURATION =====" >> "$SCAN_FILE"
  
  if [ -f "$TARGET_DIR/.gitignore" ]; then
    echo "===== .gitignore =====" >> "$SCAN_FILE"
    cat "$TARGET_DIR/.gitignore" >> "$SCAN_FILE" 2>/dev/null
    echo -e "\n" >> "$SCAN_FILE"
  fi
  
  if [ -f "$TARGET_DIR/.gitattributes" ]; then
    echo "===== .gitattributes =====" >> "$SCAN_FILE"
    cat "$TARGET_DIR/.gitattributes" >> "$SCAN_FILE" 2>/dev/null
    echo -e "\n" >> "$SCAN_FILE"
  fi
  
  if command -v git &> /dev/null; then
    cd "$TARGET_DIR"
    
    echo "===== Git Branch Information =====" >> "$SCAN_FILE"
    git branch -a 2>/dev/null >> "$SCAN_FILE" || echo "Cannot list branches" >> "$SCAN_FILE"
    echo -e "\n" >> "$SCAN_FILE"
    
    echo "===== Git Config =====" >> "$SCAN_FILE"
    git config --list 2>/dev/null >> "$SCAN_FILE" || echo "Cannot read git config" >> "$SCAN_FILE"
    echo -e "\n" >> "$SCAN_FILE"
  fi
fi

# Security scan prompt
PROMPT="You are a professional security analysis engine. Analyze the following codebase for security vulnerabilities.

Return ONLY valid JSON. DO NOT include markdown, comments, explanation, backticks, or code fences.

Respond strictly with a JSON array of findings like:
[
  {
    \"severity\": \"HIGH | MEDIUM | LOW\",
    \"file\": \"path/to/file\",
    \"issue\": \"short title\",
    \"description\": \"detailed explanation\",
    \"recommendation\": \"actionable fix instructions\"
  }
]

If no security issues are found, return an empty array: []

Focus on:
- Hardcoded credentials, API keys, passwords
- SQL injection vulnerabilities
- Path traversal issues
- Insecure dependencies
- Authentication/authorization flaws
- Exposed sensitive data
- Insecure configurations
- CSRF vulnerabilities
- XSS vulnerabilities
- Insecure cryptography
- Rate limiting issues

Codebase to analyze:
---
"

echo ""
echo -e "${YELLOW}🤖 Running Gemini AI security analysis...${NC}"

# Run Gemini scan
RAW_OUTPUT=$(gemini --sandbox -y -p "$PROMPT$(cat "$SCAN_FILE")" 2>&1)

# Clean output
CLEAN_JSON=$(echo "$RAW_OUTPUT" \
  | sed 's/```json//g' \
  | sed 's/```//g' \
  | sed 's/^[[:space:]]*//g' \
  | sed 's/[[:space:]]*$//g')

echo "$CLEAN_JSON" > /tmp/scan_raw.json

# Validate JSON
echo -e "${BLUE}🔎 Validating response...${NC}"
if ! jq empty /tmp/scan_raw.json 2>/tmp/jq_error.log; then
  echo -e "${RED}✗ Invalid JSON response from Gemini${NC}"
  echo ""
  echo "Error details:"
  cat /tmp/jq_error.log
  echo ""
  echo "Raw output saved to: /tmp/scan_raw.json"
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
echo -e "  ${BOLD}Scan Type:${NC}     $SCAN_TYPE"
echo -e "  ${BOLD}Target:${NC}        $TARGET_DIR"
echo -e "  ${BOLD}Files Scanned:${NC} $ACTUAL_FILE_COUNT"
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
    # Truncate long values and clean paths
    file_short=$(echo "$file" | sed "s|$TARGET_DIR/||" | sed 's|^/bp/workspace/||' | cut -c1-40)
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
    file=$(echo "$finding" | jq -r '.file' | sed "s|$TARGET_DIR/||" | sed 's|^/bp/workspace/||')
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
  echo "**Scan Type:** $SCAN_TYPE"
  echo "**Target Directory:** $TARGET_DIR"
  echo "**Files Scanned:** $ACTUAL_FILE_COUNT"
  echo ""
  
  # Add Git info if applicable
  if [ -d "$TARGET_DIR/.git" ] && command -v git &> /dev/null; then
    cd "$TARGET_DIR"
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    echo "**Git Branch:** $CURRENT_BRANCH"
    echo "**Git Commit:** $COMMIT_HASH"
    echo ""
  fi
  
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
    jq -r '.[] | "| \(.severity) | `\(.file)` | \(.issue) |"' /tmp/scan_raw.json | sed "s|$TARGET_DIR/||g" | sed 's|/bp/workspace/||g'
    echo ""
    echo "---"
    echo ""
    echo "## 📋 Detailed Findings"
    echo ""
    
    jq -c '.[]' /tmp/scan_raw.json | while read -r finding; do
      severity=$(echo "$finding" | jq -r '.severity')
      file=$(echo "$finding" | jq -r '.file' | sed "s|$TARGET_DIR/||" | sed 's|/bp/workspace/||')
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
# Clean output (extract only JSON array)
CLEAN_JSON=$(echo "$RAW_OUTPUT" \
  | sed 's/```json//g' \
  | sed 's/```//g' \
  | sed 's/^[[:space:]]*//g' \
  | sed 's/[[:space:]]*$//g' \
  | sed -n 's/.*\(\[.*\]\).*/\1/p')

# Fallback: try to grep JSON array if above fails
if [ -z "$CLEAN_JSON" ]; then
    CLEAN_JSON=$(echo "$RAW_OUTPUT" | grep -o '\[.*\]' || true)
fi

echo "$CLEAN_JSON" > /tmp/scan_raw.json
