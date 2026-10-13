"""Draws every PDF in build/test_pdfs/ (made by test/doc_pdf_test.dart) as a picture so a person can look at them.
Needs PyMuPDF (pip install pymupdf). Not part of the app and not needed by CI.
    python tool/pdf_check.py            ->  build/test_pdfs/<name>-<page>.png
"""
import pathlib
import sys

try:
    import pymupdf as fitz
except ImportError:  # older name
    import fitz  # type: ignore

root = pathlib.Path("build/test_pdfs")
for pdf in sorted(root.glob("*.pdf")):
    doc = fitz.open(pdf)
    for i, page in enumerate(doc):
        pix = page.get_pixmap(matrix=fitz.Matrix(2, 2))
        out = root / f"{pdf.stem}-{i + 1}.png"
        pix.save(out)
        r = page.rect
        print(f"{pdf.name}: page {i + 1}/{len(doc)} {r.width:.0f}x{r.height:.0f} pt -> {out.name}")
