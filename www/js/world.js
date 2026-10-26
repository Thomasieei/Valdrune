// FRACTURE — le monde RPG : Quartier Zéro (hub) + Les Friches (zone à explorer).
// Déplacement au joystick, caméra 3/4 façon Albion, PNJ, squelettes errants : les toucher ouvre un duel Tracé-Rupture.
import * as THREE from 'three';
import { clone as skClone } from 'three/addons/utils/SkeletonUtils.js';
import { R, makeBuildingMat, canvasTex, buildActor, attachWeapon, play } from './render.js';

export const WD = { group: null, active: false, ents: [], npcs: [], inter: [], obst: [], chests: [], heroPos: new THREE.Vector3(0, 0, 6), heroRot: Math.PI, camPos: new THREE.Vector3(), area: 'hub', speed: 0, time: 0 };

// ---------- Tenues (cases de l'atlas KayKit Rogue : "col,ligne") ----------
// (0,1)(1,1) veste/capuche verte · (3,0) chemise · (5,0) gants/ceinture · (5,2) brassards · (6,0) sangles · (7,1) chaussures · (3,2) pantalon · (1,0) cheveux
export const OUTFITS = {
  hero: { '0,1': 0x3f66a8, '1,1': 0x4b74b8, '3,0': 0xf2f4f8, '5,0': 0x3a2e2a, '5,2': 0x3f66a8, '6,0': 0x3a3e48, '7,1': 0xf4f4f4, '3,2': 0x2c3e5e, '1,0': 0x4a3226 },
  kai: { '0,1': 0x5a2a1a, '1,1': 0x6e3420, '3,0': 0xd8cbb4, '5,0': 0x3a2a1e, '5,2': 0x5a2a1a, '6,0': 0x3a2a1e, '7,1': 0x2a2420, '3,2': 0x2e2e34, '1,0': 0x9a9a9a },
  mira: { '0,1': 0x5b2a7a, '1,1': 0x6e3a8e, '3,0': 0xf2e6ff, '5,0': 0xf0c8a8, '5,2': 0x5b2a7a, '6,0': 0x2a2030, '7,1': 0x1a1a1f, '3,2': 0x1f1f26, '1,0': 0xd94f8a },
  oda: { '0,1': 0xe8e6e0, '1,1': 0xd8d4cc, '3,0': 0xffffff, '5,0': 0x111111, '5,2': 0xe8e6e0, '6,0': 0x111111, '7,1': 0x111111, '3,2': 0x15151a, '1,0': 0x2a2a2a },
  nori: { '0,1': 0xd9a21b, '1,1': 0xe5b53a, '3,0': 0x2b2b30, '5,0': 0xf0c8a8, '5,2': 0xd9a21b, '6,0': 0x6b4a1e, '7,1': 0xf2f2f2, '3,2': 0x4b6b3a, '1,0': 0x6b3a1e },
  pass1: { '0,1': 0x2f6b5a, '1,1': 0x3a7a68, '3,0': 0xf0f0f0, '5,0': 0xf0c8a8, '5,2': 0x2f6b5a, '6,0': 0x2a2a2a, '7,1': 0xc8202a, '3,2': 0x2a2a35, '1,0': 0x3a2a1a },
  pass2: { '0,1': 0xb83a4a, '1,1': 0xc8485a, '3,0': 0x222228, '5,0': 0xf0c8a8, '5,2': 0xb83a4a, '6,0': 0x222228, '7,1': 0xeeeeee, '3,2': 0x55556a, '1,0': 0x111114 },
};

// ---------- Collision : zone praticable + obstacles circulaires ----------
const HUB_R = 15.5;
function walkable(x, z) {
  if (x * x + z * z < HUB_R * HUB_R) return true;          // place du Quartier Zéro
  if (Math.abs(x) < 3.6 && z < -12 && z > -24) return true; // ruelle vers les Friches
  if (Math.abs(x) < 25 && z <= -21 && z > -124) return true; // Les Friches
  return false;
}
function free(x, z, r = 0.45) {
  if (!walkable(x, z)) return false;
  for (const o of WD.obst) { const dx = x - o.x, dz = z - o.z; if (dx * dx + dz * dz < (o.r + r) * (o.r + r)) return false; }
  return true;
}

// ---------- Décor ----------
function seeded(seed) { let s = seed; return () => (s = (s * 16807) % 2147483647) / 2147483647; }
function signTex(txt, col, w = 512, h = 160) {
  return canvasTex(w, h, (g, W, H) => { g.font = `900 ${txt.length > 6 ? 70 : 96}px Orbitron, sans-serif`; g.textAlign = 'center'; g.textBaseline = 'middle'; g.shadowColor = col; g.shadowBlur = 28; g.strokeStyle = col; g.lineWidth = 7; g.strokeText(txt, W / 2, H / 2); g.shadowBlur = 8; g.fillStyle = '#fff'; g.fillText(txt, W / 2, H / 2); });
}
function label(txt, sub, col) {
  const t = canvasTex(512, 128, (g, W, H) => {
    g.textAlign = 'center'; g.textBaseline = 'middle';
    g.font = '700 54px Rajdhani, sans-serif'; g.lineWidth = 10; g.strokeStyle = 'rgba(5,2,12,.9)'; g.strokeText(txt, W / 2, 44); g.fillStyle = col; g.fillText(txt, W / 2, 44);
    if (sub) { g.font = '700 36px Orbitron, sans-serif'; g.strokeText(sub, W / 2, 98); g.fillStyle = '#fff'; g.fillText(sub, W / 2, 98); }
  });
  const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: t, depthTest: false, transparent: true }));
  s.scale.set(2.6, 0.65, 1); s.renderOrder = 10; return s;
}
function buildDecor() {
  const G = WD.group;
  // Sol : bitume néon (place) → terre fêlée (Friches)
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(90, 170), new THREE.ShaderMaterial({
    fog: true, uniforms: THREE.UniformsUtils.merge([THREE.UniformsLib.fog, { uT: { value: 0 } }]),
    vertexShader: `#include <common>
      #include <fog_pars_vertex>
      varying vec3 vW; void main(){ vec4 w = modelMatrix*vec4(position,1.); vW = w.xyz; vec4 mvPosition = viewMatrix*w; gl_Position = projectionMatrix*mvPosition;
      #include <fog_vertex>
      }`,
    fragmentShader: `#include <common>
      #include <fog_pars_fragment>
      varying vec3 vW; uniform float uT;
      float hh(vec2 p){ return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453); }
      float line(float x, float w){ float d = abs(fract(x)-0.5); float fw = fwidth(x); return 1.0 - smoothstep(w-fw, w+fw, 0.5-d); }
      void main(){
        float r = length(vW.xz); float zone = smoothstep(-16.0, -24.0, vW.z);
        // place : dalles sombres + joints lumineux + cercle central
        vec3 hub = vec3(0.13,0.10,0.19) + hh(floor(vW.xz*0.5))*0.035;
        float tile = max(line(vW.x*0.5, 0.02), line(vW.z*0.5, 0.02));
        hub += vec3(0.25,0.85,1.0) * tile * 0.32 * smoothstep(17.0, 3.0, r);
        hub += vec3(1.0,0.2,0.6) * smoothstep(0.12, 0.0, abs(r - 5.0)) * 0.9;
        hub += vec3(0.25,0.9,1.0) * smoothstep(0.06, 0.0, abs(r - 6.0)) * 0.6;
        hub = mix(hub, vec3(0.03,0.02,0.05), smoothstep(14.5, 16.5, r) * (1.0 - zone));
        // Friches : terre violacée + veines de fracture qui pulsent
        vec2 q = vW.xz * 0.18; float n = hh(floor(q*6.0)) * 0.05;
        vec3 fr = vec3(0.16,0.09,0.15) + n;
        float vein = smoothstep(0.035, 0.0, abs(sin(vW.x*0.35 + sin(vW.z*0.21)*2.0) * cos(vW.z*0.27 + vW.x*0.08)));
        fr += vec3(1.0,0.18,0.55) * vein * (0.35 + 0.25*sin(uT*1.5 + vW.z*0.2));
        float path = smoothstep(4.0, 1.5, abs(vW.x + sin(vW.z*0.08)*6.0)); fr = mix(fr, vec3(0.14,0.10,0.13), path*0.6);
        vec3 c = mix(hub, fr, zone);
        gl_FragColor = vec4(c, 1.0);
        #include <fog_fragment>
      }`,
  }));
  floor.rotation.x = -Math.PI / 2; floor.position.set(0, 0, -50); G.add(floor); WD.floor = floor;

  // Immeubles autour de la place (1 draw call) — ouverture au nord (ruelle) et au sud
  const rnd = seeded(42), box = new THREE.BoxGeometry(1, 1, 1); box.translate(0, 0.5, 0);
  const bl = [];
  for (let i = 0; i < 22; i++) {
    const a = (i / 22) * Math.PI * 2 + 0.07; const deg = ((a * 180 / Math.PI) + 360) % 360;
    if (Math.abs(deg - 270) < 13) continue; // nord (z négatif) = ruelle
    const rad = 19 + rnd() * 4;
    bl.push({ x: Math.cos(a) * rad, z: Math.sin(a) * rad, w: 5 + rnd() * 4, d: 5 + rnd() * 4, h: 9 + rnd() * 20, rot: -a });
  }
  // façades de la ruelle + ruines hautes en bordure des Friches
  for (let z = -14; z > -24; z -= 5) { bl.push({ x: -6.5, z, w: 5, d: 5, h: 8 + rnd() * 8, rot: 0 }); bl.push({ x: 6.5, z, w: 5, d: 5, h: 8 + rnd() * 8, rot: 0 }); }
  for (let z = -28; z > -126; z -= 9) { bl.push({ x: -30 - rnd() * 3, z, w: 7, d: 8, h: 6 + rnd() * 14, rot: rnd() }); bl.push({ x: 30 + rnd() * 3, z, w: 7, d: 8, h: 6 + rnd() * 14, rot: rnd() }); }
  const inst = new THREE.InstancedMesh(box, makeBuildingMat(), bl.length);
  const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), v = new THREE.Vector3(), sc = new THREE.Vector3(), up = new THREE.Vector3(0, 1, 0);
  bl.forEach((b, i) => { q.setFromAxisAngle(up, b.rot); m4.compose(v.set(b.x, 0, b.z), q, sc.set(b.w, b.h, b.d)); inst.setMatrixAt(i, m4); });
  inst.frustumCulled = false; G.add(inst);

  // Enseignes néon sur les façades qui regardent la place
  const signs = [['FORGE', '#ff7a1a', -10.5, 7.5], ['ARCHIVES', '#b46bff', 10.5, 7.5], ['DOJO', '#22f0ff', 11, -7.5], ['RAMEN', '#ffd23f', -11, -7.5], ['ZÉRO', '#ff2e88', 0, 16.5]];
  signs.forEach(([t, col, x, z]) => {
    const m = new THREE.Mesh(new THREE.PlaneGeometry(4.2, 1.3), new THREE.MeshBasicMaterial({ map: signTex(t, col), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, fog: false }));
    const ang = Math.atan2(x, z); m.position.set(Math.sin(ang) * 17.6, 6.5, Math.cos(ang) * 17.6); m.lookAt(0, 6.5, 0); G.add(m);
  });
  const fr = new THREE.Mesh(new THREE.PlaneGeometry(9, 2.4), new THREE.MeshBasicMaterial({ map: signTex('LES FRICHES', '#ff2e88', 768, 200), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, fog: false }));
  fr.position.set(0, 7.2, -12.6); G.add(fr);

  // Lampadaires : mâts + têtes lumineuses + flaques de lumière au sol (3 draw calls)
  const lamps = [];
  for (let i = 0; i < 8; i++) { const a = (i / 8) * Math.PI * 2 + Math.PI / 8; lamps.push([Math.cos(a) * 12.5, Math.sin(a) * 12.5, i % 2 ? 0x22f0ff : 0xff2e88]); }
  for (let z = -30; z > -120; z -= 18) { lamps.push([-9, z, 0xff2e88]); lamps.push([9, z - 9, 0xb46bff]); }
  const pole = new THREE.InstancedMesh(new THREE.CylinderGeometry(0.07, 0.1, 4, 6).translate(0, 2, 0), new THREE.MeshLambertMaterial({ color: 0x241c34 }), lamps.length);
  const head = new THREE.InstancedMesh(new THREE.SphereGeometry(0.28, 10, 8), new THREE.MeshBasicMaterial({ color: 0xffffff }), lamps.length);
  const pool = new THREE.InstancedMesh(new THREE.PlaneGeometry(1, 1).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ map: canvasTex(128, 128, (g, w) => { const gr = g.createRadialGradient(w / 2, w / 2, 0, w / 2, w / 2, w / 2); gr.addColorStop(0, 'rgba(255,255,255,.55)'); gr.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = gr; g.fillRect(0, 0, w, w); }), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }), lamps.length);
  const col = new THREE.Color();
  lamps.forEach(([x, z, c], i) => {
    m4.makeTranslation(x, 0, z); pole.setMatrixAt(i, m4);
    m4.makeTranslation(x, 4.1, z); head.setMatrixAt(i, m4); head.setColorAt(i, col.set(c));
    m4.compose(v.set(x, 0.03, z), q.identity(), sc.set(6, 1, 6)); pool.setMatrixAt(i, m4); pool.setColorAt(i, col.set(c).multiplyScalar(0.8));
    WD.obst.push({ x, z, r: 0.3 });
  });
  [pole, head, pool].forEach(o => { o.frustumCulled = false; G.add(o); });

  // Étals des PNJ (comptoir + auvent lumineux) — un par métier
  const stalls = [[-9.5, 6.8, 0xff7a1a], [9.5, 6.8, 0xb46bff], [9.8, -6.6, 0x22f0ff], [-9.8, -6.6, 0xffd23f]];
  const counterM = new THREE.MeshLambertMaterial({ color: 0x35284f });
  stalls.forEach(([x, z, c]) => {
    const g = new THREE.Group(); const ang = Math.atan2(-x, -z);
    const counter = new THREE.Mesh(new THREE.BoxGeometry(2.6, 0.9, 0.8), counterM); counter.position.set(0, 0.45, -0.9); g.add(counter);
    const strip = new THREE.Mesh(new THREE.BoxGeometry(2.62, 0.08, 0.82), new THREE.MeshBasicMaterial({ color: c })); strip.position.set(0, 0.92, -0.9); g.add(strip);
    const awn = new THREE.Mesh(new THREE.BoxGeometry(3.0, 0.12, 1.6), new THREE.MeshBasicMaterial({ color: c, transparent: true, opacity: 0.85 })); awn.position.set(0, 2.9, -0.6); awn.rotation.x = -0.2; g.add(awn);
    [-1.35, 1.35].forEach(px => { const post = new THREE.Mesh(new THREE.BoxGeometry(0.12, 2.9, 0.12), counterM); post.position.set(px, 1.45, -1.3); g.add(post); });
    g.position.set(x, 0, z); g.rotation.y = ang + Math.PI; WD.group.add(g);
    const glow = new THREE.Mesh(new THREE.PlaneGeometry(5, 5).rotateX(-Math.PI / 2), pool.material.clone()); glow.material.color = new THREE.Color(c).multiplyScalar(0.6); glow.position.set(x, 0.04, z); WD.group.add(glow);
  });
  // Bancs et arbres (instanciés)
  const benches = [[0, 9.2, 0], [6.5, 3.5, 1.1], [-6.5, 3.5, -1.1], [5.5, -9.5, 2.6], [-5.5, -9.5, -2.6]];
  const bench = new THREE.InstancedMesh(new THREE.BoxGeometry(2, 0.45, 0.6).translate(0, 0.42, 0), counterM, benches.length);
  benches.forEach(([x, z, r], i) => { q.setFromAxisAngle(up, r); m4.compose(v.set(x, 0, z), q, sc.set(1, 1, 1)); bench.setMatrixAt(i, m4); WD.obst.push({ x, z, r: 0.8 }); });
  bench.frustumCulled = false; G.add(bench);
  const trees = [[13, 2], [-13, 2], [12, 9], [-12, 9], [4, -13], [-4, 13.2], [13.5, -4], [-13.5, -4]];
  const trunk = new THREE.InstancedMesh(new THREE.CylinderGeometry(0.15, 0.2, 1.6, 6).translate(0, 0.8, 0), new THREE.MeshLambertMaterial({ color: 0x2a1c2e }), trees.length);
  const crown = new THREE.InstancedMesh(new THREE.IcosahedronGeometry(1.1, 0).translate(0, 2.3, 0), new THREE.MeshLambertMaterial({ color: 0xffffff }), trees.length);
  trees.forEach(([x, z], i) => { m4.makeTranslation(x, 0, z); trunk.setMatrixAt(i, m4); crown.setMatrixAt(i, m4); crown.setColorAt(i, col.set(i % 2 ? 0xff5fae : 0x7a5cff)); WD.obst.push({ x, z, r: 0.5 }); });
  [trunk, crown].forEach(o => { o.frustumCulled = false; G.add(o); });

  // Fontaine : Cristal de Fracture (soin gratuit)
  const basin = new THREE.Mesh(new THREE.CylinderGeometry(2.2, 2.4, 0.6, 24), new THREE.MeshLambertMaterial({ color: 0x2a2140 }));
  basin.position.y = 0.3; G.add(basin);
  const water = new THREE.Mesh(new THREE.CircleGeometry(2.0, 24).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: 0x22f0ff, transparent: true, opacity: 0.35, blending: THREE.AdditiveBlending, depthWrite: false }));
  water.position.y = 0.62; G.add(water);
  const crystal = new THREE.Mesh(new THREE.OctahedronGeometry(0.7, 0), new THREE.MeshBasicMaterial({ color: 0xff7ad0 }));
  crystal.position.y = 2.2; crystal.scale.set(0.8, 1.6, 0.8); G.add(crystal); WD.crystal = crystal;
  WD.obst.push({ x: 0, z: 0, r: 2.4 });

  // Portail des Friches (arche fêlée)
  const pm = new THREE.MeshLambertMaterial({ color: 0x2c2240 });
  [-3.4, 3.4].forEach(x => { const p = new THREE.Mesh(new THREE.BoxGeometry(0.8, 6, 0.8), pm); p.position.set(x, 3, -13.5); G.add(p); WD.obst.push({ x, z: -13.5, r: 0.6 }); });
  const arch = new THREE.Mesh(new THREE.PlaneGeometry(6, 5.2), new THREE.ShaderMaterial({
    transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, uniforms: { uT: { value: 0 } },
    vertexShader: `varying vec2 vUV; void main(){ vUV = uv; gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.); }`,
    fragmentShader: `varying vec2 vUV; uniform float uT; void main(){ vec2 p = vUV - 0.5; float n = sin(p.y*30.0 + uT*3.0)*0.02 + sin(p.y*71.0 - uT*5.0)*0.01;
      float crack = smoothstep(0.04, 0.0, abs(p.x + n + sin(p.y*9.0)*0.05)); float edge = smoothstep(0.5, 0.2, abs(p.x)) * smoothstep(0.5, 0.3, abs(p.y));
      vec3 c = vec3(1.0,0.2,0.6) * edge * 0.25 + vec3(0.6,1.0,1.0) * crack * 1.5; gl_FragColor = vec4(c, max(edge*0.25, crack)); }`,
  }));
  arch.position.set(0, 2.6, -13.5); G.add(arch); WD.arch = arch;

  // Friches : ruines (1 draw call) + cristaux de fracture (1 draw call)
  const rr = seeded(7);
  const ruins = [], crystals = [];
  for (let i = 0; i < 46; i++) {
    const x = (rr() - 0.5) * 46, z = -26 - rr() * 94;
    if (Math.abs(x + Math.sin(z * 0.08) * 6) < 4) continue; // garde le chemin libre
    if (z < -104 && Math.abs(x) < 9) continue;              // arène du boss dégagée
    const s = 0.7 + rr() * 1.6; ruins.push({ x, z, s, h: 0.6 + rr() * 3.2, rot: rr() * 3 });
    WD.obst.push({ x, z, r: s * 0.65 });
  }
  const ruinMesh = new THREE.InstancedMesh(new THREE.BoxGeometry(1, 1, 1).translate(0, 0.5, 0), new THREE.MeshLambertMaterial({ color: 0x3a2c4a }), ruins.length);
  ruins.forEach((o, i) => { q.setFromAxisAngle(up, o.rot); m4.compose(v.set(o.x, 0, o.z), q, sc.set(o.s, o.h, o.s * (0.6 + (i % 3) * 0.3))); ruinMesh.setMatrixAt(i, m4); });
  ruinMesh.frustumCulled = false; G.add(ruinMesh);
  for (let i = 0; i < 26; i++) { const x = (rr() - 0.5) * 44, z = -24 - rr() * 98; if (Math.abs(x + Math.sin(z * 0.08) * 6) < 3) continue; crystals.push({ x, z, s: 0.4 + rr() * 0.9 }); }
  const crMesh = new THREE.InstancedMesh(new THREE.OctahedronGeometry(0.5, 0), new THREE.MeshBasicMaterial({ color: 0xffffff }), crystals.length);
  crystals.forEach((o, i) => { m4.compose(v.set(o.x, o.s * 0.8, o.z), q.setFromAxisAngle(up, i), sc.set(o.s * 0.6, o.s * 1.7, o.s * 0.6)); crMesh.setMatrixAt(i, m4); crMesh.setColorAt(i, col.set(i % 3 ? 0xff2e88 : 0xb46bff)); });
  crMesh.frustumCulled = false; G.add(crMesh);
  // arène du boss : anneau de piliers
  const pil = new THREE.InstancedMesh(new THREE.CylinderGeometry(0.45, 0.6, 5, 8).translate(0, 2.5, 0), new THREE.MeshLambertMaterial({ color: 0x2a1f3a }), 10);
  for (let i = 0; i < 10; i++) { const a = (i / 10) * Math.PI * 2; const x = Math.cos(a) * 8.5, z = -114 + Math.sin(a) * 8.5; m4.makeTranslation(x, 0, z); pil.setMatrixAt(i, m4); WD.obst.push({ x, z, r: 0.7 }); }
  pil.frustumCulled = false; G.add(pil);
  const ring = new THREE.Mesh(new THREE.RingGeometry(7.6, 8.0, 48).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: 0xff3030, transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false }));
  ring.position.set(0, 0.04, -114); G.add(ring); WD.bossRing = ring;
}

// ---------- Coffres ----------
function buildChests() {
  const spots = [[-14, -46], [16, -78], [-12, -98]];
  spots.forEach(([x, z], i) => {
    const g = new THREE.Group();
    const body = new THREE.Mesh(new THREE.BoxGeometry(1.0, 0.6, 0.7), new THREE.MeshLambertMaterial({ color: 0x3a2a55 }));
    body.position.y = 0.3; g.add(body);
    const lid = new THREE.Mesh(new THREE.BoxGeometry(1.04, 0.22, 0.74), new THREE.MeshLambertMaterial({ color: 0x4a3870 }));
    lid.position.y = 0.71; g.add(lid);
    const trim = new THREE.Mesh(new THREE.BoxGeometry(1.08, 0.08, 0.78), new THREE.MeshBasicMaterial({ color: 0xffd23f }));
    trim.position.y = 0.6; g.add(trim);
    g.position.set(x, 0, z); g.rotation.y = i; WD.group.add(g);
    const c = { g, lid, x, z, open: false, i };
    WD.chests.push(c); WD.obst.push({ x, z, r: 0.6 });
    WD.inter.push({ x, z, r: 1.9, kind: 'chest', ref: c, label: 'OUVRIR', visible: () => !c.open });
  });
}

// ---------- PNJ ----------
function makeNPC(models, outfitTex, def) {
  const scene = skClone(models.hero.scene);
  const a = buildActor('npc', { scene, animations: models.hero.animations }, { rim: def.rim, rimStr: 0.6, outlineW: 0, hide: /Cape|Knife|Crossbow|Throwable/, map: outfitTex });
  a.root.position.set(def.x, 0, def.z); a.root.rotation.y = def.rot;
  play(a, def.anim, { loop: true, fade: 0 });
  a.mixer.update(Math.random() * 2);
  WD.group.add(a.root);
  if (def.name) { const s = label(def.name, def.role, def.color); s.position.set(0, 2.5, 0); a.root.add(s); }
  const n = { a, def, talkT: 0 };
  WD.npcs.push(n);
  if (def.kind) { WD.inter.push({ x: def.x, z: def.z, r: 3.2, kind: def.kind, ref: n, label: 'PARLER' }); WD.obst.push({ x: def.x, z: def.z, r: 0.5 }); }
  return n;
}

// ---------- Squelettes errants ----------
const SPAWNS = [
  ['minion', -6, -34], ['minion', 4, -38], ['minion', 10, -30],
  ['minion', -10, -58], ['rogue', 6, -62], ['minion', 14, -66], ['rogue', -4, -72],
  ['rogue', -12, -86], ['rogue', 8, -90], ['rogue', 0, -96],
  ['boss', 0, -116],
];
export const ENEMY_INFO = { minion: { lvl: 1, xp: 20, gold: [6, 10], col: '#22f0ff' }, rogue: { lvl: 2, xp: 40, gold: [12, 18], col: '#b46bff' }, boss: { lvl: 5, xp: 250, gold: [120, 120], col: '#ff3050' } };
function makeEnemy(models, ENEMIES, swords, type, x, z, idx) {
  const def = ENEMIES[type];
  const scene = skClone(models[type].scene);
  const a = buildActor(type, { scene, animations: models[type].animations }, { rim: def.rim, rimStr: 0.7, eyes: def.eyes, outlineW: 0, scale: def.scale, hide: /Helmet|Cloak|Hood|Cape/ });
  const src = def.weapon === '2H_Sword' ? swords.s2 : swords.s1;
  if (src) { attachWeapon(a, src, 'handslot.r', { scale: def.wScale, color: 0xb8a8d8, emissive: def.rim, outline: false }); if (def.dual) attachWeapon(a, src, 'handslot.l', { scale: def.wScale, color: 0xb8a8d8, emissive: def.rim, outline: false }); }
  a.root.position.set(x, 0, z); a.root.rotation.y = idx;
  WD.group.add(a.root);
  const info = ENEMY_INFO[type];
  const s = label(def.name, 'NV ' + info.lvl, info.col); s.position.set(0, 2.3 * def.scale + 0.2, 0); s.scale.multiplyScalar(def.scale > 1 ? 1.4 : 1); a.root.add(s);
  // marqueur au sol (aggro)
  const mk = new THREE.Mesh(new THREE.RingGeometry(0.55 * def.scale, 0.7 * def.scale, 24).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: type === 'boss' ? 0xff3030 : 0xff2e88, transparent: true, opacity: 0.6, blending: THREE.AdditiveBlending, depthWrite: false }));
  mk.position.y = 0.05; a.root.add(mk);
  play(a, 'Idle', { loop: true, fade: 0 }); a.mixer.update(idx * 0.37);
  const e = { a, type, def, home: new THREE.Vector2(x, z), state: 'idle', t: 1 + (idx % 3), dir: new THREE.Vector2(), alive: true, respawn: 0, mk, idx, label: s };
  WD.ents.push(e); return e;
}

// ---------- Initialisation ----------
export function initWorld({ models, ENEMIES, swords, outfitTex }) {
  WD.group = new THREE.Group(); WD.group.visible = false; R.scene.add(WD.group);
  buildDecor(); buildChests();
  const npcDefs = [
    { name: 'KAÏ', role: 'FORGERON DE LAMES', color: '#ff7a1a', x: -9.5, z: 6.8, rot: 2.3, anim: 'Idle', kind: 'forge', outfit: 'kai', rim: 0xff7a1a },
    { name: 'MIRA', role: 'ARCHIVISTE', color: '#b46bff', x: 9.5, z: 6.8, rot: -2.3, anim: 'Idle', kind: 'archives', outfit: 'mira', rim: 0xb46bff },
    { name: 'SENSEI ODA', role: 'DOJO', color: '#22f0ff', x: 9.8, z: -6.6, rot: -0.9, anim: '2H_Melee_Idle', kind: 'dojo', outfit: 'oda', rim: 0x22f0ff },
    { name: 'NORI', role: 'MARCHANDE', color: '#ffd23f', x: -9.8, z: -6.6, rot: 0.9, anim: 'Idle', kind: 'shop', outfit: 'nori', rim: 0xffd23f },
    { x: 4.2, z: 9.5, rot: 3.6, anim: 'Sit_Floor_Idle', outfit: 'pass1', rim: 0x22f0ff },
    { x: -3.5, z: 10.4, rot: 2.6, anim: 'Sit_Floor_Idle', outfit: 'pass2', rim: 0xff2e88 },
  ];
  npcDefs.forEach(d => makeNPC(models, outfitTex[d.outfit], d));
  SPAWNS.forEach(([t, x, z], i) => makeEnemy(models, ENEMIES, swords, t, x, z, i));
  WD.inter.push({ x: 0, z: 0, r: 3.6, kind: 'fountain', label: 'SE SOIGNER' });
}

// ---------- Entrée / sortie du monde ----------
export function enterWorld(hero) {
  WD.active = true; WD.group.visible = true; R.env.arena.visible = false;
  R.scene.fog.density = 0.011; R.env.hemi.intensity = 1.35; R.env.key.intensity = 1.5;
  R.logicCam.fov = 40; R.logicCam.updateProjectionMatrix();
  hero.mixer.stopAllAction(); hero.cur = null;
  hero.root.position.copy(WD.heroPos); hero.root.rotation.y = WD.heroRot;
  play(hero, 'Idle', { loop: true, fade: 0 });
  WD.camPos.set(WD.heroPos.x, 12.5, WD.heroPos.z + 10.5);
  WD.speed = 0;
}
export function leaveWorld(hero) {
  WD.active = false; WD.group.visible = false; R.env.arena.visible = true;
  R.scene.fog.density = 0.018; R.env.hemi.intensity = 0.75; R.env.key.intensity = 1.7;
  R.logicCam.fov = 32; R.logicCam.updateProjectionMatrix();
  if (hero) { WD.heroPos.copy(hero.root.position); WD.heroRot = hero.root.rotation.y; }
}

// ---------- Mise à jour ----------
const _v = new THREE.Vector3();
export function updateWorld(dt, hero, joy, hooks) {
  WD.time += dt;
  WD.floor.material.uniforms.uT.value = WD.time;
  WD.arch.material.uniforms.uT.value = WD.time;
  WD.crystal.rotation.y += dt * 0.8; WD.crystal.position.y = 2.2 + Math.sin(WD.time * 1.6) * 0.15;
  WD.bossRing.material.opacity = 0.5 + 0.3 * Math.sin(WD.time * 3);
  // déplacement du héros
  const p = hero.root.position;
  let mx = 0, mz = 0, mag = 0;
  if (joy && joy.m > 0.12) { mx = joy.x; mz = joy.y; mag = Math.min(1, joy.m); }
  const target = mag * 5.6;
  WD.speed += (target - WD.speed) * Math.min(1, dt * 10);
  if (WD.speed > 0.05 && mag > 0) {
    const l = Math.hypot(mx, mz) || 1, dx = mx / l * WD.speed * dt, dz = mz / l * WD.speed * dt;
    if (free(p.x + dx, p.z + dz)) { p.x += dx; p.z += dz; }
    else if (free(p.x + dx, p.z)) p.x += dx;
    else if (free(p.x, p.z + dz)) p.z += dz;
    const ang = Math.atan2(mx, mz); let d = ang - hero.root.rotation.y; d = Math.atan2(Math.sin(d), Math.cos(d));
    hero.root.rotation.y += d * Math.min(1, dt * 14);
  }
  const want = WD.speed > 3.2 ? 'Running_A' : WD.speed > 0.4 ? 'Walking_A' : 'Idle';
  if (hero.cur !== hero.actions[want]) play(hero, want, { loop: true, fade: 0.18 });
  if (hero.cur === hero.actions.Running_A) hero.cur.timeScale = 0.75 + WD.speed / 8;
  hero.mixer.update(dt);
  // zone courante
  const area = p.z < -20 ? 'friches' : 'hub';
  if (area !== WD.area) { WD.area = area; hooks.area && hooks.area(area); }
  // caméra 3/4 qui suit
  WD.camPos.lerp(_v.set(p.x, 12.5, p.z + 10.5), Math.min(1, dt * 5));
  R.logicCam.position.copy(WD.camPos); R.logicCam.lookAt(WD.camPos.x, 0.9, WD.camPos.z - 10.5); R.logicCam.updateMatrixWorld(true);
  // PNJ : regardent le héros quand il approche
  for (const n of WD.npcs) {
    const d2 = n.a.root.position.distanceToSquared(p);
    if (d2 < 900) n.a.mixer.update(dt);
    if (n.def.kind && d2 < 12) { const ang = Math.atan2(p.x - n.a.root.position.x, p.z - n.a.root.position.z); let d = ang - n.a.root.rotation.y; d = Math.atan2(Math.sin(d), Math.cos(d)); n.a.root.rotation.y += d * Math.min(1, dt * 4); }
  }
  // ennemis
  let encounter = null;
  for (const e of WD.ents) {
    if (!e.alive) { e.respawn -= dt; if (e.respawn <= 0 && e.type !== 'boss') respawn(e); continue; }
    const ep = e.a.root.position, dx = p.x - ep.x, dz = p.z - ep.z, dist = Math.hypot(dx, dz);
    const near = dist < 34; e.a.root.visible = near; if (!near) continue;
    const aggro = e.type === 'boss' ? 9 : 7.5;
    const homeD = Math.hypot(ep.x - e.home.x, ep.z - e.home.y);
    if (e.state !== 'chase' && dist < aggro && WD.area === 'friches') { e.state = 'chase'; play(e.a, 'Running_A', { loop: true, fade: 0.15 }); hooks.aggro && hooks.aggro(e); }
    if (e.state === 'chase') {
      if (homeD > 16 || dist > 14) { e.state = 'return'; play(e.a, 'Walking_D_Skeletons', { loop: true, fade: 0.2 }); }
      else { const sp = (e.type === 'rogue' ? 4.4 : e.type === 'boss' ? 3.4 : 3.8) * dt; const nx = ep.x + dx / dist * sp, nz = ep.z + dz / dist * sp; if (free(nx, nz, 0.3) || walkable(nx, nz)) { ep.x = nx; ep.z = nz; } e.a.root.rotation.y = Math.atan2(dx, dz); }
      if (dist < 1.25 * e.def.scale + 0.2) encounter = e;
    } else if (e.state === 'return') {
      const hx = e.home.x - ep.x, hz = e.home.y - ep.z, hd = Math.hypot(hx, hz);
      if (hd < 0.4) { e.state = 'idle'; e.t = 2; play(e.a, 'Idle', { loop: true, fade: 0.2 }); }
      else { const sp = 2.6 * dt; ep.x += hx / hd * sp; ep.z += hz / hd * sp; e.a.root.rotation.y = Math.atan2(hx, hz); }
    } else {
      // errance autour du point d'apparition
      e.t -= dt;
      if (e.state === 'idle' && e.t <= 0 && e.type !== 'boss') { e.state = 'wander'; const a = Math.random() * Math.PI * 2, r = Math.random() * 3.5; e.dir.set(e.home.x + Math.cos(a) * r, e.home.y + Math.sin(a) * r); e.t = 4; play(e.a, 'Walking_D_Skeletons', { loop: true, fade: 0.2 }); }
      if (e.state === 'wander') { const wx = e.dir.x - ep.x, wz = e.dir.y - ep.z, wd = Math.hypot(wx, wz); if (wd < 0.3 || e.t <= 0) { e.state = 'idle'; e.t = 1.5 + Math.random() * 2.5; play(e.a, 'Idle', { loop: true, fade: 0.2 }); } else { const sp = 1.1 * dt; if (free(ep.x + wx / wd * sp, ep.z + wz / wd * sp, 0.3)) { ep.x += wx / wd * sp; ep.z += wz / wd * sp; } else e.t = 0; e.a.root.rotation.y = Math.atan2(wx, wz); } }
    }
    e.mk.material.opacity = e.state === 'chase' ? 0.6 + 0.4 * Math.sin(WD.time * 12) : 0.35;
    e.a.mixer.update(dist < 22 ? dt : dt * 0.5);
  }
  // coffres
  for (const c of WD.chests) if (c.open && c.lid.rotation.x > -1.2) c.lid.rotation.x -= dt * 4;
  // interaction la plus proche
  let best = null, bd = 1e9;
  for (const it of WD.inter) { if (it.visible && !it.visible()) continue; const d = Math.hypot(p.x - it.x, p.z - it.z); if (d < it.r && d < bd) { bd = d; best = it; } }
  WD.near = best;
  return encounter;
}
function respawn(e) {
  e.alive = true; e.state = 'idle'; e.t = 1; e.a.root.position.set(e.home.x, 0, e.home.y); e.a.root.visible = true;
  e.a.mixer.stopAllAction(); e.a.cur = null; play(e.a, 'Idle', { loop: true, fade: 0 });
}
export function killEnt(e) { e.alive = false; e.respawn = 45; e.a.root.visible = false; }
export function resetBoss() { const b = WD.ents.find(e => e.type === 'boss'); if (b && !b.alive) respawn(b); }
// recul après un combat (pour ne pas réengager immédiatement)
export function pushAway(hero, e) {
  const p = hero.root.position, ep = e.a.root.position; const dx = p.x - ep.x, dz = p.z - ep.z, d = Math.hypot(dx, dz) || 1;
  for (let k = 3; k > 0; k -= 0.5) { const nx = ep.x + dx / d * k, nz = ep.z + dz / d * k; if (free(nx, nz)) { p.x = nx; p.z = nz; break; } }
}

// ---------- Mini-carte ----------
export function drawMinimap(cv, hero) {
  const g = cv.getContext('2d'), W = cv.width, H = cv.height, s = W / 60;
  const p = hero.root.position;
  g.clearRect(0, 0, W, H);
  g.save(); g.beginPath(); g.arc(W / 2, H / 2, W / 2 - 2, 0, Math.PI * 2); g.clip();
  g.fillStyle = 'rgba(10,5,22,.82)'; g.fillRect(0, 0, W, H);
  const X = x => W / 2 + (x - p.x) * s, Z = z => H / 2 + (z - p.z) * s;
  g.fillStyle = 'rgba(80,60,130,.55)';
  g.beginPath(); g.arc(X(0), Z(0), HUB_R * s, 0, Math.PI * 2); g.fill();
  g.fillRect(X(-3.6), Z(-24), 7.2 * s, 12 * s); g.fillRect(X(-25), Z(-124), 50 * s, 103 * s);
  g.strokeStyle = '#ff3050'; g.lineWidth = 2; g.beginPath(); g.arc(X(0), Z(-114), 8.5 * s, 0, Math.PI * 2); g.stroke();
  g.fillStyle = '#ff7ad0'; g.beginPath(); g.arc(X(0), Z(0), 3, 0, Math.PI * 2); g.fill();
  for (const n of WD.npcs) if (n.def.kind) { g.fillStyle = n.def.color; g.fillRect(X(n.def.x) - 2.5, Z(n.def.z) - 2.5, 5, 5); }
  for (const c of WD.chests) if (!c.open) { g.fillStyle = '#ffd23f'; g.fillRect(X(c.x) - 2, Z(c.z) - 2, 4, 4); }
  for (const e of WD.ents) if (e.alive) { g.fillStyle = e.type === 'boss' ? '#ff3050' : e.state === 'chase' ? '#ff2e88' : '#c070ff'; g.beginPath(); g.arc(X(e.a.root.position.x), Z(e.a.root.position.z), e.type === 'boss' ? 4 : 2.5, 0, Math.PI * 2); g.fill(); }
  g.translate(W / 2, H / 2); g.rotate(-hero.root.rotation.y + Math.PI); g.fillStyle = '#22f0ff';
  g.beginPath(); g.moveTo(0, -6); g.lineTo(4.5, 5); g.lineTo(-4.5, 5); g.closePath(); g.fill();
  g.restore();
  g.strokeStyle = 'rgba(34,240,255,.6)'; g.lineWidth = 2; g.beginPath(); g.arc(W / 2, H / 2, W / 2 - 2, 0, Math.PI * 2); g.stroke();
}
