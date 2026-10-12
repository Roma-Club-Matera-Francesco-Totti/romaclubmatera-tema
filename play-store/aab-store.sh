#!/bin/sh
# AAB per il Play Store: lo stesso progetto dell'APK del sito, ma senza gli
# sfondi elencati in esclusi-store.txt (giocatori veri: le norme di Google
# sull'immagine delle persone). L'APK del sito resta completo.
# Uso: play-store/aab-store.sh  ->  app/build/app/outputs/bundle/release/
set -e
QUI=$(cd "$(dirname "$0")/.." && pwd)
SFONDI=$QUI/app/assets/sfondi
FUORI=$(mktemp -d)

# gli sfondi tornano al loro posto anche se la compilazione fallisce
rimetti() {
  for f in "$FUORI"/*; do
    [ -e "$f" ] && mv "$f" "$SFONDI/"
  done
  rmdir "$FUORI"
}
trap rimetti EXIT INT TERM

grep -v '^#' "$QUI/play-store/esclusi-store.txt" | while read -r nome; do
  [ -n "$nome" ] || continue
  if [ ! -e "$SFONDI/$nome" ]; then
    echo "manca $SFONDI/$nome: controlla esclusi-store.txt" >&2
    exit 1
  fi
  mv "$SFONDI/$nome" "$FUORI/"
done
echo "sfondi nello Store: $(ls "$SFONDI" | wc -l)"

cd "$QUI/app"
flutter build appbundle --release -P firma=key-play.properties
