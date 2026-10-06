#!/usr/bin/env python3
"""Icone del tema: simbolo oro su tondo rosso con filetto oro.

Uso: icone/genera.py <cartella res di Android>
Scrive drawable-nodpi/rcm_*.png (192x192), xml/appfilter.xml, xml/drawable.xml
e values/iconpack.xml. I simboli sono Material Symbols Rounded (Apache 2.0),
scaricati una volta in icone/simboli/ e poi riusati. Le app che non sono in
app.py prendono la cornice (iconback + scala), cosi' tutto resta uniforme.
"""
import base64, os, re, subprocess, sys, tempfile, urllib.request
from collections import Counter
from app import ICONE

QUI = os.path.dirname(os.path.abspath(__file__))
SIMBOLI = os.path.join(QUI, 'simboli')
STEMMA = os.path.join(QUI, '..', 'sfondi', 'stemma.svg')
URL = 'https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web/{0}/materialsymbolsrounded/{0}_fill1_24px.svg'
LATO = 192
COMPONENTI = os.path.join(QUI, 'componenti.txt')  # pacchetto/attivita', uno per riga

FONDO = '''<defs>
<radialGradient id="f" cx="50%" cy="38%" r="70%"><stop offset="0" stop-color="#a82234"/><stop offset="1" stop-color="#5a0f19"/></radialGradient>
<linearGradient id="o" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#f6cf5a"/><stop offset=".5" stop-color="#e3ad1e"/><stop offset="1" stop-color="#b8861a"/></linearGradient>
</defs>
<circle cx="96" cy="96" r="92" fill="url(#f)"/>
<circle cx="96" cy="96" r="84" fill="none" stroke="url(#o)" stroke-width="3.5"/>'''


def simbolo(nome):
    os.makedirs(SIMBOLI, exist_ok=True)
    f = os.path.join(SIMBOLI, nome + '.svg')
    if not os.path.exists(f):
        urllib.request.urlretrieve(URL.format(nome), f)
    d = re.findall(r'<path[^>]*\sd="([^"]+)"', open(f).read())
    if not d:
        sys.exit(f'simbolo {nome}: nessun path')
    return d


def svg_icona(nome):
    if nome == 'STEMMA':
        # rsvg non legge file fuori dalla cartella dell'svg: stemma incorporato
        b = base64.b64encode(subprocess.run(['rsvg-convert', '-w', '320', STEMMA], check=True, capture_output=True).stdout).decode()
        corpo = f'<image href="data:image/png;base64,{b}" x="55" y="48" width="82" height="{82 * 1611 / 1392:.0f}"/>'
    else:
        # viewBox dei simboli: 0 -960 960 960 -> 96 px al centro
        s = 96 / 960
        corpo = (f'<g transform="translate(48 {48 + 96}) scale({s})">'
                 + ''.join(f'<path d="{d}" fill="url(#o)"/>' for d in simbolo(nome)) + '</g>')
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{LATO}" height="{LATO}" viewBox="0 0 192 192">{FONDO}{corpo}</svg>'


def png(svg, dest, tmp):
    f = os.path.join(tmp, 'i.svg')
    open(f, 'w').write(svg)
    subprocess.run(['rsvg-convert', f, '-o', dest], check=True)


def main():
    res = os.path.abspath(sys.argv[1])
    for d in ('drawable-nodpi', 'xml', 'values'):
        os.makedirs(os.path.join(res, d), exist_ok=True)
    comp = [r.strip() for r in open(COMPONENTI) if r.strip()]
    filtro, disegni = [], []
    with tempfile.TemporaryDirectory() as tmp:
        png(f'<svg xmlns="http://www.w3.org/2000/svg" width="{LATO}" height="{LATO}" viewBox="0 0 192 192">{FONDO}</svg>',
            os.path.join(res, 'drawable-nodpi', 'rcm_cornice.png'), tmp)
        for chiave, (nome, pacchetti) in ICONE.items():
            dn = 'rcm_' + chiave
            png(svg_icona(nome), os.path.join(res, 'drawable-nodpi', dn + '.png'), tmp)
            disegni.append(dn)
            for c in comp:
                if c.split('/')[0] in pacchetti:
                    filtro.append(f'  <item component="ComponentInfo{{{c}}}" drawable="{dn}"/>')
    with open(os.path.join(res, 'xml', 'appfilter.xml'), 'w') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                '  <iconback img1="rcm_cornice"/>\n  <scale factor="0.62"/>\n'
                + '\n'.join(filtro) + '\n</resources>\n')
    with open(os.path.join(res, 'xml', 'drawable.xml'), 'w') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n  <version>1</version>\n  <category title="Roma Club Matera"/>\n'
                + ''.join(f'  <item drawable="{d}"/>\n' for d in disegni) + '</resources>\n')
    with open(os.path.join(res, 'values', 'iconpack.xml'), 'w') as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n  <string-array name="icon_pack" translatable="false">\n'
                + ''.join(f'    <item>{d}</item>\n' for d in disegni) + '  </string-array>\n</resources>\n')
    usati = Counter(r.split('drawable="')[1].rstrip('"/>') for r in filtro)
    print(f'{len(disegni)} icone, {len(filtro)} componenti nel filtro')
    for d in disegni:
        if not usati[d]:
            print('  senza componenti:', d)


if __name__ == '__main__':
    main()
