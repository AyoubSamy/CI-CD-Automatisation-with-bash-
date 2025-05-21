#!/bin/bash

# generate_tests.sh - Génère les sections de tests CI/CD
# Ce module est invoqué depuis cicdgen.sh avec les options -u (unitaires) ou -i (intégration)
# Il génère un bloc YAML dans un fichier temporaire, à inclure dans le fichier de pipeline final

LANGUAGE="$1"           # Langage du projet (ex: nodejs, python, java)
UNIT_TESTS_ENABLED=$2    # true/false
INTEGRATION_TESTS_ENABLED=$3  # true/false
OUTPUT_FILE="./generated/test_blocks.yml"

mkdir -p ./generated
> "$OUTPUT_FILE"

# Fonction de génération de tests unitaires
function generate_unit_tests {
  echo "  - stage: test" >> "$OUTPUT_FILE"
  echo "    name: Unit Tests" >> "$OUTPUT_FILE"
  case "$LANGUAGE" in
    nodejs)
      echo "    script: npm test" >> "$OUTPUT_FILE"
      ;;
    python)
      echo "    script: pytest tests/unit" >> "$OUTPUT_FILE"
      ;;
    java)
      echo "    script: mvn test" >> "$OUTPUT_FILE"
      ;;
    *)
      echo "    script: echo 'Aucune commande définie pour les tests unitaires de $LANGUAGE'" >> "$OUTPUT_FILE"
      ;;
  esac
}

# Fonction de génération de tests d'intégration
function generate_integration_tests {
  echo "  - stage: integration" >> "$OUTPUT_FILE"
  echo "    name: Integration Tests" >> "$OUTPUT_FILE"
  case "$LANGUAGE" in
    nodejs)
      echo "    script: npm run test:integration" >> "$OUTPUT_FILE"
      ;;
    python)
      echo "    script: pytest tests/integration" >> "$OUTPUT_FILE"
      ;;
    java)
      echo "    script: mvn verify -P integration-tests" >> "$OUTPUT_FILE"
      ;;
    *)
      echo "    script: echo 'Aucune commande définie pour les tests d\'intégration de $LANGUAGE'" >> "$OUTPUT_FILE"
      ;;
  esac
}

# Génération conditionnelle
if [ "$UNIT_TESTS_ENABLED" = true ]; then
  echo "Génération des tests unitaires pour $LANGUAGE..."
  generate_unit_tests
fi

if [ "$INTEGRATION_TESTS_ENABLED" = true ]; then
  echo "Génération des tests d'intégration pour $LANGUAGE..."
  generate_integration_tests
fi

echo "Blocs de tests générés dans $OUTPUT_FILE"
