#!/usr/bin/env bash
set -euo pipefail

# Safe slide exporter: copies rendered slides and their resource folders
# into _output/_slides while excluding git metadata. Use --move to move.

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
DEST_ROOT="$PROJECT_ROOT/_output/_slides"

MODE=copy
if [ "${1-}" = "--move" ]; then
  MODE=move
fi

mkdir -p "$DEST_ROOT"

shopt -s nullglob globstar

for f in "$PROJECT_ROOT"/**/*_L_*.html; do
  [ -f "$f" ] || continue

  dir=$(dirname "$f")
  file=$(basename "$f")
  base="${file%.*}"

  rel_dir=${dir#"$PROJECT_ROOT/"}
  # Skip copying from the destination tree itself
  case "$rel_dir" in
    _output/_slides/*|_output/_slides) continue ;;
  esac

  dest_dir="$DEST_ROOT/$rel_dir"
  mkdir -p "$dest_dir"

  if [ "$MODE" = "copy" ]; then
    echo "Copying $f -> $dest_dir/"
    rsync -a --omit-dir-times --no-perms --exclude='.git' --exclude='.git*' "$f" "$dest_dir/"
  else
    echo "Moving $f -> $dest_dir/"
    mv -f "$f" "$dest_dir/"
  fi

  # Handle companion resource folder <basename>_files
  if [ -d "$dir/${base}_files" ]; then
    if [ "$MODE" = "copy" ]; then
      echo "Copying $dir/${base}_files -> $dest_dir/"
      rsync -a --omit-dir-times --no-perms --exclude='.git' --exclude='.git*' "$dir/${base}_files" "$dest_dir/"
    else
      echo "Moving $dir/${base}_files -> $dest_dir/"
      rm -rf "$dest_dir/${base}_files"
      mv -f "$dir/${base}_files" "$dest_dir/"
    fi
  fi
done

shopt -u nullglob globstar

exit 0
