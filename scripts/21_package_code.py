"""Package code/config/docs separately from data and report documents."""
from pathlib import Path
from zipfile import ZipFile,ZipInfo,ZIP_DEFLATED
ROOT=Path(__file__).resolve().parents[1]
files=[]
for folder in ('scripts','config','docs'):
    files.extend(p for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix in ('.R','.py','.md','.json','.csv'))
files.extend(ROOT/n for n in ('README.md','requirements-report.txt','.gitignore','.gitattributes') if (ROOT/n).exists())
out=ROOT/'reports/final_report/analysis_code.zip'
with ZipFile(out,'w',ZIP_DEFLATED) as z:
    for p in sorted(files):
        info=ZipInfo('airbnb-analysis-code/'+p.relative_to(ROOT).as_posix(),date_time=(2026,11,19,0,0,0))
        info.compress_type=ZIP_DEFLATED;z.writestr(info,p.read_bytes())
with ZipFile(out) as z:
    assert z.testzip() is None
    assert all('/data/' not in n and '/.r-library/' not in n for n in z.namelist())
print(f'Packaged {len(files)} code/config/documentation files without row-level data.')
