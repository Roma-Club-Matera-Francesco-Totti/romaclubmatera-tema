#!/usr/bin/env python3
"""Portfolio per la candidatura a designer di Galaxy Themes (Samsung).

Samsung chiede 3 temi completi, 6 schermate ciascuno, in un unico PDF.
Qui i tre temi del Club, disegnati con gli stessi elementi dell'app Tema RCM
(sfondi di ../sfondi/genera.py, simboli delle icone di ../icone/):

  1. Giallorosso — rosso porpora e oro, icone tonde come quelle dell'app
  2. Notte       — nero AMOLED e oro, icone a filo
  3. Matera      — tramonto sui Sassi, icone panna e terracotta

Schermate: blocco, Home, icone, telefono, messaggi, pannello rapido.
Quando Samsung apre le candidature va confrontato con il loro Starter Kit
(modello Photoshop ufficiale): ordine e contenuto delle 6 tavole possono
cambiare. Promemoria nel calendario di Michele: 1/06/2027.

Uso: portfolio/genera.py <cartella degli sfondi PNG> <file.pdf>
(gli sfondi si fanno con sfondi/genera.py; servono 01-giallorosso,
02-notte e 10-sassi). Caratteri: Lato, Oswald, Cinzel (OFL) installati.
"""
import base64, functools, io, os, subprocess, sys, tempfile

QUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(QUI, '..', 'icone'))
from genera import simbolo  # noqa: E402  (i Material Symbols gia' scaricati)
import importlib.util  # noqa: E402
_spec = importlib.util.spec_from_file_location('sfondi_genera', os.path.join(QUI, '..', 'sfondi', 'genera.py'))
SF = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(SF)

# Per Home e pannello lo stesso sfondo senza stemma ne' scritte: sotto le icone
# vuole un fondo pulito. Corpi SVG 1440x3200 fatti con le funzioni degli sfondi.
PULITI = {
    'Giallorosso': lambda: f'<rect width="1440" height="3200" fill="url(#luce)"/>' + SF.righe('#e3ad1e'),
    'Notte': lambda: '<rect width="1440" height="3200" fill="url(#buio)"/>',
    'Matera': lambda: SF.cielo(2420) + SF.terreno(2420)
        + SF.sassi(base=2330, colore='#6b1522', finestre='#4a0f19', tratto='#9e2433', seme=3, x0=-200, x1=1640, cima=980, alt=430)
        + SF.sassi(base=2440, colore='#1b0508', finestre='#0b0204', tratto='#3a0a12', seme=7, luci=.12),
}

W, H = 1080, 2340
UI = 'Lato'

TEMI = [
    dict(nome='Giallorosso', sfondo='01-giallorosso', motto='Il rosso del Club e l’oro di Roma',
         fondo='#3a0a12', superficie='#5a0f19', testo='#f6ecd0', accento='#e3ad1e', tenue='#c9a9a0',
         icona='tonda', orologio='Oswald'),
    dict(nome='Notte', sfondo='02-notte', motto='Nero AMOLED e oro: elegante e leggero sulla batteria',
         fondo='#000000', superficie='#141010', testo='#f6ecd0', accento='#e3ad1e', tenue='#9a8f80',
         icona='filo', orologio='Cinzel'),
    dict(nome='Matera', sfondo='10-sassi', motto='Il tramonto sui Sassi, da Matera a Roma',
         fondo='#1b0508', superficie='#2e0c10', testo='#fbe7b5', accento='#f0a238', tenue='#c99a7a',
         icona='panna', orologio='Oswald'),
]

APP = [  # (simbolo, nome) per Home e foglio delle icone
    ('call', 'Telefono'), ('sms', 'Messaggi'), ('photo_camera', 'Fotocamera'), ('photo_library', 'Galleria'),
    ('public', 'Internet'), ('mail', 'Email'), ('calendar_month', 'Calendario'), ('schedule', 'Orologio'),
    ('settings', 'Impostazioni'), ('map', 'Mappe'), ('chat', 'WhatsApp'), ('headphones', 'Musica'),
    ('smart_display', 'Video'), ('folder', 'File'), ('calculate', 'Calcolatrice'), ('edit_note', 'Note'),
    ('partly_cloudy_day', 'Meteo'), ('contacts', 'Contatti'), ('sports_soccer', 'Partite'), ('storefront', 'Store'),
]


def esc(t):
    return t.replace('&', '&amp;').replace('<', '&lt;')


def testo(x, y, t, size, colore, font=UI, peso=400, anchor='start', sp=0, op=1):
    return (f'<text x="{x}" y="{y}" font-family="{font}" font-weight="{peso}" font-size="{size}" fill="{colore}" '
            f'text-anchor="{anchor}" letter-spacing="{sp}" opacity="{op}">{esc(t)}</text>')


def glifo(nome, cx, cy, lato, colore):
    s = lato / 960
    return (f'<g transform="translate({cx - lato / 2:.1f} {cy + lato / 2:.1f}) scale({s:.5f})">'
            + ''.join(f'<path d="{d}" fill="{colore}"/>' for d in simbolo(nome)) + '</g>')


def icona(t, nome, cx, cy, r=84):
    """Le tre famiglie di icone dei temi."""
    if t['icona'] == 'tonda':
        return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#f-rosso)"/>'
                f'<circle cx="{cx}" cy="{cy}" r="{r * .9:.1f}" fill="none" stroke="url(#oro)" stroke-width="{r * .04:.1f}"/>'
                + glifo(nome, cx, cy, r * 1.0, 'url(#oro)'))
    if t['icona'] == 'filo':
        return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#0a0808"/>'
                f'<circle cx="{cx}" cy="{cy}" r="{r * .94:.1f}" fill="none" stroke="#e3ad1e" stroke-width="{r * .035:.1f}"/>'
                + glifo(nome, cx, cy, r * .95, '#e3ad1e'))
    lato = r * 1.86  # panna: squircle chiaro, simbolo terracotta
    return (f'<rect x="{cx - lato / 2:.1f}" y="{cy - lato / 2:.1f}" width="{lato:.1f}" height="{lato:.1f}" rx="{lato * .3:.1f}" fill="url(#f-panna)"/>'
            + glifo(nome, cx, cy, r * 1.0, '#a8402c'))


def defs(t, sfondi):
    return ('<defs>'
            '<radialGradient id="f-rosso" cx="50%" cy="38%" r="70%"><stop offset="0" stop-color="#a82234"/><stop offset="1" stop-color="#5a0f19"/></radialGradient>'
            '<linearGradient id="oro" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#f6cf5a"/><stop offset=".5" stop-color="#e3ad1e"/><stop offset="1" stop-color="#b8861a"/></linearGradient>'
            '<linearGradient id="f-panna" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fdf3dc"/><stop offset="1" stop-color="#ead2a4"/></linearGradient>'
            '<linearGradient id="velo" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#000" stop-opacity=".45"/><stop offset=".3" stop-color="#000" stop-opacity="0"/>'
            '<stop offset=".75" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".55"/></linearGradient>'
            '<filter id="ombra" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="6" stdDeviation="10" flood-opacity=".45"/></filter>'
            f'<clipPath id="schermo"><rect width="{W}" height="{H}"/></clipPath>'
            '</defs>')


def _jpeg(png_bytes):
    """1440x3200 -> schermo 1080x2340, tagliato sopra e sotto; incorporato
    perche' rsvg non legge file fuori dalla cartella dell'svg."""
    from PIL import Image
    im = Image.open(io.BytesIO(png_bytes)).convert('RGB').resize((W, round(3200 * W / 1440)), Image.LANCZOS)
    y = (im.height - H) // 2
    b = io.BytesIO()
    im.crop((0, y, W, y + H)).save(b, 'JPEG', quality=90)
    return base64.b64encode(b.getvalue()).decode()


@functools.cache
def _sfondo_dati(file):
    return _jpeg(open(file, 'rb').read())


@functools.cache
def _pulito_dati(nome):
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="1440" height="3200" viewBox="0 0 1440 3200">'
           f'{SF.DEFS}{PULITI[nome]()}</svg>')
    return _jpeg(subprocess.run(['rsvg-convert'], input=svg.encode(), check=True, capture_output=True).stdout)


def sfondo_img(t, sfondi, pulito=False):
    dati = _pulito_dati(t['nome']) if pulito else _sfondo_dati(os.path.join(sfondi, 'sfondo-roma-club-matera-' + t['sfondo'] + '.png'))
    return f'<image href="data:image/jpeg;base64,{dati}" x="0" y="0" width="{W}" height="{H}"/>'


def barra(t, chiaro=True):
    c = t['testo'] if chiaro else '#111'
    return (testo(54, 74, '12:30', 36, c, peso=700)
            + f'<g fill="{c}"><rect x="900" y="50" width="10" height="26" rx="2"/><rect x="916" y="42" width="10" height="34" rx="2"/>'
              f'<rect x="932" y="34" width="10" height="42" rx="2"/><rect x="968" y="44" width="62" height="30" rx="7" fill="none" stroke="{c}" stroke-width="3"/>'
              f'<rect x="973" y="49" width="44" height="20" rx="3"/></g>')


def blocco(t, sfondi):
    f = t['orologio']
    notifica = (f'<g filter="url(#ombra)"><rect x="60" y="1640" width="960" height="190" rx="44" fill="{t["superficie"]}" opacity=".92"/></g>'
                + icona(t, 'sports_soccer', 140, 1735, 44)
                + testo(212, 1715, 'Roma Club Matera', 34, t['testo'], peso=700)
                + testo(212, 1765, 'Prenotazione confermata: pullman per Roma-Juventus', 30, t['tenue'])
                + testo(980, 1715, 'ora', 28, t['tenue'], anchor='end'))
    scorciatoie = ''.join(f'<circle cx="{x}" cy="2150" r="70" fill="#000" opacity=".35"/>' + glifo(n, x, 2150, 64, t['testo'])
                          for x, n in ((150, 'call'), (930, 'photo_camera')))
    return (sfondo_img(t, sfondi) + '<rect width="1080" height="2340" fill="url(#velo)"/>' + barra(t)
            + testo(540, 470, '12:30', 230, t['testo'], font=f, peso=300 if f == 'Oswald' else 400, anchor='middle')
            + testo(540, 560, 'DOMENICA 11 OTTOBRE', 38, t['accento'], font='Oswald', peso=500, anchor='middle', sp=8)
            + notifica + scorciatoie
            + testo(540, 2260, 'Scorri per sbloccare', 30, t['testo'], anchor='middle', op=.75))


def home(t, sfondi):
    out = sfondo_img(t, sfondi, pulito=True) + '<rect width="1080" height="2340" fill="url(#velo)"/>' + barra(t)
    # widget del Club: prossima partita
    out += (f'<g filter="url(#ombra)"><rect x="60" y="170" width="960" height="300" rx="56" fill="{t["superficie"]}" opacity=".88"/></g>'
            + testo(110, 250, 'PROSSIMA PARTITA', 30, t['accento'], font='Oswald', peso=500, sp=6)
            + testo(110, 340, 'Como – Roma', 72, t['testo'], font='Oswald', peso=600)
            + testo(110, 410, 'Domenica 12:30 · visione in sede dalle 12:00', 32, t['tenue']))
    for i, (n, nome) in enumerate(APP[4:12]):
        x, y = 150 + (i % 4) * 260, 1240 + (i // 4) * 300
        out += icona(t, n, x, y) + testo(x, y + 135, nome, 30, t['testo'], anchor='middle')
    out += (f'<rect x="60" y="1880" width="960" height="110" rx="55" fill="#000" opacity=".3"/>'
            + glifo('search', 130, 1935, 52, t['testo']) + testo(180, 1948, 'Cerca', 34, t['testo'], op=.8))
    out += ''.join(icona(t, n, 150 + i * 260, 2130) for i, (n, _) in enumerate(APP[:4]))
    return out


def icone(t, sfondi):
    out = f'<rect width="{W}" height="{H}" fill="{t["fondo"]}"/>' + barra(t)
    out += (testo(540, 260, 'ICONE', 64, t['accento'], font='Cinzel', peso=700, anchor='middle', sp=10)
            + testo(540, 330, f'Tema «{t["nome"]}» · Roma Club Matera', 32, t['tenue'], anchor='middle'))
    for i, (n, nome) in enumerate(APP):
        x, y = 150 + (i % 4) * 260, 520 + (i // 4) * 340
        out += icona(t, n, x, y) + testo(x, y + 140, nome, 30, t['testo'], anchor='middle')
    return out


def telefono(t, sfondi):
    out = f'<rect width="{W}" height="{H}" fill="{t["fondo"]}"/>' + barra(t)
    out += (testo(540, 560, '377 281 4538', 92, t['testo'], peso=300, anchor='middle', sp=2)
            + testo(540, 640, 'Roma Club Matera', 36, t['accento'], anchor='middle'))
    tasti = [('1', ''), ('2', 'ABC'), ('3', 'DEF'), ('4', 'GHI'), ('5', 'JKL'), ('6', 'MNO'),
             ('7', 'PQRS'), ('8', 'TUV'), ('9', 'WXYZ'), ('*', ''), ('0', '+'), ('#', '')]
    for i, (n, l) in enumerate(tasti):
        x, y = 240 + (i % 3) * 300, 960 + (i // 3) * 250
        bordo = t['accento'] if t['icona'] == 'filo' else 'none'
        out += (f'<circle cx="{x}" cy="{y}" r="104" fill="{t["superficie"]}" stroke="{bordo}" stroke-width="3"/>'
                + testo(x, y + 18, n, 70, t['testo'], peso=400, anchor='middle')
                + (testo(x, y + 62, l, 22, t['tenue'], anchor='middle', sp=3) if l else ''))
    out += (f'<circle cx="540" cy="2000" r="110" fill="{t["accento"]}"/>' + glifo('call', 540, 2000, 96, t['fondo']))
    schede = [('schedule', 'Recenti'), ('contacts', 'Contatti'), ('call', 'Tastiera')]
    for i, (n, nome) in enumerate(schede):
        x = 200 + i * 340
        c = t['accento'] if nome == 'Tastiera' else t['tenue']
        out += glifo(n, x, 2190, 54, c) + testo(x, 2260, nome, 26, c, anchor='middle')
    return out


def messaggi(t, sfondi):
    out = f'<rect width="{W}" height="{H}" fill="{t["fondo"]}"/>' + barra(t)
    out += (f'<rect x="0" y="110" width="{W}" height="170" fill="{t["superficie"]}"/>'
            + icona(t, 'sports_soccer', 120, 195, 50)
            + testo(200, 185, 'Roma Club Matera', 40, t['testo'], peso=700)
            + testo(200, 235, 'Direttivo', 28, t['tenue']))

    def fumetto(y, righe, mio):
        w = max(len(r) for r in righe) * 21 + 70
        h = len(righe) * 52 + 40
        x = W - 60 - w if mio else 60
        col = t['accento'] if mio else t['superficie']
        tc = t['fondo'] if mio else t['testo']
        return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="38" fill="{col}"/>'
                + ''.join(testo(x + 35, y + 62 + k * 52, r, 34, tc) for k, r in enumerate(righe)))
    out += fumetto(400, ['Ciao! Domenica Como-Roma:', 'sede aperta dalle 12:00'], False)
    out += fumetto(600, ['Perfetto, ci sono!'], True)
    out += fumetto(760, ['Per Roma-Juventus il pullman', 'parte alle 14:00 da via', 'Lupo Protospata'], False)
    out += fumetto(1020, ['Prenotato! Forza Roma'], True)
    out += testo(540, 1240, 'Oggi 12:31', 26, t['tenue'], anchor='middle')
    out += (f'<rect x="40" y="2090" width="860" height="120" rx="60" fill="{t["superficie"]}"/>'
            + testo(100, 2165, 'Messaggio', 34, t['tenue'])
            + f'<circle cx="980" cy="2150" r="62" fill="{t["accento"]}"/>' + glifo('send', 984, 2150, 60, t['fondo']))
    return out


def pannello(t, sfondi):
    out = sfondo_img(t, sfondi, pulito=True) + f'<rect width="{W}" height="{H}" fill="{t["fondo"]}" opacity=".82"/>' + barra(t)
    out += (testo(60, 230, '12:30', 110, t['testo'], font=t['orologio'], peso=300)
            + testo(60, 300, 'domenica 11 ottobre', 34, t['tenue']))
    tile = [('Wi-Fi', True), ('Bluetooth', True), ('Silenzioso', False), ('Torcia', False),
            ('Rotazione', True), ('Aereo', False), ('Risparmio', False), ('Posizione', True)]
    nomi = {'Wi-Fi': 'public', 'Bluetooth': 'headphones', 'Silenzioso': 'mic', 'Torcia': 'partly_cloudy_day',
            'Rotazione': 'schedule', 'Aereo': 'send', 'Risparmio': 'favorite', 'Posizione': 'map'}
    for i, (nome, on) in enumerate(tile):
        x, y = 150 + (i % 4) * 260, 480 + (i // 4) * 260
        out += (f'<circle cx="{x}" cy="{y}" r="88" fill="{t["accento"] if on else t["superficie"]}"/>'
                + glifo(nomi[nome], x, y, 76, t['fondo'] if on else t['testo'])
                + testo(x, y + 140, nome, 28, t['testo'], anchor='middle'))
    out += (f'<rect x="60" y="1040" width="960" height="90" rx="45" fill="{t["superficie"]}"/>'
            f'<rect x="60" y="1040" width="620" height="90" rx="45" fill="{t["accento"]}"/>'
            + glifo('partly_cloudy_day', 120, 1085, 50, t['fondo']))
    # una notifica e il lettore musicale
    out += (f'<rect x="60" y="1200" width="960" height="250" rx="44" fill="{t["superficie"]}"/>'
            + icona(t, 'headphones', 160, 1325, 60)
            + testo(260, 1300, 'Grazie Roma', 40, t['testo'], peso=700)
            + testo(260, 1355, 'Antonello Venditti', 30, t['tenue'])
            + f'<rect x="260" y="1390" width="700" height="8" rx="4" fill="{t["tenue"]}" opacity=".4"/>'
              f'<rect x="260" y="1390" width="300" height="8" rx="4" fill="{t["accento"]}"/>')
    out += (f'<rect x="60" y="1490" width="960" height="190" rx="44" fill="{t["superficie"]}"/>'
            + icona(t, 'sports_soccer', 140, 1585, 44)
            + testo(212, 1565, 'Roma Club Matera', 34, t['testo'], peso=700)
            + testo(212, 1615, 'Domani si parte per l’Olimpico!', 30, t['tenue']))
    return out


SCHERMATE = [('Blocco', blocco), ('Home', home), ('Icone', icone), ('Telefono', telefono),
             ('Messaggi', messaggi), ('Pannello rapido', pannello)]


def schermo(t, f, sfondi):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
            + defs(t, sfondi) + f'<g clip-path="url(#schermo)">{f(t, sfondi)}</g></svg>')


def tavola(t, i, png):
    """Una pagina per tema: titolo e le 6 schermate in un telefono stilizzato."""
    PW, PH = 3508, 2480  # A4 orizzontale a 300 dpi
    lw, passo = 480, 540  # schermo scalato e distanza fra i telefoni
    lh = lw * H / W
    x0 = (PW - 5 * passo - lw) / 2
    out = (f'<svg xmlns="http://www.w3.org/2000/svg" width="297mm" height="210mm" viewBox="0 0 {PW} {PH}">'
           f'<rect width="{PW}" height="{PH}" fill="#14080a"/>'
           + testo(160, 260, f'{i}. {t["nome"].upper()}', 110, '#e3ad1e', font='Cinzel', peso=700, sp=8)
           + testo(160, 350, t['motto'], 50, '#f6ecd0', op=.85)
           + testo(PW - 160, 260, 'Roma Club Matera «Francesco Totti»', 46, '#f6ecd0', anchor='end', op=.8))
    for k, (nome, _) in enumerate(SCHERMATE):
        x = x0 + k * passo
        y = 640
        out += (f'<rect x="{x - 18}" y="{y - 18}" width="{lw + 36}" height="{lh + 36}" rx="70" fill="#000"/>'
                f'<clipPath id="c{k}"><rect x="{x}" y="{y}" width="{lw}" height="{lh}" rx="54"/></clipPath>'
                f'<image href="file://{png[k]}" x="{x}" y="{y}" width="{lw}" height="{lh}" clip-path="url(#c{k})"/>'
                + testo(x + lw / 2, y + lh + 120, nome.upper(), 44, '#e3ad1e', font='Oswald', peso=500, anchor='middle', sp=6))
    out += testo(160, PH - 140, 'Icone: Material Symbols (Apache 2.0) su disegni originali · caratteri Lato, Oswald, Cinzel (OFL) · '
                 'nessun marchio di terzi', 34, '#f6ecd0', op=.55)
    return out + '</svg>'


def _stemma():
    png = subprocess.run(['rsvg-convert', '-w', '1040', os.path.join(QUI, '..', 'sfondi', 'stemma.svg')], check=True, capture_output=True).stdout
    return base64.b64encode(png).decode()


def copertina():
    PW, PH = 3508, 2480
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="297mm" height="210mm" viewBox="0 0 {PW} {PH}">'
            f'<rect width="{PW}" height="{PH}" fill="#14080a"/>'
            f'<image href="data:image/png;base64,{_stemma()}" x="{PW / 2 - 260}" y="420" width="520" height="602"/>'
            + testo(PW / 2, 1300, 'ROMA CLUB MATERA', 130, '#e3ad1e', font='Cinzel', peso=700, anchor='middle', sp=16)
            + testo(PW / 2, 1420, '«FRANCESCO TOTTI»', 70, '#f6ecd0', font='Oswald', peso=400, anchor='middle', sp=12)
            + f'<rect x="{PW / 2 - 300}" y="1500" width="600" height="5" fill="#e3ad1e"/>'
            + testo(PW / 2, 1650, 'Portfolio Galaxy Themes · 3 temi × 6 schermate', 64, '#f6ecd0', anchor='middle')
            + testo(PW / 2, 1760, 'Giallorosso · Notte · Matera', 54, '#e3ad1e', font='Oswald', anchor='middle', sp=6)
            + testo(PW / 2, 2200, 'romaclubmatera.it', 46, '#f6ecd0', anchor='middle', op=.7)
            + '</svg>')


def main():
    sfondi, pdf = os.path.abspath(sys.argv[1]), os.path.abspath(sys.argv[2])
    with tempfile.TemporaryDirectory() as tmp:
        pagine = [os.path.join(tmp, '0-copertina.svg')]
        open(pagine[0], 'w').write(copertina())
        for i, t in enumerate(TEMI, 1):
            png = []
            for k, (nome, f) in enumerate(SCHERMATE):
                s = os.path.join(tmp, f'{i}-{k}.svg')
                open(s, 'w').write(schermo(t, f, sfondi))
                p = s[:-4] + '.png'
                subprocess.run(['rsvg-convert', s, '-o', p], check=True)
                png.append(p)
                # le singole schermate servono anche da sole (anteprime)
                if len(sys.argv) > 3:
                    os.makedirs(sys.argv[3], exist_ok=True)
                    subprocess.run(['cp', p, os.path.join(sys.argv[3], f'{i}-{t["nome"].lower()}-{k + 1}-{nome.lower().replace(" ", "-")}.png')])
            pagina = os.path.join(tmp, f'{i}-tavola.svg')
            open(pagina, 'w').write(tavola(t, i, png))
            pagine.append(pagina)
        subprocess.run(['rsvg-convert', '-f', 'pdf', '-o', pdf] + pagine, check=True)
    print(pdf)


if __name__ == '__main__':
    main()
