#!/usr/bin/env python3
"""Sfondi per telefono (1440x3200) con lo stemma del Roma Club Matera.

Uso: [ORIGINALI=<cartella delle illustrazioni>] sfondi/genera.py [cartella di uscita]
     (default: ./sfondi-png; senza ORIGINALI si saltano gli sfondi di FOTO)
Serve rsvg-convert e i caratteri Oswald e Cinzel (Google Fonts, licenza OFL)
installati nel sistema.

Lo stemma e' quello del sito, con la crocetta nello skyline
(stemma.svg qui accanto, copia di "Logo Roma Club Matera.svg" del sito), non l'Illustrator del
NAS, che e' un disegno diverso. Niente lupetto di Gratton (marchio
registrato dell'AS Roma) e niente foto di agenzia: Totti e De Rossi vengono da
un'illustrazione generata, di spalle (vedi FOTO). Colosseo e Sassi sono
disegnati qui, in controluce sul tramonto.

Zone libere (Michele, 09/10/2026: "in basso ci sono le icone e molte cose
vengono coperte"): in alto c'e' l'orologio della schermata di blocco, in basso
la barra delle icone e i tasti. Stemma e scritte stanno solo fra ALTO e BASSO;
sopra e sotto solo fondo.
"""
import base64, io, os, subprocess, sys, tempfile

QUI = os.path.dirname(os.path.abspath(__file__))
STEMMA_SVG = os.path.join(QUI, 'stemma.svg')
W, H = 1440, 3200
RATIO = 1611 / 1392  # altezza/larghezza dello stemma
ALTO, BASSO = 950, 2470  # fascia libera da orologio (sopra) e icone (sotto)

DEFS = '''<defs>
<filter id="ombra" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="18" stdDeviation="28" flood-color="#000" flood-opacity=".55"/></filter>
<radialGradient id="luce" cx="50%" cy="56%" r="60%"><stop offset="0" stop-color="#b3283a"/><stop offset=".55" stop-color="#7d1a28"/><stop offset="1" stop-color="#3a0a12"/></radialGradient>
<linearGradient id="oro" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#f6cf5a"/><stop offset=".5" stop-color="#e3ad1e"/><stop offset="1" stop-color="#a87a10"/></linearGradient>
<radialGradient id="buio" cx="50%" cy="62%" r="55%"><stop offset="0" stop-color="#2a0a10"/><stop offset="1" stop-color="#000"/></radialGradient>
<radialGradient id="panna" cx="50%" cy="58%" r="70%"><stop offset="0" stop-color="#fbf4e2"/><stop offset="1" stop-color="#e8d6a8"/></radialGradient>
<radialGradient id="vignetta" cx="50%" cy="55%" r="75%"><stop offset=".45" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".72"/></radialGradient>
<filter id="bagliore" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="7" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
<filter id="grana" x="0" y="0" width="100%" height="100%"><feTurbulence type="fractalNoise" baseFrequency=".85" numOctaves="2" seed="4" stitchTiles="stitch"/><feColorMatrix type="matrix" values="0 0 0 0 1  0 0 0 0 .95  0 0 0 0 .85  1.4 0 0 0 -.6"/></filter>
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


def colosseo(cx=W / 2, base=2380, R=560, scala=1.0, dx=0, corpo='url(#oro)', cornice='#f6cf5a', archi='#3a0a12'):
    """Il Colosseo di fronte, stilizzato: la facciata e' una curva, quindi le
    arcate si stringono verso i lati; tre ordini di arcate, l'attico con le
    finestrelle, e a destra l'anello esterno crollato in diagonale.
    In controluce: corpo scuro e archi riempiti col cielo (url(#cielo))."""
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
        p.append(f'<path d="M{xs:.0f},{y:.0f} V{top:.0f} H{xe - 18:.0f} L{xe:.0f},{top + h * .35:.0f} L{xe - 10:.0f},{top + h * .7:.0f} L{xe + 6:.0f},{y:.0f} Z" fill="{corpo}"/>')
        p.append(f'<rect x="{xs:.0f}" y="{top:.0f}" width="{xe - xs - 18:.0f}" height="{8 * scala:.0f}" fill="{cornice}"/>')
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
                p.append(f'<path d="M{ax:.1f},{y - 10 * scala:.1f} v-{ah - r:.1f} a{r:.1f},{r:.1f} 0 0 1 {aw:.1f},0 v{ah - r:.1f} z" fill="{archi}"/>')
            elif k % 2 == 0:
                p.append(f'<rect x="{ax:.1f}" y="{top + h * .38:.1f}" width="{aw:.1f}" height="{h * .32:.1f}" fill="{archi}"/>')
        y = top
    return ''.join(p)


def cielo(orizzonte, sole=(W / 2, None), notte=False):
    """Cielo al tramonto (o di notte) fino all'orizzonte. Il gradiente e' in
    coordinate dello schermo, cosi' gli archi riempiti con url(#cielo) hanno
    lo stesso colore del cielo dietro: sembrano vuoti."""
    stop = ([(0, '#050103'), (.55, '#14040a'), (.85, '#2a0a14'), (1, '#4a1420')] if notte else
            [(0, '#12030a'), (.32, '#4a0f19'), (.6, '#9e2433'), (.8, '#d9622b'), (.93, '#f0a238'), (1, '#f8d27a')])
    g = (f'<linearGradient id="cielo" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="{orizzonte}">'
         + ''.join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stop) + '</linearGradient>')
    out = g + f'<rect width="{W}" height="{orizzonte + 2}" fill="url(#cielo)"/>'
    if not notte:
        sx, sy = sole[0], sole[1] if sole[1] is not None else orizzonte - 120
        out += (f'<radialGradient id="alone" gradientUnits="userSpaceOnUse" cx="{sx:.0f}" cy="{sy:.0f}" r="900">'
                '<stop offset="0" stop-color="#ffe6a3" stop-opacity=".85"/><stop offset=".25" stop-color="#f5a23a" stop-opacity=".35"/>'
                '<stop offset="1" stop-color="#f5a23a" stop-opacity="0"/></radialGradient>'
                f'<rect width="{W}" height="{orizzonte}" fill="url(#alone)"/>'
                f'<circle cx="{sx:.0f}" cy="{sy:.0f}" r="150" fill="#fff0c4" opacity=".95"/>')
    return out


def terreno(y, colore='#14040a'):
    return (f'<linearGradient id="terra" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{colore}"/><stop offset="1" stop-color="#050102"/></linearGradient>'
            f'<rect x="0" y="{y}" width="{W}" height="{H - y}" fill="url(#terra)"/>')


def sassi(base=2420, colore='url(#oro)', finestre='#3a0a12', seme=7, x0=0, x1=W, cima=None, luci=0.0, tratto='#5a0f19', alt=520):
    """I Sassi: case a terrazze su una collina, il campanile della Cattedrale
    in cima (come nello stemma). luci = quota di finestre accese, che
    brillano (filtro #bagliore)."""
    import random, math
    rnd = random.Random(seme)
    cx = (x0 + x1) / 2 if cima is None else cima
    larga = (x1 - x0) / 2
    alt_coll = alt * (x1 - x0) / W
    colle = lambda x: base - alt_coll * max(0, math.cos(min(1, abs(x - cx) / larga) * math.pi / 2)) ** 1.3
    p = [f'<path d="M{x0},{base} ' + ' '.join(f'L{x:.0f},{colle(x):.0f}' for x in range(int(x0), int(x1) + 1, 20)) + f' L{x1},{base} Z" fill="{colore}"/>']
    accese = []
    for fila in range(7):
        x = x0 + rnd.randint(0, 40)
        while x < x1 - 40:
            w = rnd.randint(44, 96)
            yb = colle(x + w / 2) + fila * 62 + rnd.randint(0, 20)
            if yb > base - 10:
                x += w
                continue
            h = rnd.randint(46, 92)
            p.append(f'<rect x="{x:.0f}" y="{yb - h:.0f}" width="{w}" height="{h + 4}" fill="{colore}" stroke="{tratto}" stroke-opacity=".5" stroke-width="2"/>')
            if rnd.random() < .7:
                fw, fh = rnd.choice([(12, 18), (14, 22), (18, 14)])
                fx = x + rnd.randint(8, max(9, w - fw - 8))
                r = f'<rect x="{fx:.0f}" y="{yb - h + rnd.randint(14, max(15, h - fh - 8)):.0f}" width="{fw}" height="{fh}" '
                if rnd.random() < luci:
                    accese.append(r + f'fill="{rnd.choice(["#ffd36a", "#ffbe4d", "#ffe39a"])}"/>')
                else:
                    p.append(r + f'fill="{finestre}"/>')
            x += w + rnd.randint(0, 6)
    # la Cattedrale col campanile
    top = colle(cx)
    p.append(f'<rect x="{cx - 120:.0f}" y="{top - 110:.0f}" width="190" height="130" fill="{colore}"/>')
    p.append(f'<path d="M{cx - 130:.0f},{top - 110:.0f} L{cx - 25:.0f},{top - 165:.0f} L{cx + 80:.0f},{top - 110:.0f} Z" fill="{colore}"/>')
    p.append(f'<rect x="{cx + 70:.0f}" y="{top - 330:.0f}" width="58" height="350" fill="{colore}"/>')
    p.append(f'<path d="M{cx + 64:.0f},{top - 330:.0f} L{cx + 99:.0f},{top - 420:.0f} L{cx + 134:.0f},{top - 330:.0f} Z" fill="{colore}"/>')
    for k in range(3):
        f = f'<path d="M{cx + 86:.0f},{top - 300 + k * 70:.0f} v-24 a13,13 0 0 1 26,0 v24 z" '
        (accese.append(f + 'fill="#ffd36a"/>') if luci and k == 0 else p.append(f + f'fill="{finestre}"/>'))
    if accese:
        p.append('<g filter="url(#bagliore)">' + ''.join(accese) + '</g>')
    return ''.join(p)


def stelle(n=160, seme=3):
    import random
    rnd = random.Random(seme)
    return ''.join(f'<circle cx="{rnd.uniform(0, W):.0f}" cy="{rnd.uniform(0, 2000):.0f}" r="{rnd.choice([1.5, 2, 2.5, 3.5]):.1f}" fill="#f6ecd0" opacity="{rnd.uniform(.3, .9):.2f}"/>' for _ in range(n)) \
        + f'<circle cx="1110" cy="560" r="95" fill="#f6ecd0" opacity=".9"/><circle cx="1150" cy="530" r="85" fill="#0b0204"/>'


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


# Illustrazioni fatte fuori da qui (con un generatore di immagini), che stanno
# nell'archivio del Club: la cartella si passa con ORIGINALI=..., il percorso
# non va nel repo. Nome del file -> (nome dello sfondo, scritta sotto lo stemma).
FOTO = {
    # Totti e De Rossi di spalle; la scelta di usarla cosi' com'e' e' di Michele (09/10/2026)
    '03-totti-de-rossi.png': [('08-totti-10', 'IL CAPITANO', {'centro': .30}),
                              ('09-de-rossi-16', 'CAPITAN FUTURO', {'centro': .755}),
                              ('09-totti-e-de-rossi', 'I NOSTRI CAPITANI', {'intera': True})],
    # illustrazioni del 09/10/2026 (cartella fatte/, nomi gia' pensati per il SEO):
    # prendono il posto delle versioni disegnate qui sotto, che restano se mancano
    'fatte/sfondo-roma-maglia-10-capitano-spogliatoio.png': [('05-capitano', 'IL CAPITANO', {})],
    'fatte/sfondo-roma-colosseo-tramonto.png': [('06-colosseo', 'ROMA CLUB MATERA', {'centro': .42})],
    'fatte/sfondo-roma-stadio-olimpico-notte.png': [('07-olimpico-notte', 'ROMA CLUB MATERA', {})],
    'fatte/sfondo-matera-sassi-notte-luna.png': [('11-sassi-di-notte', 'MATERA', {'centro': .45})],
    'fatte/sfondo-matera-roma-sassi-colosseo-tramonto.png': [('12-da-matera-a-roma', 'DA MATERA A ROMA', {})],
    'fatte/sfondo-roma-curva-sud-bandiere-fumogeni.png': [('14-la-curva-fumogeni', 'ROMA CLUB MATERA', {})],
    'fatte/sfondo-roma-dybala-21-stadio-notte.png': [('21-dybala-21', 'LA JOYA', {})],
    'fatte/sfondo-roma-malen-14-braccia-alzate-stadio.png': [('22-malen-14', 'DONYELL MALEN', {})],
    'fatte/sfondo-roma-malen-14-curva-bandiere.png': [('22-malen-14-curva', 'DONYELL MALEN', {'centro': .45})],
    'fatte/sfondo-roma-svilar-99-porta.png': [('23-svilar-99', 'MILE SVILAR', {})],
    'fatte/sfondo-roma-mancini-23-bandiera-giallorossa.jpeg': [('24-mancini-23', 'GIANLUCA MANCINI', {})],
    # la bandiera col topo sfotte la Lazio: voluta da Michele (10/10/2026)
    'fatte/sfondo-roma-mancini-23-bandiera-derby.png': [('24-mancini-23-derby', 'GIANLUCA MANCINI', {})],
    'fatte/sfondo-roma-portiere-tuffo-riflettori.png': [('25-portiere-tuffo', 'ROMA CLUB MATERA', {'centro': .55})],
}



def da_foto(file, testo, png, centro=.5, intera=False):
    """L'illustrazione copre tutto lo schermo, tagliata ai lati attorno a
    `centro` (frazione della larghezza). Con intera=True non si taglia: sta
    larga quanto lo schermo, e sopra e sotto continua sfocata e scura.
    In fondo sfuma nel buio, e stemma e scritta stanno appena sopra le icone."""
    from PIL import Image, ImageFilter, ImageEnhance
    im = Image.open(file).convert('RGB')
    k = max(W / im.width, H / im.height)
    pieno = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
    x = round(min(max(pieno.width * centro - W / 2, 0), pieno.width - W))
    pieno = pieno.crop((x, 0, x + W, H))
    if intera:
        fondo = ImageEnhance.Brightness(pieno.filter(ImageFilter.GaussianBlur(60))).enhance(.45)
        k = W / im.width
        nitida = im.resize((W, round(im.height * k)), Image.LANCZOS)
        y0 = 330
        # bordi sopra e sotto sfumati nel fondo
        m = Image.new('L', nitida.size, 255)
        for y in range(240):
            v = round(255 * y / 240)
            m.paste(v, (0, y, W, y + 1))
            m.paste(v, (0, nitida.height - 1 - y, W, nitida.height - y))
        fondo.paste(nitida, (0, y0), m)
        pieno = fondo
    pieno = pieno.filter(ImageFilter.UnsharpMask(radius=1.8, percent=55, threshold=2))
    b = io.BytesIO()
    pieno.save(b, 'PNG')
    dati = base64.b64encode(b.getvalue()).decode()
    return (f'<image href="data:image/png;base64,{dati}" x="0" y="0" width="{W}" height="{H}"/>'
            '<linearGradient id="sfuma" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#050102" stop-opacity="0"/>'
            '<stop offset=".45" stop-color="#050102" stop-opacity=".7"/><stop offset="1" stop-color="#050102" stop-opacity=".92"/></linearGradient>'
            f'<rect x="0" y="1900" width="{W}" height="{H - 1900}" fill="url(#sfuma)"/>'
            + stemma(png, 230, W / 2, 2190) + filetto(2360, w=300) + scritta(2440, testo, 40, sp=12))


def epigrafe(png):
    """Un'epigrafe romana: travertino, lettere incise e dipinte di rosso
    (come la rubricatura delle lapidi), cornice a tabula ansata."""
    trav = (f'<filter id="vene" filterUnits="userSpaceOnUse" x="0" y="0" width="{W}" height="{H}"><feTurbulence type="fractalNoise" baseFrequency="0.0012 0.05" numOctaves="4" seed="21"/>'
            '<feColorMatrix type="matrix" values="0 0 0 0 .5  0 0 0 0 .4  0 0 0 0 .28  2.2 0 0 0 -.95"/></filter>'
            f'<filter id="pori" filterUnits="userSpaceOnUse" x="0" y="0" width="{W}" height="{H}"><feTurbulence type="turbulence" baseFrequency="0.035 0.08" numOctaves="2" seed="3"/>'
            '<feColorMatrix type="matrix" values="0 0 0 0 .35  0 0 0 0 .28  0 0 0 0 .2  9 0 0 0 -4.2"/></filter>'
            '<radialGradient id="pietra" cx="40%" cy="40%" r="80%"><stop offset="0" stop-color="#efe3c6"/><stop offset="1" stop-color="#cdb98f"/></radialGradient>'
            f'<rect width="{W}" height="{H}" fill="url(#pietra)"/><rect width="{W}" height="{H}" filter="url(#vene)" opacity=".55"/>'
            f'<rect width="{W}" height="{H}" filter="url(#pori)" opacity=".3"/>')

    def incisa(y, testo, size, sp, colore='#8e1f2f'):
        t = lambda dx, dy, c, o: (f'<text x="{W / 2 + dx:.0f}" y="{y + dy}" text-anchor="middle" font-family="Cinzel" font-weight="700" '
                                  f'font-size="{size}" letter-spacing="{sp}" fill="{c}" opacity="{o}">{testo}</text>')
        return t(0, 3, '#fff8e8', .8) + t(0, -2, '#3d2a12', .55) + t(0, 0, colore, 1)

    x0, x1, y0, y1 = 170, W - 170, 1000, 1880
    orecchia = lambda x, d: f'M{x},{y0 + 140} L{x + d * 110},{(y0 + y1) / 2 - 90} L{x + d * 110},{(y0 + y1) / 2 + 90} L{x},{y1 - 140}'
    cornice = ''.join(f'<path d="M{x0 + i},{y0 + i} H{x1 - i} V{y1 - i} H{x0 + i} Z {orecchia(x0 + i, -1)} {orecchia(x1 - i, 1)}" fill="none" '
                      f'stroke="{c}" stroke-width="{w}" opacity="{o}"/>' for i, c, w, o in ((0, '#fff8e8', 6, .7), (-3, '#3d2a12', 4, .5), (24, '#8e1f2f', 3, .8)))
    return (trav + cornice
            + incisa(1220, 'ROMA CLUB', 118, 14) + incisa(1390, 'MATERA', 118, 34)
            + f'<rect x="{W / 2 - 300:.0f}" y="1480" width="600" height="5" fill="#8e1f2f"/>'
            + incisa(1680, 'MMXII', 190, 22) + incisa(1790, 'FRANCESCO TOTTI', 50, 14, '#5a0f19')
            + f'<rect width="{W}" height="{H}" fill="url(#vignetta)" opacity=".45"/>'
            + stemma(png, 300, W / 2, 2200))


def raggiera():
    """Raggi d'oro sottili dal centro, che si spengono verso i bordi (art deco)."""
    import math
    cx, cy = W / 2, 1600
    raggi = ''.join(f'<line x1="{cx}" y1="{cy}" x2="{cx + 1900 * math.cos(a):.0f}" y2="{cy + 1900 * math.sin(a):.0f}" stroke="#e3ad1e" stroke-width="{3 if k % 2 else 1.5}"/>'
                    for k, a in enumerate(i * math.pi / 36 for i in range(72)))
    return (f'<radialGradient id="spegni" gradientUnits="userSpaceOnUse" cx="{cx}" cy="{cy}" r="1300"><stop offset=".2" stop-color="#fff"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>'
            f'<mask id="m-raggi"><rect width="{W}" height="{H}" fill="url(#spegni)"/></mask>'
            f'<g mask="url(#m-raggi)" opacity=".28">{raggi}</g>')


def cornice_deco(x0, y0, x1, y1):
    """Doppia cornice con gli angoli a gradini."""
    def bordo(i, larg, op):
        g = 46 - i
        d = (f'M{x0 + i + g},{y0 + i} H{x1 - i - g} V{y0 + i + g / 2} H{x1 - i - g / 2} V{y0 + i + g} H{x1 - i} '
             f'V{y1 - i - g} H{x1 - i - g / 2} V{y1 - i - g / 2} H{x1 - i - g} V{y1 - i} '
             f'H{x0 + i + g} V{y1 - i - g / 2} H{x0 + i + g / 2} V{y1 - i - g} H{x0 + i} '
             f'V{y0 + i + g} H{x0 + i + g / 2} V{y0 + i + g / 2} H{x0 + i + g} Z')
        return f'<path d="{d}" fill="none" stroke="url(#oro)" stroke-width="{larg}" opacity="{op}"/>'
    return bordo(0, 4, 1) + bordo(18, 1.5, .55)


def sfondi(png):
    s = lambda *a, **k: stemma(png, *a, **k)
    strisce = ''.join(f'<rect x="{i * 240}" y="0" width="240" height="{H}" fill="{"#8e1f2f" if i % 2 == 0 else "#e3ad1e"}"/>' for i in range(7))
    grana = f'<rect width="{W}" height="{H}" filter="url(#grana)" opacity=".07"/>'
    tondo = (f'<circle cx="{W / 2:.0f}" cy="1650" r="540" fill="#1b0508"/>'
             f'<circle cx="{W / 2:.0f}" cy="1650" r="540" fill="none" stroke="url(#oro)" stroke-width="10"/>' + s(680, W / 2, 1650))

    def numero(n, ruolo, nome):
        """Il numero di maglia gigante in oro, con ruolo e nome sotto."""
        return (f'<rect width="{W}" height="{H}" fill="url(#luce)"/><rect width="{W}" height="{H}" fill="url(#vignetta)"/>' + grana
                + f'<text x="{W / 2 + 14:.0f}" y="1874" text-anchor="middle" font-family="Oswald" font-weight="700" font-size="1060" fill="#2a070d" opacity=".55">{n}</text>'
                + f'<text x="{W / 2:.0f}" y="1860" text-anchor="middle" font-family="Oswald" font-weight="700" font-size="1060" fill="url(#oro)">{n}</text>'
                + scritta(2010, ruolo, 60, sp=18) + filetto(2050, w=520)
                + scritta(2170, nome, 88, colore='#f6ecd0', font='Oswald', peso=600, sp=8)
                + s(150, W / 2, 2360, ombra=False))

    tramonto = lambda oriz: cielo(oriz) + terreno(oriz)
    d = {
        '01-giallorosso': f'<rect width="{W}" height="{H}" fill="url(#luce)"/>' + righe('#e3ad1e')
            + s(760, W / 2, 1600) + filetto(2120) + scritta(2210, 'ROMA CLUB MATERA', 44),
        '02-notte': f'<rect width="{W}" height="{H}" fill="url(#buio)"/>'
            + s(640, W / 2, 1620) + filetto(2080, w=260) + scritta(2160, 'ROMA CLUB MATERA', 38, sp=12),
        '03-sciarpa': strisce + f'<rect width="{W}" height="{H}" fill="url(#vignetta)"/>' + tondo,
        '04-panna': f'<rect width="{W}" height="{H}" fill="url(#panna)"/>' + righe('#8e1f2f')
            + s(760, W / 2, 1600) + filetto(2120, '#5a0f19') + scritta(2210, 'FORZA ROMA', 48, colore='#5a0f19'),
        '05-capitano': numero('10', 'IL CAPITANO', 'FRANCESCO TOTTI'),
        '06-colosseo': cielo(2330, sole=(1130, 2120)) + terreno(2330)
            + colosseo(cx=720, base=2335, R=560, corpo='#1b0508', cornice='#3a0a12', archi='url(#cielo)')
            + s(300, W / 2, 1120) + scritta(1400, 'ROMA CLUB MATERA', 40, colore='#fbe7b5', sp=12),
        '10-sassi': tramonto(2420)
            + sassi(base=2330, colore='#6b1522', finestre='#4a0f19', tratto='#9e2433', seme=3, x0=-200, x1=W + 200, cima=980, alt=430)
            + sassi(base=2440, colore='#1b0508', finestre='#0b0204', tratto='#3a0a12', seme=7, luci=.12)
            + s(300, W / 2, 1120) + scritta(1400, 'MATERA', 44, colore='#fbe7b5', sp=24),
        '11-sassi-di-notte': cielo(2440, notte=True) + stelle() + terreno(2440, '#0b0204')
            + sassi(base=2440, colore='#14030a', finestre='#0b0204', tratto='#2a070d', luci=.5)
            + s(280, W / 2, 1150, ombra=False) + scritta(1420, 'ROMA CLUB MATERA', 38, colore='#fbe7b5', sp=12),
        '12-da-matera-a-roma': cielo(2380, sole=(W / 2, 2160)) + terreno(2380)
            + sassi(base=2390, x0=-40, x1=720, seme=4, colore='#1b0508', finestre='#0b0204', tratto='#3a0a12', luci=.15, alt=600)
            + colosseo(cx=1100, base=2385, R=360, scala=.62, corpo='#1b0508', cornice='#3a0a12', archi='url(#cielo)')
            + s(280, W / 2, 1120) + scritta(1390, 'DA MATERA A ROMA', 44, colore='#fbe7b5', sp=12),
        '15-diagonale': f'<path d="M0,0 H{W} V900 L0,2600 Z" fill="#8e1f2f"/><path d="M0,2600 L{W},900 V{H} H0 Z" fill="url(#oro)"/>'
            + f'<rect width="{W}" height="{H}" fill="url(#vignetta)" opacity=".6"/>' + s(760, W / 2, 1720),
        '16-mosaico': f'<rect width="{W}" height="{H}" fill="#3a0a12"/>' + mosaico(png)
            + f'<rect width="{W}" height="{H}" fill="url(#vignetta)"/>' + s(760, W / 2, 1600) + filetto(2120) + scritta(2210, 'ROMA CLUB MATERA', 44),
        '17-sciarpa-diagonale': f'<g transform="rotate(-30 {W / 2:.0f} {H / 2:.0f})">'
            + ''.join(f'<rect x="-1200" y="{-800 + k * 230}" width="{W + 2400}" height="230" fill="{"#8e1f2f" if k % 2 == 0 else "#e3ad1e"}"/>' for k in range(26))
            + '</g>' + f'<rect width="{W}" height="{H}" fill="url(#vignetta)"/>' + tondo,
        '18-mmxii': epigrafe(png),
        '19-forza-grande-roma': f'<rect width="{W}" height="{H}" fill="url(#luce)"/><rect width="{W}" height="{H}" fill="url(#vignetta)"/>' + grana
            + ''.join(scritta(1250 + k * 210, t, 190, colore='#e3ad1e' if k % 2 == 0 else '#f6ecd0', font='Oswald', peso=700, sp=6) for k, t in enumerate(['FORZA', 'GRANDE', 'ROMA']))
            + filetto(1800, w=520) + scritta(1890, 'LO SAI CHE IO CI SONO', 46, sp=10) + s(260, W / 2, 2200, ombra=False),
        '20-elegante': f'<rect width="{W}" height="{H}" fill="#050102"/><rect width="{W}" height="{H}" fill="url(#buio)" opacity=".8"/>'
            + raggiera() + cornice_deco(110, 960, W - 110, 2440)
            + s(560, W / 2, 1580) + scritta(2130, 'ROMA CLUB MATERA', 52, sp=16)
            + f'<rect x="{W / 2 - 160:.0f}" y="2170" width="320" height="3" fill="url(#oro)"/>'
            + scritta(2250, '“FRANCESCO TOTTI”', 36, colore='#f6ecd0', sp=8) + scritta(2340, 'MMXII', 30, sp=20),
        # numeri della stagione 2026/27 (09/10/2026): da ricontrollare a ogni mercato
        '21-dybala-21': numero('21', 'LA JOYA', 'PAULO DYBALA'),
        '22-malen-14': numero('14', 'ATTACCANTE', 'DONYELL MALEN'),
        '23-svilar-99': numero('99', 'PORTIERE', 'MILE SVILAR'),
    }
    orig = os.environ.get('ORIGINALI')
    if orig:
        for f, varianti in FOTO.items():
            if os.path.exists(os.path.join(orig, f)):
                for nome, testo, opz in varianti:
                    d[nome] = da_foto(os.path.join(orig, f), testo, png, **opz)
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
