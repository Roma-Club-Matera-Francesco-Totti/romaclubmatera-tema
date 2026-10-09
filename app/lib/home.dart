import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'stile.dart';

/// La Home del Club: un launcher (HomeActivity.kt) disegnato sopra lo sfondo
/// del telefono. Orologio, app preferite, dock e cassetto con tutte le app,
/// tutte con le icone del tema. Niente widget e niente pallini delle notifiche.
void avviaHome() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const HomeRcm());
}

class App {
  const App(this.pacchetto, this.attivita, this.nome);
  final String pacchetto, attivita, nome;
  String get chiave => '$pacchetto/$attivita';
}

/// Parte nativa: HomeActivity.kt.
class _Nativo {
  static const c = MethodChannel('rcm/home');
  static final _icone = <String, Future<Uint8List?>>{};

  static Future<List<App>> app() async {
    final l = await c.invokeListMethod<Map>('app') ?? [];
    return l.map((m) => App(m['pacchetto'], m['attivita'], m['nome'])).toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
  }

  static Future<Uint8List?> icona(App a) => _icone.putIfAbsent(
      a.chiave, () => c.invokeMethod<Uint8List>('icona', {'pacchetto': a.pacchetto, 'attivita': a.attivita}));

  static void dimentica() => _icone.clear();
  static Future<void> avvia(App a) => c.invokeMethod('avvia', {'pacchetto': a.pacchetto, 'attivita': a.attivita});
  static Future<void> info(App a) => c.invokeMethod('info', {'pacchetto': a.pacchetto, 'attivita': a.attivita});
  static Future<void> disinstalla(App a) => c.invokeMethod('disinstalla', {'pacchetto': a.pacchetto});

  static Future<List<String>?> leggi(String k) async {
    final s = await c.invokeMethod<String>('leggi', {'chiave': k});
    return s == null ? null : List<String>.from(jsonDecode(s));
  }

  static Future<void> scrivi(String k, List<String> v) => c.invokeMethod('scrivi', {'chiave': k, 'valore': jsonEncode(v)});
}

// La prima volta: nel dock telefono, messaggi, browser, galleria, fotocamera
// (la prima che c'e' di ogni gruppo); sulla Home le app piu' comuni.
const _dockIniziale = [
  ['com.samsung.android.dialer', 'com.google.android.dialer', 'com.android.dialer'],
  ['com.samsung.android.messaging', 'com.google.android.apps.messaging', 'com.android.mms'],
  ['com.sec.android.app.sbrowser', 'com.android.chrome'],
  ['com.sec.android.gallery3d', 'com.google.android.apps.photos'],
  ['com.sec.android.app.camera', 'com.google.android.GoogleCamera', 'com.android.camera2'],
];
const _homeIniziale = [
  'it.romaclubmatera.soci', 'com.whatsapp', 'com.google.android.gm', 'com.google.android.apps.maps',
  'com.google.android.youtube', 'com.instagram.android', 'com.facebook.katana', 'com.spotify.music',
  'com.android.vending', 'com.android.settings', 'it.romaclubmatera.tema',
];

class HomeRcm extends StatelessWidget {
  const HomeRcm({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Home RCM',
      debugShowCheckedModeBanner: false,
      theme: Stile.tema().copyWith(scaffoldBackgroundColor: Colors.transparent, canvasColor: Colors.transparent),
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  List<App> tutte = [];
  List<String> casa = [], dock = [];
  bool pronta = false;

  @override
  void initState() {
    super.initState();
    _Nativo.c.setMethodCallHandler((call) async {
      if (call.method == 'cambiate') {
        _Nativo.dimentica();
        await carica();
      } else if (call.method == 'home') {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });
    carica();
  }

  Future<void> carica() async {
    final app = await _Nativo.app();
    var c = await _Nativo.leggi('casa'), d = await _Nativo.leggi('dock');
    String? primaDi(String p) => app.where((a) => a.pacchetto == p).map((a) => a.chiave).firstOrNull;
    if (d == null) {
      d = [for (final g in _dockIniziale) ?g.map(primaDi).nonNulls.firstOrNull];
      await _Nativo.scrivi('dock', d);
    }
    if (c == null) {
      c = _homeIniziale.map(primaDi).nonNulls.toList();
      await _Nativo.scrivi('casa', c);
    }
    if (!mounted) return;
    setState(() {
      tutte = app;
      casa = c!;
      dock = d!;
      pronta = true;
    });
  }

  App? perChiave(String k) => tutte.where((a) => a.chiave == k).firstOrNull;

  Future<void> salva() async {
    await _Nativo.scrivi('casa', casa);
    await _Nativo.scrivi('dock', dock);
  }

  void cassetto() {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => _Cassetto(tutte: tutte, menu: menu),
      transitionsBuilder: (_, anim, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ));
  }

  Future<void> menu(App a) async {
    final inCasa = casa.contains(a.chiave), inDock = dock.contains(a.chiave);
    await showModalBottomSheet(
      context: context,
      backgroundColor: Stile.superficie,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(children: [
              SizedBox(width: 44, child: _Icona(a)),
              const SizedBox(width: 14),
              Expanded(child: Text(a.nome, style: Stile.titolo(17), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ),
          _voce(ctx, inCasa ? Icons.remove_circle_outline : Icons.add_circle_outline,
              inCasa ? 'Togli dalla Home' : 'Aggiungi alla Home', () {
            setState(() => inCasa ? casa.remove(a.chiave) : casa.add(a.chiave));
            salva();
          }),
          if (inDock || dock.length < 5)
            _voce(ctx, inDock ? Icons.vertical_align_top : Icons.vertical_align_bottom,
                inDock ? 'Togli dal dock' : 'Metti nel dock', () {
              setState(() => inDock ? dock.remove(a.chiave) : dock.add(a.chiave));
              salva();
            }),
          _voce(ctx, Icons.info_outline, 'Informazioni app', () => _Nativo.info(a)),
          _voce(ctx, Icons.delete_outline, 'Disinstalla', () => _Nativo.disinstalla(a)),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _voce(BuildContext ctx, IconData i, String t, VoidCallback f) => ListTile(
        leading: Icon(i, color: Stile.oro),
        title: Text(t, style: Stile.testo(16)),
        onTap: () {
          Navigator.pop(ctx);
          f();
        },
      );

  Future<void> menuHome() => showModalBottomSheet(
        context: context,
        backgroundColor: Stile.superficie,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 8),
            _voce(ctx, Icons.wallpaper, 'Sfondi del Club (Tema RCM)', () => _Nativo.c.invokeMethod('temaRcm')),
            _voce(ctx, Icons.photo_library_outlined, 'Cambia sfondo (anche una tua foto)', () => _Nativo.c.invokeMethod('sfondoTuo')),
            _voce(ctx, Icons.home_outlined, 'Cambia app Home', () => _Nativo.c.invokeMethod('sceltaHome')),
            const SizedBox(height: 8),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final inCasa = casa.map(perChiave).nonNulls.toList();
    final nelDock = dock.map(perChiave).nonNulls.toList();
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragEnd: (d) {
            if ((d.primaryVelocity ?? 0) < -250) cassetto();
          },
          onLongPress: menuHome,
          child: DecoratedBox(
            // un velo scuro in alto e in basso: orologio e nomi si leggono su ogni sfondo
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0, .28, .7, 1],
                  colors: [Color(0x66000000), Color(0x00000000), Color(0x00000000), Color(0x80000000)]),
            ),
            child: SafeArea(
              child: Column(children: [
                const _Orologio(),
                Expanded(
                  child: !pronta
                      ? const SizedBox()
                      : GridView.count(
                          crossAxisCount: 4,
                          // la Home non scorre: il gesto verso l'alto apre il cassetto
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                          mainAxisSpacing: 10,
                          childAspectRatio: .82,
                          children: [for (final a in inCasa) _Lancio(a, onLong: () => menu(a))],
                        ),
                ),
                GestureDetector(
                  onTap: cassetto,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    // solo la freccia: una scritta finirebbe sopra quelle degli sfondi
                    child: const Icon(Icons.keyboard_arrow_up, color: Stile.oro, size: 26),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .35),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Stile.oro.withValues(alpha: .35), width: .8),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    for (final a in nelDock) SizedBox(width: 58, child: _Lancio(a, etichetta: false, onLong: () => menu(a))),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

const _giorni = ['lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato', 'domenica'];
const _mesi = ['gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', 'luglio', 'agosto', 'settembre',
  'ottobre', 'novembre', 'dicembre'];

class _Orologio extends StatefulWidget {
  const _Orologio();

  @override
  State<_Orologio> createState() => _OrologioState();
}

class _OrologioState extends State<_Orologio> {
  late Timer t;
  DateTime ora = DateTime.now();

  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 1), (_) {
      final n = DateTime.now();
      if (n.minute != ora.minute) setState(() => ora = n);
    });
  }

  @override
  void dispose() {
    t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ombra = [Shadow(color: Colors.black54, blurRadius: 12)];
    final hh = ora.hour.toString().padLeft(2, '0'), mm = ora.minute.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 18),
      child: Column(children: [
        Text('$hh:$mm', style: const TextStyle(fontFamily: 'Oswald', fontSize: 76, height: 1, color: Stile.panna,
            fontVariations: [FontVariation('wght', 300)], shadows: ombra)),
        const SizedBox(height: 8),
        Text('${_giorni[ora.weekday - 1]} ${ora.day} ${_mesi[ora.month - 1]}'.toUpperCase(),
            style: Stile.sotto(14).copyWith(shadows: ombra, letterSpacing: 3)),
        const SizedBox(height: 10),
        Container(width: 120, height: 2, color: Stile.oro),
      ]),
    );
  }
}

class _Icona extends StatelessWidget {
  const _Icona(this.a);
  final App a;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: FutureBuilder(
        future: _Nativo.icona(a),
        builder: (_, s) => s.data == null ? const SizedBox() : Image.memory(s.data!, gaplessPlayback: true, filterQuality: FilterQuality.medium),
      ),
    );
  }
}

/// Lato delle icone, come quelle di un launcher normale.
const _lato = 58.0;

class _Lancio extends StatelessWidget {
  const _Lancio(this.a, {this.etichetta = true, required this.onLong});
  final App a;
  final bool etichetta;
  final VoidCallback onLong;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _Nativo.avvia(a),
      onLongPress: onLong,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: _lato, height: _lato, child: _Icona(a)),
        if (etichetta) ...[
          const SizedBox(height: 5),
          Text(a.nome, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: Stile.testo(12.5).copyWith(shadows: const [Shadow(color: Colors.black, blurRadius: 6)])),
        ],
      ]),
    );
  }
}

class _Cassetto extends StatefulWidget {
  const _Cassetto({required this.tutte, required this.menu});
  final List<App> tutte;
  final Future<void> Function(App) menu;

  @override
  State<_Cassetto> createState() => _CassettoState();
}

class _CassettoState extends State<_Cassetto> {
  String cerca = '';

  @override
  Widget build(BuildContext context) {
    final q = cerca.trim().toLowerCase();
    final app = q.isEmpty ? widget.tutte : widget.tutte.where((a) => a.nome.toLowerCase().contains(q)).toList();
    return Scaffold(
      backgroundColor: const Color(0xFA0E0306),
      body: GestureDetector(
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.pop(context);
        },
        child: SafeArea(
          child: Column(children: [
            const SizedBox(height: 6),
            const Icon(Icons.keyboard_arrow_down, color: Stile.oro),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: TextField(
                onChanged: (s) => setState(() => cerca = s),
                style: Stile.testo(16),
                cursorColor: Stile.oro,
                decoration: InputDecoration(
                  hintText: 'Cerca un\'app',
                  hintStyle: Stile.testo(16, colore: Stile.panna.withValues(alpha: .5)),
                  prefixIcon: const Icon(Icons.search, color: Stile.oro),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: .06),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                ),
                onSubmitted: (_) {
                  if (app.isNotEmpty) _Nativo.avvia(app.first);
                },
              ),
            ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 4,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                mainAxisSpacing: 12,
                childAspectRatio: .82,
                children: [for (final a in app) _Lancio(a, onLong: () => widget.menu(a))],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
