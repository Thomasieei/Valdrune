/* UMBRA — moteur 3D : chargement, personnages, décors, effets */
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';
import { rnd, pick } from './data.js';

export const E = { THREE, gltf: {}, clips: [], colliders: [], boxes: [], fx: [], t: 0, yaw: 0.6, pitch: 0.92, dist: 21, shake: 0 };
const CHAR_FILES = ['Knight', 'Barbarian', 'Mage', 'Rogue_Hooded', 'Rogue', 'Skeleton_Minion', 'Skeleton_Warrior', 'Skeleton_Mage', 'wolf', 'fox', 'bull', 'stag'];
const ENV = {
  d: ['column', 'floor_tile_large', 'floor_tile_large_rocks', 'pillar', 'pillar_decorated', 'rubble_half', 'rubble_large', 'torch_mounted', 'wall', 'wall_broken', 'wall_cracked', 'chest_gold', 'banner_patternA_red', 'banner_patternB_blue', 'barrel_large', 'coin_stack_large', 'sword_shield_gold', 'candle_triple'],
  h: ['crypt', 'fence', 'grave_A', 'grave_B', 'gravestone', 'lantern_standing', 'post_lantern', 'pumpkin_orange', 'ribcage', 'shrine_candles', 'skull_candle', 'tree_dead_large', 'tree_dead_medium', 'bone_A'],
  x: ['building_castle_blue', 'building_tower_A_blue', 'building_tower_B_blue', 'building_market_blue', 'building_blacksmith_blue', 'building_church_blue', 'building_tavern_blue', 'building_well_blue', 'building_home_A_blue', 'building_home_B_red', 'building_home_A_yellow', 'building_barracks_blue', 'flag_red', 'tent', 'weaponrack', 'crate_A_big', 'barrel'],
  n: ['CommonTree_1', 'CommonTree_3', 'CommonTree_5', 'Pine_1', 'Pine_3', 'TwistedTree_1', 'TwistedTree_3', 'DeadTree_2', 'Bush_Common', 'Bush_Common_Flowers', 'Rock_Medium_1', 'Rock_Medium_2', 'Rock_Medium_3', 'Grass_Common_Tall', 'Flower_3_Group', 'Flower_4_Group', 'Mushroom_Common', 'Fern_1'],
  w: ['sword_E', 'sword_D', 'staff_A', 'axe_2handed', 'dagger_A'],
  k: ['building-a', 'building-b', 'building-c', 'building-d', 'building-e', 'building-f', 'building-g', 'building-h', 'building-skyscraper-a', 'building-skyscraper-b', 'building-skyscraper-c', 'building-skyscraper-d', 'building-skyscraper-e', 'detail-parasol-a'],
  r: ['road-straight', 'road-crossroad', 'light-square', 'light-curved', 'construction-cone', 'dumpster', 'traffic-light'],
};

/* ---------- initialisation ---------- */
export function init(canvas) {
  const r = E.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
  r.setPixelRatio(Math.min(devicePixelRatio, 2)); r.outputColorSpace = THREE.SRGBColorSpace;
  r.shadowMap.enabled = true; r.shadowMap.type = THREE.PCFSoftShadowMap;
  r.toneMapping = THREE.ACESFilmicToneMapping; r.toneMappingExposure = 1.15;
  E.scene = new THREE.Scene();
  E.cam = new THREE.PerspectiveCamera(48, 1, 0.3, 400);
  E.hemi = new THREE.HemisphereLight(0xcfd8ff, 0x3a2a40, 1.1); E.scene.add(E.hemi);
  const sun = E.sun = new THREE.DirectionalLight(0xffffff, 2.2); sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048); const sc = sun.shadow.camera; sc.left = sc.bottom = -26; sc.right = sc.top = 26; sc.near = 1; sc.far = 90; sun.shadow.bias = -0.0006;
  E.scene.add(sun, sun.target);
  E.world = new THREE.Group(); E.scene.add(E.world);
  E.glowTex = radialTex(); E.swirlTex = swirlTex();
  E.particles = new Particles(420); E.scene.add(E.particles.points);
  addEventListener('resize', resize); resize();
}
export function setQuality(hq) {
  E.renderer.setPixelRatio(hq ? Math.min(devicePixelRatio, 2) : Math.min(devicePixelRatio, 1.25));
  E.sun.castShadow = hq; resize();
}
function resize() { const w = innerWidth, h = innerHeight; E.renderer.setSize(w, h, false); E.cam.aspect = w / h; E.cam.updateProjectionMatrix(); }

/* ---------- chargement ---------- */
export async function loadAll(onProg) {
  const L = new GLTFLoader(); const jobs = [];
  for (const c of CHAR_FILES) jobs.push(['c:' + c, `assets/c/${c}.glb`]);
  jobs.push(['rig1', 'assets/c/Rig_Medium_General.glb'], ['rig2', 'assets/c/Rig_Medium_MovementBasic.glb'], ['c:dragon', 'assets/g/dragon.gltf']);
  for (const k in ENV) for (const n of ENV[k]) jobs.push([k + ':' + n, `assets/${k}/${n}.${'ckr'.includes(k) ? 'glb' : 'gltf'}`]);
  let done = 0;
  await Promise.all(jobs.map(([key, url]) => new Promise(res => {
    L.load(url, g => { E.gltf[key] = g; done++; onProg(done / jobs.length); res(); }, undefined, e => { console.warn('load fail', url, e); done++; onProg(done / jobs.length); res(); });
  })));
  E.clips = [...(E.gltf.rig1?.animations || []), ...(E.gltf.rig2?.animations || [])];
  for (const k in E.gltf) if (!k.startsWith('c:')) E.gltf[k].scene.traverse(o => { if (o.isMesh) prepMat(o); });
}
function prepMat(o) {
  const m = o.material; if (!m || m.userData.prep) return;
  if (m.map) m.map.colorSpace = THREE.SRGBColorSpace;
  m.userData.prep = true;
}

/* ---------- personnages ---------- */
const WEAPON_RX = /Shield|Axe|Sword|Mug|Spellbook|Wand|Staff|Crossbow|Knife|Throwable/;
const ANIM_MAP = {
  idle: ['Idle', 'Idle_A', 'Unarmed_Idle', 'Flying_Idle'], run: ['Running_A', 'Gallop', 'Fast_Flying'], walk: ['Walking_A', 'Walk'],
  attack: ['Attack', 'Attack_Headbutt', 'Punch', 'Headbutt', 'Use_Item', 'Throw'], cast: ['Spellcasting', 'Throw', 'Attack'], hit: ['Hit_A', 'Idle_HitReact_Left', 'HitReact'],
  death: ['Death', 'Death_A'], cheer: ['Cheer', 'Interact'],
};
const matCache = new Map();
export function makeChar(model, o = {}) {
  const g = E.gltf['c:' + model]; const root = new THREE.Group();
  const mdl = SkeletonUtils.clone(g.scene); root.add(mdl); mdl.scale.setScalar(o.scale || 1);
  const quad = !!g.animations.find(a => a.name === 'Gallop' || a.name === 'Flying_Idle');
  mdl.traverse(n => {
    if (n.isMesh || n.isSkinnedMesh) {
      n.frustumCulled = false; n.castShadow = !o.noShadow;
      if (o.keep) n.visible = o.keep.some(p => n.name.startsWith(p));
      else if (WEAPON_RX.test(n.name)) n.visible = false;
      n.material = charMat(n.material, o, n.name);
    }
  });
  if (o.weapon) attachWeapon(mdl, o.weapon, o.wcol, o.shadow);
  const mixer = new THREE.AnimationMixer(mdl); const acts = {};
  const clips = quad ? g.animations : [...g.animations, ...E.clips];
  for (const c of clips) if (!acts[c.name]) acts[c.name] = mixer.clipAction(c);
  const ch = {
    root, mdl, mixer, acts, cur: '', quad, lock: 0,
    play(kind, opt = {}) {
      const name = (ANIM_MAP[kind] || [kind]).find(n => acts[n]); if (!name) return 0;
      if (name === this.cur && !opt.restart) return acts[name]._clip.duration;
      const a = acts[name], prev = acts[this.cur];
      a.reset(); a.timeScale = opt.speed || 1;
      a.setLoop(opt.once ? THREE.LoopOnce : THREE.LoopRepeat); a.clampWhenFinished = !!opt.once;
      a.fadeIn(opt.fade ?? 0.15).play(); if (prev && prev !== a) prev.fadeOut(opt.fade ?? 0.15);
      this.cur = name; return a._clip.duration / (opt.speed || 1);
    },
    update(dt) { mixer.update(dt); },
    dispose() { root.removeFromParent(); mixer.stopAllAction(); },
  };
  ch.play('idle'); return ch;
}
function charMat(src, o, name) {
  const eyes = /Eyes/.test(name);
  const key = (src.uuid) + (o.shadow ? 'S' + (o.shadowCol || 0) : '') + (o.tint || '') + (eyes ? 'e' : '');
  if (matCache.has(key)) return matCache.get(key);
  let m;
  if (o.shadow) {
    m = eyes ? new THREE.MeshBasicMaterial({ color: o.eyeCol || 0x9ff3ff })
      : new THREE.MeshLambertMaterial({ map: src.map, color: 0x1a1236, emissive: o.shadowCol || 0x4c1d95, emissiveIntensity: 0.75 });
  } else {
    m = eyes ? new THREE.MeshBasicMaterial({ color: o.eyeCol || 0xff4040 }) : new THREE.MeshLambertMaterial({ map: src.map, color: src.color ? src.color.clone() : 0xffffff });
    if (src.map) src.map.colorSpace = THREE.SRGBColorSpace;
    if (o.tint && !eyes) m.color.multiply(new THREE.Color(o.tint)), m.emissive = new THREE.Color(o.tint).multiplyScalar(0.15);
  }
  matCache.set(key, m); return m;
}
export function attachWeapon(mdl, wname, col, shadow) {
  let hand = null; mdl.traverse(n => { if (n.name === 'handslot.r') hand = n; });
  if (!hand) return null;
  const old = hand.getObjectByName('__w'); if (old) old.removeFromParent();
  const g = E.gltf['w:' + wname]; if (!g) return null;
  const w = g.scene.clone(true); w.name = '__w';
  w.traverse(n => {
    if (!n.isMesh) return; n.castShadow = true;
    n.material = shadow ? new THREE.MeshLambertMaterial({ map: n.material.map, color: 0x2a1d5c, emissive: 0x5b2bff, emissiveIntensity: 0.8 })
      : new THREE.MeshLambertMaterial({ map: n.material.map, color: 0xffffff, emissive: new THREE.Color(col || 0), emissiveIntensity: col ? 0.45 : 0 });
  });
  hand.add(w); return w;
}

/* ---------- textures procédurales ---------- */
function radialTex() {
  const c = document.createElement('canvas'); c.width = c.height = 64; const x = c.getContext('2d');
  const g = x.createRadialGradient(32, 32, 0, 32, 32, 32); g.addColorStop(0, 'rgba(255,255,255,1)'); g.addColorStop(0.35, 'rgba(255,255,255,0.55)'); g.addColorStop(1, 'rgba(255,255,255,0)');
  x.fillStyle = g; x.fillRect(0, 0, 64, 64); const t = new THREE.CanvasTexture(c); return t;
}
function swirlTex() {
  const c = document.createElement('canvas'); c.width = c.height = 256; const x = c.getContext('2d');
  const g = x.createRadialGradient(128, 128, 4, 128, 128, 128); g.addColorStop(0, '#ffffff'); g.addColorStop(0.25, '#c9a6ff'); g.addColorStop(0.6, '#5b21b6'); g.addColorStop(1, 'rgba(20,0,60,0)');
  x.fillStyle = g; x.fillRect(0, 0, 256, 256);
  x.globalCompositeOperation = 'lighter';
  for (let i = 0; i < 6; i++) { x.strokeStyle = `rgba(${150 + i * 15},${120 + i * 10},255,0.35)`; x.lineWidth = 6; x.beginPath(); for (let a = 0; a < 9; a += 0.05) { const r = a * 13; const px = 128 + Math.cos(a + i * 1.05) * r, py = 128 + Math.sin(a + i * 1.05) * r; a === 0 ? x.moveTo(px, py) : x.lineTo(px, py); } x.stroke(); }
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}
function groundTex(c1, c2, stone) {
  const c = document.createElement('canvas'); c.width = c.height = 512; const x = c.getContext('2d');
  x.fillStyle = c1; x.fillRect(0, 0, 512, 512);
  for (let i = 0; i < 2600; i++) { x.fillStyle = Math.random() < 0.5 ? c2 : shade(c1, rnd(-18, 22)); x.globalAlpha = rnd(0.08, 0.35); const r = rnd(2, stone ? 10 : 18); x.beginPath(); x.arc(rnd(0, 512), rnd(0, 512), r, 0, 7); x.fill(); }
  if (stone) { x.globalAlpha = 0.25; x.strokeStyle = shade(c2, -30); x.lineWidth = 2; for (let yy = 0; yy < 512; yy += 64) for (let xx = 0; xx < 512; xx += 64) x.strokeRect(xx + ((yy / 64) % 2) * 32, yy, 64, 64); }
  x.globalAlpha = 1; const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4; return t;
}
function shade(hex, d) { const n = parseInt(hex.slice(1), 16); const f = v => Math.max(0, Math.min(255, v + d)); return `rgb(${f(n >> 16)},${f((n >> 8) & 255)},${f(n & 255)})`; }

/* ---------- placement instancié des décors ---------- */
let placements = new Map();
export function place(key, x, z, rot = 0, s = 1, y = 0, col = 0) {
  if (!E.gltf[key]) return; if (!placements.has(key)) placements.set(key, []);
  placements.get(key).push(new THREE.Matrix4().compose(new THREE.Vector3(x, y, z), new THREE.Quaternion().setFromEuler(new THREE.Euler(0, rot, 0)), new THREE.Vector3(s, s, s)));
  if (col) E.colliders.push({ x, z, r: col * s });
}
function flush(root) {
  for (const [key, mats] of placements) {
    const sc = E.gltf[key].scene; sc.updateMatrixWorld(true);
    sc.traverse(n => {
      if (!n.isMesh) return;
      const mat = key[0] === 'k' ? (n.userData.city ||= new THREE.MeshLambertMaterial({ map: n.material.map, color: 0xf2f6ff, emissive: 0x1d2f80, emissiveIntensity: 0.35 })) : n.material.isMeshLambertMaterial ? n.material : (n.userData.lam ||= new THREE.MeshLambertMaterial({ map: n.material.map, color: n.material.color, transparent: n.material.transparent, alphaTest: n.material.alphaTest || (n.material.map && /Grass|Flower|Fern|Bush|Leaves|Tree|Pine/.test(key) ? 0.4 : 0), side: n.material.side }));
      const im = new THREE.InstancedMesh(n.geometry, mat, mats.length);
      mats.forEach((m, i) => im.setMatrixAt(i, new THREE.Matrix4().multiplyMatrices(m, n.matrixWorld)));
      im.castShadow = mats.length <= 24 && key[0] !== 'r'; im.receiveShadow = true; im.frustumCulled = false; root.add(im);
    });
  }
  placements = new Map();
}

/* ---------- environnements ---------- */
function clearWorld() {
  E.world.traverse(o => { if (o.isInstancedMesh) o.dispose(); });
  E.world.clear(); E.colliders = []; E.boxes = []; E.anim = []; E.lights = [];
}
function sky(top, bot, stars) {
  const geo = new THREE.SphereGeometry(300, 24, 12);
  const mat = new THREE.ShaderMaterial({ side: THREE.BackSide, depthWrite: false, fog: false, uniforms: { a: { value: new THREE.Color(top) }, b: { value: new THREE.Color(bot) } },
    vertexShader: 'varying float h; void main(){ h = normalize(position).y; gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.); }',
    fragmentShader: 'uniform vec3 a; uniform vec3 b; varying float h; void main(){ gl_FragColor = vec4(mix(b,a,smoothstep(-0.05,0.55,h)),1.); }' });
  const m = new THREE.Mesh(geo, mat); E.world.add(m);
  if (stars) {
    const n = 600, p = new Float32Array(n * 3); for (let i = 0; i < n; i++) { const t = rnd(0, 6.28), u = rnd(0.15, 1), r = 280; p[i * 3] = Math.cos(t) * Math.sqrt(1 - u * u) * r; p[i * 3 + 1] = u * r; p[i * 3 + 2] = Math.sin(t) * Math.sqrt(1 - u * u) * r; }
    const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.BufferAttribute(p, 3));
    E.world.add(new THREE.Points(g, new THREE.PointsMaterial({ size: 1.6, color: 0xffffff, fog: false, transparent: true, opacity: 0.8 })));
  }
}
function ground(c1, c2, R, stone, rep = 14) {
  const t = groundTex(c1, c2, stone); t.repeat.set(rep, rep);
  const g = new THREE.Mesh(new THREE.CircleGeometry(R, 64), new THREE.MeshLambertMaterial({ map: t }));
  g.rotation.x = -Math.PI / 2; g.receiveShadow = true; E.world.add(g);
  const out = new THREE.Mesh(new THREE.RingGeometry(R - 0.5, R + 160, 64), new THREE.MeshLambertMaterial({ color: new THREE.Color(c2).multiplyScalar(0.6) }));
  out.rotation.x = -Math.PI / 2; out.position.y = -0.02; E.world.add(out);
}
function ambientMotes(col, n, R, rise) {
  const p = new Float32Array(n * 3), sp = []; for (let i = 0; i < n; i++) { p[i * 3] = rnd(-R, R); p[i * 3 + 1] = rnd(0.3, 7); p[i * 3 + 2] = rnd(-R, R); sp.push(rnd(0.2, 0.8)); }
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.BufferAttribute(p, 3));
  const pts = new THREE.Points(g, new THREE.PointsMaterial({ map: E.glowTex, size: 0.45, color: col, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending }));
  E.world.add(pts);
  E.anim.push(dt => { const a = g.attributes.position.array; for (let i = 0; i < n; i++) { a[i * 3 + 1] += dt * sp[i] * (rise ? 1 : Math.sin(E.t + i) * 0.6); a[i * 3] += Math.sin(E.t * 0.7 + i) * dt * 0.3; if (a[i * 3 + 1] > 9) a[i * 3 + 1] = 0.2; } g.attributes.position.needsUpdate = true; });
}
function pointLight(x, y, z, col, I, d) { const l = new THREE.PointLight(col, I, d, 1.6); l.position.set(x, y, z); E.world.add(l); E.lights.push(l); return l; }
export function portalMesh(col = 0x8b5cf6, s = 1) {
  const g = new THREE.Group();
  const disc = new THREE.Mesh(new THREE.CircleGeometry(1.6, 40), new THREE.MeshBasicMaterial({ map: E.swirlTex, color: col, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
  disc.position.y = 2; g.add(disc);
  const ring = new THREE.Mesh(new THREE.TorusGeometry(1.7, 0.14, 10, 48), new THREE.MeshBasicMaterial({ color: col }));
  ring.position.y = 2; g.add(ring);
  const base = new THREE.Mesh(new THREE.CircleGeometry(2.4, 32), new THREE.MeshBasicMaterial({ map: E.glowTex, color: col, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
  base.rotation.x = -Math.PI / 2; base.position.y = 0.05; g.add(base);
  g.scale.setScalar(s); g.userData.disc = disc;
  E.anim.push(dt => { disc.rotation.z -= dt * 1.8; disc.lookAt(E.cam.position.x, disc.getWorldPosition(new THREE.Vector3()).y, E.cam.position.z); ring.quaternion.copy(disc.quaternion); });
  return g;
}

/* ---------- mondes : grille de routes, quartiers, camps fixes ---------- */
const C4 = [-72, -24, 24, 72], LN = [-48, 0, 48];
const MAPS = { city: ['LTTB', 'HccH', 'cPxc', 'kHHk'], forest: ['LTHB', 'cHck', 'HcPx', 'kcHc'], necro: ['LHTB', 'kcHc', 'xPcH', 'cHkc'], abyss: ['LTTB', 'kcHc', 'HxPc', 'cHck'] };
function slab(x, z, col, h = 0.3, s = 35) { const m = new THREE.Mesh(new THREE.BoxGeometry(s, h, s), new THREE.MeshLambertMaterial({ color: col })); m.position.set(x, h / 2, z); m.receiveShadow = true; E.world.add(m); return m; }
function strip(x, z, w, l, col, y = 0.03, glow = false) { const m = new THREE.Mesh(new THREE.PlaneGeometry(w, l), glow ? new THREE.MeshBasicMaterial({ color: col }) : new THREE.MeshLambertMaterial({ color: col })); m.rotation.x = -Math.PI / 2; m.position.set(x, y, z); m.receiveShadow = true; E.world.add(m); return m; }
function disc(x, z, r, col, y = 0.05, glow = false) { const m = new THREE.Mesh(new THREE.CircleGeometry(r, 40), glow ? new THREE.MeshBasicMaterial({ color: col, transparent: true, opacity: 0.85 }) : new THREE.MeshLambertMaterial({ color: col })); m.rotation.x = -Math.PI / 2; m.position.set(x, y, z); m.receiveShadow = true; E.world.add(m); return m; }
function glowRing(x, z, r, col, y = 0.09, w = 0.5) { const m = new THREE.Mesh(new THREE.RingGeometry(r - w, r, 56), new THREE.MeshBasicMaterial({ color: col, transparent: true, opacity: 0.7, blending: THREE.AdditiveBlending, depthWrite: false })); m.rotation.x = -Math.PI / 2; m.position.set(x, y, z); E.world.add(m); E.anim.push(() => { m.material.opacity = 0.45 + Math.sin(E.t * 2 + x) * 0.25; }); return m; }
function ring(keys, x, z, r, n, s, col = 0, a0 = 0, y = 0) { for (let i = 0; i < n; i++) { const a = a0 + i / n * 6.283; place(Array.isArray(keys) ? pick(keys) : keys, x + Math.cos(a) * r, z + Math.sin(a) * r, -a + Math.PI / 2, typeof s === 'number' ? s : rnd(s[0], s[1]), y, col); } }
const box = (x, z, hw, hd, h) => E.boxes.push({ x, z, hw, hd, h });
const offPath = (x, z) => LN.every(l => Math.abs(x - l) > 5.5 && Math.abs(z - l) > 5.5);
function crystal(x, y, z, s, col, em) { const c = new THREE.Mesh(new THREE.OctahedronGeometry(s, 0), new THREE.MeshLambertMaterial({ color: col, emissive: em, emissiveIntensity: 1.1 })); c.position.set(x, y, z); c.scale.y = 1.7; c.rotation.y = rnd(0, 3); E.world.add(c); return c; }
function perimeter(n, d0, d1, fn) { for (let i = 0; i < n; i++) { const side = i % 4, t = rnd(-125, 125), d = rnd(d0, d1); const x = side === 0 ? t : side === 1 ? d : side === 2 ? t : -d, z = side === 0 ? -d : side === 1 ? t : side === 2 ? d : t; fn(x, z, i); } }

const LOW = ['k:building-a', 'k:building-b', 'k:building-c', 'k:building-d', 'k:building-f', 'k:building-g', 'k:building-h'];
const TALL = ['k:building-skyscraper-a', 'k:building-skyscraper-b', 'k:building-skyscraper-c', 'k:building-skyscraper-d', 'k:building-skyscraper-e'];
function siteCity(ch, x, z, alt) {
  if (ch === 'H' || ch === 'T') {
    slab(x, z, 0xb4bcd6, 0.3); const sc = ch === 'T' ? 12.5 : 15.5;
    for (const [ox, oz] of [[-8.6, -8.6], [8.6, -8.6], [-8.6, 8.6], [8.6, 8.6]]) place(pick(ch === 'T' ? TALL : LOW), x + ox, z + oz, pick([0, 1, 2, 3]) * Math.PI / 2, sc * rnd(0.95, 1.04), 0.3);
    box(x, z, 17.5, 17.5, ch === 'T' ? 60 : 22); return;
  }
  if (ch === 'c' && alt) { slab(x, z, 0x62a651, 0.26); for (const [ox, oz] of [[-13, -13], [13, -13], [-13, 13], [13, 13]]) { place('n:CommonTree_5', x + ox, z + oz, rnd(0, 6), 1.9, 0.26, 0.8); place('n:Bush_Common_Flowers', x + ox * 0.55, z + oz * 1.05, 0, 1.3, 0.26); } }
  else if (ch === 'c') { slab(x, z, 0x4d5386, 0.26); for (let k = -1; k <= 1; k++) { strip(x + k * 9, z, 0.5, 30, 0xe8ecff, 0.28); } place('r:dumpster', x - 15, z - 14, 0.3, 9, 0.26); place('r:dumpster', x + 15, z + 14, 2, 9, 0.26); ring('r:construction-cone', x, z, 15.5, 8, 9, 0, 0.4, 0.26); }
  else if (ch === 'k') { slab(x, z, 0x3a2d55, 0.26); glowRing(x, z, 12, 0xff7a45, 0.3); ring('r:construction-cone', x, z, 13.5, 12, 10, 0, 0, 0.26); place('r:dumpster', x - 14, z - 14, 0.8, 10, 0.26); }
  else if (ch === 'P') {
    slab(x, z, 0x62a651, 0.26); const b = new THREE.Mesh(new THREE.CylinderGeometry(4.6, 5, 0.9, 24), new THREE.MeshLambertMaterial({ color: 0xc9d0ea })); b.position.set(x, 0.7, z); E.world.add(b);
    disc(x, z, 4, 0x4ab8ff, 1.17, true); const p = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.8, 3, 10), b.material); p.position.set(x, 2.2, z); E.world.add(p); E.colliders.push({ x, z, r: 5.2 });
    for (const [ox, oz] of [[-13, -13], [13, -13], [-13, 13], [13, 13]]) { place('n:CommonTree_3', x + ox, z + oz, rnd(0, 6), 1.8, 0.26, 0.8); place('k:detail-parasol-a', x + ox * 0.6, z + oz * 0.6, 0, 9, 0.26); }
    ring('n:Bush_Common_Flowers', x, z, 8.5, 6, 1.2, 0, 0.5, 0.26);
  } else if (ch === 'x') { slab(x, z, 0x8088b8, 0.26); glowRing(x, z, 5, 0xffcc33, 0.3); ring('k:detail-parasol-a', x, z, 13, 4, 9, 0, 0.78, 0.26); ring('n:Bush_Common_Flowers', x, z, 15, 8, 1.3, 0, 0, 0.26); }
  else if (ch === 'B') { slab(x, z, 0x2a2d55, 0.26); glowRing(x, z, 14, 0xff3355, 0.3, 0.7); glowRing(x, z, 8, 0xff3355, 0.3, 0.3); ring('r:light-square', x, z, 16.5, 4, 10, 0, 0.78, 0.26); }
  else if (ch === 'L') { slab(x, z, 0x1e1b3a, 0.26); glowRing(x, z, 13, 0xffcc33, 0.3, 0.7); ring('r:construction-cone', x, z, 15, 10, 11, 0, 0, 0.26); ring('r:dumpster', x, z, 16, 3, 10, 0, 1, 0.26); }
}
const FTREE = ['n:CommonTree_3', 'n:CommonTree_5', 'n:CommonTree_5', 'n:Pine_1'], ROCKS = ['n:Rock_Medium_1', 'n:Rock_Medium_2', 'n:Rock_Medium_3'];
function siteForest(ch, x, z) {
  if (ch === 'H') { for (let i = 0; i < 7; i++) { const a = i / 7 * 6.28 + rnd(0, 0.5), r = i ? rnd(5, 9.5) : 0; place(pick(FTREE), x + Math.cos(a) * r, z + Math.sin(a) * r, rnd(0, 6), rnd(2.6, 3.4)); } ring('n:Bush_Common', x, z, 11.5, 9, [1.2, 1.7]); E.colliders.push({ x, z, r: 12.5 }); }
  else if (ch === 'T') { for (let i = 0; i < 6; i++) { const a = rnd(0, 6.28), r = rnd(0, 6); place(pick(ROCKS), x + Math.cos(a) * r, z + Math.sin(a) * r, rnd(0, 6), rnd(3.5, 5.5)); } ring('n:Pine_1', x, z, 10, 5, [2.2, 2.8]); E.colliders.push({ x, z, r: 12 }); }
  else if (ch === 'P') { disc(x, z, 11.5, 0xc9b27a, 0.04); disc(x, z, 10, 0x3aa0e8, 0.07, true); ring(['n:Flower_3_Group', 'n:Fern_1'], x, z, 11.5, 16, [1.2, 1.8]); ring(ROCKS, x, z, 10.3, 5, [0.8, 1.3], 0, 0.3); E.colliders.push({ x, z, r: 9.6 }); }
  else if (ch === 'x') { disc(x, z, 9, 0x9a9a8a, 0.05); ring(['d:pillar', 'd:column', 'd:rubble_large'], x, z, 8, 7, 1.5, 0.6); }
  else if (ch === 'B') { disc(x, z, 15, 0x8f8f80, 0.05); glowRing(x, z, 14, 0xff3355); ring('d:pillar_decorated', x, z, 15, 8, 1.7, 0.7); }
  else if (ch === 'L') { disc(x, z, 14, 0x3a4a2a, 0.05); glowRing(x, z, 13, 0xffcc33); ring(['h:tree_dead_large', 'h:tree_dead_medium'], x, z, 15, 7, [1.8, 2.4], 0.6); ring(['h:bone_A', 'h:ribcage'], x, z, 10, 6, 1.6, 0, 0.4); }
  else if (ch === 'k') { disc(x, z, 13, 0xa8824e, 0.05); glowRing(x, z, 12, 0xff7a45); ring('x:flag_red', x, z, 13, 4, 2.2, 0, 0.78); place('x:tent', x, z - 13, 0, 3, 0, 1.5); place('x:crate_A_big', x + 11, z - 9, 0.4, 2, 0, 0.8); }
  else { disc(x, z, 12.5, 0x86c653, 0.05); ring(ROCKS, x, z, 13, 5, [0.7, 1.1], 0, rnd(0, 3)); ring(['n:Flower_3_Group', 'n:Flower_4_Group'], x, z, 11, 7, 1.4, 0, 1); }
}
const GRAVES = ['h:grave_A', 'h:grave_B', 'h:gravestone'];
function siteNecro(ch, x, z) {
  if (ch === 'H') { slab(x, z, 0x4a4470, 0.12, 31); for (const [ox, oz] of [[-7.5, -7.5], [7.5, -7.5], [-7.5, 7.5], [7.5, 7.5]]) place('h:crypt', x + ox, z + oz, oz > 0 ? 0 : Math.PI, 1.55); ring('h:post_lantern', x, z, 21.5, 4, 1.4, 0, 0.785); box(x, z, 15.5, 15.5, 9); }
  else if (ch === 'T') { for (let i = 0; i < 11; i++) { const a = rnd(0, 6.28), r = rnd(0, 10); place(pick(['h:tree_dead_large', 'h:tree_dead_medium']), x + Math.cos(a) * r, z + Math.sin(a) * r, rnd(0, 6), rnd(1.8, 2.6)); } ring(GRAVES, x, z, 11.5, 8, 1.3); E.colliders.push({ x, z, r: 12.5 }); }
  else if (ch === 'P') { disc(x, z, 12, 0x6f6a94, 0.05); place('h:shrine_candles', x, z, 0, 2.6, 0, 2.2); ring('h:skull_candle', x, z, 6, 8, 1.5); ring('h:pumpkin_orange', x, z, 11, 6, 1.6, 0, 0.3); glowRing(x, z, 9, 0xc26bff); }
  else if (ch === 'x') { disc(x, z, 9, 0x6f6a94, 0.05); ring('h:skull_candle', x, z, 5, 6, 1.5); ring(GRAVES, x, z, 9.5, 8, 1.4, 0.5); }
  else if (ch === 'B') { disc(x, z, 15, 0x3a3560, 0.05); glowRing(x, z, 14, 0xff3355); ring('d:pillar_decorated', x, z, 15, 8, 1.7, 0.7); ring('h:lantern_standing', x, z, 12, 4, 1.3, 0, 0.78); }
  else if (ch === 'L') { disc(x, z, 14, 0x241a3a, 0.05); glowRing(x, z, 13, 0xffcc33); ring('h:ribcage', x, z, 13.5, 5, 3.2, 0.8); ring('h:bone_A', x, z, 9, 8, 2); }
  else if (ch === 'k') { disc(x, z, 13, 0x4a4470, 0.05); glowRing(x, z, 12, 0xff7a45); place('h:crypt', x, z - 14, 0, 1.6, 0, 3.5); ring('h:skull_candle', x, z, 12.5, 6, 1.5, 0, 0.5); }
  else { disc(x, z, 13, 0x565080, 0.05); ring(GRAVES, x, z, 11.5, 10, [1.2, 1.5], 0, rnd(0, 3)); ring(['h:bone_A', 'h:pumpkin_orange'], x, z, 13.5, 5, 1.5, 0, 1); }
}
function siteAbyss(ch, x, z) {
  if (ch === 'H') { slab(x, z, 0x2a1830, 0.15, 28); place('x:building_tower_A_blue', x - 6, z - 5, 0.4, 5.2); place('x:building_tower_B_blue', x + 6, z + 5, 2, 5.2); ring(['d:rubble_large', 'd:rubble_half'], x, z, 11, 7, 1.8); box(x, z, 14, 14, 24); }
  else if (ch === 'T') { slab(x, z, 0x2a1830, 0.15, 31); place('x:building_castle_blue', x, z, pick([0, 1, 2, 3]) * 1.5708, 6.5); ring('d:banner_patternA_red', x, z, 15, 4, 2.2, 0, 0.78); box(x, z, 15.5, 15.5, 30); }
  else if (ch === 'P') { disc(x, z, 12, 0x40203a, 0.05); glowRing(x, z, 11, 0xc26bff); for (let i = 0; i < 7; i++) { const a = i / 7 * 6.28, r = i ? rnd(4, 9) : 0; const c = crystal(x + Math.cos(a) * r, rnd(0.6, 1.6), z + Math.sin(a) * r, i ? rnd(0.8, 1.6) : 2.4, 0xd8a0ff, 0x9b5cff); E.colliders.push({ x: c.position.x, z: c.position.z, r: 1.2 }); } }
  else if (ch === 'x') { disc(x, z, 9, 0x40203a, 0.05); ring('d:pillar', x, z, 8, 6, 1.6, 0.6); ring('d:sword_shield_gold', x, z, 5.5, 4, 1.8, 0, 0.78); }
  else if (ch === 'B') { disc(x, z, 15, 0x1a0a1e, 0.05); glowRing(x, z, 14, 0xff3355, 0.09, 0.8); glowRing(x, z, 7, 0xff3355, 0.09, 0.3); ring('d:pillar_decorated', x, z, 15.5, 10, 1.9, 0.7); }
  else if (ch === 'L') { disc(x, z, 14, 0x1a0a1e, 0.05); glowRing(x, z, 13, 0xffcc33); for (let i = 0; i < 6; i++) { const a = i / 6 * 6.28; crystal(x + Math.cos(a) * 14.5, 1.6, z + Math.sin(a) * 14.5, 1.7, 0xffb0c8, 0xff3b5c); } }
  else if (ch === 'k') { disc(x, z, 13, 0x40203a, 0.05); glowRing(x, z, 12, 0xff7a45); ring('d:banner_patternA_red', x, z, 13, 4, 2.4, 0, 0.78); ring('d:pillar', x, z, 13.5, 4, 1.6, 0.6); }
  else { disc(x, z, 13, 0x4a2a44, 0.05); ring(['d:rubble_large', 'd:rubble_half', 'd:column'], x, z, 13, 7, [1.4, 1.9], 0, rnd(0, 3)); ring('d:candle_triple', x, z, 11, 4, 1.6, 0, 0.5); }
}

/* la Tour de l'Ascension, au centre du Sanctuaire */
function towerMesh() {
  const g = new THREE.Group(); const stone = new THREE.MeshLambertMaterial({ color: 0x4a3f8a }), dark = new THREE.MeshLambertMaterial({ color: 0x2a2358 }), win = new THREE.MeshBasicMaterial({ color: 0xffe9a0 });
  const segs = [[9, 8, 9], [6.8, 6, 15], [5.4, 4.6, 15], [4, 3, 13], [2.6, 1.4, 9]]; let y = 0; const rings = [];
  segs.forEach(([r0, r1, h], i) => {
    const m = new THREE.Mesh(new THREE.CylinderGeometry(r1, r0, h, 12), i % 2 ? dark : stone); m.position.y = y + h / 2; m.castShadow = true; g.add(m);
    if (i < 4) for (let k = 0; k < 12; k++) for (let row = 0; row < (i ? 3 : 1); row++) { if ((k + row) % 2) continue; const a = k / 12 * 6.283, rr = r0 - (r0 - r1) * ((row + 1) / 4) + 0.02, wy = y + h * (row + 1) / 4 + 1; const w = new THREE.Mesh(new THREE.BoxGeometry(0.7, 1.5, 0.15), win); w.position.set(Math.sin(a) * rr, wy, Math.cos(a) * rr); w.rotation.y = a; g.add(w); }
    y += h;
    const t = new THREE.Mesh(new THREE.TorusGeometry(r1 + 0.9, 0.28, 8, 40), new THREE.MeshBasicMaterial({ color: i % 2 ? 0x38bdf8 : 0xc26bff })); t.rotation.x = Math.PI / 2; t.position.y = y; g.add(t); rings.push(t);
    const cap = new THREE.Mesh(new THREE.CylinderGeometry(r1 + 0.7, r1 + 0.3, 0.8, 12), dark); cap.position.y = y; g.add(cap);
  });
  const door = new THREE.Mesh(new THREE.BoxGeometry(3.4, 5.5, 0.6), new THREE.MeshBasicMaterial({ color: 0xc26bff })); door.position.set(0, 2.75, 8.5); g.add(door);
  const cr = new THREE.Mesh(new THREE.OctahedronGeometry(3, 0), new THREE.MeshBasicMaterial({ color: 0xf5d0fe })); cr.position.y = y + 5; cr.scale.y = 1.6; g.add(cr);
  const halo = new THREE.Sprite(new THREE.SpriteMaterial({ map: E.glowTex, color: 0xc26bff, blending: THREE.AdditiveBlending, depthWrite: false })); halo.scale.setScalar(26); halo.position.y = y + 5; g.add(halo);
  const beam = new THREE.Mesh(new THREE.CylinderGeometry(0.7, 0.7, 160, 12, 1, true), new THREE.MeshBasicMaterial({ color: 0xc26bff, transparent: true, opacity: 0.3, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide })); beam.position.y = y + 85; g.add(beam);
  const orb = []; for (let i = 0; i < 3; i++) { const t = new THREE.Mesh(new THREE.TorusGeometry(11 + i * 2.5, 0.16, 6, 64), new THREE.MeshBasicMaterial({ color: [0xc26bff, 0x38bdf8, 0xffcc33][i], transparent: true, opacity: 0.8 })); t.position.y = 20 + i * 14; g.add(t); orb.push(t); }
  E.anim.push(dt => { cr.rotation.y += dt; cr.position.y = y + 5 + Math.sin(E.t * 1.5) * 0.6; halo.material.opacity = 0.7 + Math.sin(E.t * 2) * 0.2; orb.forEach((t, i) => { t.rotation.x = Math.PI / 2 + Math.sin(E.t * 0.5 + i * 2) * 0.35; t.rotation.z += dt * (0.3 + i * 0.15); }); beam.material.opacity = 0.22 + Math.sin(E.t * 3) * 0.08; });
  return g;
}
function buildHub(info, npcs) {
  const sc = E.scene; sc.fog = new THREE.Fog(0xa8dcff, 90, 260); sky('#2f8fff', '#d8f2ff', false);
  E.hemi.color.set(0xffffff); E.hemi.groundColor.set(0x6a6aa0); E.hemi.intensity = 1.4; E.sun.color.set(0xfff2d8); E.sun.intensity = 2.7;
  const sea = new THREE.Mesh(new THREE.CircleGeometry(400, 48), new THREE.MeshBasicMaterial({ color: 0x2f9fe8 })); sea.rotation.x = -Math.PI / 2; sea.position.y = -0.6; E.world.add(sea);
  const sand = new THREE.Mesh(new THREE.CylinderGeometry(62, 66, 0.7, 64), new THREE.MeshLambertMaterial({ color: 0xe8d8a0 })); sand.position.y = -0.4; E.world.add(sand);
  const t = groundTex('#6fb84a', '#5aa03c', false); t.repeat.set(14, 14); const gr = new THREE.Mesh(new THREE.CircleGeometry(58, 64), new THREE.MeshLambertMaterial({ map: t })); gr.rotation.x = -Math.PI / 2; gr.receiveShadow = true; E.world.add(gr);
  const pt = groundTex('#b9b4d8', '#a29cc8', true); pt.repeat.set(9, 9); const pl = new THREE.Mesh(new THREE.CircleGeometry(33, 64), new THREE.MeshLambertMaterial({ map: pt })); pl.rotation.x = -Math.PI / 2; pl.position.y = 0.03; pl.receiveShadow = true; E.world.add(pl);
  glowRing(0, 0, 13, 0xc26bff, 0.08, 0.6); glowRing(0, 0, 32.5, 0x38bdf8, 0.08, 0.4);
  E.world.add(towerMesh()); E.colliders.push({ x: 0, z: 0, r: 10 });
  const B = ['x:building_blacksmith_blue', 'x:building_church_blue', 'x:building_barracks_blue', 'x:building_tower_A_blue', 'x:building_tavern_blue', 'x:building_market_blue'];
  npcs.forEach((n, i) => { const x = Math.cos(n.a) * 24, z = Math.sin(n.a) * 24; info.npcs.push({ ...n, x, z }); place(B[i % B.length], Math.cos(n.a) * 43, Math.sin(n.a) * 43, -n.a - Math.PI / 2, 5.6, 0, 0.75); strip(Math.cos(n.a) * 33.5, Math.sin(n.a) * 33.5, 4, 14, 0xb9b4d8, 0.035).rotation.z = -n.a + Math.PI / 2; glowRing(x, z, 2.6, 0xffcc33, 0.09, 0.25); place('h:lantern_standing', x + Math.cos(n.a + 1.57) * 3, z + Math.sin(n.a + 1.57) * 3, 0, 1.3); });
  for (let i = 0; i < 6; i++) { const a = npcs[i].a + 0.52; place(pick(['x:building_home_A_blue', 'x:building_home_B_red', 'x:building_home_A_yellow']), Math.cos(a) * 46, Math.sin(a) * 46, -a - Math.PI / 2, 4.6, 0, 0.75); }
  for (let i = 0; i < 20; i++) { const a = i / 20 * 6.283; if (Math.abs(a - Math.PI / 2) < 0.75) continue; place(pick(['n:CommonTree_3', 'n:CommonTree_5']), Math.cos(a) * 53, Math.sin(a) * 53, rnd(0, 6), rnd(2.2, 3), 0, 0.5); } ring('x:flag_red', 0, 0, 33, 12, 2.4, 0, 0.26); ring(['n:Flower_3_Group', 'n:Fern_1', 'n:Flower_3_Group'], 0, 0, 36.5, 30, [1.3, 1.8]);
  pointLight(0, 8, 14, 0xc26bff, 40, 40); ambientMotes(0xe9d5ff, 120, 40, true);
  info.R = 55; info.spawn.set(0, 0, 30);
}

export function buildWorld(env, opt = {}) {
  clearWorld(); const info = { spawn: new THREE.Vector3(0, 0, 0), R: 91, spots: [], npcs: [], sites: { camps: [], chests: [], nodes: [], boss: null, lair: null } };
  const sc = E.scene; E.sq = false; E.world.position.y = 0;
  if (env === 'hub') { buildHub(info, opt.npcs); flush(E.world); return info; }
  if (env === 'dungeon') {
    const tint = opt.tint || 0x6d4cff; const R = 26; info.R = R - 2; info.spawn.set(0, 0, R - 8);
    sc.fog = new THREE.Fog(0x0b0820, 22, 80); sky('#05040d', '#1a1033', false);
    E.hemi.color.set(0xb0a4ff); E.hemi.groundColor.set(0x1a1028); E.hemi.intensity = 1.05; E.sun.color.set(0xc0b0ff); E.sun.intensity = 1.5;
    ground('#4a4566', '#38344f', R + 3, true, R / 2.2);
    const n = Math.floor(R * 0.8);
    for (let i = 0; i < n; i++) { const a = i / n * 6.28; place(pick(['d:wall', 'd:wall_cracked', 'd:wall', 'd:wall_broken']), Math.cos(a) * (R + 1.2), Math.sin(a) * (R + 1.2), -a - Math.PI / 2, 1.6); }
    for (let i = 0; i < 10; i++) { const a = i / 10 * 6.28; const x = Math.cos(a) * (R - 3), z = Math.sin(a) * (R - 3); place('d:pillar_decorated', x, z, 0, 1.7, 0, 0.9); place('d:torch_mounted', Math.cos(a) * (R + 0.4), Math.sin(a) * (R + 0.4), -a - Math.PI / 2, 1.6, 2.4); if (i % 2 === 0) pointLight(x, 3.5, z, i % 4 ? 0xff9a40 : tint, 18, 16); }
    for (let i = 0; i < 14; i++) { const a = rnd(0, 6.28), r = rnd(R - 6, R - 2.5); place(pick(['d:barrel_large', 'd:rubble_half', 'd:candle_triple', 'd:banner_patternB_blue', 'd:coin_stack_large', 'd:chest_gold']), Math.cos(a) * r, Math.sin(a) * r, rnd(0, 6), 1.5); }
    glowRing(0, 0, 5.6, tint, 0.06, 0.6); glowRing(0, 0, 9.3, tint, 0.06, 0.3);
    pointLight(0, 6, 0, tint, 30, 30); ambientMotes(tint, 90, R, true);
    flush(E.world); return info;
  }
  E.sq = true; const map = MAPS[env], S = info.sites;
  for (const a of LN) for (const b of LN) if (a || b) S.nodes.push({ x: a, z: b });
  const site = { city: siteCity, forest: siteForest, necro: siteNecro, abyss: siteAbyss }[env];
  for (let j = 0; j < 4; j++) for (let i = 0; i < 4; i++) {
    const ch = map[j][i], x = C4[i], z = C4[j];
    if (ch === 'c' || ch === 'k') S.camps.push({ x, z, k: ch === 'k' ? 1 : 0 }); else if (ch === 'B') S.boss = { x, z }; else if (ch === 'L') S.lair = { x, z };
    else if (ch === 'x') S.chests.push({ x, z }); else if (ch === 'P') S.chests.push({ x: x + 13.5, z: z + 13.5 });
    site(ch, x, z, (i + j) % 2);
  }
  if (env === 'city') {
    sc.fog = new THREE.Fog(0x9fd8ff, 90, 260); sky('#3aa0ff', '#d6f0ff', false);
    E.hemi.color.set(0xdbe8ff); E.hemi.groundColor.set(0x4a4a7a); E.hemi.intensity = 1.35; E.sun.color.set(0xfff4e0); E.sun.intensity = 2.6;
    ground('#3d3f78', '#2f3166', 200, true, 40); E.world.position.y = -0.27;
    const L5 = [-96, -48, 0, 48, 96];
    for (const l of L5) for (let k = -96; k <= 96; k += 12) { if (L5.includes(k)) continue; place('r:road-straight', k, l, Math.PI / 2, 12, 0.03); place('r:road-straight', l, k, 0, 12, 0.03); }
    for (const a of L5) for (const b of L5) place('r:road-crossroad', a, b, 0, 12, 0.035);
    for (const x of C4) for (const z of C4) { place('r:light-square', x, z + 18.7, 0, 9, 0.26); place('r:light-square', x, z - 18.7, Math.PI, 9, 0.26); place('r:light-square', x + 18.7, z, Math.PI / 2, 9, 0.26); place('r:light-square', x - 18.7, z, -Math.PI / 2, 9, 0.26); }
    for (const a of LN) for (const b of LN) place('r:traffic-light', a + 7, b + 7, Math.atan2(1, 1), 9, 0.26);
    for (let k = -120; k <= 120; k += 17) for (const d of [-119, 119]) { place(pick(TALL), k, d + rnd(-3, 3), rnd(0, 6), rnd(13, 18)); place(pick(TALL), d + rnd(-3, 3), k, rnd(0, 6), rnd(13, 18)); if (Math.abs(k) < 110) { place(pick(TALL), k + 8, d * 1.22, 0, rnd(17, 22)); place(pick(TALL), d * 1.22, k + 8, 0, rnd(17, 22)); } }
    glowRing(0, 0, 5, 0x38bdf8, 0.32); ambientMotes(0x9fe8ff, 90, 70, true);
  } else {
    const P = { forest: { fog: [0xbfe8a8, 60, 210], sky: ['#58b8ff', '#e8ffd0', false], hemi: [0xfff6d8, 0x3e6a2a, 1.3], sun: [0xfff0c0, 2.8], g: ['#5fa83a', '#4a8a2c', false], path: 0xb89460 },
      necro: { fog: [0x6a5a9a, 45, 170], sky: ['#2a1a5a', '#a88aff', true], hemi: [0xd0c0ff, 0x2a2040, 1.15], sun: [0xc8b8ff, 1.9], g: ['#5a5480', '#47426a', true], path: 0x7a75a2 },
      abyss: { fog: [0x2a0a2a, 40, 160], sky: ['#0a0418', '#6a1040', true], hemi: [0xffa0c8, 0x200818, 1.0], sun: [0xff9ab8, 1.7], g: ['#3a2840', '#2a1a30', true], path: 0x4a2c58 } }[env];
    sc.fog = new THREE.Fog(...P.fog); sky(...P.sky); E.hemi.color.set(P.hemi[0]); E.hemi.groundColor.set(P.hemi[1]); E.hemi.intensity = P.hemi[2]; E.sun.color.set(P.sun[0]); E.sun.intensity = P.sun[1];
    ground(P.g[0], P.g[1], 200, P.g[2], 44);
    for (const l of LN) { strip(l, 0, 8, 196, P.path, 0.03); strip(0, l, 196, 8, P.path, 0.034); }
    glowRing(0, 0, 4.5, 0x38bdf8);
    if (env === 'forest') {
      for (let i = 0; i < 300; i++) { const x = rnd(-95, 95), z = rnd(-95, 95); if (offPath(x, z)) place(pick(['n:Grass_Common_Tall', 'n:Flower_3_Group', 'n:Fern_1', 'n:Grass_Common_Tall', 'n:Fern_1']), x, z, rnd(0, 6), rnd(0.8, 1.3)); }
      for (const l of LN) for (let k = -84; k <= 84; k += 24) { place(pick(ROCKS), l + 5.5, k + 12, rnd(0, 6), 0.7); place('n:Bush_Common_Flowers', k + 12, l - 5.5, 0, 1.2); }
      perimeter(72, 99, 122, (x, z) => place(pick(FTREE), x, z, rnd(0, 6), rnd(4, 5.5))); ambientMotes(0xfff2a0, 140, 70, false);
    } else if (env === 'necro') {
      for (const l of LN) for (let k = -84; k <= 84; k += 24) { place('h:post_lantern', l + 5.2, k + 12, Math.PI / 2, 1.4); place('h:post_lantern', k + 12, l - 5.2, 0, 1.4); }
      for (let i = 0; i < 160; i++) { const x = rnd(-95, 95), z = rnd(-95, 95); if (offPath(x, z)) place(pick(['h:bone_A', 'h:gravestone', 'h:grave_A', 'h:pumpkin_orange']), x, z, rnd(0, 6), rnd(1, 1.4)); }
      for (const [x, z] of [[0, 0], [48, 0], [-48, 0], [0, 48], [0, -48]]) pointLight(x + 5, 4, z + 5, 0xc26bff, 22, 30);
      perimeter(200, 97, 128, (x, z) => place(pick(['h:tree_dead_large', 'h:tree_dead_medium']), x, z, rnd(0, 6), rnd(2, 3.2))); ambientMotes(0xd8b4fe, 170, 70, true);
    } else {
      for (const l of LN) for (const o of [-3.7, 3.7]) { strip(l + o, 0, 0.3, 196, 0xff3b5c, 0.04, true); strip(0, l + o, 196, 0.3, 0xff3b5c, 0.044, true); }
      for (let i = 0; i < 90; i++) { const x = rnd(-95, 95), z = rnd(-95, 95); if (offPath(x, z)) place(pick(['d:rubble_large', 'd:rubble_half', 'd:column']), x, z, rnd(0, 6), rnd(1, 1.6)); }
      for (const [x, z] of [[0, 0], [48, 48], [-48, -48], [48, -48], [-48, 48]]) pointLight(x + 5, 4, z + 5, 0xff3b5c, 22, 30);
      perimeter(56, 104, 128, (x, z, i) => place(pick(['x:building_tower_A_blue', 'x:building_tower_B_blue', 'x:building_castle_blue']), x, z, rnd(0, 6), rnd(7, 10)));
      for (let i = 0; i < 14; i++) { const a = i / 14 * 6.28; const c = crystal(Math.cos(a) * 118, rnd(14, 30), Math.sin(a) * 118, rnd(2, 4), 0xff7aa8, 0xff3b5c); E.anim.push(dt => { c.rotation.y += dt * 0.5; }); }
      ambientMotes(0xff7aa8, 190, 70, true);
    }
  }
  flush(E.world);
  return info;
}
const polar = r => { const a = rnd(0, 6.28); return [Math.cos(a) * r, Math.sin(a) * r]; };

/* ---------- collisions ---------- */
export function collide(p, r = 0.5, R = 60) {
  for (const c of E.colliders) { const dx = p.x - c.x, dz = p.z - c.z, d = Math.hypot(dx, dz), m = c.r + r; if (d < m && d > 0.001) { p.x = c.x + dx / d * m; p.z = c.z + dz / d * m; } }
  for (const b of E.boxes || []) { const dx = p.x - b.x, dz = p.z - b.z, px = b.hw + r - Math.abs(dx), pz = b.hd + r - Math.abs(dz); if (px > 0 && pz > 0) { if (px < pz) p.x += Math.sign(dx || 1) * px; else p.z += Math.sign(dz || 1) * pz; } }
  if (E.sq) { p.x = Math.max(-R, Math.min(R, p.x)); p.z = Math.max(-R, Math.min(R, p.z)); return; }
  const d = Math.hypot(p.x, p.z); if (d > R) { p.x *= R / d; p.z *= R / d; }
}

/* ---------- particules ---------- */
class Particles {
  constructor(n) {
    this.n = n; this.i = 0; this.pos = new Float32Array(n * 3); this.col = new Float32Array(n * 3); this.size = new Float32Array(n);
    this.v = new Float32Array(n * 3); this.life = new Float32Array(n); this.max = new Float32Array(n); this.s0 = new Float32Array(n); this.grav = new Float32Array(n);
    const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.BufferAttribute(this.pos, 3)); g.setAttribute('color', new THREE.BufferAttribute(this.col, 3)); g.setAttribute('size', new THREE.BufferAttribute(this.size, 1));
    const m = new THREE.ShaderMaterial({ uniforms: { map: { value: E.glowTex }, sc: { value: 400 } }, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, vertexColors: true,
      vertexShader: 'attribute float size; varying vec3 vC; uniform float sc; void main(){ vC=color; vec4 mv=modelViewMatrix*vec4(position,1.); gl_PointSize=size*sc/-mv.z; gl_Position=projectionMatrix*mv; }',
      fragmentShader: 'uniform sampler2D map; varying vec3 vC; void main(){ vec4 t=texture2D(map,gl_PointCoord); gl_FragColor=vec4(vC*t.a*1.4,t.a); }' });
    this.points = new THREE.Points(g, m); this.points.frustumCulled = false;
  }
  emit(p, col, o = {}) {
    const i = this.i = (this.i + 1) % this.n; const c = new THREE.Color(col);
    this.pos[i * 3] = p.x + rnd(-1, 1) * (o.spread || 0); this.pos[i * 3 + 1] = p.y + rnd(-1, 1) * (o.spreadY || o.spread || 0); this.pos[i * 3 + 2] = p.z + rnd(-1, 1) * (o.spread || 0);
    const sp = o.speed ?? 4; this.v[i * 3] = rnd(-1, 1) * sp; this.v[i * 3 + 1] = (o.up ?? rnd(0.3, 1.2)) * sp; this.v[i * 3 + 2] = rnd(-1, 1) * sp;
    this.col[i * 3] = c.r; this.col[i * 3 + 1] = c.g; this.col[i * 3 + 2] = c.b;
    this.life[i] = this.max[i] = o.life || rnd(0.4, 0.9); this.s0[i] = o.size || rnd(0.4, 0.9); this.grav[i] = o.grav ?? 6;
  }
  update(dt) {
    for (let i = 0; i < this.n; i++) {
      if (this.life[i] <= 0) { this.size[i] = 0; continue; }
      this.life[i] -= dt; const k = Math.max(0, this.life[i] / this.max[i]);
      this.v[i * 3 + 1] -= this.grav[i] * dt;
      for (let j = 0; j < 3; j++) this.pos[i * 3 + j] += this.v[i * 3 + j] * dt;
      this.size[i] = this.s0[i] * k;
    }
    const a = this.points.geometry.attributes; a.position.needsUpdate = a.size.needsUpdate = a.color.needsUpdate = true;
  }
}
export function burst(p, col, n = 14, o = {}) { for (let i = 0; i < n; i++) E.particles.emit(p, col, o); }

/* ---------- effets ---------- */
function fx(obj, life, upd) { E.scene.add(obj); E.fx.push({ obj, life, max: life, upd }); }
export function slash(p, ang, col = 0xc9b6ff, big = false) {
  const geo = new THREE.RingGeometry(big ? 1.6 : 1.1, big ? 2.6 : 1.9, 24, 1, -1.1, 2.2);
  const m = new THREE.Mesh(geo, new THREE.MeshBasicMaterial({ color: col, transparent: true, opacity: 0.9, blending: THREE.AdditiveBlending, side: THREE.DoubleSide, depthWrite: false }));
  m.rotation.set(-Math.PI / 2, 0, ang - Math.PI / 2); m.position.set(p.x, p.y + 1, p.z);
  fx(m, 0.22, (k) => { m.material.opacity = k; m.scale.setScalar(1 + (1 - k) * 0.6); });
}
export function shock(p, col, R = 4, life = 0.5) {
  const m = new THREE.Mesh(new THREE.RingGeometry(0.8, 1, 48), new THREE.MeshBasicMaterial({ color: col, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
  m.rotation.x = -Math.PI / 2; m.position.set(p.x, 0.1, p.z);
  fx(m, life, k => { m.scale.setScalar(1 + (1 - k) * R); m.material.opacity = k; });
}
export function pillar(p, col = 0x8b5cf6, h = 9) {
  const g = new THREE.CylinderGeometry(0.5, 1.1, h, 24, 1, true); g.translate(0, h / 2, 0);
  const m = new THREE.Mesh(g, new THREE.MeshBasicMaterial({ color: col, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
  m.position.copy(p);
  fx(m, 1.2, k => { m.material.opacity = Math.min(1, k * 2) * 0.32; m.scale.set(1 + (1 - k) * 0.6, Math.min(1, (1 - k) * 6), 1 + (1 - k) * 0.6); m.rotation.y += 0.1; });
  for (let i = 0; i < 26; i++) E.particles.emit({ x: p.x, y: p.y + rnd(0, 2), z: p.z }, i % 4 ? col : 0xffffff, { spread: 1.2, speed: 2.5, up: rnd(1, 3), grav: -2, life: rnd(0.8, 1.6), size: rnd(0.4, 1) });
  shock(p, col, 6, 0.8);
}
export function beam(a, b, col) {
  const g = new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(a.x, a.y + 1.2, a.z), new THREE.Vector3(b.x, b.y + 1, b.z)]);
  const l = new THREE.Line(g, new THREE.LineBasicMaterial({ color: col, transparent: true, blending: THREE.AdditiveBlending }));
  fx(l, 0.15, k => { l.material.opacity = k; });
}
export function projectile(a, b, col, dur = 0.35, onHit) {
  const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: E.glowTex, color: col, blending: THREE.AdditiveBlending, depthWrite: false })); s.scale.setScalar(1.1);
  const A = new THREE.Vector3(a.x, a.y + 1.4, a.z), B = new THREE.Vector3(b.x, b.y + 1, b.z);
  fx(s, dur, k => { s.position.lerpVectors(A, B, 1 - k); s.position.y += Math.sin((1 - k) * Math.PI) * 1.2; E.particles.emit(s.position, col, { speed: 0.4, life: 0.25, size: 0.5, grav: 0 }); });
  s.userData.onEnd = onHit;
}
export function updateFx(dt) {
  E.t += dt; for (const f of E.anim) f(dt);
  for (let i = E.fx.length - 1; i >= 0; i--) {
    const f = E.fx[i]; f.life -= dt; const k = Math.max(0, f.life / f.max); f.upd(k);
    if (f.life <= 0) { if (f.obj.userData.onEnd) f.obj.userData.onEnd(); f.obj.removeFromParent(); f.obj.geometry?.dispose(); E.fx.splice(i, 1); }
  }
  E.particles.update(dt);
}

/* ---------- caméra ---------- */
const tmpV = new THREE.Vector3();
export function camFollow(target, dt) {
  const off = tmpV.set(Math.sin(E.yaw) * Math.cos(E.pitch), Math.sin(E.pitch), Math.cos(E.yaw) * Math.cos(E.pitch)).multiplyScalar(E.dist);
  let k = 1; if (E.boxes && E.boxes.length) { for (let t = 0.3; t <= 1.001; t += 0.1) { const x = target.x + off.x * t, y = off.y * t, z = target.z + off.z * t; if (E.boxes.some(b => y < b.h && Math.abs(x - b.x) < b.hw + 1.2 && Math.abs(z - b.z) < b.hd + 1.2)) { k = Math.max(0.3, t - 0.1); break; } } }
  E.camK = (E.camK ?? 1) + (k - (E.camK ?? 1)) * Math.min(1, dt * 6); off.multiplyScalar(E.camK);
  const want = target.clone().add(off);
  E.cam.position.lerp(want, 1 - Math.exp(-dt * 8));
  if (E.shake > 0) { E.shake -= dt; E.cam.position.x += rnd(-1, 1) * E.shake * 0.6; E.cam.position.y += rnd(-1, 1) * E.shake * 0.6; }
  E.cam.lookAt(target.x, target.y + 1.4, target.z);
  E.sun.position.set(target.x + 18, 32, target.z + 10); E.sun.target.position.copy(target);
}
export function toScreen(p, out = {}) {
  tmpV.set(p.x, p.y, p.z).project(E.cam);
  out.x = (tmpV.x * 0.5 + 0.5) * innerWidth; out.y = (-tmpV.y * 0.5 + 0.5) * innerHeight; out.vis = tmpV.z < 1 && tmpV.x > -1.1 && tmpV.x < 1.1 && tmpV.y > -1.1 && tmpV.y < 1.1; return out;
}
export function render() { E.renderer.render(E.scene, E.cam); }
