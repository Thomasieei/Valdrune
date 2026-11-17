// ======================= ÉTAPE 3 : MONSTRES À PERSONNALITÉ — parlementer, provoquer, se retirer =======================
let duelV = null;
const OUVERTURES = {
  arrogant: ['Tiens, le gardien en personne. Tu viens supplier ?', 'Alors c’est toi, le « protecteur » ? Je m’attendais à mieux.', 'Approche. Que je voie de près celui que je vais briser.'],
  prudent: ['Reste où tu es. Je ne suis pas venu pour toi.', 'Doucement… Parlons avant que l’un de nous ne le regrette.', 'Tu as l’air plus dangereux qu’on ne me l’a dit.'],
  fanatique: ['La Brèche a faim. Ta ville la nourrira.', 'Le Seigneur Écarlate voit à travers mes yeux, gardien.', 'Je n’ai pas peur de mourir. Toi, si.']
};
function rapportForce(e) {
  const nO = escouade.filter(o => !o.mort).length, dps = joueur.st.degats * 1.2 + nO * joueur.st.degats * 0.95;
  const ttkC = e.pv / Math.max(1, dps), ttkJ = joueur.pv / Math.max(1, (e.dmg || 20) / 1.6);
  return ttkJ / Math.max(0.1, ttkC); // > 1 : tu le tues avant qu'il ne te tue
}
function rivaux() { const v = etatVille(); if (!v.rivaux) v.rivaux = []; return v.rivaux; }
function noterRival(e, issue) { const R = rivaux(); let r = R.find(x => x.nom === e.nomChampion); if (!r) { r = { nom: e.nomChampion, perso: e.persoC, rencontres: 0 }; R.push(r); } r.issue = issue; r.rencontres++; e.issueNotee = true; journalVille(`${e.nomChampion} : ${{ retraite: 's’est retiré face à toi', tue: 'a été abattu', epargne: 'a été épargné' }[issue]}.`); sauver(); }
function retraiteChampion(e, ligne, entraine) {
  e.parle = false; e.retraite = true; finDuel();
  UI.parole(e, ligne, 'menace'); UI.dialogueTaverne(null); UI.toast(`${e.nomChampion} bat en retraite !`, true);
  noterRival(e, 'retraite'); moralVille(5);
  if (entraine) for (const x of pillards()) if (!x.champion) { x.retraite = true; if (x.porte) finPillard(x); }
}
function finDuel() { if (!duelV) return; for (const r of ombresC()) if (r.ordreAvantDuel) { r.ordre = r.ordreAvantDuel; delete r.ordreAvantDuel; } duelV = null; }
function parlerChampion(e) {
  e.parle = true; e.tc = null;
  const v = etatVille(), O = ombresC(), victime = O.find(r => r.bourreau === e.nomChampion), enleve = v.gens.find(g => g.statut === 'enleve');
  const pvP = e.pv / e.pvMax, F = rapportForce(e), P = e.persoC;
  const scene = (texte, options) => UI.dialogueTaverne({ nom: e.nomChampion, titre: `Champion de la Brèche · ${{ arrogant: 'Arrogant', prudent: 'Prudent', fanatique: 'Fanatique' }[P]}${e.revenu ? ' · revenu se venger' : ''}`, modele: 'Barbarian', texte, options });
  const combat = (l) => { e.parle = false; UI.dialogueTaverne(null); if (l) UI.parole(e, l, 'menace'); };
  const opts = [];
  opts.push({ label: 'Pars maintenant, et personne d’autre ne mourra.', sous: 'Le raisonner', action: () => {
    if (P === 'fanatique') return scene('Partir ? La Brèche ne recule pas. Elle avale.', [{ label: 'Alors elle s’étouffera avec toi.', action: () => combat('VIENS !') }]);
    if (P === 'prudent' && F > 0.9) return retraiteChampion(e, 'Soit. Mais la Brèche se souviendra de ton visage.', true);
    if (P === 'prudent') return scene('Partir ? Tes ombres tombent comme des feuilles mortes. Donne-moi une vraie raison.', [
      { label: 'Regarde-moi bien. La prochaine raison, ce sera ma lame.', sous: 'Menacer', action: () => menacer(0.15) },
      { label: 'Assez parlé.', action: () => combat('Comme tu voudras.') }]);
    scene('Hahaha ! Tu me SUPPLIES de partir ? Voilà ce qu’on dira de toi dans la Brèche.', [
      { label: 'Alors bats-toi contre moi. Seul. Sans mes ombres.', sous: 'Duel d’honneur', action: () => {
        duelV = e; for (const r of ombresC()) if (!r.mission) { r.ordreAvantDuel = r.ordre; r.ordre = 'escorte'; }
        combat('Enfin un peu de courage ! Personne n’intervient !'); UI.toast('DUEL — tes ombres reculent', true); } },
      { label: 'Comme tu voudras.', action: () => combat('Je vais te briser devant ton peuple.') }]);
  } });
  if (victime) opts.push({ label: `Tu as détruit ${victime.nom}. Tu vas le payer.`, sous: 'Vengeance', action: () => scene(P === 'arrogant' ? `${victime.nom} ? Elle s’est dissoute en hurlant. Je n’ai jamais rien entendu d’aussi drôle.` : P === 'prudent' ? `C’était elle ou moi. Tu aurais fait pareil.` : `Ton ombre a nourri la Brèche. Toi aussi, bientôt.`, [{ label: 'Assez parlé.', action: () => { e.dmg *= 1.0; joueur.st.degats *= 1; combat('Viens venger ta poupée !'); } }, { label: 'Pars, et je t’oublierai.', sous: 'Le raisonner', action: () => opts[0].action() }]) });
  if (enleve) opts.push({ label: `Où avez-vous emmené ${enleve.nom} ?`, sous: 'Interroger', action: () => scene(P === 'fanatique' ? `${enleve.nom} attend dans ${LIEUX[enleve.lieu ?? 0]}. Le Seigneur Écarlate a besoin de chair vivante.` : P === 'prudent' ? `Dans la Brèche. ${LIEUX[enleve.lieu ?? 0]}, je crois. Encore en vie… pour l’instant.` : `${enleve.nom} ? Ça pleurait encore quand on l’a jeté dans ${LIEUX[enleve.lieu ?? 0]}. Va le chercher, si tu l’oses.`, [{ label: 'Merci pour l’information. Maintenant, meurs.', action: () => combat('Ha !') }, { label: 'Rentre chez toi.', sous: 'Le raisonner', action: () => opts[0].action() }]) });
  opts.push({ label: 'Regarde mes ombres. Regarde-moi. Tu veux vraiment mourir ici ?', sous: 'Intimider', action: () => menacer(0) });
  opts.push({ label: '💬 Lui parler librement', sous: 'Écris ce que tu veux', action: () => { UI.dialogueTaverne(null); parlerLibreChampion(e); } });
  opts.push({ label: 'Assez parlé.', sous: 'Combattre', action: () => combat(P === 'arrogant' ? 'ENFIN !' : P === 'prudent' ? 'Tu l’auras voulu.' : 'Pour la Brèche !') });
  function menacer(bonus) {
    const chance = Math.max(0, Math.min(0.95, (F - 0.7) * 0.8 + (1 - pvP) * 0.7 + bonus + { prudent: 0.3, arrogant: -0.25, fanatique: -2 }[P]));
    if (Math.random() < chance) return retraiteChampion(e, P === 'arrogant' ? '…Tch. Ce n’est que partie remise, gardien.' : 'D’accord… d’accord. Je pars.', F > 1.8);
    if (P === 'fanatique') return scene('Me menacer ? Je MEURS pour la Brèche avec joie.', [{ label: 'Alors meurs.', action: () => combat('POUR LE SEIGNEUR ÉCARLATE !') }]);
    e.dmg *= 1.25; e.enrage = true;
    scene(P === 'arrogant' ? 'Tu me menaces ? MOI ? Tout ton peuple va entendre tes cris.' : 'Tu crois me faire peur ? Je t’ai observé, gardien. Tu n’es pas si fort.', [{ label: 'On verra.', action: () => combat('Tu vas le regretter !') }]);
  }
  scene((e.revenu ? `Tu te souviens de moi ? ${e.revenu === 'retraite' ? 'La dernière fois, j’ai reculé. Pas cette fois.' : 'Tu m’as laissé la vie. Grave erreur.'} ` : '') + hasard(OUVERTURES[P]), opts);
}
// pendant le combat : un champion vaincu par plus fort que lui peut se rendre (rare)
function majChampion(e) {
  if (e.renduOffert || e.persoC === 'fanatique' || e.parle || e.retraite) return;
  if (e.pv / e.pvMax > 0.3) return;
  e.renduOffert = true;
  if (rapportForce(e) < 1.3 && Math.random() < 0.7) return;
  e.parle = true;
  UI.dialogueTaverne({ nom: e.nomChampion, titre: 'Champion de la Brèche · à genoux', modele: 'Barbarian', texte: e.persoC === 'arrogant' ? 'Assez… ASSEZ ! …Tu es plus fort que je ne le pensais. Laisse-moi partir, et je ne reviendrai plus.' : 'Je me rends ! Je me rends… Je n’aurais jamais dû venir ici.', options: [
    { label: 'Pars. Et dis à la Brèche ce que tu as vu ici.', sous: 'L’épargner', action: () => { e.parle = false; e.retraite = true; finDuel(); UI.dialogueTaverne(null); UI.parole(e, 'Je… je le dirai.'); noterRival(e, 'epargne'); moralVille(3); for (const x of pillards()) if (!x.champion) { x.retraite = true; if (x.porte) finPillard(x); } UI.toast('Les assaillants fuient la Place !', true); } },
    { label: 'Non. Tu as attaqué mon peuple.', sous: 'L’achever', action: () => { e.parle = false; UI.dialogueTaverne(null); UI.parole(e, 'Non… attends—', 'menace'); sansChoc(() => { e.pv = 0; tuer(e); }); } }] });
}

