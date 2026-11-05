#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Agrega pie de página con numeración y metadatos al PDF generado por Chrome.

Uso:
    python F6_Assets/stamp_pdf.py F6_Cumplimiento_Hardening.pdf

El PDF de entrada se reemplaza por una versión sellada. La portada no lleva
número; el resto se numera como "Página N de TOTAL".
"""

import io
import os
import sys

from PyPDF2 import PdfReader, PdfWriter
from reportlab.lib.colors import Color
from reportlab.pdfgen import canvas

TITLE = "F6 · Cumplimiento Normativo y Hardening"
AUTHOR = "Proyecto Final · Seguridad Informática 2026"
SUBJECT = "Evaluación SCA, hallazgos y hardening sobre agentes Wazuh 4.9.2"
KEYWORDS = "Wazuh, SCA, CIS, PCI DSS, HIPAA, NIST 800-53, GDPR, hardening"


def make_overlay(width, height, page_number, total_pages):
    packet = io.BytesIO()
    c = canvas.Canvas(packet, pagesize=(width, height))

    gray = Color(0.42, 0.48, 0.55)
    line = Color(0.78, 0.84, 0.89)

    left = 45
    right = width - 45
    c.setStrokeColor(line)
    c.setLineWidth(0.6)
    c.line(left, 30, right, 30)

    c.setFillColor(gray)
    c.setFont("Helvetica", 7.2)
    c.drawString(left, 18, "F6 · Cumplimiento Normativo y Hardening")

    label = f"Página {page_number} de {total_pages}"
    c.drawRightString(right, 18, label)

    c.save()
    packet.seek(0)
    return PdfReader(packet).pages[0]


def main():
    if len(sys.argv) != 2:
        print("Uso: python F6_Assets/stamp_pdf.py <archivo.pdf>")
        return 1

    src = os.path.abspath(sys.argv[1])
    if not os.path.exists(src):
        print(f"No existe: {src}")
        return 1

    reader = PdfReader(src)
    total = len(reader.pages)
    writer = PdfWriter()

    for index, page in enumerate(reader.pages):
        if index > 0:
            width = float(page.mediabox.width)
            height = float(page.mediabox.height)
            overlay = make_overlay(width, height, index + 1, total)
            page.merge_page(overlay)
        writer.add_page(page)

    writer.add_metadata({
        "/Title": TITLE,
        "/Author": AUTHOR,
        "/Subject": SUBJECT,
        "/Keywords": KEYWORDS,
        "/Creator": "Pandoc 3.9 + Chrome headless + PyPDF2",
        "/Producer": "Pandoc 3.9 + Chrome headless",
    })

    tmp = src + ".tmp"
    with open(tmp, "wb") as fh:
        writer.write(fh)
    os.replace(tmp, src)

    print(f"OK: {src}")
    print(f"Páginas: {total}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
