#!/usr/bin/env bash
# 安卓 APK 构建脚本：WebView 壳 + 内嵌游戏（assets/index.html 已内联 PeerJS）
# 依赖：JDK 17+（javac/keytool/java）、Android SDK build-tools(含 aapt2/zipalign/apksigner) 与 platforms/android-36
# 用法：bash android/build.sh
set -euo pipefail

SDK="${ANDROID_HOME:-$LOCALAPPDATA/Android/Sdk}"
BT="$SDK/build-tools/36.0.0"
PLATFORM="$SDK/platforms/android-36/android.jar"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/dist"
WORK="$(mktemp -d)"

JAVA_BIN="${JAVA_BIN:-java}"
JAVAC_BIN="${JAVAC_BIN:-javac}"
KEYTOOL_BIN="${KEYTOOL_BIN:-keytool}"
KEYSTORE="$HERE/debug.keystore"

# 1) 编译 Activity → dex
mkdir -p "$WORK/classes"
"$JAVAC_BIN" -source 8 -target 8 -cp "$PLATFORM" -d "$WORK/classes" "$HERE/java/com/koipoppy/ttt/MainActivity.java"
"$JAVA_BIN" -cp "$BT/lib/d8.jar" com.android.tools.r8.D8 --release --lib "$PLATFORM" --min-api 21 --output "$WORK" $(find "$WORK/classes" -name '*.class')

# 2) 资源与清单 → 基础 APK（含 assets）
mkdir -p "$OUT"
"$BT/aapt2" compile --dir "$HERE/res" -o "$WORK/res.zip"
"$BT/aapt2" link -o "$WORK/base.apk" -I "$PLATFORM" \
  --manifest "$HERE/AndroidManifest.xml" -A "$HERE/assets" \
  --min-sdk-version 21 --target-sdk-version 29 --auto-add-overlay \
  "$WORK/res.zip"

# 3) 注入 classes.dex
python - "$WORK/base.apk" "$WORK/classes.dex" <<'PYEOF'
import sys, zipfile, os
apk, dex = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(apk, 'a') as z:
    z.write(dex, 'classes.dex', compress_type=zipfile.ZIP_DEFLATED)
    names = z.namelist()
assert 'classes.dex' in names, 'dex injection failed'
print('classes.dex injected,', len(names), 'entries')
PYEOF

# 4) 对齐 + 签名（debug.keystore 不存在则生成）
if [ ! -f "$KEYSTORE" ]; then
  "$KEYTOOL_BIN" -genkeypair -keystore "$KEYSTORE" -alias ttt \
    -storepass ttt123456 -keypass ttt123456 -keyalg RSA -keysize 2048 \
    -validity 10950 -dname "CN=Double TTT, O=Koipoppy, C=CN"
fi
"$BT/zipalign" -f 4 "$WORK/base.apk" "$WORK/aligned.apk"
"$JAVA_BIN" -jar "$BT/lib/apksigner.jar" sign \
  --ks "$KEYSTORE" --ks-pass pass:ttt123456 --key-pass pass:ttt123456 \
  --v4-signing-enabled false \
  --out "$OUT/双层井字棋-v1.0.apk" "$WORK/aligned.apk"

echo "APK 已生成: $OUT/双层井字棋-v1.0.apk"
