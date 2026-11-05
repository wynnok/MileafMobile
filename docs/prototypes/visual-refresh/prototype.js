/*
 * THROWAWAY DESIGN PROTOTYPE.
 * Three visual systems for Mileaf / 行笺. Fixed synthetic data only.
 * No API, no persistence, no production code, no external assets.
 */
(() => {
  'use strict';

  const MONTH_DAYS = [
    32.4, 48.6, 0, 62.5, 54.8, 35.2, 108.3, 0, 42.6, 38.9, 55.4, 96.7,
    31.2, 0, 64.8, 47.5, 39.6, 82.4, 25.8, 0, 52.6, 44.3, 57.8, 69.5,
    32.9, 74.8,
  ];
  const PREV_DAYS = [
    31.9, 45.9, 0, 58.9, 52.9, 34.9, 99.9, 0, 41.9, 38.9, 52.9, 88.9,
    31.9, 0, 61.9, 42, 35, 73, 23, 0, 47, 39, 51, 61, 29, 66,
  ];
  const NET_DAYS = [
    155, 148, null, 162, 158, 147, 168, null, 151, 145, 158, 174, 150,
    null, 159, 155, 148, 165, 150, null, 153, 152, 161, 162, 145, 154,
  ];
  const PREV_NET = [
    162, 158, null, 168, 164, 155, 172, null, 160, 154, 166, 180, 158,
    null, 166, 162, 157, 171, 158, null, 160, 159, 168, 168, 152, 161,
  ];
  const DRIVE_EXTRA = [18.2, 25.4, 12.7, 25.7];
  const DRIVE_DAYS = [...DRIVE_EXTRA, ...MONTH_DAYS];
  const DRIVE_LABELS = [
    '9/27', '9/28', '9/29', '9/30', ...MONTH_DAYS.map((_, i) => `10/${i + 1}`),
  ];
  const MONTH_LABELS = MONTH_DAYS.map((_, i) => `10/${i + 1}`);

  const SESSIONS = [
    { id: 1, day: 26, date: '10/26', start: '13:12', end: '13:46', place: '湖畔超级充电站', area: '湖畔', dc: true, energy: 46.8, cost: 71.28, duration: 34, startSoc: 18, endSoc: 82, peak: 168 },
    { id: 2, day: 25, date: '10/25', start: '20:12', end: '21:00', place: '家', area: '家', dc: false, energy: 28.0, cost: 22.4, duration: 48, startSoc: 24, endSoc: 80, peak: 11 },
    { id: 3, day: 23, date: '10/23', start: '19:40', end: '20:06', place: '湖畔超级充电站', area: '湖畔', dc: true, energy: 33.2, cost: 30.32, duration: 26, startSoc: 12, endSoc: 68, peak: 162 },
    { id: 4, day: 21, date: '10/21', start: '09:10', end: '10:05', place: '公司', area: '公司', dc: false, energy: 29.4, cost: 16.6, duration: 55, startSoc: 40, endSoc: 96, peak: 11 },
    { id: 5, day: 20, date: '10/20', start: '22:30', end: '23:06', place: '未定位', area: '未知', dc: null, energy: 20.7, cost: null, duration: 36, startSoc: 50, endSoc: 70, peak: null },
    { id: 6, day: 18, date: '10/18', start: '21:05', end: '21:43', place: '家', area: '家', dc: false, energy: 24.1, cost: 12.8, duration: 38, startSoc: 20, endSoc: 65, peak: 11 },
    { id: 7, day: 17, date: '10/17', start: '12:20', end: '12:38', place: '湖畔超级充电站', area: '湖畔', dc: true, energy: 16.0, cost: 13.0, duration: 18, startSoc: 55, endSoc: 78, peak: 150 },
    { id: 8, day: 14, date: '10/14', start: '18:30', end: '18:50', place: '家', area: '家', dc: false, energy: 13.8, cost: 8.5, duration: 20, startSoc: 35, endSoc: 52, peak: 11 },
    { id: 9, day: 11, date: '10/11', start: '19:50', end: '20:25', place: '家', area: '家', dc: false, energy: 22.7, cost: 11.5, duration: 35, startSoc: 30, endSoc: 74, peak: 11 },
  ];

  const DRIVES = [
    { id: 101, date: '10/26', time: '17:52', start: '松岚小区', end: '云栖中心', distance: 32.9, duration: 46, consumption: 145, energy: 4.77, startSoc: 76, endSoc: 68, featured: true },
    { id: 102, date: '10/26', time: '08:30', start: '家', end: '公司', distance: 18.4, duration: 32, consumption: 162, energy: 2.98, startSoc: 84, endSoc: 78 },
    { id: 103, date: '10/25', time: '18:10', start: '公司', end: '湖畔超级充电站', distance: 12.6, duration: 24, consumption: 138, energy: 1.74, startSoc: 72, endSoc: 68 },
    { id: 104, date: '10/24', time: '09:40', start: '家', end: '松岚公园', distance: 7.8, duration: 18, consumption: 171, energy: 1.33, startSoc: 66, endSoc: 63 },
    { id: 105, date: '10/23', time: '18:20', start: '公司', end: '家', distance: 18.7, duration: 41, consumption: 154, energy: 2.88, startSoc: 79, endSoc: 75 },
    { id: 106, date: '10/22', time: '10:05', start: '家', end: '云栖中心', distance: 27.6, duration: 39, consumption: 149, energy: 4.11, startSoc: 88, endSoc: 82 },
  ];

  const TEMP_BINS = [
    { label: '≤5°', value: 172, samples: 4 },
    { label: '5–15°', value: 161, samples: 13 },
    { label: '15–25°', value: 154, samples: 21 },
    { label: '25–35°', value: 149, samples: 7 },
    { label: '≥35°', value: 157, samples: 1 },
  ];
  const DIST_BINS = [
    { label: '<10 km', drives: 18, distance: 92, value: 176 },
    { label: '10–50', drives: 22, distance: 560, value: 158 },
    { label: '≥50', drives: 6, distance: 546, value: 151 },
  ];
  const RANGE_MONTHS = [
    { label: '5月', value: 318, samples: 12 },
    { label: '6月', value: 321, samples: 10 },
    { label: '7月', value: 317, samples: 14 },
    { label: '8月', value: 316, samples: 9 },
    { label: '9月', value: 314, samples: 11 },
    { label: '10月', value: 316, samples: 8 },
  ];
  const DRIVE_SPEED = [0, 12, 24, 38, 46, 55, 58, 62, 74, 88, 91, 84, 76, 70, 65, 60, 55, 48, 40, 30, 18, 6, 0];
  const DRIVE_SPEED_LABELS = DRIVE_SPEED.map((_, index) => {
    const total = 17 * 60 + 52 + index * 2;
    return `${String(Math.floor(total / 60)).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`;
  });
  const DRIVE_BATTERY = [76, 75.6, 75.2, 74.8, 74.2, 73.5, 72.8, 72.2, 71.5, 70.8, 70.2, 69.7, 69.2, 68.9, 68.6, 68.4, 68.2, 68.0, 67.8, 67.5, 67.2, 67.0, 66.8];
  const DRIVE_ELEVATION = [42, 44, 47, 53, 58, 61, 59, 55, 52, 49, 47, 45, 44, 43, 43, 42, 42, 41, 40, 39, 39, 38, 38];
  const POWER_CURVE = [0, 168, 166, 158, 150, 142, 132, 120, 110, 100, 90, 80, 70, 60, 50, 40, 30, 18, 0];
  const POWER_LABELS = POWER_CURVE.map((_, index) => String(Math.round((index * 34) / (POWER_CURVE.length - 1))));
  const SOC_CURVE = [18, 25, 31, 38, 45, 52, 58, 64, 70, 74, 77, 79, 81, 82];
  const SOC_LABELS = SOC_CURVE.map((value) => `${value}%`);

  const DATA = {
    asOf: '2026-10-26T18:40:00+08:00',
    vehicle: { name: '行笺测试车', model: 'Model 3', vin: '···4821' },
    status: { state: '充电中', soc: 68, range: 320, power: 11.0, updated: '2 分钟前', todayDistance: 60.0, todayTrips: 3, todayEnergy: 11.25 },
    month: { distance: 1198.6, trips: 46, energy: 189.3, net: 158, charge: 234.7, sessions: 9, cost: 186.4, knownSessions: 8, knownEnergy: 214.0, avgCost: 0.871, active: 22 },
  };

  const ICONS = {
    leaf: '<path d="M12 3c-3 3-3 6 0 8 3-2 3-5 0-8Z"/><path d="M3 10c1 7 4 10 9 11-1-7-4-10-9-11Zm18 0c-1 7-4 10-9 11 1-7 4-10 9-11Z"/>',
    home: '<path d="m3 11 9-8 9 8M6 9v12h12V9M10 21v-7h4v7"/>',
    car: '<path d="m5 5-2 8v7h3v-3h12v3h3v-7l-2-8Zm-2 8h18M7 9h10"/><path d="M6 14h2m8 0h2"/>',
    bolt: '<path d="m13 2-8 12h6l-1 8 9-13h-6l1-7Z"/>',
    chart: '<path d="M4 21V12h4v9m3 0V4h4v17m3 0V8h4v13"/>',
    chevron: '<path d="m9 6 6 6-6 6"/>',
    'chevron-down': '<path d="m6 9 6 6 6-6"/>',
    'arrow-left': '<path d="M19 12H5m6-6-6 6 6 6"/>',
    'arrow-right': '<path d="M5 12h14m-6-6 6 6-6 6"/>',
    'arrow-up': '<path d="M12 19V5m-6 6 6-6 6 6"/>',
    refresh: '<path d="M20 7v5h-5M20 12a8 8 0 1 0-2 6"/>',
    calendar: '<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M8 3v4m8-4v4M3 10h18"/>',
    route: '<circle cx="6" cy="19" r="2"/><circle cx="18" cy="5" r="2"/><path d="M8 19h6a4 4 0 0 0 0-8h-2a4 4 0 0 1 0-8h3"/>',
    spark: '<path d="m12 3 2.4 6.6L21 12l-6.6 2.4L12 21l-2.4-6.6L3 12l6.6-2.4Z"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v5m0-8h.01"/>',
    battery: '<rect x="3" y="7" width="16" height="10" rx="2"/><path d="M21 10v4M7 10v4m4-4v4m4-4v4"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    'map-pin': '<path d="M20 10c0 6-8 11-8 11S4 16 4 10a8 8 0 1 1 16 0Z"/><circle cx="12" cy="10" r="2.5"/>',
    wallet: '<path d="M4 6h14a2 2 0 0 1 2 2v10H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2Z"/><path d="M16 12h5v4h-5a2 2 0 0 1 0-4Z"/>',
    menu: '<circle cx="5" cy="12" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="19" cy="12" r="1.4"/>',
    grid: '<rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><rect x="14" y="14" width="6" height="6" rx="1"/>',
    drop: '<path d="M12 3s6 7 6 11a6 6 0 0 1-12 0c0-4 6-11 6-11Z"/>',
    temp: '<path d="M14 14.8V5a2 2 0 1 0-4 0v9.8a4 4 0 1 0 4 0Z"/><path d="M12 9v7"/>',
    close: '<path d="m6 6 12 12M18 6 6 18"/>',
    check: '<path d="m5 12 4 4L19 6"/>',
  };

  const icon = (name) =>
    `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICONS[name] || ICONS.chart}</svg>`;

  const fmt = (value, digits = 1) =>
    value == null
      ? '—'
      : Number(value).toLocaleString('en-US', {
          minimumFractionDigits: digits,
          maximumFractionDigits: digits,
        });
  const int = (value) => fmt(value, 0);
  const signed = (value, digits = 1) => `${value >= 0 ? '+' : '−'}${fmt(Math.abs(value), digits)}`;
  const money = (value, digits = 2) => (value == null ? '未记录' : `¥${fmt(value, digits)}`);
  const pct = (value) => (value == null ? '—' : `${fmt(value, 0)}%`);
  const sum = (values) => values.reduce((a, b) => a + (b ?? 0), 0);
  const avg = (values) => {
    const valid = values.filter((v) => v != null);
    return valid.length ? sum(valid) / valid.length : null;
  };
  const pointIndex = (key, length) => {
    const value = state.points[key];
    return Math.min(Math.max(Number.isFinite(value) ? value : length - 1, 0), length - 1);
  };

  const state = {
    variant: 'A',
    page: 'overview',
    theme: 'light',
    scale: '100',
    sample: 'normal',
    period: 'm',
    metric: 'distance',
    chargeMetric: 'energy',
    detailMetric: 'speed',
    chargeDetailMetric: 'power',
    topic: 'rhythm',
    sheet: null,
    points: { 'drive-detail': 10, 'charge-detail': 4, 'b-drive-detail': 10, 'b-charge-detail': 4, 'c-drive-detail': 10, 'c-charge-detail': 4 },
    compare: false,
    full: false,
    capture: false,
  };

  /* ---------- derived data ---------- */
  function lastDays(count) {
    return { values: MONTH_DAYS.slice(-count), labels: MONTH_LABELS.slice(-count), net: NET_DAYS.slice(-count), prevNet: PREV_NET.slice(-count) };
  }

  function overviewData() {
    if (state.period === 'w') {
      const d = lastDays(7);
      return {
        labels: d.labels,
        current: d.values,
        previous: PREV_DAYS.slice(-7),
        total: 331.9,
        prevTotal: 291.3,
        trips: 12,
        energy: 52.5,
        net: 158.1,
        prevNet: 165,
        charge: 158.1,
        sessions: 5,
        cost: 140.6,
        knownSessions: 4,
        knownEnergy: 137.4,
        avgCost: 1.023,
        active: 6,
        netSeries: d.net,
        prevNetSeries: d.prevNet,
        startOffset: 0,
      };
    }
    return {
      labels: MONTH_LABELS,
      current: MONTH_DAYS,
      previous: PREV_DAYS,
      total: 1198.6,
      prevTotal: 1107.3,
      trips: 46,
      energy: 189.3,
      net: 158,
      prevNet: 166,
      charge: 234.7,
      sessions: 9,
      cost: 186.4,
      knownSessions: 8,
      knownEnergy: 214,
      avgCost: 0.871,
      active: 22,
      netSeries: NET_DAYS,
      prevNetSeries: PREV_NET,
      startOffset: 3,
    };
  }

  function drivesData() {
    if (state.period === 'w') {
      return {
        labels: DRIVE_LABELS.slice(-7),
        current: DRIVE_DAYS.slice(-7),
        total: 331.9,
        trips: 12,
        energy: 52.5,
        net: 158.1,
      };
    }
    return {
      labels: DRIVE_LABELS,
      current: DRIVE_DAYS,
      total: 1280.6,
      trips: 52,
      energy: 197.4,
      net: 154.2,
    };
  }

  function chargeDaily(days) {
    const energy = Array(days).fill(0);
    const cost = Array(days).fill(null);
    const sessions = Array(days).fill(0);
    for (const s of SESSIONS) {
      const dayIndex = state.period === 'w' ? s.day - 20 : s.day + 3;
      if (dayIndex >= 0 && dayIndex < days) {
        energy[dayIndex] += s.energy;
        sessions[dayIndex] += 1;
        if (s.cost != null) cost[dayIndex] = (cost[dayIndex] ?? 0) + s.cost;
      }
    }
    return { energy, cost, sessions };
  }

  function chargingData() {
    if (state.period === 'w') {
      const daily = chargeDaily(7);
      return {
        labels: DRIVE_LABELS.slice(-7),
        energy: daily.energy,
        cost: daily.cost,
        sessions: daily.sessions,
        totalEnergy: 158.1,
        totalCost: 140.6,
        sessionCount: 5,
        knownSessions: 4,
        knownEnergy: 137.4,
        avgCost: 1.023,
        duration: 199,
        ac: 57.4,
        dc: 80,
        unknown: 20.7,
        locations: [
          { name: '湖畔超级充电站', count: 2, energy: 80, cost: 101.6, known: 2, mode: 'DC' },
          { name: '家', count: 1, energy: 28, cost: 22.4, known: 1, mode: 'AC' },
          { name: '公司', count: 1, energy: 29.4, cost: 16.6, known: 1, mode: 'AC' },
          { name: '未定位', count: 1, energy: 20.7, cost: null, known: 0, mode: '未知' },
        ],
      };
    }
    const daily = chargeDaily(30);
    return {
      labels: DRIVE_LABELS,
      energy: daily.energy,
      cost: daily.cost,
      sessions: daily.sessions,
      totalEnergy: 234.7,
      totalCost: 186.4,
      sessionCount: 9,
      knownSessions: 8,
      knownEnergy: 214,
      avgCost: 0.871,
      duration: 310,
      ac: 118,
      dc: 96,
      unknown: 20.7,
      locations: [
        { name: '湖畔超级充电站', count: 3, energy: 96, cost: 114.6, known: 3, mode: 'DC' },
        { name: '家', count: 4, energy: 88.6, cost: 55.2, known: 4, mode: 'AC' },
        { name: '公司', count: 1, energy: 29.4, cost: 16.6, known: 1, mode: 'AC' },
        { name: '未定位', count: 1, energy: 20.7, cost: null, known: 0, mode: '未知' },
      ],
    };
  }

  function statsData() {
    if (state.period === 'w') {
      return {
        labels: MONTH_LABELS.slice(-7),
        current: MONTH_DAYS.slice(-7),
        previous: PREV_DAYS.slice(-7),
        total: 331.9,
        prevTotal: 291.3,
        trips: 12,
        net: 158.1,
        prevNet: 165,
        cost: 140.6,
        active: 6,
        durationMin: 194,
        medianTrip: 18.6,
        p90: 76,
      };
    }
    return {
      labels: MONTH_LABELS,
      current: MONTH_DAYS,
      previous: PREV_DAYS,
      total: 1198.6,
      prevTotal: 1107.3,
      trips: 46,
      net: 158,
      prevNet: 166,
      cost: 186.4,
      active: 22,
      durationMin: 798,
      medianTrip: 18.6,
      p90: 76,
    };
  }

  function weekdayTotals(days) {
    const values = Array(7).fill(0);
    days.forEach((value, index) => {
      const date = new Date(2026, 9, 1 + index);
      const monday = (date.getDay() + 6) % 7;
      values[monday] += value;
    });
    return values;
  }

  const WEEKDAY_LABELS = ['一', '二', '三', '四', '五', '六', '日'];

  function calLevel(value) {
    if (value == null || value === 0) return 0;
    if (value < 30) return 1;
    if (value < 60) return 2;
    if (value < 90) return 3;
    return 4;
  }

  /* ---------- charts ---------- */
  function linePath(series, x, y) {
    let d = '';
    let open = false;
    series.forEach((value, index) => {
      if (value == null) {
        open = false;
        return;
      }
      d += `${open ? 'L' : 'M'}${x(index).toFixed(2)},${y(value).toFixed(2)} `;
      open = true;
    });
    return d.trim();
  }

  function areaPath(series, x, y, baseline) {
    const parts = [];
    let segment = [];
    const flush = () => {
      if (segment.length < 2) {
        segment = [];
        return;
      }
      let d = `M${x(segment[0][0]).toFixed(2)},${baseline.toFixed(2)} `;
      for (const [index, value] of segment) d += `L${x(index).toFixed(2)},${y(value).toFixed(2)} `;
      d += `L${x(segment[segment.length - 1][0]).toFixed(2)},${baseline.toFixed(2)} Z`;
      parts.push(d);
      segment = [];
    };
    series.forEach((value, index) => {
      if (value == null) flush();
      else segment.push([index, value]);
    });
    flush();
    return parts.join(' ');
  }

  function chartSvg(options) {
    const {
      values,
      previous = null,
      labels,
      key,
      type = 'bars',
      height = 142,
      unit = '',
      showY = true,
      showX = true,
      showGrid = true,
      min = null,
      max = null,
      point = null,
      aria = '趋势图',
      fill = true,
      variant = 'a',
    } = options;
    const W = 310;
    const H = height;
    const L = showY ? 27 : 5;
    const R = 306;
    const T = 11;
    const B = H - (showX ? 21 : 5);
    const all = [...values, ...(previous || [])].filter((v) => v != null);
    let lo = min == null ? 0 : min;
    let hi = max == null ? Math.max(1, ...all) : max;
    if (hi === lo) hi = lo + 1;
    if (max == null) hi = hi * 1.1;
    if (min == null) lo = Math.min(0, ...(all.length ? all : [0]));
    const plotW = R - L;
    const x = (i) => L + 5 + (i * (plotW - 10)) / Math.max(1, values.length - 1);
    const y = (v) => T + ((hi - v) / (hi - lo)) * (B - T);
    const base = y(lo);
    const slot = plotW / Math.max(1, values.length);
    const barW = Math.min(13, Math.max(3, slot * (type === 'bars' ? 0.56 : 0.4)));
    const selected = point == null ? values.length - 1 : Math.min(point, values.length - 1);
    const ticks = [hi, (hi + lo) / 2, lo];
    const axisFmt = (v) => fmt(v, Number.isInteger(v) ? 0 : 1);
    const grid = showGrid
      ? ticks
          .map(
            (t) =>
              `<line x1="${L}" x2="${R}" y1="${y(t).toFixed(1)}" y2="${y(t).toFixed(1)}" class="chart-grid"/>` +
              (showY
                ? `<text x="${L - 5}" y="${(y(t) + 3).toFixed(1)}" text-anchor="end" class="chart-axis">${axisFmt(t)}</text>`
                : ''),
          )
          .join('')
      : '';
    const xTicks = showX
      ? [0, Math.floor((values.length - 1) / 2), values.length - 1]
          .filter((v, i, arr) => arr.indexOf(v) === i)
          .map(
            (i) =>
              `<text x="${x(i).toFixed(1)}" y="${H - 5}" text-anchor="${i === 0 ? 'start' : i === values.length - 1 ? 'end' : 'middle'}" class="chart-axis">${labels[i] || ''}</text>`,
          )
          .join('')
      : '';
    let marks = '';
    if (type === 'bars') {
      marks = values
        .map((value, i) => {
          if (value == null || value === 0) {
            return `<circle cx="${x(i).toFixed(1)}" cy="${base.toFixed(1)}" r="1.25" class="chart-zero"/>`;
          }
          const top = y(value);
          const h = Math.max(1.2, base - top);
          return `<rect x="${(x(i) - barW / 2).toFixed(1)}" y="${top.toFixed(1)}" width="${barW.toFixed(1)}" height="${h.toFixed(1)}" rx="2.4" class="chart-bar ${i === selected ? 'hot' : ''}"/>`;
        })
        .join('');
    } else {
      const area = fill ? areaPath(values, x, y, base) : '';
      const line = linePath(values, x, y);
      marks =
        (area ? `<path d="${area}" class="chart-area"/>` : '') +
        `<path d="${line}" class="chart-line"/>` +
        values
          .map((value, i) =>
            value == null
              ? ''
              : `<circle cx="${x(i).toFixed(1)}" cy="${y(value).toFixed(1)}" r="${i === selected ? 2.7 : 1.5}" class="chart-dot ${i === selected ? 'hot' : ''}"/>`,
          )
          .join('');
    }
    let ref = '';
    if (previous) {
      ref =
        `<path d="${linePath(previous, x, y)}" class="chart-line ref"/>` +
        previous
          .map((value, i) =>
            value == null
              ? ''
              : `<circle cx="${x(i).toFixed(1)}" cy="${y(value).toFixed(1)}" r="1.2" class="chart-dot ref"/>`,
          )
          .join('');
    }
    const cursor =
      point != null
        ? `<line x1="${x(selected).toFixed(1)}" x2="${x(selected).toFixed(1)}" y1="${T}" y2="${B}" class="chart-cursor"/>`
        : '';
    const hits = values
      .map(
        (value, i) =>
          `<rect x="${(x(i) - slot / 2).toFixed(1)}" y="${T}" width="${slot.toFixed(1)}" height="${Math.max(1, B - T)}" fill="transparent" class="chart-hit" data-action="point" data-value="${key}:${i}"><title>${labels[i]}: ${value == null ? '缺失' : `${fmt(value, unit === 'CNY' ? 2 : 1)} ${unit}`}</title></rect>`,
      )
      .join('');
    return `<svg viewBox="0 0 ${W} ${H}" class="chart-svg" role="img" aria-label="${aria}" preserveAspectRatio="xMidYMid meet">${grid}${marks}${ref}${cursor}${xTicks}${hits}</svg>`;
  }

  function sparkSvg(values, options = {}) {
    const { width = 150, height = 42, previous = null, fill = true } = options;
    const all = [...values, ...(previous || [])].filter((v) => v != null);
    const lo = Math.min(...(all.length ? all : [0]));
    const hi = Math.max(...(all.length ? all : [1]), lo + 1);
    const x = (i) => 2 + (i * (width - 4)) / Math.max(1, values.length - 1);
    const y = (v) => 4 + ((hi - v) / (hi - lo)) * (height - 8);
    const base = height - 4;
    return `<svg viewBox="0 0 ${width} ${height}" class="spark-svg" aria-hidden="true">${
      fill ? `<path d="${areaPath(values, x, y, base)}" class="chart-area"/>` : ''
    }<path d="${linePath(values, x, y)}" class="chart-line"/>${
      previous ? `<path d="${linePath(previous, x, y)}" class="chart-line ref"/>` : ''
    }${values
      .map((v, i) => (v == null ? '' : `<circle cx="${x(i).toFixed(1)}" cy="${y(v).toFixed(1)}" r="1.2" class="chart-dot"/>`))
      .join('')}</svg>`;
  }

  function barsSvg(values, labels, options = {}) {
    return chartSvg({
      values,
      labels,
      key: options.key || 'mini',
      type: 'bars',
      height: options.height || 88,
      showY: false,
      showX: options.showX !== false,
      showGrid: false,
      point: options.point == null ? null : options.point,
      aria: options.aria || '条形图',
      variant: options.variant || 'a',
    });
  }

  function calendarGrid(days, variant = 'a') {
    const pad = 3;
    const cells = [];
    for (let i = 0; i < pad; i++) cells.push(null);
    days.forEach((value, index) => cells.push({ value, day: index + 1 }));
    while (cells.length < 35) cells.push(null);
    return `<div class="cal-weekdays">${WEEKDAY_LABELS.map((label) => `<span>${label}</span>`).join('')}</div><div class="cal-grid">${cells
      .map((cell) => {
        if (!cell) return '<span class="cal-cell empty"></span>';
        const level = calLevel(cell.value);
        const today = cell.day === 26 ? ' today' : '';
        return `<span class="cal-cell heat-${level}${today}" title="10月${cell.day}日 · ${fmt(cell.value, 1)} km"></span>`;
      })
      .join('')}</div>`;
  }

  function acdcBar(data, variant = 'a') {
    const total = data.ac + data.dc + data.unknown;
    const width = (v) => `${((v / total) * 100).toFixed(2)}%`;
    return `<div class="acdc-bar"><i class="ac" style="width:${width(data.ac)}"></i><i class="dc" style="width:${width(data.dc)}"></i>${
      data.unknown > 0 ? `<i class="unknown" style="width:${width(data.unknown)}"></i>` : ''
    }</div>`;
  }

  function ring(percent) {
    const r = 34;
    const c = 2 * Math.PI * r;
    const dash = (Math.max(0, Math.min(100, percent)) / 100) * c;
    return `<div class="ring" role="img" aria-label="电池电量 ${percent}%"><svg viewBox="0 0 86 86"><circle cx="43" cy="43" r="${r}" fill="none" stroke="var(--line)" stroke-width="5"/><circle cx="43" cy="43" r="${r}" fill="none" stroke="var(--accent)" stroke-width="5" stroke-linecap="round" stroke-dasharray="${dash.toFixed(1)} ${c.toFixed(1)}"/></svg><div class="ring-center"><strong>${percent}<span style="font-size:.6em">%</span></strong><small>电池电量</small></div></div>`;
  }

  function carSvg() {
    return `<svg viewBox="0 0 240 94" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M17 61c0-8 6-14 14-15l20-4 16-12c5-4 11-6 18-6h42c10 0 19 4 26 11l13 13 33 5c9 1 15 9 15 18v8h-24a18 18 0 0 0-36 0H78a18 18 0 0 0-36 0H17V61Z"/><path d="M82 27h31c7 0 13 3 18 9l7 8H72l10-17Z"/><path d="M116 27h19c7 0 13 3 18 9l6 8h-37l-6-17Z" opacity=".55"/><circle cx="60" cy="76" r="13"/><circle cx="187" cy="76" r="13"/><circle cx="60" cy="76" r="5"/><circle cx="187" cy="76" r="5"/></svg>`;
  }

  function mapSvg(variant = 'a') {
    return `<svg class="map map-${variant}" viewBox="0 0 320 300" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
      <rect class="map-bg" width="320" height="300"/>
      <path class="map-river" d="M-10 242C48 220 61 190 105 192s55 31 100 15 70-50 125-44"/>
      <g class="map-blocks">
        <path d="M12 30h58v38H12zM86 22h75v30H86zM180 18h56v42h-56zM250 30h58v46h-58zM18 84h46v54H18zM76 76h42v38H76zM130 62h62v48h-62zM208 82h38v42h-38zM254 90h58v38h-58zM12 158h72v44H12zM96 158h56v34H96zM164 130h38v62h-38zM216 146h52v40h-52zM278 148h40v54h-40zM22 224h58v62H22zM92 220h44v50H92zM150 214h38v58h-38zM204 210h48v46h-46zM264 220h52v52h-52z"/>
      </g>
      <g class="map-streets">
        <path d="M0 72h320M0 144h320M0 212h320M0 272h320M70 0v300M132 0v300M198 0v300M258 0v300"/>
        <path d="M0 110c65 0 75 18 128 18s67-22 192-22M0 190c70 0 94 12 146 12s92-13 174-13" class="minor"/>
      </g>
      <path class="map-route-glow" d="M28 236C66 218 61 185 102 174S157 184 172 148s27-53 52-63 39-17 61-36"/>
      <path class="map-route" d="M28 236C66 218 61 185 102 174S157 184 172 148s27-53 52-63 39-17 61-36"/>
      <circle cx="28" cy="236" r="5" class="map-start"/>
      <circle cx="285" cy="49" r="5.5" class="map-end"/>
      <circle cx="285" cy="49" r="11" class="map-end-halo"/>
    </svg>`;
  }

  function latestDrive() { return DRIVES[0]; }
  function latestCharge() { return SESSIONS[0]; }

  /* ---------- shared shell pieces ---------- */
  function nav(variant, active) {
    const items = [
      ['home', '概览', 'overview'],
      ['car', '行程', 'drives'],
      ['bolt', '充电', 'charging'],
      ['chart', '统计', 'stats'],
    ];
    return `<nav class="tabbar" aria-label="主导航">${items
      .map(
        ([ic, label, page]) =>
          `<button class="${active === page ? 'active' : ''}" data-action="page" data-value="${page}" aria-current="${active === page ? 'page' : 'false'}">${icon(ic)}<span>${label}</span></button>`,
      )
      .join('')}</nav>`;
  }

  function aAppbar() {
    return `<header class="appbar">
      <div class="brandmark">${icon('leaf')}行笺</div>
      <button class="vehicle-pill" data-action="sheet" data-value="vehicle"><b>${DATA.vehicle.name}</b>${icon('chevron-down')}</button>
      <div class="appbar-actions"><button class="icon-button" data-action="sheet" data-value="menu" aria-label="更多">${icon('menu')}</button></div>
    </header>`;
  }

  function aPeriodSwitch() {
    return `<div class="period-switch" aria-label="统计区间">
      <button class="${state.period === 'm' ? 'active' : ''}" data-action="period" data-value="m">本月</button>
      <button class="${state.period === 'w' ? 'active' : ''}" data-action="period" data-value="w">近7天</button>
    </div>`;
  }

  function aDrivePeriod() {
    return `<div class="range-line">
      <button class="${state.period === 'm' ? 'active' : ''}" data-action="period" data-value="m">近30天</button>
      <button class="${state.period === 'w' ? 'active' : ''}" data-action="period" data-value="w">近7天</button>
      <span class="spacer"></span>
      <button data-action="sheet" data-value="period">${icon('calendar')} ${state.period === 'm' ? '9/27—10/26' : '10/20—10/26'}</button>
    </div>`;
  }

  function aDataNote() {
    return `<div class="data-note"><button data-action="sheet" data-value="data">${icon('info')} 数据说明 · 截至 10/26 18:40</button></div>`;
  }

  function periodWords() {
    return state.period === 'm' ? '本月' : '近7天';
  }

  function periodDates() {
    return state.period === 'm' ? '10月1日—26日 18:40' : '10月20日—26日 18:40';
  }

  /* ---------- A: cockpit pages ---------- */
  function aOverview() {
    const p = overviewData();
    const empty = state.sample === 'empty';
    const missing = state.sample === 'missing';
    const metric = state.metric;
    const values =
      metric === 'net'
        ? missing
          ? p.netSeries.map(() => null)
          : p.netSeries
        : metric === 'charge'
          ? chargingData().energy.slice(state.period === 'w' ? -7 : -26)
          : metric === 'cost'
            ? chargingData().cost.slice(state.period === 'w' ? -7 : -26)
            : p.current;
    const point = pointIndex('overview', values.length);
    const unit = metric === 'distance' || metric === 'charge' ? (metric === 'distance' ? 'km' : 'kWh') : metric === 'cost' ? 'CNY' : 'Wh/km';
    const title =
      metric === 'distance'
        ? '每日里程'
        : metric === 'net'
          ? '每日净电耗 · 估算'
          : metric === 'charge'
            ? '每日补能'
            : '每日已知费用';
    const subtitle =
      metric === 'cost'
        ? '仅含费用已知记录 · 缺失不补零'
        : `${periodDates()} · 点按图形读值`;
    const valuesForChart = empty ? values.map(() => null) : values;
    const selected = valuesForChart[point];
    const chart =
      valuesForChart.every((v) => v == null)
        ? `<div class="chart-empty"><strong>${empty ? '这个区间还没有记录' : '暂时没有可用数据'}</strong><span>${empty ? '有行程或补能记录后，这里会显示趋势。' : '缺失值不补零，已知结果仍可在下方查看。'}</span></div>`
        : chartSvg({
            values: valuesForChart,
            labels: p.labels,
            key: 'overview',
            type: metric === 'net' ? 'line' : 'bars',
            height: 137,
            unit,
            point: point,
            min: metric === 'net' ? 130 : 0,
            max: metric === 'net' ? 180 : 120,
            aria: `${title}，${periodDates()}`,
          });

    return `${aAppbar()}<div class="content">
      <section class="hero">
        <div class="hero-top">
          <span class="status-line"><i class="status-dot"></i>最近状态 · ${DATA.status.state}</span>
          <span class="freshness">${DATA.status.updated}</span>
        </div>
        <div class="hero-main">
          <div class="hero-copy">
            <p class="hero-label">额定续航 · 非实时车况</p>
            <div class="hero-number">${fmt(DATA.status.range, 1)}<span>km</span></div>
            <p class="hero-sub">电量 ${DATA.status.soc}% · 今日 ${DATA.status.todayTrips} 次出行</p>
            <span class="hero-power">${icon('bolt')}正在充电 ${fmt(DATA.status.power, 1)} kW</span>
          </div>
          <div class="hero-ring">${ring(DATA.status.soc)}</div>
        </div>
        <div class="hero-bottom">
          <div><strong>${fmt(DATA.status.todayDistance, 1)}</strong><span>今日里程 km</span></div>
          <div><strong>${DATA.status.todayTrips}</strong><span>今日行程</span></div>
          <div><strong>${fmt(DATA.status.todayEnergy, 2)}</strong><span>今日估算消耗 kWh</span></div>
        </div>
        <div class="hero-car">${carSvg()}</div>
      </section>

      <div class="month-head">
        <div>
          <div class="section-kicker">${state.period === 'w' ? '近7天' : '这个月'} · 2026.10</div>
          <div class="month-number">${empty ? '—' : fmt(p.total, 1)}<span>km</span></div>
          <div class="month-meta">${empty ? '本期暂无记录' : `<span class="delta">${icon('arrow-up')} ${fmt((p.total / p.prevTotal - 1) * 100, 1)}%</span> ${state.period === 'w' ? '较前7天' : '较上月同期'} · ${p.trips} 次出行`}</div>
        </div>
        ${aPeriodSwitch()}
      </div>
      <div class="metric-strip">
        <div><small>净电耗 · 估算</small><strong>${empty || missing ? '—' : fmt(p.net, 0)}<em>Wh/km</em></strong></div>
        <div><small>充入电池</small><strong>${empty ? '—' : fmt(p.charge, 1)}<em>kWh</em></strong></div>
        <div><small>已知费用</small><strong>${empty ? '—' : money(p.cost, 1)}</strong></div>
      </div>

      <section class="figure">
        <div class="figure-head">
          <div><div class="figure-title">${title}</div><div class="figure-sub">${subtitle}</div></div>
          <div class="metric-chips">${[
            ['distance', '里程'],
            ['net', '净电耗'],
            ['charge', '补能'],
            ['cost', '费用'],
          ]
            .map(([value, label]) => `<button class="${metric === value ? 'active' : ''}" data-action="metric" data-value="${value}">${label}</button>`)
            .join('')}</div>
        </div>
        ${chart}
        <div class="chart-readout" aria-live="polite">
          <span>${p.labels[point] ?? ''} <strong>${selected == null ? '—' : `${fmt(selected, unit === 'CNY' ? 2 : 1)} ${unit}`}</strong>${metric === 'net' && !missing ? ' · 估算' : ''}</span>
          <div class="step-buttons"><button data-action="step" data-value="overview:-1:${valuesForChart.length}" aria-label="前一个读数" ${point === 0 ? 'disabled' : ''}>‹</button><button data-action="step" data-value="overview:1:${valuesForChart.length}" aria-label="后一个读数" ${point === valuesForChart.length - 1 ? 'disabled' : ''}>›</button></div>
        </div>
      </section>

      ${empty ? '' : aInsight(p, missing)}

      <div class="section-head"><h2>最近</h2><button data-action="sheet" data-value="records">全部记录 ↗</button></div>
      ${aRecent(empty)}

      <div class="section-head"><h2>继续读懂</h2></div>
      ${aTopics()}
      ${aDataNote()}
    </div>`;
  }

  function aInsight(p, missing) {
    if (missing) {
      return `<aside class="insight"><div><small>一条值得看的</small><p>净电耗样本不足，本期暂不做区间比较。驾驶里程与补能记录仍可分别查看。</p></div><button class="insight-arrow" data-action="sheet" data-value="comparison" aria-label="查看依据">${icon('arrow-right')}</button></aside>`;
    }
    const diff = p.net - p.prevNet;
    const direction = diff < 0 ? '低' : diff > 0 ? '高' : '持平';
    const text = diff === 0 ? `净电耗与上月同期持平，为 ${fmt(p.net, 0)} Wh/km。` : `净电耗比${state.period === 'w' ? '前7天' : '上月同期'}${direction} ${fmt(Math.abs(diff), 0)} Wh/km，本期 ${fmt(p.net, 0)}。`;
    return `<aside class="insight"><div><small>一条值得看的</small><p>${text}<br>同车、同归期时区；不把差异直接解释为驾驶技术。</p></div><button class="insight-arrow" data-action="sheet" data-value="comparison" aria-label="查看依据">${icon('arrow-right')}</button></aside>`;
  }

  function aRecent(empty) {
    if (empty) {
      return `<div class="recent-empty"><strong>还没有可回顾的记录</strong><span>同步到行程或补能后，这里会出现最近发生的事。</span></div>`;
    }
    const d = latestDrive();
    const c = latestCharge();
    return `<div class="recent-scroll">
      <button class="recent-card" data-action="openDrive" data-value="${d.id}">
        <div class="mini-map">${mapSvg('a')}<span class="mini-map-tag">最近行程</span></div>
        <div class="recent-body">
          <small>${d.date} ${d.time} · ${d.duration} 分钟</small>
          <div class="recent-title">${d.start} → ${d.end}</div>
          <div class="recent-numbers"><strong>${fmt(d.distance, 1)}</strong><span>km · ${fmt(d.consumption, 0)} Wh/km</span></div>
        </div>
      </button>
      <button class="recent-card" data-action="openCharge" data-value="${c.id}">
        <div class="mini-map charge-mini">${pinMapSvg('a')}<span class="mini-map-tag">最近充电</span></div>
        <div class="recent-body">
          <small>${c.date} ${c.start} · ${c.place}</small>
          <div class="recent-title">补入 ${fmt(c.energy, 1)} kWh</div>
          <div class="soc-mini">
            <div class="soc-track"><i class="soc-fill" style="left:${c.startSoc}%;width:${c.endSoc - c.startSoc}%"></i></div>
            <div class="soc-labels"><span>${c.startSoc}%</span><span>${c.endSoc}% · ${money(c.cost)}</span></div>
          </div>
        </div>
      </button>
    </div>`;
  }

  function aTopics() {
    return `<div class="topic-list">
      <button class="topic-row" data-action="topic" data-value="rhythm"><span class="topic-icon">${icon('calendar')}</span><span><strong>用车节奏</strong><small>${overviewData().active} 个活跃日 · 单程中位 18.6 km</small></span>${icon('chevron')}</button>
      <button class="topic-row" data-action="topic" data-value="energy"><span class="topic-icon">${icon('temp')}</span><span><strong>什么影响电耗</strong><small>按温度与距离看记录，样本说话</small></span>${icon('chevron')}</button>
      <button class="topic-row" data-action="topic" data-value="long"><span class="topic-icon">${icon('battery')}</span><span><strong>续航与停放</strong><small>6 个月额定续航观测 · 不是健康评分</small></span>${icon('chevron')}</button>
    </div>`;
  }

  function aDrives() {
    const p = drivesData();
    const empty = state.sample === 'empty';
    const point = pointIndex('drives', p.current.length);
    const selected = p.current[point];
    const groups = [];
    for (const drive of DRIVES) {
      let group = groups.find((g) => g.date === drive.date);
      if (!group) {
        group = { date: drive.date, drives: [] };
        groups.push(group);
      }
      group.drives.push(drive);
    }
    return `${aAppbar()}<div class="content">
      <div class="page-head"><div><h1>行程</h1><p>${state.period === 'm' ? '最近 30 天 · 9月27日—10月26日' : '最近 7 天 · 10月20日—10月26日'}</p></div><button class="head-action" data-action="sheet" data-value="period">筛选</button></div>
      ${aDrivePeriod()}
      <section class="route-summary">
        <div class="label">${state.period === 'm' ? '近 30 天 · 期间里程' : '近 7 天 · 期间里程'}</div>
        <div class="big">${empty ? '—' : fmt(p.total, 1)}<span>km</span></div>
        <div class="meta"><span><b>${empty ? '—' : p.trips}</b> 次行程</span><span>估算 <b>${empty ? '—' : fmt(p.energy, 1)}</b> kWh</span><span>净电耗 <b>${empty ? '—' : fmt(p.net, 0)}</b> Wh/km</span></div>
        <div class="route-line-art">${routeLineArt()}</div>
      </section>
      ${empty ? `<div class="chart-empty"><strong>这个区间还没有行程</strong><span>空状态保留在这里，方便直接扩大日期范围。</span></div>` : `<section class="rhythm">
        <div class="head"><strong>出行节奏</strong><span>${state.period === 'm' ? '每日里程 · 9/27—10/26' : '每日里程 · 10/20—10/26'}</span></div>
        ${chartSvg({ values: p.current, labels: p.labels, key: 'drives', type: 'bars', height: 77, showY: false, showX: true, showGrid: false, point })}
        <div class="chart-readout"><span>${p.labels[point]} <strong>${fmt(selected, 1)} km</strong> · 点按柱子读值</span><div class="step-buttons"><button data-action="step" data-value="drives:-1:${p.current.length}" aria-label="前一天">‹</button><button data-action="step" data-value="drives:1:${p.current.length}" aria-label="后一天">›</button></div></div>
      </section>`}
      ${empty ? '' : `<div class="timeline">
        ${groups
          .map((group) => {
            const featured = group.drives.find((d) => d.featured);
            const rows = group.drives.filter((d) => !d.featured);
            return `<div class="day-label"><h2>${group.date === '10/26' ? '10月26日 · 今天' : `10月${Number(group.date.split('/')[1])}日`}</h2><span>${group.drives.length} 次行程</span></div>
              ${featured ? `<button class="featured-drive" data-action="openDrive" data-value="${featured.id}"><div class="mini-map">${mapSvg('a')}</div><div class="drive-row"><div class="drive-time">${featured.time}</div><div class="drive-main"><div class="drive-route">${featured.start}<span class="arrow">→</span>${featured.end}</div><div class="drive-meta"><span><b>${fmt(featured.distance, 1)}</b> km</span><span><b>${featured.duration}</b> 分钟</span><span>净电耗 <b>${fmt(featured.consumption, 0)}</b> Wh/km</span></div></div><div class="drive-distance"><strong>${fmt(featured.distance, 1)}</strong><span>km</span></div></div></button>` : ''}
              ${rows
                .map(
                  (d) => `<button class="drive-row" data-action="openDrive" data-value="${d.id}"><div class="drive-time">${d.time}</div><div class="drive-main"><div class="drive-route">${d.start}<span class="arrow">→</span>${d.end}</div><div class="drive-meta"><span><b>${fmt(d.distance, 1)}</b> km</span><span><b>${d.duration}</b> 分钟</span><span>净电耗 <b>${fmt(d.consumption, 0)}</b> Wh/km</span></div></div><div class="drive-distance"><strong>${fmt(d.distance, 1)}</strong><span>km</span></div></button>`,
                )
                .join('')}`;
          })
          .join('')}
        <div class="section-head"><h2>更早</h2><button data-action="sheet" data-value="period">按日期筛选 ↗</button></div>
        <button class="drive-row" data-action="openDrive" data-value="106"><div class="drive-time">10/22<br>10:05</div><div class="drive-main"><div class="drive-route">家<span class="arrow">→</span>云栖中心</div><div class="drive-meta"><span><b>27.6</b> km</span><span><b>39</b> 分钟</span><span>净电耗 <b>149</b> Wh/km</span></div></div><div class="drive-distance"><strong>27.6</strong><span>km</span></div></button>
      </div>`}
      ${aDataNote()}
    </div>`;
  }

  function aCharging() {
    const p = chargingData();
    const empty = state.sample === 'empty';
    const key = 'charge';
    const values = state.chargeMetric === 'energy' ? p.energy : state.chargeMetric === 'cost' ? p.cost : p.sessions;
    const chartPoint = pointIndex(key, values.length);
    const chartValue = values[chartPoint];
    const unit = state.chargeMetric === 'energy' ? 'kWh' : state.chargeMetric === 'cost' ? 'CNY' : '次';
    const title = state.chargeMetric === 'energy' ? '每日补能' : state.chargeMetric === 'cost' ? '每日已知费用' : '每日充电次数';
    const knownShare = p.totalCost == null ? null : p.totalCost / p.knownEnergy;
    const dcShare = p.dc / (p.ac + p.dc);
    return `${aAppbar()}<div class="content">
      <div class="page-head"><div><h1>充电</h1><p>按结束时间归期 · ${state.period === 'm' ? '近 30 天' : '近 7 天'}</p></div><button class="head-action" data-action="sheet" data-value="records">全部记录 ↗</button></div>
      ${aDrivePeriod()}
      <section class="charge-hero">
        <div class="label">已知充电费用</div>
        <div class="big">${empty ? '—' : money(p.totalCost, 1)}<span>${empty ? '' : 'CNY'}</span></div>
        <div class="sub">${empty ? '本期暂无补能记录' : `${p.knownSessions} / ${p.sessionCount} 次有费用记录 · 仅含已知费用`}</div>
        <div class="coverage"><div class="coverage-bar"><i class="coverage-fill" style="width:${empty ? 0 : (p.knownSessions / p.sessionCount) * 100}%"></i></div><div class="coverage-label"><span>费用覆盖</span><span>${empty ? '0 / 0' : `${p.knownSessions} / ${p.sessionCount} 次`}</span></div></div>
      </section>
      <div class="charge-strip">
        <div><strong>${empty ? '—' : fmt(p.totalEnergy, 1)}</strong><small>充入电池 kWh</small></div>
        <div><strong>${empty ? '—' : p.sessionCount}</strong><small>次充电</small></div>
        <div><strong>${empty ? '—' : Math.floor(p.duration / 60)}<em style="font-size:8px;font-style:normal;color:var(--sub)">h</em>${String(p.duration % 60).padStart(2, '0')}</strong><small>记录时长</small></div>
      </div>
      <section class="figure">
        <div class="figure-head"><div><div class="figure-title">${title}</div><div class="figure-sub">${state.period === 'm' ? '近30天' : '近7天'} · 点按图形读值</div></div><div class="metric-chips">${[['energy', '电量'], ['cost', '费用'], ['sessions', '次数']].map(([value, label]) => `<button class="${state.chargeMetric === value ? 'active' : ''}" data-action="chargeMetric" data-value="${value}">${label}</button>`).join('')}</div></div>
        ${values.every((v) => v == null) ? `<div class="chart-empty"><strong>暂无可用数据</strong><span>费用缺失不补零，其他指标仍可查看。</span></div>` : chartSvg({ values, labels: p.labels, key, type: 'bars', height: 126, unit, point: chartPoint, min: 0, max: state.chargeMetric === 'cost' ? Math.max(80, ...values.filter((v) => v != null)) : state.chargeMetric === 'sessions' ? 4 : 60, aria: title })}
        <div class="chart-readout"><span>${p.labels[chartPoint]} <strong>${chartValue == null ? '—' : state.chargeMetric === 'cost' ? money(chartValue) : `${fmt(chartValue, state.chargeMetric === 'sessions' ? 0 : 1)} ${unit}`}</strong>${state.chargeMetric === 'cost' ? ' · 缺失不表示免费' : ''}</span><div class="step-buttons"><button data-action="step" data-value="charge:-1:${values.length}" aria-label="前一个读数">‹</button><button data-action="step" data-value="charge:1:${values.length}" aria-label="后一个读数">›</button></div></div>
      </section>
      <section class="composition">
        <div class="composition-head"><strong>补能方式</strong><span>AC / DC / 未知</span></div>
        ${acdcBar(p)}
        <div class="acdc-legend"><span><i style="background:var(--accent)"></i>AC <b>${fmt(p.ac, 1)}</b></span><span><i style="background:var(--amber)"></i>DC <b>${fmt(p.dc, 1)}</b></span><span><i style="background:var(--line-strong)"></i>未知 <b>${fmt(p.unknown, 1)}</b></span><span><b>${fmt(dcShare * 100, 0)}%</b> DC · 仅已知分类</span></div>
        <div class="section-note">DC 占比分母为 AC + DC；未知分类不归入 AC。</div>
      </section>
      <div class="section-head"><h2>常去地点</h2><button data-action="sheet" data-value="records">全部记录 ↗</button></div>
      <div class="location-list">
        ${p.locations.map((l) => `<button class="location-row" data-action="sheet" data-value="records"><span><strong>${l.name}</strong><small>${l.count} 次 · ${fmt(l.energy, 1)} kWh · ${l.mode} · 费用 ${l.known}/${l.count} 次</small></span><span class="amount"><strong>${l.cost == null ? '未记录' : money(l.cost, 2)}</strong><span>${l.cost == null ? '' : '已知费用'}</span></span></button>`).join('')}
      </div>
      ${empty ? '' : `<button class="featured-charge" data-action="openCharge" data-value="${SESSIONS[0].id}"><span class="soc"><small>最近一次 · ${SESSIONS[0].date} ${SESSIONS[0].start} · ${SESSIONS[0].place}</small><span class="range">${SESSIONS[0].startSoc}% → ${SESSIONS[0].endSoc}%<span>${SESSIONS[0].duration} 分钟</span></span><div class="soc-track"><i class="soc-fill" style="left:${SESSIONS[0].startSoc}%;width:${SESSIONS[0].endSoc - SESSIONS[0].startSoc}%"></i></div><div class="soc-labels"><span>${fmt(SESSIONS[0].energy, 1)} kWh · DC</span><span>${SESSIONS[0].peak} kW 峰值</span></div></span><span class="cost"><strong>${money(SESSIONS[0].cost)}</strong><span>已记录费用</span></span></button>`}
      ${aDataNote()}
    </div>`;
  }

  function aStats() {
    const p = statsData();
    const empty = state.sample === 'empty';
    const point = pointIndex('stats', p.current.length);
    const current = p.current[point];
    const previous = p.previous[point];
    const diff = p.total - p.prevTotal;
    const netDiff = p.net - p.prevNet;
    return `${aAppbar()}<div class="content">
      <div class="page-head"><div><h1>统计</h1><p>${periodWords()} · 2026年10月</p></div>${aPeriodSwitch()}</div>
      <section class="stats-hero">
        <div class="section-kicker">${periodWords()} · 你开了</div>
        <h1><em>${empty ? '—' : fmt(p.total, 1)}</em> 公里。</h1>
        <p class="lede">${empty ? '本期暂无记录；先保留空态，不用零值画趋势。' : `${state.period === 'w' ? '比前7天' : '比上月同期'}多 <b>${fmt(diff, 1)} km</b> · 净电耗低 <b>${fmt(Math.abs(netDiff), 0)} Wh/km</b>。${state.period === 'w' ? '参照为前 7 天。' : '参照为 9 月 1 日—26 日 18:40。'}`}</p>
        <div class="stat-pair"><div><strong>${empty ? '—' : fmt(p.net, 0)} <span style="font-size:9px;font-weight:450;color:var(--sub)">Wh/km</span></strong><small>净电耗 · 估算</small></div><div><strong>${empty ? '—' : money(p.cost, 1)}</strong><small>已知充电支出</small></div><div><strong>${empty ? '—' : p.active} <span style="font-size:9px;font-weight:450;color:var(--sub)">天</span></strong><small>活跃日</small></div></div>
      </section>
      <section class="figure comparison-figure">
        <div class="figure-head"><div><div class="figure-title">里程走势</div><div class="figure-sub">本期 vs 参照 · 同车、同归期时区</div></div><span class="figure-unit">km</span></div>
        ${empty ? `<div class="chart-empty"><strong>这个区间还没有记录</strong><span>没有数据时不画全零趋势。</span></div>` : chartSvg({ values: p.current, previous: p.previous, labels: p.labels, key: 'stats', type: 'bars', height: 146, unit: 'km', point, max: 120, aria: '每日里程，本期与参照' })}
        <div class="legend"><span><i></i>本期</span><span><i class="ref"></i>参照 · 同进度</span></div>
        <div class="chart-readout"><span>${p.labels[point]} <strong>${fmt(current, 1)} km</strong>${previous == null ? '' : ` / 参照 ${fmt(previous, 1)} km`}</span><div class="step-buttons"><button data-action="step" data-value="stats:-1:${p.current.length}" aria-label="前一个读数">‹</button><button data-action="step" data-value="stats:1:${p.current.length}" aria-label="后一个读数">›</button></div></div>
      </section>
      <div class="section-head"><h2>继续看</h2><span class="figure-unit">四个问题</span></div>
      <div class="chapter-grid">
        <button class="chapter-card wide mint" data-action="topic" data-value="rhythm"><div class="chapter-top"><small>节奏 · RHYTHM</small>${icon('calendar')}</div><div class="chapter-value">${p.active} <span>个活跃日</span></div><div class="chapter-note">单程中位 ${p.medianTrip} km · 驾驶记录 ${Math.floor(p.durationMin / 60)}h${String(p.durationMin % 60).padStart(2, '0')}</div><div class="chapter-mini">${sparkSvg(weekdayTotals(p.current))}</div></button>
        <button class="chapter-card" data-action="topic" data-value="energy"><div class="chapter-top"><small>能耗 · ENERGY</small>${icon('temp')}</div><div class="chapter-value">${fmt(p.net, 0)} <span>Wh/km</span></div><div class="chapter-note">较参照低 ${fmt(Math.abs(netDiff), 0)}</div><div class="chapter-mini">${sparkSvg(NET_DAYS.slice(state.period === 'w' ? -7 : 0))}</div></button>
        <button class="chapter-card" data-action="topic" data-value="charging"><div class="chapter-top"><small>补能 · CHARGE</small>${icon('bolt')}</div><div class="chapter-value">${money(p.cost, 1)}</div><div class="chapter-note">${chargingData().knownSessions} / ${chargingData().sessionCount} 次有费用 · ${fmt(chargingData().totalEnergy, 1)} kWh</div><div class="chapter-mini">${acdcBar(chargingData())}</div></button>
        <button class="chapter-card wide dark" data-action="topic" data-value="long"><div class="chapter-top"><small>长期 · LONG VIEW</small>${icon('battery')}</div><div class="chapter-value">316 <span>km · 额定续航 P50</span></div><div class="chapter-note">近 6 个月记录估计 · 不是电池健康评分</div><div class="chapter-mini">${sparkSvg(RANGE_MONTHS.map((m) => m.value))}</div></button>
      </div>
      ${aDataNote()}
    </div>`;
  }

  function aTopic() {
    const p = statsData();
    const topics = {
      rhythm: { title: '用车节奏', kicker: 'RHYTHM / 这段时怎么用', lede: '先看哪些天真的开了车，再看每次出行有多长。' },
      energy: { title: '什么影响电耗', kicker: 'ENERGY / 条件与样本', lede: '按温度和单程距离分组，只描述记录，不推断因果。' },
      charging: { title: '补能与账目', kicker: 'CHARGE / 钱和能量', lede: '已知费用、覆盖和分类分开读；未知不算 AC。' },
      long: { title: '续航与停放', kicker: 'LONG VIEW / 慢慢看', lede: '看记录估计的变化，不用单次续航给电池打分。' },
    };
    const t = topics[state.topic] || topics.rhythm;
    return `<div class="content topic-content">
      <button class="back-row" data-action="page" data-value="stats">${icon('arrow-left')} 返回统计</button>
      <div class="page-head" style="margin-top:14px"><div><div class="section-kicker">${t.kicker}</div><h1>${t.title}</h1><p>${t.lede}</p></div></div>
      ${state.topic === 'rhythm' ? aTopicRhythm(p) : state.topic === 'energy' ? aTopicEnergy(p) : state.topic === 'charging' ? aTopicCharging() : aTopicLong()}
      ${aDataNote()}
    </div>`;
  }

  function aTopicRhythm(p) {
    return `<section class="figure topic-figure">
      <div class="figure-head"><div><div class="figure-title">每日里程</div><div class="figure-sub">10月1日—26日 · 点按日期读值</div></div><span class="figure-unit">km</span></div>
      ${calendarGrid(MONTH_DAYS, 'a')}
      <div class="calendar-legend"><span><i class="heat-0"></i>0</span><span><i class="heat-1"></i>&lt;30</span><span><i class="heat-2"></i>30–60</span><span><i class="heat-3"></i>60–90</span><span><i class="heat-4"></i>≥90</span><span class="today-mark">10/26</span></div>
    </section>
    <div class="stat-pair topic-pair"><div><strong>${p.active} <span>天</span></strong><small>活跃日</small></div><div><strong>${Math.floor(p.durationMin / 60)}h${String(p.durationMin % 60).padStart(2, '0')}</strong><small>驾驶记录时长</small></div><div><strong>${p.medianTrip} <span>km</span></strong><small>单程中位数</small></div></div>
    <section class="figure"><div class="figure-head"><div><div class="figure-title">一周的节奏</div><div class="figure-sub">按开始日分组 · 仅供观察</div></div><span class="figure-unit">km</span></div>${chartSvg({ values: weekdayTotals(p.current), labels: WEEKDAY_LABELS, key: 'weekday', type: 'bars', height: 108, showY: false, unit: 'km', aria: '按星期的里程分布' })}</section>
    <div class="section-head"><h2>短途、中途与长途</h2></div>
    ${DIST_BINS.map((bin) => `<div class="distance-bin"><div><strong>${bin.label}</strong><small>${bin.drives} 趟 · ${bin.distance} km</small></div><div class="bin-bar"><i style="width:${(bin.distance / 560) * 100}%"></i></div><span>${bin.value} Wh/km</span></div>`).join('')}
    <div class="section-note">分组电耗为同一批有效行程的合计能量 ÷ 合计里程；样本不足时只展示原值。</div>`;
  }

  function aTopicEnergy(p) {
    return `<div class="topic-big">${fmt(p.net, 0)} <span>Wh/km</span></div><div class="section-note" style="margin-top:2px">区间净电耗 · 估算 · 较参照低 ${fmt(Math.abs(p.net - p.prevNet), 0)}</div>
    <section class="figure"><div class="figure-head"><div><div class="figure-title">按室外均温分组</div><div class="figure-sub">柱旁数字为有效行程数 · 不推断因果</div></div><span class="figure-unit">Wh/km</span></div>${chartSvg({ values: TEMP_BINS.map((b) => b.value), labels: TEMP_BINS.map((b) => b.label), key: 'temp', type: 'bars', height: 122, unit: 'Wh/km', min: 120, max: 190, aria: '按温度分组的电耗' })}</section>
    <div class="temp-samples">${TEMP_BINS.map((b) => `<span>${b.label} <b>${b.samples}</b> 趟</span>`).join('')}</div>
    <div class="section-head"><h2>按单程距离分组</h2></div>
    ${DIST_BINS.map((bin) => `<div class="distance-bin"><div><strong>${bin.label}</strong><small>${bin.drives} 趟 · ${bin.distance} km</small></div><div class="bin-bar"><i style="width:${(bin.distance / 560) * 100}%"></i></div><span>${bin.value} Wh/km</span></div>`).join('')}
    <div class="section-note">净电耗由续航差与车辆效率估算。温度与距离只描述共时分组，不证明原因。</div>`;
  }

  function aTopicCharging() {
    const p = chargingData();
    return `<div class="topic-big">${money(p.totalCost, 1)}</div><div class="section-note" style="margin-top:2px">已知充电费用 · ${p.knownSessions}/${p.sessionCount} 次有记录</div>
    <section class="figure"><div class="figure-head"><div><div class="figure-title">费用覆盖</div><div class="figure-sub">已知费用不是全部用车成本</div></div><span class="figure-unit">${p.knownSessions}/${p.sessionCount}</span></div><div class="coverage-bar big-coverage"><i class="coverage-fill" style="width:${(p.knownSessions / p.sessionCount) * 100}%"></i></div><div class="coverage-label"><span>有费用记录</span><span>${fmt(p.knownEnergy, 1)} kWh 对应能量</span></div></section>
    <section class="figure"><div class="figure-head"><div><div class="figure-title">补能方式</div><div class="figure-sub">仅已知分类 · 未知不归入 AC</div></div><span class="figure-unit">kWh</span></div>${acdcBar(p)}<div class="acdc-legend"><span><i style="background:var(--accent)"></i>AC <b>${fmt(p.ac, 1)}</b></span><span><i style="background:var(--amber)"></i>DC <b>${fmt(p.dc, 1)}</b></span><span><i style="background:var(--line-strong)"></i>未知 <b>${fmt(p.unknown, 1)}</b></span></div></section>
    <div class="section-head"><h2>地点账目</h2></div>
    <div class="location-list">${p.locations.map((l) => `<div class="location-row"><span><strong>${l.name}</strong><small>${l.count} 次 · ${fmt(l.energy, 1)} kWh · ${l.mode} · 覆盖 ${l.known}/${l.count}</small></span><span class="amount"><strong>${l.cost == null ? '未记录' : money(l.cost, 2)}</strong><span>${l.cost == null ? '' : '已知费用'}</span></span></div>`).join('')}</div>
    <div class="section-note">地点按已知分类与费用记录拆分；排序不评价“划算”或“快慢”。</div>`;
  }

  function aTopicLong() {
    return `<div class="topic-big">316 <span>km</span></div><div class="section-note" style="margin-top:2px">近 6 个月额定续航 P50 · 记录估计</div>
    <section class="figure"><div class="figure-head"><div><div class="figure-title">额定续航观测</div><div class="figure-sub">按月 · 样本数见下方</div></div><span class="figure-unit">km</span></div>${chartSvg({ values: RANGE_MONTHS.map((m) => m.value), labels: RANGE_MONTHS.map((m) => m.label), key: 'range', type: 'line', height: 132, unit: 'km', min: 300, max: 330, point: 5, aria: '额定续航月度观测' })}</section>
    <div class="range-samples">${RANGE_MONTHS.map((m) => `<span><b>${m.label}</b> ${m.value} km <small>${m.samples} 样本</small></span>`).join('')}</div>
    <div class="section-note">这是从记录估算的满电等效额定续航，不是 BMS SOH、出厂容量或保修判断。缺月不补点，样本少不输出衰减率。</div>
    <div class="section-head"><h2>停放变化</h2><span class="figure-unit">待建能力</span></div>
    <div class="parking-note">当前版本不提供跨记录停放窗口；这里只保留入口，不用充入减行驶推测停车损耗。</div>`;
  }

  function aDriveDetail() {
    const d = latestDrive();
    const metrics = {
      speed: { values: DRIVE_SPEED, labels: DRIVE_SPEED_LABELS, unit: 'km/h', title: '速度', min: 0, max: 110 },
      battery: { values: DRIVE_BATTERY, labels: DRIVE_SPEED_LABELS, unit: '%', title: '电量', min: 60, max: 80 },
      elevation: { values: DRIVE_ELEVATION, labels: DRIVE_SPEED_LABELS, unit: 'm', title: '海拔', min: 20, max: 80 },
    };
    const m = metrics[state.detailMetric] || metrics.speed;
    const point = Math.min(state.points['drive-detail'] ?? 10, m.values.length - 1);
    const value = m.values[point];
    return `<div class="detail-map">${mapSvg('a')}<button class="map-back" data-action="page" data-value="drives" aria-label="返回行程">${icon('arrow-left')}</button><div class="map-title"><small>最近行程 · ${d.date} ${d.time}</small><h1>${d.start} → ${d.end}</h1><p>${d.distance} km · ${d.duration} 分钟 · 路线示意</p></div></div>
    <div class="detail-sheet">
      <div class="detail-result"><div><small>距离</small><strong>${fmt(d.distance, 1)}<span>km</span></strong></div><div><small>时长</small><strong>${d.duration}<span>分钟</span></strong></div><div><small>净电耗 · 估算</small><strong>${fmt(d.consumption, 0)}<span>Wh/km</span></strong></div></div>
      <div class="detail-soc"><div class="soc-track"><i class="soc-fill" style="left:${Math.min(d.startSoc, d.endSoc)}%;width:${Math.abs(d.startSoc - d.endSoc)}%"></i></div><div class="soc-labels"><span>出发 ${d.startSoc}%</span><span>到达 ${d.endSoc}%</span></div></div>
      <div class="detail-ref">${icon('spark')} <span>本次净电耗 <b>${d.consumption} Wh/km</b>，个人 30 日整体为 <b>154 Wh/km</b>；不是同路比较。</span></div>
      <section class="figure detail-chart">
        <div class="figure-head"><div><div class="figure-title">${m.title}过程</div><div class="figure-sub">真实时间采样 · 点按图形读值</div></div><div class="metric-chips">${[['speed', '速度'], ['battery', '电量'], ['elevation', '海拔']].map(([value, label]) => `<button class="${state.detailMetric === value ? 'active' : ''}" data-action="detailMetric" data-value="${value}">${label}</button>`).join('')}</div></div>
        ${chartSvg({ values: m.values, labels: m.labels, key: 'drive-detail', type: 'line', height: 132, unit: m.unit, min: m.min, max: m.max, point, aria: `${m.title}过程` })}
        <div class="chart-readout"><span>${m.labels[point] ?? ''} <strong>${fmt(value, m.unit === '%' ? 0 : 0)} ${m.unit}</strong></span><div class="step-buttons"><button data-action="step" data-value="drive-detail:-1:${m.values.length}" aria-label="前一个采样">‹</button><button data-action="step" data-value="drive-detail:1:${m.values.length}" aria-label="后一个采样">›</button></div></div>
      </section>
      <div class="environment"><div><small>平均速度</small><strong>43 km/h</strong></div><div><small>最高速度</small><strong>91 km/h</strong></div><div><small>车外均温</small><strong>15.0 °C</strong></div><div><small>车内均温</small><strong>21.0 °C</strong></div></div>
      <div class="more-row"><span>更多行程指标</span>${icon('chevron-down')}</div>
      <div class="note">速度与海拔为服务端采样，不是原始极值；缺失值断线，不补点。地图为合成路线示意，正式底图仍需供应商/坐标验收。</div>
    </div>`;
  }

  function aChargeDetail() {
    const c = SESSIONS[0];
    const metrics = {
      power: { values: POWER_CURVE, labels: POWER_LABELS, unit: 'kW', title: '功率', min: 0, max: 180 },
      soc: { values: SOC_CURVE, labels: SOC_LABELS, unit: '%', title: '电量', min: 0, max: 100 },
    };
    const m = metrics[state.chargeDetailMetric] || metrics.power;
    const point = Math.min(state.points['charge-detail'] ?? 4, m.values.length - 1);
    const value = m.values[point];
    return `<div class="charge-map">${mapSvg('a')}<button class="map-back" data-action="page" data-value="charging" aria-label="返回充电">${icon('arrow-left')}</button><div class="map-title"><small>最近充电 · ${c.date} ${c.start}–${c.end}</small><h1>${c.place}</h1><p>${c.dc ? 'DC' : c.dc === false ? 'AC' : '分类未知'} · ${c.duration} 分钟 · 地点示意</p></div></div>
    <div class="charge-sheet">
      <section class="charge-soc"><div class="charge-soc-top"><small>电量区间</small><strong>${c.startSoc}% → ${c.endSoc}%</strong></div><div class="soc-track"><i class="soc-fill" style="left:${c.startSoc}%;width:${c.endSoc - c.startSoc}%"></i></div><div class="soc-labels"><span>起始 ${c.startSoc}%</span><span>结束 ${c.endSoc}%</span></div></section>
      <div class="charge-stats"><div><small>充入电池</small><strong>${fmt(c.energy, 1)}<span>kWh</span></strong></div><div><small>已记录费用</small><strong>${money(c.cost)}</strong></div><div><small>记录时长</small><strong>${c.duration}<span>分钟</span></strong></div></div>
      <section class="figure detail-chart"><div class="figure-head"><div><div class="figure-title">${m.title}曲线</div><div class="figure-sub">服务端采样 · 点按图形读值</div></div><div class="metric-chips">${[['power', '功率'], ['soc', '电量']].map(([value, label]) => `<button class="${state.chargeDetailMetric === value ? 'active' : ''}" data-action="chargeDetailMetric" data-value="${value}">${label}</button>`).join('')}</div></div>${chartSvg({ values: m.values, labels: m.labels, key: 'charge-detail', type: 'line', height: 136, unit: m.unit, min: m.min, max: m.max, point, aria: `${m.title}曲线` })}<div class="chart-readout"><span>${m.labels[point] ?? ''} 分钟 <strong>${fmt(value, 0)} ${m.unit}</strong></span><div class="step-buttons"><button data-action="step" data-value="charge-detail:-1:${m.values.length}" aria-label="前一个采样">‹</button><button data-action="step" data-value="charge-detail:1:${m.values.length}" aria-label="后一个采样">›</button></div></div></section>
      <div class="energy-pair"><div><small>充入电池</small><strong>${fmt(c.energy, 1)} kWh</strong><span>电池侧 · 本次</span></div><div><small>电网侧估算</small><strong>49.5 kWh</strong><span>两侧不相加 · 不推导损耗率</span></div></div>
      <div class="section-note">功率峰值 ${c.peak} kW；费用为已记录值，未知不补零。地点地图为合成示意，正式底图仍需验收。</div>
    </div>`;
  }

  function routeLineArt() {
    return `<svg viewBox="0 0 150 80" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"><path d="M4 70C28 68 20 43 44 40s36 9 47-10S122 8 147 7"/><circle cx="4" cy="70" r="3" fill="currentColor" stroke="none"/><circle cx="147" cy="7" r="3" fill="currentColor" stroke="none"/></svg>`;
  }

  function pinMapSvg(variant) {
    return `<svg class="map map-${variant}" viewBox="0 0 320 190" preserveAspectRatio="xMidYMid slice" aria-hidden="true"><rect class="map-bg" width="320" height="190"/><path class="map-river" d="M-10 150C55 132 64 110 110 112s60 24 102 10 65-42 118-35"/><g class="map-blocks"><path d="M12 20h58v30H12zM88 14h72v32H88zM178 12h56v38h-56zM252 22h56v36h-56zM18 68h46v44H18zM84 58h44v34H84zM144 56h56v40h-56zM220 72h38v34h-38zM272 70h38v42h-38zM16 128h72v44H16zM100 126h56v34h-56zM166 124h38v48h-38zM218 132h48v36h-48zM276 136h34v44h-34z"/></g><g class="map-streets"><path d="M0 54h320M0 116h320M0 176h320M80 0v190M150 0v190M222 0v190M280 0v190"/></g><circle cx="204" cy="84" r="10" class="map-end-halo"/><circle cx="204" cy="84" r="5" class="map-end"/></svg>`;
  }

  /* ---------- B: journal pages ---------- */
  function bMasthead() {
    return `<header class="masthead"><div class="brand">${icon('leaf')}行笺</div><div class="issue">${DATA.vehicle.name} · 2026.10.26</div></header>`;
  }

  function bPeriodRow(kind = 'month') {
    const a = kind === 'month' ? '本月' : '近30天';
    return `<div class="period-row"><button class="${state.period === 'm' ? 'active' : ''}" data-action="period" data-value="m">${a}</button><button class="${state.period === 'w' ? 'active' : ''}" data-action="period" data-value="w">近7天</button><span class="spacer"></span><span class="zone">Asia/Shanghai</span></div>`;
  }

  function bDataNote(text = '固定合成样例 · 正式总计与比率取服务端结果') {
    return `<p class="b-data-note">${icon('info')} ${text}</p>`;
  }

  function bOverview() {
    const p = overviewData();
    const empty = state.sample === 'empty';
    const point = pointIndex('b-overview', p.current.length);
    const current = p.current[point];
    const previous = p.previous[point];
    return `${bMasthead()}<div class="content">
      <p class="kicker">${periodWords()} · 十月 / 2026</p>
      ${bPeriodRow('month')}
      ${empty ? `<h1 class="headline">${state.period === 'w' ? '这七天' : '这个月'}，<br>还没有<br>出行的记录。</h1><p class="lede">先保留空态；有记录后再展示趋势、比较与最近发生的事。</p>` : `<h1 class="headline">${state.period === 'w' ? '这七天' : '这个月'}，<br>你开了 <span class="num">${fmt(p.total, 1)}</span><br>公里。</h1><p class="lede">${state.period === 'w' ? '比前7天' : '比上月同期'}多 <b>${fmt(p.total - p.prevTotal, 1)} km</b>，${p.trips} 次出行。净电耗 <b>${fmt(p.net, 0)} Wh/km</b>，充入 <b>${fmt(p.charge, 1)} kWh</b>。</p>`}
      <div class="status-line"><i class="dot"></i><span>此刻 <b>${DATA.status.soc}%</b> · 额定续航 <b>${DATA.status.range} km</b> · ${DATA.status.state}</span><span class="spacer"></span><span class="stamp">10/26 18:40</span></div>
      <figure class="figure">
        <div class="figure-head"><strong>每日里程</strong><span>km</span></div>
        ${empty ? `<div class="chart-empty"><strong>这个区间还没有记录</strong><span>不画全零趋势。</span></div>` : chartSvg({ values: p.current, previous: p.previous, labels: p.labels, key: 'b-overview', type: 'line', height: 119, min: 0, max: 120, unit: 'km', point, aria: '每日里程与上月同期' })}
        <div class="fig-caption"><span>${periodDates()} · 每日</span><span><span class="dash">— —</span> ${state.period === 'w' ? '前7天' : '上月同期'}</span></div>
        <div class="chart-readout b-readout"><span>${p.labels[point]} <strong>${fmt(current, 1)} km</strong>${previous == null ? '' : ` · 参照 ${fmt(previous, 1)}`}</span><span class="step-buttons"><button data-action="step" data-value="b-overview:-1:${p.current.length}" aria-label="前一个读数">‹</button><button data-action="step" data-value="b-overview:1:${p.current.length}" aria-label="后一个读数">›</button></span></div>
      </figure>
      <div class="section-head"><h2>最近</h2><span>10.26</span></div>
      <button class="entry" data-action="openDrive" data-value="101"><div class="entry-date"><b>26</b>10月</div><div class="entry-body"><div class="entry-title">从松岚小区<br>到云栖中心 <span class="arrow">↗</span></div><div class="entry-meta"><span><b>32.9</b> km</span><span><b>46</b> 分钟</span><span>净电耗 <b>145</b> Wh/km</span></div><div class="entry-map">${mapSvg('b')}</div></div></button>
      <button class="entry" data-action="openCharge" data-value="1"><div class="entry-date"><b>25</b>10月</div><div class="entry-body"><div class="entry-title">在湖畔超充<br>补入 46.8 kWh <span class="arrow">↗</span></div><div class="entry-meta"><span>18% → 82%</span><span><b>34</b> 分钟</span><span><b>¥71.28</b></span></div><div class="social-soc"><div class="soc-track"><i class="soc-fill" style="left:18%;width:64%"></i></div><div class="soc-labels"><span>18%</span><span>82%</span></div></div></div></button>
      <div class="section-head"><h2>本月账单</h2><span>已知口径</span></div>
      <div class="receipt b-receipt"><div class="receipt-label">ENERGY &amp; COST</div><div class="receipt-total">${money(p.cost, 1)}<small> 已知充电费用</small></div><div class="receipt-line"><span>充入电池</span><b>${fmt(p.charge, 1)} kWh</b></div><div class="receipt-line"><span>净电耗 · 估算</span><b>${fmt(p.net, 0)} Wh/km</b></div><div class="receipt-line"><span>费用记录</span><b>${p.knownSessions} / ${p.sessions} 次</b></div><div class="receipt-line"><span>有效入电均价</span><b>${money(p.avgCost, 2)} / kWh</b></div><div class="receipt-note">已知费用不是全部用车成本。费用为空的记录不参与均价。</div></div>
      <div class="section-head"><h2>继续读</h2><span>四章</span></div>
      <div class="chapter-list"><button class="chapter" data-action="topic" data-value="rhythm"><span class="chapter-no">01</span><span><strong>节奏</strong><small>哪些天在用车，单程通常多远。</small></span><span class="chapter-go">→</span></button><button class="chapter" data-action="topic" data-value="energy"><span class="chapter-no">02</span><span><strong>能耗</strong><small>温度与距离分组下的净电耗。</small></span><span class="chapter-go">→</span></button><button class="chapter" data-action="topic" data-value="charging"><span class="chapter-no">03</span><span><strong>补能</strong><small>钱、能量与分类，分别阅读。</small></span><span class="chapter-go">→</span></button><button class="chapter" data-action="topic" data-value="long"><span class="chapter-no">04</span><span><strong>长期</strong><small>六个月额定续航与停放观察。</small></span><span class="chapter-go">→</span></button></div>
      ${bDataNote()}
    </div>`;
  }

  function bDrives() {
    const p = drivesData();
    const empty = state.sample === 'empty';
    const point = pointIndex('b-drives', p.current.length);
    const values = p.current;
    const selected = values[point];
    return `${bMasthead()}<div class="content">
      <p class="kicker">行迹 · ${state.period === 'm' ? '最近三十天' : '最近七天'} / 2026</p>
      <h1 class="page-title">行迹</h1>
      <p class="page-sub">${state.period === 'm' ? '9月27日—10月26日' : '10月20日—10月26日'} · 按开始时间归期</p>
      ${bPeriodRow('drives')}
      <h1 class="headline" style="margin-top:18px">${state.period === 'm' ? '三十天，' : '七天，'}<br><span class="num">${empty ? '—' : fmt(p.total, 1)}</span> 公里。</h1>
      <p class="lede">${empty ? '本期还没有行程记录。' : `${p.trips} 段路 · 估算 <b>${fmt(p.energy, 1)} kWh</b> · 净电耗 <b>${fmt(p.net, 0)} Wh/km</b>。`}</p>
      <figure class="figure"><div class="figure-head"><strong>每日里程</strong><span>km</span></div>${empty ? `<div class="chart-empty"><strong>没有趋势可画</strong><span>有记录后再出现。</span></div>` : chartSvg({ values, labels: p.labels, key: 'b-drives', type: 'line', height: 116, min: 0, max: 120, unit: 'km', point, aria: '每日里程' })}<div class="fig-caption"><span>${state.period === 'm' ? '9月27日—10月26日' : '10月20日—10月26日'} · 每日</span><span>点按图形读值</span></div><div class="chart-readout b-readout"><span>${p.labels[point]} <strong>${fmt(selected, 1)} km</strong></span><span class="step-buttons"><button data-action="step" data-value="b-drives:-1:${values.length}" aria-label="前一个读数">‹</button><button data-action="step" data-value="b-drives:1:${values.length}" aria-label="后一个读数">›</button></span></div></figure>
      ${empty ? '' : `<div class="route-sketch">${mapSvg('b')}</div><div class="route-title"><h2>松岚小区<br>→ 云栖中心</h2><span>10/26 · 17:52</span></div><div class="route-result"><div><b>32.9</b><small>距离 km</small></div><div><b>46</b><small>时长 分钟</small></div><div><b>145</b><small>净电耗 Wh/km</small></div><div><b>68%</b><small>到达电量</small></div></div>
      <div class="section-head"><h2>最近的路</h2><span>按日期</span></div>
      <button class="day-entry" data-action="openDrive" data-value="101"><span class="date"><b>26</b>10月</span><span><h3>松岚小区 → 云栖中心</h3><p><b>32.9 km</b> · 46 分钟 · 净电耗 <b>145 Wh/km</b></p></span></button>
      <button class="day-entry" data-action="openDrive" data-value="102"><span class="date"><b>26</b>10月</span><span><h3>家 → 公司</h3><p><b>18.4 km</b> · 32 分钟 · 净电耗 <b>162 Wh/km</b></p></span></button>
      <button class="day-entry" data-action="openDrive" data-value="103"><span class="date"><b>25</b>10月</span><span><h3>公司 → 湖畔超级充电站</h3><p><b>12.6 km</b> · 24 分钟 · 净电耗 <b>138 Wh/km</b></p></span></button>
      <button class="day-entry" data-action="openDrive" data-value="104"><span class="date"><b>24</b>10月</span><span><h3>家 → 松岚公园</h3><p><b>7.8 km</b> · 18 分钟 · 净电耗 <b>171 Wh/km</b></p></span></button>
      <div class="section-head"><h2>更早</h2><span>按日期筛选</span></div>`}
      ${bDataNote('列表分页与日期筛选沿用正式交互；原型只展示固定记录。')}
    </div>`;
  }

  function bCharging() {
    const p = chargingData();
    const empty = state.sample === 'empty';
    const point = pointIndex('b-charge', p.energy.length);
    const value = p.energy[point];
    const dcShare = p.dc / (p.ac + p.dc);
    return `${bMasthead()}<div class="content">
      <p class="kicker">补能账 · ${state.period === 'm' ? '最近三十天' : '最近七天'} / 2026</p>
      <h1 class="page-title">补能账</h1>
      <p class="page-sub">按结束时间归期 · ${state.period === 'm' ? '9月27日—10月26日' : '10月20日—10月26日'}</p>
      ${bPeriodRow('drives')}
      <h1 class="headline" style="margin-top:18px">这个月，<br>为补能花了<br><span class="num">${empty ? '—' : money(p.totalCost, 1)}</span>。</h1>
      <p class="lede">${empty ? '本期还没有已结束的充电记录。' : `${p.knownSessions} / ${p.sessionCount} 次有费用记录，充入 <b>${fmt(p.totalEnergy, 1)} kWh</b>，有效入电均价 <b>${money(p.avgCost, 2)}/kWh</b>。`}</p>
      <figure class="figure"><div class="figure-head"><strong>每日补能</strong><span>kWh</span></div>${empty ? `<div class="chart-empty"><strong>没有补能记录</strong><span>不画全零趋势。</span></div>` : chartSvg({ values: p.energy, labels: p.labels, key: 'b-charge', type: 'line', height: 112, min: 0, max: 60, unit: 'kWh', point, aria: '每日补入电量' })}<div class="fig-caption"><span>${state.period === 'm' ? '9月27日—10月26日' : '10月20日—10月26日'} · 每日</span><span>缺失不补零</span></div><div class="chart-readout b-readout"><span>${p.labels[point]} <strong>${fmt(value, 1)} kWh</strong></span><span class="step-buttons"><button data-action="step" data-value="b-charge:-1:${p.energy.length}" aria-label="前一个读数">‹</button><button data-action="step" data-value="b-charge:1:${p.energy.length}" aria-label="后一个读数">›</button></span></div></figure>
      <div class="receipt b-receipt"><div class="receipt-label">补能账单 · 已知费用</div><div class="receipt-line"><span>充入电池</span><b>${fmt(p.totalEnergy, 1)} kWh</b></div><div class="receipt-line"><span>已完成会话</span><b>${p.sessionCount} 次</b></div><div class="receipt-line"><span>费用有记录</span><b>${p.knownSessions} / ${p.sessionCount} 次</b></div><div class="receipt-line"><span>记录时长</span><b>${Math.floor(p.duration / 60)}h${String(p.duration % 60).padStart(2, '0')}</b></div><div class="receipt-note">记录时长是会话跨度，不是排队或等待时间。已知费用不是全部用车成本。</div></div>
      <div class="section-head"><h2>补能方式</h2><span>AC / DC / 未知</span></div>
      <div class="b-acdc"><div class="b-acdc-bar"><i class="ac" style="width:${(p.ac / (p.ac + p.dc + p.unknown)) * 100}%"></i><i class="dc" style="width:${(p.dc / (p.ac + p.dc + p.unknown)) * 100}%"></i><i class="unknown" style="width:${(p.unknown / (p.ac + p.dc + p.unknown)) * 100}%"></i></div><div class="b-acdc-legend"><span>AC <b>${fmt(p.ac, 1)}</b></span><span>DC <b>${fmt(p.dc, 1)}</b></span><span>未知 <b>${fmt(p.unknown, 1)}</b></span><span><b>${fmt(dcShare * 100, 0)}%</b> DC · 仅已知分类</span></div></div>
      <div class="section-head"><h2>地点账目</h2><span>按补入能量</span></div>
      ${p.locations.map((l) => `<div class="ledger-row"><span><strong>${l.name}</strong><small>${l.count} 次 · ${fmt(l.energy, 1)} kWh · ${l.mode} · 覆盖 ${l.known}/${l.count}</small></span><span class="ledger-amount">${l.cost == null ? '未记录' : money(l.cost, 2)}<small>${l.cost == null ? '' : '已知费用'}</small></span></div>`).join('')}
      <div class="section-head"><h2>最近一次</h2><span>10/26</span></div>
      <button class="entry" data-action="openCharge" data-value="1"><div class="entry-date"><b>26</b>10月</div><div class="entry-body"><div class="entry-title">湖畔超级充电站<br>补入 46.8 kWh <span class="arrow">↗</span></div><div class="entry-meta"><span>18% → 82%</span><span><b>34</b> 分钟</span><span><b>¥71.28</b></span></div><div class="social-soc"><div class="soc-track"><i class="soc-fill" style="left:18%;width:64%"></i></div><div class="soc-labels"><span>起始 18%</span><span>结束 82%</span></div></div></div></button>
      ${bDataNote('固定合成样例；地图/地点示意不是正式底图验收。')}
    </div>`;
  }

  function bStats() {
    const p = statsData();
    const charge = chargingData();
    const empty = state.sample === 'empty';
    const point = pointIndex('b-stats', p.current.length);
    const current = p.current[point];
    const previous = p.previous[point];
    const distanceDiff = p.total - p.prevTotal;
    const netDiff = p.net - p.prevNet;
    return `${bMasthead()}<div class="content">
      <p class="kicker">用车这件事 · ${periodWords()} / 2026</p>
      <h1 class="page-title">用车这件事</h1>
      <p class="page-sub">${periodWords()} · ${state.period === 'm' ? '10月1日—26日 18:40' : '10月20日—26日 18:40'}</p>
      ${bPeriodRow('month')}
      ${empty ? `<h1 class="headline" style="margin-top:18px">这段时间，<br>还没有可比较的记录。</h1><p class="lede">没有数据时不画趋势，也不输出变化结论。</p>` : `<h1 class="headline" style="margin-top:18px">多开了 <span class="num">${fmt(distanceDiff, 1)}</span> 公里，<br>每公里少用 <span class="num">${fmt(Math.abs(netDiff), 0)}</span> Wh。</h1><p class="lede">本期 <b>${fmt(p.total, 1)} km</b>，参照 <b>${fmt(p.prevTotal, 1)} km</b>；净电耗 <b>${fmt(p.net, 0)}</b> 对 <b>${fmt(p.prevNet, 0)} Wh/km</b>。只描述方向，不评价驾驶好坏。</p>`}
      <figure class="figure"><div class="figure-head"><strong>里程走势</strong><span>本期 / 参照 · km</span></div>${empty ? `<div class="chart-empty"><strong>没有趋势可画</strong><span>空态不伪装成 0。</span></div>` : chartSvg({ values: p.current, previous: p.previous, labels: p.labels, key: 'b-stats', type: 'line', height: 145, min: 0, max: 120, unit: 'km', point, aria: '本期与参照的每日里程' })}<div class="fig-caption"><span>本期 / 参照同进度</span><span><span class="dash">— —</span> 参照</span></div><div class="chart-readout b-readout"><span>${p.labels[point]} <strong>${fmt(current, 1)} km</strong>${previous == null ? '' : ` / 参照 ${fmt(previous, 1)}`}</span><span class="step-buttons"><button data-action="step" data-value="b-stats:-1:${p.current.length}" aria-label="前一个读数">‹</button><button data-action="step" data-value="b-stats:1:${p.current.length}" aria-label="后一个读数">›</button></span></div></figure>
      <section class="b-chapter-block"><div class="b-chapter-index">01</div><div class="b-chapter-copy"><h2>节奏</h2><p><b>${p.active} 个活跃日</b>，驾驶记录 ${Math.floor(p.durationMin / 60)} 小时 ${p.durationMin % 60} 分；单程中位数 ${p.medianTrip} km。</p><div class="calendar-dots">${MONTH_DAYS.map((v, i) => `<i class="${v >= 90 ? 'h3' : v >= 50 ? 'h2' : v > 0 ? 'h1' : ''}"></i>`).join('')}</div><button class="entry-link" data-action="topic" data-value="rhythm">读这一章 →</button></div></section>
      <section class="b-chapter-block"><div class="b-chapter-index">02</div><div class="b-chapter-copy"><h2>能耗</h2><p>净电耗 <b>${fmt(p.net, 0)} Wh/km</b>；按温度分组时，样本从 ${TEMP_BINS[0].samples} 到 ${Math.max(...TEMP_BINS.map((b) => b.samples))} 趟不等。</p><div class="b-spark">${sparkSvg(TEMP_BINS.map((b) => b.value))}</div><button class="entry-link" data-action="topic" data-value="energy">读这一章 →</button></div></section>
      <section class="b-chapter-block"><div class="b-chapter-index">03</div><div class="b-chapter-copy"><h2>补能</h2><p>已知费用 <b>${money(charge.totalCost, 1)}</b>，费用记录 <b>${charge.knownSessions} / ${charge.sessionCount} 次</b>；DC 占已知分类能量 ${fmt((charge.dc / (charge.ac + charge.dc)) * 100, 0)}%。</p><div class="b-acdc"><div class="b-acdc-bar"><i class="ac" style="width:${(charge.ac / (charge.ac + charge.dc + charge.unknown)) * 100}%"></i><i class="dc" style="width:${(charge.dc / (charge.ac + charge.dc + charge.unknown)) * 100}%"></i></div><div class="b-acdc-legend"><span>AC ${fmt(charge.ac, 1)}</span><span>DC ${fmt(charge.dc, 1)}</span></div></div><button class="entry-link" data-action="topic" data-value="charging">读这一章 →</button></div></section>
      <section class="b-chapter-block"><div class="b-chapter-index">04</div><div class="b-chapter-copy"><h2>长期</h2><p>近 6 个月额定续航 P50 为 <b>316 km</b>；样本数与缺月在专题中保留。</p><div class="b-spark">${sparkSvg(RANGE_MONTHS.map((m) => m.value))}</div><button class="entry-link" data-action="topic" data-value="long">读这一章 →</button></div></section>
      ${bDataNote('原型固定样例；长期续航是记录估计，不是健康评分。')}
    </div>`;
  }

  function bTopic() {
    const p = statsData();
    const charge = chargingData();
    const titles = {
      rhythm: ['节奏', '哪些天在用车，单程通常多远。'],
      energy: ['能耗', '按温度与距离看记录，不推断因果。'],
      charging: ['补能', '费用、覆盖、分类与地点分别阅读。'],
      long: ['长期', '看记录估计的变化，不用单次续航打分。'],
    };
    const [title, lede] = titles[state.topic] || titles.rhythm;
    return `<div class="content topic-page">
      <div class="back-row"><button data-action="page" data-value="stats">← 返回统计</button></div>
      <div class="topic-head"><p class="kicker">统计 / 专题</p><h1>${title}</h1><p class="topic-lede">${lede}</p></div>
      ${state.topic === 'rhythm' ? `<div class="big-line"><div><b>${p.active}</b><small>活跃日</small></div><div><b>${Math.floor(p.durationMin / 60)}h${String(p.durationMin % 60).padStart(2, '0')}</b><small>驾驶记录时长</small></div><div><b>${p.medianTrip}</b><small>单程中位 km</small></div></div><div class="topic-figure"><div class="figure-head"><strong>每日里程</strong><span>10/1—10/26 · km</span></div>${calendarGrid(MONTH_DAYS, 'b')}<div class="calendar-legend"><span>0</span><span><i class="h1"></i>&lt;50</span><span><i class="h2"></i>50–90</span><span><i class="h3"></i>≥90</span></div></div><div class="topic-figure"><div class="figure-head"><strong>一周的节奏</strong><span>按开始日</span></div>${chartSvg({ values: weekdayTotals(p.current), labels: WEEKDAY_LABELS, key: 'b-weekday', type: 'bars', height: 100, showY: false, unit: 'km', aria: '按星期的里程' })}</div>` : ''}
      ${state.topic === 'energy' ? `<div class="big-line"><div><b>${fmt(p.net, 0)}</b><small>净电耗 Wh/km</small></div><div><b>−${fmt(Math.abs(p.net - p.prevNet), 0)}</b><small>较参照</small></div><div><b>${DIST_BINS[1].drives}</b><small>中距离行程</small></div></div><div class="topic-figure"><div class="figure-head"><strong>按室外均温分组</strong><span>Wh/km</span></div>${chartSvg({ values: TEMP_BINS.map((b) => b.value), labels: TEMP_BINS.map((b) => b.label), key: 'b-temp', type: 'bars', height: 110, min: 120, max: 190, unit: 'Wh/km', aria: '按温度分组的电耗' })}<div class="temp-samples">${TEMP_BINS.map((b) => `<span>${b.label} <b>${b.samples}</b> 趟</span>`).join('')}</div></div><div class="topic-figure"><div class="figure-head"><strong>按单程距离分组</strong><span>Wh/km</span></div>${DIST_BINS.map((b) => `<div class="ledger-row"><span><strong>${b.label}</strong><small>${b.drives} 趟 · ${b.distance} km</small></span><span class="ledger-amount">${b.value}</span></div>`).join('')}</div>` : ''}
      ${state.topic === 'charging' ? `<div class="big-line"><div><b>${money(charge.totalCost, 1)}</b><small>已知费用</small></div><div><b>${charge.knownSessions}/${charge.sessionCount}</b><small>费用覆盖</small></div><div><b>${money(charge.avgCost, 2)}</b><small>有效均价 /kWh</small></div></div><div class="topic-figure"><div class="figure-head"><strong>补能方式</strong><span>kWh</span></div>${acdcBar(charge, 'b')}<div class="acdc-legend" style="margin-top:8px"><span>AC <b>${fmt(charge.ac, 1)}</b></span><span>DC <b>${fmt(charge.dc, 1)}</b></span><span>未知 <b>${fmt(charge.unknown, 1)}</b></span></div></div><div class="topic-figure"><div class="figure-head"><strong>地点账目</strong><span>已知费用</span></div>${charge.locations.map((l) => `<div class="ledger-row"><span><strong>${l.name}</strong><small>${l.count} 次 · ${fmt(l.energy, 1)} kWh · 覆盖 ${l.known}/${l.count}</small></span><span class="ledger-amount">${l.cost == null ? '未记录' : money(l.cost, 2)}</span></div>`).join('')}</div>` : ''}
      ${state.topic === 'long' ? `<div class="big-line"><div><b>316</b><small>额定续航 P50 / km</small></div><div><b>6</b><small>观察月</small></div><div><b>${RANGE_MONTHS.reduce((a, b) => a + b.samples, 0)}</b><small>样本合计</small></div></div><div class="topic-figure"><div class="figure-head"><strong>额定续航观测</strong><span>km</span></div>${chartSvg({ values: RANGE_MONTHS.map((m) => m.value), labels: RANGE_MONTHS.map((m) => m.label), key: 'b-range', type: 'line', height: 126, min: 300, max: 330, unit: 'km', point: 5, aria: '额定续航月度观测' })}</div><div class="topic-figure"><div class="figure-head"><strong>样本</strong><span>每月</span></div>${RANGE_MONTHS.map((m) => `<div class="ledger-row"><span><strong>${m.label}</strong><small>${m.samples} 个有效样本</small></span><span class="ledger-amount">${m.value} km</span></div>`).join('')}</div>` : ''}
      <p class="topic-note">固定合成样例 · 正式结果取服务端原值；不把估算、分类未知或旧快照包装成确定结论。</p>
    </div>`;
  }

  function bDriveDetail() {
    const d = latestDrive();
    const point = Math.min(state.points['b-drive-detail'] ?? 10, DRIVE_SPEED.length - 1);
    return `<div class="content">
      <div class="detail-back"><button data-action="page" data-value="drives">← 返回行程</button></div>
      <div class="detail-cover"><div class="cover-meta"><span>行笺 · 一次出行</span><span>${d.date} ${d.time}</span></div><h1>${d.start}<br>→ ${d.end}</h1><p class="cover-caption">服务端采样路线 · 地图为合成示意，不是导航。</p></div>
      <div class="detail-map">${mapSvg('b')}<span class="map-label">路线示意 · 非真实底图</span></div>
      <div class="detail-result"><div><b>32.9</b><small>距离 km</small></div><div><b>46</b><small>时长 分钟</small></div><div><b>145</b><small>净电耗 Wh/km</small></div><div><b>68%</b><small>到达电量</small></div></div>
      <div class="field-note"><b>出发 76% → 到达 68%</b><br>本次净电耗 145 Wh/km；个人 30 日整体为 154 Wh/km。这是背景参照，不是同路比较。</div>
      <div class="detail-figure"><div class="figure-head"><strong>速度过程</strong><span>km/h</span></div>${chartSvg({ values: DRIVE_SPEED, labels: DRIVE_SPEED_LABELS, key: 'b-drive-detail', type: 'line', height: 128, min: 0, max: 110, unit: 'km/h', point, aria: '速度过程' })}<div class="chart-readout b-readout"><span>${DRIVE_SPEED_LABELS[point]} <strong>${DRIVE_SPEED[point]} km/h</strong></span><span class="step-buttons"><button data-action="step" data-value="b-drive-detail:-1:${DRIVE_SPEED.length}" aria-label="前一个采样">‹</button><button data-action="step" data-value="b-drive-detail:1:${DRIVE_SPEED.length}" aria-label="后一个采样">›</button></span></div></div>
      <div class="field-note"><b>驾驶与环境</b><br>平均速度 43 km/h · 最高 91 km/h · 车外均温 15.0 °C · 车内均温 21.0 °C。<br>更多指标保留在正式详情中；缺失值不补点、不补零。</div>
      <p class="topic-note">原型固定合成样例；地图仍受供应商许可、坐标与网络验收约束。</p>
    </div>`;
  }

  function bChargeDetail() {
    const c = SESSIONS[0];
    const point = Math.min(state.points['b-charge-detail'] ?? 4, POWER_CURVE.length - 1);
    return `<div class="content">
      <div class="detail-back"><button data-action="page" data-value="charging">← 返回充电</button></div>
      <div class="detail-cover"><div class="cover-meta"><span>行笺 · 一次补能</span><span>${c.date} ${c.start}–${c.end}</span></div><h1>${c.place}<br>补入 46.8 kWh。</h1><p class="cover-caption">18% → 82% · 34 分钟 · DC · 费用 ¥71.28</p></div>
      <div class="social-soc" style="margin-top:13px"><div class="soc-track" style="height:7px"><i class="soc-fill" style="left:18%;width:64%"></i></div><div class="soc-labels"><span>起始 18%</span><span>结束 82%</span></div></div>
      <div class="receipt b-receipt"><div class="receipt-label">本次账目</div><div class="receipt-total">¥71.28</div><div class="receipt-line"><span>充入电池</span><b>46.8 kWh</b></div><div class="receipt-line"><span>电网侧估算</span><b>49.5 kWh</b></div><div class="receipt-line"><span>记录时长</span><b>34 分钟</b></div><div class="receipt-note">两侧能量不相加，不把差额命名为损耗率。</div></div>
      <div class="detail-figure"><div class="figure-head"><strong>功率曲线</strong><span>kW</span></div>${chartSvg({ values: POWER_CURVE, labels: POWER_LABELS, key: 'b-charge-detail', type: 'line', height: 132, min: 0, max: 180, unit: 'kW', point, aria: '充电功率曲线' })}<div class="chart-readout b-readout"><span>${POWER_LABELS[point]} 分钟 <strong>${fmt(POWER_CURVE[point], 0)} kW</strong></span><span class="step-buttons"><button data-action="step" data-value="b-charge-detail:-1:${POWER_CURVE.length}" aria-label="前一个采样">‹</button><button data-action="step" data-value="b-charge-detail:1:${POWER_CURVE.length}" aria-label="后一个采样">›</button></span></div></div>
      <div class="field-note"><b>过程</b><br>采样峰值 168 kW，记录均值 87.4 kW。峰值来自服务端采样，不等同原始极值；功率下降不自动解释原因。<br><b>环境</b>：DC · 地点记录为湖畔超级充电站。电压、相数等次级信息保留在正式详情。</div>
      <p class="topic-note">原型固定合成样例；地点地图为合成示意，正式底图仍需验收。</p>
    </div>`;
  }

  /* ---------- C: bento pages ---------- */
  function cTopbar() {
    return `<header class="topbar"><div class="brand">${icon('leaf')}行笺</div><button class="vehicle" data-action="sheet" data-value="vehicle"><b>${DATA.vehicle.name}</b>${icon('chevron-down')}</button><div class="spacer"></div><button class="avatar" data-action="sheet" data-value="menu" aria-label="更多">⋯</button></header>`;
  }

  function cPeriods(kind = 'month') {
    const a = kind === 'month' ? '本月' : '近30天';
    return `<div class="c-periods"><button class="${state.period === 'm' ? 'active' : ''}" data-action="period" data-value="m">${a}</button><button class="${state.period === 'w' ? 'active' : ''}" data-action="period" data-value="w">近7天</button><span style="flex:1"></span><button data-action="sheet" data-value="period">${icon('calendar')} 日期</button></div>`;
  }

  function cPageHead(title, sub, action = '') {
    return `<div class="c-page-head"><div><h1>${title}</h1><p>${sub}</p></div>${action ? `<button class="head-action" data-action="sheet" data-value="records">${action} ↗</button>` : ''}</div>`;
  }

  function cOverview() {
    const p = overviewData();
    const chargeData = chargingData();
    const empty = state.sample === 'empty';
    const missing = state.sample === 'missing';
    const metric = state.metric;
    const values =
      metric === 'net'
        ? missing
          ? p.netSeries.map(() => null)
          : p.netSeries
        : metric === 'charge'
          ? chargingData().energy.slice(state.period === 'w' ? -7 : -26)
          : metric === 'cost'
            ? chargingData().cost.slice(state.period === 'w' ? -7 : -26)
            : p.current;
    const point = pointIndex('c-overview', values.length);
    const unit = metric === 'net' ? 'Wh/km' : metric === 'charge' ? 'kWh' : metric === 'cost' ? 'CNY' : 'km';
    const title = metric === 'net' ? '每日净电耗' : metric === 'charge' ? '每日补能' : metric === 'cost' ? '每日已知费用' : '每日里程';
    const selected = values[point];
    const c = latestCharge();
    const d = latestDrive();
    return `${cTopbar()}${cPeriods('month')}<div class="bento">
      <section class="tile hero-tile full dark">
        <div class="status"><i></i>最近状态 · ${DATA.status.state} · ${DATA.status.updated}</div>
        <div class="range">${DATA.status.range}<span>km</span></div>
        <div class="range-label">额定续航 · 电量 ${DATA.status.soc}% · 非实时</div>
        <div class="soc-pill">${DATA.status.soc}%<small>电池</small></div>
        <div class="today"><div><b>${DATA.status.todayDistance}</b><small>今日 km</small></div><div><b>${DATA.status.todayTrips}</b><small>次行程</small></div><div><b>${fmt(DATA.status.todayEnergy, 2)}</b><small>估算 kWh</small></div><div><b>${fmt(DATA.status.power, 1)}</b><small>kW 充电</small></div></div>
        <div class="car">${carSvg()}</div>
      </section>
      <section class="tile mint big-mileage">
        <div class="tile-kicker"><span>${periodWords()} · 驾驶里程</span><span>${empty ? '—' : `${p.trips} 趟`}</span></div>
        <div><div class="tile-value">${empty ? '—' : fmt(p.total, 1)}<span>km</span></div><span class="delta-chip">${empty ? '暂无记录' : `↑ ${fmt((p.total / p.prevTotal - 1) * 100, 1)}% 较参照`}</span><div class="spark">${empty ? '' : sparkSvg(p.current)}</div></div>
      </section>
      <section class="tile sand small-tile">
        <div class="tile-kicker"><span>净电耗 · 估算</span>${icon('temp')}</div>
        <div class="tile-value">${empty || missing ? '—' : fmt(p.net, 0)}<span>Wh/km</span></div>
        <div class="tile-note">${missing ? '样本不足，仅保留原值' : `较参照低 ${fmt(Math.abs(p.net - p.prevNet), 0)} Wh/km`}</div>
      </section>
      <section class="tile paper small-tile">
        <div class="tile-kicker"><span>已知充电费用</span>${icon('wallet')}</div>
        <div class="tile-value">${empty ? '—' : money(p.cost, 1)}</div>
        <div class="tile-note">${empty ? '本期暂无' : `${p.knownSessions} / ${p.sessions} 次有记录`}</div>
      </section>
      <section class="tile chart-tile full">
        <div class="chart-head"><div><h2>${title}</h2><p>${state.period === 'm' ? '10月1日—26日' : '10月20日—26日'} · 点按图形读值</p></div><div class="tile-chips">${[['distance', '里程'], ['net', '电耗'], ['charge', '补能'], ['cost', '费用']].map(([value, label]) => `<button class="${metric === value ? 'active' : ''}" data-action="metric" data-value="${value}">${label}</button>`).join('')}</div></div>
        ${empty ? `<div class="chart-empty"><strong>这个区间还没有记录</strong><span>空态不画全零趋势。</span></div>` : chartSvg({ values, labels: p.labels, key: 'c-overview', type: metric === 'net' ? 'line' : 'bars', height: 138, unit, point, min: metric === 'net' ? 130 : 0, max: metric === 'net' ? 180 : 120, aria: title })}
        <div class="chart-readout"><span>${p.labels[point]} <strong>${selected == null ? '—' : `${fmt(selected, unit === 'CNY' ? 2 : 1)} ${unit}`}</strong></span><span>${icon('arrow-right')}</span></div>
      </section>
      <div class="insight-ticker full">${icon('spark')}<span>${empty || missing ? '净电耗样本不足，本期暂不做区间比较。' : `净电耗比上月同期低 <b>${fmt(Math.abs(p.net - p.prevNet), 0)} Wh/km</b>。`} <span style="color:var(--sub)">同车、同归期时区。</span></span></div>
      <section class="tile cream">
        <div class="tile-kicker"><span>补能方式</span><span class="tile-head-action" data-action="topic" data-value="charging">看明细 ${icon('chevron')}</span></div>
        ${acdcBar(chargingData())}
        <div class="acdc-caption"><span>AC <b>${fmt(chargeData.ac, 1)}</b></span><span>DC <b>${fmt(chargeData.dc, 1)}</b></span><span>未知 <b>${fmt(chargeData.unknown, 1)}</b></span></div>
        <div class="tile-note">DC 占已知分类 ${fmt((chargeData.dc / (chargeData.ac + chargeData.dc)) * 100, 0)}% · 未知不归入 AC</div>
      </section>
      <button class="tile outline" data-action="openDrive" data-value="${d.id}"><div class="tile-kicker"><span>最近行程</span><span class="tile-head-action">路线 ${icon('chevron')}</span></div><div class="route-mini">${mapSvg('c')}</div><div class="route-label">${d.start} → ${d.end}</div><div class="route-meta"><b>${fmt(d.distance, 1)} km</b> · ${d.duration} 分钟 · ${fmt(d.consumption, 0)} Wh/km</div></button>
      <button class="tile dark full" data-action="openCharge" data-value="${c.id}"><div class="tile-kicker"><span>最近充电 · ${c.date} ${c.start} · ${c.place}</span><span class="tile-head-action" style="color:#9ce7b9">${c.duration} 分钟 ${icon('chevron')}</span></div><div class="tile-value" style="font-size:28px">${c.startSoc}% → ${c.endSoc}%<span>电量</span></div><div class="soc-card"><div class="soc-track"><i class="soc-fill" style="left:${c.startSoc}%;width:${c.endSoc - c.startSoc}%"></i></div><div class="soc-labels"><span>补入 ${fmt(c.energy, 1)} kWh</span><span>${money(c.cost)}</span></div></div></button>
      <div class="c-section-label full">继续读懂</div>
      <button class="tile mint c-topic-tile" data-action="topic" data-value="rhythm"><div class="tile-kicker"><span>节奏</span>${icon('calendar')}</div><div class="tile-value">${p.active}<span>天</span></div><div class="tile-note">单程中位 18.6 km</div><span class="chapter-enter">读下去 →</span></button>
      <button class="tile sand c-topic-tile" data-action="topic" data-value="long"><div class="tile-kicker"><span>长期</span>${icon('battery')}</div><div class="tile-value">316<span>km</span></div><div class="tile-note">6个月额定续航 P50</div><span class="chapter-enter">读下去 →</span></button>
    </div>`;
  }

  function cDrives() {
    const p = drivesData();
    const empty = state.sample === 'empty';
    const point = pointIndex('c-drives', p.current.length);
    const selected = p.current[point];
    return `${cTopbar()}${cPageHead('行程', state.period === 'm' ? '近30天 · 9月27日—10月26日' : '近7天 · 10月20日—10月26日', '全部记录')}${cPeriods('drives')}<div class="bento">
      <section class="tile dark full">
        <div class="tile-kicker"><span>期间里程 · ${state.period === 'm' ? '近30天' : '近7天'}</span><span style="color:#9ce7b9">${empty ? '—' : `${p.trips} 趟`}</span></div>
        <div class="tile-value" style="font-size:39px;margin-top:9px">${empty ? '—' : fmt(p.total, 1)}<span>km</span></div>
        <div class="tile-note" style="margin-top:7px">估算 <b>${empty ? '—' : fmt(p.energy, 1)} kWh</b> · 净电耗 <b>${empty ? '—' : fmt(p.net, 0)} Wh/km</b></div>
        <div style="position:absolute;right:-12px;bottom:1px;width:150px;opacity:.18;color:#b6f0c9">${routeLineArt()}</div>
      </section>
      <section class="tile chart-tile full">
        <div class="chart-head"><div><h2>出行节奏</h2><p>${state.period === 'm' ? '9/27—10/26' : '10/20—10/26'} · 每日里程</p></div><span class="unit">km</span></div>
        ${empty ? `<div class="chart-empty"><strong>没有趋势</strong><span>有记录后再出现。</span></div>` : chartSvg({ values: p.current, labels: p.labels, key: 'c-drives', type: 'bars', height: 116, unit: 'km', point, max: 120, aria: '每日里程' })}
        <div class="chart-readout"><span>${p.labels[point]} <strong>${fmt(selected, 1)} km</strong></span><span>点按图形读值</span></div>
      </section>
      <div class="c-section-label full">最近的路</div>
      <button class="tile outline full" data-action="openDrive" data-value="101"><div class="tile-kicker"><span>10/26 · 17:52</span><span class="tile-head-action">单次回顾 ${icon('chevron')}</span></div><div class="route-mini" style="height:98px">${mapSvg('c')}</div><div class="route-label">松岚小区 → 云栖中心</div><div class="route-meta"><b>32.9 km</b> · 46 分钟 · 净电耗 145 Wh/km · 到达 68%</div></button>
      <button class="tile paper" data-action="openDrive" data-value="102"><div class="tile-kicker"><span>10/26 · 08:30</span>${icon('chevron')}</div><div class="route-label">家 → 公司</div><div class="route-meta"><b>18.4 km</b> · 32 分钟</div><div class="tile-note">净电耗 162 Wh/km</div></button>
      <button class="tile paper" data-action="openDrive" data-value="103"><div class="tile-kicker"><span>10/25 · 18:10</span>${icon('chevron')}</div><div class="route-label">公司 → 湖畔超充</div><div class="route-meta"><b>12.6 km</b> · 24 分钟</div><div class="tile-note">净电耗 138 Wh/km</div></button>
      <section class="tile cream full"><div class="tile-kicker"><span>更早的记录</span><span>按日期</span></div><button class="c-row-line" data-action="openDrive" data-value="104"><span>10/24 · 家 → 松岚公园</span><b>7.8 km</b></button><button class="c-row-line" data-action="openDrive" data-value="105"><span>10/23 · 公司 → 家</span><b>18.7 km</b></button><button class="c-row-line" data-action="openDrive" data-value="106"><span>10/22 · 家 → 云栖中心</span><b>27.6 km</b></button></section>
    </div>`;
  }

  function cCharging() {
    const p = chargingData();
    const empty = state.sample === 'empty';
    const point = pointIndex('c-charge', p.energy.length);
    const selected = p.energy[point];
    return `${cTopbar()}${cPageHead('充电', state.period === 'm' ? '近30天 · 按结束时间归期' : '近7天 · 按结束时间归期', '全部记录')}${cPeriods('drives')}<div class="bento">
      <section class="tile dark full">
        <div class="tile-kicker"><span>已知充电费用</span><span style="color:#9ce7b9">${empty ? '—' : 'CNY'}</span></div>
        <div class="tile-value" style="font-size:44px;margin-top:7px">${empty ? '—' : money(p.totalCost, 1)}</div>
        <div class="tile-note">${empty ? '本期暂无补能记录' : `${p.knownSessions} / ${p.sessionCount} 次有费用记录 · 仅含已知费用`}</div>
        <div class="soc-card" style="margin-top:13px"><div class="soc-track"><i class="soc-fill" style="width:${empty ? 0 : (p.knownSessions / p.sessionCount) * 100}%"></i></div><div class="soc-labels"><span>费用覆盖</span><span>${empty ? '0 / 0' : `${p.knownSessions} / ${p.sessionCount}`}</span></div></div>
      </section>
      <section class="tile mint small-tile"><div class="tile-kicker"><span>充入电池</span>${icon('bolt')}</div><div class="tile-value">${empty ? '—' : fmt(p.totalEnergy, 1)}<span>kWh</span></div><div class="tile-note">${empty ? '暂无' : `${p.sessionCount} 次充电`}</div></section>
      <section class="tile sand small-tile"><div class="tile-kicker"><span>记录时长</span>${icon('clock')}</div><div class="tile-value">${empty ? '—' : `${Math.floor(p.duration / 60)}h${String(p.duration % 60).padStart(2, '0')}`}</div><div class="tile-note">会话跨度 · 非等待时间</div></section>
      <section class="tile chart-tile full"><div class="chart-head"><div><h2>每日补能</h2><p>${state.period === 'm' ? '9/27—10/26' : '10/20—10/26'} · 点按图形读值</p></div><span class="unit">kWh</span></div>${empty ? `<div class="chart-empty"><strong>没有补能记录</strong><span>空态不画全零趋势。</span></div>` : chartSvg({ values: p.energy, labels: p.labels, key: 'c-charge', type: 'bars', height: 122, unit: 'kWh', point, max: 60, aria: '每日补入电量' })}<div class="chart-readout"><span>${p.labels[point]} <strong>${fmt(selected, 1)} kWh</strong></span><span>${state.period === 'm' ? '近30天' : '近7天'}</span></div></section>
      <section class="tile cream full"><div class="tile-kicker"><span>补能方式</span><span>仅已知分类</span></div>${acdcBar(p)}<div class="acdc-caption"><span>AC <b>${fmt(p.ac, 1)}</b></span><span>DC <b>${fmt(p.dc, 1)}</b></span><span>未知 <b>${fmt(p.unknown, 1)}</b></span><span><b>${fmt((p.dc / (p.ac + p.dc)) * 100, 0)}%</b> DC</span></div></section>
      <div class="c-section-label full">常去地点</div>
      ${p.locations.map((l) => `<button class="tile ${l.cost == null ? 'sand' : 'outline'}" data-action="sheet" data-value="records"><div class="tile-kicker"><span>${l.name}</span>${icon('map-pin')}</div><div class="tile-value" style="font-size:19px;margin-top:8px">${l.cost == null ? '未记录' : money(l.cost, 2)}</div><div class="tile-note">${l.count} 次 · ${fmt(l.energy, 1)} kWh · ${l.mode} · 覆盖 ${l.known}/${l.count}</div></button>`).join('')}
      <button class="tile dark full" data-action="openCharge" data-value="1"><div class="tile-kicker"><span>最近一次 · 10/26 13:12 · 湖畔超级充电站</span><span style="color:#9ce7b9">${icon('chevron')}</span></div><div class="tile-value" style="font-size:28px">18% → 82%<span>电量</span></div><div class="soc-card"><div class="soc-track"><i class="soc-fill" style="left:18%;width:64%"></i></div><div class="soc-labels"><span>补入 46.8 kWh · 34 分钟</span><span>¥71.28</span></div></div></button>
    </div>`;
  }

  function cStats() {
    const p = statsData();
    const charge = chargingData();
    const empty = state.sample === 'empty';
    const point = pointIndex('c-stats', p.current.length);
    const current = p.current[point];
    const previous = p.previous[point];
    return `${cTopbar()}${cPageHead('统计', `${periodWords()} · 2026年10月`, '全部指标')}${cPeriods('month')}<div class="bento">
      <section class="tile full paper">
        <div class="tile-kicker"><span>${periodWords()} · 驾驶里程</span><span>${empty ? '—' : `${p.trips} 趟`}</span></div>
        <div class="tile-value" style="font-size:44px;margin-top:8px">${empty ? '—' : fmt(p.total, 1)}<span>km</span></div>
        <span class="delta-chip">${empty ? '暂无记录' : `↑ ${fmt(p.total - p.prevTotal, 1)} km 较参照`}</span>
        <div class="acdc-caption" style="margin-top:9px;font-size:9px">净电耗 <b>${empty ? '—' : `${fmt(p.net, 0)} Wh/km`}</b> · 已知支出 <b>${empty ? '—' : money(p.cost, 1)}</b> · ${empty ? '—' : p.active} 个活跃日</div>
      </section>
      <section class="tile chart-tile full dark">
        <div class="chart-head"><div><h2>里程走势</h2><p>本期 vs 参照 · 同进度</p></div><span class="unit" style="background:rgba(255,255,255,.08);color:#a8c8b2">km</span></div>
        ${empty ? `<div class="chart-empty"><strong style="color:#eef7ef">这个区间还没有记录</strong><span style="color:#a8c8b2">没有数据时不画全零趋势。</span></div>` : chartSvg({ values: p.current, previous: p.previous, labels: p.labels, key: 'c-stats', type: 'bars', height: 144, unit: 'km', point, max: 120, aria: '本期与参照的每日里程' })}
        <div class="chart-readout" style="border-color:rgba(255,255,255,.12);color:#a8c8b2"><span>${p.labels[point]} <strong style="color:#eef7ef">${fmt(current, 1)} km</strong>${previous == null ? '' : ` / 参照 ${fmt(previous, 1)}`}</span><span>点按图形读值</span></div>
      </section>
      <div class="c-section-label full">四个问题</div>
      <button class="tile mint c-topic-tile" data-action="topic" data-value="rhythm"><div class="tile-kicker"><span>节奏</span>${icon('calendar')}</div><div class="tile-value">${p.active}<span>天</span></div><div class="tile-note">单程中位 ${p.medianTrip} km</div><div class="mini">${sparkSvg(weekdayTotals(p.current))}</div><span class="chapter-enter">读下去 →</span></button>
      <button class="tile sand c-topic-tile" data-action="topic" data-value="energy"><div class="tile-kicker"><span>能耗</span>${icon('temp')}</div><div class="tile-value">${fmt(p.net, 0)}<span>Wh/km</span></div><div class="tile-note">较参照低 ${fmt(Math.abs(p.net - p.prevNet), 0)}</div><div class="mini">${sparkSvg(NET_DAYS.slice(state.period === 'w' ? -7 : 0))}</div><span class="chapter-enter">读下去 →</span></button>
      <button class="tile cream c-topic-tile" data-action="topic" data-value="charging"><div class="tile-kicker"><span>补能</span>${icon('bolt')}</div><div class="tile-value">${money(charge.totalCost, 1)}</div><div class="tile-note">${charge.knownSessions} / ${charge.sessionCount} 次有费用 · ${fmt(charge.totalEnergy, 1)} kWh</div>${acdcBar(charge)}<span class="chapter-enter">读下去 →</span></button>
      <button class="tile dark c-topic-tile" data-action="topic" data-value="long"><div class="tile-kicker"><span>长期</span>${icon('battery')}</div><div class="tile-value">316<span>km</span></div><div class="tile-note">6 个月额定续航 P50 · 记录估计</div><div class="mini">${sparkSvg(RANGE_MONTHS.map((m) => m.value))}</div><span class="chapter-enter">读下去 →</span></button>
    </div>`;
  }

  function cTopic() {
    const p = statsData();
    const charge = chargingData();
    const meta = {
      rhythm: ['节奏', '哪些天在用车，单程通常多远。'],
      energy: ['能耗', '按温度和单程距离看记录，不推断因果。'],
      charging: ['补能', '费用、覆盖、分类与地点分别阅读。'],
      long: ['长期', '看记录估计的变化，不用单次续航打分。'],
    }[state.topic] || ['节奏', ''];
    return `${cTopbar()}<div class="c-page-head"><div><h1>${meta[0]}</h1><p>${meta[1]}</p></div><button class="head-action" data-action="page" data-value="stats">← 统计</button></div><div class="bento">
      ${state.topic === 'rhythm' ? `<section class="tile mint full"><div class="tile-kicker"><span>活跃日</span>${icon('calendar')}</div><div class="tile-value" style="font-size:44px">${p.active}<span>天</span></div><div class="tile-note">驾驶记录 ${Math.floor(p.durationMin / 60)}h${String(p.durationMin % 60).padStart(2, '0')} · 单程中位 ${p.medianTrip} km</div></section><section class="tile full">${calendarGrid(MONTH_DAYS, 'c')}<div class="acdc-caption"><span>10/1—10/26</span><span>浅→深：0 / &lt;30 / 30–60 / 60–90 / ≥90 km</span></div></section><section class="tile chart-tile full"><div class="chart-head"><div><h2>一周的节奏</h2><p>按开始日分组</p></div><span class="unit">km</span></div>${chartSvg({ values: weekdayTotals(p.current), labels: WEEKDAY_LABELS, key: 'c-weekday', type: 'bars', height: 112, unit: 'km', showY: false, aria: '按星期的里程' })}</section>` : ''}
      ${state.topic === 'energy' ? `<section class="tile sand full"><div class="tile-kicker"><span>净电耗 · 估算</span>${icon('temp')}</div><div class="tile-value" style="font-size:44px">${fmt(p.net, 0)}<span>Wh/km</span></div><div class="tile-note">较参照低 ${fmt(Math.abs(p.net - p.prevNet), 0)} Wh/km · 样本不足时不输出结论</div></section><section class="tile chart-tile full"><div class="chart-head"><div><h2>按室外均温分组</h2><p>柱旁数字为有效行程数</p></div><span class="unit">Wh/km</span></div>${chartSvg({ values: TEMP_BINS.map((b) => b.value), labels: TEMP_BINS.map((b) => b.label), key: 'c-temp', type: 'bars', height: 124, unit: 'Wh/km', min: 120, max: 190, aria: '按温度分组的电耗' })}<div class="acdc-caption">${TEMP_BINS.map((b) => `<span>${b.label} <b>${b.samples}</b> 趟</span>`).join('')}</div></section><section class="tile full"><div class="tile-kicker"><span>按单程距离</span><span>Wh/km</span></div>${DIST_BINS.map((b) => `<div class="c-row-line"><span>${b.label} · ${b.drives} 趟</span><b>${b.value} Wh/km</b></div>`).join('')}</section>` : ''}
      ${state.topic === 'charging' ? `<section class="tile dark full"><div class="tile-kicker"><span>已知充电费用</span><span style="color:#9ce7b9">CNY</span></div><div class="tile-value" style="font-size:43px">${money(charge.totalCost, 1)}</div><div class="tile-note">${charge.knownSessions} / ${charge.sessionCount} 次有费用记录 · ${fmt(charge.totalEnergy, 1)} kWh</div><div class="soc-card"><div class="soc-track"><i class="soc-fill" style="left:0;width:${(charge.knownSessions / charge.sessionCount) * 100}%"></i></div><div class="soc-labels"><span>费用覆盖</span><span>${charge.knownSessions} / ${charge.sessionCount}</span></div></div></section><section class="tile full">${acdcBar(charge)}<div class="acdc-caption"><span>AC <b>${fmt(charge.ac, 1)}</b></span><span>DC <b>${fmt(charge.dc, 1)}</b></span><span>未知 <b>${fmt(charge.unknown, 1)}</b></span></div></section>${charge.locations.map((l) => `<button class="tile outline" data-action="sheet" data-value="records"><div class="tile-kicker"><span>${l.name}</span>${icon('map-pin')}</div><div class="tile-value" style="font-size:18px">${l.cost == null ? '未记录' : money(l.cost, 2)}</div><div class="tile-note">${l.count} 次 · ${fmt(l.energy, 1)} kWh · ${l.mode}</div></button>`).join('')}` : ''}
      ${state.topic === 'long' ? `<section class="tile dark full"><div class="tile-kicker"><span>额定续航 P50</span><span style="color:#9ce7b9">记录估计</span></div><div class="tile-value" style="font-size:44px">316<span>km</span></div><div class="tile-note">近 6 个月 · 不是电池健康评分</div></section><section class="tile chart-tile full"><div class="chart-head"><div><h2>每月观测</h2><p>缺月不补点</p></div><span class="unit">km</span></div>${chartSvg({ values: RANGE_MONTHS.map((m) => m.value), labels: RANGE_MONTHS.map((m) => m.label), key: 'c-range', type: 'line', height: 130, unit: 'km', min: 300, max: 330, point: 5, aria: '额定续航月度观测' })}</section><section class="tile full"><div class="tile-kicker"><span>样本</span><span>每月</span></div>${RANGE_MONTHS.map((m) => `<div class="c-row-line"><span>${m.label} · ${m.samples} 样本</span><b>${m.value} km</b></div>`).join('')}</section>` : ''}
    </div>`;
  }

  function cDriveDetail() {
    const d = latestDrive();
    const point = Math.min(state.points['c-drive-detail'] ?? 10, DRIVE_SPEED.length - 1);
    return `<div class="c-detail-map">${mapSvg('c')}<button class="c-map-back" data-action="page" data-value="drives" aria-label="返回行程">${icon('arrow-left')}</button><div class="c-map-title"><small>${d.date} ${d.time} · 最近行程</small><h1>${d.start} → ${d.end}</h1><p>路线示意 · 非导航</p></div></div>
    <div class="c-detail-body">
      <div class="c-detail-result"><div><small>距离</small><strong>${fmt(d.distance, 1)}<span>km</span></strong></div><div><small>时长</small><strong>${d.duration}<span>分钟</span></strong></div><div><small>净电耗</small><strong>${d.consumption}<span>Wh/km</span></strong></div></div>
      <section class="c-detail-chart"><div class="chart-head"><div><h2>速度过程</h2><p>点按图形读值</p></div><span class="unit">km/h</span></div>${chartSvg({ values: DRIVE_SPEED, labels: DRIVE_SPEED_LABELS, key: 'c-drive-detail', type: 'line', height: 130, min: 0, max: 110, unit: 'km/h', point, aria: '速度过程' })}<div class="chart-readout"><span>${DRIVE_SPEED_LABELS[point]} <strong>${DRIVE_SPEED[point]} km/h</strong></span><span>峰值 91 km/h</span></div></section>
      <div class="c-detail-grid"><div><small>出发电量</small><strong>76%</strong></div><div><small>到达电量</small><strong>68%</strong></div><div><small>车外均温</small><strong>15.0 °C</strong></div><div><small>车内均温</small><strong>21.0 °C</strong></div></div>
      <p class="c-detail-note">本次 145 Wh/km，个人 30 日整体 154 Wh/km。合成样例；缺失不补点，地图待正式验收。</p>
    </div>`;
  }

  function cChargeDetail() {
    const c = SESSIONS[0];
    const point = Math.min(state.points['c-charge-detail'] ?? 4, POWER_CURVE.length - 1);
    return `<div class="c-detail-map">${pinMapSvg('c')}<button class="c-map-back" data-action="page" data-value="charging" aria-label="返回充电">${icon('arrow-left')}</button><div class="c-map-title"><small>${c.date} ${c.start}–${c.end} · 最近充电</small><h1>${c.place}</h1><p>地点示意 · DC · ${c.duration} 分钟</p></div></div>
    <div class="c-detail-body">
      <section class="tile dark full" style="margin-top:7px"><div class="tile-kicker"><span>电量区间</span><span style="color:#9ce7b9">46.8 kWh</span></div><div class="tile-value" style="font-size:30px">18% → 82%<span>电量</span></div><div class="soc-card"><div class="soc-track"><i class="soc-fill" style="left:18%;width:64%"></i></div><div class="soc-labels"><span>起始 18%</span><span>结束 82% · ¥71.28</span></div></div></section>
      <div class="c-detail-result" style="margin-top:7px"><div><small>充入电池</small><strong>46.8<span>kWh</span></strong></div><div><small>已记录费用</small><strong>¥71.28</strong></div><div><small>记录时长</small><strong>34<span>分钟</span></strong></div></div>
      <section class="c-detail-chart"><div class="chart-head"><div><h2>功率曲线</h2><p>点按图形读值</p></div><span class="unit">kW</span></div>${chartSvg({ values: POWER_CURVE, labels: POWER_LABELS, key: 'c-charge-detail', type: 'line', height: 132, min: 0, max: 180, unit: 'kW', point, aria: '充电功率曲线' })}<div class="chart-readout"><span>${POWER_LABELS[point]} 分钟 <strong>${fmt(POWER_CURVE[point], 0)} kW</strong></span><span>峰值 168 kW</span></div></section>
      <div class="c-detail-grid"><div><small>电网侧估算</small><strong>49.5 kWh</strong></div><div><small>充电类型</small><strong>DC</strong></div><div><small>地点</small><strong>湖畔</strong></div><div><small>费用</small><strong>¥71.28</strong></div></div>
      <p class="c-detail-note">两侧能量不相加，不推导损耗率。地点地图为合成示意；正式底图/坐标仍待验收。</p>
    </div>`;
  }

  /* ---------- shell / review ---------- */
  const VARIANTS = {
    A: {
      name: '仪表舱',
      caption: '先看车，再看这个月',
      intro: '深色车况主屏把“现在”变成一个明确锚点；本月主数、主图、洞察依次退后。落地成本最低，最适合作为默认结构。',
      points: ['主角：车况主屏 + 本月里程', '节奏：深色 → 纸面主图 → 浅色辅助', '适合：每天打开，快速确认'],
    },
    B: {
      name: '行笺志',
      caption: '把一个月写成一本小志',
      intro: '纸面、衬线、时间线与账本，弱化卡片边界。品牌气质最强，但信息密度更低、实现更定制。',
      points: ['主角：一句月度结论 + 一张图版', '节奏：标题 → 图版 → 手账 → 账单', '适合：回顾、长期阅读'],
    },
    C: {
      name: '数据拼贴',
      caption: '用大小和颜色制造节奏',
      intro: '一个最大里程 tile、一个车况 tile、若干证据 tile。视觉冲击最强；需要严格控制主角数量，避免又变成“更多卡片”。',
      points: ['主角：最大里程 tile', '节奏：大块 → 小块 → 满幅图', '适合：年轻、强视觉、专题'],
    },
  };
  const PAGE_NAMES = {
    overview: '概览',
    drives: '行程',
    charging: '充电',
    stats: '统计',
    driveDetail: '行程详情',
    chargeDetail: '充电详情',
    topic: '统计专题',
  };

  function pageContent(variant, page) {
    if (variant === 'A') {
      if (page === 'drives') return aDrives();
      if (page === 'charging') return aCharging();
      if (page === 'stats') return aStats();
      if (page === 'driveDetail') return aDriveDetail();
      if (page === 'chargeDetail') return aChargeDetail();
      if (page === 'topic') return aTopic();
      return aOverview();
    }
    if (variant === 'B') {
      if (page === 'drives') return bDrives();
      if (page === 'charging') return bCharging();
      if (page === 'stats') return bStats();
      if (page === 'driveDetail') return bDriveDetail();
      if (page === 'chargeDetail') return bChargeDetail();
      if (page === 'topic') return bTopic();
      return bOverview();
    }
    if (page === 'drives') return cDrives();
    if (page === 'charging') return cCharging();
    if (page === 'stats') return cStats();
    if (page === 'driveDetail') return cDriveDetail();
    if (page === 'chargeDetail') return cChargeDetail();
    if (page === 'topic') return cTopic();
    return cOverview();
  }

  function pageTab(page) {
    if (page === 'driveDetail') return 'drives';
    if (page === 'chargeDetail') return 'charging';
    if (page === 'topic') return 'stats';
    return page;
  }

  function phone(variant, page = state.page) {
    const noNav = ['driveDetail', 'chargeDetail', 'topic'].includes(page);
    const theme = state.theme;
    const scale = state.scale === '200' ? 'large' : '';
    return `<div class="device-wrap">
      <div class="device-label"><span>${variant} · ${VARIANTS[variant].name} / ${PAGE_NAMES[page]}</span><span>360 × 800 · ${theme === 'light' ? '浅色' : '深色'}</span></div>
      <article class="phone ${variant.toLowerCase()} theme-${theme} ${scale} ${noNav ? 'no-nav' : ''}" data-variant="${variant}">
        <div class="statusbar"><span>18:40</span><span class="signal"><i></i><i></i><i></i></span><span class="battery"></span></div>
        <div class="screen">${pageContent(variant, page)}</div>
        ${noNav ? '' : nav(variant, pageTab(page))}
        ${sheetHtml()}
      </article>
    </div>`;
  }

  function notes() {
    const v = VARIANTS[state.variant];
    const page = PAGE_NAMES[state.page];
    return `<aside class="notes">
      <p class="note-kicker">Read this page</p>
      <h2>${v.caption}。</h2>
      <p>${v.intro}</p>
      <div class="note-chip"><i></i>${state.variant} · ${v.name} · ${page}</div>
      <hr>
      <h3>这一版的主次</h3>
      <ul>${v.points.map((point) => `<li>${point}</li>`).join('')}</ul>
      <h3>评审时看</h3>
      <p>${state.sample === 'empty' ? '空数据下是否仍能看懂页面职责；是否会画出全零趋势。' : state.sample === 'missing' ? '部分缺失时哪些数变“—”，哪些图断开；主结果是否仍成立。' : '五秒内能否说出车况；三十秒内能否说出本月里程与变化；视线最后落在哪里。'}</p>
      <hr>
      <h3>当前状态</h3>
      <pre>${JSON.stringify({ variant: state.variant, page: state.page, theme: state.theme, scale: state.scale, sample: state.sample, period: state.period, metric: state.metric }, null, 2)}</pre>
      <hr>
      <h3>边界</h3>
      <p>固定合成数据；不是正式 Flutter、真实站点、地图或真机证据。所有数值与图形只用于评审层级。</p>
    </aside>`;
  }

  function sidebar() {
    return `<aside class="sidebar">
      <div class="sidebar-brand">${icon('leaf')}行笺 · 设计室</div>
      <p class="eyebrow">Visual refresh / Study 02</p>
      <h1 class="sidebar-h1">让每一页，<br>只有一个主角。</h1>
      <p class="sidebar-copy">不是加更多卡，而是把“现在、这个月、哪次、为什么”排成一条可读的线。三套结构均使用同一组固定合成数据。</p>
      <div class="variant-list">${['A', 'B', 'C']
        .map(
          (key) => `<button class="variant-button ${state.variant === key ? 'active' : ''}" data-action="variant" data-value="${key}"><span class="variant-letter">${key}</span><span><strong>${VARIANTS[key].name}${key === 'A' ? ' · 推荐' : ''}</strong><small>${VARIANTS[key].caption}</small></span></button>`,
        )
        .join('')}</div>
      <div class="controls">
        <div class="control"><label for="theme">外观</label><select id="theme" data-control="theme"><option value="light" ${state.theme === 'light' ? 'selected' : ''}>湖畔 · 浅色</option><option value="dark" ${state.theme === 'dark' ? 'selected' : ''}>湖畔 · 深色</option></select></div>
        ${state.variant === 'A' ? `<div class="control"><label for="sample">数据状态</label><select id="sample" data-control="sample"><option value="normal" ${state.sample === 'normal' ? 'selected' : ''}>正常样例</option><option value="missing" ${state.sample === 'missing' ? 'selected' : ''}>部分缺失（概览净电耗）</option><option value="empty" ${state.sample === 'empty' ? 'selected' : ''}>空数据</option></select></div>` : `<div class="control"><label>数据状态</label><p class="control-note">B / C 固定正常样例；状态矩阵在 A 概览演示。</p></div>`}
        <div class="control"><label for="scale">字号</label><select id="scale" data-control="scale"><option value="100" ${state.scale === '100' ? 'selected' : ''}>100%</option><option value="200" ${state.scale === '200' ? 'selected' : ''}>200% 排版检查</option></select></div>
        <div class="page-jumps">${[
          ['overview', '概览'],
          ['drives', '行程'],
          ['charging', '充电'],
          ['stats', '统计'],
          ['driveDetail', '行程详情'],
          ['chargeDetail', '充电详情'],
        ]
          .map(([page, label]) => `<button class="${state.page === page ? 'active' : ''}" data-action="page" data-value="${page}">${label}</button>`)
          .join('')}</div>
      </div>
      <div class="sidebar-footer">固定合成样例 · 2026-10-26 18:40<br>不连接站点 / 不写数据 / 不引入外部资源<br><a href="?variant=${state.variant}&compare=1">三套方向并排 ↗</a><a href="?variant=${state.variant}&page=${state.page}&full=1">完整长页 ↗</a><a href="?variant=${state.variant}&page=${state.page}&capture=1">360×800 首屏 ↗</a></div>
    </aside>`;
  }

  function stage() {
    const compare = state.compare;
    const v = VARIANTS[state.variant];
    return `<section class="stage">
      <header class="stage-head"><div><p class="eyebrow">Mileaf / Visual refresh / 2026.10</p><h1>${compare ? '三套方向，同一组车主问题。' : `${v.name}：${v.caption}。`}</h1><p>${compare ? '并排比较车况、月度主数、证据图、记录与专题的层级；不是三套换色，而是三种阅读顺序。' : '固定合成样例 · 同一组数据 · 仅视觉与信息层级评审，尚未修改 Flutter 页面。'}</p></div><span class="stage-tag">${compare ? '并排评审' : '待确认方向'}</span></header>
      <div class="stage-body">${compare ? ['A', 'B', 'C'].map((key) => phone(key, state.page)).join('') : `${phone(state.variant)}${notes()}`}</div>
    </section>`;
  }

  function sheetHtml() {
    if (!state.sheet) return '';
    const content = {
      comparison: `<h2>比较口径</h2><p>本期与参照使用同一车辆、同一 IANA 归期时区、同长日历窗口及当地截止时刻。月份按“截至 26 日 18:40”对齐，不拿未满月对完整月。</p><p>净电耗为续航差与车辆效率的估算；差异只描述方向，不评价驾驶好坏。基期为零、字段缺失或样本不足时不输出百分比。</p>`,
      data: `<h2>数据说明</h2><p>原型固定时钟：2026-10-26 18:40 Asia/Shanghai。车况为最近采样，不是实时车辆状态。本月样本：1,198.6 km / 46 趟 / 净电耗 158 Wh/km / 充入 234.7 kWh / 9 次 / 已知费用 ¥186.4（8/9 次有记录）。</p><p>正式 App 的总计与比率直接取服务端结果；不从列表分页加总，不平均桶比率。缺失值保留为“—”，真实 0 正常显示。</p>`,
      menu: `<h2>服务与设置</h2><p>正式 App 的车辆切换、刷新、设置与退出仍按现有会话边界。此原型只演示入口位置，不连接真实站点，也不修改任何配置。</p>`,
      vehicle: `<h2>车辆</h2><p>${DATA.vehicle.name} · ${DATA.vehicle.model} · VIN ${DATA.vehicle.vin}。正式界面不会展示完整 VIN，只保留后四位用于区分车辆。</p>`,
      period: `<h2>日期</h2><p>原型固定展示 2026 年 10 月。正式 App 的周/月/年/自定义区间仍由现有日历组件选择，并传入 IANA 时区与 UTC 半开区间；切车或换区间会重置分页游标。</p>`,
      records: `<h2>全部记录</h2><p>原型用固定记录演示列表入口。正式页面保留日期筛选、分类/地点筛选、游标分页、进行中与缺失状态；“全部”指完整查询集合，不是已经加载到手机上的这一页。</p><div class="sheet-list">${SESSIONS.slice(0, 5)
        .map(
          (s) =>
            `<div class="sheet-row"><span><b>${s.date} · ${s.place}</b><small>${fmt(s.energy, 1)} kWh · ${s.startSoc}% → ${s.endSoc}% · ${s.duration} 分钟</small></span><span>${s.cost == null ? '未记录' : money(s.cost)}</span></div>`,
        )
        .join('')}</div>`,
    }[state.sheet] || `<h2>说明</h2><p>这是一个一次性设计原型。</p>`;
    return `<div class="sheet-cover" data-action="close-sheet"><section class="sheet" role="dialog" aria-modal="true" data-action="noop"><button class="sheet-close" data-action="close-sheet" aria-label="关闭">${icon('close')}</button>${content}<p class="sheet-foot">固定合成样例 · 仅设计评审</p></section></div>`;
  }

  function render(preserveScroll = false) {
    const scrolls = preserveScroll ? Array.from(document.querySelectorAll('.screen')).map((node) => node.scrollTop) : [];
    document.body.className = `${state.compare ? 'compare' : ''} ${state.full ? 'full' : ''} ${state.capture ? 'capture' : ''} ${state.scale === '200' ? 'large' : ''}`.trim();
    document.getElementById('app').innerHTML = `<div class="studio">${sidebar()}${stage()}</div><div class="switcher"><button data-action="cycle" data-value="-1" aria-label="上一个方向">←</button><span>${state.variant} · ${VARIANTS[state.variant].name} / ${PAGE_NAMES[state.page]}</span><button data-action="cycle" data-value="1" aria-label="下一个方向">→</button></div>`;
    if (preserveScroll) {
      document.querySelectorAll('.screen').forEach((node, index) => {
        node.scrollTop = scrolls[index] ?? 0;
      });
    }
  }

  function syncUrl() {
    const url = new URL(location.href);
    for (const key of ['variant', 'page', 'theme', 'scale', 'sample', 'period', 'metric', 'compare', 'full', 'capture']) {
      if (state[key] === false || state[key] == null) url.searchParams.delete(key);
      else url.searchParams.set(key, state[key]);
    }
    history.replaceState(null, '', url);
  }

  function cycle(delta) {
    const keys = ['A', 'B', 'C'];
    state.variant = keys[(keys.indexOf(state.variant) + delta + keys.length) % keys.length];
    if (state.variant !== 'A') state.sample = 'normal';
    state.page = 'overview';
    state.sheet = null;
    syncUrl();
    render();
  }

  function setPage(page) {
    state.page = page;
    state.sheet = null;
    syncUrl();
    render();
  }

  document.addEventListener('click', (event) => {
    const target = event.target.closest('[data-action]');
    if (!target) return;
    const { action, value } = target.dataset;
    if (action === 'noop') return;
    if (action === 'close-sheet') {
      if (event.target.closest('.sheet') && !event.target.closest('.sheet-close')) return;
      state.sheet = null;
      syncUrl();
      render(true);
      return;
    }
    if (action === 'cycle') {
      cycle(Number(value));
      return;
    }
    if (action === 'variant') {
      state.variant = value;
      if (state.variant !== 'A') state.sample = 'normal';
      state.page = 'overview';
      state.sheet = null;
    }
    if (action === 'page') {
      setPage(value);
      return;
    }
    if (action === 'period') {
      state.period = value;
      delete state.points.overview;
      delete state.points['c-overview'];
      delete state.points.stats;
      delete state.points['c-stats'];
    }
    if (action === 'metric') {
      state.metric = value;
      delete state.points.overview;
      delete state.points['c-overview'];
    }
    if (action === 'chargeMetric') {
      state.chargeMetric = value;
      delete state.points.charge;
    }
    if (action === 'detailMetric') {
      state.detailMetric = value;
      delete state.points['drive-detail'];
    }
    if (action === 'chargeDetailMetric') {
      state.chargeDetailMetric = value;
      delete state.points['charge-detail'];
    }
    if (action === 'topic') {
      state.topic = value;
      state.page = 'topic';
      state.sheet = null;
    }
    if (action === 'openDrive') {
      state.page = 'driveDetail';
      state.sheet = null;
    }
    if (action === 'openCharge') {
      state.page = 'chargeDetail';
      state.sheet = null;
    }
    if (action === 'sheet') {
      state.sheet = value;
    }
    if (action === 'point') {
      const [key, index] = value.split(':');
      state.points[key] = Number(index);
      syncUrl();
      render(true);
      return;
    }
    if (action === 'step') {
      const [key, delta, count] = value.split(':');
      const current = state.points[key] ?? Number(count) - 1;
      state.points[key] = Math.max(0, Math.min(Number(count) - 1, current + Number(delta)));
      syncUrl();
      render(true);
      return;
    }
    syncUrl();
    render(['variant', 'page', 'topic', 'openDrive', 'openCharge'].includes(action) ? false : true);
  });

  document.addEventListener('change', (event) => {
    const control = event.target.dataset.control;
    if (!control) return;
    state[control] = event.target.value;
    state.sheet = null;
    syncUrl();
    render();
  });

  document.addEventListener('keydown', (event) => {
    if (['INPUT', 'TEXTAREA', 'SELECT'].includes(event.target.tagName) || event.target.isContentEditable) return;
    if (event.key === 'Escape' && state.sheet) {
      state.sheet = null;
      syncUrl();
      render(true);
      return;
    }
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      event.preventDefault();
      cycle(event.key === 'ArrowLeft' ? -1 : 1);
    }
  });

  function initFromUrl() {
    const params = new URLSearchParams(location.search);
    const allowed = (key, values, fallback) => (values.includes(params.get(key)) ? params.get(key) : fallback);
    state.variant = allowed('variant', ['A', 'B', 'C'], 'A');
    state.page = allowed('page', ['overview', 'drives', 'charging', 'stats', 'driveDetail', 'chargeDetail', 'topic'], 'overview');
    state.theme = allowed('theme', ['light', 'dark'], 'light');
    state.scale = allowed('scale', ['100', '200'], '100');
    state.sample = allowed('sample', ['normal', 'missing', 'empty'], 'normal');
    if (state.variant !== 'A') state.sample = 'normal';
    state.period = allowed('period', ['m', 'w'], 'm');
    state.metric = allowed('metric', ['distance', 'net', 'charge', 'cost'], 'distance');
    state.compare = params.get('compare') === '1';
    state.full = params.get('full') === '1';
    state.capture = params.get('capture') === '1';
    if (params.get('topic')) state.topic = allowed('topic', ['rhythm', 'energy', 'charging', 'long'], 'rhythm');
  }

  initFromUrl();
  render();
})();
