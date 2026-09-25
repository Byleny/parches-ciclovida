typedef Json = Map<String, dynamic>;

class Opcion {
  const Opcion({required this.id, required this.nombre, this.detalle});

  factory Opcion.fromJson(Json j) => Opcion(
        id: j['id'].toString(),
        nombre: j['nombre'] as String,
        detalle: j['detalle'] as String?,
      );

  final String id;
  final String nombre;
  final String? detalle;
}

class Tramo {
  const Tramo({
    required this.id,
    required this.nombre,
    required this.comuna,
    required this.punto,
    required this.referencia,
  });

  factory Tramo.fromJson(Json j) => Tramo(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        comuna: j['comuna'] as int,
        punto: j['punto'] as String,
        referencia: j['referencia'] as String,
      );

  final String id;
  final String nombre;
  final int comuna;
  final String punto;
  final String referencia;
}

class Universidad {
  const Universidad({required this.id, required this.nombre, required this.corto, required this.dominios});

  factory Universidad.fromJson(Json j) => Universidad(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        corto: j['corto'] as String,
        dominios: (j['dominios'] as List).map((e) => e.toString()).toList(),
      );

  final String id;
  final String nombre;
  final String corto;
  final List<String> dominios;
}

class Catalogo {
  const Catalogo({
    required this.comunas,
    required this.tramos,
    required this.actividades,
    required this.ritmos,
    required this.franjas,
    required this.rangosEdad,
    required this.inicio,
    required this.fin,
    required this.proximaJornada,
    required this.permiteMenores,
    required this.motivosReporte,
    this.universidades = const [],
  });

  factory Catalogo.fromJson(Json j) {
    List<Opcion> opciones(String k) =>
        (j[k] as List).map((e) => Opcion.fromJson(e as Json)).toList();
    final jornada = j['jornada'] as Json;
    return Catalogo(
      comunas: (j['comunas'] as List).map((e) => (e as Json)['id'] as int).toList(),
      tramos: (j['tramos'] as List).map((e) => Tramo.fromJson(e as Json)).toList(),
      actividades: opciones('actividades'),
      ritmos: opciones('ritmos'),
      franjas: opciones('franjas'),
      rangosEdad: opciones('rangos_edad'),
      inicio: jornada['inicio'] as String,
      fin: jornada['fin'] as String,
      proximaJornada: j['proxima_jornada'] as String,
      permiteMenores: j['permite_menores'] as bool? ?? false,
      motivosReporte: j['motivos_reporte'] == null ? const <Opcion>[] : opciones('motivos_reporte'),
      universidades: j['universidades'] == null
          ? const <Universidad>[]
          : (j['universidades'] as List).map((e) => Universidad.fromJson(e as Json)).toList(),
    );
  }

  final List<int> comunas;
  final List<Tramo> tramos;
  final List<Opcion> actividades;
  final List<Opcion> ritmos;
  final List<Opcion> franjas;
  final List<Opcion> rangosEdad;
  final String inicio;
  final String fin;
  final String proximaJornada;
  final bool permiteMenores;
  final List<Opcion> motivosReporte;
  final List<Universidad> universidades;

  Tramo? tramo(String id) {
    for (final t in tramos) {
      if (t.id == id) return t;
    }
    return null;
  }

  String nombreDe(List<Opcion> lista, String id) {
    for (final o in lista) {
      if (o.id == id) return o.nombre;
    }
    return id;
  }
}

class Perfil {
  const Perfil({
    required this.id,
    required this.nombre,
    required this.rangoEdad,
    required this.comuna,
    required this.actividad,
    required this.ritmo,
    this.universidad = '',
    this.tramoId,
    this.pausaFecha,
  });

  factory Perfil.fromJson(Json j) => Perfil(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        universidad: j['universidad'] as String? ?? '',
        rangoEdad: j['rango_edad'] as String,
        comuna: j['comuna'] as int,
        tramoId: j['tramo_id'] as String?,
        actividad: j['actividad'] as String,
        ritmo: j['ritmo'] as String,
        pausaFecha: j['pausa_fecha'] as String?,
      );

  final String id;
  final String nombre;

  /// Verificada con el correo institucional.
  final String universidad;
  final String rangoEdad;
  final int comuna;

  /// Estación favorita: solo sirve para recomendar parches.
  final String? tramoId;
  final String actividad;
  final String ritmo;
  final String? pausaFecha;
}

/// Un parche de la lista que genera el sistema. Solo cifras, nunca nombres.
class ParcheOpcion {
  const ParcheOpcion({
    required this.id,
    required this.nombre,
    required this.tramoId,
    required this.tramoNombre,
    required this.puntoEncuentro,
    required this.horaEncuentro,
    required this.horaNombre,
    required this.actividad,
    required this.actividadNombre,
    required this.inscritos,
    required this.esMio,
    required this.paraTi,
    this.universidades = 0,
    this.ritmoNombre,
  });

  factory ParcheOpcion.fromJson(Json j) {
    final tramo = j['tramo'] as Json;
    return ParcheOpcion(
      id: j['id'] as int,
      nombre: j['nombre'] as String,
      tramoId: tramo['id'] as String,
      tramoNombre: tramo['nombre'] as String,
      puntoEncuentro: j['punto_encuentro'] as String,
      horaEncuentro: j['hora_encuentro'] as String,
      horaNombre: j['hora_nombre'] as String,
      actividad: j['actividad'] as String,
      actividadNombre: j['actividad_nombre'] as String,
      inscritos: j['inscritos'] as int,
      universidades: j['universidades'] as int? ?? 0,
      esMio: j['es_mio'] as bool,
      paraTi: j['para_ti'] as bool,
      ritmoNombre: j['ritmo_nombre'] as String?,
    );
  }

  final int id;
  final String nombre;
  final String tramoId;
  final String tramoNombre;
  final String puntoEncuentro;
  final String horaEncuentro;
  final String horaNombre;
  final String actividad;
  final String actividadNombre;
  final int inscritos;

  /// De cuántas universidades distintas es la gente inscrita.
  final int universidades;
  final bool esMio;
  final bool paraTi;

  /// El ritmo más común entre quienes ya se unieron, si hay alguien.
  final String? ritmoNombre;
}

class Miembro {
  const Miembro({
    required this.ref,
    required this.nombre,
    required this.actividad,
    required this.estado,
    required this.soyYo,
    this.universidad = '',
  });

  factory Miembro.fromJson(Json j) => Miembro(
        ref: j['ref'] as int,
        nombre: j['nombre'] as String,
        universidad: j['universidad'] as String? ?? '',
        actividad: j['actividad'] as String,
        estado: j['estado'] as String,
        soyYo: j['soy_yo'] as bool,
      );

  /// Referencia opaca para reportar. No identifica a la persona fuera del parche.
  final int ref;
  final String nombre;

  /// Nombre corto de su universidad (estudiante verificado).
  final String universidad;
  final String actividad;

  /// pendiente | confirmado | declinado
  final String estado;
  final bool soyYo;
}

class Grupo {
  const Grupo({
    required this.id,
    required this.nombre,
    required this.tramoNombre,
    required this.tramoComuna,
    required this.puntoEncuentro,
    required this.referencia,
    required this.horaEncuentro,
    required this.horaNombre,
    required this.actividad,
    required this.actividadNombre,
    required this.ritmo,
    required this.ritmoNombre,
    required this.miembros,
    required this.confirmados,
  });

  factory Grupo.fromJson(Json j) {
    final tramo = j['tramo'] as Json;
    return Grupo(
      id: j['id'] as int,
      nombre: j['nombre'] as String,
      tramoNombre: tramo['nombre'] as String,
      tramoComuna: tramo['comuna'] as int,
      puntoEncuentro: j['punto_encuentro'] as String,
      referencia: j['referencia'] as String,
      horaEncuentro: j['hora_encuentro'] as String,
      horaNombre: j['hora_nombre'] as String,
      actividad: j['actividad'] as String,
      actividadNombre: j['actividad_nombre'] as String,
      ritmo: j['ritmo'] as String,
      ritmoNombre: j['ritmo_nombre'] as String,
      miembros: (j['miembros'] as List).map((e) => Miembro.fromJson(e as Json)).toList(),
      confirmados: j['confirmados'] as int,
    );
  }

  final int id;
  final String nombre;
  final String tramoNombre;
  final int tramoComuna;
  final String puntoEncuentro;
  final String referencia;
  final String horaEncuentro;
  final String horaNombre;
  final String actividad;
  final String actividadNombre;
  final String ritmo;
  final String ritmoNombre;
  final List<Miembro> miembros;
  final int confirmados;
}

class EncuestaInfo {
  const EncuestaInfo({required this.jornadaFecha, required this.respondida, this.grupoNombre});

  factory EncuestaInfo.fromJson(Json j) => EncuestaInfo(
        jornadaFecha: j['jornada_fecha'] as String,
        grupoNombre: j['grupo_nombre'] as String?,
        respondida: j['respondida'] as bool,
      );

  final String jornadaFecha;
  final String? grupoNombre;
  final bool respondida;
}

class EstadoParche {
  const EstadoParche({
    required this.jornadaFecha,
    required this.jornadaEstado,
    required this.inicio,
    required this.fin,
    required this.estado,
    required this.ajustes,
    required this.tarde,
    this.miRespuesta,
    this.salida,
    this.grupo,
    this.encuesta,
  });

  factory EstadoParche.fromJson(Json j) {
    final jornada = j['jornada'] as Json;
    return EstadoParche(
      jornadaFecha: jornada['fecha'] as String,
      jornadaEstado: jornada['estado'] as String,
      inicio: jornada['inicio'] as String,
      fin: jornada['fin'] as String,
      estado: j['estado'] as String,
      miRespuesta: j['mi_respuesta'] as String?,
      ajustes: (j['ajustes'] as List).map((e) => e.toString()).toList(),
      tarde: j['tarde'] as bool? ?? false,
      salida: j['salida'] == null ? null : ParcheOpcion.fromJson(j['salida'] as Json),
      grupo: j['grupo'] == null ? null : Grupo.fromJson(j['grupo'] as Json),
      encuesta: j['encuesta'] == null ? null : EncuestaInfo.fromJson(j['encuesta'] as Json),
    );
  }

  final String jornadaFecha;
  final String jornadaEstado;
  final String inicio;
  final String fin;

  /// sin_parche (aún no elige) | inscrito (eligió; el grupo se arma el sábado) | asignado | pausado | suspendido
  final String estado;

  /// pendiente | confirmado | declinado (solo si está asignado)
  final String? miRespuesta;
  final List<String> ajustes;
  final bool tarde;

  /// El parche que eligió de la lista.
  final ParcheOpcion? salida;

  /// Su grupo de 3 a 6 dentro del parche, desde el sábado.
  final Grupo? grupo;
  final EncuestaInfo? encuesta;

  bool get encuestaPendiente => encuesta != null && !encuesta!.respondida;
}

class SeccionAviso {
  const SeccionAviso(this.titulo, this.texto);

  final String titulo;
  final String texto;
}

class AvisoPrivacidad {
  const AvisoPrivacidad({required this.version, required this.titulo, required this.secciones});

  factory AvisoPrivacidad.fromJson(Json j) => AvisoPrivacidad(
        version: j['version'] as String,
        titulo: j['titulo'] as String,
        secciones: (j['secciones'] as List).map((e) {
          final m = e as Json;
          return SeccionAviso(m['titulo'] as String, m['texto'] as String);
        }).toList(),
      );

  final String version;
  final String titulo;
  final List<SeccionAviso> secciones;
}
