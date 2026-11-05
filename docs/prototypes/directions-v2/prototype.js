/*
 * THROWAWAY DIRECTION REVIEW. Fixed synthetic data only.
 * No API, no persistence, no production code, no external assets.
 */
(() => {
  'use strict';

  const D = {
    vehicle: '白露',
    model: 'Model 3',
    time: '18:40',
    status: '充电中',
    power: '11.0',
    soc: 68,
    range: 320,
    today: { km: 60.0, trips: 3, kwh: 11.25 },
    month: {
      km: 1198.6, trips: 46, net: 158, charge: 234.7, sessions: 9,
      cost: 186.4, knownSessions: 8, knownEnergy: 214.0, avgCost: 0.871,
      active: 22, duration: '5h10', ac: 118.0, dc: 96.0, unknown: 20.7,
    },
    prev: { km: 1107.3, net: 166 },
    days: [
      32.4, 48.6, 0, 62.5, 54.8, 35.2, 108.3, 0, 42.6, 38.9, 55.4, 96.7,
      31.2, 0, 64.8, 47.5, 39.6, 82.4, 25.8, 0, 52.6, 44.3, 57.8, 69.5,
      32.9, 60.0,
    ],
    prevDays: [
      31.9, 45.9, 0, 58.9, 52.9, 34.9, 99.9, 0, 41.9, 38.9, 52.9, 88.9,
      31.9, 0, 61.9, 42, 35, 73, 23, 0, 47, 39, 51, 61, 29, 55.4,
    ],
    drive: {
      distance: 32.9, duration: 46, net: 154, energy: 5.07,
      start: '松岚小区', end: '云栖中心', date: '10/26', time: '16:05',
      startSoc: 76, endSoc: 68, maxSpeed: 118, avgSpeed: 43,
      ascent: 120, descent: 140,
    },
    speed: [0, 12, 24, 38, 46, 55, 58, 62, 74, 88, 91, 84, 76, 70, 65, 60, 55, 48, 40, 30, 18, 6, 0],
    drives: [
      { date: '10/26', time: '16:05', start: '松岚小区', end: '云栖中心', km: 32.9, min: 46, net: 154 },
      { date: '10/26', time: '08:30', start: '家', end: '公司', km: 18.4, min: 32, net: 162 },
      { date: '10/25', time: '18:10', start: '公司', end: '湖畔超充', km: 12.6, min: 24, net: 138 },
      { date: '10/24', time: '09:40', start: '家', end: '松岚公园', km: 7.8, min: 18, net: 171 },
      { date: '10/23', time: '18:20', start: '公司', end: '家', km: 18.7, min: 41, net: 154 },
      { date: '10/22', time: '10:05', start: '家', end: '云栖中心', km: 27.6, min: 39, net: 149 },
    ],
    sessions: [
      { date: '10/26', place: '湖畔超级充电站', kwh: 46.8, soc: '18→82', min: 34, cost: '¥71.28', kind: 'DC' },
      { date: '10/25', place: '家', kwh: 28.0, soc: '24→80', min: 48, cost: '¥22.40', kind: 'AC' },
      { date: '10/23', place: '湖畔超级充电站', kwh: 33.2, soc: '12→68', min: 26, cost: '¥30.32', kind: 'DC' },
      { date: '10/21', place: '公司', kwh: 29.4, soc: '40→96', min: 55, cost: '¥16.60', kind: 'AC' },
      { date: '10/20', place: '未定位', kwh: 20.7, soc: '50→70', min: 36, cost: '未记录', kind: '未知' },
    ],
    chapters: [
      { key: 'rhythm', title: '节奏', value: '22', unit: '天', note: '13h18 驾驶 · 单程中位 18.6 km', spark: [0, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1] },
      { key: 'energy', title: '能耗', value: '158', unit: 'Wh/km', note: '较参照低 8 Wh/km', spark: [155, 148, 162, 158, 147, 168, 151, 145, 158, 174, 150, 159, 155, 148, 165, 150, 153, 152, 161, 162, 145, 154, 158, 156, 159, 158] },
      { key: 'charging', title: '补能', value: '¥186.4', unit: '', note: '8/9 次有记录 · 234.7 kWh', spark: [0, 0, 28, 0, 0, 33.2, 0, 29.4, 0, 20.7, 0, 0, 13.8, 0, 0, 16, 0, 24.1, 0, 0, 22.7, 0, 0, 28, 0, 46.8] },
      { key: 'range', title: '长期', value: '316', unit: 'km', note: '近 6 个月额定续航', spark: [318, 321, 317, 316, 314, 316] },
    ],
    temp: [
      { label: '≤5°', value: 172 }, { label: '5–15°', value: 161 },
      { label: '15–25°', value: 154 }, { label: '25–35°', value: 149 }, { label: '≥35°', value: 157 },
    ],
    rangeMonths: [318, 321, 317, 316, 314, 316],
  };

  const ICONS = {
    leaf: '<path d="M12 3c-3 3-3 6 0 8 3-2 3-5 0-8Z"/><path d="M3 10c1 7 4 10 9 11-1-7-4-10-9-11Zm18 0c-1 7-4 10-9 11 1-7 4-10 9-11Z"/>',
    home: '<path d="m3 11 9-8 9 8M6 9v12h12V9M10 21v-7h4v7"/>',
    car: '<path d="m5 5-2 8v7h3v-3h12v3h3v-7l-2-8Zm-2 8h18M7 9h10"/>',
    bolt: '<path d="m13 2-8 12h6l-1 8 9-13h-6l1-7Z"/>',
    chart: '<path d="M4 21V12h4v9m3 0V4h4v17m3 0V8h4v13"/>',
    chevron: '<path d="m9 6 6 6-6 6"/>',
    'chevron-down': '<path d="m6 9 6 6 6-6"/>',
    'arrow-up-right': '<path d="M7 17 17 7M8 7h9v9"/>',
    refresh: '<path d="M20 7v5h-5M20 12a8 8 0 1 0-2 6"/>',
    settings: '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2.8 2.8-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6v.2h-4v-.2a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1L4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9 1.7 1.7 0 0 0-1.6-1H2.8v-4H3a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9L4.2 7 7 4.2l.1.1A1.7 1.7 0 0 0 9 4.6a1.7 1.7 0 0 0 1-1.6v-.2h4V3a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1L19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.6 1h.2v4H21a1.7 1.7 0 0 0-1.6 1Z"/>',
    route: '<circle cx="6" cy="19" r="2"/><circle cx="18" cy="5" r="2"/><path d="M8 19h6a4 4 0 0 0 0-8h-2a4 4 0 0 1 0-8h3"/>',
    battery: '<rect x="3" y="7" width="16" height="10" rx="2"/><path d="M21 10v4M7 10v4m4-4v4m4-4v4"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    'map-pin': '<path d="M20 10c0 6-8 11-8 11S4 16 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/>',
    wallet: '<path d="M4 6h14a2 2 0 0 1 2 2v10H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2Z"/><path d="M16 12h5v4h-5a2 2 0 0 1 0-4Z"/>',
    more: '<circle cx="5" cy="12" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="19" cy="12" r="1.4"/>',
    grid: '<rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><rect x="14" y="14" width="6" height="6" rx="1"/>',
    drop: '<path d="M12 3s6 7 6 11a6 6 0 0 1-12 0c0-4 6-11 6-11Z"/>',
    temp: '<path d="M14 14.8V5a2 2 0 1 0-4 0v9.8a4 4 0 1 0 4 0Z"/><path d="M12 9v7"/>',
    check: '<path d="m5 12 4 4L19 6"/>',
  };

  const icon = (name, cls = '') =>
    `<svg class="ic ${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[name] || ICONS.chart}</svg>`;

  const fmt = (value, digits = 1) =>
    value == null ? '—' : Number(value).toLocaleString('en-US', {
      minimumFractionDigits: digits, maximumFractionDigits: digits,
    });
  const money = (value) => `¥${fmt(value, 2)}`;
  const deltaKm = D.month.km - D.prev.km;
  const deltaPct = (deltaKm / D.prev.km) * 100;

  /* ---------- chart primitives ---------- */
  const segs = (values) => {
    const out = [];
    let cur = [];
    values.forEach((v, i) => {
      if (v == null) {
        if (cur.length) out.push(cur);
        cur = [];
      } else cur.push([i, v]);
    });
    if (cur.length) out.push(cur);
    return out;
  };

  const linePath = (seg, x, y) =>
    seg.map(([i, v], k) => `${k ? 'L' : 'M'}${x(i).toFixed(1)} ${y(v).toFixed(1)}`).join(' ');

  function chartA(values, refValues, width = 320, height = 118, id = 'a', max = 120, labelLast = true) {
    const padL = 2, padR = 6, padT = 10, padB = 14;
    const n = values.length;
    const x = (i) => padL + (i * (width - padL - padR)) / (n - 1);
    const y = (v) => height - padB - (v / max) * (height - padT - padB);
    const seg = segs(values);
    const area = seg.map((s) => {
      const line = linePath(s, x, y);
      return `${line} L${x(s[s.length - 1][0]).toFixed(1)} ${height - padB} L${x(s[0][0]).toFixed(1)} ${height - padB} Z`;
    }).join(' ');
    const ref = refValues && refValues.length ? segs(refValues).map((s) => linePath(s, x, y)).join(' ') : '';
    const last = [...values].reverse().findIndex((v) => v != null);
    const lastIndex = last < 0 ? 0 : values.length - 1 - last;
    const lastValue = values[lastIndex];
    return `<svg class="a-chart" viewBox="0 0 ${width} ${height}" width="100%" height="${height}" preserveAspectRatio="none" role="img" aria-label="每日里程趋势">
      <defs>
        <linearGradient id="${id}-fill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="currentColor" stop-opacity=".28"/>
          <stop offset="1" stop-color="currentColor" stop-opacity="0"/>
        </linearGradient>
      </defs>
      <line x1="${padL}" y1="${height - padB}" x2="${width - padR}" y2="${height - padB}" class="chart-base"/>
      ${ref ? `<path d="${ref}" class="chart-ref"/>` : ''}
      <path d="${area}" fill="url(#${id}-fill)"/>
      <path d="${seg.map((s) => linePath(s, x, y)).join(' ')}" class="chart-line"/>
      <circle cx="${x(lastIndex)}" cy="${y(lastValue)}" r="7" class="chart-halo"/>
      <circle cx="${x(lastIndex)}" cy="${y(lastValue)}" r="3" class="chart-dot"/>
      ${labelLast ? `<text x="${x(lastIndex)}" y="${y(lastValue) - 12}" text-anchor="${lastIndex > n - 3 ? 'end' : 'middle'}" class="chart-current">${fmt(lastValue, 0)}</text>` : ''}
    </svg>`;
  }

  function microSpark(values, width = 132, height = 30) {
    const known = values.filter((v) => v != null);
    if (!known.length) return `<div class="a-micro"></div>`;
    const lo = Math.min(...known), hi = Math.max(...known);
    const span = hi - lo || 1;
    const pad = 3;
    const x = (i) => pad + (i * (width - pad * 2)) / Math.max(1, values.length - 1);
    const y = (v) => height - pad - ((v - lo) / span) * (height - pad * 2);
    const paths = segs(values).map((seg) => seg.map(([i, v], k) => `${k ? 'L' : 'M'}${x(i).toFixed(1)} ${y(v).toFixed(1)}`).join(' '));
    const areas = segs(values).map((seg) => `${seg.map(([i, v], k) => `${k ? 'L' : 'M'}${x(i).toFixed(1)} ${y(v).toFixed(1)}`).join(' ')} L${x(seg[seg.length - 1][0]).toFixed(1)} ${height} L${x(seg[0][0]).toFixed(1)} ${height} Z`);
    const last = values[values.length - 1];
    return `<svg class="a-micro" viewBox="0 0 ${width} ${height}" width="100%" height="${height}" preserveAspectRatio="none" aria-hidden="true">
      ${areas.map((d) => `<path d="${d}" class="a-micro-fill"/>`).join('')}
      ${paths.map((d) => `<path d="${d}" class="a-micro-line"/>`).join('')}
      <circle cx="${x(values.length - 1)}" cy="${y(last)}" r="2" class="a-micro-dot"/>
    </svg>`;
  }

  function miniDays(values, width = 132, height = 30) {
    const n = values.length;
    const gap = 2;
    const bw = (width - gap * (n - 1)) / n;
    return `<svg class="a-days" viewBox="0 0 ${width} ${height}" width="100%" height="${height}" preserveAspectRatio="none" aria-hidden="true">
      ${values.map((v, i) => `<rect x="${(i * (bw + gap)).toFixed(1)}" y="${v ? 8 : height - 2}" width="${bw.toFixed(1)}" height="${v ? height - 8 : 2}" rx=".8" class="${v ? 'on' : ''}${i === n - 1 ? ' current' : ''}"/>`).join('')}
    </svg>`;
  }

  function chartB(values, refValues, width = 320, height = 132, id = 'b', max = 120) {
    const padL = 26, padR = 6, padT = 12, padB = 18;
    const n = values.length;
    const x = (i) => padL + ((i + .5) * (width - padL - padR)) / n;
    const y = (v) => height - padB - (v / max) * (height - padT - padB);
    const bw = Math.max(3, ((width - padL - padR) / n) * .36);
    const bars = values.map((v, i) => {
      const h = Math.max(0, (v / max) * (height - padT - padB));
      return `<rect x="${(x(i) - bw / 2).toFixed(1)}" y="${(height - padB - h).toFixed(1)}" width="${bw.toFixed(1)}" height="${h.toFixed(1)}" rx="1" class="chart-bar${i === n - 1 ? ' is-current' : ''}"/>`;
    }).join('');
    const ref = refValues && refValues.length ? segs(refValues).map((s) => linePath(s, (i) => x(i), y)).join(' ') : '';
    const grid = [0, .25, .5, .75, 1].map((f) => f * max).map((t) => `<line x1="${padL}" y1="${y(t)}" x2="${width - padR}" y2="${y(t)}" class="chart-grid"/><text x="${padL - 6}" y="${y(t) + 3}" text-anchor="end" class="chart-tick">${Math.round(t)}</text>`).join('');
    return `<svg class="b-chart-svg" viewBox="0 0 ${width} ${height}" width="100%" height="${height}" preserveAspectRatio="none" role="img" aria-label="每日里程柱状图">
      ${grid}
      ${bars}
      ${ref ? `<path d="${ref}" class="chart-ref-b"/>` : ''}
      <line x1="${padL}" y1="${height - padB}" x2="${width - padR}" y2="${height - padB}" class="chart-axis"/>
    </svg>`;
  }

  function chartC(values, refValues, width = 312, height = 116, id = 'c') {
    const max = 120, padL = 4, padR = 4, padT = 12, padB = 12;
    const n = values.length;
    const x = (i) => padL + (i * (width - padL - padR)) / (n - 1);
    const y = (v) => height - padB - (v / max) * (height - padT - padB);
    const seg = segs(values);
    const line = seg.map((s) => linePath(s, x, y)).join(' ');
    const ref = refValues && refValues.length ? segs(refValues).map((s) => linePath(s, x, y)).join(' ') : '';
    const dots = seg.flat().filter(([i]) => i % 4 === 0).map(([i, v]) => `<circle cx="${x(i).toFixed(1)}" cy="${y(v).toFixed(1)}" r="1.8" class="c-dot"/>`).join('');
    return `<svg class="c-chart" viewBox="0 0 ${width} ${height}" width="100%" height="${height}" preserveAspectRatio="none" role="img" aria-label="每日里程折线">
      <line x1="${padL}" y1="${height - padB}" x2="${width - padR}" y2="${height - padB}" class="c-axis"/>
      ${ref ? `<path d="${ref}" class="c-ref"/>` : ''}
      <path d="${line}" class="c-line"/>
      ${dots}
    </svg>`;
  }

  function arcA(pct) {
    const size = 88, stroke = 2.4, r = (size - stroke) / 2 - 2, c = 2 * Math.PI * r;
    return `<svg class="a-arc" viewBox="0 0 ${size} ${size}" width="${size}" height="${size}" role="img" aria-label="电量 ${pct}%">
      <circle cx="${size / 2}" cy="${size / 2}" r="${r}" class="a-arc-track" stroke-width="${stroke}"/>
      <circle cx="${size / 2}" cy="${size / 2}" r="${r}" class="a-arc-value" stroke-width="${stroke}"
        stroke-dasharray="${(c * pct) / 100} ${c}" transform="rotate(-90 ${size / 2} ${size / 2})"/>
    </svg>`;
  }

  function gaugeB(pct) {
    const size = 238, cx = size / 2, cy = 128, r = 92;
    const start = -216, sweep = 252;
    const polar = (angle, rad = r) => {
      const a = (angle * Math.PI) / 180;
      return [cx + Math.cos(a) * rad, cy + Math.sin(a) * rad];
    };
    const arc = (from, to, rad = r) => {
      const [x1, y1] = polar(from, rad), [x2, y2] = polar(to, rad);
      const large = Math.abs(to - from) > 180 ? 1 : 0;
      return `M${x1.toFixed(1)} ${y1.toFixed(1)} A${rad} ${rad} 0 ${large} 1 ${x2.toFixed(1)} ${y2.toFixed(1)}`;
    };
    const ticks = Array.from({ length: 26 }, (_, i) => {
      const a = start + (sweep * i) / 25;
      const [x1, y1] = polar(a, r - 10), [x2, y2] = polar(a, i % 5 === 0 ? r - 18 : r - 14);
      return `<line x1="${x1.toFixed(1)}" y1="${y1.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}" class="b-tick${i <= Math.round((pct / 100) * 25) ? ' is-on' : ''}"/>`;
    }).join('');
    const val = start + (sweep * pct) / 100;
    const [vx, vy] = polar(val, r);
    return `<svg class="b-gauge-svg" viewBox="0 0 ${size} 176" width="${size}" height="176" role="img" aria-label="电量 ${pct}%">
      <path d="${arc(start, start + sweep)}" class="b-gauge-track"/>
      <path d="${arc(start, val)}" class="b-gauge-value"/>
      ${ticks}
      <circle cx="${vx.toFixed(1)}" cy="${vy.toFixed(1)}" r="4" class="b-gauge-dot"/>
      <text x="${cx}" y="${cy - 6}" text-anchor="middle" class="b-gauge-pct">${pct}<tspan class="b-gauge-unit">%</tspan></text>
      <text x="${cx}" y="${cy + 18}" text-anchor="middle" class="b-gauge-cap">BATTERY</text>
    </svg>`;
  }

  function mapA() {
    return `<svg class="a-map" viewBox="0 0 360 300" preserveAspectRatio="xMidYMid slice" role="img" aria-label="路线示意">
      <defs>
        <linearGradient id="a-map-fade" x1="0" y1="0" x2="0" y2="1">
          <stop offset=".45" stop-color="#07100B" stop-opacity="0"/>
          <stop offset=".78" stop-color="#07100B" stop-opacity=".75"/>
          <stop offset="1" stop-color="#07100B" stop-opacity=".99"/>
        </linearGradient>
      </defs>
      <rect width="360" height="300" fill="#0A120D"/>
      <g class="a-map-grid">
        <path d="M0 62h360M0 128h360M0 196h360M0 258h360M58 0v300M132 0v300M212 0v300M286 0v300"/>
      </g>
      <g class="a-map-water">
        <path d="M-20 232C56 218 74 188 128 190s70 30 124 16 78-44 132-36"/>
      </g>
      <g class="a-map-blocks">
        <path d="M22 28h58v26H22zM96 20h52v34H96zM172 24h64v28h-64zM258 18h76v40h-76zM26 76h42v32H26zM88 70h62v38H88zM166 78h54v30h-54zM238 84h44v28h-44zM18 134h66v40H18zM104 130h50v34h-50zM170 132h60v44h-60zM250 138h68v36h-68z"/>
      </g>
      <path d="M66 176C96 160 116 152 142 138S184 102 202 82S238 62 262 58S284 56 296 50" class="a-map-route-halo"/>
      <path d="M66 176C96 160 116 152 142 138S184 102 202 82S238 62 262 58S284 56 296 50" class="a-map-route"/>
      <circle cx="66" cy="176" r="8" class="a-map-pin-halo"/><circle cx="66" cy="176" r="3.5" class="a-map-pin"/>
      <circle cx="296" cy="50" r="8" class="a-map-pin-halo"/><circle cx="296" cy="50" r="3.5" class="a-map-pin end"/>
      <rect width="360" height="300" fill="url(#a-map-fade)"/>
    </svg>`;
  }

  function mapB() {
    return `<svg class="b-map" viewBox="0 0 360 300" preserveAspectRatio="xMidYMid slice" role="img" aria-label="路线示意">
      <rect width="360" height="300" fill="#0B1116"/>
      <g class="b-map-grid">
        <path d="M0 50h360M0 100h360M0 150h360M0 200h360M0 250h360M50 0v300M100 0v300M150 0v300M200 0v300M250 0v300M300 0v300M350 0v300"/>
      </g>
      <g class="b-map-contour">
        <path d="M-20 246c58-18 78-52 132-48s64 30 116 12 70-52 132-42"/>
        <path d="M-20 266c58-18 78-52 132-48s64 30 116 12 70-52 132-42"/>
      </g>
      <g class="b-map-blocks">
        <path d="M24 30h52v22H24zM92 22h56v30H92zM164 28h50v24h-50zM230 20h70v34h-70zM28 72h46v30H28zM90 68h58v34H90zM164 74h56v28h-56zM236 78h62v30h-62zM20 132h60v36H20zM96 128h54v32H96zM166 130h58v40h-58zM240 136h66v34h-66z"/>
      </g>
      <path d="M76 244C104 224 122 214 146 202C170 190 184 168 196 154C208 140 218 126 230 116C246 102 262 88 280 78C288 74 294 70 300 66" class="b-map-route"/>
      <g class="b-map-nodes"><circle cx="76" cy="244" r="4"/><circle cx="300" cy="66" r="4"/></g>
      <g class="b-map-label"><text x="86" y="262">A · 松岚小区</text></g>
      <g class="b-scale"><path d="M20 282h48M20 278v8M68 278v8"/><text x="20" y="274">500 m</text></g>
      <g class="b-compass"><path d="M330 256v14m0-14-5 6m5-6 5 6"/><text x="327" y="250">N</text></g>
    </svg>`;
  }

  function mapC() {
    return `<svg class="c-map" viewBox="0 0 312 220" preserveAspectRatio="xMidYMid slice" role="img" aria-label="路线示意">
      <rect width="312" height="220" fill="#12100C"/>
      <g class="c-map-lines">
        <path d="M0 40h312M0 92h312M0 146h312M0 196h312M52 0v220M112 0v220M176 0v220M240 0v220"/>
        <path d="M-10 182c48-14 62-38 104-36s54 24 94 10 56-38 104-32"/>
      </g>
      <g class="c-map-blocks">
        <path d="M20 24h48v20H20zM84 18h44v26H84zM146 22h48v20h-48zM210 16h60v28h-60zM24 64h38v24H24zM80 60h48v28H80zM144 66h46v22h-46zM206 70h52v24h-52zM18 116h52v30H18zM88 112h44v26H88zM150 114h50v32h-50zM216 120h56v28h-56z"/>
      </g>
      <path d="M62 186C88 168 102 160 126 150s34-28 48-44 26-32 44-44 26-24 42-32" class="c-map-route"/>
      <circle cx="62" cy="186" r="3" class="c-map-node"/>
      <circle cx="260" cy="30" r="3" class="c-map-node"/>
    </svg>`;
  }

  /* ---------- shared bits ---------- */
  const navA = (active) => `<nav class="a-nav">${[
    ['overview', '概览', 'home'], ['drives', '行程', 'car'], ['charging', '充电', 'bolt'], ['statistics', '统计', 'chart'],
  ].map(([key, label, ico]) => `<button class="a-nav-item${active === key ? ' is-active' : ''}" data-page="${key}">${icon(ico)}<span>${label}</span></button>`).join('')}</nav>`;

  const navB = (active) => `<nav class="b-nav">${[
    ['overview', '总览', 'grid'], ['drives', '行程', 'car'], ['charging', '补能', 'bolt'], ['statistics', '数据', 'chart'],
  ].map(([key, label, ico]) => `<button class="b-nav-item${active === key ? ' is-active' : ''}" data-page="${key}">${icon(ico)}<span>${label}</span></button>`).join('')}</nav>`;

  const navC = (active) => `<nav class="c-nav">${[
    ['overview', '概览', 'home'], ['drives', '行程', 'car'], ['charging', '补能', 'bolt'], ['statistics', '统计', 'chart'],
  ].map(([key, label, ico]) => `<button class="c-nav-item${active === key ? ' is-active' : ''}" data-page="${key}"><i></i>${icon(ico)}<span>${label}</span></button>`).join('')}</nav>`;

  /* ---------- A · 夜航 ---------- */
  const aAppbar = `<header class="a-appbar">
    <div class="a-brand">${icon('leaf')}<span>行笺</span></div>
    <button class="a-vehicle">${D.vehicle}${icon('chevron-down')}</button>
    <button class="a-icon" aria-label="设置">${icon('settings')}</button>
  </header>`;

  const aPagebar = `<header class="a-pagebar">
    <span class="a-brand">${icon('leaf')}<span>行笺</span></span>
    <button class="a-vehicle a-vehicle-ink">${D.vehicle}${icon('chevron-down')}</button>
    <button class="a-icon a-icon-ink" aria-label="设置">${icon('settings')}</button>
  </header>`;

  function aOverview() {
    const spark = D.days.map((v) => v || 0);
    return `<div class="a-page">
      <section class="a-hero">
        ${aAppbar}
        <div class="a-glow"></div>
        <div class="a-status"><span class="a-status-dot"></span><b>${D.status}</b><span class="a-status-sep"></span><span>${D.power} kW</span><span class="a-status-time">${D.time}</span></div>
        <div class="a-hero-main">
          <div class="a-range"><div class="a-range-num">${D.range}<span>km</span></div><div class="a-range-cap">额定续航</div></div>
          <div class="a-soc">${arcA(D.soc)}<div class="a-soc-val">${D.soc}<span>%</span></div><div class="a-soc-cap">电量</div></div>
        </div>
        <div class="a-hero-foot">
          <div><b>${fmt(D.today.km, 1)}</b><span>今日 km</span></div>
          <div><b>${D.today.trips}</b><span>次行程</span></div>
          <div><b>${fmt(D.today.kwh, 2)}</b><span>估算 kWh</span></div>
        </div>
      </section>
      <main class="a-main">
        <section class="a-month">
          <div class="a-kicker"><span>本月 · 驾驶里程</span><span>OCT 2026</span></div>
          <div class="a-month-row">
            <div class="a-month-num">${fmt(D.month.km, 1)}<span>km</span></div>
            <div class="a-delta"><b>↑ ${fmt(deltaPct, 1)}%</b><span>较上月同期</span></div>
          </div>
          <p class="a-note">净电耗 <b>${D.month.net}</b> Wh/km<i></i>比上月低 ${D.prev.net - D.month.net}</p>
        </section>
        <section class="a-chartsec">
          <div class="a-sechead"><h2>每日里程</h2><span>10.01 — 10.26</span></div>
          ${chartA(D.days, D.prevDays, 320, 118, 'a-ov')}
          <div class="a-chartfoot"><span>10/26 · 60.0 km</span><span>点按读值</span></div>
        </section>
        <section class="a-recent">
          <div class="a-sechead"><h2>最近</h2><button>全部 ${icon('arrow-up-right')}</button></div>
          <a class="a-record" data-page="drive">
            <span class="a-record-ic">${icon('route')}</span>
            <span class="a-record-body"><b>松岚小区 → 云栖中心</b><i>10/26 · 46 分钟 · ${D.drive.net} Wh/km</i></span>
            <span class="a-record-val">${fmt(D.drive.distance, 1)}<em>km</em></span>
          </a>
          <a class="a-record" data-page="charging">
            <span class="a-record-ic">${icon('bolt')}</span>
            <span class="a-record-body"><b>湖畔超级充电站</b><i>10/26 · 18→82% · 34 分钟</i></span>
            <span class="a-record-val">${fmt(46.8, 1)}<em>kWh</em></span>
          </a>
        </section>
        <section class="a-more">
          <a data-page="statistics"><span>节奏</span><i>${D.month.active} 个活跃日</i>${icon('chevron')}</a>
          <a data-page="statistics"><span>能耗</span><i>${D.month.net} Wh/km</i>${icon('chevron')}</a>
          <a data-page="statistics"><span>长期</span><i>316 km 额定续航</i>${icon('chevron')}</a>
        </section>
        <p class="a-footnote">数据不是实时。采样于 ${D.time}，估算口径见数据说明。</p>
      </main>
      ${navA('overview')}
    </div>`;
  }

  function aStatistics() {
    return `<div class="a-page">
      ${aPagebar}
      <header class="a-pagehead">
        <div class="a-kicker"><span>统计 · 十月</span><button class="a-period">本月 ${icon('chevron-down')}</button></div>
        <h1>${fmt(D.month.km, 1)}<span>km</span></h1>
        <div class="a-delta-line"><b>↑ ${fmt(deltaKm, 1)} km</b><span>较上月同期 · +${fmt(deltaPct, 1)}%</span></div>
      </header>
      <section class="a-darkband">
        <div class="a-sechead"><h2>里程走势</h2><span>本期 / 参照</span></div>
        ${chartA(D.days, D.prevDays, 320, 132, 'a-st')}
        <div class="a-chartfoot"><span>10/26 · 60.0 km</span><span>参照 55.4 km</span></div>
      </section>
      <p class="a-insight">净电耗 <b>${D.month.net}</b> Wh/km，比上月低 <b>${D.prev.net - D.month.net}</b>。<button>依据</button></p>
      <section class="a-grid4">
        ${D.chapters.map((c) => `<a class="a-cell" data-page="statistics">
          <div class="a-cell-head"><span>${c.title}</span>${icon(c.key === 'rhythm' ? 'clock' : c.key === 'energy' ? 'drop' : c.key === 'charging' ? 'bolt' : 'battery')}</div>
          <div class="a-cell-num">${c.value}<span>${c.unit}</span></div>
          <p>${c.note}</p>
          <div class="a-cell-spark">${c.key === 'rhythm' ? miniDays(c.spark, 132, 30) : microSpark(c.spark, 132, 30)}</div>
        </a>`).join('')}
      </section>
      <button class="a-all">全部指标 ${icon('arrow-up-right')}</button>
      <p class="a-footnote">总计与比率取服务端返回值，不从前端分桶加总。</p>
      ${navA('statistics')}
    </div>`;
  }

  function aDrives() {
    return `<div class="a-page">
      ${aPagebar}
      <header class="a-pagehead a-pagehead-tight">
        <div class="a-kicker"><span>行程 · 近 30 天</span><button class="a-period">${icon('refresh')}</button></div>
        <h1>1,280.6<span>km</span></h1>
        <p class="a-headsub">52 趟 · 估算 197.47 kWh · 净电耗 154 Wh/km</p>
      </header>
      <section class="a-chartsec a-chartsec-tight">
        <div class="a-sechead"><h2>出行节奏</h2><span>9.27 — 10.26</span></div>
        <div class="a-rhythm">${D.days.map((v, i) => `<i style="height:${Math.max(2, (v / 108.3) * 54)}px" class="${i === D.days.length - 1 ? 'is-current' : ''}"></i>`).join('')}</div>
        <div class="a-chartfoot"><span>10/26 · 60.0 km</span><span>看当天</span></div>
      </section>
      <section class="a-recent a-recent-list">
        <div class="a-sechead"><h2>最近的路</h2><button>全部 ${icon('arrow-up-right')}</button></div>
        ${D.drives.map((d, i) => `<a class="a-record${i === 0 ? ' is-featured' : ''}" data-page="drive">
          <span class="a-record-ic">${icon('route')}</span>
          <span class="a-record-body"><b>${d.start} → ${d.end}</b><i>${d.date} · ${d.min} 分钟 · ${d.net} Wh/km</i></span>
          <span class="a-record-val">${fmt(d.km, 1)}<em>km</em></span>
        </a>`).join('')}
      </section>
      ${navA('drives')}
    </div>`;
  }

  function aDrive() {
    return `<div class="a-page">
      <section class="a-maphero">
        ${mapA()}
        <header class="a-mapbar"><button class="a-icon a-icon-light" aria-label="返回">${icon('chevron')}</button><button class="a-icon a-icon-light" aria-label="更多">${icon('more')}</button></header>
        <div class="a-mapcaption">
          <div class="a-kicker"><span>10/26 · 16:05</span><span>最近行程</span></div>
          <h1>松岚小区 <i>→</i> 云栖中心</h1>
          <div class="a-mapresult"><b>${fmt(D.drive.distance, 1)}</b><span>km</span><i></i><em>${D.drive.duration} 分钟</em></div>
        </div>
      </section>
      <main class="a-main a-detail-main">
        <div class="a-resultrow">
          <div><span>时长</span><b>46</b><i>分钟</i></div>
          <div><span>净电耗</span><b>154</b><i>Wh/km</i></div>
          <div><span>估算能量</span><b>5.07</b><i>kWh</i></div>
        </div>
        <section class="a-chartsec">
          <div class="a-sechead"><h2>速度</h2><span>km/h</span></div>
          ${chartA(D.speed, null, 320, 120, 'a-spd', 120, false)}
          <div class="a-chartfoot"><span>最高 118 km/h · 平均 43</span><span>点按读值</span></div>
        </section>
        <section class="a-battery">
          <div class="a-sechead"><h2>电量</h2><span>76 → 68%</span></div>
          <div class="a-battery-track"><i style="left:68%;width:8%"></i><b style="left:76%"></b></div>
          <div class="a-battery-cap"><span>到达 68%</span><span>出发 76%</span></div>
        </section>
        <section class="a-rows">
          <div><span>最高速度</span><b>118 km/h</b></div>
          <div><span>平均速度</span><b>43 km/h</b></div>
          <div><span>海拔</span><b>+120 / −140 m</b></div>
          <div><span>驾驶与环境</span><b>标准 · 22°C ${icon('chevron')}</b></div>
        </section>
        <p class="a-footnote">净电耗为估算值，含驾驶能耗，不含停放与充电损耗。本次参照为个人 30 日中位。</p>
      </main>
    </div>`;
  }

  function aCharging() {
    const known = D.month.knownEnergy;
    return `<div class="a-page">
      <section class="a-chargehero">
        ${aAppbar}
        <div class="a-glow a-glow-warm"></div>
        <div class="a-kicker a-kicker-onhero"><span>本月 · 补能账本</span><span>CNY</span></div>
        <div class="a-cost">¥${fmt(D.month.cost, 1)}</div>
        <div class="a-cost-cap">已知充电费用</div>
        <div class="a-cover">
          <div class="a-cover-head"><span>${D.month.knownSessions} / ${D.month.sessions} 次有记录</span><b>${fmt(D.month.avgCost, 2)} ¥/kWh</b></div>
          <div class="a-cover-track"><i style="width:${(D.month.knownSessions / D.month.sessions) * 100}%"></i></div>
          <p>覆盖 ${known} kWh；未记录费用的 1 次不计入均价。</p>
        </div>
      </section>
      <main class="a-main">
        <div class="a-resultrow a-resultrow-light">
          <div><span>充入电池</span><b>234.7</b><i>kWh</i></div>
          <div><span>次数</span><b>9</b><i>次</i></div>
          <div><span>记录时长</span><b>5h10</b><i></i></div>
        </div>
        <section class="a-chartsec">
          <div class="a-sechead"><h2>每日补能</h2><span>kWh</span></div>
          ${stemA([0, 0, 0, 28, 0, 0, 33.2, 0, 29.4, 0, 20.7, 0, 0, 13.8, 0, 0, 16, 0, 24.1, 0, 0, 22.7, 0, 0, 28, 46.8], 320, 104, 60)}
          <div class="a-chartfoot"><span>10/26 · 46.8 kWh</span><span>点按读值</span></div>
        </section>
        <section class="a-mix">
          <div class="a-sechead"><h2>构成</h2><span>仅已知分类</span></div>
          <div class="a-mixbar"><i class="ac" style="width:${(D.month.ac / D.month.charge) * 100}%"></i><i class="dc" style="width:${(D.month.dc / D.month.charge) * 100}%"></i><i class="un" style="width:${(D.month.unknown / D.month.charge) * 100}%"></i></div>
          <div class="a-mixlabels"><span><i class="ac"></i>AC 118.0</span><span><i class="dc"></i>DC 96.0</span><span><i class="un"></i>未知 20.7</span></div>
        </section>
        <section class="a-recent a-recent-list">
          <div class="a-sechead"><h2>地点</h2><button>全部 ${icon('arrow-up-right')}</button></div>
          <a class="a-record"><span class="a-record-ic">${icon('map-pin')}</span><span class="a-record-body"><b>家</b><i>6 次 · 142.3 kWh</i></span><span class="a-record-val">¥98.4</span></a>
          <a class="a-record"><span class="a-record-ic">${icon('map-pin')}</span><span class="a-record-body"><b>湖畔超充</b><i>2 次 · 71.2 kWh</i></span><span class="a-record-val">¥66.0</span></a>
          <a class="a-record"><span class="a-record-ic">${icon('map-pin')}</span><span class="a-record-body"><b>公司</b><i>1 次 · 21.2 kWh</i></span><span class="a-record-val">¥22.0</span></a>
        </section>
        ${navA('charging')}
      </main>
    </div>`;
  }

  /* ---------- B · 仪表 ---------- */
  function microBars(values, width = 104, height = 26) {
    const max = Math.max(...values, 1);
    const n = values.length;
    const gap = n > 16 ? 1 : 2;
    const bw = Math.max(1, (width - gap * (n - 1)) / n);
    return `<svg class="b-micro" viewBox="0 0 ${width} ${height}" width="100%" height="${height}" preserveAspectRatio="none" aria-hidden="true">
      ${values.map((v, i) => {
        const h = Math.max(1, (v / max) * height);
        return `<rect x="${(i * (bw + gap)).toFixed(1)}" y="${(height - h).toFixed(1)}" width="${bw.toFixed(1)}" height="${h.toFixed(1)}" rx=".8" class="${i === n - 1 ? 'is-current' : ''}"/>`;
      }).join('')}
    </svg>`;
  }

  const bTopbar = `<header class="b-topbar">
    <span class="b-clock">${D.time}</span>
    <span class="b-vehicle">${D.vehicle}<i>${D.model}</i></span>
    <button class="b-topicon" aria-label="设置">${icon('settings')}</button>
  </header>`;

  function bOverview() {
    const spark = D.days.map((v) => v || 0.4);
    return `<div class="b-page">
      ${bTopbar}
      <main class="b-main">
        <section class="b-instrument">
          <div class="b-inst-top"><span>CHARGE SESSION</span><span>${D.power} kW</span></div>
          ${gaugeB(D.soc)}
          <div class="b-inst-row">
            <div><span>RANGE</span><b>${D.range}</b><i>km</i></div>
            <div><span>STATE</span><b>${D.status}</b><i>${D.time}</i></div>
            <div><span>TODAY</span><b>${fmt(D.today.km, 1)}</b><i>km</i></div>
          </div>
        </section>
        <section class="b-cells">
          <div class="b-cell"><span>今日里程</span><b>${fmt(D.today.km, 1)}</b><i>km</i>${microBars(spark, 96, 22)}</div>
          <div class="b-cell"><span>今日行程</span><b>${D.today.trips}</b><i>次</i><em>${fmt(D.today.kwh, 2)} kWh 驾驶能量</em></div>
          <div class="b-cell"><span>驾驶能量</span><b>${fmt(D.today.kwh, 2)}</b><i>kWh</i><em>估算 · 非电网侧</em></div>
          <div class="b-cell"><span>充电功率</span><b>${D.power}</b><i>kW</i><em>充电中 · ${D.time}</em></div>
        </section>
        <section class="b-odo">
          <div class="b-panel-head"><span>本月里程</span><span>${D.month.trips} TRIPS</span></div>
          <div class="b-odo-num">${fmt(D.month.km, 1)}<span>km</span></div>
          <div class="b-odo-track"><i style="width:100%"></i><em style="left:${(D.prev.km / D.month.km) * 100}%"></em></div>
          <div class="b-odo-foot"><span>参照 ${fmt(D.prev.km, 1)} km</span><b>+${fmt(deltaPct, 1)}%</b></div>
        </section>
        <section class="b-chartpanel">
          <div class="b-panel-head"><span>每日里程</span><span>km</span></div>
          ${chartB(D.days, D.prevDays, 320, 132, 'b-ov')}
          <div class="b-chart-x"><span>10/01</span><span>10/13</span><span>10/26</span></div>
        </section>
        <section class="b-logsec">
          <div class="b-panel-head"><span>最近记录</span><span>全部</span></div>
          ${D.drives.slice(0, 4).map((d) => `<a class="b-logrow" data-page="drive"><span class="b-logtime">${d.time}</span><span class="b-logroute">${d.start} → ${d.end}</span><span class="b-logkm">${fmt(d.km, 1)}</span><span class="b-logunit">km</span></a>`).join('')}
        </section>
        ${navB('overview')}
      </main>
    </div>`;
  }

  function bStatistics() {
    return `<div class="b-page">
      ${bTopbar}
      <main class="b-main">
        <header class="b-pagehead"><span>STATISTICS / OCT 2026</span><button>本月 ${icon('chevron-down')}</button></header>
        <section class="b-conclusion">
          <span>TOTAL DISTANCE</span>
          <div class="b-conclusion-num">${fmt(D.month.km, 1)}<i>km</i></div>
          <div class="b-conclusion-row"><b>+${fmt(deltaPct, 1)}%</b><span>较上月同期</span><em></em><span>参照 ${fmt(D.prev.km, 1)}</span></div>
        </section>
        <section class="b-chartpanel">
          <div class="b-panel-head"><span>里程走势</span><span>本期 / 参照</span></div>
          ${chartB(D.days, D.prevDays, 320, 140, 'b-st')}
          <div class="b-chart-x"><span>10/01</span><span>10/13</span><span>10/26</span></div>
        </section>
        <section class="b-cells b-cells-chapters">
          <div class="b-cell"><span>节奏</span><b>${D.month.active}</b><i>天</i><em>13h18 驾驶 · 中位 18.6 km</em>${microBars([0,1,0,1,1,1,1,0,1,1,1,1,1,0,1,1,1,1,1,0,1,1,1,1,1,1], 96, 20)}</div>
          <div class="b-cell"><span>能耗</span><b>${D.month.net}</b><i>Wh/km</i><em>较参照低 8</em>${microBars([155,148,162,158,147,168,151,145,158,174,150,159,155,148,165,150,153,152,161,162,145,154], 96, 20)}</div>
          <div class="b-cell"><span>补能</span><b>186.4</b><i>¥</i><em>8/9 次有记录</em>${microBars([0,0,28,0,0,33.2,0,29.4,0,20.7,0,0,13.8,0,0,16,0,24.1,0,0,22.7,0,46.8], 96, 20)}</div>
          <div class="b-cell"><span>长期</span><b>316</b><i>km</i><em>近 6 个月额定续航</em>${microBars([318,321,317,316,314,316], 96, 20)}</div>
        </section>
        <button class="b-all">全部指标 ${icon('arrow-up-right')}</button>
        ${navB('statistics')}
      </main>
    </div>`;
  }

  function bDrives() {
    return `<div class="b-page">
      ${bTopbar}
      <main class="b-main">
        <header class="b-pagehead"><span>DRIVES / 30 DAYS</span><button>日期 ${icon('chevron-down')}</button></header>
        <section class="b-summary">
          <span>PERIOD DISTANCE</span>
          <div class="b-summary-num">1,280.6<i>km</i></div>
          <div class="b-summary-row"><span>52 趟</span><span>197.47 kWh</span><span>154 Wh/km</span></div>
        </section>
        <section class="b-chartpanel b-rhythm">
          <div class="b-panel-head"><span>出行节奏</span><span>km / day</span></div>
          <div class="b-rhythm-bars">${D.days.map((v, i) => `<i style="height:${Math.max(2, (v / 108.3) * 58)}px" class="${i === D.days.length - 1 ? 'is-current' : ''}"></i>`).join('')}</div>
          <div class="b-chart-x"><span>10/01</span><span>10/13</span><span>10/26</span></div>
        </section>
        <section class="b-logsec b-logsec-drives">
          <div class="b-panel-head"><span>记录</span><span>${D.drives.length} ENTRIES</span></div>
          ${D.drives.map((d) => `<a class="b-logrow b-logrow-drive" data-page="drive"><span class="b-logdate">${d.date}</span><span class="b-logroute">${d.start} → ${d.end}</span><span class="b-logmeta">${d.min} min · ${d.net} Wh/km</span><span class="b-logkm">${fmt(d.km, 1)}</span><span class="b-logunit">km</span></a>`).join('')}
        </section>
        ${navB('drives')}
      </main>
    </div>`;
  }

  function bDrive() {
    const speed = D.speed.map((v, i) => (i === D.speed.length - 1 ? null : v));
    return `<div class="b-page">
      <section class="b-maphero">
        ${mapB()}
        <div class="b-mapbar"><button class="b-mapback">${icon('chevron')}</button><span>DRIVE / 10.26</span><button class="b-mapmore">${icon('more')}</button></div>
      </section>
      <main class="b-main b-detail">
        <header class="b-detail-head"><span>松岚小区 → 云栖中心</span><b>${fmt(D.drive.distance, 1)}<i>km</i></b></header>
        <div class="b-kv">
          <div><span>时长</span><b>46</b><i>min</i></div>
          <div><span>净电耗</span><b>154</b><i>Wh/km</i></div>
          <div><span>能量</span><b>5.07</b><i>kWh</i></div>
        </div>
        <section class="b-chartpanel">
          <div class="b-panel-head"><span>速度过程</span><span>km/h</span></div>
          ${chartBLine(speed, 320, 132, 120)}
          <div class="b-chart-x"><span>16:05</span><span>16:28</span><span>16:51</span></div>
        </section>
        <section class="b-socpanel">
          <div class="b-panel-head"><span>电量区间</span><span>76 → 68%</span></div>
          <div class="b-socbar"><i style="left:68%;width:8%"></i><em style="left:68%"></em><em style="left:76%"></em></div>
          <div class="b-soclabels"><span>到达 68%</span><span>出发 76%</span></div>
        </section>
        <section class="b-table">
          <div><span>最高速度</span><b>118 km/h</b></div>
          <div><span>平均速度</span><b>43 km/h</b></div>
          <div><span>海拔</span><b>+120 / −140 m</b></div>
          <div><span>驾驶模式</span><b>标准</b></div>
          <div><span>外部温度</span><b>22°C</b></div>
        </section>
      </main>
    </div>`;
  }

  function bCharging() {
    return `<div class="b-page">
      ${bTopbar}
      <main class="b-main">
        <header class="b-pagehead"><span>CHARGING / OCT 2026</span><button>${D.month.sessions} SESSIONS</button></header>
        <section class="b-cost">
          <span>KNOWN COST</span>
          <div class="b-cost-num">${fmt(D.month.cost, 1)}<i>CNY</i></div>
          <div class="b-cost-cover"><span>${D.month.knownSessions} / ${D.month.sessions} 次有记录</span><b>${fmt(D.month.avgCost, 2)} ¥/kWh</b></div>
          <div class="b-cost-track"><i style="width:${(D.month.knownSessions / D.month.sessions) * 100}%"></i></div>
        </section>
        <section class="b-cells b-cells-3">
          <div class="b-cell"><span>充入电池</span><b>234.7</b><i>kWh</i></div>
          <div class="b-cell"><span>次数</span><b>9</b><i>次</i></div>
          <div class="b-cell"><span>记录时长</span><b>5h10</b><i></i></div>
        </section>
        <section class="b-chartpanel">
          <div class="b-panel-head"><span>每日补能</span><span>kWh</span></div>
          ${chartB([0,0,0,28,0,0,33.2,0,29.4,0,20.7,0,0,13.8,0,0,16,0,24.1,0,0,22.7,0,0,28,46.8], null, 320, 128, 'b-ch', 60)}
          <div class="b-chart-x"><span>10/01</span><span>10/13</span><span>10/26</span></div>
        </section>
        <section class="b-mixpanel">
          <div class="b-panel-head"><span>构成</span><span>仅已知分类</span></div>
          <div class="b-mixbar"><i class="ac" style="width:${(D.month.ac / D.month.charge) * 100}%"></i><i class="dc" style="width:${(D.month.dc / D.month.charge) * 100}%"></i><i class="un" style="width:${(D.month.unknown / D.month.charge) * 100}%"></i></div>
          <div class="b-mixlabels"><span><i class="ac"></i>AC <b>118.0</b></span><span><i class="dc"></i>DC <b>96.0</b></span><span><i class="un"></i>未知 <b>20.7</b></span></div>
          <p>DC 占已知分类 44.9%；未知类型不计入比例。</p>
        </section>
        <section class="b-logsec">
          <div class="b-panel-head"><span>地点</span><span>全部</span></div>
          <a class="b-logrow b-logrow-place"><span class="b-logroute">家</span><span class="b-logmeta">6 次 · 142.3 kWh</span><span class="b-logkm">98.4</span><span class="b-logunit">¥</span></a>
          <a class="b-logrow b-logrow-place"><span class="b-logroute">湖畔超充</span><span class="b-logmeta">2 次 · 71.2 kWh</span><span class="b-logkm">66.0</span><span class="b-logunit">¥</span></a>
          <a class="b-logrow b-logrow-place"><span class="b-logroute">公司</span><span class="b-logmeta">1 次 · 21.2 kWh</span><span class="b-logkm">22.0</span><span class="b-logunit">¥</span></a>
        </section>
        ${navB('charging')}
      </main>
    </div>`;
  }
  /* ---------- C · 夜读 ---------- */
  function chartC(values, refValues, width = 312, height = 116, max = 120) {
    const padL = 3, padR = 3, padT = 12, padB = 14;
    const n = values.length;
    const x = (i) => padL + (i * (width - padL - padR)) / (n - 1);
    const y = (v) => height - padB - (v / max) * (height - padT - padB);
    const seg = segs(values);
    const line = seg.map((s2) => linePath(s2, x, y)).join(' ');
    const ref = refValues && refValues.length ? segs(refValues).map((s2) => linePath(s2, x, y)).join(' ') : '';
    const dots = seg.flat().filter(([i]) => i % 4 === 0).map(([i, v]) => `<circle cx="${x(i).toFixed(1)}" cy="${y(v).toFixed(1)}" r="1.6" class="c-dot"/>`).join('');
    const last = [...values].reverse().findIndex((v) => v != null);
    const lastIndex = last < 0 ? 0 : values.length - 1 - last;
    return `<svg class="c-chart" viewBox="0 0 ${width} ${height}" width="100%" height="${height}" preserveAspectRatio="none" role="img" aria-label="每日里程折线">
      <line x1="${padL}" y1="${height - padB}" x2="${width - padR}" y2="${height - padB}" class="c-axis"/>
      ${ref ? `<path d="${ref}" class="c-ref"/>` : ''}
      <path d="${line}" class="c-line"/>
      ${dots}
      <circle cx="${x(lastIndex).toFixed(1)}" cy="${y(values[lastIndex]).toFixed(1)}" r="3.4" class="c-dot is-last"/>
    </svg>`;
  }

  function stemA(values, width = 320, height = 104, max = 60, id = 'a-stem') {
    const padL = 2, padR = 6, padT = 10, padB = 14;
    const n = values.length;
    const x = (i) => padL + ((i + .5) * (width - padL - padR)) / n;
    const y = (v) => height - padB - (v / max) * (height - padT - padB);
    const last = [...values].reverse().findIndex((v) => v != null && v > 0);
    const lastIndex = last < 0 ? 0 : values.length - 1 - last;
    return `<svg class="a-chart a-stem-chart" viewBox="0 0 ${width} ${height}" width="100%" height="${height}" preserveAspectRatio="none" role="img" aria-label="每日补能">
      <line x1="${padL}" y1="${height - padB}" x2="${width - padR}" y2="${height - padB}" class="chart-base"/>
      ${values.map((v, i) => v > 0 ? `<line x1="${x(i).toFixed(1)}" y1="${height - padB}" x2="${x(i).toFixed(1)}" y2="${y(v).toFixed(1)}" class="a-stem${i === lastIndex ? ' is-current' : ''}"/>` : '').join('')}
      <circle cx="${x(lastIndex).toFixed(1)}" cy="${y(values[lastIndex]).toFixed(1)}" r="2.6" class="chart-dot"/>
      <text x="${Math.min(x(lastIndex), width - 14).toFixed(1)}" y="${y(values[lastIndex]) - 8}" text-anchor="end" class="chart-current">${fmt(values[lastIndex], 0)}</text>
    </svg>`;
  }

  function stemC(values, width = 312, height = 104, max = 60) {
    const padL = 3, padR = 3, padT = 12, padB = 14;
    const n = values.length;
    const x = (i) => padL + ((i + .5) * (width - padL - padR)) / n;
    const y = (v) => height - padB - (v / max) * (height - padT - padB);
    const last = [...values].reverse().findIndex((v) => v != null && v > 0);
    const lastIndex = last < 0 ? 0 : values.length - 1 - last;
    return `<svg class="c-chart" viewBox="0 0 ${width} ${height}" width="100%" height="${height}" preserveAspectRatio="none" role="img" aria-label="每日补能">
      <line x1="${padL}" y1="${height - padB}" x2="${width - padR}" y2="${height - padB}" class="c-axis"/>
      ${values.map((v, i) => v > 0 ? `<line x1="${x(i).toFixed(1)}" y1="${height - padB}" x2="${x(i).toFixed(1)}" y2="${y(v).toFixed(1)}" class="c-stem${i === lastIndex ? ' is-current' : ''}"/><circle cx="${x(i).toFixed(1)}" cy="${y(v).toFixed(1)}" r="1.5" class="c-dot"/>` : '').join('')}
      <circle cx="${x(lastIndex).toFixed(1)}" cy="${y(values[lastIndex]).toFixed(1)}" r="3.2" class="c-dot is-last"/>
    </svg>`;
  }

  function chartBLine(values, width = 320, height = 132, max = 120) {
    const padL = 26, padR = 6, padT = 12, padB = 18;
    const n = values.length;
    const x = (i) => padL + (i * (width - padL - padR)) / (n - 1);
    const y = (v) => height - padB - (v / max) * (height - padT - padB);
    const seg = segs(values);
    const line = seg.map((s2) => linePath(s2, x, y)).join(' ');
    const grid = [0, .25, .5, .75, 1].map((f) => f * max).map((t) => `<line x1="${padL}" y1="${y(t)}" x2="${width - padR}" y2="${y(t)}" class="chart-grid"/><text x="${padL - 6}" y="${y(t) + 3}" text-anchor="end" class="chart-tick">${Math.round(t)}</text>`).join('');
    const last = [...values].reverse().findIndex((v) => v != null);
    const lastIndex = last < 0 ? 0 : values.length - 1 - last;
    return `<svg class="b-chart-svg" viewBox="0 0 ${width} ${height}" width="100%" height="${height}" preserveAspectRatio="none" role="img" aria-label="速度过程">
      ${grid}
      <path d="${line}" class="b-line"/>
      <line x1="${padL}" y1="${height - padB}" x2="${width - padR}" y2="${height - padB}" class="chart-axis"/>
      ${values[lastIndex] != null ? `<circle cx="${x(lastIndex).toFixed(1)}" cy="${y(values[lastIndex]).toFixed(1)}" r="2.4" class="b-line-dot"/>` : ''}
    </svg>`;
  }

  const cNav = (active) => `<nav class="c-nav">${[
    ['overview', '概览', 'home'], ['drives', '行程', 'car'], ['charging', '补能', 'bolt'], ['statistics', '统计', 'chart'],
  ].map(([key, label, ico]) => `<button class="c-nav-item${active === key ? ' is-active' : ''}" data-page="${key}"><i></i>${icon(ico)}<span>${label}</span></button>`).join('')}</nav>`;

  const cMast = `<header class="c-mast"><span class="c-wordmark">行笺</span><span class="c-date">2026 / 10 / 26</span></header>`;

  function cOverview() {
    return `<div class="c-page">
      ${cMast}
      <div class="c-status"><span>现在 · ${D.status}</span><span>${D.soc}% · ${D.range} km · ${D.power} kW</span></div>
      <main class="c-body">
        <section class="c-lead">
          <p class="c-kicker">十月 · 行车小志</p>
          <h1>这个月，<br><em>${fmt(D.month.km, 1)}</em> 公里。</h1>
          <p class="c-sub">比上月同期多 <b>${fmt(deltaKm, 1)}</b> 公里；净电耗 <b>${D.month.net}</b> Wh/km，低了 ${D.prev.net - D.month.net}。</p>
        </section>
        <figure class="c-plate">
          <div class="c-plate-head"><span>每日里程</span><span>10.01 — 10.26 · km</span></div>
          ${chartC(D.days, D.prevDays)}
          <figcaption><span>10/26 · 60.0 km</span><span>点按读值</span></figcaption>
        </figure>
        <section class="c-ledger">
          <div class="c-ledger-row"><span>行驶</span><b>${fmt(D.month.km, 1)}</b><i>km</i></div>
          <div class="c-ledger-row"><span>行程</span><b>${D.month.trips}</b><i>趟</i></div>
          <div class="c-ledger-row"><span>净电耗</span><b>${D.month.net}</b><i>Wh/km</i></div>
          <div class="c-ledger-row"><span>补能</span><b>${fmt(D.month.charge, 1)}</b><i>kWh</i></div>
          <div class="c-ledger-row"><span>已知费用</span><b>¥${fmt(D.month.cost, 1)}</b><i>8 / 9 次</i></div>
        </section>
        <section class="c-entries">
          <h2>最近</h2>
          <a class="c-entry" data-page="drive">
            <time>10/26 · 16:05</time>
            <h3>松岚小区 → 云栖中心</h3>
            <p>46 分钟 · 净电耗 154 Wh/km</p>
            <b>${fmt(D.drive.distance, 1)}<i>km</i></b>
          </a>
          <a class="c-entry" data-page="charging">
            <time>10/26 · 14:05</time>
            <h3>湖畔超级充电站</h3>
            <p>18→82% · 34 分钟</p>
            <b>${fmt(46.8, 1)}<i>kWh</i></b>
          </a>
        </section>
        <p class="c-foot">数据不是实时。采样于 ${D.time}；估算口径见数据说明。</p>
      </main>
      ${cNav('overview')}
    </div>`;
  }

  function cStatistics() {
    return `<div class="c-page">
      ${cMast}
      <div class="c-status"><span>统计 · 十月</span><span>本期 / 参照</span></div>
      <main class="c-body">
        <header class="c-stat-head">
          <p class="c-kicker">十月 · 里程</p>
          <h1>比上月多跑了<br><em>${fmt(deltaKm, 1)}</em> 公里。</h1>
          <p class="c-sub">${fmt(D.month.km, 1)} 公里 · ${D.month.trips} 趟 · 净电耗 ${D.month.net} Wh/km。</p>
        </header>
        <figure class="c-plate">
          <div class="c-plate-head"><span>里程走势</span><span>本期 / 参照</span></div>
          ${chartC(D.days, D.prevDays)}
          <figcaption><span>10/26 · 60.0 km</span><span>参照 55.4 km</span></figcaption>
        </figure>
        <section class="c-chapters">
          <a class="c-chapter" data-page="statistics"><span>01 · 节奏</span><b>${D.month.active}<i>天</i></b><p>13h18 驾驶 · 单程中位 18.6 km</p><em>读下去 →</em></a>
          <a class="c-chapter" data-page="statistics"><span>02 · 能耗</span><b>${D.month.net}<i>Wh/km</i></b><p>较参照低 8 Wh/km</p><em>读下去 →</em></a>
          <a class="c-chapter" data-page="statistics"><span>03 · 补能</span><b>¥${fmt(D.month.cost, 1)}</b><p>8 / 9 次有记录 · 234.7 kWh</p><em>读下去 →</em></a>
          <a class="c-chapter" data-page="statistics"><span>04 · 长期</span><b>316<i>km</i></b><p>近 6 个月额定续航</p><em>读下去 →</em></a>
        </section>
        <p class="c-foot">总计与比率取服务端返回值，不从前端分桶加总。</p>
      </main>
      ${cNav('statistics')}
    </div>`;
  }

  function cDrives() {
    return `<div class="c-page">
      ${cMast}
      <div class="c-status"><span>行程 · 近 30 天</span><span>9.27 — 10.26</span></div>
      <main class="c-body">
        <header class="c-stat-head">
          <p class="c-kicker">最近的路</p>
          <h1>${fmt(1280.6, 1)} <em>公里</em><br>52 趟。</h1>
          <p class="c-sub">估算 197.47 kWh · 净电耗 154 Wh/km。</p>
        </header>
        <section class="c-rhythm">
          <div class="c-plate-head"><span>出行节奏</span><span>km / day</span></div>
          <div class="c-rhythm-bars">${D.days.map((v, i) => `<i style="height:${Math.max(2, (v / 108.3) * 54)}px" class="${i === D.days.length - 1 ? 'is-current' : ''}"></i>`).join('')}</div>
          <div class="c-rhythm-axis"><span>10/01</span><span>10/13</span><span>10/26</span></div>
        </section>
        <section class="c-entries c-entries-drives">
          ${D.drives.map((d, i) => `<a class="c-entry${i === 0 ? ' is-lead' : ''}" data-page="drive">
            <time>${d.date} · ${d.time}</time>
            <h3>${d.start} → ${d.end}</h3>
            <p>${d.min} 分钟 · 净电耗 ${d.net} Wh/km</p>
            <b>${fmt(d.km, 1)}<i>km</i></b>
          </a>`).join('')}
        </section>
        <p class="c-foot">保留日筛选与分页；这里只展示最近六条。</p>
      </main>
      ${cNav('drives')}
    </div>`;
  }

  function cDrive() {
    return `<div class="c-page">
      <section class="c-map-plate">
        ${mapC()}
        <div class="c-mapbar"><button aria-label="返回">${icon('chevron')}</button><span>10/26 · 16:05</span><button aria-label="更多">${icon('more')}</button></div>
      </section>
      <main class="c-body c-detail">
        <p class="c-kicker">行程 · 最近一次</p>
        <h1>松岚小区<br><em>→</em> 云栖中心</h1>
        <p class="c-sub">${fmt(D.drive.distance, 1)} 公里，${D.drive.duration} 分钟。到达时电量 ${D.drive.endSoc}%。</p>
        <div class="c-detail-stats">
          <div><span>时长</span><b>46<i>min</i></b></div>
          <div><span>净电耗</span><b>154<i>Wh/km</i></b></div>
          <div><span>能量</span><b>5.07<i>kWh</i></b></div>
        </div>
        <figure class="c-plate">
          <div class="c-plate-head"><span>速度过程</span><span>km/h</span></div>
          ${chartC(D.speed, null, 312, 108)}
          <figcaption><span>最高 118 km/h · 平均 43</span><span>点按读值</span></figcaption>
        </figure>
        <section class="c-ledger">
          <div class="c-ledger-row"><span>电量</span><b>76 → 68</b><i>%</i></div>
          <div class="c-ledger-row"><span>最高速度</span><b>118</b><i>km/h</i></div>
          <div class="c-ledger-row"><span>海拔</span><b>+120 / −140</b><i>m</i></div>
          <div class="c-ledger-row"><span>外部温度</span><b>22</b><i>°C</i></div>
        </section>
        <p class="c-foot">净电耗为估算值，含驾驶能耗，不含停放与充电损耗。路线为示意，非导航。</p>
      </main>
    </div>`;
  }

  function cCharging() {
    return `<div class="c-page">
      ${cMast}
      <div class="c-status"><span>补能 · 十月</span><span>9 次 · CNY</span></div>
      <main class="c-body">
        <header class="c-charge-head">
          <p class="c-kicker">补能账本</p>
          <h1>这个月，<br>补能花了<br><em>¥${fmt(D.month.cost, 1)}</em>。</h1>
          <p class="c-sub">8 / 9 次有记录；覆盖 214 kWh。未记录的 1 次不计入均价。</p>
        </header>
        <figure class="c-plate">
          <div class="c-plate-head"><span>每日补能</span><span>kWh</span></div>
          ${stemC([0,0,0,28,0,0,33.2,0,29.4,0,20.7,0,0,13.8,0,0,16,0,24.1,0,0,22.7,0,0,28,46.8], 312, 104, 60)}
          <figcaption><span>10/26 · 46.8 kWh</span><span>点按读值</span></figcaption>
        </figure>
        <section class="c-ledger">
          <div class="c-ledger-row"><span>充入电池</span><b>234.7</b><i>kWh</i></div>
          <div class="c-ledger-row"><span>次数</span><b>9</b><i>次</i></div>
          <div class="c-ledger-row"><span>记录时长</span><b>5h10</b><i></i></div>
          <div class="c-ledger-row"><span>均价</span><b>0.87</b><i>¥/kWh</i></div>
        </section>
        <section class="c-mix">
          <div class="c-plate-head"><span>构成</span><span>仅已知分类</span></div>
          <div class="c-mixbar"><i class="ac" style="width:${(D.month.ac / D.month.charge) * 100}%"></i><i class="dc" style="width:${(D.month.dc / D.month.charge) * 100}%"></i><i class="un" style="width:${(D.month.unknown / D.month.charge) * 100}%"></i></div>
          <div class="c-mixlabels"><span><i class="ac"></i>AC 118.0</span><span><i class="dc"></i>DC 96.0</span><span><i class="un"></i>未知 20.7</span></div>
          <p>DC 占已知分类 44.9%；未知类型不计入比例。</p>
        </section>
        <section class="c-entries c-entries-places">
          <h2>地点</h2>
          <a class="c-entry"><time>6 次 · 142.3 kWh</time><h3>家</h3><p>已知费用 ¥98.4</p><b>¥98.4</b></a>
          <a class="c-entry"><time>2 次 · 71.2 kWh</time><h3>湖畔超充</h3><p>已知费用 ¥66.0</p><b>¥66.0</b></a>
          <a class="c-entry"><time>1 次 · 21.2 kWh</time><h3>公司</h3><p>已知费用 ¥22.0</p><b>¥22.0</b></a>
        </section>
        <p class="c-foot">费用只统计已记录值；缺失不补零，不把未知类型计入 AC/DC 比例</p>
      </main>
      ${cNav('charging')}
    </div>`;
  }

  const VARIANTS = {
    A: { name: '夜航', caption: '一块夜里的仪表玻璃，其余退成纸面。', pages: { overview: aOverview, statistics: aStatistics, drives: aDrives, drive: aDrive, charging: aCharging }, nav: navA },
    B: { name: '仪表', caption: '像读一块精密仪表，每个数字都有刻度。', pages: { overview: bOverview, statistics: bStatistics, drives: bDrives, drive: bDrive, charging: bCharging }, nav: navB },
    C: { name: '夜读', caption: '把一个月写成一段夜读：大字、留白、纸感。', pages: { overview: cOverview, statistics: cStatistics, drives: cDrives, drive: cDrive, charging: cCharging }, nav: navC },
  };

  const PAGE_NAMES = { overview: '概览', statistics: '统计', drives: '行程', drive: '行程详情', charging: '充电' };
  const PAGE_TAB = { overview: 'overview', statistics: 'statistics', drives: 'drives', drive: 'drives', charging: 'charging' };

  const state = {
    variant: 'A', page: 'overview', theme: 'dark', palette: 'jade', capture: false,
  };

  function readState() {
    const p = new URLSearchParams(location.search);
    state.variant = (p.get('variant') || 'A').toUpperCase();
    if (!VARIANTS[state.variant]) state.variant = 'A';
    state.page = p.get('page') || 'overview';
    if (!PAGE_NAMES[state.page]) state.page = 'overview';
    state.theme = p.get('theme') === 'light' ? 'light' : 'dark';
    state.palette = ['jade', 'teal', 'moss'].includes(p.get('palette')) ? p.get('palette') : 'jade';
    state.capture = p.get('capture') === '1';
  }

  function phoneMarkup() {
    const v = VARIANTS[state.variant];
    return `<article class="phone v-${state.variant.toLowerCase()} t-${state.theme} p-${state.palette}" data-variant="${state.variant}">
      <div class="screen">${v.pages[state.page]()}</div>
    </article>`;
  }

  function sidebarMarkup() {
    return `<aside class="sidebar">
      <div class="side-brand"><span>行笺</span><small>方向评审 v2</small></div>
      <p class="side-note">同一组固定数据，三种阅读顺序。深色为主，浅色对照。不是换色稿。</p>
      <div class="variant-list">
        ${Object.entries(VARIANTS).map(([key, v]) => `<button class="variant-button${state.variant === key ? ' is-active' : ''}" data-variant="${key}">
          <b>${key}</b><span><strong>${v.name}</strong><small>${v.caption}</small></span>
        </button>`).join('')}
      </div>
      <div class="side-controls">
        <div class="control"><label>页面</label><div class="seg">${Object.entries(PAGE_NAMES).map(([key, name]) => `<button data-page="${key}" class="${state.page === key ? 'is-active' : ''}">${name}</button>`).join('')}</div></div>
        <div class="control"><label>主题</label><div class="seg"><button data-theme="dark" class="${state.theme === 'dark' ? 'is-active' : ''}">深色</button><button data-theme="light" class="${state.theme === 'light' ? 'is-active' : ''}">浅色</button></div></div>
        <div class="control"><label>强调色（仅 A）</label><div class="seg"><button data-palette="jade" class="${state.palette === 'jade' ? 'is-active' : ''}">玉绿</button><button data-palette="teal" class="${state.palette === 'teal' ? 'is-active' : ''}">青绿</button><button data-palette="moss" class="${state.palette === 'moss' ? 'is-active' : ''}">苔绿</button></div></div>
      </div>
      <div class="side-foot">固定样例 · 2026-10-26 18:40<br>360 × 800 · 无外部资源<br><a href="?variant=${state.variant}&page=${state.page}&theme=${state.theme}&palette=${state.palette}&capture=1">单屏截图 ↗</a></div>
    </aside>`;
  }

  function render() {
    readState();
    document.body.classList.toggle('capture', state.capture);
    const app = document.getElementById('app');
    if (state.capture) {
      app.innerHTML = phoneMarkup();
      return;
    }
    app.innerHTML = `<div class="review">
      ${sidebarMarkup()}
      <main class="stage">
        <header class="stage-head">
          <p class="eyebrow">Mileaf / Directions v2 / 2026.11</p>
          <h1>${VARIANTS[state.variant].name}：${VARIANTS[state.variant].caption}</h1>
          <p>${PAGE_NAMES[state.page]} · ${state.theme === 'dark' ? '深色' : '浅色'} · 360 × 800。固定合成数据，仅评审版面与视觉，不连接站点。</p>
        </header>
        ${phoneMarkup()}
        <p class="stage-foot">方向 A 为推荐；B/C 用于比较信息密度与品牌气质。截图入口在左侧底部。</p>
      </main>
    </div>`;
    app.querySelectorAll('[data-variant]').forEach((el) => el.addEventListener('click', () => {
      const p = new URLSearchParams(location.search);
      p.set('variant', el.dataset.variant);
      location.search = p.toString();
    }));
    app.querySelectorAll('[data-page]').forEach((el) => el.addEventListener('click', () => {
      const p = new URLSearchParams(location.search);
      p.set('page', el.dataset.page);
      location.search = p.toString();
    }));
    app.querySelectorAll('[data-theme]').forEach((el) => el.addEventListener('click', () => {
      const p = new URLSearchParams(location.search);
      p.set('theme', el.dataset.theme);
      location.search = p.toString();
    }));
    app.querySelectorAll('[data-palette]').forEach((el) => el.addEventListener('click', () => {
      const p = new URLSearchParams(location.search);
      p.set('palette', el.dataset.palette);
      location.search = p.toString();
    }));
  }

  render();
})();
