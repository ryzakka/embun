#!/usr/bin/env python3
"""Install only the Embun account patch, with complete conflict preflight."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys
import tempfile


def digest(data):
    return hashlib.sha256(data.replace(b'\r\n', b'\n')).hexdigest()


def inside(root, relative):
    result = (root / relative).resolve()
    if not result.is_relative_to(root) or result == root:
        raise ValueError('Jalur di luar proyek: ' + relative)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', required=True, type=Path)
    parser.add_argument('--check', action='store_true', help='Periksa tanpa menulis')
    args = parser.parse_args()
    source = Path(__file__).resolve().parent
    project = args.project.expanduser().resolve()
    manifest = json.loads((source / 'PATCH_MANIFEST.json').read_text(encoding='utf-8'))
    pubspec = project / 'pubspec.yaml'
    if not pubspec.is_file():
        raise ValueError('pubspec.yaml tidak ditemukan di folder proyek.')
    if not re.search(r'^\s+supabase_flutter\s*:', pubspec.read_text(encoding='utf-8'), re.M):
        raise ValueError('Dependency supabase_flutter belum ada pada pubspec.yaml proyek.')
    pending, conflicts = [], []
    for entry in manifest['files']:
        path = entry['path']
        payload = inside(source, path)
        if not payload.is_file() or digest(payload.read_bytes()) != entry['sha256_lf']:
            conflicts.append(path + ': isi paket tidak cocok dengan manifest')
            continue
        target = inside(project, path)
        if target.is_file():
            current = digest(target.read_bytes())
            if current == entry['sha256_lf']:
                print('Sudah terpasang: ' + path)
                continue
            if current != entry.get('original_sha256_lf'):
                conflicts.append(path + ': berkas telah berbeda; gabungkan .diff secara manual')
                continue
        elif target.exists() or entry.get('original_sha256_lf'):
            conflicts.append(path + ': berkas asal tidak ditemukan atau jalur bukan berkas')
            continue
        # Detect parent directories that are files, before copying anything.
        parent = target.parent
        while parent != project:
            if parent.exists() and not parent.is_dir():
                conflicts.append(path + ': jalur induk bukan folder')
                break
            parent = parent.parent
        pending.append((payload, target, path))
    if conflicts:
        raise ValueError('Tidak ada berkas yang diubah.\n' + '\n'.join(conflicts))
    print('Berkas yang perlu dipasang: ' + str(len(pending)))
    if args.check or not pending:
        return 0
    # Back up originals only after the entire preflight succeeds.
    originals = [entry for entry in pending if entry[1].is_file()]
    if originals:
        backup_root = project / 'backup_login_google'
        backup_root.mkdir(exist_ok=True)
        backup = Path(tempfile.mkdtemp(prefix='patch-', dir=backup_root))
        for _, target, relative in originals:
            destination = backup / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(target, destination)
        print('Cadangan: ' + str(backup))
    for payload, target, relative in pending:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(payload, target)
        print('Terpasang: ' + relative)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
