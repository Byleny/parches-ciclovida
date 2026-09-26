import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../sesion.dart';
import '../theme.dart';
import '../widgets/comunes.dart';

/// Quiz "Tu estilo de parche": 5 preguntas rápidas y en tono de domingo.
/// Es opcional, no muestra resultados ni etiquetas, y solo sirve para que el
/// sistema desempate entre grupos con gente que disfruta el plan como tú.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.quiz});

  final QuizInfo quiz;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final Map<int, String> _respuestas = {};
  bool _enviando = false;

  bool get _completo => widget.quiz.preguntas.every((p) => _respuestas.containsKey(p.id));

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    try {
      final mensaje = await Sesion.actual.api.responderQuiz(_respuestas);
      if (!mounted) return;
      Navigator.of(context).pop(mensaje);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final quiz = widget.quiz;
    final respondidas = _respuestas.length;
    return Scaffold(
      appBar: AppBar(title: Text(quiz.titulo)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: '$respondidas de ${quiz.preguntas.length} respondidas',
              child: Cinta(alto: 6, llenos: (respondidas * 4 / quiz.preguntas.length).ceil()),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text(quiz.detalle, style: t.bodyMedium?.copyWith(color: Cv.inkMuted)),
                  const SizedBox(height: 8),
                  for (var i = 0; i < quiz.preguntas.length; i++) ...[
                    const SizedBox(height: 14),
                    _Pregunta(
                      numero: i + 1,
                      pregunta: quiz.preguntas[i],
                      elegida: _respuestas[quiz.preguntas[i].id],
                      onElegir: (opcion) => setState(() => _respuestas[quiz.preguntas[i].id] = opcion),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Tus respuestas no se muestran a nadie: ni a tu grupo, ni a la Alcaldía. '
                    'Solo las usa el sistema para armarte un parche más afín.',
                    textAlign: TextAlign.center,
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                onPressed: _completo && !_enviando ? _enviar : null,
                child: Text(_completo
                    ? '¡Listo, ese soy yo!'
                    : 'Te ${quiz.preguntas.length - respondidas == 1 ? 'falta 1' : 'faltan ${quiz.preguntas.length - respondidas}'}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pregunta extends StatelessWidget {
  const _Pregunta({required this.numero, required this.pregunta, required this.elegida, required this.onElegir});

  final int numero;
  final QuizPregunta pregunta;
  final String? elegida;
  final ValueChanged<String> onElegir;

  @override
  Widget build(BuildContext context) {
    final color = Cv.cinta[(numero - 1) % Cv.cinta.length];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(
                '$numero',
                style: const TextStyle(fontFamily: 'BarlowCondensed', fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(pregunta.texto, style: Theme.of(context).textTheme.titleMedium)),
          ],
        ),
        const SizedBox(height: 8),
        for (final o in pregunta.opciones)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Seleccionable(
              titulo: o.texto,
              seleccionado: elegida == o.id,
              onTap: () => onElegir(o.id),
            ),
          ),
      ],
    );
  }
}
