import 'package:flutter/material.dart';

import '../formato.dart';
import '../models.dart';
import '../theme.dart';

/// La racha de domingos y el clima del domingo, lado a lado. Sin pronóstico, la racha ocupa todo.
class RachaYClima extends StatelessWidget {
  const RachaYClima({super.key, required this.racha, this.clima});

  final Racha racha;
  final Clima? clima;

  @override
  Widget build(BuildContext context) {
    final c = clima;
    if (c == null) return _TarjetaRacha(racha: racha);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _TarjetaRacha(racha: racha)),
          const SizedBox(width: 12),
          Expanded(child: _TarjetaClima(clima: c)),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.fondo, required this.children});

  final Color fondo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(Cv.radioMd)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.icono, required this.color, required this.valor});

  final IconData icono;
  final Color color;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, color: color, size: 30),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            valor,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: Cv.display,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _TarjetaRacha extends StatelessWidget {
  const _TarjetaRacha({required this.racha});

  final Racha racha;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final n = racha.actual;
    final String titulo;
    final String detalle;
    if (n > 0) {
      titulo = n == 1 ? 'domingo seguido' : 'domingos seguidos';
      detalle = racha.mejor > n
          ? 'Tu mejor racha: ${racha.mejor}. ¡Ve por ella!'
          : 'Si vas este domingo, llegas a ${n + 1}.';
    } else if (racha.total > 0) {
      titulo = 'Retoma tu racha';
      detalle = 'Tu mejor racha fue de ${racha.mejor}. Arranca otra este domingo.';
    } else {
      titulo = 'Empieza tu racha';
      detalle = 'Cada domingo que vayas a tu parche suma uno.';
    }
    return Semantics(
      label: n > 0 ? 'Racha: $n $titulo. $detalle' : '$titulo. $detalle',
      excludeSemantics: true,
      child: _Mini(
        fondo: Cv.coralSoft,
        children: [
          _Cifra(icono: Icons.local_fire_department, color: n > 0 ? Cv.coralInk : Cv.inkMuted, valor: '$n'),
          const SizedBox(height: 6),
          Text(
            titulo,
            style: t.titleSmall?.copyWith(color: Cv.ink, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(detalle, style: t.bodySmall),
        ],
      ),
    );
  }
}

class _TarjetaClima extends StatelessWidget {
  const _TarjetaClima({required this.clima});

  final Clima clima;

  static IconData _icono(String icono) => switch (icono) {
    'sol' => Icons.wb_sunny_outlined,
    'nubes_sol' => Icons.wb_cloudy_outlined,
    'lluvia' => Icons.umbrella_outlined,
    'tormenta' => Icons.thunderstorm_outlined,
    _ => Icons.cloud_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      label:
          'Clima del domingo a las ${horaBonita(clima.hora)}: ${clima.cielo}, ${clima.temperatura} grados, '
          '${clima.lluvia} por ciento de lluvia. ${clima.consejo}',
      excludeSemantics: true,
      child: _Mini(
        fondo: Cv.tealSoft,
        children: [
          _Cifra(icono: _icono(clima.icono), color: Cv.tealInk, valor: '${clima.temperatura}°'),
          const SizedBox(height: 6),
          Text(
            '${clima.cielo} · ${clima.lluvia} % lluvia',
            style: t.titleSmall?.copyWith(color: Cv.ink, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text('A las ${horaBonita(clima.hora)}. ${clima.consejo}', style: t.bodySmall),
        ],
      ),
    );
  }
}
