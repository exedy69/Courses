"""Vue Qt d'un schéma interactif : on survole et on clique composants et nets."""

from __future__ import annotations

from PySide6.QtCore import QByteArray, QPointF, QRectF, Qt, Signal
from PySide6.QtGui import QBrush, QColor, QFont, QPainter, QPainterPath, \
    QPainterPathStroker, QPen
from PySide6.QtSvg import QSvgRenderer
from PySide6.QtSvgWidgets import QGraphicsSvgItem
from PySide6.QtWidgets import QGraphicsEllipseItem, QGraphicsPathItem, \
    QGraphicsScene, QGraphicsSimpleTextItem, QGraphicsView

from . import schemas as sch
from .symboles import svg

ENCRE = "#202124"
GRIS = "#6b7280"
SURVOL = "#1a73e8"
JUSTE = "#188038"
FAUX = "#d93025"

GENRE, IDENT = 0, 1   # clés de QGraphicsItem.data()

# Zone cliquable d'un symbole, plus serrée que sa boîte de 120 × 100.
_ZONES = {"masse": QRectF(34, 12, 52, 58), "point_test": QRectF(44, 24, 32, 70)}
_ZONE_DEFAUT = QRectF(18, 14, 84, 72)


class ItemComposant(QGraphicsSvgItem):
    def __init__(self, comp: sch.Composant):
        super().__init__()
        self.comp = comp
        self._rendus = {}
        self.colorer(ENCRE)
        self.setTransformOriginPoint(60, 50)
        self.setRotation(comp.rotation)
        self.setPos(comp.x, comp.y)

    def colorer(self, couleur):
        if couleur not in self._rendus:
            code = svg(self.comp.symbole, couleur, self.comp.broches,
                       lettres=self.comp.rotation == 0)
            self._rendus[couleur] = QSvgRenderer(QByteArray(code.encode()))
        self.setSharedRenderer(self._rendus[couleur])

    def shape(self):
        chemin = QPainterPath()
        chemin.addRect(_ZONES.get(self.comp.symbole, _ZONE_DEFAUT))
        return chemin


class ItemNet(QGraphicsPathItem):
    def __init__(self, chemin: QPainterPath, epaisseur: float):
        super().__init__(chemin)
        self.epaisseur = epaisseur
        stroker = QPainterPathStroker()
        stroker.setWidth(14)
        self._zone = stroker.createStroke(chemin)
        self.colorer(ENCRE)

    def colorer(self, couleur):
        pen = QPen(QColor(couleur), self.epaisseur)
        pen.setCapStyle(Qt.RoundCap)
        pen.setJoinStyle(Qt.RoundJoin)
        self.setPen(pen)

    def shape(self):
        return self._zone


class _Texte(QGraphicsSimpleTextItem):
    def colorer(self, couleur):
        self.setBrush(QBrush(QColor(couleur)))


class _Point(QGraphicsEllipseItem):
    def colorer(self, couleur):
        self.setBrush(QBrush(QColor(couleur)))
        self.setPen(QPen(Qt.NoPen))


class VueSchema(QGraphicsView):
    """Affiche un schéma ; émet ``clique(genre, id)`` sur un clic."""

    clique = Signal(str, str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setScene(QGraphicsScene(self))
        self.setRenderHints(QPainter.Antialiasing | QPainter.TextAntialiasing
                            | QPainter.SmoothPixmapTransform)
        self.setBackgroundBrush(QColor("#ffffff"))
        self.setMouseTracking(True)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.schema = None
        self.actif = True
        self._groupes = {}     # (genre, id) → [items]
        self._fixes = {}       # couleurs posées par la correction
        self._survol = None

    # -- construction --------------------------------------------------------

    def charger(self, schema: sch.Schema):
        scene = self.scene()
        scene.clear()
        self._groupes, self._fixes, self._survol = {}, {}, None
        self.schema = schema
        scene.setSceneRect(0, 0, schema.largeur, schema.hauteur)

        titre = QGraphicsSimpleTextItem(schema.titre)
        titre.setFont(QFont("sans-serif", 10))
        titre.setBrush(QBrush(QColor(GRIS)))
        titre.setPos(schema.largeur - titre.boundingRect().width() - 8,
                     schema.hauteur - 22)
        scene.addItem(titre)

        police = QFont("sans-serif", 9)
        for comp in schema.composants:
            item = ItemComposant(comp)
            self._ajouter(item, "composant", comp.ref, z=1)
            if comp.symbole == "masse":
                continue
            texte = _Texte("\n".join(t for t in (comp.ref, comp.valeur) if t))
            texte.setFont(police)
            texte.setPos(comp.x + comp.etiquette[0], comp.y + comp.etiquette[1])
            self._ajouter(texte, "composant", comp.ref, z=3)

        police_net = QFont("monospace", 9)
        police_net.setStyleHint(QFont.Monospace)
        police_net.setBold(True)
        police_pages = QFont("sans-serif", 8)
        for net in schema.nets:
            chemin = QPainterPath()
            for seg in sch.polylignes(schema, net):
                chemin.moveTo(QPointF(*seg[0]))
                for p in seg[1:]:
                    chemin.lineTo(QPointF(*p))
            self._ajouter(ItemNet(chemin, 3.5 if net.est_rail else 2.2),
                          "net", net.nom, z=2)
            for (x, y) in net.jonctions:
                self._ajouter(_Point(x - 4, y - 4, 8, 8), "net", net.nom, z=2)
            if net.etiquette:
                nom = _Texte(net.nom)
                nom.setFont(police_net)
                h = nom.boundingRect().height()
                x, y = net.etiquette
                nom.setPos(x, y - h)
                self._ajouter(nom, "net", net.nom, z=3)
                if net.pages:
                    pages = _Texte(net.pages)
                    pages.setFont(police_pages)
                    pages.setPos(x + nom.boundingRect().width() + 6,
                                 y - pages.boundingRect().height())
                    pages.colorer(GRIS)
                    scene.addItem(pages)
        self._recolorer()
        self.ajuster()

    def _ajouter(self, item, genre, ident, z):
        item.setData(GENRE, genre)
        item.setData(IDENT, ident)
        item.setZValue(z)
        self.scene().addItem(item)
        self._groupes.setdefault((genre, ident), []).append(item)

    # -- couleurs ------------------------------------------------------------

    def _couleur(self, cle):
        if cle in self._fixes:
            return self._fixes[cle]
        if cle == self._survol and self.actif:
            return SURVOL
        return ENCRE

    def _recolorer(self):
        for cle, items in self._groupes.items():
            couleur = self._couleur(cle)
            for it in items:
                it.colorer(couleur)

    def marquer(self, genre, ident, couleur):
        self._fixes[(genre, ident)] = couleur
        self._recolorer()

    def reinitialiser(self):
        self._fixes = {}
        self._survol = None
        self.actif = True
        self._recolorer()

    # -- interaction ---------------------------------------------------------

    def cle_sous(self, pos_vue):
        """(genre, id) de l'élément sous ce point de la vue, ou None."""
        for item in self.items(pos_vue):
            genre = item.data(GENRE)
            if genre:
                return (genre, item.data(IDENT))
        return None

    def mouseMoveEvent(self, ev):
        cle = self.cle_sous(ev.position().toPoint()) if self.actif else None
        if cle != self._survol:
            self._survol = cle
            self.viewport().setCursor(Qt.PointingHandCursor if cle
                                      else Qt.ArrowCursor)
            self._recolorer()
        super().mouseMoveEvent(ev)

    def mousePressEvent(self, ev):
        if self.actif and ev.button() == Qt.LeftButton:
            cle = self.cle_sous(ev.position().toPoint())
            if cle:
                self.clique.emit(*cle)
                return
        super().mousePressEvent(ev)

    def ajuster(self):
        if self.schema:
            self.fitInView(self.scene().sceneRect(), Qt.KeepAspectRatio)

    def resizeEvent(self, ev):
        super().resizeEvent(ev)
        self.ajuster()

    def showEvent(self, ev):
        super().showEvent(ev)
        self.ajuster()
