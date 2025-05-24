#!/bin/bash

# ---------- Configuration initiale des variables globale : ----------

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

# ---------- Help function :  ----------

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
  local type="$1" #le type de message (ex : INFOS, ERROR)
  local msg="$2" 
  local ts=$(date '+%Y-%m-%d-%H-%M-%S') #retourner la date actuelle 
  local user=$(whoami) # retourn l'utilisateur actuelle 
  echo "$ts : $user : $type : $msg" | tee -a "$LOG_DIR/history.log" # affichage du message dans le terminale est le meme message 
                                                                    # sera etre ajouter a la fin du fichier dese logs. 
}

# ---------- Reset Config ---------- #permet la reinitialisation de fichier log si l'utilisateur a les droits necesaire
function reset_config {
  if [ "$EUID" -ne 0 ]; then #$EUID retourne 0 si l'utilisateur est Root 
    log "ERROR" "Réinitialisation requiert les droits root." 
    exit 102
  fi
  rm -rf "$DEFAULT_LOG_DIR" #supression de repertoire log 
  mkdir -p "$DEFAULT_LOG_DIR" #la recreation de dossier log
  log "INFOS" "Configuration réinitialisée."  #l'appelle a la fonction log 
  exit 0
}

# ---------- Parsing des options ----------
while getopts ":hftsrl:p:g:e:cu i d:" opt; do #lire les options 
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

#la creation de repertiore des logs mais en cas ou il n'as pas deja exists 

mkdir -p "$LOG_DIR" 
log "INFOS" "Initialisation du pipeline" 

# ---------- Détection automatique du langage ----------
if [ "$LANGUAGE" = "auto" ]; then
  LANGUAGE=$(bash templates/modules/detect_project.sh)  # fiare un appelle a detect_project.sh
  log "INFOS" "Langage détecté automatiquement: $LANGUAGE"
fi

mkdir -p generated   #creation du repertoire generated qui va contenire les fichier .yml avant de les fusionner dans github-actions ou selon la platforme choisi par l'utilisateur

# ---------- Appels de modules ----------
if $ENABLE_UNIT_TESTS || $ENABLE_INTEGRATION_TESTS; then
  bash templates/modules/generate_tests.sh "$LANGUAGE" "$ENABLE_UNIT_TESTS" "$ENABLE_INTEGRATION_TESTS" "$PLATFORM"
  log "INFOS" "Blocs de tests générés."
fi

if $ENABLE_CODE_ANALYSIS; then
  bash templates/modules/code_analysis.sh "$LANGUAGE"
  log "INFOS" "Analyse de code terminée."
fi

if [ "$ENABLE_DEPLOY" = "true" ] && [ -n "$ENVIRONMENTS" ]; then #l'appelle du Script deploy_.config.sh si 
                                                                #l'ooption -d est true est -e a au moins une environnement 
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

if [ -s generated/test_blocks.yml ]; then
  echo "" >> "$PIPELINE_FILE"
  cat generated/test_blocks.yml >> "$PIPELINE_FILE"
fi

if [ -s generated/deploy/deploy_steps.yml ]; then
  echo "" >> "$PIPELINE_FILE"
  cat generated/deploy/deploy_steps.yml >> "$PIPELINE_FILE"
fi

log "INFOS" "Pipeline final généré : $PIPELINE_FILE"

# ---------- Fin ----------
echo -e "\n Pipeline CI/CD généré dans : $PIPELINE_FILE"
