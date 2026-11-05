#!/usr/bin/env python3
"""Read-only, file-by-file SQX migration audit. Never imports or executes assets.

Run with a trusted Python runtime, outside the source and target installations.
Outputs JSONL and CSV; content compatibility remains distinct from native testing.
"""
import argparse, collections, csv, hashlib, json, re, sqlite3, time, zipfile
from pathlib import Path
import xml.etree.ElementTree as ET


def sha(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def category(rel):
    p, ext = rel.lower(), Path(rel).suffix.lower()
    if p.startswith('user/data/history/'):
        return 'History'
    if p.startswith(('user/data/', 'user/customdata/')):
        return 'Data metadata'
    if ext == '.cfx' and p.startswith(('user/', 'volumeprofile/')):
        return 'Workflow/configuration'
    if ext in ('.sqx', '.sqb') and p.startswith(('user/', 'volumeprofile/')):
        return 'Strategy/template/block preset'
    if p.startswith('custom_indicators/'):
        return 'Standard platform library'
    if p in ('user/settings/customblocks.xml', 'user/settings/blockgroups.xml'):
        return 'Active blocks/groups'
    if p.startswith(('user/extend/', 'user/extend.clean_test/', 'user/snippets/',
                     'user/sxp_import_here/', 'user/_nnt_downloads/')):
        if ext in ('.sxp', '.zip'):
            return 'Extension package'
        if ext in ('.mq5', '.mq4', '.mqh'):
            return 'MetaTrader source'
        if ext in ('.eld', '.pla'):
            return 'TradeStation/MultiCharts bundle'
        if ext in ('.java', '.tpl', '.inc', '.py'):
            return 'Extension source/template'
        if ext == '.xml':
            return 'Custom block export/settings'
        return 'Other extension asset'
    if p.startswith('user/') and ext == '.sxp':
        return 'Extension package'
    if p.startswith('user/libs/') and ext == '.jar':
        return 'User extension library'
    if p.startswith(('user/settings/', 'user/sourcecode/')):
        return 'Settings/backup/export template'
    if p.startswith(('user/projects/', 'user/strategies/')) and ext == '.xml':
        return 'Project settings/backup'
    return 'Excluded runtime/log/cache/other'


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--source', action='append', required=True, help='label=directory')
    ap.add_argument('--target', required=True)
    ap.add_argument('--output', required=True)
    args = ap.parse_args()
    target, out = Path(args.target), Path(args.output)
    out.mkdir(parents=True, exist_ok=True)
    sources = [(s.split('=', 1)[0], Path(s.split('=', 1)[1])) for s in args.source]
    seen, rows, definitions, source_hashes = {}, [], [], {}
    counters = collections.Counter()
    started = time.time()
    target_cb = target / 'user/settings/customBlocks.xml'
    target_groups = target / 'user/settings/blockGroups.xml'
    target_ids = {'Item': set(), 'Group': set()}
    for f, tag, key in ((target_cb, 'Item', 'key'), (target_groups, 'Group', 'id')):
        if f.exists():
            try:
                target_ids[tag] = {e.get(key) for e in ET.parse(f).getroot().findall(tag)}
            except ET.ParseError:
                pass
    for label, root in sources:
        cb = root / 'strategyquant/user/settings/customBlocks.xml'
        if not cb.exists():
            cb = root / 'user/settings/customBlocks.xml'
        cbkeys = set()
        if cb.exists():
            try:
                cbkeys = {e.get('key') for e in ET.parse(cb).getroot().findall('Item')}
            except ET.ParseError:
                pass
        for f in root.rglob('*'):
            if not f.is_file():
                continue
            rel = f.relative_to(root).as_posix()
            if rel.startswith('strategyquant/'):
                rel = rel[len('strategyquant/'):]
            cat = category(rel)
            row = {'source': label, 'path': rel, 'category': cat,
                   'bytes': f.stat().st_size, 'sha256': '', 'duplicate_of': '',
                   'target': 'not_checked', 'status': 'review', 'details': {}}
            details = row['details']
            try:
                if cat == 'Excluded runtime/log/cache/other':
                    row['status'] = 'exclude'
                    details['reason'] = 'Do not transplant runtime, patch scripts, logs or caches.'
                else:
                    h = sha(f)
                    row['sha256'] = h
                    source_hashes[(label, rel)] = h
                    if h in seen:
                        row['duplicate_of'] = seen[h]
                    else:
                        seen[h] = label + ':' + rel
                    t = target / rel
                    if not t.is_file():
                        row['target'] = 'absent_path'
                    elif t.stat().st_size != row['bytes']:
                        row['target'] = 'different_size'
                    else:
                        row['target'] = 'identical' if sha(t) == h else 'different_content'
                    ext = f.suffix.lower()
                    if row['target'] == 'identical':
                        row['status'] = 'already_present'
                    if cat == 'History':
                        row['status'] = 'offline_data_review' if row['target'] != 'identical' else 'already_present'
                        if row['bytes'] <= 94:
                            row['status'] = 'tiny_history_do_not_count_as_coverage'
                        details['validation'] = 'Bytes/hash checked; candle integrity and alias equivalence not established.'
                    if cat == 'Data metadata':
                        row['status'] = 'offline_metadata_only'
                        with f.open('rb') as stream:
                            magic = stream.read(16)
                        if magic == b'SQLite format 3\x00':
                            db = sqlite3.connect(f.resolve().as_uri() + '?mode=ro', uri=True)
                            try:
                                details['sqlite_quick_check'] = db.execute('pragma quick_check').fetchone()[0]
                                details['tables'] = [x[0] for x in db.execute("select name from sqlite_master where type='table'")]
                                if 'DATA' in details['tables']:
                                    details['datasets'] = db.execute('select count(*) from DATA').fetchone()[0]
                                    details['datasets_with_rows'] = db.execute('select count(*) from DATA where ROWS>0').fetchone()[0]
                            finally:
                                db.close()
                    if ext in ('.cfx', '.sqx', '.sqb', '.sxp', '.zip', '.jar'):
                        try:
                            with zipfile.ZipFile(f) as z:
                                unsafe = [n for n in z.namelist() if '..' in Path(n.replace('\\', '/')).parts or n.startswith(('/', '\\')) or re.match(r'^[A-Za-z]:', n)]
                                details['unsafe_archive_paths'] = unsafe[:8]
                                bad = z.testzip()
                                details['zip_integrity'] = 'ok' if bad is None else 'bad:' + bad
                                keys, tasktypes, versions, flags, packages = set(), collections.Counter(), set(), [], collections.Counter()
                                malformed = []
                                for n in z.namelist():
                                    if n.endswith('/'):
                                        continue
                                    packages[Path(n).suffix.lower()] += 1
                                    if not n.lower().endswith('.xml'):
                                        continue
                                    try:
                                        xr = ET.fromstring(z.read(n))
                                    except ET.ParseError:
                                        malformed.append(n)
                                        continue
                                    if n == 'config.xml':
                                        details['xml_root'] = xr.tag
                                        details['stored_version'] = xr.get('version') or xr.get('Version') or ''
                                    for el in xr.iter():
                                        if el.tag == 'Task':
                                            tasktypes[el.get('type', '')] += 1
                                        if el.tag in ('DeleteFailedStrategies', 'OverwriteFiles', 'ClearDatabank') and (el.text or '').strip().lower() == 'true':
                                            flags.append(n + ':' + el.tag)
                                        if el.tag == 'Block' and (el.get('key') or '').startswith('CBlock_'):
                                            keys.add(el.get('key'))
                                details.update(xml_errors=malformed, task_types=dict(tasktypes),
                                               destructive_flags=sorted(set(flags)),
                                               package_file_types=dict(packages),
                                               referenced_custom_blocks=sorted(keys),
                                               custom_blocks_absent_from_source_active_file=sorted(keys - cbkeys))
                                if unsafe or bad or malformed:
                                    row['status'] = 'repair_before_import'
                                elif ext == '.cfx':
                                    version = details.get('stored_version', '')
                                    details['version_is_project_build_not_strategy_schema'] = details.get('xml_root') == 'Project'
                                    if details.get('xml_root') == 'Project' and not tasktypes:
                                        row['status'] = 'empty_project_shell'
                                    elif flags or tasktypes.get('ClearDatabanks'):
                                        row['status'] = 'rewrite_preservation_before_import'
                                    elif version and version.split('.')[0].isdigit() and int(version.split('.')[0]) < 144:
                                        row['status'] = 'older_project_incremental_conversion'
                                    elif row['target'] != 'identical':
                                        row['status'] = 'isolated_145_project_test'
                                elif ext == '.sxp' and row['target'] != 'identical':
                                    row['status'] = 'isolated_extension_compile_test'
                                    conflicts, missing = [], 0
                                    for n in z.namelist():
                                        if n.endswith('/') or '..' in Path(n).parts:
                                            continue
                                        tf = target / 'user' / n
                                        if tf.is_file():
                                            if sha(tf) != hashlib.sha256(z.read(n)).hexdigest():
                                                conflicts.append(n)
                                        else:
                                            missing += 1
                                    details.update(target_payload_conflicts=conflicts, target_payload_missing=missing)
                                elif ext in ('.sqx', '.sqb') and row['target'] != 'identical':
                                    row['status'] = 'isolated_strategy_template_load_retest'
                        except (zipfile.BadZipFile, RuntimeError, OSError) as e:
                            details['zip_integrity'] = type(e).__name__
                            row['status'] = 'damaged_or_nonzip_package'
                    if ext == '.xml':
                        try:
                            xr = ET.parse(f).getroot()
                            details['xml_root'] = xr.tag
                            if xr.tag in ('CustomBlocks', 'RandomGroups'):
                                details['top_level_definitions'] = len(xr)
                                if cat == 'Active blocks/groups':
                                    row['status'] = 'merge_after_dependency_validation'
                                    for el in xr:
                                        key = el.get('key') or el.get('id') or ''
                                        refs = {e.get('key') for e in el.iter('Item') if (e.get('key') or '').startswith('CBlock_')}
                                        unresolved = sorted(refs - cbkeys)
                                        definitions.append({'source': label, 'file': rel, 'kind': el.tag,
                                                            'id': key, 'name': el.get('name'),
                                                            'items': len(el.findall('Item')),
                                                            'target_id_exists': key in target_ids.get(el.tag, set()),
                                                            'unresolved_source_custom_blocks': unresolved,
                                                            'status': 'repair_dependencies' if unresolved else 'native_validation_pending'})
                        except ET.ParseError as e:
                            details['xml_error'] = str(e)
                            row['status'] = 'repair_invalid_xml'
                    if cat == 'User extension library':
                        row['status'] = 'review_library_dependency_no_runtime_replacement'
                    if cat == 'MetaTrader source' and row['target'] != 'identical':
                        row['status'] = 'compile_and_compare_in_metatrader'
                    if cat == 'TradeStation/MultiCharts bundle' and row['target'] != 'identical':
                        row['status'] = 'platform_import_source_visibility_and_compile_pending'
                    if cat == 'Extension source/template' and row['target'] != 'identical':
                        row['status'] = 'review_recompile_reconcile_dependencies'
                        if ext in ('.java', '.py', '.tpl', '.inc'):
                            text = f.read_text(encoding='utf-8-sig', errors='replace')
                            details['static_external_io_patterns'] = sorted(set(re.findall(r'ProcessBuilder|Runtime\.getRuntime|java\.net|urllib|subprocess|os\.system', text)))
                            if ext == '.java':
                                pkg = re.search(r'\bpackage\s+([\w.]+)\s*;', text)
                                cls = re.search(r'\bpublic\s+(?:abstract\s+|final\s+)?class\s+(\w+)', text)
                                details['java_type'] = ((pkg[1] + '.') if pkg else '') + (cls[1] if cls else f.stem)
                                details['imports'] = re.findall(r'^import\s+([^;]+);', text, re.M)
            except Exception as e:
                row['status'] = 'inspection_error'
                details['error'] = type(e).__name__ + ':' + str(e)
            rows.append(row)
            counters[row['status']] += 1
            if len(rows) % 2000 == 0:
                (out / 'progress.json').write_text(json.dumps({'files': len(rows), 'seconds': round(time.time()-started), 'source': label}))
    with (out / 'assets.jsonl').open('w', encoding='utf-8') as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + '\n')
    fields = ['source', 'path', 'category', 'bytes', 'sha256', 'duplicate_of', 'target', 'status', 'details']
    with (out / 'assets.csv').open('w', newline='', encoding='utf-8-sig') as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            writer.writerow(dict(row, details=json.dumps(row['details'], ensure_ascii=False)))
    (out / 'definitions.json').write_text(json.dumps(definitions, ensure_ascii=False, indent=2), encoding='utf-8')
    summary = {'files_examined': len(rows), 'seconds': round(time.time()-started),
               'status_counts': dict(counters), 'category_counts': dict(collections.Counter(r['category'] for r in rows)),
               'source_counts': dict(collections.Counter(r['source'] for r in rows)),
               'native_import_or_runtime_tests_performed': False}
    (out / 'summary.json').write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary))


if __name__ == '__main__':
    main()
