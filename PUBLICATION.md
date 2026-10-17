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
Le QR code de votre crèche dans Apple Wallet, affiché automatiquement en arrivant. Gratuit, sans compte, rien dans le cloud : vos données vous appartiennent.
```

**Description**
```
Fini le badge de crèche oublié ou introuvable au fond du sac !

Badge Crèche transforme le QR code remis par votre crèche en début d'année en badge Apple Wallet. À l'approche de la crèche, il s'affiche tout seul sur l'écran verrouillé : il ne reste plus qu'à le présenter à la badgeuse, à l'arrivée comme au départ.

EN TROIS ÉTAPES
• Choisissez votre crèche : les plus proches vous sont proposées, et toutes les crèches de Paris sont dans la liste.
• Scannez le QR code de la crèche, ou importez-le depuis une photo, une capture d'écran ou un PDF.
• Ajoutez le badge à Apple Wallet.

Le nom de l'enfant et celui de la crèche sont facultatifs : c'est vous qui choisissez ce qui s'affiche.

VOS DONNÉES VOUS APPARTIENNENT
Rien n'est stocké dans le cloud ni sur un serveur distant. Aucun compte, aucune publicité, aucun traçage : le badge est créé directement sur votre iPhone et personne d'autre que vous n'y a accès.

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

**Confidentialité de l'app (« étiquette »)** : *Données non collectées*. La position est utilisée, mais uniquement sur l'appareil (tri des crèches) et jamais transmise : au sens d'Apple, elle n'est pas « collectée ».

**Classification par âge** : répondre « Non » / « Aucun » partout → 4+. Ne pas cocher « Made for Kids » (l'app s'adresse aux parents).

**Chiffrement** : l'app n'utilise que des signatures numériques (exemption) → `App Uses Non-Exempt Encryption = NO` dans l'Info.plist.

**Captures d'écran** : prêtes dans [`AppStore/captures/`](AppStore/captures) (iPhone 6,9", 1320 × 2868, données fictives), à glisser dans l'ordre dans la section *iPhone 6,9"*. Elles sont produites par le workflow « Captures App Store » (simulateur, dépôt dans `AppStore/raw/`) puis mises en forme par `python3 tools/make_store_screenshots.py AppStore/raw`.

**Icône** : rien à envoyer, App Store Connect la prend dans le build. Copie en 1024 × 1024 : [`AppStore/icone-1024.png`](AppStore/icone-1024.png).

**Notes pour l'App Review** (en anglais) :
```
Badge Crèche lets parents store the QR code their nursery gives them for its check-in terminal ("badgeuse") as an Apple Wallet pass that appears on the Lock Screen near the nursery. No account and no server: the pass is generated and signed on the device.

How to test:
1. Open https://tikris.github.io/appc-badgeuse/demo-qr.png and save the image to Photos (or display it on another screen and use "Scanner le QR code").
2. Tap "Créer mon badge". The app asks for your location, only to suggest the 3 nearest nurseries; it is processed on device and never sent anywhere. Outside Paris, or if you decline, tap "Autre crèche" and pick any nursery from the list (search e.g. "Lauzin").
3. In "QR code de la crèche", tap "Choisir une photo ou une capture d'écran" and pick the image.
4. Optionally enable "Afficher le nom de l'enfant" and type a first name.
5. Tap "Enregistrer", then "Add to Apple Wallet".

The app is published free of charge by the non-profit parents' association Parents à Paris Centre (APPC). It is not affiliated with the City of Paris or with nursery operators. The WhatsApp link in "À propos" invites parents to join the association's community.
```

## 4. Après la mise en ligne

- Annoncer l'app sur la communauté WhatsApp avec le lien App Store (ou le lien TestFlight public en attendant).
- Recueillir les premiers retours : la badgeuse de chaque crèche lit-elle bien l'écran ? Le badge s'affiche-t-il bien à l'arrivée ?
- Pistes V2 : plusieurs enfants/crèches, signature côté serveur protégée par App Attest, version Android (Google Wallet).
