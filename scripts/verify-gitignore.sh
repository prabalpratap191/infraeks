#!/bin/bash
# Bash Script to Verify .gitignore is Working

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m'

echo -e "${CYAN}"
echo "======================================"
echo "  .gitignore Verification Tool"
echo "======================================"
echo -e "${NC}"

# Check if Git is initialized
if [ ! -d ".git" ]; then
    echo -e "${RED}✗ Git not initialized. Run 'git init' first.${NC}\n"
    exit 1
fi

echo -e "${CYAN}Folders to be excluded from Git:${NC}"
echo "--------------------------------"
echo ""

# Folders that should be ignored
folders=(".slingshot" ".agent" ".agents" "target" "C:\Users\prasingh80")

found_folders=()
for folder in "${folders[@]}"; do
    if [ -d "$folder" ]; then
        echo -e "${YELLOW}✓ Found: $folder${NC}"
        found_folders+=("$folder")
    else
        echo -e "${GRAY}  (Not present: $folder)${NC}"
    fi
done

if [ ${#found_folders[@]} -eq 0 ]; then
    echo -e "\n${GREEN}No excluded folders found in current directory.${NC}"
    echo -e "${GREEN}This is normal if you're running this for the first time.${NC}\n"
fi

# Check .gitignore
echo -e "\n${CYAN}Checking .gitignore file...${NC}"
echo "---------------------------"
echo ""

if [ -f ".gitignore" ]; then
    echo -e "${GREEN}✓ .gitignore exists${NC}"
    
    echo -e "\n${CYAN}Verifying patterns in .gitignore:${NC}"
    for folder in "${folders[@]}"; do
        if grep -q "$folder" .gitignore; then
            echo -e "  ${GREEN}✓ $folder/ is in .gitignore${NC}"
        else
            echo -e "  ${RED}✗ $folder/ NOT in .gitignore${NC}"
        fi
    done
else
    echo -e "${RED}✗ .gitignore does NOT exist!${NC}"
    echo -e "${YELLOW}  Create it before proceeding.${NC}\n"
    exit 1
fi

# Check Git status
echo -e "\n\n${CYAN}Checking Git status...${NC}"
echo "----------------------"
echo ""

# Check if any ignored folders are being tracked
problem_found=false
for folder in "${found_folders[@]}"; do
    if git ls-files --others --exclude-standard | grep -q "$folder"; then
        echo -e "${RED}✗ WARNING: $folder/ appears in Git tracking!${NC}"
        problem_found=true
    else
        echo -e "${GREEN}✓ $folder/ is properly ignored${NC}"
    fi
done

# Show ignored files
echo -e "\n\n${CYAN}Listing all ignored items...${NC}"
echo "----------------------------"
echo ""

ignored=$(git status --ignored --short | grep "^!!")
if [ -n "$ignored" ]; then
    echo "$ignored" | while read line; do
        item=$(echo "$line" | sed 's/^!! //')
        echo -e "  ${GRAY}Ignored: $item${NC}"
    done
else
    echo -e "  ${GRAY}No ignored items found.${NC}"
fi

# Final summary
echo -e "\n\n${CYAN}======================================${NC}"
if [ "$problem_found" = true ]; then
    echo -e "${RED}  STATUS: ISSUES FOUND${NC}"
    echo -e "${CYAN}======================================${NC}\n"
    echo -e "${YELLOW}Action Required:${NC}"
    echo -e "${YELLOW}1. Review .gitignore patterns${NC}"
    echo -e "${YELLOW}2. Run: git rm -r --cached .slingshot/ .agent/${NC}"
    echo -e "${YELLOW}3. Verify again with this script${NC}\n"
else
    echo -e "${GREEN}  STATUS: ALL GOOD ✓${NC}"
    echo -e "${CYAN}======================================${NC}\n"
    echo -e "${GREEN}Excluded folders will NOT be pushed to Git.${NC}"
    echo -e "${GREEN}Safe to proceed with 'git add .' and 'git push'.${NC}\n"
fi

# Next steps
echo -e "${CYAN}Next steps:${NC}"
echo -e "${NC}1. git add .${NC}"
echo -e "${NC}2. git status (verify what will be committed)${NC}"
echo -e "${NC}3. git commit -m 'Your message'${NC}"
echo -e "${NC}4. git push -u origin main${NC}\n"
