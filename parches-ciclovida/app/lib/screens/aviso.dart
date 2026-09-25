import 'package:flutter/material.dart';

import '../api.dart';
import '../models.dart';
import '../sesion.dart';
import '../widgets/comunes.dart';

/// Aviso de privacidad completo (Ley 1581 de 2012). El texto vive en el backend.
class AvisoPrivacidadScreen extends StatefulWidget {
  const AvisoPrivacidadScreen({super.key});

  @override
  State<AvisoPrivacidadScreen> createState() => _AvisoPrivacidadScreenState();
}

class _AvisoPrivacidadScreenState extends State<AvisoPrivacidadScreen> {
  AvisoPrivacidad? _aviso;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (_error != null) setState(() => _error = null);
    try {
      final a = await Sesion.actual.api.avisoPrivacidad();
      if (!mounted) return;
      setState(() => _aviso = a);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = _aviso;
    return Scaffold(
      appBar: AppBar(title: const Text('Aviso de privacidad')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            if (_error != null) TarjetaError(mensaje: _error!, reintentar: _cargar),
            if (a == null && _error == null) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
            if (a != null) ...[
              for (final s in a.secciones) ...[
                const SizedBox(height: 16),
                Text(s.titulo, style: t.titleMedium),
                const SizedBox(height: 4),
                Text(s.texto, style: t.bodyMedium),
              ],
              const SizedBox(height: 24),
              Text('Versión ${a.version}', style: t.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
