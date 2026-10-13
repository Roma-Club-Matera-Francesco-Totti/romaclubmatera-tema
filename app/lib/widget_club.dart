import 'package:flutter/material.dart';

import 'stile.dart';
import 'tema.dart';

/// I widget del Club: si mettono sulla Home che si usa gia', senza cambiare
/// niente del telefono. Le anteprime qui ricalcano i layout Android
/// (res/layout/widget_*.xml).
class PaginaWidget extends StatelessWidget {
  const PaginaWidget({super.key});

  Future<void> aggiungi(BuildContext context, String quale) async {
    final m = ScaffoldMessenger.of(context);
    final ok = await Tema.aggiungiWidget(quale);
    m.showSnackBar(SnackBar(
      duration: Duration(seconds: ok ? 4 : 9),
      content: Text(ok
          ? 'Conferma sul telefono e il widget compare sulla Home.'
          : 'Tieni premuto su uno spazio vuoto della Home, tocca Widget e cerca Tema RCM.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 28), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
        child: Text('Due widget da mettere sulla tua Home, come quello del meteo. Il telefono resta com\'è.',
            style: Stile.testo(15, colore: Stile.panna.withValues(alpha: .8))),
      ),
      _Voce(
        titolo: 'Prossima partita',
        testo: 'Avversario, giorno, ora, canale TV e quanto manca. Si aggiorna da solo dal calendario del sito. '
            'Toccalo per aprire la pagina della partita.',
        anteprima: const _Anteprima(
          righe: ['FRA 4 GIORNI · SERIE A, 7ª GIORNATA', 'ROMA – GENOA', 'Sabato 17 ottobre · 20:45 · DAZN'],
        ),
        onPressed: () => aggiungi(context, 'partita'),
      ),
      _Voce(
        titolo: 'Orologio giallorosso',
        testo: 'Ora e data accanto allo stemma del Club. Toccalo per aprire la sveglia.',
        anteprima: const _Anteprima(orologio: true),
        onPressed: () => aggiungi(context, 'orologio'),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
        child: Text('Per togliere un widget dalla Home, tienilo premuto e scegli Rimuovi.', style: Stile.sotto(13)),
      ),
    ]);
  }
}

class _Voce extends StatelessWidget {
  const _Voce({required this.titolo, required this.testo, required this.anteprima, required this.onPressed});
  final String titolo, testo;
  final Widget anteprima;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: Stile.scheda(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titolo.toUpperCase(), style: Stile.titolo(15.5)),
        const SizedBox(height: 14),
        anteprima,
        const SizedBox(height: 14),
        Text(testo, style: Stile.testo(15)),
        const SizedBox(height: 14),
        Pulsante('Aggiungi alla Home', icona: Icons.add_to_home_screen, onPressed: onPressed),
      ]),
    );
  }
}

/// Il widget come appare sulla Home.
class _Anteprima extends StatelessWidget {
  const _Anteprima({this.righe = const [], this.orologio = false});
  final List<String> righe;
  final bool orologio;

  static const _cond = TextStyle(fontFamily: 'Oswald', height: 1.25);

  @override
  Widget build(BuildContext context) {
    final adesso = DateTime.now();
    const giorni = ['lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato', 'domenica'];
    const mesi = ['gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', 'luglio', 'agosto', 'settembre',
        'ottobre', 'novembre', 'dicembre'];
    final testo = orologio
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('${adesso.hour.toString().padLeft(2, '0')}:${adesso.minute.toString().padLeft(2, '0')}',
                style: _cond.copyWith(fontSize: 42, color: Stile.panna, height: 1, fontVariations: const [FontVariation('wght', 700)])),
            Text('${giorni[adesso.weekday - 1]} ${adesso.day} ${mesi[adesso.month - 1]}'.toUpperCase(),
                style: _cond.copyWith(fontSize: 12, color: Stile.oro, letterSpacing: .8)),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(righe[0], style: _cond.copyWith(fontSize: 11, color: Stile.oro, letterSpacing: .9)),
            Text(righe[1], style: _cond.copyWith(fontSize: 19, color: Stile.panna, fontVariations: const [FontVariation('wght', 700)])),
            Text(righe[2], style: _cond.copyWith(fontSize: 13, color: Stile.panna.withValues(alpha: .85))),
          ]);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Stile.oro.withValues(alpha: .55), width: 1),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xF21B0508), Color(0xF24A0E18)]),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Row(children: [
        Image.asset('assets/stemma.png', height: orologio ? 54 : 60),
        const SizedBox(width: 14),
        Expanded(child: testo),
      ]),
    );
  }
}
