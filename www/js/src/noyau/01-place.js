// ---------------- Place publique ----------------
function creerMarchand() {
  const a = new Acteur('Barbarian', { hauteur: 2.1 });
  const tous = Object.keys(a.nodes).filter(n => /Axe|Shield|Mug/.test(n));
  a.montrerSeul(['Mug'], tous);
  a.root.position.copy(monde.marchand.pos); a.root.rotation.y = monde.marchand.rot;
  a.jouer('Idle'); G.scene.add(a.root);
  a.hauteurPlaque = 2.6; a.pos = a.root.position;
  UI.plaque(a, { nom: 'Borin', guilde: 'MARCHAND', classe: 'pnj', vie: false });
  marchand = a;
}
let graveuse = null;
function creerGraveuse() {
  const p = V(-4, 0, 15);
  const a = new Acteur('Mage', { hauteur: 2.05 });
  const tous = Object.keys(a.nodes).filter(n => /Staff|Wand|Spellbook/.test(n)); a.montrerSeul(['Spellbook_open'], tous);
  a.teinter('Mage_Cape', '#3a7aff', 0.75, 0.3); a.teinter('Mage_Hat', '#2a5acc', 0.7, 0.2); a.teinter('Mage_Body', '#4a6aaa', 0.5, 0);
  a.root.position.copy(p); a.root.rotation.y = Math.PI; a.pos = a.root.position; a.hauteurPlaque = 2.7;
  a.jouer('Idle'); G.scene.add(a.root);
  UI.plaque(a, { nom: 'Ysolde', guilde: 'GRAVEUSE DE RUNES', classe: 'pnj', vie: false });
  const cercle = new THREE.Mesh(new THREE.PlaneGeometry(6, 6), new THREE.MeshBasicMaterial({ map: texRunes('#5ab0ff'), transparent: true, opacity: 0.7, blending: THREE.AdditiveBlending, depthWrite: false }));
  cercle.rotation.x = -Math.PI / 2; cercle.position.set(p.x, 0.08, p.z); G.scene.add(cercle);
  const cristal = new THREE.Mesh(new THREE.OctahedronGeometry(0.45, 0), new THREE.MeshStandardMaterial({ color: '#9ad8ff', emissive: '#3a8aff', emissiveIntensity: 1.8, flatShading: true }));
  cristal.scale.set(1, 1.7, 1); G.scene.add(cristal);
  G.torches.push({ pos: V(p.x, 2.5, p.z), color: '#4a9aff', int: 30, dist: 12 });
  G.anims.push((t) => { cercle.rotation.z = t * 0.2; cristal.position.set(p.x + 1.4, 2.6 + Math.sin(t * 2) * 0.2, p.z); cristal.rotation.y = t; if (Math.random() < 0.15) emettre(V(p.x + rnd(-2, 2), 0.2, p.z + rnd(-2, 2)), { n: 1, c1: '#bfe6ff', c2: '#2a6aff', dir: V(0, 1, 0), vit: 1.5, vie: 1, taille: 0.25 }); });
  monde.collisions.push({ x: p.x, z: p.z, r: 0.8 });
  graveuse = a;
  a.decor = [cercle, cristal];
}
function enchanter(id) {
  const it = J.sac.find(i => i.id == id) || Object.values(J.equip).find(i => i && i.id == id); if (!it) return { ok: false };
  const c = coutEnchant(it); if (!c) return { ok: false, msg: 'Enchantement maximal' };
  const runes = API.nbRunes();
  if (runes < c.runes) { UI.toast(`Il te faut ${c.runes} runes (tu en as ${runes})`); son('error_001', 0.4); return { ok: false }; }
  if (J.argent < c.argent) { UI.toast('Pas assez d’argent'); son('error_001', 0.4); return { ok: false }; }
  J.argent -= c.argent; let reste = c.runes;
  for (const r of J.sac.filter(i => i.cat === 'butin' && i.type === 'rune')) { const pris = Math.min(reste, r.n || 1); r.n = (r.n || 1) - pris; reste -= pris; }
  J.sac = J.sac.filter(i => !(i.cat === 'butin' && i.type === 'rune' && (i.n || 0) <= 0));
  const reussi = Math.random() < c.chance;
  if (reussi) { it.ench = (it.ench || 0) + 1; son('jingle_legend', 0.55, 1.2); if (graveuse) { onde(graveuse.pos, '#5ab0ff', 5, 0.8); emettre(V(graveuse.pos.x, 1.6, graveuse.pos.z), { n: 80, c1: '#e0f4ff', c2: '#2a6aff', vit: 6, vie: 1.1, taille: 0.45, monte: 3 }); } }
  else { son('error_001', 0.6, 0.7); if (graveuse) emettre(V(graveuse.pos.x, 1.4, graveuse.pos.z), { n: 40, c1: '#888', c2: '#333', vit: 4, vie: 0.8, taille: 0.5 }); }
  if (Object.values(J.equip).includes(it)) { recalculer(); construireJoueur(); }
  sauver();
  return { ok: true, reussi, ench: it.ench || 0 };
}
function creerBots() {
  if (V1) { if (J) creerCitoyens(); return; }
  const n = 16;
  for (let i = 0; i < n; i++) {
    const [nom, tag, guilde] = BOTS[i % BOTS.length];
    const type = ['epee', 'arbalete', 'baton'][i % 3];
    const tier = 1 + Math.floor(Math.pow(Math.random(), 1.4) * 8);
    const equip = genererEquipRival(300 + (tier - 1) * 100 + rnd(-30, 60), type);
    const modele = type === 'arbalete' && i % 2 ? 'Rogue' : ARMES[type].model;
    const a = new Acteur(modele, { hauteur: 2.0 });
    habiller(a, equip, ARMES[type]);
    const niv = nivBot(equip);
    a.data = { nom, guilde: (tag ? `[${tag}] ` : '') + guilde, equip, modele, niv, ip: statsHeros(equip, niv).ip };
    let p; do { p = V(rnd(-24, 22), 0, rnd(-20, 20)); } while (!libre(p.x, p.z, 0.6));
    a.root.position.copy(p); a.root.rotation.y = rnd(0, 6.28);
    G.scene.add(a.root);
    Object.assign(a, { pos: a.root.position, nom, etat: 'idle', timer: rnd(0, 4), cible: null, vitesse: rnd(1.8, 2.6), hauteurPlaque: 2.55, angle: a.root.rotation.y });
    a.jouer(Math.random() < 0.25 ? 'Sit_Floor_Idle' : 'Idle');
    UI.plaque(a, { nom, guilde: a.data.guilde, classe: 'allie joueur', vie: false, ip: a.data.ip, niv: a.data.niv });
    bots.push(a);
  }
}
const DISCUSSIONS = ['t’as drop quoi ?', 'mdr', 'on fait la crypte ?', 'ce boss est cheat', 'je suis full T6 bientôt', 'grp donjon ?', 'gg hier', 'quelqu’un a un heal ?', 'non jsuis à court d’argent', 'trop bien ce stuff', 'j’arrive 2 min', 'on part en terres ancestrales ?', 'ouais', 'attends je vends', 'il est fort lui', 'ma guilde recrute', 'xD', 'jsuis mort 3 fois', 'go arène', 'regarde mon arme'];
const SALUTS_JOUEUR = ['salut {n} !', 'yo {n}', 'joli stuff {n}', '{n} tu viens en donjon ?', 'c’est toi {n} de CROW ZERO ?', 'wesh {n}', 'gg pour l’arène {n}'];
// un bot qui ne se rapproche plus de sa destination depuis 2,5 s abandonne (au lieu de glisser/gigoter sur place)
function coinceBot(b, d, dt) { if (b._dMin == null || d < b._dMin - 0.4) { b._dMin = d; b._coinceT = 0; return true; } b._coinceT = (b._coinceT || 0) + dt; if (b._coinceT > 2.5) { b._dMin = null; b._coinceT = 0; return false; } return true; }
function majBots(dt) {
  emoteHubT -= dt;
  if (emoteHubT <= 0) {
    emoteHubT = rnd(7, 16);
    const proches = bots.filter(b => !(b.absentT > 0) && !b.mort && b.root.visible !== false && (!joueur || dist2D(b.pos, joueur.pos) < 22));
    if (proches.length) emoteBot(hasard(proches), ['salut', 'mdr', 'feu', 'bof', 'malin', 'diable', 'clown', 'gg', 'toi'], 1);
  }
  for (const b of bots) {
    if (b.tk || b.mort) { b.maj(dt); continue; }
    b.timer -= dt;
    if (false) { // (ancien : le coéquipier suivait le joueur sur la place)
      const d = dist2D(b.pos, joueur.pos);
      if (d > 3.2) { const dir = V(joueur.pos.x - b.pos.x, 0, joueur.pos.z - b.pos.z).normalize(); const v = (d > 7 ? 6.5 : 4.6) * dt; deplacer(b, dir.x * v, dir.z * v, 0.5); b.angle = tourner(b.angle, Math.atan2(dir.x, dir.z), dt * 10); b.root.rotation.y = b.angle; b.jouer('Running_A'); }
      else { const c = b.courante ? b.courante.getClip().name : ''; if (c === 'Running_A' || c === 'Walking_A' || c === 'Sit_Floor_Idle') b.jouer('Idle'); }
      b.etat = 'idle'; b.timer = 2; b.maj(dt); continue;
    }
    if (majVieBot(b, dt)) { if (!b.mort && joueur && b.pos.distanceTo(joueur.pos) < 45) b.maj(dt); continue; }
    if (b.etat === 'idle' && b.timer <= 0 && Math.random() < 0.4) { const dst = destinationBot(b); if (dst) { b._dMin = null; b.but = dst; b.etat = 'but'; continue; } }
    if (b.etat === 'parle') { // en discussion : face au groupe, gestes, quelques phrases
      if (b.timer <= 0 || !b.cercle || b.cercle.fin < G.t) { b.etat = 'idle'; b.timer = rnd(0.5, 2); b.cercle = null; b.jouer('Idle'); }
      else { b.angle = tourner(b.angle, Math.atan2(b.cercle.x - b.pos.x, b.cercle.z - b.pos.z), dt * 6); b.root.rotation.y = b.angle;
        if (Math.random() < dt / 7) { b.jouer(Math.random() < 0.5 ? 'Interact' : 'Cheer', { boucle: false, fin: () => b.jouer('Idle') }); if (joueur && dist2D(b.pos, joueur.pos) < 18) UI.parole(b, hasard(DISCUSSIONS)); } }
    } else if (b.etat === 'idle' && b.timer <= 0) {
      const r = Math.random(); b.cercle = null; b.voirJoueur = false;
      const allerA = (p, course) => { b._dMin = null; b.cible = p; b.etat = 'marche'; b.course = course; b.jouer(course ? 'Running_A' : 'Walking_A'); };
      const pointLibre = () => { let p, n = 0; do { p = V(rnd(-26, 24), 0, rnd(-22, 22)); } while ((!libre(p.x, p.z, 0.6) || bots.some(o => o !== b && dist2D(o.pos, p) < 2.5)) && ++n < 25); return p; };
      if (r < 0.42) allerA(pointLibre(), Math.random() < 0.72); // les vrais joueurs courent presque tout le temps
      else if (r < 0.58) { // rejoindre ou lancer une discussion à 2-4
        const c = bots.find(o => o !== b && o.cercle && o.cercle.fin > G.t + 6 && o.cercle.n < 4 && dist2D(o.pos, b.pos) < 20);
        if (c) { const C = c.cercle; C.n++; const a = C.a0 + C.n * 6.283 / 4 + rnd(-0.3, 0.3); b.cercle = C; allerA(V(C.x + Math.cos(a) * 1.7, 0, C.z + Math.sin(a) * 1.7), dist2D(b.pos, C) > 6); }
        else { const p = pointLibre(); b.cercle = { x: p.x, z: p.z, a0: rnd(0, 6.283), n: 0, fin: G.t + rnd(18, 40) }; allerA(V(p.x + Math.cos(b.cercle.a0) * 1.7, 0, p.z + Math.sin(b.cercle.a0) * 1.7), Math.random() < 0.6); }
      }
      else if (r < 0.64 && joueur && dist2D(b.pos, joueur.pos) < 26) { const a = rnd(0, 6.283); b.voirJoueur = true; allerA(V(joueur.pos.x + Math.cos(a) * 3.2, 0, joueur.pos.z + Math.sin(a) * 3.2), true); }
      else if (r < 0.72) { b.jouer('Idle'); b.timer = rnd(20, 55); } // AFK, téléphone à la main
      else if (r < 0.8) { b.jouer('Sit_Floor_Idle'); b.timer = rnd(10, 25); }
      else if (r < 0.86) { b.jouer('Cheer', { boucle: false, fin: () => b.jouer('Idle') }); b.timer = rnd(3, 6); }
      else { b.jouer('Idle'); b.timer = rnd(2, 6); b.angle += rnd(-1.5, 1.5); b.root.rotation.y = b.angle; }
    } else if (b.etat === 'marche') {
      const d = dist2D(b.pos, b.cible);
      if (d < 0.5) {
        if (b.cercle) { b.etat = 'parle'; b.timer = b.cercle.fin - G.t; b.jouer('Idle'); continue; }
        if (b.voirJoueur && joueur) { b.voirJoueur = false; b.angle = Math.atan2(joueur.pos.x - b.pos.x, joueur.pos.z - b.pos.z); b.root.rotation.y = b.angle; b.jouer('Cheer', { boucle: false, fin: () => b.jouer('Idle') }); UI.parole(b, hasard(SALUTS_JOUEUR).replace('{n}', J.nom)); b.etat = 'idle'; b.timer = rnd(3, 7); continue; }
        b.etat = 'idle'; b.timer = Math.random() < 0.5 ? rnd(0.2, 1.5) : rnd(3, 8); b.jouer('Idle'); continue; }
      const dir = V(b.cible.x - b.pos.x, 0, b.cible.z - b.pos.z).normalize();
      const v = (b.course ? 4.8 : b.vitesse) * dt;
      if (!coinceBot(b, d, dt) || !deplacer(b, dir.x * v, dir.z * v, 0.5)) { b.etat = 'idle'; b.timer = rnd(0.5, 1.5); b.cercle = null; b.voirJoueur = false; b.jouer('Idle'); continue; }
      b.angle = tourner(b.angle, Math.atan2(dir.x, dir.z), dt * 8); b.root.rotation.y = b.angle;
    }
    if (b.pos.distanceTo(joueur ? joueur.pos : ORBITE) < 45) b.maj(dt);
  }
  if (bots.length && Math.random() < dt / 14) { const b = bots[Math.floor(Math.random() * bots.length)]; UI.chat(b.nom, CHAT[Math.floor(Math.random() * CHAT.length)]); }
}

// libère la mémoire GPU de la zone quittée (géométries/ textures propres à la zone) : sinon le jeu s'alourdit de partie en partie
let ressourcesAssets = null;
function libererGPU(racines) {
  if (!ressourcesAssets) {
    ressourcesAssets = new Set();
    for (const k in G.assets) { const s = G.assets[k] && G.assets[k].scene; if (s) s.traverse(o => { if (o.geometry) ressourcesAssets.add(o.geometry); const ms = o.material ? [].concat(o.material) : []; for (const mt of ms) for (const c of ['map', 'normalMap', 'emissiveMap']) if (mt[c]) ressourcesAssets.add(mt[c]); }); }
  }
  const vus = new Set();
  for (const r of racines) if (r) r.traverse(o => {
    if (o.isSkinnedMesh && o.skeleton && !vus.has(o.skeleton)) { vus.add(o.skeleton); o.skeleton.dispose(); }
    const g = o.geometry;
    if (g && !vus.has(g) && !ressourcesAssets.has(g) && !(g.userData && g.userData.partage)) { vus.add(g); g.dispose(); }
    const ms = o.material ? [].concat(o.material) : [];
    for (const mt of ms) for (const c of ['map', 'alphaMap']) { const t = mt[c]; if (t && t.isCanvasTexture && !vus.has(t) && !ressourcesAssets.has(t) && !t.userData.partage) { vus.add(t); t.dispose(); } }
  });
}
function viderMonde() {
  viderVille();
  if (demon) finDemon(null);
  document.body.classList.remove('brumeAnc'); document.body.classList.add('vign');
  for (const a of serviteurs) { G.scene.remove(a.root); UI.retirerPlaque(a); } serviteurs = [];
  G.solH = null; G.murs = false; G.ecrans = null; terres = null; TKS = []; possedes = []; UI.choixTK && UI.choixTK(null); G.camCible = null; G.camLibre = false; for (const v of auras.values()) G.scene.remove(v.g); auras.clear(); scenes = []; crypteEtat = null; if (sceneOmbre) { sceneOmbre = null; G.camCible = null; document.body.classList.remove('cinema'); UI.dialogueTaverne(null); }
  for (const e of ennemis) if (e.auraM && e.auraM.ring.parent) G.scene.remove(e.auraM.ring);
  if (taverne) { for (const c of taverne.clients) { G.scene.remove(c.root); UI.retirerPlaque(c); } taverne = null; UI.fileAttente(null); }
  mission = null; UI.manga(null);
  viderEscouade();
  if (modeActuel && modeActuel.goulet) { goulet = null; UI.scoreGoulet(null); UI.flechesDrapeau([]); UI.classementGoulet(null); }
  ressourcesAssets = null;
  try { libererGPU([monde && monde.groupe, ...ennemis.map(e => e.root), ...allies.map(a => a.root), ...bots.map(b => b.root), ...coffres.map(c => c.obj), ...projectiles.map(p => p.mesh), ...G.vfx.map(v => v.obj)]); } catch (e) { console.warn(e); }
  if (viseeObj) { G.scene.remove(viseeObj.g, viseeObj.fleche, viseeObj.marque); viseeObj = null; } visee = null;
  for (const e of ennemis) G.scene.remove(e.root);
  for (const a of allies) G.scene.remove(a.root);
  for (const o of ouvriers) G.scene.remove(o.root);
  if (intendant) G.scene.remove(intendant.root);
  if (passeur) G.scene.remove(passeur.root);
  if (graveuse) { G.scene.remove(graveuse.root, ...graveuse.decor); graveuse = null; }
  ouvriers = []; intendant = null; passeur = null; recolteJ = null; assaut = null;
  if (raid && raid.r) raid = null;
  if (!G.scene.background || !G.scene.background.isColor) G.scene.background = new THREE.Color();
  G.scene.background.set('#120b1b'); G.scene.fog.color.set('#150d20'); G.sun.color.set('#c9b8ff'); G.sun.intensity = 1.25; G.hemi.color.set('#8f7cc8'); G.hemi.groundColor.set('#2a1830');
  viderSylve(); UI.boutonDegats(false);
  for (const b of bots) G.scene.remove(b.root);
  for (const p of projectiles) G.scene.remove(p.mesh);
  for (const c of coffres) { G.scene.remove(c.obj); G.scene.remove(c.beam); }
  if (marchand) G.scene.remove(marchand.root);
  if (sortie) G.scene.remove(sortie.groupe);
  for (const v of G.vfx) G.scene.remove(v.obj);
  G.vfx = []; dangers.length = 0; ennemis = []; allies = []; bots = []; projectiles = []; coffres = []; minuteries = []; marchand = null; sortie = null;
  UI.viderPlaques(); UI.boss(null);
  if (monde) { G.scene.remove(monde.groupe); monde.groupe.traverse(o => { if (o.isInstancedMesh) o.dispose(); }); }
  for (const p of G.parts) p.vie = 0;
  joueur && (joueur.cibleVerrou = null);
}

function fondu(fn) {
  transition = true;
  const f = document.createElement('div'); f.style.cssText = 'position:fixed;inset:0;background:radial-gradient(#ff2a1a,#2a0000 60%,#000);opacity:0;transition:opacity .45s;z-index:50;pointer-events:none';
  document.body.appendChild(f); requestAnimationFrame(() => (f.style.opacity = 1));
  setTimeout(() => { fn(); precompiler(); f.style.background = '#000'; setTimeout(() => { f.style.opacity = 0; setTimeout(() => { f.remove(); transition = false; }, 500); }, 120); }, 480);
}

function lancerHub(premier = false) {
  if (groupe && modeActuel && (modeActuel.mode !== undefined || MODES.includes(modeActuel))) {
    if (groupe.fort) { J.rushs = (J.rushs || 0) + 1; sauver(); }
    groupe.donjonsRestants = (groupe.donjonsRestants ?? 2) - 1;
    if (groupe.donjonsRestants <= 0) { const n = groupe.nom; groupe = null; setTimeout(() => { UI.chat(n, hasard(['gg, je dois y aller', 'bon je déco, gg', 'merci pour les runs', 'bye'])); UI.toast(`${n} a quitté le groupe`); }, 2500); }
  }
  invasion = null; arene = null; selection = null;
  if (V1) J.accepteInvasion = false;
  if (!premier) { viderMonde(); monde = construireHub(); creerMarchand(); if (!V1) creerPasseur(); creerGraveuse(); creerBots(); }
  if (V1) { monde.patrouille = Array.from({ length: 8 }, (_, k) => pointLibrePres(V(Math.sin(k / 8 * 6.283) * 15, 0, Math.cos(k / 8 * 6.283) * 15), 0, 3)); monde.entreesVille = ['portailArene', 'portailIle'].filter(k => monde[k]).map(k => monde[k].pos.clone()); for (const k of ['portailArene', 'portailIle', 'portailGoulet']) if (monde[k]) { monde[k].groupe.visible = false; monde[k] = null; } }
  const revientDeMode = !!modeActuel;
  modeActuel = V1 ? MODE_VILLE : null; enJeu = true;
  if (V1) { verifierSacrifices(); volontaires(); percevoirImpots(); prochaineAffaire = G.t + 90; prochainRaidV = G.t + 40 + 30 * (royaume().fortif || 0); if (!citoyens.length) creerCitoyens(); prochainPortail = G.t + 150; programmer(0.4, () => { if (joueur && modeActuel && modeActuel.id === 'ville') construireCimetiere(); if (joueur && modeActuel && modeActuel.id === 'ville' && !compActeurs.length) deployerCompagnons(false); }); if (!J.escouade) { J.escouade = true; J.escStats = { debut: Date.now(), argent0: J.argent, xp: 0, kills: 0, coffres: 0 }; } } // V1 : tes ombres font partie de toi, plus besoin de code
  construireJoueur(monde.spawn.clone());
  if (revientDeMode && !premier) setTimeout(() => proposerRefaire(60), 900); else UI.boutonRefaire(null);
  joueur.pv = joueur.st.pvMax; joueur.energie = joueur.st.energieMax;
  G.camTarget.copy(joueur.pos); G.camDist = 25; G.scene.fog.density = 0.016;
  G.hemi.intensity = 1.1; G.sun.intensity = 1.3;
  UI.journal('Place des Cendres', V1 ? 'Ta ville. Ses habitants comptent sur toi : les cultistes de la Brèche attaquent régulièrement. La Brèche rouge mène à leurs donjons.' : 'Brèche rouge : donjons. Portail violet : l’arène. Touche un joueur pour former un groupe.');
  G.renderer.compile(G.scene, G.camera);
  if (V1) majBandeauVille(); else UI.zone('Place des Cendres', `Joueurs ${bots.length + 1}/20`);
  $('#btnQuitter').hidden = true;
  if (premier) setTimeout(() => UI.toast('Bienvenue sur la Place, ' + J.nom), 400);
  sauver();
}

// ---------------- Parchemin de téléportation ----------------
const PRIX_TP = 2500000;
function prochainBoss() { return ennemis.filter(e => e.boss && !e.mort && !e.errant && !e.invoc).sort((a, b) => (a.idx ?? 0) - (b.idx ?? 0) || dist2D(a.pos, joueur.pos) - dist2D(b.pos, joueur.pos))[0]; }
function majBoutonTP() {
  const ok = MODES.includes(modeActuel) && (J.parchTP || 0) > 0 && !transition && !(invasion && invasion.rivaux && invasion.rivaux.some(r => !r.mort));
  const b = ok ? prochainBoss() : null;
  UI.boutonTP(b && dist2D(b.pos, joueur.pos) > 18 ? J.parchTP : 0, utiliserTP);
}
function utiliserTP() {
  const b = prochainBoss(); if (!b || !(J.parchTP > 0) || !MODES.includes(modeActuel)) return;
  J.parchTP--; sauver();
  effetPortail(joueur.pos, '#ff3a2a'); son('jingle_legend', 0.4, 1.3);
  let p = null;
  for (let i = 0; i < 80 && !p; i++) { const a = Math.random() * 6.28, r = rnd(7, 10); const x = b.pos.x + Math.cos(a) * r, z = b.pos.z + Math.sin(a) * r; if (libre(x, z, 0.7) && (!b.salle || !monde.zoneDe || monde.zoneDe(x, z) === b.salle.id) && ligneLibre(V(x, 0, z), b.pos)) p = V(x, 0, z); }
  p = p || pointLibrePres(b.pos, 5, 9);
  joueur.pos.copy(p); G.camTarget.copy(p); joueur.chemin = null; joueur.autoCible = null;
  for (const a of allies) if (!a.mort && !a.parti) { a.pos.copy(pointLibrePres(p, 1, 3)); a.chemin = null; }
  effetPortail(p, '#ff3a2a'); UI.toast(`Téléporté devant ${b.boss.nom}`);
}
// compile tous les shaders de la nouvelle zone pendant le fondu (sinon : gel en plein combat)
function precompiler() { try { if (G.renderer.compileAsync) G.renderer.compileAsync(G.scene, G.camera).catch(() => {}); else G.renderer.compile(G.scene, G.camera); } catch (e) {} }
