"""Makes assets/fonts/Inter-Bold.ttf (a fixed bold copy of the Inter variable font) for the PDFs, because the PDF library cannot
pick a weight inside a variable font. Needs fonttools (pip install fonttools). Run once; the result is committed.
Inter is licensed under the SIL Open Font License 1.1.
    python tool/make_bold_font.py
"""
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

vf = TTFont("assets/fonts/Inter-Variable.ttf")
axes = {a.axisTag: a for a in vf["fvar"].axes}
loc = {"wght": 700.0}
if "opsz" in axes:
    loc["opsz"] = axes["opsz"].defaultValue
bold = instancer.instantiateVariableFont(vf, loc)
bold.save("assets/fonts/Inter-Bold.ttf")
print("wrote assets/fonts/Inter-Bold.ttf", loc)
