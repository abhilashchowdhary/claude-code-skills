#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# AWS Cost Audit Skill - One-Command Setup
# =============================================================================
# Creates an IAM user with Cost Explorer permissions, generates an access key,
# and configures the AWS Cost Explorer MCP server in Claude Code.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/abhilashchowdhary/claude-code-skills/main/aws-cost-audit/setup.sh | bash
#
# Or:
#   chmod +x setup.sh && ./setup.sh
#
# Prerequisites:
#   - AWS CLI installed and configured with admin credentials (aws configure)
#   - Python 3.10+ with uvx (pip install uv)
#   - Claude Code CLI installed
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

IAM_USER="claude-cost-explorer"
POLICY_NAME="CostExplorerMCPPolicy"
REGION="us-east-1"
MCP_SERVER_NAME="aws-cost"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  AWS Cost Audit Skill - Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# -----------------------------------------------------------------------------
# Step 1: Check prerequisites
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[1/6]${NC} Checking prerequisites..."

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI not found. Install it first:${NC}"
    echo "  brew install awscli   (macOS)"
    echo "  pip install awscli    (pip)"
    echo "  https://aws.amazon.com/cli/"
    exit 1
fi

if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS CLI not configured. Run 'aws configure' first.${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CURRENT_USER=$(aws sts get-caller-identity --query Arn --output text)
echo -e "  AWS Account: ${GREEN}${ACCOUNT_ID}${NC}"
echo -e "  Current identity: ${GREEN}${CURRENT_USER}${NC}"

if ! command -v uvx &> /dev/null; then
    echo -e "${YELLOW}  uvx not found. Installing uv...${NC}"
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

echo -e "  ${GREEN}All prerequisites met.${NC}"
echo

# -----------------------------------------------------------------------------
# Step 2: Create IAM policy
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[2/6]${NC} Creating IAM policy '${POLICY_NAME}'..."

POLICY_DOC=$(cat <<'POLICY'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CostExplorerRead",
      "Effect": "Allow",
      "Action": [
        "ce:GetCostAndUsage",
        "ce:GetCostAndUsageWithResources",
        "ce:GetCostForecast",
        "ce:GetDimensionValues",
        "ce:GetTags",
        "ce:GetCostAndUsageComparisons",
        "ce:GetCostComparisonDrivers",
        "ce:GetReservationCoverage",
        "ce:GetReservationPurchaseRecommendation",
        "ce:GetReservationUtilization",
        "ce:GetSavingsPlansCoverage",
        "ce:GetSavingsPlansPurchaseRecommendation",
        "ce:GetSavingsPlansUtilization",
        "ce:GetSavingsPlansUtilizationDetails",
        "ce:GetUsageForecast",
        "ce:GetAnomalies",
        "ce:GetAnomalyMonitors",
        "ce:GetAnomalySubscriptions",
        "ce:GetCostCategories"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ComputeOptimizerRead",
      "Effect": "Allow",
      "Action": [
        "compute-optimizer:GetEC2InstanceRecommendations",
        "compute-optimizer:GetEBSVolumeRecommendations",
        "compute-optimizer:GetLambdaFunctionRecommendations",
        "compute-optimizer:GetAutoScalingGroupRecommendations",
        "compute-optimizer:GetRDSInstanceRecommendations",
        "compute-optimizer:GetECSServiceRecommendations",
        "compute-optimizer:GetIdleRecommendations"
      ],
      "Resource": "*"
    },
    {
      "Sid": "BudgetsRead",
      "Effect": "Allow",
      "Action": [
        "budgets:ViewBudget"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
)

# Check if policy already exists
EXISTING_POLICY=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='${POLICY_NAME}'].Arn" --output text 2>/dev/null || true)

if [ -n "$EXISTING_POLICY" ] && [ "$EXISTING_POLICY" != "None" ]; then
    POLICY_ARN="$EXISTING_POLICY"
    echo -e "  ${GREEN}Policy already exists: ${POLICY_ARN}${NC}"
else
    POLICY_ARN=$(aws iam create-policy \
        --policy-name "${POLICY_NAME}" \
        --policy-document "${POLICY_DOC}" \
        --description "Read-only access to AWS Cost Explorer, Compute Optimizer, and Budgets for the Claude Cost Audit MCP server" \
        --query 'Policy.Arn' --output text)
    echo -e "  ${GREEN}Created: ${POLICY_ARN}${NC}"
fi
echo

# -----------------------------------------------------------------------------
# Step 3: Create IAM user
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[3/6]${NC} Creating IAM user '${IAM_USER}'..."

if aws iam get-user --user-name "${IAM_USER}" &> /dev/null; then
    echo -e "  ${GREEN}User already exists.${NC}"
else
    aws iam create-user --user-name "${IAM_USER}" > /dev/null
    echo -e "  ${GREEN}Created user: ${IAM_USER}${NC}"
fi

# Attach policy
aws iam attach-user-policy --user-name "${IAM_USER}" --policy-arn "${POLICY_ARN}" 2>/dev/null || true
echo -e "  ${GREEN}Policy attached.${NC}"
echo

# -----------------------------------------------------------------------------
# Step 4: Create access key
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[4/6]${NC} Creating access key..."

# Check if user already has 2 keys (max)
KEY_COUNT=$(aws iam list-access-keys --user-name "${IAM_USER}" --query 'length(AccessKeyMetadata)' --output text)

if [ "$KEY_COUNT" -ge 2 ]; then
    echo -e "  ${YELLOW}User already has 2 access keys (AWS max). Deleting oldest...${NC}"
    OLDEST_KEY=$(aws iam list-access-keys --user-name "${IAM_USER}" --query 'AccessKeyMetadata | sort_by(@, &CreateDate) | [0].AccessKeyId' --output text)
    aws iam delete-access-key --user-name "${IAM_USER}" --access-key-id "${OLDEST_KEY}"
fi

KEY_OUTPUT=$(aws iam create-access-key --user-name "${IAM_USER}")
ACCESS_KEY_ID=$(echo "${KEY_OUTPUT}" | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessKey']['AccessKeyId'])")
SECRET_KEY=$(echo "${KEY_OUTPUT}" | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessKey']['SecretAccessKey'])")

echo -e "  ${GREEN}Access Key ID: ${ACCESS_KEY_ID}${NC}"
echo -e "  ${GREEN}Secret Key: ****${SECRET_KEY: -4}${NC}"
echo

# -----------------------------------------------------------------------------
# Step 5: Configure Claude Code MCP server
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[5/6]${NC} Configuring Claude Code MCP server..."

UVX_PATH=$(which uvx 2>/dev/null || echo "$HOME/.local/bin/uvx")
SETTINGS_FILE="$HOME/.claude/settings.json"

# Create settings file if it doesn't exist
if [ ! -f "${SETTINGS_FILE}" ]; then
    mkdir -p "$HOME/.claude"
    echo '{}' > "${SETTINGS_FILE}"
fi

# Use Python to safely merge the MCP server config into settings.json
python3 << PYEOF
import json
import os

settings_path = os.path.expanduser("${SETTINGS_FILE}")

with open(settings_path, 'r') as f:
    settings = json.load(f)

if 'mcpServers' not in settings:
    settings['mcpServers'] = {}

settings['mcpServers']['${MCP_SERVER_NAME}'] = {
    'command': '${UVX_PATH}',
    'args': ['awslabs.cost-explorer-mcp-server@latest'],
    'env': {
        'AWS_ACCESS_KEY_ID': '${ACCESS_KEY_ID}',
        'AWS_SECRET_ACCESS_KEY': '${SECRET_KEY}',
        'AWS_REGION': '${REGION}',
        'FASTMCP_LOG_LEVEL': 'ERROR'
    }
}

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)

print(f'  Updated {settings_path}')
PYEOF

echo -e "  ${GREEN}MCP server '${MCP_SERVER_NAME}' configured.${NC}"
echo

# -----------------------------------------------------------------------------
# Step 6: Install the skill
# -----------------------------------------------------------------------------
echo -e "${YELLOW}[6/6]${NC} Installing skill..."

COMMANDS_DIR="$HOME/.claude/commands"
mkdir -p "${COMMANDS_DIR}"

# Download SKILL.md from GitHub
curl -fsSL "https://raw.githubusercontent.com/abhilashchowdhary/claude-code-skills/main/aws-cost-audit/SKILL.md" \
    -o "${COMMANDS_DIR}/aws-cost-audit.md"

echo -e "  ${GREEN}Skill installed at ${COMMANDS_DIR}/aws-cost-audit.md${NC}"
echo

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}  Setup complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo
echo -e "  IAM User:     ${IAM_USER}"
echo -e "  Access Key:   ${ACCESS_KEY_ID}"
echo -e "  Region:       ${REGION}"
echo -e "  MCP Server:   ${MCP_SERVER_NAME}"
echo -e "  Skill:        /aws-cost-audit"
echo
echo -e "  ${YELLOW}Next steps:${NC}"
echo -e "  1. Restart Claude Code CLI (or open a new session)"
echo -e "  2. Type: /aws-cost-audit"
echo -e "  3. Follow the prompts"
echo
echo -e "  ${YELLOW}Security note:${NC}"
echo -e "  The access key is stored in ~/.claude/settings.json"
echo -e "  The IAM user has READ-ONLY access to Cost Explorer, Compute Optimizer, and Budgets."
echo -e "  It cannot modify any resources or incur charges (except $0.01/Cost Explorer API call)."
echo
