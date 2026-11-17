"""Verify downloaded CI artifacts against provenance and the owner's public certificate."""
import hashlib
import json
from pathlib import Path
import zipfile
from cryptography import x509
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.serialization import pkcs7

root = Path('release/tertiary-android-mobile-panels-v7/artifacts')
provenance = json.loads((root / 'provenance.json').read_text())
assert provenance['workflowCommit'] == '7b508701290c15b1aaf96c5c2a613660618c24f4'
assert provenance['runId'] == '44105109705'
for name, digest in provenance['files'].items():
    assert Path(name).name == name
    assert hashlib.sha256((root / name).read_bytes()).hexdigest() == digest, name
owner = x509.load_pem_x509_certificate(Path('E:/Atlas-Release-Keys/upload-certificate.pem').read_bytes())
fingerprint = owner.fingerprint(hashes.SHA256()).hex()
with zipfile.ZipFile(root / 'tertiary-atlas-testing.aab') as bundle:
    blocks = [name for name in bundle.namelist() if name.startswith('META-INF/') and name.endswith('.RSA')]
    assert len(blocks) == 1
    certificates = pkcs7.load_der_pkcs7_certificates(bundle.read(blocks[0]))
    assert any(cert.fingerprint(hashes.SHA256()).hex() == fingerprint for cert in certificates)
signature = (root / 'apk-signature.txt').read_text()
assert fingerprint in signature.replace(':', '').lower()
manifest = (root / 'android-manifest.txt').read_text()
for expected in ["application-label:'Tertiary Atlas'", "targetSdkVersion:'36'", "name='com.skoolatlas.app'", "versionCode='7'"]:
    assert expected in manifest, expected
assert 'application-debuggable' not in manifest
with zipfile.ZipFile(root / 'tertiary-atlas-testing.apk') as apk:
    admissions = apk.read('assets/flutter_assets/assets/tertiary/admissions.json')
    assert admissions == Path('assets/tertiary/admissions.json').read_bytes()
    rows = json.loads(admissions)['rules']
    assert len(rows) == 599
    assert not any(r['id']=='national-20261027-central-it' for r in rows)
    assert next(r for r in rows if r['id']=='private-20261028-central-it')['status']=='needs_source_review'
report = {
    'hashesVerified': True,
    'ownerCertificateMatchedForApkAndBundle': True,
    'certificateSha256': fingerprint,
    'applicationId': 'com.skoolatlas.app',
    'appName': 'Tertiary Atlas',
    'targetSdk': 36,
    'versionCode': 7,
    'debuggable': False,
    'reviewedAdmissionsPackMatched': True,
    'buildRun': provenance['runId'],
}
(root / 'local-verification.json').write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
