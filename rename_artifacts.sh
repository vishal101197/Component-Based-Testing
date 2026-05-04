#!/bin/bash

set -e  # Exit on any error

echo "Renaming artifacts..."

# Validate required variables
for var in DOMAIN_ID COMPONENT_NAME EXECUTION_ID; do
  if [ -z "$(eval echo \$$var)" ]; then
    echo "ERROR: Required variable not set - $var"
    exit 1
  fi
done

# Create artifact prefix
ARTIFACT_PREFIX="${DOMAIN_ID}_${COMPONENT_NAME}_${EXECUTION_ID}"
echo "Artifact prefix: ${ARTIFACT_PREFIX}"

# Rename files if they exist
RENAMED_COUNT=0

if [ -f newman-report.html ]; then
  mv newman-report.html "${ARTIFACT_PREFIX}_newman-report.html"
  echo "Renamed: newman-report.html"
  RENAMED_COUNT=$((RENAMED_COUNT + 1))
fi

if [ -f result.xml ]; then
  mv result.xml "${ARTIFACT_PREFIX}_result.xml"
  echo "Renamed: result.xml"
  RENAMED_COUNT=$((RENAMED_COUNT + 1))
fi

if [ -f newman-results.json ]; then
  mv newman-results.json "${ARTIFACT_PREFIX}_newman-results.json"
  echo "Renamed: newman-results.json"
  RENAMED_COUNT=$((RENAMED_COUNT + 1))
fi



# Verify at least one file was renamed
if [ $RENAMED_COUNT -eq 0 ]; then
  echo "WARNING: No artifact files found to rename"
  exit 1
fi

echo "Successfully renamed $RENAMED_COUNT artifacts"