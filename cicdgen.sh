#!/bin/bash

# =====================================================================
# cicdgen.sh - CI/CD Pipeline Generator
# 
# Description: Script pour automatiser la configuration et le déploiement
# d'une chaîne CI/CD complète pour différents types de projets.
# =====================================================================

# Définition des variables globales
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_LOG_DIR="/var/log/cicdgen"
LOG_DIR="${DEFAULT_LOG_DIR}"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"
BIN_DIR="${SCRIPT_DIR}/bin"
MODULE_DIR="${SCRIPT_DIR}/modules"

# Codes d'erreur
ERROR_INVALID_OPTION=100
ERROR_MISSING_PARAM=101
ERROR_PERMISSION_DENIED=102
ERROR_UNSUPPORTED_PROJECT=103
ERROR_INVALID_TEMPLATE=104
ERROR_CONFIG_GENERATION=105

# Valeurs par défaut
USE_FORK=false
USE_THREAD=false
USE_SUBSHELL=false
PLATFORM=""
LANGUAGE=""
ENVIRONMENTS=""
ENABLE_CODE_ANALYSIS=false
ENABLE_UNIT_TESTS=false
ENABLE_INTEGRATION_TESTS=false

# =====================================================================
# Fonction: show_help
# Description: Affiche l'aide du programme
# =====================================================================
show_help() {
    cat << EOF
cicdgen.sh - CI/CD Pipeline Generator

DESCRIPTION
    Script pour automatiser la configuration et le déploiement
    d'une chaîne CI/CD complète pour différents types de projets.

SYNTAXE
    cicdgen.sh [OPTIONS] <project_directory>

OPTIONS OBLIGATOIRES
    -h    Affiche cette aide
    -f    Utilise le mode fork pour traiter les étapes en parallèle
    -t    Utilise des threads pour traiter les étapes en parallèle
    -s    Exécute dans un sous-shell
    -l <directory>    Spécifie un répertoire pour les logs (défaut: /var/log/cicdgen)
    -r    Réinitialise les paramètres par défaut (nécessite des droits admin)

OPTIONS SPÉCIFIQUES
    -p <platform>     Spécifie la plateforme CI/CD (gitlab, github, jenkins)
    -g <language>     Spécifie le langage de programmation du projet
    -e <environments> Liste des environnements à configurer (dev,staging,prod)
    -c                Active l'analyse de code statique
    -u                Configure les tests unitaires
    -i                Configure les tests d'intégration

PARAMÈTRES
    <project_directory>    Chemin vers le répertoire du projet à configurer (obligatoire)

EXEMPLES
    cicdgen.sh -h
    cicdgen.sh -f -p gitlab -g python -c -u /path/to/project
    cicdgen.sh -s -l /custom/log/dir -p github -e dev,prod /path/to/project

EOF
    exit 0
}

# =====================================================================
# Fonction: log
# Description: Journalise un message avec le format requis
# Paramètres:
#   $1: Niveau (INFOS, ERROR)
#   $2: Message
# =====================================================================
log() {
    local level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d-%H-%M-%S")
    local username=$(whoami)
    
    # Créer le répertoire de logs si nécessaire
    if [ ! -d "${LOG_DIR}" ]; then
        mkdir -p "${LOG_DIR}" 2>/dev/null
        if [ $? -ne 0 ]; then
            echo "Erreur: Impossible de créer le répertoire de logs ${LOG_DIR}"
            echo "Essayez avec sudo ou spécifiez un autre répertoire avec l'option -l"
            exit $ERROR_PERMISSION_DENIED
        fi
    fi
    
    # Journaliser à la fois dans le terminal et dans le fichier
    echo "${timestamp} : ${username} : ${level} : ${message}" | tee -a "${LOG_DIR}/history.log"
}

# =====================================================================
# Fonction: check_admin_privileges
# Description: Vérifie si l'utilisateur a des droits administrateur
# =====================================================================
check_admin_privileges() {
    if [ "$(id -u)" -ne 0 ]; then
        log "ERROR" "Cette opération nécessite des privilèges administrateur"
        exit $ERROR_PERMISSION_DENIED
    fi
}

# =====================================================================
# Fonction: detect_project_type
# Description: Détecte automatiquement le type de projet
# Paramètres:
#   $1: Chemin vers le répertoire du projet
# Retourne:
#   Type de projet détecté (python, nodejs, java) ou erreur
# =====================================================================
detect_project_type() {
    local project_dir=$1
    
    log "INFOS" "Détection du type de projet dans ${project_dir}..."
    
    # Vérification que le répertoire existe
    if [ ! -d "${project_dir}" ]; then
        log "ERROR" "Le répertoire du projet n'existe pas: ${project_dir}"
        exit $ERROR_MISSING_PARAM
    fi
    
    # Détection basée sur les fichiers présents
    if [ -f "${project_dir}/package.json" ]; then
        log "INFOS" "Projet NodeJS détecté"
        echo "nodejs"
    elif [ -f "${project_dir}/requirements.txt" ] || [ -f "${project_dir}/setup.py" ]; then
        log "INFOS" "Projet Python détecté"
        echo "python"
    elif [ -f "${project_dir}/pom.xml" ] || [ -f "${project_dir}/build.gradle" ]; then
        log "INFOS" "Projet Java détecté"
        echo "java"
    else
        log "ERROR" "Type de projet non détecté. Veuillez spécifier le type avec l'option -g"
        exit $ERROR_UNSUPPORTED_PROJECT
    fi
}

# =====================================================================
# Fonction: generate_ci_config
# Description: Génère la configuration CI/CD
# Paramètres:
#   $1: Plateforme CI/CD
#   $2: Langage du projet
#   $3: Chemin vers le répertoire du projet
# =====================================================================
generate_ci_config() {
    local platform=$1
    local language=$2
    local project_dir=$3
    
    log "INFOS" "Génération de la configuration ${platform} pour ${language}..."
    
    local template_file="${TEMPLATE_DIR}/${platform}-ci/${language}.yml"
    
    if [ ! -f "$template_file" ]; then
        log "ERROR" "Template non trouvé pour ${platform}/${language}"
        exit $ERROR_INVALID_TEMPLATE
    fi
    
    # Adaptation du template au projet
    if [ "$platform" = "gitlab" ]; then
        output_file="${project_dir}/.gitlab-ci.yml"
    elif [ "$platform" = "github" ]; then
        mkdir -p "${project_dir}/.github/workflows"
        output_file="${project_dir}/.github/workflows/ci-cd.yml"
    elif [ "$platform" = "jenkins" ]; then
        output_file="${project_dir}/Jenkinsfile"
    else
        log "ERROR" "Plateforme non supportée: ${platform}"
        exit $ERROR_INVALID_TEMPLATE
    fi
    
    cp "$template_file" "$output_file"
    
    # Configuration supplémentaire selon les options
    if [ "$ENABLE_CODE_ANALYSIS" = true ]; then
        if [ "$USE_FORK" = true ]; then
            execute_with_fork "${MODULE_DIR}/code_analysis.sh" "$platform" "$language" "$project_dir" "$output_file"
        elif [ "$USE_THREAD" = true ]; then
            execute_with_thread "${MODULE_DIR}/code_analysis.sh" "$platform" "$language" "$project_dir" "$output_file"
        elif [ "$USE_SUBSHELL" = true ]; then
            execute_with_subshell "${MODULE_DIR}/code_analysis.sh" "$platform" "$language" "$project_dir" "$output_file"
        else
            "${MODULE_DIR}/code_analysis.sh" "$platform" "$language" "$project_dir" "$output_file"
        fi
    fi
    
    if [ "$ENABLE_UNIT_TESTS" = true ]; then
        if [ "$USE_FORK" = true ]; then
            execute_with_fork "${MODULE_DIR}/generate_tests.sh" "unit" "$platform" "$language" "$project_dir" "$output_file"
        elif [ "$USE_THREAD" = true ]; then
            execute_with_thread "${MODULE_DIR}/generate_tests.sh" "unit" "$platform" "$language" "$project_dir" "$output_file"
        elif [ "$USE_SUBSHELL" = true ]; then
            execute_with_subshell "${MODULE_DIR}/generate_tests.sh" "unit" "$platform" "$language" "$project_dir" "$output_file"
        else
            "${MODULE_DIR}/generate_tests.sh" "unit" "$platform" "$language" "$project_dir" "$output_file"
        fi
    fi
    
    if [ "$ENABLE_INTEGRATION_TESTS" = true ]; then
        if [ "$USE_FORK" = true ]; then
            execute_with_fork "${MODULE_DIR}/generate_tests.sh" "integration" "$platform" "$language" "$project_dir" "$output_file"
        elif [ "$USE_THREAD" = true ]; then
            execute_with_thread "${MODULE_DIR}/generate_tests.sh" "integration" "$platform" "$language" "$project_dir" "$output_file"
        elif [ "$USE_SUBSHELL" = true ]; then
            execute_with_subshell "${MODULE_DIR}/generate_tests.sh" "integration" "$platform" "$language" "$project_dir" "$output_file"
        else
            "${MODULE_DIR}/generate_tests.sh" "integration" "$platform" "$language" "$project_dir" "$output_file"
        fi
    fi
    
    if [ -n "$ENVIRONMENTS" ]; then
        if [ "$USE_FORK" = true ]; then
            execute_with_fork "${MODULE_DIR}/deploy_config.sh" "$platform" "$language" "$project_dir" "$output_file" "$ENVIRONMENTS"
        elif [ "$USE_THREAD" = true ]; then
            execute_with_thread "${MODULE_DIR}/deploy_config.sh" "$platform" "$language" "$project_dir" "$output_file" "$ENVIRONMENTS"
        elif [ "$USE_SUBSHELL" = true ]; then
            execute_with_subshell "${MODULE_DIR}/deploy_config.sh" "$platform" "$language" "$project_dir" "$output_file" "$ENVIRONMENTS"
        else
            "${MODULE_DIR}/deploy_config.sh" "$platform" "$language" "$project_dir" "$output_file" "$ENVIRONMENTS"
        fi
    fi
    
    log "INFOS" "Configuration CI/CD générée avec succès dans ${output_file}"
}

# =====================================================================
# Fonction: execute_with_fork
# Description: Exécute une commande en utilisant le fork
# Paramètres:
#   $@: Commande à exécuter
# =====================================================================
execute_with_fork() {
    log "INFOS" "Exécution avec fork: $*"
    "${BIN_DIR}/process_handler" --mode=fork "$@"
}

# =====================================================================
# Fonction: execute_with_thread
# Description: Exécute une commande en utilisant des threads
# Paramètres:
#   $@: Commande à exécuter
# =====================================================================
execute_with_thread() {
    log "INFOS" "Exécution avec thread: $*"
    "${BIN_DIR}/process_handler" --mode=thread "$@"
}

# =====================================================================
# Fonction: execute_with_subshell
# Description: Exécute une commande dans un sous-shell
# Paramètres:
#   $@: Commande à exécuter
# =====================================================================
execute_with_subshell() {
    log "INFOS" "Exécution dans un sous-shell: $*"
    (
        "$@"
    )
}

# =====================================================================
# Fonction: restore_defaults
# Description: Réinitialise les paramètres par défaut
# =====================================================================
restore_defaults() {
    check_admin_privileges
    
    log "INFOS" "Réinitialisation des paramètres par défaut..."
    
    # Suppression du répertoire de logs
    if [ -d "$DEFAULT_LOG_DIR" ]; then
        rm -rf "$DEFAULT_LOG_DIR"
        mkdir -p "$DEFAULT_LOG_DIR"
        chmod 755 "$DEFAULT_LOG_DIR"
    fi
    
    # Réinitialisation des templates
    log "INFOS" "Paramètres réinitialisés avec succès"
    exit 0
}

# =====================================================================
# Analyse des options
# =====================================================================
while getopts "hfstl:rp:g:e:cui" opt; do
    case $opt in
        h)
            show_help
            ;;
        f)
            USE_FORK=true
            ;;
        s)
            USE_SUBSHELL=true
            ;;
        t)
            USE_THREAD=true
            ;;
        l)
            LOG_DIR="$OPTARG"
            ;;
        r)
            restore_defaults
            ;;
        p)
            PLATFORM="$OPTARG"
            ;;
        g)
            LANGUAGE="$OPTARG"
            ;;
        e)
            ENVIRONMENTS="$OPTARG"
            ;;
        c)
            ENABLE_CODE_ANALYSIS=true
            ;;
        u)
            ENABLE_UNIT_TESTS=true
            ;;
        i)
            ENABLE_INTEGRATION_TESTS=true
            ;;
        \?)
            log "ERROR" "Option invalide: -$OPTARG"
            show_help
            exit $ERROR_INVALID_OPTION
            ;;
        :)
            log "ERROR" "L'option -$OPTARG nécessite un argument"
            show_help
            exit $ERROR_INVALID_OPTION
            ;;
    esac
done

# Décalage pour obtenir le paramètre non-option (répertoire du projet)
shift $((OPTIND-1))
PROJECT_DIR="$1"

# Vérification du paramètre obligatoire
if [ -z "$PROJECT_DIR" ]; then
    log "ERROR" "Le répertoire du projet est obligatoire"
    show_help
    exit $ERROR_MISSING_PARAM
fi

# Vérification que le répertoire existe
if [ ! -d "$PROJECT_DIR" ]; then
    log "ERROR" "Le répertoire du projet n'existe pas: $PROJECT_DIR"
    exit $ERROR_MISSING_PARAM
fi

# Vérification de la présence du programme process_handler
if [ "$USE_FORK" = true ] || [ "$USE_THREAD" = true ]; then
    if [ ! -x "${BIN_DIR}/process_handler" ]; then
        log "ERROR" "Le programme process_handler n'est pas disponible ou n'est pas exécutable"
        log "INFOS" "Compilation de process_handler..."
        gcc -o "${BIN_DIR}/process_handler" "${MODULE_DIR}/process_handler.c" -lpthread
        if [ $? -ne 0 ]; then
            log "ERROR" "Échec de la compilation de process_handler"
            exit $ERROR_CONFIG_GENERATION
        fi
        chmod +x "${BIN_DIR}/process_handler"
    fi
fi

# Détection automatique du type de projet si non spécifié
if [ -z "$LANGUAGE" ]; then
    LANGUAGE=$(detect_project_type "$PROJECT_DIR")
fi

# Vérification et affectation de la plateforme par défaut si non spécifiée
if [ -z "$PLATFORM" ]; then
    PLATFORM="gitlab"
    log "INFOS" "Aucune plateforme spécifiée, utilisation de la plateforme par défaut: gitlab"
fi

# Exécution de la génération de configuration CI/CD
generate_ci_config "$PLATFORM" "$LANGUAGE" "$PROJECT_DIR"

log "INFOS" "Configuration CI/CD terminée avec succès"
exit 0
