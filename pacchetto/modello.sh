#!/bin/sh
# Il modello del pacchetto di icone che l'app costruisce sul telefono di chi
# la usa ("Crea il pacchetto con le mie app", Pacchetto.kt): un'app di sole
# risorse con POSTI icone segnaposto (p0000..), appfilter.xml e drawable.xml
# segnaposto. Sul telefono l'app sostituisce i PNG e i due XML (stessi nomi
# di file: resources.arsc resta valido), firma e installa. Non firmato.
# Uso: pacchetto/modello.sh <apk di uscita>
set -e
QUI=$(cd "$(dirname "$0")" && pwd)
SDK=${ANDROID_SDK_ROOT:-$HOME/sdk/android}
BT=$(ls -d "$SDK"/build-tools/* | sort -V | tail -1)
JAR=$(ls -d "$SDK"/platforms/android-* | sort -V | tail -1)/android.jar
POSTI=600
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
R=$TMP/res
mkdir -p "$R/drawable-nodpi" "$R/xml" "$R/values" "$R/mipmap-xxxhdpi"
# segnaposto: un PNG trasparente 1x1
python3 - "$R/drawable-nodpi" $POSTI <<'PY'
import sys, zlib, struct
def png():
    raw = b'\x00\x00\x00\x00\x00'
    c = lambda t, d: struct.pack('>I', len(d)) + t + d + struct.pack('>I', zlib.crc32(t + d))
    return b'\x89PNG\r\n\x1a\n' + c(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 6, 0, 0, 0)) + c(b'IDAT', zlib.compress(raw)) + c(b'IEND', b'')
for i in range(int(sys.argv[2])):
    open(f'{sys.argv[1]}/p{i:04d}.png', 'wb').write(png())
PY
cp "$QUI/../app/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" "$R/mipmap-xxxhdpi/"
printf '<resources>\n  <item component="ComponentInfo{x/x}" drawable="p0000"/>\n</resources>\n' > "$R/xml/appfilter.xml"
printf '<resources>\n  <item drawable="p0000"/>\n</resources>\n' > "$R/xml/drawable.xml"
printf '<resources><string name="nome">Tema RCM · le mie app</string></resources>\n' > "$R/values/strings.xml"
cat > "$TMP/AndroidManifest.xml" <<X
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="it.romaclubmatera.tema.icone" android:versionCode="1" android:versionName="1">
    <uses-sdk android:minSdkVersion="26" android:targetSdkVersion="29"/>
    <application android:label="@string/nome" android:icon="@mipmap/ic_launcher" android:hasCode="false">
        <activity android:name="android.app.Activity" android:exported="true">
            <intent-filter>
                <action android:name="org.adw.launcher.THEMES" />
                <action android:name="com.gau.go.launcherex.theme" />
                <action android:name="com.novalauncher.THEME" />
                <action android:name="com.anddoes.launcher.THEME" />
                <action android:name="com.teslacoilsw.launcher.THEME" />
                <action android:name="ginlemon.smartlauncher.THEMES" />
                <action android:name="com.dlto.atom.launcher.THEME" />
                <action android:name="net.oneplus.launcher.icons.ACTION_PICK_ICON" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="com.fede.launcher.THEME_ICONPACK" />
                <category android:name="com.anddoes.launcher.THEME" />
                <category android:name="com.teslacoilsw.launcher.THEME" />
                <category android:name="com.novalauncher.category.CUSTOM_ICON_PICKER" />
                <category android:name="android.intent.category.DEFAULT" />
            </intent-filter>
        </activity>
    </application>
</manifest>
X
"$BT/aapt2" compile --dir "$R" -o "$TMP/res.zip"
"$BT/aapt2" link -I "$JAR" --manifest "$TMP/AndroidManifest.xml" -o "$1" "$TMP/res.zip"
echo "modello: $1 ($POSTI posti)"
