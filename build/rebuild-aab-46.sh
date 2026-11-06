#!/bin/bash
# Reconstruye el AAB de Mimi's Magical World desde el APK firmado (ruta manual).
# Uso: ./rebuild-aab.sh   (lee la contraseña del keystore de android/keystore-info.txt línea 12)
# Validado 2026-11-01 (v1.0) y 2026-11-05 (v1.1, Mimi Blender + teddy).
set -euo pipefail
PROJ="$HOME/workspace/mimis-magical-world-46"
WORK="$PROJ/build/aab-work-v11-46"
BT="$HOME/workspace/android-tools/sdk/build-tools/34.0.0"
JDK="$HOME/workspace/android-tools/jdk/bin"
export PATH="$JDK:$BT:$PATH"
APK="$PROJ/build/android/mimis-magical-world-signed.apk"
KS="$PROJ/android/mimi-upload.keystore"
KS_PASS="$(sed -n '12p' "$PROJ/android/keystore-info.txt" | awk -F': ' '{print $2}')"
export KS_PASS
BUNDLETOOL="$WORK/bundletool.jar"

mkdir -p "$WORK/proto" "$WORK/base"
cd "$WORK"
echo "== 1. aapt2 convert (APK -> proto) =="
aapt2 convert --output-format proto -o proto.apk "$APK"
echo "== 2. desempaquetar proto.apk =="
rm -rf proto/* && (cd proto && unzip -o -q ../proto.apk)
echo "== 3. reempaquetar módulo base =="
rm -rf base && mkdir -p base/manifest base/dex base/root
mv proto/AndroidManifest.xml base/manifest/
mv proto/*.dex base/dex/
[ -f proto/resources.pb ] && mv proto/resources.pb base/
for d in res lib assets; do [ -e "proto/$d" ] && mv "proto/$d" base/; done
for f in proto/*; do [ -e "$f" ] && [ "$(basename "$f")" != "META-INF" ] && mv "$f" base/root/; done
(cd base && zip -0 -qr ../base.zip .)
echo "== 4. bundletool build-bundle =="
rm -f mimis-magical-world.aab mimis-magical-world-signed.aab universal.apks
java -jar "$BUNDLETOOL" build-bundle --modules=base.zip --output=mimis-magical-world.aab
echo "== 5. firmar con jarsigner (llave de subida) =="
cp mimis-magical-world.aab mimis-magical-world-signed.aab
jarsigner -keystore "$KS" -storepass:env KS_PASS -keypass:env KS_PASS mimis-magical-world-signed.aab mimi-upload
echo "== 6. verificar firma =="
jarsigner -verify mimis-magical-world-signed.aab
echo "== 7. validar con build-apks --mode=universal =="
java -jar "$BUNDLETOOL" build-apks --bundle=mimis-magical-world-signed.aab --output=universal.apks --mode=universal
rm -rf universal && mkdir universal && (cd universal && unzip -o -q ../universal.apks universal.apk)
aapt2 dump badging universal/universal.apk | head -3 || true
echo "== 8. comprobar assets clave en el APK universal =="
unzip -l universal/universal.apk | grep -E "mimi-blender.glb|teddy-blender.glb|AndroidManifest" || true
ls -la mimis-magical-world-signed.aab
