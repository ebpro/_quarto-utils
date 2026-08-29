#!/usr/bin/env bash
set -euo pipefail
echo "Rendering sample files to verify tools snippets injection"
quarto render Content/java/03_nbdemo-java_D_maven.qmd --profile notes --to html
quarto render Content/java/01_nbdemo-java_L_101.qmd --profile notes --to html
echo "Render complete"
