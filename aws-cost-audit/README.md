# AWS Cost Audit Skill

A comprehensive AWS cost optimization skill for Claude Code that performs a full infrastructure cost audit, cross-references findings across 7 data sources, verifies every recommendation against actual AWS data, and produces a stack-ranked action plan in a Google Doc.

**Built from a real audit that identified $76-101K/month in verified savings on a ~$140K/month AWS bill.**

## One-Command Setup

This installs everything -- creates an IAM user with read-only Cost Explorer permissions, generates an access key, configures the MCP server, and installs the skill.

```bash
curl -fsSL https://raw.githubusercontent.com/abhilashchowdhary/claude-code-skills/main/aws-cost-audit/setup.sh | bash
```

**What it does (in 30 seconds):**

```
[1/6] Checks prerequisites (AWS CLI, uvx, Claude Code)
[2/6] Creates IAM policy "CostExplorerMCPPolicy" (read-only ce:*, compute-optimizer:*, budgets:ViewBudget)
[3/6] Creates IAM user "claude-cost-explorer"
[4/6] Generates access key and secret
[5/6] Adds MCP server config to ~/.claude/settings.json
[6/6] Downloads and installs the /aws-cost-audit skill
```

**Prerequisites:**
- AWS CLI installed and configured with admin credentials (`aws configure`)
- Python 3.10+
- Claude Code CLI installed

After setup, restart Claude Code and run:
```
/aws-cost-audit
```

### Manual Setup

If you prefer to do it step by step:

<details>
<summary>Click to expand manual setup</summary>

#### 1. Create IAM Policy

```bash
aws iam create-policy \
  --policy-name CostExplorerMCPPolicy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
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
          "ce:GetReservationUtilization",
          "ce:GetSavingsPlansCoverage",
          "ce:GetSavingsPlansUtilization",
          "ce:GetUsageForecast",
          "ce:GetAnomalies",
          "ce:GetCostCategories",
          "compute-optimizer:Get*",
          "budgets:ViewBudget"
        ],
        "Resource": "*"
      }
    ]
  }'
```

#### 2. Create IAM User + Access Key

```bash
aws iam create-user --user-name claude-cost-explorer
aws iam attach-user-policy \
  --user-name claude-cost-explorer \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/CostExplorerMCPPolicy
aws iam create-access-key --user-name claude-cost-explorer
# Save the AccessKeyId and SecretAccessKey from the output
```

#### 3. Install uvx (if not already installed)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

#### 4. Add to Claude Code settings

Edit `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "aws-cost": {
      "command": "uvx",
      "args": ["awslabs.cost-explorer-mcp-server@latest"],
      "env": {
        "AWS_ACCESS_KEY_ID": "YOUR_ACCESS_KEY_ID",
        "AWS_SECRET_ACCESS_KEY": "YOUR_SECRET_ACCESS_KEY",
        "AWS_REGION": "us-east-1",
        "FASTMCP_LOG_LEVEL": "ERROR"
      }
    }
  }
}
```

#### 5. Install the skill

```bash
cp SKILL.md ~/.claude/commands/aws-cost-audit.md
```

</details>

### Security Notes

- The IAM user has **read-only** access. It cannot create, modify, or delete any AWS resources.
- The only cost incurred is **$0.01 per Cost Explorer API call** (typically 15-40 calls per audit = $0.15-$0.40).
- Access key is stored in `~/.claude/settings.json` -- treat this file as sensitive.
- To revoke access: `aws iam delete-user --user-name claude-cost-explorer`

---

## What It Does

```
You: "Our AWS bill spiked last month. Figure out why and what to do about it."

Skill: launches 7 parallel research agents
       -> cross-references findings
       -> verifies every estimate against actual AWS data
       -> produces a Google Doc with stack-ranked action table
```

### The 7 Research Streams (run in parallel)

1. **Business Context** (Web Search) -- understands what kind of infra the business needs
2. **AWS Cost Explorer** -- 12-month breakdown by service, usage type, region, purchase type; Savings Plans and RI verification; cost forecasts
3. **Codebase Architecture** -- maps tech stack, IaC files, data pipelines, and AWS service configs to cost data
4. **Linear / Jira** -- identifies shipped features, scaling events, and migrations that explain cost changes
5. **GitHub** -- reviews recent commits, PRs, releases, and infrastructure changes
6. **Slack** -- searches 15+ cost/infra topics across channels, reads full threads for context
7. **Gmail** -- finds AWS account manager emails, call transcripts, action items, credit offers

### What It Catches (examples from real audits)

- NAT Gateway misconfigurations routing S3 traffic through paid NAT instead of free VPC endpoints ($30-39K/month)
- Spark small-file antipatterns: billions of 1.2KB PUT requests instead of coalesced Parquet files ($25-32K/month)
- Pipeline over-frequency: all tables refreshing 4x/day when most data sources update daily ($14-18K/month)
- Wrong Savings Plan type: EC2 Instance SPs that don't cover EMR Serverless (need Compute SPs)
- Expiring Reserved Instances with no replacement plan
- Triple-paying for observability (running Datadog + VictoriaLogs + ClickHouse simultaneously)
- Admin apps connected to production databases with admin privileges
- "Demo" S3 buckets running in production with no lifecycle policies

### Output Format

A Google Doc with:

1. **Stack-ranked action table** (the first thing readers see)
   - Columns: #, Action, Saves/mo, Confidence, RAG, Owner, Status, Deadline
   - Dark header row, colored RAG cells, bold owner pills, alternating row shading
2. **Savings summary** with confidence bands (high/medium/low)
3. **Root cause analysis** of cost drivers
4. **Current commitments** (verified Savings Plans + Reserved Instances)
5. **Pending follow-ups** with AWS account team
6. **What's already been done** (credit for completed optimizations)

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| Time period | 12 months | How far back to analyze |
| AWS account manager | (none) | Name/email to search Gmail for call transcripts |
| Output format | Google Doc | Google Doc, Slack summary, or both |
| Focus area | Full audit | Full audit or specific service (EMR, S3, RDS, etc.) |
| Stakeholders | (ask) | Names for owner assignment in action items |

## How the Verification Pass Works

This is what separates this skill from a generic "look at Cost Explorer" prompt.

After the initial research, the skill launches a **verification agent** that re-queries AWS Cost Explorer for every action item:

1. Gets the **exact monthly cost** of the component being optimized
2. Calculates **realistic savings** based on the specific optimization
3. Assigns a **confidence level**:
   - **95%** -- verified against exact AWS data
   - **85%** -- calculated from data with reasonable assumptions
   - **70%** -- estimated, some uncertainty
   - **30%** -- unverifiable from current data
4. **Corrects** any over/under-estimates from the initial pass

Verification rules baked in:
- Compute Savings Plans cover EC2 + EMR + Fargate + Lambda. EC2 Instance SPs only cover EC2.
- Database Savings Plans cover RDS + Aurora compute only -- not storage, backups, or proxy.
- S3 Intelligent-Tiering only helps for data 30+ days old and infrequently accessed.
- NAT Gateway costs are per-GB -- check VPC Flow Logs to confirm traffic patterns.
- Partial-month data must be projected using days_in_month / days_elapsed.

## RAG Classification

| Rating | Criteria | Typical items |
|--------|----------|---------------|
| RED | Do this week. Active bleeding or misconfiguration. >$10K/mo. | Missing VPC endpoints, runaway pipelines, small-file antipatterns |
| AMBER | Do this month. Optimization needing effort. $1-10K/mo. | Savings Plans, Graviton migration, cadence reduction |
| GREEN | Next 30-60 days. Structural improvements, <$1K/mo. | Terraform, cross-AZ optimization, vendor evaluations |

## Example Results

From a real audit on a B2B data platform (~$140K/month AWS spend):

| # | Action | Saves/mo | Confidence |
|---|--------|----------|------------|
| 1 | Fix NAT Gateway (S3 Gateway Endpoint + PrivateLink) | $30-39K | 95% |
| 2 | Coalesce Spark output (.coalesce() on PySpark) | $25-32K | 95% |
| 3 | Reduce EMR pipeline cadence (4x to 2x avg) | $14-18K | 85% |
| 4 | Compute Savings Plans (covers EMR Serverless) | $5-8K | 85% |
| 5 | EMR Graviton/ARM migration | $3-7K | 90% |

**Top 3 actions alone: $69-89K/month in verified savings.**

## License

MIT
