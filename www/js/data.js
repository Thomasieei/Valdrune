// ===== Données du jeu : tiers, objets, sorts, butin =====

export const TIERS = [
  null,
  { t: 1, roman: 'I',    nom: 'Rouillé',   color: '#9a9184', glow: 0.0 },
  { t: 2, roman: 'II',   nom: 'Bronze',    color: '#c47f3e', glow: 0.0 },
  { t: 3, roman: 'III',  nom: 'Sylvestre', color: '#49c25a', glow: 0.15 },
  { t: 4, roman: 'IV',   nom: 'Azur',      color: '#3f8cff', glow: 0.3 },
  { t: 5, roman: 'V',    nom: 'Braise',    color: '#ff4a2e', glow: 0.55 },
  { t: 6, roman: 'VI',   nom: 'Solaire',   color: '#ffa21c', glow: 0.8 },
  { t: 7, roman: 'VII',  nom: 'Abyssal',   color: '#b153ff', glow: 0.85 },
  { t: 8, roman: 'VIII', nom: 'Céleste',   color: '#ffc928', glow: 1.0 },
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
  // classe à familiers : arc + meute de 3 loups démoniaques permanents
  arc: {
    label: 'Arc du Maître des bêtes', court: 'Arc', model: 'Rogue_Hooded', node: 'Arc', procedural: true, bete: true,
    helmet: null, cape: 'Rogue_Cape', legs: ['Rogue_LegLeft', 'Rogue_LegRight'], body: 'Rogue_Body',
    portee: 14, vitesse: 0.95, base: 24, projectile: 'fleche',
    idle: 'Idle', run: 'Running_A',
    attaques: ['2H_Ranged_Shoot'],
    noms: ['', 'Arc de chasse', 'Arc de bronze', 'Arc des sous-bois', 'Arc d’azur', 'Arc des braises', 'Arc du soleil noir', 'Arc de l’abysse', 'Croc céleste'],
    sorts: ['tirArc', 'meute', 'frenesie'],
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
  // classe de farm « cheatée » : 1 % sur les boss du Cauchemar (T7-T8), ou code réutilisable
  orage: {
    label: 'Haches de l’Orage', court: 'Orage', model: 'Barbarian', node: '1H_Axe', node2: '1H_Axe_Offhand', rare: true, orage: true,
    helmet: 'Barbarian_Hat', cape: 'Barbarian_Cape', legs: ['Barbarian_LegLeft', 'Barbarian_LegRight'], body: 'Barbarian_Body',
    portee: 2.7, vitesse: 1.25, base: 42, projectile: null,
    idle: 'Idle', run: 'Running_A',
    attaques: ['1H_Melee_Attack_Chop', '1H_Melee_Attack_Slice_Diagonal'],
    noms: ['', 'Haches grondantes', 'Haches du tonnerre', 'Fendeuses d’éclairs', 'Haches de l’ouragan', 'Crocs de la tempête', 'Colère céleste', 'Haches du cataclysme', 'Jugement de Thoros'],
    sorts: ['tornade', 'titan', 'orage'],
  },
  // classe rapide à combos : code réutilisable
  assassin: {
    label: 'Lames de l’Assassin', court: 'Assassin', model: 'Rogue', node: 'Knife', node2: 'Knife_Offhand', rare: true, assassin: true,
    helmet: null, cape: 'Rogue_Cape', legs: ['Rogue_LegLeft', 'Rogue_LegRight'], body: 'Rogue_Body',
    portee: 2.2, vitesse: 1.5, base: 27, projectile: null,
    idle: '2H_Melee_Idle', run: 'Running_A',
    attaques: ['1H_Melee_Attack_Slice_Diagonal', '1H_Melee_Attack_Chop', '2H_Melee_Attack_Stab'],
    noms: ['', 'Surins émoussés', 'Crocs de vipère', 'Épines du silence', 'Lames du crépuscule', 'Sang-froid', 'Murmure écarlate', 'Dernier soupir', 'Fin de partie'],
    sorts: ['triple', 'curee', 'zephyr'],
  },
};
export const CHANCE_OMBRE = 0.001; // 0,1 %
export const CODES_BETA = { 'BRECHE-OMBRE': { arme: 'ombre', tier: 1, texte: 'Accès bêta : Dagues des Ombres T1' }, 'BRECHE-ORAGE': { arme: 'orage', tous: true, reutilisable: true, texte: 'Haches de l’Orage T1 à T8 ajoutées (maîtrise niveau 90)' }, 'BRECHE-ASSASSIN': { arme: 'assassin', tous: true, reutilisable: true, texte: 'Lames de l’Assassin T1 à T8 ajoutées (maîtrise niveau 90)' } };
export const CHANCE_ORAGE = 0.01;

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
  { id: 'rune', nom: 'Rune d’enchantement', valeur: 5000, color: '#5ab0ff', icone: 'rune' },
  // marchandises de butin (par tier) : se revendent au marché
  { id: 'eclat', nom: 'Éclat d’âme', valeur: 0, color: '#ff8a2a', icone: 'eclat', mat: 1 },
  { id: 'sceau', nom: 'Sceau runique', valeur: 0, color: '#ffb36a', icone: 'sceau', mat: 0.6 },
  { id: 'relique', nom: 'Amulette ancienne', valeur: 0, color: '#5ad0ff', icone: 'relique', mat: 1.6 },
  { id: 'tome', nom: 'Tome de maîtrise', valeur: 0, color: '#e8b04a', icone: 'tome', mat: 2.2 },
];
// valeur d'une unité de marchandise selon son tier
export const VALEUR_MAT = [0, 150, 600, 1800, 4500, 9000, 18000, 36000, 72000];

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
  tornade:   { nom: 'Œil du cyclone', desc: 'Tourbillonne 4 s en aspirant tout ce qui est autour de toi. Chaque monstre aspiré prend des dégâts continus. Tu peux bouger.', cd: 9, energie: 30, mult: 0.7, portee: 7, type: 'spin', couleur: ['#bfe8ff', '#0a2a5a'], glyphe: 'tornade' },
  titan:     { nom: 'Chute du Titan', desc: 'Bondis sur la zone visée : onde de choc qui projette tout en l’air. Si 3 ennemis ou plus meurent, la recharge est remise à zéro.', cd: 8, energie: 26, mult: 3.2, portee: 13, type: 'dash', couleur: ['#ffe27a', '#5a3a00'], glyphe: 'titan' },
  orage:     { nom: 'Colère de l’Orage', desc: 'Pendant 10 s : +70 % de vitesse d’attaque, +40 % de vitesse, vol de vie, et la foudre frappe un ennemi proche toutes les 0,4 s.', cd: 24, energie: 40, mult: 1.1, portee: 11, type: 'buff', couleur: ['#e0f4ff', '#3a3aff'], glyphe: 'foudre' },
  triple:    { nom: 'Triple entaille', desc: 'Sans recharge. Fonds sur ta cible (6 m) et enchaîne 3 coups éclair. +3 points de combo.', cd: 0, energie: 22, mult: 0.55, portee: 6, type: 'cible', couleur: ['#ff8a8a', '#3a0008'], glyphe: 'triple' },
  curee:     { nom: 'Curée', desc: 'Finisher automatique sur la cible la plus proche : consomme tous les points de combo. Dégâts énormes par point ; à 5 points, tu disparais 1 s.', cd: 7, energie: 28, mult: 0.8, portee: 9, type: 'cible', couleur: ['#ffd0d0', '#8a0010'], glyphe: 'curee' },
  zephyr:    { nom: 'Pas du zéphyr', desc: '3 dashs foudroyants en 5 s qui traversent et entaillent les ennemis (+1 combo chacun), et +40 % de vitesse pendant 5 s.', cd: 15, energie: 22, mult: 0.55, portee: 8, type: 'dash', couleur: ['#e0fff0', '#0a5a3a'], glyphe: 'zephyr' },
  // --- Maître des bêtes ---
  tirArc:    { nom: 'Flèche écarlate', desc: 'Tire une flèche chargée qui traverse tout sur 20 m et inflige des dégâts énormes. Saigne 4 s.', cd: 20, energie: 30, mult: 7.5, portee: 20, type: 'ligne', couleur: ['#ff6a5a', '#3a0004'], glyphe: 'fleche' },
  meute:     { nom: 'Appel de la meute', desc: 'Invoque tes loups démoniaques (3 au total). Tant que la meute est complète, ce sort devient un enchaînement : Entrave bestiale → Rugissement de la meute → Bond meurtrier.', cd: 20, energie: 30, mult: 0, portee: 0, type: 'invocation', couleur: ['#ff4a3a', '#2a0006'], glyphe: 'loup' },
  entrave:   { nom: 'Entrave bestiale', desc: 'Les loups bondissent sur ta cible et la clouent au sol 2,6 s (elle ne peut plus bouger).', cd: 1.2, energie: 12, mult: 1.6, portee: 22, type: 'meute', couleur: ['#ffb04a', '#3a1404'], glyphe: 'entrave', combo: 1 },
  rugissement: { nom: 'Rugissement de la meute', desc: 'Les loups rugissent ensemble : une énorme onde de choc ravage tout autour d’eux.', cd: 1.2, energie: 18, mult: 4.2, portee: 22, type: 'meute', couleur: ['#ff5a2a', '#3a0400'], glyphe: 'rugissement', combo: 2 },
  bondMeurtrier: { nom: 'Bond meurtrier', desc: 'Chaque loup se téléporte sur un monstre différent et le déchire (saignement). Termine l’enchaînement.', cd: 14, energie: 22, mult: 4.6, portee: 22, type: 'meute', couleur: ['#ff2a4a', '#2a0010'], glyphe: 'bond', combo: 3 },
  frenesie:  { nom: 'Frénésie sauvage', desc: 'Pendant 8 s : tes loups attaquent 80 % plus vite et volent 20 % de vie, toi +30 % de vitesse d’attaque.', cd: 24, energie: 25, mult: 0, type: 'buff', couleur: ['#ff8a6a', '#4a0a0a'], glyphe: 'rugissement' },
  // --- compétences débloquées par l'arbre de talents ---
  pluieEcarlate: { nom: 'Pluie écarlate', desc: 'Une pluie de flèches rouges s’abat 5 fois sur la zone visée. Ralentit de 40 %.', cd: 18, energie: 36, mult: 1.15, portee: 15, type: 'zone', couleur: ['#ff7a6a', '#3a0006'], glyphe: 'rain' },
  tirMultiple: { nom: 'Salve en éventail', desc: 'Tire 7 carreaux en éventail devant toi.', cd: 8, energie: 24, mult: 1.1, portee: 14, type: 'cone', couleur: ['#c8ffd0', '#0a3a20'], glyphe: 'bolt' },
  novaGivre: { nom: 'Nova de givre', desc: 'Une onde glacée autour de toi : dégâts et ennemis gelés sur place 2 s.', cd: 14, energie: 30, mult: 2.2, portee: 6, type: 'zone', couleur: ['#bfe8ff', '#0a2a4a'], glyphe: 'spin' },
  ruee:      { nom: 'Ruée', desc: '+60 % de vitesse pendant 3 s, supprime les ralentissements.', cd: 15, energie: 15, mult: 0, type: 'sprint', couleur: ['#fff08a', '#4d3a06'], glyphe: 'wing' },
};

// ---- Donjons ----
export const MODES = [
  { id: 0, nom: 'Facile', lieu: 'Cryptes Oubliées', argent: 1, xp: 1, tiers: [1, 2], mobTier: 1, bossTier: [1.4, 1.6, 1.8, 2.1], ipConseil: 300, couleur: '#49c25a',
    texte: 'Ouvert aux débutants. Une arme T1 suffit. Butin T1 à T2.' },
  { id: 1, nom: 'Intermédiaire', lieu: 'Forteresse des Ossements', argent: 9, xp: 5, tiers: [3, 5], mobTier: 3.6, bossTier: [4.0, 4.3, 4.6, 5.0], ipConseil: 700, couleur: '#3f8cff',
    texte: 'Prévois au moins du T3–T4. Les boss frappent fort. Butin T3 à T5.' },
  { id: 2, nom: 'Cauchemar', lieu: 'Gouffre Écarlate', argent: 45, xp: 14, tiers: [6, 8], mobTier: 6.5, bossTier: [7.0, 7.3, 7.6, 8.0], ipConseil: 1150, couleur: '#ff3b3b',
    texte: 'Réservé au T6 et plus. Chaque erreur se paie. Butin T6 à T8.' },
  { id: 3, nom: 'Abîme', lieu: 'Abîme Écarlate', argent: 45, xp: 1400, tiers: [8, 8], mobTier: 9.2, bossTier: [10, 10.4, 10.8, 11.4], ipConseil: 1550, couleur: '#b0002a', abime: true, mult: 100, nivMin: 70,
    texte: 'Or et expérience ×100. Monstres d’une puissance inouïe, zones au sol chaque seconde, boss au burst démentiel. Niveau 70 minimum.' },
];

export const COFFRES = [
  { id: 'vert', nom: 'Coffre commun', color: '#4fd16a', chance: 60, desc: 'Surtout des babioles sans valeur.' },
  { id: 'bleu', nom: 'Coffre correct', color: '#3f9bff', chance: 34.9, desc: 'Quelques objets et de l’argent.' },
  { id: 'violet', nom: 'Coffre rare', color: '#b65bff', chance: 5, desc: 'Du bon équipement, parfois de meilleure qualité.' },
  { id: 'legendaire', nom: 'Coffre légendaire', color: '#ffc23a', chance: 0.1, desc: 'Le haut de la fourchette du donjon, qualités élevées.' },
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
  { id: 'epee', nom: 'Épée à deux mains', cat: 'arme' }, { id: 'arbalete', nom: 'Arbalète lourde', cat: 'arme' }, { id: 'baton', nom: 'Bâton de feu', cat: 'arme' }, { id: 'arc', nom: 'Arc du Maître des bêtes', cat: 'arme' }, { id: 'ombre', nom: 'Dagues des Ombres', cat: 'arme', rare: true }, { id: 'orage', nom: 'Haches de l’Orage', cat: 'arme', rare: true }, { id: 'assassin', nom: 'Lames de l’Assassin', cat: 'arme', rare: true },
  { id: 'casque', nom: 'Armure de tête', cat: 'armure' }, { id: 'plastron', nom: 'Armure de poitrine', cat: 'armure' }, { id: 'bottes', nom: 'Armure de pieds', cat: 'armure' },
];

// ---- Équipement d'arène (boutique des trophées) ----
export const VARIANTES = {
  bourreau: { suffixe: 'du Bourreau', style: 'Offensif', couleur: '#ff5a4a',
    arme: { degats: 1.18, crit: 6, vitesse: 1.0 }, armure: { armure: 0.85, pv: 0.95, bonusDeg: 6 },
    remplace: { epee: ['Q', 'execution'], arbalete: ['Q', 'execution'], baton: ['Q', 'execution'], arc: ['Q', 'execution'] },
    texte: 'Plus de dégâts, moins de défense. Exécution remplace le premier sort.' },
  gardien: { suffixe: 'du Gardien', style: 'Défensif', couleur: '#5aa8ff',
    arme: { degats: 0.92, crit: 0, vitesse: 1.0, pv: 180 }, armure: { armure: 1.35, pv: 1.2, bonusDeg: 0 },
    remplace: { epee: ['E', 'purge'], arbalete: ['E', 'purge'], baton: ['E', 'purge'], arc: ['E', 'purge'] },
    texte: 'Beaucoup plus d’armure et de vie. Purge du gladiateur remplace le dernier sort.' },
  champion: { suffixe: 'du Champion', style: 'Équilibré', couleur: '#ffcf4a',
    arme: { degats: 1.07, crit: 3, vitesse: 1.08 }, armure: { armure: 1.12, pv: 1.08, bonusDeg: 3, recharge: 6 },
    remplace: { epee: ['W', 'vampirisme'], arbalete: ['W', 'vampirisme'], baton: ['W', 'vampirisme'], arc: ['E', 'vampirisme'] },
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

// ---- Sanctuaire d'Émeraude : donjon de groupe à 5 ----
export const MOBS_SYLVE = {
  moussu:  { nom: 'Squelette moussu', model: 'Skeleton_Minion', arme: 'Skeleton_Blade', hp: 1.1, dmg: 1.0, vitesse: 3.5, portee: 2.0, type: 'melee', atk: '1H_Melee_Attack_Chop', teinte: '#7acf5a' },
  ecorce:  { nom: 'Gardien d’écorce', model: 'Skeleton_Warrior', arme: 'Skeleton_Axe', hp: 2.0, dmg: 1.4, vitesse: 2.9, portee: 2.3, type: 'melee', atk: '2H_Melee_Attack_Chop', teinte: '#a07a4a' },
  ronce:   { nom: 'Archer des ronces', model: 'Skeleton_Rogue', arme: 'Skeleton_Crossbow', hp: 0.85, dmg: 1.15, vitesse: 3.2, portee: 10, type: 'ranged', atk: '2H_Ranged_Shoot', teinte: '#5ab86a' },
  druide:  { nom: 'Druide déchu', model: 'Skeleton_Mage', arme: 'Skeleton_Staff', hp: 0.8, dmg: 1.3, vitesse: 3.0, portee: 9.5, type: 'caster', atk: 'Spellcast_Shoot', teinte: '#a07aff' },
};
export const BOSS_SYLVE = [
  { id: 'ronces', nom: 'Tisserand de Ronces', titre: 'Gardien de la Clairière', model: 'Skeleton_Warrior', arme: 'Skeleton_Axe', scale: 2.5, hpMult: 26, dmgMult: 2.6, couleur: '#7dff6a', teinte: '#7a6a3a' },
  { id: 'sylphe', nom: 'Reine Sylphe', titre: 'Dame du Bassin', model: 'Skeleton_Mage', arme: 'Skeleton_Staff', scale: 2.4, hpMult: 28, dmgMult: 2.5, couleur: '#f08aff', teinte: '#e8d0ff', hover: 1.1 },
  { id: 'chasseur', nom: 'Chasseur Écorce', titre: 'Celui qui traque', model: 'Skeleton_Rogue', arme: 'Skeleton_Crossbow', scale: 2.4, hpMult: 30, dmgMult: 2.75, couleur: '#ffd06a', teinte: '#6a5030' },
  { id: 'verdanthos', nom: 'Verdanthos', titre: 'l’Ancien d’Émeraude', model: 'Dragon_Evolved', arme: null, scale: 1.0, hauteur: 7.2, rayon: 3.4, hpMult: 56, dmgMult: 3.0, couleur: '#3affa0', teinte: '#2aff8a' },
];

// ---- Caractères des joueurs simulés ----
export const TRAITS = {
  fonceur:    { nom: 'Fonceur', ico: '🔥', desc: 'Toujours devant, lance les boss', vit: 1.08, avance: 4, reflexe: 0.6 },
  tranquille: { nom: 'Tranquille', ico: '🐢', desc: 'Prend son temps, part parfois AFK', vit: 0.8, avance: -8, reflexe: 0.6 },
  toxique:    { nom: 'Toxique', ico: '🤡', desc: 'Tourne en rond, provoque, fait n’importe quoi', vit: 1.05, avance: 0, reflexe: 0.45 },
  prudent:    { nom: 'Prudent', ico: '🛡️', desc: 'Reste en retrait, esquive bien', vit: 0.92, avance: -5, reflexe: 0.9 },
  protecteur: { nom: 'Protecteur', ico: '💚', desc: 'Reste près de toi et tape tes ennemis', vit: 1.0, avance: -2, reflexe: 0.75 },
  bavard:     { nom: 'Bavard', ico: '💬', desc: 'Parle tout le temps', vit: 1.0, avance: 0, reflexe: 0.65 },
};

// ---- Rangs classés (arène et Brèche) ----
export const RANGS = [
  { id: 'bronze', nom: 'Bronze', c1: '#f0b878', c2: '#a0602a', c3: '#4a2a0e' },
  { id: 'argent', nom: 'Argent', c1: '#ffffff', c2: '#a8b4c4', c3: '#3a4252' },
  { id: 'or', nom: 'Or', c1: '#fff3a0', c2: '#e8a81a', c3: '#5a3a00' },
  { id: 'diamant', nom: 'Diamant', c1: '#e0fcff', c2: '#3ac8ff', c3: '#06306a' },
  { id: 'champion', nom: 'Champion', c1: '#f4d8ff', c2: '#a83aff', c3: '#2a0650' },
  { id: 'grand', nom: 'Grand Champion', c1: '#fff0c8', c2: '#ff3a2a', c3: '#4a0000' },
];
export const PTS_RANG = 100, GAIN_RANG = 20, PERTE_RANG = 15;
// boss errant ultra rare de la Brèche
export const BOSS_ERRANT = { id: 'devoreur', nom: 'Nyx’Ahrûn', titre: 'le Dévoreur d’Étoiles', model: 'Dragon_Evolved', arme: null, scale: 1.0, hauteur: 6.4, rayon: 3.0, hpMult: 54, dmgMult: 4.2, couleur: '#c06aff', teinte: '#3a0a6a', errant: true };

// ---- Parchemins (Brèche uniquement, en pause pendant une invasion) ----
export const COULEURS_PARCH = {
  vert: { nom: 'Célérité', effet: 'vitesse', c1: '#b8ff9a', c2: '#2a9a3a', c3: '#0a3a14', symbole: 'botte', texte: 'de vitesse de déplacement' },
  violet: { nom: 'Savoir', effet: 'xp', c1: '#f0c8ff', c2: '#9a3aff', c3: '#2a0650', symbole: 'fleches', texte: 'd’expérience' },
  orange: { nom: 'Fortune', effet: 'argent', c1: '#ffe0a0', c2: '#ff8a1a', c3: '#5a2600', symbole: 'billet', texte: 'd’argent' },
  bleu: { nom: 'Trésor', effet: 'drop', c1: '#c8f0ff', c2: '#2a8aff', c3: '#062a5a', symbole: 'coffre', texte: 'd’objets dans les coffres' },
};
export const PARCHEMINS = {
  vert20: { couleur: 'vert', bonus: 0.2, prix: 20000 }, vert50: { couleur: 'vert', bonus: 0.5, prix: 90000 },
  violet20: { couleur: 'violet', bonus: 0.2, prix: 30000 }, violet50: { couleur: 'violet', bonus: 0.5, prix: 130000 },
  orange20: { couleur: 'orange', bonus: 0.2, prix: 30000 }, orange50: { couleur: 'orange', bonus: 0.5, prix: 130000 },
  bleu20: { couleur: 'bleu', bonus: 0.2, prix: 40000 }, bleu50: { couleur: 'bleu', bonus: 0.5, prix: 170000 },
};
export const DUREE_PARCH = 30 * 60;
export const BOUTIQUE_PARCH_GRATUITE = true; // accès libre pendant la bêta

export const CLASSES_BASE = ['epee', 'arbalete', 'baton', 'arc'];
