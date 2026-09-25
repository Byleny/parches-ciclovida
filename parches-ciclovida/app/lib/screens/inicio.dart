import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../formato.dart';
import '../models.dart';
import '../notificaciones.dart';
import '../sesion.dart';
import '../theme.dart';
import '../widgets/boleta.dart';
import '../widgets/comunes.dart';
import '../widgets/parche_card.dart';
import '../widgets/telegram.dart';
import 'ajustes.dart';
import 'bienvenida.dart';
import 'elegir_parche.dart';
import 'encuesta.dart';
import 'preferencias.dart';
import 'reporte.dart';

/// "Mi parche": lo que el joven ve casi siempre.
class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  Catalogo? _cat;
  Perfil? _perfil;
  EstadoParche? _estado;
  String? _error;
  bool _ocupado = false;

  /// El match automático corre solo una vez al abrir la pantalla sin parche
  /// (recién registrado). Después, el joven decide con los botones.
  bool _matchIntentado = false;

  /// En espera, la pantalla se refresca sola para mostrar el match apenas llegue.
  Timer? _timerEspera;

  Api get _api => Sesion.actual.api;

  @override
  void initState() {
    super.initState();
    Notificaciones.tocada.addListener(_alTocarNotificacion);
    _cargar().then((_) => _alTocarNotificacion());
  }

  @override
  void dispose() {
    _timerEspera?.cancel();
    Notificaciones.tocada.removeListener(_alTocarNotificacion);
    super.dispose();
  }

  void _ajustarTimerEspera() {
    if (_estado?.estado == 'en_espera') {
      _timerEspera ??= Timer.periodic(const Duration(seconds: 45), (_) => _cargar());
    } else {
      _timerEspera?.cancel();
      _timerEspera = null;
    }
  }

  Future<void> _cargar() async {
    try {
      final cat = _cat ?? await _api.catalogo();
      final perfil = await _api.yo();
      var estado = await _api.miParche();
      // Recién llegado sin parche: el match lo une solo a un parche con gente
      // y sus mismas características, o lo deja en lista de espera.
      if (estado.estado == 'sin_parche' && !_matchIntentado) {
        _matchIntentado = true;
        estado = await _api.buscarMatch();
        if (estado.estado == 'inscrito' && estado.salida != null) {
          _aviso('¡Match! Te unimos al ${estado.salida!.nombre}: hay gente con tus mismos planes.');
        }
      }
      if (!mounted) return;
      setState(() {
        _cat = cat;
        _perfil = perfil;
        _estado = estado;
        _error = null;
      });
      _ajustarTimerEspera();
      await _revisarNotificaciones();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.sesionInvalida) {
        await _salir();
        return;
      }
      setState(() => _error = e.mensaje);
    }
  }

  /// Avisos del servidor (por ahora, "tu espera encontró parche"): se muestran
  /// como notificación (o tarjeta en web) y se marcan leídos.
  Future<void> _revisarNotificaciones() async {
    try {
      final nuevas = (await _api.notificaciones()).where((n) => !n.leida).toList();
      if (nuevas.isEmpty || !mounted) return;
      await _api.marcarNotificacionesLeidas();
      if (!mounted) return;
      final n = nuevas.first;
      await Notificaciones.probar(context, Aviso(id: 900 + n.id, titulo: n.titulo, cuerpo: n.cuerpo, payload: 'match'));
    } on ApiException {
      // sin conexión: se reintenta en la próxima carga
    }
  }

  Future<void> _salir() async {
    await Sesion.actual.cerrar();
    await Notificaciones.cancelarTodas();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const BienvenidaScreen()),
      (route) => false,
    );
  }

  Future<void> _alTocarNotificacion() async {
    final toque = Notificaciones.tocada.value;
    if (toque == null) return;
    Notificaciones.tocada.value = null;
    await _cargar();
    if (!mounted) return;
    if (toque.payload == 'encuesta' && (_estado?.encuestaPendiente ?? false)) {
      await _abrirEncuesta();
    }
  }

  Future<void> _accion(Future<void> Function() hacer, {String? exito}) async {
    setState(() => _ocupado = true);
    try {
      await hacer();
      await _cargar();
      if (exito != null) _aviso(exito);
    } on ApiException catch (e) {
      _aviso(e.mensaje);
      await _cargar();
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _responder(bool va) => _accion(
        () => _api.responder(va: va),
        exito: va ? '¡Listo! Tu parche ya sabe que vas.' : 'Gracias por avisar. Tu parche ya lo sabe.',
      );

  Future<void> _pausar(bool pausar) => _accion(() => _api.cambiar({'pausar_esta_semana': pausar}));

  Future<void> _unirme(ParcheOpcion p) => _accion(() => _api.unirme(p.id), exito: '¡Listo! Te uniste al ${p.nombre}.');

  Future<void> _buscarMatch() async {
    setState(() => _ocupado = true);
    try {
      final estado = await _api.buscarMatch();
      if (!mounted) return;
      setState(() => _estado = estado);
      if (estado.estado == 'inscrito' && estado.salida != null) {
        _aviso('¡Match! Te unimos al ${estado.salida!.nombre}: hay gente con tus mismos planes.');
      } else if (estado.estado == 'en_espera') {
        _aviso('Aún no hay parche con tus características. Quedas en lista de espera y te avisamos.');
      }
      await _cargar();
    } on ApiException catch (e) {
      _aviso(e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _cancelarEspera() => _accion(_api.cancelarEspera, exito: 'Listo, dejamos de buscar por ti.');

  Future<void> _salirDelParche() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salirte de tu parche?'),
        content: const Text('Tu lugar queda libre para alguien más. Puedes unirte a otro cuando quieras.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Salirme')),
        ],
      ),
    );
    if (ok == true) await _accion(_api.salirme, exito: 'Saliste del parche.');
  }

  Future<void> _elegir() async {
    final cat = _cat;
    if (cat == null) return;
    final msg = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => ElegirParcheScreen(
          catalogo: cat,
          tramoInicial: _perfil?.tramoId,
          actualId: _estado?.salida?.id,
        ),
      ),
    );
    await _cargar();
    if (msg != null) _aviso(msg);
  }

  Future<void> _abrirEncuesta() async {
    final e = _estado?.encuesta;
    if (e == null) return;
    final enviada = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => EncuestaScreen(info: e)),
    );
    if (enviada == true) {
      await _cargar();
      _aviso('Gracias por contarnos. Nos vemos el próximo domingo.');
    }
  }

  Future<void> _abrirPreferencias() async {
    final cat = _cat;
    final perfil = _perfil;
    if (cat == null || perfil == null) return;
    final cambio = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => PreferenciasScreen(catalogo: cat, perfil: perfil)),
    );
    if (cambio == true) await _cargar();
  }

  Future<void> _abrirAjustes() async {
    final resultado = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => AjustesScreen(onPreferencias: _abrirPreferencias)),
    );
    if (resultado == 'borrado') {
      await _salir();
    } else {
      await _cargar();
    }
  }

  Future<void> _reportar() async {
    final grupo = _estado?.grupo;
    final cat = _cat;
    if (grupo == null || cat == null) return;
    final msg = await abrirReporte(context, grupo: grupo, motivos: cat.motivosReporte);
    if (msg != null) {
      _aviso(msg);
      await _cargar();
    }
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Image.asset('assets/img/ciclovida-recorte.png', height: 36, semanticLabel: 'CicloVida'),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), tooltip: 'Ajustes', onPressed: _abrirAjustes),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: _contenido(),
        ),
      ),
    );
  }

  List<Widget> _contenido() {
    final t = Theme.of(context).textTheme;
    final estado = _estado;
    if (_error != null && estado == null) {
      return [
        TarjetaError(
          mensaje: _error!,
          reintentar: _cargar,
          cambiarServidor: () => dialogoServidor(
            context,
            actual: Sesion.actual.apiUrl,
            guardar: (url) async {
              await Sesion.actual.cambiarUrl(url);
              await _cargar();
            },
          ),
        ),
      ];
    }
    if (estado == null) {
      return const [SizedBox(height: 160), Center(child: CircularProgressIndicator())];
    }

    final nombre = _perfil?.nombre;
    return [
      if (estado.encuestaPendiente) ...[
        _TarjetaEncuesta(info: estado.encuesta!, onTap: _abrirEncuesta),
        const SizedBox(height: 16),
      ],
      _Encabezado(nombre: nombre, estado: estado),
      const SizedBox(height: 16),
      ..._principal(estado),
      const SizedBox(height: 20),
      if (_perfil != null && _cat != null)
        _TarjetaPreferencias(perfil: _perfil!, cat: _cat!, onCambiar: _abrirPreferencias),
      const SizedBox(height: 24),
      Text(
        'Tu grupo solo ve tu primer nombre y tu universidad. La Alcaldía solo ve cifras agregadas.',
        textAlign: TextAlign.center,
        style: t.bodySmall,
      ),
    ];
  }

  List<Widget> _principal(EstadoParche estado) {
    switch (estado.estado) {
      case 'asignado':
        return [
          ParcheCard(
            grupo: estado.grupo!,
            miRespuesta: estado.miRespuesta,
            ajustes: estado.ajustes,
            ocupado: _ocupado,
            onResponder: _responder,
            onReportar: _reportar,
            onCambiar: _elegir,
            onSalir: _salirDelParche,
          ),
        ];
      case 'inscrito':
        return [
          BoletaParche(parche: estado.salida!, onUnirme: () {}),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Tu grupo se arma el sábado', style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      'A las 5:00 p. m. dividimos a la gente de tu parche en grupos de 3 a 6 con ritmo, edad y '
                      'experiencia parecidos. A las 7:00 p. m. te avisamos quiénes van contigo.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: _ocupado ? null : _elegir,
                        icon: const Icon(Icons.swap_horiz, size: 20),
                        label: const Text('Cambiar de parche'),
                      ),
                      TextButton(
                        onPressed: _ocupado ? null : _salirDelParche,
                        style: TextButton.styleFrom(foregroundColor: Cv.inkMuted),
                        child: const Text('Salirme'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ];
      case 'suspendido':
        return const [
          TarjetaEstado(
            icono: Icons.pause_circle_outline,
            color: Cv.rojoInk,
            titulo: 'Tu cuenta está en revisión',
            texto: 'Recibimos reportes sobre un encuentro y una persona del equipo los está revisando. '
                'Mientras tanto no puedes unirte a parches. Si crees que es un error, escríbenos.',
          ),
        ];
      case 'pausado':
        return [
          TarjetaEstado(
            icono: Icons.weekend_outlined,
            color: Cv.coralInk,
            titulo: 'Esta semana descansas',
            texto: 'Si cambias de idea, elige un parche y listo.',
            accion: FilledButton(
              onPressed: _ocupado ? null : () => _pausar(false).then((_) => _elegir()),
              child: const Text('Sí voy, quiero elegir parche'),
            ),
          ),
        ];
      case 'en_espera':
        final espera = estado.espera;
        return [
          _TarjetaEspera(minutos: espera?.minutos ?? 0),
          const SizedBox(height: 12),
          const TarjetaTelegram(),
          if (espera != null && espera.sugerencias.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Mientras tanto, estos se te parecen', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Seguimos buscando tu parche exacto, pero puedes unirte ya a uno parecido.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            for (final p in espera.sugerencias)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: BoletaParche(parche: p, ocupado: _ocupado, onUnirme: () => _unirme(p)),
              ),
          ],
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(onPressed: _ocupado ? null : _elegir, child: const Text('Prefiero elegir yo')),
              TextButton(
                onPressed: _ocupado ? null : _cancelarEspera,
                style: TextButton.styleFrom(foregroundColor: Cv.inkMuted),
                child: const Text('Cancelar la búsqueda'),
              ),
            ],
          ),
        ];
      default:
        return [
          _TarjetaElegir(ocupado: _ocupado, onBuscarMatch: _buscarMatch, onVerTodos: _elegir),
          Align(
            child: TextButton(
              onPressed: _ocupado ? null : () => _pausar(true),
              style: TextButton.styleFrom(foregroundColor: Cv.inkMuted),
              child: const Text('Esta semana no voy'),
            ),
          ),
        ];
    }
  }
}

/// Cabecera con la fecha del domingo sobre un degradado, como cartel de jornada.
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.nombre, required this.estado});

  final String? nombre;
  final EstadoParche estado;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Cv.radioLg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Cv.ink, Cv.tealInk],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (nombre != null)
                  Row(
                    children: [
                      Text('Hola, $nombre', style: t.titleMedium?.copyWith(color: Colors.white70)),
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, size: 18, color: Colors.white, semanticLabel: 'Estudiante verificado'),
                    ],
                  ),
                Text(
                  capitalizar(fechaLarga(estado.jornadaFecha)),
                  style: t.headlineLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  'CicloVida de ${horaBonita(estado.inicio)} a ${horaBonita(estado.fin)}',
                  style: t.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const Cinta(alto: 6),
        ],
      ),
    );
  }
}

/// Lista de espera: el match no encontró parche con gente todavía.
class _TarjetaEspera extends StatelessWidget {
  const _TarjetaEspera({required this.minutos});

  final int minutos;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 46,
                  height: 46,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Cv.tealInk),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text('Buscando tu parche…', style: t.headlineSmall)),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Aún no hay un parche con gente y tus mismas características (hora, estación y actividad). '
              'Quedaste en lista de espera: apenas alguien encaje contigo, te unimos y te avisamos '
              'aquí y por Telegram.',
              style: t.bodyMedium?.copyWith(color: Cv.inkMuted),
            ),
            if (minutos > 0) ...[
              const SizedBox(height: 8),
              Text(
                minutos == 1 ? 'Llevas 1 minuto en espera.' : 'Llevas $minutos minutos en espera.',
                style: t.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Invitación cuando no tiene parche: que el match busque por él, o elegir a mano.
class _TarjetaElegir extends StatelessWidget {
  const _TarjetaElegir({required this.ocupado, required this.onBuscarMatch, required this.onVerTodos});

  final bool ocupado;
  final VoidCallback onBuscarMatch;
  final VoidCallback onVerTodos;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Cv.ink,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Cinta(alto: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Todavía no tienes parche',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Deja que el match te una al parche con gente de tu hora, tu estación y tu actividad, '
                  'o escoge uno tú en las 12 estaciones.',
                  style: TextStyle(fontSize: 16, height: 1.4, color: Colors.white),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: ocupado ? null : onBuscarMatch,
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Cv.ink),
                  icon: const Icon(Icons.auto_awesome, size: 20),
                  label: const Text('Buscar mi parche por mí'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: ocupado ? null : onVerTodos,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70, width: 2),
                  ),
                  child: const Text('Elegir yo mismo'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaEncuesta extends StatelessWidget {
  const _TarjetaEncuesta({required this.info, required this.onTap});

  final EncuestaInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final grupo = info.grupoNombre == null ? '' : ' con el ${info.grupoNombre}';
    return Card(
      color: Cv.coralSoft,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('¿Cómo te fue el ${fechaCorta(info.jornadaFecha)}$grupo?', style: t.headlineSmall),
            const SizedBox(height: 4),
            Text('Tres preguntas, menos de un minuto.', style: t.bodyMedium),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(backgroundColor: Cv.coralInk),
              child: const Text('Responder'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaPreferencias extends StatelessWidget {
  const _TarjetaPreferencias({required this.perfil, required this.cat, required this.onCambiar});

  final Perfil perfil;
  final Catalogo cat;
  final VoidCallback onCambiar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tramo = perfil.tramoId == null ? null : cat.tramo(perfil.tramoId!);
    final filas = <(String, String)>[
      if (perfil.universidad.isNotEmpty) ('Estudias en', perfil.universidad),
      ('Estación', tramo?.nombre ?? 'Cualquiera'),
      ('Actividad', cat.nombreDe(cat.actividades, perfil.actividad)),
      ('Ritmo', cat.nombreDe(cat.ritmos, perfil.ritmo)),
      ('Vives en', 'Comuna ${perfil.comuna}'),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Para recomendarte parches', style: t.titleMedium)),
                TextButton(onPressed: onCambiar, child: const Text('Cambiar')),
              ],
            ),
            for (final f in filas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 96, child: Text(f.$1, style: t.bodySmall)),
                    Expanded(child: Text(f.$2, style: t.bodyMedium)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
