/**
 * Frigo Malin — Application web Google Apps Script (synchronisation facultative).
 *
 * Installation : voir README.md (section « Synchronisation Google Sheets »).
 * Propriété de script à définir : TOKEN (valeur aléatoire longue).
 *
 * Protocole : POST JSON { token, action:'sync', since, produits[], catalogue[], historique[] }
 * Réponse   : { ok:true, serverTime, produits[], catalogue[], historique[] }
 * Les lignes renvoyées sont celles dont updated_at > since (suppressions logiques incluses).
 */

var TABLES = {
  produits: {
    onglet: 'Stock',
    cle: 'uuid',
    colonnes: ['uuid', 'code_barres', 'nom', 'date_peremption', 'quantite', 'categorie', 'date_ajout', 'updated_at', 'deleted_at'],
    texte: ['uuid', 'code_barres', 'date_peremption', 'date_ajout', 'updated_at', 'deleted_at']
  },
  catalogue: {
    onglet: 'Catalogue',
    cle: 'code_barres',
    colonnes: ['code_barres', 'nom', 'marque', 'categorie', 'image_url', 'source', 'duree_habituelle_jours', 'updated_at'],
    texte: ['code_barres', 'updated_at']
  },
  historique: {
    onglet: 'Historique',
    cle: 'uuid',
    colonnes: ['uuid', 'nom', 'issue', 'date_peremption', 'date_action', 'updated_at'],
    texte: ['uuid', 'date_peremption', 'date_action', 'updated_at']
  }
};

function reponse_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

function tokenValide_(token) {
  var attendu = PropertiesService.getScriptProperties().getProperty('TOKEN');
  return !!attendu && typeof token === 'string' && token === attendu;
}

function doGet(e) {
  return reponse_({ ok: true, service: 'frigo-malin' });
}

function doPost(e) {
  var corps;
  try {
    corps = JSON.parse(e.postData.contents);
  } catch (err) {
    return reponse_({ ok: false, error: 'requete' });
  }
  if (!tokenValide_(corps.token)) {
    return reponse_({ ok: false });
  }
  if (corps.action !== 'sync') {
    return reponse_({ ok: false, error: 'action' });
  }

  var verrou = LockService.getScriptLock();
  verrou.waitLock(30000);
  try {
    var since = corps.since || '';
    var sortie = { ok: true };
    var noms = ['produits', 'catalogue', 'historique'];
    for (var i = 0; i < noms.length; i++) {
      var nom = noms[i];
      var def = TABLES[nom];
      var feuille = feuille_(def);
      upsert_(feuille, def, corps[nom] || []);
      sortie[nom] = lignesDepuis_(feuille, def, since);
    }
    sortie.serverTime = new Date().toISOString();
    return reponse_(sortie);
  } finally {
    verrou.releaseLock();
  }
}

/** Retourne l'onglet, le crée avec en-tête figé et format texte si besoin. */
function feuille_(def) {
  var classeur = SpreadsheetApp.getActiveSpreadsheet();
  var f = classeur.getSheetByName(def.onglet);
  if (!f) {
    f = classeur.insertSheet(def.onglet);
  }
  if (f.getLastRow() === 0) {
    f.getRange(1, 1, 1, def.colonnes.length).setValues([def.colonnes]).setFontWeight('bold');
    f.setFrozenRows(1);
  }
  // Format texte (@) pour éviter que Sheets convertisse dates et codes-barres.
  for (var c = 0; c < def.colonnes.length; c++) {
    if (def.texte.indexOf(def.colonnes[c]) !== -1) {
      f.getRange(2, c + 1, Math.max(f.getMaxRows() - 1, 1), 1).setNumberFormat('@');
    }
  }
  return f;
}

function texte_(v) {
  if (v === null || v === undefined) return '';
  if (v instanceof Date) return v.toISOString();
  return String(v);
}

function upsert_(feuille, def, lignes) {
  if (!lignes.length) return;
  var nbCol = def.colonnes.length;
  var derniere = feuille.getLastRow();
  var existant = derniere > 1 ? feuille.getRange(2, 1, derniere - 1, nbCol).getValues() : [];
  var idxCle = def.colonnes.indexOf(def.cle);
  var idxMaj = def.colonnes.indexOf('updated_at');
  var position = {};
  for (var i = 0; i < existant.length; i++) {
    position[texte_(existant[i][idxCle])] = i;
  }
  var aAjouter = [];
  for (var k = 0; k < lignes.length; k++) {
    var l = lignes[k];
    var cle = texte_(l[def.cle]);
    if (!cle) continue;
    var valeurs = def.colonnes.map(function (c) { return texte_(l[c]); });
    if (position.hasOwnProperty(cle)) {
      var idx = position[cle];
      // Dernière écriture gagne (comparaison de chaînes ISO).
      if (texte_(l.updated_at) > texte_(existant[idx][idxMaj])) {
        existant[idx] = valeurs;
        feuille.getRange(idx + 2, 1, 1, nbCol).setNumberFormat('@').setValues([valeurs]);
      }
    } else {
      position[cle] = existant.length + aAjouter.length;
      aAjouter.push(valeurs);
    }
  }
  if (aAjouter.length) {
    var debut = feuille.getLastRow() + 1;
    feuille.getRange(debut, 1, aAjouter.length, nbCol).setNumberFormat('@').setValues(aAjouter);
  }
}

function lignesDepuis_(feuille, def, since) {
  var derniere = feuille.getLastRow();
  if (derniere < 2) return [];
  var valeurs = feuille.getRange(2, 1, derniere - 1, def.colonnes.length).getValues();
  var idxMaj = def.colonnes.indexOf('updated_at');
  var sortie = [];
  for (var i = 0; i < valeurs.length; i++) {
    var maj = texte_(valeurs[i][idxMaj]);
    if (!maj) continue;
    if (since && !(maj > since)) continue;
    var objet = {};
    for (var c = 0; c < def.colonnes.length; c++) {
      var v = texte_(valeurs[i][c]);
      objet[def.colonnes[c]] = v === '' ? null : v;
    }
    sortie.push(objet);
  }
  return sortie;
}

/**
 * Déclencheur simple : met à jour updated_at quand une ligne est modifiée à la main,
 * pour que la correction se propage vers le téléphone.
 */
function onEdit(e) {
  if (!e || !e.range) return;
  var feuille = e.range.getSheet();
  var def = null;
  for (var nom in TABLES) {
    if (TABLES[nom].onglet === feuille.getName()) def = TABLES[nom];
  }
  if (!def) return;
  var idxMaj = def.colonnes.indexOf('updated_at') + 1;
  var debut = e.range.getRow();
  if (debut < 2) return;
  var nb = e.range.getNumRows();
  var maintenant = new Date().toISOString();
  for (var r = 0; r < nb; r++) {
    // Ne pas boucler si l'édition porte sur la colonne updated_at elle-même.
    if (e.range.getColumn() <= idxMaj && e.range.getLastColumn() >= idxMaj && e.range.getNumColumns() === 1) return;
    var cellule = feuille.getRange(debut + r, idxMaj);
    cellule.setNumberFormat('@').setValue(maintenant);
  }
}
