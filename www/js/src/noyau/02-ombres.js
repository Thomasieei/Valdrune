// ---------------- Escouade d'ombres (code THOMAS83, outil de test de l'économie) ----------------
// 6 ombres qui se déploient : chacune se téléporte sur une cible DIFFÉRENTE (boss d'abord), la détruit d'un coup,
// puis elles ouvrent les coffres et ramassent tout le butin. Un compteur mesure l'argent et l'XP gagnés par heure.
let escouade = [];
const ESC = { kills: 0, coffres: 0, xp: 0 };
function statsEscouade() {
  if (!J.escStats) J.escStats = { debut: Date.now(), argent0: J.argent, xp: 0, kills: 0, coffres: 0 };
  return J.escStats;
}
function viderEscouade() { if (G.vueOmbre) vueOmbre(null); for (const o of escouade) { G.scene.remove(o.root); UI.retirerPlaque(o); } escouade = []; }
function creerOmbreEscouade(i) {
  const ang = i / 6 * Math.PI * 2;
  const pos = pointLibrePres(V(joueur.pos.x + Math.sin(ang) * 2.6, 0, joueur.pos.z + Math.cos(ang) * 2.6), 0, 1.2);
  const a = creerCombattant(pos, { nom: 'Ombre', guilde: J.nom.toUpperCase(), equip: J.equip, modele: 'Rogue_Hooded' }, 'allie');
  allies.splice(allies.indexOf(a), 1); // hors des alliés : personne ne la cible, elle ne compte pas dans le groupe
  UI.retirerPlaque(a);
  a.root.scale.setScalar(0.95); teinteSpectrale(a, '#140c20', 0.8);
  const rec = ombresC()[i]; if (rec) a.nom = rec.nom; if (!V1) UI.plaque(a, { nom: rec ? rec.nom : 'Ombre ' + 'ⅠⅡⅢⅣⅤⅥ'[i], guilde: 'OMBRE DE ' + J.nom.toUpperCase(), classe: 'allie', vie: false, lettre: false });
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
// formation derrière le joueur : chacun a sa place (3 de front, rangs de 1,9 m), on ne rejoint sa place que si on s'en écarte vraiment
// (hystérésis), la vitesse suit la distance (pas d'arrêts nets), et au repos on regarde dans la même direction que le joueur
function slotFormation(rang) {
  const col = [0, -1, 1][rang % 3], ligne = Math.floor(rang / 3), ec = 1.9, rec = 2.4 + ligne * 1.9;
  const fx = Math.sin(joueur.angle), fz = Math.cos(joueur.angle), rx = Math.cos(joueur.angle), rz = -Math.sin(joueur.angle);
  return V(joueur.pos.x + rx * col * ec - fx * rec, 0, joueur.pos.z + rz * col * ec - fz * rec);
}
function suivreFormation(e, rang, dt, animCourse, animRepos, teleporter) {
  let cible = slotFormation(rang);
  if (!libre(cible.x, cible.z, 0.5)) cible = pointLibreProche(cible, 0.5) || joueur.pos.clone();
  const d = dist2D(e.pos, cible);
  if (d > 24) { if (teleporter) teleporter(cible); else e.pos.copy(cible); e._suit = false; return; }
  if (!e._suit && d > 2.2) e._suit = true; else if (e._suit && d < 0.45) e._suit = false;
  if (e._suit) {
    const vv = Math.min(Math.max(joueur.st.vitesse, vitesseJoueur()) * 1.35, Math.max(1.6, d * 2.4));
    e._vv = (e._vv || 0) + (vv - (e._vv || 0)) * Math.min(1, dt * 6);
    avancerVers(e, cible, dt, e._vv); e.jouer(e._vv < 2.4 ? 'Walking_A' : animCourse); // ligne droite : pas de recalcul de chemin à chaque image (c'était la cause des gels)
  } else { e._vv = 0; e.jouer(animRepos); e.angle = tourner(e.angle, joueur.angle, dt * 3); e.root.rotation.y = e.angle; }
}
// ---- voir par les yeux d'une ombre (petite fenêtre, brouillard sombre sur les bords) ----
function vueOmbre(o) {
  if (!o) { G.vueOmbre = null; UI.vueOmbre(null); return; }
  G.vueOmbre = { acteur: o, rect: null };
  UI.vueOmbre({ nom: o.nom, fermer: () => vueOmbre(null), suivante: () => { vueOmbre(null); voirOmbre(((o.escIdx || 0) + 1) % ombresC().length); } });
  son('forceField_000', 0.25, 1.6);
}
// voir par les yeux d'une ombre : à tes côtés → vraie caméra 3D ; en mission (arène, donjon, île…) → sa vision lointaine en direct
function voirOmbre(i) {
  const R = ombresC(), r = R[i]; if (!r) return;
  const o = ombreActeur(i);
  const suivante = () => voirOmbre((i + 1) % R.length);
  if (o && !r.mission) { vueOmbre(o); return; }
  if (!r.mission) { UI.toast(`${r.nom} se repose dans l’ombre : rien à voir`); return; }
  G.vueOmbre = null; son('forceField_000', 0.25, 1.6);
  const M = r.mission, lieu = M.type === 'ile' ? (M.ile === -1 ? 'ton domaine' : (iles()[M.ile] || {}).nom || 'ton île') : M.type === 'arene' ? 'l’arène' : LIEUX[M.mode || 0];
  UI.vueMission({ nom: r.nom, type: M.type, lieu, debut: M.debut, fin: M.fin, graine: (M.debut % 100000) + i * 7, etat: () => r.rapport ? 'Mission finie : elle revient faire son rapport' : !r.mission ? 'De retour auprès de toi' : null, fermer: () => UI.vueOmbre(null), suivante });
}
function majVueOmbre() {
  const V0 = G.vueOmbre; if (!V0) return;
  if (V0.cam) { if (!arene || !G.ecrans) return vueOmbre(null); const el = document.getElementById('vueOmbre'); if (el) { const r = el.querySelector('.ecranO').getBoundingClientRect(); V0.rect = { x: r.left, y: r.top, w: r.width, h: r.height }; } return; }
  if (!V0.acteur.root.parent || !escouade.includes(V0.acteur)) { const l = escouade.filter(x => !x.sceneOmbre); return vueOmbre(l[0] || null); }
  const el = document.getElementById('vueOmbre'); if (!el) return;
  const r = el.querySelector('.ecranO').getBoundingClientRect(); V0.rect = { x: r.left, y: r.top, w: r.width, h: r.height };
  const etat = V0.acteur.escCible ? 'exécute une cible' : V0.acteur.gardeCible ? 'te protège' : V0.acteur.escCoffre ? 'ouvre un coffre' : 'marche derrière toi';
  UI.vueOmbre({ maj: etat });
}
// ce que font les ombres ne doit jamais secouer ta caméra ni figer ton personnage (ralentis, tremblements)
function sansChoc(f) { const s0 = G.shake || 0, d0 = G.camDist; G._parOmbre = true; try { f(); } finally { G._parOmbre = false; G.shake = s0; G.camDist = d0; } }
// ordre « Protéger » : elle reste près de toi et frappe ce qui s'approche à moins de 9 m (sans nettoyer tout le donjon)
function majOmbreGarde(o, dt) {
  let c = o.gardeCible;
  if (!c || c.mort || dist2D(c.pos, joueur.pos) > 13) {
    c = null; let bd = 9;
    for (const e of ennemis) { if (e.mort || e.descendre || e.etat === 'idle' && !e.tc) continue; const d = dist2D(e.pos, joueur.pos); if (d < bd) { bd = d; c = e; } }
    o.gardeCible = c;
  }
  if (!c) return false;
  engagerOmbre(o, c, dt, true); // même moteur de combat que les autres ordres (v1/ombres.js)
  return true;
}
// ======================= COMMANDEMENT DES OMBRES (code THOMAS83) =======================
// Six ombres avec un caractère, une loyauté et une mémoire. Tu leur donnes des ordres (toutes ou une seule) ;
// elles partent en mission hors de l'écran et reviennent faire leur rapport à genoux. Elles ne te sollicitent
// que sur de vrais événements du jeu (relique puissante, coffre légendaire, rumeur…), jamais en boucle.
const OMBRES_DEF = [
  { nom: 'Kael', ep: 'le Silencieux', perso: 'silencieux' }, { nom: 'Vesna', ep: 'la Fière', perso: 'fier' },
  { nom: 'Morrow', ep: 'l’Avide', perso: 'avide' }, { nom: 'Ilyr', ep: 'la Rieuse', perso: 'joueuse' },
  { nom: 'Dusk', ep: 'le Prudent', perso: 'prudent' }, { nom: 'Sabre', ep: 'l’Ambitieux', perso: 'ambitieux' },
];
// affinités : quelles envies chaque caractère a le plus souvent
const AFF_OMBRE = {
  silencieux: { relique: 1.4, coffre: 1.1, secours: 1.2, vol: 0.6, arene: 0.6, parole: 0.35 },
  fier: { relique: 0.9, coffre: 0.8, secours: 0.7, vol: 0.6, arene: 1.9, parole: 0.9 },
  avide: { relique: 1.1, coffre: 1.8, secours: 0.5, vol: 1.9, arene: 0.7, parole: 0.8 },
  joueuse: { relique: 0.9, coffre: 1, secours: 1, vol: 1.2, arene: 1.1, parole: 1.6 },
  prudent: { relique: 1.2, coffre: 1.1, secours: 1.5, vol: 0.5, arene: 0.6, parole: 0.8 },
  ambitieux: { relique: 1.1, coffre: 1, secours: 0.7, vol: 1, arene: 1.7, parole: 0.9 },
};
const PAROLES_OMBRE = {
  req_relique: ['Maître… je sens une relique {rar} derrière un mur de ce donjon. Me laisses-tu te guider jusqu’à elle ?', 'Une relique {rar} respire quelque part dans ces pierres, maître. Je connais le passage.', 'Il y a un mur qui ment, ici. Derrière, une relique {rar}. Tu veux que je te montre ?'],
  req_coffre: ['Maître, un coffre légendaire attend dans la salle d’un gardien. Je peux t’y mener et le surveiller.', 'Je sens de l’or ancien près d’un gardien, maître. Un coffre légendaire. Je t’y conduis ?', 'Un coffre comme on en voit une fois par lune dort dans ce donjon. Tu veux le voir ?'],
  req_secours: ['Maître, j’ai entendu parler d’un blessé dans {lieu}. Un aventurier, seul. M’envoies-tu le chercher ?', 'Quelqu’un appelle à l’aide dans {lieu}, maître. Je l’entends d’ici. Puis-je y aller ?', 'Un marchand a été attaqué près de {lieu}. Il vit encore… pour l’instant. J’y vais ?', 'Un enfant de la Place s’est perdu dans {lieu}, maître. Laisse-moi le ramener.'],
  req_vol: ['Maître, l’île de {cible} cache un coffre {rar}. Ses gardes dorment mal. Je peux le dérober cette nuit.', '{cible} a laissé son coffre sans surveillance. Un mot de toi et il est à nous.', 'J’ai repéré un trésor sur l’île de {cible}. Risqué… mais tentant. Tu me laisses faire ?'],
  req_arene: ['Maître, laisse-moi combattre dans l’arène. Je veux qu’on respecte ton nom.', 'Les autres ombres disent que je suis la plus faible. Envoie-moi à l’arène, je leur prouverai le contraire.', 'L’arène m’appelle, maître. Quelques victoires, et ton rang montera.', 'On rit de ton blason à l’arène, maître. Laisse-moi les faire taire.'],
  parole: ['Maître… parfois je me souviens d’avant. Puis ça passe.', 'Les autres ombres te craignent. Moi, je t’observe. Tu deviens fort.', 'Tu crois que les ombres rêvent ? Moi oui. De lumière.', 'Kael ne parle jamais. Mais il t’écoute toujours.', 'Je déteste les squelettes. Ils sentent la poussière.', 'Si un jour tu tombes, maître, je tomberai avec toi.', 'Vesna dit qu’elle est la meilleure. Elle a tort.', 'J’ai vu une étoile filante dans le Gouffre. Je l’ai gardée pour toi.', 'Un jour, je voudrais voir la mer des Îles. Juste la voir.', 'Les gens de la Place murmurent ton nom. J’aime ça.', 'Pourquoi m’as-tu choisie, maître ? Ne réponds pas. Je préfère deviner.', 'Je compte tes victoires. Il m’en manque des doigts.'],
  oui: ['Merci, maître.', 'Ce sera fait.', 'Je ne te décevrai pas.', 'Ton ombre obéit.', 'Considère que c’est fait.'],
  non_silencieux: ['…', 'Bien, maître.'], non_fier: ['Tu me retiens encore… Comme tu voudras.', 'Hm. Une autre fois, alors.'], non_avide: ['Dommage… c’était de l’or facile.', 'Tu laisses filer une fortune, maître.'],
  non_joueuse: ['Oh, rabat-joie ! Bon… d’accord.', 'Tu ne t’amuses jamais, maître !'], non_prudent: ['Sage décision, peut-être.', 'Tu as sans doute raison.'], non_ambitieux: ['Tu brides mon ambition, maître. Je m’en souviendrai.', 'Comme tu voudras. Pour l’instant.'],
  o_combat: ['À tes côtés.', 'Je chasse pour toi.', 'Montre-moi qui frapper.'], o_garde: ['Personne ne t’approchera, maître.', 'Je reste à portée de lame.', 'Qu’ils viennent. Ils tomberont à tes pieds.'], o_escorte: ['Je reste près de toi, lame rangée.', 'Je ne frapperai pas sans ton ordre.', 'Je marche dans ton ombre.'],
  o_repos: ['Je retourne dans l’ombre.', 'Appelle-moi quand tu veux.', 'Je me retire, maître.'], o_arene: ['L’arène… enfin.', 'Je reviens victorieuse. Ou pas du tout.', 'Ils vont apprendre ton nom.'],
  o_donjon: ['Je descends dans {lieu}.', 'Les gardiens de {lieu} vont me connaître.', 'Je te rapporterai leurs trésors.'], o_ile: ['Personne ne touchera à ton île.', 'Je veille sur tes ouvriers, maître.', 'Les pillards n’ont qu’à bien se tenir.'],
  souvenir_non: ['Tu as refusé la dernière fois… mais cette fois, c’est différent.', 'Je te le redemande, maître. Je sais que tu as dit non avant.'],
};
const _dkO = {};
function ligneOmbre(cat, rep = {}) { const src = PAROLES_OMBRE[cat] || PAROLES_OMBRE.oui; let d = _dkO[cat]; if (!d || !d.length) d = _dkO[cat] = [...src].sort(() => Math.random() - 0.5); let l = d.pop(); for (const k in rep) l = l.split('{' + k + '}').join(rep[k]); return l; }
function ombresC() {
  if (!J.ombresC) J.ombresC = OMBRES_DEF.map((d, i) => ({ i, nom: d.nom, ep: d.ep, perso: d.perso, loyaute: 65 + Math.round(rnd(0, 15)), ordre: 'combat', mission: null, blesseeJusqua: 0, rapport: null, souvenirs: [], respect: 0, victoires: 0 }));
  return J.ombresC;
}
const NOM_O = (r) => `${r.nom} ${r.ep}`;
function presenteOmbre(r) { return !r.mission && ['combat', 'escorte', 'garde', 'patrouille', 'chasse'].includes(r.ordre) && Date.now() > (r.blesseeJusqua || 0) && !r.rapport; }
const LIEUX = ['les Cryptes Oubliées', 'la Forteresse des Ossements', 'le Gouffre Écarlate', 'l’Abîme Écarlate'];
function ombreActeur(i) { return escouade.find(o => o.escIdx === i && !o.sceneOmbre) || null; }
function direOmbre(r, texte) { const o = ombreActeur(r.i); if (o) UI.parole(o, texte); else UI.chat(NOM_O(r), texte); }
function souvenir(r, s) { r.souvenirs.push({ s, t: Date.now() }); if (r.souvenirs.length > 8) r.souvenirs.shift(); }
// ---- ordres ----
function ordonner(cibles, ordre, extra = {}) {
  if (ordre === 'vue') { voirOmbre(cibles[0] ?? 0); UI.commandeOmbres(null); return; }
  const R = ombresC(); const now = Date.now();
  for (const i of cibles) {
    const r = R[i]; if (!r) continue;
    if (r.mission && ordre !== 'rappel') continue; // déjà partie : on attend son retour
    if (now < (r.blesseeJusqua || 0) && ordre !== 'repos') { UI.toast(`${r.nom} est blessée encore ${Math.ceil((r.blesseeJusqua - now) / 60000)} min`); continue; }
    if (ordre === 'rappel') continue;
    if (['arene', 'donjon', 'secours', 'vol'].includes(ordre)) {
      const m = extra.mode ?? 0;
      const duree = { arene: 3, donjon: 4 + m * 2, secours: 4, vol: 5 }[ordre] * 60000;
      r.mission = { type: ordre, mode: m, cible: extra.cible || null, debut: now, fin: now + duree };
      direOmbre(r, ligneOmbre('o_' + (ordre === 'secours' || ordre === 'vol' ? 'donjon' : ordre), { lieu: LIEUX[m] }));
      const o = ombreActeur(i); if (o) { o.jouer('Cheer', { boucle: false, forcer: true }); programmer(1.2, () => { fumeeOmbre(o.pos); }); }
      souvenir(r, ordre);
    } else if (ordre === 'ile') {
      const kI = extra.ile ?? 0; r.mission = { type: 'ile', ile: kI >= iles().length ? -1 : kI, debut: now, fin: Infinity };
      direOmbre(r, ligneOmbre('o_ile'));
    } else if (ordre === 'chasse') {
      const c = joueur.cible && !joueur.cible.mort ? joueur.cible : null;
      if (!c) { UI.toast('Vise d’abord un ennemi (touche-le), puis donne l’ordre'); break; }
      cibleChasseO = c; r.ordre = 'chasse'; direOmbre(r, hasard(['Il ne verra pas l’aube.', 'Je m’en charge.', 'Considère-le comme mort.']));
    } else if (ordre === 'patrouille') { r.ordre = 'patrouille'; direOmbre(r, hasard(['Je veille sur ta ville.', 'Rien ne passera.', 'Je fais ma ronde, maître.'])); }
    else { r.ordre = ordre; direOmbre(r, ligneOmbre('o_' + ordre)); }
  }
  sauver(); UI.commandeOmbres && document.getElementById('cmdOmbres') && ouvrirCommandeOmbres();
}
function rappelerIle(i) { const r = ombresC()[i]; if (r && r.mission && r.mission.type === 'ile') { r.mission = null; r.ordre = 'combat'; sauver(); UI.toast(`${r.nom} quitte ton île et revient vers toi`); } }
function ombreGardeIle(ile) { if (!J.escouade || !J.ombresC) return null; const k = iles().indexOf(ile); return J.ombresC.find(r => r.mission && r.mission.type === 'ile' && r.mission.ile === k) || null; }
function ouvrirCommandeOmbres() {
  const R = ombresC(), now = Date.now();
  UI.commandeOmbres(R.map(r => {
    let etat = r.ordre === 'escorte' ? 'Escorte (n’attaque pas)' : r.ordre === 'garde' ? 'Te protège (frappe ce qui t’approche)' : r.ordre === 'repos' ? 'Renvoyée dans l’ombre' : 'Combat à tes côtés';
    if (now < (r.blesseeJusqua || 0)) etat = `Blessée · ${Math.ceil((r.blesseeJusqua - now) / 60000)} min`;
    if (r.mission) etat = r.mission.type === 'ile' ? `Garde ${r.mission.ile === -1 ? 'ton domaine' : (iles()[r.mission.ile] || {}).nom || 'ton île'}` : `${{ arene: 'À l’arène', donjon: 'En donjon : ' + LIEUX[r.mission.mode], secours: 'Secours : ' + LIEUX[r.mission.mode], vol: 'Vol chez ' + (r.mission.cible || '?') }[r.mission.type]} · ${Math.max(0, Math.ceil((r.mission.fin - now) / 60000))} min`;
    if (r.rapport) etat = 'Revient faire son rapport';
    return { i: r.i, nom: NOM_O(r), perso: r.perso, loyaute: r.loyaute, etat, libre: !r.mission && !r.rapport && now >= (r.blesseeJusqua || 0), ile: r.mission && r.mission.type === 'ile', victoires: r.victoires };
  }), [...iles().map(x => x.nom), ...(domaine() ? ['Mon domaine'] : [])], { ordonner, rappelerIle });
}
// ---- retour de mission : le résultat se décide là, avec le hasard et le caractère ----
function resoudreMission(r) {
  const m = r.mission, P = puissanceReelleJoueur(), tierA = (J.equip.arme || { tier: 1 }).tier, loy = r.loyaute / 100;
  const bonus = { fier: 0.06, ambitieux: 0.04, prudent: -0.02, joueuse: 0.02, silencieux: 0.03, avide: 0 }[r.perso] || 0;
  const rap = { type: m.type, lignes: [], gains: { argent: 0, objets: [], trophees: 0 }, succes: true, blessee: false, mode: m.mode, cible: m.cible };
  if (m.type === 'arene') {
    const n = 3; let v = 0; for (let k = 0; k < n; k++) if (Math.random() < 0.42 + loy * 0.3 + bonus) v++;
    rap.victoires = v; rap.succes = v >= 2;
    rap.gains.argent = Math.round(v * 26000 * (1 + tierA * 0.18)); rap.gains.trophees = v * 60;
    r.victoires += v; r.respect += v * 10; if (v === 0 && Math.random() < 0.4) rap.blessee = true;
  } else if (m.type === 'donjon') {
    const p = 0.88 - m.mode * 0.13 + loy * 0.12 + bonus; rap.succes = Math.random() < p;
    const L = lootCoffre(tirerCouleurCoffre(), MODES[m.mode], 3);
    rap.gains.argent = Math.round(L.argent * (rap.succes ? 1 : 0.3)); rap.gains.objets = rap.succes ? L.objets.slice(0, 2) : [];
    if (!rap.succes) rap.blessee = true;
  } else if (m.type === 'secours') {
    rap.succes = Math.random() < 0.82 + bonus; rap.gains.argent = rap.succes ? Math.round(18000 * (m.mode + 1) * (1 + tierA * 0.1)) : 0;
    if (rap.succes) { J.potions = (J.potions || 0) + 2; rap.lignes.push('+2 potions offertes par le rescapé'); r.loyaute = Math.min(100, r.loyaute + 4); } else rap.blessee = Math.random() < 0.5;
  } else if (m.type === 'vol') {
    const p = 0.48 + ({ avide: 0.14, prudent: 0.06, joueuse: 0.05 }[r.perso] || 0) + loy * 0.1; rap.succes = Math.random() < p;
    if (rap.succes) { rap.gains.argent = Math.round(120000 * (1 + tierA * 0.22) * rnd(0.7, 1.3)); if (Math.random() < 0.5) rap.gains.objets.push(Math.random() < 0.5 ? creerArme(hasard(CLASSES_BASE), Math.min(8, tierA), 2 + (Math.random() < 0.3 ? 1 : 0)) : creerArmure(hasard(['casque', 'plastron', 'bottes']), Math.min(8, tierA), 2)); }
    else rap.blessee = true;
  }
  if (rap.succes) r.loyaute = Math.min(100, r.loyaute + 2); else r.loyaute = Math.max(0, r.loyaute - 2);
  r.mission = null; r.rapport = rap; souvenir(r, m.type + (rap.succes ? '+' : '-'));
  sauver();
}
function texteRapport(r, rap) {
  const lieu = LIEUX[rap.mode] || '';
  if (rap.type === 'arene') return rap.victoires >= 2 ? hasard([`Maître, je reviens de l’arène : ${rap.victoires} victoires sur 3. Ton nom monte.`, `${rap.victoires} combats gagnés, maître. Ils ont scandé ton nom.`, `L’arène est à nous, maître. ${rap.victoires} victoires.`]) : hasard([`J’ai perdu, maître… ${rap.victoires} victoire seulement. Je recommencerai.`, `Ils étaient plus forts aujourd’hui, maître. Pardonne-moi.`]);
  if (rap.type === 'donjon') return rap.succes ? hasard([`${lieu[0].toUpperCase() + lieu.slice(1)} est vidé, maître. Voici ce que j’ai rapporté.`, `Les gardiens de ${lieu} sont tombés. Ce butin est à toi.`, `Mission accomplie dans ${lieu}, maître.`]) : hasard([`${lieu[0].toUpperCase() + lieu.slice(1)} était trop dangereux… J’ai fui avec ce que j’ai pu.`, 'Ils m’ont eue, maître. J’ai besoin de repos.']);
  if (rap.type === 'secours') return rap.succes ? hasard(['Le blessé est sauvé, maître. Il m’a donné ceci pour toi.', 'Je l’ai ramené vivant. Il te bénit, maître.', 'Sauvé. Il voulait connaître ton nom. Je le lui ai dit.']) : 'Trop tard, maître… Il n’a pas survécu.';
  if (rap.type === 'vol') return rap.succes ? hasard([`Le coffre de ${rap.cible} est à toi, maître. Il ne s’est rendu compte de rien.`, `Fait. ${rap.cible} va pleurer demain matin.`]) : `Les gardes de ${rap.cible} m’ont repérée, maître. Je suis blessée.`;
  return 'Je suis revenue, maître.';
}
// ---- le moment où une ombre vient te parler : à genoux, caméra centrée, de vrais choix ----
let sceneOmbre = null, derniereSceneO = -999, prochaineInitiative = 0;
function calmeOmbres() {
  if (!joueur || joueur.mort || transition || arene || goulet || sceneOmbre || !J.escouade) return false;
  if (joueur.combatT > 0 || G.t - derniereSceneO < 25) return false;
  if (document.querySelector('#dialTaverne,#dlgRelique,#dlgRenom,#cmdOmbres,#tabMissions') || !$('#butin').hidden || !$('#regl').hidden) return false;
  for (const e of ennemis) if (!e.mort && e.etat === 'chasse' && dist2D(e.pos, joueur.pos) < 26) return false;
  return true;
}
function scenePresente(r, texte, options, fini) {
  sceneOmbre = { r };
  let o = ombreActeur(r.i), temp = false;
  const devant = V(joueur.pos.x + Math.sin(joueur.angle) * 2.4, 0, joueur.pos.z + Math.cos(joueur.angle) * 2.4);
  const p = pointLibrePres(devant, 0, 1.5);
  if (!o) { o = creerOmbreEscouade(r.i); o.sceneOmbre = true; escouade.push(o); temp = true; }
  teleporterOmbre(o, p); o.pos.copy(p);
  o.angle = Math.atan2(joueur.pos.x - o.pos.x, joueur.pos.z - o.pos.z); o.root.rotation.y = o.angle;
  joueur.angle = Math.atan2(o.pos.x - joueur.pos.x, o.pos.z - joueur.pos.z); joueur.root.rotation.y = joueur.angle; joueur.jouer(joueur.def.idle);
  // à genoux : on fige l'animation de ramassage au point le plus bas
  o.sceneOmbre = true; o.jouer('PickUp', { boucle: false, forcer: true, vitesse: 1.2 }); programmer(0.42, () => { const a = o.actions.PickUp; if (a && sceneOmbre) a.paused = true; });
  sceneOmbre.o = o; sceneOmbre.temp = temp;
  sceneOmbre.cam = { d: G.camDist }; G.camCible = V((o.pos.x + joueur.pos.x) / 2, 0, (o.pos.z + joueur.pos.z) / 2); G.camDist = 15; document.body.classList.add('cinema');
  son('cloth1', 0.4, 0.7);
  programmer(0.6, () => UI.dialogueTaverne({ nom: NOM_O(r), titre: `Ombre de ${J.nom} · loyauté ${r.loyaute}`, modele: 'Rogue_Hooded', ombre: true, texte, options: options.map(op => ({ ...op, action: () => { UI.dialogueTaverne(null); finScene(op.reponse, () => { op.action && op.action(); fini && fini(); }); } })) }));
}
function finScene(reponse, apres) {
  const S = sceneOmbre; if (!S) return;
  const o = S.o; const a = o.actions.PickUp; if (a) a.paused = false;
  if (reponse) UI.parole(o, reponse);
  o.jouer(o.armeDef.idle, { fondu: 0.5 });
  programmer(1.6, () => {
    G.camCible = null; G.camDist = S.cam.d; document.body.classList.remove('cinema');
    if (S.temp || !presenteOmbre(S.r)) { fumeeOmbre(o.pos); G.scene.remove(o.root); UI.retirerPlaque(o); escouade.splice(escouade.indexOf(o), 1); }
    else o.sceneOmbre = false;
    sceneOmbre = null; derniereSceneO = G.t; apres && apres();
  });
}
function livrerRapport(r) {
  const rap = r.rapport; r.rapport = null;
  const g = rap.gains; J.argent += g.argent; if (g.trophees) J.trophees = (J.trophees || 0) + g.trophees;
  for (const it of g.objets) ajouterSac(it, true);
  if (rap.blessee) r.blesseeJusqua = Date.now() + (rap.type === 'vol' ? 15 : 10) * 60000;
  if (rap.type === 'arene' && rap.victoires) { changerRang('arene', 4 * rap.victoires, `Victoires de ${r.nom}`); if (r.victoires >= 3) exploit('ombre_arene'); }
  if (rap.type === 'vol') { const v = rap.cible; setTimeout(() => UI.chat(v, rap.succes ? hasard(['QUI A VIDÉ MON COFFRE ??', 'je me fais voler mon coffre pendant que je farm… sérieux', 'si je trouve le voleur…']) : hasard(['haha une ombre a essayé de me voler, pas aujourd’hui', 'mes gardes ont attrapé une ombre cette nuit lol'])), 4000); }
  sauver();
  const lignes = [g.argent ? `+ ${fmtN(g.argent)} d’argent` : '', g.trophees ? `+ ${g.trophees} trophées` : '', ...g.objets.map(it => nomObjet(it)), ...rap.lignes, rap.blessee ? `${r.nom} est blessée : ${rap.type === 'vol' ? 15 : 10} min de repos` : ''].filter(Boolean);
  const texte = texteRapport(r, rap) + (lignes.length ? `<br><small style="opacity:.85">${lignes.join(' · ')}</small>` : '');
  if (G.ombresParole === 'silence' || !calmeOmbres()) { UI.chat(NOM_O(r), texteRapport(r, rap)); if (lignes.length) UI.toast(`${r.nom} : ${lignes.join(' · ')}`); son('handleCoins', 0.5); return; }
  scenePresente(r, texte, [{ label: 'Bien joué', sous: 'Elle reprend son poste', reponse: hasard(['Merci, maître.', 'Toujours pour toi.', 'Ton ombre est fière.']), action: () => { son('handleCoins', 0.5); r.loyaute = Math.min(100, r.loyaute + 1); } },
    { label: 'Repose-toi', sous: 'Elle retourne dans l’ombre', reponse: 'Merci, maître. Je me retire.', action: () => { r.ordre = 'repos'; son('handleCoins', 0.5); } }]);
}
// ---- l'IA des ombres : des envies réelles, pondérées par leur caractère, leur loyauté et ce qui se passe dans le jeu ----
function initiativesOmbres() {
  const R = ombresC(), now = Date.now(), cands = [];
  const dispo = R.filter(r => !r.mission && !r.rapport && now >= (r.blesseeJusqua || 0) && r.ordre !== 'repos');
  if (!dispo.length) return null;
  const E = crypteEtat;
  if (monde && monde.type === 'donjon' && E && !E.ouverte && ['violet', 'legendaire'].includes(E.relique.rarete)) cands.push({ type: 'relique', base: 3 });
  if (monde && monde.type === 'donjon' && coffres.some(c => !c.ouvert && c.couleur === 'legendaire')) cands.push({ type: 'coffre', base: 2.5 });
  if (!modeActuel || modeActuel.id === 'ile') { cands.push({ type: 'secours', base: 0.5 }, { type: 'arene', base: 0.6 }); if (iles().length) cands.push({ type: 'vol', base: 0.45 }); cands.push({ type: 'parole', base: 0.35 }); }
  else cands.push({ type: 'parole', base: 0.2 });
  let best = null, bs = 0;
  for (const c of cands) for (const r of dispo) {
    const aff = (AFF_OMBRE[r.perso] || {})[c.type] || 1;
    const deja = r.souvenirs.filter(s => s.s.startsWith('req_' + c.type) && now - s.t < 30 * 60000).length;
    const egoisme = (c.type === 'arene' || c.type === 'vol') ? 1 + (100 - r.loyaute) / 120 : 1;
    const score = c.base * aff * egoisme / (1 + deja * 1.5) * (0.4 + Math.random() * 1.2);
    if (score > bs) { bs = score; best = { ...c, r }; }
  }
  return bs > 0.6 ? best : null;
}
function lancerInitiative(c) {
  const r = c.r, aRefuse = r.souvenirs.some(s => s.s === 'refus_' + c.type);
  souvenir(r, 'req_' + c.type);
  const prefixe = aRefuse && c.type !== 'parole' ? ligneOmbre('souvenir_non') + ' ' : '';
  const refuser = { label: 'Refuser', reponse: ligneOmbre('non_' + r.perso), action: () => { r.loyaute = Math.max(0, r.loyaute - (r.perso === 'fier' || r.perso === 'ambitieux' ? 5 : 2)); souvenir(r, 'refus_' + c.type); sauver(); } };
  const accepter = (fn, sous) => ({ label: 'J’accepte', sous, reponse: ligneOmbre('oui'), action: () => { r.loyaute = Math.min(100, r.loyaute + 4); fn(); sauver(); } });
  if (c.type === 'relique') {
    const C = monde.crypte, rar = RARETES_RELIQUE[crypteEtat.relique.rarete].nom.toLowerCase();
    scenePresente(r, prefixe + ligneOmbre('req_relique', { rar }), [accepter(() => { monde.crypteVue = true; monde._fond = null; crypteEtat.indice = true; UI.toast(`${r.nom} t’attend devant le mur fissuré`, true); programmer(2, () => { const o = ombreActeur(r.i); if (o) teleporterOmbre(o, C.murObj.pos); }); }, 'Elle te montre le passage secret'), refuser]);
  } else if (c.type === 'coffre') {
    const cf = coffres.find(x => !x.ouvert && x.couleur === 'legendaire');
    scenePresente(r, prefixe + ligneOmbre('req_coffre'), [accepter(() => { UI.toast('Le coffre légendaire est marqué : suis son rayon doré', true); if (cf) { cf.beam.scale.set(2, 1.6, 2); programmer(2, () => { const o = ombreActeur(r.i); if (o) teleporterOmbre(o, cf.pos); }); } }, 'Elle te guide vers le coffre'), refuser]);
  } else if (c.type === 'secours') {
    const m = Math.floor(Math.random() * 3);
    scenePresente(r, prefixe + ligneOmbre('req_secours', { lieu: LIEUX[m] }), [accepter(() => ordonner([r.i], 'secours', { mode: m }), 'Elle part 4 min'), refuser]);
  } else if (c.type === 'vol') {
    const cible = hasard(BOTS)[0], rar = hasard(['richement garni', 'rare', 'légendaire']);
    scenePresente(r, prefixe + ligneOmbre('req_vol', { cible, rar }), [accepter(() => ordonner([r.i], 'vol', { cible }), 'Risqué : elle peut revenir blessée'), refuser]);
  } else if (c.type === 'arene') {
    scenePresente(r, prefixe + ligneOmbre('req_arene'), [accepter(() => ordonner([r.i], 'arene'), 'Elle combat 3 fois : argent, trophées et rang'), refuser]);
  } else {
    scenePresente(r, ligneOmbre('parole'), [{ label: '…', reponse: '', action: () => {} }, { label: 'Merci de ta loyauté', reponse: hasard(['…Merci, maître.', 'Toujours.', 'Je sais.']), action: () => { r.loyaute = Math.min(100, r.loyaute + 2); } }]);
  }
}
let ombresT = 0;
function majCommandeOmbres(dt) {
  if (!J.escouade) return;
  ombresT -= dt; if (ombresT > 0) return; ombresT = 1;
  const R = ombresC(), now = Date.now();
  for (const r of R) if (r.mission && r.mission.fin <= now) resoudreMission(r);
  const rr = R.find(r => r.rapport);
  if (rr && (calmeOmbres() || G.ombresParole === 'silence')) { livrerRapport(rr); return; }
  if (!prochaineInitiative) prochaineInitiative = now + rnd(3, 5) * 60000;
  if (G.ombresParole === 'silence' || now < prochaineInitiative || !calmeOmbres()) return;
  const c = initiativesOmbres();
  const gap = G.ombresParole === 'rare' ? rnd(15, 25) : rnd(6, 10);
  if (!c) { prochaineInitiative = now + 60000; return; } // rien d'intéressant : on réessaie dans une minute
  prochaineInitiative = now + gap * 60000;
  lancerInitiative(c);
}

