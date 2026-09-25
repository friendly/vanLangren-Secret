# wordcount.R — word counts for a rendered .docx, by section and by category
#
# Counts what an editor actually receives (the .docx), not the Quarto / R Markdown
# source, so YAML, code chunks, URLs, image paths and HTML-only content never
# enter the count. Words are counted the way Word counts them: whitespace-separated
# tokens (so "anyway—but" is one word), ignoring tokens with no letters or digits.
#
# Each word is assigned to one category, using the paragraph styles that pandoc
# writes (and reads back with `-f docx+styles`):
#   body            running prose, block quotes, lists
#   headings        section headings
#   footnotes       footnote text
#   figure captions captions of figures (Quarto puts figures in layout tables)
#   tables          data tables and their captions
#   display blocks  code blocks ("Source Code" style)
#   math            inline and display equations
#   references      the bibliography
# plus any categories you add for custom styles, e.g. c(PullQuote = "pull quotes").
#
# Requires: jsonlite, and pandoc (on the PATH, bundled with RStudio, or via Quarto).
#
# Usage in R:
#   source("wordcount.R")
#   wc <- docx_wordcount("paper.docx", styles = c(PullQuote = "pull quotes"))
#   wc                      # table by section x category
#   summary(wc)             # body text, + headings, + footnotes, everything
#
# Usage from a shell:
#   Rscript wordcount.R paper.docx [--style PullQuote="pull quotes"] [--level 2]
#
# Michael Friendly, 2026. MIT licence.

# pandoc's own paragraph styles for docx output, mapped to categories
default_styles <- c(
  "Source Code"    = "display blocks",
  "Bibliography"   = "references",
  "Footnote Text"  = "footnotes",
  "Table Caption"  = "tables",
  "Image Caption"  = "figure captions",
  "Captioned Figure" = "figure captions"
)

base_categories <- c("body", "headings", "footnotes", "figure captions",
                     "tables", "display blocks", "math", "references")

# Find a way to run pandoc: plain pandoc, RStudio's copy, or `quarto pandoc`.
# Returns the command and any leading arguments.
find_pandoc <- function() {
  p <- Sys.which("pandoc")
  if (nzchar(p)) return(list(cmd = p, args = character()))
  if (requireNamespace("rmarkdown", quietly = TRUE) && rmarkdown::pandoc_available())
    return(list(cmd = rmarkdown::pandoc_exec(), args = character()))
  q <- Sys.which("quarto")
  if (nzchar(q)) return(list(cmd = q, args = "pandoc"))
  stop("pandoc not found: install pandoc or Quarto, or run from RStudio")
}

count_words <- function(text) {
  # (*UCP) makes \s Unicode-aware, so non-breaking spaces ("Figure 2") split words
  tokens <- strsplit(text, "(*UCP)\\s+", perl = TRUE)[[1]]
  sum(grepl("[\\p{L}\\p{N}]", tokens, perl = TRUE))
}

# Does a pandoc AST node contain an Image anywhere?
has_image <- function(x) {
  if (!is.list(x)) return(FALSE)
  if (identical(x$t, "Image")) return(TRUE)
  any(vapply(x, has_image, logical(1)))
}

# Plain text of inline content (for section names)
stringify <- function(x) {
  if (!is.list(x)) return("")
  if (!is.null(x$t)) {
    if (x$t == "Str") return(x$c)
    if (x$t %in% c("Space", "SoftBreak", "LineBreak")) return(" ")
    return(stringify(x$c))
  }
  paste(vapply(x, stringify, character(1)), collapse = "")
}

#' Word counts of a .docx by section and category
#'
#' @param docx   path to a .docx file (rendered by pandoc, Quarto or R Markdown)
#' @param styles named character vector mapping extra paragraph styles to
#'   categories, e.g. `c(PullQuote = "pull quotes")`; added to [default_styles]
#' @param level  headings at this level or above start a new section
#' @param pandoc how to run pandoc; see [find_pandoc()]
#' @return a data frame of word counts, one row per section plus `TOTAL`,
#'   one column per category, with class `"docx_wordcount"`
docx_wordcount <- function(docx, styles = character(), level = 2,
                           pandoc = find_pandoc()) {
  stopifnot(file.exists(docx))
  styles <- c(default_styles, styles)
  json <- tempfile(fileext = ".json")
  on.exit(unlink(json))
  status <- system2(pandoc$cmd, c(pandoc$args, shQuote(docx), "-f", "docx+styles",
                                  "-t", "json", "-o", shQuote(json)))
  if (status != 0) stop("pandoc failed to read ", docx)
  ast <- jsonlite::read_json(json, simplifyVector = FALSE)

  categories <- unique(c(base_categories, unname(styles)))
  counts <- list()                       # section -> named numeric vector
  section <- "(before first heading)"
  acc <- new.env()                       # category -> text pieces, per block

  add <- function(cat, txt) acc[[cat]] <- c(acc[[cat]], txt)

  # collect inline text into categories; footnotes and math are diverted
  inline_text <- function(x, cat) {
    if (!is.list(x)) return(invisible())
    t <- x$t
    if (is.null(t)) { for (y in x) inline_text(y, cat); return(invisible()) }
    switch(t,
      Str       = add(cat, x$c),
      Space     = , SoftBreak = , LineBreak = add(cat, " "),
      Math      = add("math", paste0(" ", x$c[[2]], " ")),
      Note      = { inline_text(x$c, "footnotes"); add(cat, " ") },
      Code      = add(cat, x$c[[2]]),
      # paragraph-level elements (e.g. table cells, list items) end a word
      Para      = , Plain = , Header = , LineBlock = { inline_text(x$c, cat); add(cat, " ") },
      inline_text(x$c, cat))
  }

  flush <- function() {
    if (is.null(counts[[section]]))
      counts[[section]] <<- setNames(numeric(length(categories)), categories)
    for (cat in ls(acc)) {
      n <- count_words(paste(acc[[cat]], collapse = ""))
      if (!cat %in% names(counts[[section]])) counts[[section]][cat] <<- 0
      counts[[section]][cat] <<- counts[[section]][cat] + n
    }
    rm(list = ls(acc), envir = acc)
  }

  block <- function(b, cat) {
    t <- b$t
    if (t == "Header") {
      if (b$c[[1]] <= level) section <<- trimws(stringify(b$c[[3]]))
      inline_text(b$c[[3]], "headings")
    } else if (t == "Div") {
      kv <- b$c[[1]][[3]]
      style <- NULL
      for (p in kv) if (identical(p[[1]], "custom-style")) style <- p[[2]]
      if (!is.null(style) && style %in% names(styles)) cat <- styles[[style]]
      for (bb in b$c[[2]]) block(bb, cat)
      return(invisible())
    } else if (t %in% c("Table", "Figure")) {
      parts <- b$c
      # older pandoc (e.g. 3.1) also emits a table's caption as a separate
      # "Table Caption" paragraph just before the table; don't count it twice
      if (t == "Table" && identical(prev_style, "Table Caption")) parts[[2]] <- list()
      inline_text(parts, if (t == "Figure" || has_image(b)) "figure captions" else "tables")
    } else if (t == "CodeBlock") {
      add("display blocks", b$c[[2]])
    } else {
      inline_text(b$c, cat)
    }
    flush()
  }

  prev_style <- NULL                     # style of the previous top-level block
  for (b in ast$blocks) {
    block(b, "body")
    prev_style <- if (b$t == "Div") {
      kv <- b$c[[1]][[3]]
      s <- NULL
      for (p in kv) if (identical(p[[1]], "custom-style")) s <- p[[2]]
      s
    }
  }

  out <- do.call(rbind, lapply(counts, function(v) v[categories]))
  out[is.na(out)] <- 0
  out <- rbind(out, TOTAL = colSums(out))
  out <- data.frame(section = rownames(out), out, check.names = FALSE, row.names = NULL)
  class(out) <- c("docx_wordcount", class(out))
  out
}

print.docx_wordcount <- function(x, ...) {
  print.data.frame(x, row.names = FALSE, ...)
  invisible(x)
}

summary.docx_wordcount <- function(object, ...) {
  tot <- unlist(object[object$section == "TOTAL", -1])
  display <- setdiff(names(tot), c("body", "headings", "footnotes", "figure captions",
                                   "tables", "display blocks", "math", "references"))
  core <- tot[["body"]] + tot[["headings"]] + sum(tot[display])
  res <- c(
    "Body text"                      = tot[["body"]],
    "+ headings & custom styles"     = core,
    "+ footnotes"                    = core + tot[["footnotes"]],
    "+ captions & tables"            = core + tot[["footnotes"]] + tot[["figure captions"]] + tot[["tables"]],
    "Everything"                     = sum(tot))
  data.frame(count = names(res), words = unname(res))
}

# ---- run as a script: Rscript wordcount.R file.docx [--style Name="category"] [--level n]
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if (!length(args)) stop("usage: Rscript wordcount.R file.docx [--style Name=category] [--level n]")
  styles <- character(); level <- 2; docx <- NULL
  i <- 1
  while (i <= length(args)) {
    a <- args[i]
    if (a == "--style") {
      kv <- strsplit(args[i + 1], "=", fixed = TRUE)[[1]]
      styles[kv[1]] <- kv[2]; i <- i + 2
    } else if (a == "--level") {
      level <- as.integer(args[i + 1]); i <- i + 2
    } else { docx <- a; i <- i + 1 }
  }
  wc <- docx_wordcount(docx, styles = styles, level = level)
  print(wc)
  cat("\n")
  print(summary(wc), row.names = FALSE)
}
