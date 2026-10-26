#!/usr/bin/env python3
"""Static source-package checks; this does not replace Flutter build/tests."""
from pathlib import Path
import sys
import xml.etree.ElementTree as ET
import yaml

ROOT = Path(__file__).resolve().parents[1]
required = [
    'pubspec.yaml', 'README.md', '.gitignore', '.github/workflows/main.yml',
    'android/settings.gradle', 'android/build.gradle', 'android/app/build.gradle',
    'android/app/src/main/AndroidManifest.xml',
    'android/app/src/main/kotlin/com/hyper/inventory/MainActivity.kt',
    'assets/images/hyper_logo.png', 'lib/main.dart',
    'lib/database/database_helper.dart', 'lib/services/import_service.dart',
    'lib/services/report_detector.dart', 'lib/services/ml_kit_service.dart',
    'lib/utils/expiry_parser.dart', 'test/expiry_parser_test.dart',
    'test/report_detector_test.dart', 'test/database_helper_test.dart', 'test/import_service_test.dart',
    'test/widget_test.dart',
]
missing = [p for p in required if not (ROOT / p).is_file()]
if missing:
    print('MISSING FILES:', *missing, sep='\n- ')
    sys.exit(1)

pubspec = yaml.safe_load((ROOT / 'pubspec.yaml').read_text(encoding='utf-8'))
if 'xlsx' in pubspec.get('dependencies', {}):
    raise SystemExit('Invalid dependency `xlsx`; use `excel` for XLSX files.')
if 'excel' not in pubspec.get('dependencies', {}):
    raise SystemExit('Missing XLSX reader dependency `excel`.')
if pubspec.get('dependencies', {}).get('google_mlkit_text_recognition') != '^0.14.0':
    raise SystemExit('Use the published google_mlkit_text_recognition version ^0.14.0 for the pinned Flutter SDK.')
if 'google_ml_kit' in pubspec.get('dependencies', {}):
    raise SystemExit('Umbrella ML Kit dependency should not be used in the lean rebuild.')

workflow = yaml.safe_load((ROOT / '.github/workflows/main.yml').read_text(encoding='utf-8'))
workflow_text = (ROOT / '.github/workflows/main.yml').read_text(encoding='utf-8')
for token in ['flutter pub get', 'flutter analyze', 'flutter test', 'android-arm64', 'flutter build apk', 'upload-artifact@v4']:
    if token not in workflow_text:
        raise SystemExit(f'Missing CI build step: {token}')

for p in (ROOT / 'android/app/src/main').rglob('*.xml'):
    ET.parse(p)

# Guard the core data-integrity rule: existing item imports must not update batch dates.
db_source = (ROOT / 'lib/database/database_helper.dart').read_text(encoding='utf-8')
update_block = db_source.split('if (existing.isNotEmpty) {', 1)[1].split('} else {', 1)[0]
for forbidden in ["'expiry_date'", "'production_date'", "'item_batches'"]:
    if forbidden in update_block:
        raise SystemExit(f'Daily import must not modify batch data: found {forbidden}')

logo = ROOT / 'assets/images/hyper_logo.png'
if logo.stat().st_size > 1024 * 1024:
    raise SystemExit('Unexpectedly large logo asset (>1 MiB).')

print('Static package checks passed.')
print('NOTE: Flutter analyze, tests, and APK build require the Flutter SDK and are run in GitHub Actions.')
