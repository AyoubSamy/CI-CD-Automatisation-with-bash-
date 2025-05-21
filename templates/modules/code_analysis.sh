#!/bin/bash

# code_analysis.sh - Effectue l'analyse statique de code selon le langage
# Utilisé dans le pipeline CI/CD généré automatiquement

# Argument : langage ciblé pour l'analyse
LANGUAGE="$1"  # Langage à analyser (nodejs, python, java)

# Création du dossier de rapport si inexistant
REPORT_DIR="./generated/reports"
mkdir -p "$REPORT_DIR"

# Nom du fichier de rapport
REPORT_FILE="$REPORT_DIR/code_analysis_$LANGUAGE.log"
> "$REPORT_FILE"  # Vide le fichier s'il existe déjà

# Fonction de log de messages d'analyse
function log_analysis {
  echo "[CODE_ANALYSIS][$LANGUAGE] $1" | tee -a "$REPORT_FILE"
}

# Fonction principale qui exécute l'analyse statique
function run_analysis {
  case "$LANGUAGE" in
    nodejs)
      # Analyse Node.js avec ESLint
      if command -v eslint &>/dev/null; then
        log_analysis "Analyse avec ESLint..."
        eslint . | tee -a "$REPORT_FILE"
      else
        log_analysis "Erreur: ESLint non installé."
      fi
      ;;
    python)
      # Analyse Python avec Pylint
      if command -v pylint &>/dev/null; then
        log_analysis "Analyse avec Pylint..."
        pylint $(find . -name "*.py") | tee -a "$REPORT_FILE"
      else
        log_analysis "Erreur: Pylint non installé."
      fi
      ;;
    java)
      # Analyse Java avec Checkstyle
      if command -v checkstyle &>/dev/null; then
        log_analysis "Analyse avec Checkstyle..."
        checkstyle -c /google_checks.xml $(find . -name "*.java") | tee -a "$REPORT_FILE"
      else
        log_analysis "Erreur: Checkstyle non installé."
      fi
      ;;
    *)
      # Langage non pris en charge
      log_analysis "Aucun outil défini pour le langage : $LANGUAGE"
      ;;
  esac
}

# Exécution de l'analyse
run_analysis

# Message final avec emplacement du rapport
log_analysis "Analyse terminée. Rapport : $REPORT_FILE"
