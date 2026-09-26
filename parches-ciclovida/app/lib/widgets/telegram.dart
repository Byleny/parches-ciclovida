import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../models.dart';
import '../sesion.dart';
import '../theme.dart';

/// Tarjeta para vincular el bot de Telegram: por ahí llega el aviso cuando
/// la lista de espera encuentra parche. Si el backend no tiene bot, no se muestra.
class TarjetaTelegram extends StatefulWidget {
  const TarjetaTelegram({super.key});

  @override
  State<TarjetaTelegram> createState() => _TarjetaTelegramState();
}

class _TarjetaTelegramState extends State<TarjetaTelegram> {
  TelegramInfo? _info;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final info = await Sesion.actual.api.telegram();
      if (mounted) setState(() => _info = info);
    } on ApiException {
      // sin conexión o sin bot: la tarjeta simplemente no aparece
    }
  }

  Future<void> _abrir() async {
    final enlace = _info?.enlace;
    if (enlace == null) return;
    final ok = await launchUrl(Uri.parse(enlace), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Abre este enlace en tu teléfono: $enlace')),
      );
    }
    // al volver de Telegram, refresca para mostrar el vínculo
    Future<void>.delayed(const Duration(seconds: 3), _cargar);
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null || !info.disponible) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return Card(
      color: Cv.tealSoft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 22,
              backgroundColor: Cv.tealInk,
              child: Icon(Icons.telegram, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.vinculado ? 'Telegram conectado' : 'Conecta Telegram',
                    style: t.titleMedium?.copyWith(color: Cv.tealInk),
                  ),
                  Text(
                    info.vinculado
                        ? 'Desde el chat puedes elegir parche, confirmar y publicar en el foro.'
                        : 'Te avisamos por ahí, y desde el chat eliges parche, confirmas y publicas en el foro.',
                    style: t.bodySmall?.copyWith(color: Cv.ink),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (info.vinculado)
              const Icon(Icons.check_circle, color: Cv.verdeInk, size: 28)
            else
              FilledButton(
                onPressed: info.enlace == null ? null : _abrir,
                style: FilledButton.styleFrom(
                  backgroundColor: Cv.tealInk,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: const Text('Conectar'),
              ),
          ],
        ),
      ),
    );
  }
}
