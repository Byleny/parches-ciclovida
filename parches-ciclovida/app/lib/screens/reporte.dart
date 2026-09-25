import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../sesion.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import '../widgets/selectores.dart';

/// "Reportar un problema": sobre alguien del parche o sobre el grupo.
/// Devuelve el mensaje de confirmación si se envió.
Future<String?> abrirReporte(BuildContext context, {required Grupo grupo, required List<Opcion> motivos}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Cv.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Cv.radioLg))),
    builder: (_) => _HojaReporte(grupo: grupo, motivos: motivos),
  );
}

class _HojaReporte extends StatefulWidget {
  const _HojaReporte({required this.grupo, required this.motivos});

  final Grupo grupo;
  final List<Opcion> motivos;

  @override
  State<_HojaReporte> createState() => _HojaReporteState();
}

class _HojaReporteState extends State<_HojaReporte> {
  static const _todoElGrupo = -1;

  int? _sobre;
  String? _motivo;
  final _detalle = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _detalle.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    try {
      final msg = await Sesion.actual.api.reportar(
        grupoId: widget.grupo.id,
        motivo: _motivo!,
        ref: _sobre == null || _sobre == _todoElGrupo ? null : _sobre,
        detalle: _detalle.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(msg);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final otros = widget.grupo.miembros.where((m) => !m.soyYo).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          Text('Reportar un problema', style: t.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Lo lee una persona del equipo, no tu parche. Si es una emergencia, llama al 123.',
            style: t.bodyMedium?.copyWith(color: Cv.inkMuted),
          ),
          const TituloSeccion('¿Sobre quién?'),
          for (final m in otros)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Seleccionable(titulo: m.nombre, seleccionado: _sobre == m.ref, onTap: () => setState(() => _sobre = m.ref)),
            ),
          Seleccionable(
            titulo: 'El parche en general',
            seleccionado: _sobre == _todoElGrupo,
            onTap: () => setState(() => _sobre = _todoElGrupo),
          ),
          const TituloSeccion('¿Qué pasó?'),
          SelectorOpciones(opciones: widget.motivos, valor: _motivo, onChanged: (v) => setState(() => _motivo = v)),
          const SizedBox(height: 8),
          TextField(
            controller: _detalle,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(hintText: 'Si quieres, cuéntanos más (opcional)'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _sobre != null && _motivo != null && !_enviando ? _enviar : null,
            child: const Text('Enviar reporte'),
          ),
        ],
      ),
    );
  }
}
