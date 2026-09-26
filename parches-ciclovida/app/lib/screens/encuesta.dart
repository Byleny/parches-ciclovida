import 'package:flutter/material.dart';

import '../api.dart';
import '../formato.dart';
import '../models.dart';
import '../sesion.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import '../widgets/diseno.dart';
import '../widgets/selectores.dart';

/// Después del domingo: ¿fuiste?, ¿cómo te sentiste del 1 al 5?, ¿volverías?
class EncuestaScreen extends StatefulWidget {
  const EncuestaScreen({super.key, required this.info});

  final EncuestaInfo info;

  @override
  State<EncuestaScreen> createState() => _EncuestaScreenState();
}

class _EncuestaScreenState extends State<EncuestaScreen> {
  bool? _asistio;
  int? _bienestar;
  bool? _volveria;
  bool _enviando = false;

  bool get _valida => _asistio != null && _volveria != null;

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    try {
      await Sesion.actual.api.enviarEncuesta(
        asistio: _asistio!,
        volveria: _volveria!,
        bienestar: _asistio! ? _bienestar : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final grupo = widget.info.grupoNombre ?? 'tu parche';
    return Scaffold(
      appBar: AppBar(title: const Text('¿Cómo te fue?')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: rellenoAncho(context, arriba: 8, abajo: 24),
                children: [
                  BloqueColor(
                    color: Cv.brisaCoral,
                    borde: Cv.coralSoft,
                    relleno: const EdgeInsets.all(14),
                    radio: Cv.radioMd,
                    child: Row(
                      children: [
                        const IconoBurbuja(Icons.rate_review_outlined, color: Cv.coralInk, fondo: Colors.white, tamano: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Domingo ${fechaCorta(widget.info.jornadaFecha)} con el $grupo',
                            style: t.titleMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const TituloSeccion('¿Fuiste a la CicloVida con tu parche?'),
                  SiNo(
                    valor: _asistio,
                    si: 'Sí, fui',
                    no: 'No fui',
                    onChanged: (v) => setState(() => _asistio = v),
                  ),
                  if (_asistio == true) ...[
                    const TituloSeccion(
                      '¿Cómo te sentiste? (opcional)',
                      ayuda: '1 es muy mal y 5 es muy bien. Puedes dejarla sin responder.',
                    ),
                    EscalaBienestar(
                      valor: _bienestar,
                      // tocar de nuevo el mismo número lo desmarca
                      onChanged: (v) => setState(() => _bienestar = _bienestar == v ? null : v),
                    ),
                  ],
                  const TituloSeccion('¿Volverías el próximo domingo?'),
                  SiNo(valor: _volveria, onChanged: (v) => setState(() => _volveria = v)),
                ],
              ),
            ),
            BarraInferior(
              child: FilledButton(
                onPressed: _valida && !_enviando ? _enviar : null,
                child: _enviando
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Cv.tealInk))
                    : const Text('Enviar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Escala de 1 a 5. El número y la palabra siempre se ven: no depende del color.
class EscalaBienestar extends StatelessWidget {
  const EscalaBienestar({super.key, required this.valor, required this.onChanged});

  static const etiquetas = ['Muy mal', 'Mal', 'Regular', 'Bien', 'Muy bien'];

  final int? valor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 1; i <= 5; i++)
          Expanded(
            child: Semantics(
              button: true,
              selected: valor == i,
              label: '$i, ${etiquetas[i - 1]}',
              child: InkWell(
                borderRadius: BorderRadius.circular(Cv.radioMd),
                onTap: () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: valor == i ? Cv.tealInk : Cv.surfaceRaised,
                          border: Border.all(color: valor == i ? Cv.tealInk : Cv.lineStrong, width: 2),
                          boxShadow: valor == i ? Cv.brillo(Cv.tealInk) : null,
                        ),
                        child: Text(
                          '$i',
                          style: TextStyle(
                            fontFamily: Cv.display,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: valor == i ? Colors.white : Cv.ink,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        etiquetas[i - 1],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: valor == i ? Cv.tealInk : Cv.inkMuted,
                          fontWeight: valor == i ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
