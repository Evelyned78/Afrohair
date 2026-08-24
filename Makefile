.PHONY: help install hosts-add up stop composer-install composer-update composer-remove setup rebuild wordpress-update logs shell generate-ssl-cert

# Cible par défaut
.DEFAULT_GOAL := help

# Couleurs pour l'affichage
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m # No Color

help: ## Afficher toutes les commandes disponibles
	@echo "$(BLUE)═══════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)WordPress Codephenix - Commandes disponibles$(NC)"
	@echo "$(BLUE)═══════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(BLUE)Exemple d'utilisation :$(NC)"
	@echo "  make install             # Initialiser le projet complet"
	@echo "  make up               # Démarrer tous les services"
	@echo "  make stop             # Arrêter tous les services"
	@echo ""

install: generate-ssl-cert configure-nginx hosts-add up install-sendmail composer-install setup set-permissions ## Initialiser le projet (ajout aux hosts, démarrage, installation, configuration)
	@echo "$(GREEN)✓ Projet initialisé !$(NC)"

generate-ssl-cert: ## Générer le certificat SSL auto-signé partagé utilisé par tous les projets (si absent)
	@if [ -f /etc/ssl/certs/web.crt ] && [ -f /etc/ssl/private/web.key ]; then \
		echo "$(GREEN)✓ Certificat SSL déjà présent$(NC)"; \
	else \
		echo "$(YELLOW) Certificat SSL absent, génération d'un certificat auto-signé...$(NC)"; \
		sudo mkdir -p /etc/ssl/private; \
		sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
			-keyout /etc/ssl/private/web.key \
			-out /etc/ssl/certs/web.crt \
			-subj "/CN=localhost"; \
		sudo chmod 600 /etc/ssl/private/web.key; \
		echo "$(GREEN)✓ Certificat SSL généré ($(YELLOW)auto-signé, le navigateur affichera un avertissement$(NC)$(GREEN))$(NC)"; \
	fi

install-nginx: ## Installer Nginx sur la machine hôte (Linux)
	@echo "$(YELLOW) Installation de Nginx...$(NC)"
	sudo apt update
	sudo apt install -y nginx
	@echo "$(GREEN)✓ Nginx installé$(NC)"

install-sendmail: ## Installer Sendmail sur la machine hôte (Linux)
	@echo "$(YELLOW) Installation de Sendmail...$(NC)"
	docker compose exec -T wp apt update
	docker compose exec -T wp apt install -y sendmail
	@echo "$(GREEN)✓ Sendmail installé$(NC)"

configure-nginx: ## Configurer Nginx pour le projet (Linux)
	@echo "$(YELLOW) Configuration de Nginx...$(NC)"
	@HOSTNAME=$$(awk -F= '/^HOSTNAME=/{print substr($$0, index($$0, "=")+1); exit}' .env); \
	NGINX_ID=$$(awk -F= '/^NGINX_ID=/{print substr($$0, index($$0, "=")+1); exit}' .env); \
	DB_NAME=$$(awk -F= '/^DB_NAME=/{print substr($$0, index($$0, "=")+1); exit}' .env); \
	PORT=$$(awk -F= '/^PORT=/{print substr($$0, index($$0, "=")+1); exit}' .env); \
	PROXY_URL=$$(awk -F= '/^PROXY_URL=/{print substr($$0, index($$0, "=")+1); exit}' .env); \
	if [ -z "$$HOSTNAME" ] || [ -z "$$NGINX_ID" ] || [ -z "$$PORT" ] || [ -z "$$PROXY_URL" ]; then \
		echo "$(YELLOW)Erreur: variables .env manquantes. Vérifiez HOSTNAME, NGINX_ID, PORT, PROXY_URL.$(NC)"; \
		exit 1; \
	fi; \
	export HOSTNAME NGINX_ID DB_NAME PORT PROXY_URL; \
	TARGET_FILE=/etc/nginx/sites-enabled/$$NGINX_ID.conf; \
	envsubst '$$HOSTNAME $$NGINX_ID $$DB_NAME $$PORT $$PROXY_URL' < nginx.conf.template | sudo tee $$TARGET_FILE > /dev/null; \
	sudo nginx -t && sudo systemctl reload nginx; \
	echo "$(GREEN)✓ Nginx configuré: $$TARGET_FILE$(NC)"

test-nginx: ## Tester la configuration Nginx
	@echo "$(YELLOW) Test de la configuration Nginx...$(NC)"
	@HOSTNAME=$$(awk -F= '/^HOSTNAME=/{print substr($$0, index($$0, "=")+1); exit}' .env); \
	NGINX_ID=$$(awk -F= '/^NGINX_ID=/{print substr($$0, index($$0, "=")+1); exit}' .env); \
	DB_NAME=$$(awk -F= '/^DB_NAME=/{print substr($$0, index($$0, "=")+1); exit}' .env); \
	PORT=$$(awk -F= '/^PORT=/{print substr($$0, index($$0, "=")+1); exit}' .env); \
	PROXY_URL=$$(awk -F= '/^PROXY_URL=/{print substr($$0, index($$0, "=")+1); exit}' .env); \
	if [ -z "$$HOSTNAME" ] || [ -z "$$NGINX_ID" ] || [ -z "$$PORT" ] || [ -z "$$PROXY_URL" ]; then \
		echo "$(YELLOW)Erreur: variables .env manquantes. Vérifiez HOSTNAME, NGINX_ID, PORT, PROXY_URL.$(NC)"; \
		exit 1; \
	fi; \
	export HOSTNAME NGINX_ID DB_NAME PORT PROXY_URL; \
	envsubst '$$HOSTNAME $$NGINX_ID $$DB_NAME $$PORT $$PROXY_URL' < nginx.conf.template

hosts-add: ## Ajouter l'hôte au fichier hosts
	@echo "$(YELLOW) Ajout aux hosts...$(NC)"
	@HOSTNAME=$$(grep HOSTNAME .env | cut -d'=' -f2); \
	grep -q "$$HOSTNAME" /etc/hosts || echo "127.0.0.1 $$HOSTNAME" | sudo tee -a /etc/hosts > /dev/null
	@echo "$(GREEN)✓ Hosts configuré$(NC)"

up: ## Démarrer tous les conteneurs Docker
	@echo "$(YELLOW) Démarrage de Docker...$(NC)"
	docker compose up -d
	@echo "$(YELLOW) Attente du démarrage de MySQL...$(NC)"
	@docker compose exec -T db sh -c 'while ! mysqladmin ping -h localhost --silent; do sleep 1; done'
	@echo "$(GREEN)✓ Docker est prêt$(NC)"
	@echo "  Identifiants : $$(grep WP_USER .env | cut -d'=' -f2) / $$(grep WP_PASSWORD .env | cut -d'=' -f2)"
	@echo "  URL : https://$$(grep HOSTNAME .env | cut -d'=' -f2)"

stop: ## Arrêter tous les conteneurs Docker
	@echo "$(YELLOW) Arrêt de Docker...$(NC)"
	docker compose down
	@echo "$(GREEN)✓ Services arrêtés$(NC)"

composer-install: ## Installer les dépendances avec Composer
	@echo "$(YELLOW) Installation des dépendances...$(NC)"
	docker compose exec -T wp composer install
	@echo "$(GREEN)✓ Composer terminé$(NC)"

composer-update: ## Mettre à jour les dépendances avec Composer
	@echo "$(YELLOW) Mise à jour des dépendances...$(NC)"
	docker compose exec -T wp composer update
	@echo "$(GREEN)✓ Mise à jour des dépendances terminée$(NC)"

composer-remove: ## Supprimer un package avec Composer (usage: make composer-remove RUN_ARGS=vendor/package)
	@echo "$(YELLOW) Suppression des dépendances...$(NC)"
	docker compose exec -T wp composer remove "$(RUN_ARGS)"
	@echo "$(GREEN)✓ Package $(RUN_ARGS) supprimé$(NC)"

setup: ## Configurer WordPress avec WP-CLI
	@echo "$(YELLOW) Configuration de WordPress...$(NC)"
	@docker compose exec -T db sh -lc 'mysql -u"$$MYSQL_USER" -p"$$MYSQL_PASSWORD" -e "SELECT 1;" "$$MYSQL_DATABASE" >/dev/null 2>&1' || { \
		echo "$(YELLOW)✗ Les identifiants DB de .env ne correspondent pas a la base deja initialisee.$(NC)"; \
		echo "  Cause probable : volume MySQL persistant cree avec d'anciens identifiants."; \
		echo "  Solution : make reset-db"; \
		exit 1; \
	}
	docker compose exec -T wp wp core install \
		--url="https://$$(grep HOSTNAME .env | cut -d'=' -f2)" \
		--title="$$(grep SITENAME .env | cut -d'=' -f2)" \
		--admin_user="$$(grep WP_USER .env | cut -d'=' -f2)" \
		--admin_password="$$(grep WP_PASSWORD .env | cut -d'=' -f2)" \
		--admin_email=admin@localhost.local \
		--allow-root
	@echo "$(GREEN)✓ WordPress configuré$(NC)"
	@echo "  Identifiants : $$(grep WP_USER .env | cut -d'=' -f2) / $$(grep WP_PASSWORD .env | cut -d'=' -f2)"
	@echo "  URL : https://$$(grep HOSTNAME .env | cut -d'=' -f2)"

reset-db: ## Reinitialiser la base MySQL (supprime les donnees du volume)
	@echo "$(YELLOW) Reinitialisation de la base MySQL...$(NC)"
	docker compose down -v
	docker compose up -d db
	@echo "$(YELLOW) Attente du demarrage de MySQL...$(NC)"
	@docker compose exec -T db sh -c 'while ! mysqladmin ping -h localhost --silent; do sleep 1; done'
	@echo "$(GREEN)✓ Base reinitialisee avec les identifiants de .env$(NC)"
	@echo "Prochaine etape : make up puis make setup"

rebuild: ## Reconstruire l'image Docker sans cache
	@echo "$(YELLOW) Reconstruction de l'image...$(NC)"
	docker compose down
	docker compose build --no-cache wp
	docker compose up -d
	@echo "$(GREEN)✓ Image reconstruite$(NC)"

wordpress-update: ## Mettre a jour WordPress (rebuild + recreation + renouvellement du volume anonyme)
	@echo "$(YELLOW) Mise a jour de WordPress...$(NC)"
	docker compose build --pull --no-cache wp
	docker compose up -d --force-recreate --no-deps --renew-anon-volumes wp
	@echo "$(YELLOW) Verification de la version WordPress...$(NC)"
	@docker compose exec -T wp wp core version --allow-root
	@echo "$(GREEN)✓ WordPress mis a jour$(NC)"

logs: ## Afficher les logs en temps réel de tous les services
	@echo "$(YELLOW) Affichage des logs en temps réel (Ctrl+C pour quitter)...$(NC)"
	docker compose logs -f

shell: ## Ouvrir un shell bash dans le conteneur WordPress
	@echo "$(YELLOW) Ouverture d'un shell dans le conteneur WordPress...$(NC)"
	docker compose exec wp bash

set-permissions: ## Définir les permissions pour le dossier wp-content (Linux)
	@echo "$(YELLOW) Définition des permissions pour wp-content...$(NC)"
	@echo "Entrez le nom d'utilisateur : "; \
	read USERNAME; \
	sudo adduser $${USERNAME} www-data; \
	sudo chown -R www-data:www-data ./wp-content; \
	sudo chmod -R 775 ./wp-content;
	@echo "$(GREEN)✓ Permissions définies$(NC)"
