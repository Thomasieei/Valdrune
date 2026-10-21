// ===== Construction des cartes : place publique et donjons =====
import { THREE, G, Instancieur, cloner, texture, texRond, texRunes, texFissures, emettre, faisceau } from './engine.js';

const CELL = 4;
const rnd = (a, b) => a + Math.random() * (b - a);
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];

function pierreMat(c1 = '#3a3046', c2 = '#2a2234') {
  const t = texture('pierre' + c1, 256, 256, (g, w) => {
    g.fillStyle = c2; g.fillRect(0, 0, w, w);
    for (let i = 0; i < 26; i++) {
      g.fillStyle = c1; g.globalAlpha = 0.5 + Math.random() * 0.5;
      const x = Math.random() * w, y = Math.random() * w, s = 30 + Math.random() * 50;
      g.beginPath(); g.moveTo(x, y); g.lineTo(x + s, y + rnd(-8, 8)); g.lineTo(x + s + rnd(-8, 8), y + s * 0.7); g.lineTo(x + rnd(-8, 8), y + s * 0.7); g.closePath(); g.fill();
    }
    g.globalAlpha = 1;
  }, { repeat: true });
  return new THREE.MeshStandardMaterial({ map: t, roughness: 0.95, color: '#ffffff' });
}

// Sol sombre au-delà des murs (pas de vide noir)
function solAbysse(groupe, cx, cz, taille) {
  const t = texture('abysse', 256, 256, (g, w) => {
    g.fillStyle = '#140d1a'; g.fillRect(0, 0, w, w);
    for (let i = 0; i < 400; i++) { g.fillStyle = `rgba(${60 + Math.random() * 40},${40 + Math.random() * 30},${70 + Math.random() * 40},${Math.random() * 0.25})`; g.fillRect(Math.random() * w, Math.random() * w, 2 + Math.random() * 6, 2 + Math.random() * 6); }
  }, { repeat: true });
  t.repeat.set(taille / 16, taille / 16);
  const m = new THREE.Mesh(new THREE.PlaneGeometry(taille, taille), new THREE.MeshStandardMaterial({ map: t, roughness: 1 }));
  m.rotation.x = -Math.PI / 2; m.position.set(cx, -0.25, cz); m.receiveShadow = true; groupe.add(m);
}

function brasero(groupe, x, z, couleur = '#ff7a2a', echelle = 1) {
  const col = cloner('column', x, 0, z, 0, 0.9 * echelle); groupe.add(col);
  const bol = new THREE.Mesh(new THREE.CylinderGeometry(0.62 * echelle, 0.36 * echelle, 0.4 * echelle, 12, 1, true), new THREE.MeshStandardMaterial({ color: '#4a3a32', metalness: 0.6, roughness: 0.5, side: THREE.DoubleSide }));
  bol.position.set(x, 1.38 * echelle, z); groupe.add(bol);
  const braise = new THREE.Mesh(new THREE.CircleGeometry(0.55 * echelle, 16), new THREE.MeshBasicMaterial({ color: couleur }));
  braise.rotation.x = -Math.PI / 2; braise.position.set(x, 1.5 * echelle, z); groupe.add(braise);
  const p = new THREE.Vector3(x, 1.55 * echelle, z);
  G.feux.push({ pos: p, couleur, force: echelle });
  G.torches.push({ pos: new THREE.Vector3(x, 2.4 * echelle, z), color: couleur, int: 30 * echelle, dist: 14 });
}

function torcheMurale(inst, x, z, rotY) {
  inst.ajouter('torch_mounted', x, 2.4, z, rotY);
  const dx = Math.sin(rotY) * 0.45, dz = Math.cos(rotY) * 0.45;
  const p = new THREE.Vector3(x + dx, 3.05, z + dz);
  G.feux.push({ pos: p, couleur: '#ff8a2a', force: 0.55 });
  G.torches.push({ pos: p.clone().add(new THREE.Vector3(dx, 0, dz)), color: '#ff9440', int: 22, dist: 12 });
}

// ======================= PLACE PUBLIQUE =======================
export function construireHub() {
  const groupe = new THREE.Group();
  G.torches = []; G.feux = [];
  const inst = new Instancieur();
  const X0 = -7, X1 = 6, Z0 = -6, Z1 = 5; // cellules
  const sol = (x, z) => x >= X0 && x <= X1 && z >= Z0 && z <= Z1;
  for (let x = X0; x <= X1; x++) for (let z = Z0; z <= Z1; z++) {
    const r = Math.random();
    inst.ajouter(r < 0.82 ? 'floor_tile_large' : r < 0.92 ? 'floor_tile_large_rocks' : 'floor_dirt_large', x * CELL + 2, 0, z * CELL + 2, Math.floor(Math.random() * 4) * Math.PI / 2);
  }
  solAbysse(groupe, 0, 0, 200);
  // Murs : nord et ouest hauts (derrière), sud et est bas (devant la caméra)
  for (let x = X0; x <= X1; x++) {
    const v = x % 3 === 0 ? 'wall_arched' : 'wall';
    inst.ajouter(v, x * CELL + 2, 0, Z0 * CELL - 0.5, 0);
    if (x % 3 === 1) torcheMurale(inst, x * CELL + 2, Z0 * CELL + 0.1, 0);
    if (x % 3 === 2) inst.ajouter(x % 2 ? 'banner_patternA_red' : 'banner_thin_red', x * CELL + 2, 0, Z0 * CELL, 0);
    inst.ajouter('barrier', x * CELL + 2, 0, (Z1 + 1) * CELL + 0.25, 0);
  }
  for (let z = Z0; z <= Z1; z++) {
    inst.ajouter(z % 3 === 0 ? 'wall_arched' : 'wall', X0 * CELL - 0.5, 0, z * CELL + 2, Math.PI / 2);
    if (z % 3 === 1) torcheMurale(inst, X0 * CELL + 0.1, z * CELL + 2, Math.PI / 2);
    if (z % 3 === 2) inst.ajouter('banner_patternB_red', X0 * CELL, 0, z * CELL + 2, Math.PI / 2);
    inst.ajouter('barrier', (X1 + 1) * CELL + 0.25, 0, z * CELL + 2, Math.PI / 2);
  }
  // piliers aux angles et le long des murs hauts
  for (let x = X0; x <= X1 + 1; x += 2) inst.ajouter('pillar_decorated', x * CELL, 0, Z0 * CELL - 0.3, 0, 0.9, 1.05, 0.9);
  for (let z = Z0 + 2; z <= Z1 + 1; z += 2) inst.ajouter('pillar_decorated', X0 * CELL - 0.3, 0, z * CELL, Math.PI / 2, 0.9, 1.05, 0.9);
  inst.ajouter('pillar', (X1 + 1) * CELL, 0, (Z1 + 1) * CELL, 0, 0.8, 0.5, 0.8);
  inst.ajouter('pillar', X0 * CELL, 0, (Z1 + 1) * CELL, 0, 0.8, 0.5, 0.8);
  inst.ajouter('pillar', (X1 + 1) * CELL, 0, Z0 * CELL, 0, 0.8, 1, 0.8);
  // décor
  const deco = [['barrel_large', -24, 18], ['barrel_small_stack', -21.5, 19.5], ['crates_stacked', -24, -6], ['rubble_half', 20, 19], ['rubble_large', -14, -21], ['sword_shield_broken', 8, -20], ['box_stacked', 22, 10], ['trunk_large_A', 3, -21]];
  for (const [k, x, z] of deco) inst.ajouter(k, x, 0, z, rnd(0, 6.28));
  inst.construire(groupe);

  // ---- Place centrale circulaire ----
  const disque = texture('place', 1024, 1024, (g) => {
    g.translate(512, 512);
    g.fillStyle = '#2b2440'; g.beginPath(); g.arc(0, 0, 510, 0, 7); g.fill();
    for (let anneau = 0; anneau < 6; anneau++) {
      const r0 = 120 + anneau * 65, r1 = r0 + 60, n = 10 + anneau * 6;
      for (let i = 0; i < n; i++) {
        const a0 = i / n * Math.PI * 2 + anneau * 0.2, a1 = (i + 1) / n * Math.PI * 2 + anneau * 0.2 - 0.02;
        const l = 26 + Math.random() * 14;
        g.fillStyle = `hsl(${255 + Math.random() * 15},${18 + Math.random() * 10}%,${l}%)`;
        g.beginPath(); g.arc(0, 0, r1, a0, a1); g.arc(0, 0, r0, a1, a0, true); g.closePath(); g.fill();
      }
    }
    g.strokeStyle = '#a07a3a'; g.lineWidth = 10; g.beginPath(); g.arc(0, 0, 505, 0, 7); g.stroke();
    g.strokeStyle = 'rgba(190,150,255,0.5)'; g.lineWidth = 4; g.beginPath(); g.arc(0, 0, 115, 0, 7); g.stroke();
  });
  const place = new THREE.Mesh(new THREE.CircleGeometry(10, 64), new THREE.MeshStandardMaterial({ map: disque, roughness: 0.9 }));
  place.rotation.x = -Math.PI / 2; place.position.y = 0.07; place.receiveShadow = true; groupe.add(place);
  // Puits de cendres au centre
  const pm = pierreMat('#4a4060', '#2c2540');
  const bassin = new THREE.Mesh(new THREE.CylinderGeometry(2.3, 2.6, 0.9, 24, 1, true), pm); bassin.position.y = 0.45; bassin.castShadow = true; groupe.add(bassin);
  const bord = new THREE.Mesh(new THREE.TorusGeometry(2.35, 0.22, 8, 32), pm); bord.rotation.x = Math.PI / 2; bord.position.y = 0.9; groupe.add(bord);
  const eau = new THREE.Mesh(new THREE.CircleGeometry(2.3, 32), new THREE.MeshBasicMaterial({ color: '#6a3cff', transparent: true, opacity: 0.7, blending: THREE.AdditiveBlending, map: texRond() }));
  eau.rotation.x = -Math.PI / 2; eau.position.y = 0.7; groupe.add(eau);
  const cristal = new THREE.Mesh(new THREE.OctahedronGeometry(0.85, 0), new THREE.MeshStandardMaterial({ color: '#b9a0ff', emissive: '#7a4cff', emissiveIntensity: 1.8, roughness: 0.2, metalness: 0.3, flatShading: true }));
  cristal.scale.y = 1.7; cristal.position.y = 3; groupe.add(cristal);
  G.anims = [(t) => { cristal.rotation.y = t * 0.6; cristal.position.y = 3 + Math.sin(t * 1.4) * 0.25; eau.material.opacity = 0.55 + 0.15 * Math.sin(t * 2); }];
  G.torches.push({ pos: new THREE.Vector3(0, 3, 0), color: '#8a5cff', int: 34, dist: 16 });
  G.feux.push({ pos: new THREE.Vector3(0, 0.8, 0), couleur: '#9a6cff', force: 0.7, type: 'magie' });
  for (const [x, z] of [[7, 7], [-7, 7], [7, -7], [-7, -7]]) brasero(groupe, x, z, '#ff7a2a', 1);

  // ---- Échoppe du marchand (sud-ouest, à gauche de l'écran) ----
  const M = new THREE.Vector3(-17, 0, 9);
  const echoppe = new THREE.Group(); echoppe.position.copy(M); echoppe.rotation.y = Math.PI / 4; groupe.add(echoppe);
  const ajouter = (k, x, y, z, r = 0, s = 1) => { const o = cloner(k, x, y, z, r, s); echoppe.add(o); return o; };
  ajouter('table_long_tablecloth_decorated_A', 0, 0, 0, Math.PI / 2);
  ajouter('shelves', 0, 0, -3.2, 0);
  ajouter('shelf_small_candles', -2.6, 0, -3.1, 0);
  ajouter('keg_decorated', 3.6, 0, -1.8, Math.PI / 2, 0.8);
  ajouter('barrel_large', -3.8, 0, -1.6, 0, 0.8);
  ajouter('barrel_small_stack', -3.6, 0, 1.4, 0.5, 0.9);
  ajouter('crates_stacked', 3.8, 0, 1.6, 0.2, 0.8);
  ajouter('coin_stack_large', -1.1, 1.0, 0.1, 0, 1.2);
  ajouter('candle_triple', 1.6, 1.0, 0.2, 0, 1.4);
  ajouter('banner_triple_red' in G.assets ? 'banner_triple_red' : 'banner_patternA_red', 2.2, 0, -3.2, 0);
  // auvent en tissu rayé
  const toile = texture('toile', 256, 256, (g, w) => { for (let i = 0; i < 8; i++) { g.fillStyle = i % 2 ? '#d9b26a' : '#8e1d1d'; g.fillRect(i * 32, 0, 32, w); } g.fillStyle = 'rgba(0,0,0,0.25)'; g.fillRect(0, w - 30, w, 30); });
  const bois = new THREE.MeshStandardMaterial({ color: '#5a3b25', roughness: 0.9 });
  for (const [px, pz] of [[-4.5, -3.8], [4.5, -3.8], [-4.5, 2.4], [4.5, 2.4]]) { const p = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.2, 4.6, 8), bois); p.position.set(px, 2.3, pz); p.castShadow = true; echoppe.add(p); }
  const auvent = new THREE.Mesh(new THREE.PlaneGeometry(10, 7.2, 8, 1), new THREE.MeshStandardMaterial({ map: toile, side: THREE.DoubleSide, roughness: 1 }));
  auvent.rotation.x = -Math.PI / 2 + 0.22; auvent.position.set(0, 4.75, -0.7); auvent.castShadow = true; echoppe.add(auvent);
  auvent.material.transparent = true;
  G.anims.push(() => { if (!G.focus) return; const d = Math.hypot(G.focus.x - M.x, G.focus.z - M.z); const cible = d < 11 ? 0.28 : 1; auvent.material.opacity += (cible - auvent.material.opacity) * 0.1; auvent.material.depthWrite = auvent.material.opacity > 0.9; });
  const lanterne = new THREE.Mesh(new THREE.SphereGeometry(0.22, 10, 8), new THREE.MeshBasicMaterial({ color: '#ffd28a' }));
  lanterne.position.set(0, 3.9, 1.2); echoppe.add(lanterne);
  G.torches.push({ pos: M.clone().add(new THREE.Vector3(1.2, 3.6, 1.2)), color: '#ffc27a', int: 34, dist: 14 });

  // ---- Le Portail Écarlate (nord-est, à droite de l'écran) ----
  const P = new THREE.Vector3(15, 0, -14);
  const portail = construirePortail(groupe, P, 0.1);

  G.scene.add(groupe);
  // Collisions
  const collisions = [
    { x: 0, z: 0, r: 2.8 }, ...[[7, 7], [-7, 7], [7, -7], [-7, -7]].map(([x, z]) => ({ x, z, r: 0.7 })),
    { x: M.x, z: M.z, r: 2.4 }, { x: M.x - 1.6, z: M.z - 1.6, r: 2.4 }, { x: M.x + 1.6, z: M.z - 1.6, r: 2.4 }, { x: M.x - 2.4, z: M.z - 2.4, r: 2.6 },
    { x: P.x, z: P.z, r: 3.2 }, { x: -24, z: 18, r: 1.2 }, { x: 22, z: 10, r: 1.2 }, { x: -24, z: -6, r: 1.3 },
  ];
  return {
    groupe, type: 'hub', nom: 'Place des Cendres',
    spawn: new THREE.Vector3(0, 0, 9),
    marchand: { pos: M.clone().add(new THREE.Vector3(-1.4, 0, -1.4)), rot: Math.PI / 4, comptoir: M.clone() },
    portail,
    marche: (x, z) => x > X0 * CELL + 0.8 && x < (X1 + 1) * CELL - 0.8 && z > Z0 * CELL + 0.8 && z < (Z1 + 1) * CELL - 0.8,
    collisions,
    bornes: { x0: X0 * CELL, x1: (X1 + 1) * CELL, z0: Z0 * CELL, z1: (Z1 + 1) * CELL },
    cellules: (x, z) => sol(x, z),
    grille: { X0, X1, Z0, Z1 },
  };
}

function construirePortail(groupe, P, rot) {
  const g = new THREE.Group(); g.position.copy(P); g.rotation.y = rot; groupe.add(g);
  const pm = pierreMat('#3c2a36', '#22161f');
  const dais = new THREE.Mesh(new THREE.CylinderGeometry(5.2, 5.6, 0.45, 40), pm); dais.position.y = 0.22; dais.receiveShadow = true; g.add(dais);
  const marche = new THREE.Mesh(new THREE.CylinderGeometry(5.9, 6.2, 0.2, 40), pm); marche.position.y = 0.1; g.add(marche);
  const runes = new THREE.Mesh(new THREE.CircleGeometry(5, 48), new THREE.MeshBasicMaterial({ map: texRunes('#ff2a2a'), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
  runes.rotation.x = -Math.PI / 2; runes.position.y = 0.47; g.add(runes);
  // fissures de lave autour
  const fiss = new THREE.Mesh(new THREE.PlaneGeometry(18, 18), new THREE.MeshBasicMaterial({ map: texFissures(), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
  fiss.rotation.x = -Math.PI / 2; fiss.position.y = 0.08; g.add(fiss);
  // piliers et arche
  for (const s of [-1, 1]) {
    const p = cloner('pillar_decorated', s * 3.4, 0.4, 0, Math.PI / 2, 1.15); g.add(p);
    const b = cloner('banner_patternA_red', s * 4.6, 0.4, -0.2, 0, 1); g.add(b);
  }
  const arche = new THREE.Mesh(new THREE.TorusGeometry(3.4, 0.55, 10, 40, Math.PI), pm); arche.position.set(0, 4.95, 0); arche.castShadow = true; g.add(arche);
  const cle = new THREE.Mesh(new THREE.OctahedronGeometry(0.6), new THREE.MeshStandardMaterial({ color: '#ff3a3a', emissive: '#ff1a1a', emissiveIntensity: 2.4, flatShading: true }));
  cle.position.set(0, 8.4, 0.2); cle.scale.y = 1.5; g.add(cle);
  // anneau d'énergie
  const anneau = new THREE.Mesh(new THREE.TorusGeometry(2.75, 0.16, 12, 64), new THREE.MeshStandardMaterial({ color: '#ff5a3a', emissive: '#ff2a1a', emissiveIntensity: 3 }));
  anneau.position.set(0, 3.55, 0); g.add(anneau);
  // vortex (shader)
  const vortex = new THREE.Mesh(new THREE.CircleGeometry(2.65, 64), new THREE.ShaderMaterial({
    uniforms: { uT: { value: 0 } }, transparent: true, depthWrite: false, side: THREE.DoubleSide,
    vertexShader: `varying vec2 vUv; void main(){ vUv=uv; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);} `,
    fragmentShader: `uniform float uT; varying vec2 vUv;
      float h(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
      float n(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y); }
      void main(){ vec2 p=vUv*2.0-1.0; float r=length(p); float a=atan(p.y,p.x);
        float sw=a+ r*5.0 - uT*1.6; vec2 q=vec2(cos(sw),sin(sw))*r*3.0;
        float f=n(q*2.0+uT*0.3)*0.6+n(q*5.0-uT*0.5)*0.4;
        float core=smoothstep(0.55,0.0,r); float rim=smoothstep(0.75,1.0,r);
        vec3 c=mix(vec3(0.05,0.0,0.02),vec3(0.9,0.06,0.04),f*1.2); c+=vec3(1.0,0.5,0.25)*core*core*0.9; c+=vec3(1.0,0.2,0.1)*rim*1.4;
        float al=smoothstep(1.0,0.96,r); gl_FragColor=vec4(c*1.3,al*0.96); }`,
  }));
  vortex.position.set(0, 3.55, 0); g.add(vortex);
  const halo = new THREE.Sprite(new THREE.SpriteMaterial({ map: texRond(), color: '#ff2a1a', blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, opacity: 0.6 }));
  halo.scale.set(11, 11, 1); halo.position.set(0, 3.55, -0.3); g.add(halo);
  // éclats de cristal en orbite
  const eclats = [];
  for (let i = 0; i < 7; i++) {
    const e = new THREE.Mesh(new THREE.OctahedronGeometry(0.22 + Math.random() * 0.16), new THREE.MeshStandardMaterial({ color: '#ff6a5a', emissive: '#ff1a1a', emissiveIntensity: 2, flatShading: true }));
    e.userData = { a: i / 7 * Math.PI * 2, r: 4 + Math.random() * 0.8, h: 1.5 + Math.random() * 4, v: 0.4 + Math.random() * 0.3 }; g.add(e); eclats.push(e);
  }
  // braseros rouges et bougies
  for (const [x, z] of [[-4.2, 3.4], [4.2, 3.4]]) {
    const w = new THREE.Vector3(x, 0, z).applyAxisAngle(new THREE.Vector3(0, 1, 0), rot).add(P);
    brasero(groupe, w.x, w.z, '#ff2a1a', 1.15);
  }
  for (const [x, z] of [[-2.2, 2.4], [2.2, 2.4], [-1.2, 3.0], [1.4, 3.1]]) g.add(cloner('candle_triple', x, 0.45, z, Math.random() * 6, 1.3));
  G.torches.push({ pos: P.clone().add(new THREE.Vector3(0, 3.5, 0)), color: '#ff2a1a', int: 60, dist: 18 });
  const centre = new THREE.Vector3(0, 3.55, 0).applyAxisAngle(new THREE.Vector3(0, 1, 0), rot).add(P);
  G.anims.push((t, dt) => {
    vortex.material.uniforms.uT.value = t;
    runes.rotation.z = t * 0.12; anneau.rotation.z = t * 0.4; halo.material.opacity = 0.5 + 0.15 * Math.sin(t * 3);
    cle.rotation.y = t * 1.2;
    eclats.forEach(e => { const u = e.userData; const a = u.a + t * u.v; e.position.set(Math.cos(a) * u.r, u.h + Math.sin(t * 2 + u.a) * 0.4, Math.sin(a) * u.r * 0.5); e.rotation.x = t; e.rotation.y = t * 1.3; });
    if (Math.random() < dt * 40) {
      const a = Math.random() * 6.28, r = 2.7;
      const p = new THREE.Vector3(Math.cos(a) * r, 3.55 + Math.sin(a) * r, 0).applyAxisAngle(new THREE.Vector3(0, 1, 0), rot).add(P);
      emettre(p, { n: 1, c1: '#ff6a3a', c2: '#ff1a00', vit: 0.6, vie: 1.0, taille: 0.35, frein: 0.5 });
    }
    if (Math.random() < dt * 14) emettre(new THREE.Vector3(P.x + rnd(-5, 5), 0.5, P.z + rnd(-5, 5)), { n: 1, c1: '#ff4a1a', c2: '#ffb36a', dir: new THREE.Vector3(0, 1, 0), vit: 1.6, disp: 0.3, vie: 2.2, taille: 0.22, frein: 0.2 });
  });
  return { pos: P, centre, groupe: g };
}

// ======================= DONJON =======================
export function construireDonjon(mode) {
  const groupe = new THREE.Group();
  G.torches = []; G.feux = []; G.anims = [];
  const W = 74, H = 74;
  const grille = new Uint8Array(W * H); // 0 vide, 1 sol, 2 couloir
  const zone = new Int16Array(W * H).fill(-1);
  const salles = [];
  const set = (x, z, v = 1) => { if (x >= 0 && z >= 0 && x < W && z < H && !grille[z * W + x]) grille[z * W + x] = v; };
  const solA = (x, z) => x >= 0 && z >= 0 && x < W && z < H && grille[z * W + x] > 0;
  const salle = (cx, cz, tx, tz, type, extra = {}) => {
    const s = { cx, cz, tx, tz, type, id: salles.length, ...extra };
    for (let x = cx - Math.floor(tx / 2); x < cx - Math.floor(tx / 2) + tx; x++)
      for (let z = cz - Math.floor(tz / 2); z < cz - Math.floor(tz / 2) + tz; z++) { set(x, z, 1); zone[z * W + x] = s.id; }
    s.centre = new THREE.Vector3(cx * CELL + 2 - (tx % 2 ? 0 : 2), 0, cz * CELL + 2 - (tz % 2 ? 0 : 2));
    salles.push(s); return s;
  };
  const couloir = (x1, z1, x2, z2) => {
    if (z1 === z2) for (let x = Math.min(x1, x2); x <= Math.max(x1, x2); x++) { set(x, z1, 2); set(x, z1 - 1, 2); }
    else for (let z = Math.min(z1, z2); z <= Math.max(z1, z2); z++) { set(x1, z, 2); set(x1 - 1, z, 2); }
  };
  // 3x3 salles reliées en treillis
  const N = [22, 37, 52];
  const noeuds = [];
  for (let j = 0; j < 3; j++) for (let i = 0; i < 3; i++) {
    const t = 5 + Math.floor(Math.random() * 3);
    noeuds.push(salle(N[i], N[j], t, 5 + Math.floor(Math.random() * 3), 'normale', { i, j }));
  }
  // salle de départ (ouest) et 4 salles de boss
  const depart = salle(6, 52, 5, 5, 'depart');
  const bossPos = [[22, 7], [67, 22], [67, 52], [37, 67]];
  const bossSalles = bossPos.map(([x, z], k) => salle(x, z, 8, 8, 'boss', { boss: k }));
  // couloirs
  for (let j = 0; j < 3; j++) for (let i = 0; i < 3; i++) {
    if (i < 2) couloir(N[i], N[j], N[i + 1], N[j]);
    if (j < 2) couloir(N[i], N[j], N[i], N[j + 1]);
  }
  couloir(6, 52, 22, 52);
  couloir(22, 7, 22, 22); couloir(52, 22, 67, 22); couloir(52, 52, 67, 52); couloir(37, 52, 37, 67);

  // --- Sol ---
  const inst = new Instancieur();
  for (let z = 0; z < H; z++) for (let x = 0; x < W; x++) {
    const v = grille[z * W + x]; if (!v) continue;
    const r = Math.random();
    const k = v === 2 ? (r < 0.5 ? 'floor_dirt_large' : 'floor_tile_large') : (r < 0.8 ? 'floor_tile_large' : r < 0.9 ? 'floor_tile_large_rocks' : 'floor_dirt_large');
    inst.ajouter(k, x * CELL + 2, 0, z * CELL + 2, Math.floor(Math.random() * 4) * Math.PI / 2);
  }
  solAbysse(groupe, W * 2, H * 2, 420);
  // --- Murs ---
  const sommets = new Map();
  const noterSommet = (x, z, d) => { const k = x + ',' + z; if (!sommets.has(k)) sommets.set(k, new Set()); sommets.get(k).add(d); };
  let compteur = 0;
  const torchesPos = [];
  for (let z = 0; z < H; z++) for (let x = 0; x < W; x++) {
    if (!solA(x, z)) continue;
    const enSalle = grille[z * W + x] === 1;
    if (!solA(x, z - 1)) { // nord : mur haut
      const r = Math.random();
      inst.ajouter(r < 0.7 ? 'wall' : r < 0.85 ? 'wall_arched' : 'wall_broken', x * CELL + 2, 0, z * CELL - 0.5, 0);
      noterSommet(x, z, 'h'); noterSommet(x + 1, z, 'h');
      if (++compteur % 3 === 0) torchesPos.push([x * CELL + 2, z * CELL + 0.1, 0]);
      else if (enSalle && Math.random() < 0.18) inst.ajouter(pick(['banner_patternA_red', 'banner_thin_red', 'banner_patternB_red']), x * CELL + 2, 0, z * CELL, 0);
    }
    if (!solA(x - 1, z)) { // ouest : mur haut
      const r = Math.random();
      inst.ajouter(r < 0.75 ? 'wall' : r < 0.9 ? 'wall_arched' : 'wall_broken', x * CELL - 0.5, 0, z * CELL + 2, Math.PI / 2);
      noterSommet(x, z, 'v'); noterSommet(x, z + 1, 'v');
      if (++compteur % 3 === 0) torchesPos.push([x * CELL + 0.1, z * CELL + 2, Math.PI / 2]);
    }
    if (!solA(x, z + 1)) inst.ajouter('barrier', x * CELL + 2, 0, (z + 1) * CELL + 0.25, 0);
    if (!solA(x + 1, z)) inst.ajouter('barrier', (x + 1) * CELL + 0.25, 0, z * CELL + 2, Math.PI / 2);
  }
  for (const [k, ds] of sommets) { if (ds.size === 2) { const [x, z] = k.split(',').map(Number); inst.ajouter('pillar', x * CELL - 0.3, 0, z * CELL - 0.3, 0, 0.75, 1.02, 0.75); } }
  for (const [x, z, r] of torchesPos) torcheMurale(inst, x, z, r);

  // --- Décor des salles ---
  const collisions = [];
  const decor = ['barrel_large', 'barrel_small_stack', 'crates_stacked', 'box_stacked', 'rubble_half', 'sword_shield_broken', 'trunk_large_A', 'candle_triple'];
  for (const s of salles) {
    if (s.type === 'boss' || s.type === 'depart') continue;
    const n = 2 + Math.floor(Math.random() * 3);
    for (let i = 0; i < n; i++) {
      const x0 = (s.cx - Math.floor(s.tx / 2)) * CELL, z0 = (s.cz - Math.floor(s.tz / 2)) * CELL;
      const coin = Math.random() < 0.5;
      const x = x0 + (coin ? 1.6 : rnd(2, s.tx * CELL - 2)), z = z0 + (coin ? rnd(2, s.tz * CELL - 2) : 1.6);
      const k = pick(decor);
      inst.ajouter(k, x, 0, z, rnd(0, 6.28), 0.9, 0.9, 0.9);
      if (k !== 'candle_triple' && k !== 'sword_shield_broken') collisions.push({ x, z, r: 1.0 });
    }
    if (s.type === 'normale' && Math.random() < 0.55) {
      const f = new THREE.Mesh(new THREE.PlaneGeometry(14, 14), new THREE.MeshBasicMaterial({ map: texFissures(), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, opacity: 0.85 }));
      f.rotation.x = -Math.PI / 2; f.rotation.z = Math.random() * 6; f.position.set(s.centre.x + rnd(-3, 3), 0.09, s.centre.z + rnd(-3, 3)); groupe.add(f);
      G.torches.push({ pos: f.position.clone().setY(1.2), color: '#ff4a10', int: 18, dist: 10 });
    }
  }
  // salles de boss : colonnes, braseros, cercle de runes
  const coffresPos = [];
  for (const s of bossSalles) {
    const c = s.centre;
    for (let i = 0; i < 8; i++) {
      const a = i / 8 * Math.PI * 2 + Math.PI / 8;
      inst.ajouter('column', c.x + Math.cos(a) * 11, 0, c.z + Math.sin(a) * 11, 0, 1.3, 1.6, 1.3);
      collisions.push({ x: c.x + Math.cos(a) * 11, z: c.z + Math.sin(a) * 11, r: 0.6 });
    }
    const runes = new THREE.Mesh(new THREE.CircleGeometry(7.5, 48), new THREE.MeshBasicMaterial({ map: texRunes('#ff3a2a'), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, opacity: 0.55 }));
    runes.rotation.x = -Math.PI / 2; runes.position.set(c.x, 0.08, c.z); groupe.add(runes);
    G.anims.push((t) => { runes.rotation.z = t * 0.08; });
    for (const [dx, dz] of [[-9, -9], [9, -9], [-9, 9], [9, 9]]) brasero(groupe, c.x + dx, c.z + dz, '#ff3a1a', 1.1);
    // le coffre se tient côté nord-ouest (bien visible)
    coffresPos.push(new THREE.Vector3(c.x - 6.5, 0, c.z - 6.5));
    collisions.push({ x: c.x - 6.5, z: c.z - 6.5, r: 1.2 });
  }
  inst.construire(groupe);
  G.scene.add(groupe);

  // --- Apparitions de monstres ---
  const packs = [];
  for (const s of noeuds) {
    const n = 3 + Math.floor(Math.random() * 3);
    const pts = [];
    for (let i = 0; i < n; i++) pts.push(new THREE.Vector3(s.centre.x + rnd(-5, 5), 0, s.centre.z + rnd(-5, 5)));
    packs.push({ salle: s.id, pts });
  }
  // quelques squelettes isolés dans les couloirs
  for (let k = 0; k < 6; k++) {
    for (let essai = 0; essai < 40; essai++) {
      const x = Math.floor(Math.random() * W), z = Math.floor(Math.random() * H);
      if (grille[z * W + x] === 2) { packs.push({ salle: -1, pts: [new THREE.Vector3(x * CELL + 2, 0, z * CELL + 2)] }); break; }
    }
  }
  const marche = (x, z) => {
    const cx = Math.floor(x / CELL), cz = Math.floor(z / CELL);
    if (!solA(cx, cz)) return false;
    const fx = x - cx * CELL, fz = z - cz * CELL, m = 0.7;
    if (fz < m && !solA(cx, cz - 1)) return false;
    if (fx < m && !solA(cx - 1, cz)) return false;
    if (fz > CELL - m && !solA(cx, cz + 1)) return false;
    if (fx > CELL - m && !solA(cx + 1, cz)) return false;
    return true;
  };
  return {
    groupe, type: 'donjon', nom: mode.lieu, mode,
    spawn: depart.centre.clone(), sortie: depart.centre.clone().add(new THREE.Vector3(-4, 0, 0)),
    salles, bossSalles, packs, coffresPos, marche, collisions,
    cellules: (x, z) => solA(x, z), grilleW: W, grilleH: H, grille,
    zoneDe: (x, z) => { const cx = Math.floor(x / CELL), cz = Math.floor(z / CELL); return (cx >= 0 && cz >= 0 && cx < W && cz < H) ? zone[cz * W + cx] : -1; },
  };
}

export function majFeux(dt) {
  for (const f of G.feux) {
    if (Math.random() < dt * 22 * f.force) {
      if (f.type === 'magie') emettre(f.pos, { n: 1, c1: '#b48cff', c2: '#6a3cff', dir: new THREE.Vector3(0, 1, 0), vit: 1.2, disp: 0.6, rayon: 1.8, vie: 1.6, taille: 0.3, frein: 0.4 });
      else emettre(f.pos, { n: 1, c1: f.couleur === '#ff8a2a' || f.couleur === '#ff7a2a' ? '#ffcf6a' : '#ff8a5a', c2: f.couleur, dir: new THREE.Vector3(0, 1, 0), vit: 1.6 * f.force + 0.6, disp: 0.35, rayon: 0.25 * f.force, vie: 0.55, taille: 0.55 * f.force + 0.15, tailleFin: 0.05, frein: 0.6 });
    }
  }
}
