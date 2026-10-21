// ===== Données du jeu : tiers, objets, sorts, butin =====

export const TIERS = [
  null,
  { t: 1, roman: 'I',    nom: 'Rouillé',   color: '#9a9184', glow: 0.0 },
  { t: 2, roman: 'II',   nom: 'Bronze',    color: '#c47f3e', glow: 0.0 },
  { t: 3, roman: 'III',  nom: 'Sylvestre', color: '#49c25a', glow: 0.15 },
  { t: 4, roman: 'IV',   nom: 'Azur',      color: '#3f8cff', glow: 0.3 },
  { t: 5, roman: 'V',    nom: 'Braise',    color: '#ff4a2e', glow: 0.55 },
  { t: 6, roman: 'VI',   nom: 'Solaire',   color: '#ffa21c', glow: 0.8 },
  { t: 7, roman: 'VII',  nom: 'Abyssal',   color: '#b153ff', glow: 1.1 },
  { t: 8, roman: 'VIII', nom: 'Céleste',   color: '#fff0b0', glow: 1.5 },
];

export const QUALITES = [
  { id: 0, nom: 'Normal',        mult: 1.00, ip: 0,   color: '#d8d2c4' },
  { id: 1, nom: 'Bon',           mult: 1.07, ip: 20,  color: '#9fd8ff' },
  { id: 2, nom: 'Remarquable',   mult: 1.15, ip: 40,  color: '#7dff9b' },
  { id: 3, nom: 'Excellent',     mult: 1.26, ip: 60,  color: '#d58cff' },
  { id: 4, nom: "Chef-d'œuvre",  mult: 1.40, ip: 100, color: '#ffcf4a' },
];

export const tf = (t) => Math.pow(1.42, t - 1);

// ---- Armes ----
export const ARMES = {
  epee: {
    label: 'Épée à deux mains', court: 'Épée', model: 'Knight', node: '2H_Sword',
    helmet: 'Knight_Helmet', cape: 'Knight_Cape', legs: ['Knight_LegLeft', 'Knight_LegRight'], body: 'Knight_Body',
    portee: 2.7, vitesse: 1.0, base: 32, projectile: null,
    idle: '2H_Melee_Idle', run: 'Running_A',
    attaques: ['2H_Melee_Attack_Slice', '2H_Melee_Attack_Chop'],
    noms: ['', 'Lame rouillée', 'Épée de bronze', 'Claymore sylvestre', "Lame d'azur", 'Fend-braise', 'Espadon solaire', "Brise-l'abysse", 'Aube céleste'],
    sorts: ['fente', 'charge', 'tempete'],
  },
  arbalete: {
    label: 'Arbalète lourde', court: 'Arbalète', model: 'Rogue_Hooded', node: '2H_Crossbow',
    helmet: null, cape: 'Rogue_Cape', legs: ['Rogue_LegLeft', 'Rogue_LegRight'], body: 'Rogue_Body',
    portee: 13, vitesse: 0.9, base: 27, projectile: 'carreau',
    idle: 'Idle', run: 'Running_A',
    attaques: ['2H_Ranged_Shoot'],
    noms: ['', 'Arbalète grinçante', 'Arbalète de bronze', 'Murmure des bois', 'Trait d’azur', 'Crache-braise', 'Rayon solaire', "Gueule de l'abysse", 'Étoile filante'],
    sorts: ['perforant', 'roulade', 'pluie'],
  },
  baton: {
    label: 'Bâton de feu', court: 'Bâton', model: 'Mage', node: '2H_Staff',
    helmet: 'Mage_Hat', cape: 'Mage_Cape', legs: ['Mage_LegLeft', 'Mage_LegRight'], body: 'Mage_Body',
    portee: 12, vitesse: 0.8, base: 30, projectile: 'feu',
    idle: 'Idle', run: 'Running_A',
    attaques: ['Spellcast_Shoot'],
    noms: ['', 'Bâton noueux', 'Bâton de bronze', 'Branche sylvestre', "Sceptre d'azur", 'Bâton de braise', 'Soleil captif', "Œil de l'abysse", 'Flamme céleste'],
    sorts: ['bouleFeu', 'colonne', 'meteore'],
  },
  // classe rare : 0,1 % sur les boss et en PvP, ou code bêta (T1)
  ombre: {
    label: 'Dagues des Ombres', court: 'Ombres', model: 'Rogue_Hooded', node: 'Knife', node2: 'Knife_Offhand', rare: true, ombre: true,
    helmet: null, cape: 'Rogue_Cape', legs: ['Rogue_LegLeft', 'Rogue_LegRight'], body: 'Rogue_Body',
    portee: 2.5, vitesse: 1.3, base: 36, projectile: null,
    idle: 'Idle', run: 'Running_A',
    attaques: ['1H_Melee_Attack_Slice_Diagonal', '1H_Melee_Attack_Chop'],
    noms: ['', 'Dagues de suie', 'Crocs du crépuscule', 'Épines de brume', 'Lames du vide', 'Braises noires', 'Éclipse', "Murmures de l'abysse", 'Néant céleste'],
    sorts: ['legion', 'reflet', 'pasOmbre'],
  },
};
export const CHANCE_OMBRE = 0.001; // 0,1 %
export const CODES_BETA = { 'BRECHE-OMBRE': { arme: 'ombre', tier: 1, texte: 'Accès bêta : Dagues des Ombres T1' } };

export const ARMURES = {
  casque: { label: 'Armure de tête', slot: 'casque', armure: 8, pv: 60, sort: 'souffle',
    noms: ['', 'Casque rouillé', 'Casque de bronze', 'Heaume sylvestre', "Heaume d'azur", 'Heaume de braise', 'Couronne solaire', 'Heaume abyssal', 'Diadème céleste'] },
  plastron: { label: 'Armure de poitrine', slot: 'plastron', armure: 15, pv: 120, sort: 'rempart',
    noms: ['', 'Plastron rouillé', 'Cuirasse de bronze', 'Plastron sylvestre', "Cuirasse d'azur", 'Cuirasse de braise', 'Égide solaire', 'Carapace abyssale', 'Cuirasse céleste'] },
  bottes: { label: 'Armure de pieds', slot: 'bottes', armure: 6, pv: 40, sort: 'ruee',
    noms: ['', 'Bottes rouillées', 'Bottes de bronze', 'Bottes sylvestres', "Grèves d'azur", 'Grèves de braise', 'Sandales solaires', 'Grèves abyssales', 'Pas célestes'] },
};

export const BUTINS = [
  { id: 'os', nom: 'Os brisé', valeur: 6, color: '#cfc6b0', icone: 'os' },
  { id: 'tissu', nom: 'Tissu déchiré', valeur: 10, color: '#8f7d6a', icone: 'tissu' },
  { id: 'crane', nom: 'Crâne fêlé', valeur: 18, color: '#e3dccb', icone: 'crane' },
  { id: 'gemme', nom: 'Gemme terne', valeur: 40, color: '#7aa0a6', icone: 'gemme' },
  { id: 'rune', nom: 'Rune ébréchée', valeur: 75, color: '#c27a4a', icone: 'rune' },
];

// ---- Sorts ----
// type: cone | dash | spin | ligne | roulade | zone | projectile | delai | meteore | bouclier | soin | sprint
export const SORTS = {
  fente:     { nom: 'Fente sanglante', desc: 'Taille en arc devant toi. Les ennemis touchés saignent 3 s.', cd: 4, energie: 18, mult: 1.7, portee: 4.6, type: 'cone', couleur: ['#ff6b5a', '#5a0d12'], glyphe: 'slash' },
  charge:    { nom: 'Charge héroïque', desc: 'Bondis vers la cible, étourdis 1,2 s tout ce qui est autour.', cd: 10, energie: 28, mult: 1.3, portee: 9, type: 'dash', couleur: ['#ffd36b', '#5c3108'], glyphe: 'dash' },
  tempete:   { nom: "Tempête d'acier", desc: 'Tourbillonne 2,4 s et frappe 6 fois autour de toi. Tu peux bouger.', cd: 22, energie: 45, mult: 0.85, portee: 4.2, type: 'spin', couleur: ['#c7d6ff', '#1b2a5c'], glyphe: 'spin' },
  perforant: { nom: 'Carreau perforant', desc: 'Un carreau qui traverse tous les ennemis alignés.', cd: 4, energie: 16, mult: 2.0, portee: 16, type: 'ligne', couleur: ['#9effc4', '#0c4a2a'], glyphe: 'bolt' },
  roulade:   { nom: 'Roulade du chasseur', desc: 'Roule en arrière, intouchable 0,4 s. Ton prochain tir double ses dégâts.', cd: 9, energie: 20, mult: 0, portee: 6, type: 'roulade', couleur: ['#d0f0ff', '#20485c'], glyphe: 'roll' },
  pluie:     { nom: 'Pluie de carreaux', desc: '5 salves sur la zone ciblée. Ralentit de 40 %.', cd: 20, energie: 40, mult: 0.95, portee: 13, type: 'zone', couleur: ['#7dffb0', '#0a3a33'], glyphe: 'rain' },
  bouleFeu:  { nom: 'Boule de feu', desc: 'Projectile qui explose et enflamme les ennemis 3 s.', cd: 3.5, energie: 16, mult: 1.8, portee: 13, type: 'projectile', couleur: ['#ffb84a', '#6a1404'], glyphe: 'fire' },
  colonne:   { nom: 'Colonne de flammes', desc: 'Après 0,8 s, un pilier de feu jaillit et projette les ennemis en l’air.', cd: 9, energie: 30, mult: 2.6, portee: 12, type: 'delai', couleur: ['#ff6a2a', '#4a0606'], glyphe: 'pillar' },
  meteore:   { nom: 'Météore', desc: 'Appelle un météore gigantesque. Le sol brûle ensuite 3 s.', cd: 25, energie: 50, mult: 5.0, portee: 12, type: 'meteore', couleur: ['#ffe27a', '#7a1a00'], glyphe: 'meteor' },
  rempart:   { nom: "Rempart d'Égide", desc: 'Bouclier qui absorbe 25 % de tes PV max pendant 4 s.', cd: 18, energie: 20, mult: 0, type: 'bouclier', couleur: ['#8fd3ff', '#0d2a55'], glyphe: 'shield' },
  souffle:   { nom: 'Second souffle', desc: 'Rend 30 % de tes PV max en 3 s.', cd: 45, energie: 25, mult: 0, type: 'soin', couleur: ['#9dff8a', '#0f3d14'], glyphe: 'heart' },
  execution: { nom: 'Exécution', desc: 'Frappe brutale. Dégâts triplés si la cible a moins de 35 % de PV.', cd: 9, energie: 30, mult: 1.6, portee: 4, type: 'cible', couleur: ['#ff9a9a', '#3a0008'], glyphe: 'slash' },
  vampirisme:{ nom: 'Soif de sang', desc: 'Pendant 5 s, tes coups te rendent 35 % des dégâts infligés.', cd: 16, energie: 25, mult: 0, type: 'buff', couleur: ['#ff6a8a', '#40001a'], glyphe: 'heart' },
  purge:     { nom: 'Purge du gladiateur', desc: 'Supprime ralentissements et étourdissements, intouchable 1,2 s.', cd: 18, energie: 20, mult: 0, type: 'buff', couleur: ['#e0c8ff', '#2a0a4a'], glyphe: 'shield' },
  legion:    { nom: 'Légion d’ombres', desc: 'Invoque une ombre par tier de ton arme (T1 = 1, T8 = 8). Elles te défendent 60 s et explosent en mourant.', cd: 25, energie: 35, mult: 0, portee: 0, type: 'invocation', couleur: ['#c9a0ff', '#1a0630'], glyphe: 'ombres' },
  reflet:    { nom: 'Reflet volé', desc: 'Arrache le reflet de ta cible : un double avec 15 % de ses PV et de son énergie combat pour toi 30 s.', cd: 40, energie: 40, mult: 0, portee: 14, type: 'invocation', couleur: ['#e0b8ff', '#2a0a4a'], glyphe: 'miroir' },
  pasOmbre:  { nom: 'Pas de l’ombre', desc: 'Disparais et réapparais dans le dos de ta cible : frappe ×2,4 et étourdit 0,8 s. Tes ombres te suivent.', cd: 11, energie: 24, mult: 2.4, portee: 12, type: 'dash', couleur: ['#b07aff', '#12001f'], glyphe: 'pasOmbre' },
  ruee:      { nom: 'Ruée', desc: '+60 % de vitesse pendant 3 s, supprime les ralentissements.', cd: 15, energie: 15, mult: 0, type: 'sprint', couleur: ['#fff08a', '#4d3a06'], glyphe: 'wing' },
};

// ---- Donjons ----
export const MODES = [
  { id: 0, nom: 'Facile', lieu: 'Cryptes Oubliées', argent: 1, xp: 1, tiers: [1, 2], mobTier: 1, bossTier: [1.4, 1.6, 1.8, 2.1], ipConseil: 300, couleur: '#49c25a',
    texte: 'Ouvert aux débutants. Une arme T1 suffit. Butin T1 à T2.' },
  { id: 1, nom: 'Intermédiaire', lieu: 'Forteresse des Ossements', argent: 9, xp: 5, tiers: [3, 5], mobTier: 3.6, bossTier: [4.0, 4.3, 4.6, 5.0], ipConseil: 620, couleur: '#3f8cff',
    texte: 'Prévois au moins du T3–T4. Les boss frappent fort. Butin T3 à T5.' },
  { id: 2, nom: 'Cauchemar', lieu: 'Gouffre Écarlate', argent: 45, xp: 14, tiers: [6, 8], mobTier: 6.5, bossTier: [7.0, 7.3, 7.6, 8.0], ipConseil: 950, couleur: '#ff3b3b',
    texte: 'Réservé au T6 et plus. Chaque erreur se paie. Butin T6 à T8.' },
];

export const COFFRES = [
  { id: 'vert', nom: 'Coffre commun', color: '#4fd16a', chance: 45, desc: 'Surtout des babioles sans valeur.' },
  { id: 'bleu', nom: 'Coffre correct', color: '#3f9bff', chance: 32, desc: 'Quelques objets et de l’argent.' },
  { id: 'violet', nom: 'Coffre rare', color: '#b65bff', chance: 17, desc: 'Du bon équipement, parfois de meilleure qualité.' },
  { id: 'legendaire', nom: 'Coffre légendaire', color: '#ffc23a', chance: 6, desc: 'Le haut de la fourchette du donjon, qualités élevées.' },
];

export const BOSS = [
  { id: 'gardien', nom: 'Gardien des Os', model: 'Skeleton_Warrior', arme: 'Skeleton_Axe', scale: 2.3, hpMult: 13, dmgMult: 2.2, couleur: '#ff6a3a' },
  { id: 'archere', nom: 'Archère du Voile', model: 'Skeleton_Rogue', arme: 'Skeleton_Crossbow', scale: 2.1, hpMult: 12, dmgMult: 2.0, couleur: '#7dffb0' },
  { id: 'necro', nom: 'Nécromancien Écarlate', model: 'Skeleton_Mage', arme: 'Skeleton_Staff', scale: 2.2, hpMult: 13, dmgMult: 2.3, couleur: '#ff3b6a' },
  { id: 'horreur', nom: 'Horreur infernale', model: 'Dragon_Evolved', arme: null, scale: 1.0, hpMult: 18, dmgMult: 2.6, couleur: '#ff8a1a' },
];

export const MOBS = {
  minion:  { nom: 'Squelette errant', model: 'Skeleton_Minion', arme: 'Skeleton_Blade', hp: 1.0, dmg: 1.0, vitesse: 3.4, portee: 2.0, type: 'melee', atk: '1H_Melee_Attack_Chop' },
  guerrier:{ nom: 'Squelette guerrier', model: 'Skeleton_Warrior', arme: 'Skeleton_Axe', hp: 1.7, dmg: 1.35, vitesse: 2.9, portee: 2.3, type: 'melee', atk: '2H_Melee_Attack_Chop' },
  archer:  { nom: 'Squelette archer', model: 'Skeleton_Rogue', arme: 'Skeleton_Crossbow', hp: 0.8, dmg: 1.1, vitesse: 3.2, portee: 10, type: 'ranged', atk: '2H_Ranged_Shoot' },
  mage:    { nom: 'Squelette mage', model: 'Skeleton_Mage', arme: 'Skeleton_Staff', hp: 0.75, dmg: 1.3, vitesse: 3.0, portee: 9.5, type: 'caster', atk: 'Spellcast_Shoot' },
};

// ---- Joueurs du hub (simulés en attendant le serveur) ----
export const BOTS = [
  ['Delta69', 'P2E', 'PATH 2 EXILE'], ['Piecior', 'GRUBE', 'WIELOLYPKI'], ['Melegmu', '', 'TACTICS'], ['Ronnie12', '', 'RDF'],
  ['TonBan', '', 'HONGXI'], ['JustinVolibieber', 'CHINA', 'LEMON GIRLS'], ['TheBigtree', '', 'RAIDERS'], ['Leki457', '', 'CROW ZERO'],
  ['Quantiqus', '', 'LES VAROIS'], ['Nyxara', '', 'CENDRES'], ['Brakkus', 'FR', 'LA HORDE'], ['Sylvane', '', 'VOILE NOIR'],
  ['Kordath', '', 'CROW ZERO'], ['Elwyne', 'BE', 'LYS D’ARGENT'], ['Morvak', '', 'RDF'], ['Tsukio', 'JP', 'KAGE'],
  ['Valkyra', '', 'LES VAROIS'], ['Grimbold', '', 'TACTICS'], ['Isolde', '', 'VOILE NOIR'],
];

export const CHAT = [
  "Salut les équipements de récolte en 8.1 .2 .3 rajoute du rendement ?",
  "Quelqu'un pour le Cauchemar ? Il me faut un heal",
  "Le coffre légendaire du Gardien m'a lâché une Égide solaire !!",
  "Vends arbalète T5 Excellent, mp",
  "Le dragon il faut esquiver le souffle par les côtés",
  "gg à l'équipe pour l'Horreur infernale",
  "Ne restez pas dans les cercles rouges du nécro x)",
  "Le marchand vend jusqu'au T4, le reste c'est dans les donjons",
  "Je farm le Facile pour le bronze, ça monte vite",
  "Quelqu'un sait si la tempête d'acier traverse les boucliers ?",
];

// ---- Maîtrise : niveau requis par tier ----
export const NIVEAU_REQUIS = [0, 1, 15, 40, 50, 60, 70, 80, 90];
export const MAITRISES = [
  { id: 'epee', nom: 'Épée à deux mains', cat: 'arme' }, { id: 'arbalete', nom: 'Arbalète lourde', cat: 'arme' }, { id: 'baton', nom: 'Bâton de feu', cat: 'arme' }, { id: 'ombre', nom: 'Dagues des Ombres', cat: 'arme', rare: true },
  { id: 'casque', nom: 'Armure de tête', cat: 'armure' }, { id: 'plastron', nom: 'Armure de poitrine', cat: 'armure' }, { id: 'bottes', nom: 'Armure de pieds', cat: 'armure' },
];

// ---- Équipement d'arène (boutique des trophées) ----
export const VARIANTES = {
  bourreau: { suffixe: 'du Bourreau', style: 'Offensif', couleur: '#ff5a4a',
    arme: { degats: 1.18, crit: 6, vitesse: 1.0 }, armure: { armure: 0.85, pv: 0.95, bonusDeg: 6 },
    remplace: { epee: ['Q', 'execution'], arbalete: ['Q', 'execution'], baton: ['Q', 'execution'] },
    texte: 'Plus de dégâts, moins de défense. Exécution remplace le premier sort.' },
  gardien: { suffixe: 'du Gardien', style: 'Défensif', couleur: '#5aa8ff',
    arme: { degats: 0.92, crit: 0, vitesse: 1.0, pv: 180 }, armure: { armure: 1.35, pv: 1.2, bonusDeg: 0 },
    remplace: { epee: ['E', 'purge'], arbalete: ['E', 'purge'], baton: ['E', 'purge'] },
    texte: 'Beaucoup plus d’armure et de vie. Purge du gladiateur remplace le dernier sort.' },
  champion: { suffixe: 'du Champion', style: 'Équilibré', couleur: '#ffcf4a',
    arme: { degats: 1.07, crit: 3, vitesse: 1.08 }, armure: { armure: 1.12, pv: 1.08, bonusDeg: 3, recharge: 6 },
    remplace: { epee: ['W', 'vampirisme'], arbalete: ['W', 'vampirisme'], baton: ['W', 'vampirisme'] },
    texte: 'Un peu de tout, recharge des sorts plus rapide. Soif de sang remplace le sort du milieu.' },
};
export const PRIX_TROPHEES = [0, 0, 0, 0, 0, 1500, 3200, 6000, 11000];

// ---- Îles ----
export const ILE_TYPES = {
  bois: { nom: 'Île des Bûcherons', res: 'bois', label: 'Bois', prix: 3, couleur: '#8fd16a', verbe: 'Couper l’arbre', outil: 'tool_axe', atelier: 'b_lumbermill', icone: 'Wood_Log_Stack', ouvrier: 'Barbarian', desc: 'Une forêt dense : tes ouvriers abattent les arbres et empilent les rondins.' },
  mine: { nom: 'Île Minière', res: 'minerai', label: 'Minerai', prix: 5, couleur: '#b8c4d8', verbe: 'Miner le filon', outil: 'tool_pickaxe', atelier: 'b_mine', icone: 'Iron_Nuggets', ouvrier: 'Knight', desc: 'Des rochers veinés de fer, de cuivre et d’or. Le minerai se vend plus cher.' },
  cueillette: { nom: 'Île des Cueilleurs', res: 'recolte', label: 'Récoltes', prix: 4, couleur: '#ffa06a', verbe: 'Cueillir', outil: null, atelier: 'b_market', icone: 'crop_pumpkin', ouvrier: 'Rogue', desc: 'Buissons à baies, potagers et fleurs. Récolte rapide et régulière.' },
};
export const RESSOURCES = { bois: 'bois', minerai: 'mine', recolte: 'cueillette' };
export const ILE_TAILLES = [
  { nom: 'Îlot', rayon: 3, prix: 500000 },
  { nom: 'Île', rayon: 4, prix: 4000000 },
  { nom: 'Grande île', rayon: 5, prix: 25000000 },
  { nom: 'Île immense', rayon: 6, prix: 150000000 },
];
// ressources à livrer à l'intendant pour passer au niveau n
export const ILE_NIVEAUX = [0, 0, 1000, 3000, 8000, 20000, 50000, 120000, 300000, 700000];
export const BATIMENTS = {
  maison: { nom: 'Maison d’ouvrier', modele: 'b_home_A', ech: 5, prix: 25000, croiss: 1.35, desc: '+1 ouvrier que tu peux invoquer.' },
  foyer: { nom: 'Ta maison', modele: 'b_tavern', ech: 5, prix: 120000, unique: true, desc: 'Ton coffre définitif : stockage illimité.' },
  atelier: { nom: 'Atelier', modele: null, ech: 4.5, prix: 60000, unique: true, desc: 'Scierie, mine ou étal selon ton île.' },
  route: { nom: 'Route pavée', modele: 'ground_pathTile', ech: 1, prix: 2500, croiss: 1.05, desc: 'Pavés et lanternes.' },
  jardin: { nom: 'Jardin fleuri', modele: null, ech: 1, prix: 6000, croiss: 1.05, desc: 'Fleurs, tonneaux et sacs.' },
  puits: { nom: 'Puits', modele: 'b_well', ech: 5, prix: 15000, croiss: 1.1, desc: 'Un puits de pierre.' },
  moulin: { nom: 'Moulin', modele: 'b_windmill', ech: 5, prix: 45000, croiss: 1.1, desc: 'Un moulin à vent.' },
  tour: { nom: 'Tour de guet', modele: 'b_tower_A', ech: 4, prix: 80000, croiss: 1.1, desc: 'Une tour qui domine l’île.' },
};
export const GARDES_ILE = [
  { nom: 'Sentinelle', prix: 150000, ratio: 0.85 },
  { nom: 'Gardien', prix: 450000, ratio: 0.92 },
  { nom: 'Capitaine', prix: 1200000, ratio: 1.0 },
];
export const CHAMPION_ILE = { nom: 'Champion de l’île', prix: 3500000, ratio: 1.15 };
export const HEURE_ASSAUT = 21;

// ---- Émoticônes (joueur et bots) ----
export const EMOTES = [
  { id: 'salut', g: '👋', nom: 'Salut' }, { id: 'gg', g: 'GG', nom: 'GG', texte: true, c: '#ffd25a' }, { id: 'mdr', g: '😂', nom: 'MDR' },
  { id: 'ez', g: 'EZ', nom: 'Trop facile', texte: true, c: '#ff5a4a' }, { id: 'clown', g: '🤡', nom: 'Clown' }, { id: 'rip', g: '💀', nom: 'RIP' },
  { id: 'rage', g: '😡', nom: 'Rage' }, { id: 'ouin', g: '😭', nom: 'Ouin' }, { id: 'toi', g: '👉', nom: 'Toi !' },
  { id: 'bof', g: '🥱', nom: 'Bof' }, { id: 'feu', g: '🔥', nom: 'En feu' }, { id: 'merci', g: '❤️', nom: 'Merci' },
  { id: 'diable', g: '😈', nom: 'Viens' }, { id: 'fuite', g: '🏃', nom: 'Je fuis' }, { id: 'malin', g: '😏', nom: 'Malin' }, { id: 'oups', g: '😅', nom: 'Oups' },
];
