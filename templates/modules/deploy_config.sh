#!/bin/bash

# deploy_config.sh - Génère la configuration de déploiement
# pour les environnements spécifiés (dev, staging, prod)
# Utilisé dans un pipeline CI/CD généré automatiquement

# Arguments : langage + liste des environnements (séparés par virgules)
LANGUAGE="$1"
ENVIRONMENTS="$2"

DEPLOY_DIR="./generated/deploy"
mkdir -p "$DEPLOY_DIR"
DEPLOY_FILE="$DEPLOY_DIR/deploy_steps.yml"
> "$DEPLOY_FILE"

# Fonction de génération de blocs de déploiement YAML (GitLab CI syntaxe)
function generate_deploy_block {
  local env="$1"
  local job_name="deploy_${env}"
  echo "${job_name}:" >> "$DEPLOY_FILE"
  echo "  stage: deploy" >> "$DEPLOY_FILE"
  echo "  script:" >> "$DEPLOY_FILE"
  case "$LANGUAGE" in
    nodejs)
      echo "    - echo 'Déploiement Node.js vers $env...' && npm run deploy:$env" >> "$DEPLOY_FILE"
      ;;
    python)
      echo "    - echo 'Déploiement Python vers $env...' && ./scripts/deploy.sh $env" >> "$DEPLOY_FILE"
      ;;
    java)
      echo "    - echo 'Déploiement Java vers $env...' && ./gradlew deploy -Penvironment=$env" >> "$DEPLOY_FILE"
      ;;
    *)
      echo "    - echo 'Déploiement générique vers $env...'" >> "$DEPLOY_FILE"
      ;;
  esac
  echo "" >> "$DEPLOY_FILE"
}

# Séparer les environnements et les parcourir
IFS=',' read -ra ENV_LIST <<< "$ENVIRONMENTS"
for ENV in "${ENV_LIST[@]}"; do
  generate_deploy_block "$ENV"
done

# Résumé
echo "[DEPLOY_CONFIG] Fichier généré : $DEPLOY_FILE"
