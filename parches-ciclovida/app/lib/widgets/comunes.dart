import 'package:flutter/material.dart';

import '../theme.dart';

/// Opción que se toca para elegir. Borde teal de 2 px cuando está elegida.
class Seleccionable extends StatelessWidget {
  const Seleccionable({
    super.key,
    required this.titulo,
    required this.seleccionado,
    required this.onTap,
    this.subtitulo,
    this.icono,
    this.colorIcono,
    this.fondoIcono,
  });

  final String titulo;
  final String? subtitulo;
  final bool seleccionado;
  final VoidCallback onTap;
  final IconData? icono;
  final Color? colorIcono;
  final Color? fondoIcono;

  @override
  Widget build(BuildContext context) {
    final borde = seleccionado ? Cv.ink : Cv.line;
    return Semantics(
      selected: seleccionado,
      button: true,
      child: Material(
        color: Cv.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Cv.radioMd),
          side: BorderSide(color: borde, width: seleccionado ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Cv.radioMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (icono != null) ...[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: fondoIcono ?? Cv.surface, shape: BoxShape.circle),
                    child: Icon(icono, color: colorIcono ?? Cv.ink, size: 22),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Cv.ink)),
                      if (subtitulo != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitulo!, style: const TextStyle(fontSize: 13, color: Cv.inkMuted, height: 1.3)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  seleccionado ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: seleccionado ? Cv.ink : Cv.lineStrong,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dos botones grandes "Sí" / "No".
class SiNo extends StatelessWidget {
  const SiNo({super.key, required this.valor, required this.onChanged, this.si = 'Sí', this.no = 'No'});

  final bool? valor;
  final ValueChanged<bool> onChanged;
  final String si;
  final String no;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Seleccionable(titulo: si, seleccionado: valor == true, onTap: () => onChanged(true))),
        const SizedBox(width: 12),
        Expanded(child: Seleccionable(titulo: no, seleccionado: valor == false, onTap: () => onChanged(false))),
      ],
    );
  }
}

/// Tarjeta para los estados sin parche asignado.
class TarjetaEstado extends StatelessWidget {
  const TarjetaEstado({
    super.key,
    required this.icono,
    required this.titulo,
    required this.texto,
    this.accion,
    this.color = Cv.tealInk,
  });

  final IconData icono;
  final String titulo;
  final String texto;
  final Widget? accion;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icono, color: Colors.white, size: 26),
              ),
            ),
            const SizedBox(height: 14),
            Text(titulo, style: t.headlineSmall),
            const SizedBox(height: 6),
            Text(texto, style: t.bodyMedium?.copyWith(color: Cv.inkMuted)),
            if (accion != null) ...[const SizedBox(height: 18), accion!],
          ],
        ),
      ),
    );
  }
}

/// Estado de cada integrante: siempre con palabra, nunca solo color.
class EtiquetaEstado extends StatelessWidget {
  const EtiquetaEstado(this.estado, {super.key});

  final String estado;

  @override
  Widget build(BuildContext context) {
    late final String texto;
    late final Color fondo;
    late final Color tinta;
    switch (estado) {
      case 'confirmado':
        texto = 'Va';
        fondo = Cv.verdeSoft;
        tinta = Cv.verdeInk;
      case 'declinado':
        texto = 'No va';
        fondo = Cv.rojoSoft;
        tinta = Cv.rojoInk;
      default:
        texto = 'Por confirmar';
        fondo = Cv.surface;
        tinta = Cv.inkMuted;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
      child: Text(texto, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tinta)),
    );
  }
}

class TarjetaError extends StatelessWidget {
  const TarjetaError({super.key, required this.mensaje, required this.reintentar, this.cambiarServidor});

  final String mensaje;
  final VoidCallback reintentar;
  final VoidCallback? cambiarServidor;

  @override
  Widget build(BuildContext context) {
    return TarjetaEstado(
      icono: Icons.wifi_off,
      color: Cv.rojoInk,
      titulo: 'No pudimos conectarnos',
      texto: mensaje,
      accion: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(onPressed: reintentar, child: const Text('Reintentar')),
          if (cambiarServidor != null)
            TextButton(onPressed: cambiarServidor, child: const Text('Cambiar dirección del servidor')),
        ],
      ),
    );
  }
}

/// Pie que aclara qué es la app. Sin marca de la Alcaldía (recomendación del mentor).
class PieInstitucional extends StatelessWidget {
  const PieInstitucional({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Prototipo del equipo Dedsec para el reto CicloVida · Hackathon Smart City Expo Cali 2026. '
      'No es un canal oficial de la Alcaldía de Cali.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: Cv.inkMuted),
    );
  }
}

Future<void> dialogoServidor(BuildContext context, {required String actual, required Future<void> Function(String) guardar}) async {
  final ctrl = TextEditingController(text: actual);
  final nueva = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Dirección del servidor'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Es la IP del computador donde corre el backend, por ejemplo http://192.168.1.20:8000'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'http://192.168.1.20:8000'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text), child: const Text('Guardar')),
      ],
    ),
  );
  // El controlador no se descarta aquí: el diálogo todavía se está cerrando con animación.
  if (nueva != null && nueva.trim().isNotEmpty) {
    await guardar(nueva);
  }
}
