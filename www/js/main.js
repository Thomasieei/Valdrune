// ===== Brèche Écarlate — boucle de jeu =====
import { THREE, G, initRendu, majCamera, rendre, majTorches, chargerAssets, chargerSons, son, ambiance, Acteur, cloner,
  emettre, majParticules, majVfx, ajouterVfx, onde, lueurSol, arcTaille, faisceau, telegraphe, meshCarreau, meshBoule, DIR_HAUT, DIR_DROITE, projeter, texRond, redimensionner } from './engine.js';
import { construireHub, construireDonjon, majFeux } from './world.js';
import { UI, iconeObjet, bustePersonnage } from './ui.js';
import { TIERS, ARMES, ARMURES, SORTS, MODES, COFFRES, BOSS, MOBS, BOTS, CHAT, tf } from './data.js';
import { creerArme, creerArmure, creerPotion, statsHeros, nomObjet, valeurObjet, prixVente, lootCoffre, lootMonstre, tirerCouleurCoffre } from './items.js';

const $ = (s) => document.querySelector(s);
const rnd = (a, b) => a + Math.random() * (b - a);
const V = (x = 0, y = 0, z = 0) => new THREE.Vector3(x, y, z);
const dist2D = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);

// ---------------- Sauvegarde ----------------
let J = null;
const CLE = 'breche-ecarlate-v1';
function sauver() { try { localStorage.setItem(CLE, JSON.stringify(J)); } catch (e) {} }
function charger() { try { const s = localStorage.getItem(CLE); return s ? JSON.parse(s) : null; } catch (e) { return null; } }
function nouvellePartie(nom, arme) {
  J = { nom, argent: 2500, potions: 5, sac: [], equip: {
    arme: creerArme(arme, 1, 0), casque: creerArmure('casque', 1, 0), plastron: creerArmure('plastron', 1, 0), bottes: creerArmure('bottes', 1, 0) } };
  for (const a of ['epee', 'arbalete', 'baton']) if (a !== arme) J.sac.push(creerArme(a, 1, 0));
  sauver();
}

// ---------------- État ----------------
let monde = null, joueur = null, ennemis = [], bots = [], projectiles = [], minuteries = [], coffres = [], marchand = null, sortie = null;
let invasion = null;
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
];
const SONS = ['knifeSlice', 'knifeSlice2', 'drawKnife2', 'handleCoins', 'creak1', 'doorOpen_1', 'metalLatch', 'cloth1', 'bookOpen', 'impactPlate_heavy_000', 'impactMetal_medium_001', 'impactGeneric_light_000',
  'footstep_concrete_000', 'footstep_concrete_001', 'click_001', 'open_001', 'close_001', 'confirmation_001', 'error_001', 'select_001', 'maximize_001', 'thrusterFire_000', 'explosionCrunch_000', 'lowFrequency_explosion_000', 'forceField_000',
  'jingle_win', 'jingle_loot', 'jingle_legend'].map(k => [k, `assets/audio/${k}.ogg`]);

async function demarrer() {
  initRendu($('#scene'));
  try {
    await chargerAssets(ASSETS, (k, nom) => { $('#charge i').style.width = (k * 100) + '%'; $('#chargeTxt').textContent = 'Chargement… ' + Math.round(k * 100) + ' %'; });
  } catch (e) { $('#chargeTxt').textContent = 'Un fichier du jeu n’a pas pu se charger (' + (e && e.message ? e.message : e) + '). Recharge la page.'; console.error(e); return; }
  monde = construireHub();
  G.scene.add(G.points);
  creerMarchand(); creerBots();
  G.camTarget.set(0, 0, 4);
  $('#charge').hidden = true; $('#chargeTxt').hidden = true;
  const sauve = charger();
  const menu = $('#menuTitre'); menu.hidden = false;
  let armeChoisie = 'epee';
  if (sauve) { J = sauve; $('#nomJoueur').value = J.nom; $('#jouer').textContent = 'Reprendre l’aventure'; $('#choixArme').hidden = true; }
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
    bouclier: 0, bouclierT: 0, soinT: 0, sprintT: 0, slowT: 0, bonusTir: false, invuln: 0, spinT: 0, verrouT: 0, dashT: 0,
    cds: j.cds || {}, cdMax: {}, sorts: {}, atkT: 0, cible: null, cibleVerrou: j.cibleVerrou || null, mort: false, st, hauteurPlaque: 2.55, combatT: 0, pasT: 0,
  });
  const ss = def.sorts;
  ['Q', 'W', 'E'].forEach((k, i) => { joueur.sorts[k] = SORTS[ss[i]]; joueur.sorts[k].id = ss[i]; });
  if (J.equip.plastron) joueur.sorts.R = Object.assign(SORTS.rempart, { id: 'rempart' });
  if (J.equip.casque) joueur.sorts.D = Object.assign(SORTS.souffle, { id: 'souffle' });
  if (J.equip.bottes) joueur.sorts.F = Object.assign(SORTS.ruee, { id: 'ruee' });
  for (const k in joueur.sorts) joueur.cdMax[k] = joueur.sorts[k].cd;
  joueur.cdMax.POT = 20; joueur.potions = J.potions;
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
  const modeles = ['Knight', 'Rogue_Hooded', 'Mage', 'Barbarian', 'Rogue'];
  const armesDe = { Knight: ['2H_Sword', '1H_Sword'], Rogue_Hooded: ['2H_Crossbow', 'Knife'], Rogue: ['1H_Crossbow', 'Knife'], Mage: ['2H_Staff', '1H_Wand'], Barbarian: ['2H_Axe', '1H_Axe'] };
  const n = 16;
  for (let i = 0; i < n; i++) {
    const [nom, tag, guilde] = BOTS[i % BOTS.length];
    const m = modeles[i % modeles.length];
    const a = new Acteur(m, { hauteur: 2.0 });
    const tous = Object.keys(a.nodes).filter(x => /Sword|Axe|Shield|Crossbow|Staff|Wand|Knife|Throwable|Mug|Spellbook/.test(x));
    const arme = armesDe[m][Math.random() < 0.7 ? 0 : 1];
    a.montrerSeul([arme], tous);
    const tier = 1 + Math.floor(Math.pow(Math.random(), 1.4) * 8);
    a.teinter(arme, TIERS[tier].color, 0.62, TIERS[tier].glow);
    const cape = Object.keys(a.nodes).find(x => x.endsWith('_Cape')); if (cape) a.teinter(cape, TIERS[1 + Math.floor(Math.random() * 8)].color, 0.6);
    let p; do { p = V(rnd(-24, 22), 0, rnd(-20, 20)); } while (!libre(p.x, p.z, 0.6));
    a.root.position.copy(p); a.root.rotation.y = rnd(0, 6.28);
    G.scene.add(a.root);
    Object.assign(a, { pos: a.root.position, nom, etat: 'idle', timer: rnd(0, 4), cible: null, vitesse: rnd(1.8, 2.6), hauteurPlaque: 2.55, angle: a.root.rotation.y });
    a.jouer(Math.random() < 0.25 ? 'Sit_Floor_Idle' : 'Idle');
    const ipBot = 300 + (tier - 1) * 100 + Math.round(rnd(-40, 70));
    UI.plaque(a, { nom, guilde: (tag ? `[${tag}] ` : '') + guilde, classe: 'allie', vie: false, ip: ipBot });
    bots.push(a);
  }
}
function majBots(dt) {
  for (const b of bots) {
    b.timer -= dt;
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
  for (const b of bots) G.scene.remove(b.root);
  for (const p of projectiles) G.scene.remove(p.mesh);
  for (const c of coffres) { G.scene.remove(c.obj); G.scene.remove(c.beam); }
  if (marchand) G.scene.remove(marchand.root);
  if (sortie) G.scene.remove(sortie.groupe);
  for (const v of G.vfx) G.scene.remove(v.obj);
  G.vfx = []; ennemis = []; bots = []; projectiles = []; coffres = []; minuteries = []; marchand = null; sortie = null;
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
  invasion = null;
  if (!premier) { viderMonde(); monde = construireHub(); creerMarchand(); creerBots(); }
  modeActuel = null; enJeu = true;
  construireJoueur(monde.spawn.clone());
  joueur.pv = joueur.st.pvMax; joueur.energie = joueur.st.energieMax;
  G.camTarget.copy(joueur.pos); G.camDist = 25; G.scene.fog.density = 0.016;
  G.hemi.intensity = 1.1; G.sun.intensity = 1.3;
  UI.journal('Place des Cendres', 'Parle à Borin pour t’équiper, puis franchis la Brèche Écarlate.');
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
  if (e.rival) { victoireRival(e); return; }
  const loot = lootMonstre(modeActuel);
  J.argent += loot.argent * (e.boss ? 12 : 1);
  UI.nombre(V(e.pos.x, 2.2, e.pos.z), '+' + Math.round(loot.argent * (e.boss ? 12 : 1)) + ' ¤', 'info');
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
  if (d > st.portee) {
    if (Math.abs(entree.jx) + Math.abs(entree.jy) < 0.1) { // s'approche tout seul
      const dir = V(c.pos.x - joueur.pos.x, 0, c.pos.z - joueur.pos.z).normalize();
      deplacer(joueur, dir.x * st.vitesse * dt, dir.z * st.vitesse * dt);
      faireFace(dir); joueur.jouer(def.run);
    }
    return;
  }
  const dir = V(c.pos.x - joueur.pos.x, 0, c.pos.z - joueur.pos.z).normalize(); faireFace(dir);
  if (joueur.atkT > 0) return;
  joueur.atkT = 1 / st.vitesseAtk;
  const anim = def.attaques[Math.floor(Math.random() * def.attaques.length)];
  const vit = Math.max(1, st.vitesseAtk * joueur.duree(anim) * 0.95);
  joueur.jouer(anim, { boucle: false, vitesse: vit, forcer: true, fondu: 0.08, fin: () => joueur.jouer(def.idle) });
  joueur.verrouT = 0.28;
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
  if (joueur.verrouT > 0.15 && !['rempart', 'souffle', 'ruee'].includes(s.id)) return;
  joueur.energie -= s.energie; joueur.cds[k] = s.cd; joueur.combatT = 4;
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
      const bulle = new THREE.Mesh(new THREE.SphereGeometry(1.5, 24, 16), new THREE.ShaderMaterial({ transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
        uniforms: { uT: { value: 0 } }, vertexShader: 'varying vec3 vN; varying vec3 vV; void main(){ vec4 mv=modelViewMatrix*vec4(position,1.0); vN=normalize(normalMatrix*normal); vV=normalize(-mv.xyz); gl_Position=projectionMatrix*mv; }',
        fragmentShader: 'uniform float uT; varying vec3 vN; varying vec3 vV; void main(){ float f=pow(1.0-abs(dot(vN,vV)),2.5); gl_FragColor=vec4(vec3(0.45,0.8,1.0)*(f*1.6+0.06), f*0.9+0.05); }' }));
      ajouterVfx(bulle, () => { bulle.position.set(joueur.pos.x, 1.1, joueur.pos.z); if (joueur.bouclier <= 0 || joueur.bouclierT <= 0) return false; });
      onde(joueur.pos, '#8fd3ff', 3, 0.5); son('forceField_000', 0.5, 1.4);
      break;
    }
    case 'souffle': { joueur.soinT = 3; son('confirmation_001', 0.4); onde(joueur.pos, '#9dff8a', 2.5, 0.6); break; }
    case 'ruee': { joueur.sprintT = 3; joueur.slowT = 0; son('cloth1', 0.6, 1.4); emettre(V(joueur.pos.x, 0.4, joueur.pos.z), { n: 20, c1: '#fff8c0', c2: '#ffd04a', vit: 3, vie: 0.5, taille: 0.35 }); break; }
  }
}
function boirePotion() {
  if ((joueur.cds.POT || 0) > 0 || joueur.potions <= 0 || joueur.mort) { son('error_001', 0.25); return; }
  joueur.potions--; J.potions = joueur.potions; joueur.cds.POT = 20; joueur.potionT = 1;
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
    let v = st.vitesse * (j.sprintT > 0 ? 1.6 : 1) * (j.slowT > 0 ? 0.6 : 1) * (j.spinT > 0 ? 0.7 : 1) * Math.max(0.35, m);
    deplacer(j, dir.x * v * dt, dir.z * v * dt);
    if (j.spinT <= 0) { j.angle = tourner(j.angle, Math.atan2(dir.x, dir.z), dt * 14); j.root.rotation.y = j.angle; }
    if (j.spinT <= 0 && (j.atkT < 0.1 || !entree.atk)) j.jouer(m > 0.55 ? j.def.run : 'Walking_A', { vitesse: m > 0.55 ? 1 : 1.3 });
    j.pasT -= dt * v; if (j.pasT <= 0) { j.pasT = 2.4; son(Math.random() < 0.5 ? 'footstep_concrete_000' : 'footstep_concrete_001', 0.12); }
  } else if (!bloque && j.spinT <= 0) {
    const c = j.courante; const n = c ? c.getClip().name : '';
    if (n === j.def.run || n === 'Walking_A') j.jouer(j.def.idle);
  }
  if (entree.atk || entree.clavier[' ']) attaquer(dt);
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
    const proche = d < 42;
    e.root.visible = d < 55;
    if (!proche) continue;
    // effets
    for (let k = e.dots.length - 1; k >= 0; k--) {
      const o = e.dots[k]; o.t -= dt; o.acc = (o.acc || 0) + dt;
      if (o.acc >= 0.5) { o.acc = 0; e.pv -= o.dps * 0.5; UI.nombre(V(e.pos.x, e.hauteurPlaque * 0.7, e.pos.z), Math.round(o.dps * 0.5), 'info'); emettre(V(e.pos.x, 1, e.pos.z), { n: 3, c1: o.c, c2: '#ffffff', vit: 1.5, vie: 0.4, taille: 0.25 }); if (e.pv <= 0) { tuer(e); break; } }
      if (o.t <= 0) e.dots.splice(k, 1);
    }
    if (e.mort) continue;
    if (e.stunT > 0) { e.stunT -= dt; if (Math.random() < dt * 8) emettre(V(e.pos.x, e.hauteurPlaque, e.pos.z), { n: 1, c1: '#fff7a0', c2: '#ffd040', vit: 0.6, vie: 0.5, taille: 0.25, rayon: 0.4 }); e.maj(dt * 0.15); continue; }
    if (e.airT > 0) { e.airT -= dt; e.root.position.y = Math.sin((0.6 - e.airT) / 0.6 * Math.PI) * 1.6; e.maj(dt); continue; } else if (!e.boss && !e.sautT) e.root.position.y = e.hover;
    if (e.slowT > 0) e.slowT -= dt;
    e.atkT -= dt;
    if (e.etat === 'idle') { if (d < 11) reveiller(e); e.maj(dt); continue; }
    if (e.etat === 'dormant') {
      const zone = monde.zoneDe(joueur.pos.x, joueur.pos.z);
      if (zone === e.salle.id || d < 13) reveiller(e);
      e.maj(dt); continue;
    }
    if (e.rival) { majRival(e, d, dt); e.maj(dt); continue; }
    if (e.boss) { UI.boss(e); majBoss(e, d, dt); e.maj(dt); continue; }
    majMob(e, d, dt);
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
  deplacer(e, dir.x * v, dir.z * v, e.rayon * 0.8);
  e.angle = tourner(e.angle, Math.atan2(dir.x, dir.z), dt * 10); e.root.rotation.y = e.angle;
}
function faceJoueur(e, dt, k = 10) { e.angle = tourner(e.angle, Math.atan2(joueur.pos.x - e.pos.x, joueur.pos.z - e.pos.z), dt * k); e.root.rotation.y = e.angle; }
function majMob(e, d, dt) {
  const def = e.def;
  if (joueur.mort) { e.jouer('Idle'); return; }
  if (e.attaqueT > 0) { e.attaqueT -= dt; faceJoueur(e, dt, 6); return; }
  const portee = def.portee;
  if (d > portee + e.rayon) { avancerVers(e, joueur.pos, dt, def.vitesse); e.jouer('Running_A'); return; }
  faceJoueur(e, dt);
  if (e.atkT > 0) { e.jouer('Idle_Combat'); return; }
  e.atkT = def.type === 'melee' ? rnd(1.6, 2.0) : rnd(2.2, 2.8);
  e.attaqueT = 0.7;
  e.jouer(def.atk, { boucle: false, forcer: true, vitesse: 1.1, fin: () => e.jouer('Idle_Combat') });
  if (def.type === 'melee') programmer(0.45, () => { if (!e.mort && e.stunT <= 0 && dist2D(e.pos, joueur.pos) < portee + e.rayon + 0.9) { blesserJoueur(e.dmg, e); son('impactGeneric_light_000', 0.3); } });
  else programmer(0.4, () => { if (!e.mort && e.stunT <= 0) tirEnnemi(e, def.type === 'caster' ? 'feu' : 'carreau', e.dmg); });
}
function tirEnnemi(e, type, dmg, dirForcee = null, vitesse = null) {
  const depart = V(e.pos.x, 1.3 * (e.boss ? Math.min(2.2, e.boss.scale) * 0.7 : 1) + (e.hover || 0), e.pos.z);
  const dest = V(joueur.pos.x, 1.1, joueur.pos.z);
  const dir = dirForcee ? dirForcee.clone() : dest.sub(depart).normalize();
  const coul = type === 'feu' ? '#ff4a2a' : '#c8ff9a';
  const mesh = type === 'feu' ? meshBoule(coul, e.boss ? 0.7 : 0.45) : meshCarreau(coul);
  mesh.position.copy(depart); mesh.lookAt(depart.clone().add(dir)); G.scene.add(mesh);
  const v = vitesse || (type === 'feu' ? 11 : 16);
  projectiles.push({ mesh, pos: mesh.position, vel: dir.multiplyScalar(v), vie: 16 / v * 1.4, camp: 'ennemi', type, dmg, couleur: coul, touches: new Set(), largeur: 0.75 });
  son(type === 'feu' ? 'thrusterFire_000' : 'drawKnife2', 0.15, type === 'feu' ? 1.2 : 1.5);
}

// ---------------- Boss ----------------
function majBoss(e, d, dt) {
  const b = e.boss; const enrage = e.pv < e.pvMax * 0.3;
  if (joueur.mort) return;
  if (e.sautT > 0) { // saut du Gardien
    e.sautT -= dt; const k = 1 - e.sautT / e.sautD;
    e.pos.x = e.sautA.x + (e.sautB.x - e.sautA.x) * k; e.pos.z = e.sautA.z + (e.sautB.z - e.sautA.z) * k; e.root.position.y = Math.sin(k * Math.PI) * 4;
    if (e.sautT <= 0) e.root.position.y = 0;
    return;
  }
  if (e.chargeT > 0) { e.chargeT -= dt; deplacer(e, e.chargeV.x * dt, e.chargeV.z * dt, 1.2); emettre(V(e.pos.x, 1.5, e.pos.z), { n: 3, c1: '#ffb84a', c2: '#ff2a00', vit: 2, vie: 0.5, taille: 0.8, rayon: 1.5 }); if (dist2D(e.pos, joueur.pos) < 2.6 && !e.chargeTouche) { e.chargeTouche = true; blesserJoueur(e.dmg * 3.0, e); } if (e.chargeT <= 0) e.jouer('Flying_Idle'); return; }
  if (e.attaqueT > 0) { e.attaqueT -= dt; return; }
  e.specT -= dt * (enrage ? 1.4 : 1);
  if (e.specT <= 0) { capaciteBoss(e); e.specT = rnd(5.5, 7); return; }
  const ranged = b.id === 'archere' || b.id === 'necro';
  const portee = ranged ? 10 : e.def.portee + e.rayon;
  if (d > portee) { avancerVers(e, joueur.pos, dt, e.def.vitesse * (enrage ? 1.25 : 1)); e.jouer(b.id === 'horreur' ? 'Fast_Flying' : 'Running_A'); return; }
  faceJoueur(e, dt, 6);
  if (e.atkT > 0) { e.jouer(b.id === 'horreur' ? 'Flying_Idle' : 'Idle_Combat'); return; }
  e.atkT = ranged ? 1.6 : 2.0; e.attaqueT = 0.8;
  if (b.id === 'horreur') { e.jouer(Math.random() < 0.5 ? 'Punch' : 'Headbutt', { boucle: false, forcer: true, fin: () => e.jouer('Flying_Idle') }); programmer(0.5, () => { if (!e.mort && dist2D(e.pos, joueur.pos) < portee + 1.2) blesserJoueur(e.dmg, e); }); }
  else if (ranged) { e.jouer(e.def.atk, { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') }); programmer(0.4, () => { if (!e.mort) tirEnnemi(e, b.id === 'necro' ? 'feu' : 'carreau', e.dmg * 0.75); }); }
  else { e.jouer('2H_Melee_Attack_Chop', { boucle: false, forcer: true, vitesse: 0.9, fin: () => e.jouer('Idle_Combat') }); programmer(0.55, () => { if (!e.mort && dist2D(e.pos, joueur.pos) < portee + 1.2) { blesserJoueur(e.dmg, e); G.shake = 0.4; } }); }
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
  const pj = joueur.pos.clone();
  if (b.id === 'gardien') {
    if (e.cycle % 2) {
      // bond et fracas
      e.jouer('1H_Melee_Attack_Jump_Chop', { boucle: false, forcer: true, vitesse: 0.8, fin: () => e.jouer('Idle_Combat') });
      e.sautA = e.pos.clone(); e.sautB = pj; e.sautD = e.sautT = 1.2; e.attaqueT = 1.6;
      telegraphe(pj, 3.8, 1.2, '#ff2a2a', () => { G.shake = 1; onde(pj, '#ff8a3a', 6, 0.6); emettre(V(pj.x, 0.3, pj.z), { n: 50, c1: '#d8c8a8', c2: '#6a5a4a', vit: 8, vie: 0.8, taille: 0.6, hemi: true, grav: 6 }); son('impactPlate_heavy_000', 0.8, 0.6); if (dist2D(joueur.pos, pj) < 3.8) { blesserJoueur(e.dmg * 3.4, e); joueur.slowT = 2.5; } });
    } else {
      e.jouer('2H_Melee_Attack_Spinning', { vitesse: 1.2, forcer: true }); e.attaqueT = 1.6;
      const c = e.pos.clone();
      telegraphe(c, 5.5, 1.4, '#ff2a2a', () => { onde(c, '#ffd0a0', 6, 0.5); son('knifeSlice', 0.7, 0.6); if (dist2D(joueur.pos, e.pos) < 5.5 + 0.4) blesserJoueur(e.dmg * 2.9, e); e.jouer('Idle_Combat'); });
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
        telegraphe(p, 2.6, 1.3 + i * 0.12, '#ff2a2a', () => { emettre(V(p.x, 0.4, p.z), { n: 30, c1: '#ff8aff', c2: '#ff1a4a', vit: 6, vie: 0.6, taille: 0.6, hemi: true }); onde(p, '#ff3a6a', 3, 0.4); son('explosionCrunch_000', 0.3, 1.2); if (dist2D(joueur.pos, p) < 2.6) blesserJoueur(e.dmg * 2.4, e); });
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
        const v = V(joueur.pos.x - c.x, 0, joueur.pos.z - c.z); const dd = v.length(); v.normalize();
        if (dd < 11 && v.dot(V(Math.sin(base), 0, Math.cos(base))) > Math.cos(0.65)) blesserJoueur(e.dmg * 3.6, e);
      }, { cone: 1.3, angle: base - Math.PI / 2 });
    } else if (r === 2) {
      e.attaqueT = 1.2; const dir = V(Math.sin(base), 0, Math.cos(base));
      telegraphe(e.pos, 18, 1.1, '#ff2a2a', () => { e.chargeT = 0.6; e.chargeV = dir.clone().multiplyScalar(30); e.chargeTouche = false; e.jouer('Fast_Flying', { vitesse: 2 }); son('lowFrequency_explosion_000', 0.5, 1.2); }, { ligne: true, largeur: 3.4, angle: base + Math.PI });
      e.angle = base; e.root.rotation.y = base;
    } else {
      e.attaqueT = 1; e.jouer('Punch', { boucle: false, forcer: true, fin: () => e.jouer('Flying_Idle') });
      for (let i = 0; i < 6; i++) {
        const p = i === 0 ? pj.clone() : pj.clone().add(V(rnd(-6, 6), 0, rnd(-6, 6)));
        telegraphe(p, 3, 1.6 + i * 0.1, '#ff2a2a', () => { G.shake = 0.5; emettre(V(p.x, 0.5, p.z), { n: 40, c1: '#fff0b0', c2: '#ff3a00', vit: 8, vie: 0.7, taille: 0.7, hemi: true }); onde(p, '#ff8a2a', 4, 0.5); son('explosionCrunch_000', 0.4, 0.8); if (dist2D(joueur.pos, p) < 3) blesserJoueur(e.dmg * 2.6, e); });
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
    } else if (!fini && p.camp === 'ennemi') {
      if (dist2D(joueur.pos, p.pos) < 0.85 && p.pos.y < 2.6) { blesserJoueur(p.dmg, null); fini = true; emettre(p.pos, { n: 12, c1: '#ffd0a0', c2: p.couleur, vit: 3, vie: 0.4, taille: 0.4 }); }
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
    if (k === 'POT') return boirePotion();
    if (k === 'CIBLE') { const c = choisirCible(16); joueur.cibleVerrou = joueur.cibleVerrou ? null : c; if (joueur.cibleVerrou) UI.toast('Cible : ' + (c.boss ? c.boss.nom : c.def.nom)); son('click_001', 0.4); return; }
    lancerSort(k);
  },
  equiper: (id) => {
    const i = J.sac.findIndex(x => x.id === id); if (i < 0) return;
    const it = J.sac[i]; const slot = it.cat === 'arme' ? 'arme' : it.type;
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
  accepterInvasion: (v) => { J.accepteInvasion = v; sauver(); UI.toast(v ? 'Ton monde est ouvert aux invasions' : 'Ton monde est fermé aux invasions'); },
  envahir: () => { const ip = statsHeros(J.equip).ip; entrerDonjon(ip < 560 ? 0 : ip < 860 ? 1 : 2, { envahir: true }); },
  qualite: (q) => { G.qualite = q; G.sun.castShadow = q === 'haute'; redimensionner(); },
  reset: () => { try { localStorage.removeItem(CLE); } catch (e) {} location.reload(); },
};
UI.init(API);

// ---------------- Interactions ----------------
function majInteractions() {
  if (joueur.mort) { UI.action(null); return; }
  if (!modeActuel) {
    if (marchand && dist2D(joueur.pos, marchand.pos) < 5) return UI.action('Parler à Borin', () => UI.dialogueMarchand());
    if (dist2D(joueur.pos, monde.portail.pos) < 9) return UI.action('Franchir la Brèche', () => UI.menuPortail());
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
  setTimeout(() => {
    UI.butin(c.couleur, loot, () => { J.argent += loot.argent; for (const it of loot.objets) ajouterSac(it, true); son('handleCoins', 0.6); sauver(); c.beam.visible = false; });
  }, 700);
}

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
  $('#btnReg').onclick = () => UI.reglages();
  $('#btnChat').onclick = () => UI.chat(J.nom, 'Salut tout le monde !');
  let quitConf = 0;
  $('#btnQuitter').onclick = () => {
    if (!modeActuel) return;
    if (Date.now() - quitConf > 2500) { quitConf = Date.now(); UI.toast('Touche encore pour quitter le donjon'); return; }
    fondu(() => lancerHub());
  };
}

// ---------------- Boucle ----------------
let dernier = performance.now(), hudT = 0, miniT = 0;
const ORBITE = V(0, 0, 0);
function boucle() {
  requestAnimationFrame(boucle);
  const now = performance.now(); let dt = Math.min(0.05, (now - dernier) / 1000); dernier = now;
  G.t += dt; G.dt = dt;
  for (const f of G.anims || []) f(G.t, dt);
  for (let i = minuteries.length - 1; i >= 0; i--) { const m = minuteries[i]; m.t -= dt; if (m.t <= 0) { minuteries.splice(i, 1); m.fn(); } }
  if (marchand) marchand.maj(dt);
  if (enJeu && joueur) {
    G.focus = joueur.pos;
    if (!transition) majJoueur(dt);
    if (!modeActuel) majBots(dt); else { majEnnemis(dt); majProjectiles(dt); majInvasion(dt); }
    majCamera(dt, joueur.pos);
    majTorches(joueur.pos);
    hudT -= dt; if (hudT <= 0) { hudT = 0.08; UI.majHud(joueur, joueur.st); UI.majSorts(joueur); majInteractions(); }
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
  rendre();
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
    for (const b of bots) ents.push({ type: 'joueur', x: b.pos.x, z: b.pos.z });
    if (marchand) ents.push({ type: 'pnj', x: marchand.pos.x, z: marchand.pos.z });
    ents.push({ type: 'portail', x: monde.portail.pos.x, z: monde.portail.pos.z });
  } else {
    for (const e of ennemis) if (!e.mort) ents.push({ type: e.boss || e.rival ? 'boss' : 'mob', x: e.pos.x, z: e.pos.z });
    for (const c of coffres) if (!c.ouvert) ents.push({ type: 'coffre', x: c.pos.x, z: c.pos.z, c: c.def.color });
    if (sortie) ents.push({ type: 'portail', x: sortie.pos.x, z: sortie.pos.z });
  }
  UI.mini(monde, joueur, ents);
}

initEntrees();
demarrer();

// ---------------- Invasions (joueurs rivaux) ----------------
const RIVAL_ARRIVEE = ['Ton stuff a l’air sympa', 'Coucou :)', 'Désolé, rien de personnel', 'On va voir ce que tu vaux', 'Pas de chance, c’est moi', 'je prends tout'];
const RIVAL_COMBAT = ['pas mal', 'tu fuis ?', 'allez', 'raté', 'presque', 'lag de fou là', 'aïe'];
const RIVAL_PERD = ['gg', 'gg bien joué', 'sérieux…', 'j’avais plus de potions', 'je reviendrai', 'ok t’es fort'];
const RIVAL_GAGNE = ['gg, merci pour le stuff', 'ez', 'merci pour l’équipement', 'fallait esquiver', 'gg wp'];
const hasard = (l) => l[Math.floor(Math.random() * l.length)];

function genererEquipRival(ipCible) {
  const tMoy = Math.max(1, Math.min(8, Math.round((ipCible - 320) / 100) + 1));
  const t = () => Math.max(1, Math.min(8, tMoy + (Math.random() < 0.25 ? 1 : Math.random() < 0.3 ? -1 : 0)));
  const q = () => (Math.random() < 0.45 ? 0 : 1 + Math.floor(Math.random() * 3));
  const type = ['epee', 'arbalete', 'baton'][Math.floor(Math.random() * 3)];
  return { arme: creerArme(type, t(), q()), casque: creerArmure('casque', t(), q()), plastron: creerArmure('plastron', t(), q()), bottes: creerArmure('bottes', t(), q()) };
}
function pointLibrePres(centre, dMin, dMax) {
  for (let i = 0; i < 60; i++) {
    const a = Math.random() * 6.28, r = rnd(dMin, dMax);
    const x = centre.x + Math.cos(a) * r, z = centre.z + Math.sin(a) * r;
    if (libre(x, z, 0.7)) return V(x, 0, z);
  }
  return centre.clone().add(V(2, 0, 2));
}
function creerRival(pos, equip) {
  const [nom, tag, guilde] = BOTS[Math.floor(Math.random() * BOTS.length)];
  const arme = equip.arme, def = ARMES[arme.type];
  const a = new Acteur(def.model, { hauteur: 2.0 });
  const tous = Object.keys(a.nodes).filter(n => /Sword|Axe|Shield|Crossbow|Staff|Wand|Knife|Throwable|Mug|Spellbook/.test(n));
  a.montrerSeul([def.node], tous);
  a.teinter(def.node, TIERS[arme.tier].color, 0.62, TIERS[arme.tier].glow);
  if (def.helmet) a.teinter(def.helmet, TIERS[equip.casque.tier].color, 0.5, TIERS[equip.casque.tier].glow * 0.3);
  a.teinter(def.cape, TIERS[equip.plastron.tier].color, 0.7, TIERS[equip.plastron.tier].glow * 0.25);
  a.teinter(def.body, TIERS[equip.plastron.tier].color, 0.28, 0);
  def.legs.forEach(l => a.teinter(l, TIERS[equip.bottes.tier].color, 0.3, 0));
  const st = statsHeros(equip);
  a.root.position.copy(pos); G.scene.add(a.root);
  Object.assign(a, {
    rival: true, def: { nom, model: def.model }, armeDef: def, equip, st, nom, guilde: (tag ? `[${tag}] ` : '') + guilde, ip: st.ip,
    pos: a.root.position, pv: st.pvMax, pvMax: st.pvMax, reduction: st.reduction, dmg: st.degats * 1.05,
    etat: 'chasse', atkT: 1.2, attaqueT: 1.2, stunT: 0, slowT: 0, dots: [], pack: -9, angle: 0, mort: false, hauteurPlaque: 2.55, rayon: 0.55, hover: 0,
    specT: rnd(3, 5), potions: 2, potionT: 0, esquiveT: 2, dashT: 0, bouclier: 0, strafe: Math.random() < 0.5 ? 1 : -1, chatT: rnd(10, 18),
    argent: Math.round(rnd(0.7, 1.4) * 500 * Math.pow(2.3, arme.tier - 1)),
  });
  a.jouer('Cheer', { boucle: false, fin: () => a.jouer(def.idle) });
  UI.plaque(a, { nom, guilde: a.guilde, classe: 'rival', ip: st.ip });
  ennemis.push(a);
  return a;
}
function effetArrivee(pos) {
  onde(pos, '#ff2a2a', 5, 0.8); onde(pos, '#ffb08a', 3, 0.6); lueurSol(pos, '#ff1a1a', 3, 1.4, 1);
  emettre(V(pos.x, 0.3, pos.z), { n: 80, c1: '#ff8a6a', c2: '#8a0000', dir: V(0, 1, 0), vit: 9, disp: 2, rayon: 1, vie: 1.2, taille: 0.6, frein: 1.5 });
  son('lowFrequency_explosion_000', 0.8, 0.8); son('forceField_000', 0.6, 0.6); G.shake = 0.6;
}
function majInvasion(dt) {
  if (!invasion || invasion.rival || joueur.mort || transition) return;
  invasion.t -= dt; if (invasion.t > 0) return;
  const ipCible = statsHeros(J.equip).ip + Math.round(rnd(-50, 90));
  const equip = genererEquipRival(ipCible);
  if (invasion.mode === 'subie') {
    const pos = pointLibrePres(joueur.pos, 11, 16);
    effetArrivee(pos);
    const r = invasion.rival = creerRival(pos, equip);
    UI.flashInvasion();
    UI.toast('INVASION', true);
    UI.toast(`${r.nom} ${r.guilde} · Puissance ${r.ip} a envahi ton monde`);
    setTimeout(() => !r.mort && UI.chat(r.nom, hasard(RIVAL_ARRIVEE)), 1800);
    UI.journal('Invasion !', `${r.nom} est venu te dépouiller. Tue-le ou perds tout ton équipement.`, null);
  } else {
    const salles = monde.salles.filter(s => s.type === 'normale');
    const s = salles.sort((a, b) => dist2D(b.centre, joueur.pos) - dist2D(a.centre, joueur.pos))[Math.floor(Math.random() * 3)];
    const pos = pointLibrePres(s.centre, 0, 4);
    const r = invasion.rival = creerRival(pos, equip);
    r.attaqueT = 0; r.jouer(r.armeDef.idle);
    UI.toast(`Tu as envahi le monde de ${r.nom}`, true);
    UI.toast(`${r.guilde} · Puissance ${r.ip}`);
    UI.journal('Invasion', `Traque ${r.nom} (puissance ${r.ip}) et prends-lui tout. Le point rouge sur la carte, c’est lui.`, null);
    son('forceField_000', 0.6, 0.6);
    setTimeout(() => !r.mort && UI.chat(r.nom, hasard(['?? un envahisseur', 'sérieux pas maintenant', 'viens alors', 'oh non'])), 6000);
  }
}
function majRival(e, d, dt) {
  const def = e.armeDef, type = e.equip.arme.type, melee = type === 'epee';
  if (joueur.mort) return;
  if (d < 22) UI.boss({ nom: `${e.nom} · ⚔ ${e.ip}`, pv: e.pv, pvMax: e.pvMax }); else UI.boss(null);
  e.chatT -= dt; if (e.chatT <= 0 && d < 20) { e.chatT = rnd(16, 28); UI.chat(e.nom, hasard(RIVAL_COMBAT)); }
  if (e.potionT > 0) { e.potionT -= dt; e.pv = Math.min(e.pvMax, e.pv + e.pvMax * 0.4 * dt); if (Math.random() < 0.4) emettre(V(e.pos.x, 0.5, e.pos.z), { n: 1, c1: '#ff8a9a', c2: '#ff2a4a', dir: V(0, 1, 0), vit: 2, rayon: 0.6, vie: 0.6, taille: 0.3 }); }
  if (e.pv < e.pvMax * 0.35 && e.potions > 0 && e.potionT <= 0) { e.potions--; e.potionT = 1; son('metalLatch', 0.4, 1.4); UI.nombre(V(e.pos.x, 2.6, e.pos.z), 'Potion', 'soin'); }
  if (e.dashT > 0) { e.dashT -= dt; deplacer(e, e.dashV.x * dt, e.dashV.z * dt, 0.5); return; }
  if (e.attaqueT > 0) { e.attaqueT -= dt; faceJoueur(e, dt, 8); return; }
  e.esquiveT -= dt; e.specT -= dt;
  if (e.specT <= 0 && d < 14) { capaciteRival(e, type); e.specT = rnd(4.5, 7.5); return; }
  const portee = melee ? def.portee + e.rayon : 9.5;
  if (d > portee) { avancerVers(e, joueur.pos, dt, e.st.vitesse * 0.92); e.jouer(def.run); return; }
  // un tireur garde ses distances
  if (!melee && d < 4.5 && e.esquiveT <= 0) {
    const arr = V(e.pos.x - joueur.pos.x, 0, e.pos.z - joueur.pos.z).normalize();
    e.dashT = 0.35; e.dashV = arr.multiplyScalar(18); e.esquiveT = rnd(4, 6);
    e.jouer('Dodge_Backward', { boucle: false, forcer: true, vitesse: 1.5, fin: () => e.jouer(def.idle) });
    emettre(V(e.pos.x, 0.3, e.pos.z), { n: 12, c1: '#d0f0ff', c2: '#6aa0c0', vit: 3, vie: 0.4, taille: 0.35 });
    return;
  }
  faceJoueur(e, dt, 12);
  if (!melee) {
    const perp = V(joueur.pos.z - e.pos.z, 0, -(joueur.pos.x - e.pos.x)).normalize().multiplyScalar(e.strafe * 2.2 * dt);
    if (!deplacer(e, perp.x, perp.z, 0.5)) e.strafe *= -1;
    if (Math.random() < dt * 0.3) e.strafe *= -1;
  }
  if (e.atkT > 0) { e.jouer(def.idle); return; }
  e.atkT = 1 / e.st.vitesseAtk; e.attaqueT = 0.3;
  const anim = def.attaques[Math.floor(Math.random() * def.attaques.length)];
  e.jouer(anim, { boucle: false, forcer: true, vitesse: 1.25, fin: () => e.jouer(def.idle) });
  const coul = TIERS[e.equip.arme.tier].color;
  if (melee) programmer(0.3, () => { if (e.mort || e.stunT > 0) return; arcTaille(e.pos, e.angle - Math.PI / 2, 2.9, coul, Math.PI * 0.7, 0.22); if (dist2D(e.pos, joueur.pos) < portee + 1) { blesserJoueur(e.dmg, e); son('knifeSlice', 0.4); } });
  else programmer(0.22, () => { if (!e.mort && e.stunT <= 0) tirEnnemi(e, type === 'baton' ? 'feu' : 'carreau', e.dmg); });
}
function capaciteRival(e, type) {
  const def = e.armeDef; const pj = joueur.pos.clone();
  const base = Math.atan2(pj.x - e.pos.x, pj.z - e.pos.z);
  e.angle = base; e.root.rotation.y = base;
  if (e.pv < e.pvMax * 0.5 && !e.bouclierFait) { // Rempart
    e.bouclierFait = true; e.attaqueT = 0.4; e.potions += 0; onde(e.pos, '#8fd3ff', 3, 0.5); son('forceField_000', 0.5, 1.4);
    e.reduction = Math.min(0.85, e.reduction + 0.45); setTimeout(() => { e.reduction = e.st.reduction; }, 4000);
    UI.nombre(V(e.pos.x, 2.6, e.pos.z), 'Rempart', 'info'); return;
  }
  if (type === 'epee') {
    if (Math.random() < 0.5) { // charge héroïque
      e.attaqueT = 1.1; const dir = V(Math.sin(base), 0, Math.cos(base)); const dist = Math.min(9, dist2D(e.pos, pj) - 1);
      telegraphe(e.pos, Math.max(2, dist), 0.55, '#ff3a2a', () => {
        if (e.mort) return; e.jouer('Dodge_Forward', { boucle: false, forcer: true, vitesse: 1.6 });
        e.dashT = 0.25; e.dashV = dir.clone().multiplyScalar(Math.max(2, dist) / 0.25);
        programmer(0.27, () => { if (e.mort) return; e.jouer('2H_Melee_Attack_Chop', { boucle: false, forcer: true, vitesse: 1.6, fin: () => e.jouer(def.idle) }); onde(e.pos, '#ffd36b', 4, 0.45); G.shake = 0.5; if (dist2D(e.pos, joueur.pos) < 3.4) { blesserJoueur(e.dmg * 2.2, e); joueur.verrouT = Math.max(joueur.verrouT, 0.8); UI.nombre(V(joueur.pos.x, 2.6, joueur.pos.z), 'Étourdi', 'info'); } });
      }, { ligne: true, largeur: 2.4, angle: base + Math.PI });
    } else { // fente
      e.attaqueT = 1.0;
      telegraphe(e.pos, 4.8, 0.65, '#ff3a2a', () => {
        if (e.mort) return; e.jouer('2H_Melee_Attack_Slice', { boucle: false, forcer: true, vitesse: 1.5, fin: () => e.jouer(def.idle) });
        arcTaille(e.pos, e.angle - Math.PI / 2, 4.6, '#ff3a2a', Math.PI * 0.8, 0.3);
        const v = V(joueur.pos.x - e.pos.x, 0, joueur.pos.z - e.pos.z); const dd = v.length(); v.normalize();
        if (dd < 4.8 && v.dot(V(Math.sin(base), 0, Math.cos(base))) > Math.cos(0.7)) blesserJoueur(e.dmg * 2.3, e);
      }, { cone: 1.4, angle: base - Math.PI / 2 });
    }
  } else if (type === 'arbalete') {
    if (Math.random() < 0.5) { // carreau perforant
      e.attaqueT = 0.9;
      telegraphe(e.pos, 16, 0.6, '#ff3a2a', () => { if (e.mort) return; e.jouer('2H_Ranged_Shoot', { boucle: false, forcer: true, fin: () => e.jouer(def.idle) }); tirEnnemi(e, 'carreau', e.dmg * 2.4, V(Math.sin(base), 0, Math.cos(base)), 34); }, { ligne: true, largeur: 1.4, angle: base + Math.PI });
    } else { // pluie
      e.attaqueT = 0.6; e.jouer('2H_Ranged_Shoot', { boucle: false, forcer: true, fin: () => e.jouer(def.idle) });
      for (let w = 0; w < 3; w++) telegraphe(pj, 4.2, 0.9 + w * 0.45, '#ff3a2a', () => { emettre(V(pj.x, 0.3, pj.z), { n: 20, c1: '#bfffd8', c2: '#3a9a6a', rayon: 3.8, vit: 2, vie: 0.4, taille: 0.3, hemi: true }); son('impactGeneric_light_000', 0.3, 1.3); if (dist2D(joueur.pos, pj) < 4.2) { blesserJoueur(e.dmg * 1.1, e); joueur.slowT = 2; } });
    }
  } else {
    if (Math.random() < 0.7) { // colonne de flammes
      e.attaqueT = 0.7; e.jouer('Spellcast_Raise', { boucle: false, forcer: true, fin: () => e.jouer(def.idle) });
      telegraphe(pj, 3.5, 0.9, '#ff3a2a', () => { emettre(V(pj.x, 0.3, pj.z), { n: 60, c1: '#ffe08a', c2: '#ff2a00', dir: V(0, 1, 0), vit: 14, disp: 2.5, rayon: 1.8, vie: 0.8, taille: 0.7, frein: 2 }); son('explosionCrunch_000', 0.5, 0.8); G.shake = 0.4; if (dist2D(joueur.pos, pj) < 3.5) blesserJoueur(e.dmg * 2.8, e); });
    } else { // météore
      e.attaqueT = 1.3; e.jouer('Spellcast_Long', { boucle: false, forcer: true, fin: () => e.jouer(def.idle) });
      telegraphe(pj, 6, 1.6, '#ff3a2a', () => { G.shake = 1; onde(pj, '#ffd27a', 9, 0.7); emettre(V(pj.x, 0.5, pj.z), { n: 140, c1: '#fff0b0', c2: '#ff2a00', vit: 14, vie: 1.0, taille: 0.9, grav: 4, hemi: true }); son('lowFrequency_explosion_000', 0.8); if (dist2D(joueur.pos, pj) < 6) blesserJoueur(e.dmg * 4.2, e); });
    }
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
  UI.journal(invasion && invasion.mode === 'menee' ? 'Invasion réussie' : 'Invasion repoussée', `Fouille la dépouille de ${e.nom} : choisis ce que tu gardes.`, null);
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

// accès de débogage (console)
window.__jeu = { API, entrerDonjon, get invasion() { return invasion; }, set invasion(v) { invasion = v; }, lancerSort, ouvrirCoffre, get joueur() { return joueur; }, get ennemis() { return ennemis; }, get coffres() { return coffres; }, get J() { return J; }, get monde() { return monde; } };
