# dmgbuild settings for the Claude Swap Mac DMG.
# Used by make-dmg.sh:
#   dmgbuild -s scripts/dmg-settings.py -D app=<path> -D background=<tiff> "Claude Swap Mac" ClaudeSwapMac.dmg
import os.path

app = defines.get("app", "Claude Swap Mac.app")  # noqa: F821
appname = os.path.basename(app)

format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}

background = defines.get("background")  # noqa: F821

show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

window_rect = ((200, 120), (600, 400))
default_view = "icon-view"
include_icon_view_settings = True
arrange_by = None
grid_spacing = 100
scroll_position = (0, 0)
label_pos = "bottom"
text_size = 13
icon_size = 128
show_icon_preview = False

icon_locations = {
    appname: (150, 205),
    "Applications": (450, 205),
}
