# Parches CicloVida

Prototipo TRL 3 del equipo Dedsec para el reto CicloVida del Hackathon Smart City Expo Cali 2026.

Un estudiante universitario de Cali verifica su correo institucional y crea su perfil. Cada semana el sistema abre parches en las 12 estaciones de la CicloVida, uno por hora (8:00, 9:30, 11:00) y actividad (bici, patines, trotar, caminar). Al entrar, un match automático (la misma idea de distancia del k-means) lo une al parche que ya tiene gente con su hora, estación y actividad; si no existe, queda en lista de espera y se le avisa —en la app y por Telegram— apenas aparezca, con parches parecidos como plan B. También puede elegir a mano, ver las zonas en un mapa interactivo y comentar en el foro comunal. El sábado a las 5:00 p. m. un algoritmo k-means divide a la gente de cada parche en grupos de 3 a 6 y a las 7:00 p. m. le llega la notificación para confirmar. Ese es el momento en que decide si sale el domingo. Al terminar la jornada, la app le pregunta si fue, si volvería y, de forma opcional, cómo se sintió del 1 al 5. La Secretaría ve un tablero web solo con cifras agregadas por comuna y por grupo.

```
parches-ciclovida/
├── app/        App móvil en Flutter (Android, iOS y web para proyectar)
└── backend/    FastAPI + SQLite: registro, emparejamiento, encuestas, tablero web
```

## Qué pide el reto y dónde está

| Requisito TRL 3 | Dónde |
|---|---|
| Registro con correo institucional | `app/lib/screens/registro.dart`, `POST /api/verificacion`, `POST /api/jovenes`, `backend/app/verificacion.py` |
| Volver a entrar (login) | `app/lib/screens/ingreso.dart`, `POST /api/verificacion` con `para: "ingreso"`, `POST /api/sesiones` |
| Match automático de parche | `POST /api/yo/match`, `emparejar_automatico` en `backend/app/services.py` |
| Lista de espera con aviso | `revisar_esperas` (tick cada 5 min), `GET /api/yo/notificaciones`, bot de Telegram en `backend/app/telegram.py` |
| Parches generados por el sistema | `GET /api/parches`, `POST /api/yo/parche`, `app/lib/screens/elegir_parche.dart` |
| Agrupamiento con k-means | `backend/app/matching.py` (funciones puras, con pruebas) |
| Notificaciones | `app/lib/notificaciones.dart`: sábado 7:00 p. m. y domingo 1:30 p. m., cada semana |
| Mapa interactivo de zonas | `app/lib/screens/mapa.dart` (flutter_map + OpenStreetMap, 12 estaciones) |
| Foro comunal | `GET/POST /api/foro`, `app/lib/screens/foro.dart` |
| Historial de domingos | `GET /api/yo/historial`, `app/lib/screens/historial.dart` (a qué parches fue y con quién) |
| Quiz "Tu estilo de parche" | `POST /api/yo/quiz`, `QUIZ_PREGUNTAS` en `backend/app/catalog.py`, `app/lib/screens/quiz.dart` |
| Base de datos | SQLite con SQLModel, `backend/app/models.py` |
| Tablero | `http://localhost:8000/tablero/`, `backend/static/tablero/` |

## Match automático, espera y Telegram

Al entrar sin parche, la app ya no muestra una lista para escoger: llama a `POST /api/yo/match` y el
sistema une al joven al parche que **ya tiene gente** con sus mismas características (misma actividad
y, si las declaró, misma estación y hora), eligiendo el más afín con la misma idea de distancia del
k-means (hora, ritmo mediano del parche, cercanía de comuna, tamaño). Siempre puede tocar
"Prefiero elegir yo" y escoger a mano.

Si no existe ninguno, la app muestra un **popup** con el parche más parecido —aunque esté vacío—
por si quiere tomar la iniciativa y estrenarlo ("Unirme igual"); si prefiere esperar, queda en
**lista de espera**: el scheduler la revisa cada 5 minutos y, apenas alguien compatible se inscribe,
lo une y le avisa dentro de la app y por Telegram. Pasados
`ESPERA_MINUTOS` (10 por defecto), la app le muestra además parches parecidos o disponibles para que
no siga esperando si no quiere.

### Anclar el bot de Telegram (5 minutos)

1. En Telegram, habla con **@BotFather** → `/newbot` → dale un nombre y un usuario (p. ej.
   `ParchesCicloVidaBot`). Te entrega un **token**.
2. `cd backend && copy .env.example .env` y pega el token en `TELEGRAM_TOKEN=`. Nada más:
   el `@` del bot se detecta solo con `getMe`, y el menú de comandos se registra al arrancar.
3. Reinicia el backend. En el log debe salir `Bot de Telegram listo: @TuBot`; también puedes
   verificar con `GET /api/admin/telegram` (dice si está configurado, el `@` y cuántas cuentas
   se han vinculado, y qué falta si algo no cuadra).
4. En la app, toca **Conectar Telegram** (tarjeta de espera o Ajustes): se abre
   `t.me/<bot>?start=<código>` y el backend vincula el chat. El bot revisa sus mensajes cada
   20 segundos.

Sin token, todo lo de Telegram se apaga solo y queda el aviso interno de la app.

El bot empata las funciones de la app en el chat (`backend/app/telegram.py`):

| En el chat | Qué hace |
|---|---|
| `/parche` | Tu estado del domingo. Si aún no tienes parche, corre el match; si quedas en espera, te propone el que más se ajusta con botones **Unirme**, **Ver otras opciones** y **Prefiero esperar** |
| `/confirmo` / `/novoy` | Lo mismo que el botón de confirmar de la app (también son botones en el aviso del sábado) |
| `/foro` | Publicar en el foro: escribes el mensaje y eliges el tema con un botón. Leer el foro es en la app |
| `/ayuda` | La lista de comandos |
| Propuesta de parche | Al entrar en lista de espera: "Hola X, todavía no tenemos parche confirmado… este es el que más se ajusta a tus preferencias" |
| Aviso de match | Cuando tu lista de espera encuentra parche |
| Aviso del sábado | Cuando k-means arma tu grupo, con botones ✅ Confirmo / ❌ No voy |

Cambiarse de un parche a otro sigue siendo solo desde la app, porque deja un cupo libre en un
grupo y la app pide confirmarlo.

### Bot conversacional (Gemini)

Con `GEMINI_API_KEY` en `backend/.env` (se saca en https://aistudio.google.com/apikey), el bot
entiende texto libre: «quiero trotar el domingo temprano por Panamericana», «¿quién va conmigo?»,
«sí, úneme», «publica en el foro que me encantó el parche». Está en `backend/app/asistente.py`:

- **Function calling.** Gemini no responde de memoria: llama a las mismas funciones de la app
  (`ver_mi_estado`, `buscar_parches`, `unirme_a_parche`, `confirmar_asistencia`, `publicar_en_foro`),
  así que nunca inventa parches, horas ni personas. Los parches que menciona también salen como
  botones "Unirme".
- **Reglas en el prompt.** Une o publica solo si el joven lo pidió o aceptó; cambiarse de parche
  solo en la app; ante acoso o riesgo remite a "Reportar un problema" y al 123; ante malestar
  emocional responde con empatía y sin diagnosticar.
- **Memoria corta.** Recuerda los últimos 12 turnos por chat (en memoria); `/cancelar` la borra.
- **Privacidad.** A Gemini van los mensajes que el joven le escribe al bot, su primer nombre y sus
  preferencias; nunca el correo ni la universidad. Quedó declarado en el aviso de privacidad
  (versión `2026-09-25.3`).
- **Sin key**, el texto libre responde con la lista de comandos, y todo lo demás sigue igual.
  Si Gemini falla o no hay red, el bot responde con una salida amable y no se cae.

El modelo es `gemini-2.5-flash` por defecto; se cambia con `GEMINI_MODEL`. `GET /api/admin/telegram`
muestra si el modo conversacional está activo.

## Quiz "Tu estilo de parche" (afinidad, sin etiquetas)

Cinco preguntas cortas en tono de CicloVida ("Termina la CicloVida, ¿cuál es el plan?: ¡jugo y
charla con el parche! / foto y a la casa"). Las dimensiones que mide (plan social, charla, gusto
por lo nuevo, esperar al grupo, madrugar) están inspiradas en dimensiones clásicas de afinidad,
pero sin lenguaje clínico. Reglas de diseño, pedidas por el equipo:

- **Opcional.** Quien no lo responde queda en el punto medio y se agrupa igual por comuna,
  estación, actividad y hora.
- **Criterio secundario.** En k-means pesa 0,2 (menos que ritmo 1,0, edad 0,6 y experiencia 0,4)
  y en el match automático solo desempata entre parches estructuralmente equivalentes.
- **Sin etiquetas.** El servidor no devuelve puntajes ni perfiles: la app solo sabe si ya se
  respondió (`quiz_respondido`). Nadie ve "eres X", ni en su perfil ni en el de otros.
- **Invisible para la Secretaría.** Las respuestas no llegan al tablero ni a ningún endpoint
  de administración.

## Mapa y foro

- **Mapa** (pestaña Mapa): las 12 estaciones sobre OpenStreetMap, con leyenda (verde = con gente,
  azul = aún sin gente, coral = tu parche); el pin muestra cuánta gente va este domingo y la ficha
  trae punto de encuentro, comuna y barrios cercanos, con el botón para ver sus parches.
- **Barrios por comuna**: `BARRIOS_COMUNA` en `backend/app/catalog.py` (barrios de referencia, no la
  lista completa del DAP). Al elegir comuna en el registro o en preferencias, la app muestra abajo
  en pequeño los barrios que cubre; la estación elegida muestra su punto, referencia y barrios cercanos.
- **Foro comunal** (pestaña Foro): mensajes con primer nombre y universidad —lo mismo que ve el
  grupo—, en tres categorías: mis parches, la app y cómo me siento. Cada quien puede borrar solo sus
  mensajes, y todos se borran con el derecho de supresión.

## Ajustes por la evaluación del mentor

- **Mayoría de edad.** En el registro hay una casilla obligatoria "Declaro que tengo 18 años o más";
  sin marcarla no se puede crear la cuenta, y queda constancia (`declara_mayor`, `declara_mayor_en`)
  de que se preguntó y cuándo se aceptó, igual que con el aviso de privacidad.
- **Menores de edad.** El piloto es para jóvenes de 18 a 28 años (`PERMITIR_MENORES=0`). Si se activa, los de 14 a 17 necesitan el nombre y la autorización de su acudiente, y nunca quedan en un grupo con adultos.
- **Hábeas data (Ley 1581 de 2012).** Aviso de privacidad completo en el registro (`backend/app/privacidad.py`). Se guardan la versión del aviso y la fecha de cada autorización. La pregunta de bienestar es opcional porque puede ser un dato sensible. Cada joven puede borrar sus datos desde Ajustes. El aviso es un borrador: hay que completar los datos entre corchetes y hacerlo revisar antes de un piloto real.
- **Marca.** Ni la app ni el tablero usan el escudo de la Alcaldía. Los dos dicen que son un prototipo y no un canal oficial, y el tablero se presenta como insumo, no como decisión. El logo de CicloVida también es de la Alcaldía; si quieren riesgo cero, se reemplaza por uno propio en `app/assets/img/` y `backend/static/tablero/img/`.
- **Riesgo de encuentros entre desconocidos.** Solo se encuentran en estaciones públicas y en horario de CicloVida. El grupo ve el primer nombre, la actividad y si confirmaste, nada más. Hay un botón "Reportar un problema" con la línea 123 visible. Con 2 reportes de personas distintas, la persona sale del emparejamiento hasta que moderación la revise (`GET /api/admin/reportes`).
- **Filtro de confianza.** Solo entran estudiantes de universidades de Cali, verificados con un código de 6 dígitos enviado a su correo institucional (`@usbcali.edu.co`, `@uao.edu.co`, `@correounivalle.edu.co`, `@javerianacali.edu.co`, `@icesi.edu.co`, `@usc.edu.co` y otros en `backend/app/catalog.py`; se aceptan subdominios). El correo no se guarda: solo su huella HMAC, para que no abra dos cuentas, y el nombre de la universidad, que el grupo ve junto al primer nombre. Sin servidor de correo (`SMTP_HOST` vacío), la API devuelve el código en la respuesta para la demo; en un piloto, `CORREO_DEMO=0`.
- **"Si usa IA, expliquen sus variables."** El agrupamiento usa k-means con tres variables y sus pesos, explicadas dentro de la app en Ajustes > Cómo armamos los grupos.

## Cómo se arman los grupos

1. **El sistema abre los parches.** Uno por estación, hora y actividad para cada grupo de edad (144 por domingo). El joven elige; la app le recomienda los de su estación y actividad favoritas.
2. **Nadie queda solo.** El sábado a las 5:00 p. m., quien está en un parche de menos de 3 personas se suma al parche compatible más parecido. Reglas que nunca se relajan: misma estación, menores nunca con mayores, a pie (caminar, trotar) nunca con sobre ruedas (bici, patines), máximo 90 minutos de diferencia. Quien tuvo que ceder algo lo ve escrito en su grupo.
3. **K-means.** Cada parche se parte en grupos de 3 a 6, idealmente 5, con k-means de tamaño balanceado y determinista sobre ritmo (peso 1,0), rango de edad (0,6) y experiencia, es decir, domingos que ya fue (0,4).
4. **Quien llega tarde** se suma al grupo con cupo cuyo centroide está más cerca, o se abre uno nuevo.

Con los datos sintéticos de 260 jóvenes, casi todos los grupos quedan de 3 a 6 personas.

## Correr la demo

### 1. Backend y tablero (Python 3.10 o más)

```bash
cd backend
python -m venv .venv
source .venv/bin/activate          # en Windows: .venv\Scripts\activate
pip install -r requirements.txt
python -m app.seed --reset         # 260 jóvenes sintéticos y 4 domingos pasados
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

- Tablero: http://localhost:8000/tablero/ (muestra un aviso de "datos sintéticos" mientras existan)
- API documentada: http://localhost:8000/docs
- Pruebas: `pytest` (29 pruebas: k-means, correo institucional, flujo completo, anonimato, reportes, permisos)

Variables útiles: `ADMIN_KEY` (por defecto `dedsec-demo`), `SECRETO`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`, `CORREO_DEMO`, `PERMITIR_MENORES`, `REPORTES_PARA_SUSPENDER`, `K_CONTEO`, `GRUPO_MIN`, `GRUPO_MAX`, `DATABASE_URL`, `ESPERA_MINUTOS`, `TELEGRAM_TOKEN`, `TELEGRAM_BOT`, `FORO_MAX`.

### 2. App Flutter (Flutter 3.38.1 o más)

La carpeta `app/` trae el código, los logos y las fuentes, pero no las carpetas `android/` e `ios/`: se generan con tu versión de Flutter.

```bash
cd app
flutter --version                  # 3.38.1 o más; si no: flutter upgrade
flutter create . --project-name parches_ciclovida --org co.dedsec --platforms android,ios,web
python tool/configurar_plataformas.py
flutter pub get
flutter test
```

`configurar_plataformas.py` agrega los permisos, los receivers de notificaciones programadas y el desugaring que pide `flutter_local_notifications`, y permite `http://` en la red local. Se puede correr varias veces.

Para correrla:

```bash
# Emulador de Android: el computador se ve como 10.0.2.2 y ya viene configurado
flutter run

# Celular físico en la misma Wi-Fi que el computador
flutter run --dart-define=API_URL=http://192.168.1.20:8000

# Navegador, para proyectar (las notificaciones se simulan dentro de la app)
flutter run -d chrome
```

La IP también se puede cambiar dentro de la app: botón "Servidor" en la bienvenida o Ajustes > Dirección del servidor.

Probado con Flutter 3.38.9: `flutter analyze` sin problemas, `flutter test` pasa y la versión web completa el flujo de registro, elección de parche y grupos del sábado contra el backend. Android e iOS no se han probado en un dispositivo.

## Guion de demo (3 minutos)

1. **Registro.** Correo `@usbcali.edu.co` y el código (en la demo aparece en pantalla). Luego nombre, edad, comuna 19, bici, ritmo moderado. Mostrar el aviso de privacidad y la autorización.
2. **Match automático.** Al entrar, la app busca sola un parche con gente y esas mismas características. Con los datos sintéticos hay gente inscrita, así que el match une de una; si se quiere mostrar la espera, registrarse con una actividad y estación sin gente, ver la tarjeta "Buscando tu parche…" (y "Conectar Telegram"), inscribir a otra persona compatible desde otro navegador y ver llegar el aviso. También se puede "Elegir yo mismo": filtrar por estación, hora y actividad, y "Unirme".
2b. **Mapa y foro.** Pestaña Mapa: pines con la gente de cada estación y ficha con sus parches. Pestaña Foro: publicar un mensaje en "Mis parches".
3. **El sábado.** En Ajustes > Herramientas de demo: "Armar los grupos del sábado". Luego "Ver el aviso del sábado": llega la notificación y al tocarla se abre el grupo con punto de encuentro, hora, nombres y universidades.
4. **Confirmar.** "Confirmo, voy". Mostrar "Reportar un problema" y "Cómo armamos los grupos".
5. **El domingo.** "Terminar la jornada y abrir encuesta", luego "Ver el aviso de la encuesta" y responderla.
6. **Tablero.** Recargar http://localhost:8000/tablero/ y elegir la jornada: la respuesta ya está en las cifras, sin ningún nombre.

Si preguntan por qué app y no web: la notificación del sábado en la noche llega justo cuando el joven decide si sale el domingo. Una página web no puede avisarle en ese momento.

## Fuentes de datos

Las 12 estaciones de la CicloVida 2026 (Panamericana, El Prado, Torres de Comfandi, El Ingenio, Morichal, Sol de Oriente, Petecuy, Corredor Verde, Las Américas, Brisas de los Álamos, Siloé y La Fortaleza) y el horario de 8:00 a. m. a 1:00 p. m. salen de los boletines de la Alcaldía de Cali. Las direcciones de cada estación salen de El País (mayo de 2025). Las coordenadas del mapa son aproximadas.

- https://www.cali.gov.co/boletines/publicaciones/191401/la-sexta-ciclovida-de-2026-llega-el-domingo-para-el-disfrute-de-calenos-y-visitantes/
- https://www.cali.gov.co/boletines/publicaciones/191512/con-58-kilometros-de-bienestar-cali-vivio-una-nueva-jornada-masiva-de-la-ciclovida/
- https://www.elpais.com.co/cali/este-domingo-18-de-mayo-del-2025-hay-ciclovida-en-cali-esto-es-lo-que-debe-saber-1701.html

## Siguiente paso (TRL 4)

- Notificaciones push desde el servidor con Firebase Cloud Messaging, para avisar también cuando alguien se suma tarde a un parche.
- Validar estaciones, coordenadas y horarios con la Secretaría del Deporte y la Recreación.
- Postgres en lugar de SQLite, autenticación real para el tablero y la moderación.
- Revisión legal del aviso de privacidad y definición del responsable del tratamiento.

Fuentes Barlow y Barlow Condensed bajo licencia SIL Open Font License. Chart.js y Leaflet bajo licencia MIT.
