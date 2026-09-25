import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'notificaciones.dart';
import 'screens/bienvenida.dart';
import 'screens/inicio.dart';
import 'sesion.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notificaciones.iniciar();
  final sesion = await Sesion.cargar();
  runApp(ParchesApp(registrado: sesion.registrado));
}

class ParchesApp extends StatelessWidget {
  const ParchesApp({super.key, required this.registrado});

  final bool registrado;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parches CicloVida',
      debugShowCheckedModeBanner: false,
      theme: temaParches(),
      locale: const Locale('es', 'CO'),
      supportedLocales: const [Locale('es', 'CO'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: registrado ? const InicioScreen() : const BienvenidaScreen(),
    );
  }
}
