import 'package:flutter/material.dart';

import 'stile.dart';
import 'tema.dart';

String messaggioSfondo(String dove) {
  const testi = {'home': 'sulla schermata Home', 'blocco': 'sulla schermata di blocco', 'entrambe': 'su Home e blocco'};
  return 'Sfondo impostato ${testi[dove]}. Forza Roma!';
}

/// "07-olimpico-notte" -> "Olimpico notte"; i nomi speciali sono qui.
String nomeSfondo(String asset) {
  const speciali = {
    'capitano': 'Il Capitano', 'totti-10': 'Totti 10', 'de-rossi-16': 'De Rossi 16', 'totti-e-de-rossi': 'Totti e De Rossi', 'mmxii': 'MMXII',
    'da-matera-a-roma': 'Da Matera a Roma', 'forza-grande-roma': 'Forza grande Roma',
    'olimpico-notte': "L'Olimpico", 'la-curva-fumogeni': 'La Curva',
    'dybala-21': 'Dybala 21', 'malen-14-curva': 'Malen 14', 'svilar-99': 'Svilar 99',
    'mancini-23': 'Mancini 23', 'mancini-23-derby': 'Mancini 23 derby', 'portiere-tuffo': 'Il tuffo',
    'sassi-di-notte': 'Sassi di notte',
  };
  final base = asset.split('/').last.split('.').first.replaceFirst(RegExp(r'^\d+-'), '');
  if (speciali.containsKey(base)) return speciali[base]!;
  final s = base.replaceAll('-', ' ');
  return s[0].toUpperCase() + s.substring(1);
}

class PaginaSfondi extends StatelessWidget {
  const PaginaSfondi({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: assetIn('assets/sfondi/'),
      builder: (context, s) {
        final sfondi = s.data ?? const [];
        return CustomScrollView(slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
            sliver: SliverToBoxAdapter(
              child: Text('${sfondi.length} sfondi in alta risoluzione. Toccane uno per vederlo e impostarlo.',
                  style: Stile.testo(15, colore: Stile.panna.withValues(alpha: .8))),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid.builder(
              itemCount: sfondi.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, mainAxisSpacing: 16, crossAxisSpacing: 14, childAspectRatio: .42),
              itemBuilder: (context, i) => _Miniatura(sfondi: sfondi, i: i),
            ),
          ),
        ]);
      },
    );
  }
}

class _Miniatura extends StatelessWidget {
  const _Miniatura({required this.sfondi, required this.i});
  final List<String> sfondi;
  final int i;

  @override
  Widget build(BuildContext context) {
    final a = sfondi[i];
    return GestureDetector(
      onTap: () => Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (_, _, _) => Anteprima(sfondi: sfondi, iniziale: i),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      )),
      child: Column(children: [
        Expanded(
          child: Hero(
            tag: a,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Stile.oro.withValues(alpha: .45), width: .8),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 6))],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(a, fit: BoxFit.cover, width: double.infinity, cacheWidth: 420),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(nomeSfondo(a), style: Stile.testo(14.5, peso: 500), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

/// Lo sfondo a tutto schermo, si scorre di lato; in alto nome e numero, sotto i tre pulsanti.
class Anteprima extends StatefulWidget {
  const Anteprima({super.key, required this.sfondi, required this.iniziale});
  final List<String> sfondi;
  final int iniziale;

  @override
  State<Anteprima> createState() => _AnteprimaState();
}

class _AnteprimaState extends State<Anteprima> {
  late final pc = PageController(initialPage: widget.iniziale);
  late int i = widget.iniziale;
  bool lavoro = false;

  Future<void> imposta(String dove) async {
    setState(() => lavoro = true);
    final m = ScaffoldMessenger.of(context);
    try {
      await Tema.sfondo(widget.sfondi[i], dove);
      await Tema.esito(); // gia' mostrato qui
      m.showSnackBar(SnackBar(content: Text(messaggioSfondo(dove))));
    } catch (e) {
      m.showSnackBar(const SnackBar(content: Text('Il telefono non ha accettato lo sfondo. Riprova.')));
    } finally {
      if (mounted) setState(() => lavoro = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        PageView.builder(
          controller: pc,
          itemCount: widget.sfondi.length,
          onPageChanged: (n) => setState(() => i = n),
          itemBuilder: (_, n) => Hero(tag: widget.sfondi[n], child: Image.asset(widget.sfondi[n], fit: BoxFit.cover)),
        ),
        // in basso solo i pulsanti, su una riga: stemma e scritte dello sfondo
        // stanno sopra (zone libere di genera.py) e restano scoperti
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(14, 36, 14, 16 + MediaQuery.paddingOf(context).bottom),
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)]),
            ),
            child: lavoro
                ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Stile.oro)))
                : Row(children: [
                    for (final (k, b) in [
                      Pulsante('Home', pieno: false, icona: Icons.home_outlined, onPressed: () => imposta('home')),
                      Pulsante('Blocco', pieno: false, icona: Icons.lock_outline, onPressed: () => imposta('blocco')),
                      Pulsante('Entrambe', icona: Icons.check, onPressed: () => imposta('entrambe')),
                    ].indexed) ...[
                      if (k > 0) const SizedBox(width: 8),
                      Expanded(child: FittedBox(fit: BoxFit.scaleDown, child: b)),
                    ],
                  ]),
          ),
        ),
        // in alto, dove sul telefono c'e' l'orologio: indietro, nome e numero
        Positioned(
          left: 0, right: 0, top: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(8, MediaQuery.paddingOf(context).top + 8, 18, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0xB3000000), Colors.transparent]),
            ),
            child: Row(children: [
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.black45, foregroundColor: Stile.panna),
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(nomeSfondo(widget.sfondi[i]).toUpperCase(), style: Stile.titolo(18), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${i + 1} di ${widget.sfondi.length}', style: Stile.sotto(12.5)),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
