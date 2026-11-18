"""Check source integrity, host isolation, subset consistency and rendered report content.

This is not a statistical-model validation or a replacement for visual inspection.
"""
import csv
import hashlib
import json
import re
from pathlib import Path
from zipfile import ZipFile
from collections import Counter, defaultdict
from docx import Document
from pypdf import PdfReader

root=Path(__file__).resolve().parents[1]
out=root/"reports/project_description"
read_csv=lambda p:list(csv.DictReader((root/p).open(newline="")))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
checks=[]
def check(condition,name):
    if not condition: raise AssertionError(name)
    checks.append(name)
manifest=read_csv("reports/audit/source_manifest.csv")[0]
raw_path=root/manifest["local_file"]
check(sha(raw_path)==manifest["sha256_at_acquisition"],"Raw snapshot SHA256 matches provenance")
primary=read_csv("data/processed/model_primary.csv")
sensitivity=read_csv("data/processed/model_without_hotel_labels.csv")
host_split=read_csv("data/processed/host_split.csv")
hosts={r["host_id"]:r["partition"] for r in host_split}
check(len(hosts)==len(host_split),"One split assignment per host")
check(all(r["host_id"] in hosts and r["partition"]==hosts[r["host_id"]] for r in primary),"All primary records inherit their host assignment")
train_hosts={r["host_id"] for r in primary if r["partition"]=="train"}
test_hosts={r["host_id"] for r in primary if r["partition"]=="test"}
check(not train_hosts & test_hosts,"No host appears in both partitions")
by_id={r["id"]:r for r in primary}
check(len(by_id)==len(primary),"Primary listing IDs are unique")
check(all(r["id"] in by_id and r==by_id[r["id"]] for r in sensitivity),"Sensitivity records are unchanged primary-sample records")
check(all(not re.search("hotel|hostel|resort",r["property_type"],re.I) and r["property_type"]!="Missing" for r in sensitivity),"Sensitivity label exclusions are correctly applied")
split_expected=[]
for name,records in (("primary",primary),("without_hotel_labels",sensitivity)):
    groups=defaultdict(list)
    for r in records: groups[(r["partition"],r["borough"],r["room_type"])].append(r)
    check(len(groups)==8,f"{name} retains all four study groups in both partitions")
    for key,rows in groups.items():
        split_expected.append((name,*key,len(rows),len({r["host_id"] for r in rows})))
split_actual=[(r["sample"],r["partition"],r["borough"],r["room_type"],int(r["listings_n"]),int(r["hosts_n"]))
              for r in read_csv("reports/model_preparation/split_counts_by_group.csv")]
check(sorted(split_actual)==sorted(split_expected),"Published split counts reconcile with row-level data")
payload=json.loads((out/"report_payload.json").read_text())
doc=Document(out/"project_description.docx")
normalize=lambda t:" ".join(t.split())
text=normalize(" ".join([p.text for p in doc.paragraphs]+[c.text for t in doc.tables for row in t.rows for c in row.cells]))
for page in payload["pages"]:
    check(normalize(page["title"]) in text,f"DOCX includes page title: {page['title']}")
    for b in page["blocks"]:
        if "text" in b:check(normalize(b["text"]) in text,"DOCX includes payload text")
        if b["type"]=="numbered":
            check(all(normalize(t) in text for t in b["items"]),"DOCX includes research questions")
        if b["type"]=="table":
            check(all(normalize(str(t)) in text for row in b["rows"] for t in row),"DOCX includes every generated table value")
figures=[root/b["file"] for p in payload["pages"] for b in p["blocks"] if b["type"]=="figure"]
with ZipFile(out/"project_description.docx") as z:
    images=[z.read(n) for n in z.namelist() if n.startswith("word/media/")]
    styles=z.read("word/styles.xml")
check(len(images)==4,"DOCX contains exactly four original figures")
check(sorted(hashlib.sha256(i).hexdigest() for i in images)==sorted(sha(f) for f in figures),"Embedded DOCX figures exactly match R-generated PNG files")
check(b"<w:pBdr" not in styles,"No inherited paragraph borders in DOCX styles")
pdf=PdfReader(out/"project_description.pdf")
check(len(pdf.pages)==len(payload["pages"]),"PDF has the intended five pages")
check(all(normalize(p["title"]) in normalize(pdf.pages[i].extract_text()) for i,p in enumerate(payload["pages"])),"PDF section starts match intended page order")
pdf_text=normalize(" ".join(p.extract_text() for p in pdf.pages))
for p in payload["pages"]:
    for b in p["blocks"]:
        if "text" in b:check(normalize(b["text"]) in pdf_text,"PDF includes payload text")
        if b["type"]=="table":
            check(all(normalize(str(t)) in pdf_text for row in b["rows"] for t in row),"PDF includes every generated table value")
result={"integrity_checks_passed":len(checks),"checks":checks,
        "team_metadata_complete":payload["team_complete"],
        "ready_for_team_submission_review":bool(payload["team_complete"]),
        "scope":"Data/report integrity only; not a substitute for visual review, team review, or later model diagnostics.",
        "files":{p.name:sha(p) for p in (out/"report_payload.json",out/"project_description.docx",out/"project_description.pdf")}}
(out/"validation.json").write_text(json.dumps(result,indent=2)+"\n")
print(f"Passed {len(checks)} integrity checks. Team metadata complete: {payload['team_complete']}.")
