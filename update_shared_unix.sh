#!/usr/bin/env bash
set -euo pipefail
# update_shared_unix.sh
# Setup script for projects using _quarto-utils as a Git submodule.
# Creates symbolic links to expose submodule configs at project root.

SUBMODULE_PATH="_quarto-utils"
REPO_URL_DEFAULT="https://github.com/ebpro/quarto-utils.git"
BRANCH_DEFAULT="main"
DRY_RUN=0
INIT_ONLY=0

usage(){
  cat <<EOF
Usage: $0 [--repo URL] [--branch BRANCH] [--init-only] [--dry-run] [-h]

This script integrates _quarto-utils as a Git submodule and creates symbolic links
to expose configuration files at the project root.

Actions:
  1. Add/update submodule: git submodule add <URL> _quarto-utils
  2. Create symlinks at root:
     - _quarto.yml → _quarto-utils/_quarto.yml
     - _quarto-slides.yml → _quarto-utils/_quarto-slides.yml
     - _quarto-notes.yml → _quarto-utils/_quarto-notes.yml
     - _extensions → _quarto-utils/_extensions

Options:
  --repo URL       Repository URL (default: env REPO_URL or $REPO_URL_DEFAULT)
  --branch BRANCH  Branch to track (default: $BRANCH_DEFAULT)
  --init-only      Only update submodule, don't create/update symlinks
  --dry-run        Show what would be done without making changes
  -h, --help       Show this help

Environment variables:
  REPO_URL         Override default repository URL
  BRANCH           Override default branch

Examples:
  # Full setup (submodule + symlinks)
  ./update_shared_unix.sh --repo https://github.com/ebpro/_quarto-utils.git

  # Just update existing submodule
  ./update_shared_unix.sh --init-only

  # Dry run
  ./update_shared_unix.sh --dry-run
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_URL="$2"; shift 2;;
    --branch) BRANCH="$2"; shift 2;;
    --init-only) INIT_ONLY=1; shift 1;;
    --dry-run) DRY_RUN=1; shift 1;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

REPO_URL="${REPO_URL:-$REPO_URL_DEFAULT}"
BRANCH="${BRANCH:-$BRANCH_DEFAULT}"

echo "=== Quarto Submodule Setup ==="
echo "Repository: $REPO_URL"
echo "Branch: $BRANCH"
echo "Submodule path: $SUBMODULE_PATH"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "Mode: DRY RUN (no changes)"
fi
echo ""

# Check if we're in a git repository
if [ ! -d ".git" ] && [ ! -f ".git" ]; then
  echo "ERROR: Not in a git repository root. Please run from project root."
  exit 1
fi

# Step 1: Add or update submodule
if [ -f "$SUBMODULE_PATH/.git" ] || [ -d "$SUBMODULE_PATH/.git" ]; then
  echo "✓ Submodule already exists at $SUBMODULE_PATH"
  echo "  Updating submodule..."
  if [ "$DRY_RUN" -eq 0 ]; then
    git submodule update --init --recursive "$SUBMODULE_PATH" || echo "Warning: submodule update failed"
    git -C "$SUBMODULE_PATH" checkout "$BRANCH" 2>/dev/null || echo "Warning: couldn't checkout branch $BRANCH"
    git -C "$SUBMODULE_PATH" pull origin "$BRANCH" 2>/dev/null || echo "Warning: couldn't pull latest"
  else
    echo "  [dry-run] Would run: git submodule update --init --recursive"
  fi
else
  echo "Adding new submodule at $SUBMODULE_PATH..."
  if [ "$DRY_RUN" -eq 0 ]; then
    git submodule add -b "$BRANCH" "$REPO_URL" "$SUBMODULE_PATH" || {
      echo "ERROR: Failed to add submodule. Check repository URL and permissions."
      exit 1
    }
    git submodule update --init --recursive "$SUBMODULE_PATH"
  else
    echo "  [dry-run] Would run: git submodule add -b $BRANCH $REPO_URL $SUBMODULE_PATH"
  fi
fi

if [ "$INIT_ONLY" -eq 1 ]; then
  echo ""
  echo "✓ Submodule initialization complete (--init-only mode)"
  exit 0
fi

# Step 2: Create symbolic links
echo ""
echo "Creating symbolic links to submodule files..."

# Files to symlink
TO_LINK=(
  "_quarto.yml"
  "_quarto-slides.yml"
  "_quarto-notes.yml"
  "_extensions"
)

for item in "${TO_LINK[@]}"; do
  src="$SUBMODULE_PATH/$item"
  dest="./$item"

  # Check if source exists in submodule
  if [ ! -e "$src" ]; then
    echo "  ⚠️  Warning: $src not found in submodule, skipping"
    continue
  fi

  # Backup existing non-symlink files
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    backup="${dest}.bak"
    echo "  📦 Backing up existing $dest → $backup"
    if [ "$DRY_RUN" -eq 0 ]; then
      rm -rf "$backup" 2>/dev/null || true
      mv "$dest" "$backup"
    fi
  fi

  # Remove existing symlink if present
  if [ -L "$dest" ]; then
    if [ "$DRY_RUN" -eq 0 ]; then
      rm "$dest"
    fi
  fi

  # Create symlink
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [dry-run] Would create: $dest → $src"
  else
    ln -s "$src" "$dest"
    echo "  ✓ Linked: $dest → $src"
  fi
done

echo ""
echo "✅ Setup complete!"
echo ""
echo "📋 Summary:"
echo "  - Submodule: $SUBMODULE_PATH"
echo "  - Symlinks created for: ${TO_LINK[*]}"
echo ""
echo "🚀 Next steps:"
echo "  1. Customize author/metadata in _quarto-utils/_quarto.yml if needed"
echo "  2. Run 'quarto render --profile notes' to test"
echo "  3. Commit changes: git add . && git commit -m 'Add quarto-utils submodule'"
