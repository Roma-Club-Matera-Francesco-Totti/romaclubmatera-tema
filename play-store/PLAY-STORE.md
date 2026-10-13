# Tema RCM sul Play Store

Testi e immagini della scheda stanno in `fastlane/metadata/android/it-IT/`
(formato di fastlane `supply`); le immagini si rifanno con
`python3 play-store/genera.py`.

## Dati della scheda

| Campo | Valore |
|---|---|
| Nome dell'app | Tema RCM – Roma Club Matera (`title.txt`) |
| Pacchetto | `it.romaclubmatera.tema` |
| App o gioco | App |
| Gratuita o a pagamento | Gratuita |
| Categoria | Personalizzazione |
| Tag | Sfondi, Temi, Widget |
| Email | app@romaclubmatera.it |
| Sito web | https://romaclubmatera.it/download/ |
| Informativa sulla privacy | https://romaclubmatera.it/privacy-policy/ |

## Contenuti dell'app (questionari)

- **Accesso all'app**: tutte le funzioni sono disponibili senza accesso.
- **Annunci**: no.
- **Classificazione dei contenuti** (IARC): categoria "Tutte le altre app";
  violenza, sesso, linguaggio, droghe, gioco d'azzardo: no; interazione fra
  utenti: no; condivisione della posizione: no; acquisti digitali: no.
  Risultato atteso: PEGI 3.
- **Pubblico di destinazione**: 13-15, 16-17, 18 e oltre (non i minori di
  13: con quelli scattano le norme Famiglie).
- **App di notizie**: no. **App governative**: no. **Finanziarie, salute**: no.
- **Sicurezza dei dati**:
  - raccoglie dati? **No**. Dalla 1.7.0 l'app ha il permesso INTERNET, ma
    solo il widget della prossima partita lo usa, per leggere il calendario
    pubblico da `romaclubmatera.it/wp-json/rcm/v1/prossime`: non manda
    niente dell'utente (nessun identificativo, nessun dato del telefono);
  - condivide dati? **No**;
  - crittografia in transito: **sì** (HTTPS).
- **Permessi** (versione dello Store, senza Home RCM): SET_WALLPAPER e
  INTERNET. READ_CONTACTS ed EXPAND_STATUS_BAR servono solo alla Home RCM e
  nell'AAB dello Store vengono tolti (`app/android/app/src/senzaHome/`).

## La versione dello Store è quella «leggera» (13/10/2026)

Michele: il launcher «stravolge l'uso del telefono», chi è abituato in un
modo non vuole cambiare. Sullo Store quindi: **sfondi, widget (prossima
partita, orologio) e icone come extra per chi ha un launcher che le
supporta**. La Home RCM resta solo nell'APK del sito.
`aab-store.sh` costruisce con `-P homeRcm=false --dart-define=HOME_RCM=false`.

## Prima di caricarla

1. **Sfondi con i giocatori**: 8 sfondi su 25 ritraggono giocatori veri
   col nome sulla maglia (Totti, De Rossi, Dybala, Malen, Svilar, Mancini);
   uno dei due Mancini ha anche una bandiera con l'aquila della Lazio. Sul Play Store l'uso dell'immagine di persone reali senza
   autorizzazione è motivo di rifiuto o di rimozione (norme sulla proprietà
   intellettuale e sull'impersonificazione). Da decidere: build per lo
   Store senza quegli sfondi, oppure attendere l'autorizzazione di AS Roma.
   Le immagini della scheda non ne usano nessuno.
2. **Formato**: lo Store vuole l'**AAB**, non l'APK. Si fa con
   `play-store/aab-store.sh`, che lascia fuori gli sfondi elencati in
   `play-store/esclusi-store.txt` (deciso il 12/10/2026: sullo Store la
   versione senza i giocatori, l'APK del sito resta completo).
   L'AAB e' firmato con la **chiave di caricamento** del Play Store
   (`-Pfirma=key-play.properties`, file fuori da git): la chiave di firma
   dell'app la gestisce Google, quindi quella del Club non si puo' usare.
3. **Firma**: con la firma delle app di Google Play, la chiave di
   `key.properties` diventa la chiave di caricamento. Chi ha già
   l'APK dal sito può aggiornare dallo Store solo se Google firma con la
   stessa chiave: alla prima pubblicazione scegliere "Usa la chiave di
   firma esistente" e caricare quella del Club (PEPK).
4. **Account personale**: prima della produzione, test chiuso con almeno 12
   tester per 14 giorni.

## Caricare con fastlane

La prima versione di ogni app va creata a mano nella Play Console. Dopo:

    fastlane supply --package_name it.romaclubmatera.tema \
      --json_key <chiave-del-service-account>.json \
      --metadata_path fastlane/metadata/android \
      --aab app/build/app/outputs/bundle/release/app-release.aab --track internal

La chiave JSON del service account (Play Console › Impostazioni › Accesso
API) **non va in git**.
