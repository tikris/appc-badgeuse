#!/usr/bin/env bash
# Génère une fausse chaîne de certificats (racine > « WWDR » > « Pass Type ID »)
# pour tester la signature des pass sans certificat Apple réel.
set -euo pipefail
OUT="$(cd "$(dirname "$0")/.." && pwd)/Tests/BadgeCoreTests/Fixtures"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"
cd "$WORK"

openssl req -x509 -newkey rsa:2048 -nodes -keyout root.key -out root.pem -days 7300 \
  -subj "/CN=APPC Test Root CA/O=APPC Tests/C=FR" \
  -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign"

openssl req -newkey rsa:2048 -nodes -keyout wwdr.key -out wwdr.csr \
  -subj "/CN=APPC Test WWDR CA/OU=G4/O=APPC Tests/C=FR"
printf "basicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\n" > wwdr.ext
openssl x509 -req -in wwdr.csr -CA root.pem -CAkey root.key -CAcreateserial -out wwdr.pem -days 7300 -extfile wwdr.ext

openssl req -newkey rsa:2048 -nodes -keyout pass.key -out pass.csr \
  -subj "/UID=pass.test.appc.badge/CN=Pass Type ID: pass.test.appc.badge/OU=TEAM123456/O=APPC Tests/C=FR"
printf "basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\n" > pass.ext
openssl x509 -req -in pass.csr -CA wwdr.pem -CAkey wwdr.key -CAcreateserial -out pass.pem -days 7300 -extfile pass.ext

cp root.pem "$OUT/test-root.pem"
openssl x509 -in root.pem -outform DER -out "$OUT/test-root.der"
openssl x509 -in wwdr.pem -outform DER -out "$OUT/test-wwdr.der"
openssl x509 -in pass.pem -outform DER -out "$OUT/test-pass-cert.der"
openssl rsa -in pass.key -outform DER -traditional -out "$OUT/test-pass-key.der"
echo "Fixtures générées dans $OUT"
