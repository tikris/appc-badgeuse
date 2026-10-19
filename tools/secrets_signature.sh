#!/bin/bash
# Met à jour les secrets de signature du workflow « TestFlight », depuis le Mac, sans copier-coller à la main.
#
# À lancer depuis le dossier du projet :
#   bash tools/secrets_signature.sh [chemin/Distribution.p12]
# ou, sans récupérer la branche :
#   bash <(curl -fsSL https://raw.githubusercontent.com/tikris/appc-badgeuse/claude/gracious-fermi-astcip/tools/secrets_signature.sh)
#
# 1. Vérifie que chaque .p12 s'ouvre avec son mot de passe, exactement comme le fera GitHub Actions.
# 2. Envoie DIST_CERTIFICATE_P12, DIST_CERTIFICATE_PASSWORD, PASS_CERTIFICATE_P12 et PASS_CERTIFICATE_PASSWORD
#    avec GitHub CLI (gh) s'il est installé et connecté ; sinon, les copie un par un dans le presse-papiers.
# Aucun secret n'est affiché ni écrit sur le disque.
set -euo pipefail

REPO=tikris/appc-badgeuse
DIST_P12=${1:-$HOME/Desktop/Distribution.p12}
PASS_P12=App/BadgeCreche/PassCertificate.p12
PASS_PLIST=App/BadgeCreche/PassSigning.plist

fail() { echo "❌ $*" >&2; exit 1; }

[ -f "$PASS_PLIST" ] || fail "Lancez ce script depuis le dossier du projet (celui qui contient App/BadgeCreche)."
[ -f "$PASS_P12" ] || fail "Certificat Wallet introuvable : $PASS_P12"
[ -f "$DIST_P12" ] || fail "Certificat de distribution introuvable : $DIST_P12
   Trousseau d'accès → Mes certificats → « Apple Distribution » → Exporter → Distribution.p12 sur le Bureau,
   ou passez le chemin du fichier en argument."
PASS_PASSWORD=$(/usr/libexec/PlistBuddy -c "Print :CertificatePassword" "$PASS_PLIST" 2>/dev/null) \
  || fail "Mot de passe du certificat Wallet absent de $PASS_PLIST"

printf "Mot de passe de %s (rien ne s'affiche pendant la saisie) : " "$(basename "$DIST_P12")"
read -rs DIST_PASSWORD
echo

# Trousseau jetable : même vérification que le workflow (security import du .p12 avec son mot de passe).
KEYCHAIN="$(mktemp -d)/verification.keychain-db"
security create-keychain -p verification "$KEYCHAIN"
trap 'security delete-keychain "$KEYCHAIN" 2>/dev/null || true' EXIT
opens() { security import "$1" -P "$2" -f pkcs12 -k "$KEYCHAIN" > /dev/null 2>&1; }

opens "$DIST_P12" "$DIST_PASSWORD" || fail "Ce mot de passe n'ouvre pas $DIST_P12. Réexportez le certificat avec un mot de passe simple (lettres et chiffres)."
echo "✅ Certificat de distribution : mot de passe correct ($(wc -c < "$DIST_P12" | tr -d ' ') octets)"
opens "$PASS_P12" "$PASS_PASSWORD" || fail "Le mot de passe de $PASS_PLIST n'ouvre pas $PASS_P12."
echo "✅ Certificat Wallet : mot de passe correct ($(wc -c < "$PASS_P12" | tr -d ' ') octets)"

if command -v gh > /dev/null && gh auth status > /dev/null 2>&1; then
  base64 -i "$DIST_P12" | gh secret set DIST_CERTIFICATE_P12 --repo "$REPO"
  printf '%s' "$DIST_PASSWORD" | gh secret set DIST_CERTIFICATE_PASSWORD --repo "$REPO"
  base64 -i "$PASS_P12" | gh secret set PASS_CERTIFICATE_P12 --repo "$REPO"
  printf '%s' "$PASS_PASSWORD" | gh secret set PASS_CERTIFICATE_PASSWORD --repo "$REPO"
  echo "✅ Les 4 secrets sont à jour dans GitHub."
else
  echo
  echo "Copie guidée (GitHub CLI absent). Page : https://github.com/$REPO/settings/secrets/actions"
  echo "Pour chaque secret : crayon → Update secret → ⌘V → Update secret."
  copy() {
    printf '%s' "$2" | pbcopy
    read -rp "→ $1 est dans le presse-papiers. Collez-le dans GitHub, puis appuyez ici sur Entrée… " _
  }
  copy DIST_CERTIFICATE_P12 "$(base64 -i "$DIST_P12")"
  copy DIST_CERTIFICATE_PASSWORD "$DIST_PASSWORD"
  copy PASS_CERTIFICATE_P12 "$(base64 -i "$PASS_P12")"
  copy PASS_CERTIFICATE_PASSWORD "$PASS_PASSWORD"
  printf '' | pbcopy
  echo "✅ Terminé (presse-papiers vidé)."
fi
echo "Vous pouvez dire « go » : le build 5 partira sur TestFlight."
