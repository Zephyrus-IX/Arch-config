###############################################################################
# CONTROL CENTER MENU DEFINITIONS
#
# This file contains ONLY menu declarations for the Control Center rofi system.
# It is sourced by control-center.sh AFTER all core paths and defaults are set.
#
# ──────────────────────────────────────────────────────────────────────────
# ALLOWED CONTENT
# ──────────────────────────────────────────────────────────────────────────
# ✔ MENU_PROMPT_<name>="..."
# ✔ MENU_THEME_<name>="..."
# ✔ MENU_OPTIONS_<name>=( ... )
#
# ✔ Plain variable expansion
# ✔ Use of path variables defined in control-center.sh (see below)
#
# ──────────────────────────────────────────────────────────────────────────
# DISALLOWED CONTENT
# ──────────────────────────────────────────────────────────────────────────
# ✘ No functions
# ✘ No loops
# ✘ No conditionals (if / case / while)
# ✘ No command execution
# ✘ No rofi calls
# ✘ No exits or returns
#
# This file is DATA ONLY. All logic lives in control-center.sh.
#
# ──────────────────────────────────────────────────────────────────────────
# MENU NAMING CONVENTION
# ──────────────────────────────────────────────────────────────────────────
# Each menu consists of three variables sharing the same <name>:
#
#   MENU_PROMPT_<name>   - Prompt text shown in rofi
#   MENU_THEME_<name>    - Path to a rofi .rasi theme (may be empty)
#   MENU_OPTIONS_<name>  - Bash array of menu entries
#
# The menu name <name> is referenced via:
#   "Label →|menu:<name>"
#
# ──────────────────────────────────────────────────────────────────────────
# MENU OPTIONS FORMAT
# ──────────────────────────────────────────────────────────────────────────
# Each MENU_OPTIONS entry is a single string:
#
#   "Label|action"
#
# Supported action types:
#
#   menu:<submenu>
#     → Navigate to another menu defined in this file
#
#   run:<command>
#     → Execute a shell command, then exit the control center
#
#   <absolute-path-to-script>
#     → Execute a script directly, then exit the control center
#
#   dyn:<root>|<apply-script>
#     → Dynamic menu:
#         - If <root> contains subdirectories:
#             each directory becomes an entry (uses preview.png if present)
#         - Otherwise:
#             each image file becomes an entry (wallpapers)
#         - Selected value is passed to <apply-script>
#
# ──────────────────────────────────────────────────────────────────────────
# AVAILABLE VARIABLES FROM control-center.sh
# ──────────────────────────────────────────────────────────────────────────
# The following variables are defined BEFORE this file is sourced and may
# safely be used in menu definitions:
#
#   SCRIPT_DIR
#   LAYOUTS_DIR
#   CURRENT_THEME
#   ROFI_THEME_DEFAULT
#   PROMPT_DEFAULT
#   HOME
#
# Do NOT redefine these here.
#
# ──────────────────────────────────────────────────────────────────────────
# IMPORTANT NOTES
# ──────────────────────────────────────────────────────────────────────────
# - Leaf actions (run / script / dyn) will CLOSE the entire control center.
# - Only menu: actions keep the menu system alive.
# - Back navigation is handled globally (Alt+BackSpace).
# - Esc always exits the control center.
#
# If something breaks:
#   → Check menu names
#   → Check paths
#   → Check dyn roots and apply scripts
#
###############################################################################
ICON_DIR="$HOME/.config/rofi/icons/control-center"

ICON_LAYOUTS="$ICON_DIR/layouts.svg"
ICON_WALLPAPERS="$ICON_DIR/wallpapers.svg"
ICON_THEMES="$ICON_DIR/themes.svg"
ICON_SETTINGS="$ICON_DIR/settings.png"


MENU_PROMPT_main="Control Center | "
MENU_THEME_main="$LAYOUTS_DIR/control-center/control-center.rasi"
MENU_OPTIONS_main=(
  "System Layout Settings →\0icon\x1f$ICON_LAYOUTS|menu:layouts"
  "Select Wallpaper →\0icon\x1f$ICON_WALLPAPERS|menu:wallpapers"
  "Themes →\0icon\x1f$ICON_THEMES|menu:themes"
)

    MENU_PROMPT_layouts="Select a layout to manage | "
    MENU_THEME_layouts="$LAYOUTS_DIR/control-center/control-center.rasi"
    MENU_OPTIONS_layouts=(
      "Wlogout Layout →|menu:wlogout"
      "App Launcher Layout →|menu:launcher"
      "SwayNC Layout →|menu:swaync"
      "Waybar Layout →|menu:waybar"
    )

        MENU_PROMPT_wlogout="Waybar Layout | "
        MENU_THEME_wlogout="$LAYOUTS_DIR/launchers/launcher-picker.rasi"
        MENU_OPTIONS_wlogout=(
          "dyn:$HOME/.config/wlogout/layouts|$HOME/.config/wlogout/bin/apply-layout.sh"
        )

        MENU_PROMPT_launcher="Choose a layout | "
        MENU_THEME_launcher="$LAYOUTS_DIR/launchers/launcher-picker.rasi"
        MENU_OPTIONS_launcher=(
          "dyn:$HOME/.config/rofi/layouts/launchers/|$HOME/.config/rofi/bin/apply-launcher.sh"
        )

        MENU_PROMPT_swaync="Choose a layout | "
        MENU_THEME_swaync="$LAYOUTS_DIR/launchers/launcher-picker.rasi"
        MENU_OPTIONS_swaync=(
          "dyn:$HOME/.config/swaync/layouts/|$HOME/.config/swaync/bin/switch-layout.sh"
        )

        MENU_PROMPT_waybar="Choose a layout | "
        MENU_THEME_waybar="$LAYOUTS_DIR/launchers/launcher-picker.rasi"
        MENU_OPTIONS_waybar=(
          "dyn:$HOME/.config/waybar/layouts/|$HOME/.config/waybar/bin/switch-layout.sh"
        )

    MENU_PROMPT_wallpapers="Choose a wallpaper | "
    MENU_THEME_wallpapers="$LAYOUTS_DIR/wall-picker/wall-picker.rasi"
    MENU_OPTIONS_wallpapers=(
      "dyn:$HOME/.config/system-theme/themes/$CURRENT_THEME/wallpapers/|$HOME/.config/swww/apply-wallpaper.sh"
    )

    MENU_PROMPT_themes="Choose a theme | "
    MENU_THEME_themes="$LAYOUTS_DIR/wall-picker/wall-picker.rasi"
    MENU_OPTIONS_themes=(
      "dyn:$HOME/.config/system-theme/themes/|$HOME/.config/system-theme/bin/apply-theme.sh"
    )