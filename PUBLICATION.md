# Publication « légère » — checklist

## Calendrier réaliste

| Étape | Délai |
|---|---|
| Build envoyé sur App Store Connect, **TestFlight interne** (jusqu'à 100 membres de l'équipe) | **aujourd'hui**, ~30 min après l'envoi |
| **TestFlight externe** (lien public à partager aux parents) | après la *Beta App Review* : souvent quelques heures, parfois 24 h |
| **App Store** | après l'App Review : en général 24 à 48 h. Impossible à garantir pour cet après-midi |

Conseil : soumettre cet après-midi **à la fois** la bêta externe (lien TestFlight public pour un premier cercle de parents) et la version App Store.

## 0. Prérequis bloquants

- [ ] Compte **Apple Developer Program** actif (99 €/an). Un compte *organisation* au nom de l'APPC exige un numéro D-U-N-S (plusieurs jours) ; un compte *individuel* affiche le nom de son titulaire comme vendeur sur l'App Store.
- [ ] Certificat **Pass Type ID** créé et intégré (README, section 2).
- [x] Mentions légales complétées (app et site). Reste à reporter le numéro RNA dès réception : `App/BadgeCreche/AppConfig.swift` et `docs/mentions-legales.html`.

## 1. Site web (URL de confidentialité et d'assistance, obligatoires)

1. Fusionner la branche dans `main`.
2. GitHub → *Settings* → *Pages* → *Deploy from a branch* → `main` / `/docs` → *Save*.
3. Vérifier, après 1 à 2 minutes :
   - <https://tikris.github.io/appc-badgeuse/> (URL d'assistance et URL marketing)
   - <https://tikris.github.io/appc-badgeuse/confidentialite.html> (URL de politique de confidentialité)
   - <https://tikris.github.io/appc-badgeuse/demo-qr.png> (QR code pour les testeurs Apple)

## 2. Build

1. Xcode → cible → *General* : *Version* `1.0`, *Build* `1`.
2. Destination *Any iOS Device (arm64)* → *Product* → *Archive*.
3. *Organizer* → *Distribute App* → *App Store Connect* → *Upload*.
4. Tester d'abord sur votre iPhone via TestFlight interne : création du badge, ajout à Wallet, puis passage devant la badgeuse.

### Ou : envoi automatique par GitHub Actions (workflow « TestFlight »)

Le workflow archive, signe et envoie le build sur TestFlight, puis les captures `AppStore/captures`. Il se lance depuis l'onglet *Actions* → *TestFlight* → *Run workflow* (ou par Claude). Préparation, une seule fois : créer ces secrets dans GitHub → *Settings* → *Secrets and variables* → *Actions* → *New repository secret*. Les secrets sont chiffrés, invisibles une fois enregistrés et jamais exposés aux contributions extérieures.

| Secret | Où le trouver | Copier dans le presse-papiers (Terminal) |
|---|---|---|
| `ASC_KEY_ID`, `ASC_ISSUER_ID` | App Store Connect → *Utilisateurs et accès* → *Intégrations* → *App Store Connect API* (clé « Gestionnaire d'apps » ou « Admin » : celle des captures convient) | — |
| `ASC_KEY_P8` | le fichier `AuthKey_XXXX.p8` de cette clé | `pbcopy < ~/.appstoreconnect/private_keys/AuthKey_XXXX.p8` |
| `APPLE_TEAM_ID` | developer.apple.com → *Membership details* → *Team ID* | — |
| `DIST_CERTIFICATE_P12`, `DIST_CERTIFICATE_PASSWORD` | Xcode → *Réglages* → *Comptes* → équipe → *Gérer les certificats* : clic droit sur « Apple Distribution » → *Exporter* (choisir un mot de passe). S'il est grisé (géré dans le cloud), « + » → *Apple Distribution*, puis exporter | `base64 -i Distribution.p12 \| pbcopy` |
| `APPSTORE_PROFILE` | developer.apple.com → *Profiles* → « + » → *App Store Connect* → App ID `fr.parentsapariscentre.badgecreche` → ce certificat Apple Distribution → *Generate* → *Download* | `base64 -i Badge_Creche.mobileprovision \| pbcopy` |
| `PASS_CERTIFICATE_P12`, `PASS_CERTIFICATE_PASSWORD` | `App/BadgeCreche/PassCertificate.p12` et le mot de passe de `PassSigning.plist` | `base64 -i App/BadgeCreche/PassCertificate.p12 \| pbcopy` |

Le numéro de build est celui du projet (`CURRENT_PROJECT_VERSION`), ou celui saisi au lancement. Le build apparaît dans TestFlight après le traitement d'Apple (10 à 30 min).

## 3. Fiche App Store Connect

Nouvelle app : plateforme iOS, langue principale **Français**, bundle ID de votre projet, SKU `appc-badge-creche`.

**Nom** (30 car. max)
```
Badge Crèche – APPC
```

**Sous-titre** (30 car. max) — en France, l'app Apple Wallet s'appelle « Cartes » sur l'iPhone
```
Badge crèche dans l'app Cartes
```

**Texte promotionnel** (170 car. max)
```
Le QR code de votre crèche dans Apple Wallet, affiché automatiquement en arrivant. Gratuit, sans compte ni publicité : vos données restent sur votre iPhone.
```

**Description**
```
Fini le badge de crèche oublié ou introuvable au fond du sac !

Badge Crèche transforme le QR code remis par votre crèche en début d'année en badge Apple Wallet. Devant la crèche, il s'affiche tout seul sur l'écran verrouillé : il ne reste plus qu'à le présenter à la badgeuse, à l'arrivée comme au départ.

EN TROIS ÉTAPES
• Choisissez votre crèche : les plus proches vous sont proposées, et toutes les crèches de Paris sont dans la liste.
• Scannez le QR code de la crèche, ou importez-le depuis une photo, une capture d'écran ou un PDF.
• Ajoutez le badge à Apple Wallet.

Le nom de l'enfant et celui de la crèche sont facultatifs : c'est vous qui choisissez ce qui s'affiche.

VOS DONNÉES VOUS APPARTIENNENT
Votre QR code, le nom de votre enfant et votre position ne quittent jamais votre iPhone. Aucun compte, aucune publicité, aucun traçage : le badge est créé directement sur l'iPhone. Seule option, désactivée par défaut : partager de façon anonyme le nom de votre crèche avec l'APPC, pour ses statistiques.

UNE INITIATIVE DE L'APPC
Badge Crèche est proposée gratuitement par l'association Parents à Paris Centre (APPC). Rejoignez la communauté des parents de Paris Centre depuis l'application !

Application indépendante, non affiliée à la Ville de Paris ni aux gestionnaires de crèches.
```

**Mots-clés** (100 car. max)
```
crèche,badge,badgeuse,QR code,cartes,wallet,pass,parents,Paris,garde,enfant,pointage,APPC
```

**Catégorie** : Utilitaires (secondaire : Style de vie) · **Prix** : gratuit · **Copyright** : `2026 Parents à Paris Centre`

**URL d'assistance** : `https://tikris.github.io/appc-badgeuse/#support`
**URL de confidentialité** : `https://tikris.github.io/appc-badgeuse/confidentialite.html`

**Confidentialité de l'app (« étiquette »)** : *Données non collectées*, tant que Matomo n'est pas branché (`AppConfig.statsEndpoint` vide : rien n'est envoyé). La position est utilisée uniquement sur l'appareil (tri des crèches) et jamais transmise : au sens d'Apple, elle n'est pas « collectée ».
Dès que Matomo est branché (voir [MATOMO.md](MATOMO.md)) : *Données non associées à votre identité* → *Données d'utilisation* → *Interactions avec le produit*, finalité *Analyses* ; aucune donnée utilisée pour vous suivre. Mettre à jour en même temps `PrivacyInfo.xcprivacy` et les notes App Review ci-dessous.

**Classification par âge** : répondre « Non » / « Aucun » partout → 4+. Ne pas cocher « Made for Kids » (l'app s'adresse aux parents).

**Chiffrement** : l'app n'utilise que des signatures numériques (exemption) → `App Uses Non-Exempt Encryption = NO` dans l'Info.plist.

**Captures d'écran** : prêtes dans [`AppStore/captures/`](AppStore/captures) (iPhone 6,9", 1320 × 2868, données fictives), à glisser dans l'ordre dans la section *iPhone 6,9"*. Elles sont produites par le workflow « Captures App Store » (simulateur, dépôt dans `AppStore/raw/`) puis mises en forme par `python3 tools/make_store_screenshots.py AppStore/raw`.

**Carrousel Instagram** : 4 visuels 4:5 (1080 × 1350) dans [`AppStore/instagram/`](AppStore/instagram), tirés des mêmes captures par `python3 tools/make_instagram_carousel.py`.

**Icône** : rien à envoyer, App Store Connect la prend dans le build. Copie en 1024 × 1024 : [`AppStore/icone-1024.png`](AppStore/icone-1024.png).

**Notes pour l'App Review** (en anglais, < 4 000 caractères ; informations demandées par Apple au titre de la règle 2.1) : dans [`AppStore/review-notes.txt`](AppStore/review-notes.txt). Le workflow « TestFlight » les envoie dans App Store Connect avec le QR code de démonstration en pièce jointe (`tools/asc_release.swift`) ; joindre aussi la vidéo.

## 4. Après la mise en ligne

- Annoncer l'app sur la communauté WhatsApp avec le lien App Store (ou le lien TestFlight public en attendant).
- Recueillir les premiers retours : la badgeuse de chaque crèche lit-elle bien l'écran ? Le badge s'affiche-t-il bien à l'arrivée ?
- Pistes V2 : plusieurs enfants/crèches, signature côté serveur protégée par App Attest, version Android (Google Wallet).
