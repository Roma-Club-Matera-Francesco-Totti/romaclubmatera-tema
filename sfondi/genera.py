#!/usr/bin/env python3
"""Sfondi per telefono (1440x3200) con lo stemma del Roma Club Matera.

Uso: [ORIGINALI=<cartella delle illustrazioni>] sfondi/genera.py [cartella di uscita]
     (default: ./sfondi-png; senza ORIGINALI si saltano gli sfondi di FOTO)
Serve rsvg-convert e i caratteri Oswald e Cinzel (Google Fonts, licenza OFL)
installati nel sistema.

Lo stemma e' quello del sito, con la crocetta nello skyline
(stemma.svg qui accanto, copia di "Logo Roma Club Matera.svg" del sito), non l'Illustrator del
NAS, che e' un disegno diverso. Niente loghi o marchi dell'AS Roma (il
lupetto di Gratton e' un marchio registrato) e niente foto di Totti: la
variante "Il Capitano" e' solo tipografica, e Totti e De Rossi compaiono
come maglia vista di spalle (nome, numero, fascia), mai come volto.
Colosseo e Olimpico sono disegnati qui, non presi da foto. Michele, 06/10/2026.

Il soggetto sta nella meta' bassa: in alto c'e' l'orologio della schermata
di blocco.
"""
import base64, io, os, subprocess, sys, tempfile

QUI = os.path.dirname(os.path.abspath(__file__))
STEMMA_SVG = os.path.join(QUI, 'stemma.svg')
W, H = 1440, 3200
RATIO = 1611 / 1392  # altezza/larghezza dello stemma

DEFS = '''<defs>
<filter id="ombra" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="18" stdDeviation="28" flood-color="#000" flood-opacity=".55"/></filter>
<radialGradient id="luce" cx="50%" cy="56%" r="60%"><stop offset="0" stop-color="#b3283a"/><stop offset=".55" stop-color="#7d1a28"/><stop offset="1" stop-color="#3a0a12"/></radialGradient>
<linearGradient id="oro" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#f6cf5a"/><stop offset=".5" stop-color="#e3ad1e"/><stop offset="1" stop-color="#a87a10"/></linearGradient>
<radialGradient id="buio" cx="50%" cy="62%" r="55%"><stop offset="0" stop-color="#2a0a10"/><stop offset="1" stop-color="#000"/></radialGradient>
<radialGradient id="panna" cx="50%" cy="58%" r="70%"><stop offset="0" stop-color="#fbf4e2"/><stop offset="1" stop-color="#e8d6a8"/></radialGradient>
<radialGradient id="vignetta" cx="50%" cy="55%" r="75%"><stop offset=".45" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".72"/></radialGradient>
</defs>'''


def stemma(png, w, cx, cy, ombra=True):
    h = w * RATIO
    f = ' filter="url(#ombra)"' if ombra else ''
    return f'<image href="file://{png}" x="{cx - w / 2:.0f}" y="{cy - h / 2:.0f}" width="{w}" height="{h:.0f}"{f}/>'


def filetto(y, colore='url(#oro)', w=420):
    return f'<rect x="{W / 2 - w / 2:.0f}" y="{y}" width="{w}" height="4" fill="{colore}"/>'


def scritta(y, testo, size=46, colore='#e3ad1e', font='Cinzel', peso=700, sp=10):
    return (f'<text x="{W / 2:.0f}" y="{y}" text-anchor="middle" font-family="{font}" font-weight="{peso}" '
            f'font-size="{size}" letter-spacing="{sp}" fill="{colore}">{testo}</text>')


def righe(colore):
    return ''.join(f'<rect x="{-400 + i * 260}" y="-200" width="70" height="{H + 400}" fill="{colore}" opacity=".05" '
                   f'transform="rotate(-18 {W / 2:.0f} {H / 2:.0f})"/>' for i in range(10))


def colosseo(cx=W / 2, base=2380, R=560, scala=1.0, dx=0):
    """Il Colosseo di fronte, stilizzato: la facciata e' una curva, quindi le
    arcate si stringono verso i lati; tre ordini di arcate, l'attico con le
    finestrelle, e a destra l'anello esterno crollato in diagonale."""
    import math
    cx = cx + dx
    R = R * scala
    alt = [h * scala for h in (190, 175, 165, 125)]
    p = []
    # il crollo: oltre questo x ogni livello non c'e' piu' (piu' in alto, prima finisce)
    crollo = [cx + R * 1.1, cx + R * 0.78, cx + R * 0.52, cx + R * 0.28]
    y = base
    for liv, h in enumerate(alt):
        top = y - h
        xs = cx - R * 0.985
        xe = min(cx + R * 0.985, crollo[liv])
        # bordo destro frastagliato
        p.append(f'<path d="M{xs:.0f},{y:.0f} V{top:.0f} H{xe - 18:.0f} L{xe:.0f},{top + h * .35:.0f} L{xe - 10:.0f},{top + h * .7:.0f} L{xe + 6:.0f},{y:.0f} Z" fill="url(#oro)"/>')
        p.append(f'<rect x="{xs:.0f}" y="{top:.0f}" width="{xe - xs - 18:.0f}" height="{8 * scala:.0f}" fill="#f6cf5a"/>')
        n = 22
        for k in range(n):
            a0 = -math.pi / 2 * 0.93 + k * (math.pi * 0.93 / n)
            a1 = a0 + math.pi * 0.93 / n
            xa, xb = cx + R * math.sin(a0), cx + R * math.sin(a1)
            larg = xb - xa
            ax, aw = xa + larg * .22, larg * .56
            if ax + aw > xe - 22:
                break
            if liv < 3:
                r = aw / 2
                ah = h - 48 * scala
                p.append(f'<path d="M{ax:.1f},{y - 10 * scala:.1f} v-{ah - r:.1f} a{r:.1f},{r:.1f} 0 0 1 {aw:.1f},0 v{ah - r:.1f} z" fill="#3a0a12"/>')
            elif k % 2 == 0:
                p.append(f'<rect x="{ax:.1f}" y="{top + h * .38:.1f}" width="{aw:.1f}" height="{h * .32:.1f}" fill="#3a0a12"/>')
        y = top
    return ''.join(p)


def colosseo_scena():
    sole = f'<circle cx="{W / 2:.0f}" cy="2000" r="640" fill="#e3ad1e" opacity=".12"/><circle cx="{W / 2:.0f}" cy="2000" r="460" fill="#e3ad1e" opacity=".10"/>'
    terra = f'<rect x="0" y="2380" width="{W}" height="{H - 2380}" fill="#2a070d"/><rect x="0" y="2380" width="{W}" height="6" fill="url(#oro)"/>'
    return sole + colosseo() + terra


def sassi(base=2420, colore='url(#oro)', finestre='#3a0a12', seme=7, x0=0, x1=W, cima=None, luci=False):
    """I Sassi: case a terrazze su una collina, il campanile della Cattedrale
    in cima (come nello stemma), finestre scure (o accese, di notte)."""
    import random, math
    rnd = random.Random(seme)
    cx = (x0 + x1) / 2 if cima is None else cima
    larga = (x1 - x0) / 2
    alt_coll = 520 * (x1 - x0) / W
    colle = lambda x: base - alt_coll * max(0, math.cos(min(1, abs(x - cx) / larga) * math.pi / 2)) ** 1.3
    p = [f'<path d="M{x0},{base} ' + ' '.join(f'L{x:.0f},{colle(x):.0f}' for x in range(int(x0), int(x1) + 1, 20)) + f' L{x1},{base} Z" fill="{colore}"/>']
    for fila in range(7):
        x = x0 + rnd.randint(0, 40)
        while x < x1 - 40:
            w = rnd.randint(44, 96)
            yb = colle(x + w / 2) + fila * 62 + rnd.randint(0, 20)
            if yb > base - 10:
                x += w
                continue
            h = rnd.randint(46, 92)
            p.append(f'<rect x="{x:.0f}" y="{yb - h:.0f}" width="{w}" height="{h + 4}" fill="{colore}" stroke="#5a0f19" stroke-opacity=".35" stroke-width="2"/>')
            if rnd.random() < .7:
                fw, fh = rnd.choice([(12, 18), (14, 22), (18, 14)])
                fx = x + rnd.randint(8, max(9, w - fw - 8))
                acc = luci and rnd.random() < .45
                p.append(f'<rect x="{fx:.0f}" y="{yb - h + rnd.randint(14, max(15, h - fh - 8)):.0f}" width="{fw}" height="{fh}" fill="{"#ffd36a" if acc else finestre}"{" opacity=\".95\"" if acc else ""}/>')
            x += w + rnd.randint(0, 6)
    # la Cattedrale col campanile
    top = colle(cx)
    p.append(f'<rect x="{cx - 120:.0f}" y="{top - 110:.0f}" width="190" height="130" fill="{colore}"/>')
    p.append(f'<path d="M{cx - 130:.0f},{top - 110:.0f} L{cx - 25:.0f},{top - 165:.0f} L{cx + 80:.0f},{top - 110:.0f} Z" fill="{colore}"/>')
    p.append(f'<rect x="{cx + 70:.0f}" y="{top - 330:.0f}" width="58" height="350" fill="{colore}"/>')
    p.append(f'<path d="M{cx + 64:.0f},{top - 330:.0f} L{cx + 99:.0f},{top - 420:.0f} L{cx + 134:.0f},{top - 330:.0f} Z" fill="{colore}"/>')
    for k in range(3):
        p.append(f'<path d="M{cx + 86:.0f},{top - 300 + k * 70:.0f} v-24 a13,13 0 0 1 26,0 v24 z" fill="{"#ffd36a" if luci and k == 0 else finestre}"/>')
    return ''.join(p)


def stelle(n=160, seme=3):
    import random
    rnd = random.Random(seme)
    return ''.join(f'<circle cx="{rnd.uniform(0, W):.0f}" cy="{rnd.uniform(0, 2000):.0f}" r="{rnd.choice([1.5, 2, 2.5, 3.5]):.1f}" fill="#f6ecd0" opacity="{rnd.uniform(.3, .9):.2f}"/>' for _ in range(n)) \
        + f'<circle cx="1110" cy="560" r="95" fill="#f6ecd0" opacity=".9"/><circle cx="1150" cy="530" r="85" fill="#0b0204"/>'


def curva(cima=2280):
    """La Curva: tifosi (testa e spalle) in file, piccoli in fondo e grandi
    davanti, con le sciarpe alzate. Le file si disegnano da quella lontana a
    quella vicina, cosi' chi sta davanti copre chi sta dietro."""
    import random
    rnd = random.Random(11)
    p = []
    file = 16
    for k in range(file):
        t = k / (file - 1)
        r = 15 + t * 33                      # raggio della testa
        y = cima + (H + 40 - cima) * t ** 1.25
        scuro = ['#1b0508', '#2a070d', '#3a0a12', '#4a0f19'][:2 + round(t * 2)]
        x = -r + rnd.uniform(0, 2 * r)
        while x < W + 2 * r:
            c = rnd.choice(scuro)
            p.append(f'<ellipse cx="{x:.0f}" cy="{y + r * 1.9:.0f}" rx="{r * 1.55:.0f}" ry="{r * 1.2:.0f}" fill="{c}"/>'
                     f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r:.0f}" fill="{c}"/>')
            if rnd.random() < .2:  # sciarpa alzata sopra la testa
                sw, sh, sy = r * 4.4, r * .95, y - r * 2.3
                p.append(f'<g transform="rotate({rnd.uniform(-7, 7):.1f} {x:.0f} {sy:.0f})">'
                         + ''.join(f'<rect x="{x - sw / 2 + q * sw / 7:.1f}" y="{sy - sh / 2:.0f}" width="{sw / 7 + .6:.1f}" height="{sh:.0f}" '
                                   f'fill="{"#e3ad1e" if q % 2 else "#a82234"}"/>' for q in range(7))
                         + f'<rect x="{x - sw / 2 - r * .25:.0f}" y="{sy - sh / 2:.0f}" width="{r * .3:.0f}" height="{sh * 1.9:.0f}" fill="{c}"/>'
                         + f'<rect x="{x + sw / 2 - r * .05:.0f}" y="{sy - sh / 2:.0f}" width="{r * .3:.0f}" height="{sh * 1.9:.0f}" fill="{c}"/>'
                         + '</g>')
            x += r * 2.6 + rnd.uniform(-r * .3, r * .3)
    return ''.join(p)


def fumogeni():
    return ('<filter id="fumo" x="-30%" y="-30%" width="160%" height="160%"><feTurbulence type="fractalNoise" baseFrequency="0.004 0.006" numOctaves="4" seed="5"/>'
            '<feDisplacementMap in="SourceGraphic" scale="420"/><feGaussianBlur stdDeviation="22"/></filter>'
            '<g filter="url(#fumo)">'
            f'<ellipse cx="420" cy="1900" rx="520" ry="1100" fill="#c0283b" opacity=".9"/>'
            f'<ellipse cx="1050" cy="1700" rx="520" ry="1150" fill="#e3ad1e" opacity=".85"/>'
            f'<ellipse cx="720" cy="2500" rx="560" ry="700" fill="#8e1f2f" opacity=".8"/>'
            '</g>')


def mosaico(png):
    out = []
    for r in range(22):
        for c in range(9):
            x = c * 170 + (85 if r % 2 else 0) - 20
            y = r * 160 - 40
            out.append(f'<image href="file://{png}" x="{x}" y="{y}" width="90" height="104" opacity=".10"/>')
    return ''.join(out)


def olimpico():
    """Lo stadio visto dall'alto: tribune, pista d'atletica, campo e la
    Curva Sud in giallo."""
    cx, cy = W / 2, 2010
    p = []
    p.append(f'<ellipse cx="{cx}" cy="{cy}" rx="640" ry="980" fill="#1b0508" opacity=".55"/>')       # copertura
    p.append(f'<ellipse cx="{cx}" cy="{cy}" rx="600" ry="930" fill="#6b1522"/>')                    # tribune
    p.append(f'<clipPath id="tribune"><ellipse cx="{cx}" cy="{cy}" rx="600" ry="930"/></clipPath>')
    p.append(f'<rect x="0" y="{cy + 560}" width="{W}" height="500" fill="url(#oro)" clip-path="url(#tribune)"/>')  # Curva Sud
    p.append(f'<rect x="{cx - 430}" y="{cy - 720}" width="860" height="1440" rx="430" fill="#b5452f"/>')   # pista
    for k in (1, 2, 3):
        p.append(f'<rect x="{cx - 430 + k * 22}" y="{cy - 720 + k * 22}" width="{860 - k * 44}" height="{1440 - k * 44}" rx="{430 - k * 22}" fill="none" stroke="#f6ecd0" stroke-opacity=".35" stroke-width="2"/>')
    fw, fh = 300, 470
    for i in range(10):  # erba a strisce
        p.append(f'<rect x="{cx - fw}" y="{cy - fh + i * 2 * fh / 10:.0f}" width="{2 * fw}" height="{2 * fh / 10:.0f}" fill="{"#2f7d3a" if i % 2 else "#2a7234"}"/>')
    L = 'fill="none" stroke="#f6ecd0" stroke-width="5"'
    p.append(f'<rect x="{cx - fw}" y="{cy - fh}" width="{2 * fw}" height="{2 * fh}" {L}/>')
    p.append(f'<line x1="{cx - fw}" y1="{cy}" x2="{cx + fw}" y2="{cy}" {L}/><circle cx="{cx}" cy="{cy}" r="85" {L}/>')
    for sgn in (-1, 1):
        yb = cy + sgn * fh
        p.append(f'<rect x="{cx - 170}" y="{min(yb, yb - sgn * 150)}" width="340" height="150" {L}/>')
        p.append(f'<rect x="{cx - 75}" y="{min(yb, yb - sgn * 55)}" width="150" height="55" {L}/>')
    p.append(f'<text x="{cx}" y="{cy + 820}" text-anchor="middle" font-family="Oswald" font-weight="700" font-size="74" letter-spacing="14" fill="#5a0f19">CURVA SUD</text>')
    return ''.join(p)


def maglia(nome, numero, motto):
    """Maglia vista di spalle: rossa, colletto e polsini oro, fascia da
    capitano. Niente stemma ne' sponsor dell'AS Roma."""
    corpo = ('M560,1380 Q720,1450 880,1380 L1080,1430 L1290,1720 L1170,1830 L1080,1760 '
             'L1080,2700 Q720,2740 360,2700 L360,1760 L270,1830 L150,1720 L360,1430 Z')
    return (f'<path d="{corpo}" fill="#8e1f2f" filter="url(#ombra)"/>'
            '<path d="M560,1380 Q720,1450 880,1380" fill="none" stroke="#e3ad1e" stroke-width="22"/>'
            '<line x1="1290" y1="1720" x2="1170" y2="1830" stroke="#e3ad1e" stroke-width="26"/>'
            '<line x1="150" y1="1720" x2="270" y2="1830" stroke="#e3ad1e" stroke-width="26"/>'
            '<path d="M196,1650 L326,1765 L298,1797 L168,1682 Z" fill="#e3ad1e"/>'   # fascia da capitano
            '<text x="247" y="1742" text-anchor="middle" font-family="Oswald" font-weight="700" font-size="40" fill="#5a0f19" transform="rotate(41 247 1728)">C</text>'
            f'<text x="720" y="1640" text-anchor="middle" font-family="Oswald" font-weight="600" font-size="120" letter-spacing="10" fill="#e3ad1e">{nome}</text>'
            f'<text x="720" y="2330" text-anchor="middle" font-family="Oswald" font-weight="700" font-size="640" fill="#e3ad1e" stroke="#5a0f19" stroke-width="10">{numero}</text>'
            + scritta(2880, motto, 64, sp=18) + filetto(2930, w=520))


# Illustrazioni fatte fuori da qui (con un generatore di immagini), che stanno
# nell'archivio del Club: la cartella si passa con ORIGINALI=..., il percorso
# non va nel repo. Nome del file -> (nome dello sfondo, scritta sotto lo stemma).
FOTO = {
    '01.png': ('07-olimpico-notte', 'ROMA CLUB MATERA'),
    '02.png': ('14-la-curva-fumogeni', 'ROMA CLUB MATERA'),
}


def da_foto(file, testo, png):
    """L'illustrazione copre tutto lo schermo (si taglia ai lati quello che
    avanza); in basso, sulla folla scura, stemma e scritta."""
    from PIL import Image, ImageFilter
    im = Image.open(file).convert('RGB')
    k = max(W / im.width, H / im.height)
    im = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    x = (im.width - W) // 2
    im = im.crop((x, 0, x + W, H)).filter(ImageFilter.UnsharpMask(radius=1.8, percent=55, threshold=2))
    b = io.BytesIO()
    im.save(b, 'PNG')
    dati = base64.b64encode(b.getvalue()).decode()
    return (f'<image href="data:image/png;base64,{dati}" x="0" y="0" width="{W}" height="{H}"/>'
            '<linearGradient id="sfuma" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#050102" stop-opacity="0"/><stop offset="1" stop-color="#050102" stop-opacity=".85"/></linearGradient>'
            f'<rect x="0" y="2350" width="{W}" height="{H - 2350}" fill="url(#sfuma)"/>'
            + stemma(png, 300, W / 2, 2770) + filetto(2990, w=360) + scritta(3070, testo, 40, sp=12))


def sfondi(png):
    s = lambda *a, **k: stemma(png, *a, **k)
    strisce = ''.join(f'<rect x="{i * 240}" y="0" width="240" height="{H}" fill="{"#8e1f2f" if i % 2 == 0 else "#e3ad1e"}"/>' for i in range(7))
    d = {
        '01-giallorosso': f'<rect width="{W}" height="{H}" fill="url(#luce)"/>' + righe('#e3ad1e')
            + s(860, W / 2, 1900) + filetto(2520) + scritta(2610, 'ROMA CLUB MATERA', 44),
        '02-notte': f'<rect width="{W}" height="{H}" fill="url(#buio)"/>'
            + s(700, W / 2, 2050) + filetto(2560, w=260) + scritta(2640, 'ROMA CLUB MATERA', 38, sp=12),
        '03-sciarpa': strisce + f'<rect width="{W}" height="{H}" fill="url(#vignetta)"/>'
            + f'<circle cx="{W / 2:.0f}" cy="1900" r="560" fill="#1b0508"/>'
            + f'<circle cx="{W / 2:.0f}" cy="1900" r="560" fill="none" stroke="url(#oro)" stroke-width="10"/>'
            + s(700, W / 2, 1900),
        '04-panna': f'<rect width="{W}" height="{H}" fill="url(#panna)"/>' + righe('#8e1f2f')
            + s(860, W / 2, 1900) + filetto(2520, '#5a0f19') + scritta(2610, 'FORZA ROMA', 48, colore='#5a0f19'),
        '05-capitano': f'<rect width="{W}" height="{H}" fill="url(#luce)"/><rect width="{W}" height="{H}" fill="url(#vignetta)"/>'
            + f'<text x="{W / 2:.0f}" y="2330" text-anchor="middle" font-family="Oswald" font-weight="700" font-size="1500" '
              f'fill="none" stroke="#e3ad1e" stroke-width="8" opacity=".9">10</text>'
            + scritta(2560, 'IL CAPITANO', 64, sp=18) + filetto(2610, w=520)
            + scritta(2720, 'FRANCESCO TOTTI', 92, colore='#f6ecd0', font='Oswald', peso=600, sp=8)
            + s(250, W / 2, 2990, ombra=False),
        '06-colosseo': f'<rect width="{W}" height="{H}" fill="url(#luce)"/>' + colosseo_scena()
            + s(300, W / 2, 2720, ombra=False) + scritta(2990, 'ROMA CLUB MATERA', 40, sp=12),
        '08-totti-10': f'<rect width="{W}" height="{H}" fill="url(#buio)"/>' + maglia('TOTTI', '10', 'IL CAPITANO')
            + s(170, W / 2, 3060, ombra=False),
        '09-de-rossi-16': f'<rect width="{W}" height="{H}" fill="url(#buio)"/>' + maglia('DE ROSSI', '16', 'CAPITAN FUTURO')
            + s(170, W / 2, 3060, ombra=False),
        '10-sassi': f'<rect width="{W}" height="{H}" fill="url(#luce)"/>' + sassi()
            + f'<rect x="0" y="2420" width="{W}" height="{H - 2420}" fill="#2a070d"/><rect x="0" y="2420" width="{W}" height="6" fill="url(#oro)"/>'
            + s(300, W / 2, 2760, ombra=False) + scritta(3030, 'MATERA', 44, sp=24),
        '11-sassi-di-notte': f'<rect width="{W}" height="{H}" fill="#0b0204"/>' + stelle()
            + sassi(colore='#2a070d', finestre='#14030a', luci=True)
            + f'<rect x="0" y="2420" width="{W}" height="{H - 2420}" fill="#0b0204"/>'
            + s(280, W / 2, 2760, ombra=False) + scritta(3030, 'ROMA CLUB MATERA', 38, sp=12),
        '12-da-matera-a-roma': f'<rect width="{W}" height="{H}" fill="url(#luce)"/>'
            + sassi(base=2400, x0=0, x1=760, seme=4) + colosseo(cx=1070, base=2400, R=360, scala=.62)
            + f'<rect x="0" y="2400" width="{W}" height="{H - 2400}" fill="#2a070d"/><rect x="0" y="2400" width="{W}" height="6" fill="url(#oro)"/>'
            + s(260, W / 2, 2730, ombra=False) + scritta(2990, 'DA MATERA A ROMA', 44, sp=12),
        '13-fumogeni': f'<rect width="{W}" height="{H}" fill="#120306"/>' + fumogeni()
            + f'<rect width="{W}" height="{H}" fill="url(#vignetta)"/>' + s(760, W / 2, 2050),
        '15-diagonale': f'<path d="M0,0 H{W} V900 L0,2600 Z" fill="#8e1f2f"/><path d="M0,2600 L{W},900 V{H} H0 Z" fill="url(#oro)"/>'
            + f'<rect width="{W}" height="{H}" fill="url(#vignetta)" opacity=".6"/>' + s(820, W / 2, 1900),
        '16-mosaico': f'<rect width="{W}" height="{H}" fill="#3a0a12"/>' + mosaico(png)
            + f'<rect width="{W}" height="{H}" fill="url(#vignetta)"/>' + s(820, W / 2, 1900) + filetto(2520) + scritta(2610, 'ROMA CLUB MATERA', 44),
        '17-sciarpa-diagonale': f'<g transform="rotate(-30 {W / 2:.0f} {H / 2:.0f})">'
            + ''.join(f'<rect x="-1200" y="{-800 + k * 230}" width="{W + 2400}" height="230" fill="{"#8e1f2f" if k % 2 == 0 else "#e3ad1e"}"/>' for k in range(26))
            + '</g>' + f'<rect width="{W}" height="{H}" fill="url(#vignetta)"/>'
            + f'<circle cx="{W / 2:.0f}" cy="1900" r="560" fill="#1b0508"/><circle cx="{W / 2:.0f}" cy="1900" r="560" fill="none" stroke="url(#oro)" stroke-width="10"/>'
            + s(700, W / 2, 1900),
        '18-mmxii': f'<rect width="{W}" height="{H}" fill="url(#buio)"/>'
            + f'<text x="{W / 2:.0f}" y="2120" text-anchor="middle" font-family="Cinzel" font-weight="700" font-size="400" fill="none" stroke="#e3ad1e" stroke-width="5">MMXII</text>'
            + scritta(2330, 'DAL 2012 A MATERA', 50, sp=14) + filetto(2390, w=520) + s(300, W / 2, 2720, ombra=False),
        '19-forza-grande-roma': f'<rect width="{W}" height="{H}" fill="url(#luce)"/><rect width="{W}" height="{H}" fill="url(#vignetta)"/>'
            + ''.join(scritta(1750 + k * 210, t, 190, colore='#e3ad1e' if k % 2 == 0 else '#f6ecd0', font='Oswald', peso=700, sp=6) for k, t in enumerate(['FORZA', 'GRANDE', 'ROMA']))
            + filetto(2300, w=520) + scritta(2390, 'LO SAI CHE IO CI SONO', 46, sp=10) + s(260, W / 2, 2760, ombra=False),
        '20-elegante': f'<rect width="{W}" height="{H}" fill="#050102"/>'
            + f'<rect x="90" y="1200" width="{W - 180}" height="1700" fill="none" stroke="url(#oro)" stroke-width="3"/>'
            + f'<rect x="110" y="1220" width="{W - 220}" height="1660" fill="none" stroke="#e3ad1e" stroke-opacity=".35" stroke-width="1.5"/>'
            + s(520, W / 2, 2000, ombra=False) + scritta(2560, 'ROMA CLUB MATERA', 40, sp=16) + scritta(2640, '“FRANCESCO TOTTI”', 34, colore='#f6ecd0', sp=8),
    }
    orig = os.environ.get('ORIGINALI')
    if orig:
        for f, (nome, testo) in FOTO.items():
            if os.path.exists(os.path.join(orig, f)):
                d[nome] = da_foto(os.path.join(orig, f), testo, png)
    return dict(sorted(d.items()))


def main():
    out = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else 'sfondi-png')
    os.makedirs(out, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        png = os.path.join(tmp, 'stemma.png')
        subprocess.run(['rsvg-convert', '-w', '1000', STEMMA_SVG, '-o', png], check=True)
        for nome, corpo in sfondi(png).items():
            svg = os.path.join(tmp, nome + '.svg')
            with open(svg, 'w') as f:
                f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{DEFS}{corpo}</svg>')
            dest = os.path.join(out, f'sfondo-roma-club-matera-{nome}.png')
            subprocess.run(['rsvg-convert', svg, '-o', dest], check=True)
            print(dest)


if __name__ == '__main__':
    main()
