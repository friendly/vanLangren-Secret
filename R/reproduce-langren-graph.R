# Reproducing van Langren's 1644 dot plot in ggplot2
#
# Companion script for "Van Langren's Secret, Finally Told"
# https://friendly.github.io/blog/posts/2026-07-van-langren/
#
# Requires: ggplot2, showtext, HistData

library(ggplot2)
library(showtext)
library(HistData)

data(Langren1644)

font_add_google("IM Fell English", "imfell")
# showtext sizes text for a given resolution; keep this equal to the dpi in ggsave() below
dpi <- 300
showtext_opts(dpi = dpi)
showtext_auto()

roma_x    <- 23.5          # van Langren's placement
true_long <- 16 + 32/60    # true distance, unknown at the time
body_size <- 4.0;  head_size <- 2.5
body_y    <- 0.50; head_y    <- 0.80

p <- ggplot(Langren1644, aes(x = Longitude)) +
  annotate("segment", x = 0, xend = 32, y = 0, yend = 0, linewidth = 0.6) +
  annotate("segment",
    x = seq(0, 32, 1), xend = seq(0, 32, 1),
    y = 0, yend = -0.15, linewidth = 0.3) +
  annotate("segment",
    x = c(10, 20, 30), xend = c(10, 20, 30),
    y = 0, yend = -0.35, linewidth = 0.6) +
  annotate("text",
    x = c(10, 20, 30), y = -0.6,
    label = c("10.", "20.", "30."), family = "imfell", size = 2.1) +
  geom_point(aes(y = body_y),
    shape = 21, size = body_size, fill = "black", color = "black", stroke = 0.8) +
  geom_point(aes(y = head_y),
    shape = 21, size = head_size, fill = "white", color = "black", stroke = 0.8) +
  annotate("point", x = 0, y = body_y,
    shape = 21, size = body_size, fill = "black", color = "black", stroke = 0.8) +
  annotate("point", x = 0, y = head_y,
    shape = 21, size = head_size, fill = "white", color = "black", stroke = 1.0) +
  geom_text(aes(y = head_y + 0.35, label = paste0(Name, ".")),
    angle = 90, hjust = 0, vjust = 0.5,
    family = "imfell", size = 2.4, fontface = "italic") +
  annotate("text", x = -0.8, y = 3.5,
    label = "TOLEDO.", angle = 90, family = "imfell", size = 3.0, fontface = "bold") +
  annotate("text", x = roma_x, y = 0,
    label = "ROMA", family = "imfell", size = 3.0, fontface = "bold", vjust = 2.0) +
  annotate("text", x = 6, y = 2.8,
    label = "Grados de la Longitud.",
    family = "imfell", size = 5, hjust = 0, fontface = "italic") +
  # arrow below the axis marking the true distance (16°32'), unknown to van Langren
  annotate("segment",
    x = true_long, xend = true_long, y = -0.9, yend = -0.4,
    arrow = arrow(length = unit(0.15, "cm"), type = "open"),
    linewidth = 0.5) +
  coord_fixed(ratio = 1, xlim = c(-2, 33), ylim = c(-1.0, 6.5), expand = FALSE) +
  theme_void()

# save at a fixed size and resolution (the strip is 35 x 7.5 data units);
# on-screen previews at other resolutions will show the text at the wrong size
ggsave("langren-reconstruction.png", p, width = 7, height = 7 * 7.5 / 35, dpi = dpi)
