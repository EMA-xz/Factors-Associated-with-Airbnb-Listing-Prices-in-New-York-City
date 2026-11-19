"""Check the documents against their R payload; this is not a layout validator."""
import hashlib,json,re,zipfile
from pathlib import Path
from lxml import etree
from pypdf import PdfReader

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'reports/final_report'
payload=json.loads((OUT/'report_payload.json').read_text())
checks=[]
def check(name,ok):
    checks.append({'check':name,'passed':bool(ok)})
    if not ok: raise AssertionError(name)
def norm(s):
    return re.sub(r'\s+','',str(s)).replace('\u2018',"'").replace('\u2019',"'")
r=PdfReader(OUT/'final_report.pdf')
check('PDF has ten pages',len(r.pages)==10)
with zipfile.ZipFile(OUT/'final_report.docx') as z:
    xml=etree.fromstring(z.read('word/document.xml'))
    ns={'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
    docxtext=''.join(xml.xpath('//w:t/text()',namespaces=ns))
    check('DOCX has nine explicit page breaks',len(xml.xpath('//w:br[@w:type="page"]',namespaces=ns))==9)
    embedded={hashlib.sha256(z.read(n)).hexdigest() for n in z.namelist() if n.startswith('word/media/')}
for i,page in enumerate(payload['pages']):
    pdftext=norm(r.pages[i].extract_text())
    check(f'Page {i+1} title',norm(page['title']) in pdftext)
    texts=[]
    for block in page['blocks']:
        if block['type']=='figure':
            f=ROOT/block['file'];check(f'Figure embedded unchanged {f.name}',hashlib.sha256(f.read_bytes()).hexdigest() in embedded)
        elif block['type']=='table':
            texts.extend(block['headers'])
            for row in block['rows']:texts.extend(row)
        else:texts.append(block['text'])
    check(f'Page {i+1} PDF content equals R payload',all(norm(t) in pdftext for t in texts))
    check(f'Page {i+1} DOCX content equals R payload',all(norm(t) in norm(docxtext) for t in texts))
check('Payload source hash matches pinned raw file',hashlib.md5((ROOT/'data/raw/nyc_listings_2026-09-14.csv.gz').read_bytes()).hexdigest()==payload['source_md5'])
check('Payload model lock matches current lock',hashlib.md5((ROOT/'config/final_model_lock.json').read_bytes()).hexdigest()==payload['model_lock_md5'])
report={'checks':checks,'all_passed':all(c['passed'] for c in checks),'team_complete':payload['team_complete'],
        'pdf_pages':len(r.pages),'note':'Numerical consistency and document content checks do not prove statistical-model assumptions or team readiness.'}
(OUT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(f"Passed {len(checks)} document checks. Team metadata complete: {payload['team_complete']}.")
