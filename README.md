# appc-badgeuse — Badge Crèche

L'APPC met à disposition une badgeuse intégrée à son portefeuille iPhone pour badger à l'arrivée et au départ de la crèche.

**Badge Crèche** transforme le QR code remis par la crèche en début d'année en pass **Apple Wallet**, qui s'affiche tout seul sur l'écran verrouillé à l'approche de la crèche.

- Champs : QR code (obligatoire), adresse de la crèche (obligatoire, pour l'affichage à proximité), nom et prénom de l'enfant (facultatif, désactivé par défaut), nom de la crèche (facultatif).
- 100 % local : **rien n'est stocké dans le cloud ni sur un serveur**, pas de compte, pas de base de données. Le pass est **signé sur l'iPhone** et les données appartiennent entièrement à l'utilisateur (fichier même exclu des sauvegardes iCloud).
- Version 1 : un seul badge par iPhone (mis à jour en place dans Wallet).
- Une initiative de l'association **Parents à Paris Centre (APPC)**, avec un lien vers la [communauté WhatsApp](https://chat.whatsapp.com/CiqGioqeO4yA93wTwvFJMW) dans l'application et au dos du pass.

Publication sur l'App Store : voir **[PUBLICATION.md](PUBLICATION.md)**.

---

## 1. Ouvrir et lancer le projet (≈ 5 min)

Prérequis : Xcode 16 ou plus récent (testé en CI avec Xcode 26.6).

1. Récupérer le code :
   ```bash
   git clone https://github.com/tikris/appc-badgeuse.git
   cd appc-badgeuse
   open BadgeCreche.xcodeproj
   ```
   (ou dans Xcode : *Integrate* → *Clone…* → `https://github.com/tikris/appc-badgeuse.git`).
2. Dans Xcode : cliquer sur le projet **BadgeCreche** → cible **BadgeCreche** → onglet **Signing & Capabilities** → *Team* : choisir votre équipe Apple Developer.
   Si Xcode signale que l'identifiant `fr.parentsapariscentre.badgecreche` est déjà pris, le modifier (ex. `fr.appc.badgecreche`).
3. Choisir un simulateur (ex. *iPhone 17 Pro*) → **⌘R**.
   L'app se lance et tout l'écran de création fonctionne. Le bouton Wallet affichera « certificat introuvable » tant que l'étape 2 n'est pas faite : c'est normal.

Déjà réglé dans le projet : iOS 17 minimum, iPhone uniquement, icône, autorisation caméra, `ITSAppUsesNonExemptEncryption = NO`, manifeste de confidentialité et capacité Wallet (tous les types de pass de l'équipe).

## 2. Certificat Wallet « Pass Type ID » (≈ 15 min, compte Apple Developer requis)

Apple n'accepte que des pass signés par un certificat émis pour votre équipe.

1. [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list/passTypeId) → *Identifiers* → **+** → *Pass Type IDs* → description `Badge Crèche`, identifiant par ex. `pass.fr.parentsapariscentre.badgecreche`.
2. Sur le Mac : *Trousseau d'accès* → menu *Trousseau d'accès* → *Assistant de certification* → *Demander un certificat à une autorité de certificat…* → votre e-mail, *Enregistré sur le disque*.
3. developer.apple.com → *Certificates* → **+** → *Pass Type ID Certificate* → choisir l'identifiant → envoyer la demande (`.certSigningRequest`) → télécharger `pass.cer` → double-cliquer pour l'installer.
4. *Trousseau d'accès* → *Mes certificats* → « Pass Type ID: pass.… » → clic droit → *Exporter* → format `.p12`, nom **`PassCertificate.p12`**, choisir un mot de passe.
5. Télécharger le certificat intermédiaire Apple **WWDR G4** : <https://www.apple.com/certificateauthority/AppleWWDRCAG4.cer>.
6. Copier `tools/PassSigning.example.plist` en **`PassSigning.plist`** et y mettre le mot de passe du `.p12`.
7. Dans le Finder, déposer `PassCertificate.p12`, `AppleWWDRCAG4.cer` et `PassSigning.plist` dans le dossier **`App/BadgeCreche/`** : ils apparaissent automatiquement dans Xcode et sont intégrés à l'app.
   ⚠️ Le dépôt est **public** : `*.p12` et `PassSigning.plist` sont ignorés par git, ne les publiez jamais.
8. Relancer (**⌘R**) : « Ajouter à Apple Wallet » fonctionne, sur le simulateur comme sur l'iPhone.

L'identifiant du type de pass et le Team ID sont **lus directement dans le certificat** : rien d'autre à configurer dans le code.

## 3. Tester

- Sur un iPhone réel (scan caméra) ou sur le simulateur (glisser [`docs/demo-qr.png`](docs/demo-qr.png) sur le simulateur pour l'ajouter à Photos, puis « Choisir une photo »).
- Pour installer sur votre iPhone : le brancher (ou même Wi-Fi), le choisir comme destination dans Xcode, **⌘R**. La première fois : *Réglages → Confidentialité et sécurité → Mode développeur* à activer sur l'iPhone.
- Les textes et liens propres à l'APPC sont regroupés dans [`App/BadgeCreche/AppConfig.swift`](App/BadgeCreche/AppConfig.swift). Un `#warning` rappelle de compléter les mentions légales.
- La première fois, vérifier à la crèche que la badgeuse lit bien le QR code affiché sur l'écran.

## Architecture

```
BadgeCreche.xcodeproj        projet Xcode (dossier App/BadgeCreche synchronisé : tout fichier ajouté y est inclus)
App/BadgeCreche/
  BadgeCrecheApp.swift       point d'entrée
  ContentView.swift          écran racine
  AppConfig.swift            textes, liens et mentions légales APPC
  Core/                      sans UIKit, testé sur macOS
    BadgeData.swift          modèle du badge
    PassBuilder.swift        pass.json + manifest + signature + archive .pkpass
    CMSSignature.swift       signature PKCS#7 détachée (RFC 5652)
    PassSigningIdentity.swift  lecture du .p12, Pass Type ID / Team ID depuis le certificat
    DER.swift, ZipArchive.swift  encodage ASN.1 et ZIP minimalistes (aucune dépendance)
    QRCodeReader.swift       lecture du QR code (photo réduite à 2048 px, PDF), testée sur macOS
  Services/                  stockage local, Wallet, aperçu du QR code et images du pass (mis en cache)
  Features/                  écrans SwiftUI (accueil, éditeur, adresse, scanner, À propos)
docs/                        site GitHub Pages : présentation, confidentialité, mentions légales
Tests/                       tests de signature avec une fausse chaîne de certificats
```

La CI (GitHub Actions, macOS) compile le projet Xcode (simulateur et iPhone) et vérifie la signature d'un pass généré avec le framework Security d'Apple et avec OpenSSL.

## Limite connue (assumée pour la V1)

Signer sur l'iPhone impose d'embarquer la clé privée du certificat Pass Type ID dans l'application : une personne motivée peut l'extraire et signer des pass au nom de ce Pass Type ID. Les conséquences restent limitées : un pass n'exécute pas de code, et le certificat peut être révoqué puis remplacé. **Évolution recommandée (V2)** : un petit service de signature qui ne reçoit que le `manifest.json` (des empreintes SHA-1, aucune donnée personnelle), protégé par App Attest.

## Licence

GPL v3 — voir [LICENSE](LICENSE).
