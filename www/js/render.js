// FRACTURE — rendu : renderer, arène néon, personnages KayKit en cel-shading + contour.
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

export const R = {
  renderer: null, scene: null, cam: null, logicCam: null, clock: null,
  W: 1, H: 1, A: 1, dpr: 1, actors: {}, env: {}, shake: 0, shakeT: 0, punch: new THREE.Vector3(),
  framing: null, framingFrom: null, framingT: 1, framingDur: 1, time: 0,
};

// ---------- Renderer ----------
export function initRenderer(canvas) {
  const r = new THREE.WebGLRenderer({ canvas, antialias: false, powerPreference: 'high-performance', stencil: false });
  r.setClearColor(0x07050f, 1);
  r.autoClear = false;
  r.outputColorSpace = THREE.SRGBColorSpace;
  R.renderer = r;
  R.scene = new THREE.Scene();
  R.scene.fog = new THREE.FogExp2(0x1a0b2e, 0.018);
  R.cam = new THREE.PerspectiveCamera(32, 1, 0.1, 400);
  R.logicCam = new THREE.PerspectiveCamera(32, 1, 0.1, 400);
  R.dpr = Math.min(window.devicePixelRatio || 1, 1.6);
  resize();
  window.addEventListener('resize', resize);
  return r;
}
export function setPixelRatio(p) { R.dpr = p; resize(); }
export function resize(forcedAspect) {
  const w = window.innerWidth, h = window.innerHeight;
  R.W = w; R.H = h; R.A = w / h;
  R.renderer.setPixelRatio(R.dpr);
  R.renderer.setSize(w, h, false);
  R.cam.aspect = R.A; R.cam.updateProjectionMatrix();
  R.logicCam.aspect = forcedAspect || R.A; R.logicCam.updateProjectionMatrix();
  if (R.onResize) R.onResize();
}

// ---------- Matériaux cel-shading ----------
let gradTex = null;
function gradient() {
  if (gradTex) return gradTex;
  const d = new Uint8Array([70, 70, 70, 255, 160, 160, 160, 255, 255, 255, 255, 255]);
  gradTex = new THREE.DataTexture(d, 3, 1, THREE.RGBAFormat);
  gradTex.minFilter = gradTex.magFilter = THREE.NearestFilter; gradTex.needsUpdate = true;
  return gradTex;
}
// Toon + liseré (rim) néon + flash d'impact partagés par acteur.
export function toonMaterial(src, U, { emissive = null, tint = null } = {}) {
  const m = new THREE.MeshToonMaterial({ map: src.map || null, color: tint ? new THREE.Color(tint) : (src.color ? src.color.clone() : new THREE.Color(1, 1, 1)), gradientMap: gradient() });
  if (emissive) { m.emissive = new THREE.Color(emissive); m.emissiveIntensity = 1.0; }
  m.onBeforeCompile = sh => {
    sh.uniforms.uRim = U.rim; sh.uniforms.uRimStr = U.rimStr; sh.uniforms.uFlash = U.flash; sh.uniforms.uAura = U.aura;
    sh.fragmentShader = sh.fragmentShader
      .replace('#include <common>', '#include <common>\nuniform vec3 uRim; uniform float uRimStr; uniform vec3 uFlash; uniform vec3 uAura;')
      .replace('#include <opaque_fragment>', `
        float rimF = 1.0 - max(dot(normalize(vNormal), normalize(vViewPosition)), 0.0);
        outgoingLight += uRim * pow(rimF, 3.0) * uRimStr + uAura * pow(rimF, 1.2) + uFlash;
        #include <opaque_fragment>`);
  };
  m.customProgramCacheKey = () => 'toonRim';
  return m;
}
function outlineMaterial(color, width) {
  const m = new THREE.MeshBasicMaterial({ color, side: THREE.BackSide, fog: true });
  m.onBeforeCompile = sh => {
    sh.uniforms.uOutline = { value: width };
    sh.vertexShader = sh.vertexShader
      .replace('#include <common>', '#include <common>\nuniform float uOutline;')
      .replace('#include <begin_vertex>', 'vec3 transformed = vec3(position) + normalize(normal) * uOutline;');
  };
  m.customProgramCacheKey = () => 'outline' + width;
  return m;
}

// ---------- Chargement des modèles (GLB encodés en base64 .txt) ----------
const loader = new GLTFLoader();
function loadB64(url) {
  return fetch(url).then(r => { if (!r.ok) throw new Error(url + ' ' + r.status); return r.text(); }).then(t => new Promise((res, rej) => {
    const bin = atob(t.trim()); const u8 = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) u8[i] = bin.charCodeAt(i);
    loader.parse(u8.buffer, '', res, rej);
  }));
}
export async function loadModels(onProg) {
  const list = ['hero', 'minion', 'rogue', 'boss'];
  const out = {}; let done = 0;
  await Promise.all(list.map(k => loadB64('assets/m/' + k + '.txt').then(g => { out[k] = g; onProg(++done / list.length); })));
  return out;
}

// ---------- Acteurs ----------
const KEEP_HERO = new Set(['1H_Sword', 'Knight_Helmet', 'Knight_Cape', 'Knight_ArmLeft', 'Knight_ArmRight', 'Knight_Body', 'Knight_Head', 'Knight_LegLeft', 'Knight_LegRight']);
export function buildActor(key, gltf, opts) {
  const root = new THREE.Group(); root.name = key;
  const model = gltf.scene; root.add(model);
  const U = { rim: { value: new THREE.Color(opts.rim) }, rimStr: { value: opts.rimStr ?? 1.2 }, flash: { value: new THREE.Color(0, 0, 0) }, aura: { value: new THREE.Color(0, 0, 0) } };
  const bones = {}; const meshes = []; const remove = [];
  model.traverse(o => {
    if (o.isBone) bones[o.name] = o;
    if (o.isMesh) {
      if (opts.keep && !opts.keep.has(o.name)) { remove.push(o); return; }
      meshes.push(o);
    }
  });
  remove.forEach(o => o.parent && o.parent.remove(o));
  // GLTFLoader retire les points des noms ("upperarm.l" → "upperarml") : on accepte les deux écritures
  const boneMap = new Proxy(bones, { get: (t, k) => t[k] !== undefined ? t[k] : (typeof k === 'string' ? t[k.replace(/\./g, '')] : undefined) });
  const olMat = outlineMaterial(opts.outline ?? 0x05030a, opts.outlineW ?? 0.022);
  meshes.forEach(o => {
    const isEye = /Eyes/.test(o.name);
    o.material = toonMaterial(o.material, U, { emissive: isEye ? opts.eyes : null });
    if (isEye) o.material = new THREE.MeshBasicMaterial({ color: opts.eyes || 0xffffff });
    o.frustumCulled = false;
    if (!isEye) addOutline(o, olMat);
  });
  model.scale.setScalar(opts.scale || 1);
  const mixer = new THREE.AnimationMixer(model);
  const actions = {};
  gltf.animations.forEach(c => { actions[c.name] = mixer.clipAction(c); });
  const a = { key, root, model, mixer, actions, bones: boneMap, U, cur: null, meshes, olMat, weapon: null, scale: opts.scale || 1 };
  return a;
}
function addOutline(o, mat) {
  let ol;
  if (o.isSkinnedMesh) { ol = new THREE.SkinnedMesh(o.geometry, mat); ol.bind(o.skeleton, o.bindMatrix); ol.bindMode = o.bindMode; }
  else ol = new THREE.Mesh(o.geometry, mat);
  ol.frustumCulled = false; ol.renderOrder = -1;
  if (o.isSkinnedMesh) { ol.position.copy(o.position); ol.quaternion.copy(o.quaternion); ol.scale.copy(o.scale); o.parent.add(ol); }
  else o.add(ol);
  return ol;
}
// Greffe une arme (mesh statique d'un autre modèle) dans la main d'un acteur.
export function attachWeapon(actor, srcMesh, bone, { scale = 1, color = null, emissive = null } = {}) {
  const m = new THREE.Mesh(srcMesh.geometry, toonMaterial(srcMesh.material, actor.U, { emissive }));
  if (color) m.material.color = new THREE.Color(color);
  m.scale.setScalar(scale);
  m.frustumCulled = false;
  addOutline(m, actor.olMat);
  const b = actor.bones[bone]; if (b) b.add(m);
  return m;
}

// Joue une animation de façon déterministe (crossfade dans le temps du mixer).
export function play(a, name, { loop = false, fade = 0.12, ts = 1, clamp = true, from = 0, restart = true } = {}) {
  const act = a.actions[name]; if (!act) return null;
  if (a.cur === act && !restart) { act.timeScale = ts; return act; }
  act.reset(); act.time = from * act.getClip().duration; act.timeScale = ts; act.enabled = true; act.paused = false;
  act.setLoop(loop ? THREE.LoopRepeat : THREE.LoopOnce, loop ? Infinity : 1);
  act.clampWhenFinished = clamp;
  act.setEffectiveWeight(1);
  if (a.cur && a.cur !== act) { act.crossFadeFrom(a.cur, fade, false); }
  act.play();
  a.cur = act;
  return act;
}

// ---------- Environnement : toit néon nocturne ----------
function canvasTex(w, h, draw) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 2;
  return t;
}
export function buildEnv() {
  const S = R.scene, E = R.env;
  S.add(new THREE.HemisphereLight(0x8a7cff, 0x1a0a28, 0.75));
  const key = new THREE.DirectionalLight(0xfff0f6, 1.7); key.position.set(3, 6, 8); S.add(key);
  const back = new THREE.DirectionalLight(0xff3d9a, 0.7); back.position.set(-6, 4, -6); S.add(back);

  // Ciel : dégradé + étoiles
  const skyMat = new THREE.ShaderMaterial({
    side: THREE.BackSide, depthWrite: false, fog: false,
    uniforms: { uT: { value: 0 } },
    vertexShader: `varying vec3 vP; void main(){ vP = normalize(position); gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.); }`,
    fragmentShader: `varying vec3 vP; uniform float uT;
      float h(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
      void main(){ float y = vP.y;
        vec3 top = vec3(0.02,0.01,0.07), mid = vec3(0.16,0.03,0.24), hor = vec3(0.95,0.22,0.55);
        vec3 c = mix(hor, mid, smoothstep(-0.02, 0.18, y)); c = mix(c, top, smoothstep(0.18, 0.7, y));
        vec2 g = floor(vec2(atan(vP.z, vP.x)*220., y*220.)); float s = h(g); float tw = 0.5+0.5*sin(uT*2.+s*40.);
        c += step(0.9965, s) * tw * smoothstep(0.08, 0.5, y) * 0.9;
        gl_FragColor = vec4(c,1.); }`,
  });
  E.sky = new THREE.Mesh(new THREE.SphereGeometry(300, 32, 16), skyMat); S.add(E.sky);

  // La Fracture : une faille lumineuse déchire le ciel (texture peinte une seule fois)
  const crackTex = canvasTex(1024, 512, (g, w, h) => {
    g.clearRect(0, 0, w, h);
    const pts = []; let x = 40, y = h * 0.62; pts.push([x, y]);
    while (x < w - 40) { x += 30 + Math.random() * 60; y += (Math.random() - 0.5) * 90; y = Math.max(h * 0.2, Math.min(h * 0.85, y)); pts.push([x, y]); }
    const stroke = (wid, col, blur) => { g.save(); g.strokeStyle = col; g.lineWidth = wid; g.shadowColor = col; g.shadowBlur = blur; g.lineJoin = 'miter'; g.beginPath(); pts.forEach((p, i) => i ? g.lineTo(p[0], p[1]) : g.moveTo(p[0], p[1])); g.stroke(); g.restore(); };
    stroke(26, 'rgba(255,40,140,0.35)', 60); stroke(12, 'rgba(120,240,255,0.7)', 40); stroke(4, 'rgba(255,255,255,1)', 18);
    for (let i = 0; i < 9; i++) { const p = pts[2 + Math.floor(Math.random() * (pts.length - 4))]; g.save(); g.strokeStyle = 'rgba(160,240,255,0.8)'; g.lineWidth = 2; g.shadowColor = '#7ff'; g.shadowBlur = 12; g.beginPath(); g.moveTo(p[0], p[1]); let bx = p[0], by = p[1]; for (let k = 0; k < 4; k++) { bx += (Math.random() - 0.5) * 50; by += (Math.random() < 0.5 ? -1 : 1) * (15 + Math.random() * 30); g.lineTo(bx, by); } g.stroke(); g.restore(); }
  });
  E.crack = new THREE.Mesh(new THREE.PlaneGeometry(240, 120), new THREE.MeshBasicMaterial({ map: crackTex, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, fog: false }));
  E.crack.position.set(10, 62, -170); S.add(E.crack);
  // Lune fêlée
  const moonTex = canvasTex(256, 256, (g, w) => { const gr = g.createRadialGradient(w / 2, w / 2, 10, w / 2, w / 2, w / 2); gr.addColorStop(0, 'rgba(255,240,250,1)'); gr.addColorStop(0.42, 'rgba(255,200,230,0.95)'); gr.addColorStop(0.46, 'rgba(255,90,170,0.35)'); gr.addColorStop(1, 'rgba(255,40,140,0)'); g.fillStyle = gr; g.fillRect(0, 0, w, w); });
  E.moon = new THREE.Mesh(new THREE.PlaneGeometry(46, 46), new THREE.MeshBasicMaterial({ map: moonTex, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, fog: false }));
  E.moon.position.set(-70, 48, -180); S.add(E.moon);

  // Gratte-ciel : 1 seul draw call (InstancedMesh), fenêtres procédurales en shader
  const N = 150;
  const bMat = new THREE.ShaderMaterial({
    fog: true,
    uniforms: THREE.UniformsUtils.merge([THREE.UniformsLib.fog, { uT: { value: 0 } }]),
    vertexShader: `#include <common>
      #include <fog_pars_vertex>
      varying vec3 vW; varying vec3 vN; varying float vSeed;
      void main(){ vec4 w = modelMatrix * instanceMatrix * vec4(position,1.); vW = w.xyz;
        vN = normalize(mat3(modelMatrix * instanceMatrix) * normal); vSeed = instanceMatrix[3][0]*0.13 + instanceMatrix[3][2]*0.71;
        vec4 mvPosition = viewMatrix * w; gl_Position = projectionMatrix * mvPosition;
        #include <fog_vertex>
      }`,
    fragmentShader: `#include <common>
      #include <fog_pars_fragment>
      varying vec3 vW; varying vec3 vN; varying float vSeed; uniform float uT;
      float hh(vec2 p){ return fract(sin(dot(p,vec2(41.3,289.1)))*15731.743); }
      void main(){
        vec3 base = vec3(0.035,0.02,0.07);
        float side = 1.0 - abs(vN.y);
        vec2 uv = vec2(abs(vN.x) > 0.5 ? vW.z : vW.x, vW.y);
        vec2 cell = floor(uv / vec2(0.9, 1.2)); vec2 f = fract(uv / vec2(0.9, 1.2));
        float win = step(0.18, f.x) * step(f.x, 0.82) * step(0.25, f.y) * step(f.y, 0.78);
        float r = hh(cell + vSeed);
        vec3 wc = r < 0.5 ? vec3(0.2,0.9,1.0) : (r < 0.8 ? vec3(1.0,0.25,0.65) : vec3(1.0,0.75,0.3));
        float lit = step(0.7, hh(cell*1.7 + vSeed*3.1)) * (0.75 + 0.25*sin(uT*0.7 + r*30.));
        vec3 c = base + side * win * lit * wc * 1.1;
        // arête néon au sommet
        c += vec3(1.0,0.2,0.6) * step(0.98, vN.y) * 0.15;
        gl_FragColor = vec4(c, 1.0);
        #include <fog_fragment>
      }`,
  });
  const box = new THREE.BoxGeometry(1, 1, 1); box.translate(0, 0.5, 0);
  const inst = new THREE.InstancedMesh(box, bMat, N);
  const m4 = new THREE.Matrix4(), q = new THREE.Quaternion(), sc = new THREE.Vector3(), p = new THREE.Vector3();
  let rs = 7; const rnd = () => (rs = (rs * 16807) % 2147483647) / 2147483647;
  for (let i = 0; i < N; i++) {
    const ang = -Math.PI * 0.95 + rnd() * Math.PI * 0.9 - Math.PI * 0.05 + (i % 2 ? 0 : Math.PI * 0.0);
    const rad = 34 + rnd() * 80;
    const a2 = (i / N) * Math.PI * 2;
    const useA = rnd() < 0.75 ? (-Math.PI / 2 + (rnd() - 0.5) * Math.PI * 1.25) : a2;
    p.set(Math.cos(useA) * rad, -6, Math.sin(useA) * rad);
    if (p.length() < 30) p.setLength(30 + rnd() * 8);
    const h = 14 + Math.pow(rnd(), 1.4) * 80;
    sc.set(4 + rnd() * 9, h, 4 + rnd() * 9);
    q.setFromAxisAngle(new THREE.Vector3(0, 1, 0), rnd() * Math.PI);
    m4.compose(p, q, sc); inst.setMatrixAt(i, m4);
    void ang;
  }
  inst.frustumCulled = false; S.add(inst); E.city = inst;

  // Enseignes néon (inventées) : quelques plans additifs
  const signs = [['零', '#22f0ff', -16, 14, -30, 7], ['LAME', '#ff2e88', 18, 12, -34, 9], ['ゼロ', '#ffd23f', -30, 22, -48, 9], ['FRACTURE', '#b46bff', 34, 26, -60, 16]];
  E.signs = signs.map(([txt, col, x, y, z, w]) => {
    const t = canvasTex(512, 160, (g, W, H) => { g.font = `900 ${txt.length > 3 ? 92 : 120}px Orbitron, sans-serif`; g.textAlign = 'center'; g.textBaseline = 'middle'; g.shadowColor = col; g.shadowBlur = 30; g.strokeStyle = col; g.lineWidth = 8; g.strokeText(txt, W / 2, H / 2); g.shadowBlur = 10; g.fillStyle = '#fff'; g.fillText(txt, W / 2, H / 2); });
    const m = new THREE.Mesh(new THREE.PlaneGeometry(w, w * 160 / 512), new THREE.MeshBasicMaterial({ map: t, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, fog: false }));
    m.position.set(x, y, z); m.lookAt(0, y * 0.5, 8); S.add(m); return m;
  });

  // Sol de l'arène : grille néon + anneau
  const floorMat = new THREE.ShaderMaterial({
    transparent: false, fog: false,
    uniforms: { uT: { value: 0 }, uPulse: { value: 0 }, uCol: { value: new THREE.Color(0x22f0ff) }, uDanger: { value: 0 } },
    vertexShader: `varying vec3 vW; void main(){ vec4 w = modelMatrix*vec4(position,1.); vW = w.xyz; gl_Position = projectionMatrix*viewMatrix*w; }`,
    fragmentShader: `varying vec3 vW; uniform float uT, uPulse, uDanger; uniform vec3 uCol;
      float line(float x, float w){ float d = abs(fract(x)-0.5); float fw = fwidth(x); return 1.0 - smoothstep(w-fw, w+fw, 0.5-d); }
      void main(){ float r = length(vW.xz);
        vec3 c = vec3(0.025,0.012,0.05);
        float g = max(line(vW.x*0.9, 0.03), line(vW.z*0.9, 0.03));
        float fade = smoothstep(26.0, 4.0, r);
        vec3 gc = mix(uCol, vec3(1.0,0.15,0.35), uDanger);
        c += gc * g * fade * 0.3;
        float ring = smoothstep(0.16, 0.0, abs(r - 5.6)); c += vec3(1.0,0.18,0.6) * ring * (1.2 + 0.4*sin(uT*3.0));
        float ring2 = smoothstep(0.05, 0.0, abs(r - 5.0)); c += uCol * ring2 * 0.7;
        float wave = smoothstep(0.35, 0.0, abs(r - uPulse*14.0)) * (1.0 - uPulse); c += gc * wave * 1.2;
        float inner = smoothstep(5.0, 0.0, r); c += vec3(0.25,0.05,0.35) * inner * 0.25;
        c = mix(c, vec3(0.1,0.04,0.18), smoothstep(30.0, 70.0, r));
        gl_FragColor = vec4(c, 1.0); }`,
  });
  E.floor = new THREE.Mesh(new THREE.PlaneGeometry(160, 160), floorMat); E.floor.rotation.x = -Math.PI / 2; S.add(E.floor);

  // Ombres portées factices
  const blobTex = canvasTex(128, 128, (g, w) => { const gr = g.createRadialGradient(w / 2, w / 2, 0, w / 2, w / 2, w / 2); gr.addColorStop(0, 'rgba(0,0,0,0.75)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gr; g.fillRect(0, 0, w, w); });
  E.blobMat = new THREE.MeshBasicMaterial({ map: blobTex, transparent: true, depthWrite: false });

  // Braises montantes (1 draw call)
  const EN = 140, eg = new THREE.BufferGeometry(), ep = new Float32Array(EN * 3), es = new Float32Array(EN);
  for (let i = 0; i < EN; i++) { ep[i * 3] = (Math.random() - 0.5) * 30; ep[i * 3 + 1] = Math.random() * 14; ep[i * 3 + 2] = (Math.random() - 0.5) * 24 - 4; es[i] = Math.random(); }
  eg.setAttribute('position', new THREE.BufferAttribute(ep, 3)); eg.setAttribute('seed', new THREE.BufferAttribute(es, 1));
  E.embers = new THREE.Points(eg, new THREE.ShaderMaterial({
    transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, uniforms: { uT: { value: 0 }, uPx: { value: R.dpr } },
    vertexShader: `attribute float seed; uniform float uT, uPx; varying float vA; varying float vS;
      void main(){ vec3 p = position; p.y = mod(p.y + uT*(0.4+seed*0.8), 14.0); p.x += sin(uT*0.6+seed*20.)*0.6;
        vec4 mv = modelViewMatrix*vec4(p,1.); gl_Position = projectionMatrix*mv; gl_PointSize = (2.0+seed*4.0)*uPx*(12.0/-mv.z);
        vA = smoothstep(0.,2.,p.y)*smoothstep(14.,9.,p.y); vS = seed; }`,
    fragmentShader: `varying float vA; varying float vS; void main(){ float d = length(gl_PointCoord-0.5); float a = smoothstep(0.5,0.0,d)*vA;
      vec3 c = vS < 0.5 ? vec3(1.0,0.35,0.7) : vec3(0.35,0.95,1.0); gl_FragColor = vec4(c*a, a); }`,
  }));
  E.embers.frustumCulled = false; S.add(E.embers);
}
export function addBlob(actor, size) {
  const b = new THREE.Mesh(new THREE.PlaneGeometry(size, size), R.env.blobMat);
  b.rotation.x = -Math.PI / 2; b.position.y = 0.02; actor.root.add(b); actor.blob = b;
}

// ---------- Cadrage caméra (logique = sans tremblement, sert aux projections) ----------
export function setFraming(f, dur = 0) {
  R.framingFrom = R.framing ? { pos: R.framing.pos.clone(), look: R.framing.look.clone() } : null;
  R.framing = { pos: new THREE.Vector3(...f.pos), look: new THREE.Vector3(...f.look) };
  R.framingDur = dur; R.framingT = dur > 0 && R.framingFrom ? 0 : 1;
  applyFraming(0);
}
const _p = new THREE.Vector3(), _l = new THREE.Vector3();
export function applyFraming(dt) {
  if (!R.framing) return;
  if (R.framingT < 1) R.framingT = Math.min(1, R.framingT + dt / R.framingDur);
  const k = R.framingT * R.framingT * (3 - 2 * R.framingT);
  if (R.framingFrom && k < 1) { _p.lerpVectors(R.framingFrom.pos, R.framing.pos, k); _l.lerpVectors(R.framingFrom.look, R.framing.look, k); }
  else { _p.copy(R.framing.pos); _l.copy(R.framing.look); }
  R.logicCam.position.copy(_p); R.logicCam.lookAt(_l); R.logicCam.updateMatrixWorld(true);
}
const _v = new THREE.Vector3();
// Projette un point monde en "unités écran" : x ∈ [0, A], y ∈ [0, 1] (haut = 0)
export function project(v, out) {
  _v.copy(v).project(R.logicCam);
  out.x = (_v.x * 0.5 + 0.5) * R.logicCam.aspect; out.y = (-_v.y * 0.5 + 0.5);
  return out;
}

// ---------- Boucle de rendu ----------
export function renderFrame(dt, fxScene, fxCam) {
  R.time += dt;
  const E = R.env;
  if (E.sky) E.sky.material.uniforms.uT.value = R.time;
  if (E.city) E.city.material.uniforms.uT.value = R.time;
  if (E.floor) E.floor.material.uniforms.uT.value = R.time;
  if (E.embers) E.embers.material.uniforms.uT.value = R.time;
  // caméra rendue = caméra logique + tremblement + impulsion
  R.cam.position.copy(R.logicCam.position); R.cam.quaternion.copy(R.logicCam.quaternion);
  if (R.shake > 0.0005) {
    R.shakeT += dt * 60;
    R.cam.position.x += (Math.sin(R.shakeT * 1.7) + Math.sin(R.shakeT * 3.1)) * R.shake * 0.5;
    R.cam.position.y += (Math.cos(R.shakeT * 2.3) + Math.sin(R.shakeT * 4.7)) * R.shake * 0.5;
    R.shake *= Math.pow(0.0009, dt);
  }
  R.cam.position.add(R.punch); R.punch.multiplyScalar(Math.pow(0.0005, dt));
  R.cam.fov = R.logicCam.fov; R.cam.updateProjectionMatrix();
  const r = R.renderer;
  r.clear();
  r.render(R.scene, R.cam);
  if (fxScene) { r.clearDepth(); r.render(fxScene, fxCam); }
}
export function addShake(v) { R.shake = Math.min(0.35, R.shake + v); }
