#!/bin/bash

set -e  #setting Exit on any error

#Checking for required tools
if ! command -v jq &> /dev/null; then
  echo "ERROR: jq is not installed"
  exit 1
fi

if ! command -v curl &> /dev/null; then
  echo "ERROR: curl is not installed"
  exit 1
fi

#Validating required variables to avoid faliuer of the script
echo "Validating required variables...."
for var in ServerUrl ClientId ClientSecret EXECUTION_ID; do
  if [ -z "$(eval echo \$$var)" ]; then
    echo "ERROR: Required variable not set - $var"
    exit 1
  fi
done
echo "Done! All required variables are set...."

#Obtain access token from TOSCA server. This time it is not from api collection, here we are fetching token explicitly.
echo "Obtaining access token from TOSCA server using variables...."
TOKEN_RESPONSE=$(curl --max-time 60 -s -X POST "${ServerUrl}/tua/connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials&client_id=${ClientId}&client_secret=${ClientSecret}")

#Checking if curl succeeded
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to connect to TOSCA server"
  exit 1
fi

#Extracting access token
ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')

# Validate token
if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" == "null" ]; then
  echo "ERROR: Could not obtain access token."
  echo "Server response: $TOKEN_RESPONSE"
  exit 1
fi

echo "Done! Access token obtained successfully"

#Downloading test execution results...
echo "Downloading test execution results for Execution ID: ${EXECUTION_ID}..."
HTTP_CODE=$(curl --max-time 60 -w "%{http_code}" -o result.xml -s -X GET \
  "${ServerUrl}/automationobjectservice/api/execution/${EXECUTION_ID}/results" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "X-Tricentis: OK")

#Check HTTP response code, just to understand the error
if [ "$HTTP_CODE" -ne 200 ]; then
  echo "ERROR: Download failed with HTTP status code: $HTTP_CODE"
  [ -f result.xml ] && cat result.xml  #trying to Show error response from file if available
  exit 1
fi

#Verify file was downloaded and it is not empty as a safe side
if [ ! -s result.xml ]; then
  echo "ERROR: result.xml download failed or is empty"
  exit 1
fi

echo "Done! Test results downloaded successfully to result.xml"
echo "Done! File size: $(du -h result.xml | cut -f1)"


