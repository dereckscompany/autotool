#!/usr/bin/env Rscript
# ============================================================================
# LOGO.R - Generate the autotool hex sticker
# ============================================================================
# Multi-layer compositing: ggplot2 renders layers, magick applies a real
# gaussian-blur glow via screen blending.
#
# Concept: a gear / cog -- the universal "tool & automation" mark -- glowing
# inside a hexagon, evoking autotool's job of turning R functions into ready
# LLM tool definitions automatically. Dark slate field, tech-blue gear, soft
# glow. The "autotool" wordmark sits below.
#
# Usage:  Rscript scripts/LOGO.R
# Deps:   ggplot2, magick
# ============================================================================

library(ggplot2)
library(magick)

# ============================================================================
# Palette
# ============================================================================

col_hex_fill <- "#0E1320" # deep slate field
col_hex_edge <- "#3B9EFF" # tech-blue hex border
col_gate_ring <- "#1E2A3A" # subtle inner ring
col_gear <- "#3B9EFF" # the gear — tool blue
col_gear_core <- "#A9D6FF" # bright inner highlight
col_hub <- "#0E1320" # gear hub hole (matches field)
col_glow <- "#3B9EFF" # glow source colour
col_wordmark <- "#F0F4F8" # near-white wordmark

# ============================================================================
# Geometry helpers
# ============================================================================

# Pointy-top hexagon vertices (vertex at the top), radius r, centred at (cx, cy).
hex_vertices <- function(cx = 0, cy = 0, r = 1) {
  angles <- seq(pi / 2, pi / 2 + 2 * pi, length.out = 7)[1:6]
  return(data.frame(x = cx + r * cos(angles), y = cy + r * sin(angles)))
}

filled_circle <- function(cx, cy, r, n = 180) {
  angles <- seq(0, 2 * pi, length.out = n)
  return(data.frame(x = cx + r * cos(angles), y = cy + r * sin(angles)))
}

# A gear outline: `n_teeth` square teeth between the tip radius `r_out` and the
# root radius `r_root`, centred at (cx, cy).
gear_polygon <- function(cx, cy, r_out, r_root, n_teeth = 9, tooth_frac = 0.5) {
  step <- 2 * pi / n_teeth
  xs <- numeric(0)
  ys <- numeric(0)
  for (i in seq_len(n_teeth)) {
    a0 <- (i - 1) * step
    a_top_end <- a0 + step * tooth_frac
    a_valley_end <- a0 + step
    angles <- c(a0, a0, a_top_end, a_top_end, a_valley_end)
    radii <- c(r_root, r_out, r_out, r_root, r_root)
    xs <- c(xs, cx + radii * cos(angles))
    ys <- c(ys, cy + radii * sin(angles))
  }
  return(data.frame(x = xs, y = ys))
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

# Render a ggplot to a magick image on a transparent background.
render_layer <- function(p, width = 3000, height = 3480) {
  tmp <- tempfile(fileext = ".png")
  ggsave(tmp, plot = p, width = width / 600, height = height / 600, dpi = 600, bg = "transparent")
  img <- image_read(tmp)
  unlink(tmp)
  return(img)
}

# Shared geometry: gear sits slightly above centre, leaving room for the
# wordmark below.
gear_cy <- 0.06

# ============================================================================
# Layers
# ============================================================================

build_base_layer <- function() {
  hex_outer <- hex_vertices(0, 0, 0.62)
  hex_inner <- hex_vertices(0, 0, 0.50)
  gear <- gear_polygon(0, gear_cy, r_out = 0.34, r_root = 0.26, n_teeth = 9)
  hub <- filled_circle(0, gear_cy, 0.13)
  hub_ring <- rbind(filled_circle(0, gear_cy, 0.13), filled_circle(0, gear_cy, 0.13)[1, ])
  axle <- filled_circle(0, gear_cy, 0.05)

  ggplot() +
    # Hex field
    geom_polygon(data = hex_outer, aes(x, y), fill = col_hex_fill, colour = col_hex_edge, linewidth = 7) +
    # Subtle inner ring
    geom_polygon(data = hex_inner, aes(x, y), fill = NA, colour = col_gate_ring, linewidth = 2, linejoin = "mitre") +
    # Gear body
    geom_polygon(data = gear, aes(x, y), fill = col_gear, colour = NA) +
    # Hub hole
    geom_polygon(data = hub, aes(x, y), fill = col_hub, colour = NA) +
    # Hub ring highlight
    geom_path(data = hub_ring, aes(x, y), colour = col_gear_core, linewidth = 5) +
    # Axle dot
    geom_polygon(data = axle, aes(x, y), fill = col_gear_core, colour = NA) +
    # Wordmark
    annotate(
      "text",
      x = 0,
      y = -0.42,
      label = "autotool",
      colour = col_wordmark,
      size = 13,
      fontface = "bold",
      family = "sans"
    ) +
    logo_coord() +
    logo_theme()
}

# Glow source: the gear, to be blurred.
build_glow_layer <- function() {
  gear <- gear_polygon(0, gear_cy, r_out = 0.34, r_root = 0.26, n_teeth = 9)
  ggplot() +
    geom_polygon(data = gear, aes(x, y), fill = col_glow, colour = NA) +
    logo_coord() +
    logo_theme()
}

# ============================================================================
# Composite
# ============================================================================

generate_logo <- function(
  output_path = file.path("man", "figures", "logo.png"),
  px_width = 3000,
  px_height = 3480
) {
  message("Rendering base layer...")
  base_img <- render_layer(build_base_layer(), px_width, px_height)

  message("Rendering glow layer...")
  glow_img <- render_layer(build_glow_layer(), px_width, px_height)

  message("Blurring glow...")
  glow_wide <- image_blur(glow_img, radius = 0, sigma = 45)
  glow_tight <- image_blur(glow_img, radius = 0, sigma = 15)

  message("Compositing...")
  final <- base_img |>
    image_composite(glow_wide, operator = "screen") |>
    image_composite(glow_tight, operator = "screen") |>
    image_composite(base_img, operator = "over")

  final <- image_trim(final)

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
