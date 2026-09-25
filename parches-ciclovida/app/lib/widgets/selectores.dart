import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'comunes.dart';

class TituloSeccion extends StatelessWidget {
  const TituloSeccion(this.texto, {super.key, this.ayuda});

  final String texto;
  final String? ayuda;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(texto, style: Theme.of(context).textTheme.titleMedium),
          if (ayuda != null) ...[
            const SizedBox(height: 2),
            Text(ayuda!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Estaciones de la CicloVida. Primero las de la comuna del joven.
class SelectorTramo extends StatelessWidget {
  const SelectorTramo({super.key, required this.catalogo, required this.valor, required this.onChanged, this.comuna});

  final Catalogo catalogo;
  final String? valor;
  final int? comuna;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tramos = [...catalogo.tramos]
      ..sort((a, b) {
        final ca = a.comuna == comuna ? 0 : 1;
        final cb = b.comuna == comuna ? 0 : 1;
        if (ca != cb) return ca.compareTo(cb);
        return a.nombre.compareTo(b.nombre);
      });
    return Column(
      children: [
        for (final t in tramos)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Seleccionable(
              titulo: t.nombre,
              subtitulo: '${t.punto} · comuna ${t.comuna}${t.comuna == comuna ? ' · tu comuna' : ''}',
              seleccionado: valor == t.id,
              onTap: () => onChanged(t.id),
              icono: Icons.place_outlined,
              colorIcono: Cv.tealInk,
              fondoIcono: Cv.tealSoft,
            ),
          ),
      ],
    );
  }
}

/// Estación favorita en una lista desplegable, con la opción de no elegir ninguna.
class SelectorEstacion extends StatelessWidget {
  const SelectorEstacion({super.key, required this.catalogo, required this.valor, required this.onChanged, this.comuna});

  final Catalogo catalogo;
  final String? valor;
  final int? comuna;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tramos = [...catalogo.tramos]
      ..sort((a, b) {
        final ca = a.comuna == comuna ? 0 : 1;
        final cb = b.comuna == comuna ? 0 : 1;
        if (ca != cb) return ca.compareTo(cb);
        return a.nombre.compareTo(b.nombre);
      });
    return DropdownButtonFormField<String?>(
      initialValue: valor,
      isExpanded: true,
      decoration: const InputDecoration(prefixIcon: Icon(Icons.place_outlined)),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Cualquiera')),
        for (final t in tramos)
          DropdownMenuItem<String?>(
            value: t.id,
            child: Text('${t.nombre}${t.comuna == comuna ? ' · tu comuna' : ''}'),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class SelectorActividad extends StatelessWidget {
  const SelectorActividad({super.key, required this.opciones, required this.valor, required this.onChanged});

  final List<Opcion> opciones;
  final String? valor;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final o in opciones)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Seleccionable(
              titulo: o.nombre,
              seleccionado: valor == o.id,
              onTap: () => onChanged(o.id),
              icono: iconoDe(o.id),
              colorIcono: Colors.white,
              fondoIcono: coloresDe(o.id).tinta,
            ),
          ),
      ],
    );
  }
}

class SelectorOpciones extends StatelessWidget {
  const SelectorOpciones({super.key, required this.opciones, required this.valor, required this.onChanged});

  final List<Opcion> opciones;
  final String? valor;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final o in opciones)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Seleccionable(
              titulo: o.nombre,
              subtitulo: o.detalle,
              seleccionado: valor == o.id,
              onTap: () => onChanged(o.id),
            ),
          ),
      ],
    );
  }
}

/// Opciones cortas en una fila (franja horaria, rango de edad).
class SelectorFila extends StatelessWidget {
  const SelectorFila({super.key, required this.opciones, required this.valor, required this.onChanged});

  final List<Opcion> opciones;
  final String? valor;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < opciones.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _Pastilla(
              texto: opciones[i].nombre,
              seleccionado: valor == opciones[i].id,
              onTap: () => onChanged(opciones[i].id),
            ),
          ),
        ],
      ],
    );
  }
}

class _Pastilla extends StatelessWidget {
  const _Pastilla({required this.texto, required this.seleccionado, required this.onTap});

  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: seleccionado,
      button: true,
      child: Material(
        color: seleccionado ? Cv.ink : Cv.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Cv.radioMd),
          side: BorderSide(color: seleccionado ? Cv.ink : Cv.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Cv.radioMd),
          onTap: onTap,
          child: SizedBox(
            height: 52,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  texto,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: seleccionado ? Colors.white : Cv.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SelectorComuna extends StatelessWidget {
  const SelectorComuna({super.key, required this.comunas, required this.valor, required this.onChanged});

  final List<int> comunas;
  final int? valor;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: valor,
      isExpanded: true,
      decoration: const InputDecoration(hintText: 'Elige tu comuna'),
      items: [
        for (final c in comunas) DropdownMenuItem<int>(value: c, child: Text('Comuna $c')),
      ],
      onChanged: onChanged,
    );
  }
}
