// ===== Loups démoniaques du Maître des bêtes (modélisés à la main, animés par code) =====
import { THREE, G, emettre, solY } from './engine.js';

const MAT = {};
function mats() {
  if (MAT.f) return MAT;
  MAT.f = new THREE.MeshStandardMaterial({ color: '#1e171b', roughness: 0.55, metalness: 0.2, flatShading: true, emissive: '#4a0408', emissiveIntensity: 0.45 });
  MAT.f2 = new THREE.MeshStandardMaterial({ color: '#2c2226', roughness: 0.7, flatShading: true, emissive: '#2a0204', emissiveIntensity: 0.3 });
  MAT.os = new THREE.MeshStandardMaterial({ color: '#e8dccb', roughness: 0.4 });
  MAT.braise = new THREE.MeshBasicMaterial({ color: '#ff2a1a' });
  MAT.pic = new THREE.MeshStandardMaterial({ color: '#3a0a0e', roughness: 0.35, metalness: 0.4, emissive: '#ff1a10', emissiveIntensity: 0.55, flatShading: true });
  MAT.halo = new THREE.MeshBasicMaterial({ color: '#ff1a1a', side: THREE.BackSide, transparent: true, opacity: 0.28, blending: THREE.AdditiveBlending, depthWrite: false });
  MAT.sol = new THREE.MeshBasicMaterial({ color: '#ff2a1a', transparent: true, opacity: 0.3, blending: THREE.AdditiveBlending, depthWrite: false });
  MAT.noir = new THREE.MeshStandardMaterial({ color: '#080608', roughness: 0.3 });
  return MAT;
}
const boule = (r, m, sx = 1, sy = 1, sz = 1) => { const o = new THREE.Mesh(new THREE.SphereGeometry(r, 9, 7), m); o.scale.set(sx, sy, sz); return o; };

export class Loup {
  constructor(echelle = 1) {
    const M = mats();
    this.root = new THREE.Group();
    const c = this.corps = new THREE.Group(); this.root.add(c);
    const halo = (o, k = 1.12) => { const h = new THREE.Mesh(o.geometry, M.halo); h.scale.copy(o.scale).multiplyScalar(k); h.position.copy(o.position); h.rotation.copy(o.rotation); return h; };
    // torse : poitrail massif, ventre creusé, hanches
    const tronc = boule(0.5, M.f, 0.72, 0.6, 1.25); tronc.position.set(0, 0.95, -0.02); c.add(tronc, halo(tronc));
    const poitrail = boule(0.46, M.f, 0.9, 0.85, 0.8); poitrail.position.set(0, 1.02, 0.42); c.add(poitrail, halo(poitrail));
    const hanches = boule(0.38, M.f2, 0.85, 0.85, 0.9); hanches.position.set(0, 0.95, -0.5); c.add(hanches);
    // crinière de piques écarlates le long du dos
    for (let i = 0; i < 6; i++) { const p = new THREE.Mesh(new THREE.ConeGeometry(0.07 - i * 0.006, 0.34 - i * 0.03, 4), M.pic); p.position.set(0, 1.38 - i * 0.045, 0.5 - i * 0.2); p.rotation.x = -0.75; c.add(p); }
    // tête
    const t = this.tete = new THREE.Group(); t.position.set(0, 1.32, 0.78); c.add(t);
    const crane = boule(0.24, M.f, 1, 0.85, 1.05); t.add(crane, halo(crane, 1.15));
    const museau = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.16, 0.36), M.f2); museau.position.set(0, -0.05, 0.3); t.add(museau);
    const truffe = boule(0.05, M.noir); truffe.position.set(0, -0.0, 0.49); t.add(truffe);
    const m = this.machoire = new THREE.Group(); m.position.set(0, -0.12, 0.12); t.add(m);
    const mach = new THREE.Mesh(new THREE.BoxGeometry(0.17, 0.06, 0.34), M.f2); mach.position.z = 0.17; m.add(mach);
    for (const s of [-1, 1]) {
      const croc = new THREE.Mesh(new THREE.ConeGeometry(0.022, 0.09, 4), M.os); croc.position.set(s * 0.07, -0.12, 0.44); croc.rotation.x = Math.PI; t.add(croc);
      const oreille = new THREE.Mesh(new THREE.ConeGeometry(0.075, 0.3, 4), M.f); oreille.position.set(s * 0.13, 0.24, -0.06); oreille.rotation.set(-0.45, 0, s * -0.25); t.add(oreille);
      const oeil = boule(0.04, M.braise, 1.3, 0.7, 1); oeil.position.set(s * 0.11, 0.05, 0.19); t.add(oeil);
      const corne = new THREE.Mesh(new THREE.ConeGeometry(0.04, 0.26, 5), M.pic); corne.position.set(s * 0.09, 0.2, 0.08); corne.rotation.set(-1.0, 0, s * -0.4); t.add(corne);
    }
    // pattes (épaule/hanche → avant-bras → patte)
    this.pattes = [];
    for (const [x, z, av] of [[-0.2, 0.42, 1], [0.2, 0.42, 1], [-0.2, -0.5, 0], [0.2, -0.5, 0]]) {
      const p = new THREE.Group(); p.position.set(x, 0.92, z); c.add(p);
      const h = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.075, 0.48, 6), M.f); h.position.y = -0.22; p.add(h);
      const b = new THREE.Group(); b.position.y = -0.44; p.add(b);
      const tib = new THREE.Mesh(new THREE.CylinderGeometry(0.065, 0.05, 0.42, 6), M.f2); tib.position.y = -0.19; b.add(tib);
      const pied = boule(0.075, M.f, 1, 0.6, 1.4); pied.position.set(0, -0.42, 0.04); b.add(pied);
      for (const g of [-1, 0, 1]) { const gr = new THREE.Mesh(new THREE.ConeGeometry(0.015, 0.07, 3), M.os); gr.position.set(g * 0.035, -0.44, 0.13); gr.rotation.x = Math.PI / 2; b.add(gr); }
      this.pattes.push({ p, b, av, ph: av ? 0 : Math.PI });
    }
    // queue en braise
    const q = this.queue = new THREE.Group(); q.position.set(0, 1.05, -0.8); c.add(q);
    const qq = new THREE.Mesh(new THREE.ConeGeometry(0.11, 0.75, 6), M.f); qq.rotation.x = -2.1; qq.position.set(0, 0.18, -0.3); q.add(qq);
    const bout = new THREE.Mesh(new THREE.ConeGeometry(0.05, 0.25, 5), M.pic); bout.rotation.x = -2.1; bout.position.set(0, 0.4, -0.66); q.add(bout);
    // aura au sol
    this.aura = new THREE.Mesh(new THREE.RingGeometry(0.6, 0.85, 32), M.sol); this.aura.rotation.x = -Math.PI / 2; this.aura.position.y = 0.05; this.root.add(this.aura);
    this.root.traverse(o => { if (o.isMesh && o.material !== M.halo && o.material !== M.sol) o.castShadow = true; });
    this.root.scale.setScalar(0.82 * echelle);
    this.etat = 'idle'; this.t = Math.random() * 10; this.mordT = 0; this.flashT = 0; this.mortT = 0; this.finCb = null;
    this.matsFlash = [M.f, M.f2];
  }
  jouer(nom, opts = {}) {
    const n = String(nom || '');
    let e = /Death/.test(n) ? 'mort' : /Run|Fast|course/.test(n) ? 'course' : /Attack|Shoot|Chop|Slice|Punch|Headbutt|morsure|Spellcast/.test(n) ? 'morsure' : /saut/.test(n) ? 'saut' : /hurle/.test(n) ? 'hurle' : 'idle';
    if (this.etat === 'mort' && e !== 'idle') return;
    if (e === 'morsure' || e === 'hurle') { this.mordT = e === 'hurle' ? 0.9 : 0.38; this.finCb = opts.fin || null; }
    if (e === 'mort') this.mortT = 0;
    if ((this.etat === 'morsure' || this.etat === 'hurle') && this.mordT > 0 && (e === 'idle' || e === 'course') && !opts.forcer) return;
    this.etat = e;
  }
  frapper() { this.flashT = 0.12; }
  maj(dt) {
    this.t += dt; const t = this.t;
    if (this.mordT > 0) { this.mordT -= dt; if (this.mordT <= 0) { const cb = this.finCb; this.finCb = null; this.etat = 'idle'; if (cb) cb(); } }
    const e = this.etat, c = this.corps;
    let ouvre = 0.05, teteX = 0, teteY = 0, corpsY = 0, corpsX = 0;
    if (e === 'course' || e === 'saut') {
      const w = 15, k = e === 'saut' ? 0.9 : 0.75;
      for (const p of this.pattes) { const s = Math.sin(t * w + p.ph + (p.p.position.x > 0 ? 0.6 : 0)); p.p.rotation.x = s * k; p.b.rotation.x = Math.max(0, -s) * 0.9 * (p.av ? -1 : 1); }
      corpsY = Math.abs(Math.sin(t * w)) * 0.08; corpsX = Math.sin(t * w * 2) * 0.03; teteX = Math.sin(t * w) * 0.06; ouvre = 0.18;
      this.queue.rotation.x = 0.4 + Math.sin(t * w) * 0.15;
    } else if (e === 'morsure') {
      const k = 1 - Math.max(0, this.mordT) / 0.38; const lunge = Math.sin(k * Math.PI);
      ouvre = 0.6 * lunge; teteX = 0.35 * lunge; c.position.z = 0.3 * lunge;
      for (const p of this.pattes) { p.p.rotation.x *= 0.8; p.b.rotation.x *= 0.8; }
    } else if (e === 'hurle') {
      teteX = -0.9; teteY = 0; ouvre = 0.75; corpsX = -0.18;
      for (const p of this.pattes) p.p.rotation.x = p.av ? -0.3 : 0.2;
    } else if (e === 'mort') {
      this.mortT += dt; const k = Math.min(1, this.mortT / 0.5);
      c.rotation.z = k * 1.45; c.position.y = -k * 0.42; ouvre = 0.35;
      for (const p of this.pattes) p.p.rotation.x = 0.4 * k;
    } else { // repos : respiration, regard, queue qui fouette
      for (const p of this.pattes) { p.p.rotation.x *= 0.85; p.b.rotation.x *= 0.85; }
      corpsY = Math.sin(t * 2.2) * 0.012; teteY = Math.sin(t * 0.7) * 0.35; teteX = Math.sin(t * 1.3) * 0.05;
      this.queue.rotation.y = Math.sin(t * 3) * 0.35; ouvre = 0.08 + Math.max(0, Math.sin(t * 2.2)) * 0.12;
    }
    if (e !== 'morsure') c.position.z *= 0.8;
    if (e !== 'mort') { c.rotation.z = 0; c.position.y = corpsY; c.rotation.x = corpsX; }
    this.tete.rotation.x = teteX; this.tete.rotation.y = teteY; this.machoire.rotation.x = ouvre;
    const sy = solY(this.root.position.x, this.root.position.z); c.position.y += sy; this.aura.position.y = 0.05 + sy;
    // aura pulsée et braises
    this.aura.visible = e !== 'mort';
    const s = 1 + Math.sin(t * 5) * 0.12; this.aura.scale.set(s, s, s); this.aura.material.opacity = 0.2 + Math.sin(t * 5) * 0.08;
    if (e !== 'mort' && Math.random() < dt * 2.2) { const p = this.root.position; emettre(new THREE.Vector3(p.x + (Math.random() - 0.5) * 0.8, 0.9 + Math.random() * 0.6, p.z + (Math.random() - 0.5) * 0.8), { n: 1, c1: '#ff7a4a', c2: '#c00a0a', vit: 0.6, vie: 0.6, taille: 0.11, grav: -2.5 }); }
    if (this.flashT > 0) { this.flashT -= dt; for (const m of this.matsFlash) m.emissiveIntensity = 1.6; } else for (const m of this.matsFlash) m.emissiveIntensity = m === MAT.f ? 0.45 : 0.3;
  }
}
// portrait (tête) pour le cadre de la meute
let portraitURL = null;
export function portraitLoup() {
  if (portraitURL) return portraitURL;
  const r = new THREE.WebGLRenderer({ alpha: true, antialias: true, preserveDrawingBuffer: true }); r.setSize(128, 128); r.outputColorSpace = THREE.SRGBColorSpace;
  const sc = new THREE.Scene(); sc.add(new THREE.AmbientLight('#ffffff', 2.4)); const d = new THREE.DirectionalLight('#ffe8d8', 3.4); d.position.set(1.5, 2, 3); sc.add(d); const d2 = new THREE.DirectionalLight('#ff3a2a', 2); d2.position.set(-2, 1, -1); sc.add(d2);
  const l = new Loup(); l.maj(0.01); sc.add(l.root);
  const cam = new THREE.PerspectiveCamera(30, 1, 0.1, 20); cam.position.set(0.55, 1.2, 1.55); cam.lookAt(0, 1.07, 0.62);
  r.render(sc, cam); portraitURL = r.domElement.toDataURL(); r.dispose();
  return portraitURL;
}
