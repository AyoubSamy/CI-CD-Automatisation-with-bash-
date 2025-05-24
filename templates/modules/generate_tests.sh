#!/bin/bash

LANGUAGE=$1
ENABLE_UNIT_TESTS=$2
ENABLE_INTEGRATION_TESTS=$3

OUTPUT_FILE="generated/test_blocks.yml"
mkdir -p generated

echo "# Blocs de tests générés" > "$OUTPUT_FILE"

if [[ "$LANGUAGE" == "nodejs" ]]; then
  if [[ "$ENABLE_UNIT_TESTS" == "true" ]]; then
    cat >> "$OUTPUT_FILE" <<EOL
unit_tests:
  stage: test
  script:
    - echo "Lancement des tests unitaires Node.js"
    - npm install
    - npm test
  only:
    - branches
EOL
  fi

  if [[ "$ENABLE_INTEGRATION_TESTS" == "true" ]]; then
    cat >> "$OUTPUT_FILE" <<EOL
integration_tests:
  stage: test
  script:
    - echo "Lancement des tests d'intégration Node.js"
    - npm run integration-test
  only:
    - branches
EOL
  fi
else
  echo "Langage $LANGUAGE non supporté pour les tests." >> "$OUTPUT_FILE"
fi
