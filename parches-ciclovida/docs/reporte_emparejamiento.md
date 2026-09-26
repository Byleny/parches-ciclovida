# Reporte del emparejamiento · domingo 20 de septiembre de 2026

> Solo se muestran el estilo de parche y el perfil de los jóvenes simulados. De las personas reales no se exporta ni el nombre ni las respuestas del quiz. No es para el tablero. Generado con `python -m app.reporte`.

## Resumen

| | |
|---|---|
| Personas con grupo | 1.217 |
| Grupos | 256 |
| En grupos de 3 a 6 | 100,0 % |
| Solos / grupos de 2 | 0 / 0 |
| Cambiaron de hora o actividad para completar grupo | 22 |
| Respondieron el quiz (simulados) | 858 |

| Actividad | Personas | En grupos de 3 o más |
|---|---|---|
| Bici | 475 | 100,0 % |
| Caminar | 388 | 100,0 % |
| Patines | 169 | 100,0 % |
| Trotar | 185 | 100,0 % |

## ¿Sirve el quiz?

k-means dividió **78 parches** (1.000 personas). Al quitar el quiz, a **315** de ellas les cambia el grupo.

| Grupos armados… | Afinidad de estilo | Mismo ritmo |
|---|---|---|
| con el quiz (como funciona la app) | **65,9 %** | **80,1 %** |
| sin el quiz | 64,9 % | 80,0 % |
| al azar | 61,0 % | 60,4 % |

Pesos de k-means: ritmo 1,0, edad 0,6, experiencia 0,4 y quiz 0,2 por pregunta (se cambia con `PESO_QUIZ`).

_Solo cuenta los parches que k-means dividió (7 personas o más; con 3 a 6 queda un solo grupo). Afinidad de estilo: entre los simulados que respondieron el quiz, qué parte de cada grupo comparte el perfil más común del grupo. Mismo ritmo: qué parte de cada grupo va al ritmo más común del grupo. Se compara con armar los mismos grupos sin el quiz y al azar (promedio de 30 sorteos)._

## Ejemplos: grupos de parches que k-means dividió (primeros 6)

### Parche Chiminango A · Las Américas · 11:00 a. m. · Bici (5 personas)

- Mismo parche: estación Las Américas, 11:00 a. m., bici.
- Ritmo: todos van a ritmo tranquilo.
- Edad: todos entre 18 y 22 años.
- Experiencia: de 0 a 1 domingos con parche.
- Estilo, entre quienes respondieron el quiz: «En mi mundo, gozándome el paisaje» (4 de 4); «Llegando justo con la salida» (4 de 4); «Foto del grupo y a la casa» (3 de 4).

| Integrante | Perfil (simulado) | Ritmo | Edad | Domingos | Quiz 1 a 5 | Distancia al centro |
|---|---|---|---|---|---|---|
| Gabriela | Contemplativo | tranquilo | 18 a 22 | 0 | b·b·a·a·b | 0,10 |
| Samuel | Contemplativo | tranquilo | 18 a 22 | 0 | b·b·b·b·b | 0,21 |
| Tatiana | Contemplativo | tranquilo | 18 a 22 | 0 | c·b·a·a·b | 0,11 |
| Mateo | Contemplativo | tranquilo | 18 a 22 | 0 | — | 0,14 |
| Santiago | Contemplativo | tranquilo | 18 a 22 | 1 | b·b·a·a·b | 0,14 |

### Parche Chiminango B · Las Américas · 11:00 a. m. · Bici (5 personas)

- Mismo parche: estación Las Américas, 11:00 a. m., bici.
- Ritmo: 2 de 5 van a ritmo tranquilo.
- Edad: 3 de 5 entre 18 y 22 años.
- Experiencia: de 0 a 2 domingos con parche.
- Estilo, entre quienes respondieron el quiz: «¡Jugo y charla con el parche!» (4 de 5); «Echando cuento todo el camino» (4 de 5); «Paramos todos: nadie se queda» (4 de 5).

| Integrante | Perfil (simulado) | Ritmo | Edad | Domingos | Quiz 1 a 5 | Distancia al centro |
|---|---|---|---|---|---|---|
| Alejandro | Parchadito social | tranquilo | 18 a 22 | 2 | a·a·b·a·b | 0,60 |
| Laura | Parchadito social | tranquilo | 23 a 28 | 0 | a·a·a·a·b | 0,63 |
| Kevin | Contemplativo | moderado | 18 a 22 | 0 | a·a·a·a·b | 0,28 |
| Nicolás | Deportista | rápido | 18 a 22 | 0 | b·b·b·b·a | 0,66 |
| Luisa | Parchadito social | rápido | 23 a 28 | 1 | a·a·a·a·b | 0,63 |

### Parche Chiminango C · Las Américas · 11:00 a. m. · Bici (4 personas)

- Mismo parche: estación Las Américas, 11:00 a. m., bici.
- Ritmo: todos van a ritmo moderado.
- Edad: todos entre 23 y 28 años.
- Experiencia: de 0 a 2 domingos con parche.
- Estilo, entre quienes respondieron el quiz: «Paramos todos: nadie se queda» (3 de 3); «Foto del grupo y a la casa» (2 de 3); «Echando cuento todo el camino» (2 de 3).

| Integrante | Perfil (simulado) | Ritmo | Edad | Domingos | Quiz 1 a 5 | Distancia al centro |
|---|---|---|---|---|---|---|
| Sebastián | Contemplativo | moderado | 23 a 28 | 0 | — | 0,16 |
| Andrés | Contemplativo | moderado | 23 a 28 | 1 | b·b·a·a·b | 0,21 |
| Vanessa | Parchadito social | moderado | 23 a 28 | 1 | a·a·b·a·a | 0,21 |
| Óscar | Parchadito social | moderado | 23 a 28 | 2 | b·a·b·a·b | 0,20 |

### Parche Samán A · Petecuy · 9:30 a. m. · Caminar (5 personas)

- Mismo parche: estación Petecuy, 9:30 a. m., caminar.
- Ritmo: 4 de 5 van a ritmo tranquilo.
- Edad: 4 de 5 entre 23 y 28 años.
- Experiencia: de 0 a 2 domingos con parche.
- Estilo, entre quienes respondieron el quiz: «En mi mundo, gozándome el paisaje» (4 de 4); «Llegando justo con la salida» (4 de 4); «Foto del grupo y a la casa» (3 de 4).

| Integrante | Perfil (simulado) | Ritmo | Edad | Domingos | Quiz 1 a 5 | Distancia al centro |
|---|---|---|---|---|---|---|
| Luisa | Parchadito social | tranquilo | 18 a 22 | 0 | a·b·b·a·b | 0,57 |
| Kevin | Contemplativo | tranquilo | 23 a 28 | 0 | b·b·a·b·b | 0,33 |
| Andrés | Contemplativo | tranquilo | 23 a 28 | 1 | b·b·b·a·b | 0,27 |
| Cristian | Contemplativo | tranquilo | 23 a 28 | 2 | b·b·a·a·b | 0,30 |
| Brayan | Madrugador cumplido | rápido | 23 a 28 | 2 | — | 0,83 |

### Parche Samán B · Petecuy · 9:30 a. m. · Caminar (5 personas)

- Mismo parche: estación Petecuy, 9:30 a. m., caminar.
- Ritmo: 4 de 5 van a ritmo moderado.
- Edad: todos entre 18 y 22 años.
- Experiencia: de 0 a 2 domingos con parche.
- Estilo, entre quienes respondieron el quiz: «Paramos todos: nadie se queda» (3 de 3); «Hace rato en la estación» (3 de 3); «Foto del grupo y a la casa» (2 de 3).

| Integrante | Perfil (simulado) | Ritmo | Edad | Domingos | Quiz 1 a 5 | Distancia al centro |
|---|---|---|---|---|---|---|
| Sara | Madrugador cumplido | moderado | 18 a 22 | 0 | c·c·a·a·a | 0,20 |
| Sebastián | Contemplativo | moderado | 18 a 22 | 0 | — | 0,19 |
| Sofía | Contemplativo | moderado | 18 a 22 | 2 | b·b·a·a·a | 0,22 |
| Mateo | Madrugador cumplido | moderado | 18 a 22 | 2 | b·c·b·a·a | 0,22 |
| Kevin | Parchadito social | rápido | 18 a 22 | 1 | — | 0,41 |

### Parche Samán C · Petecuy · 9:30 a. m. · Caminar (4 personas)

- Mismo parche: estación Petecuy, 9:30 a. m., caminar.
- Ritmo: todos van a ritmo moderado.
- Edad: todos entre 23 y 28 años.
- Experiencia: de 0 a 1 domingos con parche.
- Estilo, entre quienes respondieron el quiz: «Depende de cómo esté el ambiente» (2 de 2); «Un rato de charla, un rato de silencio» (2 de 2); «La de siempre, a la fija» (2 de 2).

| Integrante | Perfil (simulado) | Ritmo | Edad | Domingos | Quiz 1 a 5 | Distancia al centro |
|---|---|---|---|---|---|---|
| Brayan | Parchadito social | moderado | 23 a 28 | 0 | — | 0,12 |
| Julián | Madrugador cumplido | moderado | 23 a 28 | 1 | c·c·a·b·a | 0,13 |
| Esteban | Madrugador cumplido | moderado | 23 a 28 | 1 | c·c·a·a·a | 0,13 |
| Melissa | Parchadito social | moderado | 23 a 28 | 1 | — | 0,08 |

### Parche Chiminango A · Sol de Oriente · 9:30 a. m. · Bici (5 personas)

- Mismo parche: estación Sol de Oriente, 9:30 a. m., bici.
- 1 llegó de otro parche de la misma estación para que nadie quedara solo (cambio de actividad).
- Ritmo: 3 de 5 van a ritmo tranquilo.
- Edad: todos entre 18 y 22 años.
- Experiencia: de 0 a 3 domingos con parche.
- Estilo, entre quienes respondieron el quiz: «¡Nueva! A ver qué aparece» (4 de 5); «Foto del grupo y a la casa» (3 de 5); «En mi mundo, gozándome el paisaje» (3 de 5).

| Integrante | Perfil (simulado) | Ritmo | Edad | Domingos | Quiz 1 a 5 | Distancia al centro |
|---|---|---|---|---|---|---|
| Paula | Parchadito social | tranquilo | 18 a 22 | 0 | c·a·b·a·b | 0,43 |
| Óscar | Parchadito social | tranquilo | 18 a 22 | 2 | c·c·b·a·b | 0,33 |
| Óscar | Contemplativo | tranquilo | 18 a 22 | 3 | b·b·a·a·b | 0,40 |
| Julián | Deportista | moderado | 18 a 22 | 2 | b·b·b·b·a | 0,28 |
| Alejandro | Deportista | rápido | 18 a 22 | 2 | b·b·b·b·a | 0,72 |

### Parche Chiminango B · Sol de Oriente · 9:30 a. m. · Bici (5 personas)

- Mismo parche: estación Sol de Oriente, 9:30 a. m., bici.
- Ritmo: todos van a ritmo moderado.
- Edad: todos entre 18 y 22 años.
- Experiencia: de 0 a 1 domingos con parche.
- Estilo, entre quienes respondieron el quiz: «La de siempre, a la fija» (3 de 3); «Paramos todos: nadie se queda» (3 de 3); «Llegando justo con la salida» (3 de 3).

| Integrante | Perfil (simulado) | Ritmo | Edad | Domingos | Quiz 1 a 5 | Distancia al centro |
|---|---|---|---|---|---|---|
| Melissa | Contemplativo | moderado | 18 a 22 | 0 | b·b·a·a·b | 0,13 |
| Yeimi | Madrugador cumplido | moderado | 18 a 22 | 0 | — | 0,12 |
| Vanessa | Contemplativo | moderado | 18 a 22 | 0 | a·c·a·a·b | 0,15 |
| Valentina | Contemplativo | moderado | 18 a 22 | 1 | b·b·a·a·b | 0,15 |
| Cristian | Contemplativo | moderado | 18 a 22 | 1 | — | 0,14 |

### Parche Chiminango C · Sol de Oriente · 9:30 a. m. · Bici (5 personas)

- Mismo parche: estación Sol de Oriente, 9:30 a. m., bici.
- 1 llegó de otro parche de la misma estación para que nadie quedara solo (cambio de actividad).
- Ritmo: 3 de 5 van a ritmo tranquilo.
- Edad: todos entre 23 y 28 años.
- Experiencia: de 0 a 2 domingos con parche.
- Estilo, entre quienes respondieron el quiz: «Paramos todos: nadie se queda» (5 de 5); «Echando cuento todo el camino» (4 de 5); «Llegando justo con la salida» (4 de 5).

| Integrante | Perfil (simulado) | Ritmo | Edad | Domingos | Quiz 1 a 5 | Distancia al centro |
|---|---|---|---|---|---|---|
| Cristian | Contemplativo | tranquilo | 23 a 28 | 0 | b·b·a·a·a | 0,34 |
| Anderson | Contemplativo | tranquilo | 23 a 28 | 0 | c·a·a·a·b | 0,25 |
| Juan | Parchadito social | tranquilo | 23 a 28 | 2 | a·a·a·a·b | 0,29 |
| Óscar | Parchadito social | moderado | 23 a 28 | 0 | b·a·b·a·b | 0,36 |
| Karen | Parchadito social | moderado | 23 a 28 | 2 | a·a·b·a·b | 0,38 |

### Parche Samán A · La Fortaleza · 8:00 a. m. · Caminar (6 personas)

- Mismo parche: estación La Fortaleza, 8:00 a. m., caminar.
- Ritmo: 4 de 6 van a ritmo tranquilo.
- Edad: 5 de 6 entre 23 y 28 años.
- Experiencia: de 0 a 3 domingos con parche.
- Estilo, entre quienes respondieron el quiz: «La de siempre, a la fija» (3 de 4); «Paramos todos: nadie se queda» (3 de 4).

| Integrante | Perfil (simulado) | Ritmo | Edad | Domingos | Quiz 1 a 5 | Distancia al centro |
|---|---|---|---|---|---|---|
| Vanessa | Contemplativo | tranquilo | 18 a 22 | 1 | b·b·a·a·b | 0,57 |
| Ángela | Madrugador cumplido | tranquilo | 23 a 28 | 1 | c·a·a·a·a | 0,26 |
| Sebastián | Parchadito social | tranquilo | 23 a 28 | 1 | a·a·b·a·a | 0,30 |
| Andrés | Contemplativo | tranquilo | 23 a 28 | 3 | a·b·a·b·b | 0,38 |
| Luisa | Madrugador cumplido | moderado | 23 a 28 | 0 | — | 0,38 |
| Miguel | Parchadito social | moderado | 23 a 28 | 1 | — | 0,35 |

### Parche Samán B · La Fortaleza · 8:00 a. m. · Caminar (6 personas)

- Mismo parche: estación La Fortaleza, 8:00 a. m., caminar.
- Ritmo: 5 de 6 van a ritmo moderado.
- Edad: todos entre 18 y 22 años.
- Experiencia: de 0 a 2 domingos con parche.
- Estilo, entre quienes respondieron el quiz: «La de siempre, a la fija» (3 de 3); «Paramos todos: nadie se queda» (3 de 3); «Depende de cómo esté el ambiente» (2 de 3).

| Integrante | Perfil (simulado) | Ritmo | Edad | Domingos | Quiz 1 a 5 | Distancia al centro |
|---|---|---|---|---|---|---|
| Jhon | Parchadito social | moderado | 18 a 22 | 0 | — | 0,14 |
| Camila | Madrugador cumplido | moderado | 18 a 22 | 0 | c·a·a·a·b | 0,18 |
| Paula | Madrugador cumplido | moderado | 18 a 22 | 1 | — | 0,12 |
| Alejandro | Madrugador cumplido | moderado | 18 a 22 | 1 | — | 0,12 |
| Brayan | Madrugador cumplido | moderado | 18 a 22 | 2 | c·c·a·a·b | 0,23 |
| Manuela | Madrugador cumplido | rápido | 18 a 22 | 0 | b·c·a·a·a | 0,46 |

### Parche Chiminango A · Siloé · 8:00 a. m. · Trotar (4 personas)

- Mismo parche: estación Siloé, 8:00 a. m., trotar.
- Ritmo: 3 de 4 van a ritmo moderado.
- Edad: todos entre 18 y 22 años.
- Experiencia: de 0 a 2 domingos con parche.
- Estilo, entre quienes respondieron el quiz: «Un rato de charla, un rato de silencio» (3 de 3); «Paramos todos: nadie se queda» (3 de 3); «Hace rato en la estación» (3 de 3).

| Integrante | Perfil (simulado) | Ritmo | Edad | Domingos | Quiz 1 a 5 | Distancia al centro |
|---|---|---|---|---|---|---|
| Duván | Deportista | tranquilo | 18 a 22 | 2 | b·c·b·a·a | 0,43 |
| Manuela | Madrugador cumplido | moderado | 18 a 22 | 0 | — | 0,19 |
| Paula | Madrugador cumplido | moderado | 18 a 22 | 0 | a·c·b·a·a | 0,21 |
| Melissa | Madrugador cumplido | moderado | 18 a 22 | 1 | c·c·a·a·a | 0,18 |

### Parche Chiminango B · Siloé · 8:00 a. m. · Trotar (4 personas)

- Mismo parche: estación Siloé, 8:00 a. m., trotar.
- Ritmo: todos van a ritmo moderado.
- Edad: todos entre 23 y 28 años.
- Experiencia: de 1 a 3 domingos con parche.
- Estilo, entre quienes respondieron el quiz: «Paramos todos: nadie se queda» (3 de 4); «Hace rato en la estación» (3 de 4).

| Integrante | Perfil (simulado) | Ritmo | Edad | Domingos | Quiz 1 a 5 | Distancia al centro |
|---|---|---|---|---|---|---|
| Gabriela | Contemplativo | moderado | 23 a 28 | 1 | b·b·a·a·b | 0,22 |
| Juan | Madrugador cumplido | moderado | 23 a 28 | 1 | c·c·b·a·a | 0,17 |
| Felipe | Madrugador cumplido | moderado | 23 a 28 | 2 | c·c·a·b·a | 0,20 |
| Laura | Deportista | moderado | 23 a 28 | 3 | b·b·b·a·a | 0,22 |

### Parche Gualanday A · Siloé · 8:00 a. m. · Caminar (6 personas)

- Mismo parche: estación Siloé, 8:00 a. m., caminar.
- Ritmo: 5 de 6 van a ritmo tranquilo.
- Edad: todos entre 18 y 22 años.
- Experiencia: de 0 a 2 domingos con parche.
- Estilo, entre quienes respondieron el quiz: «¡Nueva! A ver qué aparece» (4 de 5); «Paramos todos: nadie se queda» (4 de 5); «Llegando justo con la salida» (4 de 5).

| Integrante | Perfil (simulado) | Ritmo | Edad | Domingos | Quiz 1 a 5 | Distancia al centro |
|---|---|---|---|---|---|---|
| Yeimi | Contemplativo | tranquilo | 18 a 22 | 0 | b·b·a·b·b | 0,35 |
| Óscar | Parchadito social | tranquilo | 18 a 22 | 0 | a·c·b·a·b | 0,25 |
| Mariana | Contemplativo | tranquilo | 18 a 22 | 2 | b·c·b·a·b | 0,26 |
| Nicolás | Parchadito social | tranquilo | 18 a 22 | 2 | a·a·b·a·b | 0,26 |
| Sofía | Parchadito social | tranquilo | 18 a 22 | 2 | a·a·b·a·a | 0,29 |
| Sofía | Madrugador cumplido | rápido | 18 a 22 | 0 | — | 0,85 |

### Parche Gualanday B · Siloé · 8:00 a. m. · Caminar (6 personas)

- Mismo parche: estación Siloé, 8:00 a. m., caminar.
- Ritmo: 5 de 6 van a ritmo moderado.
- Edad: todos entre 18 y 22 años.
- Experiencia: de 0 a 2 domingos con parche.
- Estilo, entre quienes respondieron el quiz: «Paramos todos: nadie se queda» (5 de 5); «Hace rato en la estación» (5 de 5); «Depende de cómo esté el ambiente» (4 de 5).

| Integrante | Perfil (simulado) | Ritmo | Edad | Domingos | Quiz 1 a 5 | Distancia al centro |
|---|---|---|---|---|---|---|
| Felipe | Madrugador cumplido | moderado | 18 a 22 | 0 | c·c·a·a·a | 0,15 |
| Mateo | Madrugador cumplido | moderado | 18 a 22 | 1 | b·c·b·a·a | 0,19 |
| Miguel | Madrugador cumplido | moderado | 18 a 22 | 1 | c·b·a·a·a | 0,13 |
| Juan | Madrugador cumplido | moderado | 18 a 22 | 1 | — | 0,16 |
| Luisa | Madrugador cumplido | moderado | 18 a 22 | 2 | c·c·a·a·a | 0,19 |
| Brayan | Madrugador cumplido | rápido | 18 a 22 | 0 | c·c·a·a·a | 0,43 |

### Parche Gualanday C · Siloé · 8:00 a. m. · Caminar (5 personas)

- Mismo parche: estación Siloé, 8:00 a. m., caminar.
- Ritmo: 4 de 5 van a ritmo moderado.
- Edad: todos entre 23 y 28 años.
- Experiencia: de 0 a 2 domingos con parche.
- Estilo, entre quienes respondieron el quiz: «Paramos todos: nadie se queda» (4 de 4); «Un rato de charla, un rato de silencio» (3 de 4); «Llegando justo con la salida» (3 de 4).

| Integrante | Perfil (simulado) | Ritmo | Edad | Domingos | Quiz 1 a 5 | Distancia al centro |
|---|---|---|---|---|---|---|
| Jhon | Contemplativo | tranquilo | 23 a 28 | 2 | b·c·a·a·b | 0,46 |
| Karen | Madrugador cumplido | moderado | 23 a 28 | 0 | c·c·a·a·a | 0,23 |
| Vanessa | Madrugador cumplido | moderado | 23 a 28 | 0 | — | 0,17 |
| Ángela | Madrugador cumplido | moderado | 23 a 28 | 0 | c·c·b·a·b | 0,19 |
| Anderson | Parchadito social | moderado | 23 a 28 | 2 | a·a·b·a·b | 0,26 |

