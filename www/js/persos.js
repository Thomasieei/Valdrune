// Personnages Quaternius : corps de base (tête seule) + tenue + coiffure, sur le squelette universel,
// animés par la bibliothèque UAL (couper du bois, porter, s'agenouiller, se relever…).
import { THREE, G, dansChamp } from './moteur.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';

const loader = new GLTFLoader();
const cache = {}, res = {}; let CLIPS = {};
const charger = (url) => cache[url] || (cache[url] = loader.loadAsync(url).then(g => (res[url] = g)));
const P = 'assets/perso/';
export const MODELES = {
  h: { corps: 'Superhero_Male_FullBody', tenues: { paysan: 'Male_Peasant', rodeur: 'Male_Ranger' }, cheveux: ['Hair_Buzzed', 'Hair_SimpleParted', 'Hair_Beard'] },
  f: { corps: 'Superhero_Female_FullBody', tenues: { paysan: 'Female_Peasant', rodeur: 'Female_Ranger' }, cheveux: ['Hair_Long', 'Hair_Buns'] },
};
export async function chargerPersos(progres) {
  const urls = ['anims.glb', 'anims_u1.glb', 'anims_u2.glb', ...Object.values(MODELES).flatMap(m => [m.corps + '.gltf', ...Object.values(m.tenues).map(t => t + '.gltf'), ...m.cheveux.map(c => c + '.gltf')])];
  let n = 0;
  await Promise.all(urls.map(u => charger(P + u).then(() => progres && progres(++n / urls.length))));
  // les clips tournent sur place : on retire le déplacement de la racine (sinon le perso « glisse » puis revient)
  for (const f of ['anims.glb', 'anims_u1.glb', 'anims_u2.glb']) for (const c of (await charger(P + f)).animations) { c.tracks = c.tracks.filter(t => !(/^root\.(position|scale)$/.test(t.name)) && !/\.scale$/.test(t.name)); CLIPS[c.name] = c; }
}
// ne garde que la tête et le cou du corps « Superhero » (le reste est sous la tenue)
const tetes = new Map();
function teteSeule(geo) {
  if (tetes.has(geo)) return tetes.get(geo);
  const p = geo.attributes.position, idx = geo.index, garde = [];
  for (let i = 0; i < idx.count; i += 3) {
    let ok = true; for (let k = 0; k < 3; k++) { const v = idx.getX(i + k); if (p.getY(v) < 1.40 || Math.abs(p.getX(v)) > 0.24) { ok = false; break; } }
    if (ok) garde.push(idx.getX(i), idx.getX(i + 1), idx.getX(i + 2));
  }
  const g = geo.clone(); g.setIndex(garde); tetes.set(geo, g); return g;
}
const matsCache = new Map();
function matMobile(m, teinte, variante = '') { // pas de carte de relief ni rugosité : moins cher, invisible à cette distance
  const cle = m.uuid + '|' + variante;
  if (matsCache.has(cle)) return matsCache.get(cle);
  const d = m.clone(); d.normalMap = null; d.roughnessMap = null; d.metalnessMap = null; d.aoMap = null; d.metalness = 0; d.roughness = 0.82; d.envMapIntensity = 0.5;
  if (teinte) teinte(d);
  matsCache.set(cle, d); return d;
}
// base commune : mixeur d'animations UAL + jouer / phase / tenir
class Anime {
  jouer(nom, { boucle = true, fondu = 0.2, vitesse = 1, fin = null, forcer = false } = {}) {
    if (this.anim === nom && !forcer) { if (this.actions[nom]) this.actions[nom].timeScale = vitesse; return this.actions[nom]; }
    const clip = this.clip(nom); if (!clip) return null;
    let a = this.actions[nom]; if (!a) a = this.actions[nom] = this.mixer.clipAction(clip);
    a.reset(); a.setLoop(boucle ? THREE.LoopRepeat : THREE.LoopOnce, boucle ? Infinity : 1); a.clampWhenFinished = !boucle; a.timeScale = vitesse;
    const avant = this.anim && this.actions[this.anim];
    a.play(); if (avant && avant !== a) a.crossFadeFrom(avant, fondu, false);
    this.anim = nom; this._fin = fin; this._finA = a;
    if (fin && !this._ecoute) { this._ecoute = true; this.mixer.addEventListener('finished', (e) => { if (e.action === this._finA && this._fin) { const f = this._fin; this._fin = null; f(); } }); }
    return a;
  }
  clip(nom) { return CLIPS[nom]; }
  duree(nom) { return CLIPS[nom] ? CLIPS[nom].duration : 1; }
  phase() { const a = this.actions[this.anim]; return a ? (a.time / a.getClip().duration) % 1 : 0; }
  // animation à la demande : rien hors champ, 15 images/s au loin, pleine cadence de près
  maj(dt) {
    this.skip = (this.skip || 0) + dt; const p = this.root.position, c = G.camera.position, d2 = (p.x - c.x) ** 2 + (p.z - c.z) ** 2;
    if (d2 > (this.portee || 90) ** 2 || !dansChamp(p, (this.rayonVue || 2.5))) { /* hors champ ou à plus de 90 m : ni dessiné ni animé */ if (this.root.visible) this.root.visible = false; if (this.skip > 0.5) { this.mixer.update(this.skip); this.skip = 0; } return; }
    if (!this.root.visible) this.root.visible = true;
    const loin = d2 > 900;
    if (loin && this.skip < 1 / 15) return;
    this.mixer.update(this.skip); this.skip = 0;
  }
  tenir(obj, os = 'hand_r') { const b = this.os[os]; if (b) b.add(obj); return obj; }
}
// monstres du bestiaire : même squelette que les personnages, donc mêmes animations (on ne garde que les rotations,
// et la hauteur du bassin est remise à l'échelle du monstre)
const clipsMonstre = new Map();
export async function chargerMonstre(nom) { await charger('assets/monstres/' + nom + '.glb'); }
export class Monstre extends Anime {
  constructor(nom, { teinte = null, echelle = 1 } = {}) {
    super(); const url = 'assets/monstres/' + nom + '.glb';
    this.root = new THREE.Group(); const base = SkeletonUtils.clone(res[url].scene); base.scale.setScalar(echelle); this.root.add(base);
    const os = {}; base.traverse(o => { if (o.isBone) os[o.name] = o; }); this.os = os; this.meshes = [];
    base.traverse(o => { if (o.isSkinnedMesh) { o.castShadow = true; o.frustumCulled = false; o.material = matMobile(o.material, teinte, teinte ? teinte.name : ''); this.meshes.push(o); } });
    this.mixer = new THREE.AnimationMixer(base); this.actions = {}; this.anim = null; this.pos = this.root.position; this.nom = nom;
    if (!clipsMonstre.has(nom)) {
      const hum = res[P + MODELES.h.corps + '.gltf']; let ph = 1, pm = 1; hum.scene.traverse(o => { if (o.isBone && o.name === 'pelvis') ph = o.position.y || 1; }); if (os.pelvis) pm = os.pelvis.position.y || 1;
      const k = pm / ph, m = {};
      for (const [n, c] of Object.entries(CLIPS)) m[n] = new THREE.AnimationClip(n, c.duration, c.tracks.filter(t => (t.name.endsWith('.quaternion') || t.name === 'pelvis.position') && os[t.name.split('.')[0]]).map(t => { if (t.name !== 'pelvis.position') return t; const u = t.clone(); for (let i = 0; i < u.values.length; i++) u.values[i] *= k; return u; }));
      clipsMonstre.set(nom, m);
    }
    this.clips = clipsMonstre.get(nom);
  }
  clip(nom) { return this.clips[nom]; }
}
// créatures à squelette propre (gobelin, orc) : leurs animations portent d'autres noms → table de correspondance,
// le reste du code continue d'utiliser les noms UAL (Idle_Loop, Hit_Chest…)
const CORRESP = { Idle_Loop: 'Idle', Idle_FoldArms_Loop: 'Idle', Sword_Idle: 'Idle', Walk_Loop: 'Walk', Jog_Fwd_Loop: 'Run', Death01: 'Death', Hit_Chest: 'Hit', Hit_Head: 'Hit', Hit_Knockback: 'Hit', Sword_Block: 'Block', Crouch_Idle_Loop: 'Choked', Spell_Simple_Enter: 'Cast', Spell_Simple_Shoot: 'CastShoot', Sitting_Idle_Loop: 'Idle', Consume: 'Idle', LayToIdle: 'Idle' };
const hauteurs = new Map();
export class ModeleAnime extends Anime {
  constructor(nom, { hauteur = 1.8, cacher = [], teinte = null } = {}) {
    super(); const g = res['assets/monstres/' + nom + '.glb'];
    this.root = new THREE.Group(); const base = SkeletonUtils.clone(g.scene); this.root.add(base);
    base.traverse(o => { if (o.isMesh) { if (cacher.some(c => o.name.includes(c))) o.visible = false; o.castShadow = true; o.frustumCulled = false; o.material = matMobile(o.material, teinte, nom + (teinte ? '|ombre' : '')); } });
    if (!hauteurs.has(nom)) { base.updateMatrixWorld(true); const b = new THREE.Box3(); base.traverse(o => { if (o.isMesh && o.visible) b.expandByObject(o, true); }); hauteurs.set(nom, [b.max.y - b.min.y, b.min.y]); }
    const [h, y0] = hauteurs.get(nom), k = hauteur / h; base.scale.multiplyScalar(k); base.position.y = -y0 * k;
    const os = {}; base.traverse(o => { if (o.isBone) os[o.name] = o; }); this.os = os;
    this.mixer = new THREE.AnimationMixer(base); this.actions = {}; this.anim = null; this.pos = this.root.position; this.nom = nom;
    this.clips = Object.fromEntries(g.animations.map(c => [c.name, c]));
  }
  clip(nom) { return this.clips[nom] || this.clips[CORRESP[nom]] || null; }
  duree(nom) { const c = this.clip(nom); return c ? c.duration : 1; }
}
export class Perso extends Anime {
  // corps : un autre corps du même squelette (orc, orque…) habillé avec les mêmes tenues
  constructor({ sexe = 'h', tenue = 'paysan', cheveux = 0, teinte = null, couleurTenue = null, corps = null } = {}) {
    super(); const M = MODELES[sexe];
    this.root = new THREE.Group();
    const base = SkeletonUtils.clone(corps ? res['assets/monstres/' + corps + '.glb'].scene : res[P + M.corps + '.gltf'].scene);
    this.root.add(base);
    const os = {}; base.traverse(o => { if (o.isBone) os[o.name] = o; });
    this.os = os; this.meshes = [];
    const habiller = (m) => {
      m.castShadow = true; m.receiveShadow = false; m.frustumCulled = false;
      m.material = matMobile(m.material, (d) => { if (couleurTenue && /Peasant|Ranger/i.test(m.name + d.name) && d.map) d.color.set(couleurTenue); if (teinte) teinte(d); }, (couleurTenue || '') + '|' + (teinte ? teinte.name : ''));
      this.meshes.push(m);
    };
    base.traverse(o => { if (o.isSkinnedMesh) { if (/SuperHero|Superhero|_Body/i.test(o.name)) o.geometry = teteSeule(o.geometry); habiller(o); } });
    const greffer = (nom) => {
      const s = SkeletonUtils.clone(res[P + nom + '.gltf'].scene); const aj = [];
      s.traverse(o => { if (o.isSkinnedMesh) aj.push(o); });
      for (const m of aj) {
        const bones = m.skeleton.bones.map(b => os[b.name] || b);
        m.bind(new THREE.Skeleton(bones, m.skeleton.boneInverses), m.bindMatrix);
        base.add(m); habiller(m);
      }
    };
    greffer(M.tenues[tenue] || M.tenues.paysan);
    if (cheveux >= 0) greffer(M.cheveux[cheveux % M.cheveux.length]);
    this.mixer = new THREE.AnimationMixer(base); this.actions = {}; this.anim = null;
    this.pos = this.root.position; this.angle = 0;
  }
}
export const clips = () => CLIPS;
// objets du Fantasy Props MegaKit (armes, bannières, coffre…) : même famille Quaternius que le reste
export async function chargerProps(noms) { await Promise.all(noms.map(n => charger('assets/props/' + n + '.gltf'))); }
export function prop(n) { const r = res['assets/props/' + n + '.gltf']; if (!r) return new THREE.Group(); const o = SkeletonUtils.clone(r.scene); o.traverse(m => { if (m.isMesh) { if (m.isSkinnedMesh) m.frustumCulled = false; m.castShadow = true; m.receiveShadow = true; m.material = matMobile(m.material); } }); return o; }
