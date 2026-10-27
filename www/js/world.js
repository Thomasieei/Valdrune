// ===== Construction des cartes : place publique et donjons =====
import { THREE, G, Instancieur, cloner, fusionnerStatiques, texture, texRond, texRunes, texFissures, emettre, faisceau } from './engine.js';

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

function brasero(groupe, x, z, couleur = '#ff7a2a', echelle = 1, y0 = 0) {
  const col = cloner('column', x, y0, z, 0, 0.9 * echelle); groupe.add(col);
  const bol = new THREE.Mesh(new THREE.CylinderGeometry(0.62 * echelle, 0.36 * echelle, 0.4 * echelle, 12, 1, true), new THREE.MeshStandardMaterial({ color: '#4a3a32', metalness: 0.6, roughness: 0.5, side: THREE.DoubleSide }));
  bol.position.set(x, y0 + 1.38 * echelle, z); groupe.add(bol);
  const braise = new THREE.Mesh(new THREE.CircleGeometry(0.55 * echelle, 16), new THREE.MeshBasicMaterial({ color: couleur }));
  braise.rotation.x = -Math.PI / 2; braise.position.set(x, y0 + 1.5 * echelle, z); groupe.add(braise);
  const p = new THREE.Vector3(x, y0 + 1.55 * echelle, z);
  G.feux.push({ pos: p, couleur, force: echelle });
  G.torches.push({ pos: new THREE.Vector3(x, y0 + 2.4 * echelle, z), color: couleur, int: 30 * echelle, dist: 14 });
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
  // plan de la Place : chaque lieu a son emplacement réservé (rien ne doit s'y superposer)
  const M = new THREE.Vector3(-17, 0, 9), P = new THREE.Vector3(15, 0, -14), PA = new THREE.Vector3(-17, 0, -13);
  const PI = new THREE.Vector3(18, 0, 13), PB = new THREE.Vector3(22.5, 0, -0.5), TV = new THREE.Vector3(1, 0, -19.6);
  const reserve = [[0, 0, 11], [M.x, M.z, 8], [P.x, P.z, 6.5], [PA.x, PA.z, 6.5], [PI.x, PI.z, 5.5], [PB.x, PB.z, 5.5], [TV.x, TV.z, 10], [-4, 15, 4.5], [0, 9, 3], [13.2, 15.6, 2.5]];
  const libre = (x, z, m = 0) => reserve.every(([cx, cz, r]) => Math.hypot(x - cx, z - cz) > r + m);
  for (let x = X0; x <= X1; x++) for (let z = Z0; z <= Z1; z++) {
    const r = Math.random(), cx = x * CELL + 2, cz = z * CELL + 2;
    // les dalles à gravats (gros cailloux) seulement dans les zones vides, jamais sous un portail ou une échoppe
    const k = r < 0.82 ? 'floor_tile_large' : r < 0.92 ? (libre(cx, cz, 3) ? 'floor_tile_large_rocks' : 'floor_tile_large') : 'floor_dirt_large';
    inst.ajouter(k, cx, 0, cz, Math.floor(Math.random() * 4) * Math.PI / 2);
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
  const deco = [['barrel_large', -24, 18], ['barrel_small_stack', -21.5, 19.5], ['crates_stacked', -25.5, -8], ['rubble_half', 25, 21]];
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
  const portail = construirePortail(groupe, P, 0.1, THEME_ROUGE);
  // ---- Le Portail de l'Arène (nord-ouest) ----
  const portailArene = construirePortail(groupe, PA, 0.35, THEME_VIOLET);
  // ---- Le petit portail doré des Îles (sud-est) et son passeur ----
  const portailIle = construirePortail(groupe, PI, -0.5, THEME_JAUNE, 0.5);
  const passeur = { pos: new THREE.Vector3(13.2, 0, 15.6), rot: -0.9 };
  // ---- Le portail du Goulet des Braises (10 contre 10), qui s'ouvre toutes les 5 minutes ----
  const portailGoulet = construirePortail(groupe, PB, -0.75, THEME_GOULET, 0.55); portailGoulet.groupe.visible = false;
  for (const [k, x, z, r2, s2] of [['barrel_large', 24.5, 17.5, 0, 0.7], ['crates_stacked', 25, 7.5, 0.4, 0.7]]) groupe.add(cloner(k, x, 0, z, r2, s2));

  // ---- La Taverne du Croc-Rouge (nord, contre le rempart) ----
  const bat = cloner('b_tavern', TV.x, 0, TV.z, Math.PI, 6.4); groupe.add(bat);
  // emprise réelle du bâtiment : l'enseigne et les tonneaux se placent autour, jamais dedans
  const bb = new THREE.Box3().setFromObject(bat); const AV = bb.max.z, DL = (bb.max.x - bb.min.x) / 2, CX = (bb.min.x + bb.max.x) / 2, CZ = (bb.min.z + bb.max.z) / 2, PR = Math.min(3.6, (bb.max.z - bb.min.z) / 2);
  const TONNEAUX = [['barrel_large', CX - DL - 1.3, AV - 2.8, 0.7], ['keg_decorated', CX - DL - 1.4, AV - 4.8, 0.6], ['barrel_small_stack', CX + DL + 1.1, AV - 2.6, 0.8]];
  { const enseigne = texture('enseigne_croc', 256, 128, (g, w2, h2) => { g.fillStyle = '#3a2414'; g.fillRect(0, 0, w2, h2); g.strokeStyle = '#d8a84a'; g.lineWidth = 6; g.strokeRect(6, 6, w2 - 12, h2 - 12); g.fillStyle = '#ffd27a'; g.font = 'bold 34px serif'; g.textAlign = 'center'; g.fillText('Le Croc-Rouge', w2 / 2, 56); g.font = 'italic 22px serif'; g.fillStyle = '#e8c8a0'; g.fillText('taverne · missions', w2 / 2, 94); });
    const pl = new THREE.Mesh(new THREE.PlaneGeometry(3.4, 1.7), new THREE.MeshStandardMaterial({ map: enseigne, roughness: 0.8, emissive: '#2a1408', emissiveIntensity: 0.6 })); pl.position.set(CX - DL - 1.9, 3.5, AV + 1.3); pl.rotation.y = 0.45; groupe.add(pl);
    const bois2 = new THREE.MeshStandardMaterial({ color: '#2a1a10', roughness: 0.9 }); const potence = new THREE.Mesh(new THREE.BoxGeometry(0.22, 4.8, 0.22), bois2); potence.position.set(CX - DL - 1.9 - Math.cos(0.45) * 1.9, 2.4, AV + 1.3 + Math.sin(0.45) * 1.9 - 0.15); potence.castShadow = true; groupe.add(potence);
    const potence2 = new THREE.Mesh(new THREE.BoxGeometry(0.22, 4.8, 0.22), bois2); potence2.position.set(CX - DL - 1.9 + Math.cos(0.45) * 1.9, 2.4, AV + 1.3 - Math.sin(0.45) * 1.9 - 0.15); potence2.castShadow = true; groupe.add(potence2);
    for (const dx of [-DL * 0.36, DL * 0.36]) { const l = new THREE.Mesh(new THREE.SphereGeometry(0.24, 10, 8), new THREE.MeshBasicMaterial({ color: '#ffcf7a' })); l.position.set(CX + dx, 3.1, AV + 0.3); groupe.add(l); G.torches.push({ pos: new THREE.Vector3(CX + dx, 3, AV + 0.8), color: '#ffb05a', int: 26, dist: 12 }); }
    for (const [k, x, z, s] of TONNEAUX) groupe.add(cloner(k, x, 0, z, 0.3, s));
  }
  G.scene.add(groupe);
  // Collisions
  const collisions = [
    ...Array.from({ length: Math.max(2, Math.ceil(DL * 2 / PR)) }, (_, i, n) => ({ x: bb.min.x + PR * 0.8 + i * (DL * 2 - PR * 1.6) / Math.max(1, Math.max(2, Math.ceil(DL * 2 / PR)) - 1), z: AV - PR, r: PR })), ...TONNEAUX.map(([, x, z]) => ({ x, z, r: 0.8 })),
    { x: 0, z: 0, r: 2.8 }, ...[[7, 7], [-7, 7], [7, -7], [-7, -7]].map(([x, z]) => ({ x, z, r: 0.7 })),
    { x: M.x, z: M.z, r: 2.4 }, { x: M.x - 1.6, z: M.z - 1.6, r: 2.4 }, { x: M.x + 1.6, z: M.z - 1.6, r: 2.4 }, { x: M.x - 2.4, z: M.z - 2.4, r: 2.6 },
    { x: P.x, z: P.z, r: 3.2 }, { x: PA.x, z: PA.z, r: 3.2 }, { x: PI.x, z: PI.z, r: 1.8 }, { x: 24.5, z: 17.5, r: 0.9 }, { x: 25, z: 7.5, r: 1.0 }, { x: -24, z: 18, r: 1.2 }, { x: -25.5, z: -8, r: 1.3 }, { x: PB.x, z: PB.z, r: 1.8 },
  ];
  return {
    groupe, type: 'hub', nom: 'Place des Cendres',
    spawn: new THREE.Vector3(0, 0, 9),
    marchand: { pos: M.clone().add(new THREE.Vector3(-1.4, 0, -1.4)), rot: Math.PI / 4, comptoir: M.clone() },
    portail, portailArene, portailIle, portailGoulet, passeur, taverne: { porte: new THREE.Vector3(CX, 0, AV + 1.4), emprise: { x0: bb.min.x, x1: bb.max.x, z0: bb.min.z, z1: AV } },
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
const THEME_GOULET = { runes: '#5ab0ff', cle: '#ff6a5a', cleE: '#3a8aff', anneau: '#ff5a4a', anneauE: '#2a6aff', halo: '#ff6a9a', eclat: '#a0d0ff', eclatE: '#ff3a3a', brasero: '#4a8aff', lumiere: '#c07aff', p1: '#7ab8ff', p2: '#ff3a3a', s1: '#5ab0ff', s2: '#ff8a7a', fissures: false,
  v1: 'vec3(0.02,0.0,0.06)', v2: 'vec3(0.2,0.35,1.0)', v3: 'vec3(1.0,0.4,0.4)', v4: 'vec3(0.9,0.25,0.5)', pierre: ['#2e2a40', '#18141f'] };
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
    if (!g.visible) return;
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

// ---------- Habillage des salles de donjon ----------
const MATS_DECOR = {};
function matPierre() { return MATS_DECOR.pierre || (MATS_DECOR.pierre = pierreMat('#7a7480', '#55505c')); }
function texTapis(c1, c2, or) {
  return texture('tapis' + c1, 128, 512, (g, w, h) => {
    g.fillStyle = c1; g.fillRect(0, 0, w, h);
    g.fillStyle = c2; g.fillRect(10, 10, w - 20, h - 20);
    g.strokeStyle = or; g.lineWidth = 6; g.strokeRect(14, 14, w - 28, h - 28); g.lineWidth = 2; g.strokeRect(24, 24, w - 48, h - 48);
    g.fillStyle = or; for (let y = 60; y < h - 40; y += 70) { g.beginPath(); g.moveTo(w / 2, y - 22); g.lineTo(w / 2 + 22, y); g.lineTo(w / 2, y + 22); g.lineTo(w / 2 - 22, y); g.closePath(); g.globalAlpha = 0.75; g.fill(); g.globalAlpha = 1; }
    for (let i = 0; i < 900; i++) { g.fillStyle = `rgba(0,0,0,${Math.random() * 0.12})`; g.fillRect(Math.random() * w, Math.random() * h, 2, 2); }
    for (let y = 0; y < h; y += 512) {}
    for (let x = 0; x < w; x += 6) { g.fillStyle = or; g.fillRect(x, 0, 3, 6); g.fillRect(x, h - 6, 3, 6); }
  });
}
function tapis(groupe, x, z, larg, long, rotY, style = 0) {
  const st = [['#4a0c10', '#7a1418', '#d8a84a'], ['#101a3a', '#1e2c5a', '#c8b070'], ['#2a0a3a', '#43165a', '#d8a8ff']][style % 3];
  const t = texTapis(...st); t.wrapT = THREE.RepeatWrapping;
  const m = new THREE.Mesh(new THREE.PlaneGeometry(larg, long), new THREE.MeshStandardMaterial({ map: t, roughness: 0.95, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 }));
  m.rotation.set(-Math.PI / 2, 0, rotY); m.position.set(x, 0.1, z); m.receiveShadow = true; groupe.add(m);
}
function sarcophage(groupe, x, z, rotY) {
  const g = new THREE.Group(); const p = matPierre();
  const base = new THREE.Mesh(new THREE.BoxGeometry(1.25, 0.85, 2.4), p); base.position.y = 0.42;
  const cuve = new THREE.Mesh(new THREE.BoxGeometry(1.4, 0.18, 2.55), p); cuve.position.y = 0.92;
  const couvercle = new THREE.Mesh(new THREE.BoxGeometry(1.15, 0.2, 2.25), p); couvercle.position.y = 1.1;
  const croixV = new THREE.Mesh(new THREE.BoxGeometry(0.16, 0.08, 1.4), p); croixV.position.y = 1.24;
  const croixH = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.08, 0.16), p); croixH.position.set(0, 1.24, -0.3);
  g.add(base, cuve, couvercle, croixV, croixH);
  g.position.set(x, 0, z); g.rotation.y = rotY; g.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } }); groupe.add(g);
}
function toile(groupe, x, z, taille) {
  const t = MATS_DECOR.toile || (MATS_DECOR.toile = new THREE.MeshBasicMaterial({ transparent: true, depthWrite: false, side: THREE.DoubleSide, opacity: 0.55, map: texture('toile', 256, 256, (g) => {
    g.strokeStyle = 'rgba(235,235,245,0.9)'; g.lineWidth = 1.6;
    for (let i = 0; i < 9; i++) { const a = i / 8 * Math.PI / 2; g.beginPath(); g.moveTo(0, 0); g.lineTo(Math.cos(a) * 256, Math.sin(a) * 256); g.stroke(); }
    for (let r = 26; r < 256; r += 26 + Math.random() * 10) { g.beginPath(); for (let i = 0; i <= 8; i++) { const a = i / 8 * Math.PI / 2, rr = r * (0.92 + Math.random() * 0.12); const px = Math.cos(a) * rr, py = Math.sin(a) * rr; if (!i) g.moveTo(px, py); else g.quadraticCurveTo(Math.cos(a - 0.1) * rr * 0.9, Math.sin(a - 0.1) * rr * 0.9, px, py); } g.stroke(); }
  }) }));
  const m = new THREE.Mesh(new THREE.PlaneGeometry(taille, taille), t);
  m.position.set(x + taille * 0.35, 3.2, z + taille * 0.35); m.rotation.set(-0.6, Math.PI / 4 + Math.PI, 0); groupe.add(m);
}
function tache(groupe, x, z, r, couleur) {
  const cle = 'tache' + couleur;
  const mat = MATS_DECOR[cle] || (MATS_DECOR[cle] = new THREE.MeshBasicMaterial({ transparent: true, depthWrite: false, color: couleur, map: texture('tache', 128, 128, (g) => {
    for (let i = 0; i < 26; i++) { const x0 = 64 + (Math.random() - 0.5) * 70, y0 = 64 + (Math.random() - 0.5) * 70, rr = 8 + Math.random() * 26; const gr = g.createRadialGradient(x0, y0, 0, x0, y0, rr); gr.addColorStop(0, 'rgba(255,255,255,0.5)'); gr.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = gr; g.beginPath(); g.arc(x0, y0, rr, 0, 7); g.fill(); }
  }) }));
  const m = new THREE.Mesh(new THREE.PlaneGeometry(r * 2, r * 2), mat); m.rotation.set(-Math.PI / 2, 0, Math.random() * 6); m.position.set(x, 0.085, z); groupe.add(m);
}
function os(groupe, x, z) {
  const mat = MATS_DECOR.os || (MATS_DECOR.os = new THREE.MeshStandardMaterial({ color: '#d8cfbc', roughness: 0.8 }));
  for (let i = 0; i < 4; i++) {
    const b = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.05, 0.6, 5), mat); b.rotation.set(Math.PI / 2, 0, Math.random() * 6); b.position.set(x + (Math.random() - 0.5) * 1.2, 0.07, z + (Math.random() - 0.5) * 1.2); groupe.add(b);
  }
  const crane = new THREE.Mesh(new THREE.SphereGeometry(0.2, 8, 6), mat); crane.scale.set(1, 0.85, 1.15); crane.position.set(x, 0.16, z); groupe.add(crane);
}
function raiLumiere(groupe, x, z, couleur = '#ffe0b0') {
  const t = texture('rai', 32, 128, (g) => { const gr = g.createLinearGradient(0, 0, 0, 128); gr.addColorStop(0, 'rgba(255,255,255,0)'); gr.addColorStop(0.35, 'rgba(255,255,255,0.55)'); gr.addColorStop(1, 'rgba(255,255,255,0.05)'); g.fillStyle = gr; g.fillRect(0, 0, 32, 128); const gx = g.createLinearGradient(0, 0, 32, 0); });
  const mat = new THREE.MeshBasicMaterial({ map: t, color: couleur, transparent: true, opacity: 0.22, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide });
  for (let k = 0; k < 2; k++) { const m = new THREE.Mesh(new THREE.PlaneGeometry(3.2, 12), mat); m.position.set(x, 5.2, z); m.rotation.set(0.38, k * Math.PI / 2 + 0.6, 0.12); groupe.add(m); }
  const sol = new THREE.Mesh(new THREE.CircleGeometry(2.2, 24), new THREE.MeshBasicMaterial({ map: texRond(), color: couleur, transparent: true, opacity: 0.35, blending: THREE.AdditiveBlending, depthWrite: false }));
  sol.rotation.x = -Math.PI / 2; sol.position.set(x - 1.2, 0.095, z + 2); groupe.add(sol);
}
// ======================= DONJONS =======================
// Chaque niveau de donjon a sa propre pierre, ses cristaux et sa lumière : fini les murs gris uniformes
export const THEMES_DONJON = [
  { nom: 'gres', mur: '#ecd6ae', sol: '#dcc49c', roche: '#e0d4b8', bloc: ['#9a8462', '#665238'], cristal: '#3affc0', lueur: '#ffc890', mousse: '#26401c', lave: null, brume: '#0e120c', hemi: '#d8e4c0', runes: '#5affc8' },
  { nom: 'os', mur: '#f2ece2', sol: '#dcd4c6', roche: '#e8e4dc', bloc: ['#aaa296', '#767068'], cristal: '#5ab0ff', lueur: '#c0dcff', mousse: null, lave: null, brume: '#0c1018', hemi: '#c8d8f4', runes: '#7ac0ff' },
  { nom: 'basalte', mur: '#bcaaa0', sol: '#ac9890', roche: '#c8b4a8', bloc: ['#6e4a40', '#40281f'], cristal: '#ff4a2a', lueur: '#ffc8a0', mousse: null, lave: '#ff5a10', brume: '#1a0a08', hemi: '#ecd0c4', runes: '#ff5a2a' },
  { nom: 'abime', mur: '#a88690', sol: '#8c6a74', roche: '#b49aa2', bloc: ['#562434', '#2e0e18'], cristal: '#ff1a5a', lueur: '#ff9aa8', mousse: null, lave: '#ff1a3a', brume: '#1a0208', hemi: '#f0a8b4', runes: '#ff2a5a' },
];
function teinteDonjon(th) {
  const cache = new Map(), cs = new THREE.Color(th.sol), cm = new THREE.Color(th.mur), cr = new THREE.Color(th.roche);
  return (mat, cle) => {
    const sol = /^(floor|stairs)/.test(cle), roc = /^n_(rock|stone|statue|campfire)/.test(cle), pierre = sol || roc || /^(wall|pillar|column|rubble|barrier)/.test(cle);
    if (!pierre || !mat || !mat.color) return mat;
    const k = mat.uuid + (sol ? 's' : roc ? 'r' : 'm');
    if (!cache.has(k)) { const m = mat.clone(); if (roc) { m.color.lerp(cr, 0.55); m.roughness = 0.85; m.metalness = 0; } else m.color.multiply(sol ? cs : cm); cache.set(k, m); }
    return cache.get(k);
  };
}
// pierre taillée (façades des estrades)
function texBlocs(th) {
  return texture('blocs' + th.nom, 256, 256, (g, w) => {
    g.fillStyle = th.bloc[1]; g.fillRect(0, 0, w, w);
    for (let r = 0; r < 4; r++) for (let c = 0; c < 5; c++) {
      const x = c * 64 - (r % 2) * 32, y = r * 64;
      g.fillStyle = th.bloc[0]; g.globalAlpha = 0.7 + Math.random() * 0.3; g.fillRect(x + 3, y + 3, 58, 58);
      g.globalAlpha = 1; g.fillStyle = 'rgba(255,240,220,0.1)'; g.fillRect(x + 3, y + 3, 58, 4);
      g.fillStyle = 'rgba(0,0,0,0.28)'; g.fillRect(x + 3, y + 56, 58, 5);
    }
    for (let i = 0; i < 1600; i++) { g.fillStyle = `rgba(${Math.random() < 0.5 ? '0,0,0' : '255,240,220'},${Math.random() * 0.1})`; g.fillRect(Math.random() * w, Math.random() * w, 2, 2); }
  }, { repeat: true });
}
const MATS_FACE = new Map();
function faceBlocs(groupe, th, x, y, z, larg, haut, rotY) {
  const k = th.nom + Math.round(larg) + 'x' + Math.round(haut * 10);
  if (!MATS_FACE.has(k)) { const t = texBlocs(th).clone(); t.needsUpdate = true; t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(Math.max(1, Math.round(larg / 3)), Math.max(1, Math.round(haut / 1.4))); MATS_FACE.set(k, new THREE.MeshStandardMaterial({ map: t, roughness: 0.92 })); }
  const m = new THREE.Mesh(new THREE.PlaneGeometry(larg, haut), MATS_FACE.get(k));
  m.position.set(x, y, z); m.rotation.y = rotY; m.receiveShadow = true; groupe.add(m); return m;
}
// estrade praticable : socle en pierre taillée, dallage, balustrade et un vrai escalier (le relief est suivi par G.solH)
function estrade(groupe, inst, collisions, reliefs, th, o) {
  const { x0, x1, z0, z1, h, cote, ouverts = [cote] } = o;
  const w = x1 - x0, d = z1 - z0, cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
  for (let x = x0 + 2; x < x1; x += 4) for (let z = z0 + 2; z < z1; z += 4) inst.ajouter('floor_tile_large', x, h - 0.05, z, Math.floor(Math.random() * 4) * Math.PI / 2);
  const coeur = new THREE.Mesh(new THREE.BoxGeometry(w - 0.06, h - 0.06, d - 0.06), new THREE.MeshStandardMaterial({ color: th.bloc[1], roughness: 1 }));
  coeur.position.set(cx, (h - 0.06) / 2, cz); coeur.receiveShadow = true; groupe.add(coeur);
  if (ouverts.includes('S')) faceBlocs(groupe, th, cx, h / 2 - 0.03, z1 + 0.01, w, h, 0);
  if (ouverts.includes('N')) faceBlocs(groupe, th, cx, h / 2 - 0.03, z0 - 0.01, w, h, Math.PI);
  if (ouverts.includes('E')) faceBlocs(groupe, th, x1 + 0.01, h / 2 - 0.03, cz, d, h, Math.PI / 2);
  if (ouverts.includes('W')) faceBlocs(groupe, th, x0 - 0.01, h / 2 - 0.03, cz, d, h, -Math.PI / 2);
  // l'escalier tombe pile entre deux segments de balustrade
  const ex = x0 + 4 * Math.round((cx - x0) / 4), ez = z0 + 4 * Math.round((cz - z0) / 4);
  const L = Math.max(2.6, h * 2.6), larg = 7.6, hw = larg / 2, sx = larg / 7;
  let r;
  if (cote === 'S') { inst.ajouter('stairs_wide', ex, 0, z1, 0, sx, h / 5.1, L / 4); r = { x0: ex - hw, x1: ex + hw, z0: z1, z1: z1 + L, axe: 'z', haut: z1 }; }
  else if (cote === 'N') { inst.ajouter('stairs_wide', ex, 0, z0, Math.PI, sx, h / 5.1, L / 4); r = { x0: ex - hw, x1: ex + hw, z0: z0 - L, z1: z0, axe: 'z', haut: z0 }; }
  else if (cote === 'W') { inst.ajouter('stairs_wide', x0, 0, ez, -Math.PI / 2, sx, h / 5.1, L / 4); r = { x0: x0 - L, x1: x0, z0: ez - hw, z1: ez + hw, axe: 'x', haut: x0 }; }
  else { inst.ajouter('stairs_wide', x1, 0, ez, Math.PI / 2, sx, h / 5.1, L / 4); r = { x0: x1, x1: x1 + L, z0: ez - hw, z1: ez + hw, axe: 'x', haut: x1 }; }
  reliefs.push({ type: 'plat', x0, x1, z0, z1, h }, { type: 'rampe', ...r, h, L });
  const bords = { S: ['x', z1, 0], N: ['x', z0, 0], E: ['z', x1, Math.PI / 2], W: ['z', x0, Math.PI / 2] };
  for (const c of ouverts) {
    const [ax, fixe, rot] = bords[c]; const a0 = ax === 'x' ? x0 : z0, a1 = ax === 'x' ? x1 : z1, ce = ax === 'x' ? ex : ez;
    for (let a = a0 + 2; a < a1; a += 4) if (!(c === cote && Math.abs(a - ce) < 2.5)) inst.ajouter('barrier', ax === 'x' ? a : fixe, h - 0.03, ax === 'x' ? fixe : a, rot, 1, 0.72, 1);
    for (let a = a0 + 0.45; a < a1; a += 0.9) if (!(c === cote && Math.abs(a - ce) < hw + 0.1)) collisions.push(ax === 'x' ? { x: a, z: fixe, r: 0.5 } : { x: fixe, z: a, r: 0.5 });
  }
  return { ex, ez, L };
}
const GEO_CRISTAL = new THREE.OctahedronGeometry(0.5, 0);
const MATS_CRISTAL = {};
function cristaux(groupe, th, x, z, k = 1, y = 0) {
  const mat = MATS_CRISTAL[th.nom] || (MATS_CRISTAL[th.nom] = new THREE.MeshStandardMaterial({ color: th.cristal, emissive: th.cristal, emissiveIntensity: 1.2, roughness: 0.15, metalness: 0.1, flatShading: true }));
  for (let i = 0; i < 6; i++) {
    const m = new THREE.Mesh(GEO_CRISTAL, mat); const a = i / 6 * 6.28 + Math.random(); const r = i ? (0.35 + Math.random() * 0.5) * k : 0; const s = (i ? 0.45 + Math.random() * 0.6 : 1.25) * k;
    m.scale.set(s * 0.55, s * (1.8 + Math.random()), s * 0.55); m.position.set(x + Math.cos(a) * r, y + s * 0.55, z + Math.sin(a) * r);
    m.rotation.set((Math.random() - 0.5) * 0.5 + (i ? Math.sin(a) * 0.4 : 0), Math.random() * 3, (i ? -Math.cos(a) * 0.4 : 0)); groupe.add(m);
  }
  G.torches.push({ pos: new THREE.Vector3(x, y + 1.8, z), color: th.cristal, int: 22 * k, dist: 11 });
}
function rochers(nat, collisions, x, z, n = 3, haut = false, r0 = 1.4) {
  for (let i = 0; i < n; i++) {
    const a = Math.random() * 6.28, r = i ? 0.7 + Math.random() * r0 : 0;
    const px = x + Math.cos(a) * r, pz = z + Math.sin(a) * r;
    if (haut && i < 2) { const s = 3.4 + Math.random() * 2; nat.ajouter(pick(['n_stone_tallB', 'n_stone_tallG']), px, -0.1, pz, Math.random() * 6, s, s * (1.1 + Math.random() * 0.6), s); }
    else { const s = 2.4 + Math.random() * 2.4; nat.ajouter(pick(['n_rock_largeB', 'n_rock_largeC', 'n_stone_largeC']), px, -0.12, pz, Math.random() * 6, s, s * (0.8 + Math.random() * 0.9), s); }
  }
  collisions.push({ x, z, r: 1.3 + r0 * 0.4 });
}
function fissuresLave(groupe, th, x, z, taille = 7) {
  const f = new THREE.Mesh(new THREE.PlaneGeometry(taille, taille), new THREE.MeshBasicMaterial({ map: texFissures(), color: th.lave, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, opacity: 0.95 }));
  f.rotation.x = -Math.PI / 2; f.rotation.z = Math.random() * 6; f.position.set(x, 0.1, z); f.renderOrder = 1; groupe.add(f);
  G.feux.push({ pos: new THREE.Vector3(x, 0.2, z), couleur: th.lave, force: 0.35 });
  G.torches.push({ pos: new THREE.Vector3(x, 1, z), color: th.lave, int: 16, dist: 9 });
}
// petite table basse et coussins (les cultistes s'assoient autour pour manger et jouer aux dés)
function tableBasse(groupe, x, z) {
  const bois = MATS_DECOR.boisT || (MATS_DECOR.boisT = new THREE.MeshStandardMaterial({ color: '#6a4228', roughness: 0.85 }));
  const tissu = MATS_DECOR.coussin || (MATS_DECOR.coussin = new THREE.MeshStandardMaterial({ color: '#7a1a24', roughness: 1 }));
  const plateau = new THREE.Mesh(new THREE.CylinderGeometry(1.15, 1.15, 0.12, 20), bois); plateau.position.set(x, 0.5, z); plateau.castShadow = true; groupe.add(plateau);
  const pied = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.32, 0.46, 10), bois); pied.position.set(x, 0.23, z); groupe.add(pied);
  for (let i = 0; i < 4; i++) { const a = i / 4 * 6.28 + 0.4; const c = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.55, 0.16, 12), tissu); c.position.set(x + Math.cos(a) * 1.75, 0.08, z + Math.sin(a) * 1.75); groupe.add(c); }
  const metal = MATS_DECOR.chope || (MATS_DECOR.chope = new THREE.MeshStandardMaterial({ color: '#9a8a6a', metalness: 0.6, roughness: 0.4 }));
  for (let i = 0; i < 4; i++) { const a = i / 4 * 6.28 + 0.4; const m = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.09, 0.2, 8), metal); m.position.set(x + Math.cos(a) * 0.75, 0.66, z + Math.sin(a) * 0.75); groupe.add(m); }
  const de = MATS_DECOR.de || (MATS_DECOR.de = new THREE.MeshStandardMaterial({ color: '#efe6d0', roughness: 0.6 }));
  for (let i = 0; i < 2; i++) { const m = new THREE.Mesh(new THREE.BoxGeometry(0.13, 0.13, 0.13), de); m.position.set(x + rnd(-0.3, 0.3), 0.63, z + rnd(-0.3, 0.3)); m.rotation.y = rnd(0, 3); groupe.add(m); }
  const bougie = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, 0.3, 8), new THREE.MeshBasicMaterial({ color: '#ffe0a0' })); bougie.position.set(x, 0.71, z); groupe.add(bougie);
  G.torches.push({ pos: new THREE.Vector3(x, 1.4, z), color: '#ffb060', int: 14, dist: 8 });
}
// trône de pierre (salle du Gardien)
function trone(groupe, th, x, y, z, rotY) {
  const g = new THREE.Group(); const p = new THREE.MeshStandardMaterial({ map: texBlocs(th), roughness: 0.9 }); const rouge = new THREE.MeshStandardMaterial({ color: '#7a1020', roughness: 1 });
  const b = (w, h, d, px, py, pz, m = p) => { const o = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), m); o.position.set(px, py, pz); o.castShadow = true; g.add(o); };
  b(2.6, 0.5, 2.2, 0, 0.25, 0); b(2.2, 0.35, 1.8, 0, 0.67, 0.1, rouge); b(2.6, 3.8, 0.45, 0, 2.2, -1.0); b(0.4, 1.1, 2.0, -1.2, 1.0, 0); b(0.4, 1.1, 2.0, 1.2, 1.0, 0);
  b(1.6, 2.4, 0.08, 0, 2.3, -0.74, rouge); b(3.2, 0.4, 0.6, 0, 4.2, -1.0);
  const crane = new THREE.Mesh(new THREE.SphereGeometry(0.32, 10, 8), new THREE.MeshStandardMaterial({ color: '#e8dcc0', roughness: 0.7 })); crane.position.set(0, 4.65, -1.0); crane.scale.set(1, 0.9, 1.1); g.add(crane);
  g.position.set(x, y, z); g.rotation.y = rotY; groupe.add(g);
}
// cible d'entraînement en paille (salle de l'Archère)
function cibleTir(groupe, x, y, z, rotY) {
  const t = texture('cibleTir', 128, 128, (g, w) => { const c = ['#e8d8a8', '#c03028', '#e8d8a8', '#c03028', '#ffd24a']; for (let i = 0; i < 5; i++) { g.fillStyle = c[i]; g.beginPath(); g.arc(64, 64, 62 - i * 12, 0, 7); g.fill(); } });
  const d = new THREE.Mesh(new THREE.CylinderGeometry(0.9, 0.9, 0.25, 24), [new THREE.MeshStandardMaterial({ color: '#c8a868' }), new THREE.MeshStandardMaterial({ map: t }), new THREE.MeshStandardMaterial({ map: t })]);
  d.rotation.set(Math.PI / 2, 0, 0); const g = new THREE.Group(); g.add(d); d.position.y = 1.5;
  const pied = new THREE.Mesh(new THREE.BoxGeometry(0.12, 1.6, 0.12), new THREE.MeshStandardMaterial({ color: '#5a3a22' })); pied.position.set(0, 0.8, -0.2); pied.rotation.x = 0.25; g.add(pied);
  g.position.set(x, y, z); g.rotation.y = rotY; groupe.add(g);
}
// bureau du Nécromancien : grimoire ouvert, crâne, fioles et runes qui flottent
function bureau(groupe, th, x, y, z, rotY) {
  const g = new THREE.Group(); g.position.set(x, y, z); g.rotation.y = rotY; groupe.add(g);
  const bois = new THREE.MeshStandardMaterial({ color: '#4a2a1a', roughness: 0.8 });
  const plateau = new THREE.Mesh(new THREE.BoxGeometry(3.4, 0.16, 1.5), bois); plateau.position.y = 1.0; plateau.castShadow = true; g.add(plateau);
  for (const [px, pz] of [[-1.5, -0.6], [1.5, -0.6], [-1.5, 0.6], [1.5, 0.6]]) { const p = new THREE.Mesh(new THREE.BoxGeometry(0.16, 1.0, 0.16), bois); p.position.set(px, 0.5, pz); g.add(p); }
  const page = texture('pageGrimoire', 128, 64, (c, w, h) => { c.fillStyle = '#e8dcbc'; c.fillRect(0, 0, w, h); c.strokeStyle = '#6a1a2a'; for (let i = 0; i < 9; i++) { c.beginPath(); c.moveTo(8 + (i > 4 ? 64 : 0), 10 + (i % 5) * 10); c.lineTo(56 + (i > 4 ? 64 : 0), 10 + (i % 5) * 10); c.stroke(); } c.fillStyle = '#c0102a'; c.beginPath(); c.arc(96, 40, 9, 0, 7); c.fill(); });
  const livre = new THREE.Mesh(new THREE.PlaneGeometry(1.1, 0.55), new THREE.MeshStandardMaterial({ map: page, emissive: '#ff8a6a', emissiveIntensity: 0.25 })); livre.rotation.x = -Math.PI / 2; livre.position.set(0, 1.1, 0.1); g.add(livre);
  const crane = new THREE.Mesh(new THREE.SphereGeometry(0.22, 10, 8), new THREE.MeshStandardMaterial({ color: '#e8dcc0' })); crane.position.set(-1.1, 1.26, -0.2); g.add(crane);
  for (let i = 0; i < 4; i++) { const f = new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.1, 0.32, 8), new THREE.MeshStandardMaterial({ color: ['#5aff8a', '#ff3a6a', '#7a8aff', '#ffd24a'][i], emissive: ['#2aff6a', '#ff1a4a', '#4a5aff', '#ffaa1a'][i], emissiveIntensity: 1.2, transparent: true, opacity: 0.85 })); f.position.set(0.8 + i * 0.18, 1.24, -0.35 + (i % 2) * 0.2); g.add(f); }
  const runes = new THREE.Mesh(new THREE.PlaneGeometry(2.2, 2.2), new THREE.MeshBasicMaterial({ map: texRunes(th.runes), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, opacity: 0.8 }));
  runes.rotation.x = -Math.PI / 2; runes.position.set(0, 2.2, 0.1); runes.userData.dyn = true; g.add(runes);
  G.anims.push((t) => { runes.rotation.z = t * 0.6; runes.position.y = 2.2 + Math.sin(t * 1.5) * 0.12; runes.material.opacity = 0.55 + 0.3 * Math.sin(t * 3); });
  G.torches.push({ pos: new THREE.Vector3(x, y + 2.2, z), color: th.runes, int: 20, dist: 10 });
}
function decorerSalle(groupe, inst, nat, collisions, reliefs, th, s, type, solA) {
  const X0 = (s.cx - Math.floor(s.tx / 2)) * CELL, Z0 = (s.cz - Math.floor(s.tz / 2)) * CELL, X1 = X0 + s.tx * CELL, Z1 = Z0 + s.tz * CELL;
  Object.assign(s, { X0, X1, Z0, Z1, deco: type });
  const cx = s.centre.x, cz = s.centre.z, porte = 7.5;
  // une salle sur deux a une mezzanine au nord-est, desservie par un escalier
  const mezz = type !== 'effondree' && Math.random() < 0.6;
  const mW = s.tx >= 10 ? 12 : 8, mx0 = X1 - mW;
  const slotsN = [], slotsO = [];
  for (let x = X0 + 2.6; x < X1 - 5.5; x += 3.4) if (Math.abs(x - cx) > porte && !(mezz && x > mx0 - 1.6)) slotsN.push(x);
  for (let z = Z0 + 2.6; z < Z1 - 5.5; z += 3.4) if (Math.abs(z - cz) > porte) slotsO.push(z);
  const solN = (k, x, d = 1.3, sc = 1, col = 0.9) => { inst.ajouter(k, x, 0, Z0 + d, rnd(-0.08, 0.08), sc, sc, sc); if (col) collisions.push({ x, z: Z0 + d, r: col }); };
  const solO = (k, z, d = 1.3, sc = 1, col = 0.9) => { inst.ajouter(k, X0 + d, 0, z, Math.PI / 2 + rnd(-0.08, 0.08), sc, sc, sc); if (col) collisions.push({ x: X0 + d, z, r: col }); };
  const murN = (k, x, y, sc = 1) => inst.ajouter(k, x, y, Z0 + 0.25, 0, sc, sc, sc);
  const murO = (k, z, y, sc = 1) => inst.ajouter(k, X0 + 0.25, y, z, Math.PI / 2, sc, sc, sc);
  if (type === 'armurerie') {
    slotsN.forEach((x, i) => i % 2 ? solN(i % 4 === 1 ? 'crates_stacked' : 'barrel_large', x, 1.4, 0.85) : murN('sword_shield_broken', x, 1.9));
    slotsO.forEach((z, i) => solO(['chest', 'trunk_large_A', 'barrel_small_stack', 'chest_gold'][i % 4], z, 1.3, 1, 0.9));
    tapis(groupe, cx, cz, 5, s.tx * CELL - 14, Math.PI / 2, 0);
  } else if (type === 'bibliotheque') {
    slotsN.forEach((x, i) => { murN('shelves', x, 0.4); if (i % 2) murN('shelf_small_candles', x, 2.6); });
    slotsO.forEach((z, i) => { murO('shelves', z, 0.4); if (i % 2 === 0) inst.ajouter('candle_triple', X0 + 1.3, 0, z + 1.7, 0); });
    inst.ajouter('table_long_decorated_A', cx - 9, 0, Z0 + 7.5, Math.PI / 2); collisions.push({ x: cx - 10.2, z: Z0 + 7.5, r: 1.2 }, { x: cx - 7.8, z: Z0 + 7.5, r: 1.2 });
    tapis(groupe, cx, cz + 1, 4.5, 12, 0, 1);
  } else if (type === 'refectoire') {
    for (const dx of [-5.5, 5.5]) { inst.ajouter('table_long_tablecloth_decorated_A', cx + dx, 0, Z0 + 8.5, Math.PI / 2); collisions.push({ x: cx + dx - 1.2, z: Z0 + 8.5, r: 1.2 }, { x: cx + dx + 1.2, z: Z0 + 8.5, r: 1.2 }); }
    slotsO.forEach((z, i) => solO(i % 2 ? 'keg_decorated' : 'barrel_large', z, 1.6, 0.8, 1));
    slotsN.forEach((x, i) => { if (i % 2) murN(pick(['banner_patternA_red', 'banner_thin_red', 'banner_patternB_red']), x, 0); else solN('barrel_small_stack', x, 1.2, 0.9, 0.8); });
  } else if (type === 'crypte') {
    slotsN.forEach((x, i) => { sarcophage(groupe, x, Z0 + 1.9, 0); collisions.push({ x, z: Z0 + 1.9, r: 1.1 }); if (i % 2) inst.ajouter('candle_lit', x + 1.6, 0, Z0 + 0.8, 0); });
    slotsO.forEach((z, i) => { sarcophage(groupe, X0 + 1.9, z, Math.PI / 2); collisions.push({ x: X0 + 1.9, z, r: 1.1 }); if (i % 2) inst.ajouter('candle_triple', X0 + 0.9, 0, z + 1.7, 0); });
    const runes = new THREE.Mesh(new THREE.CircleGeometry(5.5, 40), new THREE.MeshBasicMaterial({ map: texRunes(th.runes), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, opacity: 0.4 }));
    runes.rotation.x = -Math.PI / 2; runes.position.set(cx, 0.1, cz); groupe.add(runes);
    for (let k = 0; k < 3; k++) os(groupe, cx + rnd(-8, 8), cz + rnd(-8, 8));
    G.torches.push({ pos: new THREE.Vector3(cx, 1.5, cz), color: th.runes, int: 14, dist: 10 });
  } else if (type === 'hall') {
    slotsN.forEach((x, i) => { if (i % 2 === 0) { inst.ajouter('pillar_decorated', x, 0, Z0 + 4.2, 0, 0.85, 1.05, 0.85); collisions.push({ x, z: Z0 + 4.2, r: 0.95 }); } else murN(pick(['banner_patternA_red', 'banner_patternB_red']), x, 0); });
    slotsO.forEach((z, i) => { if (i % 2 === 0) { inst.ajouter('pillar_decorated', X0 + 4.2, 0, z, Math.PI / 2, 0.85, 1.05, 0.85); collisions.push({ x: X0 + 4.2, z, r: 0.95 }); } else murO('banner_thin_red', z, 0); });
    tapis(groupe, cx, cz, 5.5, s.tx * CELL - 10, Math.PI / 2, 0);
  } else { // effondrée : éboulis, colonne couchée, fissures, un rai de jour
    inst.ajouter('rubble_large', X0 + 5, 0, Z0 + 2.4, 0.15, 0.9, 0.9, 0.9); collisions.push({ x: X0 + 3, z: Z0 + 2.4, r: 1.6 }, { x: X0 + 7, z: Z0 + 2.4, r: 1.6 });
    inst.ajouter('rubble_half', X1 - 7, 0, Z0 + 2, -0.2, 0.8, 0.8, 0.8); collisions.push({ x: X1 - 7, z: Z0 + 2, r: 1.5 });
    inst.ajouter('rubble_half', X0 + 2.2, 0, Z1 - 8, Math.PI / 2, 0.75, 0.75, 0.75); collisions.push({ x: X0 + 2.2, z: Z1 - 8, r: 1.4 });
    rochers(nat, collisions, cx + 7, cz - 6, 4, true, 1.8);
    const f = new THREE.Mesh(new THREE.PlaneGeometry(16, 16), new THREE.MeshBasicMaterial({ map: texFissures(), color: th.lave || '#ff6a2a', transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, opacity: 0.85 }));
    f.rotation.x = -Math.PI / 2; f.rotation.z = Math.random() * 6; f.position.set(cx, 0.1, cz); groupe.add(f);
    G.torches.push({ pos: new THREE.Vector3(cx, 1.2, cz), color: th.lave || '#ff4a10', int: 18, dist: 10 });
    raiLumiere(groupe, cx - 4, cz - 3);
  }
  // relief et minéral : stalagmites dans les angles du fond, rochers bas côté caméra, cristaux qui éclairent
  if (!mezz) { rochers(nat, collisions, X1 - 3, Z0 + 3, 4, true, 1.2); cristaux(groupe, th, X1 - 6.5, Z0 + 2.4, 1.1); }
  rochers(nat, collisions, X0 + 3, Z0 + 3, 3, true, 1);
  rochers(nat, collisions, X0 + 3, Z1 - 3, 3, false, 1.2); cristaux(groupe, th, X0 + 6, Z1 - 2.2, 0.9);
  rochers(nat, collisions, X1 - 3, Z1 - 3, 2, false, 1);
  if (th.lave) for (let k = 0; k < 2; k++) fissuresLave(groupe, th, cx + rnd(-12, 12) * (k ? 1 : -1), cz + rnd(4, 12) * (k ? -1 : 1), rnd(5, 8));
  if (th.mousse) for (let k = 0; k < 3; k++) tache(groupe, rnd(X0 + 3, X1 - 3), rnd(Z0 + 3, Z1 - 3), rnd(1.2, 2.2), th.mousse);
  if (th.mousse) nat.ajouter(pick(['n_mushroom_tanGroup', 'n_mushroom_redGroup']), X0 + 1.6, 0, Z1 - 6, rnd(0, 6), 6, 6, 6);
  // mezzanine
  if (mezz) {
    const h = 1.6;
    const e = estrade(groupe, inst, collisions, reliefs, th, { x0: mx0, x1: X1, z0: Z0, z1: Z0 + 8, h, cote: 'S', ouverts: ['S', 'W'] });
    cristaux(groupe, th, X1 - 2.2, Z0 + 2.2, 1.0, h);
    inst.ajouter(type === 'bibliotheque' ? 'shelves' : 'chest', mx0 + 2.6, h, Z0 + 1.1, 0, 1, 1, 1); collisions.push({ x: mx0 + 2.6, z: Z0 + 1.4, r: 1 });
    inst.ajouter('candle_triple', mx0 + 4.6, h, Z0 + 1.0, 0);
    s.mezz = { pos: new THREE.Vector3(mx0 + mW / 2 - 1, 0, Z0 + 4.5), h, esc: new THREE.Vector3(e.ex, 0, Z0 + 8 + e.L + 1) };
  }
  // la scène de vie de la salle : qui l'occupe, et à faire quoi
  const choix = { refectoire: ['tablee', 'tablee', 'cercle'], armurerie: ['tablee', 'cercle'], hall: ['cercle', 'tablee', 'rituel'], bibliotheque: ['rituel', 'tablee'], crypte: ['rituel', 'feu'], effondree: ['feu', 'feu', 'cercle'] }[type] || ['cercle'];
  const sc = { type: pick(choix), centre: new THREE.Vector3(cx - 7, 0, cz + 6) };
  if (sc.type === 'tablee') tableBasse(groupe, sc.centre.x, sc.centre.z), collisions.push({ x: sc.centre.x, z: sc.centre.z, r: 1.2 });
  else if (sc.type === 'feu') {
    nat.ajouter('n_campfire_stones', sc.centre.x, 0, sc.centre.z, 0, 4.4, 4.4, 4.4); collisions.push({ x: sc.centre.x, z: sc.centre.z, r: 1.1 });
    G.feux.push({ pos: new THREE.Vector3(sc.centre.x, 0.3, sc.centre.z), couleur: '#ff8a2a', force: 1.1 });
    G.torches.push({ pos: new THREE.Vector3(sc.centre.x, 1.4, sc.centre.z), color: '#ffa04a', int: 30, dist: 13 });
  } else if (sc.type === 'rituel') {
    sc.centre.set(cx, 0, cz + (type === 'bibliotheque' ? 7 : 0));
    const r = new THREE.Mesh(new THREE.CircleGeometry(3.6, 40), new THREE.MeshBasicMaterial({ map: texRunes(th.runes), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, opacity: 0.75 }));
    r.rotation.x = -Math.PI / 2; r.position.set(sc.centre.x, 0.12, sc.centre.z); r.userData.dyn = true; groupe.add(r);
    const orbe = new THREE.Mesh(new THREE.IcosahedronGeometry(0.42, 1), new THREE.MeshStandardMaterial({ color: th.cristal, emissive: th.cristal, emissiveIntensity: 2, flatShading: true }));
    orbe.position.set(sc.centre.x, 1.6, sc.centre.z); orbe.userData.dyn = true; groupe.add(orbe);
    G.anims.push((t) => { r.rotation.z = t * 0.25; orbe.position.y = 1.6 + Math.sin(t * 2) * 0.2; orbe.rotation.y = t; });
    G.torches.push({ pos: new THREE.Vector3(sc.centre.x, 1.8, sc.centre.z), color: th.runes, int: 24, dist: 11 });
    sc.orbe = orbe;
  }
  s.scene = sc;
  // des gardes postés à une entrée de la salle, tournés vers le couloir
  const cxC = Math.floor(cx / CELL), czC = Math.floor(cz / CELL);
  const entrees = [];
  if (solA(cxC, s.cz - Math.floor(s.tz / 2) - 1)) entrees.push({ p: new THREE.Vector3(cx, 0, Z0 + 3.5), dir: new THREE.Vector3(0, 0, -1) });
  if (solA(cxC, s.cz - Math.floor(s.tz / 2) + s.tz)) entrees.push({ p: new THREE.Vector3(cx, 0, Z1 - 3.5), dir: new THREE.Vector3(0, 0, 1) });
  if (solA(s.cx - Math.floor(s.tx / 2) - 1, czC)) entrees.push({ p: new THREE.Vector3(X0 + 3.5, 0, cz), dir: new THREE.Vector3(-1, 0, 0) });
  if (solA(s.cx - Math.floor(s.tx / 2) + s.tx, czC)) entrees.push({ p: new THREE.Vector3(X1 - 3.5, 0, cz), dir: new THREE.Vector3(1, 0, 0) });
  s.entrees = entrees;
  toile(groupe, X0 + 0.1, Z0 + 0.1, 3.2);
  for (let k = 0; k < 4; k++) tache(groupe, rnd(X0 + 3, X1 - 3), rnd(Z0 + 3, Z1 - 3), rnd(1.5, 3.2), pick(['#1a1008', '#203018', '#3a0606']));
  if (type !== 'effondree' && Math.random() < 0.45) raiLumiere(groupe, cx + rnd(-6, 6), cz + rnd(-6, 2));
}

export function construireDonjon(mode) {
  const groupe = new THREE.Group();
  G.torches = []; G.feux = []; G.anims = [];
  const th = THEMES_DONJON[Math.max(0, Math.min(3, mode.abime ? 3 : (mode.id | 0)))];
  const W = 74, H = 74;
  const grille = new Uint8Array(W * H); // 0 vide, 1 salle, 2 couloir, 3 crypte cachée, 4 passage secret
  const zone = new Int16Array(W * H).fill(-1);
  const salles = [];
  const set = (x, z, v = 1) => { if (x >= 0 && z >= 0 && x < W && z < H && !grille[z * W + x]) grille[z * W + x] = v; };
  const solA = (x, z) => x >= 0 && z >= 0 && x < W && z < H && grille[z * W + x] > 0;
  const salle = (cx, cz, tx, tz, type, extra = {}, v = 1) => {
    const s = { cx, cz, tx, tz, type, id: salles.length, ...extra };
    for (let x = cx - Math.floor(tx / 2); x < cx - Math.floor(tx / 2) + tx; x++)
      for (let z = cz - Math.floor(tz / 2); z < cz - Math.floor(tz / 2) + tz; z++) { set(x, z, v); zone[z * W + x] = s.id; }
    s.centre = new THREE.Vector3(cx * CELL + 2 - (tx % 2 ? 0 : 2), 0, cz * CELL + 2 - (tz % 2 ? 0 : 2));
    salles.push(s); return s;
  };
  const couloir = (x1, z1, x2, z2) => {
    if (z1 === z2) for (let x = Math.min(x1, x2); x <= Math.max(x1, x2); x++) { set(x, z1, 2); set(x, z1 - 1, 2); set(x, z1 + 1, 2); }
    else for (let z = Math.min(z1, z2); z <= Math.max(z1, z2); z++) { set(x1, z, 2); set(x1 - 1, z, 2); set(x1 + 1, z, 2); }
  };
  const N = [22, 37, 52];
  const noeuds = [];
  for (let j = 0; j < 3; j++) for (let i = 0; i < 3; i++) {
    const t = 9 + Math.floor(Math.random() * 3);
    noeuds.push(salle(N[i], N[j], t, 9 + Math.floor(Math.random() * 3), 'normale', { i, j }));
  }
  const depart = salle(7, 52, 7, 7, 'depart');
  const bossPos = [[22, 7], [66, 22], [66, 52], [37, 66]];
  const bossSalles = bossPos.map(([x, z], k) => salle(x, z, 11, 11, 'boss', { boss: k }));
  // la crypte cachée : derrière un mur fissuré, au bout d'un passage étroit (nord ou ouest selon les donjons)
  let crypte;
  {
    const nord = Math.random() < 0.5;
    if (nord) {
      const n = noeuds[1]; const zMur = n.cz - Math.floor(n.tz / 2);
      crypte = salle(40, 8, 7, 7, 'crypte', {}, 3);
      for (let z = 12; z < zMur; z++) set(40, z, 4);
      crypte.mur = { x: 40 * CELL + 2, z: zMur * CELL - 0.5, rot: 0, axe: 'x' };
    } else {
      const n = noeuds[3]; const xMur = n.cx - Math.floor(n.tx / 2);
      crypte = salle(8, 38, 7, 7, 'crypte', {}, 3);
      for (let x = 12; x < xMur; x++) set(x, 40, 4);
      crypte.mur = { x: xMur * CELL - 0.5, z: 40 * CELL + 2, rot: Math.PI / 2, axe: 'z' };
    }
  }
  for (let j = 0; j < 3; j++) for (let i = 0; i < 3; i++) {
    if (i < 2) couloir(N[i], N[j], N[i + 1], N[j]);
    if (j < 2) couloir(N[i], N[j], N[i], N[j + 1]);
  }
  couloir(7, 52, 22, 52);
  couloir(22, 7, 22, 22); couloir(52, 22, 66, 22); couloir(52, 52, 66, 52); couloir(37, 52, 37, 66);

  // --- Sol : dalles nettes dans les salles (les tapis restent à plat), dalles cassées et rochers dans les couloirs ---
  const inst = new Instancieur(), nat = new Instancieur();
  for (let z = 0; z < H; z++) for (let x = 0; x < W; x++) {
    const v = grille[z * W + x]; if (!v) continue;
    const r = Math.random();
    const k = (v === 2 || v === 4) ? (r < 0.4 ? 'floor_dirt_large' : r < 0.85 ? 'floor_tile_large' : 'floor_tile_large_rocks') : (r < 0.88 ? 'floor_tile_large' : 'floor_dirt_large');
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
    if (!solA(x, z - 1)) {
      const r = Math.random();
      inst.ajouter(r < 0.7 ? 'wall' : r < 0.85 ? 'wall_arched' : 'wall_broken', x * CELL + 2, 0, z * CELL - 0.5, 0);
      noterSommet(x, z, 'h'); noterSommet(x + 1, z, 'h');
      if (++compteur % 3 === 0) torchesPos.push([x * CELL + 2, z * CELL + 0.1, 0]);
      else if (enSalle && Math.random() < 0.18) inst.ajouter(pick(['banner_patternA_red', 'banner_thin_red', 'banner_patternB_red']), x * CELL + 2, 0, z * CELL, 0);
    }
    if (!solA(x - 1, z)) {
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

  const collisions = [], reliefs = [];
  const types = ['armurerie', 'bibliotheque', 'refectoire', 'crypte', 'hall', 'effondree', 'crypte', 'armurerie', 'hall'].sort(() => Math.random() - 0.5);
  noeuds.forEach((s, i) => decorerSalle(groupe, inst, nat, collisions, reliefs, th, s, types[i % types.length], solA));
  // couloirs : rochers et stalagmites contre les murs, os, tonneaux, toiles d'araignée
  for (let z = 0; z < H; z++) for (let x = 0; x < W; x++) {
    if (grille[z * W + x] !== 2 || Math.random() > 0.09) continue;
    if (!solA(x, z - 1)) { const r = Math.random(); if (r < 0.35) { inst.ajouter(pick(['barrel_large', 'barrel_small_stack']), x * CELL + 2, 0, z * CELL + 1.1, rnd(0, 6), 0.75, 0.75, 0.75); collisions.push({ x: x * CELL + 2, z: z * CELL + 1.1, r: 0.8 }); } else if (r < 0.75) rochers(nat, collisions, x * CELL + 2, z * CELL + 1.2, 2, Math.random() < 0.5, 0.6); else os(groupe, x * CELL + 2, z * CELL + 1.5); }
    else if (!solA(x - 1, z)) { if (Math.random() < 0.5) toile(groupe, x * CELL + 0.1, z * CELL + 0.1, 2.4); else rochers(nat, collisions, x * CELL + 1.2, z * CELL + 2, 2, true, 0.5); }
  }
  // --- Salles des gardiens : une estrade face à l'entrée, et un vrai lieu de vie pour chaque boss ---
  const coffresPos = [];
  const COTES = ['N', 'E', 'E', 'S'];
  for (const s of bossSalles) {
    const c = s.centre, k = s.boss, cote = COTES[k];
    const X0 = c.x - 22, X1 = c.x + 22, Z0 = c.z - 22, Z1 = c.z + 22;
    const dir = { N: [0, -1], E: [1, 0], S: [0, 1] }[cote];
    for (let i = 0; i < 8; i++) {
      const a = i / 8 * Math.PI * 2 + Math.PI / 8; const ux = Math.cos(a), uz = Math.sin(a);
      if (ux * dir[0] + uz * dir[1] > 0.45) continue; // pas de colonne devant l'estrade
      inst.ajouter('column', c.x + ux * 12, 0, c.z + uz * 12, 0, 1.3, 1.6, 1.3);
      collisions.push({ x: c.x + ux * 12, z: c.z + uz * 12, r: 0.6 });
    }
    const runes = new THREE.Mesh(new THREE.CircleGeometry(7.5, 48), new THREE.MeshBasicMaterial({ map: texRunes(th.runes), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, opacity: 0.55 }));
    runes.rotation.x = -Math.PI / 2; runes.position.set(c.x, 0.1, c.z); runes.userData.dyn = true; groupe.add(runes);
    G.anims.push((t) => { runes.rotation.z = t * 0.08; });
    for (const [dx, dz] of [[-9, -9], [9, -9], [-9, 9], [9, 9]]) if (dx * dir[0] + dz * dir[1] < 9) brasero(groupe, c.x + dx, c.z + dz, th.lueur === '#a8d4ff' ? '#6ab8ff' : '#ff3a1a', 1.1);
    const h = 1.4;
    let rect, ouverts;
    if (cote === 'N') { rect = { x0: c.x - 10, x1: c.x + 10, z0: Z0, z1: Z0 + 8 }; ouverts = ['S', 'E', 'W']; }
    else if (cote === 'E') { rect = { x0: X1 - 8, x1: X1, z0: c.z - 10, z1: c.z + 10 }; ouverts = ['W', 'N', 'S']; }
    else { rect = { x0: c.x - 10, x1: c.x + 10, z0: Z1 - 8, z1: Z1 }; ouverts = ['N', 'E', 'W']; }
    const opp = { N: 'S', E: 'W', S: 'N' }[cote];
    const e = estrade(groupe, inst, collisions, reliefs, th, { ...rect, h, cote: opp, ouverts });
    // tapis du centre de la salle jusqu'au pied de l'escalier
    if (cote === 'E') tapis(groupe, (c.x + rect.x0 - e.L) / 2 + 0.5, e.ez, 4, rect.x0 - e.L - c.x - 1, Math.PI / 2, 0);
    else { const zp = cote === 'N' ? rect.z1 + e.L : rect.z0 - e.L; tapis(groupe, e.ex, (c.z + zp) / 2, 4, Math.abs(zp - c.z) - 1, 0, 0); }
    // lieu de vie
    const R = { activite: 'dort', pos: null, angle: 0 };
    if (k === 0) { // Gardien des Os : salle du trône, il somnole devant
      trone(groupe, th, c.x, h, Z0 + 1.6, 0); collisions.push({ x: c.x, z: Z0 + 1.6, r: 1.6 });
      brasero(groupe, c.x - 7, Z0 + 2.5, '#ff3a1a', 0.9, h); brasero(groupe, c.x + 7, Z0 + 2.5, '#ff3a1a', 0.9, h);
      inst.ajouter('banner_triple_red' in G.assets ? 'banner_triple_red' : 'banner_patternA_red', c.x - 4, 0, Z0 + 0.1, 0); inst.ajouter('banner_patternA_red', c.x + 4, 0, Z0 + 0.1, 0);
      Object.assign(R, { activite: 'dort', pos: new THREE.Vector3(c.x, 0, Z0 + 4.8), angle: 0 });
    } else if (k === 1) { // Archère du Voile : salle d'entraînement, elle fait sa ronde et tire sur ses cibles
      for (const dz of [-6, 0, 6]) cibleTir(groupe, X1 - 1.6, h, c.z + dz, -Math.PI / 2);
      for (const dz of [-8.5, 8.5]) { inst.ajouter('sword_shield_broken', X1 - 0.4, h + 1.6, c.z + dz, -Math.PI / 2); inst.ajouter('barrel_small_stack', X1 - 1.4, h, c.z + dz + (dz > 0 ? -2 : 2), 0.4, 0.8, 0.8, 0.8); }
      const pts = [new THREE.Vector3(c.x + 6, 0, c.z - 1), new THREE.Vector3(c.x - 6, 0, c.z - 8), new THREE.Vector3(c.x - 9, 0, c.z + 5), new THREE.Vector3(c.x + 3, 0, c.z + 9)];
      Object.assign(R, { activite: 'ronde', pos: pts[0].clone(), angle: Math.PI / 2, ronde: pts, cible: new THREE.Vector3(X1 - 1.6, 0, c.z) });
    } else if (k === 2) { // Nécromancien : son bureau de recherches sur l'estrade
      bureau(groupe, th, X1 - 3.4, h, c.z, -Math.PI / 2); collisions.push({ x: X1 - 3.4, z: c.z - 1.2, r: 1 }, { x: X1 - 3.4, z: c.z + 1.2, r: 1 });
      for (const dz of [-7, 7]) { inst.ajouter('shelves', X1 - 0.6, h - 0.4, c.z + dz, -Math.PI / 2); inst.ajouter('candle_triple', X1 - 1.6, h, c.z + dz * 0.6, 0); }
      Object.assign(R, { activite: 'recherche', pos: new THREE.Vector3(X1 - 5.6, 0, c.z), angle: Math.PI / 2 });
    } else { // Horreur infernale : elle dort sur son trésor
      for (let i = 0; i < 9; i++) inst.ajouter('coin_stack_large', c.x + rnd(-8, 8), h, Z1 - rnd(1.4, 6.6), rnd(0, 6), 1.3, 1.3, 1.3);
      inst.ajouter('chest_gold', c.x - 7.5, h, Z1 - 2, 0.3); inst.ajouter('chest_gold', c.x + 7.5, h, Z1 - 2, -0.3);
      Object.assign(R, { activite: 'dort', pos: new THREE.Vector3(c.x, 0, Z1 - 4.2), angle: Math.PI });
    }
    s.repaire = R;
    coffresPos.push(new THREE.Vector3(c.x - 6.5, 0, c.z - 6.5));
    const cp = coffresPos[coffresPos.length - 1]; collisions.push({ x: cp.x, z: cp.z, r: 1.2 });
  }
  // --- La crypte cachée ---
  {
    const s = crypte, c = s.centre;
    const X0 = c.x - 14, X1 = c.x + 14, Z0 = c.z - 14, Z1 = c.z + 14;
    for (const [x, z, r] of [[X0 + 3, Z0 + 3, 0.6], [X1 - 3, Z0 + 3, -0.6], [X0 + 3, Z1 - 3, 2.4], [X1 - 3, Z1 - 3, -2.4]]) { nat.ajouter('n_statue_head', x, 0, z, r, 3.2, 3.2, 3.2); collisions.push({ x, z, r: 1.2 }); }
    for (const dx of [-7, 0, 7]) { sarcophage(groupe, c.x + dx, Z0 + 2.2, 0); collisions.push({ x: c.x + dx, z: Z0 + 2.2, r: 1.1 }); }
    rochers(nat, collisions, X0 + 2.5, c.z, 3, true, 1); rochers(nat, collisions, X1 - 2.5, c.z + 4, 3, true, 1);
    cristaux(groupe, th, X0 + 3, c.z + 7, 1); cristaux(groupe, th, X1 - 3, c.z - 7, 1);
    const runes = new THREE.Mesh(new THREE.CircleGeometry(6.5, 48), new THREE.MeshBasicMaterial({ map: texRunes('#c08aff'), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, opacity: 0.6 }));
    runes.rotation.x = -Math.PI / 2; runes.position.set(c.x, 0.1, c.z); runes.userData.dyn = true; groupe.add(runes);
    G.anims.push((t) => { runes.rotation.z = -t * 0.12; });
    // le socle de la relique
    const pm = new THREE.MeshStandardMaterial({ map: texBlocs(th), roughness: 0.85 });
    const socle = new THREE.Mesh(new THREE.CylinderGeometry(1.1, 1.4, 1.2, 8), pm); socle.position.set(c.x, 0.6, c.z); socle.castShadow = true; groupe.add(socle);
    const dessus = new THREE.Mesh(new THREE.CylinderGeometry(1.25, 1.1, 0.2, 8), pm); dessus.position.set(c.x, 1.3, c.z); groupe.add(dessus);
    collisions.push({ x: c.x, z: c.z, r: 1.4 });
    for (let k = 0; k < 4; k++) os(groupe, c.x + rnd(-10, 10), c.z + rnd(-10, 10));
    for (const [dx, dz] of [[-5, 5], [5, 5]]) inst.ajouter('candle_triple', c.x + dx, 0, c.z + dz, 0);
    raiLumiere(groupe, c.x + 1.2, c.z - 2, '#d8c0ff');
    s.socle = new THREE.Vector3(c.x, 0, c.z);
    s.gardiens = [new THREE.Vector3(c.x - 4.5, 0, c.z + 3), new THREE.Vector3(c.x + 4.5, 0, c.z + 3)];
  }
  // le faux mur fissuré qui cache la crypte
  const teinte = teinteDonjon(th);
  {
    const m = crypte.mur;
    const mur = cloner('wall', m.x, 0, m.z, m.rot); mur.traverse(o => { if (o.isMesh) { o.material = teinte(o.material, 'wall'); o.castShadow = false; o.receiveShadow = true; } });
    mur.userData.dyn = true; groupe.add(mur);
    const fis = new THREE.Mesh(new THREE.PlaneGeometry(3.2, 3.2), new THREE.MeshBasicMaterial({ map: texFissures(), color: '#c08aff', transparent: true, opacity: 0.3, blending: THREE.AdditiveBlending, depthWrite: false }));
    fis.position.set(m.x + (m.axe === 'z' ? 0.52 : 0), 1.8, m.z + (m.axe === 'x' ? 0.52 : 0)); fis.rotation.y = m.rot; fis.userData.dyn = true; groupe.add(fis);
    G.anims.push((t) => { if (fis.parent) fis.material.opacity = 0.18 + 0.16 * Math.sin(t * 1.7); });
    const cols = [-1.4, 0, 1.4].map(o => ({ x: m.x + (m.axe === 'x' ? o : 0), z: m.z + (m.axe === 'z' ? o : 0), r: 1.0, murSecret: true }));
    collisions.push(...cols);
    crypte.murObj = { mesh: mur, fissures: fis, cols, pos: new THREE.Vector3(m.x + (m.axe === 'z' ? 1.6 : 0), 0, m.z + (m.axe === 'x' ? 1.6 : 0)) };
  }
  fusionnerStatiques(groupe);
  inst.construire(groupe, { mat: teinte }); nat.construire(groupe, { mat: teinte });
  G.scene.add(groupe);

  // --- Rondes : 1 à 3 sentinelles marchent d'une salle à l'autre ---
  const rondes = [];
  const aretes = [];
  for (let j = 0; j < 3; j++) for (let i = 0; i < 3; i++) { if (i < 2) aretes.push([j * 3 + i, j * 3 + i + 1]); if (j < 2) aretes.push([j * 3 + i, (j + 1) * 3 + i]); }
  aretes.sort(() => Math.random() - 0.5).slice(0, 5).forEach(([a, b]) => {
    const A = noeuds[a].centre, B = noeuds[b].centre; const d = B.clone().sub(A).normalize(), p = new THREE.Vector3(-d.z, 0, d.x);
    rondes.push({ pts: [A.clone().addScaledVector(p, 4).addScaledVector(d, 4), A.clone().addScaledVector(d, 16), B.clone().addScaledVector(d, -16), B.clone().addScaledVector(p, -4).addScaledVector(d, -4)] });
  });
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
  const solH = (x, z) => {
    for (const r of reliefs) {
      if (x < r.x0 || x > r.x1 || z < r.z0 || z > r.z1) continue;
      if (r.type === 'plat') return r.h;
      const t = r.axe === 'z' ? Math.abs(z - r.haut) : Math.abs(x - r.haut);
      return r.h * Math.max(0, 1 - t / r.L);
    }
    return 0;
  };
  return {
    groupe, type: 'donjon', nom: mode.lieu, mode, theme: th,
    spawn: depart.centre.clone(), sortie: depart.centre.clone().add(new THREE.Vector3(-4, 0, 0)),
    salles, noeuds, bossSalles, coffresPos, marche, collisions, rondes, crypte, solH,
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
    const gr = g.createRadialGradient(0, 0, 40, 0, 0, 512); gr.addColorStop(0, '#c8a878'); gr.addColorStop(1, '#9a7a52'); g.fillStyle = gr; g.beginPath(); g.arc(0, 0, 512, 0, 7); g.fill();
    for (let i = 0; i < 260; i++) { const a = Math.random() * 6.28, r = Math.sqrt(Math.random()) * 480, rr = 10 + Math.random() * 40; const gg = g.createRadialGradient(Math.cos(a) * r, Math.sin(a) * r, 0, Math.cos(a) * r, Math.sin(a) * r, rr); gg.addColorStop(0, Math.random() < 0.5 ? 'rgba(90,60,30,0.18)' : 'rgba(240,220,180,0.16)'); gg.addColorStop(1, 'rgba(0,0,0,0)'); g.fillStyle = gg; g.beginPath(); g.arc(Math.cos(a) * r, Math.sin(a) * r, rr, 0, 7); g.fill(); }
    for (let i = 0; i < 3000; i++) { const a = Math.random() * 6.28, r = Math.sqrt(Math.random()) * 500; g.fillStyle = `rgba(${120 + Math.random() * 80},${90 + Math.random() * 60},${50 + Math.random() * 40},${Math.random() * 0.25})`; g.fillRect(Math.cos(a) * r, Math.sin(a) * r, 2 + Math.random() * 5, 2 + Math.random() * 5); }
    g.strokeStyle = 'rgba(110,70,40,0.35)'; g.lineWidth = 6; for (const r of [150, 300, 480]) { g.beginPath(); g.arc(0, 0, r, 0, 7); g.stroke(); }
    g.strokeStyle = 'rgba(110,70,40,0.25)'; g.lineWidth = 3; g.beginPath(); g.moveTo(-480, 0); g.lineTo(480, 0); g.stroke();
    // deux cercles de départ
    for (const s of [-1, 1]) { g.strokeStyle = s < 0 ? 'rgba(90,170,255,0.6)' : 'rgba(255,80,80,0.6)'; g.lineWidth = 8; g.beginPath(); g.arc(s * 300, 0, 70, 0, 7); g.stroke(); }
  });
  const sol = new THREE.Mesh(new THREE.CircleGeometry(R + 1, 64), new THREE.MeshStandardMaterial({ map: sable, roughness: 1 }));
  sol.rotation.x = -Math.PI / 2; sol.position.y = 0.02; sol.receiveShadow = true; groupe.add(sol);
  const runes = new THREE.Mesh(new THREE.CircleGeometry(5, 48), new THREE.MeshBasicMaterial({ map: texRunes('#b05aff'), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, opacity: 0.8 }));
  runes.rotation.x = -Math.PI / 2; runes.position.y = 0.06; groupe.add(runes);
  // muret et gradins
  const pm = pierreMat('#a89a88', '#7a6c5c');
  const muret = new THREE.Mesh(new THREE.CylinderGeometry(R + 1.6, R + 1.6, 1.6, 64, 1, true), pm); muret.position.y = 0.8; muret.material.side = THREE.DoubleSide; groupe.add(muret);
  const rebord = new THREE.Mesh(new THREE.TorusGeometry(R + 1.6, 0.35, 8, 64), pm); rebord.rotation.x = Math.PI / 2; rebord.position.y = 1.6; groupe.add(rebord);
  for (let k = 0; k < 5; k++) {
    const r0 = R + 2.2 + k * 2.2, h = 1.6 + k * 1.2;
    const gr = new THREE.Mesh(new THREE.CylinderGeometry(r0 + 2.2, r0 + 2.2, h, 64, 1, false), pm); gr.position.y = h / 2; gr.receiveShadow = true;
    const trou = new THREE.Mesh(new THREE.RingGeometry(r0, r0 + 2.2, 64), pm); trou.rotation.x = -Math.PI / 2; trou.position.y = h + 0.01;
    groupe.add(trou);
    const face = new THREE.Mesh(new THREE.CylinderGeometry(r0, r0, h, 64, 1, true), pm); face.material.side = THREE.DoubleSide; face.position.y = h / 2; groupe.add(face);
  }
  // spectateurs : foule en habits colorés, qui s'agite pendant le combat
  const n = 340, corps = new THREE.InstancedMesh(new THREE.CapsuleGeometry(0.33, 0.55, 3, 6), new THREE.MeshStandardMaterial({ roughness: 0.9 }), n);
  const tetes = new THREE.InstancedMesh(new THREE.SphereGeometry(0.24, 8, 6), new THREE.MeshStandardMaterial({ roughness: 0.8 }), n);
  const m4 = new THREE.Matrix4(), coul = new THREE.Color(), base = [];
  const habits = ['#8a2a2a', '#2a4a8a', '#3a6a3a', '#8a6a2a', '#5a3a6a', '#7a7a7a', '#a04a2a', '#2a6a6a', '#c8b088', '#4a3a2a'], peaux = ['#f0c8a0', '#d8a07a', '#a8704a', '#7a4a2a'];
  for (let i = 0; i < n; i++) {
    const k = Math.floor(Math.random() * 5), r0 = R + 3.3 + k * 2.2, h = 1.6 + k * 1.2 + 0.55, a = Math.random() * 6.28;
    if (Math.abs(Math.cos(a)) > 0.94) { base.push(null); continue; } // passages vers les portes des combattants
    const x = Math.cos(a) * (r0 + (Math.random() - 0.5) * 0.6), z = Math.sin(a) * (r0 + (Math.random() - 0.5) * 0.6);
    base.push([x, h, z, Math.random() * 6.28]);
    m4.makeTranslation(x, h, z); corps.setMatrixAt(i, m4); corps.setColorAt(i, coul.set(habits[i % habits.length]));
    m4.makeTranslation(x, h + 0.68, z); tetes.setMatrixAt(i, m4); tetes.setColorAt(i, coul.set(peaux[i % peaux.length]));
  }
  for (let i = 0; i < n; i++) if (!base[i]) { m4.makeScale(0, 0, 0); corps.setMatrixAt(i, m4); tetes.setMatrixAt(i, m4); }
  corps.castShadow = true; groupe.add(corps, tetes);
  G.anims.push((t) => { for (let i = 0; i < n; i += 1) { const b = base[i]; if (!b) continue; const y = b[1] + Math.max(0, Math.sin(t * 5 + b[3])) * 0.18; m4.makeTranslation(b[0], y, b[2]); corps.setMatrixAt(i, m4); m4.makeTranslation(b[0], y + 0.68, b[2]); tetes.setMatrixAt(i, m4); } corps.instanceMatrix.needsUpdate = true; tetes.instanceMatrix.needsUpdate = true; runes.rotation.z = t * 0.1; });
  // grandes portes des combattants (ouest et est) et oriflammes en haut des gradins
  for (const s of [-1, 1]) {
    groupe.add(cloner('wall_arched', s * (R + 1.7), 0, 0, Math.PI / 2, 1.3));
    for (const dz of [-3.4, 3.4]) groupe.add(cloner('pillar_decorated', s * (R + 2), 0, dz, Math.PI / 2, 1.1));
  }
  for (let i = 0; i < 16; i++) { const a = i / 16 * Math.PI * 2; const r0 = R + 2.2 + 5 * 2.2 + 1.2; const mat = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.08, 6, 6), new THREE.MeshStandardMaterial({ color: '#3a2a1a' })); mat.position.set(Math.cos(a) * r0, 1.6 + 4 * 1.2 + 3, Math.sin(a) * r0); groupe.add(mat);
    const dr = new THREE.Mesh(new THREE.PlaneGeometry(1.4, 2.6), new THREE.MeshStandardMaterial({ color: i % 2 ? '#8a1a1a' : '#1a3a8a', side: THREE.DoubleSide, emissive: i % 2 ? '#2a0404' : '#04082a' })); dr.position.set(Math.cos(a) * r0, 1.6 + 4 * 1.2 + 4.4, Math.sin(a) * r0); dr.rotation.y = -a + Math.PI / 2; dr.position.x += Math.cos(a + Math.PI / 2) * 0.72; dr.position.z += Math.sin(a + Math.PI / 2) * 0.72; groupe.add(dr); }
  // piliers et braseros violets
  for (let i = 0; i < 12; i++) {
    const a = i / 12 * Math.PI * 2 + Math.PI / 12; const x = Math.cos(a) * (R + 1.6), z = Math.sin(a) * (R + 1.6);
    groupe.add(cloner('pillar_decorated', x, 0, z, -a + Math.PI / 2, 0.85));
    if (i % 2 === 0) brasero(groupe, Math.cos(a) * (R - 0.8), Math.sin(a) * (R - 0.8), '#ff8a2a', 1.0);
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

  // ---- plan du village : une place dégagée au centre, des bâtiments jamais collés (une tuile libre entre deux),
  // une allée du ponton à la place et un chemin pavé de la place à chaque bâtiment ----
  const surAllee = (p) => { const ab = centre.clone().sub(bord.p), ap = p.clone().sub(bord.p); const k = Math.max(0, Math.min(1, ap.dot(ab) / ab.lengthSq())); return ap.sub(ab.multiplyScalar(k)).length() < 4.6; };
  const VOIS = [[1, 0], [-1, 0], [0, 1], [0, -1], [1, -1], [-1, 1]], cleH = (q, r) => q + ',' + r;
  const cands = terre.filter(t => t.d >= 2 && !(t.q === bord.q && t.r === bord.r) && !surAllee(t.p)).sort((x, y) => x.d - y.d || Math.atan2(x.p.z, x.p.x) - Math.atan2(y.p.z, y.p.x));
  const besoin = nbEmplacements(ile), pris = new Set(), ordre = [];
  for (const t of cands) { if (ordre.length >= besoin) break; if (VOIS.some(([dq, dr]) => pris.has(cleH(t.q + dq, t.r + dr)))) continue; pris.add(cleH(t.q, t.r)); ordre.push(t); }
  for (const t of cands) { if (ordre.length >= besoin) break; const k = cleH(t.q, t.r); if (pris.has(k) || VOIS.filter(([dq, dr]) => pris.has(cleH(t.q + dq, t.r + dr))).length > 1) continue; pris.add(k); ordre.push(t); }
  for (const t of cands) { if (ordre.length >= besoin) break; const k = cleH(t.q, t.r); if (!pris.has(k)) { pris.add(k); ordre.push(t); } } // île pleine : on serre (rare)
  const nPlots = ordre.length;
  const plots = [];
  const collisions = [{ x: centre.x, z: centre.z, r: 4.2 }, { x: coffrePos.x, z: coffrePos.z, r: 1.4 }, { x: portailPos.x, z: portailPos.z, r: 1.4 }];
  const anneauMat = new THREE.MeshBasicMaterial({ color: '#ffd25a', transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false });
  // pavés de la place et des chemins (texture dessinée, posée à plat sur l'herbe)
  const texPaves = texture('pavesIle', 256, 256, (g, w) => {
    g.fillStyle = '#9a8a6a'; g.fillRect(0, 0, w, w);
    for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) { const ox = (y % 2) * 16; g.fillStyle = `hsl(${32 + Math.random() * 12},${14 + Math.random() * 10}%,${52 + Math.random() * 16}%)`; g.beginPath(); g.roundRect(x * 32 + ox + 2, y * 32 + 2, 28, 28, 6); g.fill(); g.fillStyle = 'rgba(0,0,0,0.12)'; g.fillRect(x * 32 + ox + 4, y * 32 + 24, 24, 4); }
  }, { repeat: true });
  const matPave = new THREE.MeshStandardMaterial({ map: texPaves, roughness: 0.95, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 });
  const chemin = (x0, z0, x1, z1, larg = 2.4) => { const L = Math.hypot(x1 - x0, z1 - z0); if (L < 0.5) return; const t = texPaves.clone(); t.needsUpdate = true; t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(larg / 2.4, L / 2.4); const m = new THREE.Mesh(new THREE.PlaneGeometry(larg, L), new THREE.MeshStandardMaterial({ map: t, roughness: 0.95, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 })); m.rotation.set(-Math.PI / 2, 0, Math.atan2(x1 - x0, z1 - z0)); m.position.set((x0 + x1) / 2, 0.03, (z0 + z1) / 2); m.receiveShadow = true; groupe.add(m); };
  { texPaves.wrapS = texPaves.wrapT = THREE.RepeatWrapping; texPaves.repeat.set(6, 6); const place = new THREE.Mesh(new THREE.RingGeometry(5.6, 8.4, 56), matPave); place.rotation.x = -Math.PI / 2; place.position.set(centre.x, 0.03, centre.z); place.receiveShadow = true; groupe.add(place); }
  chemin(centre.x + dirOut.x * 8, centre.z + dirOut.z * 8, bord.p.x, bord.p.z, 2.8);
  for (let i = 0; i < nPlots; i++) {
    const t = ordre[i]; const b = ile.batiments.find(x => x.plot === i);
    const plot = { idx: i, pos: t.p.clone(), bati: b ? b.t : null, tuile: t };
    // chemin de la place jusqu'au bâtiment
    const dirP = t.p.clone().sub(centre).setY(0); const L = dirP.length(); dirP.normalize();
    chemin(centre.x + dirP.x * 8.2, centre.z + dirP.z * 8.2, centre.x + dirP.x * (L - 3.4), centre.z + dirP.z * (L - 3.4));
    if (b) {
      const def = BATIMENTS[b.t];
      const rot = Math.atan2(-t.p.x, -t.p.z);
      if (b.t === 'route') { for (const [dx, dz] of [[-1.4, -1.4], [1.4, -1.4], [-1.4, 1.4], [1.4, 1.4]]) inst.ajouter('ground_pathTile', t.p.x + dx, 0.05, t.p.z + dz, 0, 2.8, 2.8, 2.8); groupe.add(cloner('tool_lantern', t.p.x + 2.6, 0, t.p.z + 2.6, 0, 1.6)); G.torches.push({ pos: t.p.clone().add(new THREE.Vector3(2.6, 1.4, 2.6)), color: '#ffcf7a', int: 10, dist: 8 }); }
      else if (b.t === 'jardin') { for (let k = 0; k < 9; k++) groupe.add(cloner(['flower_redA', 'flower_yellowA', 'flower_purpleA'][k % 3], t.p.x + (rng() - 0.5) * 6, 0, t.p.z + (rng() - 0.5) * 6, rng() * 6, 5)); groupe.add(cloner('barrel', t.p.x + 1.5, 0, t.p.z - 1.2, 0, 7)); groupe.add(cloner('sack', t.p.x - 1.5, 0, t.p.z + 1.2, 1, 10)); }
      else {
        const modele = b.t === 'atelier' ? T.atelier : def.modele;
        const obj = cloner(modele, t.p.x, 0, t.p.z, rot, def.ech);
        // le bâtiment tient dans sa tuile : jamais plus de 6,4 m de large
        obj.updateMatrixWorld(true); const bb = new THREE.Box3().setFromObject(obj); const larg = Math.max(bb.max.x - bb.min.x, bb.max.z - bb.min.z);
        if (larg > 6.4) obj.scale.multiplyScalar(6.4 / larg);
        groupe.add(obj);
        collisions.push({ x: t.p.x, z: t.p.z, r: Math.min(3.0, Math.min(larg, 6.4) * 0.4) });
        // un peu de vie : lanterne à la porte, fumée de cheminée, ailes du moulin et scie qui tournent
        const porte = t.p.clone().addScaledVector(dirP, -3.4);
        groupe.add(cloner('tool_lantern', porte.x + dirP.z * 1.8, 0, porte.z - dirP.x * 1.8, rot, 0.9));
        G.torches.push({ pos: porte.clone().setY(1.6), color: '#ffcf7a', int: 9, dist: 7 });
        if (b.t === 'maison' || b.t === 'atelier') { const fumee = t.p.clone().setY(6.2); G.anims.push((tt, dt) => { if (Math.random() < (dt || 0.016) * 2.2) emettre(fumee.clone().add(new THREE.Vector3((Math.random() - 0.5) * 0.4, 0, (Math.random() - 0.5) * 0.4)), { n: 1, c1: '#e8e4dc', c2: '#8a8680', dir: new THREE.Vector3(0.2, 1, 0.1), vit: 0.9, vie: 2.6, taille: 0.9, grav: -0.3 }); }); }
        const pale = obj.getObjectByName('building_windmill_top_fan_yellow') || obj.getObjectByName('building_lumbermill_saw_yellow');
        if (pale) { pale.userData.dyn = true; G.anims.push((tt, dt) => { pale.rotation.z -= (dt || 0.016) * (b.t === 'moulin' ? 0.9 : 3); }); }
      }
    } else if (!etranger) {
      const ring = new THREE.Mesh(new THREE.RingGeometry(3.3, 3.7, 6), anneauMat); ring.rotation.x = -Math.PI / 2; ring.rotation.z = Math.PI / 6; ring.position.set(t.p.x, 0.06, t.p.z); groupe.add(ring);
      const pl = new THREE.Mesh(new THREE.CircleGeometry(3.3, 6), new THREE.MeshBasicMaterial({ color: '#ffd25a', transparent: true, opacity: 0.08, depthWrite: false })); pl.rotation.x = -Math.PI / 2; pl.rotation.z = Math.PI / 6; pl.position.set(t.p.x, 0.05, t.p.z); groupe.add(pl);
      groupe.add(cloner('flag_yellow', t.p.x + 2.4, 0, t.p.z - 1.2, 0, 6));
    }
    plots.push(plot);
  }
  G.anims.push((t) => { anneauMat.opacity = 0.35 + 0.25 * Math.sin(t * 2.5); });

  // nœuds de ressource : sur les tuiles libres, jamais sur la place, l'allée ou un chemin de bâtiment
  const noeuds = [];
  const surChemin = (p) => ordre.some(t => { const ab = t.p.clone().sub(centre), ap = p.clone().sub(centre); const k = Math.max(0, Math.min(1, ap.dot(ab) / ab.lengthSq())); return ap.sub(ab.multiplyScalar(k)).length() < 2.6; });
  const reste = terre.filter(t => t.d >= 2 && !pris.has(cleH(t.q, t.r)) && !(t.q === bord.q && t.r === bord.r) && !surAllee(t.p) && !surChemin(t.p));
  const minerais = ['Iron_Nuggets', 'Copper_Nuggets', 'Iron_Nuggets', 'Gold_Nuggets'];
  for (const t of reste) {
    const n = 1;
    for (let k = 0; k < n; k++) {
      const p = t.p.clone().add(new THREE.Vector3((rng() - 0.5) * 0.8, 0, (rng() - 0.5) * 0.8));
      const g = new THREE.Group(); g.position.copy(p); g.rotation.y = rng() * 6.28;
      let souche, rayon = 1.0;
      if (ile.type === 'bois') {
        g.add(cloner(['Tree_1_A', 'Tree_2_B', 'Tree_3_A', 'Tree_4_A'][Math.floor(rng() * 4)], 0, 0, 0, 0, 0.85 + rng() * 0.3));
        souche = cloner('Wood_Log_A', p.x, 0.2, p.z, rng() * 6, 1.4);
      } else if (ile.type === 'mine') {
        g.add(cloner('Rock_3_C', 0, 0.7, 0, 0, 2.5)); g.add(cloner(minerais[Math.floor(rng() * 4)], 0.3, 1.4, 0.2, rng() * 6, 1.4));
        souche = cloner('Rock_1_A', p.x, 0, p.z, rng() * 6, 2); rayon = 1.4;
      } else {
        creerAssetsProc();
        if (rng() < 0.35) g.add(cloner('proc_baies', 0, 0, 0, rng() * 6, 1));
        else { const cul = ['proc_citrouille', 'proc_pasteque', 'proc_chou'][Math.floor(rng() * 3)];
          for (let f = 0; f < 4; f++) { const fx = (f % 2 - 0.5) * 1.5, fz = (Math.floor(f / 2) - 0.5) * 1.5; g.add(cloner(cul, fx, 0, fz, rng() * 6, 0.9 + rng() * 0.2)); } rayon = 1.3; }
        souche = cloner('Grass_1_A', p.x, 0, p.z, 0, 3);
      }
      g.traverse(o => { if (o.isMesh) o.castShadow = true; });
      souche.visible = false; groupe.add(souche);
      noeuds.push({ pos: p, obj: g, souche, pv: 6, pvMax: 6, regenT: 0, rayon, inst: [], reel: false, groupe });
      collisions.push({ x: p.x, z: p.z, r: rayon * 0.7, noeud: noeuds[noeuds.length - 1] });
    }
  }
  // les nœuds sont dessinés en instances (une poignée d’appels GPU au lieu de plusieurs centaines)
  const lots = new Map();
  for (const n of noeuds) { n.obj.updateMatrixWorld(true); for (const c of n.obj.children) { const k = c.userData.cle; if (!lots.has(k)) lots.set(k, []); lots.get(k).push({ n, m: c.matrixWorld.clone() }); } }
  for (const [cle, liste] of lots) {
    const src = G.assets[cle].scene; src.updateMatrixWorld(true);
    src.traverse(o => {
      if (!o.isMesh) return;
      const im = new THREE.InstancedMesh(o.geometry, o.material, liste.length); im.castShadow = true; im.receiveShadow = true; im.matrixAutoUpdate = false;
      liste.forEach((e, i) => { const mat = new THREE.Matrix4().multiplyMatrices(e.m, o.matrixWorld); im.setMatrixAt(i, mat); e.n.inst.push({ im, i, mat }); });
      im.computeBoundingSphere(); groupe.add(im);
    });
  }
  // herbes et fleurs décoratives
  for (const t of terre) for (let k = 0; k < 2; k++) { const a = rng() * 6.28, rr = 2.5 + rng() * 1.5; inst.ajouter(rng() < 0.7 ? 'Grass_1_A' : 'flower_yellowA', t.p.x + Math.cos(a) * rr, 0, t.p.z + Math.sin(a) * rr, rng() * 6, 1.8, 1.8, 1.8); }
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

// un nœud passe en objet « réel » pendant qu’on le secoue, le coupe ou qu’il repousse, puis revient en instance
const ZERO = new THREE.Matrix4().makeScale(0, 0, 0);
// ---------------- Le Goulet des Braises : champ de bataille 10 contre 10 (calqué sur le Goulet des Chanteguerres) ----------------
// étendard peint à la main aux couleurs du camp
function etendard(groupe, x, z, rotY, coul, camp, h = 5.2) {
  const tex = texture('etendard_' + camp, 128, 256, (g, w, hh) => {
    const gr = g.createLinearGradient(0, 0, 0, hh); gr.addColorStop(0, coul); gr.addColorStop(1, camp === 'bleu' ? '#0c1c4a' : '#4a0c0c');
    g.fillStyle = gr; g.beginPath(); g.moveTo(0, 0); g.lineTo(w, 0); g.lineTo(w, hh - 40); g.lineTo(w / 2, hh); g.lineTo(0, hh - 40); g.closePath(); g.fill();
    g.strokeStyle = '#ffd27a'; g.lineWidth = 7; g.stroke();
    g.fillStyle = '#ffd27a'; g.strokeStyle = '#7a5a1a'; g.lineWidth = 3;
    if (camp === 'bleu') { // aile et étoile de la garde d'azur
      g.beginPath(); g.moveTo(64, 60); for (let i = 0; i < 10; i++) { const a = -Math.PI / 2 + i * Math.PI / 5, r = i % 2 ? 11 : 26; g.lineTo(64 + Math.cos(a) * r, 92 + Math.sin(a) * r); } g.closePath(); g.fill(); g.stroke();
      for (let i = 0; i < 4; i++) { g.beginPath(); g.moveTo(30, 130 + i * 18); g.quadraticCurveTo(64, 116 + i * 18, 98, 130 + i * 18); g.lineTo(90, 140 + i * 18); g.quadraticCurveTo(64, 128 + i * 18, 38, 140 + i * 18); g.closePath(); g.fill(); g.stroke(); }
    } else { // flamme de la horde des braises
      g.beginPath(); g.moveTo(64, 56); g.bezierCurveTo(96, 96, 104, 130, 86, 170); g.bezierCurveTo(84, 146, 74, 136, 70, 128); g.bezierCurveTo(74, 160, 62, 186, 64, 200); g.bezierCurveTo(40, 186, 26, 150, 44, 118); g.bezierCurveTo(46, 134, 52, 140, 56, 142); g.bezierCurveTo(48, 110, 54, 84, 64, 56); g.fill(); g.stroke();
    }
  });
  const g = new THREE.Group();
  const hampe = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.08, h + 0.6, 6), new THREE.MeshStandardMaterial({ color: '#4a3020', roughness: 0.7 })); hampe.position.y = (h + 0.6) / 2; g.add(hampe);
  const barre = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, 1.7, 6), hampe.material); barre.rotation.z = Math.PI / 2; barre.position.y = h; g.add(barre);
  const toile = new THREE.Mesh(new THREE.PlaneGeometry(1.6, 3.2), new THREE.MeshStandardMaterial({ map: tex, side: THREE.DoubleSide, transparent: true, alphaTest: 0.5, roughness: 0.9 }));
  toile.position.y = h - 1.6; g.add(toile);
  g.position.set(x, 0, z); g.rotation.y = rotY; groupe.add(g);
}
// herse de fer : fermée pendant la préparation, elle se lève au début du combat
function herse(groupe, x, z, largeur, rotY) {
  const g = new THREE.Group(); const fer = new THREE.MeshStandardMaterial({ color: '#2a2a30', metalness: 0.7, roughness: 0.45 });
  for (let u = -largeur / 2 + 0.25; u <= largeur / 2; u += 0.55) { const b = new THREE.Mesh(new THREE.BoxGeometry(0.14, 6, 0.14), fer); b.position.set(u, 3, 0); g.add(b); const p = new THREE.Mesh(new THREE.ConeGeometry(0.12, 0.35, 4), fer); p.position.set(u, -0.1, 0); p.rotation.x = Math.PI; g.add(p); }
  for (let y = 0.8; y < 6; y += 1.1) { const b = new THREE.Mesh(new THREE.BoxGeometry(largeur, 0.12, 0.12), fer); b.position.y = y; g.add(b); }
  g.position.set(x, 0, z); g.rotation.y = rotY; g.traverse(o => { if (o.isMesh) o.castShadow = true; }); g.userData.dyn = true; groupe.add(g); return g;
}
// relief du Goulet : collines douces sur le champ (jamais dans les châteaux ni sur la piste centrale), coteaux sur les bords
const lisse = (a, b, x) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
const BOSSES = [[-22, 15, 1.35, 8], [22, -15, 1.35, 8], [-6, -21, 1.1, 7], [6, 21, 1.1, 7], [-31, -22, 0.9, 6], [31, 22, 0.9, 6], [-12, 9, 0.6, 5], [12, -9, 0.6, 5]];
export function hauteurGoulet(x, z) {
  const ax = Math.abs(x), az = Math.abs(z);
  let v = 0;
  for (const [bx, bz, A, s] of BOSSES) { const dx = x - bx, dz = z - bz; v += A * Math.exp(-(dx * dx + dz * dz) / (2 * s * s)); }
  v += 0.22 * Math.sin(x * 0.17 + 1) * Math.cos(z * 0.21);
  v = Math.max(-0.15, v) * (1 - lisse(36, 44, ax)) * lisse(3.5, 9, az);
  v += lisse(29, 42, az) * (6 + 2 * Math.sin(x * 0.11)) + lisse(79, 95, ax) * 8; // coteaux hors du terrain de jeu
  return v;
}
export function construireGoulet() {
  const groupe = new THREE.Group();
  G.torches = []; G.feux = []; G.anims = [];
  const L = 70, Lz = 30; // demi-longueur et demi-largeur du champ
  // sol peint : herbe dense, trèfle, touffes claires, terre
  const tex = texture('sol_goulet2', 1024, 1024, (g, w, h) => {
    g.fillStyle = '#5c7a36'; g.fillRect(0, 0, w, h);
    for (let i = 0; i < 5200; i++) { const x = Math.random() * w, y = Math.random() * h, r = 3 + Math.random() * 14; const k = Math.random(); g.fillStyle = k < 0.45 ? `rgba(120,150,62,${0.18 + Math.random() * 0.25})` : k < 0.8 ? `rgba(70,98,40,${0.2 + Math.random() * 0.25})` : `rgba(110,92,58,${0.12 + Math.random() * 0.18})`; g.beginPath(); g.arc(x, y, r, 0, 7); g.fill(); }
    for (let i = 0; i < 9000; i++) { const x = Math.random() * w, y = Math.random() * h, l = 4 + Math.random() * 7, a = -0.4 + Math.random() * 0.8; g.strokeStyle = Math.random() < 0.6 ? `rgba(170,200,95,${0.25 + Math.random() * 0.35})` : `rgba(40,70,28,${0.25 + Math.random() * 0.3})`; g.lineWidth = 1.2; g.beginPath(); g.moveTo(x, y); g.lineTo(x + Math.sin(a) * l, y - Math.cos(a) * l); g.stroke(); }
    for (let i = 0; i < 260; i++) { const x = Math.random() * w, y = Math.random() * h; g.fillStyle = ['#f4f0d0', '#ffd85a', '#e8a0d8', '#ffffff'][i % 4]; g.globalAlpha = 0.7; g.beginPath(); g.arc(x, y, 1.6, 0, 7); g.fill(); g.globalAlpha = 1; }
  }, { repeat: true });
  tex.repeat.set(22, 12); tex.anisotropy = 4;
  // chemins de terre battue : la grande allée entre les portes, les sentiers du tunnel et du flanc sud
  const CHEMINS = [];
  { const ligne = (pts) => CHEMINS.push(pts);
    const allee = []; for (let x = -46; x <= 46; x += 4) allee.push([x, 3.2 * Math.sin(x * 0.07)]); ligne(allee);
    for (const s of [-1, 1]) { ligne([[s * 67.5, 28], [s * 52, 26.5], [s * 38, 23], [s * 24, 15], [s * 10, 6]]); ligne([[s * 44, -6], [s * 34, -15], [s * 18, -18], [s * 4, -11]]); ligne([[s * 54, 21], [s * 50, 25]]); }
  }
  const distChemin = (x, z) => { let d = 1e9; for (const p of CHEMINS) for (let i = 1; i < p.length; i++) { const [ax, az] = p[i - 1], [bx, bz] = p[i]; const vx = bx - ax, vz = bz - az, t = Math.max(0, Math.min(1, ((x - ax) * vx + (z - az) * vz) / (vx * vx + vz * vz))); d = Math.min(d, Math.hypot(x - ax - vx * t, z - az - vz * t)); } return d; };
  const gSol = new THREE.PlaneGeometry(L * 2 + 60, Lz * 2 + 50, 150, 80);
  { const p = gSol.attributes.position, cols = new Float32Array(p.count * 3);
    for (let i = 0; i < p.count; i++) {
      const x = p.getX(i), z = -p.getY(i), h = hauteurGoulet(x, z); p.setZ(i, h);
      const bord = Math.max(lisse(29, 40, Math.abs(z)), lisse(79, 92, Math.abs(x))), haut = Math.min(1, Math.max(0, h) / 1.4) * (1 - bord);
      const terre = (1 - lisse(1.2, 2.8, distChemin(x, z))) * (1 - bord);
      let r = 0.95 - bord * 0.35 + haut * 0.1, gg = 0.97 - bord * 0.28 + haut * 0.12, bb = 0.9 - bord * 0.4;
      const n = 0.9 + 0.1 * Math.sin(x * 0.09 + Math.sin(z * 0.13) * 2) * Math.cos(z * 0.11 - x * 0.03) + 0.05 * Math.sin(x * 0.31 + z * 0.27);
      r *= n * (1 - terre * 0.25); gg *= n * (1 - terre * 0.2); bb *= n * (1 - terre * 0.3);
      cols[i * 3] = r; cols[i * 3 + 1] = gg; cols[i * 3 + 2] = bb;
    }
    gSol.setAttribute('color', new THREE.BufferAttribute(cols, 3)); gSol.computeVertexNormals(); }
  const sol = new THREE.Mesh(gSol, new THREE.MeshStandardMaterial({ map: tex, roughness: 0.95, vertexColors: true }));
  sol.rotation.x = -Math.PI / 2; sol.receiveShadow = true; groupe.add(sol);
  const H = hauteurGoulet;
  // sentiers de terre : bandes texturées qui épousent le relief, bords fondus dans l'herbe
  { const tTerre = texture('terre_chemin', 256, 256, (g, w2, h2) => {
      g.fillStyle = '#7a6448'; g.fillRect(0, 0, w2, h2);
      for (let i = 0; i < 900; i++) { const x = Math.random() * w2, y = Math.random() * h2, r = 1 + Math.random() * 5; g.fillStyle = Math.random() < 0.5 ? `rgba(140,118,86,${0.3 + Math.random() * 0.3})` : `rgba(84,66,46,${0.3 + Math.random() * 0.3})`; g.beginPath(); g.arc(x, y, r, 0, 7); g.fill(); }
      for (let i = 0; i < 120; i++) { const x = Math.random() * w2, y = Math.random() * h2; g.fillStyle = `rgba(176,168,152,${0.35 + Math.random() * 0.3})`; g.beginPath(); g.ellipse(x, y, 2 + Math.random() * 3, 1.5 + Math.random() * 2, Math.random() * 3, 0, 7); g.fill(); }
    }, { repeat: true });
    const tBord = texture('bord_chemin', 64, 4, (g, w2) => { const gr = g.createLinearGradient(0, 0, w2, 0); gr.addColorStop(0, 'rgba(255,255,255,0)'); gr.addColorStop(0.28, 'rgba(255,255,255,1)'); gr.addColorStop(0.72, 'rgba(255,255,255,1)'); gr.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = gr; g.fillRect(0, 0, w2, 4); });
    const matC = new THREE.MeshStandardMaterial({ map: tTerre, alphaMap: tBord, transparent: true, opacity: 0.9, depthWrite: false, roughness: 1, polygonOffset: true, polygonOffsetFactor: -4, polygonOffsetUnits: -4 });
    for (const pts of CHEMINS) {
      const sm = []; for (let i = 1; i < pts.length; i++) { const [ax, az] = pts[i - 1], [bx, bz] = pts[i]; const n = Math.max(1, Math.ceil(Math.hypot(bx - ax, bz - az))); for (let k = 0; k < n; k++) sm.push([ax + (bx - ax) * k / n, az + (bz - az) * k / n]); } sm.push(pts[pts.length - 1]);
      const pos = [], uv = [], idx = []; let along = 0; const L2 = 3.6, NC = 5;
      const total = sm.length - 1;
      sm.forEach(([x, z], i) => { const [px, pz] = sm[Math.max(0, i - 1)], [nx, nz] = sm[Math.min(sm.length - 1, i + 1)]; let dx = nx - px, dz = nz - pz; const l = Math.hypot(dx, dz) || 1; dx /= l; dz /= l; if (i) along += Math.hypot(x - sm[i - 1][0], z - sm[i - 1][1]);
        const fin = Math.min(1, (i + 0.3) / 3.5, (total - i + 0.3) / 3.5), Lw = L2 * (0.25 + 0.75 * fin);
        for (let c = 0; c < NC; c++) { const s = c / (NC - 1) * 2 - 1; const vx = x - dz * s * Lw / 2, vz = z + dx * s * Lw / 2; pos.push(vx, H(vx, vz) + 0.07, vz); uv.push(c / (NC - 1), along / 4); }
        if (i) for (let c = 0; c < NC - 1; c++) { const b = i * NC + c, p = b - NC; idx.push(p, p + 1, b, p + 1, b + 1, b); } });
      const g2 = new THREE.BufferGeometry(); g2.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g2.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); g2.setIndex(idx); g2.computeVertexNormals();
      const m = new THREE.Mesh(g2, matC); m.receiveShadow = true; m.renderOrder = 1; groupe.add(m);
    }
  }
  const collisions = [], murs = [];
  const inst = new Instancieur();
  const a = (k) => (k in G.assets ? k : null);
  const pick = (l) => l.filter(a)[Math.floor(Math.random() * l.filter(a).length)];
  // forêt dense sur les coteaux nord et sud, falaises derrière les châteaux
  for (let x = -L - 16; x <= L + 16; x += 3.6) for (const s of [-1, 1]) for (let rang = 0; rang < 3; rang++) {
    const z = s * (Lz + 3.5 + rang * 4.2 + Math.random() * 2.4), xx = x + (Math.random() - 0.5) * 3;
    const k = pick(['n_tree_oak', 'n_tree_detailed', 'n_tree_default', 'n_tree_fat_darkh', 'Tree_1_A', 'Tree_3_A']); if (!k) continue;
    const ken = k.startsWith('n_'), sc = (ken ? 4.2 : 1.9) * (0.8 + Math.random() * 0.5);
    inst.ajouter(k, xx, H(xx, z) - 0.1, z, Math.random() * 6.28, sc, sc, sc);
    if (rang === 0 && Math.random() < 0.35) { const r = pick(['n_rock_largeB', 'n_rock_largeC', 'Rock_3_C']); inst.ajouter(r, xx + 1.8, H(xx + 1.8, z - s * 1.5), z - s * 1.5, Math.random() * 6, r.startsWith('n_') ? 2.2 : 1.6, r.startsWith('n_') ? 2.2 : 1.6, r.startsWith('n_') ? 2.2 : 1.6); }
  }
  for (let z = -Lz - 8; z <= Lz + 8; z += 4.5) for (const s of [-1, 1]) { const xx = s * (L + 15 + Math.random() * 4); inst.ajouter('Rock_3_C', xx, H(xx, z) - 0.2, z, Math.random() * 6, 3.2, 3.6, 3.2); }
  // prairie : touffes d'herbe et fleurs (jamais sur les chemins)
  for (let i = 0; i < 520; i++) {
    const x = (Math.random() - 0.5) * 90, z = (Math.random() - 0.5) * 58; if (distChemin(x, z) < 3) continue;
    const fl = Math.random() < 0.18;
    const k = fl ? pick(['n_flower_purpleB', 'n_flower_redC', 'n_flower_yellowC', 'n_flower_purpleC', 'flower_yellowA', 'flower_redA', 'flower_purpleA']) : pick(['n_grass', 'n_grass', 'Grass_2_A']);
    if (!k) continue; const ken = k.startsWith('n_'), sc = (ken ? (fl ? 4.6 : 2.6) : (fl ? 1.3 : 1.0)) * (0.75 + Math.random() * 0.5);
    inst.ajouter(k, x, H(x, z) - 0.03, z, Math.random() * 6.28, sc, sc, sc);
  }
  // pierres plates, souches et troncs couchés au pied des collines
  for (const [x, z] of [[-26, 21], [26, -21], [-14, 24], [14, -24], [-38, -24], [38, 24], [-3, 26], [3, -26], [-20, -26], [20, 26]]) {
    const k = pick(['n_stump_old', 'n_log_large', 'n_stone_largeC', 'n_stump_round', 'Rock_1_A']); if (!k) continue;
    const sc = k.startsWith('n_') ? 2.6 : 1.3; inst.ajouter(k, x, H(x, z) - 0.05, z, Math.random() * 6, sc, sc, sc); collisions.push({ x, z, r: 0.9 });
  }
  // dalles de pierre devant les grandes portes
  for (const s of [-1, 1]) for (let k = 0; k < 6; k++) { const x = s * (44 - k * 2.4), z = 3.2 * Math.sin(x * 0.07); if (a('n_path_stone')) inst.ajouter('n_path_stone', x, H(x, z) + 0.01, z, Math.random() * 6, 3.4, 3.4, 3.4); }
  // couverts au milieu du champ
  const couverts = [[-30, -12], [-30, 13], [0, -16], [0, 15], [30, -12], [30, 13], [-14, 1], [14, -1]];
  for (const [x, z] of couverts) {
    inst.ajouter('Rock_3_C', x, H(x, z) + 0.5, z, Math.random() * 6, 3.2, 3.2, 3.2); inst.ajouter('Rock_1_A', x + 2, H(x + 2, z + 1.5) - 0.1, z + 1.5, Math.random() * 6, 2.4, 2.4, 2.4);
    collisions.push({ x, z, r: 2.6 }, { x: x + 2, z: z + 1.5, r: 1.3 });
  }
  // arbres épars sur les collines du champ (hors des chemins)
  for (const [x, z] of [[-9, -26], [9, 26], [-35, 26], [35, -26]]) { inst.ajouter('Tree_' + ['1_A', '2_B', '3_A'][Math.floor(Math.random() * 3)], x, H(x, z) - 0.1, z, Math.random() * 6, 1.25, 1.25, 1.25); collisions.push({ x, z, r: 0.8 }); }
  const pierre = pierreMat('#6a6470', '#4a4652');
  // mur de pierre entre deux points : pièces de rempart + cercles de collision serrés
  const mur = (x0, z0, x1, z1, hk = 1.6) => {
    const dx = x1 - x0, dz = z1 - z0, len = Math.hypot(dx, dz), n = Math.max(1, Math.round(len / 6.4)), pl = len / n, rot = Math.atan2(-dz / len, dx / len);
    for (let i = 0; i < n; i++) { const t = (i + 0.5) / n; inst.ajouter('wall', x0 + dx * t, 0, z0 + dz * t, rot, pl / 4, hk, 1.6); }
    const m = Math.ceil(len / 1.4); for (let i = 0; i <= m; i++) { const t = i / m; collisions.push({ x: x0 + dx * t, z: z0 + dz * t, r: 1.25 }); }
    murs.push([x0, z0, x1, z1]);
  };
  const bases = {}, bonus = [];
  const F = 46, P = 62, B = 76, Zw = 18, T0 = 64, T1 = 71; // façade, cloison de la salle du drapeau, fond, demi-largeur, tunnel
  for (const [camp, sx, coul] of [['bleu', -1, '#3a7aff'], ['rouge', 1, '#ff3a3a']]) {
    const X = (a) => sx * a;
    // dallage intérieur
    const dal = new THREE.Mesh(new THREE.PlaneGeometry(B - F, Zw * 2), pierre); dal.rotation.x = -Math.PI / 2; dal.position.set(X((F + B) / 2), 0.03, 0); dal.receiveShadow = true; groupe.add(dal);
    pierre.map.repeat.set(4, 5);
    // remparts : façade avec grande porte, côtés (tunnel au nord), fond, cloison de la salle du drapeau
    mur(X(F), -Zw, X(F), -4.2); mur(X(F), 4.2, X(F), Zw);
    mur(X(F), -Zw, X(B), -Zw);
    mur(X(F), Zw, X(T0), Zw); mur(X(T1), Zw, X(B), Zw);
    mur(X(B), -Zw, X(B), Zw);
    mur(X(P), -Zw, X(P), -3.6, 1.2); mur(X(P), 3.6, X(P), Zw, 1.2);
    // le tunnel : couloir bas qui débouche dans la salle du drapeau
    mur(X(T0), Zw, X(T0), Zw + 7, 0.9); mur(X(T1), Zw, X(T1), Zw + 7, 0.9);
    for (const a of [T0 - 0.4, T1 + 0.4]) groupe.add(cloner('torch_mounted', X(a), 2, Zw + 6.5, 0, 1.2));
    // tours d'angle et tours de la porte
    for (const [a, z, k] of [[F, -Zw, 4.2], [F, Zw, 4.2], [B, -Zw, 4.2], [B, Zw, 4.2]]) { groupe.add(cloner('b_tower_A', X(a), 0, z, 0, k)); collisions.push({ x: X(a), z, r: 3 }); }
    // porte monumentale : piliers, linteau, herse
    for (const z of [-5, 5]) { groupe.add(cloner('pillar_decorated', X(F), 0, z, Math.PI / 2, 1.5)); collisions.push({ x: X(F), z, r: 1.4 }); }
    const linteau = new THREE.Mesh(new THREE.BoxGeometry(2.4, 1.3, 12), pierre); linteau.position.set(X(F), 6.3, 0); linteau.castShadow = true; groupe.add(linteau);
    const herses = [herse(groupe, X(F), 0, 8.4, Math.PI / 2), herse(groupe, X((T0 + T1) / 2), Zw + 6.6, T1 - T0, 0)];
    const portes = [];
    for (let z = -3.6; z <= 3.6; z += 1.2) portes.push({ x: X(F), z, r: 1.1 });
    for (let a = T0 + 0.6; a <= T1 - 0.6; a += 1.1) portes.push({ x: X(a), z: Zw + 6.6, r: 1.1 });
    // étendards et torches
    for (const z of [-8.5, 8.5]) etendard(groupe, X(F - 1.6), z, sx > 0 ? Math.PI / 2 : -Math.PI / 2, coul, camp);
    for (const z of [-10, 10]) etendard(groupe, X(B - 1.4), z, sx > 0 ? -Math.PI / 2 : Math.PI / 2, coul, camp, 6);
    for (const z of [-12, 12]) groupe.add(cloner('torch_mounted', X(P + 0.9), 2.2, z, sx > 0 ? Math.PI / 2 : -Math.PI / 2, 1.3));
    for (const z of [-11, 11]) brasero(groupe, X(54), z, coul, 1.2);
    // salle du drapeau : socle et anneau
    const fx = X(71);
    const socle = new THREE.Mesh(new THREE.CylinderGeometry(2.2, 2.6, 0.5, 24), new THREE.MeshStandardMaterial({ color: '#4a4048', roughness: 0.8 }));
    socle.position.set(fx, 0.25, 0); socle.receiveShadow = true; groupe.add(socle);
    const anneau = new THREE.Mesh(new THREE.RingGeometry(2.4, 2.9, 40), new THREE.MeshBasicMaterial({ color: coul, transparent: true, opacity: 0.7, blending: THREE.AdditiveBlending, depthWrite: false }));
    anneau.rotation.x = -Math.PI / 2; anneau.position.set(fx, 0.06, 0); groupe.add(anneau);
    G.anims.push((t) => { anneau.material.opacity = 0.45 + 0.3 * Math.sin(t * 3); });
    G.torches.push({ pos: new THREE.Vector3(fx, 4, 0), color: coul, int: 50, dist: 22 });
    // cimetière et esprit guérisseur, dehors contre le rempart nord (face à la caméra)
    const cim = new THREE.Vector3(X(54), 0, 22.5);
    { // tombes, croix et grille de fer
      const pierreT = new THREE.MeshStandardMaterial({ color: '#8a8490', roughness: 0.85, flatShading: true }), fer = new THREE.MeshStandardMaterial({ color: '#2a2630', metalness: 0.6, roughness: 0.5 });
      for (let i = 0; i < 8; i++) {
        const x = cim.x + (i % 4 - 1.5) * 2.4, z = cim.z + 2.6 + Math.floor(i / 4) * 2.2, g = new THREE.Group();
        if (i % 3 === 1) { const a = new THREE.Mesh(new THREE.BoxGeometry(0.22, 1.3, 0.22), pierreT); a.position.y = 0.65; const b = new THREE.Mesh(new THREE.BoxGeometry(0.8, 0.2, 0.22), pierreT); b.position.y = 0.95; g.add(a, b); }
        else { const s = new THREE.Mesh(new THREE.BoxGeometry(0.8, 0.9, 0.22), pierreT); s.position.y = 0.45; const t = new THREE.Mesh(new THREE.CylinderGeometry(0.4, 0.4, 0.22, 12, 1, false, 0, Math.PI), pierreT); t.rotation.set(Math.PI / 2, 0, Math.PI / 2); t.position.y = 0.9; g.add(s, t); }
        const tas = new THREE.Mesh(new THREE.BoxGeometry(0.9, 0.12, 1.6), new THREE.MeshStandardMaterial({ color: '#4a3a2a', roughness: 1 })); tas.position.set(0, 0.06, -0.95); g.add(tas);
        g.position.set(x, 0, z); g.rotation.set(0, (Math.random() - 0.5) * 0.2, (Math.random() - 0.5) * 0.12); g.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } }); groupe.add(g);
      }
      for (let k = -5.5; k <= 5.5; k += 0.5) { const b = new THREE.Mesh(new THREE.BoxGeometry(0.06, 1.1, 0.06), fer); b.position.set(cim.x + k, 0.55, cim.z + 6.8); groupe.add(b); const p = new THREE.Mesh(new THREE.ConeGeometry(0.06, 0.18, 4), fer); p.position.set(cim.x + k, 1.18, cim.z + 6.8); groupe.add(p); }
      const barre = new THREE.Mesh(new THREE.BoxGeometry(11, 0.06, 0.06), fer); barre.position.set(cim.x, 0.9, cim.z + 6.8); groupe.add(barre);
      inst.ajouter('Tree_Bare_2_A' in G.assets ? 'Tree_Bare_2_A' : 'Tree_1_A', cim.x - sx * 6.5, 0, cim.z + 5.2, 1, 1.6, 1.6, 1.6);
    }
    const esprit = new THREE.Mesh(new THREE.SphereGeometry(0.55, 16, 12), new THREE.MeshBasicMaterial({ color: '#d8f4ff' }));
    esprit.position.set(cim.x - sx * 5, 2.6, cim.z); esprit.userData.dyn = true; groupe.add(esprit);
    const halo = new THREE.Mesh(new THREE.RingGeometry(0.9, 1.4, 32), new THREE.MeshBasicMaterial({ color: '#9ad8ff', transparent: true, opacity: 0.6, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
    halo.position.copy(esprit.position); halo.userData.dyn = true; groupe.add(halo);
    G.anims.push((t) => { esprit.position.y = 2.6 + Math.sin(t * 2) * 0.25; halo.position.y = esprit.position.y; halo.rotation.y = t; halo.rotation.x = 0.4 * Math.sin(t); });
    G.torches.push({ pos: new THREE.Vector3(esprit.position.x, 3, cim.z), color: '#9ad8ff', int: 25, dist: 12 });
    for (const dx of [-6.5, 6.5]) brasero(groupe, cim.x + dx, cim.z - 2.2, '#ffb05a', 0.9);
    // bonus : vitesse dans la salle du drapeau (sortie du tunnel), soins dans la cour, berserk sur le champ
    bonus.push({ type: 'vitesse', pos: new THREE.Vector3(X(67.5), 0, 13) }, { type: 'soin', pos: new THREE.Vector3(X(50), 0, -13) }, { type: 'berserk', pos: new THREE.Vector3(X(22), 0, sx * 21) });
    bases[camp] = {
      pos: new THREE.Vector3(fx, 0, 0), spawn: new THREE.Vector3(X(56), 0, 0), cimetiere: cim, coul, herses, portes,
      porte: new THREE.Vector3(X(F - 4), 0, 0), tunnel: new THREE.Vector3(X((T0 + T1) / 2), 0, Zw + 9),
      dans: (x, z) => sx * x > F && sx * x < B && Math.abs(z) < Zw,
    };
  }
  fusionnerStatiques(groupe);
  inst.construire(groupe);
  G.scene.add(groupe);
  return {
    groupe, type: 'goulet', nom: 'Goulet des Braises', bases, collisions, murs, bonus, solH: hauteurGoulet,
    spawn: bases.bleu.spawn.clone(),
    bornes: { x0: -L - 10, x1: L + 10, z0: -Lz - 2, z1: Lz + 2 },
    marche: (x, z) => x > -L - 8 && x < L + 8 && z > -Lz && z < Lz,
  };
}
export function noeudReel(n, oui) {
  if (!!n.reel === oui) return;
  n.reel = oui;
  if (oui) n.groupe.add(n.obj); else { n.obj.removeFromParent(); n.obj.rotation.z = 0; n.obj.scale.setScalar(1); }
  for (const e of n.inst) { e.im.setMatrixAt(e.i, oui ? ZERO : e.mat); e.im.instanceMatrix.needsUpdate = true; }
}

// ---------- Cultures modélisées à la main : lisibles de loin (citrouilles, pastèques, choux, baies) ----------
export function creerAssetsProc() {
  if (G.assets.proc_citrouille) return;
  const std = (c, o = {}) => new THREE.MeshStandardMaterial({ color: c, roughness: 0.75, flatShading: true, ...o });
  const feuille = std('#3f9a34'), tige = std('#6a7a2a');
  const sol = (g) => { const t = new THREE.Mesh(new THREE.CylinderGeometry(0.95, 1.05, 0.08, 9), std('#7a4a2a')); t.position.y = 0.04; g.add(t); };
  const feuilles = (g, n, r, y = 0.12) => { for (let i = 0; i < n; i++) { const a = i / n * 6.28 + 0.4; const f = new THREE.Mesh(new THREE.SphereGeometry(0.28, 6, 4), feuille); f.scale.set(1.3, 0.25, 0.8); f.position.set(Math.cos(a) * r, y, Math.sin(a) * r); f.rotation.y = -a; g.add(f); } };
  const cit = new THREE.Group(); sol(cit); feuilles(cit, 5, 0.7);
  const corps = new THREE.Mesh(new THREE.SphereGeometry(0.5, 14, 9), std('#ff8418')); corps.scale.set(1, 0.72, 1); corps.position.y = 0.4; cit.add(corps);
  for (let i = 0; i < 6; i++) { const c = new THREE.Mesh(new THREE.SphereGeometry(0.5, 10, 8), std('#ff9a2e')); c.scale.set(0.42, 0.7, 0.5); const a = i / 6 * 6.28; c.position.set(Math.cos(a) * 0.3, 0.4, Math.sin(a) * 0.3); c.rotation.y = -a; cit.add(c); }
  const t = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.08, 0.25, 6), tige); t.position.y = 0.82; t.rotation.z = 0.25; cit.add(t);
  const pas = new THREE.Group(); sol(pas); feuilles(pas, 4, 0.75);
  const pc = new THREE.Mesh(new THREE.SphereGeometry(0.5, 14, 9), std('#2f8a35')); pc.scale.set(1.25, 0.78, 0.9); pc.position.y = 0.38; pas.add(pc);
  for (let i = 0; i < 5; i++) { const b = new THREE.Mesh(new THREE.SphereGeometry(0.5, 12, 8), std('#9ad85a')); b.scale.set(1.27, 0.8, 0.12); b.position.set(0, 0.38, (i - 2) * 0.17); pas.add(b); }
  const chou = new THREE.Group(); sol(chou);
  for (let i = 0; i < 7; i++) { const a = i / 7 * 6.28; const f = new THREE.Mesh(new THREE.SphereGeometry(0.35, 8, 6), std(i % 2 ? '#7ccf4a' : '#9ade5c')); f.scale.set(1, 0.55, 0.7); f.position.set(Math.cos(a) * 0.32, 0.25, Math.sin(a) * 0.32); f.rotation.set(0.5, -a, 0); chou.add(f); }
  const coeur = new THREE.Mesh(new THREE.SphereGeometry(0.33, 10, 8), std('#c8f07a')); coeur.position.y = 0.4; chou.add(coeur);
  const baies = new THREE.Group();
  const bb = G.assets.Bush_2_C.scene.clone(true); bb.scale.setScalar(1.1); baies.add(bb);
  const bx = new THREE.Box3().setFromObject(bb), bc = bx.getCenter(new THREE.Vector3()), bs = bx.getSize(new THREE.Vector3());
  const rouge = std('#ff2a4a', { emissive: '#5a0010', roughness: 0.35, flatShading: false });
  // baies posées sur les faces du buisson (cube arrondi)
  for (let i = 0; i < 22; i++) {
    const h1 = (x) => { const s = Math.sin(x) * 43758.5453; return s - Math.floor(s); }; const face = i % 5, u = (h1(i * 12.99 + 1) - 0.5) * 0.85, v = (h1(i * 78.23 + 7) - 0.5) * 0.85;
    const p = face === 4 ? new THREE.Vector3(u * bs.x, bs.y / 2 + 0.06, v * bs.z) : new THREE.Vector3(...(face < 2 ? [(face ? 1 : -1) * (bs.x / 2 + 0.06), v * bs.y, u * bs.z] : [u * bs.x, v * bs.y, (face === 2 ? 1 : -1) * (bs.z / 2 + 0.06)]));
    const s = new THREE.Mesh(new THREE.SphereGeometry(0.12, 8, 6), rouge); s.position.copy(p.add(bc)); baies.add(s);
  }
  for (const [k, g] of [['proc_citrouille', cit], ['proc_pasteque', pas], ['proc_chou', chou], ['proc_baies', baies]]) {
    g.traverse(o => { if (o.isMesh) { o.castShadow = true; o.receiveShadow = true; } });
    G.assets[k] = { scene: g, animations: [], hauteur: 1 };
  }
}

// ================= Sanctuaire d'Émeraude : donjon de groupe (5 joueurs) =================
// un seul chemin continu : tronçon → clairière du boss → tronçon → … → cœur de la forêt
function distSeg(px, pz, a, b) {
  const vx = b.x - a.x, vz = b.z - a.z, l2 = vx * vx + vz * vz;
  let t = l2 ? ((px - a.x) * vx + (pz - a.z) * vz) / l2 : 0; t = Math.max(0, Math.min(1, t));
  const dx = px - (a.x + vx * t), dz = pz - (a.z + vz * t); return Math.sqrt(dx * dx + dz * dz);
}
const texHerbe = () => texture('herbeSylve', 256, 256, (g, w) => {
  g.fillStyle = '#3f8a3a'; g.fillRect(0, 0, w, w);
  for (let i = 0; i < 2600; i++) { const x = Math.random() * w, y = Math.random() * w, l = 30 + Math.random() * 30; g.fillStyle = `hsl(${100 + Math.random() * 30},${45 + Math.random() * 20}%,${l}%)`; g.fillRect(x, y, 2, 3 + Math.random() * 4); }
  for (let i = 0; i < 40; i++) { const x = Math.random() * w, y = Math.random() * w; const gr = g.createRadialGradient(x, y, 0, x, y, 30); gr.addColorStop(0, 'rgba(20,60,20,.35)'); gr.addColorStop(1, 'rgba(20,60,20,0)'); g.fillStyle = gr; g.fillRect(x - 30, y - 30, 60, 60); }
}, { repeat: true });
const texChemin = () => texture('cheminSylve', 128, 256, (g, w, h) => {
  g.clearRect(0, 0, w, h);
  const bord = (y) => 10 + 8 * Math.sin(y * 0.11) + 5 * Math.sin(y * 0.37 + 1);
  for (let y = 0; y < h; y++) { const b = bord(y), b2 = bord(y + 40); g.fillStyle = '#8a7350'; g.fillRect(b, y, w - b - b2, 1); }
  for (let i = 0; i < 70; i++) { const y = Math.random() * h, x = 18 + Math.random() * (w - 36), r = 4 + Math.random() * 9; g.fillStyle = `hsl(${30 + Math.random() * 15},${10 + Math.random() * 12}%,${48 + Math.random() * 18}%)`; g.beginPath(); g.ellipse(x, y, r, r * 0.75, Math.random() * 3, 0, 7); g.fill(); g.strokeStyle = 'rgba(40,30,20,.35)'; g.lineWidth = 1.5; g.stroke(); }
  for (let i = 0; i < 260; i++) { const y = Math.random() * h, x = Math.random() * w; g.fillStyle = 'rgba(70,140,50,.55)'; g.fillRect(x, y, 2, 2); }
}, { repeat: true });
const texDalles = () => texture('dallesSylve', 512, 512, (g, w) => {
  g.fillStyle = '#6f7a66'; g.fillRect(0, 0, w, w); g.translate(w / 2, w / 2);
  for (let r = 0; r < 8; r++) { const n = 6 + r * 6; for (let i = 0; i < n; i++) { const a0 = i / n * 6.283, a1 = (i + 1) / n * 6.283; g.beginPath(); g.arc(0, 0, r * 32 + 30, a0 + 0.02, a1 - 0.02); g.arc(0, 0, r * 32 + 2, a1 - 0.02, a0 + 0.02, true); g.closePath(); g.fillStyle = `hsl(${90 + Math.random() * 40},${8 + Math.random() * 10}%,${45 + Math.random() * 15}%)`; g.fill(); } }
  for (let i = 0; i < 500; i++) { const a = Math.random() * 6.28, rr = Math.random() * 250; g.fillStyle = 'rgba(70,150,60,.5)'; g.fillRect(Math.cos(a) * rr, Math.sin(a) * rr, 3, 3); }
});
let sylveProcPret = false;
function preparerSylve() {
  if (sylveProcPret) return; sylveProcPret = true;
  // champignons lumineux
  const lum = (cle, nom, couleur, k) => G.assets[cle] && G.assets[cle].scene.traverse(o => { if (o.isMesh && o.material.name === nom) { o.material = o.material.clone(); o.material.color.set(couleur); o.material.emissive = new THREE.Color(couleur); o.material.emissiveIntensity = k; } });
  for (const c of ['n_mushroom_red', 'n_mushroom_redTall', 'n_mushroom_redGroup']) lum(c, 'colorRed', '#ff4ab8', 0.9);
  for (const c of ['n_mushroom_tan', 'n_mushroom_tanTall', 'n_mushroom_tanGroup']) lum(c, 'colorTan', '#4ae8ff', 1.0);
  for (const c of ['n_flower_purpleB', 'n_flower_purpleC']) lum(c, 'colorPurple', '#c97aff', 0.5);
}
export function construireSylve() {
  preparerSylve();
  const groupe = new THREE.Group();
  G.torches = []; G.feux = []; G.anims = [];
  const rng = graineRng(4242);
  const P = (x, z) => new THREE.Vector3(x, 0, z);
  const salles = [
    { id: 0, c: P(56, -10), r: 17, nom: 'Clairière des Lucioles' },
    { id: 1, c: P(130, -2), r: 17, nom: 'Bassin des Sylphes' },
    { id: 2, c: P(196, -16), r: 17, nom: 'Taillis du Chasseur' },
    { id: 3, c: P(282, -6), r: 23, nom: 'Cœur d’Émeraude' },
  ];
  const troncons = [
    [P(0, 0), P(13, 4), P(26, 1), P(38, -6)],
    [P(76, -5), P(88, 4), P(102, 8), P(114, 4)],
    [P(148, -8), P(160, -20), P(176, -24)],
    [P(214, -10), P(228, 2), P(244, 6), P(258, 0)],
  ];
  const ligne = [];
  troncons.forEach((t, i) => { ligne.push(...t); ligne.push(salles[i].c); });
  const segs = []; for (let i = 0; i < ligne.length - 1; i++) segs.push([ligne[i], ligne[i + 1]]);
  const DEMI = 5.2;
  const distChemin = (x, z) => { let d = Infinity; for (const [a, b] of segs) d = Math.min(d, distSeg(x, z, a, b)); return d; };
  const dansSalle = (x, z, marge = 0) => salles.find(s => (x - s.c.x) ** 2 + (z - s.c.z) ** 2 < (s.r + marge) ** 2);
  const marche = (x, z) => !!dansSalle(x, z, 0.8) || distChemin(x, z) < DEMI;
  // abscisse le long du chemin (pour que les joueurs du groupe suivent la route comme des humains)
  const cum = [0]; for (const [a, b] of segs) cum.push(cum[cum.length - 1] + a.distanceTo(b));
  const abscisse = (x, z) => { let best = Infinity, s = 0; segs.forEach(([a, b], i) => { const vx = b.x - a.x, vz = b.z - a.z, l2 = vx * vx + vz * vz; let t = l2 ? ((x - a.x) * vx + (z - a.z) * vz) / l2 : 0; t = Math.max(0, Math.min(1, t)); const dx = x - (a.x + vx * t), dz = z - (a.z + vz * t), d = dx * dx + dz * dz; if (d < best) { best = d; s = cum[i] + t * Math.sqrt(l2); } }); return s; };
  const pointA = (s) => { s = Math.max(0, Math.min(cum[cum.length - 1], s)); for (let i = 0; i < segs.length; i++) if (s <= cum[i + 1]) { const [a, b] = segs[i]; const t = (s - cum[i]) / Math.max(1e-6, cum[i + 1] - cum[i]); return { p: a.clone().lerp(b, t), dir: b.clone().sub(a).normalize() }; } const [a, b] = segs[segs.length - 1]; return { p: b.clone(), dir: b.clone().sub(a).normalize() }; };
  const collisions = [];
  // sol
  const tH = texHerbe(); tH.repeat.set(70, 26);
  const sol = new THREE.Mesh(new THREE.PlaneGeometry(380, 140), new THREE.MeshStandardMaterial({ map: tH, color: '#cfe8c0', roughness: 1 }));
  sol.rotation.x = -Math.PI / 2; sol.position.set(140, -0.02, -8); sol.receiveShadow = true; groupe.add(sol);
  // ruban du chemin (une seule géométrie)
  const pts = []; for (const [a, b] of segs) { const l = a.distanceTo(b), n = Math.max(1, Math.ceil(l / 1.5)); for (let i = 0; i < n; i++) pts.push(a.clone().lerp(b, i / n)); } pts.push(ligne[ligne.length - 1].clone());
  const pos = [], uv = [], idx = []; let dist = 0;
  for (let i = 0; i < pts.length; i++) {
    const a = pts[Math.max(0, i - 1)], b = pts[Math.min(pts.length - 1, i + 1)];
    const t = b.clone().sub(a).normalize(); const nx = -t.z, nz = t.x;
    if (i) dist += pts[i].distanceTo(pts[i - 1]);
    const L = DEMI + 0.3;
    pos.push(pts[i].x + nx * L, 0.02, pts[i].z + nz * L, pts[i].x - nx * L, 0.02, pts[i].z - nz * L);
    uv.push(0, dist / 6, 1, dist / 6);
    if (i) { const k = i * 2; idx.push(k - 2, k - 1, k, k - 1, k + 1, k); }
  }
  const gr = new THREE.BufferGeometry(); gr.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); gr.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2)); gr.setIndex(idx); gr.computeVertexNormals();
  const ruban = new THREE.Mesh(gr, new THREE.MeshStandardMaterial({ map: texChemin(), alphaTest: 0.4, roughness: 0.95, side: THREE.DoubleSide }));
  ruban.receiveShadow = true; groupe.add(ruban);
  const inst = new Instancieur(), arbres = new Instancieur();
  const essence = ['Tree_1_A', 'Tree_3_A', 'Tree_2_C', 'n_tree_oak', 'n_tree_detailed', 'n_tree_fat_darkh'];
  const planter = (x, z) => { const k = essence[Math.floor(rng() * essence.length)]; const kenney = k.startsWith('n_'); arbres.ajouter(k, x, 0, z, rng() * 6.28, ...Array(3).fill((kenney ? 4.4 : 0.72) * (0.8 + rng() * 0.45))); };
  // forêt dense le long du chemin
  for (let i = 0; i < pts.length; i += 2) {
    const a = pts[Math.max(0, i - 1)], b = pts[Math.min(pts.length - 1, i + 1)];
    const t = b.clone().sub(a).normalize(); const nx = -t.z, nz = t.x;
    for (const cote of [1, -1]) {
      for (let k = 0; k < 3; k++) {
        const o = 7.5 + k * 4.5 + rng() * 3; const x = pts[i].x + nx * o * cote + (rng() - 0.5) * 2, z = pts[i].z + nz * o * cote + (rng() - 0.5) * 2;
        if (distChemin(x, z) < DEMI + 2.2 || dansSalle(x, z, 3)) continue;
        if (rng() < 0.8) planter(x, z);
      }
      // sous-bois au bord du chemin
      const o = DEMI + 0.6 + rng() * 1.8; const x = pts[i].x + nx * o * cote, z = pts[i].z + nz * o * cote;
      if (!dansSalle(x, z, 1)) {
        const r = rng();
        if (r < 0.28) inst.ajouter(['Bush_1_A', 'Bush_2_C', 'Bush_3_B', 'Bush_4_A'][Math.floor(rng() * 4)], x, 0, z, rng() * 6, 1.1, 1.1, 1.1);
        else if (r < 0.45) inst.ajouter(['n_plant_bushLarge', 'n_plant_bushDetailed', 'n_plant_flatTall'][Math.floor(rng() * 3)], x, 0, z, rng() * 6, 3.4, 3.4, 3.4);
        else if (r < 0.58) inst.ajouter(['n_mushroom_redTall', 'n_mushroom_tanTall', 'n_mushroom_redGroup', 'n_mushroom_tanGroup'][Math.floor(rng() * 4)], x, 0, z, rng() * 6, 4.4, 4.4, 4.4);
        else if (r < 0.7) inst.ajouter(['n_flower_purpleB', 'n_flower_redC', 'n_flower_yellowC', 'n_flower_purpleC'][Math.floor(rng() * 4)], x, 0, z, rng() * 6, 5, 5, 5);
        else if (r < 0.8) inst.ajouter(['Rock_1_A', 'Rock_2_C', 'n_rock_largeB', 'n_stump_old'][Math.floor(rng() * 4)], x, 0, z, rng() * 6, 1.2, 1.2, 1.2);
        else if (r < 0.86) inst.ajouter('n_log_large', x, 0, z, rng() * 6, 3, 3, 3);
      }
    }
    // touffes d'herbe sur le chemin, côté bord
    if (rng() < 0.6) { const c = rng() < 0.5 ? 1 : -1, o = DEMI - 0.3 - rng(); inst.ajouter('Grass_1_A', pts[i].x + nx * o * c, 0, pts[i].z + nz * o * c, rng() * 6, 1.6, 1.6, 1.6); }
  }
  // clairières des boss
  const tD = texDalles();
  const barrieres = [];
  for (const s of salles) {
    const disque = new THREE.Mesh(new THREE.CircleGeometry(s.r + 1.2, 72), new THREE.MeshStandardMaterial({ map: tD, roughness: 0.9 }));
    disque.rotation.x = -Math.PI / 2; disque.position.set(s.c.x, 0.03, s.c.z); disque.receiveShadow = true; groupe.add(disque);
    const runes = new THREE.Mesh(new THREE.PlaneGeometry(s.r * 1.3, s.r * 1.3), new THREE.MeshBasicMaterial({ map: texRunes('#7dffb0'), transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false }));
    runes.rotation.x = -Math.PI / 2; runes.position.set(s.c.x, 0.06, s.c.z); groupe.add(runes); s.runes = runes;
    G.anims.push((t) => { runes.rotation.z = t * 0.05 * (s.id % 2 ? -1 : 1); runes.material.opacity = 0.35 + 0.2 * Math.sin(t * 1.3 + s.id); });
    // colonnes en cercle, avec des ouvertures pour le chemin
    const n = s.id === 3 ? 14 : 10;
    for (let i = 0; i < n; i++) {
      const a = i / n * 6.283 + 0.2; const x = s.c.x + Math.cos(a) * (s.r - 0.6), z = s.c.z + Math.sin(a) * (s.r - 0.6);
      if (distChemin(x, z) < DEMI + 1.5 && segs.some(([p, q]) => distSeg(x, z, p, q) < DEMI + 1.5 && !(dansSalle(p.x, p.z) && dansSalle(q.x, q.z)))) continue;
      const k = s.id === 3 ? 'n_statue_obelisk' : (i % 3 === 2 ? 'n_statue_columnDamaged' : 'n_statue_column');
      inst.ajouter(k, x, 0, z, -a, 4.2, 4.2, 4.2); collisions.push({ x, z, r: 0.9 });
      if (i % 2 === 0) inst.ajouter(rng() < 0.5 ? 'n_mushroom_tanGroup' : 'n_mushroom_redGroup', x + rng() - 0.5, 0, z + rng() - 0.5, rng() * 6, 7, 7, 7);
    }
    // forêt autour de la clairière
    for (let i = 0; i < 70; i++) { const a = rng() * 6.283, rr = s.r + 3 + rng() * 15; const x = s.c.x + Math.cos(a) * rr, z = s.c.z + Math.sin(a) * rr; if (distChemin(x, z) > DEMI + 2.5) planter(x, z); }
    // cristaux flottants qui éclairent la clairière
    for (let i = 0; i < 3; i++) {
      const a = i / 3 * 6.283 + s.id; const x = s.c.x + Math.cos(a) * (s.r + 2.5), z = s.c.z + Math.sin(a) * (s.r + 2.5);
      const cr = new THREE.Mesh(new THREE.OctahedronGeometry(0.9, 0), new THREE.MeshStandardMaterial({ color: '#7dffd0', emissive: '#3affb0', emissiveIntensity: 1.6, roughness: 0.2, flatShading: true }));
      cr.scale.set(1, 2, 1); cr.position.set(x, 3, z); groupe.add(cr);
      G.anims.push((t) => { cr.position.y = 3 + Math.sin(t * 1.4 + i) * 0.4; cr.rotation.y = t * 0.6; });
      G.torches.push({ pos: new THREE.Vector3(x, 3.5, z), color: '#4affc0', int: 34, dist: 18 });
    }
  }
  // bassin de la 2e clairière
  { const s = salles[1]; const eau = new THREE.Mesh(new THREE.CircleGeometry(5.5, 48), new THREE.MeshStandardMaterial({ color: '#2a9ab8', emissive: '#0a4a6a', roughness: 0.08, metalness: 0.4, transparent: true, opacity: 0.85 }));
    eau.rotation.x = -Math.PI / 2; eau.position.set(s.c.x - 9, 0.05, s.c.z + 8); groupe.add(eau);
    for (let i = 0; i < 6; i++) inst.ajouter(rng() < 0.5 ? 'n_lily_large' : 'n_lily_small', s.c.x - 9 + (rng() - 0.5) * 7, 0.07, s.c.z + 8 + (rng() - 0.5) * 7, rng() * 6, 6, 6, 6);
    collisions.push({ x: s.c.x - 9, z: s.c.z + 8, r: 5.2 }); }
  // l'arbre ancestral derrière le dernier boss
  { const s = salles[3]; arbres.ajouter('Tree_2_C', s.c.x + s.r + 9, 0, s.c.z - 4, 0.4, 3.4, 3.4, 3.4); arbres.ajouter('Tree_3_B', s.c.x + 6, 0, s.c.z - s.r - 9, 1.2, 2.6, 2.6, 2.6); arbres.ajouter('Tree_3_B', s.c.x + 4, 0, s.c.z + s.r + 9, 2.2, 2.6, 2.6, 2.6); }
  // barrières de ronces magiques : elles tombent quand le boss de la clairière meurt
  for (let i = 0; i < 3; i++) {
    const s = salles[i], suite = troncons[i + 1][0];
    const dir = suite.clone().sub(s.c).normalize(); const pt = s.c.clone().addScaledVector(dir, s.r + 1.2);
    const nx = -dir.z, nz = dir.x;
    const g = new THREE.Group(); g.position.copy(pt);
    const matV = new THREE.MeshStandardMaterial({ color: '#2f7a2a', emissive: '#1aff6a', emissiveIntensity: 0.35, roughness: 0.7, flatShading: true });
    for (let k = 0; k < 16; k++) { const o = (k / 15 - 0.5) * 11; const h = 2.5 + rng() * 2.5; const m = new THREE.Mesh(new THREE.ConeGeometry(0.35 + rng() * 0.25, h, 5), matV); m.position.set(nx * o, h / 2, nz * o); m.rotation.set((rng() - 0.5) * 0.6, rng() * 3, (rng() - 0.5) * 0.6); g.add(m); }
    const voile = new THREE.Mesh(new THREE.PlaneGeometry(11, 4), new THREE.MeshBasicMaterial({ color: '#5affa0', transparent: true, opacity: 0.25, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
    voile.position.y = 2; voile.rotation.y = Math.atan2(nx, nz); g.add(voile);
    G.anims.push((t) => { voile.material.opacity = 0.18 + 0.1 * Math.sin(t * 3 + i); });
    groupe.add(g);
    const cols = []; for (let k = -2; k <= 2; k++) { const c = { x: pt.x + nx * k * 2.4, z: pt.z + nz * k * 2.4, r: 1.6, barriere: i }; collisions.push(c); cols.push(c); }
    barrieres.push({ salle: i, groupe: g, cols, pt });
  }
  // départ : arche de pierre et cercle de cristaux
  inst.ajouter('n_statue_ring', -3, 0, 0, Math.PI / 2, 5, 5, 5);
  inst.construire(groupe); arbres.construire(groupe, { ombre: false });
  // lucioles autour du joueur
  G.anims.push((t, dt) => {
    if (!G.focus || Math.random() > (dt || 0.016) * 9) return;
    const a = Math.random() * 6.28, r = 3 + Math.random() * 12;
    emettre(new THREE.Vector3(G.focus.x + Math.cos(a) * r, 0.6 + Math.random() * 2.5, G.focus.z + Math.sin(a) * r), { n: 1, c1: '#f4ff9a', c2: '#5aff9a', vit: 0.4, vie: 2.6, taille: 0.22, grav: -0.15 });
  });
  G.scene.add(groupe);
  // packs : 3 monstres alignés en travers du chemin
  const packs = [];
  const parTroncon = [3, 4, 3, 4];
  troncons.forEach((t, i) => {
    const seg = []; for (let k = 0; k < t.length - 1; k++) seg.push([t[k], t[k + 1]]);
    seg.push([t[t.length - 1], salles[i].c]);
    const longueur = seg.reduce((s, [a, b]) => s + a.distanceTo(b), 0) - salles[i].r;
    for (let p = 0; p < parTroncon[i]; p++) {
      let d = longueur * (0.22 + p * 0.74 / parTroncon[i]);
      for (const [a, b] of seg) { const l = a.distanceTo(b); if (d > l) { d -= l; continue; }
        const c = a.clone().lerp(b, d / l); const dir = b.clone().sub(a).normalize(); const nx = -dir.z, nz = dir.x;
        const n = 3 + (p === parTroncon[i] - 1 && i > 0 ? 1 : 0);
        packs.push({ troncon: i, pts: Array.from({ length: n }, (_, k) => c.clone().add(new THREE.Vector3(nx * (k - (n - 1) / 2) * 2.4, 0, nz * (k - (n - 1) / 2) * 2.4))), dir });
        break; }
    }
  });
  const spawn = P(-1, 0.5);
  return {
    abscisse, pointA, longueur: cum[cum.length - 1], salleS: salles.map(s => abscisse(s.c.x, s.c.z)),
    groupe, type: 'sylve', nom: 'Sanctuaire d’Émeraude', spawn, sortie: P(-5, 0), salles, troncons, segs, packs, barrieres, collisions, marche,
    rayonMonde: 160, bornes: { x0: -12, x1: 310, z0: -48, z1: 30 },
    zoneDe: (x, z) => { const s = dansSalle(x, z); return s ? 'S' + s.id : -1; },
  };
}

// ======================= INTÉRIEUR DE LA TAVERNE =======================
export function construireTaverne() {
  const groupe = new THREE.Group();
  G.torches = []; G.feux = []; G.anims = [];
  const X0 = -14, X1 = 14, Z0 = -10, Z1 = 10;
  const inst = new Instancieur(), collisions = [];
  // parquet en planches
  const planches = texture('parquet', 512, 512, (g, w2, h2) => {
    for (let y = 0; y < h2; y += 32) { const l = 22 + Math.random() * 8; g.fillStyle = `hsl(25,${38 + Math.random() * 10}%,${l}%)`; g.fillRect(0, y, w2, 32); g.fillStyle = 'rgba(0,0,0,0.35)'; g.fillRect(0, y, w2, 2); for (let x = (y / 32 % 2) * 128; x < w2; x += 256) g.fillRect(x, y, 2, 32);
      for (let k = 0; k < 30; k++) { g.fillStyle = `rgba(${Math.random() < 0.5 ? '0,0,0' : '255,220,170'},${Math.random() * 0.08})`; g.fillRect(Math.random() * w2, y + Math.random() * 30, 20 + Math.random() * 60, 1.5); } }
  }, { repeat: true });
  planches.repeat.set(5, 4);
  const sol = new THREE.Mesh(new THREE.PlaneGeometry(X1 - X0, Z1 - Z0), new THREE.MeshStandardMaterial({ map: planches, roughness: 0.85 }));
  sol.rotation.x = -Math.PI / 2; sol.receiveShadow = true; groupe.add(sol);
  solAbysse(groupe, 0, 0, 120);
  // murs (nord et ouest hauts, sud et est bas pour la caméra)
  for (let x = X0 + 2; x < X1; x += 4) { inst.ajouter(x % 12 === 2 ? 'wall_arched' : 'wall', x, 0, Z0 - 0.5, 0); inst.ajouter('barrier', x, 0, Z1 + 0.25, 0); }
  for (let z = Z0 + 2; z < Z1; z += 4) { if (z !== 6) inst.ajouter('wall', X0 - 0.5, 0, z, Math.PI / 2); inst.ajouter('barrier', X1 + 0.25, 0, z, Math.PI / 2); }
  for (const [x, z] of [[X0, Z0], [X1, Z0], [X0, Z1], [X1, Z1]]) inst.ajouter('pillar', x, 0, z, 0, 0.75, 1, 0.75);
  // la vraie porte de la taverne (mur ouest) : elle s'ouvre quand on s'en approche
  poserPorte(groupe, X0 - 0.5, 6, Math.PI / 2, 1, { sens: -1, rayon: 3.6 });
  { const jour = new THREE.Mesh(new THREE.PlaneGeometry(3.4, 3.6), new THREE.MeshBasicMaterial({ color: '#ffd9a0', transparent: true, opacity: 0.85 })); jour.position.set(X0 - 1.6, 1.8, 6); jour.rotation.y = Math.PI / 2; groupe.add(jour); }
  inst.ajouter('torch_mounted', X0 + 0.1, 2.4, 3.2, Math.PI / 2); G.torches.push({ pos: new THREE.Vector3(X0 + 0.8, 2.6, 3.2), color: '#ffb46a', int: 10, dist: 6 });
  { const tapis = new THREE.Mesh(new THREE.PlaneGeometry(2.6, 3.4), new THREE.MeshStandardMaterial({ color: '#6a1a1a', roughness: 1, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 })); tapis.rotation.x = -Math.PI / 2; tapis.position.set(X0 + 1.9, 0.02, 6); groupe.add(tapis); }
  // poutres du plafond (suggérées) et lustres
  const bois = new THREE.MeshStandardMaterial({ color: '#3a2414', roughness: 0.9 });
  for (const x of [-7, 0, 7]) { const p = new THREE.Mesh(new THREE.BoxGeometry(0.4, 0.4, 3.2), bois); p.position.set(x, 3.9, Z0 + 1.6); groupe.add(p); }
  for (const [x, z] of [[-6, 0], [6, 0]]) {
    const lustre = new THREE.Mesh(new THREE.TorusGeometry(0.9, 0.08, 6, 20), bois); lustre.rotation.x = Math.PI / 2; lustre.position.set(x, 3.6, z); groupe.add(lustre);
    for (let i = 0; i < 6; i++) { const a = i / 6 * 6.28; inst.ajouter('candle_lit', x + Math.cos(a) * 0.9, 3.55, z + Math.sin(a) * 0.9, 0, 0.5, 0.5, 0.5); }
    G.torches.push({ pos: new THREE.Vector3(x, 3.2, z), color: '#ffb46a', int: 34, dist: 14 });
  }
  // le comptoir de Mira (nord) et l'arrière-bar
  for (const x of [-4, 0, 4]) inst.ajouter('table_long_decorated_A', x, 0, -6.2, Math.PI / 2);
  for (let x = -5; x <= 5; x += 1.4) collisions.push({ x, z: -6.2, r: 1.0 });
  for (const x of [-6, -2, 2, 6]) inst.ajouter('shelves', x, 0.5, Z0 + 0.3, 0);
  for (const x of [-4, 0, 4]) inst.ajouter('shelf_small_candles', x, 2.7, Z0 + 0.3, 0);
  for (const x of [-10, 9.5]) { inst.ajouter('keg_decorated', x, 0, -8.2, 0, 0.85, 0.85, 0.85); collisions.push({ x: x - 1, z: -8.2, r: 1 }, { x: x + 1, z: -8.2, r: 1 }); }
  inst.ajouter('banner_patternA_red', -8, 0, Z0 + 0.1, 0); inst.ajouter('banner_patternB_red', 8, 0, Z0 + 0.1, 0);
  // grande cheminée (ouest)
  const pierre = pierreMat('#6a5a50', '#4a3e36');
  const chem = new THREE.Mesh(new THREE.BoxGeometry(1.6, 3.6, 4.4), pierre); chem.position.set(X0 + 0.6, 1.8, 2); chem.castShadow = true; groupe.add(chem);
  const foyer = new THREE.Mesh(new THREE.BoxGeometry(0.4, 1.4, 2.4), new THREE.MeshBasicMaterial({ color: '#1a0804' })); foyer.position.set(X0 + 1.45, 0.7, 2); groupe.add(foyer);
  const braises = new THREE.Mesh(new THREE.PlaneGeometry(1.2, 2.2), new THREE.MeshBasicMaterial({ color: '#ff7a1a', transparent: true, opacity: 0.9, blending: THREE.AdditiveBlending, map: texRond() })); braises.rotation.set(-Math.PI / 2, 0, Math.PI / 2); braises.position.set(X0 + 1.9, 0.12, 2); groupe.add(braises);
  G.feux.push({ pos: new THREE.Vector3(X0 + 1.9, 0.4, 2), couleur: '#ff7a2a', force: 1.2 });
  G.torches.push({ pos: new THREE.Vector3(X0 + 2.6, 1.4, 2), color: '#ff8a3a', int: 40, dist: 14 });
  collisions.push({ x: X0 + 1, z: 0.5, r: 1.2 }, { x: X0 + 1, z: 3.5, r: 1.2 });
  // tapis devant la cheminée
  const tapisT = texture('tapisTaverne', 256, 256, (g, w2) => { g.fillStyle = '#5a1418'; g.fillRect(0, 0, w2, w2); g.strokeStyle = '#d8a84a'; g.lineWidth = 8; g.strokeRect(12, 12, w2 - 24, w2 - 24); g.fillStyle = '#7a2a1a'; g.beginPath(); g.arc(w2 / 2, w2 / 2, 70, 0, 7); g.fill(); g.strokeStyle = '#d8a84a'; g.lineWidth = 4; g.stroke(); });
  const tapis = new THREE.Mesh(new THREE.PlaneGeometry(4.5, 5), new THREE.MeshStandardMaterial({ map: tapisT, roughness: 1 })); tapis.rotation.x = -Math.PI / 2; tapis.position.set(X0 + 4.5, 0.03, 2); groupe.add(tapis);
  // tables et tonneaux en guise de tabourets
  const tables = [[-6.5, 3.2], [5.5, 3.6], [-1.5, 6.4], [9.6, -2.4]];
  for (const [x, z] of tables) {
    inst.ajouter('table_long_tablecloth_decorated_A', x, 0, z, Math.PI / 2, 0.9, 0.9, 0.9);
    collisions.push({ x: x - 1.1, z, r: 1.0 }, { x: x + 1.1, z, r: 1.0 });
    for (const dz of [-1.6, 1.6]) inst.ajouter('barrel_small_stack', x + (Math.random() - 0.5), 0, z + dz, Math.random() * 6, 0.45, 0.45, 0.45);
  }
  // le tableau des missions (mur ouest, près de l'entrée de la salle)
  const notes = texture('tableau_missions', 256, 192, (g, w2, h2) => {
    g.fillStyle = '#4a2e18'; g.fillRect(0, 0, w2, h2); g.strokeStyle = '#2a180a'; g.lineWidth = 10; g.strokeRect(5, 5, w2 - 10, h2 - 10);
    const cols = ['#f0e0b8', '#e8d0a0', '#f4e8c8', '#e0c890'];
    for (let i = 0; i < 6; i++) { const x = 22 + (i % 3) * 76, y = 22 + Math.floor(i / 3) * 82; g.save(); g.translate(x + 30, y + 32); g.rotate((Math.random() - 0.5) * 0.25); g.fillStyle = cols[i % 4]; g.fillRect(-30, -32, 60, 64); g.fillStyle = 'rgba(60,40,20,0.7)'; for (let l = 0; l < 5; l++) g.fillRect(-22, -20 + l * 9, 30 + Math.random() * 14, 3); g.fillStyle = '#b02020'; g.beginPath(); g.arc(0, -28, 4, 0, 7); g.fill(); g.restore(); }
  });
  const tableau = new THREE.Mesh(new THREE.PlaneGeometry(3.2, 2.4), new THREE.MeshStandardMaterial({ map: notes, roughness: 0.9 }));
  tableau.position.set(X0 + 0.15, 2.1, -4.6); tableau.rotation.y = Math.PI / 2; groupe.add(tableau);
  G.torches.push({ pos: new THREE.Vector3(X0 + 1.5, 2.6, -4.6), color: '#ffd28a', int: 18, dist: 7 });
  inst.ajouter('candle_triple', X0 + 0.9, 0, -2.8, 0); inst.ajouter('torch_mounted', X0 + 0.1, 2.4, -7.2, Math.PI / 2);
  // le coin de l'oracle (est) : boule de cristal
  const boule = new THREE.Mesh(new THREE.SphereGeometry(0.32, 20, 14), new THREE.MeshStandardMaterial({ color: '#c8a0ff', emissive: '#7a3aff', emissiveIntensity: 1.6, transparent: true, opacity: 0.85 }));
  boule.position.set(9.6, 1.25, -2.4); groupe.add(boule); G.anims.push((t) => { boule.material.emissiveIntensity = 1.3 + Math.sin(t * 2.5) * 0.5; });
  G.torches.push({ pos: new THREE.Vector3(9.6, 2, -2.4), color: '#a070ff', int: 16, dist: 7 });
  for (const [k, x, z, r] of [['crates_stacked', 12, 7.5, 0.3], ['barrel_large', 12.4, 4.8, 0], ['chest', -11.5, 8, 0.5]]) { inst.ajouter(k, x, 0, z, r, 0.8, 0.8, 0.8); collisions.push({ x, z, r: 1.1 }); }
  inst.construire(groupe);
  G.scene.add(groupe);
  return {
    groupe, type: 'taverne', nom: 'Le Croc-Rouge', collisions,
    spawn: new THREE.Vector3(X0 + 2.6, 0, 6), sortie: new THREE.Vector3(X0 + 1.1, 0, 6), portes: groupe.userData.portes || [],
    comptoir: new THREE.Vector3(0, 0, -4.4), mira: new THREE.Vector3(0, 0, -8), tableau: new THREE.Vector3(X0 + 1.6, 0, -4.6), oracle: new THREE.Vector3(11.4, 0, -2.4),
    file: [new THREE.Vector3(0, 0, -4.4), new THREE.Vector3(0.4, 0, -3), new THREE.Vector3(0.2, 0, -1.6), new THREE.Vector3(0.6, 0, -0.2), new THREE.Vector3(0.3, 0, 1.2)],
    places: [[-6.5, 1.6], [-6.5, 4.8], [5.5, 2], [5.5, 5.2], [-1.5, 4.8], [-3.6, 6.4], [8.4, 6.8], [-10.6, 1.8], [11.6, 1.2]].map(([x, z]) => new THREE.Vector3(x, 0, z)),
    bornes: { x0: X0, x1: X1, z0: Z0, z1: Z1 },
    marche: (x, z) => x > X0 + 0.8 && x < X1 - 0.8 && z > Z0 + 0.8 && z < Z1 - 0.6,
  };
}

// une porte KayKit (mur + battant sur charnière) : le battant pivote quand on approche (animé dans main.js)
export function poserPorte(groupe, x, z, rot, s = 1, opts = {}) {
  const m = cloner('d_wall_doorway', x, opts.y || 0, z, rot, s); groupe.add(m);
  if (opts.teinte) m.traverse(o => { if (o.isMesh) o.material = opts.teinte(o.material, 'wall'); });
  const battant = m.getObjectByName('wall_doorway_door');
  const P = { obj: m, battant, pos: new THREE.Vector3(x, 0, z), rot, ouv: 0, sens: opts.sens || 1, rayon: opts.rayon || 4.2 * s };
  (groupe.userData.portes = groupe.userData.portes || []).push(P);
  return P;
}
// Le château du domaine (niveau 2+) : enceinte crénelée, tours d'angle, châtelet d'entrée, douves et pont-levis,
// cour pavée, tapis rouge, estrade du trône, donjon à étages, bannières, braseros, jardins et fontaine.
function chateauDomaine(groupe, inst, collisions, reliefs, th, N) {
  const ch = new Instancieur();
  const S = 3.6, NX = 12, NZ = 10, X0 = -NX * S / 2, Z0 = -50.4, Z1 = Z0 + NZ * S; // cour : x ±21.6, z -50.4 → -14.4
  const cx = i => X0 + S * (i + 0.5), cz = k => Z0 + S * (k + 0.5);
  const H = 1.31 * S; // hauteur d'un rempart
  // sol de la cour : dalles de pierre
  const texDalles = texture('dallesCour', 256, 256, (g, w) => { g.fillStyle = '#8a8478'; g.fillRect(0, 0, w, w); for (let y = 0; y < 4; y++) for (let x = 0; x < 4; x++) { const ox = (y % 2) * 32; g.fillStyle = `hsl(${30 + Math.random() * 14},${8 + Math.random() * 8}%,${48 + Math.random() * 12}%)`; g.fillRect(x * 64 + ox + 2, y * 64 + 2, 60, 60); g.fillStyle = 'rgba(255,255,255,0.08)'; g.fillRect(x * 64 + ox + 2, y * 64 + 2, 60, 4); } for (let k = 0; k < 160; k++) { g.fillStyle = `rgba(0,0,0,${Math.random() * 0.12})`; g.fillRect(Math.random() * w, Math.random() * w, 2 + Math.random() * 6, 1.5); } }, { repeat: true });
  texDalles.repeat.set(NX * S / 5, NZ * S / 5);
  const cour = new THREE.Mesh(new THREE.PlaneGeometry(NX * S, NZ * S), new THREE.MeshStandardMaterial({ map: texDalles, roughness: 0.95, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 }));
  cour.rotation.x = -Math.PI / 2; cour.position.set(0, 0.025, (Z0 + Z1) / 2); cour.receiveShadow = true; groupe.add(cour);
  // --- enceinte ---
  const porteI = [5, 6]; // ouverture du châtelet (devant, au centre)
  for (let i = 1; i < NX - 1; i++) {
    ch.ajouter('c_wall', cx(i), 0, cz(0), 0, S, S, S);
    if (!porteI.includes(i) && i !== 4 && i !== 7) ch.ajouter('c_wall', cx(i), 0, cz(NZ - 1), Math.PI, S, S, S);
  }
  for (let k = 1; k < NZ - 1; k++) { ch.ajouter('c_wall', cx(0), 0, cz(k), Math.PI / 2, S, S, S); ch.ajouter('c_wall', cx(NX - 1), 0, cz(k), -Math.PI / 2, S, S, S); }
  // collisions des remparts (sauf la porte)
  for (let x = X0 + 0.9; x < X0 + NX * S; x += 1.2) { collisions.push({ x, z: cz(0), r: 1.6 }); if (Math.abs(x) > S + 0.6) collisions.push({ x, z: cz(NZ - 1), r: 1.6 }); }
  for (let z = Z0 + 0.9; z < Z1; z += 1.2) { collisions.push({ x: cx(0), z, r: 1.6 }); collisions.push({ x: cx(NX - 1), z, r: 1.6 }); }
  // tours d'angle hexagonales (plus hautes à chaque niveau)
  const etages = N >= 4 ? 4 : N >= 3 ? 3 : 2, TS = S * 1.55;
  const tourHex = (x, z, n, ts) => {
    ch.ajouter('c_tower_hexagon_base', x, 0, z, 0, ts, ts, ts); let y = 1.31 * ts;
    for (let e = 0; e < n; e++) { ch.ajouter('c_tower_hexagon_mid', x, y, z, 0, ts, ts, ts); y += 0.46 * ts; }
    ch.ajouter('c_tower_hexagon_top', x, y, z, 0, ts, ts, ts); ch.ajouter('c_tower_hexagon_roof', x, y + 0.1 * ts, z, 0, ts, ts, ts);
    ch.ajouter('c_flag_pennant', x, y + 0.83 * ts, z, Math.random() * 6, ts * 0.9, ts * 0.9, ts * 0.9);
    collisions.push({ x, z, r: 0.5 * ts + 0.4 });
  };
  for (const [i, k] of [[0, 0], [NX - 1, 0], [0, NZ - 1], [NX - 1, NZ - 1]]) tourHex(cx(i), cz(k), etages, TS);
  // châtelet : deux tours carrées et un linteau crénelé au-dessus du passage
  const tourCarree = (x, z, rot, n, ts, sy = ts) => {
    ch.ajouter('c_tower_square_base', x, 0, z, rot, ts, sy, ts); let y = 1.01 * sy;
    for (let e = 0; e < n; e++) { ch.ajouter(e % 2 ? 'c_tower_square_mid' : 'c_tower_square_mid_windows', x, y, z, rot, ts, sy, ts); y += 1.01 * sy; }
    ch.ajouter('c_tower_square_top_roof_high', x, y, z, rot, ts, sy, ts);
    collisions.push({ x: x - ts * 0.3, z, r: ts * 0.45 }, { x: x + ts * 0.3, z, r: ts * 0.45 });
    return y + 1.35 * sy;
  };
  const hG = tourCarree(cx(4), cz(NZ - 1), Math.PI, 1, S);
  tourCarree(cx(7), cz(NZ - 1), Math.PI, 1, S);
  { const l = cloner('c_wall', 0, H * 0.72, cz(NZ - 1), Math.PI); l.scale.set(S * 2, S * 0.3, S); groupe.add(l); }
  // herse relevée (on la devine au-dessus du passage)
  ch.ajouter('c_metal_gate', 0, H * 0.5, cz(NZ - 1) + S * 0.15, Math.PI / 2, S * 1.6, S * 0.6, S * 3.4);
  // bannières sur la façade du châtelet
  for (const x of [cx(4), cx(7)]) ch.ajouter('c_flag_banner_long', x, H * 0.55, cz(NZ - 1) + S * 0.52, -Math.PI / 2, S * 0.9, S * 0.9, S * 0.9);
  // torches à l'entrée
  for (const x of [-S - 0.6, S + 0.6]) { const t = cloner('d_torch_lit', x, 2.6, cz(NZ - 1) + S * 0.6, 0, 1.3); groupe.add(t); G.torches.push({ pos: new THREE.Vector3(x, 3.2, cz(NZ - 1) + S * 0.9), color: '#ffb05a', int: 14, dist: 9 }); }
  // --- douves et pont-levis (forteresse +) ---
  if (N >= 3) {
    const L = 4, ex0 = X0 - 3.2, ex1 = X0 + NX * S + 3.2, ez0 = Z0 - 3.2, ez1 = Z1 + 3.2;
    const eau = new THREE.MeshStandardMaterial({ color: '#2a5a72', roughness: 0.15, metalness: 0.3, transparent: true, opacity: 0.92, polygonOffset: true, polygonOffsetFactor: -3, polygonOffsetUnits: -3 });
    const bord = new THREE.MeshStandardMaterial({ map: texBlocs(th), roughness: 0.9 });
    const bande = (x0, z0, x1, z1) => {
      const w = x1 - x0, d = z1 - z0, m = new THREE.Mesh(new THREE.PlaneGeometry(w, d), eau); m.rotation.x = -Math.PI / 2; m.position.set((x0 + x1) / 2, 0.035, (z0 + z1) / 2); groupe.add(m);
      const ombre = new THREE.Mesh(new THREE.PlaneGeometry(w + 0.01, d + 0.01), new THREE.MeshBasicMaterial({ color: '#0a1a22', transparent: true, opacity: 0.55, depthWrite: false })); ombre.rotation.x = -Math.PI / 2; ombre.position.set((x0 + x1) / 2, 0.03, (z0 + z1) / 2); groupe.add(ombre);
      // margelles de pierre
      for (const [bx, bz, bw, bd] of w > d ? [[(x0 + x1) / 2, z0, w, 0.5], [(x0 + x1) / 2, z1, w, 0.5]] : [[x0, (z0 + z1) / 2, 0.5, d], [x1, (z0 + z1) / 2, 0.5, d]]) { const b = new THREE.Mesh(new THREE.BoxGeometry(bw, 0.35, bd), bord); b.position.set(bx, 0.17, bz); b.receiveShadow = true; groupe.add(b); }
    };
    // façade (en deux morceaux autour du pont), fond, côtés
    bande(ex0 - L, ez1, -3.2, ez1 + L); bande(3.2, ez1, ex1 + L, ez1 + L); bande(ex0 - L, ez0 - L, ex1 + L, ez0); bande(ex0 - L, ez0, ex0, ez1); bande(ex1, ez0, ex1 + L, ez1);
    for (let x = ex0 - L; x <= ex1 + L; x += 1.3) { if (Math.abs(x) > 3.6) collisions.push({ x, z: ez1 + L / 2, r: 1.5 }); collisions.push({ x, z: ez0 - L / 2, r: 1.5 }); }
    for (let z = ez0 - L; z <= ez1 + L; z += 1.3) { collisions.push({ x: ex0 - L / 2, z, r: 1.5 }); collisions.push({ x: ex1 + L / 2, z, r: 1.5 }); }
    // pont-levis abaissé (planches + chaînes)
    const pont = new THREE.Mesh(new THREE.BoxGeometry(6.2, 0.3, L + 1.2), new THREE.MeshStandardMaterial({ color: '#ffffff', roughness: 0.95, map: texture('planchesPont', 64, 256, (g, w, h) => { for (let y = 0; y < h; y += 16) { g.fillStyle = `hsl(28,${42 + Math.random() * 10}%,${42 + Math.random() * 10}%)`; g.fillRect(0, y, w, 15); g.fillStyle = 'rgba(0,0,0,0.4)'; g.fillRect(0, y + 15, w, 1); } }) }));
    pont.position.set(0, 0.16, ez1 + L / 2); pont.receiveShadow = true; groupe.add(pont);
    for (const sx of [-3, 3]) { const c = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.06, 7.5, 5), new THREE.MeshStandardMaterial({ color: '#3a3a40', metalness: 0.8, roughness: 0.4 })); c.position.set(sx, 3.2, ez1 + 0.6); c.rotation.x = -0.95; groupe.add(c); }
    // engins de siège qui gardent l'entrée
    for (const [x, k, r] of [[-11, 'c_siege_ballista', -Math.PI / 2], [11, 'c_siege_catapult', -Math.PI / 2]]) { ch.ajouter(k, x, 0, ez1 + L + 4, r, 3, 3, 3); collisions.push({ x, z: ez1 + L + 4, r: 2.4 }); }
  }
  // --- tapis rouge du châtelet jusqu'à l'estrade ---
  const tapisT = texture('tapisRoyal', 64, 256, (g, w, h) => { g.fillStyle = '#7a1020'; g.fillRect(0, 0, w, h); g.fillStyle = '#d8a03a'; g.fillRect(0, 0, 5, h); g.fillRect(w - 5, 0, 5, h); g.fillStyle = '#5a0818'; g.fillRect(8, 0, 2, h); g.fillRect(w - 10, 0, 2, h); for (let y = 16; y < h; y += 64) { g.fillStyle = '#c8902a'; g.beginPath(); g.moveTo(w / 2, y); g.lineTo(w / 2 + 8, y + 12); g.lineTo(w / 2, y + 24); g.lineTo(w / 2 - 8, y + 12); g.fill(); } }, { repeat: true });
  const zEst = -28, longT = Z1 + 1 - zEst; tapisT.repeat.set(1, longT / 6);
  const tapis = new THREE.Mesh(new THREE.PlaneGeometry(3, longT), new THREE.MeshStandardMaterial({ map: tapisT, roughness: 1, polygonOffset: true, polygonOffsetFactor: -4, polygonOffsetUnits: -4 }));
  tapis.rotation.x = -Math.PI / 2; tapis.position.set(0, 0.05, zEst + longT / 2); groupe.add(tapis);
  // --- estrade du trône ---
  const hE = 1.0;
  const zD = Z0 + S + 9.6 / 2 - 0.5, zFace = zD + 9.6 / 2;
  estrade(groupe, inst, collisions, reliefs, th, { x0: -8, x1: 8, z0: zFace - 0.2, z1: zEst, h: hE, cote: 'S', ouverts: ['S', 'E', 'W'] });
  const trP = new THREE.Vector3(0, 0, zEst - 4.4);
  trone(groupe, th, 0, hE, trP.z, 0); collisions.push({ x: 0, z: trP.z, r: 1.6 });
  for (const x of [-5.5, 5.5]) brasero(groupe, x, zEst - 2, '#ff9a3a', 1, hE);
  // --- donjon : grande tour à étages derrière le trône, porte qui s'ouvre ---
  const etD = N >= 4 ? 3 : N >= 3 ? 2 : 1, DS = 9.6, DY = 6.4;
  tourCarree(0, zD, 0, etD, DS, DY);
  collisions.push({ x: 0, z: zD, r: DS * 0.55 }, { x: -DS * 0.35, z: zD + DS * 0.2, r: DS * 0.3 }, { x: DS * 0.35, z: zD + DS * 0.2, r: DS * 0.3 });
  poserPorte(groupe, 0, zD + DS / 2 + 0.1, 0, 1.05, { y: hE, sens: 1 });
  ch.ajouter('d_banner_triple_red', 0, hE + 3.4, zD + DS / 2 + 0.12, 0, 1.1, 1.1, 1.1);
  for (const x of [-DS / 2 - 3.2, DS / 2 + 3.2]) tourHex(x, zD + 1, etD + 1, S * 1.25);
  // bannières sur la face intérieure des remparts
  for (let i = 2; i < NX - 2; i += 3) if (Math.abs(cx(i)) > DS / 2 + 5) ch.ajouter(i % 2 ? 'd_banner_shield_red' : 'd_banner_triple_red', cx(i), 0.6, cz(0) + S / 2 + 0.05, 0, 1, 1, 1);
  for (let k = 2; k < NZ - 2; k += 3) { ch.ajouter('d_banner_shield_red', cx(0) + S / 2 + 0.05, 0.6, cz(k), Math.PI / 2, 1, 1, 1); ch.ajouter('d_banner_shield_red', cx(NX - 1) - S / 2 - 0.05, 0.6, cz(k), -Math.PI / 2, 1, 1, 1); }
  // braseros et lanternes dans la cour
  for (const [x, z] of [[-13, -19], [13, -19], [-13, -29], [13, -29]]) { if (N >= 3) brasero(groupe, x, z, '#ff9a3a', 1); else { ch.ajouter('t_lantern', x, 0, z, 0, 2.2, 2.2, 2.2); G.torches.push({ pos: new THREE.Vector3(x, 3.2, z), color: '#ffcf7a', int: 10, dist: 8 }); } collisions.push({ x, z, r: 0.7 }); }
  // râteliers d'armes et tonneaux le long des murs
  for (const [x, z, r] of [[-18, -22, Math.PI / 2], [-18, -27, Math.PI / 2], [18, -40, -Math.PI / 2]]) { const a = cloner('d_sword_shield_gold', x, 1.5, z, r, 1); groupe.add(a); }
  for (const [x, z] of [[18.2, -18], [17.8, -20], [-18.2, -44]]) { inst.ajouter('barrel_large', x, 0, z, Math.random() * 6); collisions.push({ x, z, r: 0.9 }); }
  // --- jardins et fontaine devant le château (forteresse +) ---
  if (N >= 3) {
    const fz = 2;
    ch.ajouter('t_fountain_round_detail', 0, 0, fz, 0, 3.4, 3.4, 3.4); collisions.push({ x: 0, z: fz, r: 3.3 });
    const jet = new THREE.Mesh(new THREE.CylinderGeometry(0.08, 0.3, 2.2, 8, 1, true), new THREE.MeshBasicMaterial({ color: '#cfefff', transparent: true, opacity: 0.45, depthWrite: false })); jet.position.set(0, 1.9, fz); groupe.add(jet);
    G.anims.push((t, dt) => { jet.scale.y = 1 + Math.sin(t * 6) * 0.08; if (Math.random() < (dt || 0.016) * 14) emettre(new THREE.Vector3(rnd(-0.3, 0.3), 2.8, fz + rnd(-0.3, 0.3)), { n: 1, c1: '#ffffff', c2: '#9ad8ff', vit: 1.6, vie: 0.8, taille: 0.22, grav: 5 }); });
    for (const sx of [-1, 1]) for (let z = -6; z <= 20; z += 1.7) if (Math.abs(z - fz) > 5) inst.ajouter('Bush_2_C', sx * (3.6 + Math.random() * 0.3), 0, z, Math.random() * 6, 1.25, 1.1, 1.25);
    for (const [x, z] of [[-7, -6], [7, -6], [-7, 10], [7, 10]]) { ch.ajouter('c_tree_large', x, 0, z, Math.random() * 6, 2.6, 2.6, 2.6); collisions.push({ x, z, r: 1 }); }
    for (const [x, z] of [[-4.6, -10], [4.6, -10], [-4.6, 14], [4.6, 14]]) { ch.ajouter('t_lantern', x, 0, z, 0, 2.2, 2.2, 2.2); G.torches.push({ pos: new THREE.Vector3(x, 3.2, z), color: '#ffcf7a', int: 9, dist: 8 }); collisions.push({ x, z, r: 0.4 }); }
  }
  // --- citadelle : or des anciens rois ---
  if (N >= 4) {
    cristaux(groupe, { ...th, nom: 'or', cristal: '#ffd27a' }, -6.4, zEst - 7, 1, hE); cristaux(groupe, { ...th, nom: 'or', cristal: '#ffd27a' }, 6.4, zEst - 7, 1, hE);
    raiLumiere(groupe, 0, trP.z, '#fff0c0');
    for (const [x, z] of [[-12, -16.5], [12, -16.5]]) { const st = cloner('n_statue_obelisk', x, 0, z, 0, 3); groupe.add(st); collisions.push({ x, z, r: 1 }); }
  }
  // le trésor : coffre doré et piles de pièces à côté de l'estrade
  const tresor = new THREE.Vector3(10.5, 0, zEst + 2);
  groupe.add(cloner('chest_gold', tresor.x, 0, tresor.z, -Math.PI / 2, 1.2)); ch.ajouter('d_coin_stack_medium', tresor.x + 1.4, 0, tresor.z + 0.8, 0.4, 1.3, 1.3, 1.3); ch.ajouter('d_coin_stack_medium', tresor.x - 1.2, 0, tresor.z + 1, 2, 1, 1, 1);
  collisions.push({ x: tresor.x, z: tresor.z, r: 1.1 });
  ch.construire(groupe, { ombre: true });
  return { trone: trP.clone().setY(0), tresor };
}

// ======================= LES TERRES ÉCARLATES : monde ouvert, zone rouge (PvP punitif) =======================
// 340 m de terres : forêt sombre (ouest), ruines d'un royaume (centre), champs de cendres et de lave (est), lac noir (sud-ouest).
// Camp de départ au sud (zone sûre), deux portails de sortie, camps de monstres plus durs à mesure qu'on s'éloigne, un dragon dans les cendres.
export function construireTerres() {
  const groupe = new THREE.Group();
  G.torches = []; G.feux = []; G.anims = [];
  const R = 170, inst = new Instancieur(), nat = new Instancieur(), collisions = [];
  const rng = graineRng(4242);
  const biome = (x, z) => { const lac = Math.hypot(x + 75, z - 85) < 30; if (lac) return 'lac'; if (Math.hypot(x, z) < 42) return 'ruines'; if (x > 45 && z < 40) return 'cendres'; if (x < -35) return 'foret'; return 'plaine'; };
  // sol en couleurs par sommet (une seule géométrie, très légère) + herbe en détail
  const geo = new THREE.PlaneGeometry(2 * R + 40, 2 * R + 40, 110, 110).rotateX(-Math.PI / 2);
  const pos = geo.attributes.position, col = new Float32Array(pos.count * 3), c = new THREE.Color();
  for (let i = 0; i < pos.count; i++) { const x = pos.getX(i), z = pos.getZ(i), b = biome(x, z), n = rng() * 0.08;
    c.set(b === 'foret' ? '#5a8a46' : b === 'ruines' ? '#c8b088' : b === 'cendres' ? '#7a5a52' : b === 'lac' ? '#a0b080' : '#a0b868'); c.offsetHSL(0, 0, n - 0.04); col.set([c.r, c.g, c.b], i * 3); }
  geo.setAttribute('color', new THREE.BufferAttribute(col, 3));
  const tH = texHerbe(); tH.repeat.set(60, 60);
  const sol = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ vertexColors: true, map: tH, roughness: 1 })); sol.receiveShadow = true; groupe.add(sol);
  // lac
  const eau = new THREE.Mesh(new THREE.CircleGeometry(28, 48), new THREE.MeshStandardMaterial({ color: '#1a3a4a', roughness: 0.1, metalness: 0.4, transparent: true, opacity: 0.9, polygonOffset: true, polygonOffsetFactor: -2 }));
  eau.rotation.x = -Math.PI / 2; eau.position.set(-75, 0.04, 85); groupe.add(eau);
  for (let a = 0; a < 6.28; a += 0.08) collisions.push({ x: -75 + Math.cos(a) * 26, z: 85 + Math.sin(a) * 26, r: 2 });
  // fissures de lave dans les cendres
  const lave = new THREE.MeshBasicMaterial({ color: '#ff4a1a', transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false });
  for (let k = 0; k < 40; k++) { const x = 55 + rng() * 105, z = -150 + rng() * 180; if (Math.hypot(x, z) > R - 8) continue; const m = new THREE.Mesh(new THREE.PlaneGeometry(0.5 + rng() * 0.6, 6 + rng() * 10), lave); m.rotation.x = -Math.PI / 2; m.rotation.z = rng() * 6; m.position.set(x, 0.05, z); groupe.add(m); }
  G.anims.push((t) => { lave.opacity = 0.6 + Math.sin(t * 1.7) * 0.2; });
  // bordure : falaises de rochers tout autour
  for (let a = 0; a < 6.28; a += 0.045) { const r = R + rng() * 6; inst.ajouter(rng() < 0.5 ? 'Rock_1_A' : 'Rock_3_C', Math.cos(a) * r, 0, Math.sin(a) * r, rng() * 6, 3.5 + rng() * 2.5, 3 + rng() * 3, 3.5 + rng() * 2.5); }
  // végétation et décor par biome
  const libreDe = (x, z, m = 3) => !collisions.some(k => Math.abs(k.x - x) < m + k.r && Math.abs(k.z - z) < m + k.r);
  const camp0 = new THREE.Vector3(0, 0, 148);
  for (let k = 0; k < 2600; k++) {
    const a = rng() * 6.283, r = Math.sqrt(rng()) * (R - 6), x = Math.cos(a) * r, z = Math.sin(a) * r, b = biome(x, z);
    if (Math.hypot(x - camp0.x, z - camp0.z) < 18 || Math.abs(x) < 4 && z > 40) continue; // camp et route
    if (b === 'foret' && rng() < 0.55) { const s = 1.6 + rng() * 1.4; nat.ajouter(rng() < 0.5 ? 'n_tree_fat_darkh' : rng() < 0.5 ? 'n_tree_detailed' : 'n_tree_oak', x, 0, z, rng() * 6, s, s, s); collisions.push({ x, z, r: 0.7 }); }
    else if (b === 'foret' && rng() < 0.4) nat.ajouter(rng() < 0.5 ? 'n_mushroom_redGroup' : 'n_plant_bushLarge', x, 0, z, rng() * 6, 1.5, 1.5, 1.5);
    else if (b === 'plaine' && rng() < 0.12) { inst.ajouter(rng() < 0.5 ? 'Tree_1_A' : 'Tree_3_A', x, 0, z, rng() * 6, 1.2, 1.2, 1.2); collisions.push({ x, z, r: 0.7 }); }
    else if (b === 'plaine' && rng() < 0.3) inst.ajouter(rng() < 0.7 ? 'Grass_1_A' : 'Bush_2_C', x, 0, z, rng() * 6, 1.4, 1.4, 1.4);
    else if (b === 'cendres' && rng() < 0.1) { inst.ajouter('Tree_Bare_2_A', x, 0, z, rng() * 6, 1.6, 1.6, 1.6); collisions.push({ x, z, r: 0.6 }); }
    else if (b === 'cendres' && rng() < 0.08) { nat.ajouter(rng() < 0.5 ? 'n_rock_largeB' : 'n_rock_largeC', x, 0, z, rng() * 6, 2.5, 2.5, 2.5); collisions.push({ x, z, r: 1.6 }); }
  }
  // ruines du royaume déchu : murs effondrés, colonnes, statues, braseros
  for (let k = 0; k < 26; k++) { const a = k / 26 * 6.283, r = 30 + (k % 3) * 4; const x = Math.cos(a) * r, z = Math.sin(a) * r; if (k % 5 === 0) continue;
    inst.ajouter(k % 2 ? 'wall_broken' : 'wall', x, 0, z, -a + Math.PI / 2); collisions.push({ x, z, r: 1.6 }); }
  for (let k = 0; k < 14; k++) { const a = rng() * 6.283, r = 8 + rng() * 18, x = Math.cos(a) * r, z = Math.sin(a) * r; inst.ajouter(rng() < 0.5 ? 'pillar_decorated' : 'column', x, 0, z, rng() * 6, 1.2, 1.2, 1.2); collisions.push({ x, z, r: 0.8 }); }
  for (let k = 0; k < 20; k++) { const a = rng() * 6.283, r = rng() * 34; inst.ajouter(rng() < 0.5 ? 'rubble_large' : 'rubble_half', Math.cos(a) * r, 0, Math.sin(a) * r, rng() * 6, 0.45, 0.45, 0.45); }
  nat.ajouter('n_statue_head', 0, 0, -6, 0, 3, 3, 3); collisions.push({ x: 0, z: -6, r: 2 });
  for (const [x, z] of [[-10, 8], [10, 8], [-10, -16], [10, -16]]) brasero(groupe, x, z, '#ff5a2a', 1.2);
  for (const [x, z] of [[-40, -120], [-120, -40], [95, 110], [-140, 60]]) { nat.ajouter('n_statue_obelisk', x, 0, z, rng() * 6, 3, 3, 3); collisions.push({ x, z, r: 1 }); }
  // camp de départ (zone sûre) : tentes, feu, bannière
  for (const [x, z, r] of [[-7, 146, 0.6], [7, 146, -0.6], [-5, 156, 0.2]]) { const t = cloner('tent', x, 0, z, r, 5); groupe.add(t); collisions.push({ x, z, r: 1.4 }); }
  nat.ajouter('n_campfire_stones', 0, 0, 152, 0, 3.6, 3.6, 3.6); G.feux.push({ pos: new THREE.Vector3(0, 0.3, 152), couleur: '#ff8a2a', force: 1 }); G.torches.push({ pos: new THREE.Vector3(0, 1.6, 152), color: '#ffa04a', int: 30, dist: 14 });
  const anneauSur = new THREE.Mesh(new THREE.RingGeometry(15.5, 16, 64), new THREE.MeshBasicMaterial({ color: '#7affb0', transparent: true, opacity: 0.35, depthWrite: false })); anneauSur.rotation.x = -Math.PI / 2; anneauSur.position.set(0, 0.06, 148); groupe.add(anneauSur);
  // portails de sortie
  const sorties = [new THREE.Vector3(0, 0, 160), new THREE.Vector3(-150, 0, -10), new THREE.Vector3(140, 0, 60)];
  for (const p of sorties) { construirePortail(groupe, p, Math.atan2(-p.x, -p.z), THEME_VIOLET, 0.42); collisions.push({ x: p.x, z: p.z, r: 1.4 }); }
  // camps de monstres (plus durs en s'éloignant du camp) et coffres
  const camps = [[-80, 40], [-110, -60], [-60, -120], [-30, 70], [0, 0], [20, -40], [-20, -30], [80, -20], [110, -110], [60, 70], [130, 20], [-140, 120]].map(([x, z]) => ({ pos: new THREE.Vector3(x, 0, z), danger: Math.min(3, Math.floor(Math.hypot(x - camp0.x, z - camp0.z) / 70)), biome: biome(x, z) }));
  for (const cp of camps) for (let k = 0; k < 2; k++) inst.ajouter('crates_stacked', cp.pos.x + (k ? 3 : -3), 0, cp.pos.z + 2.5, rng() * 6, 0.8, 0.8, 0.8);
  const dragon = new THREE.Vector3(115, 0, -95);
  fusionnerStatiques(groupe);
  inst.construire(groupe); nat.construire(groupe);
  G.scene.add(groupe);
  // carte complète pour la mini-carte (on n'en affiche qu'un morceau autour du joueur)
  const carte = document.createElement('canvas'); carte.width = carte.height = 512; { const f = carte.getContext('2d'), k = 512 / (2 * R);
    for (let y = 0; y < 512; y += 4) for (let x = 0; x < 512; x += 4) { const wx = x / k - R, wz = y / k - R; const b = Math.hypot(wx, wz) > R ? 'bord' : biome(wx, wz); f.fillStyle = { foret: '#24402a', ruines: '#7a6a52', cendres: '#3a2626', lac: '#1a3a5a', plaine: '#4a5a32', bord: '#1a1410' }[b]; f.fillRect(x, y, 4, 4); }
    f.fillStyle = '#7affb0'; f.beginPath(); f.arc((0 + R) * k, (148 + R) * k, 16 * k, 0, 7); f.fill(); }
  return {
    groupe, type: 'terres', nom: 'Terres Écarlates', spawn: new THREE.Vector3(0, 0, 145), sorties, camps, dragon, collisions, carte, rayonMonde: R, campSur: camp0, rayonSur: 16,
    marche: (x, z) => Math.hypot(x, z) < R - 3, biome,
  };
}

// ======================= TERRES ANCESTRALES : archipel de grandes îles reliées par des ponts =======================
// 7 îles (forêt, ruines, cendres, givre, marais, cristaux, citadelle), chacune avec ses camps et son gardien ; les camps
// s'éveillent quand on approche (le monde paraît plein sans écraser le téléphone).
export function construireAncestrales() {
  const groupe = new THREE.Group();
  G.torches = []; G.feux = []; G.anims = [];
  const inst = new Instancieur(), nat = new Instancieur(), collisions = [], rng = graineRng(777);
  const iles = [
    { x: 0, z: 230, r: 55, b: 'plaine', nom: 'Rivage du Départ' }, { x: -170, z: 120, r: 70, b: 'foret', nom: 'Bois des Ancêtres' },
    { x: 160, z: 110, r: 62, b: 'marais', nom: 'Marais Pourpre' }, { x: 0, z: 30, r: 75, b: 'ruines', nom: 'Ruines d’Ancienne Couronne' },
    { x: -190, z: -110, r: 64, b: 'givre', nom: 'Crêtes de Givre' }, { x: 190, z: -110, r: 66, b: 'cendres', nom: 'Fournaise' },
    { x: 0, z: -210, r: 80, b: 'cristaux', nom: 'Citadelle de Cristal' },
  ];
  const ponts = [[0, 3], [0, 1], [0, 2], [1, 3], [2, 3], [1, 4], [2, 5], [3, 4], [3, 5], [4, 6], [5, 6], [3, 6]];
  const COUL = { plaine: '#a0b868', foret: '#5a8a46', marais: '#7a6a8a', ruines: '#c8b088', givre: '#e8f0f8', cendres: '#7a5a52', cristaux: '#a8a0d8' };
  // mer
  const mer = new THREE.Mesh(new THREE.CircleGeometry(520, 48), new THREE.ShaderMaterial({ uniforms: { uT: { value: 0 } },
    vertexShader: 'varying vec2 vP; void main(){ vP=position.xy; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);} ',
    fragmentShader: 'uniform float uT; varying vec2 vP; void main(){ float w=sin(vP.x*0.12+uT*0.7)*sin(vP.y*0.15-uT*0.5); vec3 c=mix(vec3(0.05,0.16,0.26),vec3(0.1,0.3,0.42),0.5+0.3*w); gl_FragColor=vec4(c,1.0);} ' }));
  mer.rotation.x = -Math.PI / 2; mer.position.y = -1.2; groupe.add(mer); G.anims.push((t) => { mer.material.uniforms.uT.value = t; });
  const tH = texHerbe(); tH.repeat.set(18, 18);
  for (const I of iles) {
    const geo = new THREE.CircleGeometry(I.r, 56, 0, Math.PI * 2).rotateX(-Math.PI / 2);
    const m = new THREE.Mesh(geo, new THREE.MeshStandardMaterial({ color: COUL[I.b], map: I.b === 'givre' ? null : tH, roughness: 1 })); m.position.set(I.x, 0, I.z); m.receiveShadow = true; groupe.add(m);
    const falaise = new THREE.Mesh(new THREE.CylinderGeometry(I.r, I.r * 0.92, 6, 56, 1, true), new THREE.MeshStandardMaterial({ color: '#5a4a3a', roughness: 1, side: THREE.DoubleSide })); falaise.position.set(I.x, -3, I.z); groupe.add(falaise);
    // décor selon l'île
    const n = Math.round(I.r * I.r / 18);
    for (let k = 0; k < n; k++) {
      const a = rng() * 6.283, r = Math.sqrt(rng()) * (I.r - 4), x = I.x + Math.cos(a) * r, z = I.z + Math.sin(a) * r;
      if (r < 10) continue;
      const p = rng();
      if (I.b === 'foret' && p < 0.45) { const s = 1.5 + rng() * 1.4; nat.ajouter(rng() < 0.5 ? 'n_tree_fat_darkh' : 'n_tree_oak', x, 0, z, rng() * 6, s, s, s); collisions.push({ x, z, r: 0.7 }); }
      else if (I.b === 'givre' && p < 0.25) { inst.ajouter('Tree_Bare_2_A', x, 0, z, rng() * 6, 1.5, 1.5, 1.5); collisions.push({ x, z, r: 0.6 }); }
      else if (I.b === 'givre' && p < 0.35) { nat.ajouter('n_stone_tallB', x, 0, z, rng() * 6, 2, 2, 2); collisions.push({ x, z, r: 1 }); }
      else if (I.b === 'marais' && p < 0.3) nat.ajouter(rng() < 0.5 ? 'n_mushroom_redTall' : 'n_mushroom_tanGroup', x, 0, z, rng() * 6, 2, 2, 2);
      else if (I.b === 'marais' && p < 0.42) { nat.ajouter('n_lily_large', x, 0.05, z, rng() * 6, 3, 3, 3); }
      else if (I.b === 'cendres' && p < 0.15) { nat.ajouter(rng() < 0.5 ? 'n_rock_largeB' : 'n_rock_largeC', x, 0, z, rng() * 6, 2.4, 2.4, 2.4); collisions.push({ x, z, r: 1.5 }); }
      else if (I.b === 'cendres' && p < 0.25) { inst.ajouter('Tree_Bare_2_A', x, 0, z, rng() * 6, 1.4, 1.4, 1.4); collisions.push({ x, z, r: 0.6 }); }
      else if (I.b === 'ruines' && p < 0.08) { inst.ajouter(rng() < 0.5 ? 'wall_broken' : 'pillar_decorated', x, 0, z, rng() * 6); collisions.push({ x, z, r: 1.4 }); }
      else if (I.b === 'ruines' && p < 0.14) inst.ajouter('rubble_half', x, 0, z, rng() * 6, 0.5, 0.5, 0.5);
      else if (I.b === 'cristaux' && p < 0.07) { cristaux(groupe, { nom: 'cristalA', cristal: '#b0a0ff' }, x, z, 1 + rng()); collisions.push({ x, z, r: 1.2 }); }
      else if (I.b === 'cristaux' && p < 0.12) { nat.ajouter('n_statue_columnDamaged', x, 0, z, rng() * 6, 2.4, 2.4, 2.4); collisions.push({ x, z, r: 1 }); }
      else if (I.b === 'plaine' && p < 0.12) { inst.ajouter(rng() < 0.5 ? 'Tree_1_A' : 'Tree_3_A', x, 0, z, rng() * 6, 1.2, 1.2, 1.2); collisions.push({ x, z, r: 0.7 }); }
      else if (p < 0.35 && I.b !== 'givre' && I.b !== 'cendres') inst.ajouter(rng() < 0.7 ? 'Grass_1_A' : 'Bush_2_C', x, 0, z, rng() * 6, 1.4, 1.4, 1.4);
    }
    if (I.b === 'cendres') { const lave = new THREE.MeshBasicMaterial({ color: '#ff4a1a', transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false }); for (let k = 0; k < 14; k++) { const a = rng() * 6.28, r = rng() * (I.r - 6); const f = new THREE.Mesh(new THREE.PlaneGeometry(0.6, 8 + rng() * 8), lave); f.rotation.x = -Math.PI / 2; f.rotation.z = rng() * 6; f.position.set(I.x + Math.cos(a) * r, 0.05, I.z + Math.sin(a) * r); groupe.add(f); } G.anims.push((t) => { lave.opacity = 0.6 + Math.sin(t * 1.7) * 0.2; }); }
    if (I.b === 'givre') G.anims.push((t, dt) => { if (Math.random() < (dt || 0.016) * 6) emettre(new THREE.Vector3(I.x + rnd(-I.r, I.r) * 0.7, 9, I.z + rnd(-I.r, I.r) * 0.7), { n: 1, c1: '#ffffff', c2: '#c8e0ff', dir: new THREE.Vector3(0, -1, 0), vit: 1.5, vie: 4, taille: 0.2 }); });
    // brasero et obélisque au centre de chaque île
    brasero(groupe, I.x + 4, I.z, I.b === 'cristaux' ? '#9a7aff' : '#ff7a2a', 1.2); nat.ajouter('n_statue_obelisk', I.x - 3, 0, I.z, 0, 3, 3, 3); collisions.push({ x: I.x - 3, z: I.z, r: 1 });
  }
  // ponts de bois entre les îles
  const bois = new THREE.MeshStandardMaterial({ color: '#7a5434', roughness: 0.9 }), corde = new THREE.MeshStandardMaterial({ color: '#4a3020' });
  const lignes = [];
  for (const [a, b] of ponts) {
    const A = iles[a], B = iles[b], d = Math.hypot(B.x - A.x, B.z - A.z), ux = (B.x - A.x) / d, uz = (B.z - A.z) / d;
    const x0 = A.x + ux * (A.r - 3), z0 = A.z + uz * (A.r - 3), x1 = B.x - ux * (B.r - 3), z1 = B.z - uz * (B.r - 3), L = Math.hypot(x1 - x0, z1 - z0), ang = Math.atan2(x1 - x0, z1 - z0);
    const p = new THREE.Mesh(new THREE.BoxGeometry(5, 0.4, L), bois); p.position.set((x0 + x1) / 2, 0.05, (z0 + z1) / 2); p.rotation.y = ang; p.receiveShadow = true; groupe.add(p);
    for (const s of [-1, 1]) { const r = new THREE.Mesh(new THREE.BoxGeometry(0.15, 0.15, L), corde); r.position.set((x0 + x1) / 2 + Math.cos(ang) * s * 2.5, 1, (z0 + z1) / 2 - Math.sin(ang) * s * 2.5); r.rotation.y = ang; groupe.add(r); }
    lignes.push({ x0, z0, x1, z1, L });
  }
  // camps (6 à 8 par île, plus durs vers la citadelle) et gardiens
  const depart = iles[0], camps = [], gardiens = [];
  iles.forEach((I, k) => {
    const danger = k === 0 ? 0 : k <= 2 ? 1 : k <= 5 ? 2 : 3;
    const nb = k === 0 ? 3 : 10;
    for (let c = 0; c < nb; c++) { const a = c / nb * 6.283 + rng(), r = I.r * (0.35 + rng() * 0.45); camps.push({ pos: new THREE.Vector3(I.x + Math.cos(a) * r, 0, I.z + Math.sin(a) * r), danger, biome: I.b, ile: k }); }
    if (k) gardiens.push({ pos: new THREE.Vector3(I.x + 12, 0, I.z - 10), ile: k, danger });
  });
  // portails : sortie au départ et dans la citadelle
  const sorties = [new THREE.Vector3(0, 0, 268), new THREE.Vector3(0, 0, -270)];
  for (const p of sorties) { construirePortail(groupe, p, Math.atan2(-p.x, -p.z), THEME_VIOLET, 0.42); collisions.push({ x: p.x, z: p.z, r: 1.4 }); }
  for (const [x, z, r] of [[-8, 236, 0.6], [8, 236, -0.6]]) { const t = cloner('tent', x, 0, z, r, 5); groupe.add(t); collisions.push({ x, z, r: 1.4 }); }
  nat.ajouter('n_campfire_stones', 0, 0, 242, 0, 3.6, 3.6, 3.6); G.feux.push({ pos: new THREE.Vector3(0, 0.3, 242), couleur: '#ff8a2a', force: 1 }); G.torches.push({ pos: new THREE.Vector3(0, 1.6, 242), color: '#ffa04a', int: 30, dist: 14 });
  fusionnerStatiques(groupe);
  inst.construire(groupe); nat.construire(groupe);
  G.scene.add(groupe);
  const surIle = (x, z) => iles.some(I => Math.hypot(x - I.x, z - I.z) < I.r - 2.5);
  const surPont = (x, z) => lignes.some(l => { const vx = l.x1 - l.x0, vz = l.z1 - l.z0, t = Math.max(0, Math.min(1, ((x - l.x0) * vx + (z - l.z0) * vz) / (l.L * l.L))); return Math.hypot(x - (l.x0 + vx * t), z - (l.z0 + vz * t)) < 2.2; });
  const RM = 320, carte = document.createElement('canvas'); carte.width = carte.height = 512; { const f = carte.getContext('2d'), k = 512 / (2 * RM); f.fillStyle = '#123448'; f.fillRect(0, 0, 512, 512);
    f.strokeStyle = '#8a6a44'; f.lineWidth = 4 * k; for (const l of lignes) { f.beginPath(); f.moveTo((l.x0 + RM) * k, (l.z0 + RM) * k); f.lineTo((l.x1 + RM) * k, (l.z1 + RM) * k); f.stroke(); }
    for (const I of iles) { f.fillStyle = COUL[I.b]; f.beginPath(); f.arc((I.x + RM) * k, (I.z + RM) * k, I.r * k, 0, 7); f.fill(); } }
  return {
    groupe, type: 'terres', sousType: 'ancestrales', nom: 'Terres Ancestrales', iles, spawn: new THREE.Vector3(0, 0, 238), sorties, camps, gardiens, collisions, carte, rayonMonde: RM, campSur: new THREE.Vector3(0, 0, 238), rayonSur: 14,
    marche: (x, z) => surIle(x, z) || surPont(x, z), biome: (x, z) => { const I = iles.find(I => Math.hypot(x - I.x, z - I.z) < I.r); return I ? I.b : 'mer'; },
  };
}

// une île des Terres Ancestrales (une étape) : petite, dense, un coffre, un portail, un gardien
export function construireIleAnc({ r = 34, biome = 'foret', etape = 1, graine = 1 } = {}) {
  const groupe = new THREE.Group();
  G.torches = []; G.feux = []; G.anims = [];
  const inst = new Instancieur(), nat = new Instancieur(), collisions = [], rng = graineRng(graine * 97 + etape);
  const COUL = { plaine: '#a0b868', foret: '#5a8a46', marais: '#7a6a8a', ruines: '#c8b088', givre: '#e8f0f8', cendres: '#7a5a52', cristaux: '#a8a0d8' };
  const mer = new THREE.Mesh(new THREE.CircleGeometry(300, 40), new THREE.ShaderMaterial({ uniforms: { uT: { value: 0 } },
    vertexShader: 'varying vec2 vP; void main(){ vP=position.xy; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);} ',
    fragmentShader: 'uniform float uT; varying vec2 vP; void main(){ float w=sin(vP.x*0.12+uT*0.7)*sin(vP.y*0.15-uT*0.5); vec3 c=mix(vec3(0.05,0.16,0.26),vec3(0.1,0.3,0.42),0.5+0.3*w); gl_FragColor=vec4(c,1.0);} ' }));
  mer.rotation.x = -Math.PI / 2; mer.position.y = -1.2; groupe.add(mer); G.anims.push((t) => { mer.material.uniforms.uT.value = t; });
  const tH = texHerbe(); tH.repeat.set(10, 10);
  const sol = new THREE.Mesh(new THREE.CircleGeometry(r, 56).rotateX(-Math.PI / 2), new THREE.MeshStandardMaterial({ color: COUL[biome], map: biome === 'givre' ? null : tH, roughness: 1 })); sol.receiveShadow = true; groupe.add(sol);
  const falaise = new THREE.Mesh(new THREE.CylinderGeometry(r, r * 0.9, 7, 56, 1, true), new THREE.MeshStandardMaterial({ color: '#5a4a3a', roughness: 1, side: THREE.DoubleSide })); falaise.position.y = -3.5; groupe.add(falaise);
  const spawn = new THREE.Vector3(0, 0, r - 6), portail = new THREE.Vector3(0, 0, -r + 6), coffre = new THREE.Vector3(6, 0, -r + 10), boss = new THREE.Vector3(0, 0, -4);
  const reserve = [spawn, portail, coffre, boss, new THREE.Vector3(0, 0, 0)];
  const n = Math.round(r * r / 9);
  for (let k = 0; k < n; k++) {
    const a = rng() * 6.283, d = Math.sqrt(rng()) * (r - 3), x = Math.cos(a) * d, z = Math.sin(a) * d;
    if (reserve.some(p => Math.hypot(p.x - x, p.z - z) < 7)) continue;
    const p = rng();
    if (biome === 'foret' && p < 0.3) { const s = 1.4 + rng(); nat.ajouter(rng() < 0.5 ? 'n_tree_fat_darkh' : 'n_tree_oak', x, 0, z, rng() * 6, s, s, s); collisions.push({ x, z, r: 0.7 }); }
    else if (biome === 'givre' && p < 0.2) { inst.ajouter('Tree_Bare_2_A', x, 0, z, rng() * 6, 1.4, 1.4, 1.4); collisions.push({ x, z, r: 0.6 }); }
    else if (biome === 'cendres' && p < 0.12) { nat.ajouter('n_rock_largeB', x, 0, z, rng() * 6, 2.2, 2.2, 2.2); collisions.push({ x, z, r: 1.4 }); }
    else if (biome === 'marais' && p < 0.3) nat.ajouter(rng() < 0.5 ? 'n_mushroom_redTall' : 'n_mushroom_tanGroup', x, 0, z, rng() * 6, 2, 2, 2);
    else if (biome === 'ruines' && p < 0.1) { inst.ajouter(rng() < 0.5 ? 'wall_broken' : 'pillar_decorated', x, 0, z, rng() * 6); collisions.push({ x, z, r: 1.3 }); }
    else if (biome === 'cristaux' && p < 0.06) { cristaux(groupe, { nom: 'cristalA', cristal: '#b0a0ff' }, x, z, 1 + rng()); collisions.push({ x, z, r: 1.1 }); }
    else if (p < 0.3 && biome !== 'givre' && biome !== 'cendres') inst.ajouter(rng() < 0.7 ? 'Grass_1_A' : 'Bush_2_C', x, 0, z, rng() * 6, 1.4, 1.4, 1.4);
  }
  if (biome === 'cendres') { const lave = new THREE.MeshBasicMaterial({ color: '#ff4a1a', transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false }); for (let k = 0; k < 10; k++) { const a = rng() * 6.28, d = rng() * (r - 5); const f = new THREE.Mesh(new THREE.PlaneGeometry(0.6, 6 + rng() * 6), lave); f.rotation.x = -Math.PI / 2; f.rotation.z = rng() * 6; f.position.set(Math.cos(a) * d, 0.05, Math.sin(a) * d); groupe.add(f); } }
  if (biome === 'givre') G.anims.push((t, dt) => { if (Math.random() < (dt || 0.016) * 6) emettre(new THREE.Vector3(rnd(-r, r) * 0.7, 9, rnd(-r, r) * 0.7), { n: 1, c1: '#ffffff', c2: '#c8e0ff', dir: new THREE.Vector3(0, -1, 0), vit: 1.5, vie: 4, taille: 0.2 }); });
  // portail éteint (il s'allume avec la pierre) : socle et anneau
  const socle = new THREE.Mesh(new THREE.CylinderGeometry(2.4, 2.8, 0.6, 24), new THREE.MeshStandardMaterial({ color: '#4a4a5a', roughness: 0.8 })); socle.position.set(portail.x, 0.3, portail.z); groupe.add(socle);
  const anneau = new THREE.Mesh(new THREE.TorusGeometry(2, 0.22, 10, 40), new THREE.MeshStandardMaterial({ color: '#6a6a8a', emissive: '#000000' })); anneau.position.set(portail.x, 2.6, portail.z); groupe.add(anneau);
  const voile = new THREE.Mesh(new THREE.CircleGeometry(1.85, 32), new THREE.MeshBasicMaterial({ color: '#7ab8ff', transparent: true, opacity: 0, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide })); voile.position.copy(anneau.position); groupe.add(voile);
  collisions.push({ x: portail.x, z: portail.z, r: 2.4 });
  G.anims.push((t) => { anneau.rotation.z = t * (voile.material.opacity > 0.1 ? 2 : 0.2); voile.material.opacity = groupe.userData.portailActif ? 0.55 + 0.25 * Math.sin(t * 4) : 0; anneau.material.emissive.set(groupe.userData.portailActif ? '#3a8aff' : '#000000'); });
  fusionnerStatiques(groupe); inst.construire(groupe); nat.construire(groupe); G.scene.add(groupe);
  const carte = document.createElement('canvas'); carte.width = carte.height = 512; { const f = carte.getContext('2d'), RM = r + 12, k = 512 / (2 * RM); f.fillStyle = '#123448'; f.fillRect(0, 0, 512, 512); f.fillStyle = COUL[biome]; f.beginPath(); f.arc(RM * k, RM * k, r * k, 0, 7); f.fill(); }
  return { groupe, type: 'terres', sousType: 'ileAnc', nom: 'Terres Ancestrales', spawn, portail, coffrePos: coffre, bossPos: boss, sorties: [], collisions, carte, rayonMonde: r + 12, campSur: new THREE.Vector3(0, 0, 999), rayonSur: 0,
    marche: (x, z) => Math.hypot(x, z) < r - 2, biome: () => biome };
}

// ======================= LE DOMAINE =======================
// Un plateau au bord de la mer : château qui grandit avec le niveau (campement → citadelle), ferme, village des serviteurs.
export function construireDomaine(dom) {
  const groupe = new THREE.Group();
  G.torches = []; G.feux = []; G.anims = [];
  const N = dom.niveau | 0, th = THEMES_DONJON[0], teinte = teinteDonjon(th);
  const inst = new Instancieur(), nat = new Instancieur(), collisions = [];
  const R = 56;
  // sol : herbe, mer autour
  const tH = texHerbe(); tH.repeat.set(26, 26);
  const sol = new THREE.Mesh(new THREE.CircleGeometry(R + 4, 72), new THREE.MeshStandardMaterial({ map: tH, color: '#d8f0c0', roughness: 1 }));
  sol.rotation.x = -Math.PI / 2; sol.receiveShadow = true; groupe.add(sol);
  const bordure = new THREE.Mesh(new THREE.CylinderGeometry(R + 4, R + 1, 3, 72, 1, true), new THREE.MeshStandardMaterial({ color: '#7a6a52', roughness: 1, side: THREE.DoubleSide })); bordure.position.y = -1.5; groupe.add(bordure);
  const mer = new THREE.Mesh(new THREE.CircleGeometry(300, 64), new THREE.ShaderMaterial({ uniforms: { uT: { value: 0 } },
    vertexShader: 'varying vec2 vP; void main(){ vP=position.xy; gl_Position=projectionMatrix*modelViewMatrix*vec4(position,1.0);} ',
    fragmentShader: 'uniform float uT; varying vec2 vP; void main(){ float w=sin(vP.x*0.18+uT*0.8)*sin(vP.y*0.21-uT*0.6)+sin((vP.x+vP.y)*0.11+uT*0.5); vec3 c=mix(vec3(0.09,0.33,0.52),vec3(0.16,0.52,0.72),0.5+0.25*w); c+=vec3(0.7,0.85,1.0)*smoothstep(1.55,1.9,w)*0.25; float d=length(vP)/300.0; c=mix(c,vec3(0.07,0.18,0.32),smoothstep(0.3,1.0,d)); gl_FragColor=vec4(c,1.0);}' }));
  mer.rotation.x = -Math.PI / 2; mer.position.y = -2.2; groupe.add(mer); G.anims.push((t) => { mer.material.uniforms.uT.value = t; });
  // chemins pavés
  const texPaves = texture('pavesIle', 256, 256, (g, w) => { g.fillStyle = '#9a8a6a'; g.fillRect(0, 0, w, w); for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) { const ox = (y % 2) * 16; g.fillStyle = `hsl(${32 + Math.random() * 12},${14 + Math.random() * 10}%,${52 + Math.random() * 16}%)`; g.beginPath(); g.roundRect(x * 32 + ox + 2, y * 32 + 2, 28, 28, 6); g.fill(); } }, { repeat: true });
  const chemin = (x0, z0, x1, z1, larg = 3) => { const L = Math.hypot(x1 - x0, z1 - z0); const t = texPaves.clone(); t.needsUpdate = true; t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(larg / 2.4, L / 2.4); const m = new THREE.Mesh(new THREE.PlaneGeometry(larg, L), new THREE.MeshStandardMaterial({ map: t, roughness: 0.95, polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2 })); m.rotation.set(-Math.PI / 2, 0, Math.atan2(x1 - x0, z1 - z0)); m.position.set((x0 + x1) / 2, 0.03, (z0 + z1) / 2); m.receiveShadow = true; groupe.add(m); };
  chemin(0, 50, 0, -14, 4); chemin(0, 6, -22, 8); chemin(0, 2, 24, 6); chemin(-3, -14, -3, -28, 6.5); chemin(3, -14, 3, -28, 6.5);
  // portail de retour
  const portailPos = new THREE.Vector3(0, 0, 50);
  construirePortail(groupe, portailPos, Math.PI, THEME_JAUNE, 0.45); collisions.push({ x: 0, z: 50, r: 1.4 });
  // ---- le château ----
  const X0 = -16, X1 = 16, Z0 = -40, Z1 = -14;
  const pose = (k, x, z, rot, s = 1) => { const o = cloner(k, x, 0, z, rot, s); groupe.add(o); return o; };
  const tour = (x, z, s) => { pose('b_tower_A', x, z, Math.atan2(-x, 30 - z), s); collisions.push({ x, z, r: s * 0.55 }); };
  if (N === 0) { // campement
    for (const [x, z, r] of [[-9, -30, 0.6], [9, -30, -0.6], [-11, -20, 1.2], [11, -20, -1.2], [-4, -36, 0.2], [4, -36, -0.2]]) { pose('tent', x, z, r, 6); collisions.push({ x, z, r: 1.6 }); }
    nat.ajouter('n_campfire_stones', 0, 0, -24, 0, 4.4, 4.4, 4.4); G.feux.push({ pos: new THREE.Vector3(0, 0.3, -24), couleur: '#ff8a2a', force: 1.1 }); G.torches.push({ pos: new THREE.Vector3(0, 1.6, -24), color: '#ffa04a', int: 34, dist: 14 }); collisions.push({ x: 0, z: -24, r: 1.2 });
    pose('flag_yellow', 0, -33, 0, 14);
  } else if (N === 1) { // fortin : palissade, tours de guet, grande salle
    for (let x = X0 + 2; x < X1; x += 4) { inst.ajouter('barrier', x, 0, Z0, 0, 1, 1.4, 1); if (Math.abs(x) > 4) inst.ajouter('barrier', x, 0, Z1, 0, 1, 1.4, 1); }
    for (let z = Z0 + 2; z < Z1; z += 4) { inst.ajouter('barrier', X0, 0, z, Math.PI / 2, 1, 1.4, 1); inst.ajouter('barrier', X1, 0, z, Math.PI / 2, 1, 1.4, 1); }
    tour(-16, -14, 3.2); tour(16, -14, 3.2);
    pose('b_home_B', 0, -34, 0, 7); collisions.push({ x: 0, z: -34, r: 3.6 });
  } else if (!G.assets.c_wall) { // (secours si le kit du château n'a pas pu être chargé)
    for (let x = X0 + 2; x < X1; x += 4) { inst.ajouter('wall', x, 0, Z0, 0); if (Math.abs(x) > 4) inst.ajouter('wall', x, 0, Z1, 0); }
    for (let z = Z0 + 2; z < Z1; z += 4) { inst.ajouter('wall', X0, 0, z, Math.PI / 2); inst.ajouter('wall', X1, 0, z, Math.PI / 2); }
    for (const [x, z] of [[X0, Z0], [X1, Z0], [X0, Z1], [X1, Z1]]) tour(x, z, 4.6);
    tour(0, -35, 7.5);
  }
  if (N >= 1 && (N === 1 || !G.assets.c_wall)) { // remparts : collisions
    for (let x = X0; x <= X1; x += 1.2) { collisions.push({ x, z: Z0, r: 0.8 }); if (Math.abs(x) > 4.4) collisions.push({ x, z: Z1, r: 0.8 }); }
    for (let z = Z0; z <= Z1; z += 1.2) { collisions.push({ x: X0, z, r: 0.8 }); collisions.push({ x: X1, z, r: 0.8 }); }
  }
  let troneP = new THREE.Vector3(0, 0, -27.5), tresorPos = new THREE.Vector3(5, 0, -27), reliefs = [];
  if (N >= 2 && G.assets.c_wall) {
    const C = chateauDomaine(groupe, inst, collisions, reliefs, th, N);
    troneP = C.trone; tresorPos = C.tresor;
  } else {
    trone(groupe, th, 0, 0, -27.5, 0); collisions.push({ x: 0, z: -27.5, r: 1.6 });
  }
  // ---- la ferme ----
  const sillons = texture('sillons', 128, 128, (g, w) => { g.fillStyle = '#5a3a22'; g.fillRect(0, 0, w, w); for (let y = 0; y < w; y += 16) { g.fillStyle = '#6e4a2c'; g.fillRect(0, y, w, 9); g.fillStyle = 'rgba(0,0,0,0.2)'; g.fillRect(0, y + 9, w, 2); } }, { repeat: true });
  const champs = [];
  for (const [cx, cz] of [[-24, 4], [-24, 14], [-36, 10]]) {
    const t = sillons.clone(); t.needsUpdate = true; t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(2, 1.4);
    const ch = new THREE.Mesh(new THREE.PlaneGeometry(9, 6), new THREE.MeshStandardMaterial({ map: t, roughness: 1, polygonOffset: true, polygonOffsetFactor: -1, polygonOffsetUnits: -1 })); ch.rotation.x = -Math.PI / 2; ch.position.set(cx, 0.025, cz); ch.receiveShadow = true; groupe.add(ch);
    const k = pick(['crop_carrot', 'crop_pumpkin', 'crop_melon']);
    for (let ix = -3; ix <= 3; ix += 1.5) for (let iz = -2; iz <= 2; iz += 1.3) inst.ajouter(k, cx + ix, 0, cz + iz, rnd(0, 6), 2.6, 2.6, 2.6);
    champs.push(new THREE.Vector3(cx, 0, cz));
  }
  pose('b_windmill', -38, -4, 0.6, 5.5); collisions.push({ x: -38, z: -4, r: 3 });
  { const m = groupe.children[groupe.children.length - 1]; const pale = m.getObjectByName('building_windmill_top_fan_yellow'); if (pale) G.anims.push((t, dt) => { pale.rotation.z -= (dt || 0.016) * 0.8; }); }
  pose('b_well', -14, 20, 0, 4.5); collisions.push({ x: -14, z: 20, r: 1.7 });
  for (const [x, z] of [[-30, 20], [-18, -2]]) { pose('sack', x, z, rnd(0, 6), 10); pose('barrel', x + 1.2, z + 0.6, 0, 6); }
  // ---- le village des serviteurs ----
  const maisons = [[18, 16], [26, 18], [34, 12], [36, 2], [30, -10], [20, -8]];
  const postes = {};
  maisons.forEach(([x, z], i) => { if (i < Math.max(2, (dom.serviteurs || []).length)) { pose('b_home_A', x, z, Math.atan2(-x, -z), 5); collisions.push({ x, z, r: 2.4 }); } });
  // forge
  { const fx = 24, fz = 2; const enclume = new THREE.Mesh(new THREE.BoxGeometry(1.2, 0.5, 0.6), new THREE.MeshStandardMaterial({ color: '#3a3a40', metalness: 0.7, roughness: 0.35 })); enclume.position.set(fx, 0.85, fz); enclume.castShadow = true; groupe.add(enclume);
    const pied = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.45, 0.6, 8), new THREE.MeshStandardMaterial({ color: '#5a3a22' })); pied.position.set(fx, 0.3, fz); groupe.add(pied);
    brasero(groupe, fx + 2.6, fz - 1, '#ff6a1a', 0.9); pose('Wood_Log_Stack', fx - 3, fz - 1.4, 0.4, 1.3); collisions.push({ x: fx, z: fz, r: 0.9 }, { x: fx - 3, z: fz - 1.4, r: 1.4 });
    postes.forgeron = { pos: new THREE.Vector3(fx, 0, fz + 1.4), regard: new THREE.Vector3(fx, 0, fz) }; postes.enclume = new THREE.Vector3(fx, 1.2, fz); }
  // cuisine
  { const kx = 10, kz = 12; nat.ajouter('n_campfire_stones', kx, 0, kz, 0, 3.6, 3.6, 3.6); G.feux.push({ pos: new THREE.Vector3(kx, 0.3, kz), couleur: '#ff8a2a', force: 0.8 }); G.torches.push({ pos: new THREE.Vector3(kx, 1.6, kz), color: '#ffa04a', int: 22, dist: 10 });
    const marmite = new THREE.Mesh(new THREE.CylinderGeometry(0.6, 0.45, 0.7, 14), new THREE.MeshStandardMaterial({ color: '#2a2a2e', metalness: 0.6, roughness: 0.4 })); marmite.position.set(kx, 0.6, kz); groupe.add(marmite);
    G.anims.push((t, dt) => { if (Math.random() < (dt || 0.016) * 3) emettre(new THREE.Vector3(kx, 1.1, kz), { n: 1, c1: '#ffffff', c2: '#c8c8c8', dir: new THREE.Vector3(0, 1, 0), vit: 0.8, vie: 1.6, taille: 0.5, grav: -0.3 }); });
    collisions.push({ x: kx, z: kz, r: 1.2 }); postes.cuisinier = { pos: new THREE.Vector3(kx + 1.4, 0, kz + 0.6), regard: new THREE.Vector3(kx, 0, kz) }; }
  // écurie
  { pose('tent', 36, -16, -0.6, 7); collisions.push({ x: 36, z: -16, r: 2 }); pose('sack', 33, -13, 0, 12); pose('barrel', 39, -12, 0, 6); postes.ecuyer = { pos: new THREE.Vector3(34, 0, -12), regard: new THREE.Vector3(36, 0, -16) }; }
  postes.fermier = { pts: champs.map(c => c.clone().add(new THREE.Vector3(0, 0, 3.6))) };
  postes.intendant = { pos: tresorPos.clone().add(new THREE.Vector3(1.8, 0, 1.2)), regard: tresorPos.clone() };
  postes.garde = { pts: [new THREE.Vector3(-12, 0, -17), new THREE.Vector3(12, 0, -17), new THREE.Vector3(12, 0, -36), new THREE.Vector3(-12, 0, -36)] };
  // arbres tout autour
  const rng = graineRng(dom.graine || 99);
  for (let i = 0; i < 70; i++) { const a = rng() * 6.283, r = 44 + rng() * 10; const x = Math.cos(a) * r, z = Math.sin(a) * r; if (Math.abs(x) < 6 && z > 40) continue; inst.ajouter(pick(['Tree_1_A', 'Tree_2_B', 'Tree_3_A', 'Tree_4_A']), x, 0, z, rng() * 6, 0.9 + rng() * 0.3, 0.9 + rng() * 0.3, 0.9 + rng() * 0.3); collisions.push({ x, z, r: 1 }); }
  for (let i = 0; i < 90; i++) { const a = rng() * 6.283, r = rng() * 42; const x = Math.cos(a) * r, z = Math.sin(a) * r; if (x > -18 && x < 18 && z > -42 && z < -12) continue; inst.ajouter(rng() < 0.7 ? 'Grass_1_A' : pick(['flower_yellowA', 'flower_redA', 'flower_purpleA']), x, 0, z, rng() * 6, 1.8, 1.8, 1.8); }
  fusionnerStatiques(groupe);
  inst.construire(groupe, { mat: teinte }); nat.construire(groupe, { mat: teinte });
  G.scene.add(groupe);
  return {
    groupe, type: 'domaine', nom: 'Domaine', dom, spawn: new THREE.Vector3(0, 0, 44), portail: { pos: portailPos }, tresorPos, trone: troneP, postes, collisions, portes: groupe.userData.portes || [],
    solH: reliefs.length ? (x, z) => { for (const r of reliefs) { if (x < r.x0 || x > r.x1 || z < r.z0 || z > r.z1) continue; if (r.type === 'plat') return r.h; const t = r.axe === 'z' ? Math.abs(z - r.haut) : Math.abs(x - r.haut); return r.h * Math.max(0, 1 - t / r.L); } return 0; } : null,
    rayonMonde: R, centre: new THREE.Vector3(0, 0, 0),
    marche: (x, z) => Math.hypot(x, z) < R,
  };
}
