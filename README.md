# appc-badgeuse — Badge Crèche

L'APPC met à disposition une badgeuse intégrée à son portefeuille iPhone pour badger à l'arrivée et au départ de la crèche.

**Badge Crèche** transforme le QR code remis par la crèche en début d'année en pass **Apple Wallet**, qui s'affiche tout seul sur l'écran verrouillé à l'approche de la crèche.

- Champs : QR code (obligatoire), adresse de la crèche (obligatoire, pour l'affichage à proximité), nom et prénom de l'enfant (facultatif, désactivé par défaut), nom de la crèche (facultatif).
- 100 % local : pas de compte, pas de serveur, pas de base de données. Le pass est **signé sur l'iPhone**.
- Version 1 : un seul badge par iPhone (mis à jour en place dans Wallet).
- Une initiative de l'association **Parents à Paris Centre (APPC)**, avec un lien vers la [communauté WhatsApp](https://chat.whatsapp.com/CiqGioqeO4yA93wTwvFJMW) dans l'application et au dos du pass.

Publication sur l'App Store : voir **[PUBLICATION.md](PUBLICATION.md)**.

---

## 1. Intégrer le code dans le projet Xcode (≈ 10 min)

Prérequis : Xcode 26 (ou 16), un projet iOS « App » SwiftUI déjà créé.

1. **Réglages de la cible** (onglet *General*) :
   - *Minimum Deployments* : **iOS 17.0** (sinon les iPhone pas à jour ne pourront pas installer l'app).
   - *Supported Destinations* : **iPhone uniquement** (supprimer iPad, Mac, Vision) — moins de captures d'écran à fournir.
   - *Display Name* : `Badge Crèche`.
2. **Code** : glisser le dossier `App/BadgeCreche` dans le navigateur de projet Xcode (cocher *Copy items if needed* et la cible). Supprimer le `ContentView.swift` généré par Xcode. **Garder** le fichier `…App.swift` de Xcode : il appelle déjà `ContentView()`.
3. **Icône** : dans le Finder, remplacer le dossier `AppIcon.appiconset` de votre `Assets.xcassets` par celui de `App/Assets.xcassets/AppIcon.appiconset` (variantes claire, sombre et teintée incluses).
4. **Info** (onglet *Info* de la cible, *Custom iOS Target Properties*) :
   - `Privacy - Camera Usage Description` : *L'appareil photo sert uniquement à scanner le QR code remis par votre crèche. Aucune image n'est conservée.*
   - `App Uses Non-Exempt Encryption` : **NO** (seule une signature numérique est utilisée, cas exempté).
5. `PrivacyInfo.xcprivacy` est dans le dossier : vérifier qu'il fait bien partie de la cible.

## 2. Certificat Wallet « Pass Type ID » (≈ 15 min, compte Apple Developer requis)

Apple n'accepte que des pass signés par un certificat émis pour votre équipe.

1. [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list/passTypeId) → *Identifiers* → **+** → *Pass Type IDs* → description `Badge Crèche`, identifiant par ex. `pass.fr.parentsapariscentre.badgecreche`.
2. Sur le Mac : *Trousseau d'accès* → menu *Trousseau d'accès* → *Assistant de certification* → *Demander un certificat à une autorité de certificat…* → votre e-mail, *Enregistré sur le disque*.
3. developer.apple.com → *Certificates* → **+** → *Pass Type ID Certificate* → choisir l'identifiant → envoyer la demande (`.certSigningRequest`) → télécharger `pass.cer` → double-cliquer pour l'installer.
4. *Trousseau d'accès* → *Mes certificats* → « Pass Type ID: pass.… » → clic droit → *Exporter* → format `.p12`, nom **`PassCertificate.p12`**, choisir un mot de passe.
5. Télécharger le certificat intermédiaire Apple **WWDR G4** : <https://www.apple.com/certificateauthority/AppleWWDRCAG4.cer>.
6. Copier `tools/PassSigning.example.plist` en **`PassSigning.plist`** et y mettre le mot de passe du `.p12`.
7. Glisser `PassCertificate.p12`, `AppleWWDRCAG4.cer` et `PassSigning.plist` dans le projet Xcode (cible cochée).
   ⚠️ Le dépôt est **public** : `*.p12` et `PassSigning.plist` sont ignorés par git, ne les publiez jamais.
8. *Signing & Capabilities* → **+ Capability** → **Wallet** → cocher le Pass Type ID créé à l'étape 1. Sans cette capacité, l'ajout fonctionne mais l'app ne peut ni détecter, ni mettre à jour, ni supprimer le pass déjà présent dans Wallet.

L'identifiant du type de pass et le Team ID sont **lus directement dans le certificat** : rien d'autre à configurer dans le code.

## 3. Tester

- Sur un iPhone réel (scan caméra) ou sur le simulateur (import d'image) : utiliser [`docs/demo-qr.png`](docs/demo-qr.png) comme QR code de démonstration.
- Les textes et liens propres à l'APPC sont regroupés dans [`App/BadgeCreche/AppConfig.swift`](App/BadgeCreche/AppConfig.swift). Un `#warning` rappelle de compléter les mentions légales.
- La première fois, vérifier à la crèche que la badgeuse lit bien le QR code affiché sur l'écran.

## Architecture

```
App/BadgeCreche/
  ContentView.swift          écran racine
  AppConfig.swift            textes, liens et mentions légales APPC
  Core/                      sans UIKit, testé sur macOS
    BadgeData.swift          modèle du badge
    PassBuilder.swift        pass.json + manifest + signature + archive .pkpass
    CMSSignature.swift       signature PKCS#7 détachée (RFC 5652)
    PassSigningIdentity.swift  lecture du .p12, Pass Type ID / Team ID depuis le certificat
    DER.swift, ZipArchive.swift  encodage ASN.1 et ZIP minimalistes (aucune dépendance)
  Services/                  stockage local, Wallet, lecture et rendu des QR codes, images du pass
  Features/                  écrans SwiftUI (accueil, éditeur, adresse, scanner, À propos)
docs/                        site GitHub Pages : présentation, confidentialité, mentions légales
Tests/                       tests de signature avec une fausse chaîne de certificats
project.yml, CI/             projet XcodeGen utilisé par la CI (plan B : `xcodegen` génère un projet complet)
```

La CI (GitHub Actions, macOS) compile l'app pour iOS et vérifie la signature d'un pass généré avec le framework Security d'Apple et avec OpenSSL.

## Limite connue (assumée pour la V1)

Signer sur l'iPhone impose d'embarquer la clé privée du certificat Pass Type ID dans l'application : une personne motivée peut l'extraire et signer des pass au nom de ce Pass Type ID. Les conséquences restent limitées : un pass n'exécute pas de code, et le certificat peut être révoqué puis remplacé. **Évolution recommandée (V2)** : un petit service de signature qui ne reçoit que le `manifest.json` (des empreintes SHA-1, aucune donnée personnelle), protégé par App Attest.

## Licence

GPL v3 — voir [LICENSE](LICENSE).
