import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'stile.dart';

/// La Home del Club: un launcher (HomeActivity.kt) disegnato sopra lo sfondo
/// del telefono. Pagine a griglia con app, cartelle e widget, dock, cassetto
/// con tutte le app; tutto si sposta tenendo premuto e trascinando.
void avviaHome() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const HomeRcm());
}

/// La griglia di ogni pagina e i posti del dock.
const _colonne = 4, _righe = 6, _postiDock = 5;

class App {
  const App(this.pacchetto, this.attivita, this.nome);
  final String pacchetto, attivita, nome;
  String get chiave => '$pacchetto/$attivita';
}

/// Una cosa sulla Home: app, cartella, widget o l'orologio del Club.
/// x, y, w, h sono in caselle; nel dock conta solo x.
class Voce {
  Voce(
    this.tipo, {
    this.x = 0,
    this.y = 0,
    this.w = 1,
    this.h = 1,
    this.app,
    List<String>? apps,
    this.nome = '',
    this.id,
    this.provider,
  }) : apps = apps ?? [];
  final String tipo; // app, cartella, widget, orologio
  int x, y, w, h;
  String? app;
  List<String> apps;
  String nome;
  int? id; // widget: id di AppWidgetHost
  String? provider;

  Map<String, dynamic> json() => {
    'tipo': tipo,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'app': ?app,
    if (apps.isNotEmpty) 'apps': apps,
    if (nome.isNotEmpty) 'nome': nome,
    'id': ?id,
    'provider': ?provider,
  };

  factory Voce.da(Map m) => Voce(
    m['tipo'],
    x: m['x'],
    y: m['y'],
    w: m['w'] ?? 1,
    h: m['h'] ?? 1,
    app: m['app'],
    apps: List<String>.from(m['apps'] ?? []),
    nome: m['nome'] ?? '',
    id: m['id'],
    provider: m['provider'],
  );

  bool copre(int cx, int cy) => cx >= x && cx < x + w && cy >= y && cy < y + h;
  bool tocca(int ax, int ay, int aw, int ah) => ax < x + w && x < ax + aw && ay < y + h && y < ay + ah;
}

/// Parte nativa: HomeActivity.kt.
class _Nativo {
  static const c = MethodChannel('rcm/home');
  static final _icone = <String, Future<Uint8List?>>{};
  static final _anteprime = <String, Future<Uint8List?>>{};

  static Future<List<App>> app() async {
    final l = await c.invokeListMethod<Map>('app') ?? [];
    return l.map((m) => App(m['pacchetto'], m['attivita'], m['nome'])).toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
  }

  static Future<Uint8List?> icona(App a) => _icone.putIfAbsent(
    a.chiave,
    () => c.invokeMethod<Uint8List>('icona', {'pacchetto': a.pacchetto, 'attivita': a.attivita}),
  );

  static void dimentica() => _icone.clear();
  static Future<void> avvia(App a) => c.invokeMethod('avvia', {'pacchetto': a.pacchetto, 'attivita': a.attivita});
  static Future<void> info(App a) => c.invokeMethod('info', {'pacchetto': a.pacchetto, 'attivita': a.attivita});
  static Future<void> disinstalla(App a) => c.invokeMethod('disinstalla', {'pacchetto': a.pacchetto});

  static Future<String?> leggi(String k) => c.invokeMethod<String>('leggi', {'chiave': k});
  static Future<void> scrivi(String k, String v) => c.invokeMethod('scrivi', {'chiave': k, 'valore': v});

  static Future<List<Map>> widgetDisponibili() async => await c.invokeListMethod<Map>('widgetDisponibili') ?? [];
  static Future<Uint8List?> anteprima(String p) =>
      _anteprime.putIfAbsent(p, () => c.invokeMethod<Uint8List>('anteprimaWidget', {'provider': p}));
  static Future<int?> aggiungiWidget(String p) => c.invokeMethod<int>('aggiungiWidget', {'provider': p});
  static Future<void> rimuoviWidget(int id) => c.invokeMethod('rimuoviWidget', {'id': id});
  static Future<void> pulisciWidget(List<int> usati) => c.invokeMethod('pulisciWidget', {'usati': usati});
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
  'it.romaclubmatera.soci',
  'com.whatsapp',
  'com.google.android.gm',
  'com.google.android.apps.maps',
  'com.google.android.youtube',
  'com.instagram.android',
  'com.facebook.katana',
  'com.spotify.music',
  'com.android.vending',
  'com.android.settings',
  'it.romaclubmatera.tema',
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

/// Quello che si sta trascinando.
class _Volo {
  _Volo(this.v, this.da, this.pagina, this.presa, this.dim, this.inizio) : pos = inizio;
  final Voce v;
  final String da; // pagina, dock, cassetto
  final int pagina;
  final Offset presa; // dove l'hai preso, dentro l'oggetto
  final Size dim;
  final Offset inizio;
  Offset pos;
  bool get mosso => (pos - inizio).distance > 14;
}

/// Dove andrebbe a finire se lo lasci adesso.
class _Bersaglio {
  const _Bersaglio({this.cestino = false, this.dock = false, this.x = 0, this.y = 0});
  final bool cestino, dock;
  final int x, y;
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> with TickerProviderStateMixin {
  List<App> tutte = [];
  Map<String, App> perChiave = {};
  List<List<Voce>> pagine = [[]];
  List<Voce> dock = [];
  bool pronta = false;
  int pagina = 0;
  final pc = PageController();
  late final cass = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  final _griglia = GlobalKey(), _dockKey = GlobalKey(), _cestino = GlobalKey();
  _Volo? volo;
  _Bersaglio? bersaglio;
  Timer? _bordo;

  @override
  void initState() {
    super.initState();
    _Nativo.c.setMethodCallHandler((call) async {
      if (call.method == 'cambiate') {
        _Nativo.dimentica();
        await carica();
      } else if (call.method == 'home') {
        Navigator.of(context).popUntil((r) => r.isFirst);
        if (cass.value > 0) {
          cass.animateBack(0);
        } else if (pc.hasClients && pagina != 0) {
          pc.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
        }
      }
    });
    carica(primaVolta: true);
  }

  @override
  void dispose() {
    cass.dispose();
    pc.dispose();
    super.dispose();
  }

  // ---------- dati ----------

  Future<void> carica({bool primaVolta = false}) async {
    final app = await _Nativo.app();
    final s = primaVolta ? await _Nativo.leggi('disposizione') : null;
    if (!mounted) return;
    setState(() {
      tutte = app;
      perChiave = {for (final a in app) a.chiave: a};
    });
    if (!primaVolta) return;
    if (s != null) {
      final m = jsonDecode(s);
      pagine = [
        for (final p in m['pagine']) [for (final v in p) Voce.da(v)],
      ];
      if (pagine.isEmpty) pagine = [[]];
      dock = [for (final v in m['dock']) Voce.da(v)];
    } else {
      await iniziale(app);
    }
    _Nativo.pulisciWidget([
      for (final v in [...pagine.expand((p) => p), ...dock]) ?v.id,
    ]);
    if (mounted) setState(() => pronta = true);
  }

  /// La prima volta: orologio, le app di prima (vecchia Home RCM) o le piu' comuni.
  Future<void> iniziale(List<App> app) async {
    String? primaDi(String p) => app.where((a) => a.pacchetto == p).map((a) => a.chiave).firstOrNull;
    List<String>? vecchia(String? s) => s == null ? null : List<String>.from(jsonDecode(s));
    final casa = vecchia(await _Nativo.leggi('casa')) ?? _homeIniziale.map(primaDi).nonNulls.toList();
    final d =
        vecchia(await _Nativo.leggi('dock')) ?? [for (final g in _dockIniziale) ?g.map(primaDi).nonNulls.firstOrNull];
    pagine = [
      [Voce('orologio', w: _colonne, h: 2)],
    ];
    for (final c in casa) {
      metti(Voce('app', app: c));
    }
    dock = [for (final (i, c) in d.take(_postiDock).indexed) Voce('app', x: i, app: c)];
    await salva();
  }

  /// Un'app disinstallata (o in aggiornamento) non si vede e non occupa posto,
  /// ma resta salvata: se torna, torna al suo posto.
  bool vive(Voce v) => switch (v.tipo) {
    'app' => perChiave.containsKey(v.app),
    'cartella' => v.apps.any(perChiave.containsKey),
    _ => true,
  };

  bool libero(List<Voce> l, int x, int y, int w, int h) =>
      x >= 0 && y >= 0 && x + w <= _colonne && y + h <= _righe && !l.any((v) => vive(v) && v.tocca(x, y, w, h));

  /// Mette v nel primo posto libero da [da] in poi; se serve aggiunge una pagina.
  int metti(Voce v, {int da = 0}) {
    for (var i = da; i < pagine.length; i++) {
      for (var y = 0; y <= _righe - v.h; y++) {
        for (var x = 0; x <= _colonne - v.w; x++) {
          if (libero(pagine[i], x, y, v.w, v.h)) return _posa(pagine[i], v, x, y, i);
        }
      }
    }
    pagine.add([]);
    return _posa(pagine.last, v, 0, 0, pagine.length - 1);
  }

  int _posa(List<Voce> l, Voce v, int x, int y, int i) {
    l.removeWhere((o) => !vive(o) && o.tocca(x, y, v.w, v.h));
    l.add(
      v
        ..x = x
        ..y = y,
    );
    return i;
  }

  List<Voce>? listaDi(Voce v) => dock.contains(v) ? dock : pagine.where((p) => p.contains(v)).firstOrNull;

  Future<void> salva() async {
    if (volo == null) {
      while (pagine.length > 1 && pagine.last.isEmpty) {
        pagine.removeLast();
      }
      if (pagina >= pagine.length) pagina = pagine.length - 1;
    }
    await _Nativo.scrivi(
      'disposizione',
      jsonEncode({
        'pagine': [
          for (final p in pagine) [for (final v in p) v.json()],
        ],
        'dock': [for (final v in dock) v.json()],
      }),
    );
  }

  void togli(Voce v) {
    listaDi(v)?.remove(v);
    if (v.tipo == 'widget' && v.id != null) _Nativo.rimuoviWidget(v.id!);
    setState(() {});
    salva();
  }

  // ---------- trascinamento ----------

  Rect? rettangolo(GlobalKey k) {
    final b = k.currentContext?.findRenderObject() as RenderBox?;
    if (b == null || !b.hasSize) return null;
    return b.localToGlobal(Offset.zero) & b.size;
  }

  void inizia(Voce v, String da, Offset globale, Offset locale, Size dim) {
    HapticFeedback.mediumImpact();
    final p = pagina;
    if (da == 'pagina') pagine[p].remove(v);
    if (da == 'dock') dock.remove(v);
    // una pagina vuota in fondo, per portarci le cose
    if (pagine.last.isNotEmpty) pagine.add([]);
    setState(() => volo = _Volo(v, da, p, locale, dim, globale));
  }

  void muovi(Offset g) {
    final f = volo;
    if (f == null) return;
    f.pos = g;
    if (f.da == 'cassetto' && f.mosso && cass.value > 0) cass.value = 0;
    final r = rettangolo(_griglia);
    if (r != null && f.mosso) {
      final lato = g.dx < r.left + 28 ? -1 : (g.dx > r.right - 28 ? 1 : 0);
      if (lato == 0) {
        _bordo?.cancel();
        _bordo = null;
      } else {
        _bordo ??= Timer(const Duration(milliseconds: 550), () {
          _bordo = null;
          final n = (pagina + lato).clamp(0, pagine.length - 1);
          if (n != pagina && pc.hasClients) {
            pc.animateToPage(n, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
          }
          // ancora sul bordo: si continua a girare pagina
          Future.delayed(const Duration(milliseconds: 300), () {
            if (volo != null) muovi(volo!.pos);
          });
        });
      }
    }
    setState(() => bersaglio = f.mosso ? calcola(f) : null);
  }

  _Bersaglio? calcola(_Volo f) {
    if (rettangolo(_cestino)?.contains(f.pos) ?? false) return const _Bersaglio(cestino: true);
    final d = rettangolo(_dockKey);
    if (d != null && d.inflate(10).contains(f.pos)) {
      if (f.v.tipo != 'app' && f.v.tipo != 'cartella') return null;
      return _Bersaglio(dock: true, x: ((f.pos.dx - d.left) / d.width * _postiDock).floor().clamp(0, _postiDock - 1));
    }
    final r = rettangolo(_griglia);
    if (r == null || !r.contains(f.pos)) return null;
    final cw = r.width / _colonne, ch = r.height / _righe;
    if (f.v.w == 1 && f.v.h == 1) {
      return _Bersaglio(
        x: ((f.pos.dx - r.left) / cw).floor().clamp(0, _colonne - 1),
        y: ((f.pos.dy - r.top) / ch).floor().clamp(0, _righe - 1),
      );
    }
    // widget e orologio: conta dove li hai presi
    final a = f.pos - f.presa - r.topLeft;
    return _Bersaglio(
      x: (a.dx / cw).round().clamp(0, _colonne - f.v.w),
      y: (a.dy / ch).round().clamp(0, _righe - f.v.h),
    );
  }

  void fine(Offset g) {
    final f = volo;
    if (f == null) return;
    _bordo?.cancel();
    _bordo = null;
    f.pos = g;
    final b = f.mosso ? calcola(f) : null;
    volo = null;
    bersaglio = null;
    if (!f.mosso) {
      rimetti(f);
      menuDi(f.v, f.da);
    } else if (b == null) {
      rimetti(f);
    } else if (b.cestino) {
      if (f.da != 'cassetto' && f.v.tipo == 'widget' && f.v.id != null) _Nativo.rimuoviWidget(f.v.id!);
    } else if (b.dock) {
      posa(dock, f, b.x, 0, inDock: true);
    } else {
      posa(pagine[pagina], f, b.x, b.y);
    }
    setState(() {});
    salva();
  }

  void rimetti(_Volo f) {
    if (f.da == 'pagina') pagine[f.pagina].add(f.v);
    if (f.da == 'dock') dock.add(f.v);
  }

  /// Lascia f nella casella x,y: sopra un'app fa una cartella, sopra una
  /// cartella ci entra; se non c'e' posto torna da dove veniva.
  void posa(List<Voce> l, _Volo f, int x, int y, {bool inDock = false}) {
    final v = f.v;
    final o = l.where((o) => vive(o) && (inDock ? o.x == x : o.copre(x, y))).firstOrNull;
    if (o != null) {
      if (v.tipo == 'app' && o.tipo == 'app' && o.app != v.app) {
        l[l.indexOf(o)] = Voce('cartella', x: o.x, y: o.y, apps: [o.app!, v.app!], nome: 'Cartella');
      } else if (v.tipo == 'app' && o.tipo == 'cartella') {
        if (!o.apps.contains(v.app)) o.apps.add(v.app!);
      } else {
        rimetti(f);
      }
      return;
    }
    if (!inDock && !libero(l, x, y, v.w, v.h)) {
      rimetti(f);
      return;
    }
    l.removeWhere((o) => !vive(o) && (inDock ? o.x == x : o.tocca(x, y, v.w, v.h)));
    l.add(
      v
        ..x = x
        ..y = inDock ? 0 : y,
    );
  }

  // ---------- menu ----------

  Future<void> foglio(Widget? testa, List<(IconData, String, VoidCallback)> voci) => showModalBottomSheet(
    context: context,
    backgroundColor: Stile.superficie,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (testa != null)
            Padding(padding: const EdgeInsets.fromLTRB(20, 18, 20, 8), child: testa)
          else
            const SizedBox(height: 8),
          for (final (i, t, f) in voci)
            ListTile(
              leading: Icon(i, color: Stile.oro),
              title: Text(t, style: Stile.testo(16)),
              onTap: () {
                Navigator.pop(ctx);
                f();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  Widget testaApp(App a) => Row(
    children: [
      SizedBox(width: 44, child: _Icona(a)),
      const SizedBox(width: 14),
      Expanded(
        child: Text(a.nome, style: Stile.titolo(17), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    ],
  );

  Future<void> menuDi(Voce v, String da) async {
    switch (v.tipo) {
      case 'app':
        final a = perChiave[v.app];
        if (a == null) return;
        await foglio(testaApp(a), [
          if (da == 'cassetto')
            (
              Icons.add_circle_outline,
              'Aggiungi alla Home',
              () {
                setState(() => metti(Voce('app', app: a.chiave), da: pagina));
                salva();
              },
            )
          else
            (Icons.remove_circle_outline, 'Togli dalla Home', () => togli(v)),
          (Icons.info_outline, 'Informazioni app', () => _Nativo.info(a)),
          (Icons.delete_outline, 'Disinstalla', () => _Nativo.disinstalla(a)),
        ]);
      case 'cartella':
        await foglio(Text(v.nome, style: Stile.titolo(17)), [
          (Icons.folder_open, 'Apri e rinomina', () => apriCartella(v)),
          (Icons.remove_circle_outline, 'Togli la cartella (le app restano nel cassetto)', () => togli(v)),
        ]);
      case 'widget':
        await foglio(null, [
          (Icons.aspect_ratio, 'Dimensioni', () => dimensioni(v)),
          (Icons.remove_circle_outline, 'Togli il widget', () => togli(v)),
        ]);
      case 'orologio':
        await foglio(null, [(Icons.remove_circle_outline, "Togli l'orologio", () => togli(v))]);
    }
  }

  Future<void> menuHome() => foglio(null, [
    (Icons.widgets_outlined, 'Widget', sceltaWidget),
    if (!pagine.expand((p) => p).any((v) => v.tipo == 'orologio'))
      (
        Icons.schedule,
        'Orologio del Club',
        () {
          setState(() => metti(Voce('orologio', w: _colonne, h: 2), da: pagina));
          salva();
        },
      ),
    (Icons.wallpaper, 'Sfondi del Club (Tema RCM)', () => _Nativo.c.invokeMethod('temaRcm')),
    (Icons.photo_library_outlined, 'Cambia sfondo (anche una tua foto)', () => _Nativo.c.invokeMethod('sfondoTuo')),
    (Icons.home_outlined, 'Cambia app Home', () => _Nativo.c.invokeMethod('sceltaHome')),
  ]);

  // ---------- cartelle ----------

  Future<void> apriCartella(Voce c) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Chiudi',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, _, _) => _Cartella(
        c: c,
        perChiave: perChiave,
        fuori: (a) {
          c.apps.remove(a);
          metti(Voce('app', app: a), da: pagina);
          setState(() {});
          salva();
        },
        cambiata: () {
          setState(() {});
          salva();
        },
      ),
      transitionBuilder: (_, a, _, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: .92, end: 1.0).animate(a), child: child),
      ),
    );
    // una cartella con una sola app torna app, vuota sparisce
    final l = listaDi(c);
    if (l == null) return;
    if (c.apps.length == 1) l[l.indexOf(c)] = Voce('app', x: c.x, y: c.y, app: c.apps.first);
    if (c.apps.isEmpty) l.remove(c);
    if (c.nome.trim().isEmpty) c.nome = 'Cartella';
    setState(() {});
    salva();
  }

  // ---------- widget ----------

  Future<void> sceltaWidget() async {
    final lista = await _Nativo.widgetDisponibili();
    if (!mounted) return;
    final perApp = <String, List<Map>>{};
    for (final w in lista) {
      perApp.putIfAbsent(w['app'], () => []).add(w);
    }
    final app = perApp.keys.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final r = rettangolo(_griglia);
    final cw = (r?.width ?? 360) / _colonne, ch = (r?.height ?? 600) / _righe;
    (int, int) celle(Map w) {
      int una(num t, num min, double cella, int max) => (t > 0 ? t.toInt() : ((min - 8) / cella).ceil()).clamp(1, max);
      return (una(w['celleW'], w['minW'], cw, _colonne), una(w['celleH'], w['minH'], ch, _righe));
    }

    final scelto = await showModalBottomSheet<Map>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Stile.superficie,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        maxChildSize: .95,
        builder: (ctx, sc) => ListView(
          controller: sc,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('WIDGET', style: Stile.titolo(18)),
            ),
            for (final a in app)
              ExpansionTile(
                title: Text(a, style: Stile.testo(16)),
                subtitle: Text(
                  '${perApp[a]!.length} widget',
                  style: Stile.testo(12, colore: Stile.panna.withValues(alpha: .6)),
                ),
                iconColor: Stile.oro,
                collapsedIconColor: Stile.oro,
                children: [
                  for (final w in perApp[a]!)
                    InkWell(
                      onTap: () => Navigator.pop(ctx, w),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(children: [
                          SizedBox(
                            width: 130,
                            height: 110,
                            child: FutureBuilder(
                              future: _Nativo.anteprima(w['provider']),
                              builder: (_, s) =>
                                  s.data == null ? const SizedBox() : Image.memory(s.data!, fit: BoxFit.contain),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(w['nome'] ?? '', style: Stile.testo(15)),
                              // stesso nome per stili diversi (il meteo Samsung): dice quale
                              if (perApp[a]!.where((o) => o['nome'] == w['nome']).length > 1)
                                Text(_stile(w['classe'] ?? ''), style: Stile.testo(12, colore: Stile.panna.withValues(alpha: .8))),
                              if ((w['descrizione'] ?? '').isNotEmpty)
                                Text(w['descrizione'],
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Stile.testo(12, colore: Stile.panna.withValues(alpha: .6))),
                              const SizedBox(height: 4),
                              Text('${celle(w).$1} × ${celle(w).$2}', style: Stile.testo(12, colore: Stile.oro)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
    if (scelto == null) return;
    final id = await _Nativo.aggiungiWidget(scelto['provider']);
    if (id == null || !mounted) return;
    final (w, h) = celle(scelto);
    final i = metti(
      Voce('widget', w: w, h: h, id: id, provider: scelto['provider']),
      da: pagina,
    );
    setState(() {});
    salva();
    if (i != pagina && pc.hasClients) pc.jumpToPage(i);
  }

  Future<void> dimensioni(Voce v) async {
    final l = listaDi(v);
    if (l == null) return;
    bool sta(int w, int h) => w >= 1 && h >= 1 && libero(l.where((o) => o != v).toList(), v.x, v.y, w, h);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, aggiorna) {
          void cambia(int dw, int dh) {
            if (!sta(v.w + dw, v.h + dh)) return;
            v
              ..w += dw
              ..h += dh;
            aggiorna(() {});
            setState(() {});
          }

          Widget riga(String t, int n, int dw, int dh) => Row(
            children: [
              Expanded(child: Text(t, style: Stile.testo(16))),
              IconButton(
                onPressed: sta(v.w - dw, v.h - dh) ? () => cambia(-dw, -dh) : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: Stile.oro,
              ),
              SizedBox(
                width: 28,
                child: Text('$n', textAlign: TextAlign.center, style: Stile.titolo(18)),
              ),
              IconButton(
                onPressed: sta(v.w + dw, v.h + dh) ? () => cambia(dw, dh) : null,
                icon: const Icon(Icons.add_circle_outline),
                color: Stile.oro,
              ),
            ],
          );
          return AlertDialog(
            backgroundColor: Stile.superficie,
            title: Text('DIMENSIONI', style: Stile.titolo(18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [riga('Larghezza', v.w, 1, 0), riga('Altezza', v.h, 0, 1)],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('FATTO'))],
          );
        },
      ),
    );
    salva();
  }

  // ---------- disegno ----------

  Widget elemento(Voce v, String da) {
    final etichetta = da != 'dock';
    final (Widget figlio, VoidCallback? tocco) = switch (v.tipo) {
      'app' => (_Lancio(perChiave[v.app]!, etichetta: etichetta), () => _Nativo.avvia(perChiave[v.app]!)),
      'cartella' => (_IconaCartella(v, perChiave, etichetta: etichetta), () => apriCartella(v)),
      'widget' => (Padding(padding: const EdgeInsets.all(6), child: _VistaWidget(v.id!)), null),
      _ => (const FittedBox(fit: BoxFit.scaleDown, child: _Orologio()), null),
    };
    return _Presa(key: ObjectKey(v), tocco: tocco, inizio: (g, l, s) => inizia(v, da, g, l, s), child: figlio);
  }

  Widget unaPagina(int i) => LayoutBuilder(
    builder: (_, c) {
      final cw = c.maxWidth / _colonne, ch = c.maxHeight / _righe;
      final b = bersaglio, f = volo;
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(behavior: HitTestBehavior.translucent, onLongPress: menuHome),
          ),
          if (f != null && b != null && !b.dock && !b.cestino && i == pagina)
            Positioned(left: b.x * cw, top: b.y * ch, width: f.v.w * cw, height: f.v.h * ch, child: const _Segno()),
          for (final v in pagine[i])
            if (vive(v))
              Positioned(
                left: v.x * cw,
                top: v.y * ch,
                width: v.w * cw,
                height: v.h * ch,
                child: v.w == 1 && v.h == 1 ? Center(child: elemento(v, 'pagina')) : elemento(v, 'pagina'),
              ),
        ],
      );
    },
  );

  Widget barraDock() => Container(
    margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: Stile.oro.withValues(alpha: .35), width: .8),
    ),
    child: SizedBox(
      key: _dockKey,
      height: _lato,
      child: LayoutBuilder(
        builder: (_, c) {
          final w = c.maxWidth / _postiDock;
          final b = bersaglio;
          return Stack(
            children: [
              if (volo != null && b != null && b.dock)
                Positioned(left: b.x * w, width: w, top: 0, bottom: 0, child: const _Segno()),
              for (final v in dock)
                if (vive(v) && v.x < _postiDock)
                  Positioned(
                    left: v.x * w,
                    width: w,
                    top: 0,
                    bottom: 0,
                    child: Center(child: elemento(v, 'dock')),
                  ),
            ],
          );
        },
      ),
    ),
  );

  Widget fluttuante(_Volo f) {
    final piccolo = f.v.w == 1 && f.v.h == 1;
    final dim = piccolo ? const Size(_lato + 14, _lato + 14) : f.dim;
    final presa = piccolo ? Offset(dim.width / 2, dim.height / 2) : f.presa;
    final Widget figura = switch (f.v.tipo) {
      'app' => _Icona(perChiave[f.v.app]!),
      'cartella' => _IconaCartella(f.v, perChiave, etichetta: false),
      'orologio' => const FittedBox(child: _Orologio()),
      _ => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .4),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Stile.oro, width: 1.5),
        ),
        child: const Center(child: Icon(Icons.widgets_outlined, color: Stile.oro, size: 40)),
      ),
    };
    return Positioned(
      left: f.pos.dx - presa.dx,
      top: f.pos.dy - presa.dy,
      width: dim.width,
      height: dim.height,
      child: IgnorePointer(
        child: Opacity(opacity: .9, child: Transform.scale(scale: 1.06, child: figura)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = volo;
    final sopra = MediaQuery.paddingOf(context).top;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, _) {
        if (cass.value > 0) cass.animateBack(0);
      },
      // il trascinamento lo segue la Home intera: l'oggetto preso sparisce
      // dal suo posto (e magari dalla pagina), il suo gesto con lui
      child: Listener(
        onPointerMove: (e) => muovi(e.position),
        onPointerUp: (e) => fine(e.position),
        onPointerCancel: (e) {
          final f = volo;
          if (f != null) fine(f.pos);
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              DecoratedBox(
                // un velo scuro in alto e in basso: orologio e nomi si leggono su ogni sfondo
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, .28, .7, 1],
                    colors: [Color(0x66000000), Color(0x00000000), Color(0x00000000), Color(0x80000000)],
                  ),
                ),
                child: SafeArea(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragEnd: (d) {
                      if ((d.primaryVelocity ?? 0) < -250) cass.forward();
                    },
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                            child: !pronta
                                ? const SizedBox()
                                : PageView.builder(
                                    key: _griglia,
                                    controller: pc,
                                    itemCount: pagine.length,
                                    onPageChanged: (i) => setState(() => pagina = i),
                                    itemBuilder: (_, i) => unaPagina(i),
                                  ),
                          ),
                        ),
                        SizedBox(
                          height: 22,
                          child: pagine.length < 2
                              ? GestureDetector(
                                  onTap: cass.forward,
                                  child: const Icon(Icons.keyboard_arrow_up, color: Stile.oro, size: 22),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    for (var i = 0; i < pagine.length; i++)
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        margin: const EdgeInsets.symmetric(horizontal: 4),
                                        width: i == pagina ? 18 : 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: i == pagina ? Stile.oro : Stile.panna.withValues(alpha: .5),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                        barraDock(),
                      ],
                    ),
                  ),
                ),
              ),
              // il cassetto resta montato anche chiuso: se ne trascini fuori
              // un'app, il gesto continua qui
              AnimatedBuilder(
                animation: cass,
                builder: (_, child) => IgnorePointer(
                  ignoring: cass.value == 0,
                  child: FractionalTranslation(translation: Offset(0, 1 - cass.value), child: child),
                ),
                child: _Cassetto(
                  tutte: tutte,
                  chiudi: () => cass.animateBack(0),
                  presa: (a) => _Presa(
                    key: ValueKey('cassetto ${a.chiave}'),
                    tocco: () => _Nativo.avvia(a),
                    inizio: (g, l, s) => inizia(Voce('app', app: a.chiave), 'cassetto', g, l, s),
                    child: _Lancio(a),
                  ),
                ),
              ),
              if (f != null && f.mosso)
                Positioned(
                  key: _cestino,
                  left: 0,
                  right: 0,
                  top: 0,
                  height: sopra + 64,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.only(top: sopra),
                    color: (bersaglio?.cestino ?? false) ? const Color(0xCC8E1B2B) : Colors.black54,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(f.da == 'cassetto' ? Icons.close : Icons.delete_outline, color: Stile.panna),
                        const SizedBox(width: 8),
                        Text(f.da == 'cassetto' ? 'ANNULLA' : 'TOGLI DALLA HOME', style: Stile.sotto(14)),
                      ],
                    ),
                  ),
                ),
              if (f != null && f.mosso) fluttuante(f),
            ],
          ),
        ),
      ),
    );
  }
}

/// "WeatherInsightAppWidget" -> "Insight"
String _stile(String classe) {
  final s = classe.replaceAll(RegExp(r'(App)?Widget(Provider|Receiver)?|Weather'), '');
  return s.replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z0-9])'), (_) => ' ').trim();
}

/// Tieni premuto: se non ti muovi apre il menu, se ti muovi trascina
/// (il resto del gesto lo segue il Listener della Home).
class _Presa extends StatelessWidget {
  const _Presa({super.key, required this.child, this.tocco, required this.inizio});
  final Widget child;
  final VoidCallback? tocco;
  final void Function(Offset globale, Offset locale, Size dim) inizio;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tocco,
      onLongPressStart: (d) => inizio(d.globalPosition, d.localPosition, context.size ?? Size.zero),
      child: child,
    );
  }
}

/// La casella dove andrebbe a finire.
class _Segno extends StatelessWidget {
  const _Segno();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(3),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Stile.oro.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Stile.oro.withValues(alpha: .8), width: 1.5),
      ),
    ),
  );
}

class _VistaWidget extends StatelessWidget {
  const _VistaWidget(this.id);
  final int id;

  @override
  Widget build(BuildContext context) => AndroidView(
    viewType: 'rcm/widget',
    creationParams: {'id': id},
    creationParamsCodec: const StandardMessageCodec(),
    // le liste dentro i widget (posta, calendario) scorrono
    gestureRecognizers: {Factory<VerticalDragGestureRecognizer>(VerticalDragGestureRecognizer.new)},
  );
}

const _giorni = ['lunedì', 'martedì', 'mercoledì', 'giovedì', 'venerdì', 'sabato', 'domenica'];
const _mesi = [
  'gennaio',
  'febbraio',
  'marzo',
  'aprile',
  'maggio',
  'giugno',
  'luglio',
  'agosto',
  'settembre',
  'ottobre',
  'novembre',
  'dicembre',
];

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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Column(
        children: [
          Text(
            '$hh:$mm',
            style: const TextStyle(
              fontFamily: 'Oswald',
              fontSize: 76,
              height: 1,
              color: Stile.panna,
              fontVariations: [FontVariation('wght', 300)],
              shadows: ombra,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_giorni[ora.weekday - 1]} ${ora.day} ${_mesi[ora.month - 1]}'.toUpperCase(),
            style: Stile.sotto(14).copyWith(shadows: ombra, letterSpacing: 3),
          ),
          const SizedBox(height: 10),
          Container(width: 120, height: 2, color: Stile.oro),
        ],
      ),
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
        builder: (_, s) => s.data == null
            ? const SizedBox()
            : Image.memory(s.data!, gaplessPlayback: true, filterQuality: FilterQuality.medium),
      ),
    );
  }
}

/// Lato delle icone, come quelle di un launcher normale.
const _lato = 58.0;

final _ombraTesto = Stile.testo(12.5).copyWith(shadows: const [Shadow(color: Colors.black, blurRadius: 6)]);

class _Lancio extends StatelessWidget {
  const _Lancio(this.a, {this.etichetta = true});
  final App a;
  final bool etichetta;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: _lato, height: _lato, child: _Icona(a)),
        if (etichetta) ...[
          const SizedBox(height: 5),
          SizedBox(
            width: 80,
            child: Text(
              a.nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _ombraTesto,
            ),
          ),
        ],
      ],
    );
  }
}

/// La cartella sulla Home: tondo scuro con bordo oro e le prime quattro app.
class _IconaCartella extends StatelessWidget {
  const _IconaCartella(this.c, this.perChiave, {this.etichetta = true});
  final Voce c;
  final Map<String, App> perChiave;
  final bool etichetta;

  @override
  Widget build(BuildContext context) {
    final app = c.apps.map((k) => perChiave[k]).nonNulls.take(4).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _lato,
          height: _lato,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xCC3A0B13),
            border: Border.all(color: Stile.oro, width: 1.6),
          ),
          // le prime quattro app in un quadrato 2x2 al centro del tondo
          child: Center(
            child: SizedBox(
              width: _lato * .66,
              child: Wrap(
                spacing: 2,
                runSpacing: 2,
                children: [for (final a in app) SizedBox(width: _lato * .31, height: _lato * .31, child: _Icona(a))],
              ),
            ),
          ),
        ),
        if (etichetta) ...[
          const SizedBox(height: 5),
          SizedBox(
            width: 80,
            child: Text(
              c.nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _ombraTesto,
            ),
          ),
        ],
      ],
    );
  }
}

/// La cartella aperta: nome modificabile, le sue app.
class _Cartella extends StatefulWidget {
  const _Cartella({required this.c, required this.perChiave, required this.fuori, required this.cambiata});
  final Voce c;
  final Map<String, App> perChiave;
  final void Function(String) fuori;
  final VoidCallback cambiata;

  @override
  State<_Cartella> createState() => _CartellaState();
}

class _CartellaState extends State<_Cartella> {
  late final nome = TextEditingController(text: widget.c.nome);

  @override
  void dispose() {
    nome.dispose();
    super.dispose();
  }

  Future<void> menu(App a) => showModalBottomSheet(
    context: context,
    backgroundColor: Stile.superficie,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          for (final (i, t, f) in <(IconData, String, VoidCallback)>[
            (
              Icons.logout,
              'Togli dalla cartella',
              () {
                widget.fuori(a.chiave);
                setState(() {});
                if (widget.c.apps.length < 2) Navigator.pop(context);
              },
            ),
            (Icons.info_outline, 'Informazioni app', () => _Nativo.info(a)),
            (Icons.delete_outline, 'Disinstalla', () => _Nativo.disinstalla(a)),
          ])
            ListTile(
              leading: Icon(i, color: Stile.oro),
              title: Text(t, style: Stile.testo(16)),
              onTap: () {
                Navigator.pop(ctx);
                f();
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final app = widget.c.apps.map((k) => widget.perChiave[k]).nonNulls.toList();
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: const Color(0xF21A0509),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Stile.oro.withValues(alpha: .6), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nome,
                textAlign: TextAlign.center,
                style: Stile.titolo(20),
                cursorColor: Stile.oro,
                decoration: const InputDecoration(border: InputBorder.none, hintText: 'Nome della cartella'),
                onChanged: (s) {
                  widget.c.nome = s;
                  widget.cambiata();
                },
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .55),
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  childAspectRatio: .8,
                  children: [
                    for (final a in app)
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _Nativo.avvia(a);
                        },
                        onLongPress: () => menu(a),
                        child: _Lancio(a),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cassetto extends StatefulWidget {
  const _Cassetto({required this.tutte, required this.chiudi, required this.presa});
  final List<App> tutte;
  final VoidCallback chiudi;
  final Widget Function(App) presa;

  @override
  State<_Cassetto> createState() => _CassettoState();
}

class _CassettoState extends State<_Cassetto> {
  final cerca = TextEditingController();

  @override
  void dispose() {
    cerca.dispose();
    super.dispose();
  }

  void chiudi() {
    FocusScope.of(context).unfocus();
    widget.chiudi();
  }

  @override
  Widget build(BuildContext context) {
    final q = cerca.text.trim().toLowerCase();
    final app = q.isEmpty ? widget.tutte : widget.tutte.where((a) => a.nome.toLowerCase().contains(q)).toList();
    return Material(
      color: const Color(0xFA0E0306),
      child: SafeArea(
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: chiudi,
              onVerticalDragEnd: (d) {
                if ((d.primaryVelocity ?? 0) > 200) chiudi();
              },
              child: const SizedBox(
                width: double.infinity,
                height: 30,
                child: Icon(Icons.keyboard_arrow_down, color: Stile.oro),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                controller: cerca,
                onChanged: (_) => setState(() {}),
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
              // tirando giu' quando sei gia' in cima si chiude
              child: NotificationListener<OverscrollNotification>(
                onNotification: (n) {
                  if (n.overscroll < -8 && n.dragDetails != null) chiudi();
                  return false;
                },
                child: GridView.count(
                  crossAxisCount: 4,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  mainAxisSpacing: 12,
                  childAspectRatio: .82,
                  children: [for (final a in app) Center(child: widget.presa(a))],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
