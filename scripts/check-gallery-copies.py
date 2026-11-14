#!/usr/bin/env python3
"""Anti-drift gate for the shared gallery search script.

The script lives in three places: gallery-search.js is the canonical source,
_quarto-notes.yml and _quarto-notes-en.yml each inline a copy inside an
include-in-header block (a relative <script src> there is emitted verbatim and
404s on nested lecture pages, so inlining is required).

stdlib only; no yaml import; read-only; no network. Compares the inline bodies
with the canonical file after normalization (script tags removed, common
indentation removed, trailing whitespace removed - no global strip).
"""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = "gallery-search.js"
COPIES = ["_quarto-notes.yml", "_quarto-notes-en.yml"]

OPEN_MARK = re.compile(r"^[ \t]*<script>[ \t]*$")
CLOSE_MARK = re.compile(r"^[ \t]*</script>[ \t]*$")


def read_text(rel):
    path = os.path.join(ROOT, rel)
    if not os.path.isfile(path):
        raise SystemExit("DRIFT %s : fichier absent" % rel)
    with open(path, "rb") as handle:
        return handle.read().decode("utf-8")


def normalize(text):
    lines = text.replace("\r\n", "\n").split("\n")
    indents = [len(l) - len(l.lstrip(" ")) for l in lines if l.strip() != ""]
    pad = min(indents) if indents else 0
    out = [l[pad:] if l.strip() != "" else "" for l in lines]
    return "\n".join(out).rstrip()


def inline_body(rel):
    lines = read_text(rel).split("\n")
    opens = [i for i, l in enumerate(lines) if OPEN_MARK.match(l)]
    closes = [i for i, l in enumerate(lines) if CLOSE_MARK.match(l)]
    if len(opens) != 1 or len(closes) != 1:
        print("DRIFT %s : %d marque(s) <script> et %d marque(s) </script> attendues 1 et 1"
              % (rel, len(opens), len(closes)))
        return None
    if closes[0] <= opens[0]:
        print("DRIFT %s : marque </script> avant <script>" % rel)
        return None
    return normalize("\n".join(lines[opens[0] + 1:closes[0]]))


def main():
    canonical = normalize(read_text(SOURCE))
    failures = 0
    for rel in COPIES:
        body = inline_body(rel)
        if body is None:
            failures += 1
            continue
        if body != canonical:
            failures += 1
            got = body.split("\n")
            want = canonical.split("\n")
            where = next((i for i in range(max(len(got), len(want)))
                          if (got[i] if i < len(got) else None)
                          != (want[i] if i < len(want) else None)), 0)
            print("DRIFT %s : corps inlinie different de %s (1er ecart ligne %d du corps)"
                  % (rel, SOURCE, where + 1))
        else:
            print("copie conforme : %s" % rel)
    if failures:
        print("%d copie(s) hors service sur %d" % (failures, len(COPIES)))
        return 1
    print("ok : %d copie(s) conforme(s) a %s" % (len(COPIES), SOURCE))
    return 0


if __name__ == "__main__":
    sys.exit(main())
