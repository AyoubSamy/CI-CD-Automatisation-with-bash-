#!/bin/bash

# ===========================
# cicdgen.sh - Générateur CI/CD Principal
# ===========================

# ---------- Configuration initiale ----------
DEFAULT_LOG_DIR="/var/log/cicdgen"
LOG_DIR="$DEFAULT_LOG_DIR"
PLATFORM=""
LANGUAGE=""
ENVIRONMENTS=""
ENABLE_CODE_ANALYSIS=false
ENABLE_UNIT_TESTS=false
ENABLE_INTEGRATION_TESTS=false
ENABLE_DEPLOY=false
USE_FORK=false
USE_THREAD=false
USE_SUBSHELL=false
RESET_CONFIG=false

# ---------- Aide ----------
function show_help {
  echo -e "\nUsage: $0 [options]"
  echo -e "\nOptions :"
  echo "  -h                Affiche cette aide"
  echo "  -f                Mode fork"
  echo "  -t                Mode thread"
  echo "  -s                Exécution dans un sous-shell"
  echo "  -l <log_dir>      Répertoire des logs (défaut: /var/log/cicdgen)"
  echo "  -r                Réinitialise la config (root uniquement)"
  echo "  -p <platform>     Plateforme CI/CD (gitlab, github, jenkins)"
  echo "  -g <language>     Langage (nodejs, python, java, auto)"
  echo "  -e <envs>         Environnements (dev,staging,prod)"
  echo "  -c                Active l'analyse de code"
  echo "  -u                Active les tests unitaires"
  echo "  -i                Active les tests d'intégration"
  echo "  -d <true/false>   Active/désactive le déploiement"
  exit 0
}

# ---------- Logging ----------
function log {
  local type="$1"
  local msg="$2"
  local ts=$(date '+%Y-%m-%d-%H-%M-%S')
  local user=$(whoami)
  echo "$ts : $user : $type : $msg" | tee -a "$LOG_DIR/history.log"
}

# ---------- Reset Config ----------
function reset_config {
  if [ "$EUID" -ne 0 ]; then
    log "ERROR" "Réinitialisation requiert les droits root."
    exit 102
  fi
  rm -rf "$DEFAULT_LOG_DIR"
  mkdir -p "$DEFAULT_LOG_DIR"
  log "INFOS" "Configuration réinitialisée."
  exit 0
}

# ---------- Parsing des options ----------
while getopts ":hftsrl:p:g:e:cui:d:" opt; do
  case $opt in
    h) show_help ;;
    f) USE_FORK=true ;;
    t) USE_THREAD=true ;;
    s) USE_SUBSHELL=true ;;
    r) RESET_CONFIG=true ;;
    l) LOG_DIR="$OPTARG" ;;
    p) PLATFORM="$OPTARG" ;;
    g) LANGUAGE="$OPTARG" ;;
    e) ENVIRONMENTS="$OPTARG" ;;
    c) ENABLE_CODE_ANALYSIS=true ;;
    u) ENABLE_UNIT_TESTS=true ;;
    i) ENABLE_INTEGRATION_TESTS=true ;;
    d) ENABLE_DEPLOY=$OPTARG ;;
    :) log "ERROR" "Option -$OPTARG requiert une valeur." ; show_help ; exit 101 ;;
    \?) log "ERROR" "Option invalide: -$OPTARG" ; show_help ; exit 100 ;;
  esac
done

# ---------- Reset immédiat ----------
if [ "$RESET_CONFIG" = true ]; then
  reset_config
fi

# ---------- Validation ----------
if [[ -z "$PLATFORM" || -z "$LANGUAGE" ]]; then
  log "ERROR" "Les options -p (plateforme) et -g (langage) sont obligatoires."
  show_help
  exit 101
fi

mkdir -p "$LOG_DIR"
log "INFOS" "Initialisation du pipeline"

# ---------- Détection automatique du langage ----------
if [ "$LANGUAGE" = "auto" ]; then
  LANGUAGE=$(bash templates/modules/detect_project.sh)  # fiare un appelle a detect_project.sh
  log "INFOS" "Langage détecté automatiquement: $LANGUAGE"
fi

mkdir -p generated   #creation du repertoire generated qui va contenire les fichier .yml avant de les fusionner dans github-actions selon la platforme

# ---------- Appels de modules ----------
if $ENABLE_UNIT_TESTS || $ENABLE_INTEGRATION_TESTS; then
  bash templates/modules/generate_tests.sh "$LANGUAGE" "$ENABLE_UNIT_TESTS" "$ENABLE_INTEGRATION_TESTS"  #appel du script qui va generer les test si l'un des v
  # variables integration test ou Unit_test est vrai 

  log "INFOS" "Blocs de tests générés."
fi

if $ENABLE_CODE_ANALYSIS; then
  bash templates/modules/code_analysis.sh "$LANGUAGE"
  log "INFOS" "Analyse de code terminée."
fi

if [ "$ENABLE_DEPLOY" = "true" ] && [ -n "$ENVIRONMENTS" ]; then
  bash templates/modules/deploy_config.sh "$LANGUAGE" "$ENVIRONMENTS"
  log "INFOS" "Étapes de déploiement configurées."
fi

# ---------- Fork / Threads ----------
if $USE_FORK; then
  ./templates/modules/process_handler -f 2
  log "INFOS" "Fork exécuté."
fi

if $USE_THREAD; then
  ./templates/modules/process_handler -t 2
  log "INFOS" "Thread exécuté."
fi

# ---------- Construction du pipeline final ----------
PIPELINE_FILE="generated/pipeline.yml"

# Copier le template de base selon plateforme
case $PLATFORM in
  gitlab)
    cp templates/gitlab-ci/$LANGUAGE.yml "$PIPELINE_FILE"
    ;;
  github)
    mkdir -p generated/.github/workflows
    cp templates/github-actions/$LANGUAGE.yml "$PIPELINE_FILE"
    ;;
  jenkins)
    cp templates/jenkins/Jenkinsfile-$LANGUAGE "$PIPELINE_FILE"
    ;;
  *)
    log "ERROR" "Plateforme non supportée: $PLATFORM"
    exit 103
    ;;
esac

# Ajouter les blocs générés (tests + deploy)
cat generated/test_blocks.yml >> "$PIPELINE_FILE" 2>/dev/null
cat generated/deploy/deploy_steps.yml >> "$PIPELINE_FILE" 2>/dev/null

log "INFOS" "Pipeline final généré : $PIPELINE_FILE"

# ---------- Fin ----------
echo -e "\n Pipeline CI/CD généré dans : $PIPELINE_FILE"
