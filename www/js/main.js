// ===== Brèche Écarlate — boucle de jeu =====
import { THREE, G, initRendu, majCamera, rendre, majTorches, chargerAssets, chargerSons, son, ambiance, Acteur, cloner,
  emettre, majParticules, majVfx, ajouterVfx, onde, lueurSol, arcTaille, faisceau, telegraphe, meshCarreau, meshBoule, DIR_HAUT, DIR_DROITE, projeter, texRond, redimensionner, appliquerNiveau, majQualiteAuto } from './engine.js';
import { construireHub, construireDonjon, construireArene, construireIle, nbEmplacements, majFeux, noeudReel, creerAssetsProc } from './world.js';
import { UI, iconeObjet, bustePersonnage } from './ui.js';
import { TIERS, ARMES, ARMURES, SORTS, MODES, COFFRES, BOSS, MOBS, BOTS, CHAT, tf, MAITRISES, NIVEAU_REQUIS, ILE_TYPES, ILE_TAILLES, ILE_NIVEAUX, BATIMENTS, GARDES_ILE, CHAMPION_ILE, HEURE_ASSAUT, RESSOURCES } from './data.js';
import { creerArme, creerArmure, creerPotion, statsHeros, nomObjet, valeurObjet, prixVente, lootCoffre, lootMonstre, tirerCouleurCoffre, ETAT, xpPour, peutPorter, niveauRequis, niveauDe, sortsArme, prixTrophees } from './items.js';

const $ = (s) => document.querySelector(s);
const rnd = (a, b) => a + Math.random() * (b - a);
const V = (x = 0, y = 0, z = 0) => new THREE.Vector3(x, y, z);
const dist2D = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);

// ---------------- Sauvegarde ----------------
let J = null;
const CLE = 'breche-ecarlate-v1';
// sauvegarde groupée : au plus une écriture toutes les 1,5 s (l’écriture disque fait des micro-freezes sur Android)
let sauverT = null, efface = false;
function sauverMaintenant() { if (efface) return; if (sauverT) { clearTimeout(sauverT); sauverT = null; } try { localStorage.setItem(CLE, JSON.stringify(J)); } catch (e) {} }
function sauver() { if (!sauverT) sauverT = setTimeout(sauverMaintenant, 1500); }
addEventListener('pagehide', sauverMaintenant); document.addEventListener('visibilitychange', () => { if (document.hidden) sauverMaintenant(); });
function charger() { try { const s = localStorage.getItem(CLE); return s ? JSON.parse(s) : null; } catch (e) { return null; } }
function nouvellePartie(nom, arme) {
  J = { nom, argent: 400, potions: 5, trophees: 0, sac: [], equip: {
    arme: creerArme(arme, 1, 0), casque: creerArmure('casque', 1, 0), plastron: creerArmure('plastron', 1, 0), bottes: creerArmure('bottes', 1, 0) } };
  for (const a of ['epee', 'arbalete', 'baton']) if (a !== arme) J.sac.push(creerArme(a, 1, 0));
  migrer(); sauver();
}
// mise à niveau des sauvegardes : maîtrise, trophées, équipement trop haut
function migrer() {
  J.maitrise = J.maitrise || {};
  for (const m of MAITRISES) J.maitrise[m.id] = J.maitrise[m.id] || { niv: 1, xp: 0 };
  J.trophees = J.trophees || 0;
  ETAT.maitrise = J.maitrise;
  let n = 0;
  for (const s of ['arme', 'casque', 'plastron', 'bottes']) {
    const it = J.equip[s];
    if (it && !peutPorter(it)) { J.sac.push(it); J.equip[s] = s === 'arme' ? creerArme(it.type, 1, 0) : creerArmure(s, 1, 0); n++; }
  }
  if (n) setTimeout(() => UI.toast(`${n} pièce${n > 1 ? 's' : ''} trop haute${n > 1 ? 's' : ''} pour ta maîtrise rangée${n > 1 ? 's' : ''} dans le sac`), 1500);
}

// ---------------- État ----------------
let monde = null, joueur = null, ennemis = [], bots = [], projectiles = [], minuteries = [], coffres = [], marchand = null, sortie = null;
let invasion = null, arene = null, groupe = null, selection = null;
let allies = [];
let modeActuel = null, bossVaincus = 0, enJeu = false, transition = false;
const entree = { jx: 0, jy: 0, atk: false, clavier: {} };

function programmer(delai, fn) { minuteries.push({ t: delai, fn }); }

// ---------------- Démarrage ----------------
const ASSETS = [
  ['Knight', 'assets/chars/Knight.json'], ['Rogue_Hooded', 'assets/chars/Rogue_Hooded.json'], ['Mage', 'assets/chars/Mage.json'], ['Barbarian', 'assets/chars/Barbarian.json'], ['Rogue', 'assets/chars/Rogue.json'],
  ['Skeleton_Warrior', 'assets/chars/Skeleton_Warrior.json'], ['Skeleton_Minion', 'assets/chars/Skeleton_Minion.json'], ['Skeleton_Mage', 'assets/chars/Skeleton_Mage.json'], ['Skeleton_Rogue', 'assets/chars/Skeleton_Rogue.json'],
  ['Dragon_Evolved', 'assets/chars/Dragon_Evolved.json'],
  ...['Skeleton_Blade', 'Skeleton_Axe', 'Skeleton_Staff', 'Skeleton_Crossbow', 'Skeleton_Shield_Large_A'].map(k => [k, `assets/props/${k}.json`]),
  ...['floor_tile_large', 'floor_tile_large_rocks', 'floor_dirt_large', 'wall', 'wall_corner', 'wall_arched', 'wall_broken', 'pillar', 'pillar_decorated', 'column', 'torch_mounted', 'banner_patternA_red', 'banner_thin_red', 'banner_patternB_red',
    'barrel_large', 'barrel_small_stack', 'box_stacked', 'crates_stacked', 'table_long_decorated_A', 'table_long_tablecloth_decorated_A', 'shelves', 'shelf_small_candles', 'candle_triple', 'candle_lit', 'coin_stack_large',
    'rubble_large', 'rubble_half', 'sword_shield_broken', 'keg_decorated', 'trunk_large_A', 'barrier', 'stairs_wide', 'chest', 'chest_gold'].map(k => [k, `assets/env/${k}.json`]),
  ...['hex_grass', 'hex_water', 'b_home_A', 'b_home_B', 'b_tavern', 'b_lumbermill', 'b_mine', 'b_market', 'b_well', 'b_windmill', 'b_tower_A', 'flag_yellow', 'barrel', 'crate_A_big', 'sack', 'tent',
    'Tree_1_A', 'Tree_2_B', 'Tree_3_A', 'Tree_4_A', 'Bush_2_C', 'Rock_1_A', 'Rock_3_C', 'Grass_1_A', 'Wood_Log_A', 'Wood_Log_Stack', 'Iron_Nuggets', 'Gold_Nuggets', 'Copper_Nuggets', 'Stone_Chunks_Large',
    'tool_axe', 'tool_pickaxe', 'tool_lantern', 'crop_carrot', 'crop_pumpkin', 'crop_melon', 'flower_redA', 'flower_yellowA', 'flower_purpleA', 'ground_pathTile'].map(k => [k, `assets/ile/${k}.json`]),
];
const SONS = ['knifeSlice', 'knifeSlice2', 'drawKnife2', 'handleCoins', 'creak1', 'doorOpen_1', 'metalLatch', 'cloth1', 'bookOpen', 'impactPlate_heavy_000', 'impactMetal_medium_001', 'impactGeneric_light_000',
  'footstep_concrete_000', 'footstep_concrete_001', 'click_001', 'open_001', 'close_001', 'confirmation_001', 'error_001', 'select_001', 'maximize_001', 'thrusterFire_000', 'explosionCrunch_000', 'lowFrequency_explosion_000', 'forceField_000',
  'jingle_win', 'jingle_loot', 'jingle_legend', 'chop', 'impactMining_000', 'impactMining_001', 'impactPlank_medium_000', 'handleSmallLeather'].map(k => [k, `assets/audio/${k}.ogg`]);

async function demarrer() {
  initRendu($('#scene'));
  try { const q = localStorage.getItem('breche-qualite'); if (q) G.qualite = q; } catch (e) {}
  appliquerNiveau({ haute: 2, moyenne: 1, basse: 0, auto: 2 }[G.qualite] ?? 2);
  try {
    await chargerAssets(ASSETS, (k, nom) => { $('#charge i').style.width = (k * 100) + '%'; $('#chargeTxt').textContent = 'Chargement… ' + Math.round(k * 100) + ' %'; });
    creerAssetsProc();
  } catch (e) { $('#chargeTxt').textContent = 'Un fichier du jeu n’a pas pu se charger (' + (e && e.message ? e.message : e) + '). Recharge la page.'; console.error(e); return; }
  monde = construireHub();
  G.scene.add(G.points);
  creerMarchand(); creerPasseur(); creerBots();
  prechauffer();
  G.camTarget.set(0, 0, 4);
  $('#charge').hidden = true; $('#chargeTxt').hidden = true;
  const sauve = charger();
  const menu = $('#menuTitre'); menu.hidden = false;
  let armeChoisie = 'epee';
  if (sauve) { J = sauve; migrer(); $('#nomJoueur').value = J.nom; $('#jouer').textContent = 'Reprendre l’aventure'; $('#choixArme').hidden = true; }
  else {
    $('#choixArme').innerHTML = ['epee', 'arbalete', 'baton'].map(a => `<button data-a="${a}" class="${a === 'epee' ? 'actif' : ''}"><img src="${iconeObjet({ cat: 'arme', type: a, tier: 1 })}" alt="">${ARMES[a].label}</button>`).join('');
    $('#choixArme').querySelectorAll('button').forEach(b => b.onclick = () => { armeChoisie = b.dataset.a; $('#choixArme').querySelectorAll('button').forEach(x => x.classList.toggle('actif', x === b)); });
  }
  $('#jouer').onclick = async () => {
    try { G.audio = G.audio || new (window.AudioContext || window.webkitAudioContext)(); await G.audio.resume(); } catch (e) {}
    chargerSons(SONS).then(() => { ambiance(); });
    if (!J) nouvellePartie(($('#nomJoueur').value || 'Héros').slice(0, 16), armeChoisie);
    else J.nom = ($('#nomJoueur').value || J.nom).slice(0, 16);
    try { await document.documentElement.requestFullscreen?.(); await screen.orientation?.lock?.('landscape'); } catch (e) {}
    $('#titre').hidden = true; $('#hud').hidden = false;
    lancerHub(true);
  };
  if (window.matchMedia('(orientation: portrait)').matches && innerWidth < 900) $('#rotation').classList.add('actif');
  $('#ignorerRot').onclick = () => $('#rotation').classList.remove('actif');
  window.addEventListener('orientationchange', () => setTimeout(() => { if (!window.matchMedia('(orientation: portrait)').matches) $('#rotation').classList.remove('actif'); redimensionner(); }, 300));
  boucle();
}

// compile d'avance les effets des sorts : évite le petit gel au premier lancer de chaque effet
function prechauffer() {
  const p = V(400, 0, 400);
  const objs = [meshCarreau('#ffffff'), meshBoule('#ff7a1a', 0.5), faisceau(p, '#ffffff')];
  for (const o of objs) { o.position.copy(p); G.scene.add(o); }
  telegraphe(p, 2, 0.05, '#ff2a2a'); telegraphe(p, 2, 0.05, '#ff2a2a', null, { cone: 1 }); telegraphe(p, 4, 0.05, '#ff2a2a', null, { ligne: true, largeur: 2, angle: 0 });
  arcTaille(p, 0, 2, '#ffffff'); onde(p, '#ffffff'); lueurSol(p, '#ffffff', 2, 0.05);
  G.renderer.compile(G.scene, G.camera);
  for (const o of objs) G.scene.remove(o);
}

// ---------------- Joueur ----------------
function construireJoueur(pos) {
  const ancienPos = pos || (joueur ? joueur.root.position.clone() : V());
  const ancienAngle = joueur ? joueur.angle : Math.PI * 1.25;
  if (joueur) { G.scene.remove(joueur.root); UI.retirerPlaque(joueur); }
  const arme = J.equip.arme || creerArme('epee', 1);
  const def = ARMES[arme.type];
  const a = new Acteur(def.model, { hauteur: 2.0 });
  // ne montrer que l'arme portée
  const tous = Object.keys(a.nodes).filter(n => /Sword|Axe|Shield|Crossbow|Staff|Wand|Knife|Throwable|Mug|Spellbook/.test(n));
  a.montrerSeul([def.node], tous);
  a.teinter(def.node, TIERS[arme.tier].color, 0.62, TIERS[arme.tier].glow);
  if (def.helmet) { a.nodes[def.helmet].visible = !!J.equip.casque; if (J.equip.casque) a.teinter(def.helmet, TIERS[J.equip.casque.tier].color, 0.5, TIERS[J.equip.casque.tier].glow * 0.3); }
  if (J.equip.plastron) { a.teinter(def.cape, TIERS[J.equip.plastron.tier].color, 0.7, TIERS[J.equip.plastron.tier].glow * 0.25); a.teinter(def.body, TIERS[J.equip.plastron.tier].color, 0.28, 0); }
  if (J.equip.bottes) def.legs.forEach(l => a.teinter(l, TIERS[J.equip.bottes.tier].color, 0.3, 0));
  G.scene.add(a.root);
  a.root.position.copy(ancienPos);
  const st = statsHeros(J.equip);
  const j = joueur && joueur.pv !== undefined ? joueur : {};
  joueur = Object.assign(a, {
    pos: a.root.position, angle: ancienAngle, armeType: arme.type, def,
    pv: Math.min(j.pv ?? st.pvMax, st.pvMax), energie: Math.min(j.energie ?? st.energieMax, st.energieMax),
    bouclier: 0, bouclierT: 0, soinT: 0, sprintT: 0, slowT: 0, vampT: 0, bonusTir: false, invuln: 0, spinT: 0, verrouT: 0, dashT: 0,
    cds: j.cds || {}, cdMax: {}, sorts: {}, atkT: 0, cible: null, cibleVerrou: j.cibleVerrou || null, mort: false, st, hauteurPlaque: 2.55, combatT: 0, pasT: 0,
  });
  const ss = sortsArme(arme);
  ['Q', 'W', 'E'].forEach((k, i) => { joueur.sorts[k] = { ...SORTS[ss[i]], id: ss[i] }; });
  if (J.equip.plastron) joueur.sorts.R = { ...SORTS.rempart, id: 'rempart' };
  if (J.equip.casque) joueur.sorts.D = { ...SORTS.souffle, id: 'souffle' };
  if (J.equip.bottes) joueur.sorts.F = { ...SORTS.ruee, id: 'ruee' };
  for (const k in joueur.sorts) joueur.cdMax[k] = +(joueur.sorts[k].cd * (1 - st.recharge / 100)).toFixed(2);
  joueur.cdMax.POT = 60; joueur.potions = J.potions;
  joueur.jouer(def.idle);
  UI.plaque(joueur, { nom: J.nom, guilde: 'CROW ZERO', classe: 'allie', vie: false, ip: st.ip });
  $('#ipHud').textContent = '⚔ ' + st.ip;
  UI.construireSorts(joueur);
  $('#nomHud').textContent = J.nom;
  bustePersonnage(def.model, $('#avatarCv'), '#5a3a5a');
  joueur.root.rotation.y = joueur.angle;
}
function recalculer() { joueur.st = statsHeros(J.equip); joueur.pv = Math.min(joueur.pv, joueur.st.pvMax); }

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
function creerBots() {
  const n = 16;
  for (let i = 0; i < n; i++) {
    const [nom, tag, guilde] = BOTS[i % BOTS.length];
    const type = ['epee', 'arbalete', 'baton'][i % 3];
    const tier = 1 + Math.floor(Math.pow(Math.random(), 1.4) * 8);
    const equip = genererEquipRival(300 + (tier - 1) * 100 + rnd(-30, 60), type);
    const modele = type === 'arbalete' && i % 2 ? 'Rogue' : ARMES[type].model;
    const a = new Acteur(modele, { hauteur: 2.0 });
    habiller(a, equip, ARMES[type]);
    a.data = { nom, guilde: (tag ? `[${tag}] ` : '') + guilde, equip, modele, ip: statsHeros(equip, false).ip };
    let p; do { p = V(rnd(-24, 22), 0, rnd(-20, 20)); } while (!libre(p.x, p.z, 0.6));
    a.root.position.copy(p); a.root.rotation.y = rnd(0, 6.28);
    G.scene.add(a.root);
    Object.assign(a, { pos: a.root.position, nom, etat: 'idle', timer: rnd(0, 4), cible: null, vitesse: rnd(1.8, 2.6), hauteurPlaque: 2.55, angle: a.root.rotation.y });
    a.jouer(Math.random() < 0.25 ? 'Sit_Floor_Idle' : 'Idle');
    UI.plaque(a, { nom, guilde: a.data.guilde, classe: 'allie', vie: false, ip: a.data.ip });
    bots.push(a);
  }
}
function majBots(dt) {
  for (const b of bots) {
    b.timer -= dt;
    if (groupe && b.nom === groupe.nom && joueur) { // le coéquipier suit le joueur sur la place
      const d = dist2D(b.pos, joueur.pos);
      if (d > 3.2) { const dir = V(joueur.pos.x - b.pos.x, 0, joueur.pos.z - b.pos.z).normalize(); const v = (d > 7 ? 6.5 : 4.6) * dt; deplacer(b, dir.x * v, dir.z * v, 0.5); b.angle = tourner(b.angle, Math.atan2(dir.x, dir.z), dt * 10); b.root.rotation.y = b.angle; b.jouer('Running_A'); }
      else { const c = b.courante ? b.courante.getClip().name : ''; if (c === 'Running_A' || c === 'Walking_A' || c === 'Sit_Floor_Idle') b.jouer('Idle'); }
      b.etat = 'idle'; b.timer = 2; b.maj(dt); continue;
    }
    if (majVieBot(b, dt)) { if (!b.mort && joueur && b.pos.distanceTo(joueur.pos) < 45) b.maj(dt); continue; }
    if (b.etat === 'idle' && b.timer <= 0 && Math.random() < 0.55) { const dst = destinationBot(b); if (dst) { b.but = dst; b.etat = 'but'; continue; } }
    if (b.etat === 'idle' && b.timer <= 0) {
      const r = Math.random();
      if (r < 0.65) { let p; let n = 0; do { p = V(rnd(-24, 22), 0, rnd(-20, 20)); } while (!libre(p.x, p.z, 0.6) && ++n < 20); b.cible = p; b.etat = 'marche'; b.jouer(Math.random() < 0.3 ? 'Running_A' : 'Walking_A'); b.course = b.courante === b.actions.Running_A; }
      else if (r < 0.8) { b.jouer('Cheer', { boucle: false, fin: () => b.jouer('Idle') }); b.timer = rnd(3, 6); }
      else if (r < 0.9) { b.jouer('Sit_Floor_Idle'); b.timer = rnd(8, 16); }
      else { b.jouer('Idle'); b.timer = rnd(3, 8); }
    } else if (b.etat === 'marche') {
      const d = dist2D(b.pos, b.cible);
      if (d < 0.5) { b.etat = 'idle'; b.timer = rnd(2, 7); b.jouer('Idle'); continue; }
      const dir = V(b.cible.x - b.pos.x, 0, b.cible.z - b.pos.z).normalize();
      const v = (b.course ? 4.8 : b.vitesse) * dt;
      const nx = b.pos.x + dir.x * v, nz = b.pos.z + dir.z * v;
      if (libre(nx, nz, 0.5)) { b.pos.x = nx; b.pos.z = nz; } else { b.etat = 'idle'; b.timer = 1; b.jouer('Idle'); }
      b.angle = tourner(b.angle, Math.atan2(dir.x, dir.z), dt * 8); b.root.rotation.y = b.angle;
    }
    if (b.pos.distanceTo(joueur ? joueur.pos : ORBITE) < 45) b.maj(dt);
  }
  if (Math.random() < dt / 14) { const b = bots[Math.floor(Math.random() * bots.length)]; UI.chat(b.nom, CHAT[Math.floor(Math.random() * CHAT.length)]); }
}

function viderMonde() {
  for (const e of ennemis) G.scene.remove(e.root);
  for (const a of allies) G.scene.remove(a.root);
  for (const o of ouvriers) G.scene.remove(o.root);
  if (intendant) G.scene.remove(intendant.root);
  if (passeur) G.scene.remove(passeur.root);
  ouvriers = []; intendant = null; passeur = null; recolteJ = null; assaut = null;
  if (raid && raid.r) raid = null;
  G.scene.background.set('#120b1b'); G.scene.fog.color.set('#150d20'); G.sun.color.set('#c9b8ff');
  for (const b of bots) G.scene.remove(b.root);
  for (const p of projectiles) G.scene.remove(p.mesh);
  for (const c of coffres) { G.scene.remove(c.obj); G.scene.remove(c.beam); }
  if (marchand) G.scene.remove(marchand.root);
  if (sortie) G.scene.remove(sortie.groupe);
  for (const v of G.vfx) G.scene.remove(v.obj);
  G.vfx = []; ennemis = []; allies = []; bots = []; projectiles = []; coffres = []; minuteries = []; marchand = null; sortie = null;
  UI.viderPlaques(); UI.boss(null);
  if (monde) { G.scene.remove(monde.groupe); monde.groupe.traverse(o => { if (o.isInstancedMesh) o.dispose(); }); }
  for (const p of G.parts) p.vie = 0;
  joueur && (joueur.cibleVerrou = null);
}

function fondu(fn) {
  transition = true;
  const f = document.createElement('div'); f.style.cssText = 'position:fixed;inset:0;background:radial-gradient(#ff2a1a,#2a0000 60%,#000);opacity:0;transition:opacity .45s;z-index:50;pointer-events:none';
  document.body.appendChild(f); requestAnimationFrame(() => (f.style.opacity = 1));
  setTimeout(() => { fn(); f.style.background = '#000'; setTimeout(() => { f.style.opacity = 0; setTimeout(() => { f.remove(); transition = false; }, 500); }, 120); }, 480);
}

function lancerHub(premier = false) {
  invasion = null; arene = null; selection = null;
  if (!premier) { viderMonde(); monde = construireHub(); creerMarchand(); creerPasseur(); creerBots(); }
  modeActuel = null; enJeu = true;
  construireJoueur(monde.spawn.clone());
  joueur.pv = joueur.st.pvMax; joueur.energie = joueur.st.energieMax;
  G.camTarget.copy(joueur.pos); G.camDist = 25; G.scene.fog.density = 0.016;
  G.hemi.intensity = 1.1; G.sun.intensity = 1.3;
  UI.journal('Place des Cendres', 'Brèche rouge : donjons. Portail violet : l’arène. Touche un joueur pour former un groupe.');
  G.renderer.compile(G.scene, G.camera);
  UI.zone('Place des Cendres', `Joueurs ${bots.length + 1}/20`);
  $('#btnQuitter').hidden = true;
  if (premier) setTimeout(() => UI.toast('Bienvenue sur la Place, ' + J.nom), 400);
  sauver();
}

// ---------------- Donjon ----------------
function entrerDonjon(id, opts = {}) {
  fondu(() => {
    viderMonde();
    modeActuel = MODES[id]; bossVaincus = 0;
    invasion = opts.envahir ? { mode: 'menee', t: 4, rival: null } : (J.accepteInvasion && Math.random() < 0.8 ? { mode: 'subie', t: rnd(40, 100), rival: null } : null);
    monde = construireDonjon(modeActuel);
    construireJoueur(monde.spawn.clone());
    joueur.pv = joueur.st.pvMax; joueur.energie = joueur.st.energieMax;
    G.camTarget.copy(joueur.pos); G.scene.fog.density = 0.028; G.hemi.intensity = 0.75; G.sun.intensity = 0.8;
    if (groupe) creerCombattant(pointLibrePres(monde.spawn, 1.5, 3), groupe, 'allie');
    // monstres
    const types = id === 0 ? ['minion', 'minion', 'minion', 'guerrier', 'archer'] : id === 1 ? ['minion', 'guerrier', 'guerrier', 'archer', 'mage'] : ['guerrier', 'guerrier', 'archer', 'mage', 'mage', 'minion'];
    monde.packs.forEach((pk, i) => pk.pts.forEach(p => creerEnnemi(MOBS[types[Math.floor(Math.random() * types.length)]], p, modeActuel.mobTier, i)));
    // boss et coffres
    if (!opts.envahir) monde.bossSalles.forEach((s, k) => {
      const b = creerBoss(BOSS[k], s.centre.clone().add(V(2, 0, 2)), modeActuel.bossTier[k], s);
      creerCoffre(monde.coffresPos[k], tirerCouleurCoffre(), b);
    });
    creerSortie(monde.sortie);
    UI.journal(modeActuel.lieu, 'Gardiens vaincus : 0 / 4', 0);
    UI.zone(modeActuel.lieu, `${modeActuel.nom} · T${modeActuel.tiers[0]}–T${modeActuel.tiers[1]}`);
    $('#btnQuitter').hidden = false;
    if (opts.envahir) { UI.journal('Invasion', 'Tu entres dans le monde d’un autre joueur…', null); setTimeout(() => UI.toast('Invasion en cours', true), 600); }
    else setTimeout(() => { UI.toast(modeActuel.lieu, true); UI.toast('Trouve les 4 gardiens. Les coffres brillent de leur couleur.'); }, 600);
    son('forceField_000', 0.6, 0.7);
    G.renderer.compile(G.scene, G.camera);
  });
}

function creerEnnemi(def, pos, tierMob, pack, boss = null) {
  const a = new Acteur(def.model, { hauteur: boss ? (boss.model === 'Dragon_Evolved' ? 4.6 : 2.0) : 2.0, echelle: boss ? (boss.model === 'Dragon_Evolved' ? 1 : boss.scale) : 1 });
  if (def.arme) a.attacher(def.arme, 'handslot.r');
  if (def.model === 'Skeleton_Warrior' && !boss) a.attacher('Skeleton_Shield_Large_A', 'handslot.l');
  a.root.position.copy(pos); a.root.rotation.y = rnd(0, 6.28);
  G.scene.add(a.root);
  const f = tf(tierMob);
  const pvMax = Math.round(160 * f * (def.hp || 1) * (boss ? boss.hpMult : 1));
  Object.assign(a, {
    def, boss, pos: a.root.position, pv: pvMax, pvMax, dmg: 15 * f * (def.dmg || 1) * (boss ? boss.dmgMult : 1),
    etat: boss ? 'dormant' : 'idle', atkT: rnd(0.5, 1.5), stunT: 0, slowT: 0, dots: [], pack, angle: a.root.rotation.y, mort: false,
    hauteurPlaque: boss ? (boss.model === 'Dragon_Evolved' ? 5.2 : 2.6 * boss.scale) : 2.55, rayon: boss ? (boss.model === 'Dragon_Evolved' ? 2.4 : 0.6 * boss.scale) : 0.55,
    specT: 3, cycle: 0, hover: def.model === 'Dragon_Evolved' ? 0.8 : 0, tierMob,
  });
  a.root.position.y = a.hover;
  if (def.model === 'Dragon_Evolved') a.jouer('Flying_Idle'); else a.jouer(boss ? 'Idle' : 'Idle_Combat', { vitesse: rnd(0.85, 1.1) });
  if (!boss) UI.plaque(a, { nom: def.nom, classe: 'ennemi', lettre: false });
  ennemis.push(a);
  return a;
}
function creerBoss(bdef, pos, tierB, salle) {
  const def = bdef.model === 'Dragon_Evolved'
    ? { nom: bdef.nom, model: 'Dragon_Evolved', arme: null, hp: 1, dmg: 1, vitesse: 4.2, portee: 3.8, type: 'melee', atk: 'Punch' }
    : { ...Object.values(MOBS).find(m => m.model === bdef.model), nom: bdef.nom, arme: bdef.arme, vitesse: 3.4, hp: 1, dmg: 1 };
  const b = creerEnnemi(def, pos, tierB, -1, bdef);
  b.salle = salle; b.idx = BOSS.indexOf(bdef);
  b.root.rotation.y = Math.PI * 0.25; b.angle = b.root.rotation.y;
  UI.plaque(b, { nom: bdef.nom, classe: 'ennemi', lettre: false });
  return b;
}
function creerCoffre(pos, couleur, boss) {
  const c = COFFRES.find(x => x.id === couleur);
  const obj = cloner(couleur === 'legendaire' ? 'chest_gold' : 'chest', pos.x, 0, pos.z, Math.PI / 4, 1.5);
  obj.traverse(o => { if (o.isMesh) { o.material = o.material.clone(); if (couleur !== 'legendaire') { o.material.color = new THREE.Color('#ffffff').lerp(new THREE.Color(c.color), 0.55); } o.material.emissive = new THREE.Color(c.color); o.material.emissiveIntensity = 0.25; o.castShadow = true; } });
  G.scene.add(obj);
  const beam = faisceau(V(pos.x, 0, pos.z), c.color, 16, 0.9); G.scene.add(beam);
  const sol = new THREE.Mesh(new THREE.CircleGeometry(2.4, 32), new THREE.MeshBasicMaterial({ color: c.color, map: texRond(), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
  sol.rotation.x = -Math.PI / 2; sol.position.y = 0.1; beam.add(sol);
  G.torches.push({ pos: V(pos.x, 2.5, pos.z), color: c.color, int: 28, dist: 12 });
  const lid = obj.getObjectByName('chest_lid');
  coffres.push({ obj, beam, couleur, def: c, boss, pos: pos.clone(), ouvert: false, lid });
}
function creerSortie(pos) {
  const g = new THREE.Group(); g.position.copy(pos); g.rotation.y = Math.PI / 4;
  const anneau = new THREE.Mesh(new THREE.TorusGeometry(1.6, 0.12, 10, 48), new THREE.MeshStandardMaterial({ color: '#9a7aff', emissive: '#6a3cff', emissiveIntensity: 2.6 }));
  anneau.position.y = 2; g.add(anneau);
  const disque = new THREE.Mesh(new THREE.CircleGeometry(1.55, 40), new THREE.MeshBasicMaterial({ color: '#6a3cff', map: texRond(), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
  disque.position.y = 2; g.add(disque);
  G.scene.add(g);
  G.torches.push({ pos: V(pos.x, 2, pos.z), color: '#8a5cff', int: 24, dist: 10 });
  G.anims.push((t) => { anneau.rotation.z = t; disque.material.opacity = 0.6 + 0.3 * Math.sin(t * 3); if (Math.random() < 0.3) emettre(V(pos.x, 2, pos.z), { n: 1, c1: '#b49cff', c2: '#5a2cff', rayon: 1.4, vit: 0.4, vie: 1, taille: 0.25 }); });
  sortie = { groupe: g, pos };
}

// ---------------- Collisions ----------------
function libre(x, z, r = 0.5) {
  if (!monde.marche(x, z)) return false;
  for (const c of monde.collisions) if (Math.hypot(x - c.x, z - c.z) < c.r + r) return false;
  return true;
}
function deplacer(ent, dx, dz, r = 0.5) {
  const p = ent.pos;
  if (libre(p.x + dx, p.z + dz, r)) { p.x += dx; p.z += dz; return true; }
  if (libre(p.x + dx, p.z, r)) { p.x += dx; return true; }
  if (libre(p.x, p.z + dz, r)) { p.z += dz; return true; }
  // contourner l'obstacle : on essaie des directions voisines
  const l = Math.hypot(dx, dz); if (l < 1e-5) return false;
  const a0 = Math.atan2(dx, dz);
  for (const k of [0.6, -0.6, 1.1, -1.1, 1.57, -1.57]) {
    const a = a0 + k * (ent.contour || 1);
    const nx = Math.sin(a) * l, nz = Math.cos(a) * l;
    if (libre(p.x + nx, p.z + nz, r)) { p.x += nx; p.z += nz; if (k < 0) ent.contour = -(ent.contour || 1); return true; }
  }
  return false;
}
function tourner(a, cible, k) { let d = cible - a; while (d > Math.PI) d -= Math.PI * 2; while (d < -Math.PI) d += Math.PI * 2; return a + d * Math.min(1, k); }

// ---------------- Combat : outils ----------------
const vivants = () => ennemis.filter(e => !e.mort && e.etat !== 'dormantCache');
function choisirCible(portee) {
  if (joueur.cibleVerrou && !joueur.cibleVerrou.mort && dist2D(joueur.cibleVerrou.pos, joueur.pos) < portee + 8) return joueur.cibleVerrou;
  const c = joueur.cible; // on garde la cible tant qu'elle reste à portée : plus de demi-tours entre deux ennemis
  if (c && !c.mort && ennemis.includes(c) && dist2D(c.pos, joueur.pos) - c.rayon < portee + 4) return c;
  let best = null, bd = portee + 3;
  for (const e of vivants()) { const d = dist2D(e.pos, joueur.pos) - e.rayon; if (d < bd) { bd = d; best = e; } }
  return best;
}
function directionVisee(portee) {
  const c = choisirCible(portee);
  if (c) return { dir: V(c.pos.x - joueur.pos.x, 0, c.pos.z - joueur.pos.z).normalize(), cible: c, point: c.pos.clone() };
  const d = V(Math.sin(joueur.angle), 0, Math.cos(joueur.angle));
  return { dir: d, cible: null, point: joueur.pos.clone().addScaledVector(d, Math.min(portee, 8)) };
}
function faireFace(dir) { joueur.angle = Math.atan2(dir.x, dir.z); joueur.root.rotation.y = joueur.angle; }
function degatsJoueur(mult) {
  const st = joueur.st; const crit = Math.random() * 100 < st.crit;
  let d = st.degats * mult * (crit ? 1.6 : 1) * rnd(0.92, 1.08);
  return { d, crit };
}
function blesser(e, mult, opts = {}) {
  if (e.mort) return;
  let { d, crit } = degatsJoueur(mult);
  if (opts.fixe) { d = opts.fixe; crit = false; }
  if (e.reduction) d *= 1 - e.reduction * 0.6;
  if (e.bouclierIA > 0) { const a = Math.min(e.bouclierIA, d); e.bouclierIA -= a; d -= a; emettre(V(e.pos.x, 1.2, e.pos.z), { n: 5, c1: '#bfe6ff', c2: '#4a9aff', vit: 3, vie: 0.4, taille: 0.3 }); if (d <= 0) { UI.nombre(V(e.pos.x, e.hauteurPlaque * 0.8, e.pos.z), 'Absorbé', 'info'); return; } }
  if (e.combattant && !opts.fixe && joueur.st.pvp) d *= 1 + joueur.st.pvp / 200;
  if (!opts.fixe && joueur.vampT > 0 && !joueur.mort) { joueur.pv = Math.min(joueur.st.pvMax, joueur.pv + d * 0.35); if (Math.random() < 0.5) emettre(V(joueur.pos.x, 1.2, joueur.pos.z), { n: 4, c1: '#ff8aa0', c2: '#c0103a', vit: 1.5, vie: 0.5, taille: 0.3 }); }
  e.pv -= d; e.frapper();
  UI.nombre(V(e.pos.x, e.hauteurPlaque * 0.8, e.pos.z), Math.round(d), crit ? 'crit' : '');
  if (!opts.silence) emettre(V(e.pos.x, 1.2 * (e.boss ? e.boss.scale * 0.7 : 1), e.pos.z), { n: crit ? 14 : 7, c1: opts.c1 || '#fff2d0', c2: opts.c2 || '#d8c8a0', vit: 4, vie: 0.35, taille: 0.25, grav: 6 });
  if (crit) son('impactPlate_heavy_000', 0.35);
  if (e.etat === 'idle' || e.etat === 'dormant') reveiller(e);
  if (opts.stun) e.stunT = Math.max(e.stunT, e.boss ? opts.stun * 0.35 : opts.stun);
  if (opts.slow) e.slowT = Math.max(e.slowT, opts.slow);
  if (opts.dot) e.dots.push({ ...opts.dot });
  if (opts.air && !e.boss) e.airT = 0.6;
  joueur.combatT = 4;
  if (e.pv <= 0) tuer(e);
}
function zoneDegats(centre, rayon, mult, opts = {}) {
  let n = 0;
  for (const e of vivants()) {
    const d = dist2D(e.pos, centre);
    if (d > rayon + e.rayon) continue;
    if (opts.cone) { const v = V(e.pos.x - centre.x, 0, e.pos.z - centre.z).normalize(); if (v.dot(opts.dir) < Math.cos(opts.cone / 2) && d > 1.2) continue; }
    blesser(e, mult, opts); n++;
  }
  return n;
}
function reveiller(e) {
  if (e.boss) { if (e.etat === 'dormant') { e.etat = 'chasse'; son('lowFrequency_explosion_000', 0.6, 0.7); UI.toast(e.boss.nom + ' se réveille !'); } return; }
  e.etat = 'chasse';
  for (const o of ennemis) if (o.pack === e.pack && o.etat === 'idle' && dist2D(o.pos, e.pos) < 14) o.etat = 'chasse';
}
function tuer(e) {
  e.mort = true; e.pv = 0;
  const anim = e.def.model === 'Dragon_Evolved' ? 'Death' : (e.actions.Death_C_Skeletons ? 'Death_C_Skeletons' : 'Death_A');
  e.jouer(anim, { boucle: false, fondu: 0.1 });
  son('impactGeneric_light_000', 0.5, 0.7);
  emettre(V(e.pos.x, 1, e.pos.z), { n: 22, c1: '#e9e0c8', c2: '#9a8a70', vit: 5, vie: 0.7, taille: 0.3, grav: 9 });
  if (joueur.cibleVerrou === e) joueur.cibleVerrou = null;
  if (e.rival) { if (arene) { setTimeout(() => { e.descendre = true; }, 4000); verifierArene(); } else if (e.bandit || e.gardeIle) finCombatIle(e); else victoireRival(e); return; }
  const part = coequipiers().length ? 0.5 : 1;
  const loot = lootMonstre(modeActuel);
  const gain = Math.max(1, Math.round(loot.argent * (e.boss ? 12 : 1) * part));
  J.argent += gain;
  const xp = Math.round(10 * (modeActuel.xp || 1) * (e.boss ? 18 : 1) * part);
  UI.nombre(V(e.pos.x, 2.2, e.pos.z), `+${gain} ¤`, 'info');
  gagnerXP(xp);
  for (const it of loot.objets) ajouterSac(it, true);
  if (e.boss) {
    bossVaincus++; UI.boss(null); G.shake = 1;
    onde(e.pos, e.boss.couleur, 10, 1.2);
    emettre(V(e.pos.x, 2, e.pos.z), { n: 120, c1: '#ffd27a', c2: e.boss.couleur, vit: 9, vie: 1.4, taille: 0.5, grav: 3 });
    son('jingle_win', 0.6);
    UI.toast(e.boss.nom + ' est vaincu !', true);
    UI.toast('Son coffre peut maintenant être ouvert.');
    UI.journal(modeActuel.lieu, `Gardiens vaincus : ${bossVaincus} / 4`, bossVaincus / 4);
    if (bossVaincus === 4) setTimeout(() => { UI.toast('Donjon nettoyé !', true); UI.journal(modeActuel.lieu, 'Les 4 gardiens sont tombés. Ouvre les coffres puis rentre par le portail violet.', 1); }, 2800);
    // les sbires restants s'effondrent
    for (const o of ennemis) if (!o.mort && o.invoque && o.maitre === e) { o.pv = 0; tuer(o); }
  }
  sauver();
  setTimeout(() => { e.descendre = true; }, e.boss ? 6000 : 2600);
}

function blesserJoueur(d, source = null) {
  if (joueur.mort || joueur.invuln > 0) { if (joueur.invuln > 0) UI.nombre(V(joueur.pos.x, 2.4, joueur.pos.z), 'Esquive', 'info'); return; }
  d = d * (1 - joueur.st.reduction) * rnd(0.92, 1.08);
  if (source && source.combattant && joueur.st.pvp) d *= 1 - joueur.st.pvp / 200;
  if (joueur.bouclier > 0) { const a = Math.min(joueur.bouclier, d); joueur.bouclier -= a; d -= a; emettre(V(joueur.pos.x, 1.2, joueur.pos.z), { n: 6, c1: '#bfe6ff', c2: '#4a9aff', vit: 3, vie: 0.4, taille: 0.3 }); }
  if (d <= 0) return;
  joueur.pv -= d; joueur.frapper(); joueur.combatT = 4;
  UI.nombre(V(joueur.pos.x, 2.2, joueur.pos.z), Math.round(d), 'joueur');
  G.shake = Math.min(1, G.shake + d / joueur.st.pvMax * 3);
  son('impactMetal_medium_001', 0.35);
  if (joueur.pv <= 0) mourirJoueur();
}
function mourirJoueur() {
  joueur.pv = 0; joueur.mort = true; joueur.jouer('Death_A', { boucle: false });
  if (assaut && !assaut.fini) { // les bandits pillent 70 % du coffre
    assaut.fini = true; const ile = assaut.ile; const pertes = [];
    for (const k in ile.coffre) { const p = Math.floor(ile.coffre[k] * 0.7); if (p) { ile.coffre[k] -= p; pertes.push(`${fmtN(p)} ${RES_LABEL[k]}`); } }
    sauver(); son('lowFrequency_explosion_000', 0.7, 0.5);
    setTimeout(() => UI.mort(`Les bandits ont vidé ton coffre : ${pertes.join(', ') || 'il était vide'}. Recrute des gardes chez Oswin pour la prochaine fois.`, () => fondu(() => lancerHub())), 1600);
    return;
  }
  if (arene) { son('lowFrequency_explosion_000', 0.6, 0.6); if (allies.some(a => !a.mort)) UI.toast('Ton coéquipier continue le combat…'); verifierArene(); return; }
  if (invasion && invasion.rival && !invasion.rival.mort) return defaiteRival();
  son('lowFrequency_explosion_000', 0.7, 0.5);
  const perte = Math.round(J.argent * 0.05); J.argent -= perte; sauver();
  setTimeout(() => UI.mort(`Tu perds ${perte.toLocaleString('fr-FR')} pièces d’argent. Ton équipement reste sur toi.`, () => fondu(() => lancerHub())), 1600);
}

// ---------------- Attaque de base ----------------
function attaquer(dt) {
  if (joueur.verrouT > 0 || joueur.mort || joueur.spinT > 0) return;
  const def = joueur.def, st = joueur.st;
  const c = choisirCible(st.portee);
  if (!c) { if (joueur.atkT <= 0 && joueur.armeType === 'epee') { /* coup dans le vide */ } return; }
  joueur.cible = c;
  const d = dist2D(c.pos, joueur.pos) - c.rayon;
  const dir = V(c.pos.x - joueur.pos.x, 0, c.pos.z - joueur.pos.z).normalize();
  const ang = Math.atan2(dir.x, dir.z);
  if (d > st.portee) {
    if (Math.abs(entree.jx) + Math.abs(entree.jy) < 0.1) { // s'approche tout seul
      deplacer(joueur, dir.x * st.vitesse * dt, dir.z * st.vitesse * dt);
      joueur.angle = tourner(joueur.angle, ang, dt * 12); joueur.root.rotation.y = joueur.angle; joueur.jouer(def.run);
    }
    return;
  }
  if (joueur.atkT > 0) { joueur.angle = tourner(joueur.angle, ang, dt * 14); joueur.root.rotation.y = joueur.angle; return; }
  faireFace(dir);
  joueur.atkT = 1 / st.vitesseAtk;
  const anim = def.attaques[Math.floor(Math.random() * def.attaques.length)];
  const vit = Math.max(1, st.vitesseAtk * joueur.duree(anim) * 0.95);
  joueur.jouer(anim, { boucle: false, vitesse: vit, forcer: true, fondu: 0.08, fin: () => joueur.jouer(def.idle) });
  joueur.verrouT = 0.28; // l'attaque de base fige brièvement : choix voulu pour le PvP
  const couleur = TIERS[J.equip.arme.tier].color;
  if (joueur.armeType === 'epee') {
    programmer(0.3 / vit * 1.4, () => {
      if (c.mort) return;
      arcTaille(joueur.pos, joueur.angle - Math.PI / 2, 2.9, couleur, Math.PI * 0.7, 0.22);
      if (dist2D(c.pos, joueur.pos) - c.rayon < st.portee + 1) { blesser(c, 1); son(Math.random() < 0.5 ? 'knifeSlice' : 'knifeSlice2', 0.45); }
    });
  } else {
    const mult = joueur.bonusTir ? 2 : 1; joueur.bonusTir = false;
    programmer(0.22, () => {
      if (joueur.armeType === 'arbalete') { tirerProjectile('carreau', couleur, c, 32, mult); son('drawKnife2', 0.35, 1.3); }
      else { tirerProjectile('feu', '#ff8a2a', c, 20, mult); son('thrusterFire_000', 0.18, 1.6); }
    });
  }
}
function pointArme() {
  const n = joueur.nodes[joueur.def.node]; const p = V();
  if (n) n.getWorldPosition(p); else p.copy(joueur.pos).setY(1.3);
  if (p.y < 0.8) p.y = 1.3;
  return p;
}
function tirerProjectile(type, couleur, cible, vitesse, mult, opts = {}) {
  const depart = pointArme();
  const dest = cible ? V(cible.pos.x, (cible.hover || 0) + 1.1 * (cible.boss ? Math.min(2, cible.boss.scale) * 0.8 : 1), cible.pos.z) : depart.clone().addScaledVector(V(Math.sin(joueur.angle), 0, Math.cos(joueur.angle)), 14);
  const dir = dest.clone().sub(depart).normalize();
  const mesh = type === 'carreau' ? meshCarreau(couleur) : meshBoule(couleur, opts.taille || 0.4);
  mesh.position.copy(depart); mesh.lookAt(dest); G.scene.add(mesh);
  projectiles.push({ mesh, pos: mesh.position, vel: dir.multiplyScalar(vitesse), vie: (opts.portee || 18) / vitesse, camp: 'joueur', type, mult, couleur, perce: opts.perce, touches: new Set(), largeur: opts.largeur || 0.7, onHit: opts.onHit, cible });
}

// ---------------- Sorts ----------------
function lancerSort(k) {
  const s = joueur.sorts[k];
  if (!s || joueur.mort) return;
  if ((joueur.cds[k] || 0) > 0) { son('error_001', 0.25); return; }
  if (joueur.energie < s.energie) { UI.toast('Pas assez d’énergie'); son('error_001', 0.25); return; }
  if (joueur.verrouT > 0.15 && !['rempart', 'souffle', 'ruee', 'purge', 'vampirisme'].includes(s.id)) return;
  joueur.energie -= s.energie; joueur.cds[k] = joueur.cdMax[k] || s.cd; joueur.combatT = 4;
  const def = joueur.def;
  const fin = () => joueur.jouer(def.idle);
  switch (s.id) {
    case 'fente': {
      const { dir } = directionVisee(5); faireFace(dir);
      joueur.jouer('2H_Melee_Attack_Slice', { boucle: false, vitesse: 1.5, forcer: true, fin }); joueur.verrouT = 0.42;
      programmer(0.2, () => {
        arcTaille(joueur.pos, joueur.angle - Math.PI / 2, s.portee, '#ff3a2a', Math.PI * 0.8, 0.32);
        arcTaille(joueur.pos, joueur.angle - Math.PI / 2, s.portee * 0.8, '#ffd0a0', Math.PI * 0.6, 0.25);
        const n = zoneDegats(joueur.pos, s.portee, s.mult, { cone: Math.PI * 0.8, dir, c1: '#ff4a3a', c2: '#7a0a0a', dot: { dps: joueur.st.degats * 0.18, t: 3, c: '#ff3a2a' } });
        son('knifeSlice', 0.55, 0.85); if (n) G.shake = 0.35;
      });
      break;
    }
    case 'charge': {
      const { dir, cible, point } = directionVisee(s.portee); faireFace(dir);
      const dmax = cible ? Math.max(0, Math.min(s.portee, dist2D(point, joueur.pos) - cible.rayon - 0.8)) : 7;
      joueur.jouer('Dodge_Forward', { boucle: false, vitesse: 1.6, forcer: true });
      joueur.dashT = 0.26; joueur.dashV = dir.clone().multiplyScalar(dmax / 0.26); joueur.verrouT = 0.55;
      son('cloth1', 0.6, 0.8);
      programmer(0.27, () => {
        joueur.jouer('2H_Melee_Attack_Chop', { boucle: false, vitesse: 1.7, forcer: true, fin });
        onde(joueur.pos, '#ffd36b', 4, 0.45); lueurSol(joueur.pos, '#ffb84a', 3.2, 0.5, 0.8);
        emettre(V(joueur.pos.x, 0.3, joueur.pos.z), { n: 30, c1: '#d8c8a8', c2: '#7a6a5a', vit: 6, vie: 0.6, taille: 0.5, hemi: true, grav: 4 });
        zoneDegats(joueur.pos, 3.2, s.mult, { stun: 1.2, c1: '#ffd36b' }); son('impactPlate_heavy_000', 0.6, 0.8); G.shake = 0.5;
      });
      break;
    }
    case 'tempete': {
      joueur.spinT = 2.4; joueur.spinTick = 0;
      joueur.jouer('2H_Melee_Attack_Spinning', { vitesse: 1.25, forcer: true });
      const anneaux = new THREE.Group();
      for (let i = 0; i < 3; i++) { const m = new THREE.Mesh(new THREE.RingGeometry(1.6 + i * 1.1, 2.2 + i * 1.1, 48, 1, 0, Math.PI * 1.2), new THREE.MeshBasicMaterial({ color: i === 1 ? '#ffffff' : '#9ab8ff', transparent: true, opacity: 0.55 - i * 0.12, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide })); m.rotation.x = -Math.PI / 2; m.position.y = 0.9 + i * 0.1; m.userData.v = 9 - i * 2; anneaux.add(m); }
      ajouterVfx(anneaux, (t, dt) => { anneaux.position.copy(joueur.pos); anneaux.children.forEach(m => (m.rotation.z -= m.userData.v * dt)); if (joueur.spinT <= 0) return false; });
      break;
    }
    case 'perforant': {
      const { dir, cible } = directionVisee(s.portee); faireFace(dir);
      joueur.jouer('2H_Ranged_Shoot', { boucle: false, vitesse: 1.4, forcer: true, fin }); joueur.verrouT = 0.35;
      programmer(0.2, () => { tirerProjectile('carreau', '#7dffb0', cible, 40, s.mult, { perce: true, portee: 17, largeur: 1.3 }); son('drawKnife2', 0.6, 0.8); });
      break;
    }
    case 'roulade': {
      const c = choisirCible(14);
      const arr = c ? V(joueur.pos.x - c.pos.x, 0, joueur.pos.z - c.pos.z).normalize() : V(-Math.sin(joueur.angle), 0, -Math.cos(joueur.angle));
      faireFace(arr.clone().negate());
      joueur.jouer('Dodge_Backward', { boucle: false, vitesse: 1.5, forcer: true, fin });
      joueur.dashT = 0.35; joueur.dashV = arr.multiplyScalar(s.portee / 0.35); joueur.invuln = 0.45; joueur.verrouT = 0.4; joueur.bonusTir = true;
      emettre(V(joueur.pos.x, 0.3, joueur.pos.z), { n: 16, c1: '#d0f0ff', c2: '#6aa0c0', vit: 3, vie: 0.5, taille: 0.4 }); son('cloth1', 0.6, 1.2);
      break;
    }
    case 'pluie': {
      const { dir, point } = directionVisee(s.portee); faireFace(dir);
      joueur.jouer('2H_Ranged_Shoot', { boucle: false, forcer: true, fin }); joueur.verrouT = 0.3;
      const centre = point.clone();
      const cercle = new THREE.Mesh(new THREE.RingGeometry(4.3, 4.5, 48), new THREE.MeshBasicMaterial({ color: '#7dffb0', transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
      cercle.rotation.x = -Math.PI / 2; cercle.position.set(centre.x, 0.1, centre.z);
      ajouterVfx(cercle, (t) => { cercle.material.opacity = 0.8 * (1 - t / 2.4); if (t > 2.4) return false; });
      for (let w = 0; w < 5; w++) programmer(0.3 + w * 0.4, () => {
        for (let i = 0; i < 9; i++) { const a = Math.random() * 6.28, r = Math.sqrt(Math.random()) * 4.2; emettre(V(centre.x + Math.cos(a) * r, 7, centre.z + Math.sin(a) * r), { n: 1, c1: '#ffffff', c2: '#7dffb0', dir: V(0, -1, 0), vit: 22, disp: 0, vie: 0.3, taille: 0.35, frein: 0 }); }
        programmer(0.3, () => { zoneDegats(centre, 4.4, s.mult, { slow: 2, c1: '#7dffb0', silence: true }); emettre(V(centre.x, 0.2, centre.z), { n: 14, c1: '#bfffd8', c2: '#3a9a6a', rayon: 3.8, vit: 2, vie: 0.4, taille: 0.3, hemi: true }); son('impactGeneric_light_000', 0.3, 1.3); });
      });
      break;
    }
    case 'bouleFeu': {
      const { dir, cible } = directionVisee(s.portee); faireFace(dir);
      joueur.jouer('Spellcast_Shoot', { boucle: false, vitesse: 1.5, forcer: true, fin }); joueur.verrouT = 0.32;
      programmer(0.22, () => {
        son('thrusterFire_000', 0.5, 0.9);
        tirerProjectile('feu', '#ff7a1a', cible, 21, 0, { taille: 0.7, portee: 15, onHit: (p) => {
          onde(p, '#ff8a2a', 3, 0.4); lueurSol(p, '#ff5a1a', 2.6, 0.5);
          emettre(p, { n: 40, c1: '#ffe08a', c2: '#ff3a00', vit: 7, vie: 0.6, taille: 0.6, grav: -1 });
          zoneDegats(p, 2.6, s.mult, { dot: { dps: joueur.st.degats * 0.22, t: 3, c: '#ff7a1a' }, c1: '#ffb84a', c2: '#ff3a00' });
          son('explosionCrunch_000', 0.45); G.shake = 0.3;
        } });
      });
      break;
    }
    case 'colonne': {
      const { dir, point } = directionVisee(s.portee); faireFace(dir);
      joueur.jouer('Spellcast_Raise', { boucle: false, vitesse: 1.3, forcer: true, fin }); joueur.verrouT = 0.5;
      const c = point.clone();
      telegraphe(c, 3.5, 0.8, '#ff8a2a', () => {
        const pil = new THREE.Group();
        for (let i = 0; i < 2; i++) { const m = new THREE.Mesh(new THREE.CylinderGeometry(i ? 1.2 : 2.2, i ? 1.6 : 3.2, 9, 24, 1, true), new THREE.MeshBasicMaterial({ color: i ? '#ffe0a0' : '#ff4a10', transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide, map: texRond() })); m.position.y = 4.5; pil.add(m); }
        pil.position.copy(c);
        ajouterVfx(pil, (t) => { const k = t / 0.7; if (k >= 1) return false; pil.scale.set(1 - k * 0.5, 0.3 + k, 1 - k * 0.5); pil.children.forEach(m => (m.material.opacity = 0.8 * (1 - k))); });
        emettre(V(c.x, 0.3, c.z), { n: 60, c1: '#ffe08a', c2: '#ff2a00', dir: V(0, 1, 0), vit: 14, disp: 2.5, rayon: 1.8, vie: 0.8, taille: 0.7, frein: 2 });
        zoneDegats(c, 3.5, s.mult, { stun: 0.8, air: true, dot: { dps: joueur.st.degats * 0.15, t: 2, c: '#ff7a1a' }, c1: '#ffb84a', c2: '#ff3a00' });
        son('explosionCrunch_000', 0.6, 0.8); G.shake = 0.5;
      });
      break;
    }
    case 'meteore': {
      const { dir, point } = directionVisee(s.portee); faireFace(dir);
      joueur.jouer('Spellcast_Long', { boucle: false, vitesse: 1.2, forcer: true, fin }); joueur.verrouT = 1.1;
      const c = point.clone();
      telegraphe(c, 6, 1.5, '#ffb030', () => {
        G.shake = 1.1; son('lowFrequency_explosion_000', 0.8); son('explosionCrunch_000', 0.6, 0.6);
        onde(c, '#ffd27a', 9, 0.7); onde(c, '#ff5a1a', 7, 0.9);
        emettre(V(c.x, 0.5, c.z), { n: 160, c1: '#fff0b0', c2: '#ff2a00', vit: 14, vie: 1.0, taille: 0.9, grav: 4, hemi: true });
        zoneDegats(c, 6, s.mult, { stun: 0.6, c1: '#ffe08a', c2: '#ff3a00' });
        const brule = lueurSol(c, '#ff4a10', 5.5, 3, 0.9);
        let tick = 0; ajouterVfx(new THREE.Group(), (t, dt) => { tick += dt; if (tick > 0.5) { tick = 0; zoneDegats(c, 5.5, 0.3, { silence: true }); } if (Math.random() < 0.6) emettre(V(c.x + rnd(-5, 5), 0.2, c.z + rnd(-5, 5)), { n: 1, c1: '#ffb84a', c2: '#ff2a00', dir: V(0, 1, 0), vit: 2.5, disp: 0.3, vie: 0.7, taille: 0.5 }); if (t > 3) return false; });
      });
      // le météore tombe
      const m = meshBoule('#ff6a1a', 1.6); m.position.set(c.x + 9, 22, c.z - 9); G.scene.add(m);
      ajouterVfx(m, (t) => { const k = Math.min(1, (t - 0.3) / 1.2); if (t < 0.3) return; m.position.set(c.x + 9 * (1 - k), 22 * (1 - k) + 0.5, c.z - 9 * (1 - k)); emettre(m.position, { n: 4, c1: '#ffe08a', c2: '#ff3a00', vit: 1, vie: 0.6, taille: 1.0, rayon: 0.8 }); if (k >= 1) return false; });
      break;
    }
    case 'rempart': {
      joueur.bouclier = joueur.st.pvMax * 0.25; joueur.bouclierT = 4;
      bulle(joueur, () => joueur.bouclier <= 0 || joueur.bouclierT <= 0);
      onde(joueur.pos, '#8fd3ff', 3, 0.5); son('forceField_000', 0.5, 1.4);
      break;
    }
    case 'execution': {
      const portee = Math.max(s.portee, joueur.st.portee);
      const { dir, cible } = directionVisee(portee); faireFace(dir);
      const anim = joueur.armeType === 'epee' ? '2H_Melee_Attack_Chop' : joueur.armeType === 'arbalete' ? '2H_Ranged_Shoot' : 'Spellcast_Shoot';
      joueur.jouer(anim, { boucle: false, vitesse: 1.3, forcer: true, fin }); joueur.verrouT = 0.4;
      const bas = cible && cible.pv / cible.pvMax < 0.35; const mult = s.mult * (bas ? 3 : 1);
      programmer(0.25, () => {
        if (!cible || cible.mort) return;
        if (joueur.armeType === 'epee') { if (dist2D(cible.pos, joueur.pos) - cible.rayon < portee + 1) { arcTaille(joueur.pos, joueur.angle - Math.PI / 2, 3.6, '#ff2a3a', Math.PI * 0.5, 0.35); blesser(cible, mult, { c1: '#ff3a4a', c2: '#5a0008' }); son('impactPlate_heavy_000', 0.6, 0.7); } }
        else tirerProjectile(joueur.armeType === 'arbalete' ? 'carreau' : 'feu', '#ff2a3a', cible, 34, mult, { taille: 0.6 });
        if (bas) { G.shake = 0.5; UI.nombre(V(cible.pos.x, 3, cible.pos.z), 'EXÉCUTION', 'crit'); }
      });
      break;
    }
    case 'vampirisme': { joueur.vampT = 5; son('forceField_000', 0.4, 1.6); onde(joueur.pos, '#ff4a6a', 3, 0.5); emettre(V(joueur.pos.x, 1, joueur.pos.z), { n: 30, c1: '#ff8aa0', c2: '#8a0020', vit: 3, vie: 0.7, taille: 0.4 }); break; }
    case 'purge': { joueur.slowT = 0; joueur.verrouT = 0; joueur.invuln = 1.2; son('forceField_000', 0.5, 1.2); onde(joueur.pos, '#e0c8ff', 3.5, 0.5); emettre(V(joueur.pos.x, 1, joueur.pos.z), { n: 40, c1: '#ffffff', c2: '#a070ff', vit: 4, vie: 0.6, taille: 0.4 }); break; }
    case 'souffle': { joueur.soinT = 3; son('confirmation_001', 0.4); onde(joueur.pos, '#9dff8a', 2.5, 0.6); break; }
    case 'ruee': { joueur.sprintT = 3; joueur.slowT = 0; son('cloth1', 0.6, 1.4); emettre(V(joueur.pos.x, 0.4, joueur.pos.z), { n: 20, c1: '#fff8c0', c2: '#ffd04a', vit: 3, vie: 0.5, taille: 0.35 }); break; }
  }
}
// bulle de protection (joueur, rivaux, coéquipiers) : un seul matériau partagé
let matBulle = null;
function bulle(cible, fini) {
  matBulle = matBulle || new THREE.ShaderMaterial({ transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    vertexShader: 'varying vec3 vN; varying vec3 vV; void main(){ vec4 mv=modelViewMatrix*vec4(position,1.0); vN=normalize(normalMatrix*normal); vV=normalize(-mv.xyz); gl_Position=projectionMatrix*mv; }',
    fragmentShader: 'varying vec3 vN; varying vec3 vV; void main(){ float f=pow(1.0-abs(dot(vN,vV)),2.5); gl_FragColor=vec4(vec3(0.45,0.8,1.0)*(f*1.6+0.06), f*0.9+0.05); }' });
  const m = new THREE.Mesh(new THREE.SphereGeometry(1.5, 24, 16), matBulle);
  ajouterVfx(m, () => { m.position.set(cible.pos.x, 1.1, cible.pos.z); if (cible.mort || fini()) return false; });
}
function rempartIA(e) {
  e.cdRempart = 18; e.bouclierIA = e.pvMax * 0.25; e.bouclierT = 4;
  bulle(e, () => e.bouclierIA <= 0 || e.bouclierT <= 0);
  onde(e.pos, '#8fd3ff', 3, 0.5); son('forceField_000', 0.45, 1.4);
  UI.nombre(V(e.pos.x, 2.8, e.pos.z), 'Rempart', 'info');
}
function boirePotion() {
  if ((joueur.cds.POT || 0) > 0 || joueur.potions <= 0 || joueur.mort) { son('error_001', 0.25); return; }
  joueur.potions--; J.potions = joueur.potions; joueur.cds.POT = 60; joueur.potionT = 1;
  son('metalLatch', 0.5, 1.4); emettre(V(joueur.pos.x, 1.2, joueur.pos.z), { n: 20, c1: '#ff8a9a', c2: '#ff2a4a', vit: 2, vie: 0.7, taille: 0.35, monte: 2 });
  sauver();
}

// ---------------- Mise à jour du joueur ----------------
function majJoueur(dt) {
  const j = joueur, st = j.st;
  for (const k in j.cds) j.cds[k] = Math.max(0, j.cds[k] - dt);
  j.atkT -= dt; j.verrouT -= dt; j.invuln -= dt; j.combatT -= dt;
  if (j.mort) { j.maj(dt); return; }
  // régénération
  j.energie = Math.min(st.energieMax, j.energie + dt * (6 + st.energieMax * 0.012));
  const regen = j.combatT > 0 ? st.regen * 0.25 : st.regen * 3;
  j.pv = Math.min(st.pvMax, j.pv + st.pvMax * regen / 100 * dt);
  if (j.soinT > 0) { j.soinT -= dt; const h = st.pvMax * 0.1 * dt; j.pv = Math.min(st.pvMax, j.pv + h); if (Math.random() < 0.5) emettre(V(j.pos.x, 0.4, j.pos.z), { n: 1, c1: '#bfffb0', c2: '#3aff4a', dir: V(0, 1, 0), vit: 2, rayon: 0.7, vie: 0.8, taille: 0.3 }); }
  if (j.potionT > 0) { j.potionT -= dt; j.pv = Math.min(st.pvMax, j.pv + st.pvMax * 0.4 * dt); }
  if (j.bouclierT > 0) { j.bouclierT -= dt; if (j.bouclierT <= 0) j.bouclier = 0; }
  if (j.sprintT > 0) { j.sprintT -= dt; if (Math.random() < 0.4) emettre(V(j.pos.x, 0.2, j.pos.z), { n: 1, c1: '#fff2b0', c2: '#ffcf4a', vit: 0.5, vie: 0.5, taille: 0.3 }); }
  if (j.slowT > 0) j.slowT -= dt;
  if (j.vampT > 0) j.vampT -= dt;
  // arme de haut tier : aura
  const tier = J.equip.arme?.tier || 1;
  if (tier >= 6 && Math.random() < dt * (tier - 4) * 6) emettre(pointArme(), { n: 1, c1: TIERS[tier].color, c2: '#ffffff', vit: 0.6, vie: 0.6, taille: 0.22, rayon: 0.3 });
  // ruée / roulade
  if (j.dashT > 0) { j.dashT -= dt; deplacer(j, j.dashV.x * dt, j.dashV.z * dt); if (Math.random() < 0.7) emettre(V(j.pos.x, 0.5, j.pos.z), { n: 1, c1: '#ffffff', c2: '#c8b8a0', vit: 0.5, vie: 0.4, taille: 0.4 }); j.maj(dt); return; }
  // tempête d'acier
  if (j.spinT > 0) {
    j.spinT -= dt; j.spinTick -= dt;
    if (j.spinTick <= 0) { j.spinTick = 0.4; zoneDegats(j.pos, SORTS.tempete.portee, SORTS.tempete.mult, { c1: '#c7d6ff', c2: '#5a7aff' }); son('knifeSlice2', 0.35, 1.2); }
    if (j.spinT <= 0) j.jouer(j.def.idle);
  }
  // déplacement
  let mx = entree.jx, my = entree.jy;
  const k = entree.clavier;
  if (k.ArrowLeft) mx -= 1; if (k.ArrowRight) mx += 1; if (k.ArrowUp) my += 1; if (k.ArrowDown) my -= 1;
  const m = Math.min(1, Math.hypot(mx, my));
  const bloque = j.verrouT > 0 && j.spinT <= 0;
  if (m > 0.12 && !bloque) {
    const dir = DIR_DROITE.clone().multiplyScalar(mx).addScaledVector(DIR_HAUT, my).normalize();
    let v = st.vitesse * (j.sprintT > 0 ? 1.6 : 1) * (j.slowT > 0 ? 0.6 : 1) * (j.spinT > 0 ? 0.7 : 1); // vitesse constante, peu importe l'inclinaison du joystick
    deplacer(j, dir.x * v * dt, dir.z * v * dt);
    const vise = (entree.atk || entree.clavier[' ']) && j.cible && !j.cible.mort && dist2D(j.cible.pos, j.pos) - j.cible.rayon < st.portee + 0.5;
    if (j.spinT <= 0 && !vise) { j.angle = tourner(j.angle, Math.atan2(dir.x, dir.z), dt * 14); j.root.rotation.y = j.angle; }
    if (j.spinT <= 0 && (j.atkT < 0.1 || !entree.atk)) j.jouer(j.def.run);
    j.pasT -= dt * v; if (j.pasT <= 0) { j.pasT = 2.4; son(Math.random() < 0.5 ? 'footstep_concrete_000' : 'footstep_concrete_001', 0.12); }
  } else if (!bloque && j.spinT <= 0) {
    const c = j.courante; const n = c ? c.getClip().name : '';
    if (n === j.def.run || n === 'Walking_A') j.jouer(j.def.idle);
  }
  if ((entree.atk || entree.clavier[' ']) && !(arene && arene.t > 0)) attaquer(dt);
  j.maj(dt);
}

// ---------------- IA des ennemis ----------------
function majEnnemis(dt) {
  for (let i = ennemis.length - 1; i >= 0; i--) {
    const e = ennemis[i];
    const d = dist2D(e.pos, joueur.pos);
    if (e.mort) {
      if (e.descendre) { e.root.position.y -= dt * 0.8; if (e.root.position.y < -2.5) { G.scene.remove(e.root); UI.retirerPlaque(e); ennemis.splice(i, 1); continue; } }
      if (d < 40) e.maj(dt);
      continue;
    }
    const proche = d < 42 || e.combattant;
    e.root.visible = d < 36;
    if (!proche) continue;
    // effets
    for (let k = e.dots.length - 1; k >= 0; k--) {
      const o = e.dots[k]; o.t -= dt; o.acc = (o.acc || 0) + dt;
      if (o.acc >= 0.5) { o.acc = 0; e.pv -= o.dps * 0.5; UI.nombre(V(e.pos.x, e.hauteurPlaque * 0.7, e.pos.z), Math.round(o.dps * 0.5), 'info'); emettre(V(e.pos.x, 1, e.pos.z), { n: 3, c1: o.c, c2: '#ffffff', vit: 1.5, vie: 0.4, taille: 0.25 }); if (e.pv <= 0) { tuer(e); break; } }
      if (o.t <= 0) e.dots.splice(k, 1);
    }
    if (e.mort) continue;
    if (e.stunT > 0) { e.stunT -= dt; if (Math.random() < dt * 8) emettre(V(e.pos.x, e.hauteurPlaque, e.pos.z), { n: 1, c1: '#fff7a0', c2: '#ffd040', vit: 0.6, vie: 0.5, taille: 0.25, rayon: 0.4 }); e.maj(dt * 0.15); continue; }
    if (sautEnCours(e, dt)) continue;
    if (e.airT > 0) { e.airT -= dt; e.root.position.y = Math.sin((0.6 - e.airT) / 0.6 * Math.PI) * 1.6; e.maj(dt); continue; } else if (!e.boss && !e.sautT) e.root.position.y = e.hover;
    if (e.slowT > 0) e.slowT -= dt;
    e.atkT -= dt;
    if (e.etat === 'idle') { if (d < 11 || allies.some(a => !a.mort && dist2D(a.pos, e.pos) < 8)) reveiller(e); e.maj(dt); continue; }
    if (e.etat === 'dormant') {
      const zone = monde.zoneDe(joueur.pos.x, joueur.pos.z);
      if (zone === e.salle.id || d < 13) reveiller(e);
      e.maj(dt); continue;
    }
    if (e.combattant) { majCombattant(e, dt); e.maj(dt); continue; }
    e.tc = cibleIA(e);
    if (!e.tc) { e.jouer(e.def.model === 'Dragon_Evolved' ? 'Flying_Idle' : 'Idle_Combat'); e.maj(dt); continue; }
    const dc = dist2D(e.pos, e.tc.pos);
    if (e.boss) { UI.boss(e); majBoss(e, dc, dt); e.maj(dt); continue; }
    majMob(e, dc, dt);
    e.maj(dt);
  }
}
function avancerVers(e, cible, dt, vitesse) {
  const dir = V(cible.x - e.pos.x, 0, cible.z - e.pos.z); const l = dir.length(); if (l < 0.01) return;
  dir.divideScalar(l);
  // séparation
  for (const o of ennemis) { if (o === e || o.mort) continue; const dx = e.pos.x - o.pos.x, dz = e.pos.z - o.pos.z, dd = Math.hypot(dx, dz); const r = e.rayon + o.rayon + 0.3; if (dd < r && dd > 0.01) { dir.x += dx / dd * (r - dd) * 1.5; dir.z += dz / dd * (r - dd) * 1.5; } }
  dir.normalize();
  const v = vitesse * (e.slowT > 0 ? 0.6 : 1) * dt;
  const ax = e.pos.x, az = e.pos.z;
  deplacer(e, dir.x * v, dir.z * v, Math.min(e.rayon * 0.8, 1.1));
  // détection de blocage dans le décor : après 0,8 s coincé, il bondit près de sa cible
  const bouge = Math.hypot(e.pos.x - ax, e.pos.z - az);
  e.bloqueT = bouge < v * 0.3 ? (e.bloqueT || 0) + dt : Math.max(0, (e.bloqueT || 0) - dt * 2);
  if (e.bloqueT > 0.8) { e.bloqueT = 0; if (l < 18) bondir(e, cible); }
  e.angle = tourner(e.angle, Math.atan2(dir.x, dir.z), dt * 10); e.root.rotation.y = e.angle;
}
function faceJoueur(e, dt, k = 10) { const c = e.tc || joueur; e.angle = tourner(e.angle, Math.atan2(c.pos.x - e.pos.x, c.pos.z - e.pos.z), dt * k); e.root.rotation.y = e.angle; }
function majMob(e, d, dt) {
  const def = e.def;
  const c = e.tc;
  if (e.attaqueT > 0) { e.attaqueT -= dt; faceJoueur(e, dt, 6); return; }
  const portee = def.portee;
  if (d > portee + e.rayon) { avancerVers(e, c.pos, dt, def.vitesse); e.jouer('Running_A'); return; }
  faceJoueur(e, dt);
  if (e.atkT > 0) { e.jouer('Idle_Combat'); return; }
  e.atkT = def.type === 'melee' ? rnd(1.6, 2.0) : rnd(2.2, 2.8);
  e.attaqueT = 0.7;
  e.jouer(def.atk, { boucle: false, forcer: true, vitesse: 1.1, fin: () => e.jouer('Idle_Combat') });
  if (def.type === 'melee') programmer(0.45, () => { if (!e.mort && e.stunT <= 0 && !c.mort && dist2D(e.pos, c.pos) < portee + e.rayon + 0.9) { infliger(e, c, e.dmg); son('impactGeneric_light_000', 0.3); } });
  else programmer(0.4, () => { if (!e.mort && e.stunT <= 0) tirEnnemi(e, def.type === 'caster' ? 'feu' : 'carreau', e.dmg); });
}
function tirEnnemi(e, type, dmg, dirForcee = null, vitesse = null) {
  const depart = V(e.pos.x, 1.3 * (e.boss ? Math.min(2.2, e.boss.scale) * 0.7 : 1) + (e.hover || 0), e.pos.z);
  const vise = e.tc || joueur;
  const dest = V(vise.pos.x, 1.1 + (vise.hover || 0), vise.pos.z);
  const dir = dirForcee ? dirForcee.clone() : dest.sub(depart).normalize();
  const coul = type === 'feu' ? '#ff4a2a' : '#c8ff9a';
  const mesh = type === 'feu' ? meshBoule(coul, e.boss ? 0.7 : 0.45) : meshCarreau(coul);
  mesh.position.copy(depart); mesh.lookAt(depart.clone().add(dir)); G.scene.add(mesh);
  const v = vitesse || (type === 'feu' ? 11 : 16);
  projectiles.push({ mesh, pos: mesh.position, vel: dir.multiplyScalar(v), vie: 16 / v * 1.4, camp: e.camp === 'allie' ? 'allie' : 'ennemi', src: e, type, dmg, couleur: coul, touches: new Set(), largeur: 0.75 });
  son(type === 'feu' ? 'thrusterFire_000' : 'drawKnife2', 0.15, type === 'feu' ? 1.2 : 1.5);
}

// ---------------- Boss ----------------
function majBoss(e, d, dt) {
  const b = e.boss; const enrage = e.pv < e.pvMax * 0.3;
  const tc = e.tc;
  if (e.chargeT > 0) { e.chargeT -= dt; deplacer(e, e.chargeV.x * dt, e.chargeV.z * dt, 1.2); emettre(V(e.pos.x, 1.5, e.pos.z), { n: 3, c1: '#ffb84a', c2: '#ff2a00', vit: 2, vie: 0.5, taille: 0.8, rayon: 1.5 }); for (const c of adversaires(e)) if (dist2D(e.pos, c.pos) < 2.8 && !e.chargeTouches.has(c)) { e.chargeTouches.add(c); infliger(e, c, e.dmg * 3.0); } if (e.chargeT <= 0) e.jouer('Flying_Idle'); return; }
  if (e.attaqueT > 0) { e.attaqueT -= dt; return; }
  e.specT -= dt * (enrage ? 1.4 : 1);
  if (e.specT <= 0) { capaciteBoss(e); e.specT = rnd(5.5, 7); return; }
  const ranged = b.id === 'archere' || b.id === 'necro';
  const portee = ranged ? 10 : e.def.portee + e.rayon;
  if (d > portee) { avancerVers(e, tc.pos, dt, e.def.vitesse * (enrage ? 1.25 : 1)); e.jouer(b.id === 'horreur' ? 'Fast_Flying' : 'Running_A'); return; }
  faceJoueur(e, dt, 6);
  if (e.atkT > 0) { e.jouer(b.id === 'horreur' ? 'Flying_Idle' : 'Idle_Combat'); return; }
  e.atkT = ranged ? 1.6 : 2.0; e.attaqueT = 0.8;
  if (b.id === 'horreur') { e.jouer(Math.random() < 0.5 ? 'Punch' : 'Headbutt', { boucle: false, forcer: true, fin: () => e.jouer('Flying_Idle') }); programmer(0.5, () => { if (!e.mort && !tc.mort && dist2D(e.pos, tc.pos) < portee + 1.2) infliger(e, tc, e.dmg); }); }
  else if (ranged) { e.jouer(e.def.atk, { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') }); programmer(0.4, () => { if (!e.mort) tirEnnemi(e, b.id === 'necro' ? 'feu' : 'carreau', e.dmg * 0.75); }); }
  else { e.jouer('2H_Melee_Attack_Chop', { boucle: false, forcer: true, vitesse: 0.9, fin: () => e.jouer('Idle_Combat') }); programmer(0.55, () => { if (!e.mort && !tc.mort && dist2D(e.pos, tc.pos) < portee + 1.2) { infliger(e, tc, e.dmg); if (tc === joueur) G.shake = 0.4; } }); }
}
function invoquer(e, n) {
  for (let i = 0; i < n; i++) {
    const a = Math.random() * 6.28; const p = V(e.pos.x + Math.cos(a) * 4, 0, e.pos.z + Math.sin(a) * 4);
    if (!libre(p.x, p.z, 0.5)) continue;
    const m = creerEnnemi(MOBS.minion, p, modeActuel.mobTier, -2);
    m.invoque = true; m.maitre = e; m.etat = 'chasse';
    m.jouer('Spawn_Ground_Skeletons', { boucle: false, fin: () => m.jouer('Idle_Combat') }); m.attaqueT = 1.2;
    emettre(V(p.x, 0.3, p.z), { n: 20, c1: '#7a5a9a', c2: '#2a1a3a', vit: 3, vie: 0.8, taille: 0.5, hemi: true });
  }
}
function capaciteBoss(e) {
  const b = e.boss; e.cycle++;
  const pj = (e.tc || joueur).pos.clone();
  if (b.id === 'gardien') {
    if (e.cycle % 2) {
      // bond et fracas
      e.jouer('1H_Melee_Attack_Jump_Chop', { boucle: false, forcer: true, vitesse: 0.8, fin: () => e.jouer('Idle_Combat') });
      e.sautA = e.pos.clone(); e.sautB = pointLibrePres(pj, 0, 1.2, 1.0); e.sautD = e.sautT = 1.2; e.sautH = 4; e.attaqueT = 1.6;
      telegraphe(pj, 3.8, 1.2, '#ff2a2a', () => { G.shake = 1; onde(pj, '#ff8a3a', 6, 0.6); emettre(V(pj.x, 0.3, pj.z), { n: 50, c1: '#d8c8a8', c2: '#6a5a4a', vit: 8, vie: 0.8, taille: 0.6, hemi: true, grav: 6 }); son('impactPlate_heavy_000', 0.8, 0.6); toucherZone(e, pj, 3.8, e.dmg * 3.4, { slow: 2.5 }); });
    } else {
      e.jouer('2H_Melee_Attack_Spinning', { vitesse: 1.2, forcer: true }); e.attaqueT = 1.6;
      const c = e.pos.clone();
      telegraphe(c, 5.5, 1.4, '#ff2a2a', () => { onde(c, '#ffd0a0', 6, 0.5); son('knifeSlice', 0.7, 0.6); toucherZone(e, e.pos, 5.9, e.dmg * 2.9); e.jouer('Idle_Combat'); });
    }
  } else if (b.id === 'archere') {
    if (e.cycle % 3 === 0) { e.jouer('Spellcast_Summon', { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') }); e.attaqueT = 1.2; invoquer(e, 2); UI.toast('L’Archère appelle ses morts !'); }
    else {
      const base = Math.atan2(pj.x - e.pos.x, pj.z - e.pos.z); e.attaqueT = 1.5;
      e.jouer('2H_Ranged_Aiming' in e.actions ? '2H_Ranged_Shoot' : e.def.atk, { boucle: false, forcer: true, vitesse: 0.6, fin: () => e.jouer('Idle_Combat') });
      telegraphe(e.pos, 14, 1.0, '#ff2a2a', () => { for (let i = -3; i <= 3; i++) { const a = base + i * 0.17; tirEnnemi(e, 'carreau', e.dmg * 1.5, V(Math.sin(a), 0, Math.cos(a)), 19); } }, { cone: 1.2, angle: base - Math.PI / 2 });
    }
  } else if (b.id === 'necro') {
    if (e.cycle % 3 === 0) { e.jouer('Spellcast_Summon', { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') }); e.attaqueT = 1.4; invoquer(e, 3); UI.toast('Le Nécromancien relève les morts !'); }
    else {
      e.jouer('Spellcast_Shoot', { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') }); e.attaqueT = 1.0;
      for (let i = 0; i < 5; i++) {
        const p = i === 0 ? pj.clone() : pj.clone().add(V(rnd(-5, 5), 0, rnd(-5, 5)));
        telegraphe(p, 2.6, 1.3 + i * 0.12, '#ff2a2a', () => { emettre(V(p.x, 0.4, p.z), { n: 30, c1: '#ff8aff', c2: '#ff1a4a', vit: 6, vie: 0.6, taille: 0.6, hemi: true }); onde(p, '#ff3a6a', 3, 0.4); son('explosionCrunch_000', 0.3, 1.2); toucherZone(e, p, 2.6, e.dmg * 2.4); });
      }
    }
  } else if (b.id === 'horreur') {
    const r = e.cycle % 3;
    const base = Math.atan2(pj.x - e.pos.x, pj.z - e.pos.z);
    if (r === 1) {
      e.attaqueT = 1.9; e.jouer('Headbutt', { boucle: false, forcer: true, vitesse: 0.6, fin: () => e.jouer('Flying_Idle') });
      e.angle = base; e.root.rotation.y = base;
      const c = e.pos.clone();
      telegraphe(c, 11, 1.3, '#ff2a2a', () => {
        son('thrusterFire_000', 0.9, 0.6); G.shake = 0.6;
        for (let i = 0; i < 70; i++) { const a = base + rnd(-0.6, 0.6); emettre(V(c.x, 2.4, c.z), { n: 1, c1: '#ffe08a', c2: '#ff2a00', dir: V(Math.sin(a), -0.05, Math.cos(a)), vit: 16, disp: 1, vie: 0.7, taille: 1.0, frein: 1 }); }
        toucherZone(e, c, 11, e.dmg * 3.6, { cone: { dir: V(Math.sin(base), 0, Math.cos(base)), cos: Math.cos(0.65) } });
      }, { cone: 1.3, angle: base - Math.PI / 2 });
    } else if (r === 2) {
      e.attaqueT = 1.2; const dir = V(Math.sin(base), 0, Math.cos(base));
      telegraphe(e.pos, 18, 1.1, '#ff2a2a', () => { e.chargeT = 0.6; e.chargeV = dir.clone().multiplyScalar(30); e.chargeTouches = new Set(); e.jouer('Fast_Flying', { vitesse: 2 }); son('lowFrequency_explosion_000', 0.5, 1.2); }, { ligne: true, largeur: 3.4, angle: base + Math.PI });
      e.angle = base; e.root.rotation.y = base;
    } else {
      e.attaqueT = 1; e.jouer('Punch', { boucle: false, forcer: true, fin: () => e.jouer('Flying_Idle') });
      for (let i = 0; i < 6; i++) {
        const p = i === 0 ? pj.clone() : pj.clone().add(V(rnd(-6, 6), 0, rnd(-6, 6)));
        telegraphe(p, 3, 1.6 + i * 0.1, '#ff2a2a', () => { G.shake = 0.5; emettre(V(p.x, 0.5, p.z), { n: 40, c1: '#fff0b0', c2: '#ff3a00', vit: 8, vie: 0.7, taille: 0.7, hemi: true }); onde(p, '#ff8a2a', 4, 0.5); son('explosionCrunch_000', 0.4, 0.8); toucherZone(e, p, 3, e.dmg * 2.6); });
        const m = meshBoule('#ff5a1a', 0.9); m.position.set(p.x + 6, 18, p.z - 6); G.scene.add(m);
        const dur = 1.6 + i * 0.1;
        ajouterVfx(m, (t) => { const k = t / dur; if (k >= 1) return false; m.position.set(p.x + 6 * (1 - k), 18 * (1 - k), p.z - 6 * (1 - k)); emettre(m.position, { n: 2, c1: '#ffe08a', c2: '#ff3a00', vit: 0.5, vie: 0.4, taille: 0.6 }); });
      }
    }
  }
}

// ---------------- Projectiles ----------------
function majProjectiles(dt) {
  for (let i = projectiles.length - 1; i >= 0; i--) {
    const p = projectiles[i];
    p.vie -= dt; p.pos.addScaledVector(p.vel, dt);
    if (p.type === 'feu') emettre(p.pos, { n: 2, c1: '#ffe08a', c2: p.couleur, vit: 0.6, vie: 0.35, taille: p.camp === 'joueur' ? 0.55 : 0.6 });
    else if (Math.random() < 0.6) emettre(p.pos, { n: 1, c1: p.couleur, c2: '#ffffff', vit: 0.2, vie: 0.25, taille: 0.2 });
    let fini = p.vie <= 0 || !monde.marche(p.pos.x, p.pos.z);
    if (!fini && p.camp === 'joueur') {
      for (const e of vivants()) {
        if (p.touches.has(e)) continue;
        if (dist2D(e.pos, p.pos) < e.rayon + p.largeur * 0.6) {
          p.touches.add(e);
          if (p.onHit) { p.onHit(p.pos.clone()); fini = true; break; }
          blesser(e, p.mult || 1, { c1: p.couleur });
          if (!p.perce) { fini = true; break; }
        }
      }
    } else if (!fini && p.camp === 'allie') {
      for (const e of vivants()) if (dist2D(e.pos, p.pos) < e.rayon + 0.5 && p.pos.y < 2.6 + (e.hover || 0) * 2) { infliger(p.src, e, p.dmg); fini = true; break; }
    } else if (!fini && p.camp === 'ennemi') {
      for (const c of equipeJoueur()) if (dist2D(c.pos, p.pos) < 0.85 && p.pos.y < 2.6) { infliger(p.src, c, p.dmg); fini = true; emettre(p.pos, { n: 12, c1: '#ffd0a0', c2: p.couleur, vit: 3, vie: 0.4, taille: 0.4 }); break; }
    }
    if (fini) {
      if (p.onHit && !p.touches.size) p.onHit(p.pos.clone());
      else if (p.type === 'feu' && p.camp === 'ennemi') emettre(p.pos, { n: 10, c1: '#ffb84a', c2: '#ff2a00', vit: 3, vie: 0.4, taille: 0.4 });
      G.scene.remove(p.mesh); projectiles.splice(i, 1);
    }
  }
}

// ---------------- Inventaire / commerce ----------------
function ajouterSac(it, silencieux = false) {
  if (it.cat === 'potion') { J.potions += it.n || 1; if (joueur) joueur.potions = J.potions; return; }
  if (it.cat === 'butin') { const ex = J.sac.find(x => x.cat === 'butin' && x.type === it.type); if (ex) { ex.n += it.n; return; } }
  if (J.sac.length >= 40) { UI.toast('Sac plein : ' + nomObjet(it) + ' perdu'); return; }
  J.sac.push(it);
  if (!silencieux) UI.toast('+ ' + nomObjet(it));
}
const API = {
  etat: () => J,
  son,
  touche: (k, bas) => {
    if (transition) return;
    if (k === 'ATK') { entree.atk = bas; return; }
    if (!bas) return;
    if (arene && arene.t > 0) return;
    if (k === 'POT') return boirePotion();
    if (k === 'CIBLE') { const c = choisirCible(16); joueur.cibleVerrou = joueur.cibleVerrou ? null : c; if (joueur.cibleVerrou) UI.toast('Cible : ' + (c.boss ? c.boss.nom : c.def.nom)); son('click_001', 0.4); return; }
    lancerSort(k);
  },
  equiper: (id) => {
    const i = J.sac.findIndex(x => x.id === id); if (i < 0) return;
    const it = J.sac[i]; const slot = it.cat === 'arme' ? 'arme' : it.type;
    if (!peutPorter(it)) { const nomM = MAITRISES.find(m => m.id === it.type).nom; UI.toast(`Niveau requis : ${nomM} ${niveauRequis(it)} (tu es niveau ${niveauDe(it.type)})`); son('error_001', 0.4); return; }
    const ipAvant = statsHeros(J.equip).ip;
    J.sac.splice(i, 1); if (J.equip[slot]) J.sac.push(J.equip[slot]); J.equip[slot] = it;
    const ipApres = statsHeros(J.equip).ip; if (ipApres !== ipAvant) setTimeout(() => UI.toast(`Puissance ${ipAvant} → ${ipApres} ${ipApres > ipAvant ? '▲' : '▼'}`), 300);
    son('metalLatch', 0.5); recalculer(); construireJoueur(); sauver();
    UI.toast(nomObjet(it) + ' équipé');
  },
  retirer: (slot) => { const it = J.equip[slot]; if (!it) return; if (slot === 'arme') { UI.toast('Garde au moins une arme en main'); return; } J.sac.push(it); J.equip[slot] = null; recalculer(); construireJoueur(); sauver(); },
  acheter: (it) => {
    const prix = valeurObjet(it);
    if (J.argent < prix) { UI.toast('Pas assez d’argent'); son('error_001', 0.3); return; }
    if (it.cat !== 'potion' && J.sac.length >= 40) { UI.toast('Sac plein'); return; }
    J.argent -= prix; const copie = { ...it, id: Date.now() + Math.floor(Math.random() * 1e6) };
    ajouterSac(copie, true); son('handleCoins', 0.6); UI.toast('Acheté : ' + nomObjet(it)); sauver();
  },
  vendre: (id) => {
    const i = J.sac.findIndex(x => x.id == id); if (i < 0) return;
    const it = J.sac[i]; const p = prixVente(it) * (it.n || 1);
    J.argent += p; J.sac.splice(i, 1); son('handleCoins', 0.6); UI.toast(`Vendu : ${nomObjet(it)} (+${p.toLocaleString('fr-FR')})`); sauver();
  },
  vendreButin: () => { let t = 0; J.sac = J.sac.filter(it => { if (it.cat === 'butin') { t += prixVente(it) * it.n; return false; } return true; }); J.argent += t; son('handleCoins', 0.7); UI.toast(`Butin vendu : +${t.toLocaleString('fr-FR')}`); sauver(); },
  rangerPotion: (id) => { const i = J.sac.findIndex(x => x.id == id); if (i >= 0) { J.potions += J.sac[i].n || 1; joueur.potions = J.potions; J.sac.splice(i, 1); sauver(); } },
  entrer: (id) => entrerDonjon(id),
  arene: (format) => entrerArene(format),
  acheterIle: (type, taille) => acheterIle(type, taille),
  allerIle: (id) => { const ile = iles().find(i => i.id === id); if (ile) entrerIle(ile); },
  piller: () => entrerIle(ileBot()),
  construire: (ile, plot, t) => construire(ile, plot, t),
  get ile() { return API_ILE; },
  infosIle: (i) => infosIle(i),
  acheterArene: (it) => {
    const prix = prixTrophees(it);
    if ((J.trophees || 0) < prix) { UI.toast('Pas assez de trophées'); son('error_001', 0.3); return; }
    if (J.sac.length >= 40) { UI.toast('Sac plein'); return; }
    J.trophees -= prix; ajouterSac({ ...it, id: Date.now() + Math.floor(Math.random() * 1e6) }, true);
    son('jingle_loot', 0.5); UI.toast('Acheté : ' + nomObjet(it)); sauver();
  },
  inviter: (data) => {
    UI.toast(`Invitation envoyée à ${data.nom}…`); son('click_001', 0.4);
    setTimeout(() => {
      if (Math.random() < 0.12) { UI.toast(`${data.nom} a décliné l’invitation`); UI.chat(data.nom, hasard(['dsl je farm', 'pas maintenant', 'je vais déco bientôt'])); return; }
      groupe = data; selection = null; son('confirmation_001', 0.5);
      UI.toast(`${data.nom} a rejoint ton groupe`); UI.chat(data.nom, hasard(['go', 'let’s go !', 'je te suis', 'on fait un donjon ?', 'salut, on y va']));
    }, 1200 + Math.random() * 900);
  },
  exclure: () => { if (!groupe) return; UI.toast(`${groupe.nom} a quitté le groupe`); groupe = null; son('close_001', 0.4); },
  duel: (data, mise) => {
    if (mise > J.argent) { UI.toast('Pas assez d’argent pour cette mise'); return; }
    UI.toast(`Défi envoyé à ${data.nom}${mise ? ` (mise ${mise.toLocaleString('fr-FR')})` : ''}…`);
    setTimeout(() => {
      if (Math.random() < (mise > 1000 ? 0.35 : 0.15)) { UI.toast(`${data.nom} refuse le duel`); UI.chat(data.nom, hasard(['non merci', 'trop cher pour moi', 'une autre fois'])); return; }
      J.argent -= mise; sauver(); UI.chat(data.nom, hasard(['ok, à l’arène', 'prépare-toi', 'tu vas regretter :)']));
      entrerArene('1v1', { duel: data, mise });
    }, 1300);
  },
  accepterInvasion: (v) => { J.accepteInvasion = v; sauver(); UI.toast(v ? 'Ton monde est ouvert aux invasions' : 'Ton monde est fermé aux invasions'); },
  envahir: () => { const ip = statsHeros(J.equip).ip; entrerDonjon(ip < 560 ? 0 : ip < 860 ? 1 : 2, { envahir: true }); },
  qualite: (q) => { G.qualite = q; try { localStorage.setItem('breche-qualite', q); } catch (e) {} appliquerNiveau({ haute: 2, moyenne: 1, basse: 0, auto: 2 }[q]); },
  reset: () => { efface = true; if (sauverT) clearTimeout(sauverT); try { localStorage.removeItem(CLE); } catch (e) {} location.reload(); },
};
UI.init(API);

// ---------------- Interactions ----------------
function majInteractions() {
  if (joueur.mort) { UI.action(null); return; }
  if (arene) return UI.action(null);
  if (modeActuel && modeActuel.id === 'ile') return interactionsIle();
  if (!modeActuel) {
    if (marchand && dist2D(joueur.pos, marchand.pos) < 5) return UI.action('Parler à Borin', () => UI.dialogueMarchand());
    if (dist2D(joueur.pos, monde.portail.pos) < 9) return UI.action('Franchir la Brèche', () => UI.menuPortail());
    if (monde.portailArene && dist2D(joueur.pos, monde.portailArene.pos) < 9) return UI.action('Entrer dans l’Arène', () => UI.menuArene(groupe));
    if ((passeur && dist2D(joueur.pos, passeur.pos) < 4.5) || (monde.portailIle && dist2D(joueur.pos, monde.portailIle.pos) < 5)) return UI.action('Les Îles', () => UI.menuIles(infosIles()));
    return UI.action(null);
  }
  for (const c of coffres) {
    if (c.ouvert || dist2D(joueur.pos, c.pos) > 3.6) continue;
    if (c.depouille) return UI.action('Fouiller la dépouille', () => ouvrirDepouille(c));
    if (!c.boss.mort) return UI.action('Coffre scellé', () => UI.toast(`Bats ${c.boss.boss.nom} pour l’ouvrir`));
    return UI.action('Ouvrir le ' + c.def.nom.toLowerCase(), () => ouvrirCoffre(c));
  }
  if (sortie && dist2D(joueur.pos, sortie.pos) < 3.2) return UI.action('Retourner sur la Place', () => fondu(() => lancerHub()));
  UI.action(null);
}
function ouvrirCoffre(c) {
  c.ouvert = true; UI.action(null);
  son('creak1', 0.7); son(c.couleur === 'legendaire' ? 'jingle_legend' : 'jingle_loot', 0.55);
  const t0 = G.t;
  if (c.lid) ajouterVfx(new THREE.Group(), (t) => { c.lid.rotation.x = -Math.min(1, t / 0.6) * 1.9; if (t > 0.7) return false; });
  emettre(V(c.pos.x, 1.2, c.pos.z), { n: 90, c1: '#fff2c0', c2: c.def.color, vit: 7, vie: 1.2, taille: 0.45, grav: 4, monte: 4 });
  onde(c.pos, c.def.color, 5, 0.8);
  const loot = lootCoffre(c.couleur, modeActuel, c.boss.idx);
  if (J.accepteInvasion) loot.argent = Math.round(loot.argent * 1.25);
  if (coequipiers().length) { // en groupe, le coffre est partagé en deux
    const a = coequipiers()[0]; const moitie = Math.round(loot.argent / 2);
    loot.allie = { nom: a.nom, argent: loot.argent - moitie, objets: loot.objets.filter((_, i) => i % 2 === 1) };
    loot.argent = moitie; loot.objets = loot.objets.filter((_, i) => i % 2 === 0);
  }
  setTimeout(() => {
    UI.butin(c.couleur, loot, () => { J.argent += loot.argent; for (const it of loot.objets) ajouterSac(it, true); son('handleCoins', 0.6); sauver(); c.beam.visible = false; });
  }, 700);
}

function interactionsIle() {
  const ile = monde.ile;
  if (dist2D(joueur.pos, monde.portail.pos) < 3.5) return UI.action('Retourner sur la Place', () => fondu(() => lancerHub()));
  if (monde.etranger) {
    const gardes = ennemis.filter(e => e.gardeIle && !e.mort).length;
    if (dist2D(joueur.pos, monde.coffrePos) < 3.2) return gardes ? UI.action('Coffre gardé', () => UI.toast(`Il reste ${gardes} garde${gardes > 1 ? 's' : ''}`)) : (monde.pille ? UI.action(null) : UI.action('Piller le coffre', pillerCoffre));
    return UI.action(null);
  }
  if (intendant && dist2D(joueur.pos, intendant.pos) < 4) return UI.action('Parler à Oswin', () => UI.menuIntendant(ile, infosIle(ile)));
  if (assaut && !assaut.fini) return UI.action(null);
  if (!recolteJ) {
    let best = null, bd = Infinity;
    for (const n of monde.noeuds) { if (n.pv <= 0) continue; const d = dist2D(n.pos, joueur.pos) - n.rayon; if (d < 2.2 && d < bd) { bd = d; best = n; } }
    if (best) return UI.action(ILE_TYPES[ile.type].verbe, () => commencerRecolte(best));
  } else return UI.action('Arrêter', arreterRecolte);
  for (const p of monde.plots) if (!p.bati && dist2D(p.pos, joueur.pos) < 3.6) return UI.action('Construire ici', () => UI.menuConstruction(ile, p.idx, infosIle(ile)));
  if (dist2D(joueur.pos, monde.coffrePos) < 3) return UI.action('Voir le coffre', () => UI.menuIntendant(ile, infosIle(ile), 'coffre'));
  UI.action(null);
}
function pillerCoffre() {
  const bot = monde.ile; monde.pille = true; const res = ILE_TYPES[bot.type].res;
  const butin = Math.floor((bot.coffre[res] || 0) * 0.4);
  const cible = iles().find(i => i.type === bot.type) || iles()[0];
  let ok = 0; if (cible) ok = ajouterRes(cible, res, butin);
  const reste = butin - ok; const argent = Math.round(reste * ILE_TYPES[bot.type].prix * 0.7); J.argent += argent;
  son('jingle_legend', 0.6); emettre(V(monde.coffrePos.x, 1.2, monde.coffrePos.z), { n: 80, c1: '#fff2c0', c2: '#ffc84a', vit: 6, vie: 1, taille: 0.4, grav: 4 });
  UI.rapport('Pillage réussi', [`${fmtN(butin)} ${RES_LABEL[res]} volés à ${bot.proprio.nom}.`, ok ? `${fmtN(ok)} rangés dans le coffre de ${cible.nom}.` : '', argent ? `${fmtN(reste)} revendus sur place : +${fmtN(argent)}` : ''].filter(Boolean));
  sauver();
}
function infosIle(ile) {
  majProduction();
  const prix = {}; for (const t in BATIMENTS) prix[t] = prixBatiment(ile, t);
  return { cap: capaciteIle(ile), vitesse: vitesseIle(ile), maxOuv: maxOuvriers(ile), prix, total: totalCoffre(ile), assaut: ile.assaut, besoin: ILE_NIVEAUX[ile.niveau + 1] || 0, nbEmpl: nbEmplacements(ile), argent: J.argent,
    prodHeure: Math.round(Math.min(ile.ouvriers || 0, maxOuvriers(ile)) * vitesseIle(ile) * 450) };
}
function infosIles() { majProduction(); return { iles: iles().map(i => ({ ile: i, ...infosIle(i) })), argent: J.argent, ip: statsHeros(J.equip).ip }; }

// ---------------- Entrées ----------------
function initEntrees() {
  const zone = $('#zoneJoy'), joy = $('#joy'), stick = joy.querySelector('.stick');
  let id = null, cx = 0, cy = 0;
  const R = () => joy.offsetWidth * 0.42;
  zone.addEventListener('pointerdown', (e) => {
    id = e.pointerId; zone.setPointerCapture(id);
    cx = e.clientX; cy = e.clientY;
    joy.style.left = cx + 'px'; joy.style.bottom = (innerHeight - cy) + 'px'; joy.style.transform = 'translate(-50%,50%)';
  });
  zone.addEventListener('pointermove', (e) => {
    if (e.pointerId !== id) return;
    let dx = e.clientX - cx, dy = e.clientY - cy; const l = Math.hypot(dx, dy), r = R();
    if (l > r) { dx *= r / l; dy *= r / l; }
    stick.style.transform = `translate(${dx}px,${dy}px)`;
    entree.jx = dx / r; entree.jy = -dy / r;
  });
  const fin = (e) => { if (e.pointerId !== id) return; id = null; entree.jx = entree.jy = 0; stick.style.transform = ''; joy.style.left = ''; joy.style.bottom = ''; };
  zone.addEventListener('pointerup', fin); zone.addEventListener('pointercancel', fin);
  // tap sur la scène : choisir une cible ou interagir
  $('#scene').addEventListener('pointerdown', (e) => {
    if (!enJeu || !joueur) return;
    let best = null, bd = 70;
    for (const en of vivants()) { const s = projeter(V(en.pos.x, 1.2, en.pos.z)); const d = Math.hypot(s.x - e.clientX, s.y - e.clientY); if (d < bd) { bd = d; best = en; } }
    if (best) { joueur.cibleVerrou = best; son('click_001', 0.3); return; }
    if (!modeActuel) {
      let bb = null, bd2 = 60;
      for (const b of bots) { const s = projeter(V(b.pos.x, 1.2, b.pos.z)); const d = Math.hypot(s.x - e.clientX, s.y - e.clientY); if (d < bd2) { bd2 = d; bb = b; } }
      if (bb) { selection = bb; son('select_001', 0.4); majCadreAutre(); return; }
      selection = null;
    }
    if (marchand) { const s = projeter(V(marchand.pos.x, 1.2, marchand.pos.z)); if (Math.hypot(s.x - e.clientX, s.y - e.clientY) < 70 && dist2D(joueur.pos, marchand.pos) < 7) UI.dialogueMarchand(); }
  });
  window.addEventListener('keydown', (e) => {
    entree.clavier[e.key] = true;
    const k = e.key.toUpperCase();
    if (['Q', 'W', 'E', 'R', 'D', 'F'].includes(k)) API.touche(k, true);
    if (k === '1') API.touche('POT', true);
    if (k === 'I') UI.ouvrirInventaire();
    if (k === 'T') API.touche('CIBLE', true);
  });
  window.addEventListener('keyup', (e) => { entree.clavier[e.key] = false; });
  $('#btnInv').onclick = () => UI.ouvrirInventaire();
  $('#cadreAutre').onclick = () => {
    const d = selection ? selection.data : groupe || (allies[0] && allies[0].data);
    if (!d || modeActuel) return;
    UI.menuJoueur(d, !!(groupe && groupe.nom === d.nom), !!groupe);
  };
  $('#btnReg').onclick = () => UI.reglages();
  $('#btnChat').onclick = () => UI.chat(J.nom, 'Salut tout le monde !');
  let quitConf = 0;
  $('#btnQuitter').onclick = () => {
    if (!modeActuel) return;
    if (Date.now() - quitConf > 2500) { quitConf = Date.now(); UI.toast(arene ? 'Touche encore pour abandonner le combat' : 'Touche encore pour quitter le donjon'); return; }
    fondu(() => lancerHub());
  };
}

// ---------------- Boucle ----------------
let dernier = performance.now(), hudT = 0, miniT = 0, ileT = 2;
const ORBITE = V(0, 0, 0);
function boucle() {
  requestAnimationFrame(boucle);
  const now = performance.now(); const dtReel = (now - dernier) / 1000; let dt = Math.min(0.05, dtReel); dernier = now;
  const q = majQualiteAuto(dtReel, enJeu && !transition && !document.hidden);
  if (q === 'baisse') UI.toast(G.niveau === 1 ? 'Qualité ajustée : lueurs coupées pour plus de fluidité' : 'Qualité ajustée : ombres coupées pour plus de fluidité');
  G.t += dt; G.dt = dt;
  for (const f of G.anims || []) f(G.t, dt);
  for (let i = minuteries.length - 1; i >= 0; i--) { const m = minuteries[i]; m.t -= dt; if (m.t <= 0) { minuteries.splice(i, 1); m.fn(); } }
  if (marchand) marchand.maj(dt);
  if (enJeu && joueur) {
    G.focus = joueur.pos;
    if (!transition) majJoueur(dt);
    if (!modeActuel) majBots(dt); else { majEnnemis(dt); majAllies(dt); majProjectiles(dt); majInvasion(dt); majArene(dt); }
    if (modeActuel && modeActuel.id === 'ile') { majOuvriers(dt); majNoeuds(dt); majRecolteJoueur(dt); majPillard(dt); if (intendant) intendant.maj(dt); }
    if (passeur) passeur.maj(dt);
    ileT -= dt; if (ileT <= 0) { ileT = 3; majProduction(); majAssauts(); majRaids(); if (modeActuel && modeActuel.id === 'ile' && !monde.etranger && !(raid && raid.r)) journalIle(monde.ile); }
    majCamera(dt, joueur.pos);
    majTorches(joueur.pos);
    hudT -= dt; if (hudT <= 0) { hudT = 0.08; UI.majHud(joueur, joueur.st); UI.majSorts(joueur); majInteractions(); majCadreAutre(); majBarreRival(); }
    miniT -= dt; if (miniT <= 0) { miniT = 0.2; majMini(); }
    UI.majPlaques(joueur.pos);
    // anneau de cible
    majAnneauCible();
  } else if (monde) {
    // écran titre : la caméra tourne autour de la place
    G.camYaw = Math.PI / 4 + Math.sin(G.t * 0.1) * 0.5; ORBITE.set(Math.sin(G.t * 0.07) * 6, 0, 2);
    majCamera(dt, ORBITE); majTorches(ORBITE);
    majBots(dt);
    UI.majPlaques(ORBITE);
  }
  if (enJeu) G.camYaw = Math.PI / 4;
  majFeux(dt); majVfx(dt); majParticules(dt);
  const t1 = performance.now();
  rendre();
  const t2 = performance.now(), P = G.perf || (G.perf = { upd: 0, rend: 0, max: 0, pics: 0 });
  P.upd = P.upd * 0.95 + (t1 - now) * 0.05; P.rend = P.rend * 0.95 + (t2 - t1) * 0.05;
  if (t2 - now > 40) P.pics++; P.max = Math.max(P.max, t2 - now);
}
let anneau = null;
function majAnneauCible() {
  if (!anneau) {
    anneau = new THREE.Mesh(new THREE.RingGeometry(0.9, 1.1, 40), new THREE.MeshBasicMaterial({ color: '#ff3a2a', transparent: true, opacity: 0.8, blending: THREE.AdditiveBlending, depthWrite: false }));
    anneau.rotation.x = -Math.PI / 2; G.scene.add(anneau);
  }
  if (!anneau.parent) G.scene.add(anneau);
  const c = joueur.cibleVerrou && !joueur.cibleVerrou.mort ? joueur.cibleVerrou : (entree.atk ? joueur.cible : null);
  if (c && !c.mort) { anneau.visible = true; anneau.position.set(c.pos.x, 0.12, c.pos.z); anneau.scale.setScalar(c.rayon * 1.6 + 0.3); anneau.material.color.set(joueur.cibleVerrou ? '#ffcf4a' : '#ff3a2a'); anneau.rotation.z = G.t; }
  else anneau.visible = false;
}
function majMini() {
  const ents = [];
  if (!modeActuel) {
    for (const b of bots) if (!b.mort) ents.push({ type: groupe && b.nom === groupe.nom ? 'allie' : 'joueur', x: b.pos.x, z: b.pos.z });
    if (marchand) ents.push({ type: 'pnj', x: marchand.pos.x, z: marchand.pos.z });
    ents.push({ type: 'portail', x: monde.portail.pos.x, z: monde.portail.pos.z });
    if (monde.portailArene) ents.push({ type: 'portailV', x: monde.portailArene.pos.x, z: monde.portailArene.pos.z });
    if (monde.portailIle) ents.push({ type: 'portailJ', x: monde.portailIle.pos.x, z: monde.portailIle.pos.z });
  } else if (monde.type === 'ile') {
    for (const e of ennemis) if (!e.mort) ents.push({ type: 'boss', x: e.pos.x, z: e.pos.z });
    for (const a of allies) if (!a.mort) ents.push({ type: 'allie', x: a.pos.x, z: a.pos.z });
    for (const o of ouvriers) ents.push({ type: 'joueur', x: o.pos.x, z: o.pos.z });
    if (intendant) ents.push({ type: 'pnj', x: intendant.pos.x, z: intendant.pos.z });
    ents.push({ type: 'coffre', x: monde.coffrePos.x, z: monde.coffrePos.z, c: '#ffd25a' });
    ents.push({ type: 'portailJ', x: monde.portail.pos.x, z: monde.portail.pos.z });
  } else {
    for (const e of ennemis) if (!e.mort) ents.push({ type: e.boss || e.rival ? 'boss' : 'mob', x: e.pos.x, z: e.pos.z });
    for (const c of coffres) if (!c.ouvert) ents.push({ type: 'coffre', x: c.pos.x, z: c.pos.z, c: c.def.color });
    if (sortie) ents.push({ type: 'portailV', x: sortie.pos.x, z: sortie.pos.z });
    for (const a of allies) if (!a.mort) ents.push({ type: 'allie', x: a.pos.x, z: a.pos.z });
  }
  UI.mini(monde, joueur, ents);
}


// ---------------- Combattants : joueurs rivaux et coéquipiers ----------------
const RIVAL_ARRIVEE = ['Ton stuff a l’air sympa', 'Coucou :)', 'Désolé, rien de personnel', 'On va voir ce que tu vaux', 'Pas de chance, c’est moi', 'je prends tout'];
const RIVAL_COMBAT = ['pas mal', 'tu fuis ?', 'allez', 'raté', 'presque', 'lag de fou là', 'aïe'];
const RIVAL_PERD = ['gg', 'gg bien joué', 'sérieux…', 'j’avais plus de potions', 'je reviendrai', 'ok t’es fort'];
const RIVAL_GAGNE = ['gg, merci pour le stuff', 'ez', 'merci pour l’équipement', 'fallait esquiver', 'gg wp'];
const hasard = (l) => l[Math.floor(Math.random() * l.length)];
const fmtN = (n) => Math.round(n).toLocaleString('fr-FR');

function genererEquipRival(ipCible, type = null) {
  const tMoy = Math.max(1, Math.min(8, Math.round((ipCible - 320) / 100) + 1));
  const t = () => Math.max(1, Math.min(8, tMoy + (Math.random() < 0.25 ? 1 : Math.random() < 0.3 ? -1 : 0)));
  const q = () => (Math.random() < 0.45 ? 0 : 1 + Math.floor(Math.random() * 3));
  type = type || ['epee', 'arbalete', 'baton'][Math.floor(Math.random() * 3)];
  return { arme: creerArme(type, t(), q()), casque: creerArmure('casque', t(), q()), plastron: creerArmure('plastron', t(), q()), bottes: creerArmure('bottes', t(), q()) };
}
function donneesBot(ipCible, exclure = []) {
  const libres = BOTS.filter(b => !exclure.includes(b[0]) && b[0] !== J.nom && !(groupe && groupe.nom === b[0]));
  const [nom, tag, guilde] = hasard(libres.length ? libres : BOTS);
  const equip = genererEquipRival(ipCible);
  const type = equip.arme.type;
  return { nom, guilde: (tag ? `[${tag}] ` : '') + guilde, equip, ip: statsHeros(equip, false).ip, modele: type === 'arbalete' && Math.random() < 0.5 ? 'Rogue' : ARMES[type].model };
}
function pointLibrePres(centre, dMin, dMax, r = 0.7) {
  for (let i = 0; i < 60; i++) {
    const a = Math.random() * 6.28, rr = rnd(dMin, dMax);
    const x = centre.x + Math.cos(a) * rr, z = centre.z + Math.sin(a) * rr;
    if (libre(x, z, r)) return V(x, 0, z);
  }
  return centre.clone();
}
// habille un personnage selon son équipement (couleur du tier sur l'arme, la cape, le casque, les jambes)
function habiller(a, equip, def) {
  const arme = equip.arme;
  const tous = Object.keys(a.nodes).filter(n => /Sword|Axe|Shield|Crossbow|Staff|Wand|Knife|Throwable|Mug|Spellbook/.test(n));
  a.montrerSeul([def.node], tous);
  a.teinter(def.node, TIERS[arme.tier].color, 0.62, TIERS[arme.tier].glow);
  const cape = Object.keys(a.nodes).find(n => n.endsWith('_Cape'));
  const corps = Object.keys(a.nodes).find(n => n.endsWith('_Body'));
  const casque = Object.keys(a.nodes).find(n => /_(Helmet|Hat)$/.test(n));
  if (casque && equip.casque) a.teinter(casque, TIERS[equip.casque.tier].color, 0.5, TIERS[equip.casque.tier].glow * 0.3);
  if (equip.plastron) { if (cape) a.teinter(cape, TIERS[equip.plastron.tier].color, 0.7, TIERS[equip.plastron.tier].glow * 0.25); if (corps) a.teinter(corps, TIERS[equip.plastron.tier].color, 0.28, 0); }
  if (equip.bottes) Object.keys(a.nodes).filter(n => /_Leg(Left|Right)$/.test(n)).forEach(l => a.teinter(l, TIERS[equip.bottes.tier].color, 0.3, 0));
}
function creerCombattant(pos, data, camp = 'ennemi') {
  const equip = data.equip, arme = equip.arme, def = ARMES[arme.type];
  const a = new Acteur(data.modele || def.model, { hauteur: 2.0 });
  habiller(a, equip, def);
  const st = statsHeros(equip, false);
  a.root.position.copy(pos); G.scene.add(a.root);
  Object.assign(a, {
    combattant: true, rival: camp === 'ennemi', camp, nom: data.nom, guilde: data.guilde, ip: data.ip || st.ip, data,
    armeDef: def, equip, st, def: { nom: data.nom, model: def.model },
    pos: a.root.position, pv: st.pvMax, pvMax: st.pvMax, reduction: st.reduction, dmg: st.degats * 1.05,
    etat: 'chasse', atkT: 1.2, attaqueT: 1.2, stunT: 0, slowT: 0, dots: [], pack: -9, angle: 0, mort: false, hauteurPlaque: 2.55, rayon: 0.55, hover: 0,
    specT: rnd(3, 5), potions: 2, potionT: 0, esquiveT: 2, dashT: 0, strafe: Math.random() < 0.5 ? 1 : -1, chatT: rnd(10, 18), tc: null,
    argent: Math.round(rnd(0.7, 1.4) * 60 * Math.pow(2.3, arme.tier - 1)),
  });
  a.jouer('Cheer', { boucle: false, fin: () => a.jouer(def.idle) });
  UI.plaque(a, { nom: data.nom, guilde: data.guilde, classe: camp === 'ennemi' ? 'rival' : 'allie', ip: a.ip, vie: camp === 'ennemi' });
  if (camp === 'ennemi') ennemis.push(a); else allies.push(a);
  return a;
}

// ---- camps, cibles et dégâts ----
function coequipiers() { return allies.filter(a => !a.garde); }
function equipeJoueur() { const l = []; if (!joueur.mort) l.push(joueur); for (const a of allies) if (!a.mort) l.push(a); return l; }
function adversaires(e) { return e.camp === 'allie' ? vivants() : equipeJoueur(); }
function cibleIA(e) {
  let liste;
  if (e.poste && e.camp === 'allie') liste = vivants().filter(x => dist2D(x.pos, e.poste) < 24);
  else if (e.poste) liste = equipeJoueur().filter(x => dist2D(x.pos, e.poste) < 20);
  else if (e.camp === 'allie') liste = arene ? vivants() : vivants().filter(x => x.etat !== 'dormant' && dist2D(x.pos, joueur.pos) < 15 && (x.etat !== 'idle' || dist2D(x.pos, e.pos) < 8));
  else liste = equipeJoueur();
  if (!liste.length) return null;
  let p = null, pd = Infinity;
  for (const c of liste) { const d = dist2D(c.pos, e.pos); if (d < pd) { pd = d; p = c; } }
  // on garde sa cible, sauf si une autre est nettement plus proche
  if (e.tc && !e.tc.mort && liste.includes(e.tc) && dist2D(e.tc.pos, e.pos) < pd + 4) return e.tc;
  return p;
}
function infliger(src, c, d, opts = {}) {
  if (!c || c.mort) return;
  if (c === joueur) {
    blesserJoueur(d, src);
    if (opts.slow) joueur.slowT = Math.max(joueur.slowT, opts.slow);
    if (opts.stun && joueur.invuln <= 0) { joueur.verrouT = Math.max(joueur.verrouT, opts.stun); UI.nombre(V(joueur.pos.x, 2.6, joueur.pos.z), 'Étourdi', 'info'); }
    return;
  }
  if (c.camp === 'allie') return blesserAllie(c, d, src, opts);
  blesser(c, 0, { fixe: d, stun: opts.stun, slow: opts.slow, c1: '#ffd0a0' });
}
function toucherZone(src, p, r, d, opts = {}) {
  for (const c of adversaires(src)) {
    const dd = dist2D(c.pos, p);
    if (dd > r + (c.rayon || 0.4)) continue;
    if (opts.cone) { const v = V(c.pos.x - p.x, 0, c.pos.z - p.z).normalize(); if (v.dot(opts.cone.dir) < opts.cone.cos && dd > 1.2) continue; }
    infliger(src, c, d, opts);
  }
}
function blesserAllie(a, d, src, opts = {}) {
  if (a.mort) return;
  d = d * (1 - a.reduction) * rnd(0.92, 1.08);
  if (a.bouclierIA > 0) { const b = Math.min(a.bouclierIA, d); a.bouclierIA -= b; d -= b; if (d <= 0) return; }
  a.pv -= d; a.frapper();
  UI.nombre(V(a.pos.x, 2.2, a.pos.z), Math.round(d), 'allie');
  if (opts.slow) a.slowT = Math.max(a.slowT, opts.slow);
  if (opts.stun) a.stunT = Math.max(a.stunT, opts.stun * 0.5);
  if (a.pv > 0) return;
  a.pv = 0; a.mort = true; a.jouer('Death_A', { boucle: false });
  UI.toast(`${a.nom} est tombé`);
  setTimeout(() => UI.chat(a.nom, hasard(['désolé…', 'je suis mort', 'ils frappent fort', 'vas-y finis-les'])), 700);
  if (arene) return verifierArene();
  if (a.garde) return;
  // en donjon, le coéquipier se relève au bout de 15 s près du joueur
  programmer(15, () => {
    if (!allies.includes(a) || joueur.mort) return;
    a.mort = false; a.pv = a.pvMax * 0.5; a.pos.copy(pointLibrePres(joueur.pos, 1.5, 3)); a.jouer(a.armeDef.idle);
    onde(a.pos, '#9dff8a', 3, 0.6); UI.toast(`${a.nom} se relève`);
  });
}
function sautEnCours(e, dt) {
  if (!(e.sautT > 0)) return false;
  e.sautT -= dt; const k = Math.min(1, 1 - Math.max(0, e.sautT) / e.sautD);
  e.pos.x = e.sautA.x + (e.sautB.x - e.sautA.x) * k; e.pos.z = e.sautA.z + (e.sautB.z - e.sautA.z) * k;
  e.root.position.y = (e.hover || 0) + Math.sin(k * Math.PI) * (e.sautH || 2.2);
  if (e.sautT <= 0) { e.root.position.y = e.hover || 0; e.sautH = 0; emettre(V(e.pos.x, 0.3, e.pos.z), { n: 18, c1: '#cfc0a8', c2: '#6a5a4a', vit: 4, vie: 0.5, taille: 0.45, hemi: true, grav: 5 }); }
  e.maj(dt); return true;
}
// sortir d'un blocage : bond vers un point libre près de la cible
function bondir(e, cible) {
  const r = Math.min(e.rayon * 0.8, 1.1);
  let dest = null;
  for (let i = 0; i < 30 && !dest; i++) { const a = Math.random() * 6.28, rr = rnd(1.8, 4.5); const x = cible.x + Math.cos(a) * rr, z = cible.z + Math.sin(a) * rr; if (libre(x, z, r)) dest = V(x, 0, z); }
  if (!dest) return;
  const dist = dist2D(e.pos, dest);
  e.sautA = e.pos.clone(); e.sautB = dest; e.sautD = e.sautT = Math.min(1.1, 0.45 + dist * 0.04); e.sautH = 1.5 + Math.min(3, dist * 0.15);
  emettre(V(e.pos.x, 0.3, e.pos.z), { n: 16, c1: '#cfc0a8', c2: '#6a5a4a', vit: 3, vie: 0.5, taille: 0.4, hemi: true });
}

// ---- IA des combattants (rivaux et coéquipiers) ----
function majCombattant(e, dt) {
  const def = e.armeDef, type = e.equip.arme.type, melee = type === 'epee';
  if (arene && arene.t > 0) { e.jouer(def.idle); faceJoueur(e, dt, 4); return; }
  e.tc = cibleIA(e);
  if (e.potionT > 0) { e.potionT -= dt; e.pv = Math.min(e.pvMax, e.pv + e.pvMax * 0.4 * dt); if (Math.random() < 0.4) emettre(V(e.pos.x, 0.5, e.pos.z), { n: 1, c1: '#ff8a9a', c2: '#ff2a4a', dir: V(0, 1, 0), vit: 2, rayon: 0.6, vie: 0.6, taille: 0.3 }); }
  e.potionCd = (e.potionCd || 0) - dt; e.cdRempart = (e.cdRempart || 0) - dt;
  if (e.bouclierT > 0) { e.bouclierT -= dt; if (e.bouclierT <= 0) e.bouclierIA = 0; }
  e.pvT = (e.pvT || 0) - dt; if (e.pvT <= 0) { e.pvT = 2; e.pvRef = e.pv; }
  if (e.pv < e.pvMax * 0.35 && e.potions > 0 && e.potionT <= 0 && e.potionCd <= 0) { e.potions--; e.potionT = 1; e.potionCd = 60; son('metalLatch', 0.4, 1.4); UI.nombre(V(e.pos.x, 2.6, e.pos.z), 'Potion', 'soin'); }
  // bulle de protection : sous la pression (gros dégâts récents ou vie basse)
  if (e.tc && e.cdRempart <= 0 && (e.pv < e.pvMax * 0.55 || (e.pvRef || e.pv) - e.pv > e.pvMax * 0.18)) rempartIA(e);
  if (e.dashT > 0) { e.dashT -= dt; deplacer(e, e.dashV.x * dt, e.dashV.z * dt, 0.5); return; }
  // repli : il s'éloigne le temps que ses sorts reviennent, puis revient
  if (e.repliT > 0 && e.tc) {
    e.repliT -= dt;
    const fuite = V(e.pos.x - e.tc.pos.x, 0, e.pos.z - e.tc.pos.z).normalize().multiplyScalar(9).add(e.pos);
    avancerVers(e, fuite, dt, e.st.vitesse * 1.05); e.jouer(def.run);
    if (e.repliT <= 0 && e.camp === 'ennemi' && Math.random() < 0.3) UI.chat(e.nom, hasard(['je reviens', 'attends un peu', 'cd', 'tu vas voir']));
    return;
  }
  if (e.attaqueT > 0) { e.attaqueT -= dt; if (e.tc) faceJoueur(e, dt, 8); return; }
  const c = e.tc;
  if (!c) {
    if (e.poste) { // un garde retourne à son poste
      if (dist2D(e.pos, e.poste) > 1.5) { avancerVers(e, e.poste, dt, e.st.vitesse * 0.8); e.jouer(def.run); } else e.jouer(def.idle);
    } else if (e.camp === 'allie') { // suit le joueur
      const dj = dist2D(e.pos, joueur.pos);
      if (dj > 3.5) { avancerVers(e, joueur.pos, dt, e.st.vitesse * (dj > 8 ? 1.15 : 0.9)); e.jouer(def.run); }
      else e.jouer(def.idle);
      if (dj > 34 && !arene) { e.pos.copy(pointLibrePres(joueur.pos, 1.5, 3)); onde(e.pos, '#4fd1ff', 2.5, 0.5); }
    } else e.jouer(def.idle);
    return;
  }
  const d = dist2D(e.pos, c.pos);
  if (e.camp === 'ennemi') { e.chatT -= dt; if (e.chatT <= 0 && d < 20) { e.chatT = rnd(16, 28); UI.chat(e.nom, hasard(RIVAL_COMBAT)); } }
  e.esquiveT -= dt; e.specT -= dt;
  if (e.specT <= 0 && d < 14) { capaciteCombattant(e, type); e.specT = rnd(4.5, 7.5); e.repliPossible = true; return; }
  if (e.repliPossible && e.attaqueT <= 0) {
    e.repliPossible = false;
    if (e.specT > 2.5 && e.pv < e.pvMax * (melee ? 0.6 : 0.85) && Math.random() < 0.6) { e.repliT = Math.min(e.specT - 1, rnd(2, 3.5)); return; }
  }
  const portee = melee ? def.portee + (c.rayon || 0.5) : 9.5;
  if (d > portee) { avancerVers(e, c.pos, dt, e.st.vitesse * (e.slowT > 0 ? 0.6 : 0.92)); e.jouer(def.run); return; }
  // un tireur garde ses distances
  if (!melee && d < 4.5 && e.esquiveT <= 0) {
    const arr = V(e.pos.x - c.pos.x, 0, e.pos.z - c.pos.z).normalize();
    e.dashT = 0.35; e.dashV = arr.multiplyScalar(18); e.esquiveT = rnd(4, 6);
    e.jouer('Dodge_Backward', { boucle: false, forcer: true, vitesse: 1.5, fin: () => e.jouer(def.idle) });
    emettre(V(e.pos.x, 0.3, e.pos.z), { n: 12, c1: '#d0f0ff', c2: '#6aa0c0', vit: 3, vie: 0.4, taille: 0.35 });
    return;
  }
  faceJoueur(e, dt, 12);
  if (!melee) {
    const perp = V(c.pos.z - e.pos.z, 0, -(c.pos.x - e.pos.x)).normalize().multiplyScalar(e.strafe * 2.2 * dt);
    if (!deplacer(e, perp.x, perp.z, 0.5)) e.strafe *= -1;
    if (Math.random() < dt * 0.3) e.strafe *= -1;
  }
  if (e.atkT > 0) { e.jouer(def.idle); return; }
  e.atkT = 1 / e.st.vitesseAtk; e.attaqueT = 0.3;
  const anim = def.attaques[Math.floor(Math.random() * def.attaques.length)];
  e.jouer(anim, { boucle: false, forcer: true, vitesse: 1.25, fin: () => e.jouer(def.idle) });
  const coul = TIERS[e.equip.arme.tier].color;
  if (melee) programmer(0.3, () => { if (e.mort || e.stunT > 0 || c.mort) return; arcTaille(e.pos, e.angle - Math.PI / 2, 2.9, coul, Math.PI * 0.7, 0.22); if (dist2D(e.pos, c.pos) < portee + 1) { infliger(e, c, e.dmg); son('knifeSlice', 0.4); } });
  else programmer(0.22, () => { if (!e.mort && e.stunT <= 0) tirEnnemi(e, type === 'baton' ? 'feu' : 'carreau', e.dmg); });
}
function capaciteCombattant(e, type) {
  const def = e.armeDef; const c = e.tc; const pj = c.pos.clone();
  const base = Math.atan2(pj.x - e.pos.x, pj.z - e.pos.z);
  e.angle = base; e.root.rotation.y = base;
  const coul = e.camp === 'allie' ? '#4fd1ff' : '#ff3a2a';
  if (type === 'epee') {
    if (Math.random() < 0.5) { // charge héroïque
      e.attaqueT = 1.1; const dir = V(Math.sin(base), 0, Math.cos(base)); const dist = Math.max(2, Math.min(9, dist2D(e.pos, pj) - 1));
      telegraphe(e.pos, dist, 0.55, coul, () => {
        if (e.mort) return; e.jouer('Dodge_Forward', { boucle: false, forcer: true, vitesse: 1.6 });
        e.dashT = 0.25; e.dashV = dir.clone().multiplyScalar(dist / 0.25);
        programmer(0.27, () => { if (e.mort) return; e.jouer('2H_Melee_Attack_Chop', { boucle: false, forcer: true, vitesse: 1.6, fin: () => e.jouer(def.idle) }); onde(e.pos, '#ffd36b', 4, 0.45); toucherZone(e, e.pos, 3.4, e.dmg * 2.2, { stun: 0.8 }); });
      }, { ligne: true, largeur: 2.4, angle: base + Math.PI });
    } else { // fente
      e.attaqueT = 1.0;
      telegraphe(e.pos, 4.8, 0.65, coul, () => {
        if (e.mort) return; e.jouer('2H_Melee_Attack_Slice', { boucle: false, forcer: true, vitesse: 1.5, fin: () => e.jouer(def.idle) });
        arcTaille(e.pos, e.angle - Math.PI / 2, 4.6, '#ff3a2a', Math.PI * 0.8, 0.3);
        toucherZone(e, e.pos, 4.8, e.dmg * 2.3, { cone: { dir: V(Math.sin(base), 0, Math.cos(base)), cos: Math.cos(0.7) } });
      }, { cone: 1.4, angle: base - Math.PI / 2 });
    }
  } else if (type === 'arbalete') {
    if (Math.random() < 0.5) { // carreau perforant
      e.attaqueT = 0.9;
      telegraphe(e.pos, 16, 0.6, coul, () => { if (e.mort) return; e.jouer('2H_Ranged_Shoot', { boucle: false, forcer: true, fin: () => e.jouer(def.idle) }); tirEnnemi(e, 'carreau', e.dmg * 2.4, V(Math.sin(base), 0, Math.cos(base)), 34); }, { ligne: true, largeur: 1.4, angle: base + Math.PI });
    } else { // pluie
      e.attaqueT = 0.6; e.jouer('2H_Ranged_Shoot', { boucle: false, forcer: true, fin: () => e.jouer(def.idle) });
      for (let w = 0; w < 3; w++) telegraphe(pj, 4.2, 0.9 + w * 0.45, coul, () => { emettre(V(pj.x, 0.3, pj.z), { n: 20, c1: '#bfffd8', c2: '#3a9a6a', rayon: 3.8, vit: 2, vie: 0.4, taille: 0.3, hemi: true }); son('impactGeneric_light_000', 0.3, 1.3); toucherZone(e, pj, 4.2, e.dmg * 1.1, { slow: 2 }); });
    }
  } else {
    if (Math.random() < 0.7) { // colonne de flammes
      e.attaqueT = 0.7; e.jouer('Spellcast_Raise', { boucle: false, forcer: true, fin: () => e.jouer(def.idle) });
      telegraphe(pj, 3.5, 0.9, coul, () => { emettre(V(pj.x, 0.3, pj.z), { n: 60, c1: '#ffe08a', c2: '#ff2a00', dir: V(0, 1, 0), vit: 14, disp: 2.5, rayon: 1.8, vie: 0.8, taille: 0.7, frein: 2 }); son('explosionCrunch_000', 0.5, 0.8); if (c === joueur) G.shake = 0.4; toucherZone(e, pj, 3.5, e.dmg * 2.8); });
    } else { // météore
      e.attaqueT = 1.3; e.jouer('Spellcast_Long', { boucle: false, forcer: true, fin: () => e.jouer(def.idle) });
      telegraphe(pj, 6, 1.6, coul, () => { G.shake = 0.8; onde(pj, '#ffd27a', 9, 0.7); emettre(V(pj.x, 0.5, pj.z), { n: 140, c1: '#fff0b0', c2: '#ff2a00', vit: 14, vie: 1.0, taille: 0.9, grav: 4, hemi: true }); son('lowFrequency_explosion_000', 0.8); toucherZone(e, pj, 6, e.dmg * 4.2); });
    }
  }
}
function majAllies(dt) {
  for (const a of allies) {
    if (a.mort) { a.maj(dt); continue; }
    if (a.stunT > 0) { a.stunT -= dt; a.maj(dt * 0.15); continue; }
    if (a.slowT > 0) a.slowT -= dt;
    a.atkT -= dt;
    if (sautEnCours(a, dt)) continue;
    majCombattant(a, dt);
    a.maj(dt);
  }
}
function majCadreAutre() {
  if (selection && !modeActuel) return UI.cadreAutre(selection.data, { membre: !!(groupe && groupe.nom === selection.nom) });
  const a = coequipiers()[0];
  if (a) return UI.cadreAutre(a.data, { membre: true, pv: a.pv / a.pvMax, en: 1 });
  if (groupe) return UI.cadreAutre(groupe, { membre: true });
  UI.cadreAutre(null);
}
function majBarreRival() {
  if (!arene && !(invasion && invasion.rival)) return;
  const rivaux = ennemis.filter(e => e.rival && !e.mort);
  if (!rivaux.length) return UI.boss(null);
  const r = rivaux.includes(joueur.cible) ? joueur.cible : rivaux.reduce((m, e) => (dist2D(e.pos, joueur.pos) < dist2D(m.pos, joueur.pos) ? e : m));
  if (!arene && dist2D(r.pos, joueur.pos) > 22) return UI.boss(null);
  UI.boss({ nom: `${r.nom} · ⚔ ${r.ip}`, pv: r.pv, pvMax: r.pvMax });
}

// ---------------- Expérience de maîtrise ----------------
function gainXP(type, montant) {
  const m = J.maitrise[type]; if (!m || m.niv >= 100) return false;
  const need = xpPour(m.niv);
  m.xp += Math.min(montant, need * 0.4); // jamais plusieurs niveaux d'un coup
  if (m.xp < need) return false;
  m.niv++; m.xp = Math.min(m.xp - need, xpPour(m.niv) * 0.25);
  const nomM = MAITRISES.find(x => x.id === type).nom;
  annonce(nomM, `${nomM} niv. ${m.niv}`);
  const t = NIVEAU_REQUIS.indexOf(m.niv);
  if (t > 0) annonce('palier ' + nomM, `T${t} débloqué : ${nomM}`, true);
  return true;
}
// les montées de niveau simultanées sont regroupées dans un seul bandeau
let annonces = null;
function annonce(cle, txt, palier = false) {
  if (!annonces) {
    annonces = { lignes: new Map(), paliers: new Map() };
    setTimeout(() => {
      const a = annonces; annonces = null;
      document.querySelectorAll('.niveauUp').forEach(x => x.remove()); // un seul bandeau à la fois
      const d = document.createElement('div'); d.className = 'niveauUp';
      d.innerHTML = `<div class="titreNiv">Niveau supérieur</div><div class="lignesNiv">${[...a.lignes.values()].map(l => `<span>${l}</span>`).join('')}</div>${[...a.paliers.values()].map(p => `<div class="palierNiv">${p}</div>`).join('')}`;
      $('#jeu').appendChild(d); setTimeout(() => d.remove(), 3400);
      onde(joueur.pos, '#8fd0ff', 4, 0.8); emettre(V(joueur.pos.x, 0.4, joueur.pos.z), { n: 50, c1: '#ffffff', c2: '#3a7aff', dir: V(0, 1, 0), vit: 6, disp: 1.5, rayon: 1, vie: 1, taille: 0.4 });
      son('confirmation_001', 0.5);
    }, 60);
  }
  (palier ? annonces.paliers : annonces.lignes).set(cle, txt); // la dernière valeur remplace les précédentes
}
function typesPortes() { return [...new Set(['arme', 'casque', 'plastron', 'bottes'].map(s => J.equip[s] && J.equip[s].type).filter(Boolean))]; }
function gagnerXP(base) {
  if (!base) return;
  let monte = false;
  for (const t of typesPortes()) monte = gainXP(t, base) || monte;
  UI.nombre(V(joueur.pos.x, 2.9, joueur.pos.z), `+${fmtN(base)} XP`, 'xp');
  if (monte) { recalculer(); $('#ipHud').textContent = '⚔ ' + joueur.st.ip; }
  sauver();
}
function gagnerXPRelatif(frac) {
  let total = 0;
  for (const t of typesPortes()) { const m = J.maitrise[t]; const x = Math.round(xpPour(m.niv) * frac); total += x; gainXP(t, x); }
  recalculer(); sauver();
  return total;
}

// ---------------- Arène ----------------
function entrerArene(format, opts = {}) {
  fondu(() => {
    viderMonde(); invasion = null; selection = null;
    modeActuel = { id: 'arene', nom: 'Arène', lieu: 'Arène des Échos', argent: 0, xp: 0, tiers: [1, 1], mobTier: 1 };
    monde = construireArene();
    construireJoueur(monde.spawn.clone());
    joueur.pv = joueur.st.pvMax; joueur.energie = joueur.st.energieMax; joueur.cds = {};
    joueur.angle = Math.PI / 2; joueur.root.rotation.y = joueur.angle;
    G.camTarget.copy(joueur.pos); G.scene.fog.density = 0.012; G.hemi.intensity = 1.0; G.sun.intensity = 1.1;
    const ipJ = statsHeros(J.equip).ip;
    arene = { format, duel: opts.duel || null, mise: opts.mise || 0, fini: false, t: 3.6, dernier: 4 };
    const pris = [];
    if (format === '2v2') { const m = groupe || donneesBot(ipJ + rnd(-40, 40)); pris.push(m.nom); const a = creerCombattant(monde.spawnAllie.clone(), m, 'allie'); a.angle = Math.PI / 2; a.root.rotation.y = a.angle; }
    const n = format === '2v2' ? 2 : 1;
    for (let i = 0; i < n; i++) {
      const d = i === 0 && opts.duel ? opts.duel : donneesBot(ipJ + rnd(-50, 80), pris); pris.push(d.nom);
      const r = creerCombattant(monde.spawnsRivaux[i].clone(), d, 'ennemi');
      r.angle = -Math.PI / 2; r.root.rotation.y = r.angle; r.potions = 1;
    }
    const rivaux = ennemis.map(e => `${e.nom} (⚔ ${e.ip})`).join(' et ');
    UI.journal('Arène des Échos', `${format === '2v2' ? 'Équipe adverse' : 'Adversaire'} : ${rivaux}`, null);
    UI.zone('Arène des Échos', opts.duel ? `Duel · mise ${fmtN(opts.mise)}` : format === '2v2' ? '2 contre 2' : '1 contre 1');
    $('#btnQuitter').hidden = false;
    son('forceField_000', 0.6, 0.6);
    G.renderer.compile(G.scene, G.camera);
  });
}
function majArene(dt) {
  if (!arene || arene.fini) return;
  if (arene.t > 0) {
    arene.t -= dt;
    const n = Math.ceil(arene.t);
    if (n !== arene.dernier && n <= 3 && n >= 1) { arene.dernier = n; UI.compteur(n); son('click_001', 0.6, 0.8); }
    if (arene.t <= 0) { UI.compteur('Combat !'); son('impactPlate_heavy_000', 0.7, 0.7); }
  }
}
function verifierArene() {
  if (!arene || arene.fini) return;
  const rivaux = ennemis.filter(e => e.rival && !e.mort).length;
  if (rivaux === 0) finArene(true);
  else if (equipeJoueur().length === 0) finArene(false);
}
function finArene(victoire) {
  arene.fini = true; UI.boss(null);
  const lignes = [];
  if (arene.duel) {
    if (victoire) { J.argent += arene.mise * 2; lignes.push(arene.mise ? `+ ${fmtN(arene.mise * 2)} d’argent (mises remportées)` : 'Duel amical remporté'); }
    else lignes.push(arene.mise ? `Mise perdue : ${fmtN(arene.mise)}` : 'Duel amical perdu');
  } else if (victoire) { J.trophees = (J.trophees || 0) + 100; lignes.push(`🏆 +100 trophées (total ${fmtN(J.trophees)})`); }
  else lignes.push('Aucun trophée cette fois');
  const xp = gagnerXPRelatif(victoire ? (arene.duel ? 0.05 : 0.12) : 0.03);
  lignes.push(`+ ${fmtN(xp)} XP de maîtrise sur ton équipement porté`);
  son(victoire ? 'jingle_win' : 'lowFrequency_explosion_000', 0.6, victoire ? 1 : 0.6);
  if (victoire && !joueur.mort) joueur.jouer('Cheer', { boucle: false });
  for (const a of allies) if (!a.mort && victoire) a.jouer('Cheer', { boucle: false });
  for (const e of ennemis) if (!e.mort) { e.jouer('Cheer', { boucle: false }); UI.chat(e.nom, hasard(RIVAL_GAGNE)); }
  if (victoire) { const r = ennemis.find(e => e.rival); if (r) setTimeout(() => UI.chat(r.nom, hasard(RIVAL_PERD)), 800); }
  sauver();
  setTimeout(() => UI.resultatArene({ victoire, lignes }, () => fondu(() => lancerHub())), 2200);
}

// ---------------- Invasions ----------------
function effetArrivee(pos) {
  onde(pos, '#ff2a2a', 5, 0.8); onde(pos, '#ffb08a', 3, 0.6); lueurSol(pos, '#ff1a1a', 3, 1.4, 1);
  emettre(V(pos.x, 0.3, pos.z), { n: 80, c1: '#ff8a6a', c2: '#8a0000', dir: V(0, 1, 0), vit: 9, disp: 2, rayon: 1, vie: 1.2, taille: 0.6, frein: 1.5 });
  son('lowFrequency_explosion_000', 0.8, 0.8); son('forceField_000', 0.6, 0.6); G.shake = 0.6;
}
function majInvasion(dt) {
  if (!invasion || invasion.rival || joueur.mort || transition) return;
  invasion.t -= dt; if (invasion.t > 0) return;
  const data = donneesBot(statsHeros(J.equip).ip + Math.round(rnd(-50, 90)));
  if (invasion.mode === 'subie') {
    const pos = pointLibrePres(joueur.pos, 11, 16);
    effetArrivee(pos);
    const r = invasion.rival = creerCombattant(pos, data, 'ennemi');
    UI.flashInvasion();
    UI.toast('INVASION', true);
    UI.toast(`${r.nom} ${r.guilde} · Puissance ${r.ip} a envahi ton monde`);
    setTimeout(() => !r.mort && UI.chat(r.nom, hasard(RIVAL_ARRIVEE)), 1800);
    UI.journal('Invasion !', `${r.nom} est venu te dépouiller. Tue-le ou perds tout ton équipement.`, null);
  } else {
    const salles = monde.salles.filter(s => s.type === 'normale');
    const s = salles.sort((a, b) => dist2D(b.centre, joueur.pos) - dist2D(a.centre, joueur.pos))[Math.floor(Math.random() * 3)];
    const r = invasion.rival = creerCombattant(pointLibrePres(s.centre, 0, 4), data, 'ennemi');
    r.attaqueT = 0; r.jouer(r.armeDef.idle);
    UI.toast(`Tu as envahi le monde de ${r.nom}`, true);
    UI.toast(`${r.guilde} · Puissance ${r.ip}`);
    UI.journal('Invasion', `Traque ${r.nom} (puissance ${r.ip}) et prends-lui tout. Le gros point rouge sur la carte, c’est lui.`, null);
    son('forceField_000', 0.6, 0.6);
    setTimeout(() => !r.mort && UI.chat(r.nom, hasard(['?? un envahisseur', 'sérieux pas maintenant', 'viens alors', 'oh non'])), 6000);
  }
}
function victoireRival(e) {
  UI.boss(null); G.shake = 0.8;
  son('jingle_win', 0.6);
  UI.toast(`${e.nom} est vaincu !`, true);
  setTimeout(() => UI.chat(e.nom, hasard(RIVAL_PERD)), 900);
  onde(e.pos, '#ff3a2a', 8, 1); emettre(V(e.pos.x, 1.5, e.pos.z), { n: 90, c1: '#ffd27a', c2: '#ff2a2a', vit: 8, vie: 1.2, taille: 0.45, grav: 3 });
  const pos = pointLibrePres(e.pos, 0.5, 1.5);
  const obj = cloner('chest_gold', pos.x, 0, pos.z, Math.PI / 4, 1.5);
  obj.traverse(o => { if (o.isMesh) { o.material = o.material.clone(); o.material.color = new THREE.Color('#ffffff').lerp(new THREE.Color('#ff3a3a'), 0.45); o.material.emissive = new THREE.Color('#ff1a1a'); o.material.emissiveIntensity = 0.35; o.castShadow = true; } });
  G.scene.add(obj);
  const beam = faisceau(V(pos.x, 0, pos.z), '#ff2a3a', 16, 0.9); G.scene.add(beam);
  coffres.push({ obj, beam, couleur: 'rival', def: { color: '#ff2a3a', nom: 'Dépouille' }, boss: { mort: true }, pos, ouvert: false, lid: obj.getObjectByName('chest_lid'), depouille: true, rival: e });
  UI.journal(e.pillard ? 'Pillard éliminé' : invasion && invasion.mode === 'menee' ? 'Invasion réussie' : 'Invasion repoussée', `Fouille la dépouille de ${e.nom} : choisis ce que tu gardes.`, null);
  if (e.pillard) { raid = null; UI.boss(null); }
  gagnerXPRelatif(0.1);
  if (invasion) invasion.fini = true;
  setTimeout(() => { e.descendre = true; }, 3500);
  sauver();
}
function ouvrirDepouille(c) {
  c.ouvert = true; UI.action(null);
  son('creak1', 0.7); son('jingle_legend', 0.5);
  if (c.lid) ajouterVfx(new THREE.Group(), (t) => { c.lid.rotation.x = -Math.min(1, t / 0.6) * 1.9; if (t > 0.7) return false; });
  emettre(V(c.pos.x, 1.2, c.pos.z), { n: 90, c1: '#ffe0c0', c2: '#ff2a3a', vit: 7, vie: 1.2, taille: 0.45, grav: 4, monte: 4 });
  const r = c.rival; const objets = Object.values(r.equip).filter(Boolean);
  setTimeout(() => UI.depouille(r.nom, r.ip, objets, r.argent, (pris) => {
    J.argent += r.argent; for (const it of pris) ajouterSac(it, true);
    son('handleCoins', 0.6); c.beam.visible = false; sauver();
    UI.toast(pris.length ? `${pris.length} objet${pris.length > 1 ? 's' : ''} ajouté${pris.length > 1 ? 's' : ''} au sac` : 'Tu laisses son équipement');
    if (invasion && invasion.mode === 'menee') UI.journal('Invasion réussie', 'Rentre sur la Place par le portail violet du début.', 1);
  }), 700);
}
function defaiteRival() {
  const r = invasion.rival;
  UI.boss(null);
  const perdus = ['arme', 'casque', 'plastron', 'bottes'].map(s => J.equip[s]).filter(Boolean);
  const type = J.equip.arme ? J.equip.arme.type : 'epee';
  J.equip = { arme: creerArme(type, 1, 0), casque: null, plastron: null, bottes: null };
  const perte = Math.round(J.argent * 0.05); J.argent -= perte;
  sauver();
  son('lowFrequency_explosion_000', 0.7, 0.5);
  setTimeout(() => { if (!r.mort) { r.jouer('Cheer', { boucle: false }); UI.chat(r.nom, hasard(RIVAL_GAGNE)); } }, 800);
  const liste = perdus.map(it => `${nomObjet(it)} (${TIERS[it.tier].roman})`).join(', ');
  setTimeout(() => UI.mort(`${r.nom} (puissance ${r.ip}) t’a vaincu et emporte tout ton équipement porté : ${liste || 'rien'}. Tu perds aussi ${perte.toLocaleString('fr-FR')} pièces. Tu repars avec une arme rouillée ; ton sac est intact.`, () => fondu(() => lancerHub())), 1800);
}

// ---------------- Îles ----------------
let recolteJ = null, ouvriers = [], intendant = null, passeur = null, assaut = null, raid = null, ileVolee = null;
const RES_LABEL = { bois: 'Bois', minerai: 'Minerai', recolte: 'Récoltes' };
const heureMs = 3600 * 1000;
function prochaineHeure(h, depuis = Date.now()) { const d = new Date(depuis); d.setHours(h, 0, 0, 0); if (d.getTime() <= depuis) d.setDate(d.getDate() + 1); return d.getTime(); }
function iles() { return (J.iles = J.iles || []); }
function nbBati(ile, t) { return ile.batiments.filter(b => b.t === t).length; }
function maxOuvriers(ile) { return nbBati(ile, 'maison'); }
function vitesseIle(ile) { return 1 + 0.001 * ile.batiments.length + 0.05 * (ile.niveau - 1); }
function capaciteIle(ile) { return nbBati(ile, 'foyer') ? Infinity : 1000 * (1 + ile.taille); }
function stockIle(ile) { return ile.coffre[ILE_TYPES[ile.type].res] || 0; }
function totalCoffre(ile) { return Object.values(ile.coffre).reduce((a, b) => a + b, 0); }
function ajouterRes(ile, res, n) {
  const cap = capaciteIle(ile); const tot = totalCoffre(ile);
  const ajout = Math.max(0, Math.min(n, cap - tot));
  ile.coffre[res] = (ile.coffre[res] || 0) + ajout;
  return ajout;
}
function prixBatiment(ile, t) { const d = BATIMENTS[t]; return Math.round(d.prix * Math.pow(d.croiss || 1, nbBati(ile, t))); }
// production des ouvriers : tourne même quand le joueur est ailleurs (12 h max hors ligne)
function majProduction() {
  const now = Date.now();
  for (const ile of iles()) {
    const dt = Math.min(12 * heureMs, Math.max(0, now - (ile.maj || now))) / 1000;
    ile.maj = now;
    const n = Math.min(ile.ouvriers || 0, maxOuvriers(ile));
    if (!n || !dt) continue;
    ile.reste = (ile.reste || 0) + n * vitesseIle(ile) * dt / 8;
    const entier = Math.floor(ile.reste); ile.reste -= entier;
    if (entier) ajouterRes(ile, ILE_TYPES[ile.type].res, entier);
  }
}
function acheterIle(type, taille) {
  const prix = ILE_TAILLES[taille].prix;
  if (J.argent < prix) { UI.toast('Pas assez d’argent'); son('error_001', 0.4); return; }
  J.argent -= prix;
  const n = iles().filter(i => i.type === type).length;
  const ile = { id: 'i' + Date.now(), graine: Math.floor(Math.random() * 1e9), type, taille, niveau: 1, nom: `${ILE_TYPES[type].nom}${n ? ' ' + (n + 1) : ''}`,
    coffre: { bois: 0, minerai: 0, recolte: 0 }, batiments: [], ouvriers: 0, gardes: 0, champion: false, livre: 0, maj: Date.now(), assaut: prochaineHeure(HEURE_ASSAUT) };
  iles().push(ile);
  if (!J.prochainRaid) J.prochainRaid = Date.now() + rnd(100, 140) * 60000;
  sauver(); son('jingle_legend', 0.6);
  UI.toast(`${ILE_TAILLES[taille].nom} achetée !`, true);
  entrerIle(ile);
}
function ileBot() {
  const ip = statsHeros(J.equip).ip;
  const type = hasard(Object.keys(ILE_TYPES)); const taille = Math.floor(Math.random() * 3);
  const proprio = donneesBot(ip);
  const ile = { id: 'bot', graine: Math.floor(Math.random() * 1e9), type, taille, niveau: 1 + Math.floor(Math.random() * 5), nom: `Île de ${proprio.nom}`, proprio,
    coffre: { bois: 0, minerai: 0, recolte: 0 }, batiments: [], gardes: 3, champion: true };
  ile.coffre[ILE_TYPES[type].res] = Math.round(rnd(2000, 9000) * (1 + taille));
  const n = nbEmplacements(ile); const types = ['maison', 'maison', 'maison', 'route', 'jardin', 'puits', 'moulin', 'tour', 'foyer', 'atelier'];
  for (let i = 0; i < n; i++) if (Math.random() < 0.75) ile.batiments.push({ plot: i, t: types[i % types.length] });
  return ile;
}

function entrerIle(ile, opts = {}) {
  fondu(() => {
    viderMonde(); invasion = null; arene = null; selection = null; assaut = null; recolteJ = null;
    majProduction();
    const etr = ile.id === 'bot';
    modeActuel = { id: 'ile', nom: ile.nom, lieu: ile.nom, argent: 0, xp: 0, tiers: [1, 1], mobTier: 1 };
    monde = construireIle(ile, etr);
    construireJoueur(monde.spawn.clone());
    joueur.pv = joueur.st.pvMax; joueur.energie = joueur.st.energieMax;
    G.camTarget.copy(joueur.pos);
    G.scene.background.set('#8fb8d8'); G.scene.fog.color.set('#9cc2dc'); G.scene.fog.density = 0.006; G.hemi.intensity = 1.35; G.sun.intensity = 1.7; G.sun.color.set('#fff2d8');
    if (groupe) creerCombattant(pointLibrePres(monde.spawn, 1.5, 3), groupe, 'allie');
    // gardes de l'île : sur ton île ils te défendent, chez les autres ils défendent le coffre
    const ipJ = statsHeros(J.equip).ip;
    const postes = [[-5, 3], [3, -5], [-6, -6], [6, 6]];
    const nG = etr ? ile.gardes : ile.gardes || 0;
    for (let i = 0; i < nG + ((etr || ile.champion) ? 1 : 0); i++) {
      const champ = i === nG;
      const def = champ ? CHAMPION_ILE : GARDES_ILE[i];
      const d = donneesBot(ipJ * def.ratio);
      d.nom = etr ? `${def.nom} de ${ile.proprio.nom}` : def.nom; d.guilde = etr ? ile.proprio.guilde : 'GARDE DE L’ÎLE';
      const pp = pointLibrePres(monde.coffrePos.clone().add(V(postes[i][0], 0, postes[i][1])), 0, 2);
      const g = creerCombattant(pp, d, etr ? 'ennemi' : 'allie');
      g.garde = true; g.poste = pp.clone(); g.gardeIle = etr;
      if (champ) { g.root.scale.setScalar(1.25); g.hauteurPlaque = 3.1; g.pvMax = g.pv = g.pvMax * 1.6; }
      g.jouer(g.armeDef.idle);
    }
    if (!etr) {
      intendant = new Acteur('Mage', { hauteur: 2.0 });
      habiller(intendant, genererEquipRival(300, 'baton'), ARMES.baton);
      intendant.root.position.copy(monde.intendantPos); intendant.pos = intendant.root.position; intendant.hauteurPlaque = 2.6;
      intendant.root.rotation.y = Math.atan2(monde.spawn.x - monde.intendantPos.x, monde.spawn.z - monde.intendantPos.z);
      intendant.jouer('Idle'); G.scene.add(intendant.root);
      monde.collisions.push({ x: intendant.pos.x, z: intendant.pos.z, r: 0.7 });
      UI.plaque(intendant, { nom: 'Oswin', guilde: 'INTENDANT', classe: 'pnj', vie: false });
      const n = Math.min(ile.ouvriers || 0, maxOuvriers(ile), 10);
      for (let i = 0; i < n; i++) creerOuvrier(ile, i);
    }
    const T = ILE_TYPES[ile.type];
    UI.zone(ile.nom, etr ? 'Pillage' : `${ILE_TAILLES[ile.taille].nom} · niv. ${ile.niveau}`);
    if (etr) { UI.journal('Pillage', `Élimine les gardes de ${ile.proprio.nom} pour ouvrir son coffre. Tu ne peux rien récolter ici.`, null); setTimeout(() => UI.toast(`Île de ${ile.proprio.nom}`, true), 600); }
    else { journalIle(ile); setTimeout(() => UI.toast(ile.nom, true), 600); if (!ile.vu) { ile.vu = true; setTimeout(() => UI.toast('Parle à Oswin, ton intendant : il t’explique tout'), 2400); } }
    $('#btnQuitter').hidden = true;
    if (opts.raid) lancerRaidSurPlace(ile, opts.raid);
    if (opts.assaut) lancerAssaut(ile);
    G.renderer.compile(G.scene, G.camera);
    sauver();
  });
}
function journalIle(ile) {
  const T = ILE_TYPES[ile.type];
  const cap = capaciteIle(ile);
  UI.journal(ile.nom, `${T.label} : ${fmtN(stockIle(ile))}${cap < Infinity ? ' / ' + fmtN(cap) : ''} · Ouvriers ${Math.min(ile.ouvriers || 0, maxOuvriers(ile))}/${maxOuvriers(ile)} · Assaut à ${HEURE_ASSAUT} h`, null);
}

// ---- ouvriers (visuels : la production est calculée par majProduction) ----
function creerOuvrier(ile, i) {
  const T = ILE_TYPES[ile.type];
  const a = new Acteur(T.ouvrier, { hauteur: 1.95 });
  const tous = Object.keys(a.nodes).filter(n => /Sword|Axe|Shield|Crossbow|Staff|Wand|Knife|Throwable|Mug|Spellbook|Offhand/.test(n));
  a.montrerSeul(ile.type === 'bois' ? ['1H_Axe'] : [], tous);
  if (ile.type === 'mine') a.attacher('tool_pickaxe', 'handslot.r', { echelle: 0.75 });
  const cape = Object.keys(a.nodes).find(n => n.endsWith('_Cape')); if (cape) a.teinter(cape, T.couleur, 0.55);
  a.root.position.copy(pointLibrePres(monde.coffrePos, 2, 5)); a.pos = a.root.position;
  G.scene.add(a.root);
  Object.assign(a, { etat: 'cherche', t: rnd(0, 2), cible: null, angle: 0, hauteurPlaque: 2.5 });
  UI.plaque(a, { nom: hasard(['Bram', 'Lutz', 'Ivo', 'Mara', 'Tibo', 'Nell', 'Gus', 'Odile', 'Pip', 'Rune']), guilde: 'OUVRIER', classe: 'pnj', vie: false, lettre: false });
  ouvriers.push(a);
}
function majOuvriers(dt) {
  const ile = monde.ile; if (!ile) return;
  for (const o of ouvriers) {
    o.t -= dt;
    if (o.etat === 'cherche') {
      const vivants = monde.noeuds.filter(n => n.pv > 0);
      o.cible = hasard(vivants.length ? vivants : monde.noeuds);
      o.etat = 'va'; o.jouer('Walking_A');
    } else if (o.etat === 'va' || o.etat === 'retour') {
      const but = o.etat === 'va' ? o.cible.pos : monde.coffrePos;
      const d = dist2D(o.pos, but);
      if (d < (o.etat === 'va' ? o.cible.rayon + 1.0 : 2.2)) {
        if (o.etat === 'va') { o.etat = 'recolte'; o.t = rnd(4, 7); o.jouer(ile.type === 'cueillette' ? 'PickUp' : '1H_Melee_Attack_Chop', { vitesse: ile.type === 'cueillette' ? 0.8 : 0.9 }); }
        else { o.etat = 'depose'; o.t = 1.2; o.jouer('Interact'); if (o.charge) { o.charge.removeFromParent(); o.charge = null; } }
        o.angle = Math.atan2(but.x - o.pos.x, but.z - o.pos.z); o.root.rotation.y = o.angle;
      } else {
        const dir = V(but.x - o.pos.x, 0, but.z - o.pos.z).normalize();
        deplacer(o, dir.x * 2.6 * dt, dir.z * 2.6 * dt, 0.45);
        o.angle = tourner(o.angle, Math.atan2(dir.x, dir.z), dt * 8); o.root.rotation.y = o.angle;
      }
    } else if (o.etat === 'recolte') {
      if (Math.random() < dt * 1.3) effetRecolte(o.cible, ile.type, 0.4);
      if (o.t <= 0) {
        o.etat = 'retour'; o.jouer('Walking_A');
        const cle = ile.type === 'bois' ? 'Wood_Log_A' : ile.type === 'mine' ? (o.cible && o.cible.obj.children[1] ? 'Iron_Nuggets' : 'Iron_Nuggets') : 'proc_citrouille';
        o.charge = o.attacher(cle, 'handslot.l', { echelle: cle === 'proc_citrouille' ? 0.45 : 0.8 });
      }
    } else if (o.etat === 'depose' && o.t <= 0) o.etat = 'cherche';
    if (o.pos.distanceTo(joueur.pos) < 50) o.maj(dt);
  }
}
function effetRecolte(n, type, force = 1) {
  if (!n) return;
  const p = V(n.pos.x, type === 'bois' ? 1.4 : 1.2, n.pos.z);
  if (type === 'bois') emettre(p, { n: Math.round(10 * force), c1: '#d8a868', c2: '#7a4a22', vit: 4, vie: 0.6, taille: 0.25, grav: 8, hemi: true });
  else if (type === 'mine') emettre(p, { n: Math.round(12 * force), c1: '#fff2b0', c2: '#9aa0aa', vit: 5, vie: 0.4, taille: 0.2, grav: 9 });
  else emettre(p, { n: Math.round(10 * force), c1: '#9dff6a', c2: '#ff6a8a', vit: 3, vie: 0.7, taille: 0.25, grav: 4 });
  noeudReel(n, true); n.secoue = 0.25;
  if (force >= 1) son(type === 'bois' ? 'chop' : type === 'mine' ? (Math.random() < 0.5 ? 'impactMining_000' : 'impactMining_001') : 'handleSmallLeather', 0.5);
}
function majNoeuds(dt) {
  for (const n of monde.noeuds) {
    if (n.secoue > 0) { n.secoue -= dt; n.obj.rotation.z = Math.sin(n.secoue * 60) * 0.04 * (n.secoue / 0.25); }
    if (n.pv <= 0) { n.regenT -= dt; if (n.regenT <= 0) { n.pv = n.pvMax; n.obj.visible = true; n.souche.visible = false; n.obj.scale.setScalar(0.01); n.pousse = 1; } }
    if (n.pousse > 0) { n.pousse = Math.max(0, n.pousse - dt * 1.5); n.obj.scale.setScalar(1 - n.pousse); }
    if (n.reel && n.pv > 0 && !(n.secoue > 0) && !(n.pousse > 0)) noeudReel(n, false);
  }
}
// ---- récolte par le joueur (uniquement sur ses îles) ----
function commencerRecolte(n) {
  const ile = monde.ile; const T = ILE_TYPES[ile.type];
  if (capaciteIle(ile) - totalCoffre(ile) <= 0) { UI.toast('Coffre plein : construis ta maison ou vends des ressources'); son('error_001', 0.4); return; }
  recolteJ = { n, t: 0.35, outil: null };
  const arme = joueur.nodes[joueur.def.node]; if (arme) arme.visible = false;
  if (T.outil) recolteJ.outil = joueur.attacher(T.outil, 'handslot.r', { echelle: 0.75 });
  joueur.angle = Math.atan2(n.pos.x - joueur.pos.x, n.pos.z - joueur.pos.z); joueur.root.rotation.y = joueur.angle;
}
function arreterRecolte() {
  if (!recolteJ) return;
  if (recolteJ.outil) recolteJ.outil.removeFromParent();
  const arme = joueur.nodes[joueur.def.node]; if (arme) arme.visible = true;
  recolteJ = null; joueur.jouer(joueur.def.idle);
}
function majRecolteJoueur(dt) {
  if (!recolteJ) return;
  const bouge = Math.hypot(entree.jx, entree.jy) > 0.12 || entree.atk || joueur.mort;
  const n = recolteJ.n;
  if (bouge || n.pv <= 0 || dist2D(n.pos, joueur.pos) > n.rayon + 3) return arreterRecolte();
  recolteJ.t -= dt;
  if (recolteJ.t > 0) return;
  recolteJ.t = 1.35;
  const ile = monde.ile; const T = ILE_TYPES[ile.type];
  joueur.jouer(ile.type === 'cueillette' ? 'PickUp' : '1H_Melee_Attack_Chop', { boucle: false, forcer: true, vitesse: ile.type === 'cueillette' ? 1.1 : 1.0 });
  programmer(ile.type === 'cueillette' ? 0.55 : 0.45, () => {
    if (!recolteJ || recolteJ.n !== n) return;
    effetRecolte(n, ile.type, 1);
    const gain = Math.round(rnd(2, 4) * vitesseIle(ile));
    const ok = ajouterRes(ile, T.res, gain);
    UI.nombre(V(n.pos.x, 2.6, n.pos.z), ok ? `+${ok} ${T.label}` : 'Coffre plein', ok ? 'soin' : 'info');
    n.pv--;
    if (n.pv <= 0) { noeudReel(n, true); n.obj.visible = false; n.souche.visible = true; n.regenT = 40; arreterRecolte(); son('impactPlank_medium_000', 0.5, 0.8); }
    if (!ok) arreterRecolte();
    journalIle(ile); sauver();
  });
}
// ---- construction ----
function construire(ile, plot, t) {
  const prix = prixBatiment(ile, t);
  if (J.argent < prix) { UI.toast('Pas assez d’argent'); son('error_001', 0.4); return; }
  if (BATIMENTS[t].unique && nbBati(ile, t)) { UI.toast('Déjà construit'); return; }
  J.argent -= prix; ile.batiments.push({ plot, t }); sauver();
  son('jingle_loot', 0.5); UI.toast(`${BATIMENTS[t].nom} construit · +0,1 % de vitesse`);
  const pos = joueur.pos.clone();
  entrerIleSansFondu(ile, pos);
}
function entrerIleSansFondu(ile, pos) { // reconstruit l'île en gardant la position du joueur
  const garde = { pv: joueur.pv };
  entrerIle(ile);
  setTimeout(() => { if (joueur && monde.ile === ile) { joueur.pos.copy(pos); G.camTarget.copy(pos); } }, 650);
}
// ---- intendant : améliorer, vendre, ouvriers, sécurité ----
const API_ILE = {
  livrer: (ile) => {
    const besoin = ILE_NIVEAUX[ile.niveau + 1]; if (!besoin) return UI.toast('Niveau maximum atteint');
    const res = ILE_TYPES[ile.type].res;
    const manque = besoin - (ile.livre || 0);
    const don = Math.min(manque, ile.coffre[res] || 0);
    if (!don) { UI.toast(`Il te faut du ${RES_LABEL[res].toLowerCase()} dans ton coffre`); return; }
    ile.coffre[res] -= don; ile.livre = (ile.livre || 0) + don;
    if (ile.livre >= besoin) { ile.niveau++; ile.livre = 0; son('jingle_legend', 0.6); UI.toast(`${ile.nom} passe au niveau ${ile.niveau} !`, true); sauver(); entrerIleSansFondu(ile, joueur.pos.clone()); return; }
    son('handleCoins', 0.5); UI.toast(`Livré : ${fmtN(don)} ${RES_LABEL[res]}`); sauver(); journalIle(ile);
  },
  vendre: (ile, res, part) => {
    const n = Math.floor((ile.coffre[res] || 0) * part); if (!n) return;
    const prix = ILE_TYPES[RESSOURCES[res]].prix;
    ile.coffre[res] -= n; J.argent += n * prix; son('handleCoins', 0.7);
    UI.toast(`Vendu ${fmtN(n)} ${RES_LABEL[res]} : +${fmtN(n * prix)}`); sauver(); journalIle(ile);
  },
  invoquer: (ile, delta) => {
    const v = Math.max(0, Math.min(maxOuvriers(ile), (ile.ouvriers || 0) + delta));
    if (v === (ile.ouvriers || 0)) { if (delta > 0) UI.toast('Construis une maison d’ouvrier pour en invoquer un de plus'); return; }
    majProduction(); ile.ouvriers = v; sauver();
    if (delta > 0 && monde.ile === ile && ouvriers.length < 10) { creerOuvrier(ile, ouvriers.length); onde(ouvriers[ouvriers.length - 1].pos, '#ffd25a', 3, 0.6); }
    if (delta < 0 && monde.ile === ile && ouvriers.length > v) { const o = ouvriers.pop(); G.scene.remove(o.root); UI.retirerPlaque(o); }
    son('confirmation_001', 0.4); journalIle(ile);
  },
  garde: (ile, i) => {
    const def = i === 'champion' ? CHAMPION_ILE : GARDES_ILE[i];
    if (i !== 'champion' && i !== (ile.gardes || 0)) return;
    if (J.argent < def.prix) { UI.toast('Pas assez d’argent'); son('error_001', 0.4); return; }
    J.argent -= def.prix; if (i === 'champion') ile.champion = true; else ile.gardes = (ile.gardes || 0) + 1;
    sauver(); son('jingle_win', 0.5); UI.toast(`${def.nom} recruté`); entrerIleSansFondu(ile, joueur.pos.clone());
  },
};

// ---- assaut des bandits (chaque jour à 21 h) ----
function lancerAssaut(ile) {
  assaut = { ile, fini: false };
  UI.flashInvasion(); UI.toast('ASSAUT DES BANDITS', true); UI.toast('Défends ton coffre !');
  son('lowFrequency_explosion_000', 0.7, 0.7);
  const ipJ = statsHeros(J.equip).ip;
  for (let i = 0; i < 6; i++) {
    const chef = i === 5;
    const d = donneesBot(ipJ * (chef ? 0.95 : 0.7));
    d.nom = chef ? 'Chef des bandits' : hasard(['Bandit des récifs', 'Pilleur', 'Écumeur', 'Coupe-jarret']); d.guilde = 'BANDITS';
    const a = Math.random() * 6.28; const p = pointLibrePres(monde.centre.clone().add(V(Math.cos(a) * monde.rayonMonde * 0.75, 0, Math.sin(a) * monde.rayonMonde * 0.75)), 0, 4);
    const b = creerCombattant(p, d, 'ennemi'); b.bandit = true; b.potions = chef ? 1 : 0;
    if (chef) { b.root.scale.setScalar(1.2); b.pvMax = b.pv = b.pvMax * 1.5; }
    effetArrivee(p);
  }
  UI.journal('Assaut des bandits', 'Élimine tous les bandits. Si tu tombes, ils emportent 70 % de ton coffre.', null);
}
function butinBandits(ile) { return Math.round(4000 * (1 + ile.taille) * (1 + ile.niveau * 0.25)); }
function finCombatIle(e) {
  setTimeout(() => { e.descendre = true; }, 3000);
  const restants = ennemis.filter(x => x.rival && !x.mort && (x.bandit || x.gardeIle));
  if (restants.length) return;
  if (assaut && !assaut.fini) {
    assaut.fini = true; const b = butinBandits(assaut.ile);
    J.argent += b; son('jingle_win', 0.6); UI.toast('Assaut repoussé !', true); UI.toast(`Le coffre des bandits : +${fmtN(b)}`);
    gagnerXPRelatif(0.06); journalIle(assaut.ile); sauver();
  } else if (monde.etranger) {
    UI.toast('Le coffre est sans défense !', true); son('jingle_win', 0.6);
    UI.journal('Pillage', `Ouvre le coffre de ${monde.ile.proprio.nom} et repars par le portail doré.`, 1);
    gagnerXPRelatif(0.08);
  }
}
function majAssauts() {
  const now = Date.now();
  for (const ile of iles()) {
    if (!ile.assaut) ile.assaut = prochaineHeure(HEURE_ASSAUT);
    if (!ile.alerte && ile.assaut - now < 15 * 60000 && ile.assaut > now) { ile.alerte = true; UI.toast(`Les bandits attaquent ${ile.nom} dans 15 min`); }
    if (now < ile.assaut) continue;
    ile.assaut = prochaineHeure(HEURE_ASSAUT, now); ile.alerte = false;
    if (monde.type === 'ile' && monde.ile === ile && !assaut) { lancerAssaut(ile); continue; }
    // absent : les gardes s'en chargent, sinon les bandits pillent 70 % du coffre
    const lignes = [];
    if ((ile.gardes || 0) > 0 || ile.champion) {
      const b = Math.round(butinBandits(ile) * 0.1); J.argent += b;
      lignes.push(`Tes gardes ont repoussé les bandits sur ${ile.nom}.`, `Ta part de leur coffre (10 %) : +${fmtN(b)}`, 'Sois présent à 21 h pour récupérer 100 % du butin.');
    } else {
      const pertes = []; for (const r in ile.coffre) { const p = Math.floor(ile.coffre[r] * 0.7); if (p) { ile.coffre[r] -= p; pertes.push(`${fmtN(p)} ${RES_LABEL[r]}`); } }
      lignes.push(`Personne ne défendait ${ile.nom}.`, pertes.length ? `Les bandits ont emporté 70 % du coffre : ${pertes.join(', ')}` : 'Ton coffre était vide : ils sont repartis bredouilles.', 'Recrute des gardes chez Oswin, ou sois là à 21 h.');
    }
    sauver(); UI.rapport('Assaut des bandits', lignes);
  }
}
// ---- pillards (autres joueurs) : de temps en temps, environ toutes les 2 h ----
function majRaids() {
  if (!iles().length || raid || transition || arene) return;
  if (!J.prochainRaid) J.prochainRaid = Date.now() + rnd(100, 140) * 60000;
  if (Date.now() < J.prochainRaid) return;
  J.prochainRaid = Date.now() + rnd(100, 140) * 60000; sauver();
  const ile = hasard(iles());
  const d = donneesBot(statsHeros(J.equip).ip + rnd(-60, 90));
  raid = { ile, d };
  son('lowFrequency_explosion_000', 0.6, 0.9);
  UI.alerteRaid(d, ile, (choix) => {
    if (choix === 'y aller') entrerIle(ile, { raid: d });
    else resoudreRaidGardes(ile, d);
  });
}
function resoudreRaidGardes(ile, d) {
  raid = null;
  const ipJ = statsHeros(J.equip).ip;
  const defense = (ile.gardes || 0) * 0.32 * ipJ + (ile.champion ? 0.55 * ipJ : 0);
  const lignes = [];
  if (defense > 0 && defense * rnd(0.75, 1.25) > d.ip * 0.8) {
    const b = Math.round(60 * Math.pow(2.3, d.equip.arme.tier - 1)); J.argent += b;
    lignes.push(`Tes gardes ont repoussé ${d.nom} (⚔ ${d.ip}).`, `Butin récupéré sur lui : +${fmtN(b)}`);
  } else {
    const pertes = []; for (const r in ile.coffre) { const p = Math.floor(ile.coffre[r] * 0.25); if (p) { ile.coffre[r] -= p; pertes.push(`${fmtN(p)} ${RES_LABEL[r]}`); } }
    lignes.push(`${d.nom} (⚔ ${d.ip}) a pillé ${ile.nom}${defense ? ' malgré tes gardes' : ''}.`, pertes.length ? `Perdu : ${pertes.join(', ')}` : 'Ton coffre était vide.');
  }
  sauver(); UI.rapport('Pillage de ton île', lignes);
}
function lancerRaidSurPlace(ile, d) {
  const p = pointLibrePres(monde.coffrePos, 2, 4);
  effetArrivee(p);
  const r = creerCombattant(p, d, 'ennemi'); r.pillard = true; r.volT = 45;
  ileVolee = ile; raid = { ile, d, r };
  UI.toast(`${d.nom} vide ton coffre !`, true);
  UI.journal('Pillard !', `Tue ${d.nom} avant qu’il ne s’enfuie avec 25 % de ton coffre.`, 0);
  setTimeout(() => !r.mort && UI.chat(r.nom, hasard(['oups, pris la main dans le sac', 'trop tard', 'merci pour le bois :)'])), 1500);
}
function majPillard(dt) {
  if (!raid || !raid.r) return;
  const r = raid.r;
  if (r.mort) { raid = null; return; }
  r.volT -= dt;
  UI.journal('Pillard !', `${r.nom} vide ton coffre : il s’enfuit dans ${Math.ceil(r.volT)} s.`, 1 - r.volT / 45);
  if (r.volT <= 0) {
    const ile = raid.ile; const pertes = [];
    for (const k in ile.coffre) { const p = Math.floor(ile.coffre[k] * 0.25); if (p) { ile.coffre[k] -= p; pertes.push(`${fmtN(p)} ${RES_LABEL[k]}`); } }
    effetArrivee(r.pos); G.scene.remove(r.root); UI.retirerPlaque(r); r.mort = true; ennemis.splice(ennemis.indexOf(r), 1);
    UI.boss(null); raid = null; sauver();
    UI.rapport('Le pillard s’est enfui', [pertes.length ? `Perdu : ${pertes.join(', ')}` : 'Ton coffre était vide.']);
    journalIle(ile);
  }
}

// ---- vie du monde : les joueurs de la Place ----
const PHRASES_RETOUR = ['coffre violet !!', 'le dragon m’a eu…', 'facile ce donjon', 'gg l’arène', '+100 trophées', 'mon île a bien produit', 'qui vend du T3 ?', 'enfin un légendaire'];
function destinationBot(b) {
  const r = Math.random();
  const devant = (p, d = 4.5) => { const v = p.clone().setY(0); return v.addScaledVector(v.clone().negate().normalize(), d); };
  if (r < 0.18 && marchand) return { type: 'marchand', p: marchand.pos.clone().add(V(2.4, 0, 2.4)) };
  if (r < 0.32) return { type: 'portail', p: devant(monde.portail.pos), porte: monde.portail.pos };
  if (r < 0.42) return { type: 'portail', p: devant(monde.portailArene.pos), porte: monde.portailArene.pos };
  if (r < 0.50) return { type: 'portail', p: devant(monde.portailIle.pos, 2.5), porte: monde.portailIle.pos };
  if (r < 0.58) return { type: 'fontaine', p: V(Math.cos(r * 40) * 3.6, 0, Math.sin(r * 40) * 3.6) };
  return null;
}
function majVieBot(b, dt) {
  if (b.absentT > 0) { // dans un donjon, l'arène ou sur son île
    b.absentT -= dt;
    if (b.absentT <= 0) {
      b.mort = false; b.root.visible = true; b.pos.copy(pointLibrePres(b.retour, 2, 4)); effetPortail(b.pos, b.couleurPortail);
      b.jouer('Cheer', { boucle: false, fin: () => b.jouer('Idle') }); b.etat = 'idle'; b.timer = rnd(3, 6);
      if (Math.random() < 0.6) setTimeout(() => UI.chat(b.nom, hasard(PHRASES_RETOUR)), 1200);
    }
    return true;
  }
  if (b.etat === 'commerce') {
    b.timer -= dt; if (b.timer <= 0) { b.etat = 'idle'; b.timer = rnd(1, 3); b.jouer('Idle'); if (marchand) marchand.jouer('Idle'); }
    return false;
  }
  if (b.etat !== 'but') return false;
  const d = dist2D(b.pos, b.but.p);
  if (d < 1.0) {
    if (b.but.type === 'marchand') {
      b.etat = 'commerce'; b.timer = rnd(4, 8); b.jouer('Interact'); b.angle = Math.atan2(marchand.pos.x - b.pos.x, marchand.pos.z - b.pos.z); b.root.rotation.y = b.angle;
      marchand.jouer('Interact'); son('handleCoins', 0.15);
      if (Math.random() < 0.4) setTimeout(() => UI.chat(b.nom, hasard(['je revends mon butin', 'Borin t’as du bronze ?', 'combien la potion ?', 'vendu !'])), 800);
    } else if (b.but.type === 'portail') {
      b.mort = true; b.root.visible = false; b.absentT = rnd(45, 160); b.retour = b.but.porte;
      b.couleurPortail = b.but.porte === monde.portail.pos ? '#ff3a2a' : b.but.porte === monde.portailArene.pos ? '#b05aff' : '#ffc84a';
      effetPortail(b.pos, b.couleurPortail);
    } else { b.etat = 'idle'; b.timer = rnd(6, 14); b.jouer('Sit_Floor_Idle'); }
    return true;
  }
  const dir = V(b.but.p.x - b.pos.x, 0, b.but.p.z - b.pos.z).normalize();
  const v = 4.6 * dt;
  if (!deplacer(b, dir.x * v, dir.z * v, 0.5)) { b.bloque = (b.bloque || 0) + dt; if (b.bloque > 2) { b.etat = 'idle'; b.timer = 1; b.bloque = 0; b.jouer('Idle'); } }
  b.angle = tourner(b.angle, Math.atan2(dir.x, dir.z), dt * 8); b.root.rotation.y = b.angle; b.jouer('Running_A');
  return true;
}
function effetPortail(p, c) { onde(p, c, 3, 0.6); emettre(V(p.x, 1, p.z), { n: 30, c1: '#ffffff', c2: c, dir: V(0, 1, 0), vit: 5, disp: 1.5, rayon: 0.8, vie: 0.8, taille: 0.35 }); }
function creerPasseur() {
  const a = new Acteur('Knight', { hauteur: 2.05 });
  const tous = Object.keys(a.nodes).filter(n => /Sword|Axe|Shield|Crossbow|Staff|Wand|Knife|Throwable|Mug|Spellbook|Offhand/.test(n));
  a.montrerSeul([], tous); a.attacher('tool_lantern', 'handslot.l', { echelle: 0.6 });
  const cape = Object.keys(a.nodes).find(n => n.endsWith('_Cape')); if (cape) a.teinter(cape, '#ffc84a', 0.7, 0.2);
  a.root.position.copy(monde.passeur.pos); a.root.rotation.y = monde.passeur.rot; a.pos = a.root.position; a.hauteurPlaque = 2.65;
  a.jouer('Idle'); G.scene.add(a.root);
  UI.plaque(a, { nom: 'Aldric', guilde: 'MAÎTRE DES ÎLES', classe: 'pnj', vie: false });
  monde.collisions.push({ x: a.pos.x, z: a.pos.z, r: 0.7 });
  passeur = a;
}

// accès de débogage (console)
window.__jeu = { API, G, hub: () => lancerHub(), majRaids, get raid() { return raid; }, entrerDonjon, entrerIle, lancerAssaut: () => lancerAssaut(monde.ile), majAssauts, get iles() { return J.iles; }, get monde() { return monde; }, set raidT(v) { J.prochainRaid = v; }, tuerTout: () => ennemis.forEach(e => { if (!e.mort) { e.pv = 0; tuer(e); } }), get bots() { return bots; }, get allies() { return allies; }, get arene() { return arene; }, ecran: (p) => projeter(V(p.x, 1.2, p.z)), get invasion() { return invasion; }, set invasion(v) { invasion = v; }, lancerSort, ouvrirCoffre, get joueur() { return joueur; }, get ennemis() { return ennemis; }, get coffres() { return coffres; }, get J() { return J; }, get monde() { return monde; } };

initEntrees();
demarrer();
