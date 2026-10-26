// ===== Brèche Écarlate — boucle de jeu =====
import { THREE, G, initRendu, majCamera, rendre, majTorches, chargerAssets, chargerSons, son, ambiance, Acteur, cloner,
  emettre, majParticules, majVfx, ajouterVfx, onde, lueurSol, arcTaille, faisceau, telegraphe, meshCarreau, meshBoule, DIR_HAUT, DIR_DROITE, projeter, texRond, texRunes, redimensionner, appliquerNiveau, majQualiteAuto, musique, musiqueActive, musiquePause } from './engine.js';
import { construireHub, construireDonjon, construireArene, construireIle, nbEmplacements, majFeux, noeudReel, creerAssetsProc, construireSylve } from './world.js';
import { UI, iconeObjet, bustePersonnage, TEINTES_OMBRE } from './ui.js';
import { initGestes } from './gestes.js';
import { TIERS, ARMES, ARMURES, SORTS, MODES, COFFRES, BOSS, MOBS, BOTS, CHAT, tf, MAITRISES, NIVEAU_REQUIS, ILE_TYPES, ILE_TAILLES, ILE_NIVEAUX, BATIMENTS, GARDES_ILE, CHAMPION_ILE, HEURE_ASSAUT, RESSOURCES, CHANCE_OMBRE, CODES_BETA, CHANCE_ORAGE, MOBS_SYLVE, BOSS_SYLVE, TRAITS, RANGS, PTS_RANG, GAIN_RANG, PERTE_RANG, BOSS_ERRANT, PARCHEMINS, COULEURS_PARCH, DUREE_PARCH, BOUTIQUE_PARCH_GRATUITE } from './data.js';
import { creerParchemin, creerArme, creerArmure, creerPotion, statsHeros, nomObjet, valeurObjet, prixVente, lootCoffre, lootMonstre, tirerCouleurCoffre, ETAT, coutEnchant, ENCH_MAX, creerButin, xpPour, peutPorter, niveauRequis, niveauDe, sortsArme, prixTrophees, bonusMaitrise, niveauHeros } from './items.js';

const $ = (s) => document.querySelector(s);
const rnd = (a, b) => a + Math.random() * (b - a);
const ri = (a, b) => a + Math.floor(Math.random() * (b - a + 1));
const V = (x = 0, y = 0, z = 0) => new THREE.Vector3(x, y, z);
const dist2D = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);

// ---------------- Sauvegarde ----------------
let J = null;
const CLE = 'breche-ecarlate-v1';
// sauvegarde groupée : au plus une écriture toutes les 1,5 s (l’écriture disque fait des micro-freezes sur Android)
let sauverT = null, efface = false;
function sauverMaintenant() { if (efface) return; if (sauverT) { clearTimeout(sauverT); sauverT = null; } try { localStorage.setItem(CLE, JSON.stringify(J)); } catch (e) {} }
function sauver() { if (!sauverT) sauverT = setTimeout(sauverMaintenant, 1500); }
addEventListener('pagehide', sauverMaintenant); document.addEventListener('visibilitychange', () => { try { if (G.audio) document.hidden ? G.audio.suspend() : G.audio.resume(); } catch (e) {} musiquePause(document.hidden); }); document.addEventListener('visibilitychange', () => { if (document.hidden) sauverMaintenant(); });
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

// ---------------- Passerelle TestBot (bot testeur) ----------------
// Si l'appli TestBot est installée, Android expose window.TestBotPont : 10 fois par seconde on lui envoie
// ce que le joueur voit, en pixels d'écran (perso, monstres, coffres, zones rouges, sorts, joystick,
// chemin calculé par le jeu) + les erreurs JS. Sans TestBot : rien ne se passe, aucun coût.
let pontT = 0;
const pontErreurs = [];
window.addEventListener('error', (e) => { if (pontErreurs.length < 20) pontErreurs.push(`${e.message} (${String(e.filename || '').split('/').pop()}:${e.lineno})`); });
window.addEventListener('unhandledrejection', (e) => { if (pontErreurs.length < 20) pontErreurs.push('Promesse rejetée : ' + ((e.reason && e.reason.message) || e.reason)); });
function pontEcran(x, y, z) {
  const p = projeter(V(x, y, z)), k = window.devicePixelRatio || 1;
  return { x: Math.round(p.x * k), y: Math.round(p.y * k), v: p.visible ? 1 : 0 };
}
function pontRect(el) {
  if (!el || el.hidden) return null;
  const cs = getComputedStyle(el); if (cs.display === 'none' || cs.visibility === 'hidden') return null;
  const r = el.getBoundingClientRect(); if (r.width < 2 || r.height < 2) return null;
  const k = window.devicePixelRatio || 1;
  return { x: Math.round((r.left + r.width / 2) * k), y: Math.round((r.top + r.height / 2) * k), w: Math.round(r.width * k), h: Math.round(r.height * k) };
}
function majPont(dt) {
  const pont = window.TestBotPont; if (!pont) return;
  pontT -= dt; if (pontT > 0) return; pontT = 0.1;
  try {
    const k = window.devicePixelRatio || 1;
    const e = { v: 1, jeu: 'Brèche Écarlate', ecran: { w: Math.round(innerWidth * k), h: Math.round(innerHeight * k) }, enJeu: !!(enJeu && joueur && !transition), mode: modeActuel ? modeActuel.id : 'place' };
    if (pontErreurs.length) e.erreurs = pontErreurs.splice(0);
    if (e.enJeu) {
      const pj = pontEcran(joueur.pos.x, 1, joueur.pos.z);
      e.joueur = { x: pj.x, y: pj.y, wx: +joueur.pos.x.toFixed(2), wz: +joueur.pos.z.toFixed(2), pv: Math.round(joueur.pv), pvMax: Math.round(joueur.st.pvMax), mort: joueur.mort ? 1 : 0 };
      const ens = [];
      for (const m of vivants()) { const p = pontEcran(m.pos.x, 1, m.pos.z); ens.push({ x: p.x, y: p.y, v: p.v, d: +dist2D(m.pos, joueur.pos).toFixed(1), pv: Math.round(m.pv), pvMax: Math.round(m.pvMax || m.pv || 1), boss: m.boss ? 1 : 0 }); }
      ens.sort((a, b) => a.d - b.d); e.ennemis = ens.slice(0, 25);
      e.coffres = coffres.filter(c => !c.ouvert).map(c => { const p = pontEcran(c.pos.x, 0.5, c.pos.z); return { x: p.x, y: p.y, v: p.v, d: +dist2D(c.pos, joueur.pos).toFixed(1) }; }).sort((a, b) => a.d - b.d).slice(0, 15);
      e.dangers = [];
      for (const z of dangers) {
        if (z.camp === 'allie' || z.camp === 'joueur') continue;
        const c = pontEcran(z.p.x, 0, z.p.z), b = pontEcran(z.p.x + z.r, 0, z.p.z);
        e.dangers.push({ x: c.x, y: c.y, r: Math.round(Math.hypot(b.x - c.x, b.y - c.y)), wr: +z.r.toFixed(1), d: +dist2D(z.p, joueur.pos).toFixed(1), t: +z.t.toFixed(2) });
      }
      // Où aller : le jeu calcule lui-même le chemin dans le donjon (il contourne les murs)
      let cible = null, quoi = null, bd = Infinity;
      for (const m of vivants()) { const d = dist2D(m.pos, joueur.pos); if (d < bd) { bd = d; cible = m.pos; quoi = 'ennemi'; } }
      if (!cible) for (const c of coffres) if (!c.ouvert) { const d = dist2D(c.pos, joueur.pos); if (d < bd) { bd = d; cible = c.pos; quoi = 'coffre'; } }
      if (!cible && sortie) { cible = sortie.pos; bd = dist2D(sortie.pos, joueur.pos); quoi = 'sortie'; }
      if (cible) {
        let pt = cible;
        if (monde && monde.grille && bd > 4) { const ch = cheminGrille(joueur.pos, cible); if (ch && ch.length) pt = ch[Math.min(1, ch.length - 1)]; }
        const p = pontEcran(pt.x, 1, pt.z);
        e.nav = { x: p.x, y: p.y, quoi, d: +bd.toFixed(1) };
      }
      e.sorts = [];
      for (const kk of ['ATK', 'Q', 'W', 'E', 'R', 'D', 'F', 'POT']) {
        const b = document.getElementById('s-' + kk), r = pontRect(b);
        if (!r || b.classList.contains('off')) continue;
        const cd = (joueur.cds && joueur.cds[kk]) || 0, s = joueur.sorts && joueur.sorts[kk];
        const pret = cd <= 0 && !b.classList.contains('manque') && (kk !== 'POT' || joueur.potions > 0) && (!s || joueur.energie >= (s.energie || 0));
        e.sorts.push({ k: kk, x: r.x, y: r.y, pret: pret ? 1 : 0 });
      }
      const zj = pontRect($('#zoneJoy')), jy = $('#joy');
      if (zj) e.joy = { x: Math.round(zj.x - zj.w * 0.1), y: Math.round(zj.y + zj.h * 0.2), r: Math.round((jy && jy.offsetWidth ? jy.offsetWidth * 0.42 : 50) * k) };
      const act = pontRect($('#action'));
      if (act) e.action = { x: act.x, y: act.y, texte: ($('#action').textContent || '').trim().slice(0, 40) };
    }
    pont.envoyer(JSON.stringify(e));
  } catch (err) { /* la passerelle ne doit jamais gêner le jeu */ }
}

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
const ASSETS_SYLVE = ['n_statue_ring', 'n_statue_head', 'n_statue_obelisk', 'n_statue_column', 'n_statue_columnDamaged', 'n_mushroom_red', 'n_mushroom_redGroup', 'n_mushroom_redTall', 'n_mushroom_tan', 'n_mushroom_tanGroup', 'n_mushroom_tanTall', 'n_lily_large', 'n_lily_small', 'n_log_large', 'n_stump_old', 'n_plant_bushLarge', 'n_plant_bushDetailed', 'n_plant_flatTall', 'n_flower_purpleB', 'n_flower_purpleC', 'n_flower_redC', 'n_flower_yellowC', 'n_tree_oak', 'n_tree_detailed', 'n_tree_default', 'n_tree_fat_darkh', 'n_rock_largeB', 'Bush_4_A', 'Bush_3_B', 'Tree_2_C', 'Tree_3_B', 'Rock_2_C'];
const SONS = ['knifeSlice', 'knifeSlice2', 'drawKnife2', 'handleCoins', 'creak1', 'doorOpen_1', 'metalLatch', 'cloth1', 'bookOpen', 'impactPlate_heavy_000', 'impactMetal_medium_001', 'impactGeneric_light_000',
  'footstep_concrete_000', 'footstep_concrete_001', 'click_001', 'open_001', 'close_001', 'confirmation_001', 'error_001', 'select_001', 'maximize_001', 'thrusterFire_000', 'explosionCrunch_000', 'lowFrequency_explosion_000', 'forceField_000',
  'jingle_win', 'jingle_loot', 'jingle_legend', 'chop', 'impactMining_000', 'impactMining_001', 'impactPlank_medium_000', 'handleSmallLeather'].map(k => [k, `assets/audio/${k}.ogg`]);

async function demarrer() {
  initRendu($('#scene'));
  try { const dc = localStorage.getItem('breche-decal'); if (dc !== null) document.documentElement.style.setProperty('--decalSorts', dc + 'vw'); } catch (e) {}
  try { const q = localStorage.getItem('breche-qualite'); if (q) G.qualite = q; G.perfOn = !!localStorage.getItem('breche-perf'); } catch (e) {}
  if (G.perfOn) UI.perf(true);
  try { G.musiqueOn = localStorage.getItem('breche-musique') !== '0'; } catch (e) {}
  // le thème démarre pendant le chargement (dans l'appli) ; sur navigateur, au premier toucher
  musique('theme');
  const relance = () => { musique(pisteMusique || 'theme'); removeEventListener('pointerdown', relance); };
  addEventListener('pointerdown', relance);
  appliquerNiveau({ haute: 2, moyenne: 1, basse: 0, auto: 2 }[G.qualite] ?? 2);
  try {
    await chargerAssets(ASSETS, (k, nom) => { $('#charge i').style.width = (k * 100) + '%'; $('#chargeTxt').textContent = 'Chargement… ' + Math.round(k * 100) + ' %'; });
    creerAssetsProc();
  } catch (e) { $('#chargeTxt').textContent = 'Un fichier du jeu n’a pas pu se charger (' + (e && e.message ? e.message : e) + '). Recharge la page.'; console.error(e); return; }
  monde = construireHub();
  G.scene.add(G.points);
  creerMarchand(); creerPasseur(); creerGraveuse(); creerBots();
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
    pisteMusique = 'fond'; musique('fond');
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
  if (joueur) { G.scene.remove(joueur.root); UI.retirerPlaque(joueur); try { libererGPU([joueur.root]); } catch (e) {} }
  const arme = J.equip.arme || creerArme('epee', 1);
  const def = ARMES[arme.type];
  const a = new Acteur(def.model, { hauteur: 2.0 });
  // ne montrer que l'arme portée
  const tous = Object.keys(a.nodes).filter(n => /Sword|Axe|Shield|Crossbow|Staff|Wand|Knife|Throwable|Mug|Spellbook/.test(n));
  a.montrerSeul([def.node, def.node2].filter(Boolean), tous);
  a.teinter(def.node, TIERS[arme.tier].color, 0.62, TIERS[arme.tier].glow);
  if (def.node2) a.teinter(def.node2, TIERS[arme.tier].color, 0.62, TIERS[arme.tier].glow);
  // tenue : on garde les matières d'origine du modèle (plus de « plastique » coloré) ; seul le tissu de la cape porte la couleur du tier
  if (def.helmet && a.nodes[def.helmet]) a.nodes[def.helmet].visible = false;
  if (J.equip.plastron && def.cape) a.teinter(def.cape, TIERS[J.equip.plastron.tier].color, 0.42, 0);
  if (def.ombre) habitOmbre(a, def);
  if (def.assassin) habitAssassin(a, def);
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
  $('#ipHud').textContent = `Niv. ${niveauHeros(J.equip)} · ⚔ ${st.ip}`;
  UI.construireSorts(joueur); UI.boutonAuto(API);
  if (modeActuel && G.gestes !== false && !G.aideSignesVue) { G.aideSignesVue = true; setTimeout(() => joueur && UI.aideSignes(joueur.sorts), 1500); }
  $('#nomHud').textContent = J.nom;
  bustePersonnage(def.model, $('#avatarCv'), def.ombre ? '#3a1a5a' : '#5a3a5a', def.ombre ? TEINTES_OMBRE : null);
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
    UI.plaque(a, { nom, guilde: a.data.guilde, classe: 'allie', vie: false, ip: a.data.ip, niv: a.data.niv });
    bots.push(a);
  }
}
function majBots(dt) {
  emoteHubT -= dt;
  if (emoteHubT <= 0) {
    emoteHubT = rnd(7, 16);
    const proches = bots.filter(b => !(b.absentT > 0) && !b.mort && b.root.visible !== false && (!joueur || dist2D(b.pos, joueur.pos) < 22));
    if (proches.length) emoteBot(hasard(proches), ['salut', 'mdr', 'feu', 'bof', 'malin', 'diable', 'clown', 'gg', 'toi'], 1);
  }
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
  viderEscouade();
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
  G.scene.background.set('#120b1b'); G.scene.fog.color.set('#150d20'); G.sun.color.set('#c9b8ff'); G.hemi.color.set('#8f7cc8'); G.hemi.groundColor.set('#2a1830');
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
  if (!premier) { viderMonde(); monde = construireHub(); creerMarchand(); creerPasseur(); creerGraveuse(); creerBots(); }
  const revientDeMode = !!modeActuel;
  modeActuel = null; enJeu = true;
  construireJoueur(monde.spawn.clone());
  if (revientDeMode && !premier) setTimeout(() => proposerRefaire(60), 900); else UI.boutonRefaire(null);
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
// ---------------- Escouade d'ombres (code THOMAS83, outil de test de l'économie) ----------------
// 6 ombres qui se déploient : chacune se téléporte sur une cible DIFFÉRENTE (boss d'abord), la détruit d'un coup,
// puis elles ouvrent les coffres et ramassent tout le butin. Un compteur mesure l'argent et l'XP gagnés par heure.
let escouade = [];
const ESC = { kills: 0, coffres: 0, xp: 0 };
function statsEscouade() {
  if (!J.escStats) J.escStats = { debut: Date.now(), argent0: J.argent, xp: 0, kills: 0, coffres: 0 };
  return J.escStats;
}
function viderEscouade() { for (const o of escouade) { G.scene.remove(o.root); UI.retirerPlaque(o); } escouade = []; }
function creerOmbreEscouade(i) {
  const ang = i / 6 * Math.PI * 2;
  const pos = pointLibrePres(V(joueur.pos.x + Math.sin(ang) * 2.6, 0, joueur.pos.z + Math.cos(ang) * 2.6), 0, 1.2);
  const a = creerCombattant(pos, { nom: 'Ombre', guilde: J.nom.toUpperCase(), equip: J.equip, modele: 'Rogue_Hooded' }, 'allie');
  allies.splice(allies.indexOf(a), 1); // hors des alliés : personne ne la cible, elle ne compte pas dans le groupe
  UI.retirerPlaque(a);
  a.root.scale.setScalar(0.95); teinteSpectrale(a, '#140c20', 0.8);
  UI.plaque(a, { nom: 'Ombre ' + 'ⅠⅡⅢⅣⅤⅥ'[i], guilde: 'ESCOUADE', classe: 'allie', vie: false, lettre: false });
  Object.assign(a, { escIdx: i, escCible: null, escT: 0.3 + i * 0.08, escPhase: 0 });
  fumeeOmbre(pos); a.jouer('Spellcast_Raise', { boucle: false, fin: () => a.jouer(a.armeDef.idle) });
  return a;
}
function cibleLibre(o, prises) {
  let vivantsE = ennemis.filter(e => !e.mort && !e.descendre && !prises.has(e));
  if (modeActuel && modeActuel.sylve) { // au Sanctuaire, les gardiens tombent dans l'ordre (le chemin s'ouvre de salle en salle)
    const k = Math.min(...ennemis.filter(e => e.boss && !e.mort && e.idxSylve !== undefined).map(e => e.idxSylve));
    vivantsE = vivantsE.filter(e => !e.boss || e.idxSylve === k);
  }
  if (!vivantsE.length) return null;
  const boss = vivantsE.filter(e => e.boss);
  const l = boss.length ? boss : vivantsE;
  let best = null, bd = 1e9;
  for (const e of l) { const d = dist2D(e.pos, o.pos) + (e.rival ? -50 : 0); if (d < bd) { bd = d; best = e; } }
  return best;
}
function teleporterOmbre(o, p) {
  fumeeOmbre(o.pos);
  const q = pointLibrePres(p, 0.8, 1.8); o.pos.copy(q); o.chemin = null;
  fumeeOmbre(q); son('cloth1', 0.25, 1.6);
}
function majEscouade(dt) {
  if (!J.escouade || !joueur || joueur.mort && !arene) { if (escouade.length && !J.escouade) viderEscouade(); return; }
  if (transition) return;
  const enAttente = arene && arene.t > 0;
  while (escouade.length < 6) escouade.push(creerOmbreEscouade(escouade.length));
  const prises = new Set(escouade.map(o => o.escCible).filter(c => c && !c.mort));
  const coffresPris = new Set(escouade.map(o => o.escCoffre).filter(Boolean));
  for (const o of escouade) {
    o.maj(dt);
    o.escT -= dt;
    if (o.escCible && o.escCible.mort) o.escCible = null;
    if (o.escT > 0) continue;
    if (enAttente) { o.escT = 0.2; continue; }
    // 1) une cible différente pour chaque ombre
    if (!o.escCible && !o.escCoffre) {
      // les coffres dont le gardien est tombé passent avant les petits monstres
      const pret = coffres.find(x => !x.ouvert && !x.final && !coffresPris.has(x) && (!x.boss || x.boss.mort || !x.boss.pv));
      const resteBoss = ennemis.some(e => e.boss && !e.mort && !prises.has(e));
      if (pret && !resteBoss) { o.escCoffre = pret; coffresPris.add(pret); teleporterOmbre(o, pret.pos); o.escT = 0.2; continue; }
      const c = cibleLibre(o, prises);
      if (c) { o.escCible = c; prises.add(c); teleporterOmbre(o, c.pos); o.angle = Math.atan2(c.pos.x - o.pos.x, c.pos.z - o.pos.z); o.root.rotation.y = o.angle;
        o.jouer('1H_Melee_Attack_Chop', { boucle: false, forcer: true, vitesse: 2.2, fin: () => o.jouer(o.armeDef.idle) }); o.escT = 0.14; continue; }
      // 2) plus d'ennemis : les coffres
      const cf = coffres.find(x => !x.ouvert && !x.final && !coffresPris.has(x));
      if (cf) { o.escCoffre = cf; coffresPris.add(cf); teleporterOmbre(o, cf.pos); o.escT = 0.35; continue; }
    }
    if (o.escCible) { // coup fatal
      const c = o.escCible; o.escCible = null;
      if (!c.mort) {
        arcTaille(c.pos, o.angle - Math.PI / 2, 2.6, '#b07aff', Math.PI * 0.8, 0.25); emettre(V(c.pos.x, 1.2, c.pos.z), { n: 30, c1: '#e0c8ff', c2: '#3a0a6a', vit: 6, vie: 0.6, taille: 0.45 });
        UI.nombre(V(c.pos.x, 2.6, c.pos.z), 'EXÉCUTÉ', 'crit'); son('knifeSlice2', 0.4, 0.8 + Math.random() * 0.4);
        c.pv = 0; tuer(c); const s = statsEscouade(); s.kills++;
      }
      o.escT = 0.1 + Math.random() * 0.12; continue;
    }
    if (o.escCoffre) { // ouvre le coffre et ramasse tout pour le joueur
      const cf = o.escCoffre; o.escCoffre = null;
      if (!cf.ouvert) { o.jouer('Interact', { boucle: false, forcer: true, fin: () => o.jouer(o.armeDef.idle) }); if (cf.depouille) ouvrirDepouille(cf, true); else ouvrirCoffre(cf, true); statsEscouade().coffres++; }
      o.escT = 0.25; continue;
    }
    // 3) rien à faire : elles reviennent se déployer autour du joueur
    const ang = o.escIdx / 6 * Math.PI * 2 + G.t * 0.3, cible = V(joueur.pos.x + Math.sin(ang) * 3, 0, joueur.pos.z + Math.cos(ang) * 3);
    const d = dist2D(o.pos, cible);
    if (d > 16) teleporterOmbre(o, cible);
    else if (d > 1) { avancerVers(o, cible, dt, joueur.st.vitesse * 1.3); o.jouer(o.armeDef.run); }
    else o.jouer(o.armeDef.idle);
    o.escT = 0;
  }
  // compteur à l'écran
  escHudT = (escHudT || 0) - dt;
  if (escHudT <= 0) { escHudT = 0.5; const s = statsEscouade(); const h = Math.max(1 / 60, (Date.now() - s.debut) / 3.6e6);
    UI.escouadeHud({ duree: Date.now() - s.debut, argent: J.argent - s.argent0, parHeure: Math.round((J.argent - s.argent0) / h), xp: s.xp, xpH: Math.round(s.xp / h), kills: s.kills, coffres: s.coffres }); }
}
let escHudT = 0;
// ---------------- Refaire ----------------
function memoriserMode(nom, fn) { G.dernier = { nom, fn }; UI.boutonRefaire(null); }
function proposerRefaire(duree = 0) {
  if (!G.dernier) return;
  const d = G.dernier;
  UI.boutonRefaire(d.nom, () => {
    if (transition) return;
    UI.boutonRefaire(null);
    if (modeActuel) bilanGroupe();
    d.fn();
  }, duree);
}
function bilanGroupe() {
  if (groupe && modeActuel && (modeActuel.mode !== undefined || MODES.includes(modeActuel))) {
    if (groupe.fort) { J.rushs = (J.rushs || 0) + 1; sauver(); }
    groupe.donjonsRestants = (groupe.donjonsRestants ?? 2) - 1;
    if (groupe.donjonsRestants <= 0) { const n = groupe.nom; groupe = null; setTimeout(() => UI.chat(n, hasard(['gg, je dois y aller', 'bon je déco, gg', 'merci pour les runs', 'bye'])), 1500); }
  }
}
// ---------------- Donjon ----------------
function entrerDonjon(id, opts = {}) {
  if (!opts.errant) memoriserMode(MODES[id].lieu + ' · ' + MODES[id].nom + (opts.envahir ? ' · invasion' : ''), () => entrerDonjon(id, { envahir: opts.envahir }));
  fondu(() => {
    viderMonde();
    modeActuel = MODES[id]; bossVaincus = 0;
    invasion = opts.envahir ? { mode: 'menee', t: 4, rival: null } : (J.accepteInvasion && Math.random() < 0.8 ? { mode: 'subie', t: rnd(40, 100), rival: null } : null);
    monde = construireDonjon(modeActuel);
    construireJoueur(monde.spawn.clone());
    joueur.pv = joueur.st.pvMax; joueur.energie = joueur.st.energieMax;
    G.camTarget.copy(joueur.pos); G.scene.fog.density = 0.028; G.hemi.intensity = 0.75; G.sun.intensity = 0.8;
    if (groupe) { const a = creerCombattant(pointLibrePres(monde.spawn, 1.5, 3), groupe, 'allie'); const p = Math.random(); Object.assign(a, { autonome: true, perso: p < 0.6 ? 'loyal' : p < 0.85 ? 'solo' : 'traitre', modeA: 'explorer', modeT: rnd(14, 24) }); groupe.trait = groupe.trait || hasard(Object.keys(TRAITS)); appliquerTrait(a, groupe.trait); if (a.trait === 'protecteur') a.modeA = 'suivre'; }
    // monstres
    const types = id === 0 ? ['minion', 'minion', 'minion', 'guerrier', 'archer'] : id === 1 ? ['minion', 'guerrier', 'guerrier', 'archer', 'mage'] : ['guerrier', 'guerrier', 'archer', 'mage', 'mage', 'minion'];
    monde.packs.forEach((pk, i) => pk.pts.forEach(p => creerEnnemi(MOBS[types[Math.floor(Math.random() * types.length)]], libre(p.x, p.z, 0.7) ? p : pointLibrePres(p, 0.5, 3), modeActuel.mobTier, i)));
    // boss et coffres
    if (!opts.envahir) monde.bossSalles.forEach((s, k) => {
      const b = creerBoss(BOSS[k], s.centre.clone().add(V(2, 0, 2)), modeActuel.bossTier[k], s);
      creerCoffre(monde.coffresPos[k], couleurSelonRang(tirerCouleurCoffre()), b);
    });
    creerSortie(monde.sortie);
    if (!opts.envahir && !G.sansErrant && (Math.random() < 0.1 || opts.errant)) apparitionErrant();
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
  const a = new Acteur(def.model, { hauteur: boss ? (boss.hauteur || (boss.model === 'Dragon_Evolved' ? 4.6 : 2.0)) : 2.0, echelle: boss ? (boss.model === 'Dragon_Evolved' ? 1 : boss.scale) : 1 });
  const teinte = (boss && boss.teinte) || def.teinte;
  if (teinte) { const c = new THREE.Color(teinte); for (const mt of a.mats) { mt.color.lerp(c, boss && boss.model === 'Dragon_Evolved' ? 0.55 : 0.4); if (mt.emissive && boss) { mt.emissive.copy(c).multiplyScalar(0.12); mt.userData.baseEmissive = mt.emissive.clone(); } } }
  if (def.arme) a.attacher(def.arme, 'handslot.r');
  if (def.model === 'Skeleton_Warrior' && !boss) a.attacher('Skeleton_Shield_Large_A', 'handslot.l');
  a.root.position.copy(pos); a.root.rotation.y = rnd(0, 6.28);
  G.scene.add(a.root);
  const f = tf(tierMob);
  const kr = (1 + 0.15 * rangK()) * (1 + bonusMaitrise(NIVEAU_REQUIS[Math.max(1, Math.min(8, Math.round(tierMob)))]) * 0.8); // les monstres suivent le niveau attendu de leur zone
  const pvMax = Math.round(160 * f * (def.hp || 1) * (boss ? boss.hpMult : 1) * kr);
  Object.assign(a, {
    def, boss, pos: a.root.position, pv: pvMax, pvMax, dmg: 15 * f * (def.dmg || 1) * (boss ? boss.dmgMult : 1) * kr,
    etat: boss ? 'dormant' : 'idle', atkT: rnd(0.5, 1.5), stunT: 0, slowT: 0, dots: [], pack, angle: a.root.rotation.y, mort: false,
    hauteurPlaque: boss ? (boss.hauteur ? boss.hauteur + 0.8 : boss.model === 'Dragon_Evolved' ? 5.2 : 2.6 * boss.scale) : 2.55, rayon: boss ? (boss.rayon || (boss.model === 'Dragon_Evolved' ? 2.4 : 0.6 * boss.scale)) : 0.55,
    specT: 3, cycle: 0, hover: (boss && boss.hover) || (def.model === 'Dragon_Evolved' ? 0.8 : 0), tierMob,
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
// collisions rangées dans une grille : on ne teste que les obstacles voisins (avant : tous, à chaque pas de chaque personnage)
function grilleCollisions() {
  const cs = monde.collisions;
  if (monde._cg && monde._cgN === cs.length) return monde._cg;
  const g = new Map(); let maxR = 0;
  for (const c of cs) { maxR = Math.max(maxR, c.r); const k = Math.floor(c.x / 4) + ',' + Math.floor(c.z / 4); let l = g.get(k); if (!l) g.set(k, (l = [])); l.push(c); }
  monde._cg = g; monde._cgN = cs.length; monde._cgK = Math.max(1, Math.ceil((maxR + 1) / 4));
  return g;
}
function libre(x, z, r = 0.5) {
  if (!monde.marche(x, z)) return false;
  const g = grilleCollisions(), K = monde._cgK, ix = Math.floor(x / 4), iz = Math.floor(z / 4);
  for (let a = -K; a <= K; a++) for (let b = -K; b <= K; b++) {
    const l = g.get((ix + a) + ',' + (iz + b)); if (!l) continue;
    for (const c of l) { const dx = x - c.x, dz = z - c.z, rr = c.r + r; if (dx * dx + dz * dz < rr * rr) return false; }
  }
  return true;
}
function pointLibreProche(p, r) {
  if (libre(p.x, p.z, r)) return p;
  for (let d = 0.5; d <= 6; d += 0.5) for (let k = 0; k < 16; k++) { const a = k / 16 * 6.283; const x = p.x + Math.cos(a) * d, z = p.z + Math.sin(a) * d; if (libre(x, z, r)) return V(x, 0, z); }
  return null;
}
function deplacer(ent, dx, dz, r = 0.5) {
  const p = ent.pos;
  if (!libre(p.x, p.z, r * 0.6)) { const q = pointLibreProche(p, r); if (q) { p.x = q.x; p.z = q.z; } return true; }
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
  if (viseeForcee) { const v = viseeForcee; return v.cible ? { dir: V(v.cible.pos.x - joueur.pos.x, 0, v.cible.pos.z - joueur.pos.z).normalize(), cible: v.cible, point: v.cible.pos.clone() } : { dir: v.dir.clone(), cible: null, point: joueur.pos.clone().addScaledVector(v.dir, Math.min(portee, v.portee * 0.85)) }; }
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
  if (compteur) noterDegats(auteurCoup || joueur, Math.min(d, d + e.pv));
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
  if (e.boss) { if (e.etat === 'dormant') { e.etat = 'chasse'; son('lowFrequency_explosion_000', 0.6, 0.7); if (modeActuel && modeActuel.sylve) debutBossSylve(e); else UI.toast(e.boss.nom + ' se réveille !'); } return; }
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
  const part = coequipiers().length && !modeActuel.sylve ? 0.5 : 1;
  const loot = lootMonstre(modeActuel);
  const gain = Math.max(1, Math.round(loot.argent * (e.boss ? 25 : 1) * part * (1 + bonusParch('argent')) * (MODES.includes(modeActuel) ? 1 + 0.25 * rangDe('donjon').i : 1)));
  J.argent += gain;
  const xp = Math.round(10 * (modeActuel.xp || 1) * (e.boss ? 18 : 1) * part);
  UI.nombre(V(e.pos.x, 2.2, e.pos.z), `+${gain} ¤`, 'info');
  gagnerXP(xp);
  for (const it of loot.objets) ajouterSac(it, true);
  if (e.boss && e.boss.errant) { mortErrant(e); }
  else if (e.boss && modeActuel.sylve) {
    tirageOmbre(modeActuel.tiers[0], modeActuel.tiers[1], 'boss');
    for (const a of allies) if (!a.mort && !a.invoc && !a.garde) emoteBot(a, ['gg', 'feu', 'merci'], 0.6, 1);
    finBossSylve(e);
  } else if (e.boss) {
    ralenti(0.9, 0.28); // ralenti sur le coup fatal du gardien
    tirageOmbre(modeActuel.tiers[0], modeActuel.tiers[1], 'boss');
    if (modeActuel.id === 2) tirageOrage(Math.random() < 0.5 ? 7 : 8);
    for (const a of allies) if (!a.mort && !a.invoc && !a.garde) emoteBot(a, ['gg', 'feu', 'merci'], 0.6, 1);
    bossVaincus++; UI.boss(null); G.shake = 1;
    if (MODES.includes(modeActuel)) changerRang('donjon', 5, 'Gardien vaincu');
    gagnerXPRelatif(0.02); setTimeout(() => montrerXP(e.boss.nom), 1500);
    { const cf = coffres.find(c => c.boss === e); if (cf) for (const a of allies) if (a.autonome && !a.mort && !a.lootCible && dist2D(a.pos, cf.pos) < 45) a.lootCible = cf; }
    for (const a of allies) if (a.autonome && !a.mort) reactionApresBoss(a);
    onde(e.pos, e.boss.couleur, 10, 1.2);
    emettre(V(e.pos.x, 2, e.pos.z), { n: 120, c1: '#ffd27a', c2: e.boss.couleur, vit: 9, vie: 1.4, taille: 0.5, grav: 3 });
    son('jingle_win', 0.6);
    UI.toast(e.boss.nom + ' est vaincu !', true);
    UI.toast('Son coffre peut maintenant être ouvert.');
    UI.journal(modeActuel.lieu, `Gardiens vaincus : ${bossVaincus} / 4`, bossVaincus / 4);
    if (bossVaincus === 4) setTimeout(() => { proposerRefaire(); UI.toast('Donjon nettoyé !', true); UI.journal(modeActuel.lieu, 'Les 4 gardiens sont tombés. Ouvre les coffres puis rentre par le portail violet.', 1); }, 2800);
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
  if (source) dernierAgresseur = source;
  joueur.pv -= d; joueur.frapper(); joueur.combatT = 4;
  UI.nombre(V(joueur.pos.x, 2.2, joueur.pos.z), Math.round(d), 'joueur');
  G.shake = Math.min(1, G.shake + d / joueur.st.pvMax * 3);
  son('impactMetal_medium_001', 0.35);
  if (joueur.pv <= 0) mourirJoueur();
}
let dernierAgresseur = null;
function mourirJoueur() {
  joueur.pv = 0; joueur.mort = true; joueur.jouer('Death_A', { boucle: false });
  // le « joueur » qui t'a tué te nargue
  const k = dernierAgresseur;
  if (k && k.combattant && !k.mort && k.camp === 'ennemi') { emoteBot(k, ['ez', 'mdr', 'clown', 'rip', 'toi', 'bof'], 1, 0.7); emoteBot(k, ['mdr', 'clown', 'diable'], 0.4, 3.2); }
  for (const a of allies.filter(x => x.invoc)) dissiper(a);
  if (assaut && !assaut.fini) { // les bandits pillent 70 % du coffre
    assaut.fini = true; const ile = assaut.ile; const pertes = [];
    for (const k in ile.coffre) { const p = Math.floor(ile.coffre[k] * 0.7); if (p) { ile.coffre[k] -= p; pertes.push(`${fmtN(p)} ${RES_LABEL[k]}`); } }
    sauver(); son('lowFrequency_explosion_000', 0.7, 0.5);
    setTimeout(() => UI.mort(`Les bandits ont vidé ton coffre : ${pertes.join(', ') || 'il était vide'}. Recrute des gardes chez Oswin pour la prochaine fois.`, () => fondu(() => lancerHub())), 1600);
    return;
  }
  if (arene) { son('lowFrequency_explosion_000', 0.6, 0.6); if (allies.some(a => !a.mort)) UI.toast('Ton coéquipier continue le combat…'); verifierArene(); return; }
  if (invasion && rivauxVivants().length) { invasion.rival = rivauxVivants()[0]; return defaiteRival(); }
  if (modeActuel && modeActuel.sylve) return mortSylve();
  if (MODES.includes(modeActuel)) changerRang('donjon', -PERTE_RANG, 'Mort dans la Brèche');
  son('lowFrequency_explosion_000', 0.7, 0.5);
  const perte = Math.round(J.argent * 0.05); J.argent -= perte; sauver();
  setTimeout(() => UI.mort(`Tu perds ${perte.toLocaleString('fr-FR')} pièces d’argent. Ton équipement reste sur toi.`, () => fondu(() => lancerHub())), 1600);
}

// ---------------- Attaque de base ----------------
function attaquer(dt) {
  if (joueur.verrouT > 0 || joueur.mort || joueur.spinT > 0 || joueur.tornadeT > 0) return;
  const def = joueur.def, st = joueur.st;
  const c = choisirCible(st.portee);
  if (!c) return;
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
  joueur.atkT = 1 / st.vitesseAtk / (joueur.orageT > 0 ? 1.7 : 1); joueur.debutAtk = G.t;
  const anim = def.attaques[Math.floor(Math.random() * def.attaques.length)];
  const vit = Math.max(1, st.vitesseAtk * joueur.duree(anim) * 0.95);
  joueur.jouer(anim, { boucle: false, vitesse: vit, forcer: true, fondu: 0.08, fin: () => joueur.jouer(def.idle) });
  joueur.verrouT = 0.28; // l'attaque de base fige brièvement : choix voulu pour le PvP
  const couleur = TIERS[J.equip.arme.tier].color;
  if (def.assassin) { attaqueAssassin(c, vit); return; }
  if (!def.projectile) {
    programmer((def.ombre ? 0.22 : 0.3) / vit * 1.4, () => {
      if (c.mort) return;
      arcTaille(joueur.pos, joueur.angle - Math.PI / 2, def.ombre ? 2.6 : 2.9, def.ombre ? '#9a5aff' : couleur, Math.PI * 0.7, 0.22);
      if (def.ombre) emettre(V(c.pos.x, 1.1, c.pos.z), { n: 6, c1: '#c9a0ff', c2: '#1a0630', vit: 3, vie: 0.4, taille: 0.3 });
      if (dist2D(c.pos, joueur.pos) - c.rayon < st.portee + 1) { blesser(c, 1); son(Math.random() < 0.5 ? 'knifeSlice' : 'knifeSlice2', 0.45); if (def.orage) chaineEclair(c, 3, 0.55); }
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
  const s = joueur && joueur.sorts[k];
  if (!s || joueur.mort) return;
  if (arene && arene.t > 0) { UI.toast('Attends la fin du décompte'); return; }
  if ((joueur.cds[k] || 0) > 0) { son('error_001', 0.25); return; }
  if (joueur.energie < s.energie) { UI.toast('Pas assez d’énergie'); son('error_001', 0.25); return; }
  joueur.sortAttente = null;
  if (joueur.verrouT > 0.15 && !['rempart', 'souffle', 'ruee', 'purge', 'vampirisme', 'orage'].includes(s.id)) { joueur.sortAttente = { k, t: 0.7, force: viseeForcee }; return; }
  joueur.energie -= s.energie; joueur.cds[k] = joueur.cdMax[k] || s.cd; joueur.combatT = 4; joueur.debutAtk = G.t; joueur.animT = 0.5; // laisse l'animation du sort se jouer même en courant
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
      const anim = joueur.armeType === 'ombre' ? '1H_Melee_Attack_Chop' : joueur.armeType === 'epee' ? '2H_Melee_Attack_Chop' : joueur.armeType === 'arbalete' ? '2H_Ranged_Shoot' : 'Spellcast_Shoot';
      joueur.jouer(anim, { boucle: false, vitesse: 1.3, forcer: true, fin }); joueur.verrouT = 0.4;
      const bas = cible && cible.pv / cible.pvMax < 0.35; const mult = s.mult * (bas ? 3 : 1);
      programmer(0.25, () => {
        if (!cible || cible.mort) return;
        if (!joueur.def.projectile) { if (dist2D(cible.pos, joueur.pos) - cible.rayon < portee + 1) { arcTaille(joueur.pos, joueur.angle - Math.PI / 2, 3.6, '#ff2a3a', Math.PI * 0.5, 0.35); blesser(cible, mult, { c1: '#ff3a4a', c2: '#5a0008' }); son('impactPlate_heavy_000', 0.6, 0.7); } }
        else tirerProjectile(joueur.armeType === 'arbalete' ? 'carreau' : 'feu', '#ff2a3a', cible, 34, mult, { taille: 0.6 });
        if (bas) { G.shake = 0.5; UI.nombre(V(cible.pos.x, 3, cible.pos.z), 'EXÉCUTION', 'crit'); }
      });
      break;
    }
    case 'legion': {
      if (!modeActuel) { joueur.cds[k] = 0; joueur.energie += s.energie; UI.toast('Tes ombres ne répondent qu’au combat'); break; }
      joueur.jouer('Spellcast_Raise', { boucle: false, vitesse: 1.3, forcer: true, fin }); joueur.verrouT = 0.45;
      programmer(0.3, () => invoquerOmbres(Math.min(8, J.equip.arme.tier + ((J.equip.arme.ench || 0) >= 4 ? 1 : 0))));
      break;
    }
    case 'reflet': {
      const { dir, cible } = directionVisee(s.portee);
      if (!modeActuel || !cible) { joueur.cds[k] = 0; joueur.energie += s.energie; UI.toast(!modeActuel ? 'Tes ombres ne répondent qu’au combat' : 'Aucune cible à refléter'); break; }
      faireFace(dir); joueur.jouer('Spellcast_Shoot', { boucle: false, vitesse: 1.2, forcer: true, fin }); joueur.verrouT = 0.4;
      programmer(0.25, () => { if (!cible.mort) invoquerReflet(cible); });
      break;
    }
    case 'pasOmbre': {
      const { cible } = directionVisee(s.portee);
      if (!cible) { joueur.cds[k] = 0; joueur.energie += s.energie; UI.toast('Aucune cible'); break; }
      const ang = Math.atan2(cible.pos.x - joueur.pos.x, cible.pos.z - joueur.pos.z);
      const dos = V(cible.pos.x + Math.sin(ang) * (cible.rayon + 1.0), 0, cible.pos.z + Math.cos(ang) * (cible.rayon + 1.0));
      fumeeOmbre(joueur.pos); son('cloth1', 0.6, 0.6);
      const p = monde.marche && !monde.marche(dos.x, dos.z) ? cible.pos.clone().add(V(-Math.sin(ang), 0, -Math.cos(ang))) : dos;
      joueur.pos.set(p.x, 0, p.z); joueur.invuln = Math.max(joueur.invuln, 0.35);
      faireFace(V(cible.pos.x - joueur.pos.x, 0, cible.pos.z - joueur.pos.z).normalize()); fumeeOmbre(joueur.pos);
      for (const a of allies) if (a.invoc === 'ombre' && !a.mort) { a.pos.copy(pointLibrePres(cible.pos, cible.rayon + 1, cible.rayon + 2.4)); fumeeOmbre(a.pos); a.tc = cible; }
      joueur.jouer('1H_Melee_Attack_Chop', { boucle: false, vitesse: 1.7, forcer: true, fin }); joueur.verrouT = 0.35;
      programmer(0.15, () => {
        if (cible.mort) return;
        arcTaille(joueur.pos, joueur.angle - Math.PI / 2, 3, '#b07aff', Math.PI * 0.8, 0.3); arcTaille(joueur.pos, joueur.angle - Math.PI / 2, 2.4, '#ffffff', Math.PI * 0.5, 0.2);
        blesser(cible, s.mult, { stun: 0.8, c1: '#c9a0ff', c2: '#2a0a4a' }); son('knifeSlice2', 0.6, 0.7); G.shake = 0.35;
      });
      break;
    }
    case 'tornade': {
      joueur.spinT = 0; joueur.jouer('2H_Melee_Attack_Spinning', { vitesse: 1.5, forcer: true });
      joueur.tornadeT = 4; let tick = 0;
      const g = new THREE.Group();
      for (let i = 0; i < 4; i++) { const m = new THREE.Mesh(new THREE.RingGeometry(1.2 + i * 1.3, 1.6 + i * 1.3, 40, 1, 0, Math.PI * 1.3), new THREE.MeshBasicMaterial({ color: i % 2 ? '#ffffff' : '#7ac8ff', transparent: true, opacity: 0.5 - i * 0.08, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide })); m.rotation.x = -Math.PI / 2; m.position.y = 0.4 + i * 0.5; m.userData.v = 10 - i * 1.5; g.add(m); }
      son('thrusterFire_000', 0.5, 0.6);
      const jT = joueur;
      ajouterVfx(g, (t, dt) => {
        if (joueur !== jT || !(joueur.tornadeT > 0)) { if (joueur === jT) joueur.jouer(def.idle); return false; }
        g.position.copy(joueur.pos); g.children.forEach(m => (m.rotation.z -= m.userData.v * dt));
        if (joueur.courante && joueur.courante.getClip().name !== '2H_Melee_Attack_Spinning') joueur.jouer('2H_Melee_Attack_Spinning', { vitesse: 1.5 });
        joueur.tornadeT -= dt; if (joueur.mort) joueur.tornadeT = 0;
        if (Math.random() < 0.7) { const a = Math.random() * 6.28, rr = 1 + Math.random() * 5; emettre(V(joueur.pos.x + Math.cos(a) * rr, 0.3, joueur.pos.z + Math.sin(a) * rr), { n: 1, c1: '#e0f4ff', c2: '#3a7aff', dir: V(-Math.sin(a), 1.2, Math.cos(a)), vit: 6, vie: 0.5, taille: 0.35 }); }
        for (const e of vivants()) { const d = dist2D(e.pos, joueur.pos); if (d < 7 && d > 1.6 && !e.boss) { const k = Math.min(1, dt * 6); deplacer(e, (joueur.pos.x - e.pos.x) * k * 0.6, (joueur.pos.z - e.pos.z) * k * 0.6, 0.4); } }
        tick -= dt; if (tick <= 0) { tick = 0.3; zoneDegats(joueur.pos, 3.8, s.mult, { silence: true, c1: '#bfe8ff' }); son('knifeSlice2', 0.25, 1.4); }
        if (joueur.tornadeT <= 0) { joueur.jouer(def.idle); return false; }
      });
      break;
    }
    case 'titan': {
      const { dir, point } = directionVisee(s.portee); faireFace(dir);
      const dep = joueur.pos.clone(), arr = pointLibreProche(V(point.x, 0, point.z), 0.6) || dep.clone();
      joueur.jouer('1H_Melee_Attack_Chop', { boucle: false, vitesse: 0.9, forcer: true, fin }); joueur.verrouT = 0.7; joueur.invuln = Math.max(joueur.invuln, 0.7);
      son('cloth1', 0.6, 0.6);
      ajouterVfx(new THREE.Group(), (t) => {
        const k = Math.min(1, t / 0.55);
        joueur.pos.x = dep.x + (arr.x - dep.x) * k; joueur.pos.z = dep.z + (arr.z - dep.z) * k; joueur.root.position.y = Math.sin(k * Math.PI) * 4;
        if (k >= 1) {
          joueur.root.position.y = 0; G.shake = 1;
          const avant = vivants().length;
          onde(arr, '#ffe27a', 7, 0.6); onde(arr, '#ffffff', 4, 0.4); lueurSol(arr, '#ffd27a', 5, 0.8, 1.2);
          emettre(V(arr.x, 0.3, arr.z), { n: 90, c1: '#fff2c0', c2: '#8a6a2a', vit: 11, vie: 0.8, taille: 0.6, hemi: true, grav: 6 });
          zoneDegats(arr, 5.5, s.mult, { stun: 1.0, air: true, c1: '#ffe27a' }); son('impactPlate_heavy_000', 0.8, 0.5); son('lowFrequency_explosion_000', 0.5, 1.3);
          const tues = avant - vivants().length;
          if (tues >= 3) { joueur.cds[k2] = 0; UI.nombre(V(joueur.pos.x, 3, joueur.pos.z), 'RECHARGÉ !', 'crit'); son('confirmation_001', 0.6, 1.4); }
          return false;
        }
      });
      const k2 = k;
      break;
    }
    case 'orage': {
      joueur.orageT = 10; joueur.vampT = Math.max(joueur.vampT, 10);
      son('forceField_000', 0.7, 1.8); son('lowFrequency_explosion_000', 0.5, 1.6); G.shake = 0.5;
      onde(joueur.pos, '#9ab8ff', 6, 0.7); emettre(V(joueur.pos.x, 1.5, joueur.pos.z), { n: 80, c1: '#ffffff', c2: '#3a5aff', vit: 8, vie: 0.8, taille: 0.45 });
      let frappe = 0; const jO = joueur;
      ajouterVfx(new THREE.Group(), (t, dt) => {
        if (joueur !== jO || !(joueur.orageT > 0)) return false;
        joueur.orageT -= dt; if (joueur.mort) joueur.orageT = 0;
        if (Math.random() < 0.5) emettre(V(joueur.pos.x + rnd(-0.6, 0.6), 0.5 + Math.random() * 1.6, joueur.pos.z + rnd(-0.6, 0.6)), { n: 1, c1: '#ffffff', c2: '#5a8aff', vit: 2, vie: 0.3, taille: 0.25 });
        frappe -= dt;
        if (frappe <= 0) { frappe = 0.4; const l = vivants().filter(e => dist2D(e.pos, joueur.pos) < s.portee); if (l.length) eclairCiel(hasard(l), s.mult); }
        if (joueur.orageT <= 0) return false;
      });
      UI.toast('COLÈRE DE L’ORAGE', true);
      break;
    }
    case 'triple': {
      const { dir, cible } = directionVisee(s.portee);
      if (!cible) { joueur.energie += s.energie; UI.toast('Aucune cible'); break; }
      faireFace(dir);
      const d = dist2D(cible.pos, joueur.pos) - cible.rayon;
      if (d > 1.6) { const p = cible.pos.clone().addScaledVector(V(joueur.pos.x - cible.pos.x, 0, joueur.pos.z - cible.pos.z).normalize(), cible.rayon + 1.1); traineeRouge(joueur.pos, p); const q = pointLibreProche(p, 0.5); if (q) joueur.pos.set(q.x, 0, q.z); }
      joueur.verrouT = 0.42;
      const anims = ['1H_Melee_Attack_Slice_Diagonal', '1H_Melee_Attack_Chop', '2H_Melee_Attack_Stab'];
      for (let i = 0; i < 3; i++) programmer(0.02 + i * 0.13, () => {
        if (cible.mort) return; faireFace(V(cible.pos.x - joueur.pos.x, 0, cible.pos.z - joueur.pos.z).normalize());
        joueur.jouer(anims[i], { boucle: false, vitesse: 2.6, forcer: true, fondu: 0.04, fin });
        arcTaille(joueur.pos, joueur.angle - Math.PI / 2, 2.4, i === 2 ? '#ff2a3a' : '#ffb0b0', Math.PI * 0.6, 0.18);
        blesser(cible, s.mult * furtifBonus(), { c1: '#ff4a5a', c2: '#3a0008' }); gagnerCombo(1); son(i === 2 ? 'knifeSlice2' : 'knifeSlice', 0.4, 1.2 + i * 0.1);
      });
      break;
    }
    case 'curee': {
      const pts = joueur.combo || 0;
      const { dir, cible } = directionVisee(s.portee);
      if (!cible || !pts) { joueur.cds[k] = 0; joueur.energie += s.energie; UI.toast(!pts ? 'Pas de points de combo' : 'Aucune cible'); son('error_001', 0.3); break; }
      faireFace(dir); teleportDerriere(cible);
      joueur.jouer('2H_Melee_Attack_Stab', { boucle: false, vitesse: 1.8, forcer: true, fin }); joueur.verrouT = 0.35;
      programmer(0.12, () => {
        if (cible.mort) return;
        const mult = (s.mult + 0.65 * pts) * furtifBonus();
        arcTaille(joueur.pos, joueur.angle - Math.PI / 2, 3.2, '#ff1a2a', Math.PI * 0.9, 0.35); arcTaille(joueur.pos, joueur.angle - Math.PI / 2, 2.5, '#ffffff', Math.PI * 0.5, 0.25);
        blesser(cible, mult, { c1: '#ff2a3a', c2: '#2a0004' }); emettre(V(cible.pos.x, 1.2, cible.pos.z), { n: 20 + pts * 12, c1: '#ff6a6a', c2: '#5a0008', vit: 7, vie: 0.7, taille: 0.45, grav: 6 });
        UI.nombre(V(cible.pos.x, 3, cible.pos.z), pts >= 5 ? 'CURÉE ×5 !' : `Curée ×${pts}`, 'crit'); son('impactPlate_heavy_000', 0.6, 0.9); G.shake = 0.25 + pts * 0.1;
        joueur.combo = 0; if (pts >= 5) furtif(1);
      });
      break;
    }
    case 'zephyr': {
      if (joueur.zephyrT > 0 && joueur.zephyrCharges > 0) { joueur.zephyrCharges--; joueur.energie += s.energie; joueur.cds[k] = joueur.zephyrCharges > 0 ? 0.25 : joueur.cdMax[k]; }
      else { joueur.zephyrCharges = 2; joueur.zephyrT = 5; joueur.cds[k] = 0.25; joueur.sprintT = Math.max(joueur.sprintT, 3); programmer(5, () => { if (joueur.zephyrCharges > 0) { joueur.zephyrCharges = 0; joueur.cds[k] = joueur.cdMax[k]; } joueur.zephyrT = 0; }); }
      const mv = Math.hypot(entree.jx, entree.jy) > 0.2 ? DIR_DROITE.clone().multiplyScalar(entree.jx).addScaledVector(DIR_HAUT, entree.jy).normalize() : directionVisee(s.portee).dir;
      faireFace(mv); const dep = joueur.pos.clone();
      joueur.jouer('Dodge_Forward', { boucle: false, vitesse: 2, forcer: true, fin }); joueur.dashT = 0.2; joueur.dashV = mv.clone().multiplyScalar(s.portee / 0.2); joueur.invuln = Math.max(joueur.invuln, 0.3);
      son('cloth1', 0.6, 1.4);
      programmer(0.21, () => {
        traineeRouge(dep, joueur.pos, '#7affc0');
        for (const e of vivants()) { if (distSegPt(dep, joueur.pos, e.pos) < 1.6 + e.rayon) { blesser(e, s.mult * furtifBonus(), { c1: '#bfffe0', c2: '#0a5a3a' }); gagnerCombo(1); } }
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
  if (e.camp === 'ennemi') emoteBot(e, ['malin', 'bof'], 0.2, 0.3);
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
G.auto = (() => { try { return localStorage.getItem('breche-auto') === '1'; } catch (e) { return false; } })();
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
  if (arene && arene.t > 0) { mx = 0; my = 0; } // décompte : personne ne bouge
  const m = Math.min(1, Math.hypot(mx, my));
  const tourne = j.spinT > 0 || j.tornadeT > 0; // tempête d'acier / œil du cyclone : on garde l'animation de toupie
  if (j.animT > 0) j.animT -= dt;
  const bloque = j.verrouT > 0 && !tourne;
  let autoAtk = false;
  if (G.auto && pvpActif()) couperAuto('Mode auto désactivé : combat JcJ');
  if (G.auto && m <= 0.12 && !transition) autoAtk = modeAuto(j, dt, bloque);
  if (m > 0.12 && !bloque) {
    const dir = DIR_DROITE.clone().multiplyScalar(mx).addScaledVector(DIR_HAUT, my).normalize();
    let v = st.vitesse * (1 + bonusParch('vitesse')) * (j.orageT > 0 ? 1.4 : 1) * (j.sprintT > 0 ? 1.6 : 1) * (j.slowT > 0 ? 0.6 : 1) * (tourne ? 0.7 : 1); // vitesse constante, peu importe l'inclinaison du joystick
    deplacer(j, dir.x * v * dt, dir.z * v * dt);
    const vise = (entree.atk || entree.clavier[' ']) && j.cible && !j.cible.mort && dist2D(j.cible.pos, j.pos) - j.cible.rayon < st.portee + 0.5;
    if (!tourne && !vise) { j.angle = tourner(j.angle, Math.atan2(dir.x, dir.z), dt * 14); j.root.rotation.y = j.angle; }
    if (!tourne && !(j.animT > 0) && (j.atkT < 0.1 || !entree.atk)) j.jouer(j.def.run);
    j.pasT -= dt * v; if (j.pasT <= 0) { j.pasT = 2.4; son(Math.random() < 0.5 ? 'footstep_concrete_000' : 'footstep_concrete_001', 0.12); }
  } else if (!bloque && !tourne && !(j.animT > 0)) {
    const c = j.courante; const n = c ? c.getClip().name : '';
    if (n === j.def.run || n === 'Walking_A') j.jouer(j.def.idle);
  }
  if (j.sortAttente) { j.sortAttente.t -= dt; if (j.sortAttente.t <= 0) j.sortAttente = null; else if (j.verrouT <= 0.15) { const sa = j.sortAttente; j.sortAttente = null; viseeForcee = sa.force; lancerSort(sa.k); viseeForcee = null; } }
  if ((entree.atk || entree.clavier[' '] || autoAtk) && !(arene && arene.t > 0) && !j.sortAttente) attaquer(dt);
  j.maj(dt);
}

// ---------------- Sorts par signes ----------------
const COUL_SIGNE = { epee: '#ffd27a', arbalete: '#9aff7a', baton: '#ff8a3a', ombre: '#b07aff', orage: '#7ab8ff', assassin: '#ff4a5a' };
G.gestes = (() => { try { return localStorage.getItem('breche-gestes') !== '0'; } catch (e) { return true; } })();
function ralenti(duree, k) { G.ralentiT = Math.max(G.ralentiT || 0, duree); G.ralentiK = k; }
function cibleEcran(x, y, rayon) {
  let best = null, bd = rayon;
  for (const en of vivants()) { const s = projeter(V(en.pos.x, 1.2, en.pos.z)); if (!s.visible) continue; const d = Math.hypot(s.x - x, s.y - y); if (d < bd) { bd = d; best = en; } }
  return best;
}
function lancerParSigne(cle, debut, centre) {
  if (!joueur || joueur.mort) return false;
  const s = joueur.sorts[cle];
  if (!s) { UI.toast('Aucun sort sur ce signe'); return false; }
  if ((joueur.cds[cle] || 0) > 0) { UI.toast(`${s.nom} : encore ${Math.ceil(joueur.cds[cle])} s`); son('error_001', 0.25); return false; }
  if (joueur.energie < s.energie) { UI.toast('Pas assez d’énergie'); son('error_001', 0.25); return false; }
  if (arene && arene.t > 0) return false;
  // l'ennemi sur lequel on a dessiné devient la cible
  const c = cibleEcran(debut[0], debut[1], 120) || cibleEcran(centre[0], centre[1], 150) || (joueur.cibleVerrou && !joueur.cibleVerrou.mort ? joueur.cibleVerrou : null) || choisirCible(18);
  if (c) joueur.cibleVerrou = c;
  son('forceField_000', 0.25, 1.8);
  const lancer = () => { viseeForcee = c ? { cible: c } : null; lancerSort(cle); viseeForcee = null; };
  bondStyle(c, lancer);
  return true;
}
// saut acrobatique avant le sort : les combattants bondissent sur la cible, les tireurs font une vrille en arrière
function bondStyle(c, apres) {
  const type = J.equip.arme ? J.equip.arme.type : 'epee';
  const melee = ['epee', 'orage', 'assassin', 'ombre'].includes(type);
  const dep = joueur.pos.clone();
  let arr = null;
  if (c && melee) { const d = dist2D(c.pos, dep); if (d > 3.2 && d < 16) { const dir = V(c.pos.x - dep.x, 0, c.pos.z - dep.z).normalize(); arr = pointLibreProche(V(c.pos.x - dir.x * (c.rayon + 1.4), 0, c.pos.z - dir.z * (c.rayon + 1.4)), 0.6); } }
  if (!melee) { const ang = c ? Math.atan2(c.pos.x - dep.x, c.pos.z - dep.z) : joueur.angle; arr = pointLibreProche(V(dep.x - Math.sin(ang) * 2.6, 0, dep.z - Math.cos(ang) * 2.6), 0.6); if (c) { joueur.angle = ang; joueur.root.rotation.y = ang; } }
  if (!arr) { apres(); ralenti(0.06, 0.15); return; }
  const duree = melee ? 0.34 : 0.3, haut = melee ? 2.6 : 1.4;
  joueur.verrouT = Math.max(joueur.verrouT, duree); joueur.invuln = Math.max(joueur.invuln, duree + 0.1);
  if (melee) { joueur.angle = Math.atan2(arr.x - dep.x, arr.z - dep.z); joueur.root.rotation.y = joueur.angle; }
  joueur.jouer(melee ? 'Dodge_Forward' : 'Dodge_Backward', { boucle: false, forcer: true, vitesse: 1.7 });
  const coul = COUL_SIGNE[type] || '#ffd27a';
  son('cloth1', 0.5, 1.3);
  const jB = joueur;
  ajouterVfx(new THREE.Group(), (t) => {
    if (joueur !== jB) return false;
    const k = Math.min(1, t / duree), e = k * k * (3 - 2 * k);
    joueur.pos.x = dep.x + (arr.x - dep.x) * e; joueur.pos.z = dep.z + (arr.z - dep.z) * e;
    joueur.root.position.y = Math.sin(k * Math.PI) * haut;
    if (melee) joueur.model.rotation.x = Math.sin(k * Math.PI) * -0.5; // corps penché en plein saut
    emettre(V(joueur.pos.x, 0.9 + joueur.root.position.y, joueur.pos.z), { n: 3, c1: '#ffffff', c2: coul, vit: 0.8, vie: 0.35, taille: 0.5, rayon: 0.4 });
    if (k >= 1) {
      joueur.root.position.y = 0; joueur.model.rotation.x = 0;
      onde(arr, coul, melee ? 5 : 3, 0.45); emettre(V(arr.x, 0.3, arr.z), { n: 40, c1: '#ffffff', c2: coul, vit: 7, vie: 0.6, taille: 0.45, hemi: true, grav: 5 });
      G.shake = Math.max(G.shake, melee ? 0.55 : 0.25); ralenti(0.07, 0.12);
      apres(); return false;
    }
  });
}
// ---------------- Mode auto ----------------
function pvpActif() {
  if (arene) return true;
  if (invasion && !invasion.fini && (invasion.mode === 'menee' || (invasion.rivaux || []).some(r => !r.mort) || invasion.rival && !invasion.rival.mort)) return true;
  return ennemis.some(e => e.rival && !e.mort);
}
function couperAuto(msg) {
  G.auto = false; try { localStorage.setItem('breche-auto', '0'); } catch (e) {}
  if (joueur) joueur.autoCible = null;
  UI.toast(msg); const b = document.getElementById('btnAuto'); if (b) b.classList.remove('on');
}
function dangerAuto(p, marge) { for (const z of dangers) { if (z.camp === 'allie' || z.camp === 'joueur') continue; const dx = p.x - z.p.x, dz = p.z - z.p.z; if (dx * dx + dz * dz < (z.r + marge) ** 2) return z; } return null; }
function cibleAuto(j) {
  let best = null, bd = 1e9;
  for (const e of ennemis) {
    if (e.mort || e.camp === 'allie' || e.camp === 'joueur' || e.furtifT > 0 || e.pnj) continue;
    const d = dist2D(e.pos, j.pos);
    const sc = d + (e.boss && d > 12 ? 40 : 0) + (d > 32 ? 20 : 0);
    if (sc < bd) { bd = sc; best = e; }
  }
  return best;
}
function modeAuto(j, dt, bloque) {
  j.autoT = (j.autoT || 0) - dt;
  if (j.autoT <= 0 || !j.autoCible || j.autoCible.mort) { j.autoT = 0.35; j.autoCible = cibleAuto(j); }
  if (j.pv < j.st.pvMax * 0.35 && j.potions > 0 && !(j.cds.POT > 0) && j.potionT <= 0) boirePotion();
  const v = j.st.vitesse * (1 + bonusParch('vitesse')) * (j.orageT > 0 ? 1.4 : 1) * (j.sprintT > 0 ? 1.6 : 1) * (j.slowT > 0 ? 0.6 : 1);
  // esquive des zones rouges
  const z = bloque ? null : dangerAuto(j.pos, 0.9);
  if (z) {
    const dir = V(j.pos.x - z.p.x, 0, j.pos.z - z.p.z); if (dir.lengthSq() < 0.01) dir.set(Math.sin(j.angle + 1.57), 0, Math.cos(j.angle + 1.57)); dir.normalize();
    let ok = false;
    for (const k of [0, 0.7, -0.7, 1.4, -1.4, 2.2, -2.2]) {
      const a = Math.atan2(dir.x, dir.z) + k, dx = Math.sin(a) * v * dt, dz = Math.cos(a) * v * dt;
      const np = V(j.pos.x + Math.sin(a) * 1.5, 0, j.pos.z + Math.cos(a) * 1.5);
      if (!libre(np.x, np.z, 0.5)) continue;
      const ax = j.pos.x, az = j.pos.z; deplacer(j, dx, dz);
      if (Math.hypot(j.pos.x - ax, j.pos.z - az) > v * dt * 0.3) { ok = true; j.angle = tourner(j.angle, a, dt * 14); j.root.rotation.y = j.angle; break; }
    }
    if (ok) { j.jouer(j.def.run); return false; }
  }
  const c = j.autoCible; if (!c) return false;
  j.cible = c;
  const d = dist2D(c.pos, j.pos) - c.rayon;
  if (d > j.st.portee * 0.9 && !bloque && !(j.spinT > 0 || j.tornadeT > 0)) {
    const ax = j.pos.x, az = j.pos.z;
    allerVers(j, c.pos, dt, v);
    if (dangerAuto(j.pos, 0.6)) { j.pos.x = ax; j.pos.z = az; j.jouer(j.def.idle); return false; } // n'entre pas dans une zone rouge
    const mx = j.pos.x - ax, mz = j.pos.z - az;
    if (mx * mx + mz * mz > 1e-6) { j.angle = tourner(j.angle, Math.atan2(mx, mz), dt * 12); j.root.rotation.y = j.angle; }
    j.jouer(j.def.run);
  }
  const aPortee = d <= j.st.portee + 0.3;
  // sorts : un toutes les ~0,6 s, quand la cible est à portée
  j.autoSortT = (j.autoSortT || 0) - dt;
  if (j.autoSortT <= 0 && !j.sortAttente && j.verrouT <= 0.15) {
    j.autoSortT = 0.6;
    const ordre = ['W', 'E', 'Q'];
    if (j.sorts.R && j.pv < j.st.pvMax * 0.5) ordre.unshift('R');
    for (const k of ordre) {
      const s = j.sorts[k]; if (!s || (j.cds[k] || 0) > 0 || j.energie < s.energie) continue;
      const portee = s.portee > 0 ? s.portee : 6;
      if (k !== 'R' && d > portee + 1) continue;
      if (s.id === 'curee' && (j.combo || 0) < 4) continue;
      lancerSort(k); break;
    }
  }
  return aPortee;
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
      if (o.acc >= 0.5) { o.acc = 0; e.pv -= o.dps * 0.5; if (compteur) noterDegats(joueur, o.dps * 0.5); UI.nombre(V(e.pos.x, e.hauteurPlaque * 0.7, e.pos.z), Math.round(o.dps * 0.5), 'info'); emettre(V(e.pos.x, 1, e.pos.z), { n: 3, c1: o.c, c2: '#ffffff', vit: 1.5, vie: 0.4, taille: 0.25 }); if (e.pv <= 0) { tuer(e); break; } }
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
    if (e.boss) { majBoss(e, dc, dt); e.maj(dt); continue; }
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
  deplacer(e, dir.x * v, dir.z * v, e === joueur ? 0.5 : Math.min(e.rayon * 0.8, 1.1));
  // détection de blocage dans le décor : après 0,8 s coincé, il bondit près de sa cible
  const bouge = Math.hypot(e.pos.x - ax, e.pos.z - az);
  e.bloqueT = bouge < v * 0.3 ? (e.bloqueT || 0) + dt : Math.max(0, (e.bloqueT || 0) - dt * 2);
  if (e.bloqueT > 0.8) { e.bloqueT = 0; if (e === joueur) { e.chemin = null; e.contour = -(e.contour || 1); } else if (l < 18) bondir(e, cible); }
  e.angle = tourner(e.angle, Math.atan2(dir.x, dir.z), dt * 10); e.root.rotation.y = e.angle;
}
function faceJoueur(e, dt, k = 10) { const c = e.tc || joueur; e.angle = tourner(e.angle, Math.atan2(c.pos.x - e.pos.x, c.pos.z - e.pos.z), dt * k); e.root.rotation.y = e.angle; }
function majMob(e, d, dt) {
  const def = e.def;
  const c = e.tc;
  if (e.attaqueT > 0) { e.attaqueT -= dt; faceJoueur(e, dt, 6); return; }
  const portee = def.portee;
  if (d > portee + e.rayon) { allerVers(e, c.pos, dt, def.vitesse); e.jouer('Running_A'); return; }
  faceJoueur(e, dt);
  if (e.atkT > 0) { e.jouer('Idle_Combat'); return; }
  e.atkT = def.type === 'melee' ? rnd(1.3, 1.7) : rnd(1.9, 2.4);
  e.attaqueT = 0.7;
  e.jouer(def.atk, { boucle: false, forcer: true, vitesse: 1.1, fin: () => e.jouer('Idle_Combat') });
  if (def.type === 'melee') programmer(0.45, () => { if (!e.mort && e.stunT <= 0 && !c.mort && dist2D(e.pos, c.pos) < portee + e.rayon + 0.9) { infliger(e, c, e.dmg); son('impactGeneric_light_000', 0.3); } });
  else programmer(0.4, () => { if (!e.mort && e.stunT <= 0) tirEnnemi(e, def.type === 'caster' ? 'feu' : 'carreau', e.dmg); });
}
function tirEnnemi(e, type, dmg, dirForcee = null, vitesse = null) {
  const depart = V(e.pos.x, 1.3 * (e.boss ? Math.min(2.2, e.boss.scale) * 0.7 : 1) + (e.hover || 0), e.pos.z);
  const vise = e.tc || joueur;
  const dest = V(vise.pos.x, 1.1 + (vise.hover || 0), vise.pos.z);
  if (e.skill !== undefined && vise.vel && !dirForcee) { const t = dest.distanceTo(V(e.pos.x, 1.3, e.pos.z)) / (vitesse || (type === 'feu' ? 11 : 16)); dest.addScaledVector(vise.vel, t * e.skill * 0.9); }
  if (e.skill !== undefined && !dirForcee) { const err = (1 - e.skill) * 1.6; dest.x += rnd(-err, err); dest.z += rnd(-err, err); }
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
  if (e.specT <= 0) { capaciteBoss(e); e.specT = rnd(4.2, 5.6) * (BOSS_SYLVE.includes(b) ? 1.15 : 1); return; }
  const dragon = e.def.model === 'Dragon_Evolved';
  const ranged = b.id === 'archere' || b.id === 'necro' || b.id === 'sylphe' || b.id === 'chasseur';
  if (b.id === 'sylphe') e.root.position.y = e.hover + Math.sin(G.t * 2) * 0.25;
  const portee = ranged ? 10 : e.def.portee + e.rayon;
  if (e.figeT > 0) { e.figeT -= dt; return; }
  if (d > portee) { allerVers(e, tc.pos, dt, e.def.vitesse * (enrage ? 1.25 : 1)); e.jouer(dragon ? 'Fast_Flying' : 'Running_A'); return; }
  faceJoueur(e, dt, 6);
  if (e.atkT > 0) { e.jouer(dragon ? 'Flying_Idle' : 'Idle_Combat'); return; }
  e.atkT = ranged ? 1.4 : 1.7; e.attaqueT = 0.8;
  if (dragon) { e.jouer(Math.random() < 0.5 ? 'Punch' : 'Headbutt', { boucle: false, forcer: true, fin: () => e.jouer('Flying_Idle') }); programmer(0.5, () => { if (!e.mort && !tc.mort && dist2D(e.pos, tc.pos) < portee + 1.2) infliger(e, tc, e.dmg); }); }
  else if (ranged) { e.jouer(e.def.atk, { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') }); programmer(0.4, () => { if (!e.mort) tirEnnemi(e, b.id === 'necro' || b.id === 'sylphe' ? 'feu' : 'carreau', e.dmg * 0.75); }); }
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
  if (BOSS_SYLVE.includes(b)) return capaciteSylve(e);
  const pj = (e.tc || joueur).pos.clone();
  if (b.id === 'gardien') {
    if (e.cycle % 2) {
      // bond et fracas
      e.jouer('1H_Melee_Attack_Jump_Chop', { boucle: false, forcer: true, vitesse: 0.8, fin: () => e.jouer('Idle_Combat') });
      e.sautA = e.pos.clone(); e.sautB = pointLibrePres(pj, 0, 1.2, 1.0); e.sautD = e.sautT = 1.2; e.sautH = 4; e.attaqueT = 1.6;
      tele(pj, 3.8, 1.2, '#ff2a2a', () => { G.shake = 1; onde(pj, '#ff8a3a', 6, 0.6); emettre(V(pj.x, 0.3, pj.z), { n: 50, c1: '#d8c8a8', c2: '#6a5a4a', vit: 8, vie: 0.8, taille: 0.6, hemi: true, grav: 6 }); son('impactPlate_heavy_000', 0.8, 0.6); toucherZone(e, pj, 3.8, e.dmg * 3.4, { slow: 2.5 }); });
    } else {
      e.jouer('2H_Melee_Attack_Spinning', { vitesse: 1.2, forcer: true }); e.attaqueT = 1.6;
      const c = e.pos.clone();
      tele(c, 5.5, 1.4, '#ff2a2a', () => { onde(c, '#ffd0a0', 6, 0.5); son('knifeSlice', 0.7, 0.6); toucherZone(e, e.pos, 5.9, e.dmg * 2.9); e.jouer('Idle_Combat'); });
    }
  } else if (b.id === 'archere') {
    if (e.cycle % 3 === 0) { e.jouer('Spellcast_Summon', { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') }); e.attaqueT = 1.2; invoquer(e, 2); UI.toast('L’Archère appelle ses morts !'); }
    else {
      const base = Math.atan2(pj.x - e.pos.x, pj.z - e.pos.z); e.attaqueT = 1.5;
      e.jouer('2H_Ranged_Aiming' in e.actions ? '2H_Ranged_Shoot' : e.def.atk, { boucle: false, forcer: true, vitesse: 0.6, fin: () => e.jouer('Idle_Combat') });
      tele(e.pos, 14, 1.0, '#ff2a2a', () => { for (let i = -3; i <= 3; i++) { const a = base + i * 0.17; tirEnnemi(e, 'carreau', e.dmg * 1.5, V(Math.sin(a), 0, Math.cos(a)), 19); } }, { cone: 1.2, angle: base - Math.PI / 2 });
    }
  } else if (b.id === 'necro') {
    if (e.cycle % 3 === 0) { e.jouer('Spellcast_Summon', { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') }); e.attaqueT = 1.4; invoquer(e, 3); UI.toast('Le Nécromancien relève les morts !'); }
    else {
      e.jouer('Spellcast_Shoot', { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') }); e.attaqueT = 1.0;
      for (let i = 0; i < 5; i++) {
        const p = i === 0 ? pj.clone() : pj.clone().add(V(rnd(-5, 5), 0, rnd(-5, 5)));
        tele(p, 2.6, 1.3 + i * 0.12, '#ff2a2a', () => { emettre(V(p.x, 0.4, p.z), { n: 30, c1: '#ff8aff', c2: '#ff1a4a', vit: 6, vie: 0.6, taille: 0.6, hemi: true }); onde(p, '#ff3a6a', 3, 0.4); son('explosionCrunch_000', 0.3, 1.2); toucherZone(e, p, 2.6, e.dmg * 2.4); });
      }
    }
  } else if (b.id === 'horreur' || b.id === 'devoreur') {
    const r = e.cycle % 3;
    const base = Math.atan2(pj.x - e.pos.x, pj.z - e.pos.z);
    if (r === 1) {
      e.attaqueT = 1.9; e.jouer('Headbutt', { boucle: false, forcer: true, vitesse: 0.6, fin: () => e.jouer('Flying_Idle') });
      e.angle = base; e.root.rotation.y = base;
      const c = e.pos.clone();
      tele(c, 11, 1.3, '#ff2a2a', () => {
        son('thrusterFire_000', 0.9, 0.6); G.shake = 0.6;
        for (let i = 0; i < 70; i++) { const a = base + rnd(-0.6, 0.6); emettre(V(c.x, 2.4, c.z), { n: 1, c1: '#ffe08a', c2: '#ff2a00', dir: V(Math.sin(a), -0.05, Math.cos(a)), vit: 16, disp: 1, vie: 0.7, taille: 1.0, frein: 1 }); }
        toucherZone(e, c, 11, e.dmg * 3.6, { cone: { dir: V(Math.sin(base), 0, Math.cos(base)), cos: Math.cos(0.65) } });
      }, { cone: 1.3, angle: base - Math.PI / 2 });
    } else if (r === 2) {
      e.attaqueT = 1.2; const dir = V(Math.sin(base), 0, Math.cos(base));
      tele(e.pos, 18, 1.1, '#ff2a2a', () => { e.chargeT = 0.6; e.chargeV = dir.clone().multiplyScalar(30); e.chargeTouches = new Set(); e.jouer('Fast_Flying', { vitesse: 2 }); son('lowFrequency_explosion_000', 0.5, 1.2); }, { ligne: true, largeur: 3.4, angle: base + Math.PI });
      e.angle = base; e.root.rotation.y = base;
    } else {
      e.attaqueT = 1; e.jouer('Punch', { boucle: false, forcer: true, fin: () => e.jouer('Flying_Idle') });
      for (let i = 0; i < 6; i++) {
        const p = i === 0 ? pj.clone() : pj.clone().add(V(rnd(-6, 6), 0, rnd(-6, 6)));
        tele(p, 3, 1.6 + i * 0.1, '#ff2a2a', () => { G.shake = 0.5; emettre(V(p.x, 0.5, p.z), { n: 40, c1: '#fff0b0', c2: '#ff3a00', vit: 8, vie: 0.7, taille: 0.7, hemi: true }); onde(p, '#ff8a2a', 4, 0.5); son('explosionCrunch_000', 0.4, 0.8); toucherZone(e, p, 3, e.dmg * 2.6); });
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
  if (it.cat === 'butin') { const ex = J.sac.find(x => x.cat === 'butin' && x.type === it.type && (x.tier || 0) === (it.tier || 0)); if (ex) { ex.n += it.n; return; } }
  if (J.sac.length >= 40) { UI.toast('Sac plein : ' + nomObjet(it) + ' perdu'); return; }
  J.sac.push(it);
  if (!silencieux) UI.toast('+ ' + nomObjet(it));
}
const API = {
  reconstruireSorts: () => { if (joueur) UI.construireSorts(joueur); },
  basculerAuto: () => { if (!G.auto && pvpActif()) { UI.toast('Mode auto interdit en JcJ'); return false; } G.auto = !G.auto; try { localStorage.setItem('breche-auto', G.auto ? '1' : '0'); } catch (e) {} if (joueur) joueur.autoCible = null; UI.toast(G.auto ? 'Mode auto activé' : 'Mode auto désactivé'); return G.auto; },
  autoActif: () => !!G.auto,
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
  arene: (format, opts = {}) => entrerArene(format, opts),
  enchanter: (id) => enchanter(id),
  acheterRunes: (n) => { const prix = 5000 * n; if (J.argent < prix) { UI.toast('Pas assez d’argent'); son('error_001', 0.4); return false; } J.argent -= prix; ajouterSac(creerButin('rune', n), true); son('handleCoins', 0.5); sauver(); return true; },
  nbRunes: () => J.sac.filter(i => i.cat === 'butin' && i.type === 'rune').reduce((a, i) => a + (i.n || 1), 0),
  raresDebloques: () => ['ombre', 'orage', 'assassin'].filter(t => (t === 'ombre' && J.codes && J.codes.includes('BRECHE-OMBRE')) || J.equip.arme?.type === t || J.sac.some(i => i.type === t) || (J.debloques || []).includes(t)),
  ombreDebloquee: () => !!((J.codes && J.codes.length) || J.equip.arme?.type === 'ombre' || J.sac.some(i => i.type === 'ombre')),
  acheterIle: (type, taille) => acheterIle(type, taille),
  allerIle: (id) => { const ile = iles().find(i => i.id === id); if (ile) entrerIle(ile); },
  piller: () => entrerIle(ileBot()),
  construire: (ile, plot, t) => construire(ile, plot, t),
  get ile() { return API_ILE; },
  musique: (on) => musiqueActive(on),
  parchemins: () => etatParchemins(),
  prixTP: () => PRIX_TP,
  acheterTP: () => { if (J.argent < PRIX_TP) { UI.toast('Pas assez d’argent'); son('error_001', 0.4); return false; } J.argent -= PRIX_TP; J.parchTP = (J.parchTP || 0) + 1; son('jingle_legend', 0.5); UI.toast('Parchemin de téléportation acheté'); sauver(); return true; },
  acheterParchemin: (id, n = 1) => { const p = PARCHEMINS[id]; const prix = BOUTIQUE_PARCH_GRATUITE ? 0 : p.prix * n; if (J.argent < prix) { UI.toast('Pas assez d’argent'); son('error_001', 0.4); return false; } J.argent -= prix; ajouterSac(creerParchemin(id, n), true); son('handleCoins', 0.5); sauver(); return true; },
  utiliserParchemin: (itemId) => utiliserParchemin(itemId),
  rang: (mode) => rangDe(mode), classement: (mode) => classementRang(mode), xpLog: () => J.xpLog || [],
  emote: (id) => emoteJoueur(id),
  visable: (k) => { const s = joueur && joueur.sorts[k]; return !!(s && s.portee > 0 && !['bouclier', 'soin', 'sprint', 'buff'].includes(s.type) && s.id !== 'legion'); },
  viseeDebut: (k) => { if (!joueur || joueur.mort || transition) return; visee = { k, s: joueur.sorts[k], dir: null, cible: null }; },
  viseeDir: (dx, dy) => { if (!visee) return; const d = DIR_DROITE.clone().multiplyScalar(dx).addScaledVector(DIR_HAUT, -dy); d.y = 0; if (d.lengthSq() < 1e-4) return; visee.dir = d.normalize(); visee.cible = cibleDansDirection(visee.dir, visee.s.portee); },
  viseeFin: (k, lancer) => { const v = visee; visee = null; cacherVisee(); if (!lancer) return; if (!v) { lancerSort(k); return; } viseeForcee = v.dir && (v.cible || !['reflet', 'pasOmbre', 'execution', 'charge'].includes(v.s.id)) ? { dir: v.dir, cible: v.cible, portee: v.s.portee } : null; if (v.cible) joueur.cible = v.cible; lancerSort(k); viseeForcee = null; },
  sylve: () => { const g = preparerGroupeSylve(); UI.rechercheGroupe(g, () => entrerSylve(g)); },
  modeleJoueur: () => (joueur && joueur.model) || null,
  code: (c) => utiliserCode(c),
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
      const ecart = data.ip - statsHeros(J.equip).ip;
      J.rushs = J.rushs || 0;
      if (ecart > 150 && J.rushs >= 3) { UI.toast(`${data.nom} a refusé l’invitation`); return; }
      if (Math.random() < (ecart > 150 ? 0.5 : 0.2)) { UI.toast(`${data.nom} a refusé l’invitation`); UI.chat(data.nom, ecart > 150 ? hasard(['t’es trop low dsl', 'reviens avec du T' + (Math.round((data.ip - 320) / 100) + 1), 'non merci', 'je groupe pas avec les débutants']) : hasard(['dsl je farm', 'pas maintenant', 'je vais déco bientôt', 'déjà en groupe', 'non']), 600); emoteBot(bots.find(b => b.nom === data.nom), ['bof', 'malin', 'oups'], 0.5); return; }
      groupe = data; selection = null; son('confirmation_001', 0.5);
      groupe.fort = ecart > 150; groupe.donjonsRestants = 1 + Math.floor(Math.random() * 3);
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
    if (graveuse && dist2D(joueur.pos, graveuse.pos) < 4.5) return UI.action('Graver des runes', () => UI.runes());
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
function ouvrirCoffre(c, auto = false) {
  if (c.final) return ouvrirCoffreFinal(c);
  c.ouvert = true; UI.action(null);
  son('creak1', 0.7); son(c.couleur === 'legendaire' ? 'jingle_legend' : 'jingle_loot', 0.55);
  const t0 = G.t;
  if (c.lid) ajouterVfx(new THREE.Group(), (t) => { c.lid.rotation.x = -Math.min(1, t / 0.6) * 1.9; if (t > 0.7) return false; });
  emettre(V(c.pos.x, 1.2, c.pos.z), { n: 90, c1: '#fff2c0', c2: c.def.color, vit: 7, vie: 1.2, taille: 0.45, grav: 4, monte: 4 });
  onde(c.pos, c.def.color, 5, 0.8);
  const loot = lootCoffre(c.couleur, modeActuel, c.mega ? 3 : c.boss.idx, rangK());
  if (MODES.includes(modeActuel) || modeActuel && modeActuel.sylve) loot.argent = Math.round(loot.argent * (1 + 0.25 * rangDe('donjon').i) * (1 + bonusParch('argent')));
  { const bd = bonusParch('drop'); if (bd > 0) { const extra = lootCoffre(c.couleur, modeActuel, c.boss.idx || 0).objets; for (const it of extra) if (Math.random() < bd * 1.6) loot.objets.push(it); if (extra.length && Math.random() < bd) loot.objets.push(extra[0]); } }
  if (c.mega) {
    loot.argent *= 8; const tm = modeActuel.tiers[1];
    loot.objets.push(...[0, 1, 2].map(() => Math.random() < 0.5 ? creerArme(hasard(['epee', 'arbalete', 'baton']), tm, 3 + (Math.random() < 0.4 ? 1 : 0)) : creerArmure(hasard(['casque', 'plastron', 'bottes']), tm, 3 + (Math.random() < 0.4 ? 1 : 0))), creerButin('rune', 12));
    const g0 = G.chanceOmbre; G.chanceOmbre = 0.05; tirageOmbre(tm, tm, 'boss'); G.chanceOmbre = g0;
  }
  if (J.accepteInvasion) loot.argent = Math.round(loot.argent * 1.25);
  loot.bonus = [];
  { const rk = (MODES.includes(modeActuel) || modeActuel && modeActuel.sylve) ? rangDe('donjon') : null; if (rk && rk.i) loot.bonus.push({ pct: 25 * rk.i, txt: 'rang ' + rk.r.nom, i: '♛', c: rk.r.c2 }); }
  { const bp = Math.round(bonusParch('argent') * 100); if (bp) loot.bonus.push({ pct: bp, txt: 'parchemin d’argent', i: '¤', c: '#e8902a' }); }
  if (J.accepteInvasion) loot.bonus.push({ pct: 25, txt: 'zone d’invasion', i: '⚔', c: '#c0281a' });
  if (coequipiers().length) { // en groupe, le coffre est partagé en deux
    const a = coequipiers()[0]; const moitie = Math.round(loot.argent / 2);
    loot.allie = { nom: a.nom, argent: loot.argent - moitie, objets: loot.objets.filter((_, i) => i % 2 === 1) };
    loot.argent = moitie; loot.objets = loot.objets.filter((_, i) => i % 2 === 0);
  }
  if (auto) { // l'escouade ramasse tout : butin ajouté directement et affiché à l'écran
    J.argent += loot.argent; for (const it of loot.objets) ajouterSac(it, true); son('handleCoins', 0.5); c.beam.visible = false; sauver();
    UI.butinFlash(c.couleur, loot); return;
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
  UI.butinPillage({ res, butin, ok, cible: cible ? cible.nom : null, reste, argent, proprio: bot.proprio.nom, ile: bot.nom });
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
  // tap sur la scène : choisir une cible ou interagir ; un tracé dessine un signe de sort
  initGestes($('#scene'), {
    actif: () => enJeu && joueur && !joueur.mort && !!modeActuel && G.gestes !== false,
    couleur: () => COUL_SIGNE[J.equip.arme ? J.equip.arme.type : 'epee'] || '#ffb347',
    tap: (e) => tapScene(e),
    rate: () => { UI.toast('Signe non reconnu'); son('error_001', 0.2); },
    lancer: (cle, debut, centre) => lancerParSigne(cle, debut, centre),
  });
  function tapScene(e) {
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
  }
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
  $('#btnEmote').onclick = (ev) => { ev.stopPropagation(); son('click_001', 0.4); UI.panneauEmotes(); };
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
  if (G.ralentiT > 0) { G.ralentiT -= dtReel; dt *= G.ralentiK; } // arrêt sur image / ralenti des gros coups
  const q = majQualiteAuto(dtReel, enJeu && !transition && !document.hidden && !modeActuel); // réglage auto seulement sur la Place : jamais de gel en plein combat
  if (q === 'baisse') UI.toast(G.niveau === 1 ? 'Qualité ajustée : lueurs coupées pour plus de fluidité' : 'Qualité ajustée : ombres coupées pour plus de fluidité');
  G.t += dt; G.dt = dt;
  for (const f of G.anims || []) f(G.t, dt);
  for (let i = minuteries.length - 1; i >= 0; i--) { const m = minuteries[i]; m.t -= dt; if (m.t <= 0) { minuteries.splice(i, 1); m.fn(); } }
  if (marchand) marchand.maj(dt);
  if (enJeu && joueur) {
    G.focus = joueur.pos;
    if (!transition) majJoueur(dt);
    for (const x of [joueur, ...allies]) { if (!x._pp) x._pp = x.pos.clone(); x.vel = x.vel || V(); x.vel.set((x.pos.x - x._pp.x) / Math.max(dt, 0.001), 0, (x.pos.z - x._pp.z) / Math.max(dt, 0.001)); x._pp.copy(x.pos); }
    if (!modeActuel) majBots(dt); else { majEnnemis(dt); majAllies(dt); majProjectiles(dt); majInvasion(dt); majArene(dt); }
    for (let i = dangers.length - 1; i >= 0; i--) { dangers[i].t -= dt; if (dangers[i].t <= 0) dangers.splice(i, 1); }
    if (modeActuel && modeActuel.sylve) { majSylve(dt); sylveMeterT = (sylveMeterT || 0) - dt; if (sylveMeterT <= 0) { sylveMeterT = 0.5; if (compteur) UI.majDegats(classement(compteur.total, 0, G.t - sylve.debut)); } }
    if (errant) majErrant(dt);
    if (modeActuel && modeActuel.id === 'ile') { majOuvriers(dt); majNoeuds(dt); majRecolteJoueur(dt); majPillard(dt); if (intendant) intendant.maj(dt); }
    if (passeur) passeur.maj(dt);
    if (graveuse) graveuse.maj(dt);
    ileT -= dt; if (ileT <= 0) { ileT = 3; majProduction(); majAssauts(); majRaids(); if (modeActuel && modeActuel.id === 'ile' && !monde.etranger && !(raid && raid.r)) journalIle(monde.ile); }
    majEscouade(dt);
    majCamera(dt, G.camCible || joueur.pos);
    majTorches(joueur.pos);
    if (joueur.comboT > 0) { joueur.comboT -= dt; if (joueur.comboT <= 0) joueur.combo = 0; }
    hudT -= dt; if (hudT <= 0) { hudT = 0.08; UI.majCombo(joueur.def.assassin ? joueur.combo || 0 : -1); UI.majHud(joueur, joueur.st); UI.majSorts(joueur); majInteractions(); majCadreAutre(); majBarreRival(); }
    miniT -= dt; if (miniT <= 0) { miniT = 0.2; majBoutonTP(); majMini(); majParchemins(0.2); majMusique(0.2); }
    UI.majPlaques(joueur.pos);
    // anneau de cible
    majAnneauCible(); majVisee();
    majPont(dt);
  } else if (monde) {
    // écran titre : la caméra tourne autour de la place
    G.camYaw = Math.PI / 4 + Math.sin(G.t * 0.1) * 0.5; ORBITE.set(Math.sin(G.t * 0.07) * 6, 0, 2);
    majCamera(dt, ORBITE); majTorches(ORBITE);
    majBots(dt);
    UI.majPlaques(ORBITE);
  }
  if (enJeu && !G.camLibre) G.camYaw = Math.PI / 4;
  majFeux(dt); majVfx(dt); majParticules(dt);
  const t1 = performance.now();
  rendre();
  const t2 = performance.now(), P = G.perf || (G.perf = { upd: 0, rend: 0, max: 0, pics: 0 });
  P.upd = P.upd * 0.95 + (t1 - now) * 0.05; P.rend = P.rend * 0.95 + (t2 - t1) * 0.05;
  if (t2 - now > 40) P.pics++; P.max = Math.max(P.max, t2 - now);
  if (G.perfOn) {
    P.n = (P.n || 0) + 1; P.acc = (P.acc || 0) + dtReel; P.pire = Math.max(P.pire || 0, dtReel);
    if (P.acc >= 0.5) { UI.majPerf(`${Math.round(P.n / P.acc)} fps · pire ${Math.round(P.pire * 1000)} ms · ${G.renderer.info.render.calls} appels · qualité ${['basse', 'moyenne', 'haute'][G.niveau]}`); P.n = 0; P.acc = 0; P.pire = 0; }
  }
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
  } else if (monde.type === 'sylve') {
    for (const e of ennemis) if (!e.mort && (e.boss || dist2D(e.pos, joueur.pos) < 60)) ents.push({ type: e.boss ? 'boss' : 'mob', x: e.pos.x, z: e.pos.z });
    for (const a of allies) if (!a.mort && !a.invoc) ents.push({ type: 'allie', x: a.pos.x, z: a.pos.z });
    for (const c of coffres) if (!c.ouvert) ents.push({ type: 'coffre', x: c.pos.x, z: c.pos.z, c: c.def.color });
    if (sortie) ents.push({ type: 'portailV', x: sortie.pos.x, z: sortie.pos.z });
    ents.centre = joueur.pos;
  } else if (monde.type === 'ile') {
    for (const e of ennemis) if (!e.mort) ents.push({ type: 'boss', x: e.pos.x, z: e.pos.z });
    for (const a of allies) if (!a.mort) ents.push({ type: 'allie', x: a.pos.x, z: a.pos.z });
    for (const o of ouvriers) ents.push({ type: 'joueur', x: o.pos.x, z: o.pos.z });
    if (intendant) ents.push({ type: 'pnj', x: intendant.pos.x, z: intendant.pos.z });
    ents.push({ type: 'coffre', x: monde.coffrePos.x, z: monde.coffrePos.z, c: '#ffd25a' });
    ents.push({ type: 'portailJ', x: monde.portail.pos.x, z: monde.portail.pos.z });
  } else {
    for (const e of ennemis) if (!e.mort) {
      if (e.rival && invasion && !(invasion.revele > 0) && dist2D(e.pos, joueur.pos) > 14) continue;
      if (e.boss && e.boss.errant && !(e.revele > 0) && e.etat === 'dormant') continue;
      ents.push({ type: e.rival ? 'envahisseur' : e.boss && e.boss.errant ? 'errant' : e.boss ? 'boss' : 'mob', x: e.pos.x, z: e.pos.z });
    }
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

// équipement minimal selon le rang d'arène (Diamant, Champion, Grand Champion = des joueurs vraiment équipés)
const EQUIP_RANG = { 3: { t: [4, 6], e: [0, 2], q: [1, 3] }, 4: { t: [5, 7], e: [1, 4], q: [1, 3] }, 5: { t: [7, 8], e: [3, 6], q: [2, 4] } };
function genererEquipRival(ipCible, type = null, rang = -1) {
  let tMoy = 1, ec = 1e9; for (let t = 1; t <= 8; t++) { const ipT = 300 + (t - 1) * 100 + 20 + 3 * (NIVEAU_REQUIS[t] + 6); const e2 = Math.abs(ipT - ipCible); if (e2 < ec) { ec = e2; tMoy = t; } }
  const R = EQUIP_RANG[rang];
  const t = () => { const v = Math.max(1, Math.min(8, tMoy + (Math.random() < 0.25 ? 1 : Math.random() < 0.3 ? -1 : 0))); return R ? Math.max(ri(R.t[0], R.t[1]), Math.min(R.t[1], v)) : v; };
  const q = () => R ? ri(R.q[0], R.q[1]) : (Math.random() < 0.45 ? 0 : 1 + Math.floor(Math.random() * 3));
  const e = (it) => { if (R) it.ench = ri(R.e[0], R.e[1]); return it; };
  type = type || ['epee', 'arbalete', 'baton'][Math.floor(Math.random() * 3)];
  return { arme: e(creerArme(type, t(), q())), casque: e(creerArmure('casque', t(), q())), plastron: e(creerArmure('plastron', t(), q())), bottes: e(creerArmure('bottes', t(), q())) };
}
// niveau d'un joueur-bot : au moins le niveau requis par son meilleur équipement, plus un peu d'avance (et beaucoup plus en haut du classement)
function nivBot(equip, bonus = 0) { const t = Math.max(...['arme', 'casque', 'plastron', 'bottes'].map(s => equip[s] ? equip[s].tier : 1)); return Math.max(1, Math.min(100, NIVEAU_REQUIS[t] + ri(0, 14) + bonus)); }
function donneesBot(ipCible, exclure = [], rang = -1) {
  const libres = BOTS.filter(b => !exclure.includes(b[0]) && b[0] !== J.nom && !(groupe && groupe.nom === b[0]));
  const [nom, tag, guilde] = hasard(libres.length ? libres : BOTS);
  const equip = genererEquipRival(ipCible, null, rang);
  const type = equip.arme.type;
  const niv = nivBot(equip, rang > 0 ? rang * 6 : 0);
  return { nom, guilde: (tag ? `[${tag}] ` : '') + guilde, equip, niv, ip: statsHeros(equip, niv).ip, modele: type === 'arbalete' && Math.random() < 0.5 ? 'Rogue' : ARMES[type].model };
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
  a.montrerSeul([def.node, def.node2].filter(Boolean), tous);
  a.teinter(def.node, TIERS[arme.tier].color, 0.62, TIERS[arme.tier].glow);
  if (def.node2) a.teinter(def.node2, TIERS[arme.tier].color, 0.62, TIERS[arme.tier].glow);
  const cape = Object.keys(a.nodes).find(n => n.endsWith('_Cape'));
  const corps = Object.keys(a.nodes).find(n => n.endsWith('_Body'));
  const casque = Object.keys(a.nodes).find(n => /_(Helmet|Hat)$/.test(n));
  if (casque && /Helmet/.test(casque) && a.nodes[casque]) a.nodes[casque].visible = false;
  if (equip.plastron && cape) a.teinter(cape, TIERS[equip.plastron.tier].color, 0.42, 0);
  if (def.ombre) habitOmbre(a, def);
}
// la classe des Ombres : capuche et tunique noires, liseré violet
function habitAssassin(a, def) {
  a.teinter(def.body, '#1a1418', 0.85, 0); a.teinter('Rogue_Head', '#f0d0c0', 0.1, 0);
  a.teinter(def.cape, '#b0101a', 0.85, 0.35); def.legs.forEach(l => a.teinter(l, '#201a20', 0.8, 0));
}
function habitOmbre(a, def) {
  a.teinter(def.body, '#2a1a40', 0.85, 0.25);
  a.teinter('Rogue_Head_Hooded', '#5a2aa0', 0.85, 0.5);
  a.teinter(def.cape, '#5a1ad0', 0.75, 0.35);
  def.legs.forEach(l => a.teinter(l, '#1c1428', 0.75, 0));
}
function creerCombattant(pos, data, camp = 'ennemi') {
  const equip = data.equip, arme = equip.arme, def = ARMES[arme.type];
  const a = new Acteur(data.modele || def.model, { hauteur: 2.0 });
  habiller(a, equip, def);
  if (!data.niv) data.niv = nivBot(equip);
  const st = statsHeros(equip, data.niv);
  a.root.position.copy(pos); G.scene.add(a.root);
  Object.assign(a, {
    combattant: true, rival: camp === 'ennemi', camp, nom: data.nom, guilde: data.guilde, ip: data.ip || st.ip, data,
    armeDef: def, equip, st, def: { nom: data.nom, model: def.model },
    pos: a.root.position, pv: Math.round(st.pvMax * kpv(camp)), pvMax: Math.round(st.pvMax * kpv(camp)), reduction: st.reduction, dmg: st.degats * 1.05 * kdg(camp),
    etat: 'chasse', atkT: 1.2, attaqueT: 1.2, stunT: 0, slowT: 0, dots: [], pack: -9, angle: 0, mort: false, hauteurPlaque: 2.55, rayon: 0.55, hover: 0,
    specT: rnd(3, 5), potions: 2, potionT: 0, esquiveT: 2, dashT: 0, strafe: Math.random() < 0.5 ? 1 : -1, chatT: rnd(10, 18), tc: null,
    argent: Math.round(rnd(0.7, 1.4) * 60 * Math.pow(2.3, arme.tier - 1)),
  });
  a.jouer('Cheer', { boucle: false, fin: () => a.jouer(def.idle) });
  UI.plaque(a, { nom: data.nom, guilde: data.guilde, classe: camp === 'ennemi' ? 'rival' : 'allie', ip: a.ip, niv: data.niv, vie: true });
  if (camp === 'ennemi') { a.skill = data.skill ?? rnd(0.35, 0.8); a.specFacteur = 0.7 + a.skill * 0.6; }
  if (camp === 'ennemi') ennemis.push(a); else allies.push(a);
  return a;
}

// ---- camps, cibles et dégâts ----
function coequipiers() { return allies.filter(a => !a.garde && !a.invoc); }
function equipeJoueur() { const l = []; if (!joueur.mort && !(joueur.furtifT > 0)) l.push(joueur); for (const a of allies) if (!a.mort) l.push(a); return l; }
function adversaires(e) { return e.camp === 'allie' ? vivants() : equipeJoueur(); }
function cibleIA(e) {
  let liste;
  if (e.poste && e.camp === 'allie') liste = vivants().filter(x => dist2D(x.pos, e.poste) < 24);
  else if (e.poste) liste = equipeJoueur().filter(x => dist2D(x.pos, e.poste) < 20);
  else if (e.camp === 'allie' && e.membreSylve) liste = vivants().filter(x => x.etat !== 'dormant' && (x.etat === 'chasse' ? dist2D(x.pos, e.pos) < 20 : dist2D(x.pos, e.pos) < 11));
  else if (e.camp === 'allie') liste = arene ? vivants() : e.autonome ? vivants().filter(x => x.etat !== 'dormant' && (dist2D(x.pos, e.pos) < 12 || (dist2D(x.pos, joueur.pos) < 15 && x.etat !== 'idle')) && (!x.boss || dist2D(x.pos, joueur.pos) < 22)) : vivants().filter(x => x.etat !== 'dormant' && dist2D(x.pos, joueur.pos) < 15 && (x.etat !== 'idle' || dist2D(x.pos, e.pos) < 8));
  else liste = equipeJoueur();
  if (!liste.length) return null;
  if (!e.combattant && !e.rival && liste.length > 1) { e.aggroT = (e.aggroT || 0) - 0.1; if (e.aggroT <= 0 || !e.tc || e.tc.mort || !liste.includes(e.tc)) { e.aggroT = rnd(4, 8); const proches = liste.filter(c => dist2D(c.pos, e.pos) < 12); if (proches.length) return hasard(proches); } }
  let p = null, pd = Infinity;
  for (const c of liste) { const d = dist2D(c.pos, e.pos); if (d < pd) { pd = d; p = c; } }
  // on garde sa cible, sauf si une autre est nettement plus proche
  if (e.tc && !e.tc.mort && liste.includes(e.tc) && dist2D(e.tc.pos, e.pos) < pd + 4) return e.tc;
  return p;
}
let auteurCoup = null;
function infliger(src, c, d, opts = {}) {
  if (!c || c.mort) return;
  if (c.camp !== 'allie' && c !== joueur) { auteurCoup = src; blesser(c, 0, { fixe: d, stun: opts.stun, slow: opts.slow, c1: '#ffd0a0' }); auteurCoup = null; return; }
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
  d = d * (1 - a.reduction) * rnd(0.92, 1.08) * (a.invoc ? 1 : 1.3);
  a.coupT = 5;
  if (a.bouclierIA > 0) { const b = Math.min(a.bouclierIA, d); a.bouclierIA -= b; d -= b; if (d <= 0) return; }
  a.pv -= d; a.frapper();
  UI.nombre(V(a.pos.x, 2.2, a.pos.z), Math.round(d), 'allie');
  if (opts.slow) a.slowT = Math.max(a.slowT, opts.slow);
  if (opts.stun) a.stunT = Math.max(a.stunT, opts.stun * 0.5);
  if (a.pv > 0) return;
  a.pv = 0; a.mort = true;
  if (a.invoc) { mortInvocation(a); return; }
  a.jouer('Death_A', { boucle: false });
  UI.toast(`${a.nom} est tombé`);
  setTimeout(() => UI.chat(a.nom, hasard(['désolé…', 'je suis mort', 'ils frappent fort', 'vas-y finis-les'])), 700);
  if (arene) return verifierArene();
  if (a.garde) return;
  // en donjon, le coéquipier se relève au bout de 15 s près du joueur
  programmer(15, () => {
    if (!allies.includes(a) || joueur.mort) return;
    a.mort = false; a.pv = a.pvMax * 0.5; if (!a.membreSylve) a.pos.copy(pointLibrePres(joueur.pos, 1.5, 3)); a.jouer(a.armeDef.idle);
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
  const def = e.armeDef, type = e.equip.arme.type, melee = !ARMES[type].projectile;
  if (arene && arene.t > 0) { e.jouer(def.idle); faceJoueur(e, dt, 4); return; }
  e.tc = cibleIA(e);
  if (e.camp === 'ennemi' && e.skill > 0.6) { e.focusT = (e.focusT || 0) - dt; if (e.focusT <= 0) { e.focusT = 1.5; const l = adversaires(e).filter(x => dist2D(x.pos, e.pos) < 14); if (l.length > 1) e.focus = l.reduce((a, b) => (a.pv / a.pvMax < b.pv / b.pvMax ? a : b)); else e.focus = null; } if (e.focus && !e.focus.mort) e.tc = e.focus; }
  if (e.camp === 'ennemi' && e.skill !== undefined && e.tc && esquiveExperte(e, dt, melee)) return;
  if (e.potionT > 0) { e.potionT -= dt; e.pv = Math.min(e.pvMax, e.pv + e.pvMax * 0.4 * dt); if (Math.random() < 0.4) emettre(V(e.pos.x, 0.5, e.pos.z), { n: 1, c1: '#ff8a9a', c2: '#ff2a4a', dir: V(0, 1, 0), vit: 2, rayon: 0.6, vie: 0.6, taille: 0.3 }); }
  e.potionCd = (e.potionCd || 0) - dt; e.cdRempart = (e.cdRempart || 0) - dt;
  if (e.bouclierT > 0) { e.bouclierT -= dt; if (e.bouclierT <= 0) e.bouclierIA = 0; }
  e.pvT = (e.pvT || 0) - dt; if (e.pvT <= 0) { e.pvT = 2; e.pvRef = e.pv; }
  if (e.pv < e.pvMax * 0.35 && e.potions > 0 && e.potionT <= 0 && e.potionCd <= 0) { e.potions--; e.potionT = 1; e.potionCd = 60; son('metalLatch', 0.4, 1.4); UI.nombre(V(e.pos.x, 2.6, e.pos.z), 'Potion', 'soin'); }
  // bulle de protection : sous la pression (gros dégâts récents ou vie basse)
  if (e.tc && !e.invoc && e.cdRempart <= 0 && (e.pv < e.pvMax * 0.55 || (e.pvRef || e.pv) - e.pv > e.pvMax * 0.18)) rempartIA(e);
  if (e.dashT > 0) { e.dashT -= dt; deplacer(e, e.dashV.x * dt, e.dashV.z * dt, 0.5); return; }
  if (e.autonome && e.perso === 'traitre' && !e.trahi && joueur.pv < joueur.st.pvMax * 0.35 && dist2D(e.pos, joueur.pos) < 10 && Math.random() < dt * 0.25) { e.trahi = true; trahir(e); }
  if (e.camp === 'allie' && dangers.length) { const z = dangerSur(e.pos); if (z && reagit(e, z, dt)) { const dir = V(e.pos.x - z.p.x, 0, e.pos.z - z.p.z); if (dir.lengthSq() < 0.01) dir.set(Math.random() - 0.5, 0, Math.random() - 0.5); dir.normalize(); avancerVers(e, V(z.p.x + dir.x * (z.r + 2), 0, z.p.z + dir.z * (z.r + 2)), dt, e.st.vitesse * 1.1); e.jouer(def.run); return; } }
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
      if (e.invoc) { // les invocations collent au joueur, même quand il court ou sprinte
        if (dj > 16) { fumeeOmbre(e.pos); e.pos.copy(pointLibrePres(joueur.pos, 1.5, 3)); fumeeOmbre(e.pos); }
        else if (dj > 2.8) { avancerVers(e, joueur.pos, dt, Math.max(e.st.vitesse, vitesseJoueur()) * (dj > 6 ? 1.3 : 1.05)); e.jouer(def.run); }
        else e.jouer(def.idle);
      } else if (e.membreSylve) { autonomieSylve(e, dt); }
      else if (e.autonome && autonomieAllie(e, dt, dj)) { /* il fait sa vie */ }
      else if (dj > (e.autonome ? 7 : 3.5)) { if (e.ox === undefined) { e.ox = rnd(-3, 3); e.oz = rnd(-3, 3); } allerVers(e, e.autonome ? V(joueur.pos.x + e.ox, 0, joueur.pos.z + e.oz) : joueur.pos, dt, e.st.vitesse * (dj > 12 ? 1.1 : 0.85)); e.jouer(def.run); }
      else e.jouer(def.idle);
      if (dj > 34 && !arene && !e.autonome) { e.pos.copy(pointLibrePres(joueur.pos, 1.5, 3)); onde(e.pos, '#4fd1ff', 2.5, 0.5); }
    } else e.jouer(def.idle);
    return;
  }
  const d = dist2D(e.pos, c.pos);
  if (e.camp === 'ennemi') { e.chatT -= dt; if (e.chatT <= 0 && d < 20) { e.chatT = rnd(16, 28); UI.chat(e.nom, hasard(RIVAL_COMBAT)); } }
  e.esquiveT -= dt; e.specT -= dt * (e.specFacteur || 1);
  if (e.specT <= 0 && d < 14) { capaciteCombattant(e, type); e.specT = rnd(4.5, 7.5); e.repliPossible = true; return; }
  if (e.repliPossible && e.attaqueT <= 0) {
    e.repliPossible = false;
    if (!e.invoc && e.specT > 2.5 && e.pv < e.pvMax * (melee ? 0.6 : 0.85) && Math.random() < 0.6) { e.repliT = Math.min(e.specT - 1, rnd(2, 3.5)); if (e.camp === 'ennemi') emoteBot(e, ['fuite', 'oups', 'ouin'], 0.35); return; }
  }
  const portee = melee ? def.portee + (c.rayon || 0.5) : 9.5;
  // un bon joueur au corps à corps zigzague en approchant un tireur ; un bon tireur garde sa distance
  if (e.skill > 0.55 && melee && d > portee && d < 12 && c.armeDef && c.armeDef.projectile) { const p = V(-(c.pos.z - e.pos.z), 0, c.pos.x - e.pos.x).normalize().multiplyScalar(Math.sin(G.t * 3.2 + (e.zz || (e.zz = rnd(0.1, 6)))) * 2.4 * e.skill); allerVers(e, c.pos.clone().add(p), dt, e.st.vitesse * 0.95); e.jouer(def.run); return; }
  if (e.skill > 0.5 && !melee && d < 6.5 && d > 2 && e.atkT > 0.25) { const ar = V(e.pos.x - c.pos.x, 0, e.pos.z - c.pos.z).normalize(); allerVers(e, V(e.pos.x + ar.x * 4, 0, e.pos.z + ar.z * 4), dt, e.st.vitesse * 0.95); e.jouer(def.run); return; } // il se retourne et court, puis refait face pour tirer
  if (d > portee) { allerVers(e, c.pos, dt, (e.invoc ? Math.max(e.st.vitesse, vitesseJoueur()) : e.st.vitesse) * (e.slowT > 0 ? 0.6 : 0.92)); e.jouer(def.run); return; }
  // un tireur garde ses distances
  if (!melee && d < 4.5 && e.esquiveT <= 0) {
    const arr = V(e.pos.x - c.pos.x, 0, e.pos.z - c.pos.z).normalize();
    e.dashT = 0.35; e.dashV = arr.multiplyScalar(18); e.esquiveT = rnd(4, 6);
    if (e.camp === 'ennemi') emoteBot(e, ['malin', 'bof', 'mdr'], 0.3, 0.2);
    e.jouer('Dodge_Backward', { boucle: false, forcer: true, vitesse: 1.5, fin: () => e.jouer(def.idle) });
    emettre(V(e.pos.x, 0.3, e.pos.z), { n: 12, c1: '#d0f0ff', c2: '#6aa0c0', vit: 3, vie: 0.4, taille: 0.35 });
    return;
  }
  faceJoueur(e, dt, 12);
  if (!melee) {
    // repositionnement : de temps en temps il court quelques pas sur le côté (en regardant où il va), puis se remet face à sa cible
    e.repoT = (e.repoT ?? rnd(1.5, 3)) - dt;
    if (e.repoT <= 0 && e.atkT > 0.3) {
      if (!e.repoDir) { const p = V(c.pos.z - e.pos.z, 0, -(c.pos.x - e.pos.x)).normalize().multiplyScalar(e.strafe * 3.5); e.repoDir = V(e.pos.x + p.x, 0, e.pos.z + p.z); e.repoFin = 0.7; e.strafe *= Math.random() < 0.5 ? -1 : 1; }
      e.repoFin -= dt; allerVers(e, e.repoDir, dt, e.st.vitesse * 0.9); e.jouer(def.run);
      if (e.repoFin <= 0) { e.repoDir = null; e.repoT = rnd(1.8, 3.5); }
      return;
    }
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
  if (e.camp === 'ennemi') emoteBot(e, ['feu', 'diable', 'toi'], 0.12, 0.4);
  if (type === 'ombre') { // surgit dans le dos de sa cible
    e.attaqueT = 0.7;
    const derriere = V(pj.x + Math.sin(base) * 1.4, 0, pj.z + Math.cos(base) * 1.4);
    fumeeOmbre(e.pos); e.pos.copy(derriere); e.angle = base + Math.PI; e.root.rotation.y = e.angle; fumeeOmbre(e.pos);
    e.jouer('1H_Melee_Attack_Chop', { boucle: false, forcer: true, vitesse: 1.6, fin: () => e.jouer(def.idle) });
    programmer(0.2, () => { if (e.mort || c.mort) return; arcTaille(e.pos, e.angle - Math.PI / 2, 2.6, '#9a5aff', Math.PI * 0.7, 0.25); infliger(e, c, e.dmg * 2, { stun: 0.5 }); son('knifeSlice2', 0.4, 0.8); });
    return;
  }
  if (type === 'epee') {
    if (Math.random() < 0.5) { // charge héroïque
      e.attaqueT = 1.1; const dir = V(Math.sin(base), 0, Math.cos(base)); const dist = Math.max(2, Math.min(9, dist2D(e.pos, pj) - 1));
      teleC(e, e.pos, dist, 0.55, coul, () => {
        if (e.mort) return; e.jouer('Dodge_Forward', { boucle: false, forcer: true, vitesse: 1.6 });
        e.dashT = 0.25; e.dashV = dir.clone().multiplyScalar(dist / 0.25);
        programmer(0.27, () => { if (e.mort) return; e.jouer('2H_Melee_Attack_Chop', { boucle: false, forcer: true, vitesse: 1.6, fin: () => e.jouer(def.idle) }); onde(e.pos, '#ffd36b', 4, 0.45); toucherZone(e, e.pos, 3.4, e.dmg * 2.2, { stun: 0.8 }); });
      }, { ligne: true, largeur: 2.4, angle: base + Math.PI });
    } else { // fente
      e.attaqueT = 1.0;
      teleC(e, e.pos, 4.8, 0.65, coul, () => {
        if (e.mort) return; e.jouer('2H_Melee_Attack_Slice', { boucle: false, forcer: true, vitesse: 1.5, fin: () => e.jouer(def.idle) });
        arcTaille(e.pos, e.angle - Math.PI / 2, 4.6, '#ff3a2a', Math.PI * 0.8, 0.3);
        toucherZone(e, e.pos, 4.8, e.dmg * 2.3, { cone: { dir: V(Math.sin(base), 0, Math.cos(base)), cos: Math.cos(0.7) } });
      }, { cone: 1.4, angle: base - Math.PI / 2 });
    }
  } else if (type === 'arbalete') {
    if (Math.random() < 0.5) { // carreau perforant
      e.attaqueT = 0.9;
      teleC(e, e.pos, 16, 0.6, coul, () => { if (e.mort) return; e.jouer('2H_Ranged_Shoot', { boucle: false, forcer: true, fin: () => e.jouer(def.idle) }); tirEnnemi(e, 'carreau', e.dmg * 2.4, V(Math.sin(base), 0, Math.cos(base)), 34); }, { ligne: true, largeur: 1.4, angle: base + Math.PI });
    } else { // pluie
      e.attaqueT = 0.6; e.jouer('2H_Ranged_Shoot', { boucle: false, forcer: true, fin: () => e.jouer(def.idle) });
      for (let w = 0; w < 3; w++) teleC(e, pj, 4.2, 0.9 + w * 0.45, coul, () => { emettre(V(pj.x, 0.3, pj.z), { n: 20, c1: '#bfffd8', c2: '#3a9a6a', rayon: 3.8, vit: 2, vie: 0.4, taille: 0.3, hemi: true }); son('impactGeneric_light_000', 0.3, 1.3); toucherZone(e, pj, 4.2, e.dmg * 1.1, { slow: 2 }); });
    }
  } else {
    if (Math.random() < 0.7) { // colonne de flammes
      e.attaqueT = 0.7; e.jouer('Spellcast_Raise', { boucle: false, forcer: true, fin: () => e.jouer(def.idle) });
      teleC(e, pj, 3.5, 0.9, coul, () => { emettre(V(pj.x, 0.3, pj.z), { n: 60, c1: '#ffe08a', c2: '#ff2a00', dir: V(0, 1, 0), vit: 14, disp: 2.5, rayon: 1.8, vie: 0.8, taille: 0.7, frein: 2 }); son('explosionCrunch_000', 0.5, 0.8); if (c === joueur) G.shake = 0.4; toucherZone(e, pj, 3.5, e.dmg * 2.8); });
    } else { // météore
      e.attaqueT = 1.3; e.jouer('Spellcast_Long', { boucle: false, forcer: true, fin: () => e.jouer(def.idle) });
      teleC(e, pj, 6, 1.6, coul, () => { G.shake = 0.8; onde(pj, '#ffd27a', 9, 0.7); emettre(V(pj.x, 0.5, pj.z), { n: 140, c1: '#fff0b0', c2: '#ff2a00', vit: 14, vie: 1.0, taille: 0.9, grav: 4, hemi: true }); son('lowFrequency_explosion_000', 0.8); toucherZone(e, pj, 6, e.dmg * 4.2); });
    }
  }
}
function majAllies(dt) {
  for (let i = allies.length - 1; i >= 0; i--) {
    const a = allies[i];
    if (a.vieT !== undefined && !a.mort) { a.vieT -= dt; if (a.vieT <= 0) { dissiper(a); continue; } if (a.vieT < 3 && Math.random() < dt * 8) emettre(V(a.pos.x, 1, a.pos.z), { n: 1, c1: '#c9a0ff', c2: '#1a0630', dir: V(0, 1, 0), vit: 1.5, rayon: 0.5, vie: 0.6, taille: 0.35 }); }
    if (a.mort) { a.maj(dt); continue; }
    a.coupT = (a.coupT || 0) - dt;
    if (!a.invoc && a.coupT <= 0 && a.pv < a.pvMax) a.pv = Math.min(a.pvMax, a.pv + a.pvMax * (a.coupT < -4 ? 0.06 : 0.012) * dt);
    if (a.stunT > 0) { a.stunT -= dt; a.maj(dt * 0.15); continue; }
    if (a.refletMob) { majRefletMob(a, dt); a.maj(dt); continue; }
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
// une seule barre de vie en haut : boss réveillé ou joueur adverse, choisie une fois par tick (avant, deux codes se la disputaient → clignotement)
let barreSuivie = null;
function majBarreRival() {
  const valide = (e) => e && !e.mort && ennemis.includes(e) && ((e.boss && e.etat !== 'idle' && e.etat !== 'dormant' && dist2D(e.pos, joueur.pos) < 30) || (e.rival && (arene || dist2D(e.pos, joueur.pos) < 22)));
  if (valide(joueur.cible) && joueur.cible !== barreSuivie) barreSuivie = joueur.cible;
  if (!valide(barreSuivie)) {
    barreSuivie = null; let bd = Infinity;
    for (const e of ennemis) if (valide(e)) { const d = dist2D(e.pos, joueur.pos) - (e.boss ? 6 : 0); if (d < bd) { bd = d; barreSuivie = e; } }
  }
  if (!barreSuivie) return UI.boss(null);
  const e = barreSuivie;
  UI.boss({ nom: e.rival ? `${e.nom} · ⚔ ${e.ip}` : (e.boss && e.boss.nom) || e.nom || e.def.nom, pv: e.pv, pvMax: e.pvMax });
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
      UI.enFile(() => {
      document.querySelectorAll('.niveauUp').forEach(x => x.remove()); // un seul bandeau à la fois
      const d = document.createElement('div'); d.className = 'niveauUp';
      d.innerHTML = `<div class="titreNiv">Niveau supérieur</div><div class="lignesNiv">${[...a.lignes.values()].map(l => `<span>${l}</span>`).join('')}</div>${[...a.paliers.values()].map(p => `<div class="palierNiv">${p}</div>`).join('')}`;
      $('#jeu').appendChild(d); return d; }, a.paliers.size ? 3.2 : 2.4, 'niveau');
      onde(joueur.pos, '#8fd0ff', 4, 0.8); emettre(V(joueur.pos.x, 0.4, joueur.pos.z), { n: 50, c1: '#ffffff', c2: '#3a7aff', dir: V(0, 1, 0), vit: 6, disp: 1.5, rayon: 1, vie: 1, taille: 0.4 });
      son('confirmation_001', 0.5);
    }, 60);
  }
  (palier ? annonces.paliers : annonces.lignes).set(cle, txt); // la dernière valeur remplace les précédentes
}
function typesPortes() { return [...new Set(['arme', 'casque', 'plastron', 'bottes'].map(s => J.equip[s] && J.equip[s].type).filter(Boolean))]; }
let xpSession = {};
function noterXP(t, x) { xpSession[t] = (xpSession[t] || 0) + x; }
function journalXP(source, x) { J.xpLog = [{ s: source, x, t: Date.now() }, ...(J.xpLog || [])].slice(0, 10); }
function montrerXP(source) {
  const lignes = Object.entries(xpSession).filter(([, x]) => x > 0).map(([t, x]) => { const mm = J.maitrise[t]; const need = xpPour(mm.niv); return { type: t, nom: MAITRISES.find(z => z.id === t).nom, niv: mm.niv, k: mm.niv >= 100 ? 1 : mm.xp / need, gain: x, reste: need - mm.xp }; });
  xpSession = {};
  if (lignes.length) { UI.jaugeXP(lignes, source); journalXP(source, lignes.reduce((a, l) => a + l.gain, 0)); }
}
function gagnerXP(base) {
  if (!base) return;
  base = Math.round(base * (1 + bonusParch('xp')));
  if (J.escouade) statsEscouade().xp += base;
  for (const t of typesPortes()) noterXP(t, base);
  let monte = false;
  for (const t of typesPortes()) monte = gainXP(t, base) || monte;
  UI.nombre(V(joueur.pos.x, 2.9, joueur.pos.z), `+${fmtN(base)} XP`, 'xp');
  if (monte) { recalculer(); $('#ipHud').textContent = `Niv. ${niveauHeros(J.equip)} · ⚔ ${joueur.st.ip}`; }
  sauver();
}
function gagnerXPRelatif(frac) {
  frac *= 1 + bonusParch('xp');
  let total = 0;
  for (const t of typesPortes()) { const m = J.maitrise[t]; const x = Math.round(xpPour(m.niv) * frac); total += x; gainXP(t, x); noterXP(t, x); }
  recalculer(); sauver();
  return total;
}

// ---------------- Arène ----------------
function entrerArene(format, opts = {}) {
  if (!opts.duel) memoriserMode(`Arène ${format}${opts.letale ? ' létale' : ''}`, () => entrerArene(format, { letale: opts.letale }));
  else G.dernier = null;
  fondu(() => {
    viderMonde(); invasion = null; selection = null;
    modeActuel = { id: 'arene', nom: 'Arène', lieu: 'Arène des Échos', argent: 0, xp: 0, tiers: [1, 1], mobTier: 1 };
    monde = construireArene();
    construireJoueur(monde.spawn.clone());
    joueur.pv = joueur.st.pvMax; joueur.energie = joueur.st.energieMax; joueur.cds = {};
    joueur.angle = Math.PI / 2; joueur.root.rotation.y = joueur.angle;
    G.camTarget.copy(joueur.pos); G.scene.fog.density = 0.012; G.hemi.intensity = 1.0; G.sun.intensity = 1.1;
    const ipJ = statsHeros(J.equip).ip;
    arene = { format, duel: opts.duel || null, mise: opts.mise || 0, letale: !!opts.letale, fini: false, t: 3.6, dernier: 4 };
    const pris = [];
    if (format === '2v2') { const m = groupe || donneesBot(ipJ + rnd(-40, 40), [], rangDe('arene').i); pris.push(m.nom); const a = creerCombattant(monde.spawnAllie.clone(), m, 'allie'); a.angle = Math.PI / 2; a.root.rotation.y = a.angle; }
    const n = format === '2v2' ? 2 : 1;
    for (let i = 0; i < n; i++) {
      const rgA = rangDe('arene').i;
      const d = i === 0 && opts.duel ? opts.duel : donneesBot(ipJ + rnd(-50, 80) + 35 * rgA, pris, rgA); pris.push(d.nom);
      d.skill = Math.max([0.35, 0.4, 0.5, 0.7, 0.85, 0.93][rgA] || 0.35, Math.min(0.98, 0.06 * rgA + 0.5 + Math.min(0.35, (J.trophees || 0) / 3000) + rnd(-0.15, 0.2) + (format === '2v2' ? 0.08 : 0)));
      const r = creerCombattant(monde.spawnsRivaux[i].clone(), d, 'ennemi');
      r.angle = -Math.PI / 2; r.root.rotation.y = r.angle; r.potions = 1;
    }
    for (const e of ennemis) emoteBot(e, ['salut', 'diable', 'toi', 'malin'], 0.6, rnd(1.5, 3.5));
    const rivaux = ennemis.map(e => `${e.nom} (⚔ ${e.ip} · ${e.skill >= 0.75 ? 'Expert' : e.skill >= 0.55 ? 'Confirmé' : 'Débutant'})`).join(' et ');
    UI.journal('Arène des Échos', `${format === '2v2' ? 'Équipe adverse' : 'Adversaire'} : ${rivaux}`, null);
    UI.zone(opts.letale ? 'Arène létale' : 'Arène des Échos', opts.duel ? `Duel · mise ${fmtN(opts.mise)}` : (format === '2v2' ? '2 contre 2' : '1 contre 1') + (opts.letale ? ' · stuff en jeu' : ''));
    if (opts.letale) { setTimeout(() => UI.toast('ARÈNE LÉTALE : le perdant repart à poil', true), 700); G.hemi.color.set('#ff6a6a'); }
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
  if (victoire && !arene.duel) { const t = J.equip.arme ? J.equip.arme.tier : 1; tirageOmbre(Math.max(1, t - 1), Math.min(8, t + 1), 'pvp'); }
  const lignes = [];
  if (arene.duel) {
    if (victoire) { J.argent += arene.mise * 2; lignes.push(arene.mise ? `+ ${fmtN(arene.mise * 2)} d’argent (mises remportées)` : 'Duel amical remporté'); }
    else lignes.push(arene.mise ? `Mise perdue : ${fmtN(arene.mise)}` : 'Duel amical perdu');
  } else if (victoire) { const tr = Math.round((arene.letale ? 200 : 100) * (1 + 0.25 * rangDe('arene').i)); J.trophees = (J.trophees || 0) + tr; lignes.push(`🏆 +${tr} trophées (total ${fmtN(J.trophees)})`);
    const gainA = Math.round((arene.letale ? 120000 : 40000) * (1 + 0.5 * rangDe('arene').i) * (arene.format === '1v1' ? 1 : 1.3)); J.argent += gainA; lignes.push(`+ ${fmtN(gainA)} d’argent`); }
  else lignes.push('Aucun trophée cette fois');
  if (arene.letale && !victoire) {
    const perdus = ['arme', 'casque', 'plastron', 'bottes'].map(s => J.equip[s]).filter(Boolean);
    const type = J.equip.arme ? J.equip.arme.type : 'epee';
    J.equip = { arme: creerArme(type === 'ombre' ? 'epee' : type, 1, 0), casque: null, plastron: null, bottes: null };
    lignes.push(`Arène létale : tu perds tout ton équipement porté (${perdus.map(it => nomObjet(it)).join(', ') || 'rien'}). Il te reste ton argent et ton sac.`);
  }
  if (arene.letale && victoire) lignes.push('Arène létale : fouille la dépouille des perdants avant de partir.');
  if (!arene.duel) changerRang('arene', victoire ? GAIN_RANG * (arene.letale ? 1.5 : 1) : -PERTE_RANG, victoire ? 'Victoire en arène' : 'Défaite en arène');
  const xp = gagnerXPRelatif(victoire ? (arene.duel ? 0.05 : 0.12) : 0.03);
  setTimeout(() => montrerXP(victoire ? 'Victoire en arène' : 'Combat d’arène'), 400);
  lignes.push(`+ ${fmtN(xp)} XP de maîtrise sur ton équipement porté`);
  son(victoire ? 'jingle_win' : 'lowFrequency_explosion_000', 0.6, victoire ? 1 : 0.6);
  if (victoire) for (const a of [joueur, ...allies]) if (a.mort) programmer(1.2, () => {
    a.mort = false; a.pv = (a === joueur ? a.st.pvMax : a.pvMax) * 0.3; a.jouer(a === joueur ? a.def.idle : a.armeDef.idle);
    onde(a.pos, '#ffd27a', 4, 0.8); emettre(V(a.pos.x, 1, a.pos.z), { n: 60, c1: '#fff2c0', c2: '#ffd27a', vit: 4, vie: 1.1, taille: 0.45, monte: 4 }); son('confirmation_001', 0.5, 0.8);
    UI.toast(a === joueur ? 'Ton équipe a gagné : tu te relèves' : `${a.nom} se relève`);
  });
  if (victoire && !joueur.mort) joueur.jouer('Cheer', { boucle: false });
  for (const a of allies) if (!a.mort && victoire) a.jouer('Cheer', { boucle: false });
  for (const e of ennemis) if (!e.mort) { e.jouer('Cheer', { boucle: false }); UI.chat(e.nom, hasard(RIVAL_GAGNE)); emoteBot(e, ['ez', 'mdr', 'clown', 'bof'], 1, 0.4); }
  if (victoire) { const r = ennemis.find(e => e.rival); if (r) { setTimeout(() => UI.chat(r.nom, hasard(RIVAL_PERD)), 800); emoteBot(r, ['gg', 'ouin', 'rage'], 0.8, 1.2); } for (const a of allies) if (!a.mort && !a.invoc) emoteBot(a, ['gg', 'feu', 'ez'], 0.7, 1.6); }
  sauver();
  const finir = () => UI.resultatArene({ victoire, lignes, refaire: G.dernier ? G.dernier.nom : null }, (refaire) => { if (refaire && G.dernier) G.dernier.fn(); else fondu(() => lancerHub()); });
  if (arene.letale && victoire) {
    const morts = ennemis.filter(e => e.rival);
    const suivant = (i) => { if (i >= morts.length) return finir(); const r = morts[i]; UI.depouille(r.nom, r.ip, Object.values(r.equip).filter(Boolean), r.argent, (pris) => { J.argent += r.argent; for (const it of pris) ajouterSac(it, true); son('handleCoins', 0.6); sauver(); suivant(i + 1); }); };
    setTimeout(() => suivant(0), 2600);
  } else setTimeout(finir, 2200);
}

// ---------------- Invasions ----------------
function effetArrivee(pos) {
  onde(pos, '#ff2a2a', 5, 0.8); onde(pos, '#ffb08a', 3, 0.6); lueurSol(pos, '#ff1a1a', 3, 1.4, 1);
  emettre(V(pos.x, 0.3, pos.z), { n: 80, c1: '#ff8a6a', c2: '#8a0000', dir: V(0, 1, 0), vit: 9, disp: 2, rayon: 1, vie: 1.2, taille: 0.6, frein: 1.5 });
  son('lowFrequency_explosion_000', 0.8, 0.8); son('forceField_000', 0.6, 0.6); G.shake = 0.6;
}
function majInvasion(dt) {
  if (invasion && invasion.rivaux && rivauxVivants().length) {
    // positions révélées brièvement toutes les ~14 s
    invasion.revealT -= dt; if (invasion.revele > 0) invasion.revele -= dt;
    if (invasion.revealT <= 0) { invasion.revealT = rnd(12, 16); invasion.revele = 2.6; son('forceField_000', 0.35, 1.8); UI.ping(); }
  }
  if (!invasion || invasion.rival || joueur.mort || transition) return;
  invasion.t -= dt; if (invasion.t > 0) return;
  lancerInvasion();
}
function lancerInvasion() {
  const ipJ = statsHeros(J.equip).ip;
  const n = coequipiers().length ? 2 : 1; const pris = [];
  const rk = rangDe('donjon').i;
  const datas = Array.from({ length: n }, () => { const d = donneesBot(ipJ + Math.round(rnd(-50, 90)) + 30 * rk, pris); d.skill = Math.min(0.97, (d.skill || 0.55) + 0.05 * rk); pris.push(d.nom); return d; });
  const salles = monde.salles.filter(s => s.type === 'normale');
  invasion.rivaux = [];
  if (invasion.mode === 'subie') {
    // ils arrivent loin de toi et te cherchent ; toi aussi tu les cherches
    const s = [...salles].sort((a, b) => dist2D(b.centre, joueur.pos) - dist2D(a.centre, joueur.pos))[Math.floor(Math.random() * 2)] || salles[0];
    for (const d of datas) { const pos = pointLibrePres(s.centre, 0, 4); effetArrivee(pos); const r = creerCombattant(pos, d, 'ennemi'); r.chasseur = true; invasion.rivaux.push(r); }
    invasion.rival = invasion.rivaux[0];
    alerteInvasion(n, true);
    setTimeout(() => invasion && invasion.rivaux.forEach((r, i) => !r.mort && setTimeout(() => UI.chat(r.nom, hasard(RIVAL_ARRIVEE)), i * 1400)), 1800);
    UI.journal('Invasion !', `${n === 2 ? `${datas[0].nom} et ${datas[1].nom} sont venus` : `${datas[0].nom} est venu`} te dépouiller. Trouve-${n === 2 ? 'les' : 'le'} avant qu’${n === 2 ? 'ils' : 'il'} te trouve${n === 2 ? 'nt' : ''}.`, null);
  } else {
    const s = [...salles].sort((a, b) => dist2D(b.centre, joueur.pos) - dist2D(a.centre, joueur.pos))[Math.floor(Math.random() * 3)] || salles[0];
    for (const d of datas) { const r = creerCombattant(pointLibrePres(s.centre, 0, 4), d, 'ennemi'); r.attaqueT = 0; r.jouer(r.armeDef.idle); invasion.rivaux.push(r); }
    invasion.rival = invasion.rivaux[0];
    alerteInvasion(n, false);
    UI.journal('Invasion', `Traque ${datas.map(d => d.nom).join(' et ')} et prends-leur tout. Leur position apparaît par moments sur la carte.`, null);
    setTimeout(() => invasion && invasion.rivaux.forEach(r => !r.mort && UI.chat(r.nom, hasard(['?? un envahisseur', 'sérieux pas maintenant', 'viens alors', 'oh non']))), 6000);
  }
  invasion.revealT = 4; invasion.revele = 0;
}
function victoireRival(e) {
  UI.boss(null); G.shake = 0.8;
  tirageOmbre(Math.max(1, e.equip.arme.tier - 1), e.equip.arme.tier, 'pvp');
  son('jingle_win', 0.6);
  UI.toast(`${e.nom} est vaincu !`, true);
  setTimeout(() => UI.chat(e.nom, hasard(RIVAL_PERD)), 900);
  emoteBot(e, ['rage', 'ouin', 'gg', 'rip'], 0.75, 0.5);
  onde(e.pos, '#ff3a2a', 8, 1); emettre(V(e.pos.x, 1.5, e.pos.z), { n: 90, c1: '#ffd27a', c2: '#ff2a2a', vit: 8, vie: 1.2, taille: 0.45, grav: 3 });
  const pos = pointLibrePres(e.pos, 0.5, 1.5);
  const obj = cloner('chest_gold', pos.x, 0, pos.z, Math.PI / 4, 1.5);
  obj.traverse(o => { if (o.isMesh) { o.material = o.material.clone(); o.material.color = new THREE.Color('#ffffff').lerp(new THREE.Color('#ff3a3a'), 0.45); o.material.emissive = new THREE.Color('#ff1a1a'); o.material.emissiveIntensity = 0.35; o.castShadow = true; } });
  G.scene.add(obj);
  const beam = faisceau(V(pos.x, 0, pos.z), '#ff2a3a', 16, 0.9); G.scene.add(beam);
  coffres.push({ obj, beam, couleur: 'rival', def: { color: '#ff2a3a', nom: 'Dépouille' }, boss: { mort: true }, pos, ouvert: false, lid: obj.getObjectByName('chest_lid'), depouille: true, rival: e });
  UI.journal(e.pillard ? 'Pillard éliminé' : invasion && invasion.mode === 'menee' ? 'Invasion réussie' : 'Invasion repoussée', `Fouille la dépouille de ${e.nom} : choisis ce que tu gardes.`, null);
  if (e.pillard) { raid = null; UI.boss(null); }
  gagnerXPRelatif(0.1); setTimeout(() => montrerXP('Joueur vaincu'), 1500);
  if (invasion && !rivauxVivants().length) invasion.fini = true;
  setTimeout(() => { e.descendre = true; }, 3500);
  sauver();
}
function ouvrirDepouille(c, auto = false) {
  c.ouvert = true; UI.action(null);
  son('creak1', 0.7); son('jingle_legend', 0.5);
  if (c.lid) ajouterVfx(new THREE.Group(), (t) => { c.lid.rotation.x = -Math.min(1, t / 0.6) * 1.9; if (t > 0.7) return false; });
  emettre(V(c.pos.x, 1.2, c.pos.z), { n: 90, c1: '#ffe0c0', c2: '#ff2a3a', vit: 7, vie: 1.2, taille: 0.45, grav: 4, monte: 4 });
  const r = c.rival; const objets = Object.values(r.equip).filter(Boolean);
  if (auto) { J.argent += r.argent; for (const it of objets) ajouterSac(it, true); c.beam.visible = false; sauver(); UI.butinFlash('legendaire', { argent: r.argent, objets }); return; }
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



// ---------------- Émoticônes ----------------
let emoteHubT = 6, emoteJoueurT = 0;
const REPONSES = { salut: ['salut', 'merci'], gg: ['gg', 'merci'], mdr: ['mdr', 'clown'], ez: ['rage', 'toi', 'clown', 'mdr'], clown: ['clown', 'rage', 'mdr'], rip: ['mdr', 'ouin'],
  rage: ['mdr', 'clown', 'bof'], ouin: ['mdr', 'rip'], toi: ['diable', 'toi', 'malin'], bof: ['bof', 'malin'], feu: ['feu', 'mdr'], merci: ['merci', 'salut'],
  diable: ['diable', 'fuite', 'ez'], fuite: ['mdr', 'clown'], malin: ['malin', 'toi'], oups: ['mdr', 'oups'] };
function emoteBot(e, ids, chance = 1, delai = 0) {
  if (!e || Math.random() > chance) return;
  const go = () => { if (!e.mort || ids.includes('rip') || ids.includes('ouin') || ids.includes('rage')) UI.emote(e, hasard(ids), e.nom); };
  if (delai > 0) setTimeout(go, delai * 1000); else go();
}
function emoteJoueur(id) {
  if (!joueur || performance.now() < emoteJoueurT) return;
  emoteJoueurT = performance.now() + 1500;
  UI.emote(joueur, id, J.nom); son('select_001', 0.3, 1.3);
  const rep = REPONSES[id] || ['mdr'];
  // les autres « joueurs » réagissent
  const cands = !modeActuel ? bots.filter(b => !(b.absentT > 0) && dist2D(b.pos, joueur.pos) < 14) : [...ennemis.filter(e => e.combattant && !e.mort), ...allies.filter(a => !a.mort && !a.invoc && a.combattant)];
  cands.sort((a, b) => dist2D(a.pos, joueur.pos) - dist2D(b.pos, joueur.pos));
  cands.slice(0, 2).forEach((c, i) => emoteBot(c, rep, i ? 0.25 : (modeActuel ? 0.45 : 0.6), rnd(0.8, 1.9) + i));
}





// ---------------- Réflexes humains : on esquive… pas toujours ----------------
function reagit(e, z, dt) {
  if (e.invoc) return true;
  if (e.dangerVu !== z) { e.dangerVu = z; e.reflexeOK = Math.random() < (e.reflexe || (e.reflexe = rnd(0.55, 0.85))); e.reactionT = rnd(0.15, 0.55); }
  if (!e.reflexeOK) return false;
  e.reactionT -= dt; return e.reactionT <= 0;
}
// ---------------- Au Sanctuaire, chaque joueur du groupe joue sa partie ----------------
let objectifSylve = null, objectifSylveT = 0;
function majObjectifSylve(dt) {
  objectifSylveT -= dt; if (objectifSylveT > 0) return objectifSylve; objectifSylveT = 0.8;
  let best = null, bs = Infinity;
  for (const x of ennemis) { if (x.mort || x.invoque) continue; const s = monde.abscisse(x.pos.x, x.pos.z); if (s < bs) { bs = s; best = x; } }
  objectifSylve = best ? { e: best, s: bs, boss: !!best.boss } : null;
  return objectifSylve;
}
function esquiveExperte(e, dt, melee) {
  if (e.esquiveT > 0 || e.dashT > 0 || e.stunT > 0) return false;
  for (const p of projectiles) {
    if (p.camp === 'ennemi') continue;
    const rx = e.pos.x - p.pos.x, rz = e.pos.z - p.pos.z; const v = Math.hypot(p.vel.x, p.vel.z) || 1; const vx = p.vel.x / v, vz = p.vel.z / v;
    const along = rx * vx + rz * vz; if (along < 0 || along > 8) continue;
    const perp = rx * vz - rz * vx; if (Math.abs(perp) > 1.6) continue;
    if (!p.vus) p.vus = new Set(); if (p.vus.has(e)) continue; p.vus.add(e);
    if (Math.random() > e.skill * 0.8) continue;
    const s = perp >= 0 ? 1 : -1; return pasDeCote(e, vz * s, -vx * s, false);
  }
  if (joueur.debutAtk && G.t - joueur.debutAtk < 0.18 && dist2D(joueur.pos, e.pos) < 3.8 && e.dernierAtkVu !== joueur.debutAtk) {
    e.dernierAtkVu = joueur.debutAtk;
    if (Math.random() < e.skill * 0.45) { const ar = V(e.pos.x - joueur.pos.x, 0, e.pos.z - joueur.pos.z).normalize(); return pasDeCote(e, ar.x, ar.z, true); }
  }
  return false;
}
function pasDeCote(e, dx, dz, arriere) {
  e.dashT = 0.26; e.dashV = V(dx, 0, dz).multiplyScalar(16); e.esquiveT = rnd(1.6, 3) * (1.7 - e.skill);
  e.jouer(arriere ? 'Dodge_Backward' : 'Dodge_Forward', { boucle: false, forcer: true, vitesse: 1.6, fin: () => e.jouer(e.armeDef.idle) });
  if (!arriere) { e.angle = Math.atan2(dx, dz); e.root.rotation.y = e.angle; }
  emettre(V(e.pos.x, 0.3, e.pos.z), { n: 10, c1: '#d0f0ff', c2: '#6aa0c0', vit: 3, vie: 0.4, taille: 0.35 });
  if (Math.random() < 0.15) emoteBot(e, ['malin', 'bof', 'mdr'], 1, 0.3);
  return true;
}
function choisirProie(e, filtre) {
  // un vrai joueur ne va pas taper le même monstre que toi : il part de son côté
  let best = null, bs = Infinity;
  for (const x of ennemis) {
    if (x.mort || x.etat === 'dormant' || x.rival || !filtre(x)) continue;
    let s = dist2D(x.pos, e.pos);
    if (dist2D(x.pos, joueur.pos) < 9) s += 14;
    s += 8 * allies.filter(a => a !== e && a.proie === x).length;
    if (s < bs) { bs = s; best = x; }
  }
  return best;
}
const PAROLES = {
  bavard: ['vous avez vu le patch ?', 'qqn a drop un truc ?', 'j’ai faim', 'ce donjon est trop beau', 'mon chat marche sur le clavier', 'on fait l’arène après ?', 'gg les gars', 'quelqu’un a un T5 à vendre ?'],
  toxique: ['ez', 'vous êtes nuls', 'je carry', 'même pas mal', 'lol', 'vous suivez ou quoi', 'trop lent'],
  tranquille: ['brb 2 min', 'je reviens', 'attendez-moi', 'doucement'],
  protecteur: ['je te couvre', 'reste derrière moi', 'je prends le gros'],
  prudent: ['attention aux zones', 'on y va doucement', 'je reste derrière'],
  fonceur: ['go go go', 'on pull', 'plus vite'],
};
function appliquerTrait(a, t) { const T = TRAITS[t] || TRAITS.bavard; a.trait = t; a.reflexe = T.reflexe; a.vitTrait = T.vit; a.parlerT = rnd(8, 20); a.chaosT = rnd(3, 6); a.afkT = rnd(40, 80); }
function traitVivant(e, dt) {
  // ce qui donne sa personnalité au joueur, quel que soit le donjon
  e.parlerT -= dt;
  if (e.parlerT <= 0) { const t = e.trait; e.parlerT = t === 'bavard' ? rnd(10, 20) : t === 'toxique' ? rnd(12, 22) : rnd(35, 70); if (PAROLES[t] && Math.random() < 0.7) UI.chat(e.nom, hasard(PAROLES[t])); else emoteBot(e, t === 'toxique' ? ['clown', 'ez', 'mdr', 'toi'] : ['feu', 'salut', 'malin', 'bof'], 1); }
  if (e.trait === 'toxique') {
    e.chaosT -= dt;
    if (e.chaosT <= 0) { e.chaosT = rnd(3, 7); const a = rnd(0, 6.28); e.dashT = 0.3; e.dashV = V(Math.sin(a), 0, Math.cos(a)).multiplyScalar(15); e.jouer('Dodge_Forward', { boucle: false, forcer: true, vitesse: 1.5, fin: () => e.jouer(e.armeDef.idle) }); if (Math.random() < 0.4) emoteBot(e, ['clown', 'mdr', 'ez'], 1); return true; }
    if (Math.random() < dt * 0.25) { e.tourneT = rnd(1.5, 3); }
    if (e.tourneT > 0) { e.tourneT -= dt; const a = G.t * 3; allerVers(e, V(e.pos.x + Math.sin(a) * 3, 0, e.pos.z + Math.cos(a) * 3), dt, e.st.vitesse); e.jouer(e.armeDef.run); return true; }
  }
  if (e.trait === 'tranquille') {
    e.afkT -= dt;
    if (e.afkT <= 0 && !e.afk) { e.afk = rnd(6, 11); UI.chat(e.nom, hasard(['brb', 'afk 1 min', 'je reviens'])); }
    if (e.afk > 0) { e.afk -= dt; e.jouer('Sit_Floor_Idle' in e.actions ? 'Sit_Floor_Idle' : e.armeDef.idle); if (e.afk <= 0) { e.afk = 0; e.afkT = rnd(50, 90); UI.chat(e.nom, hasard(['re', 'je suis là', 'dsl'])); } return true; }
  }
  return false;
}
function allerLooter(e, dt) {
  const c = e.lootCible; if (!c) return false;
  if (c.lootePar && c.lootePar.has(e)) { e.lootCible = null; return false; }
  if (dist2D(e.pos, c.pos) > 2.4) { allerVers(e, c.pos, dt, e.st.vitesse); e.jouer(e.armeDef.run); return true; }
  if (!e.fouilleT) { e.fouilleT = 1.6; e.jouer('Interact' in e.actions ? 'Interact' : 'PickUp', { boucle: false, forcer: true }); son('creak1', 0.35, 1.2); }
  e.fouilleT -= dt;
  if (e.fouilleT <= 0) {
    e.fouilleT = 0; (c.lootePar = c.lootePar || new Set()).add(e); e.lootCible = null;
    emettre(V(c.pos.x, 1.2, c.pos.z), { n: 30, c1: '#fff2c0', c2: c.def.color, vit: 4, vie: 0.8, taille: 0.35, monte: 3 });
    UI.toast(`${e.nom} a récupéré sa part du ${c.def.nom.toLowerCase()}`);
    if (Math.random() < 0.5) UI.chat(e.nom, hasard(['loot !', 'merci le boss', 'pas ouf', 'ENFIN un drop', 'encore des os…', 'bof']));
    else emoteBot(e, ['feu', 'malin', 'merci', 'bof'], 1);
    e.jouer(e.armeDef.idle);
  }
  return true;
}
function autonomieSylve(e, dt) {
  if (allerLooter(e, dt)) return;
  if (e.decal === undefined) Object.assign(e, { decal: rnd(-3.2, 3.2), attenteT: 0, proieT: 0 });
  if (traitVivant(e, dt)) return;
  const T = TRAITS[e.trait] || TRAITS.bavard;
  const se = monde.abscisse(e.pos.x, e.pos.z);
  const k = monde.salles.findIndex((s, i) => ennemis.some(b => b.boss && b.idxSylve === i && !b.mort && b.etat === 'dormant'));
  const limite = k >= 0 ? monde.salleS[k] - monde.salles[k].r - 3 : monde.longueur;
  e.proieT -= dt;
  if (e.proieT <= 0 || !e.proie || e.proie.mort) {
    e.proieT = rnd(1.5, 3);
    if (e.trait === 'protecteur') { const l = ennemis.filter(x => !x.mort && x.etat === 'chasse' && x.tc === joueur); e.proie = l.length ? l[0] : choisirProie(e, x => dist2D(x.pos, joueur.pos) < 18 && (!x.boss || x.etat === 'chasse')); }
    else e.proie = choisirProie(e, x => { const s = monde.abscisse(x.pos.x, x.pos.z); return s > se - 12 && s < Math.min(limite + 6, se + (e.trait === 'tranquille' ? 30 : 70)) && (!x.boss || x.etat === 'chasse'); });
  }
  const vit = e.st.vitesse * (e.vitTrait || 1);
  if (e.proie) { allerVers(e, e.proie.pos, dt, vit); e.jouer(e.armeDef.run); e.attenteT = 0; return; }
  const sj = monde.abscisse(joueur.pos.x, joueur.pos.z);
  let s = e.trait === 'protecteur' ? sj - 3 : Math.min(limite + (e.trait === 'fonceur' ? 1 : -2), Math.max(se, sj) + 10 + T.avance);
  if (e.trait === 'tranquille') s = Math.min(s, se + 6);
  const c = monde.pointA(s); const dest = V(c.p.x - c.dir.z * e.decal, 0, c.p.z + c.dir.x * e.decal);
  if (dist2D(e.pos, dest) > 1.8) { allerVers(e, dest, dt, vit * 0.9); e.jouer(e.armeDef.run); return; }
  e.jouer(e.armeDef.idle);
  if (k >= 0 && s >= limite - 3) {
    e.attenteT += dt;
    if (e.trait === 'fonceur' && e.attenteT > 20) {
      if (!e.annonce) { e.annonce = true; UI.chat(e.nom, hasard(['on pull ?', 'je lance le boss', 'go go go', 'bon j’y vais'])); emoteBot(e, ['diable', 'feu'], 0.6); }
      const b = ennemis.find(x => x.boss && x.idxSylve === k && !x.mort); if (b && e.attenteT > 24) { allerVers(e, b.pos, dt, vit); e.jouer(e.armeDef.run); }
    } else if (e.attenteT > 12 && !e.relance && dist2D(joueur.pos, e.pos) > 25) { e.relance = true; UI.chat(e.nom, hasard([`${J.nom} tu viens ?`, 'on attend qui là', 'afk ?'])); }
  } else { e.attenteT = 0; e.annonce = false; e.relance = false; }
}

// ---------------- Visée des sorts (doigt appuyé) ----------------
let visee = null, viseeForcee = null, viseeObj = null;
function cibleDansDirection(dir, portee) {
  let best = null, bs = Infinity;
  for (const e of vivants()) {
    const dx = e.pos.x - joueur.pos.x, dz = e.pos.z - joueur.pos.z, d = Math.hypot(dx, dz);
    if (d > portee + 2 + (e.rayon || 0) || d < 0.3) continue;
    const cos = (dx * dir.x + dz * dir.z) / d; if (cos < 0.8) continue;
    const score = (1 - cos) * 30 + d * 0.15; if (score < bs) { bs = score; best = e; }
  }
  return best;
}
function majVisee() {
  if (!visee) return;
  if (!viseeObj) {
    const g = new THREE.Group();
    const mat = new THREE.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.22, blending: THREE.AdditiveBlending, depthWrite: false });
    const cercle = new THREE.Mesh(new THREE.RingGeometry(0.965, 1, 96), mat); cercle.rotation.x = -Math.PI / 2;
    const fond = new THREE.Mesh(new THREE.CircleGeometry(1, 64), new THREE.MeshBasicMaterial({ color: '#bfe0ff', transparent: true, opacity: 0.05, blending: THREE.AdditiveBlending, depthWrite: false })); fond.rotation.x = -Math.PI / 2;
    const fleche = new THREE.Mesh(new THREE.PlaneGeometry(0.5, 1).translate(0, 0.5, 0), new THREE.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.35, blending: THREE.AdditiveBlending, depthWrite: false })); fleche.rotation.x = -Math.PI / 2;
    const marque = new THREE.Mesh(new THREE.RingGeometry(0.8, 1.05, 40), new THREE.MeshBasicMaterial({ color: '#ffd27a', transparent: true, opacity: 0.85, blending: THREE.AdditiveBlending, depthWrite: false })); marque.rotation.x = -Math.PI / 2;
    g.add(fond, cercle); G.scene.add(g, fleche, marque);
    viseeObj = { g, fleche, marque };
  }
  const { g, fleche, marque } = viseeObj; const p = visee.s.portee;
  g.visible = true; g.position.set(joueur.pos.x, 0.1, joueur.pos.z); g.scale.set(p, 1, p);
  fleche.visible = !!visee.dir;
  if (visee.dir) {
    const cible = visee.cible; const l = cible ? Math.min(p, dist2D(cible.pos, joueur.pos)) : p;
    const ang = cible ? Math.atan2(cible.pos.x - joueur.pos.x, cible.pos.z - joueur.pos.z) : Math.atan2(visee.dir.x, visee.dir.z);
    fleche.position.set(joueur.pos.x, 0.12, joueur.pos.z); fleche.scale.set(1, l, 1); fleche.rotation.z = ang + Math.PI;
  }
  marque.visible = !!visee.cible;
  if (visee.cible) { const c = visee.cible; const r = (c.rayon || 0.5) + 0.6; marque.position.set(c.pos.x, 0.13, c.pos.z); marque.scale.set(r, r, 1); marque.rotation.z = G.t * 2; }
}
function cacherVisee() { if (viseeObj) { viseeObj.g.visible = false; viseeObj.fleche.visible = false; viseeObj.marque.visible = false; } }

// ---------------- Chemins dans le donjon (grille) ----------------
function cheminGrille(a, b) {
  const W = monde.grilleW, H = monde.grilleH, g = monde.grille, C = 4;
  const ax = Math.floor(a.x / C), az = Math.floor(a.z / C), bx = Math.floor(b.x / C), bz = Math.floor(b.z / C);
  if (bx < 0 || bz < 0 || bx >= W || bz >= H || !g[bz * W + bx]) return null;
  if (!cheminGrille.prec || cheminGrille.prec.length !== W * H) { cheminGrille.prec = new Int32Array(W * H); cheminGrille.file = new Int32Array(W * H); }
  if (ax < 0 || az < 0 || ax >= W || az >= H) return null;
  const prec = cheminGrille.prec, file = cheminGrille.file; prec.fill(-1);
  let n = 0; file[n++] = az * W + ax; prec[az * W + ax] = az * W + ax;
  const but = bz * W + bx; let i = 0;
  while (i < n) {
    const c = file[i++]; if (c === but) break;
    const cx = c % W, cz = (c / W) | 0;
    for (const [dx, dz] of [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]) {
      const nx = cx + dx, nz = cz + dz; if (nx < 0 || nz < 0 || nx >= W || nz >= H) continue;
      const k = nz * W + nx; if (prec[k] >= 0 || !g[k]) continue;
      if (dx && dz && (!g[cz * W + nx] || !g[nz * W + cx])) continue;
      prec[k] = c; file[n++] = k;
    }
  }
  if (prec[but] < 0) return null;
  const pts = []; for (let c = but; c !== prec[c]; c = prec[c]) pts.push(V((c % W) * C + C / 2, 0, ((c / W) | 0) * C + C / 2));
  return pts.reverse();
}
// va vers une destination en contournant les murs du donjon
function ligneLibre(a, b) {
  const d = dist2D(a, b), n = Math.ceil(d / 1.5);
  for (let i = 1; i < n; i++) { const t = i / n; if (!libre(a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t, 0.45)) return false; }
  return true;
}
function allerVers(e, dest, dt, vitesse) {
  if (monde.type === 'sylve') {
    e._lv = e._lv || { t: 0, ok: true };
    e._lv.t -= dt; if (e._lv.t <= 0) { e._lv.t = 0.4; e._lv.ok = dist2D(e.pos, dest) < 3 || ligneLibre(e.pos, dest); }
    if (e._lv.ok) { avancerVers(e, dest, dt, vitesse); return; }
    const se = monde.abscisse(e.pos.x, e.pos.z), sd = monde.abscisse(dest.x, dest.z);
    const w = monde.pointA(se + Math.sign(sd - se) * Math.min(5, Math.abs(sd - se)));
    avancerVers(e, w.p, dt, vitesse); return;
  }
  if (!monde.grille || dist2D(e.pos, dest) < 7 && (e !== joueur || ligneLibre(e.pos, dest))) { avancerVers(e, dest, dt, vitesse); return; }
  const ch = e.chemin;
  if (!ch || ch.t <= 0 || dist2D(ch.dest, dest) > 4) { e.chemin = { pts: cheminGrille(e.pos, dest) || [], i: 0, dest: dest.clone(), t: 1.5 }; }
  e.chemin.t -= dt;
  const pts = e.chemin.pts; while (e.chemin.i < pts.length && dist2D(pts[e.chemin.i], e.pos) < 1.6) e.chemin.i++;
  avancerVers(e, e.chemin.i < pts.length ? pts[e.chemin.i] : dest, dt, vitesse);
}
// ---------------- Le coéquipier fait sa vie ----------------
const PHRASES_EXPLO = ['je vais clean à côté', 'je prends la salle là-bas', 'rejoins-moi', 'je check à gauche', 'y a du monde par ici', 'suis-moi'];
function autonomieAllie(e, dt, dj) {
  if (allerLooter(e, dt)) return true;
  if (traitVivant(e, dt)) return true;
  e.modeT -= dt;
  if (e.modeT <= 0) {
    e.modeT = rnd(18, 34);
    const avant = e.modeA; e.modeA = e.trait === 'protecteur' ? 'suivre' : Math.random() < (e.trait === 'tranquille' ? 0.4 : 0.75) ? 'explorer' : 'suivre';
    if (e.modeA !== avant) { if (e.modeA === 'explorer') { UI.chat(e.nom, hasard(PHRASES_EXPLO)); emoteBot(e, ['toi', 'feu', 'malin'], 0.3); } else if (dj > 15) UI.chat(e.nom, hasard(['j’arrive', 'attends-moi', 'je reviens vers toi'])); }
  }
  if (e.modeA !== 'explorer') return false;
  if (!e.objectif || e.objectif.mort || e.objectif.etat === 'chasse' && dist2D(e.objectif.pos, e.pos) > 30) {
    e.objectif = choisirProie(e, x => !x.boss);
  }
  if (!e.objectif) { e.modeA = 'suivre'; return false; }
  allerVers(e, e.objectif.pos, dt, e.st.vitesse * 0.95 * (e.vitTrait || 1)); e.jouer(e.armeDef.run);
  return true;
}
function reactionApresBoss(a) {
  if (a.perso === 'solo' && !a.parti && Math.random() < 0.7) { a.parti = true; setTimeout(() => partirAllie(a), rnd(2500, 5000)); return; }
  if (a.perso === 'traitre' && !a.trahi && bossVaincus >= 1 && Math.random() < 0.65) { a.trahi = true; setTimeout(() => trahir(a), rnd(4000, 9000)); return; }
  emoteBot(a, ['gg', 'feu', 'merci', 'ez'], 0.6, 1);
}
function partirAllie(a) {
  if (a.mort || !allies.includes(a)) return;
  emoteBot(a, ['gg', 'merci', 'salut'], 1);
  UI.chat(a.nom, hasard(['bon je dois y aller, gg', 'gg je déco', 'je rentre, bonne chance', 'j’ai ce qu’il me faut, bye', 'ma mère m’appelle dsl']));
  setTimeout(() => {
    if (!allies.includes(a)) return;
    effetArrivee(a.pos.clone()); fumeeOmbre(a.pos);
    allies.splice(allies.indexOf(a), 1); UI.retirerPlaque(a); G.scene.remove(a.root);
    if (groupe && groupe.nom === a.nom) groupe = null;
    UI.toast(`${a.nom} a quitté le donjon et ton groupe`);
  }, 2200);
}
function trahir(a) {
  if (a.mort || !allies.includes(a) || joueur.mort || !modeActuel || modeActuel.sylve) return;
  UI.chat(a.nom, hasard(['dsl, rien de perso', 'ton stuff me plaît trop', 'gg… pour moi', 'merci pour le carry 😈', 'surprise']));
  emoteBot(a, ['diable', 'toi', 'malin'], 1);
  setTimeout(() => {
    if (a.mort || !allies.includes(a)) return;
    allies.splice(allies.indexOf(a), 1); ennemis.push(a);
    Object.assign(a, { camp: 'ennemi', rival: true, autonome: false, potions: 2, tc: joueur, specT: 1, chasseur: true });
    UI.retirerPlaque(a); UI.plaque(a, { nom: a.nom, guilde: a.guilde, classe: 'rival', ip: a.ip, niv: a.data && a.data.niv, vie: true });
    if (groupe && groupe.nom === a.nom) groupe = null;
    invasion = invasion && !invasion.fini ? invasion : { mode: 'subie', t: 0, rival: null, rivaux: [] };
    invasion.rivaux = [...(invasion.rivaux || []), a]; invasion.rival = invasion.rival && !invasion.rival.mort ? invasion.rival : a; invasion.revealT = 10; invasion.revele = 0;
    UI.flashInvasion(); son('lowFrequency_explosion_000', 0.8, 0.7); G.shake = 0.6;
    UI.toast('TRAHISON !', true); UI.toast(`${a.nom} se retourne contre toi : s’il te tue, il prend tout ton équipement`);
    UI.journal('Trahison !', `${a.nom} veut ton équipement. Tue-le ou perds tout.`, null);
  }, 1600);
}
function rivauxVivants() { return invasion && invasion.rivaux ? invasion.rivaux.filter(r => !r.mort) : invasion && invasion.rival && !invasion.rival.mort ? [invasion.rival] : []; }
function alerteInvasion(n, subie) {
  UI.alerteInvasion(n, subie);
  son('lowFrequency_explosion_000', 0.9, 0.55); G.shake = 0.7;
  // la lumière du donjon vire au rouge quelques secondes
  const h0 = G.hemi.color.clone(), s0 = G.sun.color.clone();
  ajouterVfx(new THREE.Group(), (t) => { const k = Math.max(0, Math.sin(Math.min(1, t / 3) * Math.PI)); G.hemi.color.copy(h0).lerp(new THREE.Color('#ff1a1a'), k * 0.85); G.sun.color.copy(s0).lerp(new THREE.Color('#ff3a2a'), k * 0.8); if (t > 3) { G.hemi.color.copy(h0); G.sun.color.copy(s0); return false; } });
}

// =================== Sanctuaire d'Émeraude : donjon de groupe à 5 ===================
let sylveMeterT = 0;
let sylve = null, compteur = null, dangers = [], zonesSol = [], orbes = [], rayons = [];
const MOBS_PACKS = [['moussu', 'moussu', 'ronce'], ['moussu', 'ecorce', 'ronce', 'druide'], ['ecorce', 'ronce', 'druide', 'moussu'], ['ecorce', 'ecorce', 'druide', 'ronce']];
function tierJoueur() { return Math.max(1, Math.min(8, Math.round((statsHeros(J.equip).ip - 320) / 100) + 1)); }
function modeSylve() {
  const t = tierJoueur();
  const argent = t <= 2 ? 1.6 : t <= 5 ? 12 : 58, xp = t <= 2 ? 1.4 : t <= 5 ? 6 : 16;
  return { id: 'sylve', sylve: true, nom: 'Groupe de 5', lieu: 'Sanctuaire d’Émeraude', argent, xp, tiers: [t, Math.min(8, t + 1)], mobTier: t + 0.4, bossTier: [t + 0.7, t + 0.9, t + 1.1, t + 1.4], couleur: '#3affa0', tier: t };
}
// le groupe : un épéiste, un arbalétrier, un mage, et un 4e au hasard (plus l'ami du joueur s'il en a un)
function preparerGroupeSylve() {
  const ip = statsHeros(J.equip).ip; const pris = [];
  const types = ['epee', 'arbalete', 'baton', hasard(['epee', 'arbalete', 'baton'])];
  return types.map((type, i) => {
    if (i === 0 && groupe) { pris.push(groupe.nom); groupe.trait = groupe.trait || hasard(Object.keys(TRAITS)); return groupe; }
    const d = donneesBot(ip + rnd(-50, 60), pris); pris.push(d.nom);
    d.equip = genererEquipRival(ip + rnd(-50, 60), type); d.niv = nivBot(d.equip); d.ip = statsHeros(d.equip, d.niv).ip; d.modele = type === 'arbalete' && Math.random() < 0.5 ? 'Rogue' : ARMES[type].model;
    d.trait = hasard(Object.keys(TRAITS).filter(t => !pris.includes('trait:' + t))); pris.push('trait:' + d.trait);
    return d;
  });
}
let assetsSylvePrets = false;
async function entrerSylve(membres = null) {
  memoriserMode('Sanctuaire d’Émeraude', () => entrerSylve());
  membres = membres || preparerGroupeSylve();
  if (!assetsSylvePrets) {
    UI.toast('Ouverture du Sanctuaire…');
    await chargerAssets(ASSETS_SYLVE.map(k => [k, `assets/sylve/${k}.json`]), () => {});
    assetsSylvePrets = true;
  }
  fondu(() => {
    viderMonde();
    modeActuel = modeSylve(); bossVaincus = 0; invasion = null;
    monde = construireSylve();
    G.scene.background.set('#4a7a6a'); G.scene.fog.color.set('#3f6a5a'); G.scene.fog.density = 0.014;
    G.hemi.color.set('#d8ffe8'); G.hemi.groundColor.set('#2a4a22'); G.hemi.intensity = 1.25; G.sun.intensity = 1.55; G.sun.color.set('#fff0c8');
    construireJoueur(monde.spawn.clone());
    joueur.pv = joueur.st.pvMax; joueur.energie = joueur.st.energieMax;
    G.camTarget.copy(joueur.pos);
    for (const d of membres) { const a = creerCombattant(pointLibrePres(monde.spawn, 1.5, 3.5), d, 'allie'); a.membreSylve = true; appliquerTrait(a, d.trait || 'bavard'); }
    monde.packs.forEach((pk, i) => { const types = MOBS_PACKS[pk.troncon]; pk.pts.forEach((p, k) => { const e = creerEnnemi(MOBS_SYLVE[types[k % types.length]], p, modeActuel.mobTier, 100 + i); e.angle = Math.atan2(-pk.dir.x, -pk.dir.z); e.root.rotation.y = e.angle; }); });
    monde.salles.forEach((s, k) => { const b = creerBoss(BOSS_SYLVE[k], s.c.clone(), modeActuel.bossTier[k], { id: 'S' + s.id }); b.pvMax = b.pv = Math.round(b.pvMax * 1.0); b.idxSylve = k; });
    creerSortie(monde.sortie);
    sylve = { debut: G.t, segDebut: G.t, butinJoueur: { argent: 0, objets: [] } };
    compteur = { total: new Map(), seg: new Map(), noms: [J.nom, ...allies.filter(a => a.membreSylve).map(a => a.nom)] };
    UI.journal('Sanctuaire d’Émeraude', 'Suivez le chemin à travers la forêt. Gardiens vaincus : 0 / 4', 0);
    UI.boutonDegats(true);
    UI.zone('Sanctuaire d’Émeraude', `Groupe de 5 · T${modeActuel.tiers[0]}–T${modeActuel.tiers[1]}`);
    $('#btnQuitter').hidden = false;
    setTimeout(() => { UI.toast('Sanctuaire d’Émeraude', true); UI.toast('Un seul chemin. Quatre gardiens. Restez groupés.'); for (const a of allies) emoteBot(a, ['salut', 'feu', 'diable', 'gg'], 0.5, rnd(1, 3)); }, 700);
    son('forceField_000', 0.6, 0.9);
    G.renderer.compile(G.scene, G.camera);
  });
}
function objetSylve(t, qMin) {
  const q = Math.min(4, qMin + (Math.random() < 0.35 ? 1 : 0) + (Math.random() < 0.08 ? 1 : 0));
  return Math.random() < 0.4 ? creerArme(hasard(['epee', 'arbalete', 'baton']), t, q) : creerArmure(hasard(['casque', 'plastron', 'bottes']), t, q);
}
function noterDegats(src, d) {
  if (!compteur || !(d > 0)) return;
  const nom = !src || src === joueur || src.invoc ? J.nom : src.nom; if (!nom) return;
  compteur.total.set(nom, (compteur.total.get(nom) || 0) + d); compteur.seg.set(nom, (compteur.seg.get(nom) || 0) + d);
}
// zones dangereuses connues des alliés (pour qu'ils esquivent comme de vrais joueurs)
function dangerSur(p) { for (const z of dangers) { const dx = p.x - z.p.x, dz = p.z - z.p.z; if (dx * dx + dz * dz < (z.r + 0.8) ** 2) return z; } return null; }
function teleC(src, pos, r, duree, couleur, cb, opts = {}) { opts.camp = src.camp; return tele(pos, r, duree, couleur, cb, opts); }
function tele(pos, r, duree, couleur, cb, opts = {}) {
  const p = pos.clone(); const n0 = dangers.length;
  if (opts.ligne) { const a = opts.angle - Math.PI; for (let d = 0; d < r; d += 2) dangers.push({ p: V(p.x + Math.sin(a) * d, 0, p.z + Math.cos(a) * d), r: opts.largeur / 2 + 0.4, t: duree + 0.1 }); }
  else if (opts.cone) { const a = opts.angle + Math.PI / 2; for (let d = 2; d < r; d += 3) dangers.push({ p: V(p.x + Math.sin(a) * d, 0, p.z + Math.cos(a) * d), r: d * Math.tan(opts.cone / 2) + 0.5, t: duree + 0.1 }); }
  else dangers.push({ p, r, t: duree + 0.1 });
  for (let i = n0; i < dangers.length; i++) dangers[i].camp = opts.camp || 'ennemi';
  return telegraphe(pos, r, duree, couleur, cb, opts);
}
function zoneSol(p, r, duree, dps, src, couleur = '#5aff6a', opts = {}) {
  const g = new THREE.Group(); g.position.set(p.x, 0.08, p.z);
  const disque = new THREE.Mesh(new THREE.CircleGeometry(r, 36), new THREE.MeshBasicMaterial({ color: couleur, transparent: true, opacity: 0.32, blending: THREE.AdditiveBlending, depthWrite: false }));
  disque.rotation.x = -Math.PI / 2; g.add(disque);
  const bord = new THREE.Mesh(new THREE.RingGeometry(r - 0.18, r, 48), new THREE.MeshBasicMaterial({ color: couleur, transparent: true, opacity: 0.9, blending: THREE.AdditiveBlending, depthWrite: false }));
  bord.rotation.x = -Math.PI / 2; bord.position.y = 0.01; g.add(bord);
  G.scene.add(g);
  const z = { p: p.clone(), r, fin: duree, t: 0, dps, src, g, disque, tick: 0, couleur, piege: opts.piege };
  zonesSol.push(z); dangers.push({ p: z.p, r, t: duree, zone: z });
  return z;
}
function orbe(src, cible, dmg) {
  const mesh = meshBoule('#ff7ae8', 0.55); const p = V(src.pos.x, 1.4, src.pos.z); mesh.position.copy(p); G.scene.add(mesh);
  const o = { src, cible, dmg, mesh, pos: mesh.position, vie: 7.5 };
  orbes.push(o); return o;
}
function exploserOrbe(o) {
  onde(o.pos, '#ff7ae8', 3, 0.45); emettre(V(o.pos.x, 1, o.pos.z), { n: 36, c1: '#ffd0ff', c2: '#c01aff', vit: 6, vie: 0.6, taille: 0.5 }); son('explosionCrunch_000', 0.35, 1.3);
  toucherZone(o.src, V(o.pos.x, 0, o.pos.z), 2.6, o.dmg);
  G.scene.remove(o.mesh);
}
function rayonsEmeraude(e, n, duree, vit) {
  const g = new THREE.Group(); G.scene.add(g);
  const mat = new THREE.MeshBasicMaterial({ color: '#4affa8', transparent: true, opacity: 0.25, blending: THREE.AdditiveBlending, depthWrite: false });
  for (let i = 0; i < n; i++) { const b = new THREE.Mesh(new THREE.BoxGeometry(1.4, 0.5, 24), mat); b.position.set(Math.sin(i / n * 6.283) * 12, 1.3, Math.cos(i / n * 6.283) * 12); b.rotation.y = i / n * 6.283; g.add(b); }
  rayons.push({ src: e, n, duree, vit: vit * (Math.random() < 0.5 ? 1 : -1), angle: Math.random() * 6.28, t: 0, avert: 1.6, tick: 0, g, mat });
  UI.toast('Rayons d’émeraude : tournez autour de lui !');
}
function majSylve(dt) {
  for (let i = zonesSol.length - 1; i >= 0; i--) {
    const z = zonesSol[i]; z.t += dt; z.tick -= dt;
    z.disque.material.opacity = 0.22 + 0.12 * Math.sin(z.t * 5);
    if (Math.random() < dt * 6) emettre(V(z.p.x + rnd(-z.r, z.r) * 0.7, 0.3, z.p.z + rnd(-z.r, z.r) * 0.7), { n: 1, c1: '#d0ffb0', c2: z.couleur, dir: V(0, 1, 0), vit: 1.5, vie: 0.8, taille: 0.3 });
    if (z.tick <= 0) { z.tick = 0.5; toucherZone(z.src, z.p, z.r, z.dps * 0.5, z.piege ? { stun: 1.0 } : { slow: 1 }); }
    if (z.t >= z.fin || (z.src && z.src.mort && !z.piege)) { G.scene.remove(z.g); zonesSol.splice(i, 1); }
  }
  for (let i = orbes.length - 1; i >= 0; i--) {
    const o = orbes[i]; o.vie -= dt;
    if (!o.cible || o.cible.mort) { const l = equipeJoueur(); o.cible = l.length ? l.reduce((m, c) => dist2D(c.pos, o.pos) < dist2D(m.pos, o.pos) ? c : m) : null; }
    if (o.cible) { const d = V(o.cible.pos.x - o.pos.x, 0, o.cible.pos.z - o.pos.z); const l = d.length(); if (l > 0.01) o.pos.addScaledVector(d.multiplyScalar(1 / l), 3.6 * dt); o.pos.y = 1.3 + Math.sin(G.t * 6 + i) * 0.2; if (l < 1.2) o.vie = 0; }
    if (Math.random() < 0.6) emettre(o.pos, { n: 1, c1: '#ffd0ff', c2: '#a01aff', vit: 0.6, vie: 0.5, taille: 0.35 });
    // les alliés fuient les spores
    dangers.push({ p: o.pos.clone(), r: 2.4, t: dt * 1.5 });
    if (o.vie <= 0 || (o.src && o.src.mort)) { exploserOrbe(o); orbes.splice(i, 1); }
  }
  for (let i = rayons.length - 1; i >= 0; i--) {
    const r = rayons[i]; r.t += dt;
    if (r.src.mort) { G.scene.remove(r.g); rayons.splice(i, 1); continue; }
    r.g.position.set(r.src.pos.x, 0, r.src.pos.z);
    if (r.t > r.avert) { r.angle += r.vit * dt * (r.src.pv < r.src.pvMax * 0.33 ? 1.3 : 1); r.mat.opacity = 0.75 + 0.2 * Math.sin(r.t * 20); }
    else r.mat.opacity = 0.12 + 0.15 * (r.t / r.avert);
    r.g.rotation.y = r.angle;
    r.tick -= dt;
    if (r.t > r.avert && r.tick <= 0) {
      r.tick = 0.25;
      for (const c of adversaires(r.src)) {
        const dx = c.pos.x - r.src.pos.x, dz = c.pos.z - r.src.pos.z, d = Math.hypot(dx, dz); if (d > 24.5 || d < 1) continue;
        const a = Math.atan2(dx, dz);
        for (let k = 0; k < r.n; k++) { let diff = a - (r.angle + k / r.n * 6.283); diff = Math.atan2(Math.sin(diff), Math.cos(diff)); if (Math.abs(diff) < Math.PI / 2 && Math.abs(Math.sin(diff) * d) < 1.1) { infliger(r.src, c, r.src.dmg * (c === joueur ? 0.7 : 0.3)); break; } }
      }
    }
    if (r.t > r.avert + r.duree) { G.scene.remove(r.g); rayons.splice(i, 1); }
  }
  // phases du dernier boss
  const v = ennemis.find(e => e.boss && e.boss.id === 'verdanthos' && !e.mort && e.etat === 'chasse');
  if (v) {
    const ph = v.pv < v.pvMax * 0.33 ? 3 : v.pv < v.pvMax * 0.66 ? 2 : 1;
    if (ph > (v.phase || 1)) { v.phase = ph; transitionVerdanthos(v, ph); }
  }
}
function viderSylve() {
  for (const z of zonesSol) G.scene.remove(z.g); for (const o of orbes) G.scene.remove(o.mesh); for (const r of rayons) G.scene.remove(r.g);
  zonesSol = []; orbes = []; rayons = []; dangers = [];
  if (!modeActuel || !modeActuel.sylve) { sylve = null; compteur = null; }
}
function debutBossSylve(e) {
  const b = e.boss; sylve.bossT = G.t; if (b.id === 'verdanthos') G.camDist = 31;
  UI.introBoss(b.nom, b.titre, b.couleur);
  son('lowFrequency_explosion_000', 0.8, 0.6); G.shake = 0.6;
  onde(e.pos, b.couleur, 10, 1.2);
  for (const a of allies) if (!a.mort && a.membreSylve) emoteBot(a, ['diable', 'feu', 'toi'], 0.35, rnd(0.5, 2));
}
function finBossSylve(e) {
  bossVaincus++; G.shake = 1.1; son('jingle_win', 0.65); G.camDist = 25;
  gagnerXPRelatif(0.03 + e.idxSylve * 0.01); setTimeout(() => montrerXP(e.boss.nom), 9000);
  onde(e.pos, e.boss.couleur, 12, 1.4); emettre(V(e.pos.x, 2, e.pos.z), { n: 160, c1: '#eaffd0', c2: e.boss.couleur, vit: 10, vie: 1.6, taille: 0.55, grav: 2 });
  for (const o of ennemis) if (!o.mort && o.invoque) { o.pv = 0; tuer(o); }
  for (const z of zonesSol) z.fin = 0;
  const k = e.idxSylve; const derniere = k === 3;
  // butin du gardien (le joueur le voit dans le tableau des scores)
  // le coffre du gardien est commun : sa valeur est partagée entre les 5 joueurs, où qu'ils soient
  const nb = 1 + allies.filter(a => a.membreSylve).length;
  const pool = Math.round(lootCoffre(k >= 2 ? 'violet' : 'bleu', modeActuel, k).argent * 5 * (1 + k * 0.35));
  const butin = { argent: Math.round(pool / nb), pool, nb, objets: [objetSylve(modeActuel.tier, k >= 2 ? 3 : 2)] };
  if (Math.random() < 0.35) butin.objets.push(objetSylve(modeActuel.tier, 2));
  if (Math.random() < 0.12 + k * 0.05) butin.objets.push(objetSylve(Math.min(8, modeActuel.tier + 1), 2));
  const lignes = classement(compteur.seg, G.t - (sylve.bossT || sylve.segDebut), G.t - sylve.segDebut);
  if (!derniere) {
    const bar = monde.barrieres[k];
    if (bar) {
      monde.collisions = monde.collisions.filter(c => c.barriere !== k); monde._cg = null;
      son('forceField_000', 0.7, 0.5);
      ajouterVfx(new THREE.Group(), (t) => { bar.groupe.position.y = -t * 2.2; bar.groupe.scale.x = Math.max(0.01, 1 - t * 0.3); if (Math.random() < 0.6) emettre(V(bar.pt.x + rnd(-5, 5), 1, bar.pt.z + rnd(-5, 5)), { n: 2, c1: '#bfffc0', c2: '#2aff6a', vit: 3, vie: 0.8, taille: 0.4 }); if (t > 2.5) { bar.groupe.visible = false; return false; } });
    }
    UI.journal('Sanctuaire d’Émeraude', `Gardiens vaincus : ${bossVaincus} / 4 — les ronces s’ouvrent, continuez le chemin.`, bossVaincus / 4);
  } else {
    const s = monde.salles[3];
    const pos = s.c.clone().add(V(-4, 0, 0));
    const c = COFFRES.find(x => x.id === 'legendaire');
    const obj = cloner('chest_gold', pos.x, 0, pos.z, Math.PI / 4, 2.2); obj.traverse(o => { if (o.isMesh) o.castShadow = true; });
    G.scene.add(obj); const beam = faisceau(V(pos.x, 0, pos.z), '#3affa0', 22, 1.3); G.scene.add(beam);
    setTimeout(() => { const cf = coffres.find(x => x.final); if (cf) for (const a of allies) if (a.membreSylve && !a.mort) a.lootCible = cf; }, 4000);
    coffres.push({ obj, beam, couleur: 'legendaire', def: { ...c, nom: 'Coffre du Sanctuaire', color: '#3affa0' }, boss: { mort: true, boss: e.boss }, pos, ouvert: false, lid: obj.getObjectByName('chest_lid'), final: true });
    if (sortie) { G.scene.remove(sortie.groupe); } creerSortie(s.c.clone().add(V(6, 0, 5)));
    UI.journal('Sanctuaire purifié !', 'Ouvrez le Coffre du Sanctuaire pour voir les dégâts totaux et le butin de chacun.', 1);
  }
  setTimeout(() => {
    // plus de grand panneau qui bloque : le butin tombe directement, un petit résumé s'affiche, les dégâts restent consultables (bouton à gauche)
    J.argent += butin.argent; for (const it of butin.objets) ajouterSac(it, true); son('handleCoins', 0.6); sauver();
    sylve.butinJoueur.argent += butin.argent; sylve.butinJoueur.objets.push(...butin.objets);
    const moi = lignes.findIndex(l => l.moi);
    UI.resumeBoss({ nom: e.boss.nom, couleur: e.boss.couleur, rang: moi + 1, nb: lignes.length, argent: butin.argent, pool: butin.pool, objets: butin.objets });
    if (!derniere) UI.toast('Le chemin est ouvert : en avant !', true);
    compteur.seg = new Map(); sylve.segDebut = G.t; sylve.bossT = null;
  }, 2600);
}
function classement(map, dureeBoss, dureeSeg) {
  const total = [...map.values()].reduce((a, b) => a + b, 0) || 1;
  return compteur.noms.map(nom => {
    const a = nom === J.nom ? null : allies.find(x => x.nom === nom);
    const type = nom === J.nom ? J.equip.arme.type : a ? a.equip.arme.type : 'epee';
    const d = map.get(nom) || 0;
    return { nom, type, ip: nom === J.nom ? statsHeros(J.equip).ip : a ? a.ip : 0, degats: d, part: d / total, dps: d / Math.max(1, dureeSeg), moi: nom === J.nom };
  }).sort((x, y) => y.degats - x.degats);
}
function ouvrirCoffreFinal(c) {
  c.ouvert = true; UI.action(null);
  son('creak1', 0.7); son('jingle_legend', 0.7);
  if (c.lid) ajouterVfx(new THREE.Group(), (t) => { c.lid.rotation.x = -Math.min(1, t / 0.6) * 1.9; if (t > 0.7) return false; });
  emettre(V(c.pos.x, 1.4, c.pos.z), { n: 160, c1: '#eaffd0', c2: '#3affa0', vit: 9, vie: 1.5, taille: 0.5, grav: 4, monte: 5 }); onde(c.pos, '#3affa0', 7, 1);
  const t = modeActuel.tier;
  const lignes = classement(compteur.total, 0, G.t - sylve.debut);
  // 2 pièces à ton tier (belle qualité) + 1 pièce du tier suivant, à viser pour plus tard
  const objetsPour = () => { const o = [objetSylve(t, 3), objetSylve(t, 2), objetSylve(Math.min(8, t + 1), 2)]; if (Math.random() < 0.25) o.push(objetSylve(Math.min(8, t + 1), 3)); return o; };
  const pool = Math.round(lootCoffre('violet', modeActuel, 3).argent * 5 * 2);
  const part = Math.round(pool / lignes.length);
  for (const l of lignes) l.butin = { argent: part, objets: objetsPour() };
  const moi = lignes.find(l => l.moi);
  setTimeout(() => UI.recapFinal({ duree: G.t - sylve.debut, total: lignes.reduce((a, l) => a + l.degats, 0), lignes, pool, precedents: sylve.butinJoueur }, () => {
    J.argent += moi.butin.argent; for (const it of moi.butin.objets) ajouterSac(it, true); son('handleCoins', 0.7); sauver(); c.beam.visible = false;
    for (const a of allies) if (!a.mort) emoteBot(a, ['gg', 'merci', 'feu', 'ez'], 0.8, rnd(0.3, 2));
    proposerRefaire();
  }), 900);
}
function mortSylve() {
  son('lowFrequency_explosion_000', 0.7, 0.5);
  const vivants = allies.filter(a => !a.mort && a.membreSylve);
  if (!vivants.length) { const perte = Math.round(J.argent * 0.05); J.argent -= perte; sauver(); setTimeout(() => UI.mort(`Tout le groupe est tombé. Tu perds ${perte.toLocaleString('fr-FR')} pièces d’argent.`, () => fondu(() => lancerHub())), 1600); return; }
  UI.toast('Tu es tombé… un allié va te relever', true);
  emoteBot(hasard(vivants), ['oups', 'rip', 'toi'], 0.8, 1);
  programmer(9, () => {
    if (!joueur.mort || !modeActuel || !modeActuel.sylve) return;
    const a = allies.find(x => !x.mort && x.membreSylve) || null;
    if (!a) return mortSylve();
    joueur.mort = false; joueur.pv = joueur.st.pvMax * 0.5; joueur.invuln = 2; joueur.pos.copy(pointLibrePres(a.pos, 1, 2.5)); joueur.jouer(joueur.def.idle);
    onde(joueur.pos, '#9dff8a', 4, 0.7); emettre(V(joueur.pos.x, 1, joueur.pos.z), { n: 50, c1: '#eaffd0', c2: '#3aff6a', vit: 4, vie: 1, taille: 0.4, monte: 3 });
    UI.toast(`${a.nom} t’a relevé`);
  });
}
// ---- capacités des gardiens du Sanctuaire ----
function capaciteSylve(e) {
  const b = e.boss; const cibles = adversaires(e).filter(c => dist2D(c.pos, e.pos) < 30);
  if (!cibles.length) return;
  const pj = (e.tc || cibles[0]).pos.clone();
  const base = Math.atan2(pj.x - e.pos.x, pj.z - e.pos.z);
  const rouge = '#ff2a2a';
  if (b.id === 'ronces') {
    const r = e.cycle % 3;
    if (r === 1) { // ronces jaillissantes vers 3 joueurs, laissent des épines au sol
      e.attaqueT = 1.4; e.jouer('2H_Melee_Attack_Spinning', { boucle: false, forcer: true, vitesse: 0.8, fin: () => e.jouer('Idle_Combat') });
      for (const c of [...cibles].sort(() => Math.random() - 0.5).slice(0, 3)) {
        const a = Math.atan2(c.pos.x - e.pos.x, c.pos.z - e.pos.z); const o = e.pos.clone();
        tele(o, 17, 1.15, rouge, () => {
          for (let d = 2; d < 17; d += 1.4) emettre(V(o.x + Math.sin(a) * d, 0.4, o.z + Math.cos(a) * d), { n: 4, c1: '#bfffa0', c2: '#2a6a1a', dir: V(0, 1, 0), vit: 7, disp: 0.6, vie: 0.6, taille: 0.5, grav: 8 });
          son('impactPlank_medium_000', 0.6, 0.7); G.shake = 0.4;
          for (const cc of adversaires(e)) { const dx = cc.pos.x - o.x, dz = cc.pos.z - o.z; const along = dx * Math.sin(a) + dz * Math.cos(a), perp = Math.abs(dx * Math.cos(a) - dz * Math.sin(a)); if (along > 0 && along < 17 && perp < 1.5) infliger(e, cc, e.dmg * 2.6, { slow: 2 }); }
          for (let d = 5; d < 17; d += 5.5) zoneSol(V(o.x + Math.sin(a) * d, 0, o.z + Math.cos(a) * d), 1.9, 6, e.dmg * 0.55, e, '#5aff4a');
        }, { ligne: true, largeur: 3, angle: a + Math.PI });
      }
    } else if (r === 2) { // étreinte : tout le monde doit s'éloigner, puis les ronces poursuivent
      e.attaqueT = 2.2; e.jouer('Spellcast_Summon' in e.actions ? 'Spellcast_Summon' : 'Idle_Combat', { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') });
      const c0 = e.pos.clone();
      tele(c0, 8, 1.5, rouge, () => { G.shake = 0.9; onde(c0, '#7dff6a', 9, 0.6); emettre(V(c0.x, 0.4, c0.z), { n: 80, c1: '#d0ffb0', c2: '#2a8a1a', vit: 10, vie: 0.8, taille: 0.6, hemi: true }); son('impactPlate_heavy_000', 0.8, 0.5); toucherZone(e, c0, 8, e.dmg * 3.2); });
      programmer(1.6, () => { if (e.mort) return; for (const c of adversaires(e)) { const p = c.pos.clone(); tele(p, 3, 1.1, rouge, () => { emettre(V(p.x, 0.4, p.z), { n: 25, c1: '#bfffa0', c2: '#2a6a1a', dir: V(0, 1, 0), vit: 8, disp: 1, vie: 0.6, taille: 0.5 }); toucherZone(e, p, 3, e.dmg * 2.2, { slow: 2 }); }); } });
      if (e.pv < e.pvMax * 0.5 && !e.renforts) { e.renforts = true; for (let i = 0; i < 3; i++) { const p = pointLibrePres(e.pos, 4, 7); const m2 = creerEnnemi(MOBS_SYLVE.moussu, p, modeActuel.mobTier, -2); m2.invoque = true; m2.maitre = e; m2.etat = 'chasse'; fumeeOmbre(p); } UI.toast('Le Tisserand appelle la forêt !'); }
    } else { // bond fracassant sur le plus éloigné
      const loin = cibles.reduce((m, c) => dist2D(c.pos, e.pos) > dist2D(m.pos, e.pos) ? c : m); const p = loin.pos.clone();
      e.jouer('1H_Melee_Attack_Jump_Chop', { boucle: false, forcer: true, vitesse: 0.8, fin: () => e.jouer('Idle_Combat') });
      e.sautA = e.pos.clone(); e.sautB = pointLibrePres(p, 0, 1.2, 1.2); e.sautD = e.sautT = 1.25; e.sautH = 5; e.attaqueT = 1.7;
      tele(p, 4.5, 1.25, rouge, () => { G.shake = 1; onde(p, '#9aff6a', 7, 0.6); emettre(V(p.x, 0.3, p.z), { n: 60, c1: '#d8c8a8', c2: '#3a6a2a', vit: 9, vie: 0.8, taille: 0.6, hemi: true, grav: 6 }); son('impactPlate_heavy_000', 0.8, 0.6); toucherZone(e, p, 4.5, e.dmg * 3.6, { slow: 2.5 }); });
    }
  } else if (b.id === 'sylphe') {
    const r = e.cycle % 3;
    if (r === 1) { // spores traqueuses : il faut les promener
      e.attaqueT = 1.2; e.jouer('Spellcast_Summon', { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') });
      UI.toast('Spores traqueuses : fuyez-les !');
      for (const c of [...cibles].sort(() => Math.random() - 0.5).slice(0, e.pv < e.pvMax * 0.4 ? 4 : 3)) programmer(0.5, () => { if (!e.mort) orbe(e, c, e.dmg * 2.6); });
    } else if (r === 2) { // pluie de pétales
      e.jouer('Spellcast_Shoot', { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') }); e.attaqueT = 1.0;
      for (const c of cibles) for (let i = 0; i < 2; i++) {
        const p = i ? c.pos.clone().add(V(rnd(-4, 4), 0, rnd(-4, 4))) : c.pos.clone();
        tele(p, 2.8, 1.2 + i * 0.35, rouge, () => { emettre(V(p.x, 3, p.z), { n: 30, c1: '#ffd0f0', c2: '#ff5ab8', vit: 5, vie: 0.8, taille: 0.45, grav: 6 }); onde(p, '#ff7ae8', 3, 0.4); son('impactGeneric_light_000', 0.4, 1.3); toucherZone(e, p, 2.8, e.dmg * 2.3); });
      }
    } else { // floraison : elle disparaît, réapparaît ailleurs et explose ; du pollen reste derrière elle
      const s = monde.salles[1]; const avant = e.pos.clone();
      fumeeOmbre(avant); zoneSol(avant, 4.2, 9, e.dmg * 0.6, e, '#ff7ae8');
      const a = Math.random() * 6.28; const np = pointLibrePres(V(s.c.x + Math.cos(a) * 9, 0, s.c.z + Math.sin(a) * 9), 0, 2, 1.2);
      e.pos.copy(np); fumeeOmbre(np); e.attaqueT = 1.6; e.jouer('Spellcast_Long' in e.actions ? 'Spellcast_Long' : 'Spellcast_Shoot', { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') });
      tele(np, 6.5, 1.3, rouge, () => { G.shake = 0.7; onde(np, '#ff9aff', 8, 0.6); emettre(V(np.x, 1, np.z), { n: 90, c1: '#ffe0ff', c2: '#c01aff', vit: 9, vie: 0.8, taille: 0.6 }); son('explosionCrunch_000', 0.6, 0.9); toucherZone(e, np, 6.5, e.dmg * 3.0); });
      if (e.pv < e.pvMax * 0.5 && !e.renforts) { e.renforts = true; for (let i = 0; i < 2; i++) { const p = pointLibrePres(e.pos, 4, 8); const m2 = creerEnnemi(MOBS_SYLVE.druide, p, modeActuel.mobTier, -2); m2.invoque = true; m2.maitre = e; m2.etat = 'chasse'; fumeeOmbre(p); } UI.toast('La Reine appelle ses druides !'); }
    }
  } else if (b.id === 'chasseur') {
    const r = e.cycle % 3;
    if (r === 1) { // tir de traque : la ligne suit la cible, puis le carreau part
      const c = hasard(cibles); e.attaqueT = 2.1; e.jouer('2H_Ranged_Shoot', { boucle: false, forcer: true, vitesse: 0.45, fin: () => e.jouer('Idle_Combat') });
      if (c === joueur) UI.toast('Le Chasseur te vise : écarte-toi de la ligne !');
      const ligneM = new THREE.Mesh(new THREE.PlaneGeometry(1.6, 30).translate(0, 15, 0), new THREE.MeshBasicMaterial({ color: '#ff3a2a', transparent: true, opacity: 0.4, blending: THREE.AdditiveBlending, depthWrite: false }));
      ligneM.rotation.x = -Math.PI / 2; let ang = 0;
      ajouterVfx(ligneM, (t) => {
        if (e.mort) return false;
        if (t < 1.5) { ang = Math.atan2(c.pos.x - e.pos.x, c.pos.z - e.pos.z); e.angle = ang; e.root.rotation.y = ang; dangers.push({ p: c.pos.clone(), r: 1.4, t: 0.05 }); }
        ligneM.position.set(e.pos.x, 0.1, e.pos.z); ligneM.rotation.z = ang + Math.PI; ligneM.material.opacity = t < 1.5 ? 0.25 + 0.4 * (t / 1.5) : 0.9;
        if (t >= 1.75) { tirEnnemi(e, 'carreau', e.dmg * 4.2, V(Math.sin(ang), 0, Math.cos(ang)), 42); son('drawKnife2', 0.8, 0.6); G.shake = 0.3; return false; }
      });
    } else if (r === 2) { // éventail + bond en arrière
      e.attaqueT = 1.4; e.jouer('2H_Ranged_Shoot', { boucle: false, forcer: true, vitesse: 0.7, fin: () => e.jouer('Idle_Combat') });
      tele(e.pos, 15, 0.9, rouge, () => { for (let i = -4; i <= 4; i++) { const a = base + i * 0.14; tirEnnemi(e, 'carreau', e.dmg * 1.6, V(Math.sin(a), 0, Math.cos(a)), 20); } }, { cone: 1.3, angle: base - Math.PI / 2 });
      programmer(1.0, () => { if (e.mort) return; const arr = V(-Math.sin(base), 0, -Math.cos(base)); e.sautA = e.pos.clone(); e.sautB = pointLibrePres(e.pos.clone().addScaledVector(arr, 8), 0, 2, 1.2); e.sautD = e.sautT = 0.6; e.sautH = 2.5; e.jouer('1H_Melee_Attack_Jump_Chop', { boucle: false, forcer: true, vitesse: 1.4, fin: () => e.jouer('Idle_Combat') }); });
    } else { // pièges de ronces
      e.attaqueT = 1.0; e.jouer('Spellcast_Shoot' in e.actions ? 'Spellcast_Shoot' : '2H_Ranged_Shoot', { boucle: false, forcer: true, fin: () => e.jouer('Idle_Combat') });
      for (const c of cibles) { const p = c.pos.clone().add(V(rnd(-3, 3), 0, rnd(-3, 3))); zoneSol(p, 1.7, 14, e.dmg * 1.2, e, '#ffb02a', { piege: true }); }
      UI.toast('Pièges de ronces : regarde où tu marches');
      if (e.cycle % 6 === 0) for (let i = 0; i < 2; i++) { const p = pointLibrePres(e.pos, 5, 9); const m2 = creerEnnemi(MOBS_SYLVE.ronce, p, modeActuel.mobTier, -2); m2.invoque = true; m2.maitre = e; m2.etat = 'chasse'; fumeeOmbre(p); }
    }
  } else if (b.id === 'verdanthos') {
    const ph = e.phase || 1; const r = e.cycle % (ph >= 2 ? 4 : 3);
    if (r === 0) { // souffle d'émeraude
      e.attaqueT = 1.9; e.jouer('Headbutt', { boucle: false, forcer: true, vitesse: 0.6, fin: () => e.jouer('Flying_Idle') }); e.angle = base; e.root.rotation.y = base;
      const c0 = e.pos.clone();
      tele(c0, 14, 1.3, rouge, () => { son('thrusterFire_000', 0.9, 0.5); G.shake = 0.7;
        for (let i = 0; i < 90; i++) { const a = base + rnd(-0.6, 0.6); emettre(V(c0.x, 3, c0.z), { n: 1, c1: '#eaffb0', c2: '#1aff6a', dir: V(Math.sin(a), -0.08, Math.cos(a)), vit: 18, disp: 1, vie: 0.8, taille: 1.1, frein: 1 }); }
        toucherZone(e, c0, 14, e.dmg * 3.4, { cone: { dir: V(Math.sin(base), 0, Math.cos(base)), cos: Math.cos(0.62) } });
        zoneSol(c0.clone().add(V(Math.sin(base) * 8, 0, Math.cos(base) * 8)), 3.2, 7, e.dmg * 0.7, e); }, { cone: 1.25, angle: base - Math.PI / 2 });
    } else if (r === 1) { // pluie de graines : chaque graine laisse une zone toxique
      e.attaqueT = 1.1; e.jouer('Punch', { boucle: false, forcer: true, fin: () => e.jouer('Flying_Idle') });
      const n = ph === 3 ? 10 : 7;
      for (let i = 0; i < n; i++) {
        const c = cibles[i % cibles.length]; const p = i < cibles.length ? c.pos.clone() : c.pos.clone().add(V(rnd(-7, 7), 0, rnd(-7, 7)));
        const dur = 1.5 + i * 0.12;
        tele(p, 3, dur, rouge, () => { G.shake = 0.45; emettre(V(p.x, 0.5, p.z), { n: 40, c1: '#eaffb0', c2: '#1a8a2a', vit: 8, vie: 0.7, taille: 0.7, hemi: true }); onde(p, '#5aff8a', 4, 0.5); son('explosionCrunch_000', 0.4, 0.8); toucherZone(e, p, 3, e.dmg * 2.6); if (Math.random() < 0.5) zoneSol(p, 2.6, 7, e.dmg * 0.6, e); });
        const graine = meshBoule('#5aff6a', 0.7); graine.position.set(p.x + 6, 20, p.z - 6); G.scene.add(graine);
        ajouterVfx(graine, (t) => { const k = t / dur; if (k >= 1) return false; graine.position.set(p.x + 6 * (1 - k), 20 * (1 - k), p.z - 6 * (1 - k)); if (Math.random() < 0.5) emettre(graine.position, { n: 1, c1: '#eaffb0', c2: '#1aff6a', vit: 0.5, vie: 0.4, taille: 0.5 }); });
      }
    } else if (r === 2) { // charge
      e.attaqueT = 1.3; const dir = V(Math.sin(base), 0, Math.cos(base));
      tele(e.pos, 20, 1.1, rouge, () => { e.chargeT = 0.65; e.chargeV = dir.clone().multiplyScalar(30); e.chargeTouches = new Set(); e.jouer('Fast_Flying', { vitesse: 2 }); son('lowFrequency_explosion_000', 0.5, 1.2); }, { ligne: true, largeur: 4.2, angle: base + Math.PI });
      e.angle = base; e.root.rotation.y = base;
    } else { // rayons tournants (phases 2 et 3)
      e.attaqueT = 2.5; e.figeT = ph === 3 ? 7.5 : 6.5; e.jouer('Flying_Idle');
      rayonsEmeraude(e, ph === 3 ? 4 : 3, ph === 3 ? 6.5 : 5.5, ph === 3 ? 0.75 : 0.6);
    }
  }
}
function transitionVerdanthos(e, ph) {
  G.shake = 1.2; son('lowFrequency_explosion_000', 0.9, 0.5);
  onde(e.pos, '#3affa0', 14, 1.4); emettre(V(e.pos.x, 3, e.pos.z), { n: 140, c1: '#eaffd0', c2: '#1aff6a', vit: 12, vie: 1.2, taille: 0.7 });
  UI.introBoss(ph === 2 ? 'Verdanthos s’éveille' : 'Fureur de l’Ancien', ph === 2 ? 'Les rayons d’émeraude balaient la clairière' : 'Tout s’accélère : tenez bon !', '#3affa0');
  // onde de choc qui repousse
  for (const c of adversaires(e)) { const d = V(c.pos.x - e.pos.x, 0, c.pos.z - e.pos.z); const l = d.length() || 1; if (l < 10) { if (c === joueur) { joueur.dashT = 0.3; joueur.dashV = d.multiplyScalar(14 / l); } else { c.dashT = 0.3; c.dashV = d.multiplyScalar(14 / l); } infliger(e, c, e.dmg * 1.2); } }
  const n = ph === 2 ? 4 : 5;
  for (let i = 0; i < n; i++) { const p = pointLibrePres(e.pos, 7, 13); const m2 = creerEnnemi(MOBS_SYLVE[hasard(['moussu', 'ecorce', 'druide'])], p, modeActuel.mobTier, -2); m2.invoque = true; m2.maitre = e; m2.etat = 'chasse'; fumeeOmbre(p); }
  e.specT = 2.5; e.cycle = 2;
  if (ph === 3) for (const mt of e.mats) if (mt.emissive) { mt.emissive.set('#2aff6a').multiplyScalar(0.35); mt.userData.baseEmissive = mt.emissive.clone(); }
}



// ---------------- Musique ----------------
let pisteMusique = null, calmeT = 0;
function combatIntense() {
  if (arene && !arene.fini) return true;
  if (rivauxVivants().length) return true;
  if (assaut && !assaut.fini) return true;
  return ennemis.some(e => e.boss && !e.mort && e.etat === 'chasse' && dist2D(e.pos, joueur.pos) < 30);
}
function majMusique(dt) {
  if (!enJeu) return;
  if (combatIntense()) { calmeT = 5; if (pisteMusique !== 'theme') { pisteMusique = 'theme'; musique('theme'); } }
  else if (pisteMusique === 'theme') { calmeT -= dt; if (calmeT <= 0) { pisteMusique = 'fond'; musique('fond'); } }
}
// ---------------- Parchemins ----------------
function parchActifs() { return MODES.includes(modeActuel) && !(invasion && invasion.mode === 'menee') && !rivauxVivants().length; }
function bonusParch(effet) {
  if (!J.parchemins || !parchActifs()) return 0;
  for (const [c, p] of Object.entries(J.parchemins)) if (COULEURS_PARCH[c].effet === effet && p.reste > 0) return p.bonus;
  return 0;
}
let parchSauveT = 0;
function majParchemins(dt) {
  const P = J.parchemins; if (!P) return;
  const actif = parchActifs();
  const now = performance.now(); const reel = Math.min(5, (now - (majParchemins.t || now)) / 1000); majParchemins.t = now;
  if (actif) for (const [c, p] of Object.entries(P)) {
    p.reste -= reel;
    if (p.reste <= 0) { delete P[c]; UI.toast(`Parchemin de ${COULEURS_PARCH[c].nom} épuisé`); son('close_001', 0.4); }
  }
  parchSauveT -= 0.2; if (parchSauveT <= 0) { parchSauveT = 5; sauver(); }
  UI.majParchemins(etatParchemins());
}
function etatParchemins() {
  const P = J.parchemins || {}; const pause = !parchActifs();
  const raison = !MODES.includes(modeActuel) ? 'hors Brèche' : invasion && invasion.mode === 'menee' ? 'invasion' : rivauxVivants().length ? 'combat d’invasion' : '';
  return Object.entries(P).map(([c, p]) => ({ couleur: c, bonus: p.bonus, reste: p.reste, pause, raison }));
}
function utiliserParchemin(itemId) {
  const it = J.sac.find(i => i.id == itemId && i.cat === 'parchemin'); if (!it) return;
  const def = PARCHEMINS[it.type]; J.parchemins = J.parchemins || {};
  const cur = J.parchemins[def.couleur];
  if (cur) { cur.reste += DUREE_PARCH; cur.bonus = Math.max(cur.bonus, def.bonus); UI.toast(`${COULEURS_PARCH[def.couleur].nom} prolongé : ${Math.round(cur.reste / 60)} min restantes`); }
  else { J.parchemins[def.couleur] = { bonus: def.bonus, reste: DUREE_PARCH }; UI.toast(`Parchemin activé : +${Math.round(def.bonus * 100)} % ${COULEURS_PARCH[def.couleur].texte} pendant 30 min`, true); }
  it.n = (it.n || 1) - 1; if (it.n <= 0) J.sac = J.sac.filter(x => x !== it);
  son('bookOpen', 0.6); if (joueur) { onde(joueur.pos, COULEURS_PARCH[def.couleur].c2, 4, 0.6); emettre(V(joueur.pos.x, 1.2, joueur.pos.z), { n: 50, c1: COULEURS_PARCH[def.couleur].c1, c2: COULEURS_PARCH[def.couleur].c2, vit: 4, vie: 1, taille: 0.4, monte: 3 }); }
  if (!MODES.includes(modeActuel)) UI.toast('Il ne s’écoule que dans la Brèche Écarlate');
  sauver();
}

// ---------------- Rangs classés ----------------
// rang de la partie en cours : Argent, Or… rendent les ennemis plus forts et le butin meilleur
// les rivaux de haut rang encaissent et cognent plus (maîtrise, talents… comme de vrais joueurs)
function kpv(camp) { if (camp !== 'ennemi') return 1; const i = rangK(); return arene ? 1 + 0.16 * i + (i >= 5 ? 0.3 : 0) : 1 + 0.07 * i; }
function kdg(camp) { if (camp !== 'ennemi') return 1; const i = rangK(); return arene ? 1 + 0.09 * i : 1 + 0.07 * i; }
function couleurSelonRang(c) { const ordre = ['vert', 'bleu', 'violet', 'legendaire']; let i = ordre.indexOf(c); if (i >= 0 && i < 2 && Math.random() < 0.025 * rangK()) i++; return ordre[i] || c; } // le rang ne crée jamais de légendaire
function rangK() {
  if (arene) return rangDe('arene').i;
  if (MODES.includes(modeActuel) || modeActuel && modeActuel.sylve) return rangDe('donjon').i;
  return 0;
}
// progression lente sur la durée : chaque palier demande beaucoup plus que le précédent
const SEUILS_RANG = [0, 100, 300, 800, 2000, 4000];
const GAIN_K = [1, 0.85, 0.65, 0.45, 0.3, 0.25], PERTE_K = [0.6, 0.8, 1, 1.2, 1.4, 1.6];
function migrerRang() {
  if (!J.rang || J.rangV2) return; J.rangV2 = true;
  for (const m of ['arene', 'donjon']) { const p = J.rang[m] || 0, i = Math.min(RANGS.length - 1, Math.floor(p / 100)); const loc = i === RANGS.length - 1 ? p - i * 100 : p % 100;
    const larg = (SEUILS_RANG[i + 1] || SEUILS_RANG[i] + 1000) - SEUILS_RANG[i]; J.rang[m] = SEUILS_RANG[i] + Math.round(Math.min(0.99, loc / 100) * larg); }
}
function rangDe(mode) {
  migrerRang();
  const p = (J.rang && J.rang[mode]) || 0; let i = 0; while (i < RANGS.length - 1 && p >= SEUILS_RANG[i + 1]) i++;
  const max = i === RANGS.length - 1 ? null : SEUILS_RANG[i + 1] - SEUILS_RANG[i];
  return { i, pts: p, local: p - SEUILS_RANG[i], max, r: RANGS[i], mode };
}
function changerRang(mode, delta, raison) {
  if (!J.rang) { J.rang = { arene: 0, donjon: 0 }; J.rangV2 = true; }
  const avant = rangDe(mode); delta = delta >= 0 ? Math.max(1, Math.round(delta * GAIN_K[avant.i])) : Math.round(delta * PERTE_K[avant.i]); J.rang[mode] = Math.max(0, Math.round(J.rang[mode] + delta)); const apres = rangDe(mode); sauver();
  UI.changementRang(avant, apres, Math.round(delta), raison);
  if (apres.i > avant.i) son('jingle_legend', 0.6); else if (apres.i < avant.i) son('lowFrequency_explosion_000', 0.6, 0.6);
}
// les autres joueurs du rang : leurs points bougent au fil de la journée
function classementRang(mode) {
  const rg = rangDe(mode); const t = Date.now() / 3.6e6;
  const liste = BOTS.slice(0, 24).map(([nom, tag], k) => {
    const s = (k + 1) * 9301 + rg.i * 49297 + (mode === 'arene' ? 7 : 3);
    const base = (s * 233280) % 97; const pts = Math.max(0, Math.min(rg.max || 3000, Math.round((base / 97) * (rg.max || 3000) * 0.95 + 10 * Math.sin(t * (0.6 + (s % 7) / 10) + k))));
    return { nom, tag, pts, moi: false };
  });
  liste.push({ nom: J.nom, tag: 'CZ', pts: rg.local, moi: true });
  liste.sort((a, b) => b.pts - a.pts);
  return { rang: rg, liste };
}
// ---------------- Boss errant ultra rare ----------------
let errant = null;
function apparitionErrant() {
  const salles = monde.salles.filter(s => s.type === 'normale').sort((a, b) => dist2D(b.centre, monde.spawn) - dist2D(a.centre, monde.spawn));
  const s = salles[Math.floor(Math.random() * Math.min(3, salles.length))]; if (!s) return;
  const b = creerBoss(BOSS_ERRANT, s.centre.clone(), modeActuel.bossTier[3], s);
  b.revealT = 6; b.revele = 0; errant = b;
  for (const mt of b.mats) if (mt.emissive) { mt.emissive.set('#8a2aff').multiplyScalar(0.25); mt.userData.baseEmissive = mt.emissive.clone(); }
  setTimeout(() => { UI.introBoss(BOSS_ERRANT.nom, BOSS_ERRANT.titre + ' est apparu dans le donjon', BOSS_ERRANT.couleur); son('lowFrequency_explosion_000', 0.8, 0.4); G.shake = 0.5; }, 2500);
}
function majErrant(dt) {
  const e = errant; if (!e || e.mort || !ennemis.includes(e)) { errant = null; return; }
  if (e.revele > 0) e.revele -= dt;
  if (e.etat === 'dormant') {
    e.revealT -= dt;
    if (e.revealT <= 0) { e.revealT = rnd(20, 30); e.revele = 3.2; UI.ping(); UI.toast(`${BOSS_ERRANT.nom} rôde dans le donjon…`); son('forceField_000', 0.4, 0.5); }
    if (Math.random() < dt * 3) emettre(V(e.pos.x + rnd(-2, 2), 2, e.pos.z + rnd(-2, 2)), { n: 1, c1: '#e0b0ff', c2: '#3a0a6a', dir: V(0, 1, 0), vit: 2, vie: 1.2, taille: 0.6 });
  }
}
function mortErrant(e) {
  UI.boss(null); G.shake = 1.4; son('jingle_legend', 0.8);
  onde(e.pos, '#c06aff', 14, 1.5); emettre(V(e.pos.x, 3, e.pos.z), { n: 200, c1: '#f4d8ff', c2: '#6a1aff', vit: 12, vie: 1.8, taille: 0.6, grav: 2 });
  UI.introBoss(`${BOSS_ERRANT.nom} est vaincu`, 'Un trésor légendaire t’attend', BOSS_ERRANT.couleur);
  creerCoffre(pointLibrePres(e.pos, 2, 4), 'legendaire', e); coffres[coffres.length - 1].mega = true;
  if (MODES.includes(modeActuel)) changerRang('donjon', 15, BOSS_ERRANT.nom + ' vaincu');
  gagnerXPRelatif(0.25); setTimeout(() => montrerXP(BOSS_ERRANT.nom), 1800);
  errant = null; sauver();
  setTimeout(() => { e.descendre = true; }, 6000);
}



// ---------------- Assassin ----------------
function distSegPt(a, b, p) { const vx = b.x - a.x, vz = b.z - a.z, l2 = vx * vx + vz * vz; let t = l2 ? ((p.x - a.x) * vx + (p.z - a.z) * vz) / l2 : 0; t = Math.max(0, Math.min(1, t)); return Math.hypot(p.x - (a.x + vx * t), p.z - (a.z + vz * t)); }
function gagnerCombo(n) { joueur.combo = Math.min(5, (joueur.combo || 0) + n); joueur.comboT = 8; }
function furtifBonus() { return joueur.furtifT > 0 ? 1.15 : 1; }
function traineeRouge(a, b, c1 = '#ff4a5a') { const n = Math.max(3, Math.round(a.distanceTo(b) * 2)); for (let i = 0; i <= n; i++) { const p = a.clone().lerp(b, i / n); emettre(V(p.x, 1, p.z), { n: 1, c1, c2: '#1a0004', vit: 0.6, vie: 0.35, taille: 0.45 }); } }
function teleportDerriere(c) {
  const ang = Math.atan2(c.pos.x - joueur.pos.x, c.pos.z - joueur.pos.z);
  const p = V(c.pos.x + Math.sin(ang) * (c.rayon + 1.0), 0, c.pos.z + Math.cos(ang) * (c.rayon + 1.0));
  const q = pointLibreProche(p, 0.5) || joueur.pos.clone();
  emettre(V(joueur.pos.x, 1, joueur.pos.z), { n: 20, c1: '#ff8a8a', c2: '#1a0004', vit: 3, vie: 0.5, taille: 0.45 });
  joueur.pos.set(q.x, 0, q.z); faireFace(V(c.pos.x - q.x, 0, c.pos.z - q.z).normalize());
  emettre(V(q.x, 1, q.z), { n: 20, c1: '#ff8a8a', c2: '#1a0004', vit: 3, vie: 0.5, taille: 0.45 }); son('cloth1', 0.5, 1.6);
}
function furtif(t) {
  joueur.furtifT = Math.max(joueur.furtifT || 0, t); joueur.invuln = Math.max(joueur.invuln, t);
  for (const e of ennemis) if (e.tc === joueur) e.tc = null;
  if (!joueur._furtifVfx) {
    joueur._furtifVfx = true;
    for (const m of joueur.mats) { m.transparent = true; m.opacity = 0.28; }
    const jF = joueur;
    ajouterVfx(new THREE.Group(), (tt, dt) => {
      if (joueur !== jF) return false;
      joueur.furtifT = (joueur.furtifT || 0) - dt;
      if (Math.random() < 0.4) emettre(V(joueur.pos.x + rnd(-0.4, 0.4), 0.3 + Math.random() * 1.5, joueur.pos.z + rnd(-0.4, 0.4)), { n: 1, c1: '#ff9a9a', c2: '#1a0004', vit: 0.6, vie: 0.5, taille: 0.3 });
      if (joueur.furtifT <= 0) { for (const m of joueur.mats) { m.opacity = 1; m.transparent = false; } joueur._furtifVfx = false; return false; }
    });
  }
}
// attaque de base : coup 1, coup 2, puis au 3e coup on se téléporte dans son dos et on disparaît 1 s
function attaqueAssassin(c, vit) {
  const st = joueur.st;
  joueur.comboPas = G.t - (joueur.dernierCoup || -9) < 1.5 ? ((joueur.comboPas || 0) + 1) % 3 : 0; joueur.dernierCoup = G.t;
  const pas = joueur.comboPas;
  if (pas === 2) teleportDerriere(c);
  const anim = ['1H_Melee_Attack_Slice_Diagonal', '1H_Melee_Attack_Chop', '2H_Melee_Attack_Stab'][pas];
  joueur.jouer(anim, { boucle: false, vitesse: Math.max(1.6, vit * 1.3), forcer: true, fondu: 0.05, fin: () => joueur.jouer(joueur.def.idle) });
  joueur.verrouT = pas === 2 ? 0.3 : 0.2;
  programmer(0.12, () => {
    if (c.mort) return;
    if (dist2D(c.pos, joueur.pos) - c.rayon > st.portee + 1.2) return;
    arcTaille(joueur.pos, joueur.angle - Math.PI / 2, 2.4, pas === 2 ? '#ff1a2a' : '#ffb0b0', Math.PI * 0.6, 0.18);
    blesser(c, (pas === 2 ? 1.45 : 0.85) * furtifBonus(), { c1: '#ff5a6a' }); gagnerCombo(1);
    son(pas === 2 ? 'knifeSlice2' : 'knifeSlice', 0.45, 1.1 + pas * 0.15);
    if (pas === 2 && G.t - (joueur.dernierFurtif || -9) > 4) { joueur.dernierFurtif = G.t; furtif(0.8); UI.nombre(V(joueur.pos.x, 2.8, joueur.pos.z), 'Furtif', 'info'); }
  });
}

// ---------------- Haches de l'Orage ----------------
function arcElectrique(a, b) {
  const n = Math.max(4, Math.round(a.distanceTo(b) * 2));
  for (let i = 0; i <= n; i++) { const t = i / n; const p = a.clone().lerp(b, t); p.x += rnd(-0.25, 0.25) * Math.sin(t * Math.PI); p.y += rnd(-0.25, 0.25) * Math.sin(t * Math.PI); emettre(p, { n: 1, c1: '#ffffff', c2: '#5a9aff', vit: 0.4, vie: 0.22, taille: 0.32 }); }
}
function chaineEclair(depart, n, mult) {
  const touches = new Set([depart]); let cur = depart;
  for (let k = 0; k < n; k++) {
    let best = null, bd = 6.5; for (const e of vivants()) { if (touches.has(e)) continue; const d = dist2D(e.pos, cur.pos); if (d < bd) { bd = d; best = e; } }
    if (!best) break; touches.add(best);
    arcElectrique(V(cur.pos.x, 1.2, cur.pos.z), V(best.pos.x, 1.2, best.pos.z));
    blesser(best, mult, { silence: true, c1: '#bfe0ff' }); cur = best;
  }
  if (touches.size > 1) son('impactGeneric_light_000', 0.35, 1.8);
}
function eclairCiel(e, mult) {
  const p = V(e.pos.x, 0, e.pos.z);
  arcElectrique(V(p.x + rnd(-1, 1), 14, p.z + rnd(-1, 1)), V(p.x, 0.4, p.z));
  lueurSol(p, '#8ab8ff', 2.4, 0.3, 1.5); onde(p, '#bfe0ff', 2.6, 0.3);
  blesser(e, mult, { stun: 0.25, c1: '#ffffff', c2: '#3a6aff' }); chaineEclair(e, 1, mult * 0.5);
  son('explosionCrunch_000', 0.25, 1.9); G.shake = Math.max(G.shake, 0.15);
}
function tirageOrage(t) {
  if (Math.random() >= (G.chanceOrage ?? CHANCE_ORAGE)) return false;
  const it = creerArme('orage', t, 2 + (Math.random() < 0.3 ? 1 : 0));
  J.maitrise.orage = J.maitrise.orage || { niv: 1, xp: 0 };
  setTimeout(() => { ajouterSac(it, true); sauver(); annonceRare(`${nomObjet(it)} · T${t}`, 'Classe légendaire : une chance sur cent'); UI.chat('Système', `${J.nom} vient d’obtenir ${nomObjet(it)} (T${t}) !`); }, 1400);
  return true;
}

// ---------------- Classe des Ombres ----------------
function utiliserCode(brut) {
  const c = String(brut || '').trim().toUpperCase().replace(/\s+/g, '');
  if (c.normalize('NFKD').replace(/[^A-Z0-9]/gi, '').toUpperCase() === 'THOMAS83') {
    J.escouade = !J.escouade;
    if (J.escouade) { J.escStats = { debut: Date.now(), argent0: J.argent, xp: 0, kills: 0, coffres: 0 }; annonceRare('Escouade d’ombres', '6 ombres te suivent partout · compteur de gains lancé'); }
    else { viderEscouade(); UI.escouadeHud(null); }
    sauverMaintenant();
    return { ok: true, texte: J.escouade ? 'Escouade d’ombres activée (retape le code pour la renvoyer).' : 'Escouade d’ombres renvoyée.' };
  }
  const def = CODES_BETA[c];
  if (!def) { son('error_001', 0.4); return { ok: false, texte: 'Code inconnu.' }; }
  J.codes = J.codes || [];
  if (def.tous) { // code réutilisable : toute la gamme pour tester
    J.maitrise[def.arme] = J.maitrise[def.arme] || { niv: 1, xp: 0 }; J.maitrise[def.arme].niv = Math.max(90, J.maitrise[def.arme].niv);
    J.debloques = [...new Set([...(J.debloques || []), def.arme])];
    for (let t = 1; t <= 8; t++) { const it = creerArme(def.arme, t, 2); it.beta = true; ajouterSac(it, true); }
    sauverMaintenant(); annonceRare(ARMES[def.arme].label, 'T1 à T8 ajoutées au sac · maîtrise niveau 90');
    return { ok: true, texte: def.texte };
  }
  if (J.codes.includes(c)) return { ok: false, texte: 'Ce code a déjà été utilisé sur ce profil.' };
  J.codes.push(c);
  const it = creerArme(def.arme, def.tier, 0); it.beta = true;
  J.maitrise[def.arme] = J.maitrise[def.arme] || { niv: 1, xp: 0 };
  ajouterSac(it, true); sauverMaintenant();
  annonceRare('Dagues des Ombres', 'Accès bêta débloqué : équipe-les depuis ton sac');
  return { ok: true, texte: def.texte + ' — ajoutées à ton sac !' };
}
function annonceRare(titre, sous) {
  const d = document.createElement('div'); d.className = 'annonceRare';
  d.innerHTML = `<h2>${titre}</h2><p>${sous}</p>`; document.body.appendChild(d); setTimeout(() => d.remove(), 4600);
  son('jingle_legend', 0.7); G.shake = 0.6;
  if (joueur) { onde(joueur.pos, '#9a5aff', 8, 1); emettre(V(joueur.pos.x, 1.4, joueur.pos.z), { n: 120, c1: '#e8d0ff', c2: '#3a0a6a', vit: 8, vie: 1.4, taille: 0.5, grav: 2 }); }
}
// 0,1 % de chance sur chaque boss et chaque victoire PvP
function tirageOmbre(tMin, tMax, source) {
  if (Math.random() >= (G.chanceOmbre ?? CHANCE_OMBRE)) return false;
  const t = Math.max(1, Math.min(8, tMin + Math.floor(Math.random() * (tMax - tMin + 1))));
  const it = creerArme('ombre', t, Math.random() < 0.5 ? 1 : 2);
  J.maitrise.ombre = J.maitrise.ombre || { niv: 1, xp: 0 };
  setTimeout(() => {
    ajouterSac(it, true); sauver();
    annonceRare(`${nomObjet(it)} · T${t}`, source === 'pvp' ? 'Arraché à un adversaire : une chance sur mille' : 'Tombé d’un boss : une chance sur mille');
    UI.chat('Système', `${J.nom} vient d’obtenir ${nomObjet(it)} (T${t}) !`);
  }, 1200);
  return true;
}
// une ombre = 25 % de ta puissance, +2 % par tier au-dessus du T1, +3 % par enchantement
function forceOmbre() { const a = J.equip.arme || { tier: 1 }; return 0.25 + (a.tier - 1) * 0.02 + (a.ench || 0) * 0.03; }
function vitesseJoueur() { return joueur.st.vitesse * (joueur.sprintT > 0 ? 1.6 : 1) * (joueur.slowT > 0 ? 0.6 : 1); }
function fumeeOmbre(p) {
  emettre(V(p.x, 0.8, p.z), { n: 26, c1: '#b48aff', c2: '#0a0012', vit: 3.5, rayon: 0.6, vie: 0.7, taille: 0.6, grav: -1 });
  lueurSol(p, '#7a3aff', 1.8, 0.4, 0.6);
}
function teinteSpectrale(a, couleur, force) {
  for (const mt of a.mats) {
    mt.color.lerp(new THREE.Color(couleur), force);
    if (mt.emissive) { mt.emissive.set('#6a2aff').multiplyScalar(0.35); mt.userData.baseEmissive = mt.emissive.clone(); }
  }
}
function invoquerOmbres(n) {
  for (const a of allies.filter(x => x.invoc === 'ombre')) dissiper(a);
  const st = joueur.st;
  son('forceField_000', 0.5, 0.6); onde(joueur.pos, '#9a5aff', 5, 0.7);
  for (let i = 0; i < n; i++) {
    const ang = joueur.angle + Math.PI + (i - (n - 1) / 2) * (Math.PI * 1.6 / Math.max(1, n));
    const pos = pointLibrePres(V(joueur.pos.x + Math.sin(ang) * 2.4, 0, joueur.pos.z + Math.cos(ang) * 2.4), 0, 1.2);
    const a = creerCombattant(pos, { nom: 'Ombre', guilde: J.nom.toUpperCase(), equip: J.equip, modele: 'Rogue_Hooded' }, 'allie');
    UI.retirerPlaque(a);
    Object.assign(a, { invoc: 'ombre', vieT: 60, potions: 0, cdRempart: 1e9, specT: rnd(2, 5), ip: undefined });
    const fo = forceOmbre(); a.pvMax = a.pv = Math.round(st.pvMax * fo); a.dmg = st.degats * fo; a.reduction = st.reduction * 0.6; a.vieT = 60 + (J.equip.arme.ench || 0) * 5;
    a.root.scale.setScalar(0.9);
    teinteSpectrale(a, '#140c20', 0.8);
    UI.plaque(a, { nom: 'Ombre', guilde: '60 s', classe: 'allie', vie: true, lettre: false });
    fumeeOmbre(pos);
    a.jouer('Spellcast_Raise', { boucle: false, fin: () => a.jouer(a.armeDef.idle) });
  }
}
function invoquerReflet(cible) {
  for (const a of allies.filter(x => x.invoc === 'reflet')) dissiper(a);
  const pos = pointLibrePres(V((joueur.pos.x + cible.pos.x) / 2, 0, (joueur.pos.z + cible.pos.z) / 2), 0, 1.5);
  let a;
  const nom = 'Reflet de ' + (cible.nom || cible.def.nom);
  if (cible.combattant) {
    a = creerCombattant(pos, { ...cible.data, nom, guilde: 'OMBRE DE ' + J.nom.toUpperCase() }, 'allie');
    UI.retirerPlaque(a);
    Object.assign(a, { potions: 0, cdRempart: 1e9 });
  } else {
    const def = cible.def, dragon = def.model === 'Dragon_Evolved';
    a = new Acteur(def.model, { hauteur: dragon ? 3.2 : 2.0, echelle: cible.boss && !dragon ? Math.min(1.35, cible.boss.scale * 0.8) : 1 });
    if (def.arme) a.attacher(def.arme, 'handslot.r');
    a.root.position.copy(pos); G.scene.add(a.root);
    Object.assign(a, { def, refletMob: true, dragon, camp: 'allie', pos: a.root.position, angle: 0, mort: false, stunT: 0, slowT: 0, dots: [], atkT: 0.5, attaqueT: 0,
      rayon: Math.max(0.5, (cible.rayon || 0.6) * 0.8), hauteurPlaque: dragon ? 3.8 : (cible.hauteurPlaque || 2.5) * 0.85, hover: dragon ? 0.6 : 0, reduction: 0.25, nom,
      armeDef: { idle: dragon ? 'Flying_Idle' : 'Idle_Combat', run: dragon ? 'Fast_Flying' : 'Running_A' }, vitesse: (def.vitesse || 3.6) * 1.05, portee: def.type === 'ranged' || def.type === 'caster' ? 9 : (def.portee || 2.2) });
    a.root.position.y = a.hover;
    allies.push(a);
  }
  Object.assign(a, { invoc: 'reflet', vieT: 30 });
  const ar = J.equip.arme, pr = 0.15 + (ar.tier - 1) * 0.01 + (ar.ench || 0) * 0.02;
  a.pvMax = a.pv = Math.max(50, Math.round(cible.pvMax * pr));
  a.energieMax = a.energie = Math.round((cible.st ? cible.st.energieMax : 200) * pr);
  a.dmg = (cible.dmg || joueur.st.degats) * (0.45 + (ar.tier - 1) * 0.03 + (ar.ench || 0) * 0.04);
  a.vieT = 30 + (ar.ench || 0) * 2;
  teinteSpectrale(a, '#b48aff', 0.45);
  UI.plaque(a, { nom, guilde: '30 s', classe: 'allie', vie: true, lettre: false });
  fumeeOmbre(pos); onde(pos, '#c9a0ff', 4, 0.6); son('forceField_000', 0.6, 0.5);
  // le reflet sort du corps de la cible
  emettre(V(cible.pos.x, 1.2, cible.pos.z), { n: 40, c1: '#ffffff', c2: '#7a3aff', vit: 5, vie: 0.6, taille: 0.4 });
  UI.nombre(V(cible.pos.x, (cible.hauteurPlaque || 2.5) + 0.4, cible.pos.z), 'Reflet volé', 'crit');
  volerPouvoir(cible, a);
}
// tant que le double vit, le joueur dispose d'un pouvoir de la cible copiée (à la place de Reflet volé)
function pouvoirDe(c) {
  if (c.combattant && c.equip) { const ids = sortsArme(c.equip.arme).filter(id => id !== 'legion' && id !== 'reflet'); return ids[ids.length - 1] || 'fente'; }
  const d = c.def || {};
  if (d.model === 'Dragon_Evolved') return 'meteore';
  if (d.type === 'ranged') return c.boss ? 'pluie' : 'perforant';
  if (d.type === 'caster') return c.boss ? 'meteore' : 'bouleFeu';
  return c.boss ? 'tempete' : 'charge';
}
function volerPouvoir(cible, double) {
  const id = pouvoirDe(cible); const s = SORTS[id]; if (!s) return;
  joueur.pouvoirVole = { double, finReflet: G.t + (joueur.cdMax.W || 40), sortReflet: joueur.sorts.W, cdMaxReflet: joueur.cdMax.W };
  joueur.sorts.W = { ...s, id, vole: true, nom: s.nom + ' (volé)' };
  joueur.cdMax.W = +(s.cd * (1 - joueur.st.recharge / 100)).toFixed(2); joueur.cds.W = 0;
  UI.construireSorts(joueur);
  UI.toast(`Pouvoir volé : ${s.nom} — tant que le double vit`, true);
  son('forceField_000', 0.6, 1.6); emettre(V(joueur.pos.x, 1.4, joueur.pos.z), { n: 50, c1: '#f0d0ff', c2: '#7a2aff', vit: 4, vie: 0.9, taille: 0.45, monte: 3 });
}
function rendrePouvoir() {
  const pv = joueur && joueur.pouvoirVole; if (!pv) return;
  joueur.sorts.W = pv.sortReflet; joueur.cdMax.W = pv.cdMaxReflet; joueur.cds.W = Math.max(0, pv.finReflet - G.t);
  joueur.pouvoirVole = null; UI.construireSorts(joueur);
  UI.toast('Le double s’efface : pouvoir volé perdu');
}
function majRefletMob(a, dt) {
  a.tc = cibleIA(a); a.atkT -= dt;
  const c = a.tc;
  if (a.attaqueT > 0) { a.attaqueT -= dt; return; }
  if (!c) {
    const dj = dist2D(a.pos, joueur.pos);
    if (dj > 16) { fumeeOmbre(a.pos); a.pos.copy(pointLibrePres(joueur.pos, 1.5, 3)); fumeeOmbre(a.pos); }
    else if (dj > 3) { avancerVers(a, joueur.pos, dt, Math.max(a.vitesse, vitesseJoueur()) * (dj > 6 ? 1.3 : 1.05)); a.jouer(a.armeDef.run); }
    else a.jouer(a.armeDef.idle);
    return;
  }
  const d = dist2D(a.pos, c.pos);
  if (d > a.portee + (c.rayon || 0.5)) { avancerVers(a, c.pos, dt, Math.max(a.vitesse, vitesseJoueur())); a.jouer(a.armeDef.run); return; }
  faceJoueur(a, dt, 10);
  if (a.atkT > 0) { a.jouer(a.armeDef.idle); return; }
  a.atkT = 1.15; a.attaqueT = 0.35;
  const distance = a.portee > 5;
  const anim = a.dragon ? (Math.random() < 0.5 ? 'Punch' : 'Headbutt') : distance ? 'Spellcast_Shoot' : (Math.random() < 0.5 ? '1H_Melee_Attack_Chop' : '2H_Melee_Attack_Chop');
  a.jouer(anim, { boucle: false, forcer: true, vitesse: 1.3, fin: () => a.jouer(a.armeDef.idle) });
  programmer(0.3, () => {
    if (a.mort || c.mort) return;
    if (distance) { const p = V(c.pos.x, 1.1, c.pos.z); for (let k = 0; k < 6; k++) { const t = k / 6; emettre(V(a.pos.x + (p.x - a.pos.x) * t, 1.2, a.pos.z + (p.z - a.pos.z) * t), { n: 2, c1: '#e0c8ff', c2: '#5a1aaa', vit: 1, vie: 0.3, taille: 0.3 }); } }
    else arcTaille(a.pos, a.angle - Math.PI / 2, 2.6, '#b07aff', Math.PI * 0.7, 0.22);
    infliger(a, c, a.dmg); son('knifeSlice', 0.35, 0.8);
  });
}
// une ombre qui meurt explose et blesse tout autour
function mortInvocation(a) {
  if (a.invoc === 'ombre') {
    onde(a.pos, '#9a5aff', 3.4, 0.45); emettre(V(a.pos.x, 1, a.pos.z), { n: 40, c1: '#e0c8ff', c2: '#2a0050', vit: 7, vie: 0.6, taille: 0.5 });
    toucherZone(a, a.pos, 3.2, a.dmg * 1.6, { slow: 1.5 }); son('explosionCrunch_000', 0.35, 1.4);
  }
  dissiper(a);
}
function dissiper(a) {
  if (joueur && joueur.pouvoirVole && joueur.pouvoirVole.double === a) rendrePouvoir();
  const i = allies.indexOf(a); if (i < 0) return;
  allies.splice(i, 1); a.mort = true;
  fumeeOmbre(a.pos); UI.retirerPlaque(a); G.scene.remove(a.root);
  if (joueur && joueur.cible === a) joueur.cible = null;
}

// accès de débogage (console)
window.__jeu = { get dangers() { return dangers; }, creerCoffre: (p, c, b) => creerCoffre(p, c, b), entrerArene, construireJoueur: () => construireJoueur(joueur.pos.clone()), get entree() { return entree; }, API, G, UI, tirageOrage, changerRang, apparitionErrant, get errant() { return errant; }, tuerUn: (e) => { e.pv = 0; tuer(e); }, groupeTest: () => { groupe = donneesBot(statsHeros(J.equip).ip); return groupe.nom; }, trahir: () => allies.forEach(a => a.autonome && trahir(a)), invasionTest: () => { invasion = { mode: "subie", t: 0, rival: null }; lancerInvasion(); }, entrerSylve: (o) => entrerSylve(o), get sylve() { return sylve; }, invoquerOmbres, tirageOmbre, hub: () => lancerHub(), majRaids, get raid() { return raid; }, entrerDonjon, entrerIle, lancerAssaut: () => lancerAssaut(monde.ile), majAssauts, get iles() { return J.iles; }, get monde() { return monde; }, set raidT(v) { J.prochainRaid = v; }, tuerTout: () => ennemis.forEach(e => { if (!e.mort) { e.pv = 0; tuer(e); } }), get bots() { return bots; }, get allies() { return allies; }, get arene() { return arene; }, ecran: (p) => projeter(V(p.x, 1.2, p.z)), get invasion() { return invasion; }, set invasion(v) { invasion = v; }, lancerSort, ouvrirCoffre, get joueur() { return joueur; }, get ennemis() { return ennemis; }, get coffres() { return coffres; }, get J() { return J; }, get monde() { return monde; } };

initEntrees();
demarrer();
