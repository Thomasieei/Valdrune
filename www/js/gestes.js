// Sorts par signes : le joueur dessine un symbole directement sur l'écran (sur l'ennemi visé) et le sort part.
// Reconnaissance maison (rééchantillonnage + comparaison à des modèles), traînée lumineuse, éclat du symbole réussi.

// symbole de chaque emplacement de sort (coordonnées 0..100, y vers le bas)
export const GLYPHES = {
  Q: { nom: 'Trait', d: 'M12 50 L88 50' },
  W: { nom: 'V', d: 'M16 20 L50 82 L84 20' },
  E: { nom: 'Cercle', d: 'M50 14 A36 36 0 1 1 49.9 14' },
  R: { nom: 'Pic', d: 'M16 82 L50 18 L84 82' },
  D: { nom: 'Éclair', d: 'M16 20 L84 20 L16 80 L84 80' },
  F: { nom: 'Pilier', d: 'M50 10 L50 90' },
};
const MODELES = { W: [[0, 0], [0.5, 1], [1, 0]], R: [[0, 1], [0.5, 0], [1, 1]], D: [[0, 0], [1, 0], [0, 1], [1, 1]] };

const N = 32;
const longueur = (p) => { let l = 0; for (let i = 1; i < p.length; i++) l += Math.hypot(p[i][0] - p[i - 1][0], p[i][1] - p[i - 1][1]); return l; };
function reechantillonner(pts, n = N) {
  const I = longueur(pts) / (n - 1); if (!I) return null;
  const out = [pts[0].slice()]; let D = 0; const p = pts.map(x => x.slice());
  for (let i = 1; i < p.length; i++) {
    const d = Math.hypot(p[i][0] - p[i - 1][0], p[i][1] - p[i - 1][1]);
    if (D + d >= I && d > 0) {
      const t = (I - D) / d; const q = [p[i - 1][0] + t * (p[i][0] - p[i - 1][0]), p[i - 1][1] + t * (p[i][1] - p[i - 1][1])];
      out.push(q); p.splice(i, 0, q); D = 0;
    } else D += d;
  }
  while (out.length < n) out.push(p[p.length - 1].slice());
  return out.slice(0, n);
}
function normaliser(p) {
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const [x, y] of p) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  const s = Math.max(x1 - x0, y1 - y0) || 1, cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
  return p.map(([x, y]) => [(x - cx) / s, (y - cy) / s]);
}
const MODELES_N = Object.fromEntries(Object.entries(MODELES).map(([k, poly]) => [k, normaliser(reechantillonner(poly.map(([x, y]) => [x * 100, y * 100])))]));
const ecart = (a, b) => { let s = 0; for (let i = 0; i < N; i++) s += Math.hypot(a[i][0] - b[i][0], a[i][1] - b[i][1]); return s / N; };

// renvoie { cle, score } ou null
export function reconnaitre(brut) {
  if (brut.length < 4) return null;
  let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
  for (const [x, y] of brut) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  const w = x1 - x0, h = y1 - y0, taille = Math.max(w, h);
  if (taille < 45) return null;
  const L = longueur(brut);
  const debFin = Math.hypot(brut[0][0] - brut[brut.length - 1][0], brut[0][1] - brut[brut.length - 1][1]);
  // cercle : tracé refermé, à peu près aussi large que haut, assez long
  if (debFin < taille * 0.38 && L > taille * 2.3 && Math.min(w, h) > taille * 0.55) return { cle: 'E', score: 0.9 };
  // traits droits
  if (h < w * 0.3 && L < w * 1.35) return { cle: 'Q', score: 0.9 };
  if (w < h * 0.3 && L < h * 1.35) return { cle: 'F', score: 0.9 };
  const p = reechantillonner(brut); if (!p) return null;
  const n = normaliser(p), inv = normaliser(p.slice().reverse());
  let best = null, bd = Infinity;
  for (const [k, m] of Object.entries(MODELES_N)) { const d = Math.min(ecart(n, m), ecart(inv, m)); if (d < bd) { bd = d; best = k; } }
  if (bd > 0.2) return null;
  return { cle: best, score: 1 - bd };
}

// ---------------- Interface : traînée, éclat du symbole ----------------
export function initGestes(scene, api) {
  const cv = document.createElement('canvas'); cv.id = 'gesteCv';
  document.getElementById('jeu').appendChild(cv);
  const g = cv.getContext('2d');
  const taille = () => { cv.width = innerWidth * Math.min(2, devicePixelRatio || 1); cv.height = innerHeight * Math.min(2, devicePixelRatio || 1); cv.style.width = innerWidth + 'px'; cv.style.height = innerHeight + 'px'; };
  taille(); addEventListener('resize', taille);
  let trace = null; const traines = [];
  let anim = false;
  const dessiner = () => {
    const k = cv.width / innerWidth; g.setTransform(k, 0, 0, k, 0, 0); g.clearRect(0, 0, innerWidth, innerHeight);
    const now = performance.now();
    for (let i = traines.length - 1; i >= 0; i--) {
      const t = traines[i]; const age = t.fin ? (now - t.fin) / 450 : 0;
      if (age >= 1) { traines.splice(i, 1); continue; }
      const p = t.pts; if (p.length < 2) continue;
      g.lineCap = 'round'; g.lineJoin = 'round';
      g.globalAlpha = (1 - age) * 0.9;
      g.strokeStyle = t.rate ? '#6a6a6a' : t.couleur; g.shadowColor = t.rate ? '#000' : t.couleur; g.shadowBlur = 22; g.lineWidth = 14;
      g.beginPath(); g.moveTo(p[0][0], p[0][1]); for (let j = 1; j < p.length; j++) g.lineTo(p[j][0], p[j][1]); g.stroke();
      g.shadowBlur = 0; g.strokeStyle = '#ffffff'; g.lineWidth = 4.5; g.stroke();
      // étincelles au bout du trait
      if (!t.fin) { const [x, y] = p[p.length - 1]; g.fillStyle = '#fff'; g.beginPath(); g.arc(x, y, 7, 0, 7); g.fill(); }
    }
    g.globalAlpha = 1;
    if (traines.length || trace) requestAnimationFrame(dessiner); else anim = false;
  };
  const relancer = () => { if (!anim) { anim = true; requestAnimationFrame(dessiner); } };

  scene.addEventListener('pointerdown', (e) => {
    if (!api.actif() || trace) { api.tap(e); return; }
    trace = { id: e.pointerId, pts: [[e.clientX, e.clientY]], couleur: api.couleur(), e0: e, t0: performance.now() };
    traines.push(trace); relancer();
    try { scene.setPointerCapture(e.pointerId); } catch (er) {}
  });
  scene.addEventListener('pointermove', (e) => {
    if (!trace || e.pointerId !== trace.id) return;
    const l = trace.pts[trace.pts.length - 1];
    if (Math.hypot(e.clientX - l[0], e.clientY - l[1]) > 3) trace.pts.push([e.clientX, e.clientY]);
  });
  const fin = (e) => {
    if (!trace || e.pointerId !== trace.id) return;
    const t = trace; trace = null; t.fin = performance.now();
    if (longueur(t.pts) < 30) { traines.splice(traines.indexOf(t), 1); api.tap(t.e0); return; } // simple toucher : ciblage
    const r = reconnaitre(t.pts);
    let cx = 0, cy = 0; for (const [x, y] of t.pts) { cx += x; cy += y; } cx /= t.pts.length; cy /= t.pts.length;
    if (!r) { t.rate = true; api.rate(cx, cy); return; }
    const ok = api.lancer(r.cle, t.pts[0], [cx, cy]);
    if (ok) eclat(r.cle, cx, cy, t.couleur); else t.rate = true;
  };
  scene.addEventListener('pointerup', fin); scene.addEventListener('pointercancel', fin);
}

export function svgGlyphe(cle, couleur = '#fff', w = 6) {
  const G = GLYPHES[cle]; if (!G) return '';
  return `<svg viewBox="0 0 100 100"><path d="${G.d}" fill="none" stroke="#000a" stroke-width="${w + 5}" stroke-linecap="round" stroke-linejoin="round"/><path d="${G.d}" fill="none" stroke="${couleur}" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
}
function eclat(cle, x, y, couleur) {
  const d = document.createElement('div'); d.className = 'eclatGlyphe'; d.style.left = x + 'px'; d.style.top = y + 'px'; d.style.setProperty('--c', couleur);
  d.innerHTML = svgGlyphe(cle, '#fff', 7);
  document.getElementById('jeu').appendChild(d); setTimeout(() => d.remove(), 700);
}
