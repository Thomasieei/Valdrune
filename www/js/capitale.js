// ================= VALCOURT, LA CAPITALE =================
// Une vraie ville : rempart de 112 m avec chemin de ronde, grande porte, grille de rues pavées (avenue royale + 2 rues
// nord-sud + 3 rues est-ouest), place du marché, quartier des artisans (forges, boucherie, boulangerie, scierie),
// taverne, maison de la sorcière, quartier noble, palais et salle du trône.
// Et des gens qui y vivent selon leur rôle : ménagères qui font leur marché, ouvriers qui vont au travail, enfants qui
// jouent à chat, gardes en patrouille (rues et remparts), caravanes de marchands qui entrent et sortent, PNJ nommés.
import { THREE, G, V, tmp, texteFlottant, emettre } from './moteur.js';
import { hauteur, CAPITALE as CP } from './monde.js';
import { plan3D, modele, piece, maison } from './batiments.js';
import { prop } from './persos.js';
import { Villageois, blocs, bloqueHumain, fusionner, champ, tour, MAT_POTEAU, MAT_OR } from './humains.js';

const rnd = (a, b) => a + Math.random() * (b - a), pick = (L) => L[Math.floor(Math.random() * L.length)];
const HE = 3.12, K = 1.3;
const MAT_DALLE = new THREE.MeshStandardMaterial({ color: '#8a8070', roughness: 0.95 }), MAT_MUR = new THREE.MeshStandardMaterial({ color: '#8e8678', roughness: 0.95, flatShading: true });

// ---------- panneau d'enseigne : planche + texte peint ----------
function enseigne(texte, couleur = '#e8d8b0') {
  const c = document.createElement('canvas'); c.width = 256; c.height = 64; const x = c.getContext('2d');
  x.fillStyle = '#4a3020'; x.fillRect(0, 0, 256, 64); x.strokeStyle = '#2a180c'; x.lineWidth = 6; x.strokeRect(3, 3, 250, 58);
  x.fillStyle = couleur; x.font = 'bold 30px Georgia, serif'; x.textAlign = 'center'; x.textBaseline = 'middle'; x.fillText(texte, 128, 34);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace;
  const g = new THREE.Group(), p = new THREE.Mesh(new THREE.PlaneGeometry(1.9, 0.48), new THREE.MeshStandardMaterial({ map: t, side: THREE.DoubleSide, roughness: 0.9 })); p.position.y = 2.9; g.add(p);
  const pot = new THREE.Mesh(new THREE.CylinderGeometry(0.06, 0.08, 3.2, 6), MAT_POTEAU); pot.position.set(-1.05, 1.6, 0); g.add(pot);
  return g;
}
// ---------- étiquette de nom au-dessus d'un PNJ important ----------
function etiquette(nom, titre) {
  const c = document.createElement('canvas'); c.width = 256; c.height = 72; const x = c.getContext('2d'); x.textAlign = 'center';
  x.font = 'bold 30px Georgia, serif'; x.lineWidth = 6; x.strokeStyle = 'rgba(0,0,0,.8)'; x.strokeText(nom, 128, 30); x.fillStyle = '#ffe28a'; x.fillText(nom, 128, 30);
  x.font = 'italic 22px Georgia, serif'; x.strokeText(titre, 128, 60); x.fillStyle = '#e8e0d0'; x.fillText(titre, 128, 60);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; const s = new THREE.Sprite(new THREE.SpriteMaterial({ map: t, depthTest: false, transparent: true })); s.scale.set(1.8, 0.5, 1); s.position.y = 2.25; s.renderOrder = 10; return s;
}

// ================= le plan des rues =================
// nœuds = carrefours ; arêtes = tronçons de rue. Tous les déplacements de la foule passent par là.
let N = [], A = new Map(); // nœuds [x,z] locaux, voisins
function graphe() {
  N = []; A = new Map(); const id = (x, z) => { let i = N.findIndex(n => n[0] === x && n[1] === z); if (i < 0) { i = N.length; N.push([x, z]); A.set(i, new Set()); } return i; };
  const lier = (a, b) => { A.get(a).add(b); A.get(b).add(a); };
  for (const x of CP.vx) { let prev = null; for (const z of [CP.zMin, ...CP.hz, CP.zMax]) { const i = id(x, z); if (prev !== null) lier(prev, i); prev = i; } }
  for (const z of CP.hz) { let prev = null; for (const x of [CP.xMin, ...CP.vx, CP.xMax]) { const i = id(x, z); if (prev !== null) lier(prev, i); prev = i; } }
  const porte = id(0, -CP.H - 2), dehors = id(0, -CP.H - 22); lier(id(0, CP.zMin), porte); lier(porte, dehors);
}
const projeter = (x, z) => { // point de rue le plus proche d'un endroit (pour sortir d'une porte de maison)
  let best = null, bd = 1e9; for (const [a, voisins] of A) for (const b of voisins) { if (b < a) continue; const [ax, az] = N[a], [bx, bz] = N[b], dx = bx - ax, dz = bz - az, L2 = dx * dx + dz * dz, t = Math.max(0, Math.min(1, ((x - ax) * dx + (z - az) * dz) / L2)), px = ax + dx * t, pz = az + dz * t, d = (px - x) ** 2 + (pz - z) ** 2; if (d < bd) { bd = d; best = { p: [px, pz], a, b }; } } return best; };
function chemin(de, vers) { // Dijkstra entre deux points de rue
  const s = projeter(...de), e = projeter(...vers), dist = new Map(), prec = new Map(), file = [];
  const d2 = (i, p) => Math.hypot(N[i][0] - p[0], N[i][1] - p[1]);
  for (const i of [s.a, s.b]) { dist.set(i, d2(i, s.p)); prec.set(i, -1); file.push(i); }
  while (file.length) { file.sort((a, b) => dist.get(a) - dist.get(b)); const u = file.shift(); for (const v of A.get(u)) { const nd = dist.get(u) + d2(v, N[u]); if (nd < (dist.get(v) ?? 1e9)) { dist.set(v, nd); prec.set(v, u); if (!file.includes(v)) file.push(v); } } }
  const fin = [e.a, e.b].sort((a, b) => (dist.get(a) + d2(a, e.p)) - (dist.get(b) + d2(b, e.p)))[0]; const L = []; for (let i = fin; i !== -1 && i !== undefined; i = prec.get(i)) L.unshift(N[i]);
  return [de, s.p, ...L, e.p, vers];
}
// sur le trottoir : décale le trajet d'un côté de la rue (piétons), au centre pour gardes et charrettes
function trottoir(L, cote) { if (!cote) return L.map(p => [...p]); const R = [L[0]]; for (let i = 1; i < L.length - 1; i++) { const [ax, az] = L[i - 1], [bx, bz] = L[i], [cx, cz] = L[i + 1]; let dx = cx - ax, dz = cz - az; const l = Math.hypot(dx, dz) || 1; R.push([bx + dz / l * cote, bz - dx / l * cote]); } R.push(L[L.length - 1]); return R; }

// ================= construction =================
export function construireCapitale(Vg) {
  graphe();
  const brut = new THREE.Group(), haut = new THREE.Group(), cx = Vg.x, cz = Vg.z, H = CP.H, y0 = hauteur(cx, cz);
  const W = (x, z) => [cx + x, cz + z];
  const pose = (o, x, z, r = 0, k = 1, dy = 0, dans = brut) => { o.position.set(x, y0 + dy, z); o.rotation.y = r; o.scale.multiplyScalar(k); dans.add(o); return o; };
  const lieux = Vg.lieux = {}; const maisons = Vg.maisons = [];
  // ---- rempart : 2 rangs, créneaux, chemin de ronde intérieur, tours d'angle et tours intermédiaires ----
  const pas = 2 * K, hm = 2 * HE * K;
  for (const [sx, sz, r] of [[0, -1, 0], [0, 1, Math.PI], [-1, 0, Math.PI / 2], [1, 0, -Math.PI / 2]]) {
    for (let t = -H + 4; t < H - 4; t += pas) {
      const [x, z] = sz ? W(t + pas / 2, sz * H) : W(sx * H, t + pas / 2); if (sz === -1 && Math.abs(t + pas / 2) < 7.5) continue;
      for (let k = 0; k < 2; k++) pose(modele('Wall_UnevenBrick_Straight'), x, z, r, K, k * HE * K);
      pose(modele('Prop_ExteriorBorder_Straight1'), x, z, r, K, hm); blocs.push({ x, z, r: 1.7 });
    }
    // chemin de ronde (dalle de pierre derrière les créneaux) et ses piliers
    const len = 2 * H - 8, wk = new THREE.Mesh(new THREE.BoxGeometry(sz ? len : 2.4, 0.4, sz ? 2.4 : len), MAT_MUR); const [wx, wz] = sz ? W(0, sz * (H - 1.5)) : W(sx * (H - 1.5), 0); wk.position.set(wx, y0 + hm - 0.2, wz); brut.add(wk);
    for (let t = -H + 8; t < H - 6; t += 9) { const [x, z] = sz ? W(t, sz * (H - 2.3)) : W(sx * (H - 2.3), t); const p = new THREE.Mesh(new THREE.BoxGeometry(0.7, hm, 0.7), MAT_MUR); p.position.set(x, y0 + hm / 2, z); brut.add(p); }
  }
  for (const [sx, sz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) tour(pose, ...W(sx * H, sz * H), 4);
  for (const [x, z] of [[-H, -10], [H, -10], [-H, 20], [H, 20], [-28, H], [28, H]]) tour(pose, ...W(x, z), 3, K * 0.9);
  // escaliers vers le chemin de ronde, de part et d'autre de la porte
  for (const s of [-1, 1]) for (let k = 0; k < Math.ceil(hm); k++) pose(modele('Stairs_Exterior_Straight'), ...W(s * (12 + k * 2), -H + 2.6), s > 0 ? -Math.PI / 2 : Math.PI / 2, 1, k);
  // ---- la grande porte ----
  for (const s of [-1, 1]) { tour(pose, ...W(s * 6.6, -H), 5, K * 1.1); pose(modele('Banner'), ...W(s * 6.6, -H - 3.5), Math.PI, 1.3, 9.2); }
  for (const s of [-1, 0, 1]) { pose(modele('Wall_UnevenBrick_Straight'), ...W(s * pas, -H - 0.3), 0, K, HE * K * 1.05); pose(modele('Wall_UnevenBrick_Straight'), ...W(s * pas, -H + 0.3), Math.PI, K, HE * K * 1.05); pose(modele('Prop_ExteriorBorder_Straight1'), ...W(s * pas, -H), 0, K, 2 * HE * K * 1.05); }
  pose(modele('Portcullis_Wood'), ...W(0, -H), 0, 1.75, HE * K * 0.95);
  pose(modele('DoorGate_Wooden_Left'), ...W(-3.1, -H + 0.6), -1.25, 1.1); pose(modele('DoorGate_Wooden_Right'), ...W(3.1, -H + 0.6), 1.25, 1.1);
  { const e = enseigne('VALCOURT', '#ffd870'); pose(e, ...W(9.5, -H - 6), 0, 1.4); }
  lieux.porte = W(0, -H + 4); lieux.dehors = W(0, -H - 22);
  // ---- lanternes à chaque carrefour ----
  for (const [x, z] of N) { if (z < -H) continue; for (const [ox, oz] of [[4.4, 4.4], [-4.4, -4.4]]) { const g = new THREE.Group(), p0 = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.12, 2.8, 6), MAT_POTEAU); p0.position.y = 1.4; g.add(p0); const tq = prop('Torch_Metal'); tq.position.set(0, 1.9, -0.15); g.add(tq); pose(g, ...W(x + ox, z + oz), Math.atan2(-ox, -oz)); } }
  // ---- place du marché : fontaine-puits, 8 étals, charrette, caisses ----
  const P = CP.place, [mx, mz] = W(0, P.z); pose(modele('well_01'), mx, mz, 0, 1.5); blocs.push({ x: mx, z: mz, r: 1.7 }); lieux.place = [mx, mz];
  Vg.etals = []; for (let k = 0; k < 8; k++) { const a = k / 8 * 6.2832 + Math.PI / 8, x = mx + Math.sin(a) * 9.5, z = mz + Math.cos(a) * 9.5, r = a + Math.PI; pose(modele('stall_01'), x, z, r, 1.25); blocs.push({ x, z, r: 1.2 }); Vg.etals.push({ x: x + Math.sin(a) * 1.3, z: z + Math.cos(a) * 1.3, regard: r, client: [x - Math.sin(a) * 2.1, z - Math.cos(a) * 2.1], vers: a }); }
  pose(modele('Prop_Wagon'), mx + 7, mz + 13, 0.4, 1); pose(prop('Crate_Wooden'), mx - 6, mz + 12.5, 0.3, 0.9); pose(modele('Barrel_Closed'), mx - 7, mz + 12, 0, 1);
  // ---- maisons et boutiques le long des rues (portes sur la rue) ----
  const boutiques = [ // [nom, enseigne, plan, niveau, quartier (x,z) visé, décor]
    ['forge1', 'FORGE', 'forge', 3, [-30, -34]], ['forge2', 'ARMURERIE', 'forge', 2, [-50, -12]], ['boucher', 'BOUCHERIE', 'maison', 2, [-30, -12]],
    ['boulanger', 'BOULANGERIE', 'maison', 2, [30, -12]], ['taverne', 'TAVERNE DU SANGLIER', 'maison', 3, [30, 10]], ['sorciere', 'HERBES & POTIONS', 'maison', 1, [-50, 10]],
    ['scierie', 'SCIERIE', 'scierie', 2, [-30, 10]], ['tailleur', 'TAILLEUR', 'maison', 2, [30, -34]],
  ];
  const libre = (x, z) => !bloqueHumain(x, z) && Math.hypot(x, z - P.z) > P.r + 4.5 && !(z > CP.zMax - 6 && Math.abs(x) < 24) && Math.abs(x) < H - 6 && Math.abs(z) < H - 6;
  const emplacements = [];
  for (const [a, vs] of A) for (const b of vs) { if (b < a) continue; const [ax, az] = N[a], [bx, bz] = N[b]; if (az < -H || bz < -H) continue; const L = Math.hypot(bx - ax, bz - az), dx = (bx - ax) / L, dz = (bz - az) / L;
    for (let t = 7.5; t < L - 7; t += 8.2) for (const s of [-1, 1]) { const px = ax + dx * t + dz * s * 8.2, pz = az + dz * t - dx * s * 8.2; emplacements.push({ x: px, z: pz, r: Math.atan2(-dz * s, dx * s), rue: [ax + dx * t, az + dz * t] }); } }
  let ib = 0;
  for (const E of emplacements.sort((a, b) => Math.hypot(a.x, a.z) - Math.hypot(b.x, b.z))) {
    if (!libre(E.x, E.z) || maisons.some(m => Math.hypot(m.lx - E.x, m.lz - E.z) < 7.6)) continue;
    let bt = null; for (const B of boutiques) if (!B.pris && Math.hypot(E.x - B[4][0], E.z - B[4][1]) < 14) { bt = B; B.pris = true; break; }
    const noble = E.z > 12 && Math.abs(E.x) < 40, type = bt ? bt[2] : 'maison', niv = bt ? bt[3] : noble ? 3 : (ib % 3 === 0 ? 1 : 2);
    const [x, z] = W(E.x, E.z); pose(plan3D(type, niv), x, z, E.r); blocs.push({ x, z, r: 3.3 });
    const fx = Math.sin(E.r), fz = Math.cos(E.r), px = x + fx * 3.8 - fz * 1.3, pz = z + fz * 3.8 + fx * 1.3;
    const M = { lx: E.x, lz: E.z, x, z, porte: [px, pz], r: E.r, boutique: bt && bt[0] }; maisons.push(M); if (bt) lieux[bt[0]] = M;
    if (bt) { pose(enseigne(bt[1], bt[0] === 'sorciere' ? '#c8a8ff' : '#e8d8b0'), x + fx * 4.4 + fz * 2.6, z + fz * 4.4 - fx * 2.6, E.r, 1); }
    // devant chaque maison, un détail
    if (bt && /forge/.test(bt[0])) { pose(prop('Anvil'), x + fx * 4.6 - fz * 2.4, z + fz * 4.6 + fx * 2.4, E.r, 1.1); pose(prop('WeaponStand'), x + fx * 3.8 + fz * 4.2, z + fz * 3.8 - fx * 4.2, E.r, 0.9); M.poste = [x + fx * 5.6 - fz * 2.4, z + fz * 5.6 + fx * 2.4]; }
    else if (bt && bt[0] === 'boucher') { pose(modele('stall_01'), x + fx * 5 + fz * 2.5, z + fz * 5 - fx * 2.5, E.r + Math.PI, 1.1); pose(modele('Barrel_Closed'), x + fx * 4 - fz * 2.8, z + fz * 4 + fx * 2.8, 0, 1); M.poste = [x + fx * 6.2 + fz * 2.5, z + fz * 6.2 - fx * 2.5]; }
    else if (bt && bt[0] === 'boulanger') { pose(modele('stall_01'), x + fx * 5 + fz * 2.5, z + fz * 5 - fx * 2.5, E.r + Math.PI, 1.1); pose(prop('Crate_Wooden'), x + fx * 4 - fz * 2.8, z + fz * 4 + fx * 2.8, 0.3, 0.8); M.poste = [x + fx * 6.2 + fz * 2.5, z + fz * 6.2 - fx * 2.5]; }
    else if (bt && bt[0] === 'taverne') { for (let k = 0; k < 2; k++) { pose(modele('Table_Small'), x + fx * 5.2 + fz * (k * 3 - 1.5), z + fz * 5.2 - fx * (k * 3 - 1.5), E.r, 1.3); pose(modele('Bench'), x + fx * 6.2 + fz * (k * 3 - 1.5), z + fz * 6.2 - fx * (k * 3 - 1.5), E.r + Math.PI / 2, 1); } M.poste = [x + fx * 6.6, z + fz * 6.6]; }
    else if (bt && bt[0] === 'sorciere') { pose(prop('Cauldron'), x + fx * 4.8 + fz * 2.2, z + fz * 4.8 - fx * 2.2, 0, 1.2); Vg.chaudron = V(x + fx * 4.8 + fz * 2.2, y0 + 0.9, z + fz * 4.8 - fx * 2.2); M.poste = [x + fx * 5.8 + fz * 2.2, z + fz * 5.8 - fx * 2.2]; }
    else if (bt && bt[0] === 'scierie') M.poste = [x + fx * 5.4, z + fz * 5.4];
    else if (bt) M.poste = [x + fx * 5, z + fz * 5];
    else if (ib % 3 === 0) pose(modele('Bench'), x + fx * 3.6 + fz * 2.2, z + fz * 3.6 - fx * 2.2, E.r + Math.PI / 2, 0.85);
    else if (ib % 3 === 1) pose(modele('Barrel_Closed'), x + fx * 3.4 + fz * 2.4, z + fz * 3.4 - fx * 2.4, 0, 0.9);
    ib++;
  }
  // ---- palais ----
  const PK = 1.55, [px0, pz0] = W(0, CP.zMax + 12), demiW = 3 * PK, demiD = 4 * PK;
  const spec = maison({ w: 3, d: 4, sol: 'Floor_Brick', coins: 'Corner_Exterior_Brick', etages: [{ m: 'brique', n: 'pop', w: 'pfpf', e: 'fpfp', s: 'ppp' }, { m: 'brique', n: 'fpf', w: 'fpfp', e: 'pfpf', s: 'pfp' }], toit: 'Roof_RoundTiles_6x8', extras: [] });
  const palais = new THREE.Group(), palaisHaut = new THREE.Group(); palais.position.set(px0, y0 + 0.9, pz0); palaisHaut.position.copy(palais.position); palais.scale.setScalar(PK); palaisHaut.scale.setScalar(PK);
  for (const d of spec) { const o = piece(d); o.position.set(d.x, d.y, d.z); o.rotation.y = d.r; o.scale.setScalar(d.e); (d.y > HE * 0.5 || /Roof/.test(d.n) ? palaisHaut : palais).add(o); }
  brut.add(palais); haut.add(palaisHaut);
  const est = new THREE.Mesh(new THREE.BoxGeometry(demiW * 2 + 8, 0.9, demiD * 2 + 5), MAT_DALLE); est.position.set(px0, y0 + 0.45, pz0); brut.add(est);
  for (const s of [-1, 0, 1]) pose(modele('Stairs_Exterior_Straight'), px0 + s * 2, pz0 - demiD - 3.6, Math.PI, 1, 0);
  for (const s of [-1, 1]) { tour(pose, px0 + s * (demiW + 2), pz0 - demiD + 0.5, 4); pose(modele('Banner'), px0 + s * 2.6, pz0 - demiD - 0.25, Math.PI, 1, 0.9 + 6.2); }
  for (let t = -demiW; t <= demiW; t += 1.4) { if (Math.abs(t) > 1.8) blocs.push({ x: px0 + t, z: pz0 - demiD, r: 0.8 }); blocs.push({ x: px0 + t, z: pz0 + demiD, r: 0.8 }); }
  for (let t = -demiD; t <= demiD; t += 1.4) { blocs.push({ x: px0 - demiW, z: pz0 + t, r: 0.8 }); blocs.push({ x: px0 + demiW, z: pz0 + t, r: 0.8 }); }
  const sol = y0 + 0.92;
  for (let z = pz0 - demiD + 1.6; z < pz0 + demiD - 2; z += 3) { const c = modele('Carpet_Red'); c.position.set(px0, sol, z); c.rotation.y = Math.PI / 2; c.scale.set(0.5, 1, 0.6); brut.add(c); }
  for (const s of [-1, 1]) for (const z of [-3, 1, 5]) { const c = modele('Pillar'); c.position.set(px0 + s * 3, sol, pz0 + z); c.scale.setScalar(1.3); brut.add(c); blocs.push({ x: px0 + s * 3, z: pz0 + z, r: 0.6 }); }
  const estr = new THREE.Mesh(new THREE.BoxGeometry(4, 0.5, 2.6), MAT_DALLE); estr.position.set(px0, sol + 0.25, pz0 + demiD - 1.8); brut.add(estr);
  const trone = modele('Throne'); trone.position.set(px0, sol + 0.5, pz0 + demiD - 1.6); trone.rotation.y = Math.PI; trone.scale.setScalar(1.25); brut.add(trone); blocs.push({ x: px0, z: pz0 + demiD - 1.5, r: 0.9 });
  for (const s of [-1, 1]) { const b = modele('Banner'); b.position.set(px0 + s * 2.6, sol + 6.5, pz0 + demiD - 0.4); b.rotation.y = Math.PI; b.scale.setScalar(1.2); brut.add(b); const t = modele('Torch_Wall'); t.position.set(px0 + s * (demiW - 0.35), sol + 2.6, pz0 + 1); t.rotation.y = s > 0 ? -Math.PI / 2 : Math.PI / 2; brut.add(t); }
  for (const z of [-2, 3]) { const l = modele('Chandelier'); l.position.set(px0, sol + 8.4, pz0 + z); l.scale.setScalar(1.2); haut.add(l); }
  Vg.palais = { x: px0, z: pz0, w: demiW, d: demiD, sol, trone: V(px0, sol + 1.05, pz0 + demiD - 1.75) };
  // ---- jardins du quartier noble : haies basses et arbres en bac ----
  for (const s of [-1, 1]) { const [x, z] = W(s * 16, CP.zMax + 10); const h = new THREE.Mesh(new THREE.BoxGeometry(9, 0.8, 0.8), MAT_HAIE); h.position.set(x, y0 + 0.4, z - 5); brut.add(h); const h2 = h.clone(); h2.position.z = z + 5; brut.add(h2); for (const ox of [-3, 0, 3]) { const a = new THREE.Mesh(new THREE.IcosahedronGeometry(1.2, 0), MAT_HAIE); a.position.set(x + ox, y0 + 2.2, z); a.scale.y = 1.4; brut.add(a); const tr = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.16, 1.6, 6), MAT_POTEAU); tr.position.set(x + ox, y0 + 0.8, z); brut.add(tr); } }
  // ---- feu de camp des gardes, champs et vergers hors les murs ----
  { const [x, z] = W(-9, -H + 7); pose(modele('fire_01'), x, z, 0, 1.2); Vg.feu = V(x, y0, z); lieux.feu = [x + 1.5, z]; }
  for (const s of [-1, 1]) for (const k of [0, 1]) { const [x, z] = W(s * (22 + k * 16), -H - 18); brut.add(champ(x, z, 0, 12, 10, k === 0)); }
  lieux.champs = [W(-22, -H - 18), W(22, -H - 18), W(-38, -H - 18), W(38, -H - 18)];
  const g = new THREE.Group(); fusionner(brut, g); const gh = new THREE.Group(); fusionner(haut, gh); g.add(gh); Vg.palais.haut = gh; G.scene.add(g); Vg.g = g;
  Vg.spots = Vg.etals.map(e => ({ x: e.client[0], z: e.client[1], anim: 'Idle_Talking_Loop', dur: [6, 14], regard: e.vers }));
  Vg.portes = maisons.map(m => V(m.porte[0], 0, m.porte[1]));
}
const MAT_HAIE = new THREE.MeshStandardMaterial({ color: '#3f7a32', roughness: 0.95, flatShading: true });

// ================= la population =================
// chaque habitant a un « cerveau » : une suite d'envies (aller quelque part par les rues, y faire quelque chose)
function suivre(h, dt, vit, anim) { // avance le long de h.route ; true à l'arrivée
  if (!h.route || h.ri >= h.route.length) return true;
  const [x, z] = h.route[h.ri]; if (h.aller(V(x, 0, z), dt, vit, anim)) h.ri++; return h.ri >= h.route.length;
}
function partir(h, vers, cote = h.cote) { h.route = trottoir(chemin([h.pos.x - h.v.x, h.pos.z - h.v.z], [vers[0] - h.v.x, vers[1] - h.v.z]), cote).map(([x, z]) => [x + h.v.x, z + h.v.z]); h.ri = 1; }
function occuper(h, anim, duree, regard) { h.occ = duree; h.m.jouer(anim, { forcer: true, vitesse: rnd(0.85, 1.1) }); h.regardOcc = regard; }

const ROLES = {
  // la ménagère : de chez elle au marché ou chez un commerçant, discute, rentre les bras chargés
  menagere(h, dt) {
    if (h.occ > 0) { h.occ -= dt; if (h.regardOcc != null) h.tourner(h.regardOcc, dt); return; }
    if (h.etape === 'aller') { if (suivre(h, dt, h.vit, h.charge ? 'Walk_Carry_Loop' : 'Walk_Loop')) { h.etape = 'fait'; occuper(h, h.but.anim, rnd(...h.but.dur), h.but.regard); } return; }
    const L = h.v.lieux, E = h.v.etals;
    if (h.etape === 'fait' && h.but.retour) { h.charge = false; h.etape = null; occuper(h, 'Idle_Loop', rnd(8, 20)); h.m.root.visible = true; return; }
    const r = Math.random(), e = pick(E), cible = h.etape === 'fait' ? { x: h.maison.porte[0], z: h.maison.porte[1], anim: 'Interact', dur: [2, 3], regard: h.maison.r + Math.PI, retour: true }
      : r < 0.6 ? { x: e.client[0], z: e.client[1], anim: 'Idle_Talking_Loop', dur: [6, 14], regard: e.vers + Math.PI }
      : r < 0.8 && L.boulanger ? { x: L.boulanger.poste[0], z: L.boulanger.poste[1], anim: 'PickUp_Table', dur: [4, 8], regard: L.boulanger.r + Math.PI }
      : L.boucher ? { x: L.boucher.poste[0], z: L.boucher.poste[1], anim: 'Idle_Talking_Loop', dur: [5, 10], regard: L.boucher.r + Math.PI } : { x: e.client[0], z: e.client[1], anim: 'Idle_Talking_Loop', dur: [6, 12], regard: 0 };
    if (h.etape === 'fait') h.charge = true; h.but = cible; partir(h, [cible.x, cible.z]); h.etape = 'aller';
  },
  // l'ouvrier : de chez lui à son atelier (forge, scierie, champs), travaille longtemps, passe à la taverne, rentre
  ouvrier(h, dt) {
    if (h.occ > 0) { h.occ -= dt; if (h.regardOcc != null) h.tourner(h.regardOcc, dt); if (h.metier === 'forge' && h.occ > 0 && Math.random() < dt * 0.6) emettre(tmp(h.pos.x + Math.sin(h.m.root.rotation.y) * 0.8, h.pos.y + 0.9, h.pos.z + Math.cos(h.m.root.rotation.y) * 0.8), { n: 6, c1: '#ffd27a', c2: '#ff5a0a', vit: 2.5, vie: 0.3, taille: 0.1, grav: 6 }); return; }
    if (h.etape === 'aller') { if (suivre(h, dt, h.vit * 1.1, 'Walk_Loop')) { h.etape = 'fait'; occuper(h, h.but.anim, rnd(...h.but.dur), h.but.regard); } return; }
    const L = h.v.lieux, seq = h.seq ??= 0; h.seq = (seq + 1) % 3;
    const travail = h.atelier, cible = seq === 0 ? travail : seq === 1 && L.taverne ? { x: L.taverne.poste[0] + rnd(-1.5, 1.5), z: L.taverne.poste[1] + rnd(-1, 1), anim: 'Idle_Talking_Loop', dur: [10, 20], regard: L.taverne.r + Math.PI } : { x: h.maison.porte[0], z: h.maison.porte[1], anim: 'Interact', dur: [2, 4], regard: h.maison.r + Math.PI };
    h.but = cible; partir(h, [cible.x, cible.z]); h.etape = 'aller';
  },
  // l'enfant : court partout autour de la place, joue à chat avec un autre
  enfant(h, dt) {
    if (h.occ > 0) { h.occ -= dt; return; }
    const autre = h.copain; let cible;
    if (h.chat && autre) { cible = autre.pos; if (Math.hypot(cible.x - h.pos.x, cible.z - h.pos.z) < 0.9) { h.chat = false; autre.chat = true; autre.occ = 0.6; texteFlottant(tmp(h.pos.x, h.pos.y + 1.5, h.pos.z), pick(['Touché !', 'Chat !', 'À toi !']), 'info'); occuper(h, 'Yes', 0.8); return; } }
    else { if (!h.fuite || Math.hypot(h.fuite.x - h.pos.x, h.fuite.z - h.pos.z) < 0.6) { const [px, pz] = h.v.lieux.place, a = rnd(0, 6.28), r = rnd(5, 20); h.fuite = V(px + Math.sin(a) * r, 0, pz + Math.cos(a) * r); if (bloqueHumain(h.fuite.x, h.fuite.z)) h.fuite = V(px + Math.sin(a) * 4, 0, pz + Math.cos(a) * 4); } cible = h.fuite; }
    h.aller(cible, dt, h.chat ? 4.4 : 3.9, 'Sprint_Loop');
  },
  // le garde en patrouille : boucle de carrefours, au centre de la rue, pas réglementaire
  patrouille(h, dt) {
    if (h.occ > 0) { h.occ -= dt; return; }
    if (h.route && h.ri < h.route.length) { suivre(h, dt, 1.25, 'Walk_Loop'); return; }
    h.boucle = (h.boucle ?? 0) + 1; const [x, z] = h.tournee[h.boucle % h.tournee.length]; partir(h, [x, z], 0); occuper(h, 'Sword_Idle', h.boucle % 3 ? 0.1 : 3);
  },
  // sentinelle du rempart : marche sur le chemin de ronde
  ronde(h, dt) { const b = h.ronde[h.pi]; h.pos.y = h.yFixe; const dx = b.x - h.pos.x, dz = b.z - h.pos.z, d = Math.hypot(dx, dz); if (d < 0.3) { h.pi = 1 - h.pi; return; } const p = Math.min(d, 1.1 * dt); h.pos.x += dx / d * p; h.pos.z += dz / d * p; h.tourner(Math.atan2(dx, dz), dt); h.m.jouer('Walk_Loop', { vitesse: 0.7 }); },
  // la caravane : arrive de la route avec sa charrette, s'installe au marché, repart
  caravane(h, dt) {
    if (h.occ > 0) { h.occ -= dt; if (h.regardOcc != null) h.tourner(h.regardOcc, dt); return; }
    const L = h.v.lieux; h.charrette.position.set(h.pos.x + Math.sin(h.m.root.rotation.y) * 1.7, h.pos.y, h.pos.z + Math.cos(h.m.root.rotation.y) * 1.7); h.charrette.rotation.y = h.m.root.rotation.y + Math.PI / 2;
    if (h.etape === 'aller') { if (suivre(h, dt, 1.2, 'Walk_Carry_Loop')) { h.etape = h.but.suite; occuper(h, h.but.anim, rnd(...h.but.dur), h.but.regard); if (h.but.suite === 'sortie') { h.m.root.visible = false; h.charrette.visible = false; } } return; }
    if (h.etape === 'sortie') { h.m.root.visible = true; h.charrette.visible = true; h.etape = null; return; }
    const e = pick(h.v.etals), cible = !h.dedans ? { x: e.client[0] + Math.sin(e.vers) * -1.5, z: e.client[1] + Math.cos(e.vers) * -1.5, anim: 'Idle_Talking_Loop', dur: [18, 30], regard: e.vers + Math.PI, suite: null } : { x: L.dehors[0] + rnd(-2, 2), z: L.dehors[1] - 25, anim: 'Idle_Loop', dur: [20, 40], suite: 'sortie' };
    h.dedans = !h.dedans; h.but = cible; partir(h, [cible.x, cible.z], 0); h.etape = 'aller';
  },
  // flâneur : va d'un banc, d'un étal ou d'une place à l'autre
  flaneur(h, dt) {
    if (h.occ > 0) { h.occ -= dt; if (h.regardOcc != null) h.tourner(h.regardOcc, dt); return; }
    if (h.etape === 'aller') { if (suivre(h, dt, h.vit * 0.9, 'Walk_Loop')) { h.etape = null; occuper(h, h.but.anim, rnd(...h.but.dur), h.but.regard); } return; }
    const m = pick(h.v.maisons), e = pick(h.v.etals), r = Math.random(), L = h.v.lieux;
    h.but = r < 0.4 ? { x: e.client[0], z: e.client[1], anim: 'Idle_Talking_Loop', dur: [6, 12], regard: e.vers + Math.PI } : r < 0.6 && L.feu ? { x: L.feu[0], z: L.feu[1], anim: 'Idle_Talking_Loop', dur: [8, 16], regard: -Math.PI / 2 } : { x: m.porte[0], z: m.porte[1], anim: pick(['Interact', 'Idle_FoldArms_Loop']), dur: [3, 8], regard: m.r + Math.PI };
    partir(h, [h.but.x, h.but.z]); h.etape = 'aller';
  },
};
// PNJ nommés : ils resteront dans l'aventure (quêtes à venir)
const NOMMES = [
  { nom: 'Bram', titre: 'Maître-forgeron', lieu: 'forge1', sexe: 'h', couleur: '#5a3a2a', anim: 'Fixing_Kneeling', ligne: '« Une lame d’ombre ? Apporte-moi du minerai rare et on en reparle. »' },
  { nom: 'Gaspard', titre: 'Boucher', lieu: 'boucher', sexe: 'h', couleur: '#a03a3a', anim: 'PickUp_Table', ligne: '« Les loups rôdent près des fermes. Personne n’ose sortir la nuit. »' },
  { nom: 'Margot', titre: 'Tavernière', lieu: 'taverne', sexe: 'f', couleur: '#8a5a2a', anim: 'Idle_Talking_Loop', ligne: '« Une chope ? Les rumeurs, c’est gratuit : on parle d’une tour au nord… »' },
  { nom: 'Morwenna', titre: 'Sorcière', lieu: 'sorciere', sexe: 'f', couleur: '#3a2a5a', anim: 'Spell_Simple_Idle_Loop', ligne: '« Tes ombres… je les sens d’ici. Reviens me voir quand tu voudras savoir d’où elles viennent. »' },
  { nom: 'Capitaine Roderic', titre: 'Garde de Valcourt', lieu: 'porte', sexe: 'h', couleur: '#2a4a8a', anim: 'Sword_Idle', garde: true, ligne: '« Halte. Le roi t’attend au palais, Souverain. Et pas de grabuge en ville. »' },
  { nom: 'Fennick', titre: 'Marchand ambulant', lieu: 'place', sexe: 'h', couleur: '#3a7a5a', anim: 'Idle_Talking_Loop', ligne: '« Des marchandises d’au-delà des montagnes ! Bientôt, très bientôt… »' },
];
export function peuplerCapitale(Vg, C) {
  const L = Vg.lieux, M = Vg.maisons.filter(m => !m.boutique), y0 = hauteur(Vg.x, Vg.z), n = (f) => { const h = new Villageois(Vg, ...f); return h; };
  const naitre = (opts, cerveau, x, z) => { const h = new Villageois(Vg, x, z, opts); h.cerveau = cerveau; h.cote = pick([-2.8, 2.8]); h.vit = rnd(1.1, 1.45); return h; };
  // ménagères et ouvriers : chacun a sa maison
  for (let i = 0; i < 9; i++) { const m = M[i % M.length], h = naitre({ sexe: 'f' }, ROLES.menagere, m.porte[0], m.porte[1]); h.maison = m; h.occ = rnd(0, 6); }
  const ateliers = [['forge', L.forge1], ['forge', L.forge2], ['bois', L.scierie], ['boucher', L.boucher], ['champ'], ['champ'], ['champ'], ['forge', L.forge1]];
  ateliers.forEach(([metier, lieu], i) => { const m = M[(i + 9) % M.length], h = naitre({ sexe: 'h' }, ROLES.ouvrier, m.porte[0], m.porte[1]); h.maison = m; h.metier = metier; h.occ = rnd(0, 8);
    const [cx, cz] = metier === 'champ' ? pick(L.champs) : lieu ? lieu.poste : L.place; h.atelier = { x: cx + rnd(-1.5, 1.5), z: cz + rnd(-1.5, 1.5), anim: metier === 'forge' ? 'Fixing_Kneeling' : metier === 'champ' ? 'Farm_Harvest' : metier === 'bois' ? 'TreeChopping_Loop' : 'PickUp_Table', dur: [25, 50], regard: lieu ? lieu.r + Math.PI : 0 }; });
  // enfants qui jouent à chat (par paires)
  for (let i = 0; i < 6; i += 2) { const [px, pz] = L.place, a = naitre({ enfant: true }, ROLES.enfant, px + rnd(-6, 6), pz + rnd(6, 12)), b = naitre({ enfant: true }, ROLES.enfant, px + rnd(-6, 6), pz + rnd(6, 12)); a.copain = b; b.copain = a; a.chat = true; }
  // flâneurs
  for (let i = 0; i < 6; i++) { const m = pick(Vg.maisons); naitre({}, ROLES.flaneur, m.porte[0], m.porte[1]); }
  // marchands derrière les étals (ils crient)
  for (const e of Vg.etals) { const m = new Villageois(Vg, e.x, e.z, { marchand: true }); m.regard = e.regard; m.m.root.rotation.y = e.regard; }
  // gardes : porte (4), patrouilles dans les rues (3 binômes), sentinelles sur les remparts (6), garde royale (4)
  const gard = (x, z, r) => { const g = new Villageois(Vg, x, z, { garde: true }); g.regard = r; g.m.root.rotation.y = r; return g; };
  for (const s of [-1, 1]) { gard(Vg.x + s * 3, Vg.z - CP.H - 3, Math.PI); gard(Vg.x + s * 3, Vg.z - CP.H + 4, 0); }
  const tours = [[[-30, -34], [30, -34], [30, 10], [-30, 10]], [[0, -48], [0, -12], [-50, -12], [-30, -34]], [[0, 10], [50, 10], [50, -34], [0, -34]]];
  tours.forEach((T, k) => { for (const o of [0, 1.4]) { const [x, z] = T[0], g = naitre({ garde: true }, ROLES.patrouille, Vg.x + x + o, Vg.z + z); g.tournee = T.map(([a, b]) => [Vg.x + a + o, Vg.z + b]); g.boucle = k; } });
  const hm = 2 * HE * K + 0.02, H = CP.H - 1.5;
  for (const [a, b] of [[[-H, -H + 6], [-H, H - 6]], [[H, -H + 6], [H, H - 6]], [[-H + 6, H], [H - 6, H]], [[-H + 8, -H], [-12, -H]], [[12, -H], [H - 8, -H]], [[-H + 6, H], [-6, H]]]) { const h = naitre({ garde: true }, ROLES.ronde, Vg.x + a[0], Vg.z + a[1]); h.yFixe = y0 + hm; h.ronde = [V(Vg.x + a[0], 0, Vg.z + a[1]), V(Vg.x + b[0], 0, Vg.z + b[1])]; h.pi = 1; h.m.portee = 70; }
  const P = Vg.palais; for (const s of [-1, 1]) { gard(P.x + s * 2.4, P.z - P.d - 4.2, Math.PI); gard(P.x + s * 1.9, P.z + P.d - 2.2, Math.PI); }
  // le roi
  const roi = new Villageois(Vg, P.trone.x, P.trone.z, { roi: true }); roi.m.root.position.y = P.trone.y - 0.55; roi.m.root.rotation.y = Math.PI; roi.m.jouer('Sitting_Idle_Loop', { forcer: true }); Vg.roi = roi;
  const cour = new THREE.Group(), base = new THREE.Mesh(new THREE.CylinderGeometry(0.13, 0.12, 0.09, 10, 1, true), MAT_OR); cour.add(base); for (let i = 0; i < 6; i++) { const p = new THREE.Mesh(new THREE.ConeGeometry(0.03, 0.08, 4), MAT_OR); const a = i / 6 * 6.28; p.position.set(Math.sin(a) * 0.12, 0.08, Math.cos(a) * 0.12); cour.add(p); } cour.position.y = 0.2; roi.m.tenir(cour, 'Head'); roi.m.root.add(etiquette('Roi Aldric', 'Souverain de Valcourt'));
  // caravanes de marchands qui entrent et sortent par la grande porte
  for (let i = 0; i < 3; i++) { const h = naitre({}, ROLES.caravane, L.dehors[0] + rnd(-2, 2), L.dehors[1] - 20 - i * 12); h.charrette = modele('Prop_Wagon'); h.charrette.scale.setScalar(0.85); G.scene.add(h.charrette); h.occ = i * 25; h.dedans = false; h.m.portee = 70; }
  // PNJ nommés
  for (const P2 of NOMMES) { const lieu = P2.lieu === 'porte' ? { poste: [Vg.x - 6, Vg.z - CP.H + 6], r: 0 } : P2.lieu === 'place' ? { poste: [L.place[0] + 4, L.place[1] + 5], r: Math.PI } : L[P2.lieu]; if (!lieu) continue;
    const h = new Villageois(Vg, lieu.poste[0], lieu.poste[1], { garde: !!P2.garde, nomme: P2 }); h.regard = lieu.r + Math.PI; h.m.root.rotation.y = h.regard; h.m.jouer(P2.anim, { forcer: true }); h.m.root.add(etiquette(P2.nom, P2.titre)); h.nomme = P2;
    h.cerveau = (h, dt) => { h.tourner(h.regard, dt); const d = Math.hypot(C.joueur.pos.x - h.pos.x, C.joueur.pos.z - h.pos.z); if (d < 3.5 && !(h.parleT > 0)) { h.parleT = 45; C.toast(`${P2.nom} : ${P2.ligne}`); h.m.jouer('Idle_Talking_Loop', { forcer: true }); setTimeout(() => h.m.jouer(P2.anim, { forcer: true }), 4000); } if (h.parleT > 0) h.parleT -= dt; if (P2.lieu === 'sorciere' && Math.random() < dt * 8 && h.v.chaudron) emettre(tmp(h.v.chaudron.x + rnd(-0.3, 0.3), h.v.chaudron.y + 0.3, h.v.chaudron.z + rnd(-0.3, 0.3)), { n: 1, c1: '#c8a8ff', c2: '#4a1a8a', vit: 0.5, vie: 1, taille: 0.3, grav: -1.5 }); };
  }
}
