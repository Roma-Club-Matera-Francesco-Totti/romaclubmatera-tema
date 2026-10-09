import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'applica.dart';
import 'home.dart';
import 'icone.dart';
import 'sfondi.dart';
import 'stile.dart';
import 'tema.dart';

/// La Home RCM (HomeActivity.kt la avvia per nome, da questa libreria).
@pragma('vm:entry-point')
void home() => avviaHome();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Stile.fondo,
  ));
  runApp(const AppTema());
}

class AppTema extends StatelessWidget {
  const AppTema({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tema RCM',
      debugShowCheckedModeBanner: false,
      theme: Stile.tema(),
      home: const Casa(),
    );
  }
}

class Casa extends StatefulWidget {
  const Casa({super.key});

  @override
  State<Casa> createState() => _CasaState();
}

class _CasaState extends State<Casa> {
  int scheda = 0;

  @override
  void initState() {
    super.initState();
    Tema.esito().then((dove) {
      if (dove != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messaggioSfondo(dove))));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pagine = [const PaginaSfondi(), const PaginaIcone(), const PaginaApplica()];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [const Testata(), Expanded(child: pagine[scheda])]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: scheda,
        onDestinationSelected: (i) => setState(() => scheda = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.wallpaper_outlined), selectedIcon: Icon(Icons.wallpaper), label: 'Sfondi'),
          NavigationDestination(icon: Icon(Icons.apps_outlined), selectedIcon: Icon(Icons.apps), label: 'Icone'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: 'Applica'),
        ],
      ),
    );
  }
}

class Testata extends StatelessWidget {
  const Testata({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          Image.asset('assets/stemma.png', height: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ROMA CLUB MATERA', style: Stile.titolo(19)),
                const SizedBox(height: 2),
                Text('«FRANCESCO TOTTI» · IL TEMA', style: Stile.sotto(12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
