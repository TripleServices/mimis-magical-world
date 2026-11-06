# Upgrade Godot 4.3 → 4.6 — Mimi's Magical World (reporte 2026-11-06)

Trial copy: `~/workspace/mimis-magical-world-46/` (el proyecto original 4.3 en
`~/workspace/mimis-magical-world/` NO se tocó: sigue en `config/features 4.3` y su
APK firmado sigue siendo API 34).

## Resultado

- **Godot usado:** 4.6.3 stable oficial (`4.6.3.stable.official.7d41c59c4`),
  binario en `~/workspace/godot/Godot_v4.6.3-stable_linux.x86_64`.
- **targetSdkVersion confirmado: 36** — manifiesto del AAB (bundletool dump
  manifest): `<uses-sdk android:minSdkVersion="24" android:targetSdkVersion="36"/>`,
  `versionCode="2"`, `versionName="1.1"`, `package="com.mimithekitty.magicalworld"`,
  `compileSdkVersion="36"`. El APK universal generado desde el AAB también da
  `targetSdkVersion:'36'`. Listo para subir a Play (el AAB viejo API 34 sería
  rechazado desde el 31 ago 2026).
- **Juego verificado limpio bajo 4.6** (ver § Pruebas).

## Archivos (todo en la copia -46)

| Archivo | Tamaño | Notas |
|---|---|---|
| `build/android/mimis-magical-world.apk` (export Godot + themed_icon inyectado) | 30.330.905 | |
| `build/android/mimis-magical-world-aligned.apk` (zipalign) | 30.330.905 | |
| `build/android/mimis-magical-world-signed.apk` (apksigner, llave de subida) | 30.336.776 | v2+v3 verificados, mismo certificado que el APK 4.3 (SHA-256 `303211db…233fc5`) |
| **`build/aab-work-v11-46/mimis-magical-world-signed.aab`** | **30.250.334** | **jarsigner verificado; el entregable para Play** |

## Cambios que requirió el upgrade en el proyecto

1. **`export_presets.cfg` (solo la copia -46):**
   - Rutas del keystore apuntan a la copia:
     `…/mimis-magical-world-46/android/mimi-upload.keystore` (ambos presets Android).
   - Añadido en ambos presets Android:
     `launcher_icons/adaptive_monochrome_432x432="res://assets/icon_432.png"`.
     Sin esto, la exportación 4.6 no genera los iconos monocromo.
2. **Ningún cambio en scripts, escenas ni assets.** `project.godot` sigue diciendo
   `config/features "4.3"` (Godot no lo reescribe al importar; inofensivo).
3. **Archivos nuevos en la copia:** `build/rebuild-aab-46.sh` (ruta manual adaptada),
   `build/aab-work-v11-46/bundletool.jar` (copia del jar).
4. **Editor:** plantillas 4.6 instaladas en
   `~/.local/share/godot/export_templates/4.6.3.stable/` — OJO: 4.6 busca la
   carpeta con el parche (`4.6.3.stable`, no `4.6.stable`). Ajustes de editor
   `~/.config/godot/editor_settings-4.6.tres` copiados de los de 4.3 (rutas del
   Android SDK y JDK 17).

## Workaround necesario: themed_icon.xml (bug/quirk de la exportación 4.6.3)

La exportación 4.6.3 escribe el contenido de `themed_icon.xml` DENTRO de
`res/mipmap-anydpi-v26/icon.xml` (log: `replacing with themed_icon.xml data`)
pero NO escribe el archivo `themed_icon.xml`, aunque la tabla de recursos
(`resources.arsc`) sigue declarando `mipmap/themed_icon` → ese archivo.
Consecuencia: `aapt2 convert` falla con
`no file associated with (file) res/mipmap-anydpi-v26/themed_icon.xml`.
No afecta al APK en Android (instala y corre), solo a la ruta manual APK→AAB.

**Fix aplicado:** extraer `themed_icon.xml` del APK de la plantilla 4.6
(`~/.local/share/godot/export_templates/4.6.3.stable/android_release.apk`,
548 bytes, referencia los mismos IDs de recurso) e inyectarlo en el APK
exportado con `zip` ANTES de zipalign + apksigner. Después de eso, `aapt2
convert` funciona. Si se vuelve a exportar, hay que repetir la inyección
(está documentada aquí; no está automatizada en `rebuild-aab-46.sh`, que
parte del APK ya firmado).

## Pruebas (Godot 4.6.3, copia -46)

- **Import headless:** exit 0, 228 recursos importados, log vacío (sin errores).
- **`tools/test_game.gd` (headless):** `TEST RESULT collected=15/15 win_seen=true
  advanced_to_level2=true back_at_menu=true coco_visible=true`.
- **`tools/test_buyonly.gd` (headless):** `BUYONLY RESULT grants_blocked=true
  lulu=true win=true earn_mode=true`, 0 script errors.
- **`tools/shot_play.gd` (xvfb-run, 1280×720):** 5/5 capturas guardadas, 0 script
  errors; la de la Casa verificada visualmente (Mimi Blender visible, HUD 0/8).
- **Control 4.3:** los mismos tests corridos con Godot 4.3 sobre el proyecto
  original dan RESULTADOS IDÉNTICOS, incluido el ruido headless preexistente
  (5× `SCRIPT ERROR: save_png on null` por falta de render en headless, 15×
  `Function blocked during in/out signal`, 5× `Parameter "t" is null`). Nada de
  eso es una regresión de 4.6.

## Observaciones / diferencias 4.6 vs 4.3

- **minSdkVersion 24** (antes 21) — lo fija la plantilla 4.6. No es problema
  para Play (el 99%+ de dispositivos activos son API 24+).
- **Iconos ahora en webp** (antes png); el APK crece de 26,8 MB a 30,3 MB.
- **v1 (JAR signing):** apksigner reporta `v1: false` en el APK 4.6 aunque los
  archivos `META-INF/MANIFEST.MF`, `.SF` y `.RSA` SÍ están presentes; en el APK
  4.3 (minSdk 21) reporta `v1: true`. Parece comportamiento de apksigner con
  minSdk 24+. v2+v3 verifican bien y el AAB (el entregable real) se firma con
  jarsigner y verifica OK — no es bloqueador para Play.
- **`/tmp` es un tmpfs de 512 MB** y se llenó al extraer las plantillas (1,25 GB).
  Extraer archivos grandes bajo `/home`, nunca en `/tmp`.

## Pendiente (fuera de este trabajo)

- Subir este AAB a Play Console (pista de prueba cerrada) — NO hecho aquí.
- Cuando el proyecto original migre a 4.6, aplicar los mismos 2 cambios de
  `export_presets.cfg` (rutas de keystore + icono monocromo) y la inyección de
  `themed_icon.xml` en cada exportación.
