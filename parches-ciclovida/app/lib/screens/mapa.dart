import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api.dart';
import '../models.dart';
import '../sesion.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'elegir_parche.dart';

/// Mapa interactivo de las 12 estaciones de la CicloVida, con la gente inscrita hoy.
class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  static const _centroCali = LatLng(3.4372, -76.5175);

  Catalogo? _cat;
  Map<String, _ResumenEstacion> _resumen = const {};
  Tramo? _elegido;
  String? _error;

  Api get _api => Sesion.actual.api;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final cat = _cat ?? await _api.catalogo();
      final parches = await _api.parches();
      final resumen = <String, _ResumenEstacion>{};
      for (final p in parches) {
        final r = resumen.putIfAbsent(p.tramoId, _ResumenEstacion.new);
        r.estudiantes += p.inscritos;
        if (p.inscritos > 0) r.parchesConGente += 1;
        if (p.esMio) r.esMia = true;
      }
      if (!mounted) return;
      setState(() {
        _cat = cat;
        _resumen = resumen;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
    }
  }

  Future<void> _verParches(Tramo t) async {
    final cat = _cat;
    if (cat == null) return;
    await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => ElegirParcheScreen(catalogo: cat, tramoInicial: t.id),
      ),
    );
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final cat = _cat;
    return Scaffold(
      appBar: AppBar(title: const Text('Zonas de la CicloVida')),
      body: cat == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: TarjetaError(mensaje: _error!, reintentar: _cargar),
                    ),
            )
          : Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: _centroCali,
                    initialZoom: 12.2,
                    minZoom: 10,
                    maxZoom: 17,
                    onTap: (_, __) => setState(() => _elegido = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'co.dedsec.parches_ciclovida',
                    ),
                    MarkerLayer(
                      markers: [
                        for (final t in cat.tramos)
                          Marker(
                            point: LatLng(t.lat, t.lng),
                            width: 46,
                            height: 46,
                            child: _Pin(
                              resumen: _resumen[t.id],
                              elegido: _elegido?.id == t.id,
                              onTap: () => setState(() => _elegido = t),
                            ),
                          ),
                      ],
                    ),
                    const Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Text('© OpenStreetMap', style: TextStyle(fontSize: 10, color: Cv.inkMuted)),
                      ),
                    ),
                  ],
                ),
                if (_elegido != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _TarjetaEstacion(
                        tramo: _elegido!,
                        comuna: cat.comuna(_elegido!.comuna),
                        resumen: _resumen[_elegido!.id],
                        onVerParches: () => _verParches(_elegido!),
                      ),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Toca una estación para ver quiénes salen desde ahí este domingo.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              const Wrap(
                                spacing: 14,
                                runSpacing: 4,
                                children: [
                                  _Leyenda(color: Cv.verdeInk, texto: 'Con gente'),
                                  _Leyenda(color: Cv.tealInk, texto: 'Aún sin gente'),
                                  _Leyenda(color: Cv.coralInk, texto: 'Tu parche'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ResumenEstacion {
  int estudiantes = 0;
  int parchesConGente = 0;
  bool esMia = false;
}

/// Pin de estación: verde si ya hay gente inscrita, con el conteo encima.
class _Pin extends StatelessWidget {
  const _Pin({required this.resumen, required this.elegido, required this.onTap});

  final _ResumenEstacion? resumen;
  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gente = resumen?.estudiantes ?? 0;
    final color = resumen?.esMia ?? false
        ? Cv.coralInk
        : gente > 0
            ? Cv.verdeInk
            : Cv.tealInk;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: elegido ? 1.25 : 1,
        duration: const Duration(milliseconds: 150),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
          ),
          alignment: Alignment.center,
          child: gente > 0
              ? Text('$gente',
                  style: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white))
              : const Icon(Icons.directions_bike, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

/// Punto de leyenda del mapa: color + palabra, nunca solo color.
class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(texto, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Cv.inkMuted)),
      ],
    );
  }
}

class _TarjetaEstacion extends StatelessWidget {
  const _TarjetaEstacion({required this.tramo, required this.comuna, required this.resumen, required this.onVerParches});

  final Tramo tramo;
  final Comuna? comuna;
  final _ResumenEstacion? resumen;
  final VoidCallback onVerParches;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final gente = resumen?.estudiantes ?? 0;
    final conGente = resumen?.parchesConGente ?? 0;
    final quienes = gente == 0
        ? 'Nadie todavía este domingo: estrena esta estación'
        : '$gente ${gente == 1 ? 'estudiante' : 'estudiantes'} en $conGente ${conGente == 1 ? 'parche' : 'parches'} este domingo';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Cinta(alto: 6),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Estación ${tramo.nombre}', style: t.headlineSmall)),
                    if (resumen?.esMia ?? false)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(color: Cv.coralInk, borderRadius: BorderRadius.circular(999)),
                        child: const Text('Tu parche', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${tramo.punto} · ${tramo.referencia}', style: t.bodyMedium),
                Text(
                  comuna == null || comuna!.barrios.isEmpty
                      ? 'Comuna ${tramo.comuna}'
                      : 'Comuna ${tramo.comuna} · cerca de ${comuna!.barriosResumen()}',
                  style: t.bodySmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.groups, size: 18, color: gente > 0 ? Cv.verdeInk : Cv.inkMuted),
                    const SizedBox(width: 6),
                    Expanded(child: Text(quienes, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: onVerParches, child: const Text('Ver parches de esta estación')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
