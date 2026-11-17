// ======================= VILLE VIVANTE II : repère du raid, cimetière, portails à refermer =======================
function directionDe(p) { // relatif à l'écran du joueur : plus clair qu'une boussole
  try { const a = p.clone().setY(0).project(G.camera), b = (joueur ? joueur.pos.clone() : V()).setY(0).project(G.camera); const ang = Math.atan2(a.y - b.y, a.x - b.x) * 180 / Math.PI;
    return ['à droite de l’écran', 'en haut à droite', 'en haut de l’écran', 'en haut à gauche', 'à gauche de l’écran', 'en bas à gauche', 'en bas de l’écran', 'en bas à droite'][Math.round(((ang + 360) % 360) / 45) % 8]; } catch (e) { return 'près de la Place'; } }
function colonneLumiere(pos, couleur) {
  const m = new THREE.Mesh(new THREE.CylinderGeometry(0.7, 1.1, 40, 16, 1, true), new THREE.MeshBasicMaterial({ color: couleur, transparent: true, opacity: 0.35, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
  m.position.set(pos.x, 20, pos.z); G.scene.add(m); return m;
}
// ---- cimetière : chaque mort a sa tombe ----
let tombes = [];
function construireCimetiere() {
  for (const t of tombes) { G.scene.remove(t); UI.retirerPlaque(t.plq); } tombes = [];
  const v = etatVille(), morts = [...v.gens.filter(g => g.statut === 'mort' || g.statut === 'sacrifie'), ...compagnons().filter(c => c.statut === 'mort').map(c => ({ nom: c.nom, metier: 'compagnon d’armes', statut: 'mort' }))];
  if (!morts.length) return;
  const base = monde.cimetiere || (monde.cimetiere = pointLibrePres(V(-19, 0, 14), 0, 5, 2.5));
  const pierre = new THREE.MeshStandardMaterial({ color: '#7d7c86', roughness: 0.95 }), terre = new THREE.MeshStandardMaterial({ color: '#3a2a20', roughness: 1 });
  morts.slice(-18).forEach((g, k) => {
    const grp = new THREE.Group(), x = (k % 6) * 1.3 - 3.2, z = Math.floor(k / 6) * 1.6;
    const st = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.8, 0.16), pierre); st.position.y = 0.4; grp.add(st);
    const haut = new THREE.Mesh(new THREE.CylinderGeometry(0.35, 0.35, 0.16, 16, 1, false, 0, Math.PI), pierre); haut.rotation.set(Math.PI / 2, 0, Math.PI / 2); haut.position.y = 0.8; grp.add(haut);
    const tas = new THREE.Mesh(new THREE.BoxGeometry(0.8, 0.12, 1.2), terre); tas.position.set(0, 0.06, 0.7); grp.add(tas);
    grp.position.set(base.x + x, 0, base.z + z); grp.rotation.y = rnd(-0.08, 0.08); G.scene.add(grp);
    grp.pos = grp.position; grp.hauteurPlaque = 1.4; grp.plq = grp;
    UI.plaque(grp, { nom: '† ' + g.nom, guilde: g.statut === 'sacrifie' ? 'SACRIFIÉ·E PAR LA BRÈCHE' : (g.metier || '').toUpperCase(), classe: 'pnj', vie: false, lettre: false });
    tombes.push(grp);
  });
}
// ---- portails : un habitant vient te chercher ----
let portailV = null, prochainPortail = 0;
function ouvrirPortailVille() {
  let p, k = 0; do { const a = rnd(0, 6.28), r = rnd(16, 23); p = V(Math.sin(a) * r, 0, Math.cos(a) * r); } while (!libre(p.x, p.z, 1.2) && ++k < 30);
  const anneau = new THREE.Mesh(new THREE.TorusGeometry(1.6, 0.18, 10, 40), new THREE.MeshBasicMaterial({ color: '#ff2a3a', blending: THREE.AdditiveBlending, transparent: true }));
  anneau.position.set(p.x, 1.9, p.z); G.scene.add(anneau);
  portailV = { pos: p, anneau, beam: colonneLumiere(p, '#ff2a3a'), spawnT: 4, ferme: 0, debut: G.t, vagues: 0 };
  effetArrivee(p.clone()); son('forceField_000', 0.7, 0.6);
  const msg = citoyens.filter(c => c.etat === 'flane').sort((a, b) => dist2D(a.pos, joueur.pos) - dist2D(b.pos, joueur.pos))[0];
  const ou = directionDe(p);
  if (msg) { msg.but = joueur.pos.clone(); UI.parole(msg, `Gardien ! Un portail vient de s’ouvrir ! Là-bas, ${ou} ! Vite !`, 'menace'); }
  UI.toast(`⚠ Un portail s’ouvre (${ou}) — suis la colonne rouge !`, true);
}
function majPortailVille(dt) {
  const P = portailV; if (!P) { if (!raidV && G.t > prochainPortail) { prochainPortail = G.t + rnd(300, 480); ouvrirPortailVille(); } return; }
  P.anneau.rotation.y += dt * 1.5; P.anneau.scale.setScalar(1 + Math.sin(G.t * 4) * 0.06);
  P.spawnT -= dt;
  if (P.spawnT <= 0 && pillards().length < 14) { // tant qu'il est ouvert, il crache des monstres (14 max sur la Place)
    P.spawnT = 14; P.vagues++; const ip = statsHeros(J.equip).ip, tier = Math.max(1, Math.min(8, (ip - 300) / 100 + 1)) * 0.9;
    for (let i = 0; i < 2 + Math.floor(P.vagues / 3); i++) { const q = pointLibrePres(P.pos, 0.5, 2.5); const e = creerEnnemi(MOBS[hasard(['minion', 'guerrier', 'cultiste'])], q, tier, 950); e.raidV = true; e.etat = 'chasse'; effetArrivee(q); }
  }
  if (dist2D(joueur.pos, P.pos) < 3.2 && !joueur.mort) {
    if (P.canal) { P.ferme += dt / 4; emettre(V(P.pos.x, 1.9, P.pos.z), { n: 2, c1: '#ffd0d0', c2: '#ff2a3a', vit: 2, vie: 0.5, taille: 0.25 }); }
    if (P.ferme >= 1) return fermerPortailVille();
  } else P.canal = false;
}
function fermerPortailVille() {
  const P = portailV; portailV = null;
  G.scene.remove(P.anneau); G.scene.remove(P.beam); emettre(V(P.pos.x, 1.9, P.pos.z), { n: 80, c1: '#ffffff', c2: '#ff2a3a', vit: 9, vie: 0.9, taille: 0.5 }); G.shake = 0.35; son('lowFrequency_explosion_000', 0.6, 1.2);
  const dur = Math.round(G.t - P.debut), gain = Math.max(200, 1200 - dur * 4);
  J.argent += gain; moralVille(dur < 60 ? 5 : 2); journalVille(`Tu as refermé un portail en ${dur} s.`);
  UI.toast(`Portail refermé ! +${fmtN(gain)} ¤`, true); sauver();
}
function viderPortailVille() { if (portailV) { G.scene.remove(portailV.anneau); G.scene.remove(portailV.beam); portailV = null; } for (const t of tombes) { G.scene.remove(t); UI.retirerPlaque(t); } tombes = []; }

