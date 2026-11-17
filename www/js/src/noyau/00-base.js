// ===== Brèche Écarlate — boucle de jeu =====
import { THREE, G, initRendu, majCamera, rendre, majTorches, chargerAssets, chargerSons, son, ambiance, Acteur, cloner,
  emettre, majParticules, majVfx, ajouterVfx, onde, lueurSol, arcTaille, faisceau, telegraphe, meshCarreau, meshBoule, DIR_HAUT, DIR_DROITE, projeter, creerArc, solY, cor, texRond, texRunes, texFissures, redimensionner, appliquerNiveau, majQualiteAuto, majResolution, mesurerDemarches, musique, musiqueActive, musiquePause } from './engine.js';
import { construireTerres, construireAncestrales, construireIleAnc, construireTaverne, construireGoulet, construireHub, construireDonjon, construireArene, construireIle, construireDomaine, nbEmplacements, majFeux, noeudReel, creerAssetsProc, construireSylve } from './world.js';
import { UI, iconeObjet, bustePersonnage, TEINTES_OMBRE } from './ui.js';
import { initGestes } from './gestes.js';
import { Loup, portraitLoup } from './loups.js';
import { arbreDe, effetsTalents, pointsTotaux, pointsDepenses, ALTS } from './talents.js';
import { DOMAINE_NIVEAUX, PRIX_DOMAINE, SERVITEURS, PAROLES_SERVITEURS, APPARAT, CHOC_AURA, EXPLOITS, TITRES_RENOM, PAROLES_PNJ, RUMEURS_CHAT, REPLIQUES, ARTEFACTS, RARETES_RELIQUE, COMPAGNONS, TAVERNE_LIGNES, RIVAL_TAVERNE, FACTIONS, MISSIONS, CLASSES_BASE, TIERS, ARMES, ARMURES, SORTS, MODES, COFFRES, BOSS, MOBS, BOTS, CHAT, tf, MAITRISES, NIVEAU_REQUIS, ILE_TYPES, ILE_TAILLES, ILE_NIVEAUX, BATIMENTS, GARDES_ILE, CHAMPION_ILE, HEURE_ASSAUT, RESSOURCES, CHANCE_OMBRE, CODES_BETA, CHANCE_ORAGE, MOBS_SYLVE, BOSS_SYLVE, TRAITS, RANGS, PTS_RANG, GAIN_RANG, PERTE_RANG, BOSS_ERRANT, PARCHEMINS, COULEURS_PARCH, DUREE_PARCH, BOUTIQUE_PARCH_GRATUITE } from './data.js';
import { creerParchemin, creerArme, creerArmure, creerPotion, statsHeros, nomObjet, valeurObjet, prixVente, lootCoffre, lootMonstre, tirerCouleurCoffre, ETAT, coutEnchant, ENCH_MAX, creerButin, xpPour, peutPorter, niveauRequis, niveauDe, sortsArme, prixTrophees, bonusMaitrise, niveauHeros } from './items.js';

const $ = (s) => document.querySelector(s);
const rnd = (a, b) => a + Math.random() * (b - a);
const ri = (a, b) => a + Math.floor(Math.random() * (b - a + 1));
const V = (x = 0, y = 0, z = 0) => new THREE.Vector3(x, y, z);
const dist2D = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);

// ---------------- Sauvegarde ----------------
let J = null;
const CLE = 'breche-ecarlate-v1';
// Version 1.0 recentrée : Place + Brèche (3 donjons, 4 boss). Les autres modes sont gelés, pas supprimés : mettre false pour les rallumer.
const V1 = true;
if (V1) document.body.classList.add('v1');
// sauvegarde groupée : au plus une écriture toutes les 1,5 s (l’écriture disque fait des micro-freezes sur Android)
let sauverT = null, efface = false;
function sauverMaintenant() { if (efface) return; if (sauverT) { clearTimeout(sauverT); sauverT = null; } try { localStorage.setItem(CLE, JSON.stringify(J)); } catch (e) {} }
function sauver() { if (sauverT) return; let essais = 0;
  const go = () => { if (G.enCombat && ++essais < 6) { sauverT = setTimeout(go, 5000); return; } if (window.requestIdleCallback) requestIdleCallback(sauverMaintenant, { timeout: 3000 }); else sauverMaintenant(); };
  sauverT = setTimeout(go, 12000); }
addEventListener('pagehide', sauverMaintenant); document.addEventListener('visibilitychange', () => { try { if (G.audio) document.hidden ? G.audio.suspend() : G.audio.resume(); } catch (e) {} musiquePause(document.hidden); }); document.addEventListener('visibilitychange', () => { if (document.hidden) sauverMaintenant(); });
function charger() { try { const s = localStorage.getItem(CLE); return s ? JSON.parse(s) : null; } catch (e) { return null; } }
function nouvellePartie(nom, arme) {
  J = { nom, argent: 400, potions: 5, trophees: 0, sac: [], equip: {
    arme: creerArme(arme, 1, 0), casque: creerArmure('casque', 1, 0), plastron: creerArmure('plastron', 1, 0), bottes: creerArmure('bottes', 1, 0) } };
  for (const a of CLASSES_BASE) if (a !== arme) J.sac.push(creerArme(a, 1, 0));
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
  // nouvelle classe : un arc T1 offert aux anciennes sauvegardes
  if (!J.arcOffert) { J.arcOffert = true; if (J.equip.arme && J.equip.arme.type !== 'arc' && !J.sac.some(it => it.cat === 'arme' && it.type === 'arc')) { J.sac.push(creerArme('arc', 1, 0)); setTimeout(() => UI.toast('Nouvelle classe : un Arc du Maître des bêtes t’attend dans ton sac', true), 2500); } }
  J.talents = J.talents || {}; J.slotsTalent = J.slotsTalent || {};
  J.taverne = J.taverne || { lien: {}, respect: {}, missions: 0, offres: null };
  if (n) setTimeout(() => UI.toast(`${n} pièce${n > 1 ? 's' : ''} trop haute${n > 1 ? 's' : ''} pour ta maîtrise rangée${n > 1 ? 's' : ''} dans le sac`), 1500);
}

// ---------------- État ----------------
let monde = null, joueur = null, ennemis = [], bots = [], projectiles = [], minuteries = [], coffres = [], marchand = null, sortie = null;
let invasion = null, arene = null, groupe = null, selection = null;
let allies = [];
const meute = []; let loupChoisi = null; // Maître des bêtes : les 3 loups et celui qu'on envoie en ruée
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
  ['Dragon_Evolved', 'assets/chars/Dragon_Evolved.json'], ['d_wall_doorway', 'assets/chateau/d_wall_doorway.json'], ['d_coin', 'assets/chateau/d_coin.json'],
  ...['Skeleton_Blade', 'Skeleton_Axe', 'Skeleton_Staff', 'Skeleton_Crossbow', 'Skeleton_Shield_Large_A'].map(k => [k, `assets/props/${k}.json`]),
  ...['floor_tile_large', 'floor_tile_large_rocks', 'floor_dirt_large', 'wall', 'wall_corner', 'wall_arched', 'wall_broken', 'pillar', 'pillar_decorated', 'column', 'torch_mounted', 'banner_patternA_red', 'banner_thin_red', 'banner_patternB_red',
    'barrel_large', 'barrel_small_stack', 'box_stacked', 'crates_stacked', 'table_long_decorated_A', 'table_long_tablecloth_decorated_A', 'shelves', 'shelf_small_candles', 'candle_triple', 'candle_lit', 'coin_stack_large',
    'rubble_large', 'rubble_half', 'sword_shield_broken', 'keg_decorated', 'trunk_large_A', 'barrier', 'stairs_wide', 'chest', 'chest_gold'].map(k => [k, `assets/env/${k}.json`]),
  ...['hex_grass', 'hex_water', 'b_home_A', 'b_home_B', 'b_tavern', 'b_lumbermill', 'b_mine', 'b_market', 'b_well', 'b_windmill', 'b_tower_A', 'flag_yellow', 'barrel', 'crate_A_big', 'sack', 'tent',
    'Tree_1_A', 'Tree_2_B', 'Tree_3_A', 'Tree_4_A', 'Bush_2_C', 'Rock_1_A', 'Rock_3_C', 'Grass_1_A', 'Wood_Log_A', 'Wood_Log_Stack', 'Iron_Nuggets', 'Gold_Nuggets', 'Copper_Nuggets', 'Stone_Chunks_Large',
    'tool_axe', 'tool_pickaxe', 'tool_lantern', 'crop_carrot', 'crop_pumpkin', 'crop_melon', 'flower_redA', 'flower_yellowA', 'flower_purpleA', 'ground_pathTile'].map(k => [k, `assets/ile/${k}.json`]),
];
// château du domaine (kits Kenney Castle / Fantasy Town et portes KayKit) : chargés à la première visite
const ASSETS_CHATEAU = ['c_bridge_draw', 'c_flag_banner_long', 'c_flag_pennant', 'c_flag_wide', 'c_gate', 'c_metal_gate', 'c_rocks_large', 'c_siege_ballista', 'c_siege_catapult', 'c_stairs_stone', 'c_tower_base', 'c_tower_hexagon_base', 'c_tower_hexagon_mid', 'c_tower_hexagon_roof', 'c_tower_hexagon_top', 'c_tower_square_base', 'c_tower_square_mid', 'c_tower_square_mid_windows', 'c_tower_square_roof', 'c_tower_square_top_roof_high', 'c_tower_top', 'c_tree_large', 'c_wall', 'c_wall_corner', 'c_wall_doorway', 'c_wall_half', 'c_wall_pillar', 'c_bridge_straight', 'c_stairs_stone_square',
  'd_banner_shield_red', 'd_banner_triple_red', 'd_coin_stack_medium', 'd_stairs_walled', 'd_sword_shield_gold', 'd_torch_lit', 'd_wall_window_open',
  't_banner_red', 't_cart', 't_fountain_round', 't_fountain_round_detail', 't_hedge', 't_hedge_curved', 't_hedge_large', 't_lantern', 't_pillar_stone', 't_stairs_wide_stone_handrail', 't_stall_red'];
let assetsChateauPrets = false;
const ASSETS_SYLVE = ['n_statue_ring', 'n_statue_head', 'n_statue_obelisk', 'n_statue_column', 'n_statue_columnDamaged', 'n_mushroom_red', 'n_mushroom_redGroup', 'n_mushroom_redTall', 'n_mushroom_tan', 'n_mushroom_tanGroup', 'n_mushroom_tanTall', 'n_lily_large', 'n_lily_small', 'n_log_large', 'n_stump_old', 'n_plant_bushLarge', 'n_plant_bushDetailed', 'n_plant_flatTall', 'n_flower_purpleB', 'n_flower_purpleC', 'n_flower_redC', 'n_flower_yellowC', 'n_tree_oak', 'n_tree_detailed', 'n_tree_default', 'n_tree_fat_darkh', 'n_rock_largeB', 'n_rock_largeC', 'n_stone_tallB', 'n_stone_tallG', 'n_stone_largeC', 'n_campfire_stones', 'Bush_4_A', 'Bush_3_B', 'Tree_2_C', 'Tree_3_B', 'Rock_2_C', 'Tree_Bare_2_A'];
const SONS = ['knifeSlice', 'knifeSlice2', 'drawKnife2', 'handleCoins', 'creak1', 'doorOpen_1', 'metalLatch', 'cloth1', 'bookOpen', 'impactPlate_heavy_000', 'impactMetal_medium_001', 'impactGeneric_light_000',
  'footstep_concrete_000', 'footstep_concrete_001', 'click_001', 'open_001', 'close_001', 'confirmation_001', 'error_001', 'select_001', 'maximize_001', 'thrusterFire_000', 'explosionCrunch_000', 'lowFrequency_explosion_000', 'forceField_000',
  'jingle_win', 'jingle_loot', 'jingle_legend', 'chop', 'impactMining_000', 'impactMining_001', 'impactPlank_medium_000', 'handleSmallLeather'].map(k => [k, `assets/audio/${k}.ogg`]);

async function demarrer() {
  initRendu($('#scene'));
  try { const dc = localStorage.getItem('breche-decal'); if (dc !== null) document.documentElement.style.setProperty('--decalSorts', dc + 'vw'); } catch (e) {}
  try { if (!localStorage.getItem('breche-v169')) { localStorage.setItem('breche-v169', '1'); localStorage.setItem('breche-qualite', 'haute'); localStorage.setItem('breche-cam', 'normale'); localStorage.setItem('breche-vue', 'iso'); localStorage.setItem('breche-zoom', '1'); } } catch (e) {}
  try { if (!localStorage.getItem('breche-v220')) { localStorage.setItem('breche-v220', '1'); localStorage.setItem('breche-v161', '1'); localStorage.setItem('breche-vue', 'libre'); localStorage.setItem('breche-zoom', '0.8'); } // caméra libre « à la Roblox » par défaut
  G.camSens = +(localStorage.getItem('breche-sens') || 1);
  if (!localStorage.getItem('breche-v161')) { localStorage.setItem('breche-v161', '1'); localStorage.setItem('breche-vue', 'iso'); localStorage.setItem('breche-zoom', '1'); } G.camVue = localStorage.getItem('breche-vue') || 'libre'; G.camMode = localStorage.getItem('breche-cam') || 'normale'; G.ombresParole = localStorage.getItem('breche-ombres') || 'normal'; G.camZoom = +(localStorage.getItem('breche-zoom') || 1); } catch (e) {}
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
    mesurerDemarches(['Knight', 'Rogue', 'Rogue_Hooded', 'Barbarian', 'Mage', 'Skeleton_Minion', 'Skeleton_Warrior', 'Skeleton_Rogue', 'Skeleton_Mage']);
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
    $('#choixArme').innerHTML = CLASSES_BASE.map(a => `<button data-a="${a}" class="${a === 'epee' ? 'actif' : ''}"><img src="${iconeObjet({ cat: 'arme', type: a, tier: 1 })}" alt="">${ARMES[a].label}</button>`).join('');
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
  // variantes courantes créées en plein jeu (bulle, icônes, éclats sans texture) : compilées une fois pour toutes
  bulle({ pos: p, mort: false }, () => true);
  const geoW = new THREE.PlaneGeometry(1, 1);
  objs.push(new THREE.Sprite(new THREE.SpriteMaterial({ map: texRond(), transparent: true, depthWrite: false })),
    new THREE.Mesh(geoW, new THREE.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.5, depthWrite: false })),
    new THREE.Mesh(geoW, new THREE.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.5, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide })),
    new THREE.Mesh(geoW, new THREE.MeshBasicMaterial({ color: '#ffffff' })),
    new THREE.Mesh(geoW, new THREE.MeshStandardMaterial({ color: '#ffffff', emissive: '#ffffff', flatShading: true, metalness: 0.5, roughness: 0.3 })));
  for (const o of objs) { o.position.copy(p); G.scene.add(o); }
  G.renderer.compile(G.scene, G.camera);
  for (const o of objs) G.scene.remove(o);
}

// ---------------- Joueur ----------------
function construireJoueur(pos) {
  { const b = document.getElementById('btnArmes'); if (b) b.classList.remove('actif'); }
  const ancienPos = pos || (joueur ? joueur.root.position.clone() : V());
  const ancienAngle = joueur ? joueur.angle : Math.PI * 1.25;
  if (joueur) { G.scene.remove(joueur.root); UI.retirerPlaque(joueur); try { libererGPU([joueur.root]); } catch (e) {} }
  const arme = J.equip.arme || creerArme('epee', 1);
  const def = ARMES[arme.type];
  const a = new Acteur(def.model, { hauteur: 2.0 });
  tenue(a); a.tenueCouleur(def.ombre || def.assassin || !J.equip.plastron ? null : TENUE_TIER[J.equip.plastron.tier]);
  // ne montrer que l'arme portée
  const tous = Object.keys(a.nodes).filter(n => /Sword|Axe|Shield|Crossbow|Staff|Wand|Knife|Throwable|Mug|Spellbook/.test(n));
  a.montrerSeul([def.node, def.node2].filter(Boolean), tous);
  if (def.procedural) { const arc = creerArc(TIERS[arme.tier].color, TIERS[arme.tier].glow); arc.scale.setScalar(0.8); arc.rotation.set(0, Math.PI / 2, Math.PI / 2); const os = a.nodes['handslotl'] || a.nodes['handslot.l']; if (os) os.add(arc); a.nodes.Arc = arc; }
  else { a.teinter(def.node, TIERS[arme.tier].color, 0.62, TIERS[arme.tier].glow); if (def.node2) a.teinter(def.node2, TIERS[arme.tier].color, 0.62, TIERS[arme.tier].glow); }
  // tenue : on garde les matières d'origine du modèle (plus de « plastique » coloré) ; seul le tissu de la cape porte la couleur du tier
  if (def.helmet && a.nodes[def.helmet]) a.nodes[def.helmet].visible = false;
  if (J.equip.plastron && def.cape) a.teinter(def.cape, TIERS[J.equip.plastron.tier].color, 0.42, 0);
  if (def.ombre) habitOmbre(a, def);
  if (def.assassin) habitAssassin(a, def);
  if (def.demon) a.tenueCouleur('#3a0008');
  G.scene.add(a.root);
  a.root.position.copy(ancienPos);
  const st = statsJoueur();
  const j = joueur && joueur.pv !== undefined ? joueur : {};
  joueur = Object.assign(a, {
    pos: a.root.position, angle: ancienAngle, armeType: arme.type, def,
    pv: Math.min(j.pv ?? st.pvMax, st.pvMax), energie: Math.min(j.energie ?? st.energieMax, st.energieMax),
    bouclier: 0, bouclierT: 0, soinT: 0, sprintT: 0, slowT: 0, vampT: 0, bonusTir: false, invuln: 0, spinT: 0, verrouT: 0, dashT: 0,
    cds: j.cds || {}, cdMax: {}, sorts: {}, atkT: 0, cible: null, cibleVerrou: j.cibleVerrou || null, mort: false, st, hauteurPlaque: 2.55, combatT: 0, pasT: 0,
  });
  const ss = idsSortsJoueur(arme, st.tal);
  ['Q', 'W', 'E'].forEach((k, i) => { joueur.sorts[k] = sortAvecTalents(ss[i], st.tal); });
  if (J.equip.plastron) joueur.sorts.R = { ...SORTS.rempart, id: 'rempart' };
  if (J.equip.casque) joueur.sorts.D = { ...SORTS.souffle, id: 'souffle' };
  if (J.equip.bottes) joueur.sorts.F = { ...SORTS.ruee, id: 'ruee' };
  if (J.relique) { const sr = sortRelique(J.relique); if (sr) joueur.sorts.A = sr; }
  for (const k in joueur.sorts) joueur.cdMax[k] = +(joueur.sorts[k].cd * (1 - st.recharge / 100)).toFixed(2);
  joueur.cdMax.POT = 60; joueur.potions = J.potions;
  joueur.jouer(def.idle);
  majAffichagePuissance();
  UI.construireSorts(joueur); UI.boutonAuto(API);
  if (modeActuel && G.gestes !== false && !G.aideSignesVue) { G.aideSignesVue = true; setTimeout(() => joueur && UI.aideSignes(joueur.sorts), 1500); }
  $('#nomHud').textContent = J.nom;
  bustePersonnage(def.model, $('#avatarCv'), def.ombre ? '#3a1a5a' : '#5a3a5a', def.ombre ? TEINTES_OMBRE : null);
  joueur.root.rotation.y = joueur.angle;
  assurerMeute(); UI.majBoutonTalents && UI.majBoutonTalents(); majBoutonAura();
  if (G.armesRangees) { joueur.rangee = true; for (const n of noeudsArme()) n.visible = false; joueur.jouer('Idle'); const b = $('#btnArmes'); if (b) b.classList.add('actif'); }
}
function recalculer() { joueur.st = statsJoueur(); joueur.pv = Math.min(joueur.pv, joueur.st.pvMax); }
// statistiques du héros + effets de l'arbre de talents de sa classe
function statsJoueur() {
  const st = statsHeros(J.equip);
  const type = (J.equip.arme || {}).type || 'epee';
  const T = effetsTalents((J.talents || {})[type], type); st.tal = T;
  st.degats = Math.round(st.degats * (1 + (T.deg || 0)));
  st.crit += T.crit || 0; st.vitesseAtk *= 1 + (T.vitAtk || 0);
  st.pvMax = Math.round(st.pvMax * (1 + (T.pv || 0))); st.energieMax = Math.round(st.energieMax * (1 + (T.energie || 0)));
  st.armure *= 1 + (T.armure || 0); st.reduction = st.armure / (st.armure + 320);
  st.regen *= 1 + (T.regen || 0); st.recharge = Math.min(60, st.recharge + (T.rech || 0)); st.vitesse *= 1 + (T.vit || 0); st.pvp += T.pvp || 0;
  if (J.repas && Date.now() < J.repas) { st.pvMax = Math.round(st.pvMax * 1.1); st.degats = Math.round(st.degats * 1.1); }
  if (J.domaine) { if (J.domaine.serviteurs.includes('forgeron')) st.degats = Math.round(st.degats * 1.04); if (J.domaine.serviteurs.includes('ecuyer')) st.vitesse *= 1.05; }
  if (J.repasDomaine && Date.now() < J.repasDomaine) st.pvMax = Math.round(st.pvMax * 1.08);
  if (J.banquet && Date.now() < J.banquet) st.degats *= 1.1;
  if (J.orbeT && Date.now() < J.orbeT) st.degats *= 1.15;
  st.dps = Math.round(st.degats * st.vitesseAtk * (1 + st.crit / 200));
  return st;
}
// un sort avec les bonus de talents (dégâts, recharge)
function sortAvecTalents(id, T) {
  const base = SORTS[id]; if (!base) return null;
  const s = { ...base, id }; T = T || (joueur && joueur.st && joueur.st.tal) || {};
  const cle = base.type === 'meute' ? 'meute' : id;
  if (s.mult) s.mult *= 1 + (T.sorts || 0) + (T['s_' + cle] || 0);
  if (T['cd_' + cle]) s.cd *= 1 - T['cd_' + cle];
  return s;
}
// sorts de la classe, remplacés par les compétences débloquées que le joueur a placées
function idsSortsJoueur(arme, T) {
  const ids = sortsArme(arme);
  const choix = (J.slotsTalent || {})[arme.type] || {};
  ['Q', 'W', 'E'].forEach((k, i) => { if (choix[k] && T.competences.includes(choix[k])) ids[i] = choix[k]; });
  return ids;
}

