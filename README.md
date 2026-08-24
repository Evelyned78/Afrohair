# CodePhenix WordPress Boilerplate

Boilerplate WordPress avec Docker, Composer et Make pour un développement rapide et reproductible.

## Démarrage rapide

### Prérequis

- Docker & Docker Compose
- Make
- Un IDE
- NGINX

### Installation

1. **Cloner le projet :**

```bash
git clone https://github.com/CodePhenix/wordpress-boilerplate.git
cd wordpress-boilerplate
```

2. **Créer et éditer le fichier `.env` avec les informations nécessaires :**

```bash
cp .env.example .env
nano .env
```

3. **Initialiser le projet :**

```bash
make install
```

## Accès au site (par défaut)

- **WordPress :** `http://*nom-du-site*.local`
- **phpMyAdmin :** `http://127.0.0.1:8080`
- **Mailcatcher :** `http://localhost:1080`

## Commandes Make disponibles

| Commande                | Description                                                                                |
| ----------------------- | ------------------------------------------------------------------------------------------ |
| `make install`          | Initialiser le projet complet (ajout aux hosts, démarrage, installation, configuration)    |
| `make hosts-add`        | Ajouter l'hôte au fichier hosts                                                            |
| `make up`               | Démarrer tous les conteneurs Docker                                                        |
| `make stop`             | Arrêter tous les conteneurs Docker                                                         |
| `make composer-install` | Installer les dépendances avec Composer                                                    |
| `make composer-update`  | Mettre à jour les dépendances avec Composer                                                |
| `make composer-remove`  | Supprimer un package avec Composer (usage: `make composer-remove RUN_ARGS=vendor/package`) |
| `make setup`            | Configurer WordPress avec WP-CLI                                                           |
| `make rebuild`          | Reconstruire l'image Docker sans cache                                                     |
| `make wordpress-update` | Appliquer une mise à jour de WordPress (après avoir changé de version dans `Dockerfile`)   |
| `make logs`             | Afficher les logs en temps réel de tous les services                                       |
| `make shell`            | Ouvrir un shell bash dans le conteneur WordPress                                           |
| `m̀ake install-nginx`    | Installe NGINX                                                                             |
| `make generate-ssl-cert`| Génère le certificat SSL auto-signé partagé (si absent) requis par NGINX                   |
| `make configure-nginx`  | Configure le reverse proxy de NGINX                                                        |
| `make set-permissions`  | Définit les permissions requises pour le projet                                            |

## Gestion des plugins/thèmes

Les plugins et thèmes sont gérés via **Composer** (sauf notre theme enfant) et définis dans `composer.json`.

**Ajouter un plugin (Elementor par exemple) :**

```bash
docker compose exec -T wp composer require wpackagist-plugin/elementor
```

**Mettre à jour :**

```bash
docker compose exec -T wp composer update
```

## Structure du projet

```
.
├── Makefile              # Commandes automatisées
├── Dockerfile            # Image Docker personnalisée
├── docker-compose.yml    # Configuration des services
├── composer.json         # Dépendances PHP/WordPress
├── .env                  # Variables d'environnement (à créer)
├── .env.example          # Exemple de configuration
├── nginx.conf.template   # Modèle de la configuration NGINX
├── wp-config.php         # Configuration WordPress
├── wp-content/           # Contenu WordPress (plugins, thèmes, uploads)
└── config/               # Fichiers de configuration PHP
```

## Configuration

Modifier le fichier `.env` pour :

- Changer le port Docker
- Configurer la base de données
- Ajouter un nouveau domaine local
- etc.

## Notes importantes

- Ne pas commit les dépendances Composer (elles sont de toute façon dans `.gitignore`)

## Troubleshooting

**Le container ne démarre pas :**

```bash
docker compose logs *nom-du-container*
```

**WordPress n'est pas configuré :**

```bash
make setup
```

**Erreur `Access denied for user ...` pendant `make setup` :**

Si vous avez modifie `DB_USER` ou `DB_PASSWORD` dans `.env` apres le premier demarrage, MySQL garde les anciens identifiants dans le volume persistant.

```bash
make reset-db
make up
make setup
```

**`nginx -t` échoue avec `cannot load certificate "/etc/ssl/certs/web.crt"` :**

Le certificat SSL partagé n'existe pas encore sur cette machine (il n'est pas versionné, chaque poste doit le générer une fois). Sans lui, `nginx -t` échoue et `configure-nginx` n'active jamais le site.

```bash
make generate-ssl-cert
make configure-nginx
```

**Le site est injoignable alors que Docker/MySQL fonctionnent :**

Vérifiez `sudo nginx -t`. Deux causes fréquentes :

- Certificat SSL absent (voir ci-dessus).
- `PROXY_URL` dans `.env` ne correspond pas à `NGINX_ID` (doit être exactement `http://<NGINX_ID>`), sinon NGINX tente de résoudre ce nom via DNS au lieu d'utiliser le reverse proxy local.

**Réinitialiser complètement :**

```bash
docker compose down -v
make install
```

## À faire

- [ ] Mettre en place des URL plus parlantes pour PHPMyAdmin et Mailcatcher
- [ ] Setup des templates de base pour le theme WordPress
- [ ] Récupérer de la documentation WP CLI
