import 'package:flutter/material.dart';

/// Tokens del design system "Parches CicloVida".
/// Los cuatro colores salen de las letras V, I, D, A del logo; la tinta, del gris de "CICLO".
/// Cada color tiene tres tonos: `marca` para acentos, `Ink` para fondos con texto blanco
/// y para texto sobre blanco (contraste AA), y `Soft` para fondos tenues.
class Cv {
  static const surface = Color(0xFFF3F4F6);
  static const surfaceRaised = Color(0xFFFFFFFF);
  static const line = Color(0xFFE3E4E8);
  static const lineStrong = Color(0xFF9A9CA3);
  static const ink = Color(0xFF1D1E22);
  static const inkMuted = Color(0xFF5E6068);

  static const rojo = Color(0xFFE4253F);
  static const coral = Color(0xFFF26B21);
  static const verde = Color(0xFF19A85B);
  static const teal = Color(0xFF0B9BC4);

  static const rojoInk = Color(0xFFB8162E);
  static const coralInk = Color(0xFFB0460B);
  static const verdeInk = Color(0xFF0B7A3F);
  static const tealInk = Color(0xFF06708F);

  static const rojoSoft = Color(0xFFFDE6E9);
  static const coralSoft = Color(0xFFFFEBDD);
  static const verdeSoft = Color(0xFFDDF5E7);
  static const tealSoft = Color(0xFFDBF2FA);

  static const cinta = [rojo, coral, verde, teal];

  static const radioMd = 14.0;
  static const radioLg = 22.0;
}

/// Cada actividad lleva uno de los cuatro colores del logo.
class ColoresActividad {
  const ColoresActividad(this.marca, this.tinta, this.suave);

  /// Acento: puntos, bordes, la cinta.
  final Color marca;

  /// Fondo para texto blanco, o texto sobre blanco o sobre [suave].
  final Color tinta;

  /// Fondo tenue.
  final Color suave;
}

ColoresActividad coloresDe(String actividad) {
  switch (actividad) {
    case 'bici':
      return const ColoresActividad(Cv.teal, Cv.tealInk, Cv.tealSoft);
    case 'trotar':
      return const ColoresActividad(Cv.coral, Cv.coralInk, Cv.coralSoft);
    case 'caminar':
      return const ColoresActividad(Cv.verde, Cv.verdeInk, Cv.verdeSoft);
    case 'patines':
      return const ColoresActividad(Cv.rojo, Cv.rojoInk, Cv.rojoSoft);
    default:
      return const ColoresActividad(Cv.inkMuted, Cv.ink, Cv.surface);
  }
}

IconData iconoDe(String actividad) {
  switch (actividad) {
    case 'bici':
      return Icons.directions_bike;
    case 'trotar':
      return Icons.directions_run;
    case 'caminar':
      return Icons.directions_walk;
    case 'patines':
      return Icons.roller_skating;
    default:
      return Icons.circle_outlined;
  }
}

/// La cinta de cuatro colores, como la pintura del carril de la CicloVida.
/// Con [llenos] funciona como barra de progreso: los tramos que faltan van en gris.
class Cinta extends StatelessWidget {
  const Cinta({super.key, this.alto = 6, this.llenos = 4, this.radio = 0});

  final double alto;
  final int llenos;
  final double radio;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: SizedBox(
        height: alto,
        child: Row(
          children: [
            for (var i = 0; i < 4; i++)
              Expanded(child: ColoredBox(color: i < llenos ? Cv.cinta[i] : Cv.line)),
          ],
        ),
      ),
    );
  }
}

ThemeData temaParches() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: Cv.ink,
    onPrimary: Colors.white,
    primaryContainer: Cv.tealSoft,
    onPrimaryContainer: Cv.tealInk,
    secondary: Cv.tealInk,
    onSecondary: Colors.white,
    secondaryContainer: Cv.tealSoft,
    onSecondaryContainer: Cv.tealInk,
    error: Cv.rojoInk,
    onError: Colors.white,
    surface: Cv.surfaceRaised,
    onSurface: Cv.ink,
    onSurfaceVariant: Cv.inkMuted,
    outline: Cv.lineStrong,
    outlineVariant: Cv.line,
    surfaceContainerHighest: Cv.surface,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Barlow',
    scaffoldBackgroundColor: Cv.surface,
  );

  const boton = TextStyle(fontFamily: 'Barlow', fontSize: 17, fontWeight: FontWeight.w700);
  const pastilla = StadiumBorder();

  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: Cv.ink, displayColor: Cv.ink)
        .merge(const TextTheme(
          displaySmall: TextStyle(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w800, fontSize: 46, height: 0.95),
          headlineLarge: TextStyle(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w800, fontSize: 38, height: 1.0),
          headlineMedium: TextStyle(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w800, fontSize: 32, height: 1.0),
          headlineSmall: TextStyle(fontFamily: 'BarlowCondensed', fontWeight: FontWeight.w700, fontSize: 25, height: 1.05),
          titleLarge: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, height: 1.25),
          titleMedium: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, height: 1.3),
          bodyLarge: TextStyle(fontSize: 17, height: 1.4),
          bodyMedium: TextStyle(fontSize: 15, height: 1.4),
          bodySmall: TextStyle(fontSize: 13, height: 1.35, color: Cv.inkMuted),
          labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        )),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: pastilla,
        textStyle: boton,
        backgroundColor: Cv.ink,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Cv.line,
        disabledForegroundColor: Cv.lineStrong,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: pastilla,
        textStyle: boton,
        foregroundColor: Cv.ink,
        side: const BorderSide(color: Cv.ink, width: 2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Cv.tealInk,
        textStyle: const TextStyle(fontFamily: 'Barlow', fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: const CardThemeData(
      color: Cv.surfaceRaised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Cv.radioLg))),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Cv.surface,
      foregroundColor: Cv.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'BarlowCondensed', fontSize: 26, fontWeight: FontWeight.w800, color: Cv.ink),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(side: BorderSide(color: Cv.line)),
      backgroundColor: Cv.surfaceRaised,
      labelStyle: const TextStyle(fontFamily: 'Barlow', fontSize: 15, fontWeight: FontWeight.w600, color: Cv.ink),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      showCheckmark: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Cv.surfaceRaised,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Cv.radioMd),
        borderSide: const BorderSide(color: Cv.lineStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Cv.radioMd),
        borderSide: const BorderSide(color: Cv.lineStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Cv.radioMd),
        borderSide: const BorderSide(color: Cv.tealInk, width: 2),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Cv.tealInk),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Cv.verdeInk : null),
    ),
    dividerTheme: const DividerThemeData(color: Cv.line, thickness: 1, space: 24),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Cv.surfaceRaised,
      indicatorColor: Cv.tealSoft,
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? Cv.tealInk : Cv.inkMuted),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: 'Barlow',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: s.contains(WidgetState.selected) ? Cv.tealInk : Cv.inkMuted,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Cv.ink,
      shape: StadiumBorder(),
      contentTextStyle: TextStyle(fontFamily: 'Barlow', fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
    ),
  );
}
