import 'package:flutter/material.dart';

import 'stile.dart';
import 'tema.dart';

class PaginaIcone extends StatelessWidget {
  const PaginaIcone({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: assetIn('assets/icone/'),
      builder: (context, s) {
        final icone = s.data ?? const [];
        return CustomScrollView(slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
            sliver: SliverToBoxAdapter(
              child: Text(
                  '${icone.length} icone oro su rosso per le app più usate: telefono, messaggi, fotocamera, '
                  'WhatsApp, banca e tante altre. Tutte le altre app prendono la cornice giallorossa, '
                  'così la schermata resta uniforme.',
                  style: Stile.testo(15, colore: Stile.panna.withValues(alpha: .8))),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            sliver: SliverGrid.builder(
              itemCount: icone.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, mainAxisSpacing: 18, crossAxisSpacing: 18),
              itemBuilder: (_, i) => Image.asset(icone[i], filterQuality: FilterQuality.medium),
            ),
          ),
        ]);
      },
    );
  }
}
