# Tema del Roma Club Matera «Francesco Totti»

[romaclubmatera.it](https://romaclubmatera.it)

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
  (Nova, Smart Launcher, Action Launcher con un tocco; Lawnchair con le
  istruzioni; Samsung Theme Park guidato passo per passo).
- **Home RCM** (`HomeActivity.kt` + `lib/home.dart`): la stessa app e' anche
  un launcher. Chi la sceglie come app Home ha le icone del Club su tutte le
  app (cornice per quelle non in elenco), pagine a griglia 4x6, cartelle,
  widget delle altre app (AppWidgetHost, mostrati come viste native), dock e
  cassetto con ricerca; si sposta tutto tenendo premuto. Tenendo premuta
  un'app compaiono le sue scorciatoie; i pallini delle notifiche arrivano
  da `Notifiche.kt` se l'utente concede l'accesso alle notifiche (solo quali
  app, mai il contenuto). Le app senza icona del Club hanno la loro icona
  ritagliata nella cornice, come `personale/cornice.py`. Pubblica dalla 1.5.0; si spegne
  costruendo con `--dart-define=HOME_RCM=false -PhomeRcm=false`.

- `portfolio/genera.py` — il portfolio per la candidatura a designer di
  Galaxy Themes (Samsung): 3 temi (Giallorosso, Notte, Matera) × 6 schermate
  in un PDF A4. Da confrontare con lo Starter Kit di Samsung quando aprono
  le candidature.

## Compilare

    ORIGINALI=<cartella delle illustrazioni> ./prepara.sh
    cd app && flutter build apk --release --target-platform android-arm64

La firma è la stessa delle altre app del Club: `app/android/key.properties`
(fuori da git) dice dove sta la chiave. Senza, l'APK è firmato con la chiave
di debug e **non va distribuito**: chi lo installa non potrebbe più
aggiornarlo con quello vero.

## Licenza

Codice **Apache 2.0**, grafica **CC BY 4.0**; stemma e nome del Club esclusi.
Ogni copia o modifica deve riportare il riferimento **«romaclubmatera.it»**.
Tutti i dettagli, e i componenti di terzi, in [LICENZA.md](LICENZA.md).

Niente lupetto dell'AS Roma né volti di giocatori.
