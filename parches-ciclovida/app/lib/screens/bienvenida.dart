import 'package:flutter/material.dart';

import '../sesion.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import 'registro.dart';

class BienvenidaScreen extends StatelessWidget {
  const BienvenidaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Cv.surfaceRaised,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Image.asset('assets/img/ciclovida-recorte.png', height: 44, semanticLabel: 'CicloVida, Cali en movimiento'),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => dialogoServidor(
                    context,
                    actual: Sesion.actual.apiUrl,
                    guardar: Sesion.actual.cambiarUrl,
                  ),
                  icon: const Icon(Icons.dns_outlined, size: 18),
                  label: const Text('Servidor'),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Semantics(
              header: true,
              label: 'Este domingo sal en parche a la CicloVida',
              child: const ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Franja(texto: 'Este domingo', color: Cv.rojoInk, giro: -0.035),
                    _Franja(texto: 'sal en parche', color: Cv.verdeInk, giro: 0.02, sangria: 22),
                    _Franja(texto: 'a la CicloVida', color: Cv.tealInk, giro: -0.02, sangria: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Cada semana abrimos parches en las 12 estaciones: a pie o sobre ruedas, a las 8:00, 9:30 u 11:00. '
              'Solo para estudiantes de universidades de Cali, verificados con su correo institucional.',
              style: t.bodyLarge,
            ),
            const SizedBox(height: 24),
            const _Paso(numero: '1', texto: 'Verifica tu correo de la universidad y crea tu perfil.', color: Cv.rojo),
            const _Paso(numero: '2', texto: 'Elige tu parche en la lista: hora, actividad y estación.', color: Cv.coral),
            const _Paso(numero: '3', texto: 'El sábado te armamos un grupo de 3 a 6 y confirmas si vas.', color: Cv.verde),
            const _Paso(numero: '4', texto: 'El domingo se encuentran en la estación y arrancan.', color: Cv.teal),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RegistroScreen())),
              child: const Text('Crear mi perfil'),
            ),
            const SizedBox(height: 10),
            Text(
              'Tu grupo solo ve tu primer nombre y tu universidad. Se encuentran siempre en una estación pública.',
              textAlign: TextAlign.center,
              style: t.bodySmall,
            ),
            const SizedBox(height: 28),
            const Cinta(alto: 8, radio: 4),
            const SizedBox(height: 16),
            const PieInstitucional(),
          ],
        ),
      ),
    );
  }
}

/// Una línea del titular sobre una franja de color, levemente girada como un sticker.
class _Franja extends StatelessWidget {
  const _Franja({required this.texto, required this.color, required this.giro, this.sangria = 0});

  final String texto;
  final Color color;
  final double giro;
  final double sangria;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: sangria, bottom: 6),
      child: Transform.rotate(
        angle: giro,
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 4, 16, 6),
          color: color,
          child: Text(
            texto,
            style: const TextStyle(
              fontFamily: 'BarlowCondensed',
              fontWeight: FontWeight.w800,
              fontSize: 50,
              height: 1,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({required this.numero, required this.texto, required this.color});

  final String numero;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(numero, style: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}
