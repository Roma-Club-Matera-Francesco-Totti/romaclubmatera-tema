# Tema del Roma Club Matera «Francesco Totti»

App Android **Tema RCM** (`it.romaclubmatera.tema`) con gli sfondi e le icone
del Club, e i generatori da cui escono.

- `sfondi/genera.py` — gli sfondi 1440×3200 (stemma, sciarpa, maglie,
  scritte…). Quelli fatti da illustrazioni stanno nell'archivio del Club e
  si passano con `ORIGINALI=<cartella>` (vedi `FOTO` nello script).
- `icone/` — l'icon pack: simbolo oro su tondo rosso (Material Symbols,
  Apache 2.0). `app.py` dice quali app e con quale simbolo; per le app con
  un marchio si usa un simbolo generico, mai il logo. Le app non in elenco
  prendono la cornice giallorossa.
- `prepara.sh` — rigenera icone, icona dell'app, sfondi (WebP) e caratteri
  dentro `app/`.
- `app/` — l'app Flutter: Sfondi (Home, Blocco, Entrambe), Icone, Applica
  (Nova, Smart Launcher, Action Launcher con un tocco; Lawnchair e Samsung
  Theme Park con le istruzioni).

## Compilare

    ORIGINALI=<cartella delle illustrazioni> ./prepara.sh
    cd app && flutter build apk --release --target-platform android-arm64

La firma è la stessa delle altre app del Club: `app/android/key.properties`
(fuori da git) dice dove sta la chiave. Senza, l'APK è firmato con la chiave
di debug e **non va distribuito**: chi lo installa non potrebbe più
aggiornarlo con quello vero.

Caratteri: Cinzel e Oswald, licenza SIL OFL (testi in `app/assets/caratteri/`).
Niente marchi dell'AS Roma né volti di giocatori.
