# build.R — build the Nightingale submission: text, figures, captions
#
#   Rscript submission/build.R          (from the project root)
#
# 1. Renders vanLangren-Secret.qmd with -M submission:true (see submission.lua):
#    figures replaced by "[FIG n about here]", captions page at the end, and a
#    manifest submission/figures.csv. The .docx is rendered in the project root
#    and then moved into submission/. (Do NOT use quarto's --output-dir here:
#    it empties the target folder, including these scripts.)
# 2. Writes submission/figures/figure-NN.<ext>, numbered as in the text:
#      raster images copied unchanged (never recompressed);
#      the water-clock SVG converted to vector PDF;
#      the two ggplot2 graphs drawn straight to vector PDF, text as outlines.
# 3. Writes submission/figure-captions.docx (the captions page on its own)
#    and submission/README.txt (size and print resolution of every file).

library(ggplot2)
library(showtext)

root <- here::here()
sub  <- file.path(root, "submission")
out_dir <- file.path(sub, "figures")
docx_name <- "vanLangren-Secret-submission.docx"

# ---- 1. render the submission text ------------------------------------------
quarto <- Sys.which("quarto")
Sys.setenv(QUARTO_R = R.home("bin"))
status <- system2(quarto, c("render", shQuote(file.path(root, "vanLangren-Secret.qmd")),
                            "--to", "docx", "-M", "submission:true", "-o", docx_name))
# quarto may report an error when Dropbox locks its temporary files during
# cleanup; what matters is that the .docx was written
if (!file.exists(file.path(root, docx_name))) stop("render failed (status ", status, ")")
file.rename(file.path(root, docx_name), file.path(sub, docx_name))
message("wrote submission/", docx_name)

# ---- 2. figure files ---------------------------------------------------------
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
figs <- read.csv(file.path(sub, "figures.csv"), encoding = "UTF-8")

# source a companion script into its own environment, without its ggsave()
build_plot <- function(script) {
  e <- new.env()
  e$ggsave <- function(...) invisible(NULL)
  sys.source(file.path(root, script), envir = e, chdir = FALSE)
  e$p
}

save_pdf <- function(p, file, width, height) {
  showtext_auto()                      # text drawn as outlines: no font embedding needed
  grDevices::pdf(file, width = width, height = height)
  print(p)
  invisible(dev.off())
  file
}

# figures that are not simply copied: label -> function(stem) returning the file written
special <- list(
  "fig-waterclock" = function(stem) {
    f <- paste0(stem, ".pdf")
    rsvg::rsvg_pdf(file.path(root, "images", "vanlangren-waterclock.svg"), f)
    f
  },
  "fig-reconstruction" = function(stem) {
    p <- build_plot("R/reproduce-langren-graph.R")
    save_pdf(p, paste0(stem, ".pdf"), width = 7, height = 7 * 7.5 / 35)
  },
  "fig-scherer" = function(stem) {
    p <- build_plot("R/03_historical.R")
    # the script registers its fonts with systemfonts (for ragg); a PDF device
    # needs them from showtext instead, under the same family names
    font_add_google("Averia Serif Libre", "Averia Serif Libre")
    font_add_google("Kaushan Script", "Kaushan Script")
    save_pdf(p, paste0(stem, ".pdf"), width = 17600 / 1200, height = 4600 / 1200)
  }
)

img_size <- function(path) {
  d <- switch(tolower(tools::file_ext(path)),
    png = dim(png::readPNG(path, native = TRUE)),
    jpg = , jpeg = dim(jpeg::readJPEG(path, native = TRUE)),
    NULL)
  if (is.null(d)) c(NA, NA) else c(d[2], d[1])   # width, height
}

rows <- list()
for (i in seq_len(nrow(figs))) {
  fg   <- figs[i, ]
  stem <- file.path(out_dir, sprintf("figure-%02d", fg$number))
  unlink(Sys.glob(paste0(stem, ".*")))
  if (fg$label %in% names(special)) {
    file <- special[[fg$label]](stem)
    wh <- c(NA, NA)
  } else {
    src <- file.path(root, fg$source)
    ext <- tolower(tools::file_ext(src))
    if (ext == "jpeg") ext <- "jpg"
    file <- paste0(stem, ".", ext)
    file.copy(src, file, overwrite = TRUE)
    wh <- img_size(file)
  }
  rows[[i]] <- data.frame(number = fg$number, file = basename(file), label = fg$label,
                          source = fg$source, width_px = wh[1], height_px = wh[2])
  message(sprintf("figure %d  %-18s -> %s", fg$number, fg$label, basename(file)))
}
tab <- do.call(rbind, rows)

# ---- 3. captions file and README ----------------------------------------------
pandoc <- rmarkdown::pandoc_exec()
system2(pandoc, c(shQuote(file.path(sub, docx_name)),
                  "-L", shQuote(file.path(sub, "extract-captions.lua")),
                  "--reference-doc", shQuote(file.path(root, "vanLangren-reference.docx")),
                  "-o", shQuote(file.path(sub, "figure-captions.docx"))))
message("wrote submission/figure-captions.docx")

# captions as rendered (citations resolved to [n]), for the README
cap_txt <- system2(pandoc, c(shQuote(file.path(sub, "figure-captions.docx")),
                             "-t", "plain", "--wrap=none"), stdout = TRUE)
cap_txt <- enc2utf8(cap_txt[grepl("^Figure [0-9]+\\. ", cap_txt)])
if (length(cap_txt) == nrow(figs)) figs$caption <- sub("^Figure [0-9]+\\. ", "", cap_txt)

res_line <- function(r) {
  if (is.na(r$width_px)) return("vector PDF (any size)")
  sprintf("%d x %d px; %d dpi at 3.25 in, %d dpi at 6.5 in; 300 dpi up to %.1f in wide%s",
          r$width_px, r$height_px, round(r$width_px / 3.25), round(r$width_px / 6.5),
          r$width_px / 300, if (r$width_px / 6.5 < 300) "  <-- below 300 dpi at 6.5 in" else "")
}
lines <- c(
  "Van Langren's Secret, Finally Told: figures for Nightingale",
  paste("Generated", format(Sys.Date()), "by submission/build.R"),
  "",
  "Raster files are the original images, not recompressed. PDFs are vector,",
  "with text converted to outlines (no fonts needed). Captions, with credits,",
  "are in figure-captions.docx and at the end of the submission text.",
  "")
for (i in seq_len(nrow(tab))) {
  r <- tab[i, ]
  lines <- c(lines, sprintf("%s  (%s)", r$file, r$label), paste0("  ", res_line(r)),
             strwrap(figs$caption[i], width = 88, prefix = "  "), "")
}
writeLines(enc2utf8(lines), file.path(sub, "README.txt"), useBytes = TRUE)
message("wrote submission/README.txt")
print(tab[, c("number", "file", "width_px", "height_px")], row.names = FALSE)
