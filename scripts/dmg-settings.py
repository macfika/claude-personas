"""Finder layout, built without UI scripting by dmgbuild 1.6.7."""
import os

application = defines['app']
format = 'UDZO'
files = [application, defines['instructions']]
symlinks = {'Applications': '/Applications'}
icon = os.path.join(application, 'Contents/Resources/ClaudePersonas.icns')
background = defines['background']
icon_locations = {'ClaudePersonas.app': (180, 220), 'Applications': (540, 220), 'Installation.html': (650, 60)}
window_rect = ((100, 100), (720, 480))
default_view = 'icon-view'
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
grid_spacing = 80
icon_size = 88
text_size = 13
hide_extensions = ['Installation.html']
