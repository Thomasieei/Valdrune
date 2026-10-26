// FRACTURE — couche d'effets en espace écran (caméra orthographique).
// Unités : x ∈ [0, A], y ∈ [0, 1] (haut = 0). Tout est poolé : pas d'allocation en combat.
import * as THREE from 'three';

export const FX = { scene: new THREE.Scene(), cam: null, A: 1 };
const Y = y => 1 - y; // conversion vers l'espace ortho (y vers le haut)

export function initFX(A) {
  FX.cam = new THREE.OrthographicCamera(0, A, 1, 0, -10, 10);
  FX.A = A;
  buildParticles(); buildSparks(); buildScreen();
}
export function resizeFX(A) { FX.A = A; FX.cam.right = A; FX.cam.updateProjectionMatrix(); if (FX.screen) { FX.screen.scale.set(A, 1, 1); FX.screen.position.set(A / 2, 0.5, 5); } }

// ---------- Ruban (tracé, lame, lignes rouges, guides) ----------
const ribbonVS = `attribute vec2 aUV; varying vec2 vUV; void main(){ vUV = aUV; gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.); }`;
const ribbonFS = `varying vec2 vUV; uniform vec3 uCol; uniform vec3 uCore; uniform float uAlpha, uHead, uTail, uDash, uT, uProg, uGlow, uDark;
  void main(){
    float v = abs(vUV.y);
    float core = smoothstep(0.42, 0.0, v);
    float glow = smoothstep(1.0, 0.0, v) * uGlow;
    float u = vUV.x;
    float along = smoothstep(uTail, uTail + 0.25, u) * (1.0 - smoothstep(uHead, uHead + 0.02, u));
    if (uDash > 0.0) along *= step(0.45, fract(u * uDash - uT * 2.0));
    vec3 c = uCol * glow + uCore * core;
    float prog = step(u, uProg);
    c += vec3(1.0) * prog * core * 0.8;
    float a = (core + glow * 0.8) * along * uAlpha;
    float dk = smoothstep(0.75, 0.55, v) * smoothstep(0.25, 0.45, v) * uDark * along * min(uAlpha, 1.0);
    gl_FragColor = vec4(c * a, clamp(a * (1.0 - uDark) + max(dk, core * along * uDark), 0.0, 1.0));
  }`;
export class Ribbon {
  constructor(maxPts = 256, { col = 0x22f0ff, core = 0xffffff, width = 0.012, glow = 1, dash = 0, order = 2, dark = 0 } = {}) {
    this.max = maxPts; this.width = width;
    const g = new THREE.BufferGeometry();
    this.pos = new Float32Array(maxPts * 2 * 3); this.uv = new Float32Array(maxPts * 2 * 2);
    const idx = []; for (let i = 0; i < maxPts - 1; i++) { const a = i * 2; idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2); }
    g.setIndex(idx);
    g.setAttribute('position', new THREE.BufferAttribute(this.pos, 3).setUsage(THREE.DynamicDrawUsage));
    g.setAttribute('aUV', new THREE.BufferAttribute(this.uv, 2).setUsage(THREE.DynamicDrawUsage));
    g.setDrawRange(0, 0);
    this.mat = new THREE.ShaderMaterial({
      vertexShader: ribbonVS, fragmentShader: ribbonFS, transparent: true, depthTest: false, depthWrite: false, side: THREE.DoubleSide,
      blending: dark ? THREE.CustomBlending : THREE.AdditiveBlending, blendSrc: THREE.OneFactor, blendDst: THREE.OneMinusSrcAlphaFactor,
      uniforms: { uCol: { value: new THREE.Color(col) }, uCore: { value: new THREE.Color(core) }, uAlpha: { value: 1 }, uHead: { value: 1.01 }, uTail: { value: -1 }, uDash: { value: dash }, uT: { value: 0 }, uProg: { value: -1 }, uGlow: { value: glow }, uDark: { value: dark } },
    });
    this.mesh = new THREE.Mesh(g, this.mat); this.mesh.frustumCulled = false; this.mesh.renderOrder = order; this.mesh.visible = false;
    FX.scene.add(this.mesh); this.geo = g; this.n = 0;
  }
  color(c, core) { this.mat.uniforms.uCol.value.set(c); if (core !== undefined) this.mat.uniforms.uCore.value.set(core); }
  // pts : tableau [{x,y}] ; widthFn(t) optionnelle
  set(pts, widthFn) {
    const n = Math.min(pts.length, this.max); this.n = n;
    if (n < 2) { this.geo.setDrawRange(0, 0); this.mesh.visible = false; return; }
    let total = 0; const L = new Float32Array(n);
    for (let i = 1; i < n; i++) { total += Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y); L[i] = total; }
    total = total || 1;
    for (let i = 0; i < n; i++) {
      const p = pts[i], a = pts[Math.max(0, i - 1)], b = pts[Math.min(n - 1, i + 1)];
      let dx = b.x - a.x, dy = b.y - a.y; const l = Math.hypot(dx, dy) || 1; dx /= l; dy /= l;
      const t = L[i] / total, w = this.width * (widthFn ? widthFn(t) : 1);
      const nx = -dy * w, ny = dx * w;
      this.pos[i * 6] = p.x + nx; this.pos[i * 6 + 1] = Y(p.y) - ny; this.pos[i * 6 + 2] = 0;
      this.pos[i * 6 + 3] = p.x - nx; this.pos[i * 6 + 4] = Y(p.y) + ny; this.pos[i * 6 + 5] = 0;
      this.uv[i * 4] = t; this.uv[i * 4 + 1] = 1; this.uv[i * 4 + 2] = t; this.uv[i * 4 + 3] = -1;
    }
    this.geo.attributes.position.needsUpdate = true; this.geo.attributes.aUV.needsUpdate = true;
    this.geo.setDrawRange(0, (n - 1) * 6); this.mesh.visible = true; this.length = total;
  }
  hide() { this.mesh.visible = false; }
  u(name, v) { this.mat.uniforms[name].value = v; }
}

// ---------- Disques (failles, anneaux d'approche, ondes de choc) ----------
const discFS = `varying vec2 vUV; uniform vec3 uCol; uniform float uAlpha, uMode, uT, uFill, uRing, uState;
  float sdStar(vec2 p, float r){ float a = atan(p.y,p.x); float k = 0.82 + 0.18*cos(a*4.0 + uT*1.5); return length(p) - r*k; }
  void main(){
    vec2 p = vUV*2.0 - 1.0; float d = length(p); vec3 c = vec3(0.); float a = 0.;
    if (uMode < 0.5) { // faille : cristal + halo + éclats tournants
      float s = sdStar(p, 0.42);
      float core = smoothstep(0.03, -0.03, s);
      float rim = smoothstep(0.06, 0.0, abs(s)) ;
      float halo = smoothstep(1.0, 0.3, d) * 0.55;
      float ang = atan(p.y,p.x) + uT*2.5; float shards = step(0.82, fract(ang*3.0/6.2831)) * smoothstep(0.95,0.75,d) * smoothstep(0.55,0.7,d);
      vec3 inner = mix(vec3(1.0), uCol, 0.25 + 0.35*uState);
      float dark = smoothstep(0.07, 0.0, abs(s - 0.09)) * 0.85;
      c = inner * core * 1.1 + uCol * (rim * 1.6 + halo * 0.6 + shards * 1.2);
      a = clamp(max(core, rim) + dark + halo * 0.15 + shards * 0.5, 0.0, 1.0);
      if (uState > 1.5) { c = mix(c, vec3(0.6,1.0,0.7), 0.6); }
    } else if (uMode < 1.5) { // anneau d'approche
      float r = uRing; float w = 0.06;
      float ring = smoothstep(w, 0.0, abs(d - r));
      c = uCol * ring * 1.6; a = ring;
    } else if (uMode < 2.5) { // onde de choc
      float r = uRing; float ring = smoothstep(0.12*(1.0-uRing*0.6), 0.0, abs(d - r)) * (1.0 - uRing);
      c = uCol * ring * 2.0; a = ring;
    } else { // faille fantôme (miroir) : contour seul
      float s = sdStar(p, 0.42); float rim = smoothstep(0.05, 0.0, abs(s));
      c = uCol * rim * 1.3; a = rim * 0.85;
    }
    gl_FragColor = vec4(c * uAlpha, a * uAlpha);
  }`;
const discGeo = new THREE.PlaneGeometry(1, 1);
export class Disc {
  constructor(mode = 0, col = 0x22f0ff, order = 3) {
    this.mat = new THREE.ShaderMaterial({
      vertexShader: `varying vec2 vUV; void main(){ vUV = uv; gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.); }`,
      fragmentShader: discFS, transparent: true, depthTest: false, depthWrite: false, blending: (mode === 0 || mode === 3) ? THREE.CustomBlending : THREE.AdditiveBlending,
      blendSrc: THREE.OneFactor, blendDst: THREE.OneMinusSrcAlphaFactor,
      uniforms: { uCol: { value: new THREE.Color(col) }, uAlpha: { value: 1 }, uMode: { value: mode }, uT: { value: 0 }, uFill: { value: 0 }, uRing: { value: 0.5 }, uState: { value: 0 } },
    });
    this.mesh = new THREE.Mesh(discGeo, this.mat); this.mesh.renderOrder = order; this.mesh.visible = false; this.mesh.frustumCulled = false;
    FX.scene.add(this.mesh);
  }
  at(x, y, size) { this.mesh.position.set(x, Y(y), 0); this.mesh.scale.set(size, size, 1); this.mesh.visible = true; }
  u(n, v) { if (this.mat.uniforms[n].value && this.mat.uniforms[n].value.set) this.mat.uniforms[n].value.set(v); else this.mat.uniforms[n].value = v; }
  hide() { this.mesh.visible = false; }
}

// Chiffres d'ordre des failles (texture unique, 4 cases)
let digitTex = null;
function digits() {
  if (digitTex) return digitTex;
  const c = document.createElement('canvas'); c.width = 512; c.height = 128; const g = c.getContext('2d');
  g.font = '900 96px Orbitron, Arial Black, sans-serif'; g.textAlign = 'center'; g.textBaseline = 'middle';
  for (let i = 0; i < 4; i++) { g.lineWidth = 14; g.strokeStyle = '#0a0418'; g.strokeText(String(i + 1), 64 + i * 128, 70); g.fillStyle = '#ffffff'; g.fillText(String(i + 1), 64 + i * 128, 70); }
  digitTex = new THREE.CanvasTexture(c); digitTex.colorSpace = THREE.SRGBColorSpace; return digitTex;
}
export class Digit {
  constructor() {
    this.mat = new THREE.MeshBasicMaterial({ map: digits(), transparent: true, depthTest: false, depthWrite: false });
    const g = new THREE.PlaneGeometry(1, 1); this.uv = g.attributes.uv;
    this.mesh = new THREE.Mesh(g, this.mat); this.mesh.renderOrder = 6; this.mesh.visible = false; FX.scene.add(this.mesh);
  }
  set(n, x, y, size, alpha = 1) {
    const u0 = (n - 1) / 4, u1 = n / 4; const a = this.uv.array;
    a[0] = u0; a[2] = u1; a[4] = u0; a[6] = u1; this.uv.needsUpdate = true;
    this.mesh.position.set(x, Y(y), 0); this.mesh.scale.set(size, size, 1); this.mat.opacity = alpha; this.mesh.visible = true;
  }
  hide() { this.mesh.visible = false; }
}

// ---------- Particules lumineuses (Points, 1 draw call) ----------
const PN = 700; const P = { pos: null, col: null, size: null, vel: new Float32Array(PN * 2), life: new Float32Array(PN), maxLife: new Float32Array(PN), drag: new Float32Array(PN), grav: new Float32Array(PN), size0: new Float32Array(PN), next: 0, geo: null };
function buildParticles() {
  const g = new THREE.BufferGeometry();
  P.pos = new Float32Array(PN * 3); P.col = new Float32Array(PN * 4); P.size = new Float32Array(PN);
  g.setAttribute('position', new THREE.BufferAttribute(P.pos, 3).setUsage(THREE.DynamicDrawUsage));
  g.setAttribute('aCol', new THREE.BufferAttribute(P.col, 4).setUsage(THREE.DynamicDrawUsage));
  g.setAttribute('aSize', new THREE.BufferAttribute(P.size, 1).setUsage(THREE.DynamicDrawUsage));
  P.geo = g;
  P.mat = new THREE.ShaderMaterial({
    transparent: true, depthTest: false, depthWrite: false, blending: THREE.AdditiveBlending, uniforms: { uScale: { value: 800 } },
    vertexShader: `attribute vec4 aCol; attribute float aSize; uniform float uScale; varying vec4 vC; void main(){ vC = aCol; gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.); gl_PointSize = aSize*uScale; }`,
    fragmentShader: `varying vec4 vC; void main(){ float d = length(gl_PointCoord-0.5); float a = smoothstep(0.5,0.0,d); a = a*a; gl_FragColor = vec4(vC.rgb*a*vC.a + vec3(1.)*smoothstep(0.18,0.0,d)*vC.a*0.6, a*vC.a); }`,
  });
  const pts = new THREE.Points(g, P.mat); pts.frustumCulled = false; pts.renderOrder = 8; FX.scene.add(pts);
}
export function setParticleScale(hPx) { if (P.mat) P.mat.uniforms.uScale.value = hPx; }
const _c = new THREE.Color();
export function burst(x, y, n, { col = 0xffffff, speed = 0.6, size = 0.02, life = 0.5, drag = 3, grav = 0, spread = Math.PI * 2, dir = 0, jitter = 0.5 } = {}) {
  _c.set(col);
  for (let k = 0; k < n; k++) {
    const i = P.next; P.next = (P.next + 1) % PN;
    const a = dir + (Math.random() - 0.5) * spread, s = speed * (1 - jitter + Math.random() * jitter * 2);
    P.pos[i * 3] = x; P.pos[i * 3 + 1] = Y(y); P.pos[i * 3 + 2] = 0;
    P.vel[i * 2] = Math.cos(a) * s; P.vel[i * 2 + 1] = Math.sin(a) * s;
    P.col[i * 4] = _c.r; P.col[i * 4 + 1] = _c.g; P.col[i * 4 + 2] = _c.b; P.col[i * 4 + 3] = 1;
    P.size0[i] = size * (0.6 + Math.random() * 0.8); P.size[i] = P.size0[i];
    P.life[i] = P.maxLife[i] = life * (0.7 + Math.random() * 0.6); P.drag[i] = drag; P.grav[i] = grav;
  }
}
function updParticles(dt) {
  for (let i = 0; i < PN; i++) {
    if (P.life[i] <= 0) { if (P.col[i * 4 + 3] !== 0) { P.col[i * 4 + 3] = 0; P.size[i] = 0; } continue; }
    P.life[i] -= dt; const t = Math.max(0, P.life[i] / P.maxLife[i]);
    const dr = Math.exp(-P.drag[i] * dt);
    P.vel[i * 2] *= dr; P.vel[i * 2 + 1] = P.vel[i * 2 + 1] * dr - P.grav[i] * dt;
    P.pos[i * 3] += P.vel[i * 2] * dt; P.pos[i * 3 + 1] += P.vel[i * 2 + 1] * dt;
    P.col[i * 4 + 3] = t; P.size[i] = P.size0[i] * (0.4 + 0.6 * t);
  }
  P.geo.attributes.position.needsUpdate = true; P.geo.attributes.aCol.needsUpdate = true; P.geo.attributes.aSize.needsUpdate = true;
}

// ---------- Étincelles allongées (InstancedMesh, 1 draw call) ----------
const SN = 220; const SP = { mesh: null, vx: new Float32Array(SN), vy: new Float32Array(SN), x: new Float32Array(SN), y: new Float32Array(SN), life: new Float32Array(SN), max: new Float32Array(SN), len: new Float32Array(SN), next: 0 };
function buildSparks() {
  const g = new THREE.PlaneGeometry(1, 1); g.translate(-0.5, 0, 0);
  const m = new THREE.ShaderMaterial({
    transparent: true, depthTest: false, depthWrite: false, blending: THREE.AdditiveBlending,
    vertexShader: `varying vec2 vUV; varying vec3 vC; void main(){ vUV = uv; vC = instanceColor; gl_Position = projectionMatrix*modelViewMatrix*instanceMatrix*vec4(position,1.); }`,
    fragmentShader: `varying vec2 vUV; varying vec3 vC; void main(){ float a = smoothstep(0.5,0.0,abs(vUV.y-0.5)) * vUV.x; gl_FragColor = vec4((vC + vec3(0.6)*a)*a, a); }`,
  });
  SP.mesh = new THREE.InstancedMesh(g, m, SN); SP.mesh.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
  SP.mesh.instanceColor = new THREE.InstancedBufferAttribute(new Float32Array(SN * 3), 3);
  SP.mesh.frustumCulled = false; SP.mesh.renderOrder = 9; FX.scene.add(SP.mesh);
  const z = new THREE.Matrix4().makeScale(0, 0, 0); for (let i = 0; i < SN; i++) SP.mesh.setMatrixAt(i, z);
}
export function sparks(x, y, n, { col = 0xffffff, speed = 1.2, len = 0.05, life = 0.25, dir = 0, spread = Math.PI * 2 } = {}) {
  _c.set(col);
  for (let k = 0; k < n; k++) {
    const i = SP.next; SP.next = (SP.next + 1) % SN;
    const a = dir + (Math.random() - 0.5) * spread, s = speed * (0.5 + Math.random());
    SP.x[i] = x; SP.y[i] = Y(y); SP.vx[i] = Math.cos(a) * s; SP.vy[i] = Math.sin(a) * s;
    SP.life[i] = SP.max[i] = life * (0.6 + Math.random() * 0.8); SP.len[i] = len * (0.6 + Math.random() * 0.8);
    SP.mesh.instanceColor.setXYZ(i, _c.r, _c.g, _c.b);
  }
  SP.mesh.instanceColor.needsUpdate = true;
}
const _m = new THREE.Matrix4(), _q = new THREE.Quaternion(), _s = new THREE.Vector3(), _pv = new THREE.Vector3(), _z = new THREE.Vector3(0, 0, 1);
function updSparks(dt) {
  for (let i = 0; i < SN; i++) {
    if (SP.life[i] <= 0) continue;
    SP.life[i] -= dt; const t = Math.max(0, SP.life[i] / SP.max[i]);
    const dr = Math.exp(-5 * dt); SP.vx[i] *= dr; SP.vy[i] *= dr; SP.x[i] += SP.vx[i] * dt; SP.y[i] += SP.vy[i] * dt;
    const ang = Math.atan2(SP.vy[i], SP.vx[i]); _q.setFromAxisAngle(_z, ang);
    _s.set(SP.len[i] * (0.3 + t) * (0.4 + Math.hypot(SP.vx[i], SP.vy[i])), 0.006 * t + 0.001, 1); if (t <= 0) _s.set(0, 0, 0);
    _pv.set(SP.x[i], SP.y[i], 0); _m.compose(_pv, _q, _s); SP.mesh.setMatrixAt(i, _m);
  }
  SP.mesh.instanceMatrix.needsUpdate = true;
}

// ---------- Ondes de choc (pool de disques mode 2) ----------
const shocks = []; for (let i = 0; i < 10; i++) shocks.push({ d: null, t: 1, dur: 0.4, size: 0.3, x: 0, y: 0 });
export function shock(x, y, size = 0.35, col = 0xffffff, dur = 0.38) {
  let s = shocks.find(s => s.t >= 1) || shocks[0];
  if (!s.d) s.d = new Disc(2, col, 4);
  s.d.u('uCol', col); s.t = 0; s.dur = dur; s.size = size; s.x = x; s.y = y;
}
function updShocks(dt) {
  shocks.forEach(s => { if (!s.d) return; if (s.t >= 1) { s.d.hide(); return; } s.t = Math.min(1, s.t + dt / s.dur); const e = 1 - Math.pow(1 - s.t, 3); s.d.at(s.x, s.y, s.size * 2); s.d.u('uRing', e); });
}

// ---------- Écran : flash + vignette (1 quad plein écran) ----------
function buildScreen() {
  const m = new THREE.ShaderMaterial({
    transparent: true, depthTest: false, depthWrite: false,
    uniforms: { uFlash: { value: 0 }, uFlashCol: { value: new THREE.Color(1, 1, 1) }, uVig: { value: 0 }, uVigCol: { value: new THREE.Color(1, 0, 0.2) }, uSlow: { value: 0 }, uA: { value: 1 } },
    vertexShader: `varying vec2 vUV; void main(){ vUV = uv; gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.); }`,
    fragmentShader: `varying vec2 vUV; uniform float uFlash, uVig, uSlow, uA; uniform vec3 uFlashCol, uVigCol;
      void main(){ vec2 p = (vUV - 0.5) * vec2(uA, 1.0); float d = length(p) / (0.5*length(vec2(uA,1.0)));
        float vig = smoothstep(0.45, 1.05, d);
        vec3 c = uFlashCol * uFlash; float a = uFlash;
        c += uVigCol * vig * uVig; a += vig * uVig;
        // ralenti : bords bleutés + lignes de vitesse
        float lines = step(0.985, fract(atan(p.y,p.x)*14.0 + sin(atan(p.y,p.x)*91.0)*0.3)) * smoothstep(0.55, 1.0, d);
        c += vec3(0.4,0.8,1.0) * (vig*0.5 + lines*0.7) * uSlow; a += (vig*0.45 + lines*0.5) * uSlow;
        gl_FragColor = vec4(c, clamp(a,0.,1.)); }`,
  });
  FX.screenMat = m;
  FX.screen = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), m); FX.screen.renderOrder = 20; FX.screen.frustumCulled = false;
  FX.scene.add(FX.screen);
}
const scr = { flash: 0, vig: 0, vigTarget: 0, slow: 0 };
export function flash(v = 0.8, col = 0xffffff) { scr.flash = Math.max(scr.flash, v); FX.screenMat.uniforms.uFlashCol.value.set(col); }
export function vignette(v, col = 0xff1040) { scr.vig = Math.max(scr.vig, v); FX.screenMat.uniforms.uVigCol.value.set(col); }
export function setVigTarget(v) { scr.vigTarget = v; }
export function setSlowFX(v) { scr.slow = v; }

export function updateFX(dt, A) {
  updParticles(dt); updSparks(dt); updShocks(dt);
  scr.flash *= Math.pow(0.0004, dt); scr.vig += (scr.vigTarget - scr.vig) * Math.min(1, dt * 3);
  const U = FX.screenMat.uniforms; U.uFlash.value = scr.flash; U.uVig.value = scr.vig; U.uA.value = A;
  U.uSlow.value += (scr.slow - U.uSlow.value) * Math.min(1, dt * 12);
}
