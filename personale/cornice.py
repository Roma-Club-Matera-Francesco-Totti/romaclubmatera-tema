#!/usr/bin/env python3
"""Icone del pacchetto personale: l'icona originale di un'app, ritagliata a
cerchio, dentro il tondo rosso con il filetto oro delle icone del Club.

Uso: personale/cornice.py <cartella icone originali> <cartella di uscita> [lato]
Le icone originali le esporta l'app Tema RCM sul telefono (extra
"esporta_icone", vedi genera.sh); contengono loghi di terzi: restano sul PC
in personale/locale/ (fuori da git) e finiscono solo nel pacchetto personale.
"""
import os, sys
from PIL import Image, ImageDraw, ImageFilter

LATO = 192
S = 4  # disegno a 4x e poi riduco: bordi lisci


def cornice(orig):
    L = LATO * S
    c = L / 2
    im = Image.new('RGBA', (L, L), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # tondo rosso con il chiaroscuro di FONDO (icone/genera.py): gradiente radiale
    # centrato un po' in alto, dal rosso chiaro al porpora scuro
    R = 92 / 96 * c
    yy, xx = [v.astype(float) for v in __import__('numpy').mgrid[0:L, 0:L]]
    np = __import__('numpy')
    t = np.clip(np.hypot(xx - c, yy - .76 * c) / (1.4 * c), 0, 1)
    rgb = np.stack([0xa8 + (0x5a - 0xa8) * t, 0x22 + (0x0f - 0x22) * t, 0x34 + (0x19 - 0x34) * t], -1).astype('uint8')
    disco = Image.new('L', (L, L), 0)
    ImageDraw.Draw(disco).ellipse((c - R, c - R, c + R, c + R), fill=255)
    im.paste(Image.fromarray(rgb, 'RGB').convert('RGBA'), (0, 0), disco)
    # l'icona originale, a cerchio
    ri = 72 / 96 * c
    o = orig.convert('RGBA').resize((round(2 * ri), round(2 * ri)), Image.LANCZOS)
    m = Image.new('L', o.size, 0)
    ImageDraw.Draw(m).ellipse((0, 0, o.size[0] - 1, o.size[1] - 1), fill=255)
    m = Image.composite(m, Image.new('L', o.size, 0), o.split()[3].point(lambda v: 255 if v > 0 else 0))
    sotto = Image.new('RGBA', o.size, (0xf6, 0xec, 0xd0, 255))  # icone trasparenti: fondo panna
    sotto.alpha_composite(o)
    im.paste(sotto, (round(c - ri), round(c - ri)), m)
    # filetto oro sopra il bordo dell'icona
    for w, col in ((5.5, (0xb8, 0x86, 0x1a)), (3.5, (0xe3, 0xad, 0x1e)), (1.2, (0xf6, 0xcf, 0x5a))):
        rr = 78 / 96 * c
        d.ellipse((c - rr, c - rr, c + rr, c + rr), outline=col + (255,), width=round(w * S))
    return im.resize((LATO, LATO), Image.LANCZOS)


def main():
    global LATO
    src, out = sys.argv[1], sys.argv[2]
    if len(sys.argv) > 3:
        LATO = int(sys.argv[3])
    os.makedirs(out, exist_ok=True)
    for f in sorted(os.listdir(src)):
        if f.endswith('.png'):
            cornice(Image.open(os.path.join(src, f))).save(os.path.join(out, f))


if __name__ == '__main__':
    main()
