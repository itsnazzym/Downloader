"""Textes anglais restés dans les captures de l'appli : on les remplace par leur équivalent français.

Chaque correction cible une zone de la capture brute (px du fichier 1170 px de large). On repère le texte
dans la zone, on repeint le fond (couleur médiane du pourtour) et on réécrit le texte en Inter,
même position, même couleur, taille calée sur le texte d'origine.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/opentype/inter/Inter-Medium.otf"
BODY = "/usr/share/fonts/opentype/inter/Inter-Regular.otf"     # texte courant gris des cartes
NAV = {"Library": "Biblio", "Browse": "Web", "Send": "Envoi", "Settings": "Réglages"}
NAV_Y = (2290, 2360)


def _nav(centers: dict[str, int]) -> list:
    return [((c - 100, NAV_Y[0], c + 100, NAV_Y[1]), old, NAV[old], "center") for old, c in centers.items()]


# clé de capture → [(zone (x0, y0, x1, y1), ancien texte, nouveau texte, alignement)]
PATCHES: dict[str, list] = {
    "share": [((175, 1433, 995, 1510), "Your download list is empty.", "Ta liste de téléchargements est vide.", "center"),
              *_nav({"Library": 211, "Settings": 959})],
    "done": [((70, 780, 600, 850), "Extracting title…", "Extraction du titre…", "left"),
             ((320, 1255, 700, 1315), "Extracting title…", "Extraction du titre…", "left"),
             ((320, 1322, 720, 1372), "YouTube, Extracting", "YouTube, Extraction", "left"),
             ((320, 1548, 700, 1600), "Web, 770.0 KB", "Web, 770,0 Ko", "left"),
             *_nav({"Library": 211, "Settings": 959})],
    "library": [((330, 560, 700, 612), "Web, 235.0 MB", "Web, 235,0 Mo", "left"),
                ((330, 785, 700, 838), "Web, 770.0 KB", "Web, 770,0 Ko", "left")],
    "send": [((90, 1420, 385, 1495), "Scan network", "Scanner", "center"),
             ((440, 1420, 875, 1495), "Direct IP Connection", "IP directe", "center"),
             ((85, 1595, 990, 1665), "No device yet — scan the QR on your phone.",
              "Aucun appareil — scanne le QR code.", "left"),
             ((95, 1815, 440, 1890), "What to send", "Quoi envoyer", "left"),
             ((140, 1955, 395, 2015), "Entire library", "Toute la biblio", "center"),
             ((255, 2125, 660, 2157), "Search a creator…", "", "erase"),  # champ coupé par la barre : on l'efface
             *_nav({"Library": 137, "Browse": 360, "Send": 810, "Settings": 1035})],
    # l'appli s'appelle désormais TapLoad : seul le nom change, la suite de la ligne est recollée telle quelle
    "archive": [((110, 1340, 1060, 1395), "Modern Downloader|est installée, puis reviens", "TapLoad", "reflow"),
                *_nav({"Library": 137, "Browse": 360, "Send": 810, "Settings": 1035})],
    "stats": [((150, 125, 460, 220), "Statistics", "Statistiques", "left"),
              ((55, 2090, 360, 2152), "Free Space", "Espace libre", "left"),
              ((920, 2090, 1080, 2152), "8.3 GB", "8,3 Go", "left"),
              *_nav({"Library": 137, "Browse": 360, "Send": 810, "Settings": 1035})],
    "settings": _nav({"Library": 211, "Settings": 959}),
}


def _swap(img: Image.Image, box, old: str, new: str, align: str) -> None:
    arr = np.asarray(img).astype(int)
    x0, y0, x1, y1 = box
    if align == "erase":
        top = arr[y0, x0:x1]
        ImageDraw.Draw(img).rectangle((x0, y0, x1, y1), fill=tuple(int(v) for v in np.median(top, axis=0)))
        return
    reg = arr[y0:y1, x0:x1]
    bg = np.median(np.concatenate([reg[0], reg[-1], reg[:, 0], reg[:, -1]]), axis=0)
    ys, xs = np.nonzero(np.abs(reg - bg).max(axis=2) > 45)
    if len(xs) == 0:
        raise ValueError(f"aucun texte trouvé pour « {old} » dans {box}")
    bx0, bx1, by0, by1 = xs.min(), xs.max(), ys.min(), ys.max()
    if bx0 == 0 or by0 == 0 or bx1 == reg.shape[1] - 1 or by1 == reg.shape[0] - 1:
        raise ValueError(f"zone trop serrée pour « {old} » dans {box}")
    sub = reg[by0:by1 + 1, bx0:bx1 + 1].reshape(-1, 3)
    order = np.argsort(sub.sum(axis=1))
    colour = tuple(int(v) for v in np.median(sub[order[-max(3, len(order) // 40):]], axis=0))
    if align == "reflow":
        _reflow(img, arr, (x0, y0), reg, bg, (bx0, by0, bx1, by1), old, new, colour)
        return

    f100 = ImageFont.truetype(FONT, 100)
    l, t, r, _ = f100.getbbox(old, anchor="ls")
    size = (bx1 - bx0 + 1) / (r - l) * 100               # même largeur que le texte d'origine
    baseline = by0 + (-t) * size / 100                    # même ligne de base
    font = ImageFont.truetype(FONT, max(8, round(size)))
    nl, _, nr, _ = font.getbbox(new, anchor="ls")
    if nr - nl > 1.1 * (bx1 - bx0 + 1):                   # plus long que l'ancien : on réduit
        font = ImageFont.truetype(FONT, max(8, round(size * 1.1 * (bx1 - bx0 + 1) / (nr - nl))))
        nl, _, nr, _ = font.getbbox(new, anchor="ls")

    d = ImageDraw.Draw(img)
    d.rectangle((x0 + bx0 - 4, y0 + by0 - 4, x0 + bx1 + 4, y0 + by1 + 4), fill=tuple(int(v) for v in bg))
    if not new:
        return
    if align == "center":
        d.text((x0 + (bx0 + bx1) / 2, baseline + y0), new, font=font, fill=colour, anchor="ms")
    else:
        d.text((x0 + bx0 - nl, baseline + y0), new, font=font, fill=colour, anchor="ls")


def _reflow(img, arr, org, reg, bg, ink_box, old: str, new: str, colour) -> None:
    """old = « mots remplacés|suite de la ligne » : les premiers mots deviennent new, la suite de la ligne
    (pixels d'origine) est recollée juste après, avec le même espace entre mots."""
    x0, y0 = org
    bx0, by0, bx1, by1 = ink_box
    gone, kept = (p.split() for p in old.split("|"))
    cols = (np.abs(reg - bg).max(axis=2) > 45).any(axis=0)
    words, start = [], None
    for i, c in enumerate(list(cols) + [False]):
        if c and start is None:
            start = i
        elif not c and start is not None:
            if words and start - words[-1][1] <= 10:      # simple interlettre : même mot
                words[-1] = (words[-1][0], i)
            else:
                words.append((start, i))
            start = None
    if len(words) != len(gone) + len(kept):
        raise ValueError(f"{len(words)} mots trouvés pour « {old} »")
    n = len(gone)
    rest0, rest1 = words[n][0], words[-1][1]
    space = words[n][0] - words[n - 1][1]
    # corps calé sur la hauteur de capitale du premier mot (colonnes du mot, sans jambage) ; interlettre
    # calé sur la largeur des mots remplacés
    ink = np.abs(reg[:, words[0][0]:words[0][1]] - bg).max(axis=2) > 45
    rows = np.nonzero(ink.any(axis=1))[0]
    top, bottom = rows.min(), rows.max()
    f100 = ImageFont.truetype(BODY, 100)
    cap = -f100.getbbox(gone[0][0], anchor="ls")[1]
    font = ImageFont.truetype(BODY, max(8, round((bottom - top + 1) / cap * 100)))

    def ink_w(word, tr):
        l = font.getbbox(word[0], anchor="ls")[0]
        return sum(font.getlength(c) + tr for c in word[:-1]) + font.getbbox(word[-1], anchor="ls")[2] - l

    want = sum(b - a for a, b in words[:n])
    tr = (want - sum(ink_w(w, 0.0) for w in gone)) / sum(len(w) - 1 for w in gone)
    baseline = y0 + bottom + 1
    rest = arr[y0 + by0 - 4:y0 + by1 + 5, x0 + rest0:x0 + rest1].astype(np.uint8)
    d = ImageDraw.Draw(img)
    d.rectangle((x0 + bx0 - 4, y0 + by0 - 4, x0 + bx1 + 4, y0 + by1 + 4), fill=tuple(int(v) for v in bg))
    x = x0 + words[0][0] - font.getbbox(new[0], anchor="ls")[0]
    for c in new:
        d.text((x, baseline), c, font=font, fill=colour, anchor="ls")
        x += font.getlength(c) + tr
    end = x0 + words[0][0] + round(ink_w(new, tr))
    img.paste(Image.fromarray(rest), (end + space, y0 + by0 - 4))


def localize(key: str, img: Image.Image) -> Image.Image:
    for box, old, new, align in PATCHES.get(key, []):
        _swap(img, box, old, new, align)
    return img
