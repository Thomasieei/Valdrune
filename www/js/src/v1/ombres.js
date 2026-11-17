// ---- ÉTAPE 2 : ombres vulnérables, vrais combats, patrouille, chasse, réinvocation qui coûte la mana ----
let cibleChasseO = null; const reinvocO = {};
const RAILLERIES = ['C’est ça, tes ombres ?', 'Une de moins. Envoie la suivante.', 'Tes ombres sont aussi faibles que toi.', 'Hahaha ! Elles se dissolvent comme de la fumée !', 'Viens toi-même, lâche !'];
function pvOmbreMax() { return Math.round(joueur.st.pvMax * 0.5); }
function blesserOmbre(o, d, src) {
  if (o.mort) return;
  o.pvO = (o.pvO ?? pvOmbreMax()) - d; o.frapper && o.frapper();
  UI.nombre(V(o.pos.x, 2.2, o.pos.z), Math.round(d), 'allie');
  if (o.pvO > 0) { if (!o.crieT || G.t > o.crieT) { o.crieT = G.t + 8; if (o.pvO < pvOmbreMax() * 0.35) direOmbre(ombresC()[o.escIdx], 'Maître… je faiblis.'); } return; }
  detruireOmbre(o, src);
}
function detruireOmbre(o, src) {
  o.mort = true; const r = ombresC()[o.escIdx];
  fumeeOmbre(o.pos); emettre(V(o.pos.x, 1.2, o.pos.z), { n: 60, c1: '#d8b8ff', c2: '#1a0830', vit: 7, vie: 1, taille: 0.5 }); son('forceField_000', 0.6, 0.5);
  G.scene.remove(o.root); UI.retirerPlaque(o); const k = escouade.indexOf(o); if (k >= 0) escouade.splice(k, 1);
  const tueur = src ? (src.champion ? src.nomChampion : (src.def && src.def.nom) || src.nom || 'un ennemi') : 'un ennemi';
  UI.toast(`${r ? r.nom : 'Une ombre'} a été détruite par ${tueur}`, true);
  if (r) { r.defaites = (r.defaites || 0) + 1; r.bourreau = tueur; souvenir(r, 'detruite'); r.loyaute = Math.max(0, r.loyaute - 2); reinvocO[r.i] = { t: G.t + 5, dit: false }; }
  if (src && src.champion && !src.mort) UI.parole(src, hasard(RAILLERIES), 'menace');
  sauver();
}
// renvoie false si l'ombre doit encore attendre (délai ou mana)
function reinvoquerOmbre(i) {
  const R = reinvocO[i]; if (!R) return true;
  if (G.t < R.t) return false;
  const cout = Math.round(joueur.st.energieMax * 0.2);
  if (joueur.energie < cout) { if (!R.dit) { R.dit = true; UI.toast(`Pas assez de mana pour relever ${ombresC()[i].nom} (${cout})`); } return false; }
  joueur.energie -= cout; delete reinvocO[i];
  UI.nombre(V(joueur.pos.x, 2.8, joueur.pos.z), `-${cout} mana`, 'info');
  return true;
}
function engagerOmbre(o, c, dt, tp) {
  const d = dist2D(o.pos, c.pos);
  if (d > 8 && tp) { teleporterOmbre(o, c.pos); return; }
  if (d > (c.rayon || 0.6) + 1.3) { allerVers(o, c.pos, dt, joueur.st.vitesse * 1.25); o.jouer(o.armeDef.run); return; }
  o.angle = tourner(o.angle, Math.atan2(c.pos.x - o.pos.x, c.pos.z - o.pos.z), dt * 12); o.root.rotation.y = o.angle;
  o.coupT = (o.coupT || 0) - dt; if (o.coupT > 0) return;
  o.coupT = 0.8 + Math.random() * 0.35;
  o.jouer(hasard(['1H_Melee_Attack_Chop', '1H_Melee_Attack_Slice_Diagonal', '1H_Melee_Attack_Stab']), { boucle: false, forcer: true, vitesse: 1.4, fin: () => o.jouer(o.armeDef.idle) });
  programmer(0.22, () => { if (c.mort || o.mort) return; arcTaille(c.pos, o.angle - Math.PI / 2, 2.2, '#b07aff', Math.PI * 0.7, 0.2);
    const dmg = Math.max(1, joueur.st.degats * 0.9 * (c.boss || c.champion ? 0.6 : 1));
    sansChoc(() => { if (c.pv - dmg <= 0) { c.pv = 0; tuer(c); statsEscouade().kills++; } else { c.pv -= dmg; c.flash = 0.12; UI.nombre(V(c.pos.x, 2.3, c.pos.z), fmtN(Math.round(dmg)), ''); if (c.etat === 'idle' || c.etat === 'dormant') reveiller(c); } });
    son('knifeSlice', 0.25, 1.1 + Math.random() * 0.3); });
}
function majOmbreCombat(o, dt, ord) {
  let c = o.combatCible;
  const patr = ord === 'patrouille' && monde.patrouille, centre = patr ? o.pos : joueur.pos, R = patr ? 11 : 16;
  if (ord === 'chasse') {
    c = cibleChasseO && !cibleChasseO.mort && !cibleChasseO.parti ? cibleChasseO : null;
    if (!c) { const r = ombresC()[o.escIdx]; if (r && r.ordre === 'chasse') { r.ordre = 'combat'; direOmbre(r, 'Cible abattue. Je reviens à tes côtés.'); } }
  } else if (!c || c.mort || c.descendre || c.parti || dist2D(c.pos, centre) > R + 4) {
    c = null; let bd = R;
    for (const e of ennemis) { if (e.mort || e.descendre || e.parti || e.etat === 'dormant' || (e.etat === 'idle' && dist2D(e.pos, joueur.pos) > 11)) continue; const dd = dist2D(e.pos, centre); if (dd < bd) { bd = dd; c = e; } }
  }
  o.combatCible = c;
  if (c) { engagerOmbre(o, c, dt, !patr); return true; }
  if (patr) { const P = monde.patrouille; if (o.patI === undefined) o.patI = o.escIdx * 2; let p = P[o.patI % P.length]; if (dist2D(o.pos, p) < 1.6) { o.patI++; p = P[o.patI % P.length]; } allerVers(o, p, dt, 2.4); o.jouer('Walking_A'); return true; }
  return false;
}
function majEscouade(dt) {
  { const b = $('#btnOmbres'); if (b && b.hidden === !!J.escouade) b.hidden = !J.escouade; }
  if (!J.escouade || !joueur || joueur.mort && !arene) { if (escouade.length && !J.escouade) viderEscouade(); return; }
  if (transition) return;
  const enAttente = arene && arene.t > 0;
  // seules les ombres présentes (ni en mission, ni blessées, ni renvoyées) marchent avec toi
  const R = ombresC();
  for (let k = escouade.length - 1; k >= 0; k--) { const o = escouade[k]; if (o.sceneOmbre) continue; if (!presenteOmbre(R[o.escIdx])) { fumeeOmbre(o.pos); G.scene.remove(o.root); UI.retirerPlaque(o); escouade.splice(k, 1); } }
  for (const r of R) if (presenteOmbre(r) && !escouade.some(o => o.escIdx === r.i) && reinvoquerOmbre(r.i)) { const o = creerOmbreEscouade(r.i); o.pvO = pvOmbreMax(); escouade.push(o); }
  const prises = new Set(escouade.map(o => o.escCible).filter(c => c && !c.mort));
  const coffresPris = new Set(escouade.map(o => o.escCoffre).filter(Boolean));
  for (const o of escouade) {
    o.maj(dt);
    if (o.sceneOmbre) continue;
    const rec = R[o.escIdx], passive = rec && rec.ordre === 'escorte', garde = rec && rec.ordre === 'garde';
    if (passive) { o.escCible = null; o.escCoffre = null; }
    if (garde) { if (majOmbreGarde(o, dt)) continue; o.escCible = null; o.escCoffre = null; }
    else if (!passive && !o.escCoffre && majOmbreCombat(o, dt, rec ? rec.ordre : 'combat')) continue;
    o.escT -= dt;
    if (o.escCible && o.escCible.mort) o.escCible = null;
    if (o.escT > 0) continue;
    if (enAttente) { o.escT = 0.2; continue; }
    // 1) une cible différente pour chaque ombre
    if (!o.escCible && !o.escCoffre && !passive) {
      // les coffres dont le gardien est tombé passent avant les petits monstres
      const pret = coffres.find(x => !x.ouvert && !x.final && !coffresPris.has(x) && (!x.boss || x.boss.mort || !x.boss.pv || x.boss.etat === 'possede'));
      const resteBoss = ennemis.some(e => e.boss && !e.mort && !prises.has(e));
      if (pret && !resteBoss) { o.escCoffre = pret; coffresPris.add(pret); teleporterOmbre(o, pret.pos); o.escT = 0.2; continue; }
      const c = null; // plus d'exécutions instantanées : les ombres se battent vraiment (majOmbreCombat)
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
        sansChoc(() => { c.pv = 0; tuer(c); }); const s = statsEscouade(); s.kills++;
      }
      o.escT = 0.35 + Math.random() * 0.25; continue; // un rythme qui reste spectaculaire sans écraser le téléphone
    }
    if (o.escCoffre) { // ouvre le coffre et ramasse tout pour le joueur
      const cf = o.escCoffre; o.escCoffre = null;
      if (!cf.ouvert) { o.jouer('Interact', { boucle: false, forcer: true, fin: () => o.jouer(o.armeDef.idle) }); if (cf.depouille) ouvrirDepouille(cf, true); else ouvrirCoffre(cf, true); statsEscouade().coffres++; }
      o.escT = 0.25; continue;
    }
    // 3) rien à faire : elles marchent derrière toi, en formation (aucune ronde autour de toi)
    const rang = allies.filter(x => x.invoc && !x.mort).length + escouade.filter(x => !x.sceneOmbre).indexOf(o);
    suivreFormation(o, rang, dt, o.armeDef.run, o.armeDef.idle, (c) => teleporterOmbre(o, c));
    o.escT = 0;
  }
  // compteur à l'écran
  escHudT = (escHudT || 0) - dt;
  if (escHudT <= 0) { escHudT = 0.5; const s = statsEscouade(); const h = Math.max(1 / 60, (Date.now() - s.debut) / 3.6e6);
    UI.escouadeHud({ duree: Date.now() - s.debut, argent: J.argent - s.argent0, parHeure: Math.round((J.argent - s.argent0) / h), xp: s.xp, xpH: Math.round(s.xp / h), kills: s.kills, coffres: s.coffres }); }
}
let escHudT = 0;

