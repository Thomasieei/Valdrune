/* NOCTALIS — Domaine : ressources, quartiers, tours, guilde, factions, renommée, événements scénarisés */
import { S, ZONES, ZK, zoneHp, fmt, rnd, pick, clamp, RANK_COL } from './core.js';

export const RES = [
  { id: 'minerai', name: 'Ombracier', col: '#7dd3fc', ico: 'ore' },
  { id: 'bois', name: 'Bois-de-nuit', col: '#c08457', ico: 'wood' },
  { id: 'essence', name: "Essence d'âme", col: '#e879f9', ico: 'soul' },
];
export const FACTIONS = {
  lames: { name: 'Les Lames Grises', col: '#a3b1c6', model: 'Knight', desc: 'Mercenaires fiers, payés pour tenir le Bois.' },
  bandits: { name: 'Bandits du Gué', col: '#c08457', model: 'Rogue_Hooded', desc: 'Pillards qui rançonnent les routes.' },
  culte: { name: "Le Culte de l'Os", col: '#d8b4fe', model: 'Mage', desc: 'Prêtres qui vénèrent les morts… et les craignent.' },
  sel: { name: 'Marchands du Sel', col: '#ffcc33', model: 'Barbarian', desc: 'Guilde marchande. Tout a un prix.' },
  couronne: { name: 'La Couronne Déchue', col: '#ff5544', model: 'Knight', desc: 'Les derniers chevaliers du roi parjure.' },
  joueur: { name: 'Ton Domaine', col: '#c26bff' },
};
export const DISTRICTS = [
  { id: 'hameau', name: 'Hameau des Bûcherons', z: 0, fac: 'lames', res: 'bois', diff: 1, x: 18, y: 64, cap: 'varn' },
  { id: 'carriere', name: 'Carrière de Brunepierre', z: 0, fac: 'lames', res: 'minerai', diff: 1.4, x: 30, y: 82, cap: null },
  { id: 'gue', name: 'Gué aux Loups', z: 0, fac: 'bandits', res: 'or', diff: 0.8, x: 8, y: 84, cap: 'grisoin' },
  { id: 'ossuaire', name: 'Ossuaire du Nord', z: 1, fac: 'culte', res: 'essence', diff: 1, x: 46, y: 30, cap: 'ysolde' },
  { id: 'linceuls', name: 'Marché des Linceuls', z: 1, fac: 'sel', res: 'or', diff: 1.2, x: 58, y: 52, cap: 'orsel' },
  { id: 'hurlantes', name: 'Mines Hurlantes', z: 1, fac: 'culte', res: 'minerai', diff: 1.5, x: 40, y: 50, cap: null },
  { id: 'faubourg', name: 'Faubourg Écarlate', z: 2, fac: 'couronne', res: 'or', diff: 1, x: 78, y: 26, cap: 'kesh' },
  { id: 'forges', name: 'Forges du Parjure', z: 2, fac: 'couronne', res: 'minerai', diff: 1.3, x: 90, y: 46, cap: null },
  { id: 'sanctuaire', name: 'Sanctuaire Brisé', z: 2, fac: 'couronne', res: 'essence', diff: 1.6, x: 80, y: 66, cap: null },
];
export const CAPTAINS = {
  varn: { name: 'Varn le Balafré', model: 'Knight', trait: 'loyal', fac: 'lames' },
  grisoin: { name: 'Grisoin', model: 'Rogue_Hooded', trait: 'ruse', fac: 'bandits' },
  ysolde: { name: 'Sœur Ysolde', model: 'Mage', trait: 'mystique', fac: 'culte' },
  orsel: { name: 'Maître Orsel', model: 'Barbarian', trait: 'avare', fac: 'sel' },
  kesh: { name: 'Dame Kesh', model: 'Knight', trait: 'ambitieux', fac: 'couronne' },
};
export const TRAITS = {
  loyal: { n: 'Loyal', d: '+loyauté chaque minute' }, ruse: { n: 'Rusé', d: '+25% production' }, mystique: { n: 'Mystique', d: '+50% essence' },
  avare: { n: 'Avare', d: '+50% or, loyauté en baisse' }, ambitieux: { n: 'Ambitieux', d: '+40% défense et production… mais il ou elle en veut plus' },
};
export const TOWERS = {
  guet: { name: 'Tour de guet', d: '+30% défense, +loyauté', cost: { minerai: 40, bois: 60 } },
  caserne: { name: 'Caserne', d: '+50% défense, étouffe les révoltes', cost: { minerai: 70, bois: 40 } },
  mine: { name: 'Mine profonde', d: '+50% Ombracier', cost: { bois: 80, essence: 5 } },
  scierie: { name: "Scierie d'ombre", d: '+50% Bois-de-nuit', cost: { minerai: 60, essence: 5 } },
  puits: { name: "Puits d'âmes", d: '+50% Essence', cost: { minerai: 60, bois: 60 } },
  marche: { name: 'Marché', d: "+40% d'or (impôts)", cost: { minerai: 50, bois: 50, essence: 10 } },
};
export const TITLES = [[0, 'Inconnu'], [150, "Chasseur d'ombres"], [600, 'Seigneur de guerre'], [2000, 'Souverain'], [7000, 'Monarque des Ombres']];
export const TAX = [{ n: 'Faibles', g: 0.6, l: 0.25 }, { n: 'Normaux', g: 1, l: 0 }, { n: 'Lourds', g: 1.6, l: -0.35 }];

export function dom() {
  if (!S.dom) S.dom = {
    res: { minerai: 0, bois: 0, essence: 0 }, renom: 0, tick: 0, evT: 60, pending: [], log: [], flags: {},
    att: { lames: 0, bandits: -10, culte: 0, sel: 10, couronne: -20 },
    d: Object.fromEntries(DISTRICTS.map(d => [d.id, { owner: d.fac, loy: 50, towers: {}, gov: null, workers: 0, tax: 1, held: 0 }])),
    lts: [], bonusEveil: 0, income: {},
  };
  return S.dom;
}
export const title = () => { const r = dom().renom; let t = 0; TITLES.forEach((x, i) => { if (r >= x[0]) t = i; }); return t; };
export const titleName = () => TITLES[title()][1];
export const owned = () => DISTRICTS.filter(d => dom().d[d.id].owner === 'joueur');
export const discount = () => [0, 0.05, 0.1, 0.15, 0.22][title()];
export function addRenom(n) { const t0 = title(); dom().renom = Math.max(0, dom().renom + n); const t1 = title(); if (t1 > t0) queue('titre'); }
export function towerCost(d, type, lvl) { const z = DISTRICTS.find(x => x.id === d).z; const c = {}; for (const k in TOWERS[type].cost) c[k] = Math.ceil(TOWERS[type].cost[k] * Math.pow(1.9, lvl) * Math.pow(3, z)); return c; }
export const canPay = c => Object.entries(c).every(([k, v]) => k === 'or' ? S.gold >= v : dom().res[k] >= v);
export function pay(c) { for (const [k, v] of Object.entries(c)) { if (k === 'or') S.gold -= v; else dom().res[k] -= v; } }
export const costTxt = c => Object.entries(c).map(([k, v]) => `${fmt(v)} ${k === 'or' ? 'or' : RES.find(r => r.id === k).name}`).join(' · ');
export function defPower(id) {
  const D = DISTRICTS.find(x => x.id === id), st = dom().d[id];
  let m = 1; for (const [t, l] of Object.entries(st.towers)) { if (t === 'guet') m += 0.3 * l; if (t === 'caserne') m += 0.5 * l; }
  const lt = st.gov && dom().lts.find(x => x.id === st.gov); if (lt && lt.trait === 'ambitieux') m += 0.4;
  return 60 * Math.pow(ZK, D.z) * D.diff * m;
}
export function lieutenant(id) { return dom().lts.find(l => l.id === id); }
export const freeWorkers = () => { const used = Object.values(dom().d).reduce((a, b) => a + b.workers, 0); return Math.max(0, S.shadows.filter(s => !s.eq).length - used); };

/* production d'un quartier pour 1 minute */
export function yieldOf(id) {
  const D = DISTRICTS.find(x => x.id === id), st = dom().d[id];
  if (st.owner !== 'joueur') return {};
  const lt = st.gov && lieutenant(st.gov);
  let m = (0.5 + st.loy / 100) * (1 + 0.08 * st.workers) * (lt && lt.trait === 'ruse' ? 1.25 : 1) * (lt && lt.trait === 'ambitieux' ? 1.4 : 1);
  const out = {}; const T = st.towers;
  if (D.res === 'or') out.or = zoneHp(D.z) * 6 * m * TAX[st.tax].g * (1 + 0.4 * (T.marche || 0)) * (lt && lt.trait === 'avare' ? 1.5 : 1);
  else {
    out[D.res] = 30 * Math.pow(3, D.z) * m * (1 + 0.5 * (T[{ minerai: 'mine', bois: 'scierie', essence: 'puits' }[D.res]] || 0)) * (D.res === 'essence' && lt && lt.trait === 'mystique' ? 1.5 : 1);
    out.or = zoneHp(D.z) * 2 * m * TAX[st.tax].g * (1 + 0.4 * (T.marche || 0));
  }
  for (const t of ['mine', 'scierie', 'puits']) if (T[t] && !out[{ mine: 'minerai', scierie: 'bois', puits: 'essence' }[t]]) out[{ mine: 'minerai', scierie: 'bois', puits: 'essence' }[t]] = 8 * Math.pow(3, D.z) * T[t] * m;
  return out;
}
export function incomeTotal() { const tot = {}; for (const d of owned()) for (const [k, v] of Object.entries(yieldOf(d.id))) tot[k] = (tot[k] || 0) + v; return tot; }

/* tic : toutes les 10 s de jeu */
export function tick(dt, busy, notify) {
  const D = dom(); D.tick += dt; if (D.tick < 10) return; D.tick -= 10;
  const inc = incomeTotal();
  for (const [k, v] of Object.entries(inc)) { if (k === 'or') S.gold += v / 6; else D.res[k] += v / 6; }
  for (const d of owned()) {
    const st = D.d[d.id]; st.held += 10; const lt = st.gov && lieutenant(st.gov);
    let dl = TAX[st.tax].l + 0.05 * (st.towers.guet || 0) + 0.12 * (st.towers.caserne || 0) - 0.06;
    if (lt) { dl += 0.12; if (lt.trait === 'loyal') dl += 0.2; if (lt.trait === 'avare') dl -= 0.15; lt.loy = clamp(lt.loy + (lt.trait === 'ambitieux' ? -0.25 : 0.05) * (st.tax === 2 ? 2 : 1), 0, 100); }
    if (D.att[d.fac] < -40) dl -= 0.1;
    st.loy = clamp(st.loy + dl, 0, 100);
    if (st.loy < 18 && !D.pending.some(p => p.id === 'revolte' && p.d === d.id) && !st.calm) queue('revolte', { d: d.id });
    if (st.loy > 30) st.calm = 0;
  }
  for (const l of D.lts) if (l.loy < 12 && l.gov && !D.pending.some(p => p.id === 'trahison')) queue('trahison', { lt: l.id });
  D.evT -= 10;
  if (D.evT <= 0 && !busy) { D.evT = rnd(100, 170); const e = pickEvent(); if (e) { queue(e.id, e.arg); notify && notify(); } }
}
export function queue(id, arg = {}) { const D = dom(); if (D.pending.some(p => p.id === id && p.d === arg.d)) return; D.pending.push({ id, ...arg }); }
function pickEvent() {
  const D = dom(), F = D.flags, own = owned();
  const c = [];
  if (!F.varn && S.lvl >= 3) c.push({ id: 'varn', w: 50 });
  if (own.length && own.some(d => D.d[d.id].tax === 2)) c.push({ id: 'petition', w: 6, arg: { d: pick(own.filter(d => D.d[d.id].tax === 2)).id } });
  for (const f of ['lames', 'culte', 'couronne', 'bandits']) if (D.att[f] < -40 && own.some(d => d.fac === f)) c.push({ id: 'ultimatum', w: 5, arg: { fac: f } });
  if (!F.orsel && S.lvl >= 12) c.push({ id: 'orsel', w: 6 });
  if (!F.ysolde && S.lvl >= 14) c.push({ id: 'ysolde', w: 6 });
  if (!F.toll && S.lvl >= 5 && D.d.gue.owner !== 'joueur') c.push({ id: 'peage', w: 5 });
  if (D.lts.some(l => l.trait === 'ambitieux' && l.gov && !F.keshduc)) c.push({ id: 'ambition', w: 6 });
  if (own.length >= 2) c.push({ id: 'fete', w: 3 }, { id: 'espion', w: 3 });
  if (S.lvl >= 6) c.push({ id: 'refugies', w: 3 });
  if (!c.length) return null; let t = c.reduce((a, b) => a + b.w, 0), r = Math.random() * t; for (const x of c) { r -= x.w; if (r <= 0) return x; } return c[0];
}

/* ---------- dialogues ----------
   chaque événement renvoie { who, model, fac, text, choices:[{t, req, reqTxt, eff -> texte résultat}] } */
export function dialogue(ev, api) {
  const D = dom(), F = D.flags, pw = api.power();
  const d = ev.d && DISTRICTS.find(x => x.id === ev.d), ds = d && D.d[d.id];
  const att = (f, n) => D.att[f] = clamp(D.att[f] + n, -100, 100);
  switch (ev.id) {
    case 'varn': return { who: 'Varn le Balafré', model: 'Knight', fac: 'lames',
      text: `Halte, Veilleur. Ce bois appartient aux Lames Grises. Chaque loup que tu abats ici, c'est une prime qui ne tombe pas dans nos bourses. Alors dis-moi… tu paies, ou tu dégages ?`,
      choices: [
        { t: 'Je chasse où je veux.', eff: () => { F.varn = 1; att('lames', -20); addRenom(15); return 'Varn crache par terre. « Alors viens prendre le Hameau, si tu l’oses. » Les Lames Grises te considèrent comme une menace.'; } },
        { t: 'Payer le droit de chasse (500 or)', req: () => S.gold >= 500, reqTxt: '500 or', eff: () => { F.varn = 1; S.gold -= 500; att('lames', 20); return '« Raisonnable. Pour l’instant. » Les Lames Grises te tolèrent.'; } },
        { t: 'Laisser tes ombres se lever derrière toi.', req: () => S.shadows.filter(s => s.eq).length >= 8, reqTxt: '8 ombres équipées', eff: () => { F.varn = 1; att('lames', -5); addRenom(40); return 'Les ombres se dressent, silencieuses. Varn recule d’un pas, la main tremblante sur la garde. « …Garde ton bois. » Ta renommée grandit.'; } },
      ] };
    case 'capture': {
      const cap = CAPTAINS[ev.cap]; const fac = FACTIONS[d.fac];
      return { who: cap ? cap.name : `Capitaine de ${fac.name}`, model: cap ? cap.model : fac.model, fac: d.fac,
        text: `${d.name} est tombé. ${cap ? cap.name : 'Le capitaine'} est à genoux devant toi, le souffle court. « Fais vite, Veilleur. Ou fais-moi une offre. »`,
        choices: [
          { t: 'Exécuter. Que tout le quartier le voie.', eff: () => { addRenom(60); ds.loy = clamp(ds.loy - 15, 0, 100); att(d.fac, -25); return 'La foule se tait. Personne ne contestera plus ton pouvoir ici… mais on te craint plus qu’on ne t’aime.'; } },
          ...(cap && !lieutenant(ev.cap) ? [{ t: 'Épargner — et le recruter dans ta guilde.', eff: () => { D.lts.push({ id: ev.cap, name: cap.name, trait: cap.trait, model: cap.model, loy: 55, gov: null }); ds.loy = clamp(ds.loy + 15, 0, 100); att(d.fac, 10); addRenom(20); return `${cap.name} rejoint ta guilde comme lieutenant (${TRAITS[cap.trait].n}). Nomme-le gouverneur d’un quartier depuis le Domaine.`; } }] : []),
          { t: 'Éveiller son ombre. (3 runes)', req: () => S.runes >= 3, reqTxt: '3 runes', eff: () => { S.runes -= 3; api.captainShadow(d, cap); addRenom(35); att(d.fac, -35); ds.loy = clamp(ds.loy - 5, 0, 100); return 'Son corps s’effondre, son ombre se relève et s’incline devant toi. Sa faction ne te le pardonnera pas.'; } },
        ] };
    }
    case 'revolte': return { who: 'Meneur des insurgés', model: 'Barbarian', fac: d.fac,
      text: `Les habitants de ${d.name} se sont soulevés ! Ils barricadent les rues et brûlent tes bannières. « On ne sert pas un maître qui nous saigne ! »`,
      choices: [
        { t: 'Écraser la révolte. (combat)', eff: () => { api.assault(d.id, 'revolte'); return null; } },
        { t: `Négocier : ${fmt(zoneHp(d.z) * 300)} or`, req: () => S.gold >= zoneHp(d.z) * 300, reqTxt: fmt(zoneHp(d.z) * 300) + ' or', eff: () => { S.gold -= zoneHp(d.z) * 300; ds.loy = 45; ds.calm = 1; ds.tax = Math.min(ds.tax, 1); return 'Tu baisses les impôts et ouvres les greniers. La foule se disperse, méfiante mais calmée.'; } },
        { t: 'Abandonner le quartier.', eff: () => { ds.owner = d.fac; ds.loy = 50; ds.gov = null; addRenom(-40); return `${d.name} retourne à ${FACTIONS[d.fac].name}. Ta renommée en souffre.`; } },
      ] };
    case 'petition': return { who: 'Ancienne du quartier', model: 'Mage', fac: 'joueur',
      text: `Seigneur… à ${d.name}, les familles ne mangent plus qu'un jour sur deux. Vos impôts sont trop lourds. Nous vous en supplions.`,
      choices: [
        { t: 'Baisser les impôts.', eff: () => { ds.tax = 1; ds.loy = clamp(ds.loy + 20, 0, 100); addRenom(5); return 'Les rues de ' + d.name + ' respirent. La loyauté remonte.'; } },
        { t: 'Refuser. Le Domaine a besoin d’or.', eff: () => { ds.loy = clamp(ds.loy - 10, 0, 100); return 'L’ancienne baisse les yeux. Les murmures grondent dans les ruelles.'; } },
        { t: 'Faire un exemple.', eff: () => { ds.loy = clamp(ds.loy - 25, 0, 100); addRenom(30); return 'Plus personne ne viendra se plaindre. Plus personne ne viendra tout court.'; } },
      ] };
    case 'ultimatum': { const f = FACTIONS[ev.fac]; const mine = owned().filter(x => x.fac === ev.fac); const tgt = pick(mine); if (!tgt) return null;
      return { who: `Émissaire de ${f.name}`, model: f.model, fac: ev.fac,
        text: `${f.name} exige que tu rendes ${tgt.name}. Sinon, nos lames viendront le reprendre avant la prochaine lune.`,
        choices: [
          { t: 'Rendre le quartier.', eff: () => { D.d[tgt.id].owner = ev.fac; D.d[tgt.id].gov = null; att(ev.fac, 40); addRenom(-30); return 'L’émissaire sourit. Tu as perdu un quartier, mais gagné un répit.'; } },
          { t: 'Payer un tribut (150 Ombracier, 150 Bois)', req: () => canPay({ minerai: 150, bois: 150 }), reqTxt: '150 Ombracier · 150 Bois', eff: () => { pay({ minerai: 150, bois: 150 }); att(ev.fac, 30); return '« Sage décision. » La tension retombe.'; } },
          { t: 'Refuser. Qu’ils viennent.', eff: () => { att(ev.fac, -10); D.pending.push({ id: 'contre', d: tgt.id, fac: ev.fac }); addRenom(10); return 'L’émissaire tourne les talons. Une attaque se prépare contre ' + tgt.name + '.'; } },
          { t: 'Humilier l’émissaire.', req: () => title() >= 2, reqTxt: 'Titre : Seigneur de guerre', eff: () => { att(ev.fac, -25); addRenom(70); att('sel', 10); return 'Tu le renvoies sans ses bottes ni sa bannière. Toute la région en parle déjà.'; } },
        ] }; }
    case 'contre': { const f = FACTIONS[ev.fac];
      return { who: `Commandant de ${f.name}`, model: f.model, fac: ev.fac, text: `${f.name} marche sur ${d.name} ! Leurs bannières sont déjà aux portes.`,
        choices: [{ t: 'Défendre le quartier. (combat)', eff: () => { api.assault(d.id, 'defense'); return null; } },
          { t: 'Laisser tomber le quartier.', eff: () => { ds.owner = ev.fac; ds.gov = null; addRenom(-50); return d.name + ' est perdu.'; } }] }; }
    case 'orsel': return { who: 'Maître Orsel', model: 'Barbarian', fac: 'sel',
      text: `Ah, le fameux Veilleur ! Les Marchands du Sel ont un nez pour les puissants. Une alliance ? Nos caravanes, vos ombres. Bien sûr, le Culte de l'Os n'aimera pas ça…`,
      choices: [
        { t: 'Alliance commerciale.', eff: () => { F.orsel = 1; att('sel', 35); att('culte', -20); D.flags.sel = 1; return 'Alliance scellée : +15% d’or sur tous tes quartiers. Le Culte de l’Os grince des dents.'; } },
        { t: 'Acheter leurs plans de tour (30 Éclats)', req: () => S.gems >= 30, reqTxt: '30 Éclats', eff: () => { F.orsel = 1; S.gems -= 30; D.res.minerai += 120; D.res.bois += 120; return 'Orsel te cède des matériaux : +120 Ombracier, +120 Bois-de-nuit.'; } },
        { t: 'Je prendrai votre or par la force.', eff: () => { F.orsel = 1; att('sel', -40); addRenom(25); return 'Orsel pâlit. « Vous le regretterez. » Les Marchands du Sel deviennent hostiles.'; } },
      ] };
    case 'ysolde': return { who: 'Sœur Ysolde', model: 'Mage', fac: 'culte',
      text: `Tu marches avec les morts, Veilleur. Le Culte l'a vu dans les os. Offre-nous cinq ombres faibles, et nous t'apprendrons à mieux entendre les âmes qui refusent de se lever.`,
      choices: [
        { t: 'Sacrifier 5 ombres de rang E-D.', req: () => S.shadows.filter(s => s.r <= 1 && !s.eq && !s.lock).length >= 5, reqTxt: '5 ombres E-D libres', eff: () => { F.ysolde = 1; let n = 0; S.shadows = S.shadows.filter(s => { if (n < 5 && s.r <= 1 && !s.eq && !s.lock) { n++; return false; } return true; }); D.bonusEveil += 0.1; att('culte', 25); D.res.essence += 60; return 'Le rituel s’achève. Chance d’Éveil +10% permanente, +60 Essence.'; } },
        { t: 'Refuser poliment.', eff: () => { F.ysolde = 1; return '« Les morts attendront. Ils sont patients. »'; } },
        { t: 'Exiger leur grimoire.', req: () => title() >= 2, reqTxt: 'Titre : Seigneur de guerre', eff: () => { F.ysolde = 1; att('culte', -30); D.bonusEveil += 0.05; addRenom(40); return 'Ysolde te tend le grimoire, les doigts crispés. Chance d’Éveil +5%. Le Culte te hait désormais.'; } },
      ] };
    case 'peage': return { who: 'Grisoin', model: 'Rogue_Hooded', fac: 'bandits',
      text: `Hé hé. Le Gué, c'est mon péage. Même les ombres paient pour traverser, chef. Cinquante pièces par tête… on va dire mille, pour toi.`,
      choices: [
        { t: 'Payer 1 000 or.', req: () => S.gold >= 1000, reqTxt: '1 000 or', eff: () => { F.toll = 1; S.gold -= 1000; att('bandits', 25); return 'Grisoin mord la pièce et s’écarte en ricanant.'; } },
        { t: 'Attaquer le Gué. (combat)', eff: () => { F.toll = 1; api.assault('gue', 'conquete'); return null; } },
        { t: 'Lui proposer une place dans ta guilde.', req: () => title() >= 1, reqTxt: "Titre : Chasseur d'ombres", eff: () => { F.toll = 1; if (!lieutenant('grisoin')) D.lts.push({ id: 'grisoin', name: 'Grisoin', trait: 'ruse', model: 'Rogue_Hooded', loy: 40, gov: null }); att('bandits', 30); return 'Grisoin hausse un sourcil, puis serre ta main. Il rejoint ta guilde (Rusé) — à surveiller.'; } },
      ] };
    case 'ambition': { const l = D.lts.find(x => x.trait === 'ambitieux' && x.gov); const gd = DISTRICTS.find(x => x.id === l.gov);
      return { who: l.name, model: l.model, fac: 'joueur', text: `J'ai fait de ${gd.name} le quartier le plus rentable de ton Domaine. Je veux un titre : Duchesse. Et une part des impôts.`,
        choices: [
          { t: 'Accorder le titre.', eff: () => { F.keshduc = 1; l.loy = 90; D.d[gd.id].loy = clamp(D.d[gd.id].loy + 10, 0, 100); addRenom(-15); return `${l.name} s’incline, ravie. Sa loyauté est totale… pour l’instant.`; } },
          { t: 'Refuser.', eff: () => { F.keshduc = 1; l.loy = clamp(l.loy - 35, 0, 100); return `Un éclair passe dans ses yeux. « Comme tu voudras. » Sa loyauté chute.`; } },
          { t: 'La remettre à sa place.', req: () => S.shadows.filter(s => s.eq && s.r >= 4).length >= 3, reqTxt: '3 ombres de rang A+', eff: () => { F.keshduc = 1; l.loy = clamp(l.loy + 20, 0, 100); addRenom(30); return `Tes ombres d’élite l’encerclent sans un bruit. ${l.name} comprend. « …Pardonnez mon audace. »`; } },
        ] }; }
    case 'trahison': { const l = lieutenant(ev.lt); if (!l || !l.gov) return null; const gd = DISTRICTS.find(x => x.id === l.gov);
      return { who: l.name, model: l.model, fac: 'joueur', text: `${l.name} a fermé les portes de ${gd.name} et fait hisser son propre étendard. « Ce quartier est à moi, désormais. »`,
        choices: [{ t: 'Reprendre le quartier. (combat)', eff: () => { D.lts = D.lts.filter(x => x !== l); D.d[gd.id].gov = null; api.assault(gd.id, 'revolte'); return null; } },
          { t: 'Lui laisser le quartier.', eff: () => { D.lts = D.lts.filter(x => x !== l); D.d[gd.id].owner = gd.fac; D.d[gd.id].gov = null; addRenom(-60); return `${gd.name} est perdu. Les autres lieutenants ont vu ta faiblesse.`; } }] }; }
    case 'titre': { const t = titleName();
      return { who: 'Héraut de la Citadelle', model: 'Knight', fac: 'joueur', text: `Oyez ! Que tous sachent que le Veilleur est désormais « ${t} » ! Les marchands baissent leurs prix, les gardes s'inclinent sur ton passage.`,
        choices: [{ t: 'Que le peuple se prosterne.', eff: () => { addRenom(20); for (const d of owned()) D.d[d.id].loy = clamp(D.d[d.id].loy - 5, 0, 100); return 'Ta légende enfle. Les quartiers, eux, te craignent un peu plus.'; } },
          { t: 'Je ne suis qu’un veilleur.', eff: () => { for (const d of owned()) D.d[d.id].loy = clamp(D.d[d.id].loy + 8, 0, 100); return 'Ta modestie touche le peuple : +8 loyauté dans tous tes quartiers.'; } }] }; }
    case 'fete': return { who: 'Intendant du Domaine', model: 'Barbarian', fac: 'joueur', text: `Les récoltes ont été bonnes. Le peuple réclame une fête en ton honneur. Cela coûtera, mais quelle ferveur !`,
      choices: [{ t: 'Offrir la fête (80 Bois, 40 Essence)', req: () => canPay({ bois: 80, essence: 40 }), reqTxt: '80 Bois · 40 Essence', eff: () => { pay({ bois: 80, essence: 40 }); for (const d of owned()) D.d[d.id].loy = clamp(D.d[d.id].loy + 15, 0, 100); addRenom(25); return 'Trois jours de fête ! +15 loyauté partout.'; } },
        { t: 'Pas cette fois.', eff: () => 'L’intendant soupire et range ses listes.' }] };
    case 'espion': { const f = pick(['lames', 'culte', 'couronne', 'bandits']);
      return { who: 'Garde de la Citadelle', model: 'Knight', fac: 'joueur', text: `Nous avons capturé un espion de ${FACTIONS[f].name} près de tes entrepôts. Il cartographiait tes défenses.`,
        choices: [{ t: 'L’interroger.', eff: () => { D.res.minerai += 40; att(f, -10); return 'Il parle : une cache d’Ombracier (+40). Sa faction est furieuse.'; } },
          { t: 'Le renvoyer avec un message.', eff: () => { att(f, 15); addRenom(10); return '« Dis à tes maîtres que je les vois. » Ils te respectent un peu plus.'; } },
          { t: 'L’éveiller.', req: () => S.runes >= 2, reqTxt: '2 runes', eff: () => { S.runes -= 2; api.captainShadow({ z: Math.max(0, api.zMax()), fac: f }, { name: 'Espion de ' + FACTIONS[f].name, model: FACTIONS[f].model }); att(f, -20); return 'Une nouvelle ombre rejoint tes rangs.'; } }] }; }
    case 'refugies': return { who: 'Réfugiés du Bastion', model: 'Rogue_Hooded', fac: 'joueur', text: `Une colonne de réfugiés fuit la Couronne Déchue. Ils demandent asile dans ton Domaine.`,
      choices: [{ t: 'Les accueillir.', eff: () => { const o = owned(); for (const d of o) D.d[d.id].loy = clamp(D.d[d.id].loy + 6, 0, 100); att('couronne', -10); addRenom(20); D.res.bois += 30; return 'Ils s’installent et travaillent dur : +30 Bois, loyauté en hausse.'; } },
        { t: 'Les renvoyer.', eff: () => { att('couronne', 10); return 'La colonne repart sous la pluie.'; } }] };
  }
  return null;
}
