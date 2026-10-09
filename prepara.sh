#!/bin/sh
# Rigenera tutto quello che l'app prende da sfondi/ e icone/:
# icone del tema, icona dell'app, sfondi (WebP) e caratteri.
# Uso: ORIGINALI=<cartella delle illustrazioni> ./prepara.sh
# (serve rsvg-convert, cwebp e i caratteri Oswald/Cinzel; senza ORIGINALI
# mancano gli sfondi fatti dalle illustrazioni, vedi FOTO in sfondi/genera.py)
set -e
QUI=$(cd "$(dirname "$0")" && pwd)
RES=$QUI/app/android/app/src/main/res
ASSETS=$QUI/app/assets
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# icone del tema
rm -f "$RES"/drawable-nodpi/rcm_*.png
(cd "$QUI/icone" && ./genera.py "$RES")
mkdir -p "$ASSETS/icone"
rm -f "$ASSETS"/icone/*.png
cp "$RES"/drawable-nodpi/rcm_*.png "$ASSETS/icone/"
rm "$ASSETS/icone/rcm_cornice.png" "$ASSETS"/icone/rcm_l_*.png  # nella scheda Icone solo le icone del Club

# icona dell'app: stemma su rosso (adattiva) e versione tonda per i vecchi launcher
rsvg-convert -w 230 "$QUI/sfondi/stemma.svg" -o "$TMP/s.png"
convert -size 432x432 xc:none "$TMP/s.png" -gravity center -geometry +0+4 -composite "$RES/drawable-nodpi/ic_primo_piano.png"
for d in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  mkdir -p "$RES/mipmap-${d%%:*}"
  convert "$RES/drawable-nodpi/rcm_stemma.png" -resize "${d#*:}x${d#*:}" "$RES/mipmap-${d%%:*}/ic_launcher.png"
done
mkdir -p "$RES/mipmap-anydpi-v26" "$RES/values"
cat > "$RES/mipmap-anydpi-v26/ic_launcher.xml" <<X
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/rosso_club"/>
    <foreground android:drawable="@drawable/ic_primo_piano"/>
</adaptive-icon>
X
cat > "$RES/values/colori.xml" <<X
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="rosso_club">#7D1A28</color>
</resources>
X

# sfondi: 1440x3200 in WebP, piu' leggeri dei PNG
python3 "$QUI/sfondi/genera.py" "$TMP/sfondi" >/dev/null
mkdir -p "$ASSETS/sfondi"
rm -f "$ASSETS"/sfondi/*.webp
for f in "$TMP"/sfondi/*.png; do
  n=$(basename "$f" .png | sed 's/^sfondo-roma-club-matera-//')
  cwebp -quiet -q 90 "$f" -o "$ASSETS/sfondi/$n.webp"
done

# caratteri (OFL): Cinzel per i titoli, Oswald per il resto
mkdir -p "$ASSETS/caratteri"
cp "$HOME/.local/share/fonts/rcm-ofl/Oswald[wght].ttf" "$ASSETS/caratteri/Oswald.ttf"
cp "$HOME/.local/share/fonts/rcm-ofl/Cinzel[wght].ttf" "$ASSETS/caratteri/Cinzel.ttf"
cp "$HOME/.local/share/fonts/rcm-ofl/OFL-oswald.txt" "$HOME/.local/share/fonts/rcm-ofl/OFL-cinzel.txt" "$ASSETS/caratteri/"
rsvg-convert -w 360 "$QUI/sfondi/stemma.svg" -o "$ASSETS/stemma.png"
echo "pronto: $(ls "$ASSETS/sfondi" | wc -l) sfondi, $(ls "$ASSETS/icone" | wc -l) icone, $(du -sh "$ASSETS" | cut -f1)"
