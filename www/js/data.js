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
  // classe de style « puissance monstrueuse » : télékinésie (soulever, écraser, projeter) et trois lames spectrales
  esprit: {
    label: 'Grimoire de l’Esprit', court: 'Esprit', model: 'Mage', node: 'Spellbook_open', rare: true, esprit: true,
    helmet: null, cape: 'Mage_Cape', legs: ['Mage_LegLeft', 'Mage_LegRight'], body: 'Mage_Body',
    portee: 11, vitesse: 0.9, base: 38, projectile: 'esprit',
    idle: 'Idle', run: 'Running_A',
    attaques: ['Spellcast_Shoot'],
    noms: ['', 'Carnet du rêveur', 'Grimoire de bronze', 'Codex des murmures', 'Livre d’azur', 'Psautier de braise', 'Somme solaire', 'Codex de l’abysse', 'Pensée céleste'],
    sorts: ['emprise', 'lames', 'possession'],
  },
};
export const CHANCE_OMBRE = 0.001; // 0,1 %
export const CODES_BETA = { 'BRECHE-OMBRE': { arme: 'ombre', tier: 1, texte: 'Accès bêta : Dagues des Ombres T1' }, 'BRECHE-ORAGE': { arme: 'orage', tous: true, reutilisable: true, texte: 'Haches de l’Orage T1 à T8 ajoutées (maîtrise niveau 90)' }, 'BRECHE-ESPRIT': { arme: 'esprit', tous: true, reutilisable: true, texte: 'Grimoire de l’Esprit T1 à T8 ajouté (maîtrise niveau 90)' }, 'BRECHE-ASSASSIN': { arme: 'assassin', tous: true, reutilisable: true, texte: 'Lames de l’Assassin T1 à T8 ajoutées (maîtrise niveau 90)' } };
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
  // --- Esprit (télékinésie) ---
  emprise:   { nom: 'Emprise', desc: 'Soulève ta cible par la pensée — monstre, joueur ou passant. Ensuite, tu choisis : la déposer en douceur, l’écraser au sol (le décor éclate), ou la projeter où tu vises, sur d’autres ennemis.', cd: 6, energie: 24, mult: 4.2, portee: 15, type: 'tk', couleur: ['#f0e0ff', '#4a1a8a'], glyphe: 'main' },
  lames:     { nom: 'Trois lames', desc: 'Invoque trois lames spectrales qui tournent autour de toi et te défendent jusqu’à se briser. Relance pour leur donner un ordre : garde, assaut, ou exploration du donjon (10 % plus vite que toi). Elles grandissent avec ton tier et tes talents.', cd: 2, energie: 10, mult: 0.45, portee: 16, type: 'lames', couleur: ['#e8f0ff', '#3a2a8a'], glyphe: 'lames' },
  possession:{ nom: 'Possession', desc: 'Tu envoûtes ta cible et tout son groupe (6 m). Un boss envoûté compte comme vaincu (butin, coffre) puis se bat à tes côtés jusqu’à sa mort.', cd: 30, energie: 45, mult: 0, portee: 14, type: 'possession', couleur: ['#e8c8ff', '#3a0a5a'], glyphe: 'oeil' },
  onde:      { nom: 'Onde de force', desc: 'Une vague de pure volonté repousse et soulève tout ce qui t’entoure (7 m), étourdit 0,6 s.', cd: 9, energie: 28, mult: 1.6, portee: 7, type: 'onde', couleur: ['#d8c8ff', '#2a0a5a'], glyphe: 'onde' },
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
  // les vivants du donjon : des cultistes qui servent les gardiens (ils mangent, jouent aux dés, s'enfuient parfois)
  cultiste:{ nom: 'Cultiste écarlate', model: 'Rogue_Hooded', humain: true, noeuds: ['Knife', 'Knife_Offhand'], cape: 'Rogue_Cape', hp: 0.95, dmg: 1.1, vitesse: 3.7, portee: 2.0, type: 'melee', atk: '1H_Melee_Attack_Slice_Diagonal' },
  brute:   { nom: 'Brute du culte', model: 'Barbarian', humain: true, noeuds: ['2H_Axe'], cape: 'Barbarian_Cape', hp: 1.7, dmg: 1.4, vitesse: 3.1, portee: 2.4, type: 'melee', atk: '2H_Melee_Attack_Chop' },
  pretresse:{ nom: 'Prêtresse de la Brèche', model: 'Mage', humain: true, noeuds: ['1H_Wand'], cape: 'Mage_Cape', hp: 0.8, dmg: 1.3, vitesse: 3.2, portee: 9.5, type: 'caster', atk: 'Spellcast_Shoot' },
};

// ---- Répliques du donjon vivant (tirées sans répétition) ----
export const REPLIQUES = {
  intrus: ['Intrusion ! Que fais-tu là, petit humain ?', 'Hé ! Toi ! Personne n’entre ici sans l’ordre du maître !', 'Un vivant ?! Aux armes !', 'On a de la visite… et elle respire encore.', 'Tu t’es perdu, l’ami ? Mauvaise porte.', 'Debout ! On nous attaque !', 'Je savais que j’avais entendu des pas…', 'Qui t’a laissé passer ? Les gardes dorment encore ?', 'Encore un aventurier. Ils ne retiennent jamais la leçon.'],
  intrus_tablee: ['Lâchez les dés ! Un intrus !', 'Mon repas… tu vas me le payer !', 'On ne peut jamais manger tranquille ici !', 'Hé, c’est pas l’heure de la relève, ça…', 'Range ta chope, on a du travail.', 'Qui a invité ce rat à notre table ?'],
  intrus_feu: ['Éteignez rien du tout, on a un invité !', 'Approche du feu, petit humain… de plus près.', 'Il a vu le camp ! Ne le laissez pas repartir !', 'Je me réchauffais à peine…'],
  intrus_rituel: ['Le rituel est interrompu ! Tuez-le !', 'Ton sang complétera l’incantation.', 'Il a brisé le cercle ! Rattrapez-le !', 'Un profane devant l’orbe… blasphème !'],
  intrus_ronde: ['Halte ! Qui va là ?', 'Toi. Ne bouge plus.', 'Patrouille ! J’ai un intrus !', 'Ah, enfin un peu d’action pendant ma ronde.', 'Les couloirs ne sont pas sûrs, petit. Surtout pour toi.'],
  intrus_garde: ['On ne passe pas.', 'Le maître ne reçoit personne. Encore moins toi.', 'Recule, ou tu repartiras en morceaux.', 'Halte ! Cette salle est gardée.'],
  intrus_cercle: ['Tiens, on parlait justement des humains…', 'Silence, les gars. On a de la compagnie.', 'Tu écoutais aux portes ? Mauvaise idée.'],
  bav_tablee: ['Je te dis que le maître a encore réduit les rations.', 'Ta mise. Et ne triche pas cette fois.', 'T’as entendu ? Un humain aurait passé la Brèche.', 'Encore trois siècles de garde et je prends ma retraite.', 'Pourquoi c’est toujours nous qu’on met près de l’entrée ?', 'Ce ragoût a un goût de… non, mieux vaut pas savoir.', 'Paraît que la crypte du fond est maudite. Même pour nous.', 'Six ! Encore six ! Ces dés sont pipés !', 'Le Nécromancien m’a encore demandé un cœur frais. Où je trouve ça, moi ?'],
  bav_feu: ['Il fait froid dans ces pierres. Toujours froid.', 'Raconte encore l’histoire du chevalier qui s’est perdu ici.', 'Tu crois que la Brèche se refermera un jour ?', 'Rajoute du bois. Ou des os, c’est pareil.', 'J’ai entendu un mur respirer, dans l’aile secrète…'],
  bav_rituel: ['Encore un cercle… concentre-toi.', 'Le maître veut le sceau avant la lune rouge.', 'Ne prononce pas ce nom ici !', 'Sens-tu ? La Brèche respire.', 'L’orbe pulse plus fort ce soir.'],
  bav_cercle: ['Rien à signaler… comme d’habitude.', 'Tu crois qu’on a encore une âme, nous ?', 'Le Gardien dort depuis des jours. Ça me rend nerveux.', 'Si un humain arrive, je le laisse passer. Je plaisante. Quoique…', 'Ma lame est émoussée. Comme moi.', 'J’entends des pas dans les couloirs… ou c’est le vent ?', 'Il paraît que l’Archère rate jamais. Jamais.'],
  bav_garde: ['Rien à l’horizon.', 'Encore six heures de garde…', 'Si quelqu’un vient, c’est toi qui cries.', 'Le maître a dit : personne. Même pas le cuisinier.'],
  bav_ronde: ['Ronde numéro mille… rien.', 'Gauche, droite, gauche…', 'Encore ce couloir. J’en rêve la nuit.', 'Si je croise ce rat encore une fois…', 'Tu as fermé la crypte, la dernière fois ?'],
  moquerie: ['Ha ! Un gringalet. Ce sera rapide.', 'Tu tiens à peine ton arme, petit.', 'On t’a envoyé seul ? Quelle cruauté.', 'Regardez-moi ça… on dirait un apprenti.', 'Toi ? Contre nous ? Je vais bien rire.'],
  fuite: ['Cette puissance… c’est un monstre ! Je me rends !', 'Je ne suis pas payé pour mourir ! Je pars !', 'Pitié ! Prends ce que tu veux !', 'Le maître se débrouillera sans moi !', 'Non non non… pas contre ça !', 'Je dépose les armes ! Ne me frappe pas !', 'Sauve qui peut !'],
  loyal: ['Nous ne te laisserons pas passer ! Ne dérange pas le maître !', 'Pour le maître ! Jusqu’au dernier os !', 'Tu devras me briser pour avancer.', 'Le maître ne sera pas dérangé. Jamais.', 'Je sens ta force. Je reste quand même.', 'Fuir ? Je préfère mourir debout.'],
  terre: ['Je… je ne bouge pas ! Promis !', 'Passe ton chemin, s’il te plaît…', 'Je n’ai rien vu, rien entendu.', 'Ne me regarde pas comme ça…'],
  desespoir: ['Tant pis… je me défendrai !', 'Tu ne me laisses pas le choix !', 'Alors ce sera ensemble, dans la tombe !'],
  boss_gardien: ['Hm… qui ose me réveiller ?', 'Mon sommeil durait depuis mille ans… et c’est toi qui l’interromps ?', 'Un vivant… dans MA salle du trône ?', 'Tu as fait trop de bruit, petit humain. Bien trop.'],
  boss_archere: ['Tiens, une nouvelle cible pour mon entraînement.', 'Tu marches comme un sanglier. Je t’entends depuis l’entrée.', 'Ne bouge pas… ça ira plus vite.', 'Mes flèches s’ennuyaient. Merci d’être venu.'],
  boss_necro: ['Qui ose troubler mes recherches ?!', 'Encore un sujet d’expérience qui vient à moi de lui-même…', 'Silence ! Tu as gâché trois siècles de calculs !', 'Approche, approche… j’ai justement besoin d’un cœur frais.'],
  boss_horreur: ['… MORTEL. TU SENS LA PEUR.', 'QUI A TOUCHÉ À MON OR ?!', 'TU OSES ENTRER DANS MON ANTRE ?', 'JE T’AI SENTI DEPUIS LES ÉTAGES SUPÉRIEURS.'],
  rech_necro: ['Non… la troisième rune est fausse.', 'Encore un peu d’essence d’ombre…', 'Fascinant. Absolument fascinant.', 'Si la Brèche s’ouvre encore d’un doigt…'],
  crypte: ['Nul ne profanera la relique.', 'Mille ans de garde. Tu n’es qu’un instant de plus.', 'La relique a choisi ses gardiens. Pas toi.', 'Tu as trouvé le passage… tu ne trouveras pas la sortie.'],
};

// ---- Reliques : trouvées dans les cryptes cachées, elles donnent un pouvoir mystique (bouton dédié) ----
export const ARTEFACTS = [
  { id: 'meteore', nom: 'Cœur de l’Étoile morte', pouvoir: 'Chute d’astre', desc: 'Un astre s’écrase sur la zone visée : dégâts énormes, étourdissement et sol en feu.', cd: 70, glyphe: 'meteor', couleur: ['#ffe27a', '#7a1a00'] },
  { id: 'avatar', nom: 'Masque du Roi oublié', pouvoir: 'Avatar spectral', desc: 'Le spectre géant d’un ancien roi combat à tes côtés pendant 20 s.', cd: 90, glyphe: 'titan', couleur: ['#d8c0ff', '#1a0630'] },
  { id: 'temps', nom: 'Sablier des Abysses', pouvoir: 'Temps suspendu', desc: 'Fige tous les ennemis autour de toi (les boss moins longtemps).', cd: 75, glyphe: 'spin', couleur: ['#bfe8ff', '#0a2a4a'] },
  { id: 'nova', nom: 'Larme de la Sainte', pouvoir: 'Nova sacrée', desc: 'Te soigne, te couvre d’un bouclier et repousse les ennemis proches.', cd: 80, glyphe: 'heart', couleur: ['#fff2a0', '#5a4a00'] },
  { id: 'ailes', nom: 'Plume du Phénix', pouvoir: 'Ailes de cendre', desc: 'Pendant 6 s : bien plus rapide, intouchable 2 s, et chacun de tes coups enflamme.', cd: 60, glyphe: 'wing', couleur: ['#ffb07a', '#4a1000'] },
];
export const RARETES_RELIQUE = {
  vert: { nom: 'Peu commune', k: 1, color: '#4fd16a' },
  bleu: { nom: 'Rare', k: 1.3, color: '#3f9bff' },
  violet: { nom: 'Épique', k: 1.7, color: '#b65bff' },
  legendaire: { nom: 'Légendaire', k: 2.3, color: '#ffc23a' },
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
  { id: 'epee', nom: 'Épée à deux mains', cat: 'arme' }, { id: 'arbalete', nom: 'Arbalète lourde', cat: 'arme' }, { id: 'baton', nom: 'Bâton de feu', cat: 'arme' }, { id: 'arc', nom: 'Arc du Maître des bêtes', cat: 'arme' }, { id: 'ombre', nom: 'Dagues des Ombres', cat: 'arme', rare: true }, { id: 'orage', nom: 'Haches de l’Orage', cat: 'arme', rare: true }, { id: 'assassin', nom: 'Lames de l’Assassin', cat: 'arme', rare: true }, { id: 'esprit', nom: 'Grimoire de l’Esprit', cat: 'arme', rare: true },
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

// ======================= TAVERNE DU CROC-ROUGE =======================
// compagnons récurrents : ils se souviennent de toi (lien 0-100) et réagissent pendant les missions
export const COMPAGNONS = [
  { id: 'kordath', nom: 'Kordath', titre: 'le Roc', arme: 'epee', couleur: '#5a7aaa',
    debut: ['…On y va. Reste derrière moi.', 'Pas de discours. On frappe, on rentre.'],
    blesse: ['…C\'est rien. Continue.', 'Tch… ils frappent fort.'],
    joueurBlesse: ['Recule ! Je les retiens !', 'Ne meurs pas maintenant, pas ici.'],
    eveil: ['…Cette aura. Qui es-tu vraiment ?', 'Hm. J\'avais raison de te suivre.'],
    boss: ['Celui-là… je le sens dans mes os.', 'Ensemble. Maintenant.'],
    fin: ['…Bien joué.', 'On boira un verre. Toi et moi.'] },
  { id: 'sylvane', nom: 'Sylvane', titre: 'Œil-de-Lynx', arme: 'arbalete', couleur: '#5aaa7a',
    debut: ['Je couvre tes arrières, promis !', 'Le vent nous est favorable aujourd\'hui.'],
    blesse: ['Aïe… je… je tiens encore !', 'Ne t\'occupe pas de moi, avance !'],
    joueurBlesse: ['Non ! Tiens bon, je t\'en supplie !', 'Je vise ses yeux, recule !'],
    eveil: ['Incroyable… tu… tu brilles !', 'Alors c\'était ça, ta vraie force…'],
    boss: ['J\'ai peur… mais je ne fuirai pas.', 'Son aura… elle me glace le sang.'],
    fin: ['On a réussi ! On a vraiment réussi !', 'Merci… d\'être resté avec nous.'] },
  { id: 'nyxara', nom: 'Nyxara', titre: 'la Pyromane', arme: 'baton', couleur: '#aa5a8a',
    debut: ['Enfin un peu d\'action ! J\'espère que tu suis, toi.', 'Essaie de ne pas te faire griller par mes flammes, hein.'],
    blesse: ['Hé ! Personne ne touche à mes cheveux !', 'Ça… ça commence à piquer.'],
    joueurBlesse: ['Déjà fatigué ? Allez, debout !', 'T\'avise pas de mourir, j\'ai parié sur toi !'],
    eveil: ['Tu nous as caché ÇA depuis le début ?!', 'Ok… je retire tout ce que j\'ai dit sur toi.'],
    boss: ['Ohoh… lui, il est pour moi.', 'Qu\'il vienne ! Je vais le réduire en cendres !'],
    fin: ['Pas mal, pas mal… pour un débutant !', 'Tu me dois une tournée, héros.'] },
];
// clients de la taverne : moqueries quand tu sembles faible, respect une fois ta force révélée
export const TAVERNE_LIGNES = {
  moque: ['Hé le minus, t\'es perdu ?', 'Avec cette puissance, commande plutôt du lait.', 'Recule, tu sens la défaite.', 'Regardez-moi ce débutant… mdr.', 'Le bout de la file, c\'est là-bas, gamin.', 'T\'as pris ton arme au marché aux puces ?', 'Pousse-toi, j\'ai pas que ça à faire.', 'On m\'a dit que les rats aussi faisaient la queue ici.'],
  passeDevant: ['Pousse-toi, minus. Les forts passent devant.', 'Je passe avant toi, ça te pose un problème ?', 'Les faibles attendent. C\'est la règle.'],
  choc: ['… !', 'Qu… quoi ?!', 'C\'est… c\'est une blague ?', 'Cette aura… !', 'J\'ai… j\'ai rien dit, hein.'],
  respect: ['Passe, je t\'en prie.', 'Pardon… je ne t\'avais pas reconnu.', 'Après toi, maître.', 'Je… je retourne au fond de la file.'],
  salutRespect: ['Le voilà… personne ne le provoque.', 'C\'est lui, celui à l\'aura écarlate.', 'Salut, champion.', 'Une tournée pour la légende !'],
  rire: ['Pfff, c\'est tout ?', 'Ahahah ! Tu m\'as fait peur… de rire.', 'Joli feu d\'artifice. Maintenant dégage.'],
  ambiance: ['Le Gouffre a encore avalé trois groupes hier…', 'Paraît que l\'Ordre de la Lame Noire recrute.', 'Mira, remets-moi ça !', 'Quelqu\'un a vu Brakkus ? Il me doit 2 000 pièces.', 'J\'ai entendu un dragon rugir sous la Place.', 'Les missions de la Main Écarlate, c\'est du suicide.'],
};
export const RIVAL_TAVERNE = { nom: 'Brakkus', titre: 'le Colosse', guilde: '[FR] LA HORDE', arme: 'epee' };
// missions d'aventure du tableau : ennemis d'élite à l'aura meurtrière
export const FACTIONS = [
  { nom: 'l\'Ordre de la Lame Noire', couleur: '#ff2a2a', tenue: '#140808', elites: ['Vesper', 'Kael', 'Riven', 'Morgath', 'Selka', 'Draven'], titres: ['aux Mille Lames', 'le Boucher', 'l\'Ombre Rouge', 'Lame-Sanglante'] },
  { nom: 'les Chiens de Cendre', couleur: '#ff8a2a', tenue: '#2a1a0a', elites: ['Ashra', 'Grim', 'Toben', 'Raska', 'Vorn', 'Ilda'], titres: ['le Brûlé', 'Croc-de-Fer', 'la Cendreuse', 'le Chien Fou'] },
  { nom: 'la Main Écarlate', couleur: '#d02aff', tenue: '#140a1a', elites: ['Nihil', 'Seraph', 'Oriane', 'Lucan', 'Myrr', 'Zhaal'], titres: ['l\'Exécuteur', 'aux Yeux Morts', 'le Sans-Visage', 'la Faucheuse'] },
];
export const MISSIONS = [
  { id: 'convoi', titre: 'Le convoi disparu', resume: 'Un convoi d\'or a disparu sur la route de la forêt. Retrouve les responsables et récupère la cargaison.', boss: { nom: 'Varek', titre: 'Lame de l\'Abîme', arme: 'epee' }, intro: 'Tiens, tiens… des chiens envoyés par la Taverne ?', phase2: 'Tu m\'obliges à libérer ma vraie lame. Tu vas le regretter.', mort: 'Impossible… battu… par toi… ?' },
  { id: 'pretresse', titre: 'La prêtresse captive', resume: 'Une prêtresse du Sanctuaire a été enlevée. Ses ravisseurs préparent un rituel au cœur des bois.', boss: { nom: 'Ysmera', titre: 'Sorcière du Voile', arme: 'baton' }, intro: 'Le rituel est presque achevé. Ton sang le complétera.', phase2: 'Assez joué ! Le Voile se déchire pour moi !', mort: 'Le Voile… se referme… non…' },
  { id: 'chasse', titre: 'La chasse au traître', resume: 'Un ancien héros de la Place a trahi les siens. Il se cache avec ses mercenaires. Ramène sa tête.', boss: { nom: 'Orsen', titre: 'le Traître', arme: 'arbalete' }, intro: 'Ils t\'ont envoyé, toi ? Ils me sous-estiment toujours.', phase2: 'Fini de jouer. Je vais te montrer pourquoi on m\'appelait le Héros.', mort: 'J\'étais… comme toi… avant…' },
  { id: 'gouffre', titre: 'Le gardien du gouffre', resume: 'Une créature humanoïde sort du gouffre la nuit et dévore les voyageurs. Arrête-la avant l\'aube.', boss: { nom: 'Morrigar', titre: 'le Dévoreur', arme: 'orage' }, intro: 'Mmmh… de la chair qui sent la peur.', phase2: 'GRAAAAH ! Je vais te broyer les os !', mort: 'La faim… s\'arrête… enfin…' },
  { id: 'tournoi', titre: 'Le tournoi sanglant', resume: 'Une guilde organise des combats clandestins. Infiltre-toi et fais tomber son champion.', boss: { nom: 'Dame Kesha', titre: 'Championne invaincue', arme: 'assassin' }, intro: 'Un nouveau jouet ? Essaie de durer plus de dix secondes.', phase2: 'Personne ne m\'a jamais forcée à sortir mes deux lames.', mort: 'Invaincue… jusqu\'à aujourd\'hui…' },
  { id: 'relique', titre: 'La relique maudite', resume: 'Des pillards ont volé une relique qui corrompt ceux qui la portent. Leur chef n\'est plus humain.', boss: { nom: 'Haldor', titre: 'le Corrompu', arme: 'baton' }, intro: 'La relique… me parle… elle veut ton âme.', phase2: 'Elle me donne TOUT son pouvoir !', mort: 'Merci… de m\'avoir… libéré…' },
];

// ======================= RENOMMÉE : exploits réels du joueur, titres, et ce qu'en disent les PNJ =======================
// t3 : à la 3e personne (« Thomas a… »), t2 : à la 2e (« tu as… »)
export const EXPLOITS = {
  chef_oeuvre:    { pts: 40, t3: 'a forgé de ses propres mains un chef-d’œuvre', t2: 'as forgé un chef-d’œuvre de tes mains' },
  premier_boss:   { pts: 10, t3: 'a abattu son premier gardien de la Brèche', t2: 'as abattu ton premier gardien de la Brèche' },
  cryptes:        { pts: 15, t3: 'a vidé les Cryptes Oubliées de leurs quatre gardiens', t2: 'as vidé les Cryptes Oubliées' },
  cryptes_solo:   { pts: 25, t3: 'a nettoyé seul les Cryptes Oubliées', t2: 'as nettoyé seul les Cryptes Oubliées' },
  forteresse:     { pts: 35, t3: 'a fait tomber les gardiens de la Forteresse des Ossements', t2: 'as fait tomber la Forteresse des Ossements' },
  forteresse_solo:{ pts: 70, t3: 'a pris seul la Forteresse des Ossements', t2: 'as pris seul la Forteresse des Ossements' },
  gouffre:        { pts: 80, t3: 'a vaincu les gardiens du Gouffre Écarlate (T8)', t2: 'as vaincu les gardiens du Gouffre Écarlate' },
  gouffre_solo:   { pts: 170, t3: 'a terrassé à lui seul les gardiens du Gouffre Écarlate (T8)', t2: 'as terrassé seul les gardiens du Gouffre Écarlate' },
  abime:          { pts: 260, t3: 'est revenu vivant de l’Abîme Écarlate', t2: 'es revenu vivant de l’Abîme' },
  abime_solo:     { pts: 520, t3: 'a vaincu seul l’Abîme Écarlate', t2: 'as vaincu seul l’Abîme' },
  sanctuaire:     { pts: 60, t3: 'a libéré le Sanctuaire d’Émeraude', t2: 'as libéré le Sanctuaire d’Émeraude' },
  relique:        { pts: 30, t3: 'a trouvé une crypte cachée et emporté sa relique', t2: 'as trouvé une crypte cachée et sa relique' },
  relique_legende:{ pts: 120, t3: 'porte une relique légendaire arrachée à ses gardiens', t2: 'portes une relique légendaire' },
  coffre_legende: { pts: 60, t3: 'a ouvert un coffre légendaire dans la Brèche', t2: 'as ouvert un coffre légendaire' },
  goulet_victoire:{ pts: 25, t3: 'a mené son camp à la victoire dans le Goulet des Braises', t2: 'as gagné le Goulet des Braises' },
  goulet_capture: { pts: 40, t3: 'a rapporté lui-même le drapeau ennemi au Goulet', t2: 'as rapporté le drapeau ennemi au Goulet' },
  arene_10:       { pts: 40, t3: 'a remporté dix combats d’arène', t2: 'as remporté dix combats d’arène' },
  arene_50:       { pts: 120, t3: 'a remporté cinquante combats d’arène', t2: 'as remporté cinquante combats d’arène' },
  duel_brakkus:   { pts: 45, t3: 'a battu Brakkus en duel devant toute la taverne', t2: 'as battu Brakkus en duel' },
  mission_5:      { pts: 70, t3: 'a réussi une mission cinq étoiles du Croc-Rouge', t2: 'as réussi une mission cinq étoiles' },
  defense_ile:    { pts: 30, t3: 'a repoussé des pillards sur son île', t2: 'as repoussé des pillards sur ton île' },
  ombre_rare:     { pts: 90, t3: 'possède une arme d’ombre, une chance sur mille', t2: 'possèdes une arme d’ombre' },
  niveau_25:      { pts: 20, t3: 'a atteint le niveau 25', t2: 'as atteint le niveau 25' },
  niveau_50:      { pts: 50, t3: 'a atteint le niveau 50', t2: 'as atteint le niveau 50' },
  niveau_80:      { pts: 120, t3: 'a atteint le niveau 80', t2: 'as atteint le niveau 80' },
  rang_argent:    { pts: 20, t3: 'est monté au rang Argent', t2: 'es monté au rang Argent' },
  rang_or:        { pts: 45, t3: 'est monté au rang Or', t2: 'es monté au rang Or' },
  rang_diamant:   { pts: 90, t3: 'a atteint le rang Diamant', t2: 'as atteint le rang Diamant' },
  rang_champion:  { pts: 160, t3: 'est devenu Champion', t2: 'es devenu Champion' },
  rang_grand:     { pts: 300, t3: 'est Grand Champion de la Brèche', t2: 'es Grand Champion' },
  ombre_arene:    { pts: 25, t3: 'a une ombre qui gagne des combats d’arène en son nom', t2: 'as une ombre qui gagne l’arène en ton nom' },
};
export const TITRES_RENOM = [[0, 'Inconnu', '#a89a8a'], [40, 'Remarqué', '#c8d8e8'], [120, 'Connu sur la Place', '#8ad0ff'], [300, 'Célèbre', '#b88aff'], [700, 'Héros de la Brèche', '#ffb84a'], [1500, 'Légende vivante', '#ff5a3a']];
// ce que disent les PNJ : général (10+), selon la renommée (palier 0-5), et sur un exploit précis ({nom}, {exploit} à la 2e personne)
export const PAROLES_PNJ = {
  borin: {
    general: ['Des potions fraîches, tirées ce matin ! Enfin… ce matin d’hier.', 'Mes prix sont honnêtes. Plus honnêtes que mes cousins, en tout cas.', 'La Brèche a craché trois aventuriers à moitié cuits ce matin. Mauvais pour les affaires.', 'Tu veux un conseil gratuit ? Ne bois jamais l’eau du puits de cendres.', 'J’ai vendu une épée à un gars hier. Il est revenu sans bras. Pas de remboursement.', 'Le vent tourne, petit. Je le sens à mes genoux.', 'Mira me doit encore trois tonneaux. Si tu passes à la taverne, rappelle-le-lui.', 'Une bonne armure, c’est comme un bon ami : ça coûte cher et ça te sauve la vie.', 'On dit que les squelettes du Gouffre gardent leurs pièces dans leurs côtes.', 'Reviens quand tu auras de l’argent. Ou des histoires. Les deux se vendent.', 'Tu as l’air fatigué. Une potion ? Non ? Tant pis pour toi.', 'Les marchands de l’Est parlent d’une crypte cachée dans chaque donjon. Balivernes… sûrement.'],
    renom: [['Encore un nouveau visage. Tu ne feras pas long feu, mais achète d’abord.', 'Premier passage ? Les morts aussi ont commencé comme toi.'], ['Tiens, je t’ai déjà vu passer, toi. Tu reviens entier, c’est bon signe.', 'On commence à prononcer ton nom au marché, {nom}.'], ['{nom} ! Les gens demandent ce que tu achètes. Je leur dis que c’est secret.', 'Depuis que tu passes ici, mes ventes de potions ont doublé. Les gens veulent t’imiter.'], ['Le célèbre {nom} à mon étal ! Je devrais afficher un écriteau.', 'Les apprentis me demandent l’épée que tu portais. Je leur vends des copies.'], ['{nom}, le Héros de la Brèche… Prends ce que tu veux. Non, je plaisante. Paie quand même.', 'Les bardes chantent ton nom, {nom}. Faux, mais avec cœur.'], ['Une légende vivante devant moi… Mes petits-enfants ne me croiront jamais.', 'On raconte que même les gardiens de l’Abîme tremblent quand tu passes, {nom}.']],
    exploit: ['Alors c’est vrai, {nom} ? Tu {exploit} ? Je l’ai vendu à tout le monde comme une rumeur !', 'Toute la Place répète que tu {exploit}. Mes clients veulent toucher ton armure.', 'Depuis que tu {exploit}, j’ai augmenté mes prix. C’est la célébrité, mon grand.', 'On m’a juré que tu {exploit}. Si c’est vrai, je te dois un verre.'],
  },
  ysolde: {
    general: ['Les runes ne mentent jamais. Les gens, oui.', 'Chaque gravure demande un peu de ton âme. Juste un peu.', 'J’ai vu une rune se briser cette nuit. Mauvais présage… ou mauvaise lame.', 'Approche ton arme. Elle me parle déjà.', 'Le cristal chante plus fort aujourd’hui. Quelque chose bouge dans la Brèche.', 'Je grave depuis trois cents ans. Ne me presse pas.', 'Les ombres aiment les lames gravées. Prends garde à ce que tu attires.', 'Une rune ratée n’est pas un échec. C’est une leçon chère.', 'Le bleu de mon cercle vient de la mer des Îles. Personne ne sait pourquoi.', 'Tu as les mains d’un guerrier et le regard d’un curieux. Bon mélange.', 'Ne touche pas au cristal. Il est plus vieux que la Place.'],
    renom: [['Ton nom n’est encore gravé nulle part. Ça viendra.', 'Je ne te connais pas, mais ton arme, si : elle a soif.'], ['Les pierres commencent à retenir ton pas, {nom}.', 'Ton aura a changé depuis la dernière fois.'], ['On murmure ton nom près du cristal, {nom}.', 'Tes armes reviennent toujours plus marquées. Tu combats bien.'], ['Ton nom résonne dans mes runes, {nom}. C’est rare.', 'Même le cristal brille plus fort quand tu passes.'], ['{nom}… les anciens gravaient les noms des héros dans la pierre. Je vais graver le tien.', 'Ton âme pèse lourd, Héros. Lourd et brillant.'], ['Une légende… Mes runes tremblent de te servir, {nom}.', 'Les morts eux-mêmes parlent de toi dans mes visions.']],
    exploit: ['Les runes me l’ont montré avant toi : tu {exploit}.', 'Tu {exploit}, {nom}… Ta lame mérite une rune digne de ça.', 'J’ai senti l’écho jusqu’ici quand tu {exploit}.'],
  },
  aldric: {
    general: ['Les Îles t’attendent. Elles attendent tout le monde, mais toi un peu plus.', 'Ma barque n’a jamais coulé. Deux fois.', 'Les pillards ne dorment jamais. Garde ton île à l’œil.', 'Le vent des Îles sent le sel et l’or.', 'Un bon intendant vaut dix soldats. Paie bien Oswin.', 'J’ai vu une île flotter, une fois. Je n’ai plus jamais bu de rhum.', 'Les ressources ne poussent pas toutes seules. Enfin… presque.', 'Il paraît qu’un joueur a perdu son île aux dés. Ne fais pas ça.', 'La mer est calme aujourd’hui. Méfie-toi des jours calmes.', 'Tu as le pied marin ? Non ? Ça viendra.'],
    renom: [['Un nouveau propriétaire ? Bienvenue dans la grande famille des endettés.', 'Tes premières terres, hein ? Ne les perds pas.'], ['Les autres insulaires parlent de toi, {nom}.', 'Ton île commence à faire envie.'], ['Les pillards hésitent avant d’attaquer chez {nom}, paraît-il.', 'On me demande ta route. Je ne la donne pas.'], ['Le célèbre {nom} dans ma barque ! Je devrais faire payer double.', 'Les cartographes ont mis ton nom sur leurs cartes.'], ['Les Îles entières savent qui tu es, Héros.', 'On raconte que ton drapeau fait fuir les pillards.'], ['Légende des mers et de la Brèche… monte, {nom}, la barque est à toi.', 'Même les mouettes saluent ton passage, {nom}.']],
    exploit: ['Tu {exploit} ? Les marins vont en parler pendant des semaines.', 'Depuis que tu {exploit}, on me demande si je te connais. Je dis oui. Fièrement.', 'Un passager m’a juré que tu {exploit}. Je l’ai cru.'],
  },
  mira: {
    general: ['Essuie tes bottes, la Brèche colle aux semelles.', 'Le ragoût est chaud. Ne demande pas ce qu’il y a dedans.', 'Ici, on se bat dehors. Dedans, on boit.', 'Brakkus a encore cassé une table. Il la paiera. Un jour.', 'Si tu cherches du travail, regarde le tableau des missions.', 'L’oracle n’a pas dormi depuis trois jours. Elle voit des choses.', 'Je sers tout le monde. Même ceux qui ne payent pas… une fois.', 'Tu veux le secret de mon hydromel ? Non. Personne ne l’aura.', 'Les nouveaux font toujours la même erreur : ils parlent trop fort.', 'Assieds-toi, souffle un peu. La Brèche ne va pas s’envoler.', 'On raconte des histoires ici. Certaines sont vraies.'],
    renom: [['Toi, je ne te connais pas encore. Commande, et on verra.', 'Un inconnu de plus. Ils finissent tous par avoir un nom… ou une tombe.'], ['{nom}, c’est ça ? On commence à parler de toi au comptoir.', 'Ta tête me dit quelque chose. Ah oui : tu reviens vivant.'], ['{nom} ! La table du fond t’attend, les habitués veulent t’écouter.', 'Les clients me demandent si tu passes ce soir.'], ['Le célèbre {nom} ! La maison offre… la moitié du verre.', 'Depuis que tu viens ici, je refuse du monde.'], ['Héros de la Brèche… Les bardes ont réécrit leurs chansons pour toi, {nom}.', 'Brakkus fait semblant de ne pas te voir. C’est le plus beau compliment qu’il sait faire.'], ['Légende vivante dans ma taverne… Je vais encadrer ta chope, {nom}.', 'Tout le Croc-Rouge se lève quand tu entres. Moi aussi, mais c’est pour te servir.']],
    exploit: ['C’est toi qui {exploit} ? Tout le comptoir ne parle que de ça !', 'On m’a raconté que tu {exploit}. La tournée est pour toi… non, sur toi !', 'Brakkus refuse de croire que tu {exploit}. Je l’ai vu pâlir quand même.', 'Depuis que tu {exploit}, l’oracle prononce ton nom dans son sommeil.'],
  },
  oswin: {
    general: ['Les comptes sont tenus, maître. Au sou près.', 'Les ouvriers réclament une pause. Je leur ai accordé trente secondes.', 'Le bois rentre bien, la pierre un peu moins.', 'Un bâtiment de plus et il nous faudra un second entrepôt.', 'J’ai repéré des voiles au loin. Probablement des marchands. Probablement.', 'Les récoltes seront bonnes si les pillards nous laissent tranquilles.', 'Je dors peu. Une île ne se gère pas toute seule.', 'Un ouvrier a vu une ombre rôder près des réserves. Elle n’a rien volé.', 'Nos murs tiendront. Peut-être.', 'Voulez-vous le rapport long ou le rapport court ? Le court : tout va bien.'],
    renom: [['Votre île est modeste, maître. Mais propre.', 'Les voisins ne savent pas encore qui vous êtes.'], ['On commence à respecter cette île, maître.', 'Les marchands nous font de meilleurs prix depuis peu.'], ['Votre nom attire des travailleurs, maître {nom}.', 'Les pillards nous évitent un peu plus.'], ['Des voyageurs viennent juste pour voir l’île du célèbre {nom}.', 'Je dois refuser des volontaires, maître.'], ['Les ouvriers chantent votre nom en travaillant, maître.', 'L’île du Héros de la Brèche… je suis fier de la tenir.'], ['Servir une légende vivante… ma mère n’y croirait pas, maître.', 'Même les pillards saluent en passant au large.']],
    exploit: ['Les ouvriers racontent que le maître {exploit3}. Ils travaillent deux fois plus.', 'On raconte jusqu’ici que mon maître {exploit3}. Je l’ai noté dans les registres.', 'Toute l’île sait que le maître {exploit3}. J’ai doublé les rations pour fêter ça.'],
  },
};
PAROLES_PNJ.clients = {
  general: ['Encore un qui croit pouvoir faire la loi ici.', 'Range ton arme, on boit tranquille.', 'T’as vu la taille de son épée ? Il compense.', 'Moi, à ton âge, je vidais déjà le Gouffre. Enfin… presque.', 'Le tableau des missions, c’est pour les vrais. Pas pour les touristes.', 'Mira, une autre ! Et une pour le nouveau, qu’il se détende.', 'Paraît que l’oracle a vu un dragon dans sa soupe.', 'J’ai perdu mon équipe dans les Cryptes. Je bois à leur santé… enfin, à leurs os.', 'Tu fais la queue comme tout le monde, compris ?', 'Si tu cherches Brakkus, il est là-bas. Si tu ne le cherches pas, c’est lui qui te trouvera.', 'On dit que les ombres parlent à certains joueurs. Je préfère ne pas savoir.'],
  renom: [['Un inconnu… Mira, garde un œil sur tes chopes.', 'Toi, t’es qui déjà ?'], ['Hé, c’est pas {nom}, celui dont on parle un peu ?', 'Je t’ai vu revenir de la Brèche, toi. En un seul morceau.'], ['{nom} ! Viens t’asseoir, raconte-nous un peu.', 'Laissez passer {nom}, il a du travail, lui.'], ['Le célèbre {nom}… on peut toucher ton armure ?', 'Silence, c’est {nom} qui entre.'], ['Le Héros de la Brèche ! La prochaine tournée est pour lui… je veux dire, PAR lui.', 'Je raconterai à mes enfants que j’ai bu dans la même taverne que {nom}.'], ['Tout le monde debout ! {nom}, la légende !', 'Même Brakkus baisse les yeux quand {nom} passe.']],
  exploit: ['C’est toi qui {exploit} ? Raconte, raconte !', 'J’ai parié que tu {exploit}. J’ai gagné une fortune grâce à toi.', 'Brakkus dit que c’est faux, que tu {exploit}. Moi je te crois.', 'Depuis que tu {exploit}, ma femme ne parle que de toi.'],
};
// ce que les autres joueurs disent de toi dans le chat de la Place
export const RUMEURS_CHAT = ['vous avez vu ? {nom} {exploit}', 'paraît que {nom} {exploit}, sérieux ?', '{nom} {exploit}… c’est quoi ce niveau', 'gg {nom}, j’ai vu que tu {exploit2}', 'qqn a le build de {nom} ? il {exploit}', 'on m’a dit que {nom} {exploit}, je demande des preuves', 'respect à {nom}, il {exploit}', '{nom} {exploit}, il faut qu’il nous carry', 'moi aussi un jour je serai comme {nom}', 'je viens de croiser {nom} sur la Place, c’est lui qui {exploit}'];

// ---- Apparat : auras de prestige (cosmétiques, au prix fort) ----
export const APPARAT = [
  { id: 'ecarlate', nom: 'Aura meurtrière écarlate', desc: 'Une aura de sang qui fait trembler tout ce qui respire.', prix: 3000000, c1: '#ff2a2a', c2: '#3a0000', c3: '#ffb08a' },
  { id: 'neant', nom: 'Aura du Néant', desc: 'Les ombres elles-mêmes reculent devant toi.', prix: 6000000, c1: '#b05aff', c2: '#12001e', c3: '#e8c8ff' },
  { id: 'celeste', nom: 'Aura céleste', desc: 'La lumière des anciens rois. Rares sont ceux qui la portent.', prix: 12000000, c1: '#ffd27a', c2: '#5a3a00', c3: '#fff4d0' },
];
// ce que crient ceux qui voient l'aura se déployer
export const CHOC_AURA = {
  ennemi: ['Qu… quelle est cette puissance ?!', 'Mes jambes… elles ne bougent plus…', 'Ce n’est pas un humain…', 'Reculez ! RECULEZ !', 'Je… je ne veux pas mourir ici !', 'Le maître ne m’a jamais parlé de ça…'],
  boss: ['Cette aura… impossible.', 'Enfin un adversaire digne de moi.', 'Tu caches bien ton jeu, mortel.', 'Même mon maître n’avait pas cette pression…'],
  pnj: ['Par tous les dieux…', 'J’en ai renversé ma chope…', 'C’est donc ça, la puissance d’une légende ?', 'Je… je ferai un prix. Un très bon prix.', 'Mes runes tremblent…'],
  bot: ['wtf c’est quoi cette aura', 'ok là je recule', 'il a payé combien pour ça ??', 'gg je fuis', 'mes oreilles sifflent…', 'respect.'],
  ombre: ['Maître… tu es magnifique.', 'Voilà pourquoi nous te suivons.', 'Ils te craignent enfin comme il se doit.'],
};

// ======================= LE DOMAINE : château évolutif, ferme, serviteurs, trésor =======================
export const DOMAINE_NIVEAUX = [
  { nom: 'Campement', desc: 'Quelques tentes autour d’un feu. Tout commence ici.', revenu: 8000, cap: 80000, cout: 0, res: {} },
  { nom: 'Fortin', desc: 'Une palissade, deux tours de guet et une grande salle.', revenu: 20000, cap: 260000, cout: 600000, res: { bois: 300 } },
  { nom: 'Château', desc: 'Des murs de pierre, quatre tours et un donjon.', revenu: 50000, cap: 800000, cout: 2500000, res: { bois: 800, minerai: 500 } },
  { nom: 'Forteresse', desc: 'Tours jumelles, braseros et bannières sur chaque rempart.', revenu: 110000, cap: 2000000, cout: 9000000, res: { bois: 1600, minerai: 1200, recolte: 800 } },
  { nom: 'Citadelle', desc: 'Cristaux d’or et lumière des anciens rois. Une légende de pierre.', revenu: 240000, cap: 5000000, cout: 30000000, res: { bois: 3000, minerai: 2500, recolte: 2000 } },
];
export const PRIX_DOMAINE = 1000000;
export const SERVITEURS = {
  fermier: { nom: 'Lisette', role: 'Fermière', modele: 'Rogue', prix: 150000, niv: 0, desc: '+20 % de revenus : les champs nourrissent tout le domaine.' },
  cuisinier: { nom: 'Margot', role: 'Cuisinière', modele: 'Rogue', prix: 300000, niv: 1, desc: 'Un festin à chaque visite : +8 % de vie pendant 30 min.' },
  forgeron: { nom: 'Gunnar', role: 'Forgeron', modele: 'Barbarian', prix: 400000, niv: 1, desc: '+4 % de dégâts en permanence.' },
  garde: { nom: 'Aldwin', role: 'Capitaine de la garde', modele: 'Knight', prix: 800000, niv: 2, desc: 'Repousse la plupart des voleurs de ton trésor.' },
  intendant: { nom: 'Corvin', role: 'Intendant', modele: 'Mage', prix: 1200000, niv: 2, desc: '+30 % de revenus.' },
  ecuyer: { nom: 'Elya', role: 'Écuyère', modele: 'Rogue_Hooded', prix: 2000000, niv: 3, desc: '+5 % de vitesse de déplacement.' },
};
export const PAROLES_SERVITEURS = {
  fermier: ['Les carottes poussent bien cette saison, maître.', 'J’ai chassé trois corbeaux ce matin. Ils reviendront.', 'Le blé sent bon. C’est bon signe.', 'Si vous voulez du pain frais, il faudra attendre demain.', 'Le moulin grince. Il faudrait l’huiler.', 'La terre ici est riche. Comme vous, maître.'],
  cuisinier: ['Asseyez-vous, maître, le ragoût est presque prêt.', 'J’ai mis double ration de viande pour vous.', 'Ne dites rien à Gunnar, il a déjà mangé deux fois.', 'Une bonne soupe vaut une bonne armure.', 'Goûtez ça. Non, ne demandez pas ce que c’est.', 'Le feu doit rester doux, sinon tout brûle.'],
  forgeron: ['Ton arme a besoin d’un coup de marteau, maître.', 'Le fer chante quand il est bien chauffé.', 'J’ai forgé une lame pour un roi, autrefois. Il est mort quand même.', 'Encore trois coups et c’est fini.', 'Le charbon arrive demain. J’espère.', 'Chaque coup que tu donnes, je l’ai forgé un peu.'],
  garde: ['Les remparts sont sûrs, maître.', 'Des voleurs rôdent parfois la nuit. Ils repartent les mains vides.', 'J’ai doublé la garde près du trésor.', 'Personne n’entre sans que je le sache.', 'Mes hommes s’entraînent à l’aube.', 'Le domaine dort tranquille grâce à vous… et un peu à moi.'],
  intendant: ['Les comptes sont tenus au sou près, maître.', 'Le trésor grossit. Lentement, mais sûrement.', 'Je vous conseille d’agrandir les murs avant l’hiver.', 'Les marchands demandent votre sceau sur trois contrats.', 'Nous dépensons trop en chandelles. Je m’en occupe.', 'Votre renommée attire des travailleurs. C’est excellent pour les revenus.'],
  ecuyer: ['Les montures sont prêtes, maître.', 'J’ai brossé ta cape. Elle en avait besoin.', 'Tu marches vite aujourd’hui. Bon signe.', 'Le palefrenier dit que tu es le meilleur maître du royaume.', 'J’ai graissé tes bottes. Tu iras plus loin.', 'Un jour, tu m’apprendras à me battre ?'],
};
