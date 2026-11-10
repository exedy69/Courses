/**
 * Frigo Malin — Application web Google Apps Script (synchronisation facultative).
 *
 * Installation : voir README.md (section « Synchronisation Google Sheets »).
 * Propriété de script à définir : TOKEN (valeur aléatoire longue, 32 caractères ou plus).
 *
 * Protocole (version 2) :
 *   POST JSON { token, action:'sync', v:2, cursor, complet, produits[], catalogue[], historique[], courses[] }
 *   Réponse   { ok:true, cursor, produits[], catalogue[], historique[], courses[] }
 *
 * Chaque écriture acceptée reçoit un numéro croissant (colonne « seq ») attribué par le
 * serveur. Un téléphone demande « tout ce qui a un seq plus grand que mon curseur » :
 * l'ordre ne dépend donc plus de l'horloge des téléphones, et aucun changement n'est perdu
 * quand plusieurs téléphones se synchronisent.
 */

var JOURS_PURGE = 90;

var TABLES = {
  produits: {
    onglet: 'Stock',
    cle: 'uuid',
    colonnes: ['uuid', 'code_barres', 'nom', 'date_peremption', 'quantite', 'categorie', 'date_ajout', 'auteur', 'updated_at', 'deleted_at', 'seq'],
    purge: 'deleted_at'
  },
  catalogue: {
    onglet: 'Catalogue',
    cle: 'code_barres',
    colonnes: ['code_barres', 'nom', 'marque', 'categorie', 'image_url', 'source', 'duree_habituelle_jours', 'updated_at', 'seq']
  },
  historique: {
    onglet: 'Historique',
    cle: 'uuid',
    colonnes: ['uuid', 'nom', 'issue', 'date_peremption', 'date_action', 'updated_at', 'deleted_at', 'seq'],
    purge: 'deleted_at',
    purgeDate: 'date_action'
  },
  courses: {
    onglet: 'Courses',
    cle: 'uuid',
    colonnes: ['uuid', 'nom', 'fait', 'auteur', 'updated_at', 'deleted_at', 'seq'],
    purge: 'deleted_at'
  }
};
var NOMS = ['produits', 'catalogue', 'historique', 'courses'];

function reponse_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

function empreinte_(texte) {
  return Utilities.base64Encode(Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, String(texte)));
}

/** Compare les empreintes (et non les jetons) pour ne rien révéler par le temps de réponse. */
function tokenValide_(token) {
  var attendu = PropertiesService.getScriptProperties().getProperty('TOKEN');
  if (!attendu || attendu.length < 16 || typeof token !== 'string') return false;
  return empreinte_(token) === empreinte_(attendu);
}

function doGet(e) {
  return reponse_({ ok: true, service: 'frigo-malin', v: 2 });
}

function doPost(e) {
  var corps;
  try {
    corps = JSON.parse(e.postData.contents);
  } catch (err) {
    return reponse_({ ok: false, error: 'requete' });
  }
  if (!tokenValide_(corps.token)) {
    // Ralentit les essais de jetons au hasard.
    Utilities.sleep(1500);
    return reponse_({ ok: false });
  }
  if (corps.action !== 'sync') {
    return reponse_({ ok: false, error: 'action' });
  }

  var props = PropertiesService.getScriptProperties();
  var curseur = Number(corps.cursor) || 0;
  var aRecu = false;
  for (var i = 0; i < NOMS.length; i++) {
    if (corps[NOMS[i]] && corps[NOMS[i]].length) aRecu = true;
  }

  // Chemin rapide : rien à écrire, rien de nouveau à lire. Aucune feuille n'est ouverte.
  // (Jamais avant le premier passage complet : SEQ n'existe pas encore.)
  var seqBrut = props.getProperty('SEQ');
  var seqActuel = Number(seqBrut) || 0;
  if (seqBrut !== null && !aRecu && !corps.complet && props.getProperty('DIRTY') !== '1' && curseur === seqActuel) {
    var vide = { ok: true, cursor: seqActuel };
    for (var j = 0; j < NOMS.length; j++) vide[NOMS[j]] = [];
    return reponse_(vide);
  }

  var verrou = LockService.getScriptLock();
  verrou.waitLock(30000);
  try {
    var etat = { seq: Number(props.getProperty('SEQ')) || 0 };
    var sortie = { ok: true };
    for (var k = 0; k < NOMS.length; k++) {
      var nom = NOMS[k];
      sortie[nom] = traiterTable_(TABLES[nom], corps[nom] || [], curseur, etat, !!corps.complet);
    }
    props.setProperty('SEQ', String(etat.seq));
    props.deleteProperty('DIRTY');
    sortie.cursor = etat.seq;
    return reponse_(sortie);
  } finally {
    verrou.releaseLock();
  }
}

/** Texte brut ; neutralise ce qui serait interprété comme une formule. */
function texte_(v) {
  if (v === null || v === undefined) return '';
  if (v instanceof Date) return v.toISOString();
  return String(v).replace(/^[=+\-@\t\r\n\s]+/, '');
}

/**
 * Retourne l'onglet (créé au besoin) et la position de chaque colonne d'après la ligne
 * d'en-tête. Les colonnes manquantes sont ajoutées à droite ; l'ordre est libre.
 */
function feuille_(def) {
  var classeur = SpreadsheetApp.getActiveSpreadsheet();
  var f = classeur.getSheetByName(def.onglet);
  if (!f) f = classeur.insertSheet(def.onglet);
  var nbCol = f.getLastColumn();
  var entetes = nbCol > 0 ? f.getRange(1, 1, 1, nbCol).getValues()[0].map(String) : [];
  var position = {};
  for (var i = 0; i < entetes.length; i++) {
    if (entetes[i]) position[entetes[i]] = i;
  }
  var ajoutees = false;
  for (var c = 0; c < def.colonnes.length; c++) {
    if (!position.hasOwnProperty(def.colonnes[c])) {
      position[def.colonnes[c]] = entetes.length;
      entetes.push(def.colonnes[c]);
      ajoutees = true;
    }
  }
  if (ajoutees) {
    if (f.getMaxColumns() < entetes.length) {
      f.insertColumnsAfter(f.getMaxColumns(), entetes.length - f.getMaxColumns());
    }
    f.getRange(1, 1, 1, entetes.length).setValues([entetes]).setFontWeight('bold');
    f.setFrozenRows(1);
    // Tout en texte (@) : Sheets ne doit convertir ni les dates ni les codes-barres.
    f.getRange(1, 1, f.getMaxRows(), entetes.length).setNumberFormat('@');
  }
  return { feuille: f, position: position, nbCol: entetes.length };
}

/** Upsert des lignes reçues, numérotation, purge, puis lecture de ce qui dépasse le curseur. */
function traiterTable_(def, recues, curseur, etat, complet) {
  var info = feuille_(def);
  var f = info.feuille;
  var pos = info.position;
  var nbCol = info.nbCol;
  var derniere = f.getLastRow();
  var lignes = derniere > 1 ? f.getRange(2, 1, derniere - 1, nbCol).getValues() : [];
  var modifie = false;

  var index = {};
  for (var i = 0; i < lignes.length; i++) {
    var cleExistante = texte_(lignes[i][pos[def.cle]]);
    if (cleExistante) index[cleExistante] = i;
  }

  // 1. Lignes reçues : la dernière écriture gagne (comparaison des dates ISO en texte).
  for (var r = 0; r < recues.length; r++) {
    var l = recues[r];
    var cle = texte_(l[def.cle]);
    var maj = texte_(l.updated_at);
    if (!cle || !maj) continue;
    var cible;
    if (index.hasOwnProperty(cle)) {
      cible = lignes[index[cle]];
      if (!(maj > texte_(cible[pos.updated_at]))) continue;
    } else {
      cible = [];
      for (var z = 0; z < nbCol; z++) cible.push('');
      index[cle] = lignes.length;
      lignes.push(cible);
    }
    for (var c = 0; c < def.colonnes.length; c++) {
      var col = def.colonnes[c];
      if (col === 'seq') continue;
      cible[pos[col]] = texte_(l[col]);
    }
    etat.seq++;
    cible[pos.seq] = String(etat.seq);
    modifie = true;
  }

  // 2. Lignes sans numéro : ajoutées ou corrigées à la main dans le Sheet (voir onEdit).
  var maintenant = new Date().toISOString();
  for (var n = 0; n < lignes.length; n++) {
    var ligne = lignes[n];
    if (!texte_(ligne[pos[def.cle]])) continue;
    if (texte_(ligne[pos.seq]) === '') {
      if (texte_(ligne[pos.updated_at]) === '') ligne[pos.updated_at] = maintenant;
      etat.seq++;
      ligne[pos.seq] = String(etat.seq);
      modifie = true;
    }
  }

  // 3. Purge des lignes supprimées (et de l'historique) de plus de JOURS_PURGE jours.
  if (complet && def.purge) {
    var limite = new Date(Date.now() - JOURS_PURGE * 86400000).toISOString();
    var gardees = [];
    for (var g = 0; g < lignes.length; g++) {
      var supprimeLe = texte_(lignes[g][pos[def.purge]]);
      var dateAction = def.purgeDate ? texte_(lignes[g][pos[def.purgeDate]]) : '';
      var perime = (supprimeLe !== '' && supprimeLe < limite) ||
          (dateAction !== '' && dateAction < limite.substring(0, 10));
      if (!perime) gardees.push(lignes[g]);
    }
    if (gardees.length !== lignes.length) {
      lignes = gardees;
      modifie = true;
    }
  }

  // 4. Une seule écriture groupée.
  if (modifie) {
    if (derniere > 1) f.getRange(2, 1, derniere - 1, nbCol).clearContent();
    if (lignes.length) {
      if (f.getMaxRows() < lignes.length + 1) {
        f.insertRowsAfter(f.getMaxRows(), lignes.length + 1 - f.getMaxRows());
      }
      var texteSeul = lignes.map(function (li) { return li.map(texte_); });
      f.getRange(2, 1, lignes.length, nbCol).setNumberFormat('@').setValues(texteSeul);
    }
  }

  // 5. Ce que le téléphone n'a pas encore vu.
  var sortie = [];
  for (var s = 0; s < lignes.length; s++) {
    var seq = Number(texte_(lignes[s][pos.seq])) || 0;
    if (seq <= curseur) continue;
    var objet = {};
    for (var d = 0; d < def.colonnes.length; d++) {
      var nomCol = def.colonnes[d];
      if (nomCol === 'seq') continue;
      var v = texte_(lignes[s][pos[nomCol]]);
      objet[nomCol] = v === '' ? null : v;
    }
    sortie.push(objet);
  }
  return sortie;
}

/**
 * Déclencheur simple : quand une ligne est modifiée à la main, on met à jour updated_at
 * et on efface son numéro « seq ». Le serveur lui en redonnera un à la prochaine synchro,
 * et la correction partira vers les téléphones.
 */
function onEdit(e) {
  if (!e || !e.range) return;
  var feuille = e.range.getSheet();
  var def = null;
  for (var nom in TABLES) {
    if (TABLES[nom].onglet === feuille.getName()) def = TABLES[nom];
  }
  if (!def) return;
  var debut = e.range.getRow();
  var nb = e.range.getNumRows();
  if (debut < 2) {
    debut = 2;
    nb = nb - 1;
  }
  if (nb < 1) return;
  var entetes = feuille.getRange(1, 1, 1, feuille.getLastColumn()).getValues()[0].map(String);
  var colMaj = entetes.indexOf('updated_at') + 1;
  var colSeq = entetes.indexOf('seq') + 1;
  if (colMaj < 1 || colSeq < 1) return;
  var maintenant = new Date().toISOString();
  var dates = [];
  var vides = [];
  for (var i = 0; i < nb; i++) {
    dates.push([maintenant]);
    vides.push(['']);
  }
  feuille.getRange(debut, colMaj, nb, 1).setNumberFormat('@').setValues(dates);
  feuille.getRange(debut, colSeq, nb, 1).setValues(vides);
  try {
    PropertiesService.getScriptProperties().setProperty('DIRTY', '1');
  } catch (err) {
    // Sans cette marque, la correction partira au prochain passage complet.
  }
}
