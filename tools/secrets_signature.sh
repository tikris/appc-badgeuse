#!/bin/bash
# Met à jour le certificat Wallet du workflow « TestFlight », depuis le Mac, sans copier-coller à la main.
# La signature App Store est gérée par Apple (clé API « Admin ») : seul ce certificat, embarqué dans l'app
# pour signer les badges, vient du Mac.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/tikris/appc-badgeuse/claude/gracious-fermi-astcip/tools/secrets_signature.sh)
#
# Lancé de préférence depuis le dossier du projet (le mot de passe du certificat y est lu).
# 1. Trouve le certificat (.p12) : projet, Bureau, Téléchargements, ou fichier glissé dans le Terminal ;
#    s'il manque, explique comment l'exporter depuis Trousseau d'accès.
# 2. Vérifie le .p12 avec son mot de passe, exactement comme le workflow, et qu'il contient bien un
#    certificat « Pass Type ID ».
# 3. Envoie les deux secrets avec GitHub CLI (gh), ou les copie un par un dans le presse-papiers.
# Aucun secret n'est affiché ni laissé sur le disque.
set -euo pipefail

REPO=tikris/appc-badgeuse
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

fail() { echo "❌ $*" >&2; exit 1; }
step() { echo; echo "── $*"; }

# Chemin glissé dans le Terminal : espaces et caractères échappés, espace final.
clean_path() {
  local path
  path=$(printf '%s' "$1" | sed -e 's/[[:space:]]*$//' -e "s/^'//" -e "s/'$//" -e 's/\\\(.\)/\1/g')
  printf '%s' "${path/#\~/$HOME}"
}

# Premier fichier existant parmi les candidats ; sinon, explications puis fichier glissé dans le Terminal.
find_p12() {
  local label=$1 help=$2
  shift 2
  for candidate in "$@"; do
    [ -f "$candidate" ] && { printf '%s' "$candidate"; return; }
  done
  echo "$help" >&2
  open -a "Keychain Access" 2>/dev/null || true
  local answer
  read -rp "Glissez ici le fichier .p12 « $label », puis Entrée : " answer
  answer=$(clean_path "$answer")
  [ -f "$answer" ] || fail "Fichier introuvable : $answer"
  printf '%s' "$answer"
}

# Importe le .p12 dans un trousseau jetable (même test que le workflow), supprimé aussitôt.
# Affiche l'empreinte SHA-1 du certificat attendu (vide s'il n'y est pas) ; échoue si le mot de passe est faux.
check_p12() {
  local file=$1 password=$2 expected=$3 keychain sha1="" status=0
  keychain="$WORK/verification-$RANDOM.keychain-db"
  security create-keychain -p verification "$keychain" > /dev/null
  security unlock-keychain -p verification "$keychain"
  if security import "$file" -P "$password" -f pkcs12 -k "$keychain" > /dev/null 2>&1; then
    sha1=$(security find-certificate -c "$expected" -Z "$keychain" 2>/dev/null | awk '/SHA-1 hash:/ { print $3; exit }')
  else
    status=1
  fi
  security delete-keychain "$keychain" 2>/dev/null || true
  printf '%s' "$sha1"
  return $status
}

read_password() {
  local password
  printf "Mot de passe de %s (rien ne s'affiche) : " "$1" >&2
  read -rs password
  echo >&2
  printf '%s' "$password"
}

# ── 1. Certificat Wallet ──────────────────────────────────────────────────────

step "Certificat Wallet (Pass Type ID)"
PASS_P12=$(find_p12 "Pass Type ID" \
  "Trousseau d'accès → session → Mes certificats → « Pass Type ID: pass.… » → clic droit → Exporter → format .p12.
S'il n'y est pas : developer.apple.com → Certificates → « + » → Pass Type ID Certificate, puis double-clic sur
le fichier téléchargé et export. (Le Trousseau s'ouvre.)" \
  "${1:-}" "App/BadgeCreche/PassCertificate.p12" "$HOME/Desktop/PassCertificate.p12" "$HOME/Downloads/PassCertificate.p12")
echo "Fichier : $PASS_P12"
PASS_PASSWORD=""
PASS_SHA1=""
if [ -f App/BadgeCreche/PassSigning.plist ]; then
  PASS_PASSWORD=$(/usr/libexec/PlistBuddy -c "Print :CertificatePassword" App/BadgeCreche/PassSigning.plist 2>/dev/null || true)
  PASS_SHA1=$(check_p12 "$PASS_P12" "$PASS_PASSWORD" "Pass Type ID" || true)
fi
if [ -z "$PASS_SHA1" ]; then
  PASS_PASSWORD=$(read_password "$(basename "$PASS_P12")")
  PASS_SHA1=$(check_p12 "$PASS_P12" "$PASS_PASSWORD" "Pass Type ID") \
    || fail "Ce mot de passe n'ouvre pas $PASS_P12."
  [ -n "$PASS_SHA1" ] || fail "$PASS_P12 ne contient pas de certificat « Pass Type ID » (mauvais fichier ?)."
fi
echo "✅ Mot de passe correct, certificat Pass Type ID ($(wc -c < "$PASS_P12" | tr -d ' ') octets)"

# ── 2. Envoi ──────────────────────────────────────────────────────────────────

step "Envoi des secrets"
if command -v gh > /dev/null && gh auth status > /dev/null 2>&1; then
  base64 -i "$PASS_P12" | gh secret set PASS_CERTIFICATE_P12 --repo "$REPO"
  printf '%s' "$PASS_PASSWORD" | gh secret set PASS_CERTIFICATE_PASSWORD --repo "$REPO"
  echo "✅ Secrets à jour dans GitHub."
else
  echo "GitHub CLI absent ou non connecté (gh auth login) : copie guidée."
  echo "Page : https://github.com/$REPO/settings/secrets/actions — crayon → Update secret → ⌘V → Update secret."
  copy() {
    printf '%s' "$2" | pbcopy
    read -rp "→ $1 est dans le presse-papiers. Collez-le dans GitHub, puis Entrée… " _
  }
  copy PASS_CERTIFICATE_P12 "$(base64 -i "$PASS_P12")"
  copy PASS_CERTIFICATE_PASSWORD "$PASS_PASSWORD"
  printf '' | pbcopy
  echo "✅ Terminé (presse-papiers vidé)."
fi
echo "Vous pouvez dire « go » à Claude : le build partira sur TestFlight."
