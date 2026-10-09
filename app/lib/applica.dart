import 'package:flutter/material.dart';

import 'stile.dart';
import 'tema.dart';

const _nomi = {
  'com.teslacoilsw.launcher': 'Nova Launcher',
  'app.lawnchair': 'Lawnchair',
  'app.lawnchair.play': 'Lawnchair',
  'ginlemon.flowerfree': 'Smart Launcher',
  'ginlemon.flowerpro': 'Smart Launcher',
  'com.actionlauncher.playstore': 'Action Launcher',
};

/// Dove si trova l'opzione delle icone, per i launcher che non accettano
/// il comando diretto.
const _dove = {
  'app.lawnchair': 'Impostazioni di Lawnchair › Generali › Pacchetto icone › Tema RCM',
  'app.lawnchair.play': 'Impostazioni di Lawnchair › Generali › Pacchetto icone › Tema RCM',
};

class PaginaApplica extends StatefulWidget {
  const PaginaApplica({super.key});

  @override
  State<PaginaApplica> createState() => _PaginaApplicaState();
}

class _PaginaApplicaState extends State<PaginaApplica> with WidgetsBindingObserver {
  Future<({String? predefinito, List<String> installati})> stato = Tema.launcher();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // si torna dal Play Store o dal launcher: ricontrolla cosa c'e'
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) setState(() => stato = Tema.launcher());
  }

  Future<void> applica(String p) async {
    final m = ScaffoldMessenger.of(context);
    final ok = await Tema.applica(p);
    if (!ok) {
      m.showSnackBar(SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(_dove[p] ?? 'Nelle impostazioni del launcher cerca «Pacchetto icone» e scegli Tema RCM.')));
    }
  }

  /// La Home RCM (HomeActivity.kt): un launcher nostro, le icone del Club su
  /// tutte le app senza Theme Park ne' launcher da installare.
  Widget _homeRcm(bool attiva) => _Scheda(
        titolo: 'La Home del Club',
        icona: Icons.home,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              attiva
                  ? 'La Home RCM è la tua Home: tutte le app hanno le icone del Club. '
                      'Per tornare alla Home di prima scegli un\'altra app Home.'
                  : 'Il modo più semplice: usa la Home del Club al posto di quella del telefono. Tutte le app '
                      'prendono le icone del Club, su qualunque telefono, senza installare altro.',
              style: Stile.testo(15)),
          const SizedBox(height: 8),
          Text('Ci sono orologio, app preferite, dock e cassetto con la ricerca; tieni premuta un\'app per '
              'aggiungerla alla Home o al dock. Non ci sono i widget né i pallini delle notifiche. '
              'Si torna indietro quando vuoi da Impostazioni › App › App predefinite › App Home.',
              style: Stile.sotto(13)),
          const SizedBox(height: 12),
          Pulsante(attiva ? 'Cambia app Home' : 'Usa la Home RCM',
              pieno: !attiva, icona: Icons.home_outlined, onPressed: Tema.sceltaHome),
        ]),
      );

  /// Samsung: le icone passano da Theme Park (Good Lock). L'app guarda cosa
  /// c'e' gia' e il pulsante porta al passo successivo; i passi sono quelli
  /// provati su un Galaxy S25 con One UI 9 (09/10/2026), Theme Park e' in inglese.
  Widget _samsung(List<String> installati) {
    const goodLock = 'com.samsung.android.goodlock', themePark = 'com.samsung.android.themedesigner';
    final haGoodLock = installati.contains(goodLock), haThemePark = installati.contains(themePark);
    final (testo, icona, azione) = haThemePark
        ? ('Apri Theme Park', Icons.open_in_new, () => Tema.applica(themePark))
        : haGoodLock
            ? ('Installa Theme Park', Icons.shop, () => Tema.apri('samsungapps://ProductDetail/$themePark'))
            : ('Installa Good Lock', Icons.shop, () => Tema.apri('samsungapps://ProductDetail/$goodLock'));
    return _Scheda(
      titolo: 'Telefono Samsung',
      icona: Icons.phone_android,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Il launcher Samsung accetta le icone tramite Theme Park, un\'app gratuita di Samsung. '
            'Il pulsante qui sotto ti porta al passo che manca.', style: Stile.testo(15)),
        const SizedBox(height: 10),
        _Passo(1, 'Installa Good Lock dal Galaxy Store, aprilo e accetta i termini.', fatto: haGoodLock),
        _Passo(2, 'Installa Theme Park (da Good Lock o dal Galaxy Store).', fatto: haThemePark),
        const _Passo(3, 'In Theme Park tocca Icon in basso, poi Create new.'),
        const _Passo(4, 'Nell\'editor tocca Icon in basso, poi Iconpack, e scegli Tema RCM.'),
        const _Passo(5, 'Tocca il pulsante di salvataggio in alto a destra e dai un nome senza spazi, per esempio TemaRCM.'),
        const _Passo(6, 'Tocca il tema salvato e poi Apply.'),
        const SizedBox(height: 6),
        Text('Con Theme Park le app senza un\'icona del Club restano come sono: la cornice giallorossa '
            'la mettono solo i launcher come Nova.', style: Stile.sotto(13)),
        const SizedBox(height: 12),
        Pulsante(testo, icona: icona, onPressed: azione),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: stato,
      builder: (context, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator(color: Stile.oro));
        final installati = s.data!.installati;
        final launcher = installati.where(_nomi.containsKey).toList();
        final samsung = (s.data!.predefinito ?? '').startsWith('com.sec.android') ||
            installati.contains('com.samsung.android.themedesigner');
        return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 28), children: [
          _Scheda(
            titolo: 'Lo sfondo',
            icona: Icons.wallpaper,
            child: Text('Dalla scheda Sfondi: tocca quello che ti piace e scegli Home, Blocco o Entrambe. '
                'Su Android 12 e successivi anche menu e pulsanti prendono i colori giallorossi.',
                style: Stile.testo(15)),
          ),
          _homeRcm(s.data!.predefinito == 'it.romaclubmatera.tema'),
          for (final p in launcher)
            _Scheda(
              titolo: _nomi[p]!,
              icona: Icons.apps,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Le icone del Club si applicano con un tocco.', style: Stile.testo(15)),
                const SizedBox(height: 14),
                Pulsante('Applica le icone', icona: Icons.check, onPressed: () => applica(p)),
              ]),
            ),
          if (samsung) _samsung(installati),
          if (launcher.isEmpty)
            _Scheda(
              titolo: 'Un launcher per le icone',
              icona: Icons.download,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                    samsung
                        ? 'In alternativa a Theme Park puoi usare un launcher gratuito che accetta le icone in un tocco:'
                        : 'Il launcher del tuo telefono non cambia le icone da solo. Installa un launcher gratuito '
                            'che le accetta, poi torna qui e tocca Applica:',
                    style: Stile.testo(15)),
                const SizedBox(height: 14),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  Pulsante('Nova Launcher', icona: Icons.shop,
                      onPressed: () => Tema.apri('market://details?id=com.teslacoilsw.launcher')),
                  Pulsante('Lawnchair', pieno: false, icona: Icons.shop,
                      onPressed: () => Tema.apri('market://details?id=app.lawnchair.play')),
                ]),
              ]),
            ),
          const SizedBox(height: 10),
          Center(child: Text('Roma Club Matera «Francesco Totti» · dal 2012', style: Stile.sotto(12))),
        ]);
      },
    );
  }
}

class _Scheda extends StatelessWidget {
  const _Scheda({required this.titolo, required this.icona, required this.child});
  final String titolo;
  final IconData icona;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: Stile.scheda(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icona, color: Stile.oro, size: 22),
          const SizedBox(width: 10),
          Text(titolo.toUpperCase(), style: Stile.titolo(15.5)),
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class _Passo extends StatelessWidget {
  const _Passo(this.n, this.testo, {this.fatto = false});
  final int n;
  final String testo;
  final bool fatto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 24, height: 24, alignment: Alignment.center,
          decoration: BoxDecoration(color: fatto ? Stile.oro : Stile.rosso, shape: BoxShape.circle),
          child: fatto
              ? const Icon(Icons.check, size: 16, color: Stile.fondo)
              : Text('$n', style: Stile.testo(13, colore: Stile.oro, peso: 600)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(testo, style: Stile.testo(15, colore: fatto ? Stile.panna.withValues(alpha: .55) : Stile.panna))),
      ]),
    );
  }
}
