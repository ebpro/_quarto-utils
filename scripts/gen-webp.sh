#!/usr/bin/env bash
set -euo pipefail

# Portable generator for WebP optimized images
# Usage: gen-webp.sh [SRC_DIR] [OUT_DIR]
# Default SRC_DIR: <repo>/_quarto-utils/MyMedia/images
# Default OUT_DIR: ${SRC_DIR}/optimized

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
SRC_DIR="${1:-$ROOT_DIR/MyMedia/images}"
OUT_DIR="${2:-$SRC_DIR/optimized}"

mkdir -p "$OUT_DIR"
shopt -s nullglob
for f in "$SRC_DIR"/*.{jpg,jpeg,png}; do
  [ -f "$f" ] || continue
  name=$(basename "$f")
  base="${name%.*}"
  if [ ! -f "$OUT_DIR/${base}-800.webp" ]; then
    magick "$f" -strip -resize 800x -quality 80 "$OUT_DIR/${base}-800.webp"
    echo "Created $OUT_DIR/${base}-800.webp"
  fi
  if [ ! -f "$OUT_DIR/${base}-400.webp" ]; then
    magick "$f" -strip -resize 400x -quality 80 "$OUT_DIR/${base}-400.webp"
    echo "Created $OUT_DIR/${base}-400.webp"
  fi
done
