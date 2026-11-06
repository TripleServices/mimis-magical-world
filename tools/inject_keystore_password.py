#!/usr/bin/env python3
"""Re-inject the release keystore password into export_presets.cfg for LOCAL
exports (manual route). Reads the password from android/keystore-info.txt
(never printed) and replaces the __KEYSTORE_PASSWORD__ placeholder.

The committed export_presets.cfg carries the placeholder, not the real
password; CI injects it from GitHub secrets instead. Run this before a local
Godot editor export, or after cloning, and never commit the result.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLACEHOLDER = "__KEYSTORE_PASSWORD__"

info = open(os.path.join(ROOT, "android/keystore-info.txt")).read()
match = re.search(r"alias: mimi-upload\n\s*password: (\S+)", info)
if not match:
    print("ERROR: no se encontró la contraseña en android/keystore-info.txt",
          file=sys.stderr)
    sys.exit(1)
pw = match.group(1)

path = os.path.join(ROOT, "export_presets.cfg")
current = open(path).read()
if PLACEHOLDER not in current:
    print("export_presets.cfg ya tiene contraseña real o no tiene placeholder; "
          "nada que hacer")
    sys.exit(0)
open(path, "w").write(current.replace(PLACEHOLDER, pw))
print("Contraseña del keystore inyectada en export_presets.cfg (no se muestra).")
print("Recuerda: NO hagas commit de export_presets.cfg con la contraseña real.")
