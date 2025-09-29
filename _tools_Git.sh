#!/bin/bash

echo "**Git Repository Status**"
echo

if git rev-parse --git-dir > /dev/null 2>&1; then
    # Gather basic info
    BRANCH=$(git branch --show-current)
    COMMIT=$(git rev-parse --short HEAD)
    REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "No remote")
    LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "No tags")
    LAST_COMMIT_DATE=$(git log -1 --format="%cd" --date=format:"%Y-%m-%d %H:%M:%S")
    HTTPS_URL=$(echo $REMOTE_URL | sed -e 's/git@github.com:/https:\/\/github.com\//' -e 's/\.git$//')
    
    # Get additional details
    #UNCOMMITTED=$(git status --porcelain | wc -l)
    #AHEAD_BEHIND=$(git rev-list --left-right --count origin/$BRANCH...HEAD 2>/dev/null || echo "0 0")
    #TOTAL_COMMITS=$(git rev-list --count HEAD)
    #CONTRIBUTORS=$(git shortlog -sn --no-merges | wc -l)
    
    echo "| Category | Details |"
    echo "|----------|---------|"
    # echo "| 📦 Repository Status | $([ $UNCOMMITTED -eq 0 ] && echo "✅ Clean" || echo "⚠️ Uncommitted changes: $UNCOMMITTED") |"
    echo "| 🌿 Current Branch | \`$BRANCH\` |"
    echo "| 📝 Latest Commit | \`$COMMIT\` ($LAST_COMMIT_DATE) |"
    echo "| 🔗 Remote | [$REMOTE_URL]($HTTPS_URL) |"
    echo "| 🏷️ Latest Tag | \`$LAST_TAG\` |"
    
else
    echo "| ⚠️ Status | Not a git repository |"
fi

echo