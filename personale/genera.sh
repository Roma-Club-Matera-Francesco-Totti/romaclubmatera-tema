#!/bin/sh
# Pacchetto di icone PERSONALE (it.romaclubmatera.tema.personale): le 43 icone
# del Club piu', per ogni altra app del telefono, l'icona originale dentro la
# cornice del Club (personale/cornice.py). Serve con Samsung Theme Park, che
# non mette la cornice da solo alle app fuori dal pacchetto.
#
# Le icone originali contengono loghi di terzi e dicono quali app ha il
# telefono: restano in personale/locale/ (fuori da git) e il pacchetto non si
# pubblica. Si installa solo sul telefono da cui sono state prese.
#
# Uso: personale/genera.sh [seriale adb]
#   1. l'app Tema RCM (>= 1.3.2) deve essere installata sul telefono
#   2. esporta le icone (extra esporta_icone), le copia qui e le cancella
#   3. costruisce, firma con la chiave del Club e installa il pacchetto
set -e
QUI=$(cd "$(dirname "$0")" && pwd)
APP=$QUI/../app
RES_PUB=$APP/android/app/src/main/res
SDK=${ANDROID_SDK_ROOT:-$HOME/sdk/android}
BT=$(ls -d "$SDK"/build-tools/* | sort -V | tail -1)
JAR=$(ls -d "$SDK"/platforms/android-* | sort -V | tail -1)/android.jar
ADB="$SDK/platform-tools/adb ${1:+-s $1}"
LOC=$QUI/locale
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# 1. icone originali dal telefono
D=/sdcard/Android/data/it.romaclubmatera.tema/files/icone
$ADB shell rm -rf $D
$ADB shell am start -S -n it.romaclubmatera.tema/.MainActivity --ez esporta_icone true >/dev/null  # -S: riparte da zero
i=0; until $ADB shell ls $D/FATTO >/dev/null 2>&1; do i=$((i+1)); [ $i -gt 60 ] && { echo "esportazione non riuscita"; exit 1; }; sleep 2; done
rm -rf "$LOC/icone"; mkdir -p "$LOC"
$ADB pull $D "$LOC/" >/dev/null
$ADB shell rm -rf $D
rm -f "$LOC/icone/FATTO"

# 2. risorse: icone del Club + cornici per le app non coperte, appfilter
R=$TMP/res
mkdir -p "$R/drawable-nodpi" "$R/xml" "$R/values" "$R/mipmap-xxxhdpi"
cp "$RES_PUB"/drawable-nodpi/rcm_*.png "$R/drawable-nodpi/"
cp "$RES_PUB"/mipmap-xxxhdpi/ic_launcher.png "$R/mipmap-xxxhdpi/"
python3 - "$RES_PUB/xml/appfilter.xml" "$LOC/icone" "$R" "$QUI" <<'EOF'
import hashlib, os, re, sys
sys.path.insert(0, sys.argv[4])
from PIL import Image
from cornice import cornice
af, src, R = open(sys.argv[1]).read(), sys.argv[2], sys.argv[3]
noti = set()
for c in re.findall(r'component="ComponentInfo\{([^}]+)\}"', af):
    p, a = c.split('/', 1)
    noti.add(f'{p}/{p + a if a.startswith(".") else a}')
voci, nomi = [], []
for f in sorted(os.listdir(src)):
    p, a = f[:-4].split('__', 1)
    if f'{p}/{a}' in noti:
        continue
    n = 'p_' + re.sub(r'[^a-z0-9]', '_', p.lower())[-40:] + '_' + hashlib.sha1(a.encode()).hexdigest()[:6]
    cornice(Image.open(os.path.join(src, f))).save(os.path.join(R, 'drawable-nodpi', n + '.png'))
    voci.append(f'  <item component="ComponentInfo{{{p}/{a}}}" drawable="{n}"/>')
    nomi.append(n)
open(os.path.join(R, 'xml', 'appfilter.xml'), 'w').write(af.replace('</resources>', '\n'.join(voci) + '\n</resources>'))
d = open(os.path.join(os.path.dirname(sys.argv[1]), 'drawable.xml')).read()
open(os.path.join(R, 'xml', 'drawable.xml'), 'w').write(
    d.replace('</resources>', '  <category title="Le mie app"/>\n' + ''.join(f'  <item drawable="{n}"/>\n' for n in nomi) + '</resources>'))
print(f'{len(voci)} app nella cornice')
EOF
cat > "$R/values/strings.xml" <<X
<?xml version="1.0" encoding="utf-8"?>
<resources><string name="nome">Tema RCM personale</string></resources>
X

# 3. manifest: solo risorse, nessun codice; l'attivita' e' quella di sistema,
# serve solo perche' launcher e Theme Park riconoscano il pacchetto
VER=$(date +%y%m%d%H)
cat > "$TMP/AndroidManifest.xml" <<X
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="it.romaclubmatera.tema.personale" android:versionCode="$VER" android:versionName="personale-$VER">
    <uses-sdk android:minSdkVersion="26" android:targetSdkVersion="36"/>
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

# 4. costruzione e firma (password lette da key.properties, mai stampate)
"$BT/aapt2" compile --dir "$R" -o "$TMP/res.zip"
"$BT/aapt2" link -I "$JAR" --manifest "$TMP/AndroidManifest.xml" -o "$TMP/non-firmato.apk" "$TMP/res.zip"
"$BT/zipalign" -f 4 "$TMP/non-firmato.apk" "$TMP/allineato.apk"
eval "$(python3 - "$APP/android/key.properties" <<'EOF'
import shlex, sys
k = dict(l.strip().split('=', 1) for l in open(sys.argv[1]) if '=' in l)
for a, b in (('KS', 'storeFile'), ('KS_PASS', 'storePassword'), ('KS_ALIAS', 'keyAlias'), ('KEY_PASS', 'keyPassword')):
    print(f'export {a}={shlex.quote(k[b])}')
EOF
)"
case "$KS" in /*) ;; *) KS=$APP/android/app/$KS ;; esac
"$BT/apksigner" sign --ks "$KS" --ks-pass env:KS_PASS --ks-key-alias "$KS_ALIAS" --key-pass env:KEY_PASS \
  --out "$LOC/tema-rcm-personale.apk" "$TMP/allineato.apk"
unset KS_PASS KEY_PASS
$ADB install -r --user 0 "$LOC/tema-rcm-personale.apk"
echo "installato: $LOC/tema-rcm-personale.apk"
