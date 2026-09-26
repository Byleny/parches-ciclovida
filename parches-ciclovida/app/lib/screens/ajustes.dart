import 'package:flutter/material.dart';

import '../api.dart';
import '../notificaciones.dart';
import '../sesion.dart';
import '../theme.dart';
import '../widgets/comunes.dart';
import '../widgets/telegram.dart';
import 'aviso.dart';
import 'como_armamos.dart';
import 'historial.dart';

/// Ajustes del joven y, al final, las herramientas para la demo con jurados.
/// Devuelve 'borrado' si la persona borró sus datos.
class AjustesScreen extends StatefulWidget {
  const AjustesScreen({super.key, required this.onPreferencias, this.onQuiz});

  final Future<void> Function() onPreferencias;
  final Future<void> Function()? onQuiz;

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  late final TextEditingController _clave = TextEditingController(text: Sesion.actual.claveAdmin);
  bool _ocupado = false;

  @override
  void dispose() {
    _clave.dispose();
    super.dispose();
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _demo(Future<String> Function(String clave) accion) async {
    setState(() => _ocupado = true);
    try {
      await Sesion.actual.guardarClave(_clave.text);
      _aviso(await accion(_clave.text.trim()));
    } on ApiException catch (e) {
      _aviso(e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<String> _armar(String clave) async {
    final r = await Sesion.actual.api.adminArmarGrupos(clave);
    return 'K-means armó ${r['grupos']} grupos con ${r['emparejados']} estudiantes. '
        '${r['movidos']} se sumaron a otro parche y ${r['solos']} quedaron sin compañía.';
  }

  Future<String> _terminar(String clave) async {
    final r = await Sesion.actual.api.adminFinalizar(clave);
    return 'Jornada del ${r['finalizada']} terminada. Ya se puede responder la encuesta.';
  }

  Future<void> _borrar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar tus datos?'),
        content: const Text('Se borra tu perfil, tus parches y tus encuestas. No se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Cv.rojoInk),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Sesion.actual.api.borrarMisDatos();
      if (!mounted) return;
      Navigator.of(context).pop('borrado');
    } on ApiException catch (e) {
      _aviso(e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _Grupo(
            children: [
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Cambiar mis preferencias'),
                subtitle: const Text('Actividad, ritmo y estación cercana'),
                onTap: widget.onPreferencias,
              ),
              if (widget.onQuiz != null)
                ListTile(
                  leading: const Icon(Icons.local_drink_outlined),
                  title: const Text('Tu estilo de parche'),
                  subtitle: const Text('El quiz de 5 preguntas. Puedes cambiarlo cuando quieras'),
                  onTap: widget.onQuiz,
                ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Mis domingos'),
                subtitle: const Text('A qué parches has ido y con quién'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HistorialScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Volver a activar los avisos'),
                subtitle: const Text('Sábado 7:00 p. m. y domingo 1:30 p. m.'),
                onTap: () async {
                  final ok = await Notificaciones.pedirPermiso();
                  await Notificaciones.programarSemana();
                  _aviso(ok || !Notificaciones.soportadas
                      ? 'Avisos programados.'
                      : 'Activa las notificaciones de Parches CicloVida en los ajustes del teléfono.');
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          const TarjetaTelegram(),
          const SizedBox(height: 20),
          _Grupo(
            children: [
              ListTile(
                leading: const Icon(Icons.account_tree_outlined),
                title: const Text('Cómo armamos los grupos'),
                subtitle: const Text('K-means y sus tres variables'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ComoArmamosScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Aviso de privacidad'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AvisoPrivacidadScreen())),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Herramientas de demo', style: t.titleMedium),
          const SizedBox(height: 4),
          Text('Para mostrar el ciclo completo sin esperar al fin de semana.', style: t.bodySmall),
          const SizedBox(height: 10),
          _Grupo(
            children: [
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: const Text('Ver el aviso del sábado'),
                onTap: () => Notificaciones.probar(context, avisoSabado),
              ),
              ListTile(
                leading: const Icon(Icons.rate_review_outlined),
                title: const Text('Ver el aviso de la encuesta'),
                onTap: () => Notificaciones.probar(context, avisoDomingo),
              ),
              ListTile(
                leading: const Icon(Icons.dns_outlined),
                title: const Text('Dirección del servidor'),
                subtitle: Text(Sesion.actual.apiUrl),
                onTap: () async {
                  await dialogoServidor(context, actual: Sesion.actual.apiUrl, guardar: Sesion.actual.cambiarUrl);
                  if (mounted) setState(() {});
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _clave,
                      decoration: const InputDecoration(labelText: 'Clave de administración'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _ocupado ? null : () => _demo(_armar),
                      child: const Text('1. Armar los grupos del sábado'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _ocupado ? null : () => _demo(_terminar),
                      child: const Text('2. Terminar la jornada y abrir encuesta'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _Grupo(
            children: [
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Cv.rojoInk),
                title: const Text('Borrar mis datos', style: TextStyle(color: Cv.rojoInk)),
                subtitle: const Text('Ley 1581 de 2012: puedes pedirlo cuando quieras'),
                onTap: _borrar,
              ),
            ],
          ),
          const SizedBox(height: 32),
          const PieInstitucional(),
        ],
      ),
    );
  }
}

class _Grupo extends StatelessWidget {
  const _Grupo({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
