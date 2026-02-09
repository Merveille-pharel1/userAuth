# Session secret (développement)

Pour éviter l'erreur "Session cookie encryptor error: HMAC is invalid" après chaque redémarrage du serveur, utilisez un secret de session persistant pendant le développement.

Générer un secret (une seule fois) :

```bash
ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'
```

Démarrer le serveur en passant la variable d'environnement :

```bash
SESSION_SECRET="votre_secret_genere" ruby serveur/server.rb
```

ou utilisez le script fourni `start_server.sh` qui :
- crée un fichier `.env` contenant `SESSION_SECRET` si celui-ci n'existe pas
- exporte la variable et lance le serveur

Ne commitez jamais `.env` dans le dépôt.

Notes :
- En production, utilisez une valeur de secret gérée par votre système d'Orchestration / CI (Vault, secrets manager, variables d'environnement du serveur) et activez `secure: true` pour le cookie (HTTPS obligatoire).
- Si vous souhaitez une rotation d'ID de session côté serveur (vraie rotation), utilisez un store de sessions serveur (ex: Redis) au lieu du cookie store.
