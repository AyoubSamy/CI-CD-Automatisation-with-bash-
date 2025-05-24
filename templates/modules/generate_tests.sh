#!/bin/bash

# generate_tests.sh - Génère les sections de tests CI/CD
# Ce module est invoqué depuis cicdgen.sh avec les options -u (unitaires) ou -i (intégration)
# Il génère un bloc YAML dans un fichier temporaire, à inclure dans le fichier de pipeline final

LANGUAGE="$1"           # Langage du projet (ex: nodejs, python, java)
UNIT_TESTS_ENABLED=$2    # true/false
INTEGRATION_TESTS_ENABLED=$3  # true/false
PLATFORM=$4  # Ajouté : la plateforme cible
OUTPUT_FILE="./generated/test_blocks.yml"

mkdir -p ./generated
> "$OUTPUT_FILE"

# Fonction de génération de tests unitaires pour GitLab
function generate_unit_tests_gitlab {
  echo "unit_tests:" >> "$OUTPUT_FILE"
  echo "  stage: test" >> "$OUTPUT_FILE"
  echo "  script:" >> "$OUTPUT_FILE"
  case "$LANGUAGE" in
    nodejs) echo "    - npm test" >> "$OUTPUT_FILE" ;;
    python) echo "    - pytest tests/unit" >> "$OUTPUT_FILE" ;;
    java)   echo "    - mvn test" >> "$OUTPUT_FILE" ;;
    *)      echo "    - echo 'Aucune commande définie pour les tests unitaires de $LANGUAGE'" >> "$OUTPUT_FILE" ;;
  esac
}

# Fonction de génération de tests d'intégration pour GitLab
function generate_integration_tests_gitlab {
  echo "integration_tests:" >> "$OUTPUT_FILE"
  echo "  stage: integration" >> "$OUTPUT_FILE"
  echo "  script:" >> "$OUTPUT_FILE"
  case "$LANGUAGE" in
    nodejs) echo "    - npm run test:integration" >> "$OUTPUT_FILE" ;;
    python) echo "    - pytest tests/integration" >> "$OUTPUT_FILE" ;;
    java)   echo "    - mvn verify -P integration-tests" >> "$OUTPUT_FILE" ;;
    *)      echo "    - echo 'Aucune commande définie pour les tests d'intégration de $LANGUAGE'" >> "$OUTPUT_FILE" ;;
  esac
}

# Fonction de génération de tests unitaires pour GitHub
function generate_unit_tests_github {
  echo "  unit_tests:" >> "$OUTPUT_FILE"
  echo "    runs-on: ubuntu-latest" >> "$OUTPUT_FILE"
  echo "    needs: install" >> "$OUTPUT_FILE"
  echo "    steps:" >> "$OUTPUT_FILE"
  echo "      - uses: actions/checkout@v3" >> "$OUTPUT_FILE"
  case "$LANGUAGE" in
    nodejs) echo "      - run: npm test" >> "$OUTPUT_FILE" ;;
    python) echo "      - run: pytest tests/unit" >> "$OUTPUT_FILE" ;;
    java)   echo "      - run: mvn test" >> "$OUTPUT_FILE" ;;
    *)      echo "      - run: echo 'Aucune commande définie pour les tests unitaires de $LANGUAGE'" >> "$OUTPUT_FILE" ;;
  esac
}

# Fonction de génération de tests d'intégration pour GitHub
function generate_integration_tests_github {
  echo "  integration_tests:" >> "$OUTPUT_FILE"
  echo "    runs-on: ubuntu-latest" >> "$OUTPUT_FILE"
  echo "    needs: install" >> "$OUTPUT_FILE"
  echo "    steps:" >> "$OUTPUT_FILE"
  echo "      - uses: actions/checkout@v3" >> "$OUTPUT_FILE"
  case "$LANGUAGE" in
    nodejs) echo "      - run: npm run test:integration" >> "$OUTPUT_FILE" ;;
    python) echo "      - run: pytest tests/integration" >> "$OUTPUT_FILE" ;;
    java)   echo "      - run: mvn verify -P integration-tests" >> "$OUTPUT_FILE" ;;
    *)      echo "      - run: echo 'Aucune commande définie pour les tests d'intégration de $LANGUAGE'" >> "$OUTPUT_FILE" ;;
  esac
}

# Génération conditionnelle
if [ "$PLATFORM" = "gitlab" ]; then
  if [ "$UNIT_TESTS_ENABLED" = true ]; then
    generate_unit_tests_gitlab
  fi
  if [ "$INTEGRATION_TESTS_ENABLED" = true ]; then
    generate_integration_tests_gitlab
  fi
elif [ "$PLATFORM" = "github" ]; then
  if [ "$UNIT_TESTS_ENABLED" = true ]; then
    generate_unit_tests_github
  fi
  if [ "$INTEGRATION_TESTS_ENABLED" = true ]; then
    generate_integration_tests_github
  fi
fi

echo "Blocs de tests générés dans $OUTPUT_FILE"
