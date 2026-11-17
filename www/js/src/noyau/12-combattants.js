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
// matchmaking sur la puissance réelle : même puissance d'équipement ET même niveau que le joueur
function calerSurJoueur(d, ecartNiv = 3, bonusNiv = 0) {
  const nJ = niveauHeros(J.equip);
  d.niv = Math.max(1, Math.min(100, Math.max(nivBot(d.equip, 0) - 12, nJ + ri(-ecartNiv, ecartNiv) + bonusNiv)));
  d.ip = statsHeros(d.equip, d.niv).ip;
  return d;
}
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
// tenues : le chevalier troque son armure de plaques contre un équipement de cuir de rôdeur, le barbare enlève sa tête d'ours
// couleurs des tuniques : celle du joueur dépend de son armure de torse, celles des autres joueurs sont variées
const PALETTE_TENUES = ['#2a4a9a', '#7a1a2a', '#3a3a46', '#5a2a8a', '#6a4a24', '#1a5a4a', '#9a8a62', '#1c1c24', '#2a6a8a', '#8a3a1a', '#4a5a2a', '#5a1a5a'];
const TENUE_TIER = [null, '#6a4a24', '#8a6a3a', '#1a5a4a', '#2a4a9a', '#7a1a2a', '#5a2a8a', '#1c1c24', '#e8e0d0'];
function tenue(a) {
  if (a.cle === 'Knight' && !a._tenue) { a._tenue = true; for (const [c, s] of [['Knight_Body', 'Rogue_Body'], ['Knight_ArmLeft', 'Rogue_ArmLeft'], ['Knight_ArmRight', 'Rogue_ArmRight'], ['Knight_LegLeft', 'Rogue_LegLeft'], ['Knight_LegRight', 'Rogue_LegRight']]) a.remplacerPiece(c, 'Rogue', s); }
  if (a.cle === 'Barbarian' && a.nodes.Barbarian_Hat) a.nodes.Barbarian_Hat.visible = false;
  if (a.nodes.Knight_Helmet) a.nodes.Knight_Helmet.visible = false;
}
function habiller(a, equip, def) {
  tenue(a);
  a.tenueCouleur(PALETTE_TENUES[Math.floor(Math.random() * PALETTE_TENUES.length)]);
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
// puissance réelle du joueur : dégâts par seconde (attaque + sorts + bonus de classe) et vie effective (vie / part de dégâts encaissés)
const BONUS_CLASSE = { invocateur: 1.5, demon: 1.5, orage: 1.7, ombre: 1.45, assassin: 1.4, arc: 1.3 }; // classes à invocations / zone : plus fortes que leur fiche
function puissanceReelleJoueur() {
  const st = joueur && joueur.st || statsJoueur(); const type = (J.equip.arme || {}).type || 'epee';
  let sorts = 0; for (const k of ['Q', 'W', 'E']) { const s = joueur && joueur.sorts && joueur.sorts[k]; if (s && s.mult && s.cd) sorts += s.mult / Math.max(2, s.cd); }
  const dps = st.degats * (st.vitesseAtk * (1 + st.crit / 200) + sorts) * (BONUS_CLASSE[type] || 1);
  const T = st.tal || {};
  const ehp = st.pvMax / Math.max(0.15, (1 - st.reduction) * (1 - Math.min(0.5, T.reduc || 0)));
  return { dps, ehp, ip: st.ip };
}
// matchmaking JcJ sur la puissance réelle : chaque bot est recalé pour valoir le joueur (× la difficulté du rang)
function recalerBot(a, camp) {
  if (!joueur || !joueur.st) return;
  const P = puissanceReelleJoueur();
  let sorts = 0; for (const id of sortsArme(a.equip.arme)) { const s = SORTS[id]; if (s && s.mult && s.cd) sorts += s.mult / Math.max(2, s.cd); }
  const dpsB = a.dmg * (a.st.vitesseAtk * (1 + a.st.crit / 200) + sorts);
  const ehpB = a.pvMax / Math.max(0.15, 1 - a.reduction);
  const k = camp === 'ennemi' ? 1 : 0.92; // les coéquipiers sont un peu en dessous du joueur : c'est toi qui portes l'équipe
  const kd = Math.max(0.25, Math.min(8, P.dps / Math.max(1, dpsB) * k * rnd(0.92, 1.08) * (a.data && a.data.kDg || 1)));
  const ke = Math.max(0.25, Math.min(12, P.ehp / Math.max(1, ehpB) * k * rnd(0.92, 1.08) * (a.data && a.data.kPv || 1)));
  a.dmg *= kd * (camp === 'ennemi' ? kdg(camp) : 1); a.pvMax = Math.round(a.pvMax * ke * (camp === 'ennemi' ? kpv(camp) : 1)); a.pv = a.pvMax;
  a.ip = Math.max(100, Math.round(P.ip + rnd(-35, 35) + (camp === 'ennemi' ? 12 * rangK() : 0)));
  if (a.data) a.data.ip = a.ip;
  a._dps = dpsB * kd * (camp === 'ennemi' ? kdg(camp) : 1); a._ehp = a.pvMax / Math.max(0.15, 1 - a.reduction);
}
// résilience JcJ : entre joueurs, un affrontement dure environ 12 s quelle que soit la puissance (plus de mort en un coup)
const TTK_JCJ = 12;
function puissanceJ() { if (!joueur._P || G.t - joueur._PT > 2) { joueur._P = puissanceReelleJoueur(); joueur._PT = G.t; } return joueur._P; }
function dpsDe(x) { if (!x) return 0; if (x === joueur || x.invoc) return puissanceJ().dps; return x._dps || 0; }
function ehpDe(x) { if (x === joueur) return puissanceJ().ehp; if (x._ehp) return x._ehp; return (x.pvMax || 1) / Math.max(0.15, 1 - (x.reduction || 0)); }
function facteurJcJ(att, cible, d) { const dps = dpsDe(att); if (!(dps > 0)) return d; return d * Math.min(1, ehpDe(cible) / (dps * TTK_JCJ)); }
function creerCombattant(pos, data, camp = 'ennemi') {
  const equip = data.equip, arme = equip.arme, def = ARMES[arme.type];
  const a = new Acteur(data.modele || def.model, { hauteur: 2.0 });
  habiller(a, equip, def);
  if (!data.niv) data.niv = nivBot(equip);
  const st = statsHeros(equip, data.niv);
  { const k = Math.min(0.32, data.niv * 0.0035); st.degats *= 1 + k; st.pvMax *= 1 + k; } // équivalent des talents d'un joueur de ce niveau
  a.root.position.copy(pos); G.scene.add(a.root);
  Object.assign(a, {
    combattant: true, rival: camp === 'ennemi', camp, nom: data.nom, guilde: data.guilde, ip: data.ip || st.ip, data,
    armeDef: def, equip, st, def: { nom: data.nom, model: def.model },
    pos: a.root.position, pv: Math.round(st.pvMax * kpv(camp)), pvMax: Math.round(st.pvMax * kpv(camp)), reduction: st.reduction, dmg: st.degats * 1.05 * kdg(camp),
    etat: 'chasse', atkT: 1.2, attaqueT: 1.2, stunT: 0, slowT: 0, dots: [], pack: -9, angle: 0, mort: false, hauteurPlaque: 2.55, rayon: 0.55, hover: 0,
    specT: rnd(3, 5), potions: 2, potionT: 0, esquiveT: 2, dashT: 0, strafe: Math.random() < 0.5 ? 1 : -1, chatT: rnd(10, 18), tc: null,
    argent: Math.round(rnd(0.7, 1.4) * 60 * Math.pow(2.3, arme.tier - 1)),
  });
  // en JcJ (arène, Goulet, invasions, coéquipiers) : force réelle calée sur celle du joueur
  if (!data.sansRecalage) { a.pvMax = Math.round(st.pvMax); a.dmg = st.degats * 1.05; recalerBot(a, camp); }
  a.jouer('Cheer', { boucle: false, fin: () => a.jouer(def.idle) });
  UI.plaque(a, { nom: data.nom, guilde: data.guilde, classe: (camp === 'ennemi' ? 'rival' : 'allie') + ' joueur', ip: a.ip, niv: data.niv, vie: true });
  if (camp === 'ennemi') { a.skill = data.skill ?? rnd(0.35, 0.8); a.specFacteur = 0.7 + a.skill * 0.6; }
  if (camp === 'ennemi') ennemis.push(a); else allies.push(a);
  return a;
}

// ---- camps, cibles et dégâts ----
function coequipiers() { return allies.filter(a => !a.garde && !a.invoc); }
function equipeJoueur() { const l = []; if (!joueur.mort && !(joueur.furtifT > 0)) l.push(joueur); for (const a of allies) if (!a.mort) l.push(a); if (captifV && captifV.libre && !captifV.mort) l.push(captifV); if (!duelV) for (const o of escouade) if (!o.mort && !o.sceneOmbre && o.root.visible) l.push(o); return l; }
function adversaires(e) { return e.camp === 'allie' ? vivants() : equipeJoueur(); }
function cibleIA(e) {
  let liste;
  // les loups provoquent les monstres à moins de 10 m d'eux
  if (e.camp !== 'allie' && !e.combattant && !e.rival && meute.length) { let best = null, bd = Infinity; for (const l of meute) if (l && !l.mort && allies.includes(l)) { const d = dist2D(l.pos, e.pos); if (d < l.taunt && d < bd) { bd = d; best = l; } } if (best) return best; }
  if (goulet && e.bg) { const l = adversairesGoulet(e.bg.camp).filter(x => dist2D(x.pos, e.pos) < 14); const porteur = l.find(x => estPorteur(x)); if (porteur) return porteur; liste = l; }
  else
  if (e.poste && e.camp === 'allie') liste = vivants().filter(x => dist2D(x.pos, e.poste) < 24);
  else if (e.poste) liste = equipeJoueur().filter(x => dist2D(x.pos, e.poste) < 20);
  else if (e.camp === 'allie' && e.membreSylve) liste = vivants().filter(x => x.etat !== 'dormant' && (x.etat === 'chasse' ? dist2D(x.pos, e.pos) < 20 : dist2D(x.pos, e.pos) < 11));
  else if (e.camp === 'allie' && e.invoc === 'pacte') liste = J.ordrePacte === 'garde' ? vivants().filter(x => x.etat !== 'dormant' && dist2D(x.pos, joueur.pos) < 12) : vivants().filter(x => x.etat !== 'dormant' && dist2D(x.pos, e.pos) < 16);
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
    if (opts.stun && joueur.invuln <= 0) { joueur.verrouAtk = false; joueur.verrouT = Math.max(joueur.verrouT, opts.stun); UI.nombre(V(joueur.pos.x, 2.6, joueur.pos.z), 'Étourdi', 'info'); }
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
  if (a === captifV) return blesserCaptif(a, d);
  if (a.escIdx !== undefined) return blesserOmbre(a, d * (1 - (a.reduction || 0)), src);
  d = d * (1 - a.reduction) * rnd(0.92, 1.08) * (a.invoc ? 1 : 1.3);
  a.coupT = 5;
  if (a.bouclierIA > 0) { const b = Math.min(a.bouclierIA, d); a.bouclierIA -= b; d -= b; if (d <= 0) return; }
  if (src && src.combattant && (a.combattant || a.loup)) d = facteurJcJ(src, a, d);
  if (goulet && a.bg) d = modBG(src, a, d);
  a.pv -= d; a.frapper();
  UI.nombre(V(a.pos.x, 2.2, a.pos.z), Math.round(d), 'allie');
  if (opts.slow) a.slowT = Math.max(a.slowT, opts.slow);
  if (opts.stun) a.stunT = Math.max(a.stunT, opts.stun * 0.5);
  if (a.pv > 0) return;
  a.pv = 0; a.mort = true;
  if (a.compagnonV) return mortCompagnon(a);
  if (a.invoc) { mortInvocation(a); return; }
  a.jouer('Death_A', { boucle: false });
  UI.toast(`${a.nom} est tombé`);
  setTimeout(() => UI.chat(a.nom, hasard(['désolé…', 'je suis mort', 'ils frappent fort', 'vas-y finis-les'])), 700);
  if (goulet && a.bg) return mortGoulet(a);
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
  if (goulet && e.bg && iaGoulet(e, dt)) return;
  e.tc = cibleIA(e);
  if (e.camp === 'ennemi' && e.skill > 0.6) { e.focusT = (e.focusT || 0) - dt; if (e.focusT <= 0) { e.focusT = 1.5; const l = adversaires(e).filter(x => dist2D(x.pos, e.pos) < 14); if (l.length > 1) e.focus = l.reduce((a, b) => (a.pv / a.pvMax < b.pv / b.pvMax ? a : b)); else e.focus = null; } if (e.focus && !e.focus.mort) e.tc = e.focus; }
  if (e.camp === 'ennemi' && e.skill !== undefined && e.tc && esquiveExperte(e, dt, melee)) return;
  if (e.potionT > 0) { e.potionT -= dt; if (goulet && e.bg) scoreDe(e).soin += Math.min(e.pvMax * 0.4 * dt, e.pvMax - e.pv); e.pv = Math.min(e.pvMax, e.pv + e.pvMax * 0.4 * dt); if (Math.random() < 0.4) emettre(V(e.pos.x, 0.5, e.pos.z), { n: 1, c1: '#ff8a9a', c2: '#ff2a4a', dir: V(0, 1, 0), vit: 2, rayon: 0.6, vie: 0.6, taille: 0.3 }); }
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
      if (e.invoc === 'pacte' && J.ordrePacte !== 'garde' && autonomieAllie(e, dt, dj)) { /* le sbire part chasser seul */ }
      else if (e.invoc) { // les invocations collent au joueur, même quand il court ou sprinte
        if (dj > 16) { fumeeOmbre(e.pos); e.pos.copy(pointLibrePres(joueur.pos, 1.5, 3)); fumeeOmbre(e.pos); }
        else suivreFormation(e, allies.filter(x => x.invoc && !x.mort).indexOf(e), dt, def.run, def.idle);
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
    if (a.mort || a.tk) { a.maj(dt); continue; }
    a.coupT = (a.coupT || 0) - dt;
    if (!a.invoc && a.coupT <= 0 && a.pv < a.pvMax) a.pv = Math.min(a.pvMax, a.pv + a.pvMax * (a.coupT < -4 ? 0.06 : 0.012) * dt);
    if (a.stunT > 0) { a.stunT -= dt; a.maj(dt * 0.15); continue; }
    if (a.loup) { majLoup(a, dt); a.maj(dt); continue; }
    if (a.refletMob) { majRefletMob(a, dt); a.maj(dt); continue; }
    if (a.slowT > 0) a.slowT -= dt;
    a.atkT -= dt;
    if (sautEnCours(a, dt)) continue;
    majCombattant(a, dt);
    a.maj(dt);
  }
}
function majCadreAutre() {
  if (goulet) return UI.cadreAutre(null);
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
  annonce(nomM, MAITRISES.find(x => x.id === type).cat === 'arme' ? `${nomM} niv. ${m.niv} · +1 point de talent` : `${nomM} niv. ${m.niv}`);
  if (UI.majBoutonTalents) setTimeout(() => UI.majBoutonTalents(), 50);
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
  if (J.hydromel && Date.now() < J.hydromel) base *= 1.2;
  if (!base) return;
  base = Math.round(base * (1 + bonusParch('xp')));
  if (J.escouade) statsEscouade().xp += base;
  for (const t of typesPortes()) noterXP(t, base);
  let monte = false;
  for (const t of typesPortes()) monte = gainXP(t, base) || monte;
  UI.nombre(V(joueur.pos.x, 2.9, joueur.pos.z), `+${fmtN(base)} XP`, 'xp');
  if (monte) exploitNiveau();
  if (monte) { recalculer(); $('#ipHud').textContent = `Niv. ${niveauHeros(J.equip)} · ⚔ ${joueur.st.ip}`; }
  sauver();
}
function gagnerXPRelatif(frac) {
  frac *= 0.1 * (1 + bonusParch('xp')); // les bonus de fin (boss, arène…) restent un petit plus : la progression vient surtout du combat
  let total = 0;
  for (const t of typesPortes()) { const m = J.maitrise[t]; const x = Math.round(xpPour(m.niv) * frac); total += x; gainXP(t, x); noterXP(t, x); }
  recalculer(); sauver();
  return total;
}

