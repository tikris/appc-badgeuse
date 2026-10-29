# Service de signature des badges Wallet

Garde la clé du certificat Wallet (Pass Type ID) hors de l'application. L'iPhone construit le badge, puis envoie seulement le `manifest.json` : les empreintes SHA-1 des fichiers du badge, sans rien de lisible. Le service renvoie la signature PKCS#7 détachée que Wallet exige.

```
GET  /  → { challenge, passTypeIdentifier, teamIdentifier }           défi valable 5 minutes
POST /  { challenge, manifest, keyId, attestation }  (base64)
        → { signature }                                               PKCS#7 DER, base64
```

**Vie privée**
- Le service ne reçoit ni QR code, ni nom d'enfant, ni position.
- L'empreinte de `pass.json` n'est pas réversible : le fichier contient un identifiant aléatoire (UUID) propre à chaque badge.
- Rien n'est enregistré : ni base de données, ni journal du contenu des requêtes (seuls les codes d'erreur sont écrits).

**Sécurité**
- Chaque signature exige une attestation [App Attest](https://developer.apple.com/documentation/devicecheck/establishing-your-app-s-integrity) portant sur le défi et sur ce manifest. Elle prouve que la requête vient de l'app Badge Crèche, non modifiée, sur un vrai iPhone. Le service vérifie :
  - la chaîne de certificats jusqu'à la racine App Attest d'Apple ;
  - le nonce ;
  - l'identifiant de la clé ;
  - l'identifiant de l'app (Team ID tiré du certificat + `fr.parentsapariscentre.badgecreche`) ;
  - le compteur ;
  - l'environnement (production).
- Seuls des manifests de pass sont signés : un objet JSON de noms de fichiers et d'empreintes SHA-1, avec `pass.json`.
- La clé des défis est dérivée de la clé du certificat : il n'y a pas de secret supplémentaire à gérer.

**Hébergement** : Scaleway Serverless Functions, région Paris (`fr-par`), espace de noms `badge-creche`, fonction `signature`, Python 3.13.
- Variables secrètes de la fonction, saisies dans la console Scaleway et jamais dans GitHub : `PASS_CERTIFICATE_PEM` et `PASS_PRIVATE_KEY_PEM`. Les deux acceptent un PEM ou le base64 seul. `tools/certificat_serveur.sh` crée ce certificat depuis le Mac et les copie.
- Les certificats racines d'Apple (WWDR G4, App Attest) sont téléchargés au déploiement. Leurs empreintes s'affichent dans le journal.

**Tests et déploiement** : workflow « Service de signature ».
- Tests avec de fausses chaînes de certificats à chaque modification du dossier `server/`.
- Déploiement à la demande (`server/deploy.py`, secrets GitHub `SCW_SECRET_KEY` et `SCW_PROJECT_ID`).

```bash
pip install -r server/requirements.txt
python -m unittest discover -s server/tests
```
