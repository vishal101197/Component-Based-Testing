#!/bin/bash

# push_to_newrelic.sh
# Parses test result files and pushes individual test case results to New Relic
# Usage: ./push_to_newrelic.sh API     → parses Newman JSON from API stage
#        ./push_to_newrelic.sh TOSCA   → parses TOSCA result XML

set -e

# ── Validate arguments ────────────────────────────────────────────────────────
TEST_TYPE="${1}"
if [ "$TEST_TYPE" != "API" ] && [ "$TEST_TYPE" != "TOSCA" ]; then
  echo "ERROR: First argument must be API or TOSCA"
  echo "Usage: ./push_to_newrelic.sh [API|TOSCA]"
  exit 1
fi

# ── Validate required variables ───────────────────────────────────────────────
echo "Validating required variables..."
for var in NEW_RELIC_LICENSE_KEY NEW_RELIC_ACCOUNT_ID DOMAIN_ID COMPONENT_NAME; do
  if [ -z "$(eval echo \$$var)" ]; then
    echo "ERROR: Required variable not set - $var"
    exit 1
  fi
done
echo "All required variables are set."

PIPELINE_ID="${CI_PIPELINE_ID:-unknown}"
EVENTS_FILE="/tmp/nr_events_${TEST_TYPE}.json"

# ══════════════════════════════════════════════════════════════════════════════
# PARSE API RESULTS — Newman JSON
# Pass/fail = HTTP 2xx AND zero assertion failures (not HTTP 200 only)
# ══════════════════════════════════════════════════════════════════════════════
if [ "$TEST_TYPE" = "API" ]; then

  NEWMAN_FILE=$(ls *_api_newman-results.json 2>/dev/null | head -1)

  if [ -z "$NEWMAN_FILE" ] || [ ! -f "$NEWMAN_FILE" ]; then
    echo "ERROR: No Newman results file found matching *_api_newman-results.json"
    exit 1
  fi

  echo "Parsing API results from: $NEWMAN_FILE"

  node - "$NEWMAN_FILE" "$DOMAIN_ID" "$COMPONENT_NAME" "$PIPELINE_ID" "$EVENTS_FILE" << 'EOF'
const fs         = require('fs');
const file       = process.argv[2];
const domain     = process.argv[3];
const component  = process.argv[4];
const pipelineId = process.argv[5];
const outputFile = process.argv[6];

let results;
try {
  results = JSON.parse(fs.readFileSync(file, 'utf8'));
} catch (e) {
  console.error('ERROR: Could not parse Newman JSON:', e.message);
  process.exit(1);
}

const executions = results.run && results.run.executions ? results.run.executions : [];
if (executions.length === 0) {
  console.error('ERROR: No executions found in Newman results');
  process.exit(1);
}

const events = [];

for (const execution of executions) {
  const name = execution.item ? execution.item.name : 'Unknown';
  const code = execution.response ? execution.response.code : 0;

  // HTTP success = any 2xx code (200, 201, 204, etc.)
  const httpOk = code >= 200 && code < 300;

  // Assertion failures = any assertion with a non-null error field
  const assertionFailures = (execution.assertions || []).filter(a => a.error).length;
  const assertionErrors   = (execution.assertions || [])
    .filter(a => a.error)
    .map(a => a.assertion)
    .join('; ');

  // Both conditions must pass
  const status = httpOk && assertionFailures === 0 ? 'Passed' : 'Failed';

  const event = {
    eventType:         'ComponentBasedTestingResults',
    domain:            domain,
    component:         component,
    testType:          'API',
    testCaseName:      name,
    status:            status,
    httpCode:          code,
    assertionFailures: assertionFailures,
    pipelineId:        pipelineId,
    timestamp:         Math.floor(Date.now() / 1000)
  };

  // Include failure detail when present (helps New Relic dashboards)
  if (assertionErrors) {
    event.failureDetail = assertionErrors;
  }

  events.push(event);
  console.log(`  [${status.toUpperCase()}] ${name} (HTTP ${code}${assertionFailures > 0 ? ', ' + assertionFailures + ' assertion(s) failed' : ''})`);
}

fs.writeFileSync(outputFile, JSON.stringify(events));
console.log('Total API test cases parsed: ' + events.length);
EOF

fi

# ══════════════════════════════════════════════════════════════════════════════
# PARSE TOSCA RESULTS — JUnit XML
# ══════════════════════════════════════════════════════════════════════════════
if [ "$TEST_TYPE" = "TOSCA" ]; then

  TOSCA_FILE=$(ls *_result.xml 2>/dev/null | head -1)

  if [ -z "$TOSCA_FILE" ] || [ ! -f "$TOSCA_FILE" ]; then
    echo "ERROR: No TOSCA result file found matching *_result.xml"
    exit 1
  fi

  echo "Parsing TOSCA results from: $TOSCA_FILE"

  node - "$TOSCA_FILE" "$DOMAIN_ID" "$COMPONENT_NAME" "$PIPELINE_ID" "$EVENTS_FILE" << 'EOF'
const fs         = require('fs');
const file       = process.argv[2];
const domain     = process.argv[3];
const component  = process.argv[4];
const pipelineId = process.argv[5];
const outputFile = process.argv[6];

let xml;
try {
  xml = fs.readFileSync(file, 'utf8');
} catch (e) {
  console.error('ERROR: Could not read TOSCA XML file:', e.message);
  process.exit(1);
}

const events = [];
const testcaseRegex = /<testcase([^>]*)\/?>|<testcase([^>]*)>([\s\S]*?)<\/testcase>/g;
let match;

while ((match = testcaseRegex.exec(xml)) !== null) {
  const attrs = match[1] || match[2] || '';
  const inner = match[3] || '';

  const nameMatch = attrs.match(/name="([^"]*)"/);
  if (!nameMatch) continue;
  const name = nameMatch[1];

  const status = inner.includes('<failure') ? 'Failed' : 'Passed';

  // Extract failure message if present
  const failMsgMatch = inner.match(/<failure[^>]*message="([^"]*)"/) ||
                       inner.match(/<failure[^>]*>([\s\S]*?)<\/failure>/);
  const failureDetail = failMsgMatch ? failMsgMatch[1].trim() : null;

  const event = {
    eventType:    'ComponentBasedTestingResults',
    domain:       domain,
    component:    component,
    testType:     'TOSCA',
    testCaseName: name,
    status:       status,
    pipelineId:   pipelineId,
    timestamp:    Math.floor(Date.now() / 1000)
  };

  if (failureDetail) {
    event.failureDetail = failureDetail.substring(0, 500); // NR attribute limit
  }

  events.push(event);
  console.log(`  [${status.toUpperCase()}] ${name}`);
}

if (events.length === 0) {
  console.error('ERROR: No test cases found in TOSCA XML. Check the file format.');
  process.exit(1);
}

fs.writeFileSync(outputFile, JSON.stringify(events));
console.log('Total TOSCA test cases parsed: ' + events.length);
EOF

fi

# ══════════════════════════════════════════════════════════════════════════════
# PUSH EVENTS TO NEW RELIC
# ══════════════════════════════════════════════════════════════════════════════

if [ ! -f "$EVENTS_FILE" ]; then
  echo "ERROR: Events file not created. Parsing may have failed."
  exit 1
fi

EVENT_COUNT=$(node -e "console.log(JSON.parse(require('fs').readFileSync('$EVENTS_FILE','utf8')).length)")
echo "Pushing $EVENT_COUNT events to New Relic (EU endpoint)..."

set +e
HTTP_CODE=$(curl -w "%{http_code}" -o /tmp/nr_response.txt -s \
  -X POST "https://insights-collector.eu01.nr-data.net/v1/accounts/${NEW_RELIC_ACCOUNT_ID}/events" \
  -H "Content-Type: application/json" \
  -H "Api-Key: ${NEW_RELIC_LICENSE_KEY}" \
  -d @"$EVENTS_FILE")
CURL_EXIT=$?
set -e

echo "--- New Relic Response ---"
echo "Curl exit code : $CURL_EXIT"
echo "HTTP status    : $HTTP_CODE"
echo "Response body  : $(cat /tmp/nr_response.txt 2>/dev/null || echo 'empty')"
echo "--------------------------"

if [ $CURL_EXIT -ne 0 ]; then
  echo "ERROR: curl failed to connect to New Relic. Exit code: $CURL_EXIT"
  exit 1
fi

# Accept any 2xx response (200 or 202 are both valid from NR Insights API)
if [ "$HTTP_CODE" -lt 200 ] || [ "$HTTP_CODE" -gt 299 ]; then
  echo "ERROR: New Relic API returned HTTP $HTTP_CODE — check your Ingest License key and Account ID"
  exit 1
fi

echo "Successfully pushed $EVENT_COUNT $TEST_TYPE test results to New Relic."
