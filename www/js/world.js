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
  const deco = [['barrel_large', -24, 18], ['barrel_small_stack', -21.5, 19.5], ['crates_stacked', -24, -6], ['rubble_half', 20, 19], ['sword_shield_broken', 8, -20], ['trunk_large_A', 3, -21]];
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
  const portail = construirePortail(groupe, P, 0.1, THEME_ROUGE);
  // ---- Le Portail de l'Arène (nord-ouest) ----
  const PA = new THREE.Vector3(-17, 0, -13);
  const portailArene = construirePortail(groupe, PA, 0.35, THEME_VIOLET);
  // ---- Le petit portail doré des Îles (sud-est) et son passeur ----
  const PI = new THREE.Vector3(18, 0, 13);
  const portailIle = construirePortail(groupe, PI, -0.5, THEME_JAUNE, 0.5);
  const passeur = { pos: new THREE.Vector3(13.2, 0, 15.6), rot: -0.9 };
  for (const [k, x, z, r2, s2] of [['barrel_large', 21.8, 16.8, 0, 0.7], ['crates_stacked', 22.5, 9.6, 0.4, 0.7]]) groupe.add(cloner(k, x, 0, z, r2, s2));

  G.scene.add(groupe);
  // Collisions
  const collisions = [
    { x: 0, z: 0, r: 2.8 }, ...[[7, 7], [-7, 7], [7, -7], [-7, -7]].map(([x, z]) => ({ x, z, r: 0.7 })),
    { x: M.x, z: M.z, r: 2.4 }, { x: M.x - 1.6, z: M.z - 1.6, r: 2.4 }, { x: M.x + 1.6, z: M.z - 1.6, r: 2.4 }, { x: M.x - 2.4, z: M.z - 2.4, r: 2.6 },
    { x: P.x, z: P.z, r: 3.2 }, { x: PA.x, z: PA.z, r: 3.2 }, { x: PI.x, z: PI.z, r: 1.8 }, { x: 21.8, z: 16.8, r: 0.9 }, { x: 22.5, z: 9.6, r: 1.0 }, { x: -24, z: 18, r: 1.2 }, { x: -24, z: -6, r: 1.3 },
  ];
  return {
    groupe, type: 'hub', nom: 'Place des Cendres',
    spawn: new THREE.Vector3(0, 0, 9),
    marchand: { pos: M.clone().add(new THREE.Vector3(-1.4, 0, -1.4)), rot: Math.PI / 4, comptoir: M.clone() },
    portail, portailArene, portailIle, passeur,
    marche: (x, z) => x > X0 * CELL + 0.8 && x < (X1 + 1) * CELL - 0.8 && z > Z0 * CELL + 0.8 && z < (Z1 + 1) * CELL - 0.8,
    collisions,
    bornes: { x0: X0 * CELL, x1: (X1 + 1) * CELL, z0: Z0 * CELL, z1: (Z1 + 1) * CELL },
    cellules: (x, z) => sol(x, z),
    grille: { X0, X1, Z0, Z1 },
  };
}

const THEME_ROUGE = { runes: '#ff2a2a', cle: '#ff3a3a', cleE: '#ff1a1a', anneau: '#ff5a3a', anneauE: '#ff2a1a', halo: '#ff2a1a', eclat: '#ff6a5a', eclatE: '#ff1a1a', brasero: '#ff2a1a', lumiere: '#ff2a1a', p1: '#ff6a3a', p2: '#ff1a00', s1: '#ff4a1a', s2: '#ffb36a', fissures: true,
  v1: 'vec3(0.05,0.0,0.02)', v2: 'vec3(0.9,0.06,0.04)', v3: 'vec3(1.0,0.5,0.25)', v4: 'vec3(1.0,0.2,0.1)', pierre: ['#3c2a36', '#22161f'] };
const THEME_JAUNE = { runes: '#ffcf3a', cle: '#ffe08a', cleE: '#ffaa00', anneau: '#ffd25a', anneauE: '#ff9a00', halo: '#ffb81a', eclat: '#fff0a0', eclatE: '#ffb000', brasero: '#ffb52a', lumiere: '#ffc04a', p1: '#fff0a0', p2: '#ffaa00', s1: '#ffd25a', s2: '#ffffff', fissures: false,
  v1: 'vec3(0.06,0.04,0.0)', v2: 'vec3(1.0,0.62,0.05)', v3: 'vec3(1.0,0.95,0.7)', v4: 'vec3(1.0,0.75,0.2)', pierre: ['#4a4030', '#2a2418'] };
export { THEME_JAUNE };
const THEME_VIOLET = { runes: '#b05aff', cle: '#c88aff', cleE: '#8a2aff', anneau: '#b47aff', anneauE: '#7a2aff', halo: '#8a3aff', eclat: '#d0a0ff', eclatE: '#7a1aff', brasero: '#9a4aff', lumiere: '#8a3aff', p1: '#d09aff', p2: '#6a1aff', s1: '#b07aff', s2: '#ffc8ff', fissures: false,
  v1: 'vec3(0.02,0.0,0.06)', v2: 'vec3(0.45,0.08,0.95)', v3: 'vec3(0.9,0.6,1.0)', v4: 'vec3(0.6,0.25,1.0)', pierre: ['#2e2a40', '#18141f'] };

function construirePortail(groupe, P, rot, th = THEME_ROUGE, ech = 1) {
  const g = new THREE.Group(); g.position.copy(P); g.rotation.y = rot; g.scale.setScalar(ech); groupe.add(g);
  const pm = pierreMat(th.pierre[0], th.pierre[1]);
  const dais = new THREE.Mesh(new THREE.CylinderGeometry(5.2, 5.6, 0.45, 40), pm); dais.position.y = 0.22; dais.receiveShadow = true; g.add(dais);
  const marche = new THREE.Mesh(new THREE.CylinderGeometry(5.9, 6.2, 0.2, 40), pm); marche.position.y = 0.1; g.add(marche);
  const runes = new THREE.Mesh(new THREE.CircleGeometry(5, 48), new THREE.MeshBasicMaterial({ map: texRunes(th.runes), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
  runes.rotation.x = -Math.PI / 2; runes.position.y = 0.47; g.add(runes);
  // fissures de lave autour
  const fiss = new THREE.Mesh(new THREE.PlaneGeometry(18, 18), new THREE.MeshBasicMaterial({ map: texFissures(), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
  fiss.rotation.x = -Math.PI / 2; fiss.position.y = 0.08; if (th.fissures) g.add(fiss);
  if (!th.fissures) { const r2 = new THREE.Mesh(new THREE.RingGeometry(6.6, 7.2, 64), new THREE.MeshBasicMaterial({ color: th.runes, transparent: true, opacity: 0.5, blending: THREE.AdditiveBlending, depthWrite: false })); r2.rotation.x = -Math.PI / 2; r2.position.y = 0.09; g.add(r2); }
  // piliers et arche
  for (const s of [-1, 1]) {
    const p = cloner('pillar_decorated', s * 3.4, 0.4, 0, Math.PI / 2, 1.15); g.add(p);
    const b = cloner('banner_patternA_red', s * 4.6, 0.4, -0.2, 0, 1); g.add(b);
  }
  const arche = new THREE.Mesh(new THREE.TorusGeometry(3.4, 0.55, 10, 40, Math.PI), pm); arche.position.set(0, 4.95, 0); arche.castShadow = true; g.add(arche);
  const cle = new THREE.Mesh(new THREE.OctahedronGeometry(0.6), new THREE.MeshStandardMaterial({ color: th.cle, emissive: th.cleE, emissiveIntensity: 2.4, flatShading: true }));
  cle.position.set(0, 8.4, 0.2); cle.scale.y = 1.5; g.add(cle);
  // anneau d'énergie
  const anneau = new THREE.Mesh(new THREE.TorusGeometry(2.75, 0.16, 12, 64), new THREE.MeshStandardMaterial({ color: th.anneau, emissive: th.anneauE, emissiveIntensity: 3 }));
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
        vec3 c=mix(${th.v1},${th.v2},f*1.2); c+=${th.v3}*core*core*0.9; c+=${th.v4}*rim*1.4;
        float al=smoothstep(1.0,0.96,r); gl_FragColor=vec4(c*1.3,al*0.96); }`,
  }));
  vortex.position.set(0, 3.55, 0); g.add(vortex);
  const halo = new THREE.Sprite(new THREE.SpriteMaterial({ map: texRond(), color: th.halo, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, opacity: 0.6 }));
  halo.scale.set(11, 11, 1); halo.position.set(0, 3.55, -0.3); g.add(halo);
  // éclats de cristal en orbite
  const eclats = [];
  for (let i = 0; i < 7; i++) {
    const e = new THREE.Mesh(new THREE.OctahedronGeometry(0.22 + Math.random() * 0.16), new THREE.MeshStandardMaterial({ color: th.eclat, emissive: th.eclatE, emissiveIntensity: 2, flatShading: true }));
    e.userData = { a: i / 7 * Math.PI * 2, r: 4 + Math.random() * 0.8, h: 1.5 + Math.random() * 4, v: 0.4 + Math.random() * 0.3 }; g.add(e); eclats.push(e);
  }
  // braseros rouges et bougies
  for (const [x, z] of [[-4.2, 3.4], [4.2, 3.4]]) {
    const w = new THREE.Vector3(x * ech, 0, z * ech).applyAxisAngle(new THREE.Vector3(0, 1, 0), rot).add(P);
    brasero(groupe, w.x, w.z, th.brasero, 1.15 * Math.max(0.6, ech));
  }
  for (const [x, z] of [[-2.2, 2.4], [2.2, 2.4], [-1.2, 3.0], [1.4, 3.1]]) g.add(cloner('candle_triple', x, 0.45, z, Math.random() * 6, 1.3));
  G.torches.push({ pos: P.clone().add(new THREE.Vector3(0, 3.5 * ech, 0)), color: th.lumiere, int: 60 * ech, dist: 18 * ech });
  const centre = new THREE.Vector3(0, 3.55 * ech, 0).applyAxisAngle(new THREE.Vector3(0, 1, 0), rot).add(P);
  G.anims.push((t, dt) => {
    vortex.material.uniforms.uT.value = t;
    runes.rotation.z = t * 0.12; anneau.rotation.z = t * 0.4; halo.material.opacity = 0.5 + 0.15 * Math.sin(t * 3);
    cle.rotation.y = t * 1.2;
    eclats.forEach(e => { const u = e.userData; const a = u.a + t * u.v; e.position.set(Math.cos(a) * u.r, u.h + Math.sin(t * 2 + u.a) * 0.4, Math.sin(a) * u.r * 0.5); e.rotation.x = t; e.rotation.y = t * 1.3; });
    if (Math.random() < dt * 40) {
      const a = Math.random() * 6.28, r = 2.7 * ech;
      const p = new THREE.Vector3(Math.cos(a) * r, 3.55 * ech + Math.sin(a) * r, 0).applyAxisAngle(new THREE.Vector3(0, 1, 0), rot).add(P);
      emettre(p, { n: 1, c1: th.p1, c2: th.p2, vit: 0.6, vie: 1.0, taille: 0.35, frein: 0.5 });
    }
    if (Math.random() < dt * 14) emettre(new THREE.Vector3(P.x + rnd(-5, 5) * ech, 0.5, P.z + rnd(-5, 5) * ech), { n: 1, c1: th.s1, c2: th.s2, dir: new THREE.Vector3(0, 1, 0), vit: 1.6, disp: 0.3, vie: 2.2, taille: 0.22, frein: 0.2 });
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
      else emettre(f.pos, { n: 1, c1: f.couleur === '#ff8a2a' || f.couleur === '#ff7a2a' ? '#ffcf6a' : f.couleur === '#9a4aff' ? '#e0b0ff' : '#ff8a5a', c2: f.couleur, dir: new THREE.Vector3(0, 1, 0), vit: 1.6 * f.force + 0.6, disp: 0.35, rayon: 0.25 * f.force, vie: 0.55, taille: 0.55 * f.force + 0.15, tailleFin: 0.05, frein: 0.6 });
    }
  }
}

// ======================= ARÈNE =======================
export function construireArene() {
  const groupe = new THREE.Group();
  G.torches = []; G.feux = []; G.anims = [];
  const R = 17;
  solAbysse(groupe, 0, 0, 200);
  // sable de l'arène
  const sable = texture('sableArene', 1024, 1024, (g) => {
    g.translate(512, 512);
    const gr = g.createRadialGradient(0, 0, 40, 0, 0, 512); gr.addColorStop(0, '#4a3a5a'); gr.addColorStop(1, '#2a2034'); g.fillStyle = gr; g.beginPath(); g.arc(0, 0, 512, 0, 7); g.fill();
    for (let i = 0; i < 3000; i++) { const a = Math.random() * 6.28, r = Math.sqrt(Math.random()) * 500; g.fillStyle = `rgba(${150 + Math.random() * 60},${120 + Math.random() * 50},${170 + Math.random() * 60},${Math.random() * 0.12})`; g.fillRect(Math.cos(a) * r, Math.sin(a) * r, 2 + Math.random() * 5, 2 + Math.random() * 5); }
    g.strokeStyle = 'rgba(200,140,255,0.35)'; g.lineWidth = 6; for (const r of [150, 300, 480]) { g.beginPath(); g.arc(0, 0, r, 0, 7); g.stroke(); }
    g.strokeStyle = 'rgba(220,170,255,0.25)'; g.lineWidth = 3; g.beginPath(); g.moveTo(-480, 0); g.lineTo(480, 0); g.stroke();
    // deux cercles de départ
    for (const s of [-1, 1]) { g.strokeStyle = s < 0 ? 'rgba(90,170,255,0.6)' : 'rgba(255,80,80,0.6)'; g.lineWidth = 8; g.beginPath(); g.arc(s * 300, 0, 70, 0, 7); g.stroke(); }
  });
  const sol = new THREE.Mesh(new THREE.CircleGeometry(R + 1, 64), new THREE.MeshStandardMaterial({ map: sable, roughness: 1 }));
  sol.rotation.x = -Math.PI / 2; sol.position.y = 0.02; sol.receiveShadow = true; groupe.add(sol);
  const runes = new THREE.Mesh(new THREE.CircleGeometry(5, 48), new THREE.MeshBasicMaterial({ map: texRunes('#b05aff'), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, opacity: 0.8 }));
  runes.rotation.x = -Math.PI / 2; runes.position.y = 0.06; groupe.add(runes);
  // muret et gradins
  const pm = pierreMat('#3a3050', '#201a2c');
  const muret = new THREE.Mesh(new THREE.CylinderGeometry(R + 1.6, R + 1.6, 1.6, 64, 1, true), pm); muret.position.y = 0.8; muret.material.side = THREE.DoubleSide; groupe.add(muret);
  const rebord = new THREE.Mesh(new THREE.TorusGeometry(R + 1.6, 0.35, 8, 64), pm); rebord.rotation.x = Math.PI / 2; rebord.position.y = 1.6; groupe.add(rebord);
  for (let k = 0; k < 5; k++) {
    const r0 = R + 2.2 + k * 2.2, h = 1.6 + k * 1.2;
    const gr = new THREE.Mesh(new THREE.CylinderGeometry(r0 + 2.2, r0 + 2.2, h, 64, 1, false), pm); gr.position.y = h / 2; gr.receiveShadow = true;
    const trou = new THREE.Mesh(new THREE.RingGeometry(r0, r0 + 2.2, 64), pm); trou.rotation.x = -Math.PI / 2; trou.position.y = h + 0.01;
    groupe.add(trou);
    const face = new THREE.Mesh(new THREE.CylinderGeometry(r0, r0, h, 64, 1, true), pm); face.material.side = THREE.DoubleSide; face.position.y = h / 2; groupe.add(face);
  }
  // spectateurs : silhouettes sombres sur les gradins
  const silGeo = new THREE.CapsuleGeometry(0.35, 0.6, 3, 6);
  const silMat = new THREE.MeshStandardMaterial({ color: '#1a1424', roughness: 1 });
  const n = 220; const foule = new THREE.InstancedMesh(silGeo, silMat, n); const m4 = new THREE.Matrix4();
  for (let i = 0; i < n; i++) {
    const k = Math.floor(Math.random() * 5), r0 = R + 3.3 + k * 2.2, h = 1.6 + k * 1.2 + 0.65, a = Math.random() * 6.28;
    if (Math.cos(a) > 0.6 && Math.sin(a) > -0.3 && Math.sin(a) < 0.3) continue;
    m4.makeTranslation(Math.cos(a) * r0, h, Math.sin(a) * r0); foule.setMatrixAt(i, m4);
  }
  groupe.add(foule);
  G.anims.push((t) => { foule.position.y = Math.abs(Math.sin(t * 6)) * 0.06; runes.rotation.z = t * 0.1; });
  // piliers et braseros violets
  for (let i = 0; i < 12; i++) {
    const a = i / 12 * Math.PI * 2 + Math.PI / 12; const x = Math.cos(a) * (R + 1.6), z = Math.sin(a) * (R + 1.6);
    groupe.add(cloner('pillar_decorated', x, 0, z, -a + Math.PI / 2, 0.85));
    if (i % 2 === 0) brasero(groupe, Math.cos(a) * (R - 0.8), Math.sin(a) * (R - 0.8), '#9a4aff', 1.0);
    else groupe.add(cloner('banner_patternA_red', Math.cos(a) * (R + 1.0), 0, Math.sin(a) * (R + 1.0), -a - Math.PI / 2, 1));
  }
  // cristal flottant au-dessus du centre
  const cristal = new THREE.Mesh(new THREE.OctahedronGeometry(1.1, 0), new THREE.MeshStandardMaterial({ color: '#d0a0ff', emissive: '#7a2aff', emissiveIntensity: 2.2, flatShading: true }));
  cristal.scale.set(0.5, 0.8, 0.5); cristal.position.y = 6.5; groupe.add(cristal);
  G.anims.push((t) => { cristal.rotation.y = t * 0.5; cristal.position.y = 6.5 + Math.sin(t) * 0.3; });
  G.torches.push({ pos: new THREE.Vector3(0, 8, 0), color: '#a060ff', int: 50, dist: 30 });
  G.torches.push({ pos: new THREE.Vector3(-10, 3, 0), color: '#6aa0ff', int: 22, dist: 12 });
  G.torches.push({ pos: new THREE.Vector3(10, 3, 0), color: '#ff5a5a', int: 22, dist: 12 });
  G.scene.add(groupe);
  return {
    groupe, type: 'arene', nom: 'Arène des Échos',
    spawn: new THREE.Vector3(-10, 0, 1.2), spawnAllie: new THREE.Vector3(-10, 0, -1.8),
    spawnsRivaux: [new THREE.Vector3(10, 0, -1.2), new THREE.Vector3(10, 0, 1.8)],
    marche: (x, z) => Math.hypot(x, z) < R - 1.2,
    collisions: [], rayon: R,
  };
}

// ======================= ÎLES =======================
import { ILE_TYPES, ILE_TAILLES, BATIMENTS } from './data.js';
function graineRng(a) { return function () { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
export const HEX = { SC: 4, taille: 1.15 * 4 };
export function hexPos(q, r) { return new THREE.Vector3(HEX.taille * Math.sqrt(3) * (q + r / 2), 0, HEX.taille * 1.5 * r); }
const hexDist = (q, r) => (Math.abs(q) + Math.abs(r) + Math.abs(-q - r)) / 2;
function versHex(x, z) {
  const q = (Math.sqrt(3) / 3 * x - z / 3) / HEX.taille, r = (2 / 3 * z) / HEX.taille;
  let rx = Math.round(q), rz = Math.round(r), ry = Math.round(-q - r);
  const dx = Math.abs(rx - q), dz = Math.abs(rz - r), dy = Math.abs(ry + q + r);
  if (dx > dy && dx > dz) rx = -ry - rz; else if (dy > dz) ry = -rx - rz; else rz = -rx - ry;
  return [rx, rz];
}
export function rayonIle(ile) { return ILE_TAILLES[ile.taille].rayon + (ile.niveau >= 4 ? 1 : 0) + (ile.niveau >= 7 ? 1 : 0); }
export function nbEmplacements(ile) { return 6 + 2 * ile.taille + 2 * (ile.niveau - 1); }

export function construireIle(ile, etranger = false) {
  const groupe = new THREE.Group();
  G.torches = []; G.feux = []; G.anims = [];
  const rng = graineRng(ile.graine || 7);
  const T = ILE_TYPES[ile.type];
  const SC = HEX.SC, R = rayonIle(ile);
  if (!G.assets.hex_grass.verdi) { G.assets.hex_grass.verdi = true; G.assets.hex_grass.scene.traverse(o => { if (o.isMesh) o.material.color.setRGB(0.72, 0.95, 0.6); }); }
  const inst = new Instancieur();
  const terre = [];
  for (let q = -R - 5; q <= R + 5; q++) for (let r = -R - 5; r <= R + 5; r++) {
    const d = hexDist(q, r); if (d > R + 5) continue;
    const p = hexPos(q, r);
    if (d <= R) { inst.ajouter('hex_grass', p.x, 0, p.z, 0, SC, SC, SC); terre.push({ q, r, d, p }); }
    else inst.ajouter('hex_water', p.x, 0, p.z, 0, SC, SC, SC);
  }
  // mer au-delà des tuiles : reflets animés
  const mer = new THREE.Mesh(new THREE.CircleGeometry(260, 64), new THREE.ShaderMaterial({
    uniforms: { uT: { value: 0 } },
    vertexShader: 'varying vec2 vP; void main(){ vP=position.xy; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);} ',
    fragmentShader: `uniform float uT; varying vec2 vP;
      void main(){ float w=sin(vP.x*0.18+uT*0.8)*sin(vP.y*0.21-uT*0.6)+sin((vP.x+vP.y)*0.11+uT*0.5);
        vec3 c=mix(vec3(0.09,0.33,0.52),vec3(0.16,0.52,0.72),0.5+0.25*w); c+=vec3(0.7,0.85,1.0)*smoothstep(1.55,1.9,w)*0.25;
        float d=length(vP)/260.0; c=mix(c,vec3(0.07,0.18,0.32),smoothstep(0.35,1.0,d)); gl_FragColor=vec4(c,1.0);} `,
  }));
  mer.rotation.x = -Math.PI / 2; mer.position.y = -0.85; groupe.add(mer);
  G.anims.push((t) => { mer.material.uniforms.uT.value = t; });

  // ponton et portail de retour, côté caméra
  const bord = terre.filter(t => t.d === R).sort((a, b) => (b.p.x + b.p.z) - (a.p.x + a.p.z))[0];
  const dirOut = bord.p.clone().normalize();
  const spawn = bord.p.clone().addScaledVector(dirOut, -2.5);
  for (let i = 0; i < 4; i++) { const pp = bord.p.clone().addScaledVector(dirOut, 3 + i * 3); inst.ajouter('ground_pathTile', pp.x, 0.05, pp.z, Math.atan2(dirOut.x, dirOut.z), 3, 3, 3); }
  const portailPos = bord.p.clone().addScaledVector(dirOut, 9.5).setY(0);
  const portail = construirePortail(groupe, portailPos, Math.atan2(dirOut.x, dirOut.z) + Math.PI, THEME_JAUNE, 0.42);
  const intendantPos = bord.p.clone().addScaledVector(dirOut, -1).add(new THREE.Vector3(-dirOut.z, 0, dirOut.x).multiplyScalar(4));

  // centre : maison du joueur (ou entrepôt provisoire) et coffre
  const centre = hexPos(0, 0);
  const aFoyer = !etranger ? ile.batiments.some(b => b.t === 'foyer') : true;
  let coffrePos = centre.clone().add(new THREE.Vector3(3.2, 0, 3.2));
  if (aFoyer) { groupe.add(cloner('b_tavern', centre.x - 0.6, 0, centre.z - 0.6, Math.PI / 4, 5.2)); }
  else { groupe.add(cloner('tent', centre.x - 1, 0, centre.z - 1, Math.PI / 4, 5)); groupe.add(cloner('crate_A_big', centre.x + 1.8, 0, centre.z - 1.8, 0.3, 7)); groupe.add(cloner('barrel', centre.x - 2.6, 0, centre.z + 1.4, 0, 7)); }
  const coffre = cloner(etranger ? 'chest_gold' : 'chest', coffrePos.x, 0, coffrePos.z, Math.PI / 4, 1.4); groupe.add(coffre);
  G.torches.push({ pos: coffrePos.clone().setY(3), color: '#ffd27a', int: 18, dist: 12 });
  const tasRes = cloner(T.icone === 'Wood_Log_Stack' ? 'Wood_Log_Stack' : T.icone === 'Iron_Nuggets' ? 'Stone_Chunks_Large' : 'sack', coffrePos.x + 2.4, 0, coffrePos.z - 0.6, 0.5, T.icone === 'crop_pumpkin' ? 10 : 1.6); groupe.add(tasRes);

  // emplacements de construction
  const libres = terre.filter(t => t.d >= 1 && !(t.q === bord.q && t.r === bord.r));
  const ordre = libres.sort((a, b) => a.d - b.d || Math.atan2(a.p.z, a.p.x) - Math.atan2(b.p.z, b.p.x));
  const nPlots = Math.min(nbEmplacements(ile), ordre.length - 4);
  const plots = [];
  const collisions = [{ x: centre.x, z: centre.z, r: 4.2 }, { x: coffrePos.x, z: coffrePos.z, r: 1.4 }, { x: portailPos.x, z: portailPos.z, r: 1.4 }];
  const anneauMat = new THREE.MeshBasicMaterial({ color: '#ffd25a', transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false });
  for (let i = 0; i < nPlots; i++) {
    const t = ordre[i]; const b = ile.batiments.find(x => x.plot === i);
    const plot = { idx: i, pos: t.p.clone(), bati: b ? b.t : null, tuile: t };
    if (b) {
      const def = BATIMENTS[b.t];
      const rot = Math.atan2(-t.p.x, -t.p.z) + (rng() - 0.5) * 0.4;
      if (b.t === 'route') { for (const [dx, dz] of [[-1.4, -1.4], [1.4, -1.4], [-1.4, 1.4], [1.4, 1.4]]) inst.ajouter('ground_pathTile', t.p.x + dx, 0.04, t.p.z + dz, 0, 2.8, 2.8, 2.8); groupe.add(cloner('tool_lantern', t.p.x + 2.6, 0, t.p.z + 2.6, 0, 1.6)); G.torches.push({ pos: t.p.clone().add(new THREE.Vector3(2.6, 1.4, 2.6)), color: '#ffcf7a', int: 10, dist: 8 }); }
      else if (b.t === 'jardin') { for (let k = 0; k < 9; k++) groupe.add(cloner(['flower_redA', 'flower_yellowA', 'flower_purpleA'][k % 3], t.p.x + (rng() - 0.5) * 6, 0, t.p.z + (rng() - 0.5) * 6, rng() * 6, 5)); groupe.add(cloner('barrel', t.p.x + 1.5, 0, t.p.z - 1.2, 0, 7)); groupe.add(cloner('sack', t.p.x - 1.5, 0, t.p.z + 1.2, 1, 10)); }
      else { const modele = b.t === 'atelier' ? T.atelier : def.modele; groupe.add(cloner(modele, t.p.x, 0, t.p.z, rot, def.ech)); collisions.push({ x: t.p.x, z: t.p.z, r: b.t === 'tour' ? 2.4 : 3.0 }); }
    } else if (!etranger) {
      const ring = new THREE.Mesh(new THREE.RingGeometry(3.3, 3.7, 6), anneauMat); ring.rotation.x = -Math.PI / 2; ring.rotation.z = Math.PI / 6; ring.position.set(t.p.x, 0.06, t.p.z); groupe.add(ring);
      const pl = new THREE.Mesh(new THREE.CircleGeometry(3.3, 6), new THREE.MeshBasicMaterial({ color: '#ffd25a', transparent: true, opacity: 0.08, depthWrite: false })); pl.rotation.x = -Math.PI / 2; pl.rotation.z = Math.PI / 6; pl.position.set(t.p.x, 0.05, t.p.z); groupe.add(pl);
      groupe.add(cloner('flag_yellow', t.p.x + 2.4, 0, t.p.z - 1.2, 0, 6));
    }
    plots.push(plot);
  }
  G.anims.push((t) => { anneauMat.opacity = 0.35 + 0.25 * Math.sin(t * 2.5); });

  // nœuds de ressource sur les tuiles restantes
  const noeuds = [];
  const reste = ordre.slice(nPlots).filter(t => !(t.q === bord.q && t.r === bord.r));
  const minerais = ['Iron_Nuggets', 'Copper_Nuggets', 'Iron_Nuggets', 'Gold_Nuggets'];
  for (const t of reste) {
    const n = ile.type === 'bois' ? 1 + Math.floor(rng() * 2) : 2 + Math.floor(rng() * 2);
    for (let k = 0; k < n; k++) {
      const a = rng() * Math.PI * 2, rr = 1 + rng() * 2.6;
      const p = t.p.clone().add(new THREE.Vector3(Math.cos(a) * rr, 0, Math.sin(a) * rr));
      const g = new THREE.Group(); g.position.copy(p); g.rotation.y = rng() * 6.28;
      let souche, rayon = 1.0;
      if (ile.type === 'bois') {
        g.add(cloner(['Tree_1_A', 'Tree_2_B', 'Tree_3_A', 'Tree_4_A'][Math.floor(rng() * 4)], 0, 0, 0, 0, 0.85 + rng() * 0.3));
        souche = cloner('Wood_Log_A', p.x, 0.2, p.z, rng() * 6, 1.4);
      } else if (ile.type === 'mine') {
        g.add(cloner('Rock_3_C', 0, 0.7, 0, 0, 2.5)); g.add(cloner(minerais[Math.floor(rng() * 4)], 0.3, 1.4, 0.2, rng() * 6, 1.4));
        souche = cloner('Rock_1_A', p.x, 0, p.z, rng() * 6, 2); rayon = 1.4;
      } else {
        if (rng() < 0.5) { g.add(cloner('Bush_2_C', 0, 0, 0, 0, 1.6)); for (let f = 0; f < 4; f++) g.add(cloner('flower_redA', (rng() - 0.5) * 1.6, 0.6 + rng() * 1.2, (rng() - 0.5) * 1.6, rng() * 6, 4)); }
        else { for (let f = 0; f < 4; f++) g.add(cloner(['crop_pumpkin', 'crop_melon', 'crop_carrot'][Math.floor(rng() * 3)], (f % 2 - 0.5) * 1.6, 0, (Math.floor(f / 2) - 0.5) * 1.6, rng() * 6, 3.2)); }
        souche = cloner('Grass_1_A', p.x, 0, p.z, 0, 3);
      }
      g.traverse(o => { if (o.isMesh) o.castShadow = true; });
      groupe.add(g); souche.visible = false; groupe.add(souche);
      noeuds.push({ pos: p, obj: g, souche, pv: 6, pvMax: 6, regenT: 0, rayon });
      collisions.push({ x: p.x, z: p.z, r: rayon * 0.8, noeud: noeuds[noeuds.length - 1] });
    }
  }
  // herbes et fleurs décoratives
  for (const t of terre) for (let k = 0; k < 3; k++) { const a = rng() * 6.28, rr = rng() * 4; inst.ajouter(rng() < 0.7 ? 'Grass_1_A' : 'flower_yellowA', t.p.x + Math.cos(a) * rr, 0, t.p.z + Math.sin(a) * rr, rng() * 6, 3, 3, 3); }
  inst.construire(groupe);
  G.scene.add(groupe);
  const rayonMonde = (R + 0.45) * HEX.taille * Math.sqrt(3);
  return {
    groupe, type: 'ile', nom: ile.nom, ile, etranger,
    spawn, portail: { pos: portailPos }, intendantPos, coffrePos, centre, plots, noeuds, rayonMonde, R,
    collisions,
    marche: (x, z) => {
      const [q, r] = versHex(x, z); if (hexDist(q, r) <= R) return true;
      // ponton
      const v = new THREE.Vector3(x, 0, z).sub(bord.p); const along = v.dot(dirOut); const perp = Math.abs(v.x * dirOut.z - v.z * dirOut.x);
      return along > 0 && along < 11 && perp < 2;
    },
  };
}
