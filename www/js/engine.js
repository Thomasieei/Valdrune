/* NOCTALIS — moteur 3D : chargement, personnages, décors, effets */
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import * as SkeletonUtils from 'three/addons/utils/SkeletonUtils.js';
import { rnd, pick, ZONES } from './core.js';

export const E = { THREE, gltf: {}, clips: [], colliders: [], fx: [], t: 0, yaw: 0.6, pitch: 0.95, dist: 17, shake: 0 };
const CHAR_FILES = ['Knight', 'Barbarian', 'Mage', 'Rogue_Hooded', 'Skeleton_Minion', 'Skeleton_Warrior', 'Skeleton_Mage', 'Skeleton_Rogue', 'wolf', 'fox', 'bull', 'stag'];
const ENV = {
  d: ['column', 'floor_tile_large', 'floor_tile_large_rocks', 'pillar', 'pillar_decorated', 'rubble_half', 'rubble_large', 'torch_mounted', 'wall', 'wall_broken', 'wall_cracked', 'chest_gold', 'banner_patternA_red', 'banner_patternB_blue', 'barrel_large', 'coin_stack_large', 'sword_shield_gold', 'candle_triple'],
  h: ['crypt', 'fence', 'grave_A', 'grave_B', 'gravestone', 'lantern_standing', 'post_lantern', 'pumpkin_orange', 'ribcage', 'shrine_candles', 'skull_candle', 'tree_dead_large', 'tree_dead_medium', 'bone_A'],
  x: ['building_castle_blue', 'building_tower_A_blue', 'building_tower_B_blue', 'building_market_blue', 'building_blacksmith_blue', 'building_church_blue', 'building_tavern_blue', 'building_well_blue', 'building_home_A_blue', 'building_home_B_red', 'building_home_A_yellow', 'building_barracks_blue', 'flag_red', 'tent', 'weaponrack', 'crate_A_big', 'barrel'],
  n: ['CommonTree_1', 'CommonTree_3', 'CommonTree_5', 'Pine_1', 'Pine_3', 'TwistedTree_1', 'TwistedTree_3', 'DeadTree_2', 'Bush_Common', 'Bush_Common_Flowers', 'Rock_Medium_1', 'Rock_Medium_2', 'Rock_Medium_3', 'Grass_Common_Tall', 'Flower_3_Group', 'Flower_4_Group', 'Mushroom_Common', 'Fern_1'],
  w: ['sword_E', 'sword_D', 'staff_A', 'axe_2handed', 'dagger_A'],
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
  jobs.push(['rig1', 'assets/c/Rig_Medium_General.glb'], ['rig2', 'assets/c/Rig_Medium_MovementBasic.glb']);
  for (const k in ENV) for (const n of ENV[k]) jobs.push([k + ':' + n, `assets/${k}/${n}.${k === 'c' ? 'glb' : 'gltf'}`]);
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
  idle: ['Idle', 'Idle_A', 'Unarmed_Idle'], run: ['Running_A', 'Gallop'], walk: ['Walking_A', 'Walk'],
  attack: ['Attack', 'Attack_Headbutt', 'Use_Item', 'Throw'], cast: ['Spellcasting', 'Throw', 'Attack'], hit: ['Hit_A', 'Idle_HitReact_Left'],
  death: ['Death', 'Death_A'], cheer: ['Cheer', 'Interact'],
};
const matCache = new Map();
export function makeChar(model, o = {}) {
  const g = E.gltf['c:' + model]; const root = new THREE.Group();
  const mdl = SkeletonUtils.clone(g.scene); root.add(mdl); mdl.scale.setScalar(o.scale || 1);
  const quad = !!g.animations.find(a => a.name === 'Gallop');
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
      const mat = n.material.isMeshLambertMaterial ? n.material : (n.userData.lam ||= new THREE.MeshLambertMaterial({ map: n.material.map, color: n.material.color, transparent: n.material.transparent, alphaTest: n.material.alphaTest || (n.material.map && /Grass|Flower|Fern|Bush|Leaves|Tree|Pine/.test(key) ? 0.4 : 0), side: n.material.side }));
      const im = new THREE.InstancedMesh(n.geometry, mat, mats.length);
      mats.forEach((m, i) => im.setMatrixAt(i, new THREE.Matrix4().multiplyMatrices(m, n.matrixWorld)));
      im.castShadow = true; im.receiveShadow = true; im.frustumCulled = false; root.add(im);
    });
  }
  placements = new Map();
}

/* ---------- environnements ---------- */
function clearWorld() {
  E.world.traverse(o => { if (o.isInstancedMesh) o.dispose(); });
  E.world.clear(); E.colliders = []; E.anim = []; E.lights = [];
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

export function buildWorld(kind, opt = {}) {
  clearWorld(); const info = { spawn: new THREE.Vector3(0, 0, 0), R: 55, spots: [], stations: [], portals: [] };
  const sc = E.scene;
  if (kind === 'hub') {
    sc.fog = new THREE.Fog(0x2a2350, 40, 150); sky('#120d2e', '#5b3a8a', true);
    E.hemi.color.set(0xb8b0ff); E.hemi.groundColor.set(0x2a2040); E.hemi.intensity = 1.2; E.sun.color.set(0xd7ccff); E.sun.intensity = 2.0;
    ground('#4a4560', '#3a3550', 42, true, 18); info.R = 40;
    const plaza = new THREE.Mesh(new THREE.CircleGeometry(9, 48), new THREE.MeshLambertMaterial({ color: 0x2b2445 })); plaza.rotation.x = -Math.PI / 2; plaza.position.y = 0.02; plaza.receiveShadow = true; E.world.add(plaza);
    const sig = new THREE.Mesh(new THREE.RingGeometry(6.5, 7.2, 64), new THREE.MeshBasicMaterial({ color: 0x8b5cf6, transparent: true, opacity: 0.7, blending: THREE.AdditiveBlending })); sig.rotation.x = -Math.PI / 2; sig.position.y = 0.04; E.world.add(sig);
    E.anim.push(() => { sig.material.opacity = 0.45 + Math.sin(E.t * 2) * 0.25; });
    place('x:building_well_blue', 0, 0, 0, 2.2, 0, 0.7);
    place('x:building_castle_blue', 0, -27, 0, 7, 0, 1);
    place('x:building_tower_A_blue', -17, -22, 0.4, 5.5, 0, 0.6); place('x:building_tower_B_blue', 17, -22, -0.4, 5.5, 0, 0.6);
    const st = [
      ['forge', 'x:building_blacksmith_blue', -17, -6, 1.2, 'Forge des Ombres', '#ff7a45'],
      ['armurerie', 'x:building_market_blue', 17, -6, -1.2, 'Armurerie', '#ffcc33'],
      ['autel', 'x:building_church_blue', -18, 9, 2.0, 'Autel des Reliques', '#c26bff'],
      ['donjons', 'x:building_tavern_blue', 18, 9, -2.0, 'Salle des Brèches', '#38bdf8'],
    ];
    for (const [id, m, x, z, r, label, col] of st) { place(m, x, z, r, 5.2, 0, 0.7); info.stations.push({ id, x: x * 0.62, z: z * 0.62, label, col }); }
    for (let i = 0; i < 14; i++) { const a = i / 14 * Math.PI * 2; place(pick(['x:building_home_A_blue', 'x:building_home_B_red', 'x:building_home_A_yellow']), Math.cos(a) * 34, Math.sin(a) * 34, -a + Math.PI / 2, 4.6, 0, 0.7); }
    for (let i = 0; i < 26; i++) { const a = rnd(0, 6.28), r = rnd(24, 31); place(pick(['n:Pine_1', 'n:Pine_3', 'n:CommonTree_3']), Math.cos(a) * r, Math.sin(a) * r, rnd(0, 6), rnd(1.6, 2.4), 0, 0.8); }
    for (let i = 0; i < 6; i++) { const a = i / 6 * 6.28 + 0.3; place('x:flag_red', Math.cos(a) * 9.5, Math.sin(a) * 9.5, -a, 2.2); }
    place('x:weaponrack', 13, -2, -1.4, 2.4); place('x:crate_A_big', 14, 1, 0.3, 2); place('x:barrel', -13, -1, 0, 2); place('x:tent', -12, 17, 0.6, 3, 0, 0.7); place('x:tent', 12, 18, -0.6, 3, 0, 0.7);
    for (let i = 0; i < 8; i++) { const a = i / 8 * 6.28; place('h:lantern_standing', Math.cos(a) * 11.5, Math.sin(a) * 11.5, 0, 1.1); }
    pointLight(0, 4, 0, 0x9b6bff, 30, 26);
    ZONES.forEach((z, i) => { const a = Math.PI / 2 + (i - 1) * 0.55; const x = Math.cos(a) * 20, zz = Math.sin(a) * 20; const p = portalMesh(new THREE.Color(z.fragCol).getHex(), 1.15); p.position.set(x, 0, zz); E.world.add(p); info.portals.push({ zone: i, x, z: zz }); pointLight(x, 2.5, zz, new THREE.Color(z.fragCol).getHex(), 18, 12); });
    ambientMotes(0xb08bff, 140, 35, true);
    info.spawn.set(0, 0, 6);
  } else if (typeof kind === 'number') {
    const Z = ZONES[kind]; info.R = 56;
    sc.fog = new THREE.Fog(Z.fog, 30, 130); sky(Z.sky[0], Z.sky[1], kind > 0);
    E.hemi.color.set(Z.light); E.hemi.groundColor.set(kind === 0 ? 0x4a5a30 : 0x2a2030); E.hemi.intensity = kind === 0 ? 1.25 : 1.0; E.sun.color.set(Z.light); E.sun.intensity = kind === 0 ? 2.6 : 1.7;
    ground(Z.ground, Z.ground2, 62, kind === 2, 16);
    const tree = kind === 0 ? ['n:CommonTree_1', 'n:CommonTree_3', 'n:CommonTree_5', 'n:Pine_1', 'n:Pine_3', 'n:TwistedTree_1'] : kind === 1 ? ['h:tree_dead_large', 'h:tree_dead_medium', 'n:DeadTree_2', 'n:TwistedTree_3'] : ['n:DeadTree_2', 'h:tree_dead_large', 'n:TwistedTree_3'];
    for (let i = 0; i < 80; i++) { const a = rnd(0, 6.28), r = rnd(60, 76); place(pick(tree), Math.cos(a) * r, Math.sin(a) * r, rnd(0, 6), rnd(1.6, 2.6)); }
    for (let i = 0; i < 10; i++) { const a = rnd(0, 6.28), r = rnd(16, 46); const x = Math.cos(a) * r, z = Math.sin(a) * r; if (Math.abs(x) < 8 && z > 20) continue; place(pick(tree), x, z, rnd(0, 6), rnd(0.65, 0.9), 0, 0.6); }
    if (kind === 0) {
      for (let i = 0; i < 160; i++) place(pick(['n:Grass_Common_Tall', 'n:Flower_3_Group', 'n:Flower_4_Group', 'n:Fern_1', 'n:Bush_Common', 'n:Bush_Common_Flowers', 'n:Mushroom_Common']), rnd(-55, 55), rnd(-55, 55), rnd(0, 6), rnd(1.2, 2));
      for (let i = 0; i < 18; i++) place(pick(['n:Rock_Medium_1', 'n:Rock_Medium_2', 'n:Rock_Medium_3']), rnd(-50, 50), rnd(-50, 50), rnd(0, 6), rnd(0.7, 1.3), 0, 0.9);
      ambientMotes(0xfff2a0, 90, 50, false);
    } else if (kind === 1) {
      for (let i = 0; i < 60; i++) place(pick(['h:grave_A', 'h:grave_B', 'h:gravestone', 'h:bone_A', 'h:ribcage', 'h:pumpkin_orange', 'h:skull_candle']), rnd(-50, 50), rnd(-50, 50), rnd(0, 6), rnd(1.4, 2.2));
      for (let i = 0; i < 6; i++) { const a = i / 6 * 6.28 + 0.4, r = rnd(30, 44); const x = Math.cos(a) * r, z = Math.sin(a) * r; if (z > 25 && Math.abs(x) < 14) continue; place('h:crypt', x, z, -a, 1.4, 0, 1.6); }
      for (let i = 0; i < 10; i++) { const a = rnd(0, 6.28), r = rnd(12, 48); const x = Math.cos(a) * r, z = Math.sin(a) * r; place('h:post_lantern', x, z, 0, 2); if (i < 5) pointLight(x, 3, z, 0x9b6bff, 14, 16); }
      for (let i = 0; i < 20; i++) place(pick(['n:Rock_Medium_1', 'n:Rock_Medium_3']), rnd(-50, 50), rnd(-50, 50), rnd(0, 6), rnd(0.7, 1.2), 0, 0.9);
      ambientMotes(0x9ff3ff, 110, 50, true);
    } else {
      for (let i = 0; i < 8; i++) { const a = i / 8 * 6.28, r = rnd(30, 45); place(pick(['x:building_tower_A_blue', 'x:building_tower_B_blue', 'x:building_barracks_blue']), Math.cos(a) * r, Math.sin(a) * r, -a, 4.5, 0, 0.7); }
      for (let i = 0; i < 50; i++) place(pick(['d:rubble_large', 'd:rubble_half', 'd:column', 'd:pillar', 'd:barrel_large', 'd:banner_patternA_red', 'd:sword_shield_gold']), rnd(-48, 48), rnd(-48, 48), rnd(0, 6), rnd(1.6, 2.6), 0, 0.6);
      for (let i = 0; i < 18; i++) place('x:flag_red', rnd(-45, 45), rnd(-45, 45), rnd(0, 6), 2.6);
      for (let i = 0; i < 6; i++) pointLight(rnd(-35, 35), 3, rnd(-35, 35), 0xff6a30, 16, 18);
      ambientMotes(0xff7a30, 160, 50, true);
    }
    for (let i = 0; i < 14; i++) { const a = rnd(0, 6.28), r = rnd(8, 46); info.spots.push(new THREE.Vector3(Math.cos(a) * r, 0, Math.sin(a) * r)); }
    const back = portalMesh(0x8b5cf6, 0.9); back.position.set(0, 0, 50); E.world.add(back); info.portals.push({ zone: -1, x: 0, z: 50 });
    info.spawn.set(0, 0, 42);
  } else if (kind === 'dungeon' || kind === 'siege') {
    const tint = opt.tint || 0x6d4cff; info.R = kind === 'siege' ? 30 : 24;
    sc.fog = new THREE.Fog(0x0b0820, 20, 80); sky('#05040d', '#1a1033', false);
    E.hemi.color.set(0x9a8cff); E.hemi.groundColor.set(0x1a1028); E.hemi.intensity = 0.9; E.sun.color.set(0xb0a0ff); E.sun.intensity = 1.2;
    const R = info.R;
    ground('#3a3550', '#2c2840', R + 2, true, R / 2.5);
    const n = Math.floor(R * 0.75);
    for (let i = 0; i < n; i++) { const a = i / n * 6.28; const back = Math.sin(a) < 0.2; place(back ? pick(['d:wall', 'd:wall_cracked', 'd:wall_broken']) : pick(['d:rubble_half', 'd:rubble_large']), Math.cos(a) * (R + 1.5), Math.sin(a) * (R + 1.5), -a - Math.PI / 2, back ? 1.5 : 1.1); }
    for (let i = 0; i < 10; i++) { const a = i / 10 * 6.28; const x = Math.cos(a) * (R - 3), z = Math.sin(a) * (R - 3); place('d:pillar_decorated', x, z, 0, 1.6, 0, 0.9); if (Math.sin(a) < 0.2) place('d:torch_mounted', Math.cos(a) * (R + 0.6), Math.sin(a) * (R + 0.6), -a - Math.PI / 2, 1.6, 2.2); if (i % 2 === 0) pointLight(x, 3.5, z, i % 4 ? 0xff9a40 : tint, 16, 14); }
    for (let i = 0; i < 12; i++) place(pick(['d:barrel_large', 'd:rubble_half', 'd:candle_triple', 'd:banner_patternB_blue', 'd:coin_stack_large']), ...polar(rnd(R - 6, R - 2.5)), rnd(0, 6), 1.5);
    const rune = new THREE.Mesh(new THREE.RingGeometry(4, 4.6, 6), new THREE.MeshBasicMaterial({ color: tint, transparent: true, opacity: 0.6, blending: THREE.AdditiveBlending })); rune.rotation.x = -Math.PI / 2; rune.position.y = 0.05; E.world.add(rune);
    E.anim.push(dt => { rune.rotation.z += dt * 0.3; });
    ambientMotes(tint, 80, R, true);
    if (kind === 'siege') {
      const cr = new THREE.Mesh(new THREE.OctahedronGeometry(1.6, 0), new THREE.MeshLambertMaterial({ color: 0x9ff3ff, emissive: 0x38bdf8, emissiveIntensity: 1.2 }));
      cr.position.y = 3; E.world.add(cr); info.crystal = cr; pointLight(0, 3, 0, 0x38bdf8, 30, 20);
      const gl = new THREE.Mesh(new THREE.CircleGeometry(4, 32), new THREE.MeshBasicMaterial({ map: E.glowTex, color: 0x38bdf8, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false })); gl.rotation.x = -Math.PI / 2; gl.position.y = 0.06; E.world.add(gl);
      E.anim.push(dt => { cr.rotation.y += dt; cr.position.y = 3 + Math.sin(E.t * 2) * 0.3; });
      info.spawn.set(0, 0, 5);
    } else info.spawn.set(0, 0, R - 9);
  }
  flush(E.world);
  return info;
}
const polar = r => { const a = rnd(0, 6.28); return [Math.cos(a) * r, Math.sin(a) * r]; };

/* ---------- collisions ---------- */
export function collide(p, r = 0.5, R = 60) {
  for (const c of E.colliders) { const dx = p.x - c.x, dz = p.z - c.z, d = Math.hypot(dx, dz), m = c.r + r; if (d < m && d > 0.001) { p.x = c.x + dx / d * m; p.z = c.z + dz / d * m; } }
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
