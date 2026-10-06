import 'package:flutter/material.dart';

/// Colori e caratteri del Club: fondo quasi nero, oro, rosso porpora.
class Stile {
  static const fondo = Color(0xFF0E0306);
  static const superficie = Color(0xFF1B0508);
  static const rosso = Color(0xFF8E1F2F);
  static const oro = Color(0xFFE3AD1E);
  static const panna = Color(0xFFF6ECD0);

  static TextStyle titolo(double size, {Color colore = oro}) => TextStyle(
      fontFamily: 'Cinzel', fontSize: size, color: colore, letterSpacing: size * .12,
      fontVariations: const [FontVariation('wght', 700)]);

  static TextStyle sotto(double size, {Color colore = panna}) => TextStyle(
      fontFamily: 'Oswald', fontSize: size, color: colore.withValues(alpha: .75), letterSpacing: 1.6,
      fontVariations: const [FontVariation('wght', 400)]);

  static TextStyle testo(double size, {Color colore = panna, double peso = 400}) => TextStyle(
      fontFamily: 'Oswald', fontSize: size, color: colore, height: 1.35,
      fontVariations: [FontVariation('wght', peso)]);

  static ThemeData tema() {
    final schema = ColorScheme.fromSeed(seedColor: rosso, brightness: Brightness.dark)
        .copyWith(primary: oro, onPrimary: fondo, secondary: rosso, surface: fondo, onSurface: panna);
    return ThemeData(
      colorScheme: schema,
      scaffoldBackgroundColor: fondo,
      fontFamily: 'Oswald',
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: superficie,
        indicatorColor: rosso,
        iconTheme: WidgetStateProperty.resolveWith((s) =>
            IconThemeData(color: s.contains(WidgetState.selected) ? oro : panna.withValues(alpha: .7))),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: 'Oswald', letterSpacing: 1.2,
            color: s.contains(WidgetState.selected) ? oro : panna.withValues(alpha: .7))),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: superficie,
        contentTextStyle: testo(15),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: oro, width: .6)),
      ),
    );
  }

  static BoxDecoration scheda() => BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: oro.withValues(alpha: .35), width: .8),
      );
}

/// Pulsante oro pieno o solo bordato.
class Pulsante extends StatelessWidget {
  const Pulsante(this.testo, {super.key, required this.onPressed, this.pieno = true, this.icona});
  final String testo;
  final VoidCallback? onPressed;
  final bool pieno;
  final IconData? icona;

  @override
  Widget build(BuildContext context) {
    final contenuto = Row(mainAxisSize: MainAxisSize.min, children: [
      if (icona != null) ...[Icon(icona, size: 18), const SizedBox(width: 6)],
      Text(testo.toUpperCase(), style: const TextStyle(fontFamily: 'Oswald', letterSpacing: 1.4, fontSize: 14.5,
          fontVariations: [FontVariation('wght', 600)])),
    ]);
    final forma = RoundedRectangleBorder(borderRadius: BorderRadius.circular(30));
    const pad = EdgeInsets.symmetric(horizontal: 14, vertical: 13);
    return pieno
        ? FilledButton(onPressed: onPressed, style: FilledButton.styleFrom(backgroundColor: Stile.oro,
            foregroundColor: Stile.fondo, shape: forma, padding: pad), child: contenuto)
        : OutlinedButton(onPressed: onPressed, style: OutlinedButton.styleFrom(foregroundColor: Stile.panna,
            side: const BorderSide(color: Stile.oro, width: 1), shape: forma, padding: pad,
            backgroundColor: Colors.black.withValues(alpha: .35)), child: contenuto);
  }
}
