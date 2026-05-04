#!/bin/bash

set -e  # Exit on any error

echo "Extracting Execution ID from Newman results..."

# Check if newman-results.json exists
if [ ! -f "newman-results.json" ]; then
  echo "ERROR: newman-results.json not found"
  exit 1
fi

# Create Node.js script to extract Execution ID
cat > extract_exec_id.js << 'EOF'
const fs = require('fs');
const results = JSON.parse(fs.readFileSync('./newman-results.json', 'utf8'));
const execution = results.run.executions.find(e => e.item.name === 'Execute');
if (!execution) { 
  console.error('ERROR: Could not find Execute request in results'); 
  process.exit(1); 
}
const executionId = JSON.parse(Buffer.from(execution.response.stream.data).toString('utf8')).ExecutionId;
fs.writeFileSync('execution.env', 'EXECUTION_ID=' + executionId);
console.log('Execution ID extracted: ' + executionId);
EOF

# Run the extraction
node extract_exec_id.js

# Verify execution.env was created
if [ ! -f "execution.env" ]; then
  echo "ERROR: execution.env file was not created"
  exit 1
fi

# Load the variable
source execution.env

# Verify EXECUTION_ID is set
if [ -z "$EXECUTION_ID" ]; then
  echo "ERROR: EXECUTION_ID not set after extraction"
  exit 1
fi

echo "Execution ID loaded: $EXECUTION_ID"

# Export for use by other scripts
export EXECUTION_ID