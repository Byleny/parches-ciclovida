import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../sesion.dart';
import '../widgets/selectores.dart';

/// Lo que usamos para recomendar parches y armar grupos. Cambiarlo no te saca del parche que elegiste.
class PreferenciasScreen extends StatefulWidget {
  const PreferenciasScreen({super.key, required this.catalogo, required this.perfil});

  final Catalogo catalogo;
  final Perfil perfil;

  @override
  State<PreferenciasScreen> createState() => _PreferenciasScreenState();
}

class _PreferenciasScreenState extends State<PreferenciasScreen> {
  late int? _comuna = widget.perfil.comuna;
  late String? _tramo = widget.perfil.tramoId;
  late String _actividad = widget.perfil.actividad;
  late String _ritmo = widget.perfil.ritmo;
  bool _guardando = false;

  bool get _cambio =>
      _comuna != widget.perfil.comuna ||
      _tramo != widget.perfil.tramoId ||
      _actividad != widget.perfil.actividad ||
      _ritmo != widget.perfil.ritmo;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      await Sesion.actual.api.cambiar({
        'comuna': _comuna,
        'tramo_id': _tramo,
        'actividad': _actividad,
        'ritmo': _ritmo,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.catalogo;
    return Scaffold(
      appBar: AppBar(title: const Text('Tus preferencias')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text(
                    'Las usamos para recomendarte parches y, con tu ritmo, para armar tu grupo. '
                    'Cambiarlas no te saca del parche que ya elegiste.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const TituloSeccion('¿Qué te gusta hacer?'),
                  SelectorActividad(opciones: cat.actividades, valor: _actividad, onChanged: (v) => setState(() => _actividad = v)),
                  const TituloSeccion('¿A qué ritmo?'),
                  SelectorOpciones(opciones: cat.ritmos, valor: _ritmo, onChanged: (v) => setState(() => _ritmo = v)),
                  const TituloSeccion('¿En qué comuna vives?'),
                  SelectorComuna(comunas: cat.comunas, valor: _comuna, onChanged: (v) => setState(() => _comuna = v)),
                  const TituloSeccion('Estación que te queda cerca'),
                  SelectorEstacion(catalogo: cat, comuna: _comuna, valor: _tramo, onChanged: (v) => setState(() => _tramo = v)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                onPressed: _cambio && !_guardando ? _guardar : null,
                child: const Text('Guardar cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
