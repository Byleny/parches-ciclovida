/* Tablero Parches CicloVida: solo lee /api/tablero/*, que ya viene agregado y anonimizado. */
(() => {
  const $ = (s) => document.querySelector(s);
  const css = (v) => getComputedStyle(document.documentElement).getPropertyValue(v).trim();
  const fmt = new Intl.NumberFormat('es-CO');
  const NIVEL = { armado: 'K-means', juntado: 'K-means con gente de otro parche' };
  const ESTADO = {
    finalizada: 'Jornada terminada',
    emparejada: 'Grupos armados, falta el domingo',
    inscripcion: 'Parches abiertos para unirse',
  };
  const CARAS = ['Muy mal', 'Mal', 'Regular', 'Bien', 'Muy bien'];

  let datos = null;
  let grafTendencia = null;
  let mapa = null;
  let capaMapa = null;

  const fechaLarga = (f) => new Date(f + 'T12:00:00').toLocaleDateString('es-CO', { weekday: 'long', day: 'numeric', month: 'long' });
  const fechaCorta = (f) => new Date(f + 'T12:00:00').toLocaleDateString('es-CO', { day: 'numeric', month: 'short' });
  const ND = 's. d.'; // sin dato
  const pct = (v) => (v == null ? ND : `${fmt.format(v)} %`);
  const conteo = (c) => (c.suprimido ? `<${datos.anonimato.k_conteo}` : fmt.format(c.valor));
  const esc = (s) => String(s).replace(/[&<>"]/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[ch]));

  // Servido por el backend, la API está en el mismo sitio; desplegado aparte (Render), config.js
  // trae la dirección del backend.
  const API = String(window.PARCHES_API || '').replace(/\/+$/, '');

  async function getJSON(url) {
    const r = await fetch(API + url);
    if (!r.ok) throw new Error(`${url}: ${r.status}`);
    return r.json();
  }

  async function cargarJornadas() {
    const lista = await getJSON('/api/tablero/jornadas');
    const sel = $('#jornada');
    const actual = sel.value;
    sel.innerHTML = lista.map((j) => `<option value="${j.fecha}">${fechaLarga(j.fecha)}</option>`).join('');
    const porDefecto = (lista.find((j) => j.estado === 'finalizada') || lista[0] || {}).fecha;
    sel.value = actual && lista.some((j) => j.fecha === actual) ? actual : porDefecto;
  }

  async function cargarResumen() {
    const fecha = $('#jornada').value;
    datos = await getJSON(`/api/tablero/resumen${fecha ? `?fecha=${fecha}` : ''}`);
    pintar();
  }

  function pintar() {
    $('#aviso-sintetico').hidden = !datos.datos_sinteticos;
    $('#estado-jornada').textContent = ESTADO[datos.estado] || datos.estado;
    $('#nota-privacidad').textContent =
      `Conteos menores a ${datos.anonimato.k_conteo} se muestran como <${datos.anonimato.k_conteo}. ` +
      `Promedios con menos de ${datos.anonimato.k_promedio} respuestas se ocultan.`;
    pintarKpis();
    pintarEmbudo();
    pintarTendencia();
    pintarComunas();
    pintarMapa();
    pintarBienestar();
    pintarGrupos();
  }

  function pintarKpis() {
    const k = datos.kpis;
    const fueron = datos.embudo.find((e) => e.paso === 'Fueron').valor;
    const sinEncuesta = datos.estado !== 'finalizada';
    const nota = sinEncuesta ? 'La encuesta abre al terminar la jornada' : `${fmt.format(k.respuestas)} respuestas`;
    const tiles = [
      { hero: true, lbl: 'Jóvenes que fueron con su parche', val: sinEncuesta ? ND : fmt.format(fueron), det: sinEncuesta ? nota : `de ${fmt.format(k.emparejados)} que tuvieron parche` },
      { lbl: 'Parches formados', val: fmt.format(k.parches), det: `${fmt.format(k.emparejados)} jóvenes de ${fmt.format(k.inscritos)} inscritos` },
      { lbl: 'Confirmaron el sábado', val: pct(k.confirmacion_pct), det: 'de quienes tuvieron parche' },
      { lbl: 'Fueron', val: pct(k.asistencia_pct), det: nota },
      { lbl: 'Volverían', val: pct(k.volverian_pct), det: nota },
      { lbl: 'Bienestar promedio', val: k.bienestar_promedio == null ? ND : String(k.bienestar_promedio).replace('.', ','), det: 'sobre 5 · pregunta opcional' },
      { lbl: 'Reportes de seguridad', val: fmt.format(k.reportes), det: 'los revisa moderación' },
    ];
    $('#kpis').innerHTML = tiles.map((t) => `
      <div class="kpi${t.hero ? ' hero' : ''}">
        <div class="lbl">${t.lbl}</div>
        <div class="val">${t.val}</div>
        <div class="det">${t.det}</div>
      </div>`).join('');
  }

  function fila(nombre, valor, maximo, etiqueta, { base = null, titulo = '' } = {}) {
    const w = (v) => (maximo ? Math.max(0, (100 * v) / maximo) : 0);
    return `<div class="fila${valor == null && base == null ? ' suprimida' : ''}" title="${esc(titulo)}">
      <span class="nom">${esc(nombre)}</span>
      <span class="pista">
        ${base != null ? `<span class="fill base" style="width:${w(base)}%"></span>` : ''}
        ${valor != null ? `<span class="fill" style="width:${w(valor)}%"></span>` : ''}
      </span>
      <span class="num">${etiqueta}</span>
    </div>`;
  }

  function pintarEmbudo() {
    const total = datos.embudo[0].valor || 0;
    $('#embudo').innerHTML = datos.embudo.map((e, i) => {
      const p = total ? Math.round((100 * e.valor) / total) : 0;
      const et = i === 0 ? fmt.format(e.valor) : `${fmt.format(e.valor)} <small>${p} %</small>`;
      return fila(e.paso, e.valor, total, et, { titulo: `${e.paso}: ${fmt.format(e.valor)}` });
    }).join('');
  }

  function pintarTendencia() {
    const t = datos.tendencia;
    const c1 = css('--data-1');
    const c2 = css('--data-2');
    $('#leyenda-tendencia').innerHTML =
      `<span><i style="background:${c1}"></i>Fueron</span><span><i style="background:${c2}"></i>Volverían</span>`;
    const serie = (label, key, color) => ({
      label, data: t.map((x) => x[key]), borderColor: color, backgroundColor: color,
      borderWidth: 2, pointRadius: 4, pointHoverRadius: 6, pointBorderColor: '#ffffff', pointBorderWidth: 2,
      pointBackgroundColor: color, tension: 0, spanGaps: true,
    });
    const cfg = {
      type: 'line',
      data: { labels: t.map((x) => fechaCorta(x.fecha)), datasets: [serie('Fueron', 'asistencia_pct', c1), serie('Volverían', 'volverian_pct', c2)] },
      options: {
        responsive: true, maintainAspectRatio: false, animation: false,
        interaction: { mode: 'index', intersect: false },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: '#1e1f23', padding: 10, titleFont: { family: 'Barlow', weight: '600' }, bodyFont: { family: 'Barlow' },
            callbacks: {
              title: (items) => fechaLarga(t[items[0].dataIndex].fecha),
              label: (it) => ` ${it.dataset.label}: ${pct(it.parsed.y)}`,
              afterBody: (items) => {
                const x = t[items[0].dataIndex];
                return [`${fmt.format(x.respuestas)} respuestas`, `Bienestar: ${x.bienestar_promedio ?? ND} / 5`];
              },
            },
          },
        },
        scales: {
          y: { min: 0, max: 100, ticks: { stepSize: 25, callback: (v) => `${v} %`, color: css('--ink-muted'), font: { family: 'Barlow' } },
               grid: { color: '#ecece8' }, border: { display: false } },
          x: { ticks: { color: css('--ink-muted'), font: { family: 'Barlow' } }, grid: { display: false }, border: { color: '#d6d6d1' } },
        },
      },
    };
    if (grafTendencia) grafTendencia.destroy();
    grafTendencia = new Chart($('#tendencia'), cfg);
  }

  function pintarComunas() {
    const filas = [...datos.por_comuna].sort((a, b) => (b.inscritos.valor ?? -1) - (a.inscritos.valor ?? -1) || a.comuna - b.comuna);
    const max = Math.max(1, ...filas.map((f) => f.inscritos.valor || 0));
    $('#comunas').innerHTML =
      `<div class="leyenda"><span><i style="background:${css('--data-1')};height:10px"></i>Con parche</span><span><i style="background:${css('--data-track')};height:10px"></i>Inscritos</span></div>` +
      filas.filter((f) => f.inscritos.valor !== 0).map((f) => fila(
        `Comuna ${f.comuna}`, f.con_parche.valor, max,
        `${conteo(f.con_parche)} <small>/ ${conteo(f.inscritos)}</small>`,
        { base: f.inscritos.valor, titulo: `Comuna ${f.comuna}: ${conteo(f.inscritos)} inscritos, ${conteo(f.con_parche)} con parche, ${conteo(f.fueron)} fueron` },
      )).join('');
    $('#tabla-comunas').innerHTML = `<table><thead><tr><th>Comuna</th><th class="n">Inscritos</th><th class="n">Con parche</th><th class="n">Fueron</th><th class="n">Bienestar</th></tr></thead><tbody>${
      datos.por_comuna.map((f) => `<tr><td>Comuna ${f.comuna}</td><td class="n">${conteo(f.inscritos)}</td><td class="n">${conteo(f.con_parche)}</td><td class="n">${conteo(f.fueron)}</td><td class="n">${f.bienestar_promedio ?? `<span class="guion">${ND}</span>`}</td></tr>`).join('')
    }</tbody></table>`;
  }

  function pintarMapa() {
    if (!window.L) return;
    if (!mapa) {
      mapa = L.map('mapa', { scrollWheelZoom: false, zoomControl: true }).setView([3.435, -76.515], 12);
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 17, attribution: '&copy; colaboradores de OpenStreetMap',
      }).addTo(mapa);
    }
    if (capaMapa) capaMapa.remove();
    capaMapa = L.layerGroup().addTo(mapa);
    const color = css('--data-1');
    datos.por_tramo.forEach((t) => {
      const r = 5 + 3 * Math.sqrt(t.con_parche);
      L.circleMarker([t.lat, t.lng], { radius: r, color, weight: 2, fillColor: color, fillOpacity: 0.3 })
        .bindTooltip(`<b>${esc(t.nombre)}</b> · comuna ${t.comuna}<br>${t.parches} parches · ${t.con_parche} con parche · ${t.fueron} fueron`)
        .addTo(capaMapa);
    });
  }

  function pintarBienestar() {
    const d = datos.bienestar_distribucion;
    const max = Math.max(1, ...d);
    $('#bienestar').innerHTML = d.map((n, i) => `
      <div class="col" title="${CARAS[i]}: ${n} respuestas">
        <span class="v">${fmt.format(n)}</span>
        <span class="barra" style="height:${(150 * n) / max}px"></span>
        <span class="e"><b>${i + 1}</b>${CARAS[i]}</span>
      </div>`).join('');
  }

  function pintarGrupos() {
    const sel = $('#filtro-tramo');
    const elegido = sel.value;
    const tramos = [...new Set(datos.por_grupo.map((g) => g.tramo))].sort();
    sel.innerHTML = '<option value="">Todas</option>' + tramos.map((t) => `<option>${esc(t)}</option>`).join('');
    sel.value = tramos.includes(elegido) ? elegido : '';
    const filas = datos.por_grupo.filter((g) => !sel.value || g.tramo === sel.value);
    const guion = `<span class="guion" title="Menos de ${datos.anonimato.k_promedio} respuestas">${ND}</span>`;
    $('#grupos').innerHTML = `<thead><tr>
        <th>Parche</th><th>Estación</th><th>Hora</th><th>Actividad</th><th>Cómo se armó</th>
        <th class="n">Integrantes</th><th class="n">Confirmaron</th><th class="n">Fueron</th><th class="n">Volverían</th><th class="n">Bienestar</th>
      </tr></thead><tbody>${filas.map((g) => `<tr>
        <td>${esc(g.grupo)}</td><td>${esc(g.tramo)}</td><td>${esc(g.hora)}</td><td>${esc(g.actividad)}</td>
        <td><span class="tag ${g.nivel}">${NIVEL[g.nivel] || g.nivel}</span></td>
        <td class="n">${g.tamano}</td><td class="n">${g.confirmados}</td><td class="n">${g.fueron}</td><td class="n">${g.volverian}</td>
        <td class="n">${g.bienestar_promedio == null ? guion : String(g.bienestar_promedio).replace('.', ',')}</td>
      </tr>`).join('')}</tbody>`;
  }

  $('#jornada').addEventListener('change', cargarResumen);
  $('#filtro-tramo').addEventListener('change', pintarGrupos);

  async function iniciar() {
    try {
      await cargarJornadas();
      await cargarResumen();
    } catch (e) {
      $('#kpis').innerHTML = `<div class="kpi"><div class="lbl">No se pudo cargar el tablero</div><div class="det">${esc(e.message)}</div></div>`;
    }
  }
  iniciar();
  // se refresca solo durante la demo, conservando la jornada elegida
  setInterval(() => cargarJornadas().then(cargarResumen).catch(() => {}), 30000);
})();
