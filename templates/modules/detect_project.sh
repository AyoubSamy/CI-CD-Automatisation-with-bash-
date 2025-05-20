#!/bin/bash

# =====================================================================
# detect_project.sh - Module de détection du type de projet
# =====================================================================

# Vérification des arguments
if [ $# -ne 1 ]; then
    echo "Usage: $0 <project_directory>"
    exit 1
fi

PROJECT_DIR="$1"

# Vérification que le répertoire existe
if [ ! -d "${PROJECT_DIR}" ]; then
    echo "ERROR: Le répertoire du projet n'existe pas: ${PROJECT_DIR}"
    exit 1
fi

# Détection basée sur les fichiers présents
if [ -f "${PROJECT_DIR}/package.json" ]; then
    echo "nodejs"
    exit 0
elif [ -f "${PROJECT_DIR}/requirements.txt" ] || [ -f "${PROJECT_DIR}/setup.py" ]; then
    echo "python"
    exit 0
elif [ -f "${PROJECT_DIR}/pom.xml" ] || [ -f "${PROJECT_DIR}/build.gradle" ]; then
    echo "java"
    exit 0
else
    echo "unknown"
    exit 1
fi