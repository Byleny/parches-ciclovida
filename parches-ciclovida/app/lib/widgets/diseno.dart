import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Piezas del lenguaje visual "carril": la CicloVida como una vía. La cinta de cuatro colores se
/// curva como un carril, las líneas punteadas son las del asfalto y el parche es un boleto
/// perforado. Son los mismos colores de la marca (theme.dart), usados con más intención.

/// Rótulo pequeño en mayúsculas con un trazo de color, encima de títulos y secciones.
class Rotulo extends StatelessWidget {
  const Rotulo(this.texto, {super.key, this.color = Cv.tealInk, this.claro = false});

  final String texto;
  final Color color;

  /// Sobre fondo oscuro.
  final bool claro;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            texto.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
              color: claro ? Colors.white70 : Cv.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// Dibuja [path] punteado, como la línea de un carril.
void dibujarPunteada(Canvas canvas, Path path, Paint paint, {double trazo = 10, double espacio = 8}) {
  for (final m in path.computeMetrics()) {
    var d = 0.0;
    while (d < m.length) {
      canvas.drawPath(m.extractPath(d, math.min(d + trazo, m.length)), paint);
      d += trazo + espacio;
    }
  }
}

/// Fondo oscuro con la cinta de cuatro colores entrando por una esquina y curvándose como una vía,
/// más una línea de carril punteada. Para encabezados y tarjetas protagonistas.
class FondoCarril extends StatelessWidget {
  const FondoCarril({
    super.key,
    required this.child,
    this.borde = const BorderRadius.all(Radius.circular(Cv.radioLg)),
    this.colores = const [Cv.fondoOscuro, Cv.ink],
    this.intensidad = 1,
  });

  final Widget child;
  final BorderRadius borde;

  /// Degradado del fondo (de arriba a la izquierda hacia abajo a la derecha).
  final List<Color> colores;

  /// 0 a 1: qué tan presentes se ven la cinta y el carril.
  final double intensidad;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borde,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colores),
        ),
        child: CustomPaint(painter: _CarrilPainter(intensidad), child: child),
      ),
    );
  }
}

class _CarrilPainter extends CustomPainter {
  const _CarrilPainter(this.intensidad);

  final double intensidad;

  @override
  void paint(Canvas canvas, Size s) {
    if (s.isEmpty) return;
    final ancho = (s.shortestSide * 0.05).clamp(6.0, 12.0);
    // La cinta: cuatro franjas que entran por arriba a la derecha y se curvan hacia la orilla.
    for (var i = 0; i < 4; i++) {
      final d = i * ancho * 1.2;
      final franja = Path()
        ..moveTo(s.width * 0.74 + d, -ancho)
        ..cubicTo(
          s.width * 0.86 + d, s.height * 0.30,
          s.width * 0.80 + d, s.height * 0.62,
          s.width + ancho * 3, s.height * 0.82 + d,
        );
      canvas.drawPath(
        franja,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ancho
          ..color = Cv.cinta[i].withValues(alpha: 0.85 * intensidad),
      );
    }
    // La línea de carril punteada que cruza el fondo por abajo.
    final carril = Path()
      ..moveTo(-12, s.height * 0.92)
      ..quadraticBezierTo(s.width * 0.30, s.height * 0.70, s.width * 0.62, s.height + 12);
    dibujarPunteada(
      canvas,
      carril,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.16 * intensidad),
    );
  }

  @override
  bool shouldRepaint(_CarrilPainter old) => old.intensidad != intensidad;
}

/// Línea punteada horizontal (o vertical), como la del asfalto o la de un boleto.
class LineaPunteada extends StatelessWidget {
  const LineaPunteada({super.key, this.color = Cv.lineStrong, this.grosor = 1.5, this.vertical = false});

  final Color color;
  final double grosor;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: vertical ? grosor : double.infinity,
      height: vertical ? double.infinity : grosor,
      child: CustomPaint(painter: _PunteadaPainter(color, grosor, vertical)),
    );
  }
}

class _PunteadaPainter extends CustomPainter {
  const _PunteadaPainter(this.color, this.grosor, this.vertical);

  final Color color;
  final double grosor;
  final bool vertical;

  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    final largo = vertical ? s.height : s.width;
    var d = 0.0;
    while (d < largo) {
      final fin = math.min(d + 6, largo);
      if (vertical) {
        canvas.drawLine(Offset(s.width / 2, d), Offset(s.width / 2, fin), paint);
      } else {
        canvas.drawLine(Offset(d, s.height / 2), Offset(fin, s.height / 2), paint);
      }
      d += 11;
    }
  }

  @override
  bool shouldRepaint(_PunteadaPainter old) => old.color != color || old.grosor != grosor || old.vertical != vertical;
}

/// El corte de un boleto: dos muescas del color del fondo de la página y una línea punteada.
class Perforacion extends StatelessWidget {
  const Perforacion({super.key, this.fondo = Cv.surface, this.color = Cv.surfaceRaised});

  /// Color de la página detrás de la tarjeta: las muescas lo "dejan ver".
  final Color fondo;

  /// Color de la tarjeta en ese punto.
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      height: 24,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 24,
            decoration: BoxDecoration(color: fondo, borderRadius: const BorderRadius.horizontal(right: Radius.circular(12))),
          ),
          const SizedBox(width: 8),
          const Expanded(child: LineaPunteada()),
          const SizedBox(width: 8),
          Container(
            width: 12,
            height: 24,
            decoration: BoxDecoration(color: fondo, borderRadius: const BorderRadius.horizontal(left: Radius.circular(12))),
          ),
        ],
      ),
    );
  }
}

/// Caras del grupo apiladas: la inicial de cada quien en un círculo con borde blanco.
class AvatarPila extends StatelessWidget {
  const AvatarPila({super.key, required this.nombres, this.colores = const [], this.radio = 16, this.maximo = 5});

  final List<String> nombres;

  /// Color de cada círculo (si falta, rota por los colores de la marca).
  final List<Color> colores;
  final double radio;
  final int maximo;

  static const _rotacion = [Cv.tealInk, Cv.coralInk, Cv.verdeInk, Cv.rojoInk];

  @override
  Widget build(BuildContext context) {
    final visibles = nombres.take(maximo).toList();
    final resto = nombres.length - visibles.length;
    final paso = radio * 1.35;
    final total = visibles.length + (resto > 0 ? 1 : 0);
    if (total == 0) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: SizedBox(
        width: radio * 2 + (total - 1) * paso,
        height: radio * 2,
        child: Stack(
          children: [
            for (var i = 0; i < visibles.length; i++)
              Positioned(
                left: i * paso,
                child: _circulo(
                  visibles[i].isEmpty ? '?' : visibles[i].substring(0, 1).toUpperCase(),
                  i < colores.length ? colores[i] : _rotacion[i % _rotacion.length],
                ),
              ),
            if (resto > 0) Positioned(left: visibles.length * paso, child: _circulo('+$resto', Cv.ink)),
          ],
        ),
      ),
    );
  }

  Widget _circulo(String texto, Color color) {
    return Container(
      width: radio * 2,
      height: radio * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
      child: Text(
        texto,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: radio * 0.78, height: 1),
      ),
    );
  }
}

/// Entrada suave (sube y aparece), escalonada por [orden]. Respeta "reducir movimiento".
class Aparecer extends StatefulWidget {
  const Aparecer({super.key, required this.child, this.orden = 0});

  final Widget child;
  final int orden;

  @override
  State<Aparecer> createState() => _AparecerState();
}

class _AparecerState extends State<Aparecer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _curva = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  bool _arrancado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_arrancado) return;
    _arrancado = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      Future<void>.delayed(Duration(milliseconds: 70 * widget.orden.clamp(0, 8)), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curva,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(_curva),
        child: widget.child,
      ),
    );
  }
}

/// Bloque gris que late mientras carga: la forma de lo que viene, en vez de un circulito girando.
class Esqueleto extends StatefulWidget {
  const Esqueleto({super.key, required this.alto, this.radio = Cv.radioLg});

  final double alto;
  final double radio;

  @override
  State<Esqueleto> createState() => _EsqueletoState();
}

class _EsqueletoState extends State<Esqueleto> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
      child: Container(
        height: widget.alto,
        decoration: BoxDecoration(color: Cv.line, borderRadius: BorderRadius.circular(widget.radio)),
      ),
    );
  }
}

/// Ondas que salen de un punto, como un radar: "estamos buscando".
class Radar extends StatefulWidget {
  const Radar({super.key, required this.icono, this.color = Cv.tealInk, this.tamano = 64});

  final IconData icono;
  final Color color;
  final double tamano;

  @override
  State<Radar> createState() => _RadarState();
}

class _RadarState extends State<Radar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c
        ..stop()
        ..value = 0.4;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.tamano,
        height: widget.tamano,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) => CustomPaint(painter: _RadarPainter(_c.value, widget.color)),
              ),
            ),
            Container(
              width: widget.tamano * 0.56,
              height: widget.tamano * 0.56,
              decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
              child: Icon(widget.icono, color: Colors.white, size: widget.tamano * 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final centro = s.center(Offset.zero);
    final minimo = s.shortestSide * 0.28;
    final maximo = s.shortestSide * 0.5;
    for (var k = 0; k < 3; k++) {
      final p = (t + k / 3) % 1;
      canvas.drawCircle(
        centro,
        minimo + (maximo - minimo) * p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color.withValues(alpha: (1 - p) * 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.t != t || old.color != color;
}

/// Una parada de [RutaPasos].
class PasoRuta {
  const PasoRuta({required this.titulo, required this.color, this.texto, this.icono, this.numero});

  final String titulo;
  final String? texto;
  final Color color;

  /// En el nodo va el ícono o, si no hay, el número.
  final IconData? icono;
  final String? numero;
}

/// Pasos unidos por una línea punteada, como las paradas de una ruta.
class RutaPasos extends StatelessWidget {
  const RutaPasos({super.key, required this.pasos, this.nodo = 38});

  final List<PasoRuta> pasos;
  final double nodo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < pasos.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: nodo,
                  child: Column(
                    children: [
                      _nodo(pasos[i]),
                      if (i < pasos.length - 1)
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Center(child: LineaPunteada(vertical: true, grosor: 2)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: (nodo - 24) / 2, bottom: i < pasos.length - 1 ? 18 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pasos[i].titulo, style: t.titleMedium),
                        if (pasos[i].texto != null) ...[
                          const SizedBox(height: 2),
                          Text(pasos[i].texto!, style: t.bodyMedium?.copyWith(color: Cv.inkMuted)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _nodo(PasoRuta p) {
    return Container(
      width: nodo,
      height: nodo,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: p.color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: p.icono != null
          ? Icon(p.icono, color: Colors.white, size: nodo * 0.5)
          : Text(
              p.numero ?? '',
              style: TextStyle(fontFamily: 'BarlowCondensed', fontSize: nodo * 0.58, fontWeight: FontWeight.w800, color: Colors.white, height: 1),
            ),
    );
  }
}

/// Cuenta regresiva al domingo: un anillo con la cinta de colores que se va llenando.
class AnilloCuenta extends StatelessWidget {
  const AnilloCuenta({super.key, required this.dias, this.tamano = 78});

  /// Días que faltan; 0 o menos es "hoy".
  final int dias;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final hoy = dias <= 0;
    final progreso = hoy ? 1.0 : (7 - dias.clamp(1, 7)) / 7;
    return Semantics(
      label: hoy ? 'Es hoy' : 'Faltan $dias ${dias == 1 ? 'día' : 'días'}',
      child: ExcludeSemantics(
        child: SizedBox(
          width: tamano,
          height: tamano,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(child: CustomPaint(painter: _AnilloPainter(progreso))),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hoy ? '¡Hoy!' : '$dias',
                    style: TextStyle(
                      fontFamily: 'BarlowCondensed',
                      fontWeight: FontWeight.w800,
                      fontSize: hoy ? 20 : 30,
                      height: 1,
                      color: Colors.white,
                    ),
                  ),
                  if (!hoy)
                    Text(
                      dias == 1 ? 'día' : 'días',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white70),
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

class _AnilloPainter extends CustomPainter {
  const _AnilloPainter(this.progreso);

  final double progreso;

  @override
  void paint(Canvas canvas, Size s) {
    final rect = (Offset.zero & s).deflate(4);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.white.withValues(alpha: 0.14),
    );
    if (progreso <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progreso.clamp(0.02, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          colors: [Cv.teal, Cv.verde, Cv.coral, Cv.rojo, Cv.teal],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_AnilloPainter old) => old.progreso != progreso;
}

/// El momento "¡Match!": una tarjeta que aparece con un estallido en los cuatro colores.
Future<void> celebrar(
  BuildContext context, {
  required String titulo,
  required String texto,
  required IconData icono,
  Color color = Cv.verdeInk,
  String boton = '¡De una!',
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (ctx, _, __) => _Celebracion(titulo: titulo, texto: texto, icono: icono, color: color, boton: boton),
    transitionBuilder: (ctx, anim, _, child) {
      final curva = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween<double>(begin: 0.85, end: 1).animate(curva), child: child),
      );
    },
  );
}

class _Celebracion extends StatefulWidget {
  const _Celebracion({required this.titulo, required this.texto, required this.icono, required this.color, required this.boton});

  final String titulo;
  final String texto;
  final IconData icono;
  final Color color;
  final String boton;

  @override
  State<_Celebracion> createState() => _CelebracionState();
}

class _CelebracionState extends State<_Celebracion> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Material(
            color: Cv.surfaceRaised,
            borderRadius: BorderRadius.circular(Cv.radioXl),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 170,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _c,
                          builder: (_, __) => CustomPaint(painter: _EstallidoPainter(_c.value)),
                        ),
                      ),
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: widget.color,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
                        ),
                        child: Icon(widget.icono, color: Colors.white, size: 42),
                      ),
                    ],
                  ),
                ),
                const Cinta(alto: 6),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.titulo,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 36, fontWeight: FontWeight.w800, color: Cv.ink, height: 1),
                      ),
                      const SizedBox(height: 8),
                      Text(widget.texto, textAlign: TextAlign.center, style: t.bodyLarge),
                      const SizedBox(height: 18),
                      FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(widget.boton)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EstallidoPainter extends CustomPainter {
  const _EstallidoPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size s) {
    final centro = s.center(Offset.zero);
    final e = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
    final alfa = (1 - t) * 0.85 + 0.15;
    // anillo que se abre
    canvas.drawCircle(
      centro,
      46 + 44 * e,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Cv.coral.withValues(alpha: (1 - e) * 0.5),
    );
    // rayos en los cuatro colores de la cinta
    for (var i = 0; i < 16; i++) {
      final angulo = i * math.pi * 2 / 16 + 0.2;
      final dir = Offset(math.cos(angulo), math.sin(angulo));
      final desde = 52 + 26 * e;
      final hasta = desde + (i.isEven ? 16 : 9) + 8 * e;
      canvas.drawLine(
        centro + dir * desde,
        centro + dir * hasta,
        Paint()
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = Cv.cinta[i % 4].withValues(alpha: alfa),
      );
    }
  }

  @override
  bool shouldRepaint(_EstallidoPainter old) => old.t != t;
}
