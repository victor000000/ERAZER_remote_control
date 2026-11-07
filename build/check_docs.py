"""Check owned Markdown links/fragments without fetching URLs or executing examples."""
import argparse
import re
import subprocess
from pathlib import Path
from urllib.parse import unquote, urlsplit

# These snapshots intentionally refer to the former layout. Their index is checked.
HISTORICAL = {
    'docs/history/README-before-restructure.md',
    'docs/history/CLEANUP-TODO-before-restructure.md',
    'docs/history/ERAZER-Windows-Review.md',
    'docs/history/gateway-review-20261020.md',
}


def prose(text):
    """Remove fenced code so example Markdown is not interpreted as a document."""
    lines = []
    fence = None
    for line in text.splitlines():
        match = re.match(r'^\s*(`{3,}|~{3,})', line)
        if match:
            marker = match[1]
            if fence is None:
                fence = marker
            elif marker[0] == fence[0] and len(marker) >= len(fence):
                fence = None
            continue
        if fence is None:
            lines.append(line)
    return '\n'.join(lines)


def anchors(text):
    result, counts = set(), {}
    for line in prose(text).splitlines():
        match = re.match(r'^\s{0,3}#{1,6}\s+(.+?)\s*#*\s*$', line)
        if not match:
            continue
        heading = re.sub(r'!?\[([^]]+)\]\([^)]*\)', r'\1', match[1])
        heading = re.sub(r'<[^>]*>', '', heading).lower()
        slug = re.sub(r'[^\w\s-]', '', heading, flags=re.UNICODE).replace(' ', '-')
        occurrence = counts.get(slug, 0)
        counts[slug] = occurrence + 1
        result.add(slug + (f'-{occurrence}' if occurrence else ''))
    return result


def check_document(root, relative):
    root = root.resolve()
    source = root / relative
    errors = []
    if not source.is_file():
        return [f'{relative}: document missing']
    text = prose(source.read_text(encoding='utf-8-sig'))
    # Current owned docs use inline links; code spans containing link syntax
    # are ignored. External URLs are syntax-only and never requested.
    text = re.sub(r'`[^`\n]*`', 'code', text)
    for match in re.finditer(r'!?\[[^]\n]+\]\((<[^>]+>|[^)\s]+)(?:\s+"[^"]*")?\)', text):
        value = match[1].strip('<>')
        link = urlsplit(value)
        if link.scheme or link.netloc:
            if link.scheme.lower() in {'file', 'javascript', 'data'}:
                errors.append(f'{relative}: nonportable/unsafe link scheme')
            continue
        path = unquote(link.path)
        target = (source.parent / path).resolve() if path else source.resolve()
        try:
            target.relative_to(root)
        except ValueError:
            errors.append(f'{relative}: link leaves repository: {value}')
            continue
        if not target.exists():
            errors.append(f'{relative}: missing target: {value}')
        elif link.fragment:
            if target.suffix.lower() != '.md' or unquote(link.fragment) not in anchors(target.read_text(encoding='utf-8-sig')):
                errors.append(f'{relative}: missing Markdown anchor: {value}')
    return errors


def repository_documents(root):
    data = subprocess.check_output([
        'git', '-C', str(root), 'ls-files', '--cached', '--others',
        '--exclude-standard', '-z', '--', '*.md',
    ])
    return sorted(set(filter(None, data.decode().split('\0'))))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    paths = repository_documents(args.root)
    current = [p for p in paths if p not in HISTORICAL]
    errors = [e for p in current for e in check_document(args.root, p)]
    print(f'Documentation: {len(paths)} owned Markdown files; {len(current)} link-checked; '
          f'{len(set(paths) & HISTORICAL)} frozen historical snapshots excluded.')
    for error in errors:
        print(error)
    return bool(errors)


if __name__ == '__main__':
    raise SystemExit(main())
