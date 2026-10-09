import 'package:flutter/services.dart';

/// Parte nativa (MainActivity.kt): sfondo, launcher installati, icone.
class Tema {
  static const _c = MethodChannel('rcm/tema');

  /// dove: "home", "blocco" o "entrambe".
  static Future<void> sfondo(String asset, String dove) =>
      _c.invokeMethod('sfondo', {'asset': asset, 'dove': dove});

  /// Lo sfondo appena impostato, se l'app e' stata ricreata nel frattempo.
  static Future<String?> esito() => _c.invokeMethod<String>('esito');

  static Future<({String? predefinito, List<String> installati})> launcher() async {
    final r = Map<String, dynamic>.from(await _c.invokeMethod('launcher'));
    return (predefinito: r['predefinito'] as String?, installati: List<String>.from(r['installati']));
  }

  /// true se il launcher ha applicato le icone da solo.
  static Future<bool> applica(String pacchetto) async =>
      await _c.invokeMethod<bool>('applica', {'pacchetto': pacchetto}) ?? false;

  /// Impostazioni › App Home: scegliere (o lasciare) la Home RCM.
  static Future<void> sceltaHome() => _c.invokeMethod('sceltaHome');

  /// Il pacchetto di icone per Theme Park costruito qui (Pacchetto.kt).
  static Future<Map> pacchettoStato() async => Map.from(await _c.invokeMethod('pacchettoStato'));
  static Future<void> pacchettoPermesso() => _c.invokeMethod('pacchettoPermesso');
  static Future<Map> pacchettoCrea() async => Map.from(await _c.invokeMethod('pacchettoCrea'));

  /// Avanzamento ed esito dell'installazione del pacchetto.
  static void ascolta(Future<dynamic> Function(MethodCall) h) => _c.setMethodCallHandler(h);

  static Future<bool> apri(String url) async => await _c.invokeMethod<bool>('apri', {'url': url}) ?? false;
}

/// Gli asset di una cartella, in ordine di nome.
Future<List<String>> assetIn(String cartella) async {
  final m = await AssetManifest.loadFromAssetBundle(rootBundle);
  return m.listAssets().where((a) => a.startsWith(cartella)).toList()..sort();
}
