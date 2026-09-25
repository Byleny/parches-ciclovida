import 'package:flutter/material.dart';

import '../api.dart';
import '../notificaciones.dart';
import '../sesion.dart';
import '../theme.dart';
import 'principal.dart';

/// Volver a entrar: el mismo correo institucional del registro y un código nuevo.
/// La cuenta es la misma de siempre; no se crea nada.
class IngresoScreen extends StatefulWidget {
  const IngresoScreen({super.key});

  @override
  State<IngresoScreen> createState() => _IngresoScreenState();
}

class _IngresoScreenState extends State<IngresoScreen> {
  final _correo = TextEditingController();
  final _codigo = TextEditingController();

  String? _correoEnviado;
  String? _universidad;
  String? _codigoDemo;
  bool _ocupado = false;

  @override
  void dispose() {
    _correo.dispose();
    _codigo.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _pedirCodigo() async {
    FocusScope.of(context).unfocus();
    setState(() => _ocupado = true);
    try {
      final r = await Sesion.actual.api.pedirCodigo(_correo.text.trim(), para: 'ingreso');
      if (!mounted) return;
      setState(() {
        _correoEnviado = _correo.text.trim();
        _universidad = r.universidad;
        _codigoDemo = r.codigoDemo;
        _codigo.clear();
      });
    } on ApiException catch (e) {
      _aviso(e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    setState(() => _ocupado = true);
    try {
      final r = await Sesion.actual.api.ingresar(correo: _correoEnviado!, codigo: _codigo.text.trim());
      await Sesion.actual.guardarToken(r.token);
      await Notificaciones.pedirPermiso();
      await Notificaciones.programarSemana();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const PrincipalScreen()),
        (route) => false,
      );
    } on ApiException catch (e) {
      _aviso(e.mensaje);
      if (mounted) setState(() => _ocupado = false);
    }
  }

  bool get _puedeEntrar =>
      _correoEnviado != null && _correoEnviado == _correo.text.trim() && _codigo.text.trim().length == 6;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final enviado = _correoEnviado != null && _correoEnviado == _correo.text.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Ya tengo cuenta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text('Entra con tu correo', style: t.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Escribe el correo institucional con el que te registraste y te enviamos un código nuevo. '
            'Tu perfil y tus parches siguen intactos.',
            style: t.bodyMedium?.copyWith(color: Cv.inkMuted),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _correo,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Correo institucional', hintText: 'tu@usbcali.edu.co'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _ocupado || _correo.text.trim().isEmpty ? null : _pedirCodigo,
            child: Text(enviado ? 'Enviarme otro código' : 'Enviarme el código'),
          ),
          if (enviado) ...[
            const SizedBox(height: 18),
            if (_universidad != null)
              Row(
                children: [
                  const Icon(Icons.verified, size: 18, color: Cv.verdeInk),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_universidad!, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                ],
              ),
            if (_codigoDemo != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Card(
                  color: Cv.coralSoft,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Modo demo, sin servidor de correo: tu código es $_codigoDemo',
                        style: t.bodyMedium?.copyWith(color: Cv.coralInk, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _codigo,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Código de 6 dígitos', counterText: ''),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _ocupado || !_puedeEntrar ? null : _entrar,
              child: const Text('Entrar'),
            ),
          ],
        ],
      ),
    );
  }
}
