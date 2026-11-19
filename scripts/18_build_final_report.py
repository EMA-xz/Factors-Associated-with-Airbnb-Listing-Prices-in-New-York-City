"""Render the R-generated report payload to editable DOCX and standalone PDF.

Run after scripts/17_prepare_final_report.R, from the repository root.
No analytical statistics are calculated or inserted manually by this renderer.
"""
import json
from pathlib import Path
from xml.sax.saxutils import escape
from datetime import datetime, timezone
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

from PIL import Image as PILImage
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Image, Table, TableStyle, PageBreak, Preformatted
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen.canvas import Canvas

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "reports/final_report"
payload = json.loads((OUT / "report_payload.json").read_text())
assert len(payload["pages"]) == 10
assert sum(b["type"] == "figure" for p in payload["pages"] for b in p["blocks"]) == 7
assert all((ROOT / b["file"]).exists() for p in payload["pages"] for b in p["blocks"] if b["type"] == "figure")

def add_field(paragraph, name):
    field = OxmlElement("w:fldSimple")
    field.set(qn("w:instr"), name)
    paragraph._p.append(field)

def docx_table(doc, block):
    table = doc.add_table(rows=1, cols=len(block["headers"]))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    for col, width in zip(table.columns, block["widths"]):
        col.width = Inches(width)
    for idx, text in enumerate(block["headers"]):
        table.rows[0].cells[idx].text = text
    for row in block["rows"]:
        cells = table.add_row().cells
        for idx, text in enumerate(row):
            cells[idx].text = str(text)
    borders = OxmlElement("w:tblBorders")
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        e = OxmlElement("w:" + edge)
        for k, v in {"val":"single", "sz":"4", "color":"D9D9D9"}.items():
            e.set(qn("w:"+k),v)
        borders.append(e)
    table._tbl.tblPr.append(borders)
    for ri, row in enumerate(table.rows):
        trpr = row._tr.get_or_add_trPr()
        no_split = OxmlElement("w:cantSplit")
        trpr.append(no_split)
        if ri == 0:
            trpr.append(OxmlElement("w:tblHeader"))
        for ci, cell in enumerate(row.cells):
            cell.width = Inches(block["widths"][ci])
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            props = cell._tc.get_or_add_tcPr()
            margins = OxmlElement("w:tcMar")
            for edge in ("top","bottom","left","right"):
                e = OxmlElement("w:"+edge)
                e.set(qn("w:w"), "65")
                e.set(qn("w:type"), "dxa")
                margins.append(e)
            props.append(margins)
            if ri == 0:
                shade = OxmlElement("w:shd")
                shade.set(qn("w:fill"), "E8EBEE")
                props.append(shade)
            for para in cell.paragraphs:
                para.alignment = WD_ALIGN_PARAGRAPH.LEFT if ci == 0 else WD_ALIGN_PARAGRAPH.RIGHT
                para.paragraph_format.space_after = Pt(0)
                para.paragraph_format.line_spacing = 1.0
                for run in para.runs:
                    run.font.size = Pt(9)
                    run.font.bold = ri == 0
    doc.add_paragraph().paragraph_format.space_after = Pt(1)

def build_docx():
    doc = Document()
    sec = doc.sections[0]
    sec.page_width, sec.page_height = Inches(8.5), Inches(11)
    sec.top_margin = sec.bottom_margin = Inches(.65)
    sec.left_margin = sec.right_margin = Inches(.7)
    sec.footer_distance = Inches(.3)
    for name in ("Normal","Title","Subtitle","Heading 1","Heading 2"):
        style = doc.styles[name]
        style.font.name = "Times New Roman"
        style.font.color.rgb = RGBColor(0,0,0)
        style.font.underline = False
        fonts = style.element.get_or_add_rPr().get_or_add_rFonts()
        for attr in list(fonts.attrib):
            if "theme" in attr.lower():
                del fonts.attrib[attr]
        for attr in ("ascii", "hAnsi", "eastAsia", "cs"):
            fonts.set(qn("w:"+attr), "Times New Roman")
    # Some bundled Word templates carry a blue title rule in style inheritance.
    # Remove paragraph borders explicitly rather than relying on theme defaults.
    for style in doc.styles:
        for border in list(style.element.iter(qn("w:pBdr"))):
            border.getparent().remove(border)
    normal = doc.styles["Normal"]
    normal.font.size = Pt(11)
    normal.paragraph_format.line_spacing = 1.07
    normal.paragraph_format.space_after = Pt(7)
    for name, size in (("Title",19),("Heading 1",16),("Heading 2",12)):
        s=doc.styles[name]; s.font.size=Pt(size); s.font.bold=True
        s.paragraph_format.space_before=Pt(4); s.paragraph_format.space_after=Pt(8)
    footer = sec.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    add_field(footer,"PAGE")
    for i,page in enumerate(payload["pages"]):
        if i: doc.add_page_break()
        doc.add_paragraph(page["title"],"Title" if i==0 else "Heading 1")
        for b in page["blocks"]:
            kind=b["type"]
            if kind=="heading": doc.add_paragraph(b["text"],"Heading 2")
            elif kind=="table": docx_table(doc,b)
            elif kind=="figure":
                p=doc.add_paragraph();p.alignment=WD_ALIGN_PARAGRAPH.CENTER
                p.paragraph_format.space_after=Pt(7)
                shape=p.add_run().add_picture(str(ROOT/b["file"]),width=Inches(b["width"]))
                shape._inline.docPr.set("descr",Path(b["file"]).stem.replace("_"," "))
            elif kind=="verbatim":
                p=doc.add_paragraph()
                p.paragraph_format.space_after=Pt(7)
                p.paragraph_format.line_spacing=1.02
                run=p.add_run(b["text"].expandtabs(4))
                run.font.name="Courier New"
                run.font.size=Pt(8)
            elif kind=="numbered":
                for j,t in enumerate(b["items"],1):
                    p=doc.add_paragraph(f"{j}. {t}")
                    p.paragraph_format.space_after=Pt(3)
            else:
                p=doc.add_paragraph(b["text"])
                if kind in ("small","subtitle"):
                    for r in p.runs: r.font.size=Pt(9 if kind=="small" else 10.5)
    doc.core_properties.title = payload["title"]
    doc.core_properties.author = ""
    doc.core_properties.created = datetime(2026,11,19,tzinfo=timezone.utc)
    doc.core_properties.modified = datetime(2026,11,19,tzinfo=timezone.utc)
    path=OUT/"final_report.docx"
    doc.save(path)
    # Fixed ZIP metadata makes repeated builds byte-identical in this environment.
    with ZipFile(path) as z: entries={n:z.read(n) for n in z.namelist()}
    with ZipFile(path,"w",ZIP_DEFLATED) as z:
        for n in sorted(entries):
            info=ZipInfo(n,date_time=(2026,11,19,0,0,0));info.compress_type=ZIP_DEFLATED
            z.writestr(info,entries[n])

body=ParagraphStyle("Body",fontName="Times-Roman",fontSize=11,leading=13.2,spaceAfter=7)
small=ParagraphStyle("Small",parent=body,fontSize=9,leading=10.5,spaceAfter=5)
title=ParagraphStyle("Title",parent=body,fontName="Times-Bold",fontSize=19,leading=22,spaceAfter=9)
page_title=ParagraphStyle("PageTitle",parent=title,fontSize=16,leading=19)
section_title=ParagraphStyle("Heading",parent=body,fontName="Times-Bold",fontSize=12,leading=14,spaceBefore=5,spaceAfter=6,keepWithNext=True)
cell_style=ParagraphStyle("Cell",parent=small,fontSize=9,leading=10,spaceAfter=0)
cell_right=ParagraphStyle("CellRight",parent=cell_style,alignment=2)

def para(text,style=body):
    return Paragraph(escape(str(text)).replace("\n","<br/>"),style)

def page_footer(canvas,doc):
    canvas.saveState();canvas.setFont("Times-Roman",9)
    canvas.drawCentredString(letter[0]/2,22,str(doc.page));canvas.restoreState()

def stable_canvas(*args, **kwargs):
    kwargs["invariant"] = 1
    return Canvas(*args, **kwargs)

def build_pdf():
    content=[]
    for i,page in enumerate(payload["pages"]):
        if i:content.append(PageBreak())
        content.append(para(page["title"],title if i==0 else page_title))
        for b in page["blocks"]:
            kind=b["type"]
            if kind=="heading": content.append(para(b["text"],section_title))
            elif kind=="verbatim":
                content.append(Preformatted(b["text"].expandtabs(4),ParagraphStyle("Code",fontName="Courier",fontSize=8,leading=9.1,spaceAfter=8)))
            elif kind=="numbered":
                for j,t in enumerate(b["items"],1):content.append(para(f"{j}. {t}"))
            elif kind=="figure":
                path=ROOT/b["file"]
                with PILImage.open(path) as im:w,h=im.size
                content.append(Image(str(path),width=b["width"]*72,height=b["width"]*72*h/w))
                content.append(Spacer(1,7))
            elif kind=="table":
                rows=[b["headers"]]+b["rows"]
                data=[[para(x,cell_style if j==0 else cell_right) for j,x in enumerate(row)] for row in rows]
                table=Table(data,colWidths=[w*72 for w in b["widths"]],hAlign="CENTER",repeatRows=1)
                table.setStyle(TableStyle([("BACKGROUND",(0,0),(-1,0),colors.HexColor("#E8EBEE")),
                    ("GRID",(0,0),(-1,-1),.4,colors.HexColor("#D9D9D9")),
                    ("VALIGN",(0,0),(-1,-1),"MIDDLE"),
                    ("TOPPADDING",(0,0),(-1,-1),4),("BOTTOMPADDING",(0,0),(-1,-1),4),
                    ("LEFTPADDING",(0,0),(-1,-1),5),("RIGHTPADDING",(0,0),(-1,-1),5)]))
                content.extend([table,Spacer(1,7)])
            else:content.append(para(b["text"],small if kind=="small" else body))
    doc=SimpleDocTemplate(str(OUT/"final_report.pdf"),pagesize=letter,
        rightMargin=.7*72,leftMargin=.7*72,topMargin=.65*72,bottomMargin=.65*72,
        title=payload["title"],author="")
    doc.build(content,onFirstPage=page_footer,onLaterPages=page_footer,canvasmaker=stable_canvas)

build_docx()
build_pdf()
print("Created final_report.docx and final_report.pdf from the R payload.")
print("Team metadata complete:",payload["team_complete"])
