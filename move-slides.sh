#!/usr/bin/env bash
#!/usr/bin/env bash
# Move generated slides and their resource folders to output directory
set -euo pipefail

# Resolve project root (one level up from this script's directory)
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

mkdir -p "$PROJECT_ROOT/_output/_slides/Content"

# Find all *_L_*.html files recursively in Content/
shopt -s nullglob globstar
for f in "$PROJECT_ROOT"/Content/**/*_L_*.html; do
  if [ -f "$f" ]; then
    # Get directory and filename (keeping Content/ prefix)
    dir=$(dirname "$f")
    file=$(basename "$f")
    base="${file%.*}"

    # Compute destination directory under project root
    rel_dir=${dir#"$PROJECT_ROOT/"}
    dest_dir="$PROJECT_ROOT/_output/_slides/$rel_dir"

    # Create subdirectory structure in _output/_slides/
    mkdir -p "$dest_dir"

    echo "Moving $f -> $dest_dir/"
    mv -f "$f" "$dest_dir/"

    # Move companion resource folder (Pandoc/Quarto): <basename>_files
    if [ -d "$dir/${base}_files" ]; then
      echo "Moving $dir/${base}_files -> $dest_dir/"
      # Remove destination if exists, then move
      rm -rf "$dest_dir/${base}_files"
      mv -f "$dir/${base}_files" "$dest_dir/"
    fi
  fi
done

shopt -u nullglob globstar

exit 0
