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
          if (samsung)
            _Scheda(
              titolo: 'Telefono Samsung',
              icona: Icons.phone_android,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Il launcher Samsung accetta le icone tramite Theme Park, un\'app gratuita di Samsung:',
                    style: Stile.testo(15)),
                const SizedBox(height: 10),
                for (final (n, t) in [
                  (1, 'Installa Good Lock dal Galaxy Store e, da Good Lock, il modulo Theme Park.'),
                  (2, 'In Theme Park apri la scheda Icone e tocca Crea nuovo.'),
                  (3, 'Scegli Tema RCM tra i pacchetti di icone installati.'),
                  (4, 'Salva e tocca Applica.'),
                ])
                  _Passo(n, t),
                const SizedBox(height: 12),
                Pulsante('Apri il Galaxy Store', pieno: false, icona: Icons.open_in_new,
                    onPressed: () => Tema.apri('samsungapps://ProductDetail/com.samsung.android.goodlock')),
              ]),
            ),
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
  const _Passo(this.n, this.testo);
  final int n;
  final String testo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 24, height: 24, alignment: Alignment.center,
          decoration: const BoxDecoration(color: Stile.rosso, shape: BoxShape.circle),
          child: Text('$n', style: Stile.testo(13, colore: Stile.oro, peso: 600)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(testo, style: Stile.testo(15))),
      ]),
    );
  }
}
