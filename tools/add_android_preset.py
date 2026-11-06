#!/usr/bin/env python3
"""Appends the Android preset to export_presets.cfg, injecting the release
keystore password read from android/keystore-info.txt (never printed)."""
import os
import re

ROOT = os.path.expanduser("~/workspace/mimis-magical-world")
info = open(os.path.join(ROOT, "android/keystore-info.txt")).read()
pw = re.search(r"alias: mimi-upload\n\s*password: (\S+)", info).group(1)

preset = f"""
[preset.1]

name="Android"
platform="Android"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/android/mimis-magical-world.aab"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.1.options]

custom_template/debug=""
custom_template/release=""
gradle_build/use_gradle_build=false
gradle_build/export_format=1
keystore/debug=""
keystore/debug_user=""
keystore/debug_password=""
keystore/release="/home/hatch/workspace/mimis-magical-world/android/mimi-upload.keystore"
keystore/release_user="mimi-upload"
keystore/release_password="{pw}"
package/unique_name="com.mimithekitty.magicalworld"
package/name="Mimi's Magical World"
package/signed=true
package/retain_data_on_uninstall=false
package/exclude_from_recents=false
package/show_in_android_tv=false
package/show_in_app_library=true
version/code=1
version/name="1.0"
launcher_icons/main_192x192="res://assets/icon_192.png"
launcher_icons/adaptive_foreground_432x432="res://assets/icon_432.png"
launcher_icons/adaptive_background_432x432="res://assets/icon_432.png"
graphics/opengl_debug=false
xr_features/xr_mode=0
screen/immersive_mode=true
screen/background_color=Color(0.98, 0.85, 0.9, 1)
"""

path = os.path.join(ROOT, "export_presets.cfg")
current = open(path).read()
if 'name="Android"' in current:
    print("preset already present, skipping")
else:
    with open(path, "a") as f:
        f.write(preset)
    print("Android preset added (password injected, not shown)")
