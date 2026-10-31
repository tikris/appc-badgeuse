#!/bin/bash
# Écrit la clé API App Store Connect (secret ASC_KEY_P8) au format PEM attendu par Xcode et les scripts.
# Tolère un copier-coller abîmé (depuis un téléphone notamment) : retours à la ligne perdus ou ajoutés,
# espaces, tirets des lignes BEGIN / END transformés ou absents. Seul le contenu base64 est gardé.
#
#   ASC_KEY_P8=… bash tools/asc_key.sh "$RUNNER_TEMP/keys/AuthKey.p8"
set -euo pipefail

dest=${1:?chemin du fichier .p8 à écrire}
body=$(printf '%s' "${ASC_KEY_P8:?secret ASC_KEY_P8 manquant}" | tr -cd 'A-Za-z0-9+/=' \
  | sed -e 's/BEGINPRIVATEKEY//' -e 's/ENDPRIVATEKEY//')

mkdir -p "$(dirname "$dest")"
{
  echo "-----BEGIN PRIVATE KEY-----"
  printf '%s' "$body" | fold -w 64
  echo
  echo "-----END PRIVATE KEY-----"
} > "$dest"

# Une clé illisible arrête le job ici, avec un message clair plutôt qu'une erreur d'Xcode.
if ! openssl pkey -in "$dest" -noout 2> /dev/null; then
  rm -f "$dest"
  echo "::error::ASC_KEY_P8 n'est pas une clé privée valide : collez tout le contenu du fichier AuthKey_XXXX.p8 ($(printf '%s' "$body" | wc -c | tr -d ' ') caractères base64 reçus, environ 200 attendus)"
  exit 1
fi
