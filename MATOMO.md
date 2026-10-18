# Statistiques des crèches avec Matomo (auto-hébergé)

But : savoir **quelles crèches** sont choisies au moment de créer un badge, sans renoncer à la promesse de l'app.

## Ce que l'app envoie (et ce qu'elle n'envoie pas)

- **Uniquement si le parent l'accepte** : option « Partager le nom de ma crèche, de façon anonyme », **désactivée par défaut**, proposée à la création du badge et dans « À propos ».
- **Un seul événement**, à l'enregistrement du badge, puis si le parent change de crèche :
  - catégorie : `Badge créé` ou `Crèche changée` ;
  - action : `Parmi les 3 plus proches`, `Dans la liste` ou `Hors liste` ;
  - nom : `Crèche rue Montmartre · 75002` (ou `Hors liste` : une adresse saisie à la main n'est jamais envoyée).
- **Jamais** : QR code, nom de l'enfant, position, identifiant de visiteur, cookie.
- Tant que `AppConfig.statsEndpoint` vaut `nil`, **rien n'est envoyé** et l'option n'apparaît pas.

Code : `App/BadgeCreche/Core/CrecheStat.swift` (contenu de l'envoi, testé) et `App/BadgeCreche/Services/CrecheStats.swift` (envoi).

## 1. Hébergement (≈ 5 € par mois)

Un hébergement web mutualisé suffit : **PHP 8**, **MySQL ou MariaDB**, **HTTPS** obligatoire (iOS refuse le HTTP). De préférence chez un hébergeur français ou européen (o2switch, OVHcloud, Infomaniak…), idéalement celui qui gère déjà le domaine `appc.paris`.

1. Créez le sous-domaine **`stats.appc.paris`** et activez son certificat HTTPS (Let's Encrypt, en général un clic).
2. Créez une base de données MySQL et son utilisateur, et notez les identifiants.

## 2. Installation de Matomo (≈ 15 min)

- **Avec un installateur en un clic** (Softaculous ou équivalent, proposé par la plupart des hébergeurs) : choisissez Matomo et installez-le sur `stats.appc.paris`.
- **Sinon** : téléchargez <https://builds.matomo.org/matomo.zip>, décompressez-le, envoyez le contenu du dossier `matomo` dans le dossier du sous-domaine (FTP, par exemple avec FileZilla), puis ouvrez <https://stats.appc.paris>.

L'assistant demande ensuite :

1. Les identifiants de la base de données.
2. Un super-utilisateur : mot de passe long et unique.
3. Le premier site :
   - nom : `Badge Crèche (app iOS)` ;
   - URL : `http://fr.parentsapariscentre.badgecreche` ;
   - fuseau horaire : Europe/Paris.
4. Le code de suivi JavaScript : **ignorez-le**, l'app parle directement à Matomo.

Notez l'**ID du site** : `1` si c'est le premier.

## 3. Réglages de confidentialité (à ne pas sauter)

Ces réglages tiennent les engagements écrits dans la politique de confidentialité.

- **Administration → Confidentialité → Anonymiser les données de suivi**
  - Anonymiser l'adresse IP des visiteurs : **Oui, 2 octets**.
  - Utiliser aussi l'IP anonymisée pour enrichir les visites : **Oui**.
- **Administration → Confidentialité → Supprimer les anciennes données**
  - Supprimer régulièrement les anciennes données brutes : **Oui, après 180 jours** (la politique annonce 25 mois au plus).
  - Garder les rapports : ce sont des totaux par crèche, anonymes.
- **Administration → Système → Réglages généraux**
  - Désactiver le **journal des visites et le profil du visiteur**.
- **Administration → Personnel → Sécurité**
  - Activer la **double authentification**.

Pensez aussi aux mises à jour de Matomo (signalées dans l'administration) et aux sauvegardes de la base (souvent incluses chez l'hébergeur).

## 4. Brancher l'app

Dans `App/BadgeCreche/AppConfig.swift` :

```swift
static let statsEndpoint: URL? = URL(string: "https://stats.appc.paris/matomo.php")
static let statsSiteID = 1
```

Dans `App/BadgeCreche/PrivacyInfo.xcprivacy`, déclarer la collecte dans `NSPrivacyCollectedDataTypes` :

```xml
<dict>
	<key>NSPrivacyCollectedDataType</key>
	<string>NSPrivacyCollectedDataTypeProductInteraction</string>
	<key>NSPrivacyCollectedDataTypeLinked</key>
	<false/>
	<key>NSPrivacyCollectedDataTypeTracking</key>
	<false/>
	<key>NSPrivacyCollectedDataTypePurposes</key>
	<array>
		<string>NSPrivacyCollectedDataTypePurposeAnalytics</string>
	</array>
</dict>
```

Puis nouveau build. L'option apparaît dans l'éditeur du badge et dans « À propos ». Mettre à jour l'étiquette de confidentialité et les notes App Review (PUBLICATION.md).

**Test du serveur, avant l'app.** La commande suivante doit répondre `HTTP/2 204` :

```
curl -i "https://stats.appc.paris/matomo.php?idsite=1&rec=1&apiv=1&send_image=0&ca=1&url=http%3A%2F%2Ffr.parentsapariscentre.badgecreche%2Fbadge&e_c=Test&e_a=Test&e_n=Test"
```

## 5. Lire les statistiques

Ouvrez **Comportement → Événements**.

- **Noms d'événements** : le classement des crèches (`Crèche rue Montmartre · 75002`…).
- **Actions d'événements** : comment la crèche a été trouvée. Cela permet de savoir si les 3 propositions suffisent ou si la liste est nécessaire.
- Pour croiser les deux, cliquez sur une catégorie (`Badge créé`), puis sur une action.
- L'export CSV ou Excel se fait en bas de chaque tableau.

**Limite à garder en tête** : seuls les parents qui ont accepté sont comptés. Les chiffres donnent un **classement fiable des crèches**, pas le nombre total d'utilisateurs. Pour le total, utilisez les téléchargements d'App Store Connect.

## 6. Avant la mise en ligne

- **Hébergeur** : compléter son nom et son adresse dans `docs/confidentialite.html` et `docs/mentions-legales.html` (repères `À compléter`).
- **App Store Connect**, rubrique Confidentialité de l'app : déclarer *Interactions avec le produit*, finalité *Analyses*, non associées à l'identité (voir PUBLICATION.md).
