# Rebuilding van Langren's 1644 dot plot as an overlay on a modern map
#
# Companion script for "Van Langren's Secret, Finally Told"
# https://friendly.github.io/blog/posts/2026-07-van-langren/
#
# Uses HistData::Langren1644 (the estimates) and the Google Maps image
# bundled with that package as a backdrop, built up in three layers:
# the map itself, city markers, and the dot plot on top.
#
# Requires: jpeg, HistData

library(jpeg)
library(HistData)

data(Langren1644)

# translate degrees longitude -> pixel x-coordinate
xlate <- function(x) 131 + x * 726 / 30

gimage <- readJPEG(system.file("images", "google-toledo-rome3.jpg", package = "HistData"))
gdim   <- dim(gimage)[1:2]   # NB: readJPEG returns y, x, colors

draw_map <- function() {
  op <- par(bty = "n", xaxt = "n", yaxt = "n", mar = c(0, 0, 0, 0))
  plot(c(1, gdim[2]), c(1, gdim[1]), type = "n", ann = FALSE, asp = 1)
  rasterImage(gimage, 1, 1, gdim[2], gdim[1])
  invisible(op)
}

add_cities <- function() {
  points(rbind(c(131, 59), c(506, 119)), cex = 2)
  text(131, 95,  "Toledo", cex = 1.5)
  text(506, 104, "Roma",   cex = 1.5)
}

add_dotplot <- function() {
  lines(data.frame(x = c(131, 856), y = c(52, 52)))
  ticks <- xlate(seq(0, 30, 5))
  segments(ticks, 52, ticks, 45)
  text(ticks, 40, seq(0, 30, 5))
  text(xlate(8), 67, "Grados de la Longitud", cex = 1.7)
  points(x = xlate(Langren1644$Longitude), y = rep(57, nrow(Langren1644)),
         pch = 25, col = "blue", bg = "blue")
  text(x = xlate(Langren1644$Longitude), y = rep(57, nrow(Langren1644)),
       labels = Langren1644$Name, srt = 90, adj = c(-.1, .5), cex = 0.8)
}

# Layer by layer, ending with the full overlay:
draw_map()
add_cities()
add_dotplot()
