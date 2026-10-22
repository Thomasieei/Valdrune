// ===== Moteur : rendu, assets, acteurs, particules, effets, sons =====
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';

export { THREE };
export const G = {
  assets: {}, sounds: {}, t: 0, dt: 0, vfx: [], qualite: 'auto', niveau: 2, son: true, acteurs: new Set(), focus: null,
  camYaw: Math.PI / 4, camDist: 25, camPitch: 0.98, shake: 0, camTarget: new THREE.Vector3(),
};

// ---------- Rendu ----------
export function initRendu(canvas) {
  const r = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
  r.outputColorSpace = THREE.SRGBColorSpace;
  r.toneMapping = THREE.ACESFilmicToneMapping;
  r.toneMappingExposure = 1.15;
  r.shadowMap.enabled = true;
  r.shadowMap.type = THREE.PCFShadowMap;
  r.info.autoReset = false;
  r.shadowMap.autoUpdate = false; // ombres recalculées une image sur deux
  G.renderer = r;
  G.scene = new THREE.Scene();
  G.scene.background = new THREE.Color('#120b1b');
  G.scene.fog = new THREE.FogExp2('#150d20', 0.022);
  G.camera = new THREE.PerspectiveCamera(38, 1, 0.5, 220);
  // Lumières de base
  G.hemi = new THREE.HemisphereLight('#8f7cc8', '#2a1830', 1.05);
  G.scene.add(G.hemi);
  G.sun = new THREE.DirectionalLight('#c9b8ff', 1.25);
  G.sun.castShadow = true;
  G.sun.shadow.mapSize.set(1024, 1024);
  const sc = G.sun.shadow.camera; sc.left = -22; sc.right = 22; sc.top = 22; sc.bottom = -22; sc.near = 1; sc.far = 80;
  G.sun.shadow.bias = -0.0008; G.sun.shadow.normalBias = 0.03;
  G.scene.add(G.sun, G.sun.target);
  // Composer + bloom
  G.composer = new EffectComposer(r);
  G.composer.addPass(new RenderPass(G.scene, G.camera));
  G.bloom = new UnrealBloomPass(new THREE.Vector2(512, 512), 0.75, 0.45, 0.78);
  G.composer.addPass(G.bloom);
  G.composer.addPass(new OutputPass());
  // Pool de lumières ponctuelles (torches)
  G.lightPool = [];
  for (let i = 0; i < 4; i++) {
    const l = new THREE.PointLight('#ff9a4a', 0, 13, 1.6);
    G.scene.add(l); G.lightPool.push(l);
  }
  G.torches = [];
  window.addEventListener('resize', redimensionner);
  redimensionner();
  initParticules();
}

export function redimensionner() {
  const w = window.innerWidth, h = window.innerHeight;
  const tactile = matchMedia('(pointer: coarse)').matches;
  const pr = Math.min(window.devicePixelRatio || 1, G.niveau >= 2 ? (tactile ? 1.25 : 1.6) : G.niveau === 1 ? (tactile ? 1.0 : 1.25) : 0.8);
  G.renderer.setPixelRatio(pr);
  G.renderer.setSize(w, h, false);
  G.composer.setPixelRatio(pr);
  G.composer.setSize(w, h);
  G.bloom.resolution.set(w * pr * 0.5, h * pr * 0.5);
  G.camera.aspect = w / h;
  // en portrait on recule pour garder la scène lisible
  G.camera.fov = w < h ? 55 : 38;
  G.camera.updateProjectionMatrix();
  if (G.partMat) G.partMat.uniforms.uScale.value = h * pr * 0.5 / Math.tan(THREE.MathUtils.degToRad(G.camera.fov / 2));
}

const _off = new THREE.Vector3();
export function majCamera(dt, cible) {
  G.camTarget.lerp(cible, 1 - Math.exp(-dt * 8));
  const d = G.camDist, p = G.camPitch;
  const off = _off.set(Math.sin(G.camYaw) * Math.cos(p) * d, Math.sin(p) * d, Math.cos(G.camYaw) * Math.cos(p) * d);
  G.camera.position.copy(G.camTarget).add(off);
  if (G.shake > 0) {
    G.shake = Math.max(0, G.shake - dt * 2.5);
    const s = G.shake * G.shake * 0.6;
    G.camera.position.x += (Math.random() - 0.5) * s; G.camera.position.y += (Math.random() - 0.5) * s; G.camera.position.z += (Math.random() - 0.5) * s;
  }
  G.camera.lookAt(G.camTarget.x, G.camTarget.y + 1, G.camTarget.z);
  G.sun.position.set(cible.x - 10, 26, cible.z + 6);
  G.sun.target.position.copy(cible);
}
// directions écran -> monde
export const DIR_HAUT = new THREE.Vector3(-1, 0, -1).normalize();
export const DIR_DROITE = new THREE.Vector3(1, 0, -1).normalize();

// ---------- Qualité et culling des personnages ----------
const _frustum = new THREE.Frustum(), _pv = new THREE.Matrix4(), _sph = new THREE.Sphere();
function cullActeurs() {
  G.camera.updateMatrixWorld();
  _pv.multiplyMatrices(G.camera.projectionMatrix, G.camera.matrixWorldInverse); _frustum.setFromProjectionMatrix(_pv);
  const f = G.focus || G.camTarget;
  for (const a of G.acteurs) {
    if (!a.root.parent) { if (a._dansScene) G.acteurs.delete(a); continue; }
    if (!a._dansScene) { a._dansScene = true; a.fusionner(); }
    const p = a.root.position;
    _sph.center.set(p.x, p.y + a.rayonVis * 0.6, p.z); _sph.radius = a.rayonVis + 2.5;
    const vis = _frustum.intersectsSphere(_sph);
    if (vis !== a.vu) { a.vu = vis; a.model.visible = vis; }
    if (vis) {
      const ombre = G.niveau > 0 && Math.abs(p.x - f.x) + Math.abs(p.z - f.z) < 30;
      if (ombre !== a._ombre) { a._ombre = ombre; for (const m of a.meshes) m.castShadow = ombre; }
    }
  }
}
export function appliquerNiveau(n) {
  n = Math.max(0, Math.min(2, n));
  const avant = G.niveau; G.niveau = n;
  G.bloom.enabled = n >= 2;
  const ombres = n >= 1;
  if (G.sun.castShadow !== ombres) { G.sun.castShadow = ombres; G.renderer.shadowMap.enabled = ombres; G.scene.traverse(o => { if (o.material) [].concat(o.material).forEach(m => (m.needsUpdate = true)); }); }
  redimensionner();
  return avant !== n;
}
// mesure de fluidité : la qualité « auto » descend d’un cran si le jeu rame, et remonte si ça n’a rien changé
const auto = { t: 0, n: 0, somme: 0, essai: null, fini: false };
export function majQualiteAuto(dtReel, actif) {
  if (G.qualite !== 'auto' || auto.fini || !actif) { auto.t = auto.n = auto.somme = 0; return null; }
  auto.t += Math.min(dtReel, 0.25); auto.n++; auto.somme += dtReel;
  if (auto.t < 4) return null;
  const fps = auto.n / auto.somme; auto.t = auto.n = auto.somme = 0;
  if (auto.essai) {
    const e = auto.essai; auto.essai = null;
    if (fps < e.fps * 1.12) { auto.fini = true; appliquerNiveau(e.niveau); return 'inutile'; }
    if (fps >= 48) { auto.fini = true; return null; }
  }
  if (fps < 48 && G.niveau > 0) { auto.essai = { fps, niveau: G.niveau }; appliquerNiveau(G.niveau - 1); return 'baisse'; }
  if (fps >= 55) auto.fini = true;
  return null;
}
export function rendre() {
  G.renderer.info.reset();
  cullActeurs();
  G._img = (G._img || 0) + 1;
  if (G.renderer.shadowMap.enabled) G.renderer.shadowMap.needsUpdate = (G._img & 1) === 0;
  if (G.niveau >= 1) G.composer.render(); else G.renderer.render(G.scene, G.camera);
}

// ---------- Torches : on allume les plus proches ----------
export function majTorches(pos) {
  if (!G.torches.length) { G.lightPool.forEach(l => (l.intensity = 0)); return; }
  if (!G._tTorch || G.t - G._tTorch > 0.4) {
    G._tTorch = G.t;
    const tri = G.torches.map(t => ({ t, d: t.pos.distanceToSquared(pos) })).sort((a, b) => a.d - b.d);
    G.lightPool.forEach((l, i) => { const e = tri[i]; l.userData.src = e ? e.t : null; if (e) { l.position.copy(e.t.pos); l.color.set(e.t.color || '#ff9a4a'); l.distance = e.t.dist || 13; } });
  }
  G.lightPool.forEach((l, i) => {
    const s = l.userData.src; if (!s) { l.intensity = 0; return; }
    const base = s.int || 26;
    l.intensity = base * (0.85 + 0.15 * Math.sin(G.t * 9 + i * 2.1) + 0.06 * Math.sin(G.t * 23 + i));
  });
}

// ---------- Chargement ----------
const loader = new GLTFLoader();
// textures via <img> (autorisé) plutôt que fetch(blob:) (bloqué sur la page publiée)
loader.register((parser) => { parser.textureLoader = new THREE.TextureLoader(parser.options.manager); return { name: 'textures_img' }; });
// Les URL data: sont bloquées sur la page publiée : on reconstruit un GLB en mémoire.
function b64EnOctets(b64) {
  const s = atob(b64); const n = s.length; const out = new Uint8Array(n);
  for (let i = 0; i < n; i++) out[i] = s.charCodeAt(i);
  return out;
}
async function chargerModele(url) {
  const rep = await fetch(url);
  if (!rep.ok) throw new Error(url + ' : HTTP ' + rep.status);
  const j = await rep.json();
  const buf = j.buffers[0];
  const bin = b64EnOctets(buf.uri.slice(buf.uri.indexOf(',') + 1));
  j.buffers = [{ byteLength: bin.length }];
  const enc = new TextEncoder();
  let js = enc.encode(JSON.stringify(j));
  const padJ = (4 - js.length % 4) % 4, padB = (4 - bin.length % 4) % 4;
  const lj = js.length + padJ, lb = bin.length + padB;
  const glb = new Uint8Array(12 + 8 + lj + 8 + lb);
  const dv = new DataView(glb.buffer);
  dv.setUint32(0, 0x46546C67, true); dv.setUint32(4, 2, true); dv.setUint32(8, glb.length, true);
  dv.setUint32(12, lj, true); dv.setUint32(16, 0x4E4F534A, true);
  glb.set(js, 20); for (let i = 0; i < padJ; i++) glb[20 + js.length + i] = 0x20;
  const o = 20 + lj;
  dv.setUint32(o, lb, true); dv.setUint32(o + 4, 0x004E4942, true);
  glb.set(bin, o + 8);
  const dossier = url.slice(0, url.lastIndexOf('/') + 1);
  return await new Promise((ok, ko) => loader.parse(glb.buffer, dossier, ok, ko));
}
export async function chargerAssets(liste, progres) {
  let fait = 0;
  await Promise.all(liste.map(async ([cle, url]) => {
    const g = await chargerModele(url);
    g.scene.updateMatrixWorld(true);
    const box = new THREE.Box3().setFromObject(g.scene);
    g.hauteur = box.max.y - box.min.y;
    g.box = box;
    g.scene.traverse(o => { if (o.isMesh) { o.castShadow = false; o.receiveShadow = true; if (o.material) o.material.envMapIntensity = 0.6; } });
    G.assets[cle] = g;
    progres(++fait / liste.length, cle);
  }));
}

export async function chargerSons(liste) {
  const ctx = (G.audio = G.audio || new (window.AudioContext || window.webkitAudioContext)());
  if (!G.master) {
    // limiteur : quand beaucoup de sons se superposent, on évite la saturation qui grésille sur téléphone
    const comp = ctx.createDynamicsCompressor(); comp.threshold.value = -16; comp.knee.value = 10; comp.ratio.value = 8; comp.attack.value = 0.003; comp.release.value = 0.2;
    G.master = ctx.createGain(); G.master.gain.value = 0.6; G.master.connect(comp); comp.connect(ctx.destination);
  }
  await Promise.all(liste.map(async ([cle, url]) => {
    try { const b = await (await fetch(url)).arrayBuffer(); G.sounds[cle] = await ctx.decodeAudioData(b); } catch (e) { /* son manquant */ }
  }));
}
const dernierSon = {}; let sonsActifs = 0;
export function son(cle, vol = 0.5, rate = 1) {
  if (!G.son || !G.audio || !G.sounds[cle]) return;
  // anti-spam : un même son au plus toutes les 70 ms, et 10 sons simultanés maximum
  const now = G.audio.currentTime; if (now - (dernierSon[cle] || -1) < 0.07 || sonsActifs >= 10) return; dernierSon[cle] = now;
  const s = G.audio.createBufferSource(); s.buffer = G.sounds[cle]; s.playbackRate.value = rate * (0.94 + Math.random() * 0.12);
  const g = G.audio.createGain(); g.gain.value = Math.min(0.8, vol); s.connect(g); g.connect(G.master); sonsActifs++; s.onended = () => { sonsActifs--; s.disconnect(); g.disconnect(); }; s.start();
}
export function ambiance() {
  // nappe très douce (sinusoïdes filtrées) — l'ancien bourdonnement en dents de scie grésillait sur les haut-parleurs de téléphone
  if (G._amb || !G.audio) return; G._amb = true;
  const ctx = G.audio; const out = ctx.createGain(); out.gain.value = 0.025; out.connect(G.master);
  const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = 600; f.connect(out);
  [110, 164.8, 220].forEach((fr, i) => {
    const o = ctx.createOscillator(); o.type = 'sine'; o.frequency.value = fr; o.detune.value = i * 4;
    const g = ctx.createGain(); g.gain.value = 0.35; o.connect(g); g.connect(f); o.start();
    const lfo = ctx.createOscillator(); lfo.frequency.value = 0.04 + i * 0.02; const lg = ctx.createGain(); lg.gain.value = 0.25;
    lfo.connect(lg); lg.connect(g.gain); lfo.start();
  });
}

// ---------- Acteurs animés ----------
const NOIR = new THREE.Color(0), BLANC = new THREE.Color('#ffffff');
export class Acteur {
  constructor(cle, { hauteur = 2.0, echelle = 1 } = {}) {
    const src = G.assets[cle];
    this.cle = cle;
    this.root = new THREE.Group();
    this.model = SkeletonUtils.clone(src.scene);
    const s = (hauteur / src.hauteur) * echelle;
    this.model.scale.multiplyScalar(s);
    this.root.add(this.model);
    this.nodes = {};
    this.mats = []; this.meshes = [];
    this.rayonVis = hauteur * echelle * 0.75 + 0.8; this.vu = true; this._ombre = true; this._acc = 0;
    G.acteurs.add(this);
    this.model.traverse(o => {
      this.nodes[o.name] = o;
      if (o.isMesh) {
        o.castShadow = true; o.receiveShadow = false; o.frustumCulled = false; this.meshes.push(o);
        o.material = o.material.clone(); this.mats.push(o.material);
        o.material.userData.baseEmissive = o.material.emissive ? o.material.emissive.clone() : null;
      }
    });
    this.mixer = new THREE.AnimationMixer(this.model);
    this.actions = {};
    for (const c of src.animations) this.actions[c.name] = this.mixer.clipAction(c);
    this.courante = null; this.flash = 0;
    this.mixer.addEventListener('finished', (e) => { if (this._onFin && e.action === this.courante) { const f = this._onFin; this._onFin = null; f(); } });
  }
  jouer(nom, { fondu = 0.18, boucle = true, vitesse = 1, forcer = false, fin = null } = {}) {
    const a = this.actions[nom]; if (!a) return;
    if (this.courante === a && !forcer) { a.timeScale = vitesse; return; }
    a.reset(); a.timeScale = vitesse;
    a.setLoop(boucle ? THREE.LoopRepeat : THREE.LoopOnce, boucle ? Infinity : 1);
    a.clampWhenFinished = !boucle;
    a.enabled = true; a.setEffectiveWeight(1);
    if (this.courante && this.courante !== a) a.crossFadeFrom(this.courante, fondu, false);
    a.play(); this.courante = a; this._onFin = fin;
  }
  duree(nom) { return this.actions[nom] ? this.actions[nom].getClip().duration : 1; }
  montrerSeul(noms, cacher) { for (const n of cacher) if (this.nodes[n]) this.nodes[n].visible = noms.includes(n); }
  teinter(nomNode, couleur, force = 0.65, glow = 0) {
    const n = this.nodes[nomNode]; if (!n) return;
    n.traverse(o => {
      if (!o.isMesh) return;
      const c = new THREE.Color('#ffffff').lerp(new THREE.Color(couleur), force);
      o.material.color.copy(c);
      if (o.material.emissive) { o.material.emissive.set(couleur).multiplyScalar(glow * 0.6); o.material.userData.baseEmissive = o.material.emissive.clone(); }
    });
  }
  frapper() { this.flash = 0.12; }
  // fusionne les morceaux du corps (tête, buste, bras, jambes) en un seul maillage : 1 appel GPU au lieu de 6
  fusionner() {
    if (this._fusion || G.pasFusion) return; this._fusion = true;
    const groupes = new Map();
    this.model.traverse(o => {
      if (!o.isSkinnedMesh || !o.geometry.attributes.uv) return;
      let v = true; for (let p = o; p; p = p.parent) if (!p.visible) { v = false; break; }
      if (!v) return;
      const be = o.material.userData.baseEmissive; if (be && (be.r + be.g + be.b) > 0.001) return;
      if (o.material.transparent) return;
      const k = (o.material.map ? o.material.map.uuid : '-') + '|' + o.skeleton.bones.length + '|' + o.parent.uuid;
      if (!groupes.has(k)) groupes.set(k, []); groupes.get(k).push(o);
    });
    for (const parts of groupes.values()) {
      if (parts.length < 2) continue;
      const ref = parts[0];
      if (!parts.every(p => p.bindMatrix.equals(ref.bindMatrix) && p.skeleton.bones.every((b, i) => b === ref.skeleton.bones[i]))) continue;
      const geos = [];
      for (const p of parts) {
        const g = new THREE.BufferGeometry();
        for (const n of ['position', 'normal', 'uv', 'skinIndex', 'skinWeight']) { if (!p.geometry.attributes[n]) return; g.setAttribute(n, p.geometry.attributes[n]); }
        if (p.geometry.index) g.setIndex(p.geometry.index);
        const nb = g.attributes.position.count, col = new Float32Array(nb * 3), c = p.material.color;
        for (let i = 0; i < nb; i++) { col[i * 3] = c.r; col[i * 3 + 1] = c.g; col[i * 3 + 2] = c.b; }
        g.setAttribute('color', new THREE.BufferAttribute(col, 3));
        geos.push(g.index ? g : g);
      }
      const indexes = geos.every(g => g.index), aucun = geos.every(g => !g.index);
      if (!indexes && !aucun) continue;
      const geo = mergeGeometries(geos, false); if (!geo) continue;
      const mat = ref.material.clone(); mat.color.set('#ffffff'); mat.vertexColors = true;
      mat.userData.baseEmissive = mat.emissive ? mat.emissive.clone() : null;
      const m = new THREE.SkinnedMesh(geo, mat);
      m.name = ref.name + '_fusion'; m.frustumCulled = false; m.castShadow = this._ombre; m.receiveShadow = false;
      m.bind(ref.skeleton, ref.bindMatrix);
      m.position.copy(ref.position); m.quaternion.copy(ref.quaternion); m.scale.copy(ref.scale);
      ref.parent.add(m);
      for (const p of parts) { p.removeFromParent(); const i = this.mats.indexOf(p.material); if (i >= 0) this.mats.splice(i, 1); const j = this.meshes.indexOf(p); if (j >= 0) this.meshes.splice(j, 1); }
      this.mats.push(mat); this.meshes.push(m);
    }
  }
  maj(dt) {
    // hors écran : animation mise à jour 5 fois par seconde seulement
    if (this.vu === false) { this._acc += dt; if (this._acc < 0.2) return; dt = this._acc; }
    this._acc = 0;
    this.mixer.update(dt);
    if (this.flash > 0 || this._flashOn) {
      this.flash -= dt; const k = Math.max(0, this.flash) / 0.12; this._flashOn = k > 0;
      for (const m of this.mats) if (m.emissive) { m.emissive.copy(m.userData.baseEmissive || NOIR).lerp(BLANC, k * 0.8); }
    }
  }
  attacher(cleProp, os = 'handslot.r', { echelle = 1, rot = null } = {}) {
    const p = G.assets[cleProp]; if (!p || !this.nodes[os]) return null;
    const m = p.scene.clone(true);
    m.traverse(o => { if (o.isMesh) { o.castShadow = this._ombre; o.material = o.material.clone(); this.mats.push(o.material); this.meshes.push(o); } });
    m.scale.setScalar(echelle); if (rot) m.rotation.set(...rot);
    this.nodes[os].add(m); return m;
  }
}

// ---------- Mobilier instancié ----------
export class Instancieur {
  constructor() { this.par = new Map(); }
  ajouter(cle, x, y, z, rotY = 0, sx = 1, sy = 1, sz = 1) {
    if (!this.par.has(cle)) this.par.set(cle, []);
    const m = new THREE.Matrix4().compose(new THREE.Vector3(x, y, z), new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), rotY), new THREE.Vector3(sx, sy, sz));
    this.par.get(cle).push(m);
  }
  // découpé en blocs de 24 m : la caméra ne dessine que les blocs visibles
  construire(groupe, { ombre = false } = {}) {
    const CELL = 36;
    for (const [cle, toutes] of this.par) {
      const src = G.assets[cle]; if (!src) continue;
      src.scene.updateMatrixWorld(true);
      const blocs = new Map();
      for (const m of toutes) { const k = Math.floor(m.elements[12] / CELL) + ',' + Math.floor(m.elements[14] / CELL); if (!blocs.has(k)) blocs.set(k, []); blocs.get(k).push(m); }
      src.scene.traverse(o => {
        if (!o.isMesh) return;
        const tmp = new THREE.Matrix4();
        for (const mats of blocs.values()) {
          const im = new THREE.InstancedMesh(o.geometry, o.material, mats.length);
          mats.forEach((m, i) => im.setMatrixAt(i, tmp.multiplyMatrices(m, o.matrixWorld)));
          im.computeBoundingSphere();
          im.receiveShadow = true; im.castShadow = ombre; im.matrixAutoUpdate = false;
          groupe.add(im);
        }
      });
    }
  }
}
export function cloner(cle, x = 0, y = 0, z = 0, rotY = 0, s = 1) {
  const src = G.assets[cle]; const m = src.scene.clone(true); m.userData.cle = cle;
  m.position.set(x, y, z); m.rotation.y = rotY; m.scale.setScalar(s);
  return m;
}

// ---------- Textures procédurales ----------
const texCache = {};
export function texture(nom, w, h, dessin, opts = {}) {
  if (texCache[nom]) return texCache[nom];
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  dessin(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  if (opts.repeat) { t.wrapS = t.wrapT = THREE.RepeatWrapping; }
  t.anisotropy = 4;
  return (texCache[nom] = t);
}
export const texRond = () => texture('rond', 64, 64, (g, w) => {
  const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32);
  gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.25, 'rgba(255,255,255,0.8)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = gr; g.fillRect(0, 0, w, w);
});
export const texRunes = (couleur = '#ff3030') => texture('runes' + couleur, 512, 512, (g) => {
  g.translate(256, 256);
  g.strokeStyle = couleur; g.fillStyle = couleur; g.shadowColor = couleur; g.shadowBlur = 18; g.lineWidth = 6;
  for (const r of [240, 200, 120]) { g.beginPath(); g.arc(0, 0, r, 0, Math.PI * 2); g.stroke(); }
  g.lineWidth = 3;
  for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2; g.beginPath(); g.moveTo(Math.cos(a) * 200, Math.sin(a) * 200); g.lineTo(Math.cos(a + Math.PI * 2 / 3) * 200, Math.sin(a + Math.PI * 2 / 3) * 200); g.stroke(); }
  g.font = 'bold 30px serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
  const glyphes = 'ᚠᚢᚦᚨᚱᚲᚷᚹᚺᚾᛁᛃᛇᛈᛉᛊᛏᛒᛖᛗᛚᛜᛞᛟ';
  for (let i = 0; i < 24; i++) { const a = i / 24 * Math.PI * 2; g.save(); g.rotate(a); g.fillText(glyphes[i], 0, -220); g.restore(); }
  for (let i = 0; i < 12; i++) { const a = i / 12 * Math.PI * 2; g.save(); g.rotate(a); g.fillText(glyphes[(i * 5) % 24], 0, -160); g.restore(); }
});
export const texFissures = () => texture('fissures', 512, 512, (g) => {
  g.lineCap = 'round';
  const branche = (x, y, a, l, w, n) => {
    if (n <= 0 || w < 0.6) return;
    const x2 = x + Math.cos(a) * l, y2 = y + Math.sin(a) * l;
    g.lineWidth = w; g.beginPath(); g.moveTo(x, y); g.lineTo(x2, y2); g.stroke();
    branche(x2, y2, a + (Math.random() - 0.5) * 0.9, l * 0.85, w * 0.8, n - 1);
    if (Math.random() < 0.45) branche(x2, y2, a + (Math.random() < 0.5 ? 1 : -1) * (0.5 + Math.random() * 0.7), l * 0.6, w * 0.6, n - 2);
  };
  for (const pass of [[26, 'rgba(255,60,10,0.25)'], [10, 'rgba(255,120,40,0.7)'], [0, 'rgba(255,230,160,1)']]) {
    g.shadowBlur = pass[0]; g.shadowColor = '#ff3a00'; g.strokeStyle = pass[1];
    Math.random = mulberry(7);
    for (let i = 0; i < 7; i++) { const a = i / 7 * Math.PI * 2; branche(256, 256, a, 34, pass[0] ? 9 : 4, 8); }
  }
  Math.random = MathRandomOrig;
});
const MathRandomOrig = Math.random;
function mulberry(a) { return function () { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }

// ---------- Particules (un seul système, additif) ----------
const MAXP = 2600;
function initParticules() {
  const geo = new THREE.BufferGeometry();
  G.pPos = new Float32Array(MAXP * 3); G.pCol = new Float32Array(MAXP * 3); G.pSize = new Float32Array(MAXP); G.pAlpha = new Float32Array(MAXP);
  geo.setAttribute('position', new THREE.BufferAttribute(G.pPos, 3).setUsage(THREE.DynamicDrawUsage));
  geo.setAttribute('color', new THREE.BufferAttribute(G.pCol, 3).setUsage(THREE.DynamicDrawUsage));
  geo.setAttribute('size', new THREE.BufferAttribute(G.pSize, 1).setUsage(THREE.DynamicDrawUsage));
  geo.setAttribute('alpha', new THREE.BufferAttribute(G.pAlpha, 1).setUsage(THREE.DynamicDrawUsage));
  G.partMat = new THREE.ShaderMaterial({
    uniforms: { map: { value: texRond() }, uScale: { value: 600 } },
    vertexShader: `attribute float size; attribute float alpha; attribute vec3 color; varying vec3 vC; varying float vA; uniform float uScale;
      void main(){ vC=color; vA=alpha; vec4 mv=modelViewMatrix*vec4(position,1.0); gl_PointSize=size*uScale/max(0.1,-mv.z); gl_Position=projectionMatrix*mv; }`,
    fragmentShader: `uniform sampler2D map; varying vec3 vC; varying float vA; void main(){ vec4 t=texture2D(map,gl_PointCoord); gl_FragColor=vec4(vC*1.6,t.a*vA); if(gl_FragColor.a<0.01) discard; }`,
    transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
  });
  G.points = new THREE.Points(geo, G.partMat); G.points.frustumCulled = false; G.points.renderOrder = 10;
  G.parts = []; for (let i = 0; i < MAXP; i++) G.parts.push({ vie: 0 });
  G.pIdx = 0;
}
const _c1 = new THREE.Color(), _c2 = new THREE.Color();
export function emettre(pos, o = {}) {
  const n = o.n ?? 10;
  _c1.set(o.c1 ?? '#ffaa44'); _c2.set(o.c2 ?? o.c1 ?? '#ff4400');
  for (let i = 0; i < n; i++) {
    const p = G.parts[G.pIdx]; G.pIdx = (G.pIdx + 1) % MAXP;
    const a = Math.random() * Math.PI * 2, r = Math.random() * (o.rayon ?? 0.2);
    p.x = pos.x + Math.cos(a) * r; p.y = pos.y + (o.dy ?? 0) + Math.random() * (o.hy ?? 0); p.z = pos.z + Math.sin(a) * r;
    const sp = (o.vit ?? 2) * (0.4 + Math.random() * 0.6);
    const dir = o.dir;
    if (dir) { p.vx = dir.x * sp + (Math.random() - 0.5) * (o.disp ?? 1); p.vy = dir.y * sp + (Math.random() - 0.5) * (o.disp ?? 1); p.vz = dir.z * sp + (Math.random() - 0.5) * (o.disp ?? 1); }
    else { const b = Math.acos(1 - Math.random() * (o.hemi ? 1 : 2)); p.vx = Math.sin(b) * Math.cos(a) * sp; p.vz = Math.sin(b) * Math.sin(a) * sp; p.vy = Math.cos(b) * sp * (o.hemi ? 1 : 1) + (o.monte ?? 0); }
    p.g = o.grav ?? 0; p.drag = o.frein ?? 1.5; p.vieMax = p.vie = (o.vie ?? 0.8) * (0.6 + Math.random() * 0.6);
    p.taille = (o.taille ?? 0.4) * (0.6 + Math.random() * 0.8); p.fin = o.tailleFin ?? 0.1;
    const k = Math.random(); p.r = _c1.r + (_c2.r - _c1.r) * k; p.gg = _c1.g + (_c2.g - _c1.g) * k; p.b = _c1.b + (_c2.b - _c1.b) * k;
  }
}
export function majParticules(dt) {
  for (let i = 0; i < MAXP; i++) {
    const p = G.parts[i];
    if (p.vie > 0) {
      p.vie -= dt;
      const f = Math.exp(-p.drag * dt);
      p.vx *= f; p.vz *= f; p.vy = p.vy * f - p.g * dt;
      p.x += p.vx * dt; p.y += p.vy * dt; p.z += p.vz * dt;
      const k = Math.max(0, p.vie / p.vieMax);
      G.pPos[i * 3] = p.x; G.pPos[i * 3 + 1] = p.y; G.pPos[i * 3 + 2] = p.z;
      G.pCol[i * 3] = p.r; G.pCol[i * 3 + 1] = p.gg; G.pCol[i * 3 + 2] = p.b;
      G.pSize[i] = p.taille * (p.fin + (1 - p.fin) * k);
      G.pAlpha[i] = Math.min(1, k * 2.2);
    } else G.pAlpha[i] = 0;
  }
  const a = G.points.geometry.attributes;
  a.position.needsUpdate = a.color.needsUpdate = a.size.needsUpdate = a.alpha.needsUpdate = true;
}

// ---------- Effets visuels ----------
function matAdd(couleur, opacite = 1, map = null) {
  return new THREE.MeshBasicMaterial({ color: couleur, transparent: true, opacity: opacite, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, map });
}
export function ajouterVfx(obj, maj) { G.scene.add(obj); G.vfx.push({ obj, maj, t: 0 }); return obj; }
export function majVfx(dt) {
  for (let i = G.vfx.length - 1; i >= 0; i--) {
    const v = G.vfx[i]; v.t += dt;
    if (v.maj(v.t, dt, v.obj) === false) {
      G.scene.remove(v.obj);
      v.obj.traverse(o => { if (o.geometry && !o.geometry.userData.partage) o.geometry.dispose(); }); // les matériaux restent : leur programme GPU est réutilisé
      G.vfx.splice(i, 1);
    }
  }
}
export function onde(pos, couleur, rayon = 3, duree = 0.5, y = 0.12) {
  const m = new THREE.Mesh(new THREE.RingGeometry(0.85, 1, 48), matAdd(couleur, 1));
  m.rotation.x = -Math.PI / 2; m.position.set(pos.x, y, pos.z);
  ajouterVfx(m, (t) => { const k = t / duree; if (k >= 1) return false; m.scale.setScalar(0.2 + rayon * k); m.material.opacity = (1 - k) * 0.9; });
}
export function lueurSol(pos, couleur, rayon, duree, int = 1) {
  const m = new THREE.Mesh(new THREE.CircleGeometry(rayon, 40), matAdd(couleur, int, texRond()));
  m.rotation.x = -Math.PI / 2; m.position.set(pos.x, 0.1, pos.z);
  ajouterVfx(m, (t) => { const k = t / duree; if (k >= 1) return false; m.material.opacity = int * (1 - k); });
  return m;
}
// Arc de taillade (épée)
export function arcTaille(pos, angle, rayon, couleur, ouverture = Math.PI * 0.75, duree = 0.28) {
  const geo = new THREE.RingGeometry(rayon * 0.35, rayon, 40, 1, -ouverture / 2, ouverture);
  const tex = texture('arc', 128, 8, (g) => {
    const gr = g.createLinearGradient(0, 0, 128, 0); gr.addColorStop(0, 'rgba(255,255,255,0)'); gr.addColorStop(0.7, 'rgba(255,255,255,0.6)'); gr.addColorStop(1, 'rgba(255,255,255,1)');
    g.fillStyle = gr; g.fillRect(0, 0, 128, 8);
  });
  const m = new THREE.Mesh(geo, matAdd(couleur, 1, tex));
  m.rotation.x = -Math.PI / 2; m.rotation.z = angle; m.position.set(pos.x, 1.0, pos.z);
  ajouterVfx(m, (t) => { const k = t / duree; if (k >= 1) return false; m.material.opacity = 1 - k; m.rotation.z = angle + (k - 0.5) * 0.9; m.scale.setScalar(0.85 + k * 0.25); });
}
// Faisceau vertical (coffres, butin)
export function faisceau(pos, couleur, hauteur = 14, largeur = 0.9) {
  const tex = texture('faisceau', 4, 128, (g) => {
    const gr = g.createLinearGradient(0, 0, 0, 128); gr.addColorStop(0, 'rgba(255,255,255,0)'); gr.addColorStop(0.75, 'rgba(255,255,255,0.55)'); gr.addColorStop(1, 'rgba(255,255,255,1)');
    g.fillStyle = gr; g.fillRect(0, 0, 4, 128);
  });
  const grp = new THREE.Group();
  for (let i = 0; i < 2; i++) {
    const m = new THREE.Mesh(new THREE.CylinderGeometry(largeur * (i ? 0.45 : 1), largeur * (i ? 0.45 : 1), hauteur, 20, 1, true), matAdd(couleur, i ? 0.9 : 0.45, tex));
    m.position.y = hauteur / 2; grp.add(m);
  }
  grp.position.copy(pos);
  return grp;
}
// Télégraphe au sol : cercle ou cône rouge qui se remplit
const telegraphVS = `varying vec2 vUv; void main(){ vUv=uv; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);} `;
const telegraphFS = `uniform float uK; uniform vec3 uC; varying vec2 vUv;
  void main(){ vec2 p=vUv*2.0-1.0; float r=length(p); if(r>1.0) discard;
   float bord=smoothstep(0.9,0.98,r)*(1.0-smoothstep(0.98,1.0,r));
   float rempli=step(r,uK)*0.38 + smoothstep(uK-0.04,uK,r)*step(r,uK)*0.5;
   gl_FragColor=vec4(uC, bord*0.95+rempli+0.12); }`;
export function telegraphe(pos, rayon, duree, couleur = '#ff2a2a', cb, opts = {}) {
  let geo;
  if (opts.cone) geo = new THREE.CircleGeometry(rayon, 40, -opts.cone / 2, opts.cone);
  else geo = new THREE.PlaneGeometry(rayon * 2, rayon * 2);
  let mat;
  if (opts.cone || opts.ligne) mat = matAdd(couleur, 0.35);
  else mat = new THREE.ShaderMaterial({ uniforms: { uK: { value: 0 }, uC: { value: new THREE.Color(couleur) } }, vertexShader: telegraphVS, fragmentShader: telegraphFS, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending });
  if (opts.ligne) geo = new THREE.PlaneGeometry(opts.largeur, rayon).translate(0, rayon / 2, 0);
  const m = new THREE.Mesh(geo, mat);
  m.rotation.x = -Math.PI / 2; if (opts.angle !== undefined) m.rotation.z = opts.angle;
  m.position.set(pos.x, 0.09, pos.z);
  let fait = false;
  ajouterVfx(m, (t) => {
    const k = t / duree;
    if (mat.uniforms) mat.uniforms.uK.value = Math.min(1, k);
    else mat.opacity = 0.18 + 0.5 * k + 0.1 * Math.sin(t * 30);
    if (k >= 1 && !fait) { fait = true; cb && cb(); }
    if (k >= 1.06) return false;
  });
  return m;
}
// Projectiles visuels
// matériaux et géométries des projectiles partagés (aucune création à chaque tir)
const cacheP = {};
const pris = (cle, f) => { if (!cacheP[cle]) { const o = f(); if (o.isBufferGeometry) o.userData.partage = true; cacheP[cle] = o; } return cacheP[cle]; };
export function meshCarreau(couleur) {
  const g = new THREE.Group();
  const corps = new THREE.Mesh(pris('gCorps', () => new THREE.CylinderGeometry(0.04, 0.04, 1.1, 6)), pris('mCorps', () => new THREE.MeshStandardMaterial({ color: '#3a2a1e', roughness: 0.8 })));
  corps.rotation.x = Math.PI / 2; g.add(corps);
  const pointe = new THREE.Mesh(pris('gPointe', () => new THREE.ConeGeometry(0.09, 0.28, 6)), pris('mP' + couleur, () => new THREE.MeshStandardMaterial({ color: couleur, emissive: couleur, emissiveIntensity: 1.6 })));
  pointe.rotation.x = Math.PI / 2; pointe.position.z = 0.65; g.add(pointe);
  const halo = new THREE.Sprite(pris('sH' + couleur, () => new THREE.SpriteMaterial({ map: texRond(), color: couleur, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, opacity: 0.8 })));
  halo.scale.setScalar(0.9); halo.position.z = 0.6; g.add(halo);
  return g;
}
export function meshBoule(couleur, taille = 0.45) {
  const g = new THREE.Group();
  const coeur = new THREE.Mesh(pris('gBoule', () => new THREE.SphereGeometry(1, 12, 10)), pris('mBoule', () => new THREE.MeshBasicMaterial({ color: '#fff4c8' })));
  coeur.scale.setScalar(taille * 0.55); g.add(coeur);
  const halo = new THREE.Sprite(pris('sB' + couleur, () => new THREE.SpriteMaterial({ map: texRond(), color: couleur, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true })));
  halo.scale.setScalar(taille * 4.2); g.add(halo);
  return g;
}
export function chiffre3d() {}

// Étiquette (nom au-dessus des têtes)
export function projeter(v3) {
  const v = v3.clone().project(G.camera);
  return { x: (v.x + 1) / 2 * window.innerWidth, y: (1 - v.y) / 2 * window.innerHeight, visible: v.z < 1 && v.z > -1 };
}
