-- Change the default Omarchy look'n'feel.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })

-- Estilo Noctalia (CachyOS): Bordes redondeados, Blur (cristal esmerilado) y sombras
hl.config({
  decoration = {
    rounding = 12,

    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      new_optimizations = true,
      vibrancy = 0.1696,
      ignore_opacity = true,
    },

    shadow = {
      enabled = true,
      range = 12,
      render_power = 3,
      color = "rgba(1a1a1aee)",
    },
  },
})

-- Transparencia más pronunciada para las ventanas generales:
-- 0.80 = ventana activa | 0.70 = ventana inactiva
o.window({ tag = "default-opacity" }, { opacity = "0.80 0.70" })

-- Kitty: letras 100% nítidas siempre (1.0), mientras el fondo usa la transparencia de kitty.conf
o.window("kitty", { tag = "-default-opacity", opacity = "1.0 1.0" })

-- Navegadores y Web Apps de Omarchy (WhatsApp, etc.) 100% opacos siempre
-- (Incluimos brave-origin y las webapps tipo brave-web.whatsapp.com__-Default)
o.window("([bB]rave-origin|[bB]rave-.*|[cC]hrom(e|ium)-.*|[mM]sedge-.*)", { tag = "+chromium-based-browser" })
o.window("([bB]rave-origin|[bB]rave-.*|[cC]hrom(e|ium)-.*|[mM]sedge-.*)", { tag = "-default-opacity", tile = true, opacity = "1.0 1.0" })
o.window({ tag = "chromium-based-browser" }, { tag = "-default-opacity", opacity = "1.0 1.0" })
o.window({ tag = "firefox-based-browser" }, { tag = "-default-opacity", opacity = "1.0 1.0" })

-- Efecto Blur (cristal esmerilado) solo para la tarjeta del menú, barra y paneles (no el fondo)
hl.layer_rule({
  match = { namespace = "^(omarchy-bar|omarchy-menu|omarchy-notifications|omarchy-.*)$" },
  blur = true,
  blur_popups = true,
  ignore_alpha = 0.5,
})






