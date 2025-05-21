#!/bin/bash

# detect_project.sh - Détection du type de projet
# Ce module identifie automatiquement le langage du projet
# en fonction des fichiers présents dans le répertoire courant

LANG=""

# Fonction de log simplifié
function log_detect {
  echo "[DETECT] $1"
}

# Fonction de détection
function detect_language {
  if [ -f "package.json" ]; then
    LANG="nodejs"
    log_detect "Projet Node.js détecté (package.json trouvé)"
  elif [ -f "requirements.txt" ] || [ -f "setup.py" ]; then
    LANG="python"
    log_detect "Projet Python détecté (requirements.txt ou setup.py trouvé)"
  elif [ -f "composer.json" ]; then
    LANG="php"
    log_detect "Projet PHP détecté (composer.json trouvé)"
  elif ls *.java &>/dev/null; then
    LANG="java"
    log_detect "Projet Java détecté (*.java trouvé)"
  else
    log_detect "Aucun langage détecté automatiquement."
    LANG="unknown"
  fi

  echo "$LANG"
}

# Si ce script est exécuté directement
if [ "$0" = "$BASH_SOURCE" ]; then
  detect_language
fi
