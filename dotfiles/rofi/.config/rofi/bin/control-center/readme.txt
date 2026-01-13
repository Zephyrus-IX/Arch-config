CONTROL CENTER – NESTED ROFI MENU SYSTEM
======================================

Author: Jaeden
Purpose: Centralized, extensible, theme-aware rofi control center with
         safe nested navigation and zero duplicated menu logic.

----------------------------------------------------------------------
1. OVERVIEW
----------------------------------------------------------------------

This control center implements a fully nested rofi menu system written
entirely in Bash. It supports:

- Unlimited nested menus
- Static menus (label → submenu / script)
- Dynamic menus (auto-discovered entries)
- Theme-aware rofi layouts
- Icon previews (layouts, wallpapers)
- A consistent "Back" key across all menus
- Safe operation under `set -euo pipefail`

All rofi UI logic is centralized here. Other scripts are task-only
(apply layout, apply wallpaper, etc.) and never invoke rofi themselves.

This avoids duplicated logic, inconsistent keybinds, and UI drift.

----------------------------------------------------------------------
2. CORE DESIGN PRINCIPLES
----------------------------------------------------------------------

1) ONE MENU ENGINE
   - Only this script launches rofi.
   - Other scripts only *do work*.

2) EXPLICIT MENU STACK
   - Menus are nested via recursion (run_menu → run_menu).
   - "Back" returns one level up.
   - "Esc" exits the entire control center.

3) NO GLOBAL STATE MUTATION
   - Menu state is passed via function calls.
   - No hidden globals controlling flow.

4) SAFE UNDER set -euo pipefail
   - All commands that may exit non-zero are explicitly guarded.
   - This prevents silent crashes and infinite loops.

----------------------------------------------------------------------
3. FILE STRUCTURE
----------------------------------------------------------------------

~/.config/rofi/bin/
├── control-center.sh          ← MAIN ENTRY POINT
├── helpers/
│   └── dmenu-helper.sh        ← rofi wrapper + back key definition
├── CONTROL_CENTER_ARCHITECTURE.txt

Other relevant directories:

~/.config/system-theme/
├── state/
│   └── current-theme          ← single source of truth for active theme
├── themes/
│   └── <theme-name>/
│       └── wallpapers/

~/.config/waybar/
├── layouts/
│   └── <layout-name>/
│       └── preview.png

(similar layout structure for wlogout, rofi launchers, etc.)

----------------------------------------------------------------------
4. MENU DATA MODEL
----------------------------------------------------------------------

Menus are defined declaratively using three variables:

- MENU_PROMPT_<name>
- MENU_THEME_<name>
- MENU_OPTIONS_<name>=( ... )

Example:

MENU_PROMPT_main="Control Center | "
MENU_THEME_main="$LAYOUTS_DIR/control-center/control-center.rasi"
MENU_OPTIONS_main=(
  "System Layout Settings →|menu:layouts"
  "Select Wallpaper →|menu:wallpapers"
)

This design allows:
- Adding new menus without touching engine logic
- Per-menu prompts
- Per-menu rofi themes
- Easy reordering

----------------------------------------------------------------------
5. MENU OPTION TYPES
----------------------------------------------------------------------

Each MENU_OPTIONS entry is a single string:

"Label|action"

Where action can be:

1) menu:<submenu>
   - Navigates to another menu
   - Example: "Waybar Layout →|menu:waybar"

2) run:<command>
   - Executes an inline shell command
   - Example: "Reload WM|run:hyprctl reload"

3) <absolute-path-to-script>
   - Executes a script directly

4) dyn:<root>|<apply-script>
   - Dynamic menu (special case)
   - Root determines entries at runtime

----------------------------------------------------------------------
6. DYNAMIC MENUS (dyn:)
----------------------------------------------------------------------

Dynamic menus are auto-generated at runtime.

They support TWO modes automatically:

A) Folder-based (layouts)
   - Root contains subdirectories
   - Each directory represents one entry
   - preview.png is used as icon
   - Selection passes directory name to apply script

B) File-based (wallpapers)
   - Root contains image files
   - Each file becomes an entry
   - File itself is used as icon
   - Full path is passed to apply script

This is auto-detected via:
- Presence of subdirectories in the root

Example:

MENU_OPTIONS_wallpapers=(
  "dyn:$HOME/.config/system-theme/themes/$CURRENT_THEME/wallpapers/|$HOME/.config/swww/apply-wallpaper.sh"
)

----------------------------------------------------------------------
7. BACK & EXIT BEHAVIOR (CRITICAL)
----------------------------------------------------------------------

Keybindings (defined in dmenu-helper.sh):

- Alt+BackSpace → Back (rofi exit code 10)
- Esc            → Cancel (rofi exit code 1)

Behavior:

- Back:
  - Returns to the parent menu
  - Does NOT exit the control center

- Esc:
  - Exits the entire control center immediately

This distinction is intentional and enforced explicitly.

----------------------------------------------------------------------
8. WHY set -e CAUSED SO MANY BUGS
----------------------------------------------------------------------

With `set -e`, Bash immediately exits on any non-zero return UNLESS
the return code is handled on the SAME LINE.

❌ WRONG:
    result="$(rofi ...)"
    rc=$?    # never reached if rc != 0

✅ CORRECT:
    rc=0
    result="$(rofi ...)" || rc=$?

This applies to:
- rofi calls
- function calls
- dynamic menu handlers

Failing to do this caused:
- Menus closing instead of returning
- Back key silently exiting scripts
- Infinite reopen loops

Every non-zero-returning command in this system is guarded correctly.

----------------------------------------------------------------------
9. CORE FUNCTIONS (MENTAL MODEL)
----------------------------------------------------------------------

run_menu(name)
  |
  |-- static menu
  |     |-- rofi_dmenu
  |     |-- interpret action
  |     |-- recurse or run script
  |
  |-- dynamic menu
        |-- _run_dynamic_menu
        |-- propagate rc upward
        |-- decide: stay / return / exit

There is NO global loop restarting rofi.
Menus persist only because parent functions are still running.

----------------------------------------------------------------------
10. HOW TO ADD A NEW MENU (SAFE)
----------------------------------------------------------------------

1) Define menu variables:
   - MENU_PROMPT_new
   - MENU_THEME_new
   - MENU_OPTIONS_new=( ... )

2) Add an entry pointing to it:
   "New Menu →|menu:new"

3) Done.
   No engine code changes required.

----------------------------------------------------------------------
11. HOW TO ADD A NEW DYNAMIC MENU
----------------------------------------------------------------------

If entries are:
- folders → use dyn:<root>|<apply>
- files   → use dyn:<root>|<apply>

Ensure:
- Root exists
- Apply script is executable
- Apply script accepts the passed argument

----------------------------------------------------------------------
12. WHAT NOT TO DO
----------------------------------------------------------------------

❌ Do not call rofi from other scripts
❌ Do not use exec rofi
❌ Do not ignore rc under set -e
❌ Do not hardcode keybinds elsewhere
❌ Do not add logic into apply scripts

----------------------------------------------------------------------
13. FINAL NOTE
----------------------------------------------------------------------

This system is intentionally over-engineered so that:

- Adding features is trivial
- Debugging is predictable
- UI behavior is consistent
- Future refactors are unnecessary

If something breaks:
- Check exit codes
- Check set -e interactions
- Check that functions return, not exit

This file exists so future-you remembers WHY things were done this way.

----------------------------------------------------------------------

END OF DOCUMENT
