// Mini-carte (coin haut droit) + grande carte (toucher la mini-carte).
// Fond peint une fois avec les vraies couleurs du sol (routes, lacs, forêts, montagnes) ;
// par-dessus, rafraîchis 4×/s : toi (flèche), tes bâtiments et territoire, villages et capitale, camps et groupes ennemis,
// appels à l'aide qui clignotent, objectif de quête (étoile).
import { THREE, G } from './moteur.js';
import { couleurCarte, VILLAGES, LACS, MONDE, hauteur, foret, CHEMINS } from './monde.js';
import { campsCarte } from './combat.js';
import { territoires, batiments } from './batiments.js';

let C = null, fond = null, mini, grande, ouverte = false, t = 0;
const TAILLE = 2 * MONDE, RES = 220;
const versPx = (x, z, cx, cz, echelle, w) => [w / 2 + (x - cx) * echelle, w / 2 + (z - cz) * echelle];

function peindreFond() {
  fond = document.createElement('canvas'); fond.width = fond.height = RES; const g = fond.getContext('2d'), img = g.createImageData(RES, RES), c = new THREE.Color(), c2 = new THREE.Color();
  for (let j = 0; j < RES; j++) for (let i = 0; i < RES; i++) { const x = -MONDE + (i + 0.5) / RES * TAILLE, z = -MONDE + (j + 0.5) / RES * TAILLE; couleurCarte(x, z, c, c2); const pente = (hauteur(x - 6, z - 6) - hauteur(x + 6, z + 6)) * 0.022, f = foret(x, z); c.offsetHSL(0, 0.05, Math.max(-0.18, Math.min(0.18, pente)) - f * 0.06); /* relief ombré + forêts plus sombres */ const k = (j * RES + i) * 4; img.data[k] = c.r * 255; img.data[k + 1] = c.g * 255; img.data[k + 2] = c.b * 255; img.data[k + 3] = 255; }
  g.putImageData(img, 0, 0);
  { const t = document.createElement('canvas'); t.width = t.height = RES; const tg = t.getContext('2d'); tg.filter = 'blur(1.4px)'; tg.drawImage(fond, 0, 0); g.drawImage(t, 0, 0); } // lisse le motif du sol (sinon des rayures)
  g.strokeStyle = '#b8955e'; g.lineWidth = 1.6; g.lineJoin = 'round'; const px = (v) => (v + MONDE) / TAILLE * RES; for (const L of CHEMINS) { g.beginPath(); L.forEach((p, i) => { const x = px(p.x ?? p[0]), z = px(p.z ?? p[1]); i ? g.lineTo(x, z) : g.moveTo(x, z); }); g.stroke(); } // routes nettes
  g.fillStyle = '#3d7fb0'; for (const L of LACS) { g.beginPath(); g.arc((L.x + MONDE) / TAILLE * RES, (L.z + MONDE) / TAILLE * RES, L.r * 1.05 / TAILLE * RES, 0, 6.29); g.fill(); }
}
function icone(g, x, z, emoji, taille) { g.font = `${taille}px sans-serif`; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(emoji, x, z); }
function dessiner(cv, cx, cz, rayon, grand) {
  const w = cv.width, g = cv.getContext('2d'), e = w / (2 * rayon); g.clearRect(0, 0, w, w); g.save();
  if (!grand) { g.beginPath(); g.arc(w / 2, w / 2, w / 2 - 2, 0, 6.29); g.clip(); }
  // fond : la portion visible de la carte peinte
  const sx = (cx - rayon + MONDE) / TAILLE * RES, sz = (cz - rayon + MONDE) / TAILLE * RES, sw = 2 * rayon / TAILLE * RES; g.imageSmoothingEnabled = true; g.fillStyle = '#2a3a2a'; g.fillRect(0, 0, w, w); g.drawImage(fond, sx, sz, sw, sw, 0, 0, w, w);
  const P = (x, z) => versPx(x, z, cx, cz, e, w), s = Math.max(10, w / (grand ? 34 : 9));
  // ton territoire
  g.strokeStyle = 'rgba(185,138,255,.85)'; g.lineWidth = grand ? 2 : 1.5; g.setLineDash([4, 3]); for (const T of territoires()) { const [x, z] = P(T.x, T.z); g.beginPath(); g.arc(x, z, T.r * e, 0, 6.29); g.stroke(); } g.setLineDash([]);
  for (const b of batiments) { const [x, z] = P(b.g.position.x, b.g.position.z); g.fillStyle = '#c8a8ff'; g.fillRect(x - 2, z - 2, 4, 4); }
  // humains
  for (const V of VILLAGES) { const [x, z] = P(V.x, V.z); icone(g, x, z, V.type === 'ville' ? '🏰' : '🏘️', s * (V.type === 'ville' ? 1.5 : 1.1)); if (grand) { g.font = `bold ${s * 0.75}px Georgia`; g.fillStyle = '#fff'; g.strokeStyle = '#000'; g.lineWidth = 3; g.strokeText(V.nom, x, z + s * 1.2); g.fillText(V.nom, x, z + s * 1.2); } if (V.attaque && (G.t * 3 | 0) % 2) { g.strokeStyle = '#ff3a2a'; g.lineWidth = 3; g.beginPath(); g.arc(x, z, s * 1.1, 0, 6.29); g.stroke(); } }
  // ennemis : camps (crâne / couronne pour un boss), groupes errants (points rouges)
  let ic = 0; for (const c of campsCarte()) { const [x, z] = P(c.x, c.z); ic++; if (c.errant) { g.fillStyle = '#ff4a3a'; g.beginPath(); g.arc(x, z, Math.max(2.5, s * 0.22), 0, 6.29); g.fill(); continue; } icone(g, x, z, c.boss ? '👹' : c.vide ? '✔️' : '💀', s * (c.boss ? 1.1 : 0.85)); if (grand && !c.vide) { g.font = `${s * 0.6}px Georgia`; g.fillStyle = '#ffb0a0'; g.strokeStyle = '#000'; g.lineWidth = 3; const dy = ic % 2 ? s * 0.95 : -s * 0.75; g.strokeText(c.nom + ' · Nv ' + c.niv, x, z + dy); g.fillText(c.nom + ' · Nv ' + c.niv, x, z + dy); /* une étiquette sur deux au-dessus : moins de chevauchements */ } }
  // objectif
  const cible = C.cible(); if (cible) { const [x, z] = P(cible.x, cible.z); icone(g, x, z, '⭐', s * 1.1); }
  g.restore();
  // toi : flèche dans le sens de ta marche
  const J = C.joueur, [jx, jz] = P(J.pos.x, J.pos.z), a = J.perso.root.rotation.y; g.save(); g.translate(jx, jz); g.rotate(-a + Math.PI); g.fillStyle = '#ffe28a'; g.strokeStyle = '#2a1a00'; g.lineWidth = 2; g.beginPath(); const k = grand ? 9 : 7; g.moveTo(0, -k * 1.3); g.lineTo(k * 0.8, k); g.lineTo(0, k * 0.45); g.lineTo(-k * 0.8, k); g.closePath(); g.fill(); g.stroke(); g.restore();
  if (!grand) { g.strokeStyle = 'rgba(255,226,138,.9)'; g.lineWidth = 3; g.beginPath(); g.arc(w / 2, w / 2, w / 2 - 2, 0, 6.29); g.stroke(); g.font = 'bold 12px Georgia'; g.fillStyle = '#ffe28a'; g.textAlign = 'center'; g.fillText('N', w / 2, 13); }
}
export function initCarte(ctx) {
  C = ctx; peindreFond();
  const st = document.createElement('style'); st.textContent = `
#miniCarte{position:absolute;right:calc(1.6vh + env(safe-area-inset-right));top:16vh;width:19vh;height:19vh;border-radius:50%;box-shadow:0 .6vh 2vh rgba(0,0,0,.55);z-index:3;touch-action:none}
#grandeCarte{position:fixed;inset:0;background:rgba(8,6,16,.82);display:none;align-items:center;justify-content:center;z-index:60;flex-direction:column;gap:1.2vh}
#grandeCarte.on{display:flex}#grandeCarte canvas{width:min(84vh,92vw);height:min(84vh,92vw);border:.4vh solid #ffe28a88;border-radius:1.6vh;box-shadow:0 0 4vh #000}
#grandeCarte p{margin:0;font:700 1.8vh var(--f-label);color:#e8dcc8;text-align:center}`; document.head.appendChild(st);
  mini = document.createElement('canvas'); mini.id = 'miniCarte'; mini.width = mini.height = 200; document.getElementById('hud')?.appendChild(mini) ?? document.body.appendChild(mini);
  const fen = document.createElement('div'); fen.id = 'grandeCarte'; grande = document.createElement('canvas'); grande.width = grande.height = 900; fen.appendChild(grande);
  const p = document.createElement('p'); p.textContent = '🏰 capitale · 🏘️ village · 💀 camp ennemi · 👹 boss · ● groupe errant · ⭐ objectif · pointillés violets : ton territoire — touche pour fermer'; fen.appendChild(p); document.body.appendChild(fen);
  mini.addEventListener('pointerdown', (e) => { e.stopPropagation(); ouverte = true; fen.classList.add('on'); dessiner(grande, 0, 0, MONDE, true); });
  fen.addEventListener('pointerdown', () => { ouverte = false; fen.classList.remove('on'); });
}
export function majCarte(dt) {
  if (!C || (t += dt) < 0.25) return; t = 0;
  const J = C.joueur.pos; dessiner(mini, J.x, J.z, 70, false); if (ouverte) dessiner(grande, 0, 0, MONDE, true);
}
