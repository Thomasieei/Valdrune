// Moteur : rendu, caméra « à la Roblox », commandes tactiles, sons, particules, textes flottants.
import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
export { THREE };

export const TACTILE = matchMedia('(pointer: coarse)').matches;
export const G = {
  t: 0, dt: 0, scene: null, camera: null, renderer: null, composer: null,
  camYaw: 0.6, camPitch: 0.34, camZoom: 0.22, camDist: 14, camCible: new THREE.Vector3(), shake: 0,
  sens: 1, hauteur: null,
};
export const V = (x = 0, y = 0, z = 0) => new THREE.Vector3(x, y, z);

// ---------------- Rendu ----------------
export function initRendu(canvas) {
  const r = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
  r.outputColorSpace = THREE.SRGBColorSpace;
  r.toneMapping = THREE.ACESFilmicToneMapping; r.toneMappingExposure = 1.15;
  r.shadowMap.enabled = true; r.shadowMap.type = THREE.PCFSoftShadowMap;
  G.renderer = r;
  const sc = G.scene = new THREE.Scene();
  sc.background = new THREE.Color('#9fc4e8');
  sc.fog = new THREE.Fog('#b8d2ea', 70, 250);
  G.camera = new THREE.PerspectiveCamera(50, 1, 0.2, 700);
  G.hemi = new THREE.HemisphereLight('#cfe4ff', '#5a6a3a', 1.1); sc.add(G.hemi);
  const sun = G.sun = new THREE.DirectionalLight('#fff1d6', 2.4);
  sun.castShadow = true; sun.shadow.mapSize.set(2048, 2048);
  const s = sun.shadow.camera; s.left = -26; s.right = 26; s.top = 26; s.bottom = -26; s.near = 1; s.far = 120;
  sun.shadow.bias = -0.0006; sun.shadow.normalBias = 0.04; sun.shadow.radius = 3;
  sc.add(sun, sun.target);
  sc.environment = environnement(r);
  const rt = new THREE.WebGLRenderTarget(1, 1, { type: THREE.HalfFloatType, samples: TACTILE ? 2 : 4 });
  G.composer = new EffectComposer(r, rt);
  G.composer.addPass(new RenderPass(sc, G.camera));
  G.bloom = new UnrealBloomPass(new THREE.Vector2(256, 256), 0.55, 0.5, 0.86); G.composer.addPass(G.bloom);
  G.composer.addPass(new OutputPass());
  addEventListener('resize', redimensionner); redimensionner();
  initParticules();
}
function environnement(r) { // ciel en dégradé → carte d'environnement (reflets doux, lumière d'ambiance)
  const sc = new THREE.Scene(), geo = new THREE.SphereGeometry(10, 24, 12), P = geo.attributes.position, C = new Float32Array(P.count * 3), c = new THREE.Color();
  for (let i = 0; i < P.count; i++) { const y = P.getY(i) / 10; c.set(y > 0.15 ? '#a8c8f0' : y > -0.1 ? '#f2dcb8' : '#4a5a32').multiplyScalar(0.6); C.set([c.r, c.g, c.b], i * 3); }
  geo.setAttribute('color', new THREE.BufferAttribute(C, 3));
  sc.add(new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ vertexColors: true, side: THREE.BackSide })));
  const pm = new THREE.PMREMGenerator(r), t = pm.fromScene(sc, 0.04).texture; pm.dispose(); return t;
}
export function redimensionner() {
  const w = innerWidth, h = innerHeight, pr = Math.min(devicePixelRatio || 1, 2) * (G.resK || 1); // 1,6 suffit sur un écran de téléphone (au-delà : 50 % de pixels en plus pour un gain invisible)
  G.renderer.setPixelRatio(pr); G.renderer.setSize(w, h, false);
  G.composer.setPixelRatio(pr); G.composer.setSize(w, h);
  G.bloom.resolution.set(w * 0.3, h * 0.3);
  G.camera.aspect = w / h; G.camera.fov = w < h ? 62 : 50; G.camera.updateProjectionMatrix();
}
// qualité auto : si ça rame vraiment, on baisse un peu la définition (jamais les ombres d'abord)
const perf = { t: 0, n: 0 };
function majPerf(dtReel) {
  perf.t += dtReel; perf.n++; if (perf.t < 3) return;
  const fps = perf.n / perf.t; perf.t = perf.n = 0; G.fps = Math.round(fps);
  if (fps < 30 && (G.resK || 1) > 0.8) { G.resK = Math.max(0.8, (G.resK || 1) - 0.1); redimensionner(); } // jamais sous 80 % : en dessous l'image devient floue
  else if (fps < 24 && G.bloom.enabled && G.sun.shadow.mapSize.x <= 1024) G.bloom.enabled = false; // tout dernier recours : sans halo
  else if (fps < 26 && G.sun.shadow.mapSize.x > 1024) { G.sun.shadow.mapSize.set(1024, 1024); G.sun.shadow.map?.dispose(); G.sun.shadow.map = null; } // en dernier recours : ombres moins fines
  else if (fps > 55 && (G.resK || 1) < 1) { G.resK = Math.min(1, G.resK + 0.06); redimensionner(); } // ça tourne bien : on remonte
}
export function rendre(dtReel) { majPerf(dtReel); majParticules(G.dt); G.composer.render(); }

// ---------------- Caméra « à la Roblox » ----------------
const _off = V(), _vise = V();
export const DIR_AV = V(0, 0, -1), DIR_DR = V(1, 0, 0);
// deux caméras : HÉROS (derrière toi, façon Roblox) et SOUVERAIN (vue du dessus façon Age of Empires) ; on glisse de l'une à l'autre
G.mode = 'heros'; G.focus = new THREE.Vector3(); G.zoomS = 0.35;
// ce que voit la caméra : sert à ne pas animer ni dessiner les personnages hors champ
const _fr = new THREE.Frustum(), _mat = new THREE.Matrix4(), _sph = new THREE.Sphere();
export function dansChamp(p, r = 2.5) { _sph.center.set(p.x, p.y + r * 0.6, p.z); _sph.radius = r; return _fr.intersectsSphere(_sph); }
export function majCamera(dt, cible) {
  const souv = G.mode === 'souverain', k = 1 - Math.exp(-dt * 6);
  if (souv) { const r = Math.hypot(G.focus.x, G.focus.z); if (r > 230) G.focus.multiplyScalar(230 / r); G.focus.y = G.hauteur ? G.hauteur(G.focus.x, G.focus.z) : 0; }
  // caméra de combat : elle recule un peu, monte, et cadre le héros ET sa cible ; en marche elle se replace doucement derrière lui
  const vise = cible;
  G.camCible.lerp(souv ? G.focus : vise, 1 - Math.exp(-dt * (souv ? 14 : 8)));
  G._d = G._d ?? 4 + G.camZoom * 26; G._p = G._p ?? G.camPitch;
  const inte = G.interieur && !souv; /* dans un bâtiment : caméra proche et plongeante, le toit s'efface */
  G._d += ((souv ? 14 + G.zoomS * 38 : inte ? Math.min(7, 4 + G.camZoom * 26) : 4 + G.camZoom * 26) - G._d) * k; G._p += ((souv ? 0.98 : inte ? Math.max(0.75, G.camPitch) : G.camPitch) - G._p) * k;
  let d = G._d; const p = G._p;
  // comme Roblox : un arbre entre toi et la caméra ? elle se rapproche, puis recule en douceur
  if (G.obstacle && !souv && !inte) { const ox = Math.sin(G.camYaw) * Math.cos(p), oz = Math.cos(G.camYaw) * Math.cos(p), oy = Math.sin(p); let lib = d; for (let f = 1.5; f <= d; f += 0.5) { if (G.camCible.y + 1 + oy * f < 6 && G.obstacle(G.camCible.x + ox * f, G.camCible.z + oz * f)) { lib = Math.max(2.2, f - 0.8); break; } } G._col = lib < (G._col ?? d) ? lib : (G._col ?? d) + (lib - (G._col ?? d)) * Math.min(1, dt * 2); d = Math.min(d, G._col); }
  const proche = Math.max(0, Math.min(1, (14 - d) / 10)), hv = 1.1 + proche * 0.5;
  _off.set(Math.sin(G.camYaw) * Math.cos(p) * d, Math.sin(p) * d, Math.cos(G.camYaw) * Math.cos(p) * d);
  G.camera.position.copy(G.camCible).add(_off); G.camera.position.y += hv * 0.5;
  const sol = G.hauteur ? G.hauteur(G.camera.position.x, G.camera.position.z) + 0.6 : 0.6;
  if (G.camera.position.y < sol) G.camera.position.y = sol; // jamais sous le sol
  if (G.shake > 0) { G.shake = Math.max(0, G.shake - dt * 2.2); const s = G.shake * G.shake * 0.35, t = G.t; G.camera.position.x += Math.sin(t * 37) * s; G.camera.position.y += Math.sin(t * 41 + 1) * s * 0.7; }
  G.camera.lookAt(_vise.set(G.camCible.x, G.camCible.y + hv, G.camCible.z));
  DIR_AV.set(-Math.sin(G.camYaw), 0, -Math.cos(G.camYaw)); DIR_DR.set(Math.cos(G.camYaw), 0, -Math.sin(G.camYaw));
  G.sun.position.set(cible.x + 18, 34, cible.z + 12); G.sun.target.position.copy(cible);
  G.camera.updateMatrixWorld(); _fr.setFromProjectionMatrix(_mat.multiplyMatrices(G.camera.projectionMatrix, G.camera.matrixWorldInverse));
}

// ---------------- Commandes ----------------
export const entree = { x: 0, y: 0, clavier: {} };
export function initEntrees({ toucher, saisir, glisser }) {
  const zj = document.getElementById('zoneJoy'), joy = document.getElementById('joy'), bout = joy.querySelector('i');
  let jid = null, c0 = null;
  const R = () => joy.offsetWidth * 0.42;
  zj.addEventListener('pointerdown', (e) => { jid = e.pointerId; c0 = { x: e.clientX, y: e.clientY }; joy.style.left = (e.clientX - joy.offsetWidth / 2) + 'px'; joy.style.top = (e.clientY - joy.offsetHeight / 2) + 'px'; joy.classList.add('actif'); zj.setPointerCapture(jid); });
  zj.addEventListener('pointermove', (e) => { if (e.pointerId !== jid) return; let dx = e.clientX - c0.x, dy = e.clientY - c0.y; const l = Math.hypot(dx, dy), m = R(); if (l > m) { dx *= m / l; dy *= m / l; } bout.style.transform = `translate(${dx}px,${dy}px)`; entree.x = dx / m; entree.y = dy / m; });
  const fin = (e) => { if (e.pointerId !== jid) return; jid = null; entree.x = entree.y = 0; bout.style.transform = ''; joy.classList.remove('actif'); joy.style.left = ''; joy.style.top = ''; };
  zj.addEventListener('pointerup', fin); zj.addEventListener('pointercancel', fin);
  // HÉROS : un doigt tourne la caméra · SOUVERAIN : un doigt fait glisser la carte · deux doigts : zoomer (et tourner en souverain) · toucher court : sélectionner / ordonner
  const sc = document.getElementById('scene'), doigts = new Map(); let pince = 0, angle = 0, dep = null;
  sc.addEventListener('pointerdown', (e) => { doigts.set(e.pointerId, { x: e.clientX, y: e.clientY }); if (doigts.size === 1) dep = { x: e.clientX, y: e.clientY, t: performance.now(), bouge: false, saisi: G.mode === 'souverain' && saisir && saisir(e.clientX, e.clientY) }; if (doigts.size === 2) { const [a, b] = [...doigts.values()]; pince = Math.hypot(a.x - b.x, a.y - b.y); angle = Math.atan2(b.y - a.y, b.x - a.x); dep = null; } });
  sc.addEventListener('pointermove', (e) => {
    const d = doigts.get(e.pointerId); if (!d) return;
    const dx = e.clientX - d.x, dy = e.clientY - d.y; d.x = e.clientX; d.y = e.clientY;
    if (doigts.size === 2) {
      const [a, b] = [...doigts.values()], l = Math.hypot(a.x - b.x, a.y - b.y), an = Math.atan2(b.y - a.y, b.x - a.x);
      if (G.mode === 'souverain') { if (pince) G.zoomS = Math.max(0, Math.min(1, G.zoomS + (pince - l) * 0.004)); let da = an - angle; da = Math.atan2(Math.sin(da), Math.cos(da)); G.camYaw -= da; }
      else if (pince) G.camZoom = Math.max(0, Math.min(1, G.camZoom * (pince / l)));
      pince = l; angle = an; return;
    }
    if (dep && Math.hypot(e.clientX - dep.x, e.clientY - dep.y) > 10) dep.bouge = true;
    if (dep && dep.bouge && dep.saisi) { glisser(e.clientX, e.clientY); return; }
    if (dep && dep.bouge && G.mode === 'souverain') { const f = G._d * 0.0016; G.focus.addScaledVector(DIR_DR, -dx * f).addScaledVector(DIR_AV, dy * f); return; }
    if (dep && dep.bouge) { G.camMain = performance.now(); G.camYaw -= dx * 0.008 * G.sens; G.camPitch = Math.max(0.08, Math.min(1.35, G.camPitch + dy * 0.005 * G.sens)); }
  });
  const leve = (e) => { if (dep && !dep.bouge && doigts.size === 1 && performance.now() - dep.t < 350) toucher(e.clientX, e.clientY); doigts.delete(e.pointerId); if (doigts.size < 2) pince = 0; if (!doigts.size) dep = null; };
  sc.addEventListener('pointerup', leve); sc.addEventListener('pointercancel', (e) => { doigts.delete(e.pointerId); dep = null; });
  sc.addEventListener('wheel', (e) => { if (G.mode === 'souverain') { G.zoomS = Math.max(0, Math.min(1, G.zoomS + (e.deltaY > 0 ? 0.05 : -0.05))); return; } G.camZoom = Math.max(0, Math.min(1, G.camZoom + (e.deltaY > 0 ? 0.05 : -0.05))); }, { passive: true });
  addEventListener('keydown', (e) => { entree.clavier[e.key.toLowerCase()] = true; }); addEventListener('keyup', (e) => { entree.clavier[e.key.toLowerCase()] = false; });
}
export function directionVoulue(out) {
  let x = entree.x, y = entree.y; const k = entree.clavier;
  if (k.z || k.w || k.arrowup) y = -1; if (k.s || k.arrowdown) y = 1; if (k.q || k.a || k.arrowleft) x = -1; if (k.d || k.arrowright) x = 1;
  out.set(0, 0, 0).addScaledVector(DIR_DR, x).addScaledVector(DIR_AV, -y);
  const l = out.length(); if (l > 1) out.divideScalar(l);
  return Math.min(1, l);
}
const _p = V(), _ray = new THREE.Raycaster(), _ndc = new THREE.Vector2();
// point du sol sous le doigt (plan, puis affiné deux fois avec le relief)
export function solSous(x, y) {
  _ndc.set(x / innerWidth * 2 - 1, -(y / innerHeight) * 2 + 1); _ray.setFromCamera(_ndc, G.camera);
  const o = _ray.ray.origin, d = _ray.ray.direction; if (d.y > -0.01) return null; let h = 0, q = null;
  for (let i = 0; i < 3; i++) { const t = (h - o.y) / d.y; q = V(o.x + d.x * t, h, o.z + d.z * t); h = G.hauteur ? G.hauteur(q.x, q.z) : 0; }
  q.y = h; return q;
}
export function projeter(v) { _p.copy(v).project(G.camera); return { x: (_p.x + 1) / 2 * innerWidth, y: (1 - _p.y) / 2 * innerHeight, devant: _p.z < 1 }; }

// ---------------- Sons ----------------
const sons = {}; let actx = null, maitre = null;
export function initAudio() { if (actx) { actx.resume(); return; } actx = new (window.AudioContext || window.webkitAudioContext)(); maitre = actx.createGain(); maitre.gain.value = 0.8; maitre.connect(actx.destination); }
export async function chargerSons(liste) {
  await Promise.all(liste.map(async (n) => { try { const r = await fetch('assets/sons/' + n); const b = await r.arrayBuffer(); sons[n.replace(/\.\w+$/, '')] = b; } catch (e) {} }));
}
const decodes = {};
export function son(nom, vol = 0.5, hauteur = 1, pos = null) {
  if (!actx || !sons[nom]) return;
  if (pos && G.camCible) { const d = Math.hypot(pos.x - G.camCible.x, pos.z - G.camCible.z); vol *= Math.max(0, 1 - d / 40); if (vol < 0.02) return; }
  const jouer = (buf) => { const s = actx.createBufferSource(); s.buffer = buf; s.playbackRate.value = hauteur * (0.94 + Math.random() * 0.12); const g = actx.createGain(); g.gain.value = vol; s.connect(g); g.connect(maitre); s.start(); };
  if (decodes[nom]) return jouer(decodes[nom]);
  actx.decodeAudioData(sons[nom].slice(0)).then(b => { decodes[nom] = b; jouer(b); }).catch(() => {});
}

// ---------------- Particules (un seul nuage de points, très peu coûteux) ----------------
// particules : tableaux typés (aucune allocation pendant le jeu = pas d'à-coups du ramasse-miettes),
// chaque particule retombe sur le vrai relief (et pas sur y = 0)
const MAXP = 1500; let PG = null, PA = null, NP = 0;
const PX = new Float32Array(MAXP * 3), PV = new Float32Array(MAXP * 3), PC = new Float32Array(MAXP * 6), PT = new Float32Array(MAXP * 5); // t, vie, taille, grav, sol
function initParticules() {
  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.BufferAttribute(new Float32Array(MAXP * 3), 3));
  geo.setAttribute('color', new THREE.BufferAttribute(new Float32Array(MAXP * 3), 3));
  geo.setAttribute('taille', new THREE.BufferAttribute(new Float32Array(MAXP), 1));
  const mat = new THREE.ShaderMaterial({
    uniforms: { k: { value: 300 } }, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, vertexColors: true,
    vertexShader: 'attribute float taille; varying vec3 vC; uniform float k; void main(){ vC = color; vec4 mv = modelViewMatrix * vec4(position,1.0); gl_PointSize = taille * k / -mv.z; gl_Position = projectionMatrix * mv; }',
    fragmentShader: 'varying vec3 vC; void main(){ float d = length(gl_PointCoord - 0.5); if (d > 0.5) discard; gl_FragColor = vec4(vC, smoothstep(0.5, 0.0, d)); }',
  });
  PG = new THREE.Points(geo, mat); PG.frustumCulled = false; PA = geo; G.scene.add(PG);
}
const _c1 = new THREE.Color(), _c2 = new THREE.Color();
export function emettre(pos, { n = 10, c1 = '#ffffff', c2 = null, vit = 3, vie = 0.7, taille = 0.25, grav = 6, haut = 0.5 } = {}) {
  _c1.set(c1); _c2.set(c2 || c1); const sol = G.hauteur ? G.hauteur(pos.x, pos.z) + 0.03 : 0.03;
  for (let i = 0; i < n && NP < MAXP; i++, NP++) {
    const a = Math.random() * 6.283, v = vit * (0.4 + Math.random() * 0.6), j = NP * 3, c = NP * 6, t = NP * 5;
    PX[j] = pos.x; PX[j + 1] = pos.y; PX[j + 2] = pos.z; PV[j] = Math.cos(a) * v; PV[j + 1] = (Math.random() * 0.8 + haut) * v; PV[j + 2] = Math.sin(a) * v;
    PC[c] = _c1.r; PC[c + 1] = _c1.g; PC[c + 2] = _c1.b; PC[c + 3] = _c2.r; PC[c + 4] = _c2.g; PC[c + 5] = _c2.b;
    PT[t] = 0; PT[t + 1] = vie * (0.7 + Math.random() * 0.6); PT[t + 2] = taille * (0.7 + Math.random() * 0.6); PT[t + 3] = grav; PT[t + 4] = sol;
  }
}
function majParticules(dt) {
  const P = PA.attributes.position.array, C = PA.attributes.color.array, S = PA.attributes.taille.array;
  for (let i = NP - 1; i >= 0; i--) { // fin de vie : on recopie la dernière à sa place
    if ((PT[i * 5] += dt) < PT[i * 5 + 1]) continue;
    NP--; if (i !== NP) { PX.copyWithin(i * 3, NP * 3, NP * 3 + 3); PV.copyWithin(i * 3, NP * 3, NP * 3 + 3); PC.copyWithin(i * 6, NP * 6, NP * 6 + 6); PT.copyWithin(i * 5, NP * 5, NP * 5 + 5); }
  }
  for (let i = 0; i < NP; i++) {
    const j = i * 3, c = i * 6, t = i * 5, g = PT[t + 3];
    PV[j + 1] -= g * dt; PX[j] += PV[j] * dt; PX[j + 1] += PV[j + 1] * dt; PX[j + 2] += PV[j + 2] * dt;
    if (g > 0 && PX[j + 1] < PT[t + 4]) { PX[j + 1] = PT[t + 4]; PV[j] *= 0.7; PV[j + 2] *= 0.7; PV[j + 1] *= -0.2; }
    const k = PT[t] / PT[t + 1], f = 1 - k;
    P[j] = PX[j]; P[j + 1] = PX[j + 1]; P[j + 2] = PX[j + 2];
    C[j] = (PC[c] + (PC[c + 3] - PC[c]) * k) * f; C[j + 1] = (PC[c + 1] + (PC[c + 4] - PC[c + 1]) * k) * f; C[j + 2] = (PC[c + 2] + (PC[c + 5] - PC[c + 2]) * k) * f;
    S[i] = PT[t + 2] * (0.6 + f * 0.6);
  }
  PA.setDrawRange(0, NP); PA.attributes.position.needsUpdate = PA.attributes.color.needsUpdate = PA.attributes.taille.needsUpdate = true;
  PG.material.uniforms.k.value = innerHeight * G.renderer.getPixelRatio() * 0.6;
}
// vecteurs de travail réutilisés (pour projeter / émettre / afficher un texte : ces fonctions recopient la position)
const _ring = Array.from({ length: 32 }, () => new THREE.Vector3()); let _ri = 0;
export const tmp = (x, y, z) => _ring[(_ri = (_ri + 1) & 31)].set(x, y, z);

// ---------------- Textes flottants ----------------
const flottants = [];
export function texteFlottant(pos, txt, cls = '') {
  const d = document.createElement('div'); d.className = 'flot ' + cls; d.textContent = txt; document.getElementById('flots').appendChild(d);
  flottants.push({ d, pos: pos.clone(), t: 0, dx: (Math.random() - 0.5) * 1.6, dz: (Math.random() - 0.5) * 1.6, gros: /crit|parade|arise/.test(cls) });
}
export function majFlottants(dt) {
  for (let i = flottants.length - 1; i >= 0; i--) {
    const f = flottants[i]; f.t += dt; f.pos.y += dt * (1.6 - f.t); f.pos.x += f.dx * dt; f.pos.z += f.dz * dt; // les chiffres jaillissent en arc, les critiques éclatent
    const sc = f.gros ? (f.t < 0.12 ? 0.6 + f.t * 12 : Math.max(1, 2 - (f.t - 0.12) * 5)) : Math.min(1, 0.6 + f.t * 4);
    const s = projeter(f.pos); f.d.style.transform = `translate(${s.x}px,${s.y}px) translate(-50%,-50%) scale(${sc})`; f.d.style.opacity = f.t > 1.1 ? Math.max(0, 1 - (f.t - 1.1) / 0.5) : 1;
    if (f.t > 1.6 || !s.devant) { f.d.remove(); flottants.splice(i, 1); }
  }
}
