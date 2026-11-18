// Rendu « moderne » léger pour téléphone :
//  • sol texturé : 4 textures de détail générées (herbe, terre, roche, pavés) mêlées selon le terrain, + variation à grande échelle
//  • ciel : dôme en dégradé avec halo du soleil et nuages qui dérivent (un seul shader, pas de texture)
//  • eau : reflets ondulants, plus claire sur les bords, scintillement
//  • vent : herbes, fleurs, fougères, buissons et feuillages oscillent
// Tout est procédural : rien à télécharger, quelques Mo de mémoire vidéo au plus.
import { THREE, G } from './moteur.js';

export const U = { temps: { value: 0 } }; // temps partagé par tous les shaders animés
const rnd = (a, b) => a + Math.random() * (b - a);

// ---------- textures de détail (niveaux de gris centrés sur 0,5 : elles modulent la couleur peinte du sol) ----------
function toile(n = 512) { const c = document.createElement('canvas'); c.width = c.height = n; const g = c.getContext('2d'); g.fillStyle = '#808080'; g.fillRect(0, 0, n, n); return [c, g, n]; }
const gris = (v, a = 1) => `rgba(${v},${v},${v},${a})`;
function enTexture(c) { const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.anisotropy = 4; t.generateMipmaps = true; t.minFilter = THREE.LinearMipmapLinearFilter; return t; }
// dessine aussi de l'autre côté des bords : textures sans couture
const tore = (n, x, y, f) => { for (const dx of [-n, 0, n]) for (const dy of [-n, 0, n]) f(x + dx, y + dy); };
function texHerbe() {
  const [c, g, n] = toile();
  for (let i = 0; i < 9000; i++) { const x = rnd(0, n), y = rnd(0, n), l = rnd(4, 11), a = rnd(-0.5, 0.5) - Math.PI / 2, v = rnd(70, 190) | 0; g.strokeStyle = gris(v, 0.55); g.lineWidth = rnd(0.8, 1.8); tore(n, x, y, (X, Y) => { g.beginPath(); g.moveTo(X, Y); g.lineTo(X + Math.cos(a) * l, Y + Math.sin(a) * l); g.stroke(); }); }
  for (let i = 0; i < 60; i++) { const x = rnd(0, n), y = rnd(0, n), r = rnd(12, 40); tore(n, x, y, (X, Y) => { const d = g.createRadialGradient(X, Y, 0, X, Y, r); d.addColorStop(0, gris(Math.random() < 0.5 ? 100 : 160, 0.25)); d.addColorStop(1, gris(128, 0)); g.fillStyle = d; g.fillRect(X - r, Y - r, 2 * r, 2 * r); }); }
  return enTexture(c);
}
function texTerre() {
  const [c, g, n] = toile();
  for (let i = 0; i < 14000; i++) { const x = rnd(0, n), y = rnd(0, n); g.fillStyle = gris(rnd(80, 180) | 0, 0.35); g.fillRect(x, y, rnd(1, 3), rnd(1, 3)); }
  for (let i = 0; i < 260; i++) { const x = rnd(0, n), y = rnd(0, n), r = rnd(1.5, 5); tore(n, x, y, (X, Y) => { g.fillStyle = gris(60, 0.5); g.beginPath(); g.ellipse(X + 1, Y + 1.5, r, r * 0.75, 0, 0, 6.29); g.fill(); g.fillStyle = gris(rnd(150, 200) | 0, 0.9); g.beginPath(); g.ellipse(X, Y, r, r * 0.75, rnd(0, 3), 0, 6.29); g.fill(); }); }
  return enTexture(c);
}
function texRoche() {
  const [c, g, n] = toile();
  for (let i = 0; i < 80; i++) { const x = rnd(0, n), y = rnd(0, n), r = rnd(20, 70); tore(n, x, y, (X, Y) => { const d = g.createRadialGradient(X, Y, 0, X, Y, r); d.addColorStop(0, gris(rnd(110, 170) | 0, 0.5)); d.addColorStop(1, gris(128, 0)); g.fillStyle = d; g.fillRect(X - r, Y - r, 2 * r, 2 * r); }); }
  g.strokeStyle = gris(50, 0.55); for (let i = 0; i < 70; i++) { let x = rnd(0, n), y = rnd(0, n); g.lineWidth = rnd(0.8, 2); g.beginPath(); g.moveTo(x, y); for (let k = 0; k < 6; k++) { x += rnd(-18, 18); y += rnd(-18, 18); g.lineTo(x, y); } g.stroke(); }
  for (let i = 0; i < 6000; i++) { g.fillStyle = gris(rnd(90, 170) | 0, 0.3); g.fillRect(rnd(0, n), rnd(0, n), 2, 2); }
  return enTexture(c);
}
function texPaves() { // pavés irréguliers et joints sombres (grille déformée)
  const [c, g, n] = toile(); g.fillStyle = gris(55); g.fillRect(0, 0, n, n); const k = 8, s = n / k;
  for (let i = 0; i < k; i++) for (let j = 0; j < k; j++) { const dec = (j % 2) * s / 2, x = i * s + dec + rnd(-3, 3), y = j * s + rnd(-3, 3), w = s - rnd(5, 9), h = s - rnd(5, 9), v = rnd(115, 185) | 0;
    tore(n, x, y, (X, Y) => { g.fillStyle = gris(v); g.beginPath(); g.roundRect(X + 3, Y + 3, w, h, rnd(8, 16)); g.fill(); const d = g.createLinearGradient(X, Y, X, Y + h); d.addColorStop(0, gris(255, 0.18)); d.addColorStop(1, gris(0, 0.22)); g.fillStyle = d; g.fill(); }); }
  for (let i = 0; i < 5000; i++) { g.fillStyle = gris(rnd(70, 200) | 0, 0.2); g.fillRect(rnd(0, n), rnd(0, n), 1.5, 1.5); }
  return enTexture(c);
}

// ---------- sol ----------
export function materiauSol() {
  const T = { tH: { value: texHerbe() }, tT: { value: texTerre() }, tR: { value: texRoche() }, tP: { value: texPaves() } };
  const m = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.95 });
  m.onBeforeCompile = (s) => {
    Object.assign(s.uniforms, T);
    s.vertexShader = 'attribute vec4 poids;\nvarying vec4 vPoids;\nvarying vec2 vSol;\n' + s.vertexShader.replace('#include <begin_vertex>', '#include <begin_vertex>\nvPoids = poids; vSol = position.xz;');
    s.fragmentShader = 'uniform sampler2D tH, tT, tR, tP;\nvarying vec4 vPoids;\nvarying vec2 vSol;\n' + s.fragmentShader.replace('#include <color_fragment>', `#include <color_fragment>
      vec4 w = vPoids / max(0.001, vPoids.x + vPoids.y + vPoids.z + vPoids.w);
      float d = texture2D(tH, vSol * 0.33).r * w.x + texture2D(tT, vSol * 0.28).r * w.y + texture2D(tR, vSol * 0.12).r * w.z + texture2D(tP, vSol * 0.36).r * w.w;
      float macro = texture2D(tH, vSol * 0.012).r * 0.5 + texture2D(tR, vSol * 0.031).r * 0.5;
      diffuseColor.rgb *= (0.3 + d * 1.4) * (0.74 + macro * 0.52);`);
  };
  return m;
}

// ---------- ciel ----------
export function ciel() {
  const m = new THREE.ShaderMaterial({ side: THREE.BackSide, depthWrite: false, fog: false, uniforms: { temps: U.temps, soleil: { value: new THREE.Vector3(0.45, 0.62, 0.35).normalize() } },
    vertexShader: 'varying vec3 vD; void main(){ vD = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); gl_Position.z = gl_Position.w; }',
    fragmentShader: `varying vec3 vD; uniform float temps; uniform vec3 soleil;
      float h(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
      float bruit(vec2 p){ vec2 i = floor(p), f = fract(p); f = f*f*(3.0-2.0*f); return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
      void main(){ float y = max(vD.y, 0.0);
        vec3 col = mix(vec3(0.80,0.88,0.95), vec3(0.33,0.56,0.86), pow(y, 0.55));
        float s = max(dot(vD, soleil), 0.0); col += vec3(1.0,0.86,0.6) * (pow(s, 8.0) * 0.35 + pow(s, 400.0) * 2.0);
        vec2 p = vD.xz / (vD.y + 0.18) * 1.6 + vec2(temps * 0.012, temps * 0.004);
        float n = bruit(p) * 0.55 + bruit(p * 2.1) * 0.3 + bruit(p * 4.3) * 0.15; float nuage = smoothstep(0.52, 0.78, n) * smoothstep(0.02, 0.25, vD.y);
        col = mix(col, vec3(1.0,0.99,0.97) - (1.0 - n) * 0.12, nuage * 0.85);
        gl_FragColor = vec4(col, 1.0);
        #include <colorspace_fragment>
      }` });
  const d = new THREE.Mesh(new THREE.SphereGeometry(500, 24, 12), m); d.renderOrder = -10; d.frustumCulled = false; return d;
}

// ---------- eau ----------
export function animerEau(mat) {
  mat.onBeforeCompile = (s) => {
    s.uniforms.temps = U.temps;
    s.vertexShader = 'varying vec2 vE;\n' + s.vertexShader.replace('#include <begin_vertex>', '#include <begin_vertex>\nvE = (modelMatrix * vec4(position,1.0)).xz;');
    s.fragmentShader = 'uniform float temps;\nvarying vec2 vE;\n' + s.fragmentShader
      .replace('#include <normal_fragment_maps>', `#include <normal_fragment_maps>
        vec2 q = vE * 0.35; float t = temps;
        vec3 o = vec3(sin(q.x * 2.1 + t * 1.3) + sin(q.x * 3.7 - q.y * 2.3 + t * 1.9) * 0.6, 0.0, cos(q.y * 2.4 - t * 1.1) + sin((q.x + q.y) * 4.1 + t * 2.3) * 0.5) * 0.09;
        normal = normalize(normal + (viewMatrix * vec4(o, 0.0)).xyz);`)
      .replace('#include <color_fragment>', `#include <color_fragment>
        float scint = pow(max(0.0, sin(vE.x * 1.3 + sin(vE.y * 0.7 + temps) * 2.0 + temps * 1.4) * sin(vE.y * 1.1 + sin(vE.x * 0.9 - temps * 0.8) * 2.0 - temps * 1.1)), 40.0);
        diffuseColor.rgb += scint * 0.35;`);
  };
}

// ---------- vent ----------
export function venter(mat, force = 1) {
  if (!mat || mat.userData.vent) return; mat.userData.vent = true;
  mat.onBeforeCompile = (s) => {
    s.uniforms.temps = U.temps;
    s.vertexShader = 'uniform float temps;\n' + s.vertexShader.replace('#include <begin_vertex>', `#include <begin_vertex>
      #ifdef USE_INSTANCING
        vec3 base = instanceMatrix[3].xyz;
      #else
        vec3 base = vec3(0.0);
      #endif
      float k = max(0.0, transformed.y) * ${(0.06 * force).toFixed(3)};
      transformed.x += sin(temps * 1.6 + base.x * 0.35 + base.z * 0.2) * k;
      transformed.z += cos(temps * 1.25 + base.z * 0.3) * k * 0.6;`);
  };
  mat.needsUpdate = true;
}

let dome = null;
export function initRendu() { dome = ciel(); G.scene.add(dome); G.scene.background = null; if (G.scene.fog) G.scene.fog.color.set('#c6dbec'); }
export function majRendu(dt) { U.temps.value += dt; if (dome) dome.position.copy(G.camera.position); }
