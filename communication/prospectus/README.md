# Prospectus A4 pour les crèches

- **À imprimer** : [`badge-creche-prospectus-a4.pdf`](badge-creche-prospectus-a4.pdf), en A4, à taille réelle (100 %, pas « Ajuster à la page »). Il reste lisible en noir et blanc.
- **Aperçu** : [`badge-creche-prospectus-a4.png`](badge-creche-prospectus-a4.png).
- **Source** : `prospectus.html`. Régénérer le PDF et l'aperçu : `node communication/prospectus/render.js` (Playwright).

## Le QR code

Il mène à `https://tikris.github.io/appc-badgeuse/app/` (page `docs/app/index.html`). Cette adresse ne doit jamais changer, puisqu'elle est imprimée. La page envoie l'iPhone vers l'App Store et Android vers Google Play, selon les liens renseignés en tête du fichier (`APP_STORE`, `GOOGLE_PLAY`). Tant qu'un lien est vide, elle affiche une consigne de recherche, ou l'invitation à tester sur Android. Le lien App Store est renseigné (fiche « Badgeuse Crèche – APPC », id6823635433).

`qr-telecharger.svg` a été généré avec `segno` (correction Q, version 4). Le contrôle a été fait avec `zxing-cpp` sur l'aperçu : le code est lu en couleur, en niveaux de gris, réduit au quart et flouté. Le badge dessiné dans le téléphone est un pictogramme non scannable, pour éviter toute confusion avec le vrai code.

## Avant d'afficher

1. Accord de la direction de chaque crèche : un affichage dans un établissement municipal se demande.
2. Quand l'app sera publiée sur Google Play, retirer la mention « bientôt » et régénérer le PDF.
