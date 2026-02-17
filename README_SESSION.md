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

## Déploiement sur Render (Ruby/Sinatra)

### Pré-requis (déjà ajoutés au projet)
- `Gemfile` pour les dépendances Ruby
- `config.ru` (entrée Rack)
- `.ruby-version` pour fixer la version Ruby

### Paramètres Render recommandés
- **Build Command** : `bundle install`
- **Start Command** : `bundle exec rackup -p $PORT -o 0.0.0.0`
- **Environment Variables** :
	- `SESSION_SECRET` (obligatoire)
	- `USER_DATA_DIR` (optionnel, recommandé pour persistance)

### Notes importantes
- Render impose d'écouter le port `$PORT` (déjà géré dans `serveur/server.rb`).
- Le fichier `serveur/users.json` est stocké sur disque local : sur Render, le système de fichiers est éphémère.
	- Pour garder les utilisateurs, utilisez un **disque persistant** Render ou une **base de données**.
	- Si vous activez un disque persistant, définissez `USER_DATA_DIR` vers le chemin du disque (ex: `/var/data`).
