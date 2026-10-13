#!/usr/bin/env python3
"""Le immagini della scheda Play Store di Tema RCM, nel formato di fastlane
(fastlane/metadata/android/it-IT/images/).

- icon.png 512x512: lo stemma su rosso, come l'icona adattiva dell'app;
- featureGraphic.png 1024x500: Matera di notte con lo stemma e il nome;
- phoneScreenshots/: 1080x1920 (Google non accetta lati oltre il doppio
  dell'altro, e i 1080x2340 del telefono lo superano), con una riga di
  didascalia sopra la schermata.

Le schermate grezze stanno in play-store/schermate/ (telefono ed emulatore
come un S25, 1080x2340, senza dati personali). Sfondi solo di luoghi e colori: niente volti di
giocatori, che nello Store sono il primo motivo di rifiuto.

Uso: python3 play-store/genera.py
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

QUI = Path(__file__).resolve().parent
REPO = QUI.parent
ASSETS = REPO / 'app' / 'assets'
RES = REPO / 'app' / 'android' / 'app' / 'src' / 'main' / 'res'
OUT = REPO / 'fastlane' / 'metadata' / 'android' / 'it-IT' / 'images'

ROSSO = (125, 26, 40)  # rosso_club dell'icona
SCURO = (22, 6, 9)
ORO = (240, 188, 66)
PANNA = (245, 235, 215)


def carattere(nome, peso, dim):
    f = ImageFont.truetype(str(ASSETS / 'caratteri' / nome), dim)
    try:
        f.set_variation_by_axes([peso])
    except (OSError, AttributeError):
        pass
    return f


def icona():
    img = Image.new('RGBA', (512, 512), ROSSO + (255,))
    stemma = Image.open(RES / 'drawable-nodpi' / 'ic_primo_piano.png').convert('RGBA').resize((512, 512), Image.LANCZOS)
    img.alpha_composite(stemma)
    img.save(OUT / 'icon.png')


def copri(img, w, h):
    """Ritaglia al centro riempiendo w x h."""
    r = max(w / img.width, h / img.height)
    img = img.resize((round(img.width * r), round(img.height * r)), Image.LANCZOS)
    x, y = (img.width - w) // 2, (img.height - h) // 2
    return img.crop((x, y, x + w, y + h))


def sfumatura(w, h, dall_alto=True, forza=235):
    m = Image.linear_gradient('L').resize((w, h))
    if not dall_alto:
        m = m.transpose(Image.FLIP_TOP_BOTTOM)
    return m.point(lambda v: v * forza // 255)


def grafica():
    w, h = 1024, 500
    sf = Image.open(ASSETS / 'sfondi' / '11-sassi-di-notte.webp').convert('RGB')
    # la parte con la citta' illuminata, non il cielo
    sf = sf.crop((0, int(sf.height * .18), sf.width, int(sf.height * .18) + sf.width * h // w))
    img = copri(sf, w, h).convert('RGBA')
    velo = Image.new('RGBA', (w, h), SCURO + (0,))
    # scuro sotto le scritte, la citta' si vede a destra
    m = Image.linear_gradient('L').rotate(90, expand=True).resize((w, h)).point(lambda v: 120 + v * 115 // 255)
    velo.putalpha(m)
    img.alpha_composite(velo)
    stemma = Image.open(ASSETS / 'stemma.png').convert('RGBA')
    stemma = stemma.resize((round(stemma.width * 300 / stemma.height), 300), Image.LANCZOS)
    img.alpha_composite(stemma, (70, 100))
    d = ImageDraw.Draw(img)
    x = 70 + stemma.width + 50
    d.text((x, 140), 'TEMA RCM', font=carattere('Cinzel.ttf', 800, 74), fill=ORO)
    d.line((x, 240, x + 330, 240), fill=ORO, width=3)
    corpo = carattere('Oswald.ttf', 400, 34)
    d.text((x, 262), 'Sfondi, icone e Home', font=corpo, fill=PANNA)
    d.text((x, 306), 'del Roma Club Matera', font=corpo, fill=PANNA)
    img.convert('RGB').save(OUT / 'featureGraphic.png')


def a_capo(d, testo, font, larghezza):
    righe, riga = [], ''
    for p in testo.split():
        prova = (riga + ' ' + p).strip()
        if d.textlength(prova, font=font) <= larghezza:
            riga = prova
        else:
            righe.append(riga)
            riga = p
    return righe + [riga]


def schermata(n, didascalia, sorgente):
    w, h = 1080, 1920
    img = Image.new('RGB', (w, h), SCURO)
    # in alto un po' di rosso del Club che sfuma nel nero
    rosso = Image.new('RGB', (w, h), ROSSO)
    img.paste(rosso, (0, 0), sfumatura(w, h, dall_alto=False, forza=200))
    d = ImageDraw.Draw(img)
    f = carattere('Oswald.ttf', 600, 70)
    y = 90
    for r in a_capo(d, didascalia.upper(), f, w - 140):
        d.text((w // 2, y), r, font=f, fill=ORO, anchor='ma')
        y += 86
    # la schermata del telefono, tagliata sotto la barra di stato
    s = sorgente.convert('RGB')
    s = s.crop((0, 0, s.width, s.height - 140))  # via la barra dei pulsanti
    alta = h - y - 60
    r = alta / s.height
    s = s.resize((round(s.width * r), alta), Image.LANCZOS)
    x = (w - s.width) // 2
    maschera = Image.new('L', s.size, 0)
    ImageDraw.Draw(maschera).rounded_rectangle((0, 0, s.width - 1, s.height - 1), radius=44, fill=255)
    ombra = Image.new('L', (w, h), 0)
    ImageDraw.Draw(ombra).rounded_rectangle((x - 6, y + 34, x + s.width + 6, y + 40 + s.height), radius=50, fill=200)
    img.paste((0, 0, 0), (0, 0), ombra.filter(ImageFilter.GaussianBlur(24)))
    ImageDraw.Draw(img).rounded_rectangle((x - 5, y + 35, x + s.width + 4, y + 35 + s.height + 4), radius=48, outline=ORO, width=4)
    img.paste(s, (x, y + 37), maschera)
    img.save(OUT / 'phoneScreenshots' / f'{n}.png')


def sfondo_intero(n, didascalia, nomi):
    """Tre sfondi affiancati, come carte sul tavolo."""
    w, h = 1080, 1920
    img = Image.new('RGB', (w, h), SCURO)
    img.paste(Image.new('RGB', (w, h), ROSSO), (0, 0), sfumatura(w, h, dall_alto=False, forza=200))
    d = ImageDraw.Draw(img)
    f = carattere('Oswald.ttf', 600, 70)
    y = 90
    for r in a_capo(d, didascalia.upper(), f, w - 140):
        d.text((w // 2, y), r, font=f, fill=ORO, anchor='ma')
        y += 86
    base = img.convert('RGBA')
    for i, (nome, ang, dx) in enumerate(zip(nomi, (7, 0, -7), (-255, 0, 255))):
        sf = Image.open(ASSETS / 'sfondi' / nome).convert('RGB').resize((500, 1111), Image.LANCZOS)
        carta = Image.new('RGBA', (512, 1123), ORO + (255,))
        m = Image.new('L', (500, 1111), 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, 499, 1110), radius=40, fill=255)
        carta.paste(sf, (6, 6), m)
        mc = Image.new('L', carta.size, 0)
        ImageDraw.Draw(mc).rounded_rectangle((0, 0, carta.width - 1, carta.height - 1), radius=44, fill=255)
        carta.putalpha(mc)
        carta = carta.rotate(ang, resample=Image.BICUBIC, expand=True)
        cx = w // 2 + dx - carta.width // 2
        cy = y + 200
        if i == 1:
            continue
        base.alpha_composite(carta, (cx, cy))
    # quella di mezzo sopra le altre
    sf = Image.open(ASSETS / 'sfondi' / nomi[1]).convert('RGB').resize((600, 1333), Image.LANCZOS)
    carta = Image.new('RGBA', (612, 1345), ORO + (255,))
    m = Image.new('L', (600, 1333), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 599, 1332), radius=40, fill=255)
    carta.paste(sf, (6, 6), m)
    mc = Image.new('L', carta.size, 0)
    ImageDraw.Draw(mc).rounded_rectangle((0, 0, carta.width - 1, carta.height - 1), radius=44, fill=255)
    carta.putalpha(mc)
    base.alpha_composite(carta, ((w - carta.width) // 2, y + 90))
    base.convert('RGB').save(OUT / 'phoneScreenshots' / f'{n}.png')


def main():
    (OUT / 'phoneScreenshots').mkdir(parents=True, exist_ok=True)
    for f in (OUT / 'phoneScreenshots').glob('*.png'):
        f.unlink()
    icona()
    grafica()
    sc = QUI / 'schermate'
    schermata(1, 'I widget del Club sulla tua Home', Image.open(sc / 'home-widget.png'))
    schermata(2, 'Gli sfondi del Club in alta risoluzione', Image.open(sc / 'sfondi.png'))
    sfondo_intero(3, 'Matera e Roma, di giorno e di notte', ['06-colosseo.webp', '11-sassi-di-notte.webp', '07-olimpico-notte.webp'])
    schermata(4, 'Prossima partita e orologio, con un tocco', Image.open(sc / 'widget.png'))
    sfondo_intero(5, 'Roma e Matera in giallorosso', ['26-castel-santangelo.webp', '30-fontana-di-trevi.webp', '27-duomo-di-matera.webp'])
    schermata(6, 'E per chi vuole, le icone oro su rosso', Image.open(sc / 'icone.png'))
    print('fatto:', ', '.join(sorted(str(p.relative_to(OUT)) for p in OUT.rglob('*.png'))))


if __name__ == '__main__':
    main()
