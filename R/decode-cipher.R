# Decoding van Langren's cipher (La Verdadera Longitud, 1644, p.8)
#
# Companion script for "Van Langren's Secret, Finally Told"
# https://friendly.github.io/blog/posts/2026-07-van-langren/
#
# Reproduces, in R, the four steps Jarl Van Eycke described using to break
# the cipher (as reported by Klaus Schmeh on Cipherbrain):
#   1. the "word" spacing is a decoy
#   2. strip spaces and decoy capital letters
#   3. split what remains into three interleaved streams
#   4. undo a digit-for-letter substitution (1 = a, 2 = b, ... 9 = i)
#
# Requires: cipher-transcription.txt (in this same directory)

## Step 1: the "words" are a decoy ------------------------------------------

cipher_raw <- readLines("cipher-transcription.txt", encoding = "UTF-8") |>
  paste(collapse = " ")
tokens <- strsplit(cipher_raw, "[ \t]+")[[1]]
tokens <- tokens[tokens != ""]

tab <- table(nchar(tokens))
m <- rbind(nchar = as.integer(names(tab)), freq = as.integer(tab))
colnames(m) <- rep("", ncol(m))
m

cat("Total tokens:", sum(tab), "\n")
prop_4_8 <- sum(tab[names(tab) %in% as.character(4:8)]) / sum(tab)
cat(sprintf("Proportion with 4-8 characters: %.1f%%\n", 100 * prop_4_8))

## Step 2: strip spaces and decoy capitals -----------------------------------

nospace <- gsub("[ \t]+", "", cipher_raw)
nocaps  <- gsub("[A-Z]", "", nospace)
substr(nospace, 1, 60)
substr(nocaps, 1, 60)

## Step 3: split into three interleaved streams ------------------------------

chars <- strsplit(nocaps, "")[[1]]
n <- length(chars)
stream1 <- paste(chars[seq(1, n, by = 3)], collapse = "")
stream2 <- paste(chars[seq(2, n, by = 3)], collapse = "")
stream3 <- paste(chars[seq(3, n, by = 3)], collapse = "")
substr(stream1, 1, 60)

## Step 4: undo the digit substitution ---------------------------------------

plain_raw <- paste0(stream1, stream2, stream3)
digit_map <- setNames(letters[1:9], as.character(1:9))
plain_chars <- strsplit(plain_raw, "")[[1]]
subbed <- vapply(plain_chars, function(ch) {
  if (ch %in% names(digit_map)) digit_map[[ch]] else ch
}, character(1))
plain_final <- gsub("ſ", "s", paste(subbed, collapse = ""))

## Highlight the excerpt naming van Langren's method -------------------------

excerpt <- substr(plain_final, 533, 940)
target  <- "langrendictqvonfairadeuxuisesdecuiuredesemblablecipaciteenformedecelindre"

width  <- 68
n      <- nchar(excerpt)
starts <- seq(1, n, by = width)
tpos   <- regexpr(target, excerpt, fixed = TRUE)
ts     <- as.integer(tpos)          # -1 if not found
te     <- if (ts > 0L) ts + nchar(target) - 1L else -1L

esc <- function(x)
  x |> gsub(">", "&gt;", x = _, fixed = TRUE) |>
       gsub("<", "&lt;", x = _, fixed = TRUE) |>
       gsub("&", "&amp;", x = _, fixed = TRUE)

lines_html <- vapply(starts, function(ls) {
  le  <- min(ls + width - 1L, n)
  txt <- substr(excerpt, ls, le)
  os  <- max(ls, ts);  oe <- min(le, te)
  if (ts > 0L && os <= oe) {
    is <- os - ls + 1L;  ie <- oe - ls + 1L
    paste0(esc(substr(txt, 1L,      is - 1L)),
           "<mark>", esc(substr(txt, is, ie)), "</mark>",
           esc(substr(txt, ie + 1L, nchar(txt))))
  } else {
    esc(txt)
  }
}, character(1))

cat('<pre style="background:#f8f8f8;padding:0.6em;border-radius:4px;font-size:0.85em;">\n',
    paste(lines_html, collapse = "\n"), '\n</pre>\n', sep = "")
