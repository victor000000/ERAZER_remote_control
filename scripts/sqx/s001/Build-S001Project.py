#!/usr/bin/env python3
"""Build the reviewed S001 revision 2 bundle offline; does not deploy or run SQX."""
from pathlib import Path
from zipfile import ZipFile,ZipInfo,ZIP_DEFLATED
from xml.etree import ElementTree as E
from copy import deepcopy
import argparse,json,hashlib,shutil

REVIEWED_SOURCE_SHA256 = '5f0e6b21a62e3ef041e4163f2560ab99a64761636b1ded54335b58d7404bb9cc'

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True, help='Reviewed original 21-task S001 .cfx, never the live revised project')
    parser.add_argument('--output-dir', type=Path, required=True, help='New local directory for the blueprint, manifest, and runtime helpers')
    args = parser.parse_args()
    source = args.source.resolve()
    if hashlib.sha256(source.read_bytes()).hexdigest() != REVIEWED_SOURCE_SHA256:
     parser.error('Source is not the reviewed original S001 archive. Refusing to apply task-number mappings.')
    with ZipFile(source) as z:
     data = {n: z.read(n) for n in z.namelist()}
    ROOT = args.output_dir.resolve()
    if ROOT.exists():
     parser.error('Output directory already exists; choose a new directory to preserve previous artifacts.')
    ROOT.mkdir(parents=True)
    parse=lambda b:E.fromstring(b,parser=E.XMLParser(target=E.TreeBuilder(insert_comments=True)))
    original=parse(data['config.xml']);ot=list(original.find('Tasks'))
    cfg=E.Element('Project',name=original.get('name'),version=original.get('version'));ts=E.SubElement(cfg,'Tasks');bs=E.SubElement(cfg,'Databanks')
    aux=['Results','Last generation','Initial population','Strategies to improve','Existing portfolio']
    for b in aux:E.SubElement(bs,'Databank',name=b,view='Default',syncType='Auto-sync never')
    files={};banks=set();folders=set();mapping=[];counter=0
    archive=r'C:\Users\Vic\ERAZER-Tools\StrategyArchives\S001_reproduce_project\current'
    def val(e,k,v):
     n=e.find(k)
     if n is None:n=E.SubElement(e,k)
     n.text=str(v);return n
    def bank(s,role,name):
     d=s.find('Databanks')
     if d is None:d=E.SubElement(s,'Databanks')
     matches=[e for e in d if e.get('name')==role]
     if matches:assert len(matches)==1;matches[0].set('value',name)
     else:E.SubElement(d,'Databank',name=role,label=role+' databank',value=name)
     banks.add(name)
    def add(kind,title,s,fn=None):
     nonlocal counter
     counter+=1;fn=fn or f'Flow-{counter:02d}-{kind}.xml';assert fn not in files
     files[fn]=s;E.SubElement(ts,'Task',type=kind,name=title,title=title,active='true',taskXMLFile=fn);return counter

    def save(source,folder):
     folders.add(folder);s=parse(data['SaveToFiles-Task1.xml']);sf=s.find('SaveToFiles');val(sf,'DestDirectorySqx',archive+'\\'+folder);val(sf,'OverwriteFiles','false');val(sf,'SetNoteActive','false');bank(s,'Input',source)
     # Save task has no meaningful output; remove its misleading original Results target.
     for b in list(s.find('Databanks')):
      if b.get('name')!='Input':s.find('Databanks').remove(b)
     add('SaveToFiles','Archive: '+source,s)
    def copy(source,target,passed=True):
     s=E.Element('Settings');f=E.SubElement(s,'Filtering');val(f,'ActionType',1);val(f,'MaxStrategies',0);val(f,'ConditionsType',2 if passed else 0);E.SubElement(f,'Conditions');bank(s,'Source',source);bank(s,'Target',target);add('Filtering',('Pass only: ' if passed else 'Copy: ')+source+' -> '+target,s)
    def namespace_load(source_folder,dest_folder,prefix,target):
     folders.update([source_folder,dest_folder]);marker=archive+'\\'+dest_folder+'\\namespace.ok'
     s=E.Element('Settings');e=E.SubElement(s,'CallExternalScript');params='-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\\Users\\Vic\\ERAZER-Tools\\SQX\\Namespace-SqxFiles.ps1" -Source "'+archive+'\\'+source_folder+'" -Destination "'+archive+'\\'+dest_folder+'" -Prefix '+prefix+' -Marker "'+marker+'" -MinimumCount '+{'B01':'500','B02':'500','B03':'1000'}[prefix]
     val(e,'File',r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe').set('params',params);val(e,'WaitFor','end').set('hours','0');e.find('WaitFor').set('minutes','0');E.SubElement(s,'Databanks');add('CallExternalScript','Namespace copied strategies: '+prefix,s)
     s=E.Element('Settings');e=E.SubElement(s,'WaitFor');val(e,'Action','file');val(e,'File',marker);E.SubElement(s,'Databanks');add('WaitFor','Require verified namespace copies: '+prefix,s)
     s=E.Element('Settings');e=E.SubElement(s,'LoadFromFiles');val(e,'SourceDirectory',archive+'\\'+dest_folder);val(e,'IncludeSubdirectories','false');val(e,'SourceDatabank',target);val(e,'UnrecognizedInstrumentAction',0);val(e,'UnrecognizedInstrumentValue','');bank(s,'Input',target);add('LoadFromFiles','Load distinct '+prefix+' candidates into '+target,s)

    def task(i,source=None,target=None,title=None,cap=None):
     t=ot[i-1];s=parse(data[t.get('taskXMLFile')]);before=deepcopy(s);kind=t.get('type')
     if source:bank(s,'Input',source)
     if target:bank(s,'Output',target)
     if kind in ['Retest','AutomaticRetest']:
      r=s.find('Rankings');val(r,'DeleteFailedStrategies','false');val(r,'MaxStrategies',0);r.find('StopCondition').set('type','never')
     if kind=='Build':
      if cap is not None:val(s.find('Rankings'),'MaxStrategies',cap)
      f=s.find('Rankings/FitPortfolio')
      if f is not None:f.set('databank',target)
     # Prove backtests, risk settings, crosschecks, templates and filter thresholds remain unchanged.
     for n in before:
      if n.tag not in ['Databanks','Rankings']:assert E.tostring(n)==E.tostring(s.find(n.tag)),(i,n.tag)
     a=deepcopy(before.find('Rankings'));b=deepcopy(s.find('Rankings'))
     if a is not None:
      for r in [a,b]:
       for k in ['DeleteFailedStrategies','MaxStrategies','StopCondition','FitPortfolio']:
        x=r.find(k)
        if x is not None:r.remove(x)
      assert E.tostring(a)==E.tostring(b),(i,'filter thresholds')
     pos=add(kind,title or t.get('title',t.get('name')),s,t.get('taskXMLFile'));mapping.append(dict(original=i,task=pos,title=title or t.get('title'),input=source,output=target));return s

    def ret(i,source,stem,title):
     raw=stem+'_All';passed=stem+'_Passed';task(i,source,raw,title);save(raw,stem+'_all');copy(raw,passed);return passed

    # Three independent build caches keep their existing caps; source IDs are added to copies.
    # Caps raised for the 2026-10-25 next run: 500 / 500 / 1000 (seeded from the prior builder banks).
    task(1,target='S001_build_01_template',title='Build 1: S001 Nasdaq template (cap 500)',cap=500);save('S001_build_01_template','build01_all');namespace_load('build01_all','build01_candidates','B01','A00_NasdaqCandidates')
    task(2,target='S001_build_02_random',title='Build 2: random Nasdaq strategies (cap 500)',cap=500);save('S001_build_02_random','build02_all');namespace_load('build02_all','build02_candidates','B02','A00_NasdaqCandidates')
    a='A00_NasdaqCandidates'
    for i,stem,title in [(3,'A01_Dow','A1: Dow Jones retest'),(4,'A02_SP500','A2: S&P 500 retest'),(5,'A03_SP400','A3: S&P MidCap 400 retest'),(6,'A04_Russell1000','A4: Russell 1000 retest'),(7,'A05_Nasdaq100','A5: Nasdaq 100 retest'),(8,'A06_AutoRetest','A6: automatic retest of current passing Nasdaq results')]:a=ret(i,a,stem,title)
    task(9,a,'A07_CorrelationSelected','A7: correlation selection (0.7)');save('A07_CorrelationSelected','A07_correlation');copy('A07_CorrelationSelected','B00_FinalCandidates',False)
    task(10,target='S001_build_10_sp500',title='Build 3: SP500 template on Nasdaq data (cap 1000)',cap=1000);save('S001_build_10_sp500','build03_all');namespace_load('build03_all','build03_candidates','B03','B00_FinalCandidates')
    b='B00_FinalCandidates'
    for i,stem,title in [(11,'B01_SP500_OOS','B1: S&P 500 OOS / crosschecks'),(12,'B02_Dow','B2: Dow Jones retest'),(13,'B03_Nasdaq100','B3: Nasdaq 100 retest'),(14,'B04_SP400','B4: S&P MidCap 400 retest'),(15,'B05_SP500_Final','B5: final S&P 500 retest')]:b=ret(i,b,stem,title)
    task(16,b,'B06_CorrelationSelected','B6: correlation selection (0.6)');save('B06_CorrelationSelected','B06_correlation');b='B06_CorrelationSelected'
    for i,stem,title in [(17,'B07_NasdaqConfirm','B7: Nasdaq confirmation'),(18,'B08_MCTrades','B8: Monte Carlo trades'),(19,'B09_MCParameters','B9: Monte Carlo parameters'),(20,'B10_SystemParameters','B10: system parameter permutations')]:b=ret(i,b,stem,title)
    task(21,source=b,title='Export only fully validated strategies')
    for name in sorted(banks-set(aux)):E.SubElement(bs,'Databank',name=name,view='Default - Main data',syncType='Auto-sync every 10 minutes')
    files['config.xml']=cfg
    out=ROOT/'S001-preservation-blueprint.cfx'
    with ZipFile(out,'w',ZIP_DEFLATED) as zz:
     for n,r in files.items():
      entry=ZipInfo(n,date_time=(1980,1,1,0,0,0));entry.compress_type=ZIP_DEFLATED
      zz.writestr(entry,E.tostring(r,encoding='utf-8'))
    with ZipFile(out) as zz:assert zz.testzip() is None
    # Exact ordered data flow, no historical mixed input, no destructive built-in tasks.
    for t in ts:
     s=files[t.get('taskXMLFile')];k=t.get('type');assert k not in ['ClearDatabanks','DeleteFile']
     if k=='Filtering':assert s.findtext('Filtering/ActionType')=='1'
     if k in ['Retest','AutomaticRetest','CustomAnalysis']:
      ds={x.get('name'):x.get('value') for x in s.find('Databanks')};assert ds['Input']!=ds['Output']
    report={'revision':2,'previousTasks':144,'revisedTasks':len(ts),'previousDatabanks':63,'revisedDatabanks':len(bs),'newDatabanks':sorted(banks-set(aux)),'buildCaps':[500,500,1000],'changes':mapping,'archiveFolders':sorted(folders),'sourceSha256':hashlib.sha256(source.read_bytes()).hexdigest(),'blueprintSha256':hashlib.sha256(out.read_bytes()).hexdigest(),'assertions':['Sequential current-run passing-result routing','No historical result bank used as an active validation stage','Original datasets, dates, risk, thresholds and crosschecks unchanged','All failed retests retained','Collision-safe builder provenance applied only to copied strategies','No databank clear, move or delete task','Full pre-run backups moved to launcher']}
    (ROOT/'S001-preservation-manifest.json').write_text(json.dumps(report,indent=2));(ROOT/'S001-archive-folders.json').write_text(json.dumps(sorted(folders),indent=2))
    print(json.dumps({k:report[k] for k in ['previousTasks','revisedTasks','previousDatabanks','revisedDatabanks','buildCaps']},indent=2))
    for name in ('Start-S001PreservingProject.ps1','Namespace-SqxFiles.ps1','Start-S001ArchiveRun.ps1'):
     shutil.copyfile(Path(__file__).resolve().parent/name,ROOT/name)

if __name__ == "__main__":
    main()
