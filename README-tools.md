Tools centralisation (proof-of-concept)
=====================================

Structure
---------
- `_include-tools.lua` : pandoc lua filter that injects a snippet based on `jupyter` frontmatter.
- `snippets/` : per-kernel qmd snippets (bash.qmd, java.qmd, zsh.qmd).
- `tools-common.sh` : shared shell helpers; small wrappers call it.
- `_tools.qmd` : central description file (optional to include manually).

Usage
-----
By default the project `_quarto.yml` has been updated to register the lua filter, so when you
render a notebook that contains `jupyter: java` the content of `_quarto-utils/snippets/java.qmd`
will be injected at the top of the document.

Adding a new kernel
-------------------
1. Create `_quarto-utils/snippets/<kernel>.qmd`.
2. Optionally add a small wrapper script `_tools_<Kernel>.sh` that calls `tools-common.sh`.

Notes
-----
- Snippets must use `::: {.content-visible when-profile="notes"}` and/or `when-profile="slides"`
  to remain compatible with both outputs.
