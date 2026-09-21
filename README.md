# Van Langren's Secret

![Page 8 of *La Verdadera Longitud por Mar y Tierra* (1644): van Langren's printed cipher.](images/verdadera-cipher.jpg)

This repo holds the source and companion material for **"Van Langren's Secret, Finally Told,"**
the story of how a 380-year-old cipher hidden in a 1644 navigation treatise was finally broken
in 2020 — and turned out to hide something stranger than anyone expected.

- **Original version**: published as a blog post at
  [friendly.github.io/blog/posts/2026-07-van-langren](https://friendly.github.io/blog/posts/2026-07-van-langren/)
- **This repo**: the Quarto source for a shorter, adapted version being prepared for print in
  *Nightingale*, the magazine of the Data Visualization Society — along with the R scripts that
  reproduce the article's key figures and analysis, kept here so they don't need to be printed
  inline in the magazine piece.

## Contents

- `vanLangren-Secret.qmd` — Quarto source for the article
- `R/` — standalone, runnable companion scripts
  - `decode-cipher.R` — reproduces all four steps of breaking van Langren's cipher
  - `reproduce-langren-overlay.R` — rebuilds the 1644 estimates as an overlay on a modern map
  - `reproduce-langren-graph.R` — a ggplot2 reconstruction of van Langren's original 1644 graph
- `cipher-transcription.txt` — the ciphertext, transcribed from page 8 of *La Verdadera Longitud
  por Mar y Tierra* (1644)
- `images/` — figures used in the article
- `references.bib` — bibliography
- `vanLangren-reference.docx` — Word reference template used when rendering to `.docx`

## Running the scripts

Each script in `R/` is self-contained. Open `vanLangren-Secret.Rproj` in RStudio first so
relative paths resolve correctly, then source any script directly.
