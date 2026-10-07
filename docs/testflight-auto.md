# Envoi automatique vers TestFlight

Le fichier `.github/workflows/testflight.yml` construit l'app sur un Mac de GitHub et l'envoie vers TestFlight :
à chaque fusion dans `main`, et à la demande (onglet **Actions › TestFlight › Run workflow**).
Plus besoin du Terminal. Il faut une seule chose : une clé API App Store Connect, rangée dans les secrets du dépôt.

## 1. Créer la clé (une fois, 3 minutes)

1. Sur https://appstoreconnect.apple.com : **Utilisateurs et accès › Intégrations › API App Store Connect**.
2. Onglet **Clés d'équipe** › **+** (bouton « Générer une clé API » la première fois).
3. Nom : `GitHub TestFlight`. Accès : **Admin** (nécessaire pour que GitHub crée lui-même les certificats de signature).
4. Note l'**ID de la clé** (10 caractères) et, en haut de la page, l'**ID de l'émetteur** (« Issuer ID », un long code avec des tirets).
5. Clique **Télécharger** : tu obtiens un fichier `AuthKey_XXXXXXXXXX.p8`. Apple ne le laisse télécharger **qu'une fois** : garde-le.

## 2. Ranger la clé dans GitHub

Sur https://github.com/baghrir-studio/goslo-records : **Settings › Secrets and variables › Actions › New repository secret**. Crée trois secrets :

| Nom | Valeur |
|---|---|
| `ASC_KEY_ID` | l'ID de la clé (10 caractères) |
| `ASC_ISSUER_ID` | l'ID de l'émetteur |
| `ASC_KEY_P8` | tout le contenu du fichier `.p8`, ouvert avec TextEdit, de `-----BEGIN PRIVATE KEY-----` à `-----END PRIVATE KEY-----` inclus |

## 3. Lancer

Onglet **Actions › TestFlight › Run workflow**. Compter 15 à 25 minutes, puis le traitement d'Apple (10 à 30 minutes).
Ensuite, chaque fusion dans `main` envoie un build tout seul.

Sans les secrets, le workflow s'arrête à la première étape, en vert : rien ne casse.
