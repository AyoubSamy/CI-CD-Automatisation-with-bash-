#!/bin/bash

# Fonction pour exécuter une commande dans un sous-shell
function run_in_subshell {
    local command="$1"
    (
        echo "[SUBSHELL] Démarrage du sous-shell (PID: $$)"
        eval "$command"
        echo "[SUBSHELL] Fin du sous-shell (PID: $$)"
    )
}

# Si le script est exécuté directement
if [ "$0" = "$BASH_SOURCE" ]; then
    if [ -z "$1" ]; then
        echo "Usage: $0 'commande'"
        exit 1
    fi
    run_in_subshell "$1"
fi