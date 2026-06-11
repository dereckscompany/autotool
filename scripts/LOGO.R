#!/usr/bin/env Rscript
# ============================================================================
# LOGO.R - Generate the autotool hex sticker
# ============================================================================
# Flat, clean hex sticker in the tidyverse / plyr family style: a small,
# limited palette, flat shapes, no glow. A wrench -- the iconic tool, a nod to
# dplyr's pliers -- sits across the hex. autotool is, literally, an automatic
# tool.
#
# Usage:  Rscript scripts/LOGO.R
# Deps:   ggplot2, magick
# ============================================================================

library(ggplot2)
library(magick)

# ============================================================================
# Palette  (3 colours: parchment field, terracotta tool, dark slate ink)
# ============================================================================

col_bg <- "#EFE7D6" # warm parchment field
col_edge <- "#2F4858" # dark slate border + ink
col_inner <- "#C9BBA0" # faint inner border line
col_tool <- "#E07A3F" # terracotta wrench
col_tool_edge <- "#B85C28" # wrench outline
col_tool_hi <- "#F1A86F" # soft highlight on the wrench
col_word <- "#2F4858" # wordmark ink

# ============================================================================
# Geometry helpers
# ============================================================================

# Pointy-top hexagon vertices (vertex at the top), radius r, centred at (cx, cy).
hex_vertices <- function(cx = 0, cy = 0, r = 1) {
  angles <- seq(pi / 2, pi / 2 + 2 * pi, length.out = 7)[1:6]
  return(data.frame(x = cx + r * cos(angles), y = cy + r * sin(angles)))
}

# Rotate a data frame of x/y points by `theta` radians about (cx, cy).
rotate_df <- function(df, theta, cx = 0, cy = 0) {
  ct <- cos(theta)
  st <- sin(theta)
  x <- df$x - cx
  y <- df$y - cy
  return(data.frame(x = cx + x * ct - y * st, y = cy + x * st + y * ct))
}

# Silhouette of an open-end wrench, head (with U-notch) pointing up, handle
# pointing down, centred near the origin.
wrench_polygon <- function() {
  hw <- 0.055 # handle half-width
  half_w <- 0.170 # head half-width
  notch_w <- 0.062 # jaw opening half-width
  y_bot <- -0.30 # handle bottom
  y_head <- 0.05 # head widens here
  y_notch <- 0.16 # bottom of jaw notch
  y_top <- 0.33 # prong tips
  return(data.frame(
    x = c(-hw, -hw, -half_w, -half_w, -notch_w, -notch_w, notch_w, notch_w, half_w, half_w, hw, hw),
    y = c(y_bot, y_head, y_head, y_top, y_top, y_notch, y_notch, y_top, y_top, y_head, y_head, y_bot)
  ))
}

logo_theme <- function() {
  return(
    theme_void() +
      theme(
        plot.background = element_rect(fill = "transparent", colour = NA),
        panel.background = element_rect(fill = "transparent", colour = NA),
        plot.margin = margin(0, 0, 0, 0)
      )
  )
}

logo_coord <- function() {
  return(coord_equal(xlim = c(-0.67, 0.67), ylim = c(-0.67, 0.67)))
}

# The wrench, rotated diagonally and nudged up to leave room for the wordmark.
wrench_mark <- function(shift_x = 0, shift_y = 0) {
  wr <- wrench_polygon()
  wr <- rotate_df(wr, theta = -0.55, cx = 0, cy = 0.015)
  wr$x <- wr$x + shift_x
  wr$y <- wr$y + shift_y + 0.09
  return(wr)
}

# ============================================================================
# Build the sticker (single flat layer, no glow)
# ============================================================================

build_logo <- function() {
  hex_outer <- hex_vertices(0, 0, 0.62)
  hex_line <- hex_vertices(0, 0, 0.55)
  wrench <- wrench_mark()
  wrench_shadow <- wrench_mark(shift_x = 0.012, shift_y = -0.012)

  ggplot() +
    # Parchment field with dark border
    geom_polygon(data = hex_outer, aes(x, y), fill = col_bg, colour = col_edge, linewidth = 9) +
    # Faint inner border line
    geom_polygon(data = hex_line, aes(x, y), fill = NA, colour = col_inner, linewidth = 1.4, linejoin = "mitre") +
    # Soft flat shadow under the wrench
    geom_polygon(data = wrench_shadow, aes(x, y), fill = col_tool_edge, colour = NA, alpha = 0.35) +
    # Wrench body
    geom_polygon(data = wrench, aes(x, y), fill = col_tool, colour = col_tool_edge, linewidth = 2) +
    # Wordmark
    annotate(
      "text",
      x = 0,
      y = -0.39,
      label = "autotool",
      colour = col_word,
      size = 13,
      fontface = "bold",
      family = "sans"
    ) +
    logo_coord() +
    logo_theme()
}

# ============================================================================
# Render
# ============================================================================

generate_logo <- function(
  output_path = file.path("man", "figures", "logo.png"),
  px_width = 3000,
  px_height = 3480
) {
  message("Rendering sticker...")
  tmp <- tempfile(fileext = ".png")
  ggsave(
    tmp,
    plot = build_logo(),
    width = px_width / 600,
    height = px_height / 600,
    dpi = 600,
    bg = "transparent"
  )
  final <- image_trim(image_read(tmp))
  unlink(tmp)

  dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)
  image_write(final, output_path, format = "png")
  message("Logo saved to: ", output_path)

  for (dest in c("docs/logo.png", "docs/reference/figures/logo.png")) {
    if (dir.exists(dirname(dest))) {
      file.copy(output_path, dest, overwrite = TRUE)
      message("Copied to:    ", dest)
    }
  }

  return(invisible(final))
}

# ============================================================================
# Run
# ============================================================================

if (!interactive() || identical(Sys.getenv("LOGO_GENERATE"), "true")) {
  generate_logo()
} else {
  message("Source this file and call generate_logo() to create the sticker.")
  message("Or run: Rscript scripts/LOGO.R")
}
