# dmgbuild settings for Spindle's installer window. Run by Scripts/make-dmg.sh, which passes
#   -D app=<path to Spindle.app>   -D art=<folder with background-combined.tiff and volume.icns>
import os.path

app_path = defines["app"]
art = defines["art"]

files = [app_path]
symlinks = {"Applications": "/Applications"}
icon = os.path.join(art, "volume.icns")
background = os.path.join(art, "background-combined.tiff")

format = "UDZO"
filesystem = "HFS+"

# A bare window: no toolbar, sidebar or status bar, just the picture and two icons.
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
window_rect = ((200, 120), (660, 400))

default_view = "icon-view"
icon_size = 128
text_size = 13
arrange_by = None
label_pos = "bottom"

# Centres of the icons, in points from the window's top left. The arrow in background.swift
# runs between them, so change both together.
icon_locations = {
    os.path.basename(app_path): (170, 178),
    "Applications": (490, 178),
}
