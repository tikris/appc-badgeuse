#!/bin/bash
# Crée le certificat Wallet (Pass Type ID) du service de signature et le copie vers Scaleway, depuis le Mac.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/tikris/appc-badgeuse/claude/gracious-fermi-astcip/tools/certificat_serveur.sh)
#
# 1. Génère une clé privée et une demande de certificat (CSR) dans un dossier temporaire.
# 2. Ouvre developer.apple.com : « Pass Type ID Certificate », envoi de la CSR, téléchargement de pass.cer.
# 3. Vérifie que le certificat correspond à la clé et qu'il s'agit bien d'un Pass Type ID.
# 4. Copie l'un après l'autre le certificat puis la clé dans le presse-papiers, à coller dans les
#    variables secrètes de la fonction Scaleway ; supprime ensuite la clé et vide le presse-papiers.
# La clé n'est jamais affichée, ni envoyée ailleurs que dans le presse-papiers.
set -euo pipefail

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"; printf "" | pbcopy' EXIT
fail() { echo "❌ $*" >&2; exit 1; }
step() { echo; echo "── $*"; }

step "1. Clé et demande de certificat"
openssl genrsa -out "$WORK/key.pem" 2048 2> /dev/null
openssl req -new -key "$WORK/key.pem" -out "$WORK/request.csr" \
  -subj "/CN=Badge Creche - service de signature/O=Parents a Paris Centre/C=FR"
cp "$WORK/request.csr" "$HOME/Desktop/BadgeCreche-serveur.csr"
echo "✅ Demande enregistrée sur le Bureau : BadgeCreche-serveur.csr (elle ne contient aucun secret)."

step "2. Certificat chez Apple"
echo "Sur la page qui s'ouvre : « Pass Type ID Certificate » → Continue → choisissez pass.fr.parentsapariscentre…"
echo "→ envoyez BadgeCreche-serveur.csr (Bureau) → Download. Le fichier pass.cer arrive dans Téléchargements."
open "https://developer.apple.com/account/resources/certificates/add" 2> /dev/null || true
read -rp "Une fois pass.cer téléchargé, Entrée… " _
# Seulement un certificat téléchargé après la demande (un ancien pass.cer serait le mauvais).
CER=$(find "$HOME/Downloads" -maxdepth 1 -name '*.cer' -newer "$WORK/request.csr" -print 2> /dev/null | head -1 || true)
[ -n "$CER" ] || CER=$(read -rp "Glissez ici le fichier .cer, puis Entrée : " answer; printf '%s' "$answer" | sed -e "s/^'//" -e "s/'$//" -e 's/\\\(.\)/\1/g' -e 's/[[:space:]]*$//')
[ -f "$CER" ] || fail "Certificat introuvable : $CER"
echo "Fichier : $CER"

step "3. Vérifications"
openssl x509 -inform DER -in "$CER" -out "$WORK/cert.pem" 2> /dev/null || fail "$CER n'est pas un certificat valide."
SUBJECT=$(openssl x509 -in "$WORK/cert.pem" -noout -subject -nameopt RFC2253)
case "$SUBJECT" in *"Pass Type ID: pass."*) ;; *) fail "Ce n'est pas un certificat Pass Type ID : $SUBJECT" ;; esac
[ "$(openssl x509 -in "$WORK/cert.pem" -noout -pubkey | openssl sha256)" = \
  "$(openssl rsa -in "$WORK/key.pem" -pubout 2> /dev/null | openssl sha256)" ] \
  || fail "Ce certificat ne correspond pas à la clé générée (mauvais fichier .cer ?)."
echo "✅ $SUBJECT"
echo "   Valide jusqu'au $(openssl x509 -in "$WORK/cert.pem" -noout -enddate | cut -d= -f2)"
openssl pkcs8 -topk8 -nocrypt -in "$WORK/key.pem" -outform DER -out "$WORK/key.der"

step "4. Copie vers Scaleway"
echo "Console Scaleway → Serverless Functions → badge-creche → signature → Paramètres → Variables secrètes."
copy() {
  printf '%s' "$2" | pbcopy
  read -rp "→ $1 est dans le presse-papiers : ajoutez la variable secrète $1 et collez, puis Entrée… " _
}
copy PASS_CERTIFICATE_PEM "$(openssl x509 -in "$WORK/cert.pem" -outform DER | base64 | tr -d '\n')"
copy PASS_PRIVATE_KEY_PEM "$(base64 -i "$WORK/key.der" | tr -d '\n')"
echo "✅ Terminé : clé supprimée de ce Mac, presse-papiers vidé. Enregistrez les variables dans Scaleway"
echo "   (la fonction redémarre), puis dites « go » à Claude."
