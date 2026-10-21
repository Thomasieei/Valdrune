// ===== Interface : icônes, HUD, inventaire, marché, dialogues =====
import { THREE, G, projeter } from './engine.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';
import { TIERS, QUALITES, ARMES, ARMURES, BUTINS, SORTS, MODES, COFFRES, MAITRISES, NIVEAU_REQUIS, VARIANTES, ILE_TYPES, ILE_TAILLES, ILE_NIVEAUX, BATIMENTS, GARDES_ILE, CHAMPION_ILE, HEURE_ASSAUT } from './data.js';
import { nomObjet, couleurObjet, statsObjet, sortsObjet, puissanceObjet, valeurObjet, prixVente, categorieLabel, statsHeros, stockMarchand, stockArene, prixTrophees, niveauRequis, peutPorter, niveauDe, xpPour, bonusMaitrise, tierMaxPour } from './items.js';

const $ = (s) => document.querySelector(s);
const fmt = (n) => Math.round(n).toLocaleString('fr-FR');
export const UI = {};
let api = null;
UI.init = (a) => { api = a; };

// ---------------- Icônes de sorts (SVG) ----------------
const GLYPHES = {
  slash: '<path d="M16 80 C28 42 54 20 88 14 C66 30 46 54 30 86 Z"/><path d="M30 60 L44 46 M40 72 L56 54" stroke="#fff" stroke-width="3" opacity=".6"/>',
  dash: '<path d="M14 30 L38 50 L14 70 L22 50 Z M40 30 L64 50 L40 70 L48 50 Z M66 30 L90 50 L66 70 L74 50 Z"/>',
  spin: '<g><path d="M50 12 A38 38 0 0 1 88 50 L74 50 A24 24 0 0 0 50 26 Z"/><path d="M50 12 A38 38 0 0 1 88 50 L74 50 A24 24 0 0 0 50 26 Z" transform="rotate(120 50 50)"/><path d="M50 12 A38 38 0 0 1 88 50 L74 50 A24 24 0 0 0 50 26 Z" transform="rotate(240 50 50)"/><circle cx="50" cy="50" r="9"/></g>',
  bolt: '<path d="M18 82 L66 34 L60 28 L88 14 L74 42 L68 36 L20 84 Z"/><path d="M18 82 L10 74 M18 82 L26 90 M24 76 L16 68 M24 76 L32 84" stroke="#fff" stroke-width="4" fill="none"/>',
  roll: '<path d="M72 30 A28 28 0 1 0 78 58" fill="none" stroke="#fff" stroke-width="10" stroke-linecap="round"/><path d="M58 18 L84 22 L76 46 Z"/>',
  rain: '<g stroke="#fff" stroke-width="5" stroke-linecap="round"><path d="M26 14 L22 46"/><path d="M50 22 L46 54"/><path d="M74 12 L70 44"/><path d="M36 50 L32 82"/><path d="M62 54 L58 86"/></g><g><path d="M22 52 L14 40 L28 42 Z"/><path d="M46 60 L38 48 L52 50 Z"/><path d="M70 50 L62 38 L76 40 Z"/><path d="M32 88 L24 76 L38 78 Z"/><path d="M58 92 L50 80 L64 82 Z"/></g>',
  fire: '<path d="M50 10 C62 30 80 40 76 62 C74 80 60 90 50 90 C38 90 24 80 24 62 C24 48 34 42 36 28 C44 40 46 44 50 48 C53 34 50 22 50 10 Z"/><path d="M50 52 C56 60 64 66 62 76 C60 84 54 86 50 86 C44 86 38 82 38 74 C38 66 46 62 50 52 Z" fill="#ffd27a"/>',
  pillar: '<ellipse cx="50" cy="86" rx="30" ry="7" opacity=".7"/><path d="M36 86 L36 44 C36 28 46 22 50 8 C54 22 64 28 64 44 L64 86 Z"/><path d="M44 86 L44 52 C44 42 48 38 50 30 C52 38 56 42 56 52 L56 86 Z" fill="#ffe0a0"/>',
  meteor: '<path d="M44 52 L90 10 L56 62 Z" opacity=".75"/><path d="M38 46 L80 18 L48 58 Z" opacity=".5"/><circle cx="36" cy="66" r="20"/><circle cx="30" cy="60" r="6" fill="#ffe0a0"/>',
  shield: '<path d="M50 8 L86 20 L82 54 C78 74 64 84 50 92 C36 84 22 74 18 54 L14 20 Z"/><path d="M50 22 L72 30 L69 52 C66 64 58 72 50 77 Z" fill="#ffffff" opacity=".35"/>',
  heart: '<path d="M50 86 C20 64 10 48 14 32 C18 18 36 14 50 30 C64 14 82 18 86 32 C90 48 80 64 50 86 Z"/><path d="M44 34 h12 v12 h12 v12 h-12 v12 h-12 v-12 h-12 v-12 h12 z" fill="#1a5a1a" opacity=".7"/>',
  wing: '<path d="M14 72 C26 40 58 22 90 18 C76 28 72 34 68 42 C78 40 84 40 88 42 C76 50 66 54 56 56 C64 58 70 60 74 64 C58 72 40 74 14 72 Z"/><path d="M14 72 L30 86 L40 76 Z"/>',
  epee: '<path d="M80 12 L88 20 L46 62 L38 54 Z"/><path d="M30 50 L50 70 L44 76 L24 56 Z"/><path d="M36 64 L20 80 L26 86 L42 70 Z"/><circle cx="18" cy="84" r="5"/>',
  arbalete: '<path d="M14 40 C40 24 60 24 86 40 L84 46 C60 32 40 32 16 46 Z"/><path d="M47 30 h6 v56 h-6 z"/><path d="M50 26 L56 36 L44 36 Z"/><path d="M16 44 L50 60 L84 44" stroke="#fff" stroke-width="2" fill="none"/>',
  baton: '<path d="M30 90 L62 34 L68 37 L36 93 Z"/><circle cx="68" cy="26" r="12"/><path d="M68 8 C74 16 80 18 78 26 C76 34 60 34 58 26 C58 20 64 18 68 8 Z" fill="#ffd27a"/>',
  potion: '<path d="M40 10 h20 v8 h-4 v14 C70 38 78 50 78 62 C78 80 66 90 50 90 C34 90 22 80 22 62 C22 50 30 38 44 32 V18 h-4 z"/><path d="M28 62 C34 58 44 66 50 62 C58 58 66 62 72 60 C72 76 62 84 50 84 C38 84 28 76 28 62 Z" fill="#ff3a4a"/>',
  cible: '<circle cx="50" cy="50" r="28" fill="none" stroke="#fff" stroke-width="7"/><path d="M50 8 V30 M50 70 V92 M8 50 H30 M70 50 H92" stroke="#fff" stroke-width="7"/><circle cx="50" cy="50" r="6"/>',
};
export function svgSort(glyphe, c1, c2, id) {
  const gid = 'g' + id + Math.random().toString(36).slice(2, 6);
  return `<svg class="ic" viewBox="0 0 100 100"><defs><radialGradient id="${gid}" cx="40%" cy="35%" r="75%"><stop offset="0" stop-color="${c1}"/><stop offset=".55" stop-color="${mix(c1, c2, .55)}"/><stop offset="1" stop-color="${c2}"/></radialGradient>
  <filter id="f${gid}" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="2.4" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>
  <rect width="100" height="100" fill="url(#${gid})"/><circle cx="50" cy="50" r="44" fill="none" stroke="#000" stroke-opacity=".35" stroke-width="6"/>
  <g fill="#fff" filter="url(#f${gid})" transform="translate(50 50) scale(.78) translate(-50 -50)">${GLYPHES[glyphe] || ''}</g></svg>`;
}
function mix(a, b, k) { const ca = new THREE.Color(a), cb = new THREE.Color(b); return '#' + ca.lerp(cb, k).getHexString(THREE.SRGBColorSpace); }

// ---------------- Icônes d'objets (rendu 3D) ----------------
let icoR = null, icoScene, icoCam;
const icoCache = {};
function initIcones() {
  const cv = document.createElement('canvas'); cv.width = cv.height = 192;
  icoR = new THREE.WebGLRenderer({ canvas: cv, alpha: true, antialias: true, preserveDrawingBuffer: true });
  icoR.outputColorSpace = THREE.SRGBColorSpace; icoR.toneMapping = THREE.ACESFilmicToneMapping; icoR.toneMappingExposure = 1.2;
  icoScene = new THREE.Scene();
  icoScene.add(new THREE.AmbientLight('#ffffff', 1.0));
  const k = new THREE.DirectionalLight('#fff4e0', 2.4); k.position.set(2, 3, 4); icoScene.add(k);
  const r = new THREE.DirectionalLight('#9ab8ff', 1.2); r.position.set(-3, 1, -2); icoScene.add(r);
  icoCam = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.01, 100);
}
function meshesDe(cleModele, noms) {
  const src = G.assets[cleModele].scene; const out = [];
  for (const n of noms) { const node = src.getObjectByName(n); if (!node) continue; node.traverse(o => { if (o.isMesh) out.push(o); }); }
  return out;
}
function rendreGroupe(grp, orient = 'arme') {
  icoScene.add(grp);
  grp.updateMatrixWorld(true);
  let box = new THREE.Box3().setFromObject(grp);
  const size = box.getSize(new THREE.Vector3()), c = box.getCenter(new THREE.Vector3());
  grp.position.sub(c);
  if (orient === 'arme') {
    // axe le plus long en diagonale
    const axe = size.x > size.y && size.x > size.z ? 'x' : size.y > size.z ? 'y' : 'z';
    const pivot = new THREE.Group(); icoScene.add(pivot); pivot.add(grp);
    if (axe === 'x') pivot.rotation.z = Math.PI / 2; if (axe === 'z') pivot.rotation.x = Math.PI / 2;
    const p2 = new THREE.Group(); icoScene.add(p2); p2.add(pivot); p2.rotation.z = -Math.PI / 4; p2.rotation.y = 0.5;
    p2.updateMatrixWorld(true); box = new THREE.Box3().setFromObject(p2);
    const cc = box.getCenter(new THREE.Vector3()); p2.position.sub(cc);
    grp = p2;
  } else { grp.rotation.y = 0.45; grp.rotation.x = 0.12; }
  grp.updateMatrixWorld(true); box = new THREE.Box3().setFromObject(grp);
  const s = box.getSize(new THREE.Vector3()); const m = Math.max(s.x, s.y) * 0.56;
  icoCam.left = -m; icoCam.right = m; icoCam.top = m; icoCam.bottom = -m; icoCam.position.set(0, 0, 50); icoCam.lookAt(0, 0, 0); icoCam.updateProjectionMatrix();
  icoR.setClearColor(0x000000, 0); icoR.render(icoScene, icoCam);
  const url = icoR.domElement.toDataURL('image/png');
  icoScene.remove(grp);
  return url;
}
function materielTier(m, tier) {
  const mat = m.material.clone();
  const col = TIERS[tier].color;
  mat.color = new THREE.Color('#ffffff').lerp(new THREE.Color(col), 0.62);
  if (mat.emissive) { mat.emissive = new THREE.Color(col); mat.emissiveIntensity = TIERS[tier].glow * 0.5; }
  mat.skinning = false;
  return mat;
}
export function iconeObjet(it) {
  const cle = it.cat + '_' + it.type + '_' + it.tier;
  if (icoCache[cle]) return icoCache[cle];
  if (it.cat === 'butin' || it.cat === 'potion') return (icoCache[cle] = icone2D(it));
  if (!icoR) initIcones();
  const grp = new THREE.Group();
  let ms, orient = 'arme';
  if (it.cat === 'arme') ms = meshesDe(ARMES[it.type].model, [ARMES[it.type].node]);
  else if (it.type === 'casque') { ms = meshesDe('Knight', ['Knight_Helmet']); orient = 'armure'; }
  else if (it.type === 'plastron') { ms = meshesDe('Knight', ['Knight_Body', 'Knight_ArmLeft', 'Knight_ArmRight']); orient = 'armure'; }
  else { ms = meshesDe('Knight', ['Knight_LegLeft', 'Knight_LegRight']); orient = 'armure'; }
  for (const m of ms) {
    const mesh = new THREE.Mesh(m.geometry, materielTier(m, it.tier));
    if (orient === 'arme') { m.updateMatrixWorld(true); }
    grp.add(mesh);
  }
  return (icoCache[cle] = rendreGroupe(grp, orient));
}
export function bustePersonnage(cle, canvas, couleurFond = null) {
  if (!icoR) initIcones();
  const src = G.assets[cle];
  const m = SkeletonUtils.clone(src.scene);
  // on cache les armes pour un portrait propre
  m.traverse(o => { if (/Sword|Axe|Shield|Crossbow|Staff|Wand|Knife|Throwable|Mug|Spellbook|Offhand/.test(o.name)) o.visible = false; });
  icoScene.add(m); m.updateMatrixWorld(true);
  const box = new THREE.Box3().setFromObject(m); const h = box.max.y - box.min.y;
  const cy = box.max.y - h * 0.2; const r = h * 0.21;
  icoCam.left = -r; icoCam.right = r; icoCam.top = r; icoCam.bottom = -r;
  icoCam.position.set(r * 0.6, cy + r * 0.1, 50); icoCam.lookAt(0, cy, 0); icoCam.updateProjectionMatrix();
  icoR.setClearColor(0x000000, 0); icoR.render(icoScene, icoCam);
  icoScene.remove(m);
  const g = canvas.getContext('2d'); g.clearRect(0, 0, canvas.width, canvas.height);
  if (couleurFond) { const gr = g.createRadialGradient(64, 50, 10, 64, 64, 80); gr.addColorStop(0, couleurFond); gr.addColorStop(1, '#120b16'); g.fillStyle = gr; g.fillRect(0, 0, canvas.width, canvas.height); }
  g.drawImage(icoR.domElement, 0, 0, canvas.width, canvas.height);
}
function icone2D(it) {
  const c = document.createElement('canvas'); c.width = c.height = 128; const g = c.getContext('2d');
  g.lineJoin = 'round'; g.lineCap = 'round'; g.shadowColor = '#000a'; g.shadowBlur = 6; g.shadowOffsetY = 3;
  const t = it.type;
  if (it.cat === 'potion') {
    g.fillStyle = '#d8e8f0'; g.globalAlpha = .9; g.beginPath(); g.moveTo(54, 18); g.lineTo(74, 18); g.lineTo(74, 42); g.quadraticCurveTo(102, 54, 100, 82); g.quadraticCurveTo(96, 112, 64, 112); g.quadraticCurveTo(32, 112, 28, 82); g.quadraticCurveTo(26, 54, 54, 42); g.closePath(); g.fill();
    g.globalAlpha = 1; const gr = g.createLinearGradient(0, 60, 0, 110); gr.addColorStop(0, '#ff6a7a'); gr.addColorStop(1, '#a3102a'); g.fillStyle = gr;
    g.beginPath(); g.moveTo(32, 76); g.quadraticCurveTo(64, 66, 96, 76); g.quadraticCurveTo(94, 108, 64, 108); g.quadraticCurveTo(34, 108, 32, 76); g.fill();
    g.fillStyle = '#8a5a2a'; g.fillRect(50, 10, 28, 12); g.fillStyle = '#fff8'; g.beginPath(); g.ellipse(46, 70, 6, 12, 0.4, 0, 7); g.fill();
  } else if (t === 'os') {
    g.fillStyle = '#e8dcc0'; g.translate(64, 64); g.rotate(-0.7);
    g.fillRect(-36, -7, 72, 14); for (const s of [-1, 1]) { g.beginPath(); g.arc(s * 38, -8, 10, 0, 7); g.arc(s * 38, 8, 10, 0, 7); g.fill(); }
    g.strokeStyle = '#7a6a4a'; g.lineWidth = 2; g.beginPath(); g.moveTo(-4, -8); g.lineTo(4, 8); g.stroke();
  } else if (t === 'tissu') {
    g.fillStyle = '#8a6a4e'; g.beginPath(); g.moveTo(20, 30); g.lineTo(104, 22); g.lineTo(96, 60); g.lineTo(108, 100); g.lineTo(70, 92); g.lineTo(52, 108); g.lineTo(30, 88); g.lineTo(18, 60); g.closePath(); g.fill();
    g.strokeStyle = '#5a4030'; g.lineWidth = 3; g.setLineDash([6, 5]); g.strokeRect(34, 40, 56, 40);
  } else if (t === 'crane') {
    g.fillStyle = '#eee4cc'; g.beginPath(); g.arc(64, 54, 36, Math.PI * 0.9, Math.PI * 2.1); g.lineTo(88, 96); g.lineTo(40, 96); g.closePath(); g.fill();
    g.fillStyle = '#2a1a10'; g.beginPath(); g.arc(50, 60, 9, 0, 7); g.arc(78, 60, 9, 0, 7); g.fill(); g.fillRect(58, 74, 12, 8);
    g.strokeStyle = '#6a5a40'; g.lineWidth = 3; g.beginPath(); g.moveTo(64, 20); g.lineTo(60, 34); g.lineTo(68, 44); g.stroke();
  } else if (t === 'gemme') {
    g.fillStyle = '#6a9aa0'; g.beginPath(); g.moveTo(64, 18); g.lineTo(100, 50); g.lineTo(64, 110); g.lineTo(28, 50); g.closePath(); g.fill();
    g.fillStyle = '#9ac8cc'; g.beginPath(); g.moveTo(64, 18); g.lineTo(80, 50); g.lineTo(64, 110); g.lineTo(48, 50); g.closePath(); g.fill();
  } else if (t === 'rune') {
    g.fillStyle = '#6a4a3a'; g.beginPath(); g.ellipse(64, 66, 40, 46, 0.2, 0, 7); g.fill();
    g.strokeStyle = '#ff8a3a'; g.shadowColor = '#ff5a1a'; g.shadowBlur = 14; g.lineWidth = 7; g.beginPath(); g.moveTo(52, 40); g.lineTo(52, 92); g.moveTo(52, 50); g.lineTo(78, 64); g.lineTo(52, 76); g.stroke();
  }
  return c.toDataURL('image/png');
}

export function htmlCase(it, extra = '', style = '') {
  if (!it) return `<div class="case ${extra}"></div>`;
  const equipable = it.cat === 'arme' || it.cat === 'armure';
  const bloque = equipable && !peutPorter(it);
  const glow = it.tier >= 5 && !bloque ? `filter:drop-shadow(0 0 6px ${TIERS[it.tier].color})` : '';
  const tc = it.tier ? TIERS[it.tier].color : '#8a6a4a';
  const bg = it.tier ? `background:radial-gradient(circle at 50% 42%, ${tc}aa, ${tc}33 55%, #241810 85%);--tc:${tc};` : '';
  const cad = bloque ? `<span class="cadenas"><svg viewBox="0 0 24 24"><path d="M7 10V7a5 5 0 0110 0v3h1.5v11h-13V10zm2 0h6V7a3 3 0 00-6 0z" fill="#ffd0c0"/></svg>Niv. ${niveauRequis(it)}</span>` : '';
  return `<div class="case q${it.q || 0} ${it.tier ? 'tiere' : ''} ${bloque ? 'bloque' : ''} ${extra}" style="${bg}${style}">${cad}<img src="${iconeObjet(it)}" alt="" style="${glow}">${it.tier ? `<span class="tier">${TIERS[it.tier].roman}</span>` : ''}${it.n > 1 ? `<span class="nb">${it.n}</span>` : ''}</div>`;
}

// ---------------- Barre de sorts ----------------
const TOUCHES = ['ATK', 'Q', 'W', 'E', 'R', 'D', 'F', 'POT', 'CIBLE'];
UI.construireSorts = (joueur) => {
  const zone = $('#sorts'); zone.innerHTML = '';
  for (const k of TOUCHES) {
    const b = document.createElement('button'); b.className = 'sort'; b.id = 's-' + k; b.dataset.k = k;
    let svg = '', lettre = k.length === 1 ? k : '';
    if (k === 'ATK') { const t = joueur.armeType; svg = svgSort(t, '#ffe2a0', '#6a3a10', 'atk'); }
    else if (k === 'POT') svg = svgSort('potion', '#ffd0d8', '#5a0a18', 'pot');
    else if (k === 'CIBLE') svg = svgSort('cible', '#ffcf9a', '#3a1a10', 'cib');
    else { const s = joueur.sorts[k]; svg = s ? svgSort(s.glyphe, s.couleur[0], s.couleur[1], k) : svgSort('', '#3a3440', '#141016', k); if (!s) b.classList.add('off'); }
    b.innerHTML = `<div class="cadre"><div>${svg}<div class="cd"></div><div class="num"></div></div></div>${lettre ? `<span class="t">${lettre}</span>` : ''}${k === 'POT' ? '<span class="compte"></span>' : ''}`;
    b.setAttribute('aria-label', k === 'ATK' ? 'Attaque' : k === 'POT' ? 'Potion' : k === 'CIBLE' ? 'Verrouiller la cible' : (joueur.sorts[k]?.nom || 'Vide'));
    const go = (e) => { e.preventDefault(); e.stopPropagation(); api.touche(k, true); };
    const fin = (e) => { e.preventDefault(); api.touche(k, false); };
    b.addEventListener('pointerdown', go); b.addEventListener('pointerup', fin); b.addEventListener('pointercancel', fin); b.addEventListener('pointerleave', fin);
    zone.appendChild(b);
  }
};
// écritures DOM seulement quand la valeur change (sinon le navigateur recalcule le style 12 fois par seconde)
const txt = (el, v) => { if (el && el._t !== v) { el._t = v; el.textContent = v; } };
const sty = (el, k, v) => { if (!el) return; const c = el._s || (el._s = {}); if (c[k] !== v) { c[k] = v; if (k[0] === '-') el.style.setProperty(k, v); else el.style[k] = v; } };
const cls = (el, c, on) => { if (!el) return; const m = el._c || (el._c = {}); if (m[c] !== on) { m[c] = on; el.classList.toggle(c, on); } };
const els = {};
const E = (id) => { const e = els[id]; if (e && e.isConnected) return e; return (els[id] = document.getElementById(id)); };
UI.majSorts = (joueur) => {
  for (const k of ['Q', 'W', 'E', 'R', 'D', 'F', 'POT']) {
    const b = E('s-' + k); if (!b) continue;
    const cd = joueur.cds[k] || 0, max = joueur.cdMax[k] || 1;
    const cdEl = b._cdEl || (b._cdEl = b.querySelector('.cd')), num = b._num || (b._num = b.querySelector('.num'));
    sty(cdEl, '--k', (cd > 0 ? Math.round(cd / max * 200) / 200 : 0) + 'turn');
    txt(num, cd > 0 ? (cd < 1 ? cd.toFixed(1) : String(Math.ceil(cd))) : '');
    const s = joueur.sorts[k];
    cls(b, 'manque', !!(s && cd <= 0 && joueur.energie < s.energie));
    if (k === 'POT') txt(b._cpt || (b._cpt = b.querySelector('.compte')), 'x' + joueur.potions);
    if (b._cd > 0 && cd <= 0) { b.classList.remove('pret'); void b.offsetWidth; b.classList.add('pret'); }
    b._cd = cd;
  }
  cls(E('s-CIBLE'), 'actif', !!joueur.cibleVerrou);
};

// ---------------- HUD ----------------
UI.majHud = (j, st) => {
  sty(E('pvFill'), 'transform', `scaleX(${(Math.max(0, j.pv / st.pvMax)).toFixed(3)})`);
  sty(E('pvShield'), 'transform', `scaleX(${(Math.min(1, (j.pv + j.bouclier) / st.pvMax)).toFixed(3)})`);
  txt(E('pvTxt'), `${fmt(j.pv)} / ${fmt(st.pvMax)}`);
  sty(E('enFill'), 'transform', `scaleX(${(Math.max(0, j.energie / st.energieMax)).toFixed(3)})`);
  txt(E('enTxt'), `${fmt(j.energie)} / ${fmt(st.energieMax)}`);
  const et = api.etat();
  txt(E('argentTxt'), fmt(et.argent));
  txt(E('trophTxt'), fmt(et.trophees || 0));
  const d = new Date(); txt(E('zHeure'), String(d.getHours()).padStart(2, '0') + ':' + String(d.getMinutes()).padStart(2, '0'));
  const buffs = [];
  if (j.bouclier > 0) buffs.push(['#62b0ff', 'É']);
  if (j.soinT > 0) buffs.push(['#6aff7a', '+']);
  if (j.sprintT > 0) buffs.push(['#ffe27a', '»']);
  if (j.bonusTir) buffs.push(['#9effc4', '×2']);
  if (j.vampT > 0) buffs.push(['#ff4a6a', '♥']);
  if (j.invuln > 0.3) buffs.push(['#e0c8ff', '✦']);
  const html = buffs.map(([c, t]) => `<div class="buff" style="background:radial-gradient(${c},#111);color:#fff">${t}</div>`).join('');
  if (UI._buffs !== html) { E('buffs').innerHTML = html; UI._buffs = html; }
};
UI.journal = (titre, obj, prog = null) => {
  $('#jTitre').textContent = titre; $('#jObj').textContent = obj;
  const p = $('#jProg'); p.hidden = prog === null; if (prog !== null) p.querySelector('i').style.width = (prog * 100) + '%';
};
UI.zone = (nom, info) => { $('#zNom').textContent = nom; $('#zInfo').textContent = info; };
UI.boss = (b) => {
  const el = $('#bossbar');
  if (!b) { el.hidden = true; return; }
  el.hidden = false; $('#bNom').textContent = b.nom;
  $('#bFill').style.transform = `scaleX(${Math.max(0, b.pv / b.pvMax)})`; $('#bFill').style.transformOrigin = 'left';
  $('#bTxt').textContent = `${fmt(b.pv)} / ${fmt(b.pvMax)}`;
};
UI.toast = (txt, grand = false) => {
  const d = document.createElement('div'); d.textContent = txt; if (grand) d.className = 'grand';
  $('#toast').appendChild(d); setTimeout(() => d.remove(), 2700);
};
UI.chat = (nom, txt) => {
  const log = $('#chatLog'); const d = document.createElement('div');
  d.innerHTML = `[Français] <b></b>: <span></span>`; d.querySelector('b').textContent = nom; d.querySelector('span').textContent = txt;
  log.appendChild(d); while (log.children.length > 2) log.firstChild.remove();
  setTimeout(() => d.remove(), 9000);
};
UI.action = (texte, cb) => {
  const b = $('#action');
  if (!texte) { b.hidden = true; b.onclick = null; return; }
  if (b.textContent !== texte) b.textContent = texte;
  b.hidden = false; b.onclick = (e) => { e.stopPropagation(); cb(); };
};
UI.nombre = (pos, txt, classe = '') => {
  const p = projeter(pos); if (!p.visible) return;
  const d = document.createElement('div'); d.className = 'dmg contour ' + classe; d.textContent = txt;
  d.style.left = (p.x + (Math.random() - 0.5) * 30) + 'px'; d.style.top = p.y + 'px';
  $('#nombres').appendChild(d); setTimeout(() => d.remove(), 900);
};

// ---------------- Plaques de nom ----------------
const plaques = new Map();
UI.plaque = (ent, { nom, guilde = '', classe = '', vie = true, lettre = true, ip = null }) => {
  const d = document.createElement('div'); d.className = 'plaque contour ' + classe;
  const ini = lettre ? `<b>${nom[0]}</b>` : '';
  d.innerHTML = `<div class="n">${ini}${lettre ? nom.slice(1) : nom}</div>${guilde || ip ? `<div class="gd">${guilde}${ip ? `<span class="ipb">⚔ ${ip}</span>` : ''}</div>` : ''}${vie ? '<div class="vie"><i></i></div>' : ''}`;
  $('#labels').appendChild(d); plaques.set(ent, { d, barre: d.querySelector('.vie i'), h: ent.hauteurPlaque || 2.5 });
};
UI.retirerPlaque = (ent) => { const p = plaques.get(ent); if (p) { p.d.remove(); plaques.delete(ent); } };
UI.viderPlaques = () => { for (const p of plaques.values()) p.d.remove(); plaques.clear(); };
const _v = new THREE.Vector3();
UI.majPlaques = (centre) => {
  for (const [ent, p] of plaques) {
    const pos = ent.pos || ent.root.position;
    let vis = !ent.mort && Math.abs(pos.x - centre.x) < 30 && Math.abs(pos.z - centre.z) < 30;
    let s = null;
    if (vis) { _v.set(pos.x, pos.y + p.h, pos.z); s = projeter(_v); vis = s.visible && s.x > -80 && s.x < innerWidth + 80 && s.y > -40 && s.y < innerHeight + 40; }
    if (!vis) { if (p.vis !== false) { p.d.style.display = 'none'; p.vis = false; } continue; }
    if (p.vis !== true) { p.d.style.display = ''; p.vis = true; }
    const x = Math.round(s.x), y = Math.round(s.y);
    if (x !== p.x || y !== p.y) { p.d.style.transform = `translate(${x}px,${y}px) translate(-50%,-100%)`; p.x = x; p.y = y; }
    if (p.barre && ent.pvMax) { const w = Math.max(0, Math.round(ent.pv / ent.pvMax * 100)); if (w !== p.w) { p.barre.style.width = w + '%'; p.w = w; } }
  }
};

// ---------------- Mini-carte ----------------
UI.mini = (monde, joueur, entites) => {
  const cv = $('#miniCv'), g = cv.getContext('2d');
  g.clearRect(0, 0, 256, 256);
  let x0, z0, x1, z1;
  if (monde.type === 'hub') { x0 = monde.bornes.x0 - 4; x1 = monde.bornes.x1 + 4; z0 = monde.bornes.z0 - 4; z1 = monde.bornes.z1 + 4; }
  else if (monde.type === 'arene') { x0 = z0 = -monde.rayon - 3; x1 = z1 = monde.rayon + 3; }
  else if (monde.type === 'ile') { x0 = z0 = -monde.rayonMonde - 14; x1 = z1 = monde.rayonMonde + 14; }
  else { x0 = 0; z0 = 0; x1 = monde.grilleW * 4; z1 = monde.grilleH * 4; }
  const ech = 236 / Math.max(x1 - x0, z1 - z0), ox = 128 - (x0 + x1) / 2 * ech, oz = 128 - (z0 + z1) / 2 * ech;
  const P = (x, z) => [ox + x * ech, oz + z * ech];
  if (!monde._fond) {
    const c = document.createElement('canvas'); c.width = c.height = 256; const f = c.getContext('2d');
    if (monde.type === 'hub') { f.fillStyle = '#4a5f8a'; const [a, b] = P(monde.bornes.x0, monde.bornes.z0); f.fillRect(a, b, (monde.bornes.x1 - monde.bornes.x0) * ech, (monde.bornes.z1 - monde.bornes.z0) * ech); f.fillStyle = '#6a80b0'; f.beginPath(); f.arc(...P(0, 0), 10 * ech, 0, 7); f.fill(); }
    else if (monde.type === 'ile') { f.fillStyle = '#2a5a8a'; f.fillRect(0, 0, 256, 256); f.fillStyle = '#6aa85a'; f.beginPath(); f.arc(...P(0, 0), monde.rayonMonde * ech, 0, 7); f.fill(); for (const p of monde.plots) { f.fillStyle = p.bati ? '#c8a060' : '#ffd25a66'; f.beginPath(); f.arc(...P(p.pos.x, p.pos.z), 4 * ech, 0, 7); f.fill(); } }
    else if (monde.type === 'arene') { f.fillStyle = '#5f5a8e'; f.beginPath(); f.arc(...P(0, 0), monde.rayon * ech, 0, 7); f.fill(); }
    else {
      for (let z = 0; z < monde.grilleH; z++) for (let x = 0; x < monde.grilleW; x++) {
        const v = monde.grille[z * monde.grilleW + x]; if (!v) continue;
        f.fillStyle = v === 1 ? '#5f7fae' : '#4a6290'; const [a, b] = P(x * 4, z * 4); f.fillRect(a, b, 4 * ech + 0.6, 4 * ech + 0.6);
      }
    }
    monde._fond = c;
  }
  g.drawImage(monde._fond, 0, 0);
  for (const e of entites) {
    const [a, b] = P(e.x, e.z);
    if (e.type === 'mob') { g.fillStyle = '#ff3a2a'; g.beginPath(); g.arc(a, b, 2.6, 0, 7); g.fill(); }
    else if (e.type === 'boss') { g.fillStyle = '#ff2a1a'; g.strokeStyle = '#ffd27a'; g.lineWidth = 1.5; g.beginPath(); g.arc(a, b, 6, 0, 7); g.fill(); g.stroke(); }
    else if (e.type === 'coffre') { g.fillStyle = e.c; g.fillRect(a - 4, b - 4, 8, 8); g.strokeStyle = '#000'; g.strokeRect(a - 4, b - 4, 8, 8); }
    else if (e.type === 'joueur') { g.fillStyle = '#7fb2ff'; g.beginPath(); g.arc(a, b, 3, 0, 7); g.fill(); }
    else if (e.type === 'pnj') { g.fillStyle = '#ffd97a'; g.beginPath(); g.arc(a, b, 5, 0, 7); g.fill(); }
    else if (e.type === 'allie') { g.fillStyle = '#4fd1ff'; g.strokeStyle = '#fff'; g.lineWidth = 1.5; g.beginPath(); g.arc(a, b, 4.5, 0, 7); g.fill(); g.stroke(); }
    else if (e.type === 'portailJ') { g.fillStyle = '#ffc84a'; g.shadowColor = '#ffc84a'; g.shadowBlur = 8; g.beginPath(); g.arc(a, b, 5, 0, 7); g.fill(); g.shadowBlur = 0; }
    else if (e.type === 'portailV') { g.fillStyle = '#b05aff'; g.shadowColor = '#b05aff'; g.shadowBlur = 8; g.beginPath(); g.arc(a, b, 6, 0, 7); g.fill(); g.shadowBlur = 0; }
    else if (e.type === 'portail') { g.fillStyle = '#ff3a2a'; g.shadowColor = '#ff3a2a'; g.shadowBlur = 8; g.beginPath(); g.arc(a, b, 6, 0, 7); g.fill(); g.shadowBlur = 0; }
  }
  const [a, b] = P(joueur.pos.x, joueur.pos.z);
  g.save(); g.translate(a, b); g.rotate(-joueur.angle + Math.PI);
  g.fillStyle = '#ffffff'; g.strokeStyle = '#2a6aff'; g.lineWidth = 2; g.beginPath(); g.moveTo(0, -8); g.lineTo(6, 6); g.lineTo(0, 3); g.lineTo(-6, 6); g.closePath(); g.fill(); g.stroke(); g.restore();
};

// ---------------- Inventaire ----------------
let selection = null, ongletInv = 'equip';
UI.ouvrirInventaire = () => { selection = null; UI.rendreInventaire(); $('#inv').hidden = false; api.son('open_001', 0.4); };
UI.rendreInventaire = () => {
  const j = api.etat(); const st = statsHeros(j.equip);
  const slot = (s, label) => {
    const it = j.equip[s];
    return `<button class="case-btn" data-eq="${s}" style="border:0;background:none;padding:0">${it ? htmlCase(it) : `<div class="case"><span class="vide">${label}</span></div>`}</button>`;
  };
  const tabs = `<div class="ongletsInv"><button data-t="equip" class="${ongletInv === 'equip' ? 'actif' : ''}">Équipement</button><button data-t="maitrise" class="${ongletInv === 'maitrise' ? 'actif' : ''}">Maîtrise</button></div>`;
  $('#inv').innerHTML = `<div class="cadreInv parchemin">
    <button class="fermer" data-x aria-label="Fermer">×</button>
    <div style="display:flex;flex-direction:column;min-height:0">
      <div class="titreInv"><h2>${j.nom}</h2>${tabs}</div>
      ${ongletInv === 'maitrise' ? htmlMaitrise(j) : `
      <div class="equipement">
        <div style="grid-column:1;grid-row:1">${slot('casque', 'Tête')}</div>
        <div class="silhouette"><canvas id="silCv" width="256" height="256"></canvas></div>
        <div style="grid-column:3;grid-row:1">${slot('arme', 'Arme')}</div>
        <div style="grid-column:1;grid-row:2">${slot('plastron', 'Torse')}</div>
        <div style="grid-column:1;grid-row:3">${slot('bottes', 'Pieds')}</div>
        <div style="grid-column:3;grid-row:2;font-family:var(--f-label);font-weight:800;text-align:center;font-size:2vh">Puissance<br><span style="font-size:3.4vh">${st.ip}</span></div>
      </div>
      <div class="stats">
        <div><span>Points de vie</span><b>${fmt(st.pvMax)}</b></div><div><span>Armure</span><b>${fmt(st.armure)} (${Math.round(st.reduction * 100)} %)</b></div>
        <div><span>Dégâts</span><b>${fmt(st.degats)}</b></div><div><span>DPS</span><b>${fmt(st.dps)}</b></div>
        <div><span>Vitesse d'attaque</span><b>${st.vitesseAtk.toFixed(2)}/s</b></div><div><span>Critique</span><b>${st.crit} %</b></div>
        <div><span>Énergie</span><b>${fmt(st.energieMax)}</b></div><div><span>Vitesse</span><b>${st.vitesse.toFixed(1)} m/s</b></div>
      </div>`}
    </div>
    <div class="colDroite">
      <div class="entete"><h2>Sac</h2><div style="font-family:var(--f-label);font-weight:800;font-size:2.4vh;display:flex;align-items:center;gap:.8vh"><span class="piece"></span>${fmt(j.argent)} <span class="troph">🏆</span>${fmt(j.trophees || 0)} · ${j.sac.length}/40</div></div>
      <div class="grilleSac">${j.sac.map(it => `<button data-id="${it.id}" style="border:0;background:none;padding:0">${htmlCase(it, selection === it.id ? 'choisi' : '')}</button>`).join('')}
      ${Array.from({ length: Math.max(0, 40 - j.sac.length) }, () => '<div class="case"></div>').join('')}</div>
      <p style="margin:1vh 0 0;font-size:1.8vh;color:#6a4a2e">Touche un objet pour voir toutes ses caractéristiques et l’équiper.</p>
    </div></div>`;
  if ($('#silCv')) bustePersonnage(ARMES[j.equip.arme ? j.equip.arme.type : 'epee'].model, $('#silCv'), '#6a4a3a');
  $('#inv').querySelectorAll('[data-t]').forEach(b => b.onclick = () => { ongletInv = b.dataset.t; api.son('click_001', 0.4); UI.rendreInventaire(); });
  $('#inv').querySelector('[data-x]').onclick = () => { $('#inv').hidden = true; api.son('close_001', 0.4); };
  $('#inv').querySelectorAll('[data-id]').forEach(b => b.onclick = () => { const it = j.sac.find(i => i.id == b.dataset.id); UI.fiche(it, 'sac'); });
  $('#inv').querySelectorAll('[data-eq]').forEach(b => b.onclick = () => { const it = j.equip[b.dataset.eq]; if (it) UI.fiche(it, 'equipe'); });
};

// Fiche détaillée d'un objet (un seul clic)
UI.fiche = (it, contexte) => {
  if (!it) return;
  api.son('select_001', 0.4);
  const j = api.etat();
  const st = statsObjet(it);
  const slot = it.cat === 'arme' ? 'arme' : it.cat === 'armure' ? it.type : null;
  const porte = slot ? j.equip[slot] : null;
  const stP = porte && porte.id !== it.id ? statsObjet(porte) : null;
  const libelles = { bonusDeg: 'Bonus de dégâts', recharge: 'Recharge des sorts', pvp: 'Contre les joueurs', degats: 'Dégâts par coup', dps: 'Dégâts par seconde', vitesse: it.cat === 'arme' ? "Vitesse d'attaque" : 'Vitesse de déplacement', crit: 'Chance de critique', portee: 'Portée', armure: 'Armure', pv: 'Points de vie', regen: 'Régénération' };
  const unite = { vitesse: it.cat === 'arme' ? '/s' : ' %', crit: ' %', portee: ' m', regen: ' %/s', bonusDeg: ' %', recharge: ' % plus rapide', pvp: ' % de dégâts' };
  const lignes = Object.entries(st).map(([k, v]) => {
    let diff = '';
    if (stP && stP[k] !== undefined) { const d = v - stP[k]; if (Math.abs(d) > 0.001) diff = `<span class="${d > 0 ? 'plus' : 'moins'}">${d > 0 ? '▲' : '▼'} ${Math.abs(+d.toFixed(2))}</span>`; }
    return `<tr><td>${libelles[k] || k}</td><td>${typeof v === 'number' && !Number.isInteger(v) ? v.toFixed(k === 'vitesse' && it.cat === 'arme' ? 2 : 1) : fmt(v)}${unite[k] || ''}</td><td class="diff">${diff}</td></tr>`;
  }).join('');
  const sorts = sortsObjet(it).map(s => `<div class="s">${svgSort(s.glyphe, s.couleur[0], s.couleur[1], 'f' + s.touche)}<div><b>${s.touche} · ${s.nom}</b> <span style="color:#6a4a2e">— ${s.cd} s · ${s.energie} énergie</span><br>${s.desc}</div></div>`).join('');
  const t = it.tier ? TIERS[it.tier] : null;
  const q = QUALITES[it.q || 0];
  const boutons = [];
  const ok = peutPorter(it);
  if (contexte === 'sac' && slot) boutons.push(`<button class="btn or" data-a="equiper" ${ok ? '' : 'disabled'}>Équiper</button>`);
  if (contexte === 'sac' && it.cat === 'potion') boutons.push(`<button class="btn or" data-a="ranger">Ranger dans la ceinture</button>`);
  if (contexte === 'equipe') boutons.push(`<button class="btn gris" data-a="retirer">Retirer</button>`);
  if (contexte === 'vente') boutons.push(`<button class="btn" data-a="vendre">Vendre ${fmt(prixVente(it))}</button>`);
  if (contexte === 'achat') boutons.push(`<button class="btn" data-a="acheter">Acheter ${fmt(valeurObjet(it))}</button>`);
  if (contexte === 'arene') boutons.push(`<button class="btn" data-a="acheterArene" ${j.trophees >= prixTrophees(it) ? '' : 'disabled'}>Acheter 🏆 ${fmt(prixTrophees(it))}</button>`);
  const req = slot ? (() => { const n = niveauDe(it.type), r = niveauRequis(it); const nomM = MAITRISES.find(m => m.id === it.type).nom; return `<p class="req ${n >= r ? 'okr' : 'ko'}">Niveau requis : ${nomM} ${r} · ${n >= r ? 'tu es niveau ' + n : 'tu n’es que niveau ' + n}${n > 1 ? ` · bonus de maîtrise +${(bonusMaitrise(n) * 100).toFixed(1).replace('.', ',')} %` : ''}</p>`; })() : '';
  const vInfo = it.arene ? `<p class="varArene" style="--vc:${VARIANTES[it.arene].couleur}"><b>Objet d’arène · ${VARIANTES[it.arene].style}.</b> ${VARIANTES[it.arene].texte} +10 % contre les joueurs.</p>` : '';
  $('#fiche').innerHTML = `<div class="carteObjet parchemin"><button class="fermer" data-x aria-label="Fermer">×</button>
    <div class="tete"><div class="grosse">${htmlCase(it, '', 'width:100%;height:100%')}</div>
    <div><div class="titre" style="color:${it.tier ? shade(couleurObjet(it)) : '#3a2312'}">${nomObjet(it)}</div>
    <div class="sous">${categorieLabel(it)}${t ? ` · Tier ${t.roman} (${t.nom}) · <b style="color:${shade(q.color)}">${q.nom}</b>` : ''}</div>
    ${slot ? `<span class="ip">Puissance ${puissanceObjet(it)}</span>` : ''}</div></div>
    ${req}${vInfo}
    ${lignes ? `<table>${lignes}</table>` : `<p style="font-size:2.1vh">${it.cat === 'potion' ? 'Rend 40 % de tes PV en 1 s. Se boit avec le bouton potion.' : 'Ne sert à rien, sauf à être vendu au marchand.'}</p>`}
    ${sorts ? `<div class="sortsObj">${sorts}</div>` : ''}
    ${porte && porte.id !== it.id ? `<p style="font-size:1.8vh;color:#6a4a2e;margin:1vh 0 0">Comparé à ton ${nomObjet(porte)} (${TIERS[porte.tier].roman}).</p>` : ''}
    <p style="font-size:1.8vh;margin:1vh 0 0">Valeur : <b>${fmt(valeurObjet(it))}</b> · Revente : <b>${fmt(prixVente(it))}</b></p>
    <div class="actions">${boutons.join('')}</div></div>`;
  const f = $('#fiche'); f.hidden = false;
  f.querySelector('[data-x]').onclick = () => (f.hidden = true);
  f.onclick = (e) => { if (e.target === f) f.hidden = true; };
  f.querySelectorAll('[data-a]').forEach(b => b.onclick = () => {
    const a = b.dataset.a; f.hidden = true;
    if (a === 'equiper') api.equiper(it.id);
    if (a === 'retirer') api.retirer(slot);
    if (a === 'vendre') api.vendre(it.id);
    if (a === 'acheter') api.acheter(it);
    if (a === 'acheterArene') api.acheterArene(it);
    if (a === 'ranger') api.rangerPotion(it.id);
    if (!$('#inv').hidden) UI.rendreInventaire();
    if (!$('#marche').hidden) UI.rendreMarche();
  });
};
function shade(c) { const S = THREE.SRGBColorSpace; const col = new THREE.Color(c); const hsl = {}; col.getHSL(hsl, S); return '#' + new THREE.Color().setHSL(hsl.h, Math.min(1, hsl.s * 1.15), Math.min(hsl.l, 0.34), S).getHexString(S); }

// ---------------- Marchand ----------------
let stock = null, ongletM = 'achat';
const filtres = { cat: 'tout', niv: 'tout', q: 'tout', txt: '' };
UI.dialogueMarchand = () => {
  const d = $('#dialogue');
  d.innerHTML = `<div class="boiteDial bois"><button class="fermer" data-x aria-label="Fermer">×</button><div class="visage"><canvas id="visageCv" width="128" height="128"></canvas></div>
  <div><h3>Borin, marchand de la Place</h3><p>Bienvenue, voyageur. Le bronze et l'azur, je les ai. Le reste, faudra aller le chercher de l'autre côté de la Brèche… et revenir vivant pour me le revendre.</p>
  <div class="choix"><button class="btn or" data-c="achat">Acheter</button><button class="btn" data-c="vente">Vendre</button><button class="btn gris" data-c="infos">Parle-moi des tiers</button><button class="btn gris" data-x2>Au revoir</button></div></div></div>`;
  d.hidden = false; bustePersonnage('Barbarian', $('#visageCv'), '#8a5a2a');
  api.son('bookOpen', 0.5);
  const fermer = () => { d.hidden = true; };
  d.querySelector('[data-x]').onclick = fermer; d.querySelector('[data-x2]').onclick = fermer;
  d.querySelectorAll('[data-c]').forEach(b => b.onclick = () => {
    if (b.dataset.c === 'infos') {
      d.querySelector('p').innerHTML = 'Du <b style="color:#c9c1b4">T1 Rouillé</b> au <b style="color:#fff0b0">T8 Céleste</b> : rouillé, bronze, <b style="color:#6be27a">sylvestre</b>, <b style="color:#7ab0ff">azur</b>, <b style="color:#ff7a5a">braise</b>, <b style="color:#ffb84a">solaire</b>, <b style="color:#c88aff">abyssal</b>, céleste. Chaque tier frappe environ 40 % plus fort que le précédent. La qualité, de Normal à Chef-d’œuvre, ajoute jusqu’à 40 %.';
      return;
    }
    fermer(); ongletM = b.dataset.c; UI.ouvrirMarche();
  });
};
let stockA = null;
UI.ouvrirMarche = (onglet = null) => { if (!stock) stock = stockMarchand(); if (!stockA) stockA = stockArene(); if (onglet) { ongletM = onglet; if (onglet === 'arene') { filtres.niv = 'tout'; filtres.q = 'tout'; } } UI.rendreMarche(); $('#marche').hidden = false; api.son('open_001', 0.4); };
UI.rendreMarche = () => {
  const j = api.etat();
  const A = ongletM === 'arene';
  const source = ongletM === 'achat' ? stock : A ? stockA : j.sac;
  const prix = (it) => A ? prixTrophees(it) : ongletM === 'achat' ? valeurObjet(it) : prixVente(it);
  const solde = A ? j.trophees : j.argent;
  const liste = source.filter(it => {
    if (filtres.cat !== 'tout') {
      const c = it.cat === 'arme' ? 'arme' : it.cat === 'armure' ? it.type : it.cat;
      if (c !== filtres.cat) return false;
    }
    if (filtres.niv !== 'tout' && it.tier != filtres.niv) return false;
    if (filtres.q !== 'tout' && (it.q || 0) != filtres.q) return false;
    if (filtres.txt && !nomObjet(it).toLowerCase().includes(filtres.txt.toLowerCase())) return false;
    return true;
  }).sort((a, b) => (ongletM === 'vente' ? prix(b) - prix(a) : prix(a) - prix(b)));
  const icone = A ? '<span class="troph">🏆</span>' : '<span class="piece"></span>';
  const opt = (v, l, cur) => `<option value="${v}" ${cur == v ? 'selected' : ''}>${l}</option>`;
  $('#marche').innerHTML = `<div class="cadreM parchemin"><button class="fermer" data-x aria-label="Fermer">×</button>
    <div class="mEntete"><div class="embleme"><svg viewBox="0 0 24 24" fill="#f2cd78"><path d="M13.8 2.6l7.6 7.6-2.1 2.1-1.4-1.4-2.8 2.8 1.4 1.4-2.1 2.1-5.7-5.7 2.1-2.1 1.4 1.4 2.8-2.8-1.4-1.4zM8 14l2 2-6.4 6.4-2-2z"/></svg></div>
      <input id="rech" placeholder="Recherche…" value="${filtres.txt}" aria-label="Rechercher un objet">
      <div class="solde">${A ? '<span class="troph" style="font-size:3vh">🏆</span>' : '<span class="piece" style="width:3vh;height:3vh"></span>'}${fmt(solde)}</div></div>
    <div class="filtres">
      <select id="fCat" aria-label="Catégorie">${opt('tout', 'Catégorie : tout', filtres.cat)}${opt('arme', 'Armes', filtres.cat)}${opt('casque', 'Armure de tête', filtres.cat)}${opt('plastron', 'Armure de poitrine', filtres.cat)}${opt('bottes', 'Armure de pieds', filtres.cat)}${opt('potion', 'Consommable', filtres.cat)}${opt('butin', 'Butin', filtres.cat)}</select>
      <select id="fNiv" aria-label="Niveau">${opt('tout', 'Niveau : tout', filtres.niv)}${[1, 2, 3, 4, 5, 6, 7, 8].map(n => opt(n, 'Niveau ' + n, filtres.niv)).join('')}</select>
      <select id="fQ" aria-label="Qualité">${opt('tout', 'Qualité : toute', filtres.q)}${QUALITES.map(q => opt(q.id, q.nom, filtres.q)).join('')}</select>
    </div>
    <div class="mCorps"><div class="mListe"><h3>${A ? 'Boutique des trophées' : ongletM === 'achat' ? 'Acheter sur le Marché' : 'Vendre au Marché'}</h3>${A ? '<p class="sousA">Équipement d’arène, du T5 au T8. Chaque pièce a un style (Offensif, Défensif, Équilibré), un sort qui lui est propre et +10 % contre les joueurs. Le niveau de maîtrise reste requis pour le porter.</p>' : ''}
      <div class="lignes">${liste.length ? liste.map(it => `<div class="ligne"><button data-v="${it.id}" style="border:0;background:none;padding:0">${htmlCase(it)}</button>
        <div class="nomL" style="color:${it.tier ? shade(couleurObjet(it)) : '#3a2312'}">${nomObjet(it)}<small>${categorieLabel(it)}${it.tier ? ' · ' + (it.arene ? VARIANTES[it.arene].style : QUALITES[it.q].nom) + ' · Puissance ' + puissanceObjet(it) + ' · Niv. ' + niveauRequis(it) : ''}</small></div>
        <div class="prix">${icone}${fmt(prix(it))}</div>
        <button class="btn" data-${ongletM === 'vente' ? 'sell' : 'buy'}="${it.id}" ${ongletM !== 'vente' && prix(it) > solde ? 'disabled' : ''}>${ongletM === 'vente' ? 'Vendre' : 'Acheter'}</button></div>`).join('')
        : `<div class="vide-liste">${ongletM === 'achat' ? 'Rien ne correspond à ces filtres.' : 'Ton sac ne contient rien à vendre avec ces filtres.'}</div>`}</div>
      ${ongletM === 'vente' && j.sac.some(i => i.cat === 'butin') ? '<div style="padding-top:1vh;text-align:right"><button class="btn or" id="venteButin">Vendre tout le butin sans valeur</button></div>' : ''}
    </div>
    <div class="onglets"><button data-o="achat" class="${ongletM === 'achat' ? 'actif' : ''}">ACHAT</button><button data-o="vente" class="${ongletM === 'vente' ? 'actif' : ''}">VENTE</button><button data-o="arene" class="arene ${A ? 'actif' : ''}">ARÈNE</button></div></div></div>`;
  const m = $('#marche');
  m.querySelector('[data-x]').onclick = () => { m.hidden = true; api.son('close_001', 0.4); };
  m.querySelector('#fCat').onchange = (e) => { filtres.cat = e.target.value; UI.rendreMarche(); };
  m.querySelector('#fNiv').onchange = (e) => { filtres.niv = e.target.value; UI.rendreMarche(); };
  m.querySelector('#fQ').onchange = (e) => { filtres.q = e.target.value; UI.rendreMarche(); };
  const r = m.querySelector('#rech'); r.oninput = (e) => { filtres.txt = e.target.value; clearTimeout(UI._rt); UI._rt = setTimeout(() => { UI.rendreMarche(); const n = $('#rech'); n.focus(); n.setSelectionRange(n.value.length, n.value.length); }, 350); };
  m.querySelectorAll('[data-o]').forEach(b => b.onclick = () => { ongletM = b.dataset.o; UI.rendreMarche(); api.son('click_001', 0.4); });
  const trouve = (id) => source.find(i => i.id == id);
  m.querySelectorAll('[data-v]').forEach(b => b.onclick = () => UI.fiche(trouve(b.dataset.v), ongletM));
  m.querySelectorAll('[data-buy]').forEach(b => b.onclick = () => { A ? api.acheterArene(trouve(b.dataset.buy)) : api.acheter(trouve(b.dataset.buy)); UI.rendreMarche(); });
  m.querySelectorAll('[data-sell]').forEach(b => b.onclick = () => { api.vendre(+b.dataset.sell); UI.rendreMarche(); });
  const vb = m.querySelector('#venteButin'); if (vb) vb.onclick = () => { api.vendreButin(); UI.rendreMarche(); };
};

// ---------------- Portail ----------------
UI.menuPortail = () => {
  const j = api.etat(); const ip = statsHeros(j.equip).ip;
  $('#portailMenu').innerHTML = `<div class="cadreP"><button class="fermer" data-x aria-label="Fermer">×</button>
    <h2>La Brèche Écarlate</h2><div class="sous">Quatre gardiens, quatre coffres. La couleur du coffre se voit en entrant ; il ne s’ouvre qu’une fois son gardien tombé.</div>
    <div class="modes">${MODES.map(m => {
      const ok = ip >= m.ipConseil;
      return `<div class="mode" style="--c:${m.couleur}"><div class="niv">NIVEAU ${m.id + 1}</div><h3>${m.nom}</h3><div class="lieu">${m.lieu}</div>
      <div class="tiers">${Array.from({ length: m.tiers[1] - m.tiers[0] + 1 }, (_, i) => m.tiers[0] + i).map(t => `<span style="background:${TIERS[t].color}">T${t}</span>`).join('')}</div>
      <p>${m.texte}</p><div class="ipl"><span>Puissance conseillée</span><b>${m.ipConseil}</b></div><div class="ipl"><span>Ta puissance</span><b class="${ok ? 'ok' : 'ko'}">${ip}</b></div>
      <button class="btn ${ok ? 'or' : ''}" data-m="${m.id}">${ok ? 'Entrer' : 'Entrer quand même'}</button></div>`;
    }).join('')}</div></div>`;
  const inv = document.createElement('div'); inv.className = 'invasion';
  inv.innerHTML = `<div><h4>Être envahi</h4><label class="bascule"><input type="checkbox" id="accInv" ${j.accepteInvasion ? 'checked' : ''}><span>Ouvrir mon monde aux invasions</span></label>
    <p>+25 % d’argent dans les coffres. Un joueur peut surgir dans ton donjon. S’il te tue, il emporte tout ton équipement porté.</p></div>
    <div><h4>Envahir</h4><p>Entre dans le donjon d’un joueur de puissance proche. Tue-le et choisis ce que tu prends dans son équipement. Meurs et tu perds le tien.</p>
    <button class="btn" data-envahir>Envahir un joueur</button></div>`;
  $('#portailMenu .cadreP').appendChild(inv);
  inv.querySelector('#accInv').onchange = (e) => api.accepterInvasion(e.target.checked);
  inv.querySelector('[data-envahir]').onclick = () => { $('#portailMenu').hidden = true; api.envahir(); };
  const p = $('#portailMenu'); p.hidden = false; api.son('forceField_000', 0.5);
  p.querySelector('[data-x]').onclick = () => (p.hidden = true);
  p.querySelectorAll('[data-m]').forEach(b => b.onclick = () => { p.hidden = true; api.entrer(+b.dataset.m); });
};

// ---------------- Butin d'un coffre ----------------
UI.butin = (couleur, loot, cb) => {
  const c = COFFRES.find(x => x.id === couleur);
  $('#butin').innerHTML = `<div class="cadreB parchemin" style="box-shadow:0 0 80px ${c.color}88, inset 0 0 0 2px #b78f55"><h2 style="color:${shade(c.color)}">${c.nom}</h2>
    <div style="font-size:2vh;color:#6a4a2e">${c.desc}</div>
    <div class="argentG"><span class="piece" style="width:3vh;height:3vh"></span>+ ${fmt(loot.argent)}</div>
    <div class="lootGrille">${loot.objets.map((it, i) => `<button class="item" data-i="${i}" style="animation-delay:${0.25 + i * 0.22}s;border:0;background:none;padding:0">${htmlCase(it)}<span style="color:${it.tier ? shade(couleurObjet(it)) : '#3a2312'}">${nomObjet(it)}${it.tier ? ` (${TIERS[it.tier].roman})` : ''}</span></button>`).join('')}</div>
    ${loot.allie ? `<div class="partAllie"><b>Part de ${loot.allie.nom}</b> · ${fmt(loot.allie.argent)} d’argent${loot.allie.objets.length ? ' · ' + loot.allie.objets.map(o => nomObjet(o) + (o.tier ? ` (${TIERS[o.tier].roman})` : '')).join(', ') : ''}</div>` : ''}
    <button class="btn or" data-ok>Prendre ma part</button></div>`;
  const b = $('#butin'); b.hidden = false;
  if (!loot.allie) b.querySelector('[data-ok]').textContent = 'Tout prendre';
  b.querySelectorAll('[data-i]').forEach(e => e.onclick = () => UI.fiche(loot.objets[+e.dataset.i], 'apercu'));
  b.querySelector('[data-ok]').onclick = () => { b.hidden = true; cb(); };
};

UI.mort = (txt, cb) => {
  $('#mort').innerHTML = `<div style="display:flex;flex-direction:column;align-items:center;gap:2vh"><h2>Tu es tombé</h2><p>${txt}</p><button class="btn or" data-ok>Revenir sur la Place</button></div>`;
  const m = $('#mort'); m.hidden = false; m.querySelector('[data-ok]').onclick = () => { m.hidden = true; cb(); };
};

UI.reglages = () => {
  const r = $('#regl');
  r.innerHTML = `<div class="reglages parchemin"><button class="fermer" data-x aria-label="Fermer">×</button><h2>Réglages</h2>
    <label>Qualité graphique <select id="rQ" class="btn gris">${[['auto', 'Automatique (conseillé)'], ['haute', 'Haute : lueurs et ombres'], ['moyenne', 'Moyenne : ombres, sans lueurs'], ['basse', 'Basse : fluidité maximale']].map(([v, l]) => `<option value="${v}" ${G.qualite === v ? 'selected' : ''}>${l}</option>`).join('')}</select></label>
    <label>Sons <input type="checkbox" id="rS" ${G.son ? 'checked' : ''} style="width:3vh;height:3vh"></label>
    <label>Plein écran <button class="btn gris" id="rF">Activer</button></label>
    <label>Sauvegarde <button class="btn" id="rR">Effacer et recommencer</button></label>
    <p id="rConf" style="font-size:2vh;margin:0" hidden>Touche encore pour confirmer : tout ton équipement sera perdu.</p></div>`;
  r.hidden = false;
  r.querySelector('[data-x]').onclick = () => (r.hidden = true);
  r.querySelector('#rQ').onchange = (e) => api.qualite(e.target.value);
  r.querySelector('#rS').onchange = (e) => { G.son = e.target.checked; };
  r.querySelector('#rF').onclick = () => { document.documentElement.requestFullscreen?.().catch(() => {}); };
  let n = 0; r.querySelector('#rR').onclick = () => { if (++n === 1) { r.querySelector('#rConf').hidden = false; return; } api.reset(); };
};

// ---------------- Dépouille d'un joueur vaincu ----------------
UI.depouille = (nom, ip, objets, argent, cb) => {
  const choix = new Set(objets.map(o => o.id));
  const b = $('#butin');
  const rendre = () => {
    b.innerHTML = `<div class="cadreB parchemin depouille" style="box-shadow:0 0 80px #ff2a2a66, inset 0 0 0 2px #b78f55"><h2 style="color:#8a1410">Dépouille de ${nom}</h2>
      <div style="font-size:2vh;color:#6a4a2e">Puissance ${ip} · Touche un objet pour le garder ou le laisser.</div>
      <div class="argentG"><span class="piece" style="width:3vh;height:3vh"></span>+ ${Math.round(argent).toLocaleString('fr-FR')}</div>
      <div class="lootGrille">${objets.map((it, i) => `<div class="item ${choix.has(it.id) ? 'on' : ''}" data-i="${i}" style="animation-delay:${0.15 + i * 0.15}s">${htmlCase(it)}<span style="color:${shade(couleurObjet(it))}">${nomObjet(it)} (${TIERS[it.tier].roman})</span><span class="coche">${choix.has(it.id) ? '✓ Je prends' : 'Je laisse'}</span><button class="det" data-d="${i}">Détails</button></div>`).join('')}</div>
      <div class="actions" style="justify-content:center"><button class="btn gris" data-rien>Ne rien prendre</button><button class="btn" data-tout>Tout prendre</button><button class="btn or" data-sel>Prendre la sélection (${choix.size})</button></div></div>`;
    b.querySelectorAll('[data-i]').forEach(e => e.onclick = (ev) => { if (ev.target.dataset.d !== undefined) return; const it = objets[+e.dataset.i]; choix.has(it.id) ? choix.delete(it.id) : choix.add(it.id); api.son('click_001', 0.4); rendre(); });
    b.querySelectorAll('[data-d]').forEach(e => e.onclick = (ev) => { ev.stopPropagation(); UI.fiche(objets[+e.dataset.d], 'apercu'); });
    const fin = (liste) => { b.hidden = true; cb(liste); };
    b.querySelector('[data-rien]').onclick = () => fin([]);
    b.querySelector('[data-tout]').onclick = () => fin(objets);
    b.querySelector('[data-sel]').onclick = () => fin(objets.filter(o => choix.has(o.id)));
  };
  rendre(); b.hidden = false;
};
UI.flashInvasion = () => { const d = document.createElement('div'); d.id = 'flashInv'; $('#jeu').appendChild(d); setTimeout(() => d.remove(), 2500); };

// ---------------- Maîtrise ----------------
function htmlMaitrise(j) {
  const portes = new Set(['arme', 'casque', 'plastron', 'bottes'].map(s => j.equip[s] && j.equip[s].type).filter(Boolean));
  return `<div class="maitrise">${MAITRISES.map(m => {
    const d = j.maitrise[m.id]; const need = xpPour(d.niv); const k = d.niv >= 100 ? 1 : d.xp / need;
    const tmax = tierMaxPour(d.niv); const suiv = NIVEAU_REQUIS.findIndex((n, i) => i > 0 && n > d.niv);
    const it = { cat: m.cat, type: m.id, tier: tmax, q: 0 };
    const info = d.niv >= 100 ? 'Maîtrise complète' : suiv > 0 ? `T${suiv} au niveau ${NIVEAU_REQUIS[suiv]}` : `Bonus +2 % par niveau jusqu’au 100`;
    return `<div class="mLigne ${portes.has(m.id) ? 'porte' : ''}">
      <div class="mIco">${htmlCase(it)}</div>
      <div class="mTxt"><div class="mNom">${m.nom}${portes.has(m.id) ? '<span class="pastille">porté</span>' : ''}</div>
        <div class="mBarre"><i style="width:${(k * 100).toFixed(1)}%"></i><span>${d.niv >= 100 ? 'MAX' : fmt(d.xp) + ' / ' + fmt(need) + ' XP'}</span></div>
        <div class="mInfo">Porte jusqu’au <b style="color:${shade(TIERS[tmax].color)}">T${tmax}</b> · Prochain palier : ${info}${d.niv > 1 ? ` · <b>+${(bonusMaitrise(d.niv) * 100).toFixed(1).replace('.', ',')} % de puissance</b>` : ''}</div></div>
      <div class="mNiv"><small>NIV.</small>${d.niv}</div></div>`;
  }).join('')}
  <p class="mAide">Seules les pièces que tu portes gagnent de l’expérience. Chaque niveau ajoute 0,2 % de puissance brute à ce type de pièce, puis 2 % par niveau du 90 au 100.</p></div>`;
}

// ---------------- Arène ----------------
UI.menuArene = (groupe) => {
  const j = api.etat(); const ip = statsHeros(j.equip).ip;
  const p = $('#portailMenu');
  p.innerHTML = `<div class="cadreP arene"><button class="fermer" data-x aria-label="Fermer">×</button>
    <h2>Arène des Échos</h2><div class="sous">Combats entre joueurs. Chaque victoire rapporte 🏆 100 trophées et de l’expérience. Ton équipement ne se perd pas ici.</div>
    <div class="modes deux">
      <div class="mode" style="--c:#b05aff"><div class="niv">DUEL</div><h3>1 contre 1</h3><p>Un adversaire de puissance proche. Rien que toi et lui.</p>
        <div class="ipl"><span>Ta puissance</span><b>${ip}</b></div><button class="btn or" data-f="1v1">Trouver un adversaire</button></div>
      <div class="mode" style="--c:#4fd1ff"><div class="niv">ÉQUIPE</div><h3>2 contre 2</h3><p>${groupe ? `Avec <b>${groupe.nom}</b> (⚔ ${groupe.ip}), ton coéquipier de groupe.` : 'Tu n’as pas de groupe : un coéquipier sera trouvé pour toi. Touche un joueur sur la Place pour former un groupe.'}</p>
        <div class="ipl"><span>Équipe</span><b>${groupe ? 'Groupe' : 'Aléatoire'}</b></div><button class="btn or" data-f="2v2">Trouver un combat</button></div>
    </div>
    <div class="barreTroph"><div><span class="troph" style="font-size:3.4vh">🏆</span><b>${fmt(j.trophees || 0)}</b> trophées</div><button class="btn" data-shop>Boutique des trophées</button></div></div>`;
  p.hidden = false; api.son('forceField_000', 0.5, 0.8);
  p.querySelector('[data-x]').onclick = () => (p.hidden = true);
  p.querySelectorAll('[data-f]').forEach(b => b.onclick = () => { p.hidden = true; api.arene(b.dataset.f); });
  p.querySelector('[data-shop]').onclick = () => { p.hidden = true; UI.ouvrirMarche('arene'); };
};
UI.resultatArene = (r, cb) => {
  const m = $('#mort');
  m.innerHTML = `<div class="resultat ${r.victoire ? 'gagne' : 'perdu'}"><h2>${r.victoire ? 'Victoire' : 'Défaite'}</h2>
    <div class="recap">${r.lignes.map(l => `<div>${l}</div>`).join('')}</div>
    <button class="btn or" data-ok>Revenir sur la Place</button></div>`;
  m.hidden = false; m.querySelector('[data-ok]').onclick = () => { m.hidden = true; cb(); };
};
UI.compteur = (n) => { const d = document.createElement('div'); d.className = 'compteur'; d.textContent = n; $('#jeu').appendChild(d); setTimeout(() => d.remove(), 900); };

// ---------------- Groupe et cible ----------------
UI.cadreAutre = (data, opts = {}) => {
  const c = $('#cadreAutre');
  if (!data) { c.hidden = true; c._nom = null; return; }
  c.hidden = false; c.classList.toggle('membre', !!opts.membre);
  if (c._nom !== data.nom || c._membre !== !!opts.membre) {
    c._nom = data.nom; c._membre = !!opts.membre;
    c.querySelector('.nomA').innerHTML = `${data.nom}<span>⚔ ${data.ip}</span>`;
    c.querySelector('.etiq').textContent = opts.membre ? 'GROUPE' : 'JOUEUR';
    bustePersonnage(data.modele, c.querySelector('canvas'), opts.membre ? '#2a5a7a' : '#5a3a5a');
  }
  const pv = opts.pv ?? 1, en = opts.en ?? 1;
  c.querySelector('.pvA').style.transform = `scaleX(${Math.max(0, pv)})`;
  c.querySelector('.enA').style.transform = `scaleX(${Math.max(0, en)})`;
  c.classList.toggle('ko', pv <= 0);
};
UI.menuJoueur = (data, estMembre, aUnGroupe) => {
  const j = api.etat();
  const d = $('#dialogue');
  d.innerHTML = `<div class="boiteDial bois"><button class="fermer" data-x aria-label="Fermer">×</button><div class="visage"><canvas width="128" height="128"></canvas></div>
  <div style="min-width:0;flex:1"><h3>${data.nom} <span style="color:#7fb2ff;font-size:2.2vh">${data.guilde}</span> <span class="ipb2">⚔ ${data.ip}</span></h3>
  <div class="choix" style="margin:1.4vh 0">
    ${estMembre ? '<button class="btn gris" data-a="exclure">Exclure du groupe</button>' : `<button class="btn or" data-a="inviter">${aUnGroupe ? 'Remplacer mon coéquipier' : 'Inviter dans le groupe'}</button>`}
  </div>
  <div class="duelBloc"><b>Proposer un duel à l’arène</b> · mise :
    <div class="mises">${[0, 100, 500, 1000, 5000].map((m, i) => `<button class="mise ${i === 1 ? 'actif' : ''}" data-m="${m}" ${m > j.argent ? 'disabled' : ''}>${m ? fmt(m) : 'Sans mise'}</button>`).join('')}</div>
    <button class="btn" data-a="duel">Défier ${data.nom}</button><p class="aide">Le gagnant remporte les deux mises.</p></div></div></div>`;
  d.hidden = false; bustePersonnage(data.modele, d.querySelector('canvas'), '#4a3a5a');
  let mise = Math.min(100, j.argent >= 100 ? 100 : 0);
  d.querySelectorAll('.mise').forEach(b => { b.classList.toggle('actif', +b.dataset.m === mise); b.onclick = () => { mise = +b.dataset.m; d.querySelectorAll('.mise').forEach(x => x.classList.toggle('actif', x === b)); api.son('click_001', 0.4); }; });
  d.querySelector('[data-x]').onclick = () => (d.hidden = true);
  d.querySelectorAll('[data-a]').forEach(b => b.onclick = () => {
    d.hidden = true;
    if (b.dataset.a === 'inviter') api.inviter(data);
    if (b.dataset.a === 'exclure') api.exclure();
    if (b.dataset.a === 'duel') api.duel(data, mise);
  });
};

// ---------------- Îles ----------------
const icoModeles = {};
export function iconeModele(cle) {
  if (icoModeles[cle]) return icoModeles[cle];
  if (!icoR) initIcones();
  const m = G.assets[cle].scene.clone(true);
  const grp = new THREE.Group(); grp.add(m);
  return (icoModeles[cle] = rendreGroupe(grp, 'armure'));
}
const RES_ICO = { bois: 'Wood_Log_Stack', minerai: 'Iron_Nuggets', recolte: 'proc_citrouille' };
const RES_NOM = { bois: 'Bois', minerai: 'Minerai', recolte: 'Récoltes' };
const ICO_TYPE = { bois: 'Tree_1_A', mine: 'Gold_Nuggets', cueillette: 'proc_baies' };
const fmtCourt = (n) => n >= 1e6 ? (n / 1e6).toLocaleString('fr-FR', { maximumFractionDigits: 1 }) + ' M' : n >= 1e3 ? Math.round(n / 1e3).toLocaleString('fr-FR') + ' k' : fmt(n);
function dans(ts) { const m = Math.max(0, Math.round((ts - Date.now()) / 60000)); return m >= 60 ? `${Math.floor(m / 60)} h ${String(m % 60).padStart(2, '0')}` : `${m} min`; }
function ouvrir(id) { const p = $(id); p.hidden = false; p.onclick = (e) => { if (e.target === p) p.hidden = true; }; return p; }

UI.menuIles = (info) => {
  const p = ouvrir('#portailMenu');
  const mes = info.iles.length ? info.iles.map(({ ile, cap, total, prodHeure, assaut }) => {
    const T = ILE_TYPES[ile.type];
    return `<div class="carteIle" style="--c:${T.couleur}"><img src="${iconeModele(ICO_TYPE[ile.type])}" alt=""><div class="txtIle"><b>${ile.nom}</b><small>${ILE_TAILLES[ile.taille].nom} · niveau ${ile.niveau} · ${fmt(ile.coffre[T.res] || 0)} ${T.label}${cap < Infinity ? ' / ' + fmt(cap) : ''} · ${fmt(prodHeure)}/h · assaut dans ${dans(assaut)}</small></div><button class="btn or" data-aller="${ile.id}">Y aller</button></div>`;
  }).join('') : '<p class="aideIle">Tu n’as pas encore d’île. Choisis son type avec soin : chacune ne produit qu’une seule ressource.</p>';
  const achat = Object.entries(ILE_TYPES).map(([k, T]) => `<div class="typeIle" style="--c:${T.couleur}"><img src="${iconeModele(ICO_TYPE[k])}" alt=""><h4>${T.nom}</h4><p>${T.desc}</p><div class="prixRes"><img src="${iconeModele(RES_ICO[T.res])}" alt="">${T.label} · ${T.prix} pièces l’unité</div>
    <div class="tailles">${ILE_TAILLES.map((t, i) => `<button class="taille" data-type="${k}" data-taille="${i}" ${info.argent < t.prix ? 'disabled' : ''}><b>${t.nom}</b><span>${fmtCourt(t.prix)}</span></button>`).join('')}</div></div>`).join('');
  p.innerHTML = `<div class="cadreP iles"><button class="fermer" data-x aria-label="Fermer">×</button>
    <h2>Les Îles d’Aldric</h2><div class="sous">Achète une île, construis, fais travailler tes ouvriers… et défends ton coffre. Ton argent : <b>${fmt(info.argent)}</b></div>
    <h3 class="sec">Tes îles</h3><div class="mesIles">${mes}</div>
    <h3 class="sec">Acheter une île</h3><div class="typesIle">${achat}</div>
    <div class="barreTroph pille"><div><b>Piller une île</b> — attaque l’île d’un autre joueur, élimine ses 3 gardes et son champion, puis vide son coffre.</div><button class="btn" data-piller>Partir piller (⚔ ${info.ip})</button></div></div>`;
  p.querySelector('[data-x]').onclick = () => (p.hidden = true);
  p.querySelectorAll('[data-aller]').forEach(b => b.onclick = () => { p.hidden = true; api.allerIle(b.dataset.aller); });
  p.querySelectorAll('[data-type]').forEach(b => b.onclick = () => {
    const t = ILE_TAILLES[+b.dataset.taille], T = ILE_TYPES[b.dataset.type];
    b.closest('.typeIle').querySelector('p').innerHTML = `<b>${t.nom} ${T.nom.replace('Île', '').trim()}</b> pour ${fmt(t.prix)} pièces. <button class="btn or" data-confirm>Confirmer l’achat</button>`;
    b.closest('.typeIle').querySelector('[data-confirm]').onclick = () => { p.hidden = true; api.acheterIle(b.dataset.type, +b.dataset.taille); };
  });
  p.querySelector('[data-piller]').onclick = () => { p.hidden = true; api.piller(); };
  api.son('forceField_000', 0.4, 1.4);
};

UI.menuIntendant = (ile, info, onglet = 'accueil') => {
  const T = ILE_TYPES[ile.type];
  const d = ouvrir('#portailMenu');
  const res = (k) => `<div class="resL"><img src="${iconeModele(RES_ICO[k])}" alt=""><b>${fmt(ile.coffre[k] || 0)}</b> ${RES_NOM[k]} <span>(${ILE_TYPES[{ bois: 'bois', minerai: 'mine', recolte: 'cueillette' }[k]].prix}/u)</span>
    <button class="btn gris" data-v="${k}" data-p="0.5" ${(ile.coffre[k] || 0) < 2 ? 'disabled' : ''}>Vendre la moitié</button><button class="btn" data-v="${k}" data-p="1" ${(ile.coffre[k] || 0) < 1 ? 'disabled' : ''}>Tout vendre</button></div>`;
  const ong = { accueil: 'Règles', coffre: 'Coffre', ameliorer: 'Améliorer', ouvriers: 'Ouvriers', securite: 'Sécurité' };
  let corps = '';
  if (onglet === 'accueil') corps = `<div class="regles">
    <p><b>Bienvenue sur ${ile.nom}.</b> Je suis Oswin, ton intendant. Voici comment tourne ton île :</p>
    <ul><li><b>Récolte</b> : tu peux ${T.verbe.toLowerCase()} toi-même ici, jamais chez les autres. Tout va dans le coffre.</li>
    <li><b>Ouvriers</b> : chaque <b>maison d’ouvrier</b> te permet d’en invoquer un. Ils travaillent même quand tu es ailleurs (12 h maximum).</li>
    <li><b>Constructions</b> : chaque achat (maison, route, décor) ajoute <b>+0,1 %</b> de vitesse à tes ouvriers.</li>
    <li><b>Ta maison</b> : sans elle, le coffre est limité à ${fmt(1000 * (1 + ile.taille))}. Avec elle, il devient illimité.</li>
    <li><b>Niveaux</b> : livre-moi des ressources pour agrandir l’île : plus d’emplacements, +5 % de vitesse par niveau.</li>
    <li><b>Assaut des bandits</b> : chaque jour à ${HEURE_ASSAUT} h. Si tu es là, tu gardes tout leur butin. Absent sans gardes : ils emportent <b>70 %</b> du coffre. Absent avec gardes : tu ne touches que 10 % de leur butin.</li>
    <li><b>Pillards</b> : d’autres joueurs passent parfois. Tu peux y aller toi-même ou laisser tes gardes s’en charger.</li></ul></div>`;
  if (onglet === 'coffre') corps = `<div class="coffreIle"><p>Capacité : <b>${info.cap < Infinity ? fmt(info.total) + ' / ' + fmt(info.cap) : 'illimitée'}</b> · Production : <b>${fmt(info.prodHeure)} ${T.label}/h</b> · Vitesse ×${info.vitesse.toFixed(3).replace('.', ',')}</p>${['bois', 'minerai', 'recolte'].map(res).join('')}</div>`;
  if (onglet === 'ameliorer') {
    const k = T.res; const pct = info.besoin ? Math.min(1, (ile.livre || 0) / info.besoin) : 1;
    corps = info.besoin ? `<div class="amelio"><p>Niveau <b>${ile.niveau}</b> → <b>${ile.niveau + 1}</b> : livre ${fmt(info.besoin)} ${T.label.toLowerCase()}.</p>
      <div class="mBarre gros"><i style="width:${pct * 100}%"></i><span>${fmt(ile.livre || 0)} / ${fmt(info.besoin)}</span></div>
      <p>Au niveau suivant : +2 emplacements de construction, +5 % de vitesse${ile.niveau + 1 === 4 || ile.niveau + 1 === 7 ? ', et l’île s’agrandit d’un anneau de terres' : ''}.</p>
      <button class="btn or" data-livrer ${(ile.coffre[k] || 0) ? '' : 'disabled'}>Livrer depuis le coffre (${fmt(ile.coffre[k] || 0)})</button></div>` : '<p>Ton île a atteint son niveau maximum.</p>';
  }
  if (onglet === 'ouvriers') corps = `<div class="ouvr"><p>Ouvriers au travail : <b>${Math.min(ile.ouvriers || 0, info.maxOuv)}</b> / ${info.maxOuv} (une maison = un ouvrier).</p>
    <div class="choix"><button class="btn gris" data-o="-1">Renvoyer un ouvrier</button><button class="btn or" data-o="1" ${(ile.ouvriers || 0) >= info.maxOuv ? 'disabled' : ''}>Invoquer un ouvrier</button></div>
    <p class="aideIle">Chaque ouvrier rapporte environ ${fmt(Math.round(450 * info.vitesse))} ${T.label.toLowerCase()} par heure. Construis des maisons sur les emplacements dorés pour en avoir plus.</p></div>`;
  if (onglet === 'securite') corps = `<div class="secu"><p>Tes gardes défendent l’île contre les bandits et les pillards. Leur puissance suit <b>la tienne en temps réel</b>.</p>
    ${GARDES_ILE.map((g, i) => `<div class="gardeL ${i < (ile.gardes || 0) ? 'pris' : ''}"><b>${g.nom}</b><span>${Math.round(g.ratio * 100)} % de ta puissance</span>${i < (ile.gardes || 0) ? '<em>En poste</em>' : `<button class="btn" data-g="${i}" ${i !== (ile.gardes || 0) || info.argent < g.prix ? 'disabled' : ''}>Recruter · ${fmtCourt(g.prix)}</button>`}</div>`).join('')}
    <div class="gardeL champ ${ile.champion ? 'pris' : ''}"><b>${CHAMPION_ILE.nom}</b><span>Boss final · ${Math.round(CHAMPION_ILE.ratio * 100)} % de ta puissance</span>${ile.champion ? '<em>En poste</em>' : `<button class="btn" data-g="champion" ${info.argent < CHAMPION_ILE.prix ? 'disabled' : ''}>Recruter · ${fmtCourt(CHAMPION_ILE.prix)}</button>`}</div>
    <p class="aideIle">Prochain assaut des bandits : dans ${dans(info.assaut)} (${HEURE_ASSAUT} h).</p></div>`;
  d.innerHTML = `<div class="cadreP intendant"><button class="fermer" data-x aria-label="Fermer">×</button>
    <div class="teteInt"><div class="visage"><canvas width="128" height="128"></canvas></div><div><h2>Oswin, intendant</h2><div class="sous">${ile.nom} · ${ILE_TAILLES[ile.taille].nom} · niveau ${ile.niveau}</div></div></div>
    <div class="ongletsInv ongInt">${Object.entries(ong).map(([k, l]) => `<button data-t="${k}" class="${k === onglet ? 'actif' : ''}">${l}</button>`).join('')}</div>
    <div class="corpsInt">${corps}</div></div>`;
  bustePersonnage('Mage', d.querySelector('canvas'), '#5a4a2a');
  d.querySelector('[data-x]').onclick = () => (d.hidden = true);
  const re = (o) => UI.menuIntendant(ile, api.infosIle ? api.infosIle(ile) : info, o);
  d.querySelectorAll('[data-t]').forEach(b => b.onclick = () => { api.son('click_001', 0.4); re(b.dataset.t); });
  d.querySelectorAll('[data-v]').forEach(b => b.onclick = () => { api.ile.vendre(ile, b.dataset.v, +b.dataset.p); re('coffre'); });
  const l = d.querySelector('[data-livrer]'); if (l) l.onclick = () => { d.hidden = true; api.ile.livrer(ile); };
  d.querySelectorAll('[data-o]').forEach(b => b.onclick = () => { api.ile.invoquer(ile, +b.dataset.o); re('ouvriers'); });
  d.querySelectorAll('[data-g]').forEach(b => b.onclick = () => { d.hidden = true; api.ile.garde(ile, b.dataset.g === 'champion' ? 'champion' : +b.dataset.g); });
};

UI.menuConstruction = (ile, plot, info) => {
  const d = ouvrir('#portailMenu');
  const T = ILE_TYPES[ile.type];
  const liste = Object.entries(BATIMENTS).map(([k, b]) => {
    const deja = b.unique && ile.batiments.some(x => x.t === k);
    const mod = k === 'atelier' ? T.atelier : k === 'jardin' ? 'flower_redA' : b.modele;
    return `<div class="batL ${deja ? 'pris' : ''}"><img src="${iconeModele(mod)}" alt=""><div><b>${b.nom}${k === 'atelier' ? ` (${{ bois: 'scierie', mine: 'mine', cueillette: 'étal' }[ile.type]})` : ''}</b><small>${b.desc} +0,1 % de vitesse.</small></div>
      ${deja ? '<em>Construit</em>' : `<button class="btn ${info.argent >= info.prix[k] ? 'or' : ''}" data-b="${k}" ${info.argent < info.prix[k] ? 'disabled' : ''}>${fmtCourt(info.prix[k])}</button>`}</div>`;
  }).join('');
  d.innerHTML = `<div class="cadreP construction"><button class="fermer" data-x aria-label="Fermer">×</button>
    <h2>Construire</h2><div class="sous">Emplacement ${plot + 1} / ${info.nbEmpl} · Ton argent : <b>${fmt(info.argent)}</b> · Vitesse actuelle ×${info.vitesse.toFixed(3).replace('.', ',')}</div>
    <div class="listeBat">${liste}</div></div>`;
  d.querySelector('[data-x]').onclick = () => (d.hidden = true);
  d.querySelectorAll('[data-b]').forEach(b => b.onclick = () => { d.hidden = true; api.construire(ile, plot, b.dataset.b); });
};

UI.alerteRaid = (data, ile, cb) => {
  const d = $('#mort');
  let reste = 45;
  d.innerHTML = `<div class="alerteRaid"><div class="sirene">⚠</div><h2>Ton île est pillée !</h2>
    <p><b>${data.nom}</b> <span style="color:#7fb2ff">${data.guilde}</span> <span class="ipb2">⚔ ${data.ip}</span> vide le coffre de <b>${ile.nom}</b>.</p>
    <div class="choix" style="justify-content:center"><button class="btn or" data-c="y aller">J’y vais, je le chasse moi-même</button><button class="btn gris" data-c="gardes">Je confie l’île à mes gardes</button></div>
    <p class="aideIle" id="raidTimer">Sans réponse, tes gardes s’en chargent dans ${reste} s.</p></div>`;
  d.hidden = false; UI.flashInvasion();
  const fin = (c) => { clearInterval(iv); d.hidden = true; cb(c); };
  const iv = setInterval(() => { reste--; const t = document.getElementById('raidTimer'); if (t) t.textContent = `Sans réponse, tes gardes s’en chargent dans ${reste} s.`; if (reste <= 0) fin('gardes'); }, 1000);
  d.querySelectorAll('[data-c]').forEach(b => b.onclick = () => fin(b.dataset.c));
};
UI.rapport = (titre, lignes) => {
  const d = $('#butin');
  d.innerHTML = `<div class="cadreB parchemin"><h2>${titre}</h2>${lignes.map(l => `<p style="font-size:2.3vh;margin:.8vh 0">${l}</p>`).join('')}<button class="btn or" data-ok>Compris</button></div>`;
  d.hidden = false; d.querySelector('[data-ok]').onclick = () => (d.hidden = true);
};
