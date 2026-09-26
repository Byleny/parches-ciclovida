import 'package:flutter/material.dart';

import '../theme.dart';
import 'foro.dart';
import 'inicio.dart';
import 'mapa.dart';

/// Cascarón con las tres pestañas: Mi parche, Mapa y Foro, con una barra flotante tipo píldora.
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
          // cada pestaña se recarga cuando vuelve a quedar activa: lo que cambie por Telegram se ve al volver
          InicioScreen(activo: _pestana == 0),
          MapaScreen(activo: _pestana == 1),
          ForoScreen(activo: _pestana == 2),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: _BarraPildora(actual: _pestana, onCambio: (i) => setState(() => _pestana = i)),
        ),
      ),
    );
  }
}

class _Destino {
  const _Destino(this.icono, this.iconoActivo, this.texto, this.color);

  final IconData icono;
  final IconData iconoActivo;
  final String texto;
  final Color color;
}

/// Barra flotante oscura: la pestaña activa se vuelve una píldora blanca con el color de su sección.
class _BarraPildora extends StatelessWidget {
  const _BarraPildora({required this.actual, required this.onCambio});

  final int actual;
  final ValueChanged<int> onCambio;

  static const _destinos = [
    _Destino(Icons.groups_outlined, Icons.groups, 'Mi parche', Cv.coralInk),
    _Destino(Icons.map_outlined, Icons.map, 'Mapa', Cv.tealInk),
    _Destino(Icons.forum_outlined, Icons.forum, 'Foro', Cv.verdeInk),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Cv.ink,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [BoxShadow(color: Color(0x401D1E22), blurRadius: 22, offset: Offset(0, 10))],
      ),
      child: Row(
        children: [
          for (var i = 0; i < _destinos.length; i++)
            Expanded(child: _Pestana(destino: _destinos[i], activa: i == actual, onTap: () => onCambio(i))),
        ],
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana({required this.destino, required this.activa, required this.onTap});

  final _Destino destino;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activa,
      label: destino.texto,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: ShapeDecoration(
                color: activa ? Colors.white : Colors.transparent,
                shape: const StadiumBorder(),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(activa ? destino.iconoActivo : destino.icono, size: 22, color: activa ? destino.color : Colors.white70),
                  Flexible(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: activa
                          ? Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                destino.texto,
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Cv.ink),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
