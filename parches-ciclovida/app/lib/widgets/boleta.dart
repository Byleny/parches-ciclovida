import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Un parche de la lista, como una boleta: la hora en el bloque de color y el resto al lado.
class BoletaParche extends StatelessWidget {
  const BoletaParche({super.key, required this.parche, required this.onUnirme, this.ocupado = false});

  final ParcheOpcion parche;
  final VoidCallback onUnirme;
  final bool ocupado;

  @override
  Widget build(BuildContext context) {
    final col = coloresDe(parche.actividad);
    final partes = parche.horaNombre.split(' ');
    final hora = partes.first;
    final sufijo = partes.skip(1).join(' ');
    final mio = parche.esMio;

    return Semantics(
      container: true,
      label: '${parche.nombre}, ${parche.actividadNombre} a las ${parche.horaNombre} en ${parche.tramoNombre}',
      child: Material(
        color: Cv.surfaceRaised,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Cv.radioLg),
          side: mio ? BorderSide(color: col.marca, width: 3) : BorderSide.none,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 88,
                color: col.tinta,
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(hora, style: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
                    Text(sufijo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 12),
                    Icon(iconoDe(parche.actividad), color: Colors.white, size: 28),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(parche.actividadNombre, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: col.tinta)),
                          const Spacer(),
                          if (mio)
                            _Sello(texto: 'Estás aquí', fondo: col.tinta)
                          else if (parche.paraTi)
                            const _Sello(texto: 'Para ti', fondo: Cv.ink),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(parche.nombre, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 2),
                      Text('Estación ${parche.tramoNombre}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Cv.ink)),
                      Text(parche.puntoEncuentro, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 12),
                      if (parche.inscritos > 0) ...[
                        PuntosGente(cantidad: parche.inscritos, color: col.marca),
                        const SizedBox(height: 6),
                      ],
                      Text(_textoGente(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Cv.inkMuted)),
                      if (!mio) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: ocupado ? null : onUnirme,
                            style: FilledButton.styleFrom(minimumSize: const Size(132, 46), backgroundColor: col.tinta),
                            child: const Text('Unirme'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _textoGente() {
    final n = parche.inscritos;
    if (n == 0) return 'Nadie todavía: estrena este parche';
    final unis = parche.universidades;
    final de = unis <= 1 ? '' : ' de $unis universidades';
    final ritmo = parche.ritmoNombre == null ? '' : ', la mayoría a ritmo ${parche.ritmoNombre!.toLowerCase()}';
    return '${n == 1 ? '1 estudiante va' : '$n estudiantes van'}$de$ritmo';
  }
}

class _Sello extends StatelessWidget {
  const _Sello({required this.texto, required this.fondo});

  final String texto;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(999)),
      child: Text(texto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}

/// Un punto por persona inscrita, hasta ocho; el resto se cuenta al final.
class PuntosGente extends StatelessWidget {
  const PuntosGente({super.key, required this.cantidad, required this.color});

  static const _maximo = 8;

  final int cantidad;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final visibles = cantidad > _maximo ? _maximo : cantidad;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < visibles; i++)
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
          if (cantidad > _maximo)
            Text('+${cantidad - _maximo}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}
