import 'package:flutter/material.dart';

import '../theme.dart';

/// Transparencia del agrupamiento: qué hace k-means y con qué variables.
class ComoArmamosScreen extends StatelessWidget {
  const ComoArmamosScreen({super.key});

  static const _pasos = [
    ('Tú eliges el parche', 'Cada semana abrimos un parche por estación, hora y actividad. Tú escoges cuál.', Cv.rojo),
    (
      'Nadie queda por fuera',
      'El sábado a las 5:00 p. m., si tu parche no llegó a 3 personas, te sumamos al parche compatible más parecido: '
          'misma estación, a pie o sobre ruedas igual que tú y máximo 90 minutos de diferencia. Te lo decimos en la app.',
      Cv.coral,
    ),
    (
      'K-means arma los grupos',
      'Dentro de cada parche, un algoritmo k-means reparte a la gente en grupos de 3 a 6, idealmente 5, '
          'juntando a quienes se parecen en tres variables.',
      Cv.verde,
    ),
    ('Te avisamos', 'A las 7:00 p. m. te llega tu grupo: primeros nombres, universidad y quién confirmó.', Cv.teal),
  ];

  static const _variables = [
    ('Ritmo', 'Tranquilo, moderado o rápido. Es la que más pesa: 1,0.'),
    ('Rango de edad', '18 a 22 o 23 a 28. Pesa 0,6.'),
    ('Experiencia', 'Cuántos domingos has ido con tu parche, hasta 3. Pesa 0,4.'),
    (
      'Tu estilo de parche (opcional)',
      'El quiz de 5 preguntas de gustos. Es solo un desempate (pesa 0,2, menos que todo lo demás): '
          'si no lo respondes quedas en el punto medio y te agrupamos igual. Nadie ve tus respuestas '
          'ni ninguna etiqueta, y no llegan al tablero de la Alcaldía.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Cómo armamos los grupos')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            for (var i = 0; i < _pasos.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _pasos[i].$3, shape: BoxShape.circle),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_pasos[i].$1, style: t.titleMedium),
                          const SizedBox(height: 2),
                          Text(_pasos[i].$2, style: t.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Las variables de k-means', style: t.headlineSmall),
                    const SizedBox(height: 4),
                    Text('Solo estas, cada una de 0 a 1 multiplicada por su peso:', style: t.bodySmall),
                    const SizedBox(height: 10),
                    for (final v in _variables)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.$1, style: t.titleMedium),
                            Text(v.$2, style: t.bodyMedium),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Es un algoritmo de agrupamiento, no una caja negra: cualquiera puede revisar el código y repetir el '
              'resultado, porque con los mismos datos siempre arma los mismos grupos. Las reglas de estación, '
              'edad y actividad nunca las cambia.',
              style: t.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'No usamos tu ubicación, tu foto, tu comuna, tu universidad ni tus datos de contacto para armar los grupos.',
              style: t.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
