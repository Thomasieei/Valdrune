// ===== Interface : icônes, HUD, inventaire, marché, dialogues =====
import { THREE, G, projeter, creerArc } from './engine.js';
import { arbreDe, pointsTotaux, pointsDepenses, pointsBranche, peutMonter, texteNoeud, ALTS } from './talents.js';
import { svgGlyphe, GLYPHES as SIGNES } from './gestes.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';
import { TIERS, QUALITES, ARMES, ARMURES, BUTINS, SORTS, MODES, COFFRES, MAITRISES, NIVEAU_REQUIS, VARIANTES, EMOTES, TRAITS, RANGS, PTS_RANG, PARCHEMINS, COULEURS_PARCH, BOUTIQUE_PARCH_GRATUITE, ILE_TYPES, ILE_TAILLES, ILE_NIVEAUX, BATIMENTS, GARDES_ILE, CHAMPION_ILE, HEURE_ASSAUT } from './data.js';
import { nomObjet, couleurObjet, statsObjet, sortsObjet, puissanceObjet, valeurObjet, prixVente, categorieLabel, statsHeros, stockMarchand, stockArene, prixTrophees, niveauRequis, peutPorter, niveauDe, xpPour, bonusMaitrise, tierMaxPour, coutEnchant } from './items.js';

const $ = (s) => document.querySelector(s);
const fmt = (n) => Math.round(n).toLocaleString('fr-FR');
export const UI = {};
let api = null;
UI.init = (a) => { api = a; };

// ---------------- Icônes de sorts (SVG) ----------------
const GLYPHES = {
  assassin: '<path d="M22 84 L58 30 L64 34 L28 88 Z"/><path d="M58 30 L80 10 L66 38 Z"/><path d="M78 84 L42 30 L36 34 L72 88 Z" opacity=".75"/><path d="M42 30 L20 10 L34 38 Z" opacity=".75"/><circle cx="50" cy="60" r="5" fill="#ff4a5a"/>',
  triple: '<path d="M14 30 L60 16 L56 24 Z"/><path d="M14 52 L72 38 L68 46 Z"/><path d="M14 74 L86 60 L80 70 Z" fill="#ff8a8a"/>',
  curee: '<path d="M50 8 L58 60 L50 92 L42 60 Z"/><circle cx="50" cy="66" r="10" fill="#ff2a3a"/><path d="M30 26 h40" stroke="#fff" stroke-width="5"/>',
  zephyr: '<path d="M10 64 C30 40 56 34 90 36 C70 42 56 50 46 64 Z"/><path d="M16 80 C34 64 56 60 80 62 C64 68 52 74 44 82 Z" opacity=".7"/><path d="M60 14 l14 10 -16 6z"/>',
  orage: '<path d="M30 86 L52 30 L58 33 L36 89 Z"/><path d="M52 30 C40 20 46 8 62 10 C60 18 66 26 70 30 C64 34 58 34 52 30 Z"/><path d="M70 86 L48 30 L42 33 L64 89 Z" opacity=".7"/><path d="M60 46 L76 46 L66 58 L80 58 L56 80 L64 62 L52 62 Z" fill="#ffe27a"/>',
  tornade: '<path d="M18 22 C40 14 64 14 84 22 C64 30 40 30 22 26 Z"/><path d="M26 38 C42 32 60 32 74 38 C60 44 44 44 30 42 Z"/><path d="M34 54 C46 50 56 50 66 54 C56 58 46 58 38 58 Z"/><path d="M42 68 C48 66 54 66 58 68 C54 72 48 72 44 72 Z"/><path d="M48 80 h6 v10 h-6z"/>',
  titan: '<path d="M50 8 L58 30 L50 26 L42 30 Z"/><path d="M34 34 h32 l-6 22 h-20 z"/><ellipse cx="50" cy="80" rx="38" ry="8" fill="none" stroke="#fff" stroke-width="5"/><ellipse cx="50" cy="80" rx="22" ry="4"/><path d="M14 70 l8 4 M86 70 l-8 4 M26 62 l6 6 M74 62 l-6 6" stroke="#fff" stroke-width="4"/>',
  foudre: '<path d="M58 6 L24 54 H46 L36 94 L78 40 H54 Z"/>',
  ombre: '<path d="M22 84 L60 30 L66 34 L28 88 Z"/><path d="M60 30 L74 12 L70 36 Z"/><path d="M78 84 L40 30 L34 34 L72 88 Z" opacity=".75"/><path d="M40 30 L26 12 L30 36 Z" opacity=".75"/>',
  ombres: '<g><circle cx="50" cy="26" r="11"/><path d="M34 88 C34 58 40 42 50 40 C60 42 66 58 66 88 Z"/></g><g opacity=".55"><circle cx="24" cy="38" r="8"/><path d="M12 88 C12 64 16 52 24 50 C32 52 36 64 36 88 Z"/><circle cx="76" cy="38" r="8"/><path d="M64 88 C64 64 68 52 76 50 C84 52 88 64 88 88 Z"/></g>',
  miroir: '<ellipse cx="50" cy="50" rx="30" ry="40" fill="none" stroke="#fff" stroke-width="6"/><circle cx="42" cy="38" r="8"/><path d="M28 78 C30 60 36 52 42 50 C48 52 54 60 56 78 Z"/><circle cx="62" cy="40" r="7" opacity=".45"/><path d="M50 78 C52 62 56 56 62 54 C68 56 72 62 72 78 Z" opacity=".45"/>',
  pasOmbre: '<path d="M20 70 C30 40 50 30 70 30 L64 20 L88 34 L66 50 L68 40 C52 40 38 50 30 74 Z"/><circle cx="24" cy="80" r="6" opacity=".5"/><circle cx="12" cy="66" r="4" opacity=".35"/>',
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
Object.assign(GLYPHES, {
  arc: '<path d="M30 8 C70 22 74 78 30 92 L34 86 C64 72 62 28 34 14 Z"/><path d="M31 11 L31 89" stroke="#fff" stroke-width="3"/><path d="M14 50 H82" stroke="#fff" stroke-width="5"/><path d="M84 50 L72 42 L72 58 Z"/>',
  fleche: '<path d="M12 88 L70 30" stroke="#fff" stroke-width="7" stroke-linecap="round"/><path d="M88 12 L58 26 L74 42 Z"/><path d="M12 88 L10 72 M12 88 L28 90 M20 80 L16 66 M20 80 L34 84" stroke="#fff" stroke-width="5"/>',
  loup: '<path d="M18 22 L36 40 L50 34 L64 40 L82 22 L80 52 C80 70 66 84 50 90 C34 84 20 70 20 52 Z"/><path d="M36 54 L44 58 L36 60 Z M64 54 L56 58 L64 60 Z" fill="#ff2a1a"/><path d="M42 74 L50 82 L58 74 Z" fill="#1a0a0a"/>',
  entrave: '<circle cx="50" cy="50" r="30" fill="none" stroke="#fff" stroke-width="8" stroke-dasharray="12 6"/><path d="M26 26 L74 74 M74 26 L26 74" stroke="#fff" stroke-width="8" stroke-linecap="round"/>',
  rugissement: '<path d="M20 50 C20 30 34 18 50 18 C66 18 80 30 80 50 L66 56 L72 72 L50 62 L28 72 L34 56 Z"/><path d="M6 36 C2 46 2 54 6 64 M94 36 C98 46 98 54 94 64" stroke="#fff" stroke-width="5" fill="none"/>',
  bond: '<path d="M10 80 C30 20 70 20 90 60" stroke="#fff" stroke-width="7" fill="none" stroke-dasharray="10 7"/><path d="M60 52 L92 64 L74 88 Z"/><circle cx="16" cy="78" r="8"/>',
  sablier: '<path d="M24 10 H76 V18 C76 34 58 42 58 50 C58 58 76 66 76 82 V90 H24 V82 C24 66 42 58 42 50 C42 42 24 34 24 18 Z"/>',
  crane: '<path d="M50 10 C26 10 14 28 16 48 C18 60 24 64 28 66 V82 H72 V66 C76 64 82 60 84 48 C86 28 74 10 50 10 Z"/><circle cx="36" cy="46" r="9" fill="#1a0a0a"/><circle cx="64" cy="46" r="9" fill="#1a0a0a"/>',
  livre: '<path d="M10 20 C26 14 42 16 50 24 C58 16 74 14 90 20 V84 C74 78 58 80 50 86 C42 80 26 78 10 84 Z"/><path d="M50 24 V86" stroke="#1a0a0a" stroke-width="3"/>',
  couronne: '<path d="M10 76 L16 28 L34 50 L50 18 L66 50 L84 28 L90 76 Z"/><rect x="10" y="78" width="80" height="10"/>',
  goutte: '<path d="M50 8 C62 30 80 48 80 64 C80 82 66 92 50 92 C34 92 20 82 20 64 C20 48 38 30 50 8 Z"/>',
  oeil: '<path d="M6 50 C24 22 76 22 94 50 C76 78 24 78 6 50 Z"/><circle cx="50" cy="50" r="15" fill="#1a0a0a"/><circle cx="55" cy="45" r="5"/>',
  poing: '<path d="M22 40 h56 v30 c0 14 -10 22 -26 22 h-6 c-16 0 -24 -8 -24 -22 z"/><path d="M22 40 v-14 h14 v14 M36 40 v-18 h14 v18 M50 40 v-18 h14 v18 M64 40 v-14 h14 v14"/>',
  etoile: '<path d="M50 6 L61 38 L94 38 L67 58 L77 92 L50 72 L23 92 L33 58 L6 38 L39 38 Z"/>',
  griffe: '<path d="M20 90 C30 60 40 30 70 8 C56 34 48 62 44 90 Z M44 92 C52 64 62 40 88 24 C76 46 70 70 68 92 Z"/>',
  epees: '<path d="M14 14 L22 10 L66 54 L58 62 Z M86 14 L78 10 L34 54 L42 62 Z"/><path d="M50 66 L62 54 L74 66 L62 78 Z M50 66 L38 54 L26 66 L38 78 Z"/>',
  flamme: '<path d="M50 6 C66 30 84 42 78 66 C74 84 62 94 50 94 C36 94 22 84 22 64 C22 46 36 40 38 24 C46 36 48 40 50 44 C54 30 52 18 50 6 Z"/>',
  bouclier: '<path d="M50 8 L86 20 L82 54 C78 74 64 84 50 92 C36 84 22 74 18 54 L14 20 Z"/>',
  coeur: '<path d="M50 86 C20 64 10 48 14 32 C18 18 36 14 50 30 C64 14 82 18 86 32 C90 48 80 64 50 86 Z"/>',
  coeurB: '<path d="M50 86 C20 64 10 48 14 32 C18 18 36 14 50 30 C64 14 82 18 86 32 C90 48 80 64 50 86 Z"/><path d="M50 30 V70 M30 50 H70" stroke="#1a0a0a" stroke-width="7"/>',
  goutteB: '<path d="M50 8 C62 30 80 48 80 64 C80 82 66 92 50 92 C34 92 20 82 20 64 C20 48 38 30 50 8 Z"/><path d="M38 64 C38 74 44 80 52 80" stroke="#1a3a6a" stroke-width="6" fill="none"/>',
  feuille: '<path d="M14 86 C14 40 40 14 88 12 C86 60 60 86 14 86 Z"/><path d="M14 86 L64 36" stroke="#1a3a1a" stroke-width="5"/>',
  aile: '<path d="M14 72 C26 40 58 22 90 18 C76 28 72 34 68 42 C78 40 84 40 88 42 C76 50 66 54 56 56 C64 58 70 60 74 64 C58 72 40 74 14 72 Z"/>',
  spirale: '<path d="M50 50 m0 -6 a6 6 0 1 1 -6 6 a14 14 0 1 1 14 14 a24 24 0 1 1 -24 -24 a34 34 0 1 1 34 34" stroke="#fff" stroke-width="7" fill="none"/>',
  tour: '<path d="M22 92 V30 H30 V16 H42 V30 H58 V16 H70 V30 H78 V92 Z"/><rect x="42" y="56" width="16" height="36" fill="#1a0a0a"/>',
  fiole: '<path d="M40 10 h20 v8 h-4 v14 C70 38 78 50 78 62 C78 80 66 90 50 90 C34 90 22 80 22 62 C22 50 30 38 44 32 V18 h-4 z"/>',
  eclair: '<path d="M58 6 L22 54 H46 L38 94 L80 40 H54 Z"/>',
  montagne: '<path d="M4 88 L36 30 L52 54 L66 34 L96 88 Z"/><path d="M36 30 L44 44 L30 44 Z" fill="#fff"/>',
});
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
  mat.color = new THREE.Color('#ffffff').lerp(new THREE.Color(col), 0.75);
  if (mat.emissive) { mat.emissive = new THREE.Color(col); mat.emissiveIntensity = Math.min(0.22, TIERS[tier].glow * 0.2); } // icône lisible : pas de surbrillance
  mat.skinning = false;
  return mat;
}
// icônes de butin peintes (marchandises, runes, bourse d'argent)
export function svgButin(type, tier = 0) {
  const tc = tier ? TIERS[tier].color : '#ff8a2a';
  const D = `<defs>
    <radialGradient id="feu" cx=".45" cy=".45" r=".6"><stop offset="0" stop-color="#fff6c0"/><stop offset=".35" stop-color="#ffb02a"/><stop offset=".75" stop-color="#e2420e"/><stop offset="1" stop-color="#5a0e04"/></radialGradient>
    <linearGradient id="roche" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#6a5a52"/><stop offset=".5" stop-color="#3a302c"/><stop offset="1" stop-color="#1a1412"/></linearGradient>
    <radialGradient id="lueur"><stop offset="0" stop-color="${tc}" stop-opacity=".9"/><stop offset="1" stop-color="${tc}" stop-opacity="0"/></radialGradient>
    <linearGradient id="cuir" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e8d8b8"/><stop offset=".6" stop-color="#b89a70"/><stop offset="1" stop-color="#6a5038"/></linearGradient>
    <radialGradient id="glace" cx=".4" cy=".35" r=".7"><stop offset="0" stop-color="#e8fbff"/><stop offset=".45" stop-color="#5ad0ff"/><stop offset="1" stop-color="#0a4a7a"/></radialGradient>
    <linearGradient id="or" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff0a8"/><stop offset=".5" stop-color="#e8b04a"/><stop offset="1" stop-color="#7a4a10"/></linearGradient>
    <filter id="fl" x="-30%" y="-30%" width="160%" height="160%"><feGaussianBlur stdDeviation="3"/></filter></defs>`;
  const ombre = '<ellipse cx="50" cy="90" rx="28" ry="5" fill="#000" opacity=".4"/>';
  const T = 'stroke="#1a0e06" stroke-width="2.4" stroke-linejoin="round"';
  let c = '';
  if (type === 'eclat') c = `<path d="M50 6 L70 30 L74 64 L54 92 L30 78 L24 40 Z" fill="url(#roche)" ${T}/>
    <path d="M50 14 L64 34 L66 60 L52 82 L36 72 L32 42 Z" fill="url(#feu)"/>
    <path d="M50 14 L52 46 L66 60 M52 46 L36 72 M52 46 L32 42" stroke="#fff2b0" stroke-width="1.8" opacity=".75" fill="none"/>
    <circle cx="50" cy="48" r="16" fill="#ffd27a" opacity=".55" filter="url(#fl)"/>
    <path d="M40 24 L46 18" stroke="#fff" stroke-width="3" stroke-linecap="round" opacity=".8"/>`;
  else if (type === 'sceau') c = `<path d="M22 30 C26 14 70 8 80 26 C90 44 86 74 70 86 C52 96 24 88 18 66 C14 52 18 40 22 30 Z" fill="url(#roche)" ${T}/>
    <path d="M30 30 C40 20 66 18 74 30" stroke="#8a7a70" stroke-width="3" fill="none" opacity=".6"/>
    <path d="M50 30 L66 64 L34 64 Z" fill="none" stroke="${tc}" stroke-width="7" stroke-linejoin="round" filter="url(#fl)"/>
    <path d="M50 30 L66 64 L34 64 Z" fill="none" stroke="#fff3c8" stroke-width="3.2" stroke-linejoin="round"/>
    <path d="M50 44 L50 56" stroke="#fff3c8" stroke-width="3" stroke-linecap="round"/>`;
  else if (type === 'relique') c = `<path d="M36 10 C36 2 64 2 64 10 L60 22 L40 22 Z" fill="none" stroke="#2a1a10" stroke-width="3"/>
    <circle cx="50" cy="56" r="30" fill="#0a2a40" ${T}/>
    <circle cx="50" cy="56" r="26" fill="url(#glace)"/>
    <circle cx="50" cy="56" r="26" fill="none" stroke="#bff4ff" stroke-width="2" opacity=".7"/>
    <path d="M50 38 L58 50 L72 52 L60 60 L64 74 L50 66 L36 74 L40 60 L28 52 L42 50 Z" fill="none" stroke="#e8fbff" stroke-width="2.6" stroke-linejoin="round"/>
    <circle cx="50" cy="56" r="7" fill="#e8fbff"/><circle cx="42" cy="46" r="5" fill="#fff" opacity=".7"/>`;
  else if (type === 'tome') c = `<path d="M18 22 L60 14 L82 26 L82 84 L40 92 L18 80 Z" fill="#5a1a10" ${T}/>
    <path d="M40 30 L82 26 L82 84 L40 92 Z" fill="#9a2a1a" ${T}/>
    <path d="M18 22 L40 30 L40 92 L18 80 Z" fill="#e8d8b0" ${T}/>
    <path d="M22 34 L36 38 M22 46 L36 50 M22 58 L36 62" stroke="#8a7a5a" stroke-width="2"/>
    <circle cx="61" cy="58" r="12" fill="url(#or)" ${T}/><path d="M56 58 L66 58 M61 53 L61 63" stroke="#7a1a0a" stroke-width="3"/>
    <path d="M44 34 L78 30" stroke="#e8b04a" stroke-width="3"/>`;
  else if (type === 'rune') c = `<circle cx="50" cy="52" r="34" fill="url(#lueur)" opacity=".6"/>
    <path d="M32 18 L68 18 L80 50 L66 86 L34 86 L20 50 Z" fill="#2a3a5a" ${T}/>
    <path d="M36 24 L64 24 L74 50 L62 80 L38 80 L26 50 Z" fill="#3a5a8a"/>
    <path d="M50 30 L50 74 M50 40 L62 50 L50 60 M50 52 L38 44" stroke="#bfe8ff" stroke-width="4.5" stroke-linecap="round" fill="none"/>
    <path d="M50 30 L50 74 M50 40 L62 50 L50 60 M50 52 L38 44" stroke="#5ab0ff" stroke-width="10" stroke-linecap="round" fill="none" opacity=".35" filter="url(#fl)"/>`;
  else if (type === 'bourse') c = `<path d="M30 40 C14 54 14 86 34 90 L66 90 C86 86 86 54 70 40 Z" fill="url(#cuir)" ${T}/>
    <path d="M36 40 C34 30 40 24 50 24 C60 24 66 30 64 40 Z" fill="#d8c8a8" ${T}/>
    <path d="M32 40 C40 46 60 46 68 40" stroke="#6a3a1a" stroke-width="5" fill="none"/>
    <circle cx="50" cy="66" r="11" fill="url(#or)" ${T}/><text x="50" y="71" text-anchor="middle" font-size="13" font-weight="900" fill="#7a4a10" font-family="Georgia,serif">¤</text>
    <ellipse cx="68" cy="88" rx="9" ry="4" fill="url(#or)" stroke="#1a0e06" stroke-width="1.6" stroke-linejoin="round"/><ellipse cx="78" cy="84" rx="8" ry="3.6" fill="url(#or)" stroke="#1a0e06" stroke-width="1.6" stroke-linejoin="round"/>
    <path d="M38 52 C40 62 40 74 42 82" stroke="#fff" stroke-width="3" opacity=".35" fill="none"/>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="128" height="128">${D}${ombre}${c}</svg>`;
}
const SVG_BUTINS = ['eclat', 'sceau', 'relique', 'tome', 'rune', 'bourse'];
// icônes d'armure dessinées (plus nettes et plus belles que les morceaux du modèle 3D)
function svgArmure(slot, tier) {
  const T = TIERS[tier], c = new THREE.Color(T.color);
  const hx = (col) => '#' + col.getHexString();
  const clair = hx(c.clone().lerp(new THREE.Color('#ffffff'), 0.55)), moyen = hx(c.clone().lerp(new THREE.Color('#d8d8e0'), 0.25)), sombre = hx(c.clone().multiplyScalar(0.38));
  // métal neutre (acier, bronze ou rouille) pour bien ressortir sur le fond coloré du tier ; les ornements prennent la couleur du tier
  const metal = tier === 1 ? ['#c8b8a0', '#8a7058', '#3e2e22'] : tier === 2 ? ['#f0c890', '#b07a3a', '#4a2a10'] : tier >= 7 ? ['#ffffff', '#b8c0cc', '#2a2e38'] : ['#eef2f6', '#98a2ae', '#343a44'];
  const orne = tier <= 2 ? '#6a5040' : hx(c.clone().lerp(new THREE.Color('#ffffff'), 0.15));
  void clair; void moyen; void sombre;
  const gemme = tier >= 5 ? `<circle cx="50" cy="${slot === 'casque' ? 40 : slot === 'plastron' ? 42 : 62}" r="${tier >= 7 ? 6 : 4.5}" fill="${T.color}" stroke="#fff8" stroke-width="1.5"/><circle cx="48" cy="${slot === 'casque' ? 38 : slot === 'plastron' ? 40 : 60}" r="1.6" fill="#fff"/>` : '';
  const halo = tier >= 7 ? `<circle cx="50" cy="52" r="44" fill="url(#h)"/>` : '';
  const defs = `<defs><linearGradient id="m" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${metal[0]}"/><stop offset=".55" stop-color="${metal[1]}"/><stop offset="1" stop-color="${metal[2]}"/></linearGradient>
    <linearGradient id="r" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".55"/><stop offset=".4" stop-color="#fff" stop-opacity="0"/></linearGradient>
    <radialGradient id="h"><stop offset="0" stop-color="${T.color}" stop-opacity=".45"/><stop offset="1" stop-color="${T.color}" stop-opacity="0"/></radialGradient></defs>`;
  const trait = `stroke="#1a1208" stroke-width="2.5" stroke-linejoin="round"`;
  let corps = '';
  if (slot === 'casque') corps = `<path d="M20 58 C20 30 34 16 50 16 C66 16 80 30 80 58 L80 74 L64 74 L62 60 L38 60 L36 74 L20 74 Z" fill="url(#m)" ${trait}/>
    <path d="M26 54 C27 34 38 22 50 22" fill="none" stroke="url(#r)" stroke-width="6" stroke-linecap="round"/>
    <path d="M47 16 L53 16 L54 60 L46 60 Z" fill="${orne}" stroke="#1a1208" stroke-width="1.6" stroke-linejoin="round"/>
    <path d="M30 60 L70 60 L68 66 L32 66 Z" fill="#1a1208" opacity=".85"/>
    ${tier >= 4 ? `<path d="M20 50 L8 40 L14 58 Z M80 50 L92 40 L86 58 Z" fill="${orne}" stroke="#1a1208" stroke-width="1.6" stroke-linejoin="round"/>` : ''}
    ${tier >= 6 ? `<path d="M38 18 L42 6 L46 16 M54 16 L58 6 L62 18" fill="${orne}" stroke="#1a1208" stroke-width="1.6" stroke-linejoin="round"/>` : ''}`;
  else if (slot === 'plastron') corps = `<path d="M30 18 L42 24 L58 24 L70 18 L86 30 L80 50 L72 46 L72 86 C62 92 38 92 28 86 L28 46 L20 50 L14 30 Z" fill="url(#m)" ${trait}/>
    <path d="M36 30 C36 50 40 70 44 84" fill="none" stroke="url(#r)" stroke-width="7" stroke-linecap="round"/>
    <path d="M50 26 L50 88" stroke="#1a1208" stroke-width="2" opacity=".6"/>
    <path d="M32 58 C42 64 58 64 68 58" fill="none" stroke="${orne}" stroke-width="3.5"/>
    <path d="M30 72 C42 78 58 78 70 72" fill="none" stroke="${orne}" stroke-width="3" opacity=".8"/>
    <path d="M42 24 L50 32 L58 24" fill="none" stroke="${orne}" stroke-width="3"/>
    ${tier >= 5 ? `<path d="M14 30 L22 26 L28 34 M86 30 L78 26 L72 34" fill="none" stroke="${orne}" stroke-width="3"/>` : ''}`;
  else corps = `<path d="M24 16 L44 16 L44 62 L50 70 L50 84 L16 84 L16 74 L24 66 Z" fill="url(#m)" ${trait}/>
    <path d="M56 16 L76 16 L76 66 L84 74 L84 84 L50 84 L50 70 L56 62 Z" fill="url(#m)" ${trait} opacity=".92"/>
    <path d="M28 22 L28 60" stroke="url(#r)" stroke-width="5" stroke-linecap="round"/>
    <path d="M22 30 L46 30 M54 30 L78 30" stroke="${orne}" stroke-width="3.5"/>
    <path d="M16 78 L50 78 M50 78 L84 78" stroke="#1a1208" stroke-width="2" opacity=".6"/>
    ${tier >= 4 ? `<path d="M22 46 L46 46 M54 46 L78 46" stroke="${orne}" stroke-width="2.5" opacity=".85"/>` : ''}`;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" width="128" height="128">${defs}${halo}<ellipse cx="50" cy="92" rx="30" ry="4" fill="#000" opacity=".35"/>${corps}${gemme}</svg>`;
}
export function iconeObjet(it) {
  const cle = it.cat + '_' + it.type + '_' + it.tier;
  if (icoCache[cle]) return icoCache[cle];
  if (it.cat === 'parchemin') return (icoCache[cle] = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svgParchemin(it.type)));
  if (it.cat === 'butin' && SVG_BUTINS.includes(it.type)) return (icoCache[cle] = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svgButin(it.type, it.tier)));
  if (it.cat === 'butin' || it.cat === 'potion') return (icoCache[cle] = icone2D(it));
  if (!icoR) initIcones();
  const grp = new THREE.Group();
  let ms, orient = 'arme';
  if (it.cat === 'arme' && ARMES[it.type].procedural) { const a = creerArc(); a.updateMatrixWorld(true); ms = []; a.traverse(o => { if (o.isMesh) { o.applyMatrix4(a.matrixWorld); ms.push(o); } }); }
  else if (it.cat === 'arme') ms = meshesDe(ARMES[it.type].model, [ARMES[it.type].node]);
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
export const TEINTES_OMBRE = { Rogue_Head_Hooded: ['#5a2aa0', 0.85, 0.3], Rogue_Body: ['#2a1a40', 0.85, 0.15], Rogue_Cape: ['#6a2aff', 0.6, 0.2] };
export function bustePersonnage(cle, canvas, couleurFond = null, teintes = null, opts = {}) {
  if (!icoR) initIcones();
  const corps = opts.cadrage === 'corps';
  const src = opts.source || G.assets[cle].scene;
  const m = SkeletonUtils.clone(src);
  m.position.set(0, 0, 0); m.rotation.set(0, 0, 0); m.visible = true;
  m.traverse(o => { o.visible = o.visible !== false; });
  if (opts.source) { const s = src.scale; m.scale.copy(s); }
  if (teintes) for (const [nom, [c, f, gl]] of Object.entries(teintes)) { const n = m.getObjectByName(nom); if (n) n.traverse(o => { if (o.isMesh) { o.material = o.material.clone(); o.material.color.set('#ffffff').lerp(new THREE.Color(c), f); if (gl && o.material.emissive) o.material.emissive.set(c).multiplyScalar(gl); } }); }
  // portrait : on cache les armes ; corps entier : on les garde
  if (!corps) m.traverse(o => { if (/Sword|Axe|Shield|Crossbow|Staff|Wand|Knife|Throwable|Mug|Spellbook|Offhand/.test(o.name)) o.visible = false; });
  icoScene.add(m); m.updateMatrixWorld(true);
  const box = new THREE.Box3();
  m.traverse(o => { if (o.isMesh && o.visible && !/Sword|Axe|Shield|Crossbow|Staff|Wand|Knife|Throwable|Mug|Spellbook|Offhand/.test(o.name)) box.expandByObject(o); });
  if (box.isEmpty()) box.setFromObject(m);
  const h = box.max.y - box.min.y;
  // portrait : toute la tête et le haut des épaules ; corps : le personnage en entier
  const r = corps ? h * 0.56 : h * 0.34;
  const cy = corps ? (box.min.y + box.max.y) / 2 : box.max.y - h * 0.31;
  icoCam.left = -r; icoCam.right = r; icoCam.top = r; icoCam.bottom = -r;
  const cx = (box.min.x + box.max.x) / 2;
  icoCam.position.set(cx + r * 0.5, cy + r * 0.12, 50); icoCam.lookAt(cx, cy, 0); icoCam.updateProjectionMatrix();
  icoR.setClearColor(0x000000, 0); icoR.render(icoScene, icoCam);
  icoScene.remove(m);
  const g = canvas.getContext('2d'); g.clearRect(0, 0, canvas.width, canvas.height);
  const W = canvas.width;
  if (couleurFond) { const gr = g.createRadialGradient(W / 2, W * 0.4, W * 0.08, W / 2, W / 2, W * 0.62); gr.addColorStop(0, couleurFond); gr.addColorStop(1, '#120b16'); g.fillStyle = gr; g.fillRect(0, 0, W, canvas.height); }
  g.drawImage(icoR.domElement, 0, 0, W, canvas.height);
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
  const bloque = equipable && !peutPorter(it) && !extra.includes('libre');
  const glow = it.tier >= 5 && !bloque ? `filter:drop-shadow(0 0 6px ${TIERS[it.tier].color})` : '';
  const tc = it.tier ? TIERS[it.tier].color : '#8a6a4a';
  const bg = it.tier ? `--tc:${tc};` : '';
  const cad = bloque ? `<span class="cadenas"><svg viewBox="0 0 24 24"><path d="M7 10V7a5 5 0 0110 0v3h1.5v11h-13V10zm2 0h6V7a3 3 0 00-6 0z" fill="#ffd0c0"/></svg>Niv. ${niveauRequis(it)}</span>` : '';
  return `<div class="case q${it.q || 0} ${it.tier ? 'tiere' : ''} ${bloque ? 'bloque' : ''} ${extra}" style="${bg}${style}">${cad}<img src="${iconeObjet(it)}" alt="" style="${glow}">${it.tier ? `<span class="tier">${TIERS[it.tier].roman}</span>` : ''}${it.ench ? `<span class="ench">${'<i></i>'.repeat(it.ench)}</span>` : ''}${it.n > 1 ? `<span class="nb">${it.n}</span>` : ''}</div>`;
}

// ---------------- Barre de sorts ----------------
// cases vides du personnage : silhouette discrète (comme les emplacements pas encore utilisés)
const SILHOUETTES = { sac: 'M30 40 C30 26 70 26 70 40 L74 80 L26 80 Z M40 34 C40 22 60 22 60 34', cape: 'M34 22 L66 22 L80 82 L50 72 L20 82 Z', main: 'M50 12 L56 20 L56 62 L44 62 L44 20 Z M36 62 L64 62 M50 62 L50 84', repas: 'M28 22 L28 50 M36 22 L36 50 M44 22 L44 50 M36 50 L36 84 M66 20 C56 34 56 52 66 56 L66 84' };
function caseVide(k) { return `<div class="case vide2"><svg viewBox="0 0 100 100"><path d="${SILHOUETTES[k]}" fill="none" stroke="#8a6a4a" stroke-width="7" stroke-linecap="round" stroke-linejoin="round" opacity=".55"/></svg></div>`; }
const TOUCHES = ['ATK', 'Q', 'W', 'E', 'R', 'D', 'F', 'POT', 'CIBLE'];
UI.boutonRefaire = (nom, fn, duree = 0) => {
  let b = document.getElementById('btnRefaire');
  clearTimeout(UI._refT);
  if (!nom) { if (b) b.remove(); return; }
  if (!b) { b = document.createElement('button'); b.id = 'btnRefaire'; b.type = 'button'; document.getElementById('hud').appendChild(b); }
  b.innerHTML = `<span class="ic">↻</span><span><b>Refaire</b><small>${nom}</small></span>`;
  b.onpointerdown = (e) => { e.stopPropagation(); e.preventDefault(); fn(); };
  if (duree) UI._refT = setTimeout(() => b.remove(), duree * 1000);
};
UI.boutonTP = (n, fn) => {
  let b = document.getElementById('btnTP');
  if (!n) { if (b) b.remove(); return; }
  if (!b) { b = document.createElement('button'); b.id = 'btnTP'; b.type = 'button'; document.getElementById('hud').appendChild(b); }
  const h = `<span class="ic">✦</span><span><b>Téléport boss</b><small>${n} parchemin${n > 1 ? 's' : ''}</small></span>`;
  if (b._h !== h) { b.innerHTML = h; b._h = h; }
  b.onpointerdown = (e) => { e.stopPropagation(); e.preventDefault(); fn(); };
};
// compteur de l'escouade d'ombres (mesure de l'économie)
UI.escouadeHud = (s) => {
  let el = document.getElementById('escHud');
  if (!s) { if (el) el.remove(); return; }
  if (!el) { el = document.createElement('div'); el.id = 'escHud'; $('#jeu').appendChild(el); }
  const t = Math.floor(s.duree / 1000), hh = Math.floor(t / 3600), mm = Math.floor(t / 60) % 60, ss = t % 60;
  const h = `<b>☠ Escouade d’ombres</b><span>⏱ ${hh ? hh + ' h ' : ''}${String(mm).padStart(2, '0')}:${String(ss).padStart(2, '0')}</span>
    <span>¤ +${fmt(s.argent)} <em>${fmt(s.parHeure)}/h</em></span><span>✦ +${fmt(s.xp)} XP <em>${fmt(s.xpH)}/h</em></span><span>⚔ ${fmt(s.kills)} · 🗝 ${fmt(s.coffres)} coffres</span>`;
  if (el._h !== h) { el.innerHTML = h; el._h = h; }
};
// butin ramassé par l'escouade : carte compacte, sans bloquer le jeu
UI.butinFlash = (couleur, loot) => {
  let pile = document.getElementById('butinFlash');
  if (!pile) { pile = document.createElement('div'); pile.id = 'butinFlash'; $('#jeu').appendChild(pile); }
  const C = COFFRES.find(c => c.id === couleur) || { nom: 'Coffre', color: '#fff' };
  const d = document.createElement('div'); d.className = 'bf'; d.style.setProperty('--c', C.color);
  const valeur = loot.argent + loot.objets.reduce((a, it) => a + valeurObjet(it) * (it.n || 1), 0);
  d.innerHTML = `<div class="t"><b>${C.nom}</b><span>≈ ${fmtK(valeur)}</span></div><div class="ic">${loot.argent ? caseBourse(loot.argent) : ''}${loot.objets.slice(0, 7).map(it => htmlCase(it, 'libre')).join('')}${loot.objets.length > 7 ? `<i>+${loot.objets.length - 7}</i>` : ''}</div>`;
  pile.prepend(d); while (pile.children.length > 3) pile.lastChild.remove();
  setTimeout(() => { d.classList.add('part'); setTimeout(() => d.remove(), 400); }, 4500);
};
// aide des signes : rappel discret des symboles à dessiner (non bloquant)
UI.aideSignes = (sorts) => {
  document.querySelectorAll('.aideSignes').forEach(x => x.remove());
  const l = Object.keys(SIGNES).filter(k => sorts[k]);
  if (!l.length) return;
  const d = document.createElement('div'); d.className = 'aideSignes';
  d.innerHTML = `<b>Dessine le signe sur l’ennemi</b>${l.map(k => `<span>${svgGlyphe(k, '#ffe2a0', 9)}<em>${sorts[k].nom}</em></span>`).join('')}`;
  document.getElementById('jeu').appendChild(d); setTimeout(() => d.classList.add('part'), 9000); setTimeout(() => d.remove(), 9600);
};
// tableau du Goulet : score, chrono, état des deux drapeaux
UI.scoreGoulet = (g) => {
  let el = document.getElementById('scoreGoulet');
  if (!g) { if (el) el.remove(); return; }
  if (!el) {
    el = document.createElement('div'); el.id = 'scoreGoulet'; $('#jeu').appendChild(el);
    el.addEventListener('pointerdown', (e) => {
      const p = e.target.closest('[data-porteur]'); const c = e.target.closest('[data-cl]');
      if (p || c) { e.stopPropagation(); e.preventDefault(); }
      if (p) api.ciblerPorteur(p.dataset.porteur);
      if (c) UI.classementGoulet({ live: true });
    });
  }
  const t = Math.max(0, Math.ceil(g.debut > 0 ? g.debut : g.t));
  const etat = (F) => {
    if (F.etat === 'base') return '<small>⚑ sur son socle</small>';
    if (F.etat === 'attente') return `<small>⚑ revient dans ${Math.ceil(F.t)} s</small>`;
    if (F.etat === 'sol') return `<small class="alerte">⚑ à terre ! ${Math.ceil(F.t)} s</small>`;
    const nom = F.porteur && F.porteur.nom ? F.porteur.nom : 'toi';
    const ennemi = F.camp === 'bleu'; // notre drapeau porté par un rouge : on peut le cibler d'un toucher
    return `<button class="porteur ${ennemi ? 'cible' : ''}" ${ennemi ? `data-porteur="bleu"` : ''}>⚑ ${ennemi ? 'Volé par' : 'Porté par'} <b>${nom}</b></button>`;
  };
  const assaut = g.assaut > 0 ? `<div class="assaut ${g.assaut > 5 ? 'brutal' : ''}">${g.assaut > 5 ? 'Assaut brutal' : 'Assaut ciblé'} ×${g.assaut} · porteurs +${g.assaut * 10} % de dégâts subis</div>` : '';
  const res = g.resJ ? `<div class="resBG">✦ Cimetière · retour au combat dans ${g.resJ} s</div>` : '';
  const h = `<div class="ligneSG"><div class="sg bleu"><b>${g.score.bleu}</b>${etat(g.drapeaux.rouge).replace('Porté par', 'Porté par')}</div>
    <div class="chrono">${g.debut > 0 ? '<small>Ouverture</small>' : ''}${Math.floor(t / 60)}:${String(t % 60).padStart(2, '0')}<small>3 captures</small><button class="btnCl" data-cl>Classement</button></div>
    <div class="sg rouge"><b>${g.score.rouge}</b>${etat(g.drapeaux.bleu)}</div></div>${assaut}${res}`;
  if (el._h !== h) { el.innerHTML = h; el._h = h; }
};
// flèches au bord de l'écran vers les drapeaux hors champ
UI.flechesDrapeau = (liste) => {
  let box = document.getElementById('flechesBG');
  if (!liste.length) { if (box) box.innerHTML = ''; return; }
  if (!box) { box = document.createElement('div'); box.id = 'flechesBG'; $('#jeu').appendChild(box); }
  const W = innerWidth, H = innerHeight, cx = W / 2, cy = H / 2, m = 46;
  box.innerHTML = liste.map(f => {
    const dx = f.x - cx, dy = f.y - cy; const k = Math.min((cx - m) / Math.abs(dx || 1e-3), (cy - m) / Math.abs(dy || 1e-3));
    const x = cx + dx * k, y = cy + dy * k, ang = Math.atan2(dy, dx);
    return `<div class="flecheBG" style="left:${x}px;top:${y}px;--c:${f.c}"><i style="transform:rotate(${ang}rad)"></i><span>⚑ ${f.nom}</span></div>`;
  }).join('');
};
// tableau des scores (comme dans le vrai Goulet : coups fatals, morts, victoires honorables, dégâts, soins, drapeaux, renommée)
let clOpts = null, clTri = 'kb', clFiltre = 'tous', clTimer = null;
UI.classementOuvert = () => !!clOpts;
UI.classementGoulet = (opts, fini) => {
  let m = document.getElementById('classementBG');
  if (!opts) { clOpts = null; clearInterval(clTimer); if (m) m.remove(); return; }
  clOpts = { ...opts, fini };
  if (!m) { m = document.createElement('div'); m.id = 'classementBG'; $('#jeu').appendChild(m); }
  const COLS = [['nom', 'Nom'], ['kb', 'Coups fatals'], ['morts', 'Morts'], ['hk', 'Vict. honorables'], ['caps', 'Drapeaux pris'], ['ret', 'Drapeaux ramenés'], ['deg', 'Dégâts'], ['soin', 'Soins'], ['renom', 'Renommée']];
  const rendre = () => {
    const rows = (clOpts.rows || api.classementGoulet() || []).filter(r => clFiltre === 'tous' || r.camp === clFiltre);
    rows.sort((a, b) => clTri === 'nom' ? a.nom.localeCompare(b.nom) : (b[clTri] - a[clTri]) || (b.deg - a.deg));
    const tete = clOpts.fin ? `<div class="banBG ${clOpts.victoire === true ? 'bleu' : clOpts.victoire === false ? 'rouge' : ''}"><h2>${clOpts.titre}</h2><div>🔵 ${clOpts.score.bleu} – ${clOpts.score.rouge} 🔴</div></div>` : '<h2 class="titreBG">Goulet des Braises · Classement</h2>';
    m.innerHTML = `<div class="cadreBG parchemin">${clOpts.fin ? '' : '<button class="fermer" data-x aria-label="Fermer">×</button>'}${tete}
      <div class="filtresBG">${[['tous', 'Tous'], ['bleu', 'Équipe bleue'], ['rouge', 'Équipe rouge']].map(([k, l]) => `<button data-f="${k}" class="${clFiltre === k ? 'actif' : ''} ${k}">${l}</button>`).join('')}</div>
      <div class="tabBG"><table><thead><tr>${COLS.map(([k, l]) => `<th data-t="${k}" class="${clTri === k ? 'tri' : ''}">${l}</th>`).join('')}</tr></thead>
      <tbody>${rows.map(r => `<tr class="${r.camp} ${r.moi ? 'moi' : ''}"><td class="nomBG"><i></i>${r.nom}</td><td>${r.kb}</td><td>${r.morts}</td><td>${r.hk}</td><td>${r.caps}</td><td>${r.ret}</td><td>${fmtK(r.deg)}</td><td>${fmtK(r.soin)}</td><td class="renomBG">${r.renom}</td></tr>`).join('')}</tbody></table></div>
      ${clOpts.fin ? '<div class="actionsRes"><button class="btn or" data-ok>Continuer</button></div>' : ''}</div>`;
  };
  rendre();
  m.onclick = (e) => {
    const f = e.target.closest('[data-f]'), t = e.target.closest('[data-t]');
    if (f) { clFiltre = f.dataset.f; rendre(); }
    if (t) { clTri = t.dataset.t; rendre(); }
    if (e.target.closest('[data-x]')) UI.classementGoulet(null);
    if (e.target.closest('[data-ok]')) { const cb = clOpts.fini; UI.classementGoulet(null); if (cb) cb(); }
  };
  m.addEventListener('pointerdown', (e) => e.stopPropagation());
  clearInterval(clTimer); if (!clOpts.fin) clTimer = setInterval(() => { if (clOpts) rendre(); }, 1000);
};
// ---------------- Cadre de la meute (Maître des bêtes) ----------------
UI.cadreMeute = (meute, api2) => {
  let c = document.getElementById('cadreMeute');
  if (!meute) { if (c) c.remove(); return; }
  if (!c) {
    c = document.createElement('div'); c.id = 'cadreMeute';
    const jr = document.getElementById('journal');
    let col = document.getElementById('colJournal');
    if (!col && jr) { col = document.createElement('div'); col.id = 'colJournal'; jr.parentNode.insertBefore(col, jr); col.appendChild(jr); }
    (col || $('#hud')).appendChild(c);
    const img = api.portraitLoup();
    c.innerHTML = [0, 1, 2].map(i => `<button class="carteLoup" data-l="${i}" aria-label="Loup ${i + 1}"><div class="avL"><img src="${img}" alt=""><span class="mortL">☠</span></div><b></b><div class="barreL"><i class="pvL"></i></div><div class="barreL en"><i class="enL"></i></div></button>`).join('');
    c.addEventListener('pointerdown', (e) => { const b = e.target.closest('[data-l]'); if (!b) return; e.stopPropagation(); e.preventDefault(); api.choisirLoup(+b.dataset.l); });
  }
  UI.majMeute(meute, null);
};
UI.majMeute = (meute, choisi) => {
  const c = document.getElementById('cadreMeute'); if (!c) return;
  c.querySelectorAll('.carteLoup').forEach((b, i) => {
    const l = meute[i]; const mort = !l || l.mort;
    b.classList.toggle('ko', mort); b.classList.toggle('choisi', !!l && l === choisi); b.classList.toggle('rush', !!l && !!l.rush && !mort);
    const nom = l ? l.nom : ['Croc-Sang', 'Cendre', 'Fléau'][i]; const bb = b.querySelector('b'); if (bb.textContent !== nom) bb.textContent = nom;
    b.querySelector('.pvL').style.transform = `scaleX(${mort ? 0 : Math.max(0, l.pv / l.pvMax)})`;
    b.querySelector('.enL').style.transform = `scaleX(${mort ? 0 : Math.max(0, l.energie / l.energieMax)})`;
  });
};
// ---------------- Arbre de talents ----------------
UI.majBoutonTalents = () => {
  let b = document.getElementById('btnTalents');
  if (!b) {
    b = document.createElement('button'); b.id = 'btnTalents'; b.className = 'rond metal'; b.setAttribute('aria-label', 'Arbre de talents');
    b.innerHTML = '<svg viewBox="0 0 24 24" fill="#ffd27a"><path d="M12 2l2.4 5 5.6.8-4 3.9.9 5.6L12 14.7 7.1 17.3l.9-5.6-4-3.9 5.6-.8z"/><path d="M11 17h2v5h-2z"/></svg><span class="pastille" hidden></span>';
    b.addEventListener('click', () => UI.ouvrirTalents());
    const col = document.getElementById('colonne'); col.insertBefore(b, document.getElementById('btnQuitter'));
  }
  const T = api.talents(); const dispo = pointsTotaux(T.niv) - pointsDepenses(T.t);
  const p = b.querySelector('.pastille'); p.hidden = dispo <= 0; p.textContent = dispo;
};
let talentSel = null;
const ICONES_NOEUD = (n) => n.competence ? SORTS[n.competence].glyphe : n.ic;
UI.ouvrirTalents = () => {
  let m = document.getElementById('talents');
  if (!m) { m = document.createElement('div'); m.id = 'talents'; $('#jeu').appendChild(m); m.addEventListener('pointerdown', (e) => e.stopPropagation()); }
  m.hidden = false; api.son('open_001', 0.4);
  const rendre = () => {
    const T = api.talents(); const arbre = arbreDe(T.type); const t = T.t;
    const total = pointsTotaux(T.niv), dep = pointsDepenses(t), dispo = total - dep;
    const ROWS = 6;
    const branche = (b) => {
      const pb = pointsBranche(t, b);
      const pos = (n) => ({ x: n.col === 0 ? 28 : 72, y: 8 + n.rang * (84 / (ROWS - 1)) });
      const liens = b.noeuds.filter(n => n.dep).map(n => { const p = b.noeuds.find(x => x.id === n.dep); if (!p) return ''; const a = pos(p), c = pos(n); const on = (t[n.dep] || 0) > 0; return `<line x1="${a.x}" y1="${a.y}" x2="${c.x}" y2="${c.y}" class="${on ? 'on' : ''}" style="--c:${b.couleur}"/>`; }).join('');
      const noeuds = b.noeuds.map(n => {
        const r = t[n.id] || 0, p = pos(n), ok = peutMonter(t, arbre, b, n, dispo).ok;
        const etat = r >= n.max ? 'max' : r > 0 ? 'partiel' : ok ? 'dispo' : 'bloque';
        const sorts = n.competence ? SORTS[n.competence] : null;
        const ic = svgSort(ICONES_NOEUD(n), sorts ? sorts.couleur[0] : b.couleur, sorts ? sorts.couleur[1] : '#1a0e08', 'n' + n.id);
        return `<button class="noeud ${etat} ${n.ultime ? 'ultime' : ''} ${n.competence ? 'comp' : ''} ${talentSel === n.id ? 'sel' : ''}" data-n="${n.id}" style="left:${p.x}%;top:${p.y}%;--c:${b.couleur}">${ic}<span class="rg">${r}/${n.max}</span></button>`;
      }).join('');
      return `<div class="branche" style="--c:${b.couleur}"><div class="teteB">${svgSort(b.ic, b.couleur, '#1a0e08', 'b' + b.id)}<div><h3>${b.nom}</h3><small>${pb} point${pb > 1 ? 's' : ''} investi${pb > 1 ? 's' : ''}</small></div></div>
        <div class="grilleB"><svg class="liens" viewBox="0 0 100 100" preserveAspectRatio="none">${liens}</svg>${noeuds}</div></div>`;
    };
    // fiche du nœud sélectionné
    let fiche = '<div class="ficheT vide"><p>Touche un talent pour voir ce qu’il apporte.</p><p class="astuce">1 point par niveau de maîtrise de ton arme. Chaque ligne demande 3 points de plus dans la même branche.</p></div>';
    if (talentSel) for (const b of arbre.branches) { const n = b.noeuds.find(x => x.id === talentSel); if (!n) continue;
      const r = t[n.id] || 0, v = peutMonter(t, arbre, b, n, dispo);
      const sorts = n.competence ? SORTS[n.competence] : null;
      const place = n.competence && r ? Object.entries(T.slots).find(([, id]) => id === n.competence) : null;
      fiche = `<div class="ficheT" style="--c:${b.couleur}"><div class="icoT">${svgSort(ICONES_NOEUD(n), sorts ? sorts.couleur[0] : b.couleur, sorts ? sorts.couleur[1] : '#1a0e08', 'f' + n.id)}</div>
        <h3>${n.nom}</h3><div class="rangT">Rang ${r} / ${n.max}${n.ultime ? ' · <b>Ultime</b>' : ''}</div>
        ${sorts ? `<p class="effT">${sorts.desc}</p><p class="sub">Recharge ${sorts.cd} s · ${sorts.energie} énergie</p>` : `<p class="effT">${r ? 'Actuel : ' + texteNoeud(n, r) : texteNoeud(n, 1)}</p>${r && r < n.max ? `<p class="sub">Rang suivant : ${texteNoeud(n, r + 1)}</p>` : ''}`}
        ${v.ok ? `<button class="btn or" data-up>${r ? 'Améliorer' : 'Apprendre'} · 1 point</button>` : r >= n.max ? '' : `<p class="bloqueT">🔒 ${v.raison}</p>`}
        ${n.competence && r ? `<div class="placer"><span>Placer sur :</span>${['Q', 'W', 'E'].map(k => `<button class="btn ${place && place[0] === k ? 'vert' : 'gris'}" data-k="${k}">${k}</button>`).join('')}${place ? '<button class="btn gris" data-k="">Retirer</button>' : ''}</div>` : ''}
      </div>`; }
    m.innerHTML = `<div class="cadreT"><button class="fermer" data-x aria-label="Fermer">×</button>
      <div class="enteteT"><div><small>Arbre de talents</small><h2>${arbre.branches[2].nom}</h2></div><div class="pointsT"><b>${dispo}</b><span>point${dispo > 1 ? 's' : ''} à dépenser</span><small>${dep} / ${total} utilisés · maîtrise niv. ${T.niv}</small></div><button class="btn gris" data-reset>Réinitialiser</button></div>
      <div class="corpsT"><div class="branches">${arbre.branches.map(branche).join('')}</div>${fiche}</div></div>`;
  };
  rendre();
  m.onclick = (e) => {
    if (e.target.closest('[data-x]')) { m.hidden = true; UI.majBoutonTalents(); return; }
    const n = e.target.closest('[data-n]'); if (n) { talentSel = n.dataset.n; api.son('select_001', 0.3); rendre(); return; }
    if (e.target.closest('[data-up]')) { if (api.monterTalent(talentSel)) rendre(); else api.son('error_001', 0.3); return; }
    const k = e.target.closest('[data-k]'); if (k) { const T = api.talents(); for (const b of arbreDe(T.type).branches) { const nn = b.noeuds.find(x => x.id === talentSel); if (nn && nn.competence) api.placerCompetence(nn.competence, k.dataset.k || null); } rendre(); return; }
    if (e.target.closest('[data-reset]')) { if (m._conf && Date.now() - m._conf < 3000) { api.resetTalents(); talentSel = null; m._conf = 0; rendre(); } else { m._conf = Date.now(); UI.toast('Touche encore « Réinitialiser » pour rendre tous tes points'); } }
  };
};
UI.boutonAuto = (api) => {
  let b = document.getElementById('btnAuto');
  if (!b) {
    b = document.createElement('button'); b.id = 'btnAuto'; b.type = 'button';
    b.innerHTML = '<i></i>AUTO';
    b.addEventListener('pointerdown', (e) => { e.stopPropagation(); e.preventDefault(); b.classList.toggle('on', api.basculerAuto()); });
    document.getElementById('hud').appendChild(b);
  }
  b.classList.toggle('on', api.autoActif());
};
UI.construireSorts = (joueur) => {
  const zone = $('#sorts'); zone.innerHTML = '';
  for (const k of TOUCHES) {
    const b = document.createElement('button'); b.className = 'sort'; b.id = 's-' + k; b.dataset.k = k;
    let svg = '', lettre = k.length === 1 ? k : '';
    if (k === 'ATK') { const t = joueur.armeType; svg = svgSort(t, '#ffe2a0', '#6a3a10', 'atk'); }
    else if (k === 'POT') svg = svgSort('potion', '#ffd0d8', '#5a0a18', 'pot');
    else if (k === 'CIBLE') svg = svgSort('cible', '#ffcf9a', '#3a1a10', 'cib');
    else { const s = joueur.sorts[k]; svg = s ? svgSort(s.glyphe, s.couleur[0], s.couleur[1], k) : svgSort('', '#3a3440', '#141016', k); if (!s) b.classList.add('off'); }
    if (joueur.sorts[k] && joueur.sorts[k].vole) b.classList.add('vole');
    const signe = '';
    if (signe && G.gestes !== false) b.classList.add('indic'); // en mode signes : le bouton montre le symbole à dessiner et la recharge
    b.innerHTML = `<div class="cadre"><div>${svg}<div class="cd"></div><div class="num"></div></div></div>${signe}${lettre && !signe ? `<span class="t">${lettre}</span>` : ''}${k === 'POT' ? '<span class="compte"></span>' : ''}`;
    b.setAttribute('aria-label', k === 'ATK' ? 'Attaque' : k === 'POT' ? 'Potion' : k === 'CIBLE' ? 'Verrouiller la cible' : (joueur.sorts[k]?.nom || 'Vide'));
    // sort visable : on garde le doigt appuyé, un cercle montre la portée, on glisse pour choisir sa cible, on relâche pour lancer
    let vise = null;
    const go = (e) => {
      e.preventDefault(); e.stopPropagation();
      try { b.setPointerCapture(e.pointerId); } catch (er) {} // le doigt peut glisser hors du bouton sans tout couper
      if ('QWERDF'.includes(k) && api.visable(k)) { vise = { id: e.pointerId, x: e.clientX, y: e.clientY, bouge: false }; api.viseeDebut(k); b.classList.add('vise'); return; }
      api.touche(k, true);
    };
    const bouge = (e) => {
      if (!vise || e.pointerId !== vise.id) return;
      const dx = e.clientX - vise.x, dy = e.clientY - vise.y;
      if (!vise.bouge && Math.hypot(dx, dy) > 38) vise.bouge = true; // un petit glissement du pouce ne compte pas comme une visée
      if (vise.bouge) api.viseeDir(dx, dy);
    };
    const fin = (e) => {
      e.preventDefault();
      if (vise) { if (e.pointerId !== vise.id) return; const v = vise; vise = null; b.classList.remove('vise'); api.viseeFin(k, e.type !== 'pointercancel'); return; }
      api.touche(k, false);
    };
    b.addEventListener('pointerdown', go); b.addEventListener('pointermove', bouge); b.addEventListener('pointerup', fin); b.addEventListener('pointercancel', fin);
    b.addEventListener('lostpointercapture', (e) => { if (!vise) fin(e); });
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
  // filtre rouge quand la vie est basse : il pulse comme un cœur et s'efface quand la vie remonte
  const ratio = j.pv / st.pvMax, k = j.mort ? 0 : Math.max(0, Math.min(1, (0.38 - ratio) / 0.3));
  const vg = E('vignetteVie'); if (vg) { sty(vg, 'opacity', k.toFixed(2)); sty(vg, '--v', '1'); }
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
  const el = E('bossbar');
  if (!b) { if (!el.hidden) el.hidden = true; return; }
  if (el.hidden) el.hidden = false;
  txt(E('bNom'), b.nom);
  sty(E('bFill'), 'transformOrigin', 'left');
  sty(E('bFill'), 'transform', `scaleX(${Math.max(0, b.pv / b.pvMax).toFixed(3)})`);
  txt(E('bTxt'), `${fmt(Math.max(0, b.pv))} / ${fmt(b.pvMax)}`);
};
// file d'annonces centrales : une seule à la fois, jamais de superposition
const fileC = []; let fileOcc = false;
function suivantFile() {
  const it = fileC.shift(); if (!it) { fileOcc = false; return; }
  fileOcc = true; const k = fileC.length >= 2 ? 0.55 : fileC.length === 1 ? 0.8 : 1;
  const d = it.montrer(); if (d) d.classList.add('fileC');
  setTimeout(() => { if (d) { d.classList.add('fileOut'); setTimeout(() => d.remove(), 300); } setTimeout(suivantFile, 120); }, it.duree * k * 1000);
}
UI.enFile = (montrer, duree, cle) => {
  if (cle) { const i = fileC.findIndex(x => x.cle === cle); if (i >= 0) { fileC[i] = { montrer, duree, cle }; return; } }
  fileC.push({ montrer, duree, cle }); if (!fileOcc) suivantFile();
};
UI.toast = (txt, grand = false) => {
  if (grand) { UI.enFile(() => { const d = document.createElement('div'); d.textContent = txt; d.className = 'grand'; $('#toast').appendChild(d); return d; }, 1.9); return; }
  const t = $('#toast'); [...t.children].filter(x => !x.classList.contains('grand')).slice(0, -2).forEach(x => x.remove());
  if ([...t.children].some(x => x.textContent === txt)) return;
  const d = document.createElement('div'); d.textContent = txt; t.appendChild(d); setTimeout(() => d.remove(), 2700);
};
UI.chat = (nom, txt) => {
  const log = $('#chatLog'); const d = document.createElement('div');
  d.innerHTML = `[Français] <b></b>: <span></span>`; d.querySelector('b').textContent = nom; d.querySelector('span').textContent = txt;
  log.appendChild(d); while (log.children.length > 2) log.firstChild.remove();
  setTimeout(() => d.remove(), 9000);
};
// ---------------- Émoticônes ----------------
const bulles = new Map();
const EMO = Object.fromEntries(EMOTES.map(e => [e.id, e]));
UI.emote = (ent, id, nom = null) => {
  const e = EMO[id]; if (!e || !ent) return;
  const old = bulles.get(ent); if (old) old.d.remove();
  const d = document.createElement('div'); d.className = 'emoteBulle' + (e.texte ? ' txt' : '');
  d.innerHTML = e.texte ? `<span style="color:${e.c}">${e.g}</span>` : `<span>${e.g}</span>`;
  $('#labels').appendChild(d);
  const b = { d, h: (ent.hauteurPlaque || 2.5) + 1.15 }; bulles.set(ent, b);
  setTimeout(() => { if (bulles.get(ent) === b) { bulles.delete(ent); } d.remove(); }, 2700);
  if (nom) UI.chat(nom, e.g);
};
function majBulles() {
  for (const [ent, b] of bulles) {
    const pos = ent.pos || ent.root.position;
    _v.set(pos.x, pos.y + b.h, pos.z); const s = projeter(_v);
    const vis = s.visible;
    if (vis !== b.vis) { b.vis = vis; b.d.style.visibility = vis ? '' : 'hidden'; }
    if (!vis) continue;
    const x = Math.round(s.x), y = Math.round(s.y);
    if (x !== b.x || y !== b.y) { b.x = x; b.y = y; b.d.style.transform = `translate(${x}px,${y}px) translate(-50%,-100%)`; }
  }
}
UI.panneauEmotes = () => {
  const p = $('#emotes');
  if (!p.hidden) { p.hidden = true; return; }
  p.innerHTML = EMOTES.map(e => `<button data-e="${e.id}" aria-label="${e.nom}">${e.texte ? `<b style="color:${e.c}">${e.g}</b>` : e.g}<small>${e.nom}</small></button>`).join('');
  p.hidden = false;
  p.querySelectorAll('[data-e]').forEach(b => b.onclick = (ev) => { ev.stopPropagation(); p.hidden = true; api.emote(b.dataset.e); });
};
UI.action = (texte, cb) => {
  const b = $('#action');
  if (!texte) { b.hidden = true; b.onclick = null; return; }
  if (b.textContent !== texte) b.textContent = texte;
  b.hidden = false; b.onclick = (e) => { e.stopPropagation(); cb(); };
};
// chiffres de dégâts : au plus 26 à l'écran (au-delà, le téléphone passe son temps à mettre la page en page)
let nbNombres = 0;
UI.nombre = (pos, txt, classe = '') => {
  if (nbNombres >= 26 && classe !== 'crit' && classe !== 'joueur') return;
  const p = projeter(G.solH ? new THREE.Vector3(pos.x, pos.y + G.solH(pos.x, pos.z), pos.z) : pos); if (!p.visible) return;
  const d = document.createElement('div'); d.className = 'dmg contour ' + classe; d.textContent = txt;
  d.style.left = (p.x + (Math.random() - 0.5) * 30) + 'px'; d.style.top = p.y + 'px';
  $('#nombres').appendChild(d); nbNombres++; setTimeout(() => { d.remove(); nbNombres--; }, 900);
};
// compteur de performances (Réglages)
let perfEl = null;
UI.perf = (on) => { if (on && !perfEl) { perfEl = document.createElement('div'); perfEl.id = 'perfHud'; document.body.appendChild(perfEl); } if (!on && perfEl) { perfEl.remove(); perfEl = null; } };
UI.majPerf = (txt) => { if (perfEl) perfEl.textContent = txt; };

// ---------------- Plaques de nom ----------------
const plaques = new Map();
UI.plaque = (ent, { nom, guilde = '', classe = '', vie = true, lettre = true, ip = null, niv = null }) => {
  const d = document.createElement('div'); d.className = 'plaque contour ' + classe;
  const ini = lettre ? `<b>${nom[0]}</b>` : '';
  d.innerHTML = `<div class="n">${ini}${lettre ? nom.slice(1) : nom}</div>${guilde || ip ? `<div class="gd">${guilde}${niv ? `<span class="nivb">Niv. ${niv}</span>` : ''}${ip ? `<span class="ipb">⚔ ${ip}</span>` : ''}</div>` : ''}${vie ? '<div class="vie"><i></i></div>' : ''}`;
  $('#labels').appendChild(d); plaques.set(ent, { d, barre: d.querySelector('.vie i'), h: ent.hauteurPlaque || 2.5 });
};
UI.retirerPlaque = (ent) => { const p = plaques.get(ent); if (p) { p.d.remove(); plaques.delete(ent); } };
UI.viderPlaques = () => { for (const p of plaques.values()) p.d.remove(); plaques.clear(); for (const b of bulles.values()) b.d.remove(); bulles.clear(); };
const _v = new THREE.Vector3();
UI.majPlaques = (centre) => {
  for (const [ent, p] of plaques) {
    const pos = ent.pos || ent.root.position;
    const lim = ent.drapeauPorte ? 70 : 30; let vis = !ent.mort && Math.abs(pos.x - centre.x) < lim && Math.abs(pos.z - centre.z) < lim;
    let s = null;
    if (vis) { _v.set(pos.x, pos.y + p.h + (G.solH ? G.solH(pos.x, pos.z) : 0), pos.z); s = projeter(_v); vis = s.visible && s.x > -80 && s.x < innerWidth + 80 && s.y > -40 && s.y < innerHeight + 40; }
    if (!vis) { if (p.vis !== false) { p.d.style.display = 'none'; p.vis = false; } continue; }
    if (p.vis !== true) { p.d.style.display = ''; p.vis = true; }
    const x = Math.round(s.x), y = Math.round(s.y);
    if (x !== p.x || y !== p.y) { p.d.style.transform = `translate(${x}px,${y}px) translate(-50%,-100%)`; p.x = x; p.y = y; }
    const pd = ent.drapeauPorte || null; if (pd !== p.pd) { p.pd = pd; p.d.classList.toggle('porteurB', pd === 'bleu'); p.d.classList.toggle('porteurR', pd === 'rouge'); }
    if (p.barre && ent.pvMax) { const w = Math.max(0, Math.round(ent.pv / ent.pvMax * 100)); if (w !== p.w) { p.barre.style.width = w + '%'; p.w = w; } }
    // compte à rebours des invocations, en temps réel
    if (ent.vieT !== undefined) {
      const t = Math.max(0, Math.ceil(ent.vieT));
      if (t !== p.t) { p.t = t; const g = p.gd || (p.gd = p.d.querySelector('.gd')); if (g) { g.textContent = `⏳ ${t} s`; g.classList.toggle('urgent', t <= 5); } }
    }
  }
  if (bulles.size) majBulles();
};

// ---------------- Mini-carte ----------------
UI.mini = (monde, joueur, entites) => {
  const cv = $('#miniCv'), g = cv.getContext('2d');
  g.clearRect(0, 0, 256, 256);
  let x0, z0, x1, z1;
  if (monde.type === 'hub') { x0 = monde.bornes.x0 - 4; x1 = monde.bornes.x1 + 4; z0 = monde.bornes.z0 - 4; z1 = monde.bornes.z1 + 4; }
  else if (monde.type === 'arene') { x0 = z0 = -monde.rayon - 3; x1 = z1 = monde.rayon + 3; }
  else if (monde.type === 'ile') { x0 = z0 = -monde.rayonMonde - 14; x1 = z1 = monde.rayonMonde + 14; }
  else if (monde.type === 'sylve' || monde.type === 'goulet') { x0 = monde.bornes.x0; x1 = monde.bornes.x1; z0 = monde.bornes.z0; z1 = monde.bornes.z1; }
  else { x0 = 0; z0 = 0; x1 = monde.grilleW * 4; z1 = monde.grilleH * 4; }
  const ech = 236 / Math.max(x1 - x0, z1 - z0), ox = 128 - (x0 + x1) / 2 * ech, oz = 128 - (z0 + z1) / 2 * ech;
  const P = (x, z) => [ox + x * ech, oz + z * ech];
  if (!monde._fond) {
    const c = document.createElement('canvas'); c.width = c.height = 256; const f = c.getContext('2d');
    if (monde.type === 'hub') { f.fillStyle = '#4a5f8a'; const [a, b] = P(monde.bornes.x0, monde.bornes.z0); f.fillRect(a, b, (monde.bornes.x1 - monde.bornes.x0) * ech, (monde.bornes.z1 - monde.bornes.z0) * ech); f.fillStyle = '#6a80b0'; f.beginPath(); f.arc(...P(0, 0), 10 * ech, 0, 7); f.fill(); }
    else if (monde.type === 'sylve') {
      f.fillStyle = '#1e3a24'; f.fillRect(0, 0, 256, 256);
      f.strokeStyle = '#8fd07a'; f.lineCap = 'round'; f.lineJoin = 'round'; f.lineWidth = 9.2 * ech; f.beginPath();
      monde.segs.forEach(([a, b], i) => { if (!i) f.moveTo(...P(a.x, a.z)); f.lineTo(...P(b.x, b.z)); }); f.stroke();
      for (const s of monde.salles) { f.fillStyle = '#a8e090'; f.beginPath(); f.arc(...P(s.c.x, s.c.z), s.r * ech, 0, 7); f.fill(); f.strokeStyle = '#3affa0'; f.lineWidth = 1.5; f.stroke(); }
    }
    else if (monde.type === 'ile') { f.fillStyle = '#2a5a8a'; f.fillRect(0, 0, 256, 256); f.fillStyle = '#6aa85a'; f.beginPath(); f.arc(...P(0, 0), monde.rayonMonde * ech, 0, 7); f.fill(); for (const p of monde.plots) { f.fillStyle = p.bati ? '#c8a060' : '#ffd25a66'; f.beginPath(); f.arc(...P(p.pos.x, p.pos.z), 4 * ech, 0, 7); f.fill(); } }
    else if (monde.type === 'goulet') {
      f.fillStyle = '#3a4a28'; f.fillRect(0, 0, 256, 256); f.fillStyle = '#6a7a42'; const [a0, b0] = P(-78, -30); f.fillRect(a0, b0, 156 * ech, 60 * ech);
      for (const [k, c, sx] of [['bleu', '#3a7aff', -1], ['rouge', '#ff3a3a', 1]]) { const [a, b] = P(sx > 0 ? 46 : -76, -18); f.fillStyle = c + '55'; f.fillRect(a, b, 30 * ech, 36 * ech); const cm = monde.bases[k].cimetiere; const [g1, g2] = P(cm.x, cm.z); f.fillStyle = '#d8f4ff'; f.fillRect(g1 - 2, g2 - 5, 4, 10); f.fillRect(g1 - 5, g2 - 2, 10, 4); }
      f.strokeStyle = '#e8dcc0'; f.lineWidth = Math.max(2, 1.6 * ech); f.lineCap = 'round'; for (const [x0, z0, x1, z1] of monde.murs) { f.beginPath(); f.moveTo(...P(x0, z0)); f.lineTo(...P(x1, z1)); f.stroke(); }
    }
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
    else if (e.type === 'errant') { const k = 7 + 2.5 * Math.sin(performance.now() / 150); g.fillStyle = '#c06aff'; g.shadowColor = '#a03aff'; g.shadowBlur = 16; g.beginPath(); g.arc(a, b, k, 0, 7); g.fill(); g.shadowBlur = 0; g.strokeStyle = '#ffd27a'; g.lineWidth = 2; g.stroke(); }
    else if (e.type === 'envahisseur') { const k = 6 + 2 * Math.sin(performance.now() / 120); g.fillStyle = '#ff1a1a'; g.shadowColor = '#ff0000'; g.shadowBlur = 14; g.beginPath(); g.arc(a, b, k, 0, 7); g.fill(); g.shadowBlur = 0; g.strokeStyle = '#fff'; g.lineWidth = 1.5; g.stroke(); }
    else if (e.type === 'portailJ') { g.fillStyle = '#ffc84a'; g.shadowColor = '#ffc84a'; g.shadowBlur = 8; g.beginPath(); g.arc(a, b, 5, 0, 7); g.fill(); g.shadowBlur = 0; }
    else if (e.type === 'portailV') { g.fillStyle = '#b05aff'; g.shadowColor = '#b05aff'; g.shadowBlur = 8; g.beginPath(); g.arc(a, b, 6, 0, 7); g.fill(); g.shadowBlur = 0; }
    else if (e.type === 'bonusBG') { g.fillStyle = e.c; g.beginPath(); g.arc(a, b, 3, 0, 7); g.fill(); }
    else if (e.type === 'drapeau' && e.porte) { const k = 9 + 3 * Math.sin(performance.now() / 140); g.strokeStyle = e.c; g.lineWidth = 2.5; g.beginPath(); g.arc(a, b - 1, k, 0, 7); g.stroke(); g.fillStyle = e.c; g.strokeStyle = '#fff'; g.lineWidth = 2; g.beginPath(); g.moveTo(a, b + 7); g.lineTo(a, b - 10); g.lineTo(a + 10, b - 5); g.lineTo(a, b - 1); g.stroke(); g.fill(); }
    else if (e.type === 'drapeau') { g.fillStyle = e.c; g.strokeStyle = '#fff'; g.lineWidth = 2; g.beginPath(); g.moveTo(a, b + 6); g.lineTo(a, b - 8); g.lineTo(a + 8, b - 4); g.lineTo(a, b - 1); g.stroke(); g.fill(); }
    else if (e.type === 'rouge') { g.fillStyle = '#ff4a3a'; g.beginPath(); g.arc(a, b, 3.6, 0, 7); g.fill(); }
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
  const tabs = `<div class="ongletsInv"><button data-t="equip" class="${ongletInv === 'equip' ? 'actif' : ''}">Équipement</button><button data-t="maitrise" class="${ongletInv === 'maitrise' ? 'actif' : ''}">Maîtrise</button><button data-t="profil" class="${ongletInv === 'profil' ? 'actif' : ''}">Profil</button></div>`;
  $('#inv').innerHTML = `<div class="cadreInv parchemin">
    <button class="fermer" data-x aria-label="Fermer">×</button>
    <div style="display:flex;flex-direction:column;min-height:0">
      <div class="titreInv"><div class="portraitInv"><canvas id="silCv" width="256" height="256"></canvas></div><div class="nomInv"><small>Inventaire de</small><h2>${j.nom}</h2></div>${tabs}</div>
      ${ongletInv === 'profil' ? htmlProfil(j) : ongletInv === 'maitrise' ? htmlMaitrise(j) : `
      <div class="poupee">
        <div class="pv">${caseVide('sac')}</div><div>${slot('casque', 'Tête')}</div><div class="pv">${caseVide('cape')}</div>
        <div>${slot('arme', 'Arme')}</div><div>${slot('plastron', 'Torse')}</div><div class="pv fantome">${j.equip.arme && ['epee', 'arbalete', 'baton'].includes(j.equip.arme.type) ? htmlCase(j.equip.arme, 'libre') : caseVide('main')}</div>
        <div class="pv">${caseVide('repas')}</div><div>${slot('bottes', 'Pieds')}</div><div>${htmlCase({ id: 0, cat: 'potion', type: 'soin', tier: 0, q: 0, n: j.potions || 0 }, 'libre')}</div>
      </div>
      <div class="bilanInv"><span><span class="piece"></span>${fmt(j.argent)}</span><span class="ipInv">⚔ ${st.ip}</span><span>🏆 ${fmt(j.trophees || 0)}</span></div>
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
  if ($('#silCv')) { const tA = j.equip.arme ? j.equip.arme.type : 'epee'; const mj = api.modeleJoueur && api.modeleJoueur(); bustePersonnage(ARMES[tA].model, $('#silCv'), tA === 'ombre' ? '#3a1a5a' : '#6a4a3a', mj ? null : ARMES[tA].ombre ? TEINTES_OMBRE : null, { cadrage: 'corps', source: mj }); }
  $('#inv').querySelectorAll('[data-t]').forEach(b => b.onclick = () => { ongletInv = b.dataset.t; api.son('click_001', 0.4); UI.rendreInventaire(); });
  $('#inv').querySelector('[data-x]').onclick = () => { $('#inv').hidden = true; api.son('close_001', 0.4); };
  $('#inv').querySelectorAll('[data-id]').forEach(b => b.onclick = () => { const it = j.sac.find(i => i.id == b.dataset.id); UI.fiche(it, 'sac'); });
  const bc = $('#inv').querySelector('#codeOk');
  const ci = $('#inv').querySelector('#codeIn'); if (ci && bc) ci.onkeydown = (e) => { if (e.key === 'Enter') bc.click(); };
  if (bc) bc.onclick = () => { const r = api.code($('#inv').querySelector('#codeIn').value); const m = $('#inv').querySelector('#codeMsg'); m.textContent = r.texte; m.className = r.ok ? 'ok' : 'ko'; if (r.ok) setTimeout(() => UI.rendreInventaire(), 1600); };
  $('#inv').querySelectorAll('[data-eq]').forEach(b => b.onclick = () => { const it = j.equip[b.dataset.eq]; if (it) UI.fiche(it, 'equipe'); });
};

// Fiche détaillée d'un objet (un seul clic)
// Fiche détaillée d'un objet : grande, riche, lisible
const STAT_MAX = { degats: 900, dps: 1400, vitesse: 1.6, crit: 16, portee: 13, armure: 260, pv: 2200, regen: 1.6, bonusDeg: 12, recharge: 15, pvp: 10 };
UI.fiche = (it, contexte) => {
  if (!it) return;
  api.son('select_001', 0.4);
  const j = api.etat();
  const st = statsObjet(it);
  const slot = it.cat === 'arme' ? 'arme' : it.cat === 'armure' ? it.type : null;
  const porte = slot ? j.equip[slot] : null;
  const stP = porte && porte.id !== it.id ? statsObjet(porte) : null;
  const libelles = { bonusDeg: 'Bonus de dégâts', recharge: 'Recharge des sorts', pvp: 'Contre les joueurs', degats: 'Dégâts par coup', dps: 'Dégâts par seconde', vitesse: it.cat === 'arme' ? "Vitesse d'attaque" : 'Vitesse de déplacement', crit: 'Chance de critique', portee: 'Portée', armure: 'Armure', pv: 'Points de vie', regen: 'Régénération' };
  const unite = { vitesse: it.cat === 'arme' ? '/s' : ' %', crit: ' %', portee: ' m', regen: ' %/s', bonusDeg: ' %', recharge: ' %', pvp: ' %' };
  const t = it.tier ? TIERS[it.tier] : null;
  const q = QUALITES[it.q || 0];
  const tc = t ? t.color : '#8a6a4a';
  const lignes = Object.entries(st).map(([k, v]) => {
    let diff = '';
    if (stP && stP[k] !== undefined) { const d = v - stP[k]; if (Math.abs(d) > 0.001) diff = `<span class="${d > 0 ? 'plus' : 'moins'}">${d > 0 ? '▲' : '▼'} ${Math.abs(+d.toFixed(2))}</span>`; }
    const pct = Math.max(4, Math.min(100, v / (STAT_MAX[k] || v) * 100));
    return `<div class="statF"><span class="lib">${libelles[k] || k}</span><div class="barreF"><i style="width:${pct.toFixed(0)}%"></i></div><b>${typeof v === 'number' && !Number.isInteger(v) ? v.toFixed(k === 'vitesse' && it.cat === 'arme' ? 2 : 1) : fmt(v)}${unite[k] || ''}</b><span class="diff">${diff}</span></div>`;
  }).join('');
  const sorts = sortsObjet(it).map(s => `<div class="s">${svgSort(s.glyphe, s.couleur[0], s.couleur[1], 'f' + s.touche)}<div><b>${s.touche} · ${s.nom}</b> <span class="cdS">${s.cd} s · ${s.energie} énergie</span><br>${s.desc}</div></div>`).join('');
  const boutons = [];
  const ok = peutPorter(it);
  if (contexte === 'sac' && slot) boutons.push(`<button class="btn or" data-a="equiper" ${ok ? '' : 'disabled'}>Équiper</button>`);
  if (contexte === 'sac' && it.cat === 'potion') boutons.push(`<button class="btn or" data-a="ranger">Ranger dans la ceinture</button>`);
  if (contexte === 'sac' && it.cat === 'parchemin') boutons.push(`<button class="btn or" data-a="parch">Lire le parchemin (30 min)</button>`);
  if (contexte === 'equipe') boutons.push(`<button class="btn gris" data-a="retirer">Retirer</button>`);
  if (contexte === 'vente') boutons.push(`<button class="btn" data-a="vendre">Vendre ${fmt(prixVente(it))}</button>`);
  if (contexte === 'achat') boutons.push(`<button class="btn" data-a="acheter">Acheter ${fmt(valeurObjet(it))}</button>`);
  if (contexte === 'arene') boutons.push(`<button class="btn" data-a="acheterArene" ${(j.trophees || 0) + (j.renom || 0) >= prixTrophees(it) ? '' : 'disabled'}>Acheter 🏆 ${fmt(prixTrophees(it))}</button>`);
  const req = slot ? (() => { const n = niveauDe(it.type), r = niveauRequis(it); const nomM = MAITRISES.find(m => m.id === it.type).nom; return `<p class="req ${n >= r ? 'okr' : 'ko'}">${n >= r ? '✔' : '🔒'} Niveau requis : ${nomM} ${r} · ${n >= r ? 'tu es niveau ' + n : 'tu n’es que niveau ' + n}${n > 1 ? ` · bonus de maîtrise +${(bonusMaitrise(n) * 100).toFixed(1).replace('.', ',')} %` : ''}</p>`; })() : '';
  const vInfo = it.arene ? `<p class="varArene" style="--vc:${VARIANTES[it.arene].couleur}"><b>Objet d’arène · ${VARIANTES[it.arene].style}.</b> ${VARIANTES[it.arene].texte} +10 % contre les joueurs.</p>` : '';
  const etoiles = slot ? `<div class="etoiles">${[1, 2, 3, 4].map(k => `<span class="${(it.q || 0) >= k ? 'on' : ''}">★</span>`).join('')}</div>` : '';
  const ench = slot ? `<div class="enchF" title="Enchantement">${Array.from({ length: 6 }, (_, k) => `<i class="${(it.ench || 0) > k ? 'on' : ''}"></i>`).join('')}<small>${it.ench ? `+${it.ench} · équivaut à un T${(it.tier + it.ench / 2).toString().replace('.', ',')}` : 'Non enchanté'}</small></div>` : '';
  const desc = it.cat === 'parchemin' ? (() => { const p = PARCHEMINS[it.type], C = COULEURS_PARCH[p.couleur]; return `<b>+${Math.round(p.bonus * 100)} % ${C.texte}</b> pendant 30 minutes de jeu dans la Brèche Écarlate. Le temps ne s’écoule que dans la Brèche, et se met en pause si tu envahis ou pendant le combat contre des envahisseurs. Tu peux cumuler des couleurs différentes ; deux parchemins de la même couleur additionnent leur durée.`; })() : it.cat === 'potion' ? 'Rend 40 % de tes PV en 1 s. Se boit avec le bouton potion.' : it.cat === 'butin' ? (it.type === 'rune' ? 'Sert à graver un enchantement chez Ysolde, la graveuse de runes, sur la Place. Jusqu’à +6 par objet : deux enchantements valent un tier.' : 'Ne sert à rien, sauf à être vendu au marchand.') : '';
  $('#fiche').innerHTML = `<div class="carteObjet riche" style="--tc:${tc}"><button class="fermer" data-x aria-label="Fermer">×</button>
    <div class="bandeau"><span>${t ? `TIER ${t.roman} · ${t.nom.toUpperCase()}` : categorieLabel(it).toUpperCase()}</span>${slot ? `<span class="qual" style="color:${q.color}">${q.nom}</span>` : ''}</div>
    <div class="corpsF">
      <div class="gaucheF">
        <div class="vitrine"><div class="halo"></div>${htmlCase(it, '', 'width:100%;height:100%')}</div>
        ${etoiles}${ench}
        ${slot ? `<div class="ipF"><small>PUISSANCE</small><b>${puissanceObjet(it)}</b></div>` : ''}
      </div>
      <div class="droiteF">
        <div class="titre">${nomObjet(it)}</div>
        <div class="sous">${categorieLabel(it)}</div>
        ${req}${vInfo}
        ${lignes ? `<div class="statsF">${lignes}</div>` : `<p class="descF">${desc}</p>`}
        ${sorts ? `<div class="sortsObj">${sorts}</div>` : ''}
        ${porte && porte.id !== it.id ? `<p class="compare">Comparé à ton ${nomObjet(porte)} (${TIERS[porte.tier].roman}) : ▲ mieux, ▼ moins bien.</p>` : ''}
        <p class="valeurF">Valeur <b>${fmt(valeurObjet(it))}</b> · Revente <b>${fmt(prixVente(it))}</b></p>
      </div>
    </div>
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
    if (a === 'parch') api.utiliserParchemin(it.id);
    if (!$('#inv').hidden) UI.rendreInventaire();
    if (!$('#marche').hidden) UI.rendreMarche();
  });
};
// ---------------- Ysolde, la graveuse de runes ----------------
let choixRune = null;
UI.runes = () => {
  const j = api.etat(); const d = $('#portailMenu');
  const objets = [...['arme', 'casque', 'plastron', 'bottes'].map(s => j.equip[s]).filter(Boolean), ...j.sac.filter(i => i.cat === 'arme' || i.cat === 'armure')];
  if (!choixRune || !objets.find(o => o.id === choixRune)) choixRune = objets[0] && objets[0].id;
  const it = objets.find(o => o.id === choixRune);
  const nb = api.nbRunes();
  let detail = '<p class="vide">Tu n’as aucun objet à enchanter.</p>';
  if (it) {
    const c = coutEnchant(it); const e = it.ench || 0;
    const avant = statsObjet(it), apres = c ? statsObjet({ ...it, ench: e + 1 }) : null;
    const lib = { degats: 'Dégâts', dps: 'DPS', armure: 'Armure', pv: 'Points de vie', crit: 'Critique', vitesse: it.cat === 'arme' ? 'Vit. d’attaque' : 'Vitesse', regen: 'Régénération' };
    const lignes = apres ? Object.keys(lib).filter(k => avant[k] !== undefined && avant[k] !== apres[k]).map(k => `<div class="evo"><span>${lib[k]}</span><b>${fmt(avant[k])}</b><em>➜</em><b class="nouv">${fmt(apres[k])}</b></div>`).join('') : '';
    detail = `<div class="ficheRune" style="--tc:${TIERS[it.tier].color}">
      <div class="teteR"><div class="caseR">${htmlCase(it, '', 'width:100%;height:100%')}</div><div><b>${nomObjet(it)}</b><small>Tier ${TIERS[it.tier].roman} · ${QUALITES[it.q || 0].nom}</small>
        <div class="enchF">${Array.from({ length: 6 }, (_, k) => `<i class="${e > k ? 'on' : ''} ${e === k && c ? 'proch' : ''}"></i>`).join('')}</div></div></div>
      ${c ? `<div class="evos"><div class="evo titreE"><span>Puissance</span><b>${puissanceObjet(it)}</b><em>➜</em><b class="nouv">${puissanceObjet({ ...it, ench: e + 1 })}</b></div>${lignes}</div>
        <div class="cout"><span class="${nb >= c.runes ? 'ok' : 'ko'}"><i class="runeIco"></i> ${c.runes} runes <small>(tu en as ${nb})</small></span><span class="${j.argent >= c.argent ? 'ok' : 'ko'}"><span class="piece"></span> ${fmt(c.argent)}</span><span class="${c.chance < 1 ? 'risque' : 'ok'}">Réussite ${Math.round(c.chance * 100)} %</span></div>
        ${c.chance < 1 ? '<p class="avert">Au-delà de +3, la gravure peut échouer : les runes et l’argent sont perdus, l’objet reste intact.</p>' : ''}
        <button class="btn bleu grand" data-g ${nb >= c.runes && j.argent >= c.argent ? '' : 'disabled'}>Graver l’enchantement +${e + 1}</button>`
      : '<p class="max">Enchantement maximal atteint : +6. Cet objet vaut un tier de plus que trois paliers au-dessus.</p>'}
    </div>`;
  }
  d.innerHTML = `<div class="cadreP runes"><button class="fermer" data-x aria-label="Fermer">×</button>
    <h2>Ysolde, graveuse de runes</h2><div class="sous">Jusqu’à +6 enchantements par objet. Deux enchantements valent un tier : un T1 +2 équivaut à un T2. Ton argent : <b>${fmt(j.argent)}</b></div>
    <div class="runesCorps"><div class="listeR">${objets.map(o => `<button class="${o.id === choixRune ? 'choisi' : ''}" data-o="${o.id}">${htmlCase(o)}</button>`).join('')}</div>
    <div class="detailR">${detail}
      <div class="achatR"><span><i class="runeIco"></i> Rune d’enchantement · 5 000</span><button class="btn gris" data-r="1">Acheter 1</button><button class="btn gris" data-r="5">Acheter 5 (25 000)</button><button class="btn gris" data-r="20">Acheter 20 (100 000)</button></div>
    </div></div></div>`;
  d.hidden = false; d.onclick = (ev) => { if (ev.target === d) d.hidden = true; };
  d.querySelector('[data-x]').onclick = () => (d.hidden = true);
  d.querySelectorAll('[data-o]').forEach(b => b.onclick = () => { choixRune = +b.dataset.o || b.dataset.o; api.son('click_001', 0.4); UI.runes(); });
  d.querySelectorAll('[data-r]').forEach(b => b.onclick = () => { if (api.acheterRunes(+b.dataset.r)) UI.runes(); });
  const g = d.querySelector('[data-g]');
  if (g) g.onclick = () => {
    g.disabled = true; g.classList.add('grave');
    setTimeout(() => { const r = api.enchanter(it.id); if (r.ok) UI.toast(r.reussi ? `Gravure réussie : ${nomObjet(it)}` : 'La rune s’est brisée… l’objet est intact', true); UI.runes(); }, 700);
  };
};
function shade(c) { const S = THREE.SRGBColorSpace; const col = new THREE.Color(c); const hsl = {}; col.getHSL(hsl, S); return '#' + new THREE.Color().setHSL(hsl.h, Math.min(1, hsl.s * 1.15), Math.min(hsl.l, 0.34), S).getHexString(S); }

// ---------------- Marchand ----------------
let stock = null, ongletM = 'achat';
const filtres = { cat: 'tout', niv: 'tout', q: 'tout', txt: '' };
UI.dialogueMarchand = () => {
  const d = $('#dialogue');
  d.innerHTML = `<div class="boiteDial bois"><button class="fermer" data-x aria-label="Fermer">×</button><div class="visage"><canvas id="visageCv" width="128" height="128"></canvas></div>
  <div><h3>Borin, marchand de la Place</h3><p>Bienvenue, voyageur. Le bronze et l'azur, je les ai. Le reste, faudra aller le chercher de l'autre côté de la Brèche… et revenir vivant pour me le revendre.</p>
  <div class="choix"><button class="btn or" data-c="achat">Acheter</button><button class="btn" data-c="vente">Vendre</button><button class="btn violet" data-c="parch">Parchemins</button><button class="btn gris" data-c="infos">Parle-moi des tiers</button><button class="btn gris" data-x2>Au revoir</button></div></div></div>`;
  d.hidden = false; bustePersonnage('Barbarian', $('#visageCv'), '#8a5a2a');
  api.son('bookOpen', 0.5);
  const fermer = () => { d.hidden = true; };
  d.querySelector('[data-x]').onclick = fermer; d.querySelector('[data-x2]').onclick = fermer;
  d.querySelectorAll('[data-c]').forEach(b => b.onclick = () => {
    if (b.dataset.c === 'infos') {
      d.querySelector('p').innerHTML = 'Du <b style="color:#c9c1b4">T1 Rouillé</b> au <b style="color:#fff0b0">T8 Céleste</b> : rouillé, bronze, <b style="color:#6be27a">sylvestre</b>, <b style="color:#7ab0ff">azur</b>, <b style="color:#ff7a5a">braise</b>, <b style="color:#ffb84a">solaire</b>, <b style="color:#c88aff">abyssal</b>, céleste. Chaque tier frappe environ 40 % plus fort que le précédent. La qualité, de Normal à Chef-d’œuvre, ajoute jusqu’à 40 %.';
      return;
    }
    if (b.dataset.c === 'parch') { fermer(); UI.boutiqueParchemins(); return; }
    fermer(); ongletM = b.dataset.c; UI.ouvrirMarche();
  });
};
let stockA = null;
UI.ouvrirMarche = (onglet = null) => { const rr = api.raresDebloques(), om = rr.join(','); if (!stock || stock.ombre !== om) { stock = stockMarchand(rr); stock.ombre = om; } if (!stockA) stockA = stockArene(); if (onglet) { ongletM = onglet; if (onglet === 'arene') { filtres.niv = 'tout'; filtres.q = 'tout'; } } UI.rendreMarche(); $('#marche').hidden = false; api.son('open_001', 0.4); };
UI.rendreMarche = () => {
  const j = api.etat();
  const A = ongletM === 'arene';
  const source = ongletM === 'achat' ? stock : A ? stockA : j.sac;
  const prix = (it) => A ? prixTrophees(it) : ongletM === 'achat' ? valeurObjet(it) : prixVente(it);
  const solde = A ? j.trophees : j.argent;
  const liste = source.filter(it => {
    if (filtres.cat !== 'tout') {
      const c = it.cat === 'arme' ? 'arme' : it.cat === 'armure' ? it.type : it.cat;
      if (filtres.cat.startsWith('arme:')) { if (it.cat !== 'arme' || it.type !== filtres.cat.slice(5)) return false; }
      else if (c !== filtres.cat) return false;
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
      <select id="fCat" aria-label="Catégorie">${opt('tout', 'Catégorie : tout', filtres.cat)}${opt('arme', 'Toutes les armes', filtres.cat)}${opt('arme:epee', '— Épées à deux mains', filtres.cat)}${opt('arme:arbalete', '— Arbalètes lourdes', filtres.cat)}${opt('arme:baton', '— Bâtons de feu', filtres.cat)}${opt('arme:arc', '— Arcs du Maître des bêtes', filtres.cat)}${api.raresDebloques().includes('ombre') ? opt('arme:ombre', '— Dagues des Ombres', filtres.cat) : ''}${api.raresDebloques().includes('orage') ? opt('arme:orage', '— Haches de l’Orage', filtres.cat) : ''}${opt('casque', 'Armure de tête', filtres.cat)}${opt('plastron', 'Armure de poitrine', filtres.cat)}${opt('bottes', 'Armure de pieds', filtres.cat)}${opt('potion', 'Consommable', filtres.cat)}${opt('butin', 'Butin', filtres.cat)}</select>
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
    <div class="enteteRang">${emblemeRang(api.rang('donjon').i, 9)}<div><small>TON RANG DANS LA BRÈCHE</small><b style="color:${RANGS[api.rang('donjon').i].c1}">${RANGS[api.rang('donjon').i].nom}</b>${barreRang(api.rang('donjon'))}<small>${api.rang('donjon').i ? `Monstres et boss +${15 * api.rang('donjon').i} % · envahisseurs plus forts · argent +${25 * api.rang('donjon').i} % · coffres et objets de meilleure qualité` : 'Monte en rang : ennemis plus forts, mais butin et argent bien meilleurs.'}</small></div><button class="btn gris" data-cl="donjon">Classement</button></div>
    <h2>La Brèche Écarlate</h2><div class="sous">Quatre gardiens, quatre coffres. La couleur du coffre se voit en entrant ; il ne s’ouvre qu’une fois son gardien tombé.</div>
    <div class="modes">${MODES.map(m => {
      const ok = ip >= m.ipConseil;
      return `<div class="mode" style="--c:${m.couleur}"><div class="niv">NIVEAU ${m.id + 1}</div><h3>${m.nom}</h3><div class="lieu">${m.lieu}</div>
      <div class="tiers">${Array.from({ length: m.tiers[1] - m.tiers[0] + 1 }, (_, i) => m.tiers[0] + i).map(t => `<span style="background:${TIERS[t].color}">T${t}</span>`).join('')}</div>
      <p>${m.texte}</p><div class="ipl"><span>Puissance conseillée</span><b>${m.ipConseil}</b></div><div class="ipl"><span>Ta puissance</span><b class="${ok ? 'ok' : 'ko'}">${ip}</b></div>
      <div class="btnsMode"><button class="btn ${ok ? 'or' : ''}" data-m="${m.id}">${ok ? 'Entrer' : 'Entrer quand même'}</button>${m.abime ? '' : `<button class="btn hard" data-h="${m.id}" title="Monstres ×3, or et XP ×3">☠ Hard</button>`}</div></div>`;
    }).join('')}</div></div>`;
  const sy = document.createElement('div'); sy.className = 'carteSylve';
  sy.innerHTML = `<div class="feuilles"></div><div class="txtS"><div class="niv">DONJON DE GROUPE · 5 JOUEURS</div><h3>Sanctuaire d’Émeraude</h3>
    <p>Une forêt magique, un seul chemin, quatre gardiens. Le dernier, Verdanthos, ne pardonne rien : il faut bouger, esquiver, jouer ensemble. Scores après chaque boss, coffre final pour tout le groupe.</p>
    <div class="tiers"><span style="background:${TIERS[Math.max(1, Math.min(8, Math.round((ip - 320) / 100) + 1))].color}">Butin à ton niveau</span><span style="background:#3affa0;color:#06301a">Coffre légendaire</span></div></div>
    <button class="btn vert" data-sylve>Rechercher un groupe</button>`;
  $('#portailMenu .cadreP').appendChild(sy);
  sy.querySelector('[data-sylve]').onclick = () => { $('#portailMenu').hidden = true; api.sylve(); };
  const inv = document.createElement('div'); inv.className = 'invasion';
  inv.innerHTML = `<div><h4>Être envahi</h4><label class="bascule"><input type="checkbox" id="accInv" ${j.accepteInvasion ? 'checked' : ''}><span>Ouvrir mon monde aux invasions</span></label>
    <p>+25 % d’argent dans les coffres. Un joueur peut surgir dans ton donjon. S’il te tue, il emporte tout ton équipement porté.</p></div>
    <div><h4>Envahir</h4><p>Entre dans le donjon d’un joueur de puissance proche. Tue-le et choisis ce que tu prends dans son équipement. Meurs et tu perds le tien.</p>
    <button class="btn" data-envahir>Envahir un joueur</button></div>`;
  $('#portailMenu .cadreP').appendChild(inv);
  $('#portailMenu').querySelectorAll('[data-cl]').forEach(b => b.onclick = () => UI.classement(b.dataset.cl));
  inv.querySelector('#accInv').onchange = (e) => api.accepterInvasion(e.target.checked);
  inv.querySelector('[data-envahir]').onclick = () => { $('#portailMenu').hidden = true; api.envahir(); };
  const p = $('#portailMenu'); p.hidden = false; api.son('forceField_000', 0.5);
  p.querySelector('[data-x]').onclick = () => (p.hidden = true);
  p.querySelectorAll('[data-m]').forEach(b => b.onclick = () => { p.hidden = true; api.entrer(+b.dataset.m); });
  p.querySelectorAll('[data-h]').forEach(b => b.onclick = () => { p.hidden = true; api.entrer(+b.dataset.h, true); });
};

// ---------------- Butin d'un coffre ----------------
// carte de butin : médaillon du coffre, bonus, grille d'objets par tier, valeur marchande estimée
function svgCoffre(col) {
  return `<svg viewBox="0 0 100 100"><defs><linearGradient id="cb" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#d8d4cc"/><stop offset="1" stop-color="#6a6660"/></linearGradient></defs>
    <circle cx="50" cy="50" r="48" fill="#2a2622"/><circle cx="50" cy="50" r="44" fill="#4a4540"/>
    <path d="M20 46 C20 30 80 30 80 46 L80 52 L20 52 Z" fill="url(#cb)" stroke="#1a1714" stroke-width="2.5"/>
    <rect x="20" y="50" width="60" height="28" rx="3" fill="url(#cb)" stroke="#1a1714" stroke-width="2.5"/>
    <path d="M20 58 L80 58 M34 36 L34 78 M66 36 L66 78" stroke="#1a1714" stroke-width="3" opacity=".7"/>
    <rect x="44" y="50" width="12" height="14" rx="2" fill="${col}" stroke="#1a1714" stroke-width="2"/><circle cx="50" cy="56" r="2.4" fill="#1a1714"/></svg>`;
}
function caseBourse(v) { return `<div class="case tiere bourse" style="--tc:#9aa0aa"><img src="${'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svgButin('bourse'))}" alt=""><span class="nb">${fmtK(v)}</span></div>`; }
UI.butin = (couleur, loot, cb) => {
  const c = COFFRES.find(x => x.id === couleur) || { nom: 'Coffre', color: '#c9a052', desc: '' };
  const valeur = loot.argent + loot.objets.reduce((a, it) => a + valeurObjet(it) * (it.n || 1), 0);
  const bonus = (loot.bonus || []).map(b => `<div class="bonusL"><span class="icB" style="background:${b.c}">${b.i}</span>+${b.pct} % <small>${b.txt}</small></div>`).join('');
  $('#butin').innerHTML = `<div class="lootCarte" style="--cc:${c.color}">
    <div class="lcTete"><div class="medaille">${svgCoffre(c.color)}</div><div class="lcTitre"><small>Butin du</small><h2>${c.nom}</h2>${bonus}</div></div>
    <div class="lcGrille">${loot.argent ? `<div class="lcItem" style="animation-delay:.15s">${caseBourse(loot.argent)}</div>` : ''}${loot.objets.map((it, i) => `<button class="lcItem" data-i="${i}" style="animation-delay:${0.25 + i * 0.12}s">${htmlCase(it, 'libre')}</button>`).join('')}</div>
    ${loot.allie ? `<div class="partAllie"><b>Part de ${loot.allie.nom}</b> · ${fmt(loot.allie.argent)} d’argent</div>` : ''}
    <div class="lcPied"><div><small>Valeur marchande estimée :</small><b><span class="piece"></span>${fmtK(valeur)}</b></div><button class="btn or" data-ok>${loot.allie ? 'Prendre ma part' : 'Tout prendre'}</button></div></div>`;
  const b = $('#butin'); b.hidden = false;
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
    <label>Position des sorts <input type="range" id="rDec" min="0" max="35" step="1" value="${parseInt(getComputedStyle(document.documentElement).getPropertyValue('--decalSorts')) || 18}" style="width:22vh"></label>
    <label>Musique <input type="checkbox" id="rM" ${G.musiqueOn !== false ? 'checked' : ''} style="width:3vh;height:3vh"></label>
    <label>Afficher les FPS <input type="checkbox" id="rP" ${G.perfOn ? 'checked' : ''} style="width:3vh;height:3vh"></label>
    <label>Plein écran <button class="btn gris" id="rF">Activer</button></label>
    <label>Sauvegarde <button class="btn" id="rR">Effacer et recommencer</button></label>
    <p id="rConf" style="font-size:2vh;margin:0" hidden>Touche encore pour confirmer : tout ton équipement sera perdu.</p></div>`;
  r.hidden = false;
  r.querySelector('[data-x]').onclick = () => (r.hidden = true);
  r.querySelector('#rQ').onchange = (e) => api.qualite(e.target.value);
  r.querySelector('#rDec').oninput = (e) => { document.documentElement.style.setProperty('--decalSorts', e.target.value + 'vw'); try { localStorage.setItem('breche-decal', e.target.value); } catch (er) {} };
  r.querySelector('#rM').onchange = (e) => { api.musique(e.target.checked); try { localStorage.setItem('breche-musique', e.target.checked ? '1' : '0'); } catch (er) {} };
  r.querySelector('#rS').onchange = (e) => { G.son = e.target.checked; if (G.master) G.master.gain.value = G.son ? 0.6 : 0; };
  r.querySelector('#rP').onchange = (e) => { G.perfOn = e.target.checked; UI.perf(G.perfOn); try { localStorage.setItem('breche-perf', G.perfOn ? '1' : ''); } catch (er) {} };
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
function htmlProfil(j) {
  const codes = (j.codes || []);
  return `<div class="profil">
    <div class="ligneP"><span>Joueur</span><b>${j.nom}</b></div>
    <div class="ligneP"><span>Guilde</span><b>CROW ZERO</b></div>
    <div class="ligneP"><span>Trophées d’arène</span><b>🏆 ${fmt(j.trophees || 0)}</b></div>
    ${codes.length ? `<div class="badgeBeta">✦ Bêta-testeur</div>` : ''}
    <h3>Code bêta</h3>
    <p>Un code donne accès en avant-première à du contenu en test. Chaque code ne marche qu’une fois par profil.</p>
    <div class="codeL"><input id="codeIn" type="text" autocomplete="off" autocapitalize="characters" spellcheck="false" placeholder="ENTRE TON CODE" maxlength="24"><button class="btn or" id="codeOk">Valider</button></div>
    <div id="codeMsg"></div>
  </div>`;
}
function htmlMaitrise(j) {
  const portes = new Set(['arme', 'casque', 'plastron', 'bottes'].map(s => j.equip[s] && j.equip[s].type).filter(Boolean));
  const possede = (id) => ['arme'].some(s => j.equip[s] && j.equip[s].type === id) || j.sac.some(i => i.type === id);
  return `<div class="maitrise">${MAITRISES.filter(m => !m.rare || possede(m.id) || (j.maitrise[m.id] && (j.maitrise[m.id].niv > 1 || j.maitrise[m.id].xp > 0))).map(m => {
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
  ${(api.xpLog() || []).length ? `<div class="xpLog"><h4>Dernières sources d’expérience</h4>${api.xpLog().map(l => `<div><span>${l.s}</span><b>+${fmt(l.x)} XP</b><small>${Math.max(0, Math.round((Date.now() - l.t) / 60000))} min</small></div>`).join('')}</div>` : ''}
  <p class="mAide">Seules les pièces que tu portes gagnent de l’expérience. Chaque niveau ajoute 0,2 % de puissance brute à ce type de pièce, puis 2 % par niveau du 90 au 100.</p></div>`;
}

// ---------------- Arène ----------------
UI.menuArene = (groupe) => {
  const j = api.etat(); const ip = statsHeros(j.equip).ip;
  const p = $('#portailMenu');
  p.innerHTML = `<div class="cadreP arene"><button class="fermer" data-x aria-label="Fermer">×</button>
    <div class="enteteRang">${emblemeRang(api.rang('arene').i, 9)}<div><small>TON RANG D’ARÈNE</small><b style="color:${RANGS[api.rang('arene').i].c1}">${RANGS[api.rang('arene').i].nom}</b>${barreRang(api.rang('arene'))}<small>${api.rang('arene').i ? `Adversaires +${7 * api.rang('arene').i} % PV/dégâts, plus malins · trophées +${25 * api.rang('arene').i} %` : 'Monte en rang : adversaires plus forts, récompenses plus grosses.'}</small></div><button class="btn gris" data-cl="arene">Classement</button></div>
    <h2>Arène des Échos</h2><div class="sous">Combats entre joueurs. Chaque victoire rapporte 🏆 100 trophées et de l’expérience. Ton équipement ne se perd pas ici.</div>
    <div class="modes deux">
      <div class="mode" style="--c:#b05aff"><div class="niv">DUEL</div><h3>1 contre 1</h3><p>Un adversaire de puissance proche. Rien que toi et lui.</p>
        <div class="ipl"><span>Ta puissance</span><b>${ip}</b></div><button class="btn or" data-f="1v1">Trouver un adversaire</button></div>
      <div class="mode" style="--c:#4fd1ff"><div class="niv">ÉQUIPE</div><h3>2 contre 2</h3><p>${groupe ? `Avec <b>${groupe.nom}</b> (⚔ ${groupe.ip}), ton coéquipier de groupe.` : 'Tu n’as pas de groupe : un coéquipier sera trouvé pour toi. Touche un joueur sur la Place pour former un groupe.'}</p>
        <div class="ipl"><span>Équipe</span><b>${groupe ? 'Groupe' : 'Aléatoire'}</b></div><button class="btn or" data-f="2v2">Trouver un combat</button></div>
    </div>
    <div class="letale"><div><div class="niv">ARÈNE LÉTALE</div><h3>Ton stuff est en jeu</h3><p>Le perdant repart à poil : il perd tout son équipement porté (il garde son argent et son sac). Le gagnant fouille les dépouilles et gagne 🏆 200 trophées.</p></div>
      <div class="boutonsL"><button class="btn rouge" data-l="1v1">1 contre 1</button><button class="btn rouge" data-l="2v2">2 contre 2</button></div></div>
    <div class="barreTroph"><div><span class="troph" style="font-size:3.4vh">🏆</span><b>${fmt(j.trophees || 0)}</b> trophées · <b style="color:#c9a0ff">✦ ${fmt(j.renom || 0)}</b> renommée</div><button class="btn" data-shop>Boutique des trophées</button></div></div>`;
  p.hidden = false; api.son('forceField_000', 0.5, 0.8);
  p.querySelector('[data-x]').onclick = () => (p.hidden = true);
  p.querySelectorAll('[data-f]').forEach(b => b.onclick = () => { p.hidden = true; api.arene(b.dataset.f); });
  p.querySelectorAll('[data-cl]').forEach(b => b.onclick = () => UI.classement(b.dataset.cl));
  p.querySelectorAll('[data-l]').forEach(b => b.onclick = () => {
    if (b.dataset.ok) { p.hidden = true; api.arene(b.dataset.l, { letale: true }); return; }
    b.dataset.ok = '1'; b.textContent = 'Confirmer : je risque mon stuff'; api.son('error_001', 0.3, 0.6);
  });
  p.querySelector('[data-shop]').onclick = () => { p.hidden = true; UI.ouvrirMarche('arene'); };
};
UI.resultatArene = (r, cb) => {
  const m = $('#mort');
  m.innerHTML = `<div class="resultat ${r.victoire ? 'gagne' : 'perdu'}"><h2>${r.titre || (r.victoire ? 'Victoire' : 'Défaite')}</h2>
    <div class="recap">${r.lignes.map(l => `<div>${l}</div>`).join('')}</div>
    <div class="actionsRes">${r.refaire ? `<button class="btn vert" data-re>↻ Refaire</button>` : ''}<button class="btn or" data-ok>Revenir sur la Place</button></div></div>`;
  m.hidden = false; m.querySelector('[data-ok]').onclick = () => { m.hidden = true; cb(false); };
  const re = m.querySelector('[data-re]'); if (re) re.onclick = () => { m.hidden = true; cb(true); };
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

// ---------------- Sanctuaire d'Émeraude ----------------
const COUL_CLASSE = { epee: '#ff6a5a', arbalete: '#5aff9a', baton: '#ffab3a', ombre: '#b07aff', arc: '#ff3a3a', orage: '#7ab8ff', assassin: '#ff5a6a' };
const fmtK = (n) => n >= 1e6 ? (n / 1e6).toFixed(2).replace('.', ',') + ' M' : n >= 1e4 ? (n / 1e3).toFixed(1).replace('.', ',') + ' k' : fmt(n);
const fmtT = (s) => `${Math.floor(s / 60)} min ${String(Math.floor(s % 60)).padStart(2, '0')}`;
UI.rechercheGroupe = (membres, cb) => {
  const d = $('#butin'); const j = api.etat();
  const slot = (m, i) => m ? `<div class="slotG plein" style="--c:${COUL_CLASSE[m.equip.arme.type]};animation-delay:${i * 0.1}s"><div class="icoC">${svgSort(m.equip.arme.type, '#ffe2a0', '#3a2a10', 'g' + i)}</div><b>${m.nom}</b><small>${m.guilde || ''}</small><span>⚔ ${m.ip}</span>${m.trait && TRAITS[m.trait] ? `<em class="trait" title="${TRAITS[m.trait].desc}">${TRAITS[m.trait].ico} ${TRAITS[m.trait].nom}</em>` : ''}</div>` : `<div class="slotG"><div class="cherche"></div><small>Recherche…</small></div>`;
  const moi = { nom: j.nom, guilde: 'CROW ZERO', ip: statsHeros(j.equip).ip, equip: j.equip };
  let n = 0;
  const rendre = () => {
    d.innerHTML = `<div class="cadreG"><h2>${n < membres.length ? 'Recherche de groupe…' : 'Groupe complet !'}</h2><div class="sous">Sanctuaire d’Émeraude · 5 joueurs</div>
      <div class="slotsG">${slot(moi, 0)}${membres.map((m, i) => slot(i < n ? m : null, i + 1)).join('')}</div>
      ${n >= membres.length ? '<button class="btn vert grand" data-go>Entrer dans le Sanctuaire</button>' : '<button class="btn gris" data-annule>Annuler</button>'}</div>`;
    const go = d.querySelector('[data-go]'); if (go) go.onclick = () => { d.hidden = true; cb(); };
    const an = d.querySelector('[data-annule]'); if (an) an.onclick = () => { clearInterval(iv); d.hidden = true; };
  };
  d.hidden = false; rendre(); api.son('forceField_000', 0.4, 1.3);
  const iv = setInterval(() => { n++; api.son('select_001', 0.4, 1 + n * 0.1); rendre(); if (n >= membres.length) { clearInterval(iv); api.son('jingle_win', 0.4, 1.2); } }, 750);
};
UI.introBoss = (nom, titre, couleur) => {
  const d = document.createElement('div'); d.className = 'introBoss'; d.style.setProperty('--c', couleur);
  d.innerHTML = `<div class="trait"></div><h2>${nom}</h2><p>${titre}</p><div class="trait"></div>`;
  document.body.appendChild(d); setTimeout(() => d.remove(), 3600);
};
function tableauScorescores(lignes, opts = {}) {
  const max = Math.max(1, ...lignes.map(l => l.degats));
  return lignes.map((l, i) => `<div class="rangScore ${l.moi ? 'moi' : ''}" style="--c:${COUL_CLASSE[l.type] || '#fff'};animation-delay:${0.15 + i * 0.12}s">
    <div class="rang">${i === 0 ? '👑' : i + 1}</div><div class="icoC">${svgSort(l.type, '#ffe2a0', '#3a2a10', 's' + i + (opts.id || ''))}</div>
    <div class="nomS"><b>${l.nom}</b><small>${ARMES[l.type] ? ARMES[l.type].court : ''} · ⚔ ${l.ip}</small></div>
    <div class="barreS"><i style="width:${(l.degats / max * 100).toFixed(1)}%"></i><span>${fmtK(l.degats)}</span></div>
    <div class="chiffres"><b>${fmtK(l.dps)}/s</b><small>${Math.round(l.part * 100)} %</small></div>
    ${opts.butin && l.butin ? `<div class="butinS"><span class="arg"><span class="piece"></span>${fmtK(l.butin.argent)}</span>${l.butin.objets.map(it => `<span class="mini">${htmlCase(it)}</span>`).join('')}</div>` : ''}</div>`).join('');
}
UI.scores = (data, cb) => {
  const d = $('#butin');
  d.innerHTML = `<div class="cadreS" style="--c:${data.couleur}"><h2>${data.titre}</h2><div class="sous">${data.sous} · combat ${fmtT(data.duree)}</div>
    <div class="enteteS"><span>Joueur</span><span>Dégâts</span><span>DPS · part</span></div>
    <div class="tableauScores">${tableauScorescores(data.lignes)}</div>
    <div class="partage">Coffre du gardien : <b>${fmt(data.butin.pool)}</b> pièces, partagé en ${data.butin.nb} → <b>${fmt(data.butin.argent)}</b> chacun</div>
    <div class="butinBoss"><span class="titreB">Ton butin</span><span class="arg"><span class="piece"></span>+ ${fmt(data.butin.argent)}</span>${data.butin.objets.map((it, i) => `<button class="item" data-i="${i}" style="border:0;background:none;padding:0">${htmlCase(it)}</button>`).join('')}</div>
    <button class="btn vert grand" data-ok>Continuer</button></div>`;
  d.hidden = false;
  d.querySelectorAll('[data-i]').forEach(b => b.onclick = () => UI.fiche(data.butin.objets[+b.dataset.i], 'apercu'));
  d.querySelector('[data-ok]').onclick = () => { d.hidden = true; cb && cb(); };
};
UI.recapFinal = (data, cb) => {
  const d = $('#butin'); const moi = data.lignes.find(l => l.moi);
  d.innerHTML = `<div class="cadreS final" style="--c:#3affa0"><div class="eclat"></div><h2>Sanctuaire purifié</h2>
    <div class="sous">4 gardiens vaincus · ${fmtT(data.duree)} · ${fmtK(data.total)} dégâts au total</div>
    <div class="partage">Trésor du Sanctuaire : <b>${fmt(data.pool)}</b> pièces, partagé en ${data.lignes.length} → <b>${fmt(Math.round(data.pool / data.lignes.length))}</b> chacun</div>
    <div class="enteteS"><span>Joueur</span><span>Dégâts totaux</span><span>DPS · part</span><span>Butin</span></div>
    <div class="tableauScores">${tableauScorescores(data.lignes, { butin: true, id: 'f' })}</div>
    <div class="butinBoss"><span class="titreB">Ton coffre</span><span class="arg"><span class="piece"></span>+ ${fmt(moi.butin.argent)}</span>${moi.butin.objets.map((it, i) => `<button class="item" data-i="${i}" style="border:0;background:none;padding:0">${htmlCase(it)}</button>`).join('')}</div>
    <button class="btn vert grand" data-ok>Récupérer mon butin</button></div>`;
  d.hidden = false;
  d.querySelectorAll('[data-i]').forEach(b => b.onclick = () => UI.fiche(moi.butin.objets[+b.dataset.i], 'apercu'));
  d.querySelector('[data-ok]').onclick = () => { d.hidden = true; cb && cb(); };
};

UI.alerteInvasion = (n, subie) => {
  const d = document.createElement('div'); d.className = 'alerteInv';
  d.innerHTML = `<div class="voile"></div><h2>${subie ? 'Invasion !' : 'Tu envahis un monde'}</h2><p>${subie ? `Vous avez été envahis par ${n} joueur${n > 1 ? 's' : ''}` : `${n} joueur${n > 1 ? 's' : ''} à traquer`}</p><small>${subie ? 'Ils vous cherchent. Leur position apparaît par moments sur la carte.' : 'Leur position apparaît par moments sur la carte.'}</small>`;
  document.body.appendChild(d); setTimeout(() => d.remove(), 4200);
};
UI.ping = () => { const m = $('#carteCadre') || $('#hudD'); if (!m) return; m.classList.remove('ping'); void m.offsetWidth; m.classList.add('ping'); };

// ---------------- Rangs : emblèmes dessinés ----------------
export function emblemeRang(i, taille = 8) {
  const r = RANGS[i]; const id = 'rg' + i + Math.random().toString(36).slice(2, 7);
  const chevrons = Array.from({ length: Math.min(3, i + 1) }, (_, k) => `<path d="M30 ${78 - k * 11} L50 ${66 - k * 11} L70 ${78 - k * 11}" fill="none" stroke="${r.c3}" stroke-width="5.5" stroke-linecap="round" stroke-linejoin="round"/>`).join('');
  const ailes = i >= 4 ? `<g fill="url(#${id}a)" stroke="${r.c3}" stroke-width="1.5"><path d="M18 40 C2 34 -2 20 4 10 C10 22 16 26 24 28 Z"/><path d="M82 40 C98 34 102 20 96 10 C90 22 84 26 76 28 Z"/></g>` : '';
  const couronne = i >= 5 ? `<path d="M34 10 L40 0 L46 8 L50 -2 L54 8 L60 0 L66 10 Z" fill="#ffd27a" stroke="#6a3a00" stroke-width="1.5"/>` : '';
  const etoile = i >= 3 ? `<path d="M50 24 l3.5 7 7.5 1 -5.5 5 1.5 7.5 -7 -3.6 -7 3.6 1.5 -7.5 -5.5 -5 7.5 -1z" fill="${r.c1}" stroke="${r.c3}" stroke-width="1.2"/>` : `<circle cx="50" cy="36" r="6" fill="${r.c1}" stroke="${r.c3}" stroke-width="1.5"/>`;
  return `<svg class="embleme" viewBox="-4 -6 108 112" style="width:${taille}vh;height:${taille}vh" aria-label="${r.nom}"><defs>
    <linearGradient id="${id}m" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${r.c1}"/><stop offset=".45" stop-color="${r.c2}"/><stop offset="1" stop-color="${r.c3}"/></linearGradient>
    <linearGradient id="${id}a" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${r.c1}"/><stop offset="1" stop-color="${r.c2}"/></linearGradient>
    <filter id="${id}f"><feDropShadow dx="0" dy="2" stdDeviation="2" flood-color="#000" flood-opacity=".6"/></filter></defs>
    <g filter="url(#${id}f)">${ailes}
    <path d="M50 4 L88 16 L84 58 C80 80 64 94 50 102 C36 94 20 80 16 58 L12 16 Z" fill="url(#${id}m)" stroke="${r.c3}" stroke-width="3"/>
    <path d="M50 12 L80 22 L77 57 C74 75 62 86 50 93 C38 86 26 75 23 57 L20 22 Z" fill="none" stroke="${r.c1}" stroke-opacity=".7" stroke-width="2"/>
    ${etoile}${chevrons}${couronne}</g></svg>`;
}
function barreRang(rg) {
  const max = rg.max;
  return `<div class="barreRang"><i style="width:${max ? rg.local / max * 100 : 100}%;background:linear-gradient(90deg,${rg.r.c2},${rg.r.c1})"></i><span>${max ? `${rg.local} / ${max} pts` : `${rg.local} pts`}</span></div>`;
}
UI.changementRang = (avant, apres, delta, raison) => {
  const d = document.createElement('div'); const monte = apres.i > avant.i, descend = apres.i < avant.i;
  d.className = 'changeRang ' + (monte ? 'monte' : descend ? 'descend' : '');
  d.innerHTML = `${emblemeRang(apres.i, monte || descend ? 12 : 7)}<div><small>${apres.mode === 'arene' ? 'ARÈNE' : 'BRÈCHE'} · ${raison}</small>
    <b style="color:${apres.r.c1}">${monte ? 'PROMOTION : ' : descend ? 'RÉTROGRADÉ : ' : ''}${apres.r.nom}</b>${barreRang(apres)}<em class="${delta >= 0 ? 'plus' : 'moins'}">${delta >= 0 ? '+' : ''}${delta} pts</em></div>`;
  UI.enFile(() => { document.body.appendChild(d); return d; }, monte || descend ? 4 : 2.4);
};
UI.classement = (mode) => {
  const c = api.classement(mode); const rg = c.rang;
  const d = $('#butin');
  d.innerHTML = `<div class="cadreCl" style="--c1:${rg.r.c1};--c2:${rg.r.c2}"><button class="fermer" data-x aria-label="Fermer">×</button>
    <div class="ongCl"><button data-m="arene" class="${mode === 'arene' ? 'actif' : ''}">Arène</button><button data-m="donjon" class="${mode === 'donjon' ? 'actif' : ''}">Brèche</button></div>
    <div class="teteCl">${emblemeRang(rg.i, 14)}<div><small>LIGUE</small><h2>${rg.r.nom}</h2>${barreRang(rg)}<p>${rg.i < RANGS.length - 1 ? `Victoire +20 · défaite −15. À 100 pts, promotion en <b>${RANGS[rg.i + 1].nom}</b>. Sous 0, retour en ${rg.i ? RANGS[rg.i - 1].nom : 'Bronze'}.` : 'Le sommet. Tes adversaires sont les meilleurs du jeu.'}</p></div></div>
    <div class="echelle">${RANGS.map((r, k) => `<div class="${k === rg.i ? 'ici' : k < rg.i ? 'fait' : ''}">${emblemeRang(k, 5)}<small>${r.nom}</small></div>`).join('')}</div>
    <div class="listeCl">${c.liste.map((l, k) => `<div class="${l.moi ? 'moi' : ''}"><span class="pos">${k + 1}</span><b>${l.nom}</b><small>${l.tag || ''}</small><span class="pts">${l.pts} pts</span></div>`).join('')}</div></div>`;
  d.hidden = false;
  d.querySelector('[data-x]').onclick = () => (d.hidden = true);
  d.querySelectorAll('[data-m]').forEach(b => b.onclick = () => UI.classement(b.dataset.m));
};
// ---------------- Jauge d'expérience ----------------
UI.jaugeXP = (lignes, source) => {
  // version compacte, en haut au centre, qui ne gêne pas le combat
  document.querySelectorAll('.jaugeXP').forEach(x => x.remove());
  const d = document.createElement('div'); d.className = 'jaugeXP mini';
  d.innerHTML = `<div class="srcXP">${source} · <b>+${fmt(lignes.reduce((a, l) => a + l.gain, 0))} XP</b></div>` + lignes.map(l => `<div class="lXP"><small>${l.nom.replace('Armure de ', '').replace('Épée à deux mains', 'Épée')}</small><div class="bXP"><i style="--k:${(l.k * 100).toFixed(1)}%"></i></div><em>niv. ${l.niv}</em></div>`).join('');
  document.body.appendChild(d); setTimeout(() => d.classList.add('part'), 3200); setTimeout(() => d.remove(), 3800);
};
UI._jaugeXPGrande = (lignes, source) => {
  document.querySelectorAll('.jaugeXP').forEach(x => x.remove());
  const d = document.createElement('div'); d.className = 'jaugeXP';
  d.innerHTML = `<div class="srcXP">${source} · <b>+${fmt(lignes.reduce((a, l) => a + l.gain, 0))} XP</b></div>` + lignes.map(l => `<div class="lXP"><span class="ic">${svgSort(['casque', 'plastron', 'bottes'].includes(l.type) ? 'shield' : l.type, '#ffe2a0', '#3a2a10', 'x' + l.type)}</span>
    <div class="cXP"><div><b>${l.nom}</b><small>niv. ${l.niv}</small><em>+${fmt(l.gain)}</em></div><div class="bXP"><i style="--k:${(l.k * 100).toFixed(1)}%"></i></div><small class="resteXP">${l.niv >= 100 ? 'MAX' : `encore ${fmt(Math.max(0, l.reste))} XP pour le niv. ${l.niv + 1}`}</small></div></div>`).join('');
  document.body.appendChild(d); setTimeout(() => d.classList.add('part'), 4200); setTimeout(() => d.remove(), 4800);
};
// ---------------- Butin d'un pillage ----------------
UI.butinPillage = (b) => {
  const d = $('#butin'); const T = { bois: 'Bois', minerai: 'Minerai', recolte: 'Récoltes' };
  d.innerHTML = `<div class="cadreB parchemin pillage"><h2>Pillage réussi !</h2><div class="sous">L’île ${b.ile} de <b>${b.proprio}</b> est vidée.</div>
    <div class="tuilesP">
      <div class="tuileP"><img src="${iconeModele(RES_ICO[b.res])}" alt=""><b>${fmt(b.butin)}</b><small>${T[b.res]} volé${b.res === 'recolte' ? 'es' : ''}</small></div>
      ${b.ok ? `<div class="tuileP"><img src="${iconeModele('chest_gold')}" alt=""><b>${fmt(b.ok)}</b><small>rangés sur ${b.cible}</small></div>` : ''}
      ${b.argent ? `<div class="tuileP or"><span class="piece" style="width:7vh;height:7vh"></span><b>+${fmt(b.argent)}</b><small>${fmt(b.reste)} revendus sur place</small></div>` : ''}
    </div><button class="btn or" data-ok>Emporter le butin</button></div>`;
  d.hidden = false; d.querySelector('[data-ok]').onclick = () => (d.hidden = true);
};

// ---------------- Parchemins ----------------
const SYMB = {
  botte: '<path d="M34 30 h16 v26 l20 8 c6 2 8 6 8 10 v4 H30 v-8 l4 -4 z" fill="#fff" stroke="#0006" stroke-width="2"/><path d="M30 78 h48" stroke="#0006" stroke-width="3"/><path d="M14 46 h12 M10 56 h14 M14 66 h10" stroke="#fff" stroke-width="4" stroke-linecap="round" opacity=".85"/>',
  fleches: '<path d="M50 26 L70 46 H58 V54 H42 V46 H30 Z" fill="#fff" stroke="#0006" stroke-width="2"/><path d="M50 50 L70 70 H58 V80 H42 V70 H30 Z" fill="#fff" stroke="#0006" stroke-width="2" opacity=".85"/>',
  billet: '<rect x="22" y="38" width="56" height="30" rx="4" fill="#fff" stroke="#0006" stroke-width="2"/><circle cx="50" cy="53" r="8" fill="none" stroke="#2a7a2a" stroke-width="3"/><path d="M50 47 v12 M47 50 h5 a2 2 0 0 1 0 4 h-4 a2 2 0 0 0 0 4 h5" stroke="#2a7a2a" stroke-width="2" fill="none"/><rect x="26" y="42" width="6" height="22" fill="#9ad89a"/><rect x="68" y="42" width="6" height="22" fill="#9ad89a"/>',
  coffre: '<path d="M26 46 h48 v26 h-48 z" fill="#fff" stroke="#0006" stroke-width="2"/><path d="M26 46 c0 -14 48 -14 48 0" fill="#fff" stroke="#0006" stroke-width="2"/><rect x="45" y="50" width="10" height="10" rx="2" fill="#ffd27a" stroke="#0006"/><path d="M38 30 l3 6 M62 30 l-3 6 M50 26 v7" stroke="#fff" stroke-width="3" stroke-linecap="round"/>',
};
export function svgParchemin(id, taille = null) {
  const p = PARCHEMINS[id], C = COULEURS_PARCH[p.couleur]; const g = 'p' + id;
  const s = taille ? `style="width:${taille};height:${taille}"` : 'width="128" height="128"';
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" ${s}><defs><linearGradient id="${g}" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${C.c1}"/><stop offset=".55" stop-color="${C.c2}"/><stop offset="1" stop-color="${C.c3}"/></linearGradient></defs>
    <rect x="16" y="14" width="68" height="72" rx="4" fill="url(#${g})" stroke="${C.c3}" stroke-width="3"/>
    <rect x="10" y="8" width="80" height="12" rx="6" fill="${C.c1}" stroke="${C.c3}" stroke-width="3"/><rect x="10" y="80" width="80" height="12" rx="6" fill="${C.c1}" stroke="${C.c3}" stroke-width="3"/>
    <circle cx="10" cy="14" r="5" fill="${C.c2}" stroke="${C.c3}" stroke-width="2"/><circle cx="90" cy="14" r="5" fill="${C.c2}" stroke="${C.c3}" stroke-width="2"/><circle cx="10" cy="86" r="5" fill="${C.c2}" stroke="${C.c3}" stroke-width="2"/><circle cx="90" cy="86" r="5" fill="${C.c2}" stroke="${C.c3}" stroke-width="2"/>
    <g transform="translate(0 -4)">${SYMB[C.symbole]}</g>
    ${p.bonus >= 0.5 ? `<path d="M74 22 l3 6 6 1 -4.5 4 1 6 -5.5 -3 -5.5 3 1 -6 -4.5 -4 6 -1z" fill="#ffe27a" stroke="#6a4a00" stroke-width="1.2"/>` : ''}
    <text x="50" y="78" text-anchor="middle" font-family="sans-serif" font-weight="900" font-size="15" fill="#fff" stroke="${C.c3}" stroke-width="3" paint-order="stroke">+${Math.round(p.bonus * 100)}%</text></svg>`;
}
UI.boutiqueParchemins = () => {
  const j = api.etat(); const d = $('#portailMenu');
  const actifs = api.parchemins();
  const cartes = Object.entries(COULEURS_PARCH).map(([c, C]) => `<div class="colParch" style="--c1:${C.c1};--c2:${C.c2};--c3:${C.c3}"><h4>${C.nom}</h4><small>${C.texte}</small>
    ${['20', '50'].map(b => { const id = c + b, p = PARCHEMINS[id]; const nb = j.sac.filter(i => i.cat === 'parchemin' && i.type === id).reduce((a, i) => a + (i.n || 1), 0);
      return `<div class="carteParch ${b === '50' ? 'fort' : ''}">${svgParchemin(id, '11vh')}<b>+${b} %</b><span class="dur">30 min</span>${nb ? `<em>${nb} dans le sac</em>` : ''}
      <button class="btn" data-p="${id}">${BOUTIQUE_PARCH_GRATUITE ? `<s>${fmt(p.prix)}</s> Gratuit` : fmt(p.prix)}</button></div>`; }).join('')}</div>`).join('');
  d.innerHTML = `<div class="cadreP parch"><button class="fermer" data-x aria-label="Fermer">×</button>
    <h2>Parchemins de la Brèche</h2><div class="sous">Lis-les depuis ton sac. Ils ne s’écoulent que dans la Brèche Écarlate et se mettent en pause pendant une invasion. Combine les couleurs ; une même couleur additionne la durée.${BOUTIQUE_PARCH_GRATUITE ? ' <b class="beta">Accès bêta : gratuit</b>' : ''}</div>
    ${actifs.length ? `<div class="actifsP">${actifs.map(a => `<span style="--c2:${COULEURS_PARCH[a.couleur].c2}">${COULEURS_PARCH[a.couleur].nom} +${Math.round(a.bonus * 100)} % · ${Math.ceil(a.reste / 60)} min${a.pause ? ' · en pause' : ''}</span>`).join('')}</div>` : ''}
    <div class="grilleParch">${cartes}</div>
    <div class="carteTP"><svg viewBox="0 0 100 100" width="12vh" height="12vh"><defs><radialGradient id="gTP"><stop offset="0" stop-color="#fff2c0"/><stop offset=".5" stop-color="#ff5a2a"/><stop offset="1" stop-color="#5a0606"/></radialGradient></defs>
      <rect x="22" y="16" width="56" height="68" rx="6" fill="#f2dcae" stroke="#5a2a0e" stroke-width="3"/><rect x="16" y="10" width="68" height="12" rx="6" fill="#c8964a" stroke="#5a2a0e" stroke-width="3"/><rect x="16" y="78" width="68" height="12" rx="6" fill="#c8964a" stroke="#5a2a0e" stroke-width="3"/>
      <circle cx="50" cy="50" r="18" fill="url(#gTP)"/><path d="M50 36 L56 50 L50 64 L44 50Z" fill="#fff8e0"/><circle cx="50" cy="50" r="22" fill="none" stroke="#ff3a2a" stroke-width="2" stroke-dasharray="4 4"/></svg>
      <div><h4>Parchemin de téléportation</h4><small>Uniquement dans les donjons de la Brèche rouge : te transporte devant le prochain gardien encore debout. Usage unique.</small>
      ${j.parchTP ? `<em>${j.parchTP} en ta possession</em>` : ''}</div>
      <button class="btn or" data-tp>${fmt(api.prixTP())}</button></div></div>`;
  d.querySelector('[data-tp]').onclick = () => { if (api.acheterTP()) UI.boutiqueParchemins(); };
  d.hidden = false; d.onclick = (e) => { if (e.target === d) d.hidden = true; };
  d.querySelector('[data-x]').onclick = () => (d.hidden = true);
  d.querySelectorAll('[data-p]').forEach(b => b.onclick = () => { if (api.acheterParchemin(b.dataset.p, 1)) { UI.toast('Parchemin ajouté au sac'); UI.boutiqueParchemins(); } });
};
let parchCache = '';
UI.majParchemins = (liste) => {
  let el = document.getElementById('parchHud');
  if (!liste.length) { if (el) el.remove(); parchCache = ''; return; }
  if (!el) { el = document.createElement('div'); el.id = 'parchHud'; $('#jeu').appendChild(el); }
  const html = liste.map(p => { const C = COULEURS_PARCH[p.couleur]; const m = Math.floor(p.reste / 60), s = Math.floor(p.reste % 60);
    return `<div class="pH ${p.pause ? 'pause' : ''}" style="--c2:${C.c2}" title="${C.nom}">${svgParchemin(p.couleur + (p.bonus >= 0.5 ? '50' : '20'), '4.4vh')}<span>${p.pause ? '⏸' : `${m}:${String(s).padStart(2, '0')}`}</span></div>`; }).join('');
  if (html !== parchCache) { el.innerHTML = html; parchCache = html; }
};

// points de combo de l'assassin
let comboCache = -2;
UI.majCombo = (n) => {
  if (n === comboCache) return; comboCache = n;
  let el = document.getElementById('comboHud');
  if (n < 0) { if (el) el.remove(); return; }
  if (!el) { el = document.createElement('div'); el.id = 'comboHud'; $('#jeu').appendChild(el); }
  el.innerHTML = Array.from({ length: 5 }, (_, i) => `<i class="${i < n ? 'on' : ''} ${n >= 5 ? 'max' : ''}"></i>`).join('') + `<span>${n >= 5 ? 'CURÉE PRÊTE' : 'COMBO'}</span>`;
};

// ---------------- Sanctuaire : résumé discret et compteur de dégâts ----------------
UI.resumeBoss = (r) => {
  const d = document.createElement('div'); d.className = 'resumeBoss'; d.style.setProperty('--c', r.couleur);
  d.innerHTML = `<b>${r.nom} vaincu</b><span>Tu es <b>${r.rang}${r.rang === 1 ? 'er' : 'e'}</b> / ${r.nb} aux dégâts</span><span><span class="piece"></span> +${fmt(r.argent)} <small>(coffre ${fmt(r.pool)} ÷ ${r.nb})</small></span>${r.objets.length ? `<span class="objR">${r.objets.map(it => `<img src="${iconeObjet(it)}" alt="" style="border-color:${TIERS[it.tier].color}">`).join('')}</span>` : ''}`;
  document.body.appendChild(d); setTimeout(() => d.classList.add('part'), 4200); setTimeout(() => d.remove(), 4800);
};
let degatsOuvert = false, derniersDegats = null;
UI.boutonDegats = (on) => {
  let b = document.getElementById('btnDegats');
  if (!on) { if (b) b.remove(); const p = document.getElementById('dmgMeter'); if (p) p.remove(); degatsOuvert = false; return; }
  if (b) return;
  b = document.createElement('button'); b.id = 'btnDegats'; b.className = 'rond metal'; b.setAttribute('aria-label', 'Dégâts du groupe');
  b.innerHTML = '<svg viewBox="0 0 24 24" fill="#ffd0d0"><path d="M4 20V10h3v10zm6.5 0V4h3v16zM17 20v-7h3v7z"/></svg>';
  b.onclick = (e) => { e.stopPropagation(); degatsOuvert = !degatsOuvert; api.son('click_001', 0.4); UI.majDegats(derniersDegats); };
  $('#jeu').appendChild(b);
};
UI.majDegats = (lignes) => {
  derniersDegats = lignes;
  let p = document.getElementById('dmgMeter');
  if (!degatsOuvert || !lignes) { if (p) p.remove(); return; }
  if (!p) { p = document.createElement('div'); p.id = 'dmgMeter'; $('#jeu').appendChild(p); }
  const max = Math.max(1, ...lignes.map(l => l.degats));
  p.innerHTML = lignes.map((l, i) => `<div class="${l.moi ? 'moi' : ''}"><i style="width:${(l.degats / max * 100).toFixed(0)}%;background:${COUL_CLASSE[l.type] || '#aaa'}"></i><span>${i + 1}. ${l.nom}</span><b>${fmtK(l.degats)}</b></div>`).join('');
};
UI.emblemeHTML = (i, t) => emblemeRang(i, t);

// ======================= TAVERNE, MANGA ET MISSIONS =======================
// bulle de parole au-dessus d'un personnage
UI.parole = (ent, texte, classe = '') => {
  if (!ent || !texte) return;
  const old = bulles.get(ent); if (old) old.d.remove();
  const d = document.createElement('div'); d.className = 'paroleBulle ' + classe; d.innerHTML = `<span>${texte}</span>`;
  $('#labels').appendChild(d);
  const b = { d, h: (ent.hauteurPlaque || 2.5) + 1.0 }; bulles.set(ent, b);
  setTimeout(() => { if (bulles.get(ent) === b) bulles.delete(ent); d.remove(); }, 3400);
  if (ent.nom) UI.chat(ent.nom, texte);
};
// cases de manga : portrait, nom, réplique tapée lettre à lettre, lignes de vitesse
let mangaFile = [], mangaFin = null, mangaTimer = null;
UI.manga = (panneaux, fin = null) => {
  let m = document.getElementById('manga');
  if (!panneaux) { mangaFile = []; mangaFin = null; clearTimeout(mangaTimer); if (m) m.remove(); return; }
  mangaFile.push(...panneaux); if (fin) mangaFin = fin;
  if (!m) { m = document.createElement('div'); m.id = 'manga'; $('#jeu').appendChild(m); m.addEventListener('pointerdown', (e) => { e.stopPropagation(); suivant(); }); suivant(); }
  function suivant() {
    clearTimeout(mangaTimer);
    const p = mangaFile.shift();
    if (!p) { m.remove(); const f = mangaFin; mangaFin = null; if (f) f(); return; }
    m.className = (p.choc ? 'choc ' : '') + (p.cote === 'd' ? 'droite' : '');
    m.style.setProperty('--c', p.couleur || '#ffd27a');
    m.innerHTML = `<div class="caseM"><div class="lignes"></div><div class="portraitM"><canvas width="160" height="160"></canvas></div><div class="texteM"><div class="nomM">${p.nom}${p.titre ? `<small>${p.titre}</small>` : ''}</div><div class="repl"></div></div></div>`;
    try { bustePersonnage(p.modele || 'Knight', m.querySelector('canvas'), '#1a1014'); } catch (e) {}
    const r = m.querySelector('.repl'); let i = 0; const txt = p.texte || '';
    const tape = () => { r.textContent = txt.slice(0, ++i); if (i < txt.length) mangaTimer = setTimeout(tape, 22); else mangaTimer = setTimeout(suivant, Math.max(1600, txt.length * 55)); };
    tape();
  }
};
// carte-titre façon manga (nom de mission, nom d'ennemi)
UI.titreManga = (titre, sous = '') => {
  const d = document.createElement('div'); d.className = 'titreManga'; d.innerHTML = `<div class="tm">${titre}</div>${sous ? `<div class="ts">${sous}</div>` : ''}`;
  $('#jeu').appendChild(d); setTimeout(() => d.remove(), 2600);
};
// pression meurtrière : l'écran se teinte et pulse
UI.intention = (couleur = '#ff2a2a') => {
  const d = document.createElement('div'); d.className = 'intention'; d.style.setProperty('--c', couleur); d.innerHTML = '<span>INTENTION MEURTRIÈRE</span>';
  $('#jeu').appendChild(d); setTimeout(() => d.remove(), 1900);
};
// file d'attente au comptoir
UI.fileAttente = (etat, actions) => {
  let f = document.getElementById('fileAttente');
  if (!etat) { if (f) f.remove(); return; }
  if (!f) { f = document.createElement('div'); f.id = 'fileAttente'; $('#jeu').appendChild(f); f.addEventListener('pointerdown', (e) => { e.stopPropagation(); const b = e.target.closest('[data-a]'); if (b && f._act) f._act[b.dataset.a](); }); }
  f._act = actions;
  const h = `<div class="fa"><b>File d’attente</b><span>${etat.devant > 0 ? `${etat.devant} client${etat.devant > 1 ? 's' : ''} devant toi · ${etat.t} s` : 'C’est bientôt ton tour…'}</span></div>
    <div class="fb">${etat.dissimule ? '<button class="btn rouge" data-a="reveler">Révéler ma puissance</button>' : ''}<button class="btn gris" data-a="quitter">Quitter la file</button></div>`;
  if (f._h !== h) { f.innerHTML = h; f._h = h; }
};
// bouton discret « Révéler » quand ta puissance est dissimulée
UI.boutonReveler = (visible, cb) => {
  let b = document.getElementById('btnReveler');
  if (!visible) { if (b) b.remove(); return; }
  if (!b) { b = document.createElement('button'); b.id = 'btnReveler'; b.type = 'button'; b.innerHTML = '<i></i>RÉVÉLER'; b.addEventListener('pointerdown', (e) => { e.stopPropagation(); e.preventDefault(); b._cb && b._cb(); }); document.getElementById('hud').appendChild(b); }
  b._cb = cb;
};
// dialogue avec un personnage de la taverne
UI.dialogueTaverne = (d) => {
  let m = document.getElementById('dialTaverne');
  if (!d) { if (m) m.remove(); return; }
  if (!m) { m = document.createElement('div'); m.id = 'dialTaverne'; $('#jeu').appendChild(m); m.addEventListener('pointerdown', (e) => e.stopPropagation()); }
  m.innerHTML = `<div class="boiteT"><button class="fermer" data-x aria-label="Fermer">×</button><div class="visageT"><canvas width="160" height="160"></canvas></div>
    <div class="corpsT2"><h3>${d.nom}<small>${d.titre || ''}</small></h3><p class="texteT">${d.texte}</p>
    <div class="optsT">${d.options.map((o, i) => `<button class="optT" data-o="${i}" ${o.desactive ? 'disabled' : ''}><b>${o.label}</b>${o.sous ? `<small>${o.sous}</small>` : ''}</button>`).join('')}</div></div></div>`;
  try { bustePersonnage(d.modele || 'Rogue', m.querySelector('canvas'), '#2a1a10'); } catch (e) {}
  m.onclick = (e) => { if (e.target.closest('[data-x]')) return UI.dialogueTaverne(null); const o = e.target.closest('[data-o]'); if (o && !o.disabled) { api.son('select_001', 0.4); d.options[+o.dataset.o].action(); } };
};
// tableau des missions
UI.tableauMissions = (offres, cb) => {
  let m = document.getElementById('tabMissions');
  if (!offres) { if (m) m.remove(); return; }
  if (!m) { m = document.createElement('div'); m.id = 'tabMissions'; $('#jeu').appendChild(m); m.addEventListener('pointerdown', (e) => e.stopPropagation()); }
  m.innerHTML = `<div class="planche"><button class="fermer" data-x aria-label="Fermer">×</button><h2>Tableau des missions</h2><p class="sousT">Ennemis d’élite à l’aura meurtrière. Pars seul, ou avec Kordath, Sylvane et Nyxara.</p>
    <div class="affiches">${offres.map((o, i) => `<div class="affiche" style="--c:${o.couleur};--r:${(i % 2 ? 1 : -1) * (1 + i * 0.4)}deg"><div class="punaise"></div>
      <div class="etoiles">${'★'.repeat(o.etoiles)}<span>${'★'.repeat(5 - o.etoiles)}</span></div><h3>${o.titre}</h3><p>${o.resume}</p>
      <div class="cible">Cible : <b>${o.boss}</b><br><small>${o.faction}</small></div><div class="prime">Prime : ${fmt(o.recompense)} ¤</div>
      <div class="choixM"><button class="btn gris" data-m="${i}" data-e="0">Seul</button><button class="btn or" data-m="${i}" data-e="1">En équipe</button></div></div>`).join('')}</div></div>`;
  m.onclick = (e) => { if (e.target.closest('[data-x]')) return UI.tableauMissions(null); const b = e.target.closest('[data-m]'); if (b) { api.son('confirmation_001', 0.4); cb(offres[+b.dataset.m], b.dataset.e === '1'); } };
};
