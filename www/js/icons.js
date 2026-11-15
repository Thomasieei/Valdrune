/* UMBRA — icônes vectorielles (interface, reliques, accessoires, ombres) */
import { RAR } from './data.js';

let uid = 0;
const grad = (c1, c2) => { const id = 'g' + (++uid); return [id, `<defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${c1}"/><stop offset="1" stop-color="${c2}"/></linearGradient></defs>`]; };
const S = (body, vb = 24) => `<svg viewBox="0 0 ${vb} ${vb}">${body}</svg>`;

/* ---------- interface ---------- */
export const UIC = {
  inv: () => { const [g, d] = grad('#fcd34d', '#b45309'); return S(`${d}<path d="M7 7V5a5 5 0 0110 0v2h3l1 14H3L4 7zm2 0h6V5a3 3 0 00-6 0z" fill="url(#${g})" stroke="#3b1d00" stroke-width="1"/><rect x="9" y="11" width="6" height="4" rx="1" fill="#7c2d12"/>`); },
  ombres: () => S(`<path d="M12 2C7 2 4 6 4 10c0 3 1.5 4.5 2 6v3h3v-2h2v2h2v-2h2v2h3v-3c.5-1.5 2-3 2-6 0-4-3-8-8-8z" fill="#f1f5f9" stroke="#1e1b4b" stroke-width="1"/><circle cx="9" cy="11" r="2.2" fill="#ef4444"/><circle cx="15" cy="11" r="2.2" fill="#ef4444"/>`),
  mondes: () => { const [g, d] = grad('#7dd3fc', '#1d4ed8'); return S(`${d}<circle cx="12" cy="12" r="10" fill="url(#${g})" stroke="#0c1240" stroke-width="1"/><path d="M5 8c3 1 4 4 7 3s2-5 5-4M4 14c3-1 5 1 7 3m3 3c0-3 2-5 6-5" fill="none" stroke="#4ade80" stroke-width="2.4" stroke-linecap="round"/>`); },
  autel: () => { const [g, d] = grad('#f0abfc', '#7e22ce'); return S(`${d}<path d="M12 1l3 7h7l-5.5 4.5 2 7.5L12 15.5 5.5 20l2-7.5L2 8h7z" fill="url(#${g})" stroke="#3b0764" stroke-width="1"/>`); },
  quetes: () => S(`<path d="M6 2h11l3 3v17H6a3 3 0 01-3-3V5a3 3 0 013-3z" fill="#fde68a" stroke="#78350f" stroke-width="1"/><path d="M7 8h9M7 12h9M7 16h6" stroke="#92400e" stroke-width="1.8"/><circle cx="19" cy="19" r="4" fill="#ef4444" stroke="#fff" stroke-width="1"/><path d="M19 17v2.5" stroke="#fff" stroke-width="1.6"/>`),
  succes: () => { const [g, d] = grad('#fde047', '#ca8a04'); return S(`${d}<path d="M6 3h12v4a6 6 0 01-12 0zM3 4h3v3a3 3 0 01-3-3zM21 4h-3v3a3 3 0 003-3zM10 13h4v4h3v3H7v-3h3z" fill="url(#${g})" stroke="#713f12" stroke-width="1"/>`); },
  stats: () => S(`<rect x="3" y="12" width="4" height="9" fill="#4ade80" stroke="#052e16"/><rect x="10" y="7" width="4" height="14" fill="#38bdf8" stroke="#082f49"/><rect x="17" y="3" width="4" height="18" fill="#f472b6" stroke="#500724"/>`),
  reglages: () => S(`<path d="M19.4 13a7.6 7.6 0 000-2l2.1-1.6-2-3.5-2.5 1a7.4 7.4 0 00-1.7-1L15 3h-4l-.4 2.9a7.4 7.4 0 00-1.7 1l-2.5-1-2 3.5L6.6 11a7.6 7.6 0 000 2l-2.1 1.6 2 3.5 2.5-1c.5.4 1.1.7 1.7 1L11 21h4l.4-2.9c.6-.3 1.2-.6 1.7-1l2.5 1 2-3.5zM13 15a3 3 0 110-6 3 3 0 010 6z" fill="#cbd5e1" stroke="#1e293b" stroke-width="1"/>`),
  cash: () => S(`<rect x="1" y="6" width="22" height="13" rx="2" fill="#22c55e" stroke="#052e16" stroke-width="1.2"/><rect x="3" y="4" width="22" height="13" rx="2" fill="#4ade80" stroke="#052e16" stroke-width="1.2" transform="translate(-2 0)"/><circle cx="12" cy="10.5" r="3.5" fill="#86efac" stroke="#14532d"/><text x="12" y="12.7" text-anchor="middle" font-size="6" font-weight="900" fill="#14532d">$</text>`),
  gem: () => S(`<path d="M6 3h12l4 6-10 13L2 9z" fill="#7dd3fc" stroke="#0c4a6e" stroke-width="1.3"/><path d="M2 9h20M9 3l3 6 3-6M12 9v13" stroke="#e0f2fe" stroke-width=".9" fill="none"/>`),
  fist: () => S(`<path d="M7 9V6a2 2 0 014 0v2-3a2 2 0 014 0v3-2a2 2 0 014 0v8c0 4-3 7-7 7s-7-3-7-6v-3a2 2 0 013-1z" fill="#fca5a5" stroke="#450a0a" stroke-width="1.2"/>`),
  arise: () => S(`<path d="M12 2c3 4 7 7 7 12a7 7 0 01-14 0c0-3 2-5 3-6 0 2 1 3 2 3 0-4 1-7 2-9z" fill="#e879f9" stroke="#4a044e" stroke-width="1.2"/><path d="M12 12c1.5 2 3 3 3 5a3 3 0 01-6 0c0-1.5 1.5-3 3-5z" fill="#fff"/>`),
  auto: () => S(`<path d="M12 4V1L8 5l4 4V6a6 6 0 11-6 6H4a8 8 0 108-8z" fill="#86efac" stroke="#052e16" stroke-width=".8"/><path d="M10 9l5 3-5 3z" fill="#fff"/>`),
  army: () => S(`<g fill="#c4b5fd" stroke="#1e1b4b" stroke-width=".8"><circle cx="6" cy="8" r="3"/><circle cx="18" cy="8" r="3"/><circle cx="12" cy="6" r="3.5"/><path d="M1 20c0-4 2-7 5-7s5 3 5 7zM13 20c0-4 2-7 5-7s5 3 5 7z"/><path d="M6 21c0-5 3-8 6-8s6 3 6 8z" fill="#e9d5ff"/></g>`),
  sword: () => S(`<path d="M20 2l-9 9-2-2-2 2 2 2-5 5 2 2 5-5 2 2 2-2-2-2 9-9V2z" fill="#e2e8f0" stroke="#1e293b" stroke-width="1"/>`),
  skull: () => S(`<path d="M12 2C7 2 4 6 4 10c0 3 1.5 4.5 2 6v3h12v-3c.5-1.5 2-3 2-6 0-4-3-8-8-8z" fill="#fecdd3" stroke="#4c0519"/><circle cx="9" cy="11" r="2.3" fill="#4c0519"/><circle cx="15" cy="11" r="2.3" fill="#4c0519"/>`),
};

/* ---------- reliques ---------- */
const RELIC_SHAPES = {
  coin: (g) => `<circle cx="12" cy="12" r="9" fill="url(#${g})" stroke="#000" stroke-width="1.2"/><circle cx="12" cy="12" r="6" fill="none" stroke="#fff" stroke-opacity=".6"/><text x="12" y="16" text-anchor="middle" font-size="11" font-weight="900" fill="#fff" fill-opacity=".9" stroke="#000" stroke-width=".6">$</text>`,
  fang: (g) => `<path d="M6 3c6 0 12 3 12 9 0 4-3 8-5 10 0-5-1-8-4-10-2-1-3-5-3-9z" fill="url(#${g})" stroke="#000" stroke-width="1.2"/><path d="M9 6c3 1 5 3 6 6" stroke="#fff" stroke-opacity=".6" fill="none"/>`,
  feather: (g) => `<path d="M19 2C9 4 5 11 5 19l-2 3 1 .5 2-3C14 19 20 12 19 2z" fill="url(#${g})" stroke="#000" stroke-width="1.2"/><path d="M6 19C10 13 14 8 18 4" stroke="#fff" stroke-opacity=".7" fill="none"/>`,
  hourglass: (g) => `<path d="M5 2h14v2c0 4-4 6-4 8s4 4 4 8v2H5v-2c0-4 4-6 4-8S5 8 5 4z" fill="url(#${g})" stroke="#000" stroke-width="1.2"/><path d="M8 19h8l-4-4z" fill="#fff" fill-opacity=".8"/><path d="M14 6l-3 4" stroke="#000" stroke-width="1.5"/>`,
  heart: (g) => `<path d="M12 21C5 15 2 12 2 8a5 5 0 0110-1 5 5 0 0110 1c0 4-3 7-10 13z" fill="url(#${g})" stroke="#000" stroke-width="1.2"/><path d="M12 7c-1 2-3 3-2 6 1-1 2-1 2 2 1-2 3-3 2-6" fill="#fff7" />`,
  tear: (g) => `<path d="M12 2c4 6 7 9 7 13a7 7 0 01-14 0c0-4 3-7 7-13z" fill="url(#${g})" stroke="#000" stroke-width="1.2"/><path d="M9 14a3 3 0 003 3" stroke="#fff" stroke-width="1.6" fill="none"/>`,
  eye: (g) => `<path d="M1 12c4-6 18-6 22 0-4 6-18 6-22 0z" fill="#0b0620" stroke="#000" stroke-width="1.2"/><circle cx="12" cy="12" r="5" fill="url(#${g})"/><ellipse cx="12" cy="12" rx="1.5" ry="4" fill="#000"/><circle cx="10" cy="10" r="1" fill="#fff"/>`,
  crown: (g) => `<path d="M2 8l5 4 5-8 5 8 5-4-2 12H4z" fill="url(#${g})" stroke="#000" stroke-width="1.2"/><circle cx="12" cy="15" r="2" fill="#fff" fill-opacity=".85"/><path d="M5 18h14" stroke="#000" stroke-opacity=".5"/>`,
  seal: (g) => `<path d="M12 1l3 3h5v5l3 3-3 3v5h-5l-3 3-3-3H4v-5l-3-3 3-3V4h5z" fill="url(#${g})" stroke="#000" stroke-width="1.2"/><circle cx="12" cy="12" r="5" fill="#0b0620" stroke="#fff" stroke-opacity=".6"/><path d="M12 8v8M8 12h8" stroke="#fff" stroke-opacity=".8"/>`,
  star: (g) => `<path d="M12 1l3 8h8l-6.5 5 2.5 8-7-5-7 5 2.5-8L1 9h8z" fill="url(#${g})" stroke="#000" stroke-width="1.2"/><circle cx="12" cy="12" r="3" fill="#000"/><circle cx="12" cy="12" r="1.3" fill="#fff"/>`,
};
export function relicIcon(rel, cls = 'ic') {
  const R = RAR[rel.r]; const [g, d] = grad('#fff', R.c);
  return `<svg class="${cls}" viewBox="0 0 24 24">${d.replace('stop-color="#fff"', `stop-color="${lighten(R.c)}"`)}${RELIC_SHAPES[rel.ic](g)}</svg>`;
}
function lighten(hex) { const n = parseInt(hex.slice(1), 16); const f = v => Math.min(255, v + 110); return `rgb(${f(n >> 16)},${f((n >> 8) & 255)},${f(n & 255)})`; }

/* ---------- accessoires ---------- */
const ACC_SHAPES = {
  a1: g => `<path d="M12 2C6 2 3 7 3 13v8h4v-6c0-3 2-5 5-5s5 2 5 5v6h4v-8c0-6-3-11-9-11z" fill="url(#${g})" stroke="#000" stroke-width="1.2"/><path d="M8 15c1-2 7-2 8 0" stroke="#000" fill="none"/>`,
  a2: g => `<path d="M4 12C4 6 8 2 12 2s8 4 8 10v8H4z" fill="url(#${g})" stroke="#000" stroke-width="1.2"/><path d="M7 11h10v3H7z" fill="#0b0620"/><path d="M12 2v8" stroke="#fff" stroke-opacity=".6" stroke-width="1.6"/><path d="M12 0l2 3h-4z" fill="#ff3b5c"/>`,
  a3: g => `<path d="M2 9l5 4 5-9 5 9 5-4-2 11H4z" fill="url(#${g})" stroke="#000" stroke-width="1.2"/><circle cx="12" cy="15" r="2.5" fill="#ff3b5c" stroke="#000"/><circle cx="6" cy="16" r="1.3" fill="#38bdf8"/><circle cx="18" cy="16" r="1.3" fill="#38bdf8"/>`,
  a4: g => `<path d="M7 2h10l3 20-4-2-2 2-2-2-2 2-2-2-4 2z" fill="url(#${g})" stroke="#000" stroke-width="1.2"/><path d="M7 2c2 3 8 3 10 0" stroke="#000" fill="none"/>`,
  a5: g => `<path d="M6 2h12l4 20c-3-2-5-1-6 0-2-2-6-2-8 0-1-1-3-2-6 0z" fill="url(#${g})" stroke="#000" stroke-width="1.2"/><path d="M6 2c3 4 9 4 12 0" stroke="#fde68a" stroke-width="1.5" fill="none"/><circle cx="12" cy="5" r="1.5" fill="#fde68a"/>`,
  a6: g => `<path d="M7 2l5 3 5-3 4 4-2 4v12H5V10L3 6z" fill="url(#${g})" stroke="#000" stroke-width="1.2"/><path d="M9 12h6M9 16h6" stroke="#000" stroke-opacity=".5"/>`,
  a7: g => `<path d="M7 2l5 3 5-3 4 4-2 4v12H5V10L3 6z" fill="url(#${g})" stroke="#000" stroke-width="1.2"/><path d="M8 9h8M8 12h8M8 15h8M8 18h8M12 6v15" stroke="#fff" stroke-opacity=".75" stroke-width="1.2"/>`,
  a8: g => `<path d="M6 2l6 4 6-4 5 5-3 4v11H4V11L1 7z" fill="url(#${g})" stroke="#000" stroke-width="1.2"/><path d="M12 8l3 4-3 5-3-5z" fill="#0b0620" stroke="#ff7aa8"/><path d="M1 7l4 2M23 7l-4 2" stroke="#fff" stroke-opacity=".6"/>`,
  a9: g => `<path d="M6 2h6v12l8 3v5H4V14z" fill="url(#${g})" stroke="#000" stroke-width="1.2"/><path d="M4 19h16" stroke="#000" stroke-opacity=".5"/><path d="M6 8h6" stroke="#000" stroke-opacity=".4"/>`,
  a10: g => `<path d="M5 2h7v11l9 4v5H3V13z" fill="url(#${g})" stroke="#000" stroke-width="1.2"/><path d="M14 5l7-3-3 5 4 1-6 3" fill="#c26bff" fill-opacity=".85"/><path d="M3 19h18" stroke="#fff" stroke-opacity=".6"/>`,
};
export function accIcon(a, cls = 'ic') { const R = RAR[a.r]; const [g, d] = grad(lighten(R.c), R.c2); return `<svg class="${cls}" viewBox="0 0 24 24">${d}${ACC_SHAPES[a.id](g)}</svg>`; }

/* ---------- ombres (silhouettes) ---------- */
export function shadowIcon(model, col, cls = 'ic') {
  const [g, d] = grad('#1e1b4b', '#05030f');
  let body;
  if (/wolf|fox/.test(model)) body = `<path d="M3 15l2-6 3 1 2-4 1 4h6l4 2 2 4-3 1v4h-2v-3h-7v3H9v-3l-4-1z" fill="url(#${g})" stroke="${col}" stroke-width="1"/><circle cx="7" cy="12" r="1" fill="${col}"/>`;
  else if (/stag|bull/.test(model)) body = `<path d="M4 9L2 4l3 2 1-3 1 4 3 1h8l3 3v5l-2 1v4h-2v-4h-8v4H8v-5l-3-2z" fill="url(#${g})" stroke="${col}" stroke-width="1"/><circle cx="6" cy="10" r="1" fill="${col}"/>`;
  else if (model === 'dragon') body = `<path d="M12 6c2 0 3 2 3 4l7-6-2 9-5 1 2 6h-2l-3-4-3 4H7l2-6-5-1-2-9 7 6c0-2 1-4 3-4z" fill="url(#${g})" stroke="${col}" stroke-width="1"/><circle cx="11" cy="9" r=".9" fill="${col}"/><circle cx="13" cy="9" r=".9" fill="${col}"/>`;
  else body = `<path d="M12 1c-4 0-6 3-6 7 0 2 1 3 1 4l-4 3 1 8h16l1-8-4-3c0-1 1-2 1-4 0-4-2-7-6-7z" fill="url(#${g})" stroke="${col}" stroke-width="1"/><path d="M9 8l2 1M15 8l-2 1" stroke="${col}" stroke-width="1.8" stroke-linecap="round"/>`;
  return `<svg class="${cls}" viewBox="0 0 24 24">${d}${body}</svg>`;
}
