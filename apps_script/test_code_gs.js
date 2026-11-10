// Test du script Google avec un faux Google Sheets : node apps_script/test_code_gs.js apps_script/Code.gs
const fs = require('fs'), vm = require('vm'), crypto = require('crypto');
const code = fs.readFileSync(process.argv[2], 'utf8');
// --- Faux Google Sheets ---
class Range {
  constructor(sh, r, c, nr, nc) { Object.assign(this, { sh, r, c, nr, nc }); }
  getValues() { const o = []; for (let i = 0; i < this.nr; i++) { const row = []; for (let j = 0; j < this.nc; j++) row.push((this.sh.d[this.r - 1 + i] || [])[this.c - 1 + j] ?? ''); o.push(row); } return o; }
  setValues(v) { if (v.length !== this.nr || v[0].length !== this.nc) throw new Error('dimension'); for (let i = 0; i < this.nr; i++) { const R = this.r - 1 + i; while (this.sh.d.length <= R) this.sh.d.push([]); for (let j = 0; j < this.nc; j++) { const x = v[i][j]; if (typeof x === 'string' && /^[=+]/.test(x)) throw new Error('FORMULE: ' + x); this.sh.d[R][this.c - 1 + j] = x; } } return this; }
  setNumberFormat() { return this; } setFontWeight() { return this; }
  clearContent() { for (let i = 0; i < this.nr; i++) { const R = this.r - 1 + i; if (this.sh.d[R]) for (let j = 0; j < this.nc; j++) this.sh.d[R][this.c - 1 + j] = ''; } return this; }
  getSheet() { return this.sh; } getRow() { return this.r; } getNumRows() { return this.nr; }
}
class Sheet {
  constructor(n) { this.n = n; this.d = []; this.maxR = 1000; this.maxC = 26; }
  getName() { return this.n; }
  getLastRow() { for (let i = this.d.length; i > 0; i--) if ((this.d[i - 1] || []).some(x => x !== '' && x != null)) return i; return 0; }
  getLastColumn() { let m = 0; for (const r of this.d) for (let j = r.length; j > 0; j--) if (r[j - 1] !== '' && r[j - 1] != null) { m = Math.max(m, j); break; } return m; }
  getMaxRows() { return this.maxR; } getMaxColumns() { return this.maxC; }
  insertRowsAfter(a, n) { this.maxR += n; } insertColumnsAfter(a, n) { this.maxC += n; }
  getRange(r, c, nr, nc) { return new Range(this, r, c, nr, nc); } setFrozenRows() {}
}
const sheets = {}, props = { TOKEN: 'un-jeton-secret-tres-long-0123456789' };
const ctx = {
  SpreadsheetApp: { getActiveSpreadsheet: () => ({ getSheetByName: n => sheets[n] || null, insertSheet: n => (sheets[n] = new Sheet(n)) }) },
  PropertiesService: { getScriptProperties: () => ({ getProperty: k => props[k] ?? null, setProperty: (k, v) => { props[k] = v; }, deleteProperty: k => { delete props[k]; } }) },
  LockService: { getScriptLock: () => ({ waitLock() {}, releaseLock() {} }) },
  ContentService: { MimeType: { JSON: 'j' }, createTextOutput: t => ({ t, setMimeType() { return this; } }) },
  Utilities: { DigestAlgorithm: { SHA_256: 1 }, computeDigest: (a, s) => crypto.createHash('sha256').update(s).digest(), base64Encode: b => Buffer.from(b).toString('base64'), sleep() {} },
};
vm.createContext(ctx); vm.runInContext(code, ctx);
const post = b => JSON.parse(ctx.doPost({ postData: { contents: JSON.stringify(b) } }).t);
const T = props.TOKEN, ok = (c, m) => { if (!c) { console.error('ECHEC:', m); process.exitCode = 1; } else console.log('ok  ', m); };
const P = (uuid, nom, maj, x = {}) => ({ uuid, nom, date_peremption: '2026-12-01', quantite: 1, date_ajout: '2026-11-01', updated_at: maj, ...x });

ok(JSON.parse(ctx.doGet({}).t).service === 'frigo-malin', 'doGet');
ok(post({ token: 'faux', action: 'sync' }).ok === false, 'jeton faux refusé');
ok(post({ action: 'sync' }).ok === false, 'jeton absent refusé');
// Scénario : B modifie à 10:00 hors-ligne, A synchronise à 10:05, B synchronise à 10:10
let a = post({ token: T, action: 'sync', cursor: 0, produits: [P('a1', 'Lait de A', '2026-11-10T10:05:00.000Z')] });
ok(a.ok && a.cursor === 1 && a.produits.length === 1, 'A pousse, curseur=1');
let b = post({ token: T, action: 'sync', cursor: 0, produits: [P('b1', 'Yaourt de B', '2026-11-10T10:00:00.000Z')] });
ok(b.produits.length === 2 && b.cursor === 2, 'B reçoit tout');
let a2 = post({ token: T, action: 'sync', cursor: a.cursor });
ok(a2.produits.length === 1 && a2.produits[0].nom === 'Yaourt de B', 'A reçoit la modification ancienne de B (bug C1 corrigé)');
// chemin rapide
const nb = sheets.Stock.d.length; let r = post({ token: T, action: 'sync', cursor: 2 });
ok(r.ok && r.cursor === 2 && r.produits.length === 0 && r.courses.length === 0, 'chemin rapide');
// LWW
r = post({ token: T, action: 'sync', cursor: 2, produits: [P('a1', 'Vieux', '2026-11-10T09:00:00.000Z')] });
ok(r.cursor === 2 && r.produits.length === 0, 'écriture plus ancienne ignorée');
r = post({ token: T, action: 'sync', cursor: 2, produits: [P('a1', 'Lait bio', '2026-11-10T11:00:00.000Z', { deleted_at: '2026-11-10T11:00:00.000Z' })] });
ok(r.cursor === 3 && r.produits[0].deleted_at, 'suppression plus récente acceptée');
ok(sheets.Stock.getLastRow() === 3, 'pas de doublon de ligne');
// formules
r = post({ token: T, action: 'sync', cursor: 3, produits: [P('f1', '=IMPORTXML("http://x")', '2026-11-10T12:00:00.000Z')], courses: [{ uuid: 'c1', nom: '+Farine', fait: 0, updated_at: '2026-11-10T12:00:00.000Z' }] });
ok(r.produits[0].nom === 'IMPORTXML("http://x")' && r.courses[0].nom === 'Farine', 'formules neutralisées');
// code-barres avec zéros, texte
r = post({ token: T, action: 'sync', cursor: r.cursor, catalogue: [{ code_barres: '0012345678905', nom: 'Soda', source: 'off', updated_at: '2026-11-10T12:00:00.000Z' }] });
ok(r.catalogue[0].code_barres === '0012345678905', 'code-barres conservé en texte');
// édition manuelle : onEdit efface seq
const st = sheets.Stock, h = st.d[0]; const iNom = h.indexOf('nom'), iSeq = h.indexOf('seq');
st.d[2][iNom] = 'Yaourt corrigé'; const cur = r.cursor;
ctx.onEdit({ range: new Range(st, 3, iNom + 1, 1, 1) });
ok(st.d[2][iSeq] === '' && props.DIRTY === '1', 'onEdit efface seq et marque DIRTY');
r = post({ token: T, action: 'sync', cursor: cur });
ok(r.produits.length === 1 && r.produits[0].nom === 'Yaourt corrigé' && r.cursor === cur + 1, 'correction manuelle propagée');
// ligne ajoutée à la main sans updated_at
st.d.push(h.map(x => x === 'uuid' ? 'm1' : x === 'nom' ? 'Ajout manuel' : x === 'date_peremption' ? '2026-12-25' : ''));
r = post({ token: T, action: 'sync', cursor: r.cursor, complet: true });
ok(r.produits.length === 1 && r.produits[0].uuid === 'm1' && r.produits[0].updated_at, 'ligne manuelle numérotée au passage complet');
// purge
r = post({ token: T, action: 'sync', cursor: r.cursor, complet: true, produits: [P('old', 'Vieux', '2020-01-01T00:00:00.000Z', { deleted_at: '2020-01-01T00:00:00.000Z' })], historique: [{ uuid: 'h1', nom: 'x', issue: 'jete', date_peremption: '2020-01-01', date_action: '2020-01-01', updated_at: '2020-01-01T00:00:00.000Z' }] });
ok(!st.d.some(l => l[h.indexOf('uuid')] === 'old') && sheets.Historique.getLastRow() === 1, 'purge des vieilles lignes supprimées');
ok(st.d.filter(l => l[0]).length === st.getLastRow(), 'pas de trou dans la feuille');
// migration d'un Sheet v1 (sans colonnes auteur/seq)
delete sheets.Stock; delete props.SEQ; const v1 = sheets.Stock = new Sheet('Stock');
v1.d = [['uuid', 'code_barres', 'nom', 'date_peremption', 'quantite', 'categorie', 'date_ajout', 'updated_at', 'deleted_at'], ['x1', '', 'Ancien', '2026-12-01', '1', '', '2026-11-01', '2026-11-01T00:00:00.000Z', '']];
r = post({ token: T, action: 'sync', cursor: 0 });
ok(v1.d[0].includes('seq') && v1.d[0].includes('auteur') && r.produits.some(p => p.nom === 'Ancien'), 'migration d\'un Sheet v1');
