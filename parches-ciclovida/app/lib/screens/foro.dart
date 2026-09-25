import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../sesion.dart';
import '../theme.dart';
import '../widgets/comunes.dart';

/// Foro comunal: comentarios sobre los parches, la app o cómo se sienten.
/// Cada mensaje muestra solo el primer nombre y la universidad, igual que en el grupo.
class ForoScreen extends StatefulWidget {
  const ForoScreen({super.key});

  @override
  State<ForoScreen> createState() => _ForoScreenState();
}

class _ForoScreenState extends State<ForoScreen> {
  final TextEditingController _texto = TextEditingController();

  Catalogo? _cat;
  List<MensajeForo> _mensajes = const [];
  String? _filtro; // null = todas las categorías
  String _categoria = 'parches';
  String? _error;
  bool _ocupado = false;

  Api get _api => Sesion.actual.api;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final cat = _cat ?? await _api.catalogo();
      final mensajes = await _api.foro(categoria: _filtro);
      if (!mounted) return;
      setState(() {
        _cat = cat;
        _mensajes = mensajes;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
    }
  }

  Future<void> _publicar() async {
    final texto = _texto.text.trim();
    if (texto.length < 2 || _ocupado) return;
    setState(() => _ocupado = true);
    try {
      await _api.foroPublicar(categoria: _categoria, texto: texto);
      _texto.clear();
      if (mounted) FocusScope.of(context).unfocus();
      await _cargar();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _borrar(MensajeForo m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar tu mensaje?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Cv.rojoInk),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.foroBorrar(m.id);
      await _cargar();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = _cat;
    return Scaffold(
      appBar: AppBar(title: const Text('Foro del parche')),
      body: cat == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: TarjetaError(mensaje: _error!, reintentar: _cargar),
                    ),
            )
          : Column(
              children: [
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('Todo'),
                          selected: _filtro == null,
                          selectedColor: Cv.ink,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _filtro == null ? Colors.white : Cv.ink,
                          ),
                          onSelected: (_) {
                            setState(() => _filtro = null);
                            _cargar();
                          },
                        ),
                      ),
                      for (final c in cat.foroCategorias)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c.nombre),
                            selected: _filtro == c.id,
                            selectedColor: _colorCategoria(c.id).tinta,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _filtro == c.id ? Colors.white : Cv.ink,
                            ),
                            onSelected: (_) {
                              setState(() => _filtro = c.id);
                              _cargar();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _cargar,
                    child: _mensajes.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            children: [
                              const SizedBox(height: 40),
                              const Icon(Icons.forum_outlined, size: 56, color: Cv.lineStrong),
                              const SizedBox(height: 12),
                              Text(
                                'Nadie ha escrito todavía.\nCuenta cómo te fue en tu parche o qué mejorarías de la app.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Cv.inkMuted),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            itemCount: _mensajes.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _Mensaje(
                              mensaje: _mensajes[i],
                              nombreCategoria: cat.nombreDe(cat.foroCategorias, _mensajes[i].categoria),
                              onBorrar: _mensajes[i].esMio ? () => _borrar(_mensajes[i]) : null,
                            ),
                          ),
                  ),
                ),
                _Redactor(
                  categorias: cat.foroCategorias,
                  categoria: _categoria,
                  controller: _texto,
                  ocupado: _ocupado,
                  onCategoria: (id) => setState(() => _categoria = id),
                  onEnviar: _publicar,
                ),
              ],
            ),
    );
  }
}

ColoresActividad _colorCategoria(String id) {
  switch (id) {
    case 'parches':
      return const ColoresActividad(Cv.verde, Cv.verdeInk, Cv.verdeSoft);
    case 'app':
      return const ColoresActividad(Cv.teal, Cv.tealInk, Cv.tealSoft);
    default: // animo
      return const ColoresActividad(Cv.coral, Cv.coralInk, Cv.coralSoft);
  }
}

String _haceCuanto(String iso) {
  final fecha = DateTime.tryParse(iso);
  if (fecha == null) return '';
  final d = DateTime.now().difference(fecha);
  if (d.inMinutes < 1) return 'ahora';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  return 'hace ${d.inDays} ${d.inDays == 1 ? 'día' : 'días'}';
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.mensaje, required this.nombreCategoria, this.onBorrar});

  final MensajeForo mensaje;
  final String nombreCategoria;
  final VoidCallback? onBorrar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final col = _colorCategoria(mensaje.categoria);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: col.suave,
              child: Text(
                mensaje.nombre.isEmpty ? '?' : mensaje.nombre[0].toUpperCase(),
                style: TextStyle(fontFamily: 'BarlowCondensed', fontSize: 20, fontWeight: FontWeight.w800, color: col.tinta),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('${mensaje.nombre} · ${mensaje.universidad}',
                          style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                      Text(_haceCuanto(mensaje.creadoEn), style: t.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(mensaje.texto, style: t.bodyMedium),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: col.suave, borderRadius: BorderRadius.circular(999)),
                    child: Text(nombreCategoria,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: col.tinta)),
                  ),
                ],
              ),
            ),
            if (onBorrar != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20, color: Cv.inkMuted),
                tooltip: 'Borrar mi mensaje',
                onPressed: onBorrar,
              ),
          ],
        ),
      ),
    );
  }
}

class _Redactor extends StatelessWidget {
  const _Redactor({
    required this.categorias,
    required this.categoria,
    required this.controller,
    required this.ocupado,
    required this.onCategoria,
    required this.onEnviar,
  });

  final List<Opcion> categorias;
  final String categoria;
  final TextEditingController controller;
  final bool ocupado;
  final ValueChanged<String> onCategoria;
  final VoidCallback onEnviar;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Cv.surfaceRaised,
      elevation: 8,
      shadowColor: Colors.black26,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final c in categorias)
                    ChoiceChip(
                      label: Text(c.nombre),
                      selected: categoria == c.id,
                      selectedColor: _colorCategoria(c.id).tinta,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: categoria == c.id ? Colors.white : Cv.ink,
                      ),
                      onSelected: (_) => onCategoria(c.id),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 500,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: '¿Cómo te fue? ¿Qué mejorarías?',
                        counterText: '',
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: ocupado ? null : onEnviar,
                    style: IconButton.styleFrom(backgroundColor: Cv.ink, minimumSize: const Size(48, 48)),
                    icon: const Icon(Icons.send, size: 20, color: Colors.white),
                    tooltip: 'Publicar',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
