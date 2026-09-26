import 'package:flutter/material.dart';

import 'foro.dart';
import 'inicio.dart';
import 'mapa.dart';

/// Cascarón con las tres pestañas: Mi parche, Mapa y Foro.
class PrincipalScreen extends StatefulWidget {
  const PrincipalScreen({super.key});

  @override
  State<PrincipalScreen> createState() => _PrincipalScreenState();
}

class _PrincipalScreenState extends State<PrincipalScreen> {
  int _pestana = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _pestana,
        children: [
          const InicioScreen(),
          // el mapa y el foro se recargan cada vez que su pestaña vuelve a quedar activa
          MapaScreen(activo: _pestana == 1),
          ForoScreen(activo: _pestana == 2),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestana,
        onDestinationSelected: (i) => setState(() => _pestana = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Mi parche'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: 'Foro'),
        ],
      ),
    );
  }
}
