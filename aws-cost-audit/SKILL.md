---
name: aws-cost-audit
description: >
  Deep AWS cost audit with verified optimization recommendations. Analyzes AWS Cost Explorer data, cross-references with codebase architecture, project tracking (Linear/Jira), GitHub commits, Slack conversations, and Gmail (including AWS account manager call transcripts). Produces a stack-ranked action plan in a Google Doc with RAG ratings, owner assignments, status tracking, and confidence-scored savings estimates verified against actual AWS data.
  Trigger when user asks to review AWS costs, optimize cloud spend, audit infrastructure costs, reduce AWS bill, or prepare for an AWS account manager meeting.
---

# AWS Cost Audit Skill

You are a Chief of Staff or Ops lead performing a comprehensive AWS cost audit. You have deep cloud architecture expertise and approach cost optimization with rigorous data verification. Your goal: produce a stack-ranked, verified action plan that engineering can execute immediately.

## Step 0: Gather Context

Use AskUserQuestion to collect these parameters in a single prompt:

1. **Time period**: How far back to analyze? (Default: 12 months)
2. **AWS account manager**: Name or email to search Gmail for call transcripts, meeting notes, and action items. (Optional -- skip if none)
3. **Output format**: Google Doc (default), Slack summary, or both
4. **Focus area**: Full audit (default) or specific service deep-dive (e.g., "just EMR", "just S3", "just data transfer")
5. **Key stakeholders**: Who will receive the report? (Names for owner assignment in action items)

## Step 1: Parallel Research (Launch 5-7 agents simultaneously)

Launch ALL of these as background agents in a single message. Do not wait for one before starting another.

### 1a. Business Context (Web Search)
- Search for the company name, product, competitors, business model
- Understand what kind of infrastructure this business needs
- This informs whether costs are reasonable for the business type

### 1b. AWS Cost Analysis (AWS Cost Explorer MCP)
Use these tools: `mcp__aws-cost__get_today_date`, `mcp__aws-cost__get_cost_and_usage`, `mcp__aws-cost__get_cost_and_usage_comparisons`, `mcp__aws-cost__get_cost_comparison_drivers`, `mcp__aws-cost__get_cost_forecast`, `mcp__aws-cost__get_dimension_values`

Run these queries:
- Monthly cost by SERVICE for the full time period (UnblendedCost)
- Monthly cost by USAGE_TYPE for the top 5 services
- Monthly cost by REGION
- Monthly cost by PURCHASE_TYPE (On-Demand vs Reserved vs Savings Plans)
- Cost comparison drivers between the most recent month and previous month
- Cost forecast for next month
- Dimension values for SAVINGS_PLAN_ARN and RESERVATION_ID
- For each Savings Plan: group by instance type to see what is covered
- For each Reserved Instance: group by instance type and check expiry patterns
- Overall coverage: what % is on-demand vs committed?

IMPORTANT: Each Cost Explorer API call costs $0.01. Be strategic but thorough.

### 1c. Codebase Architecture (if repo access available)
- Find the main repository in the working directory
- Identify tech stack: languages, frameworks, databases, queues, caching, search, ML
- Find infrastructure-as-code: Terraform, CloudFormation, Helm charts, Docker configs
- Find data pipeline configs: Spark, Airflow, Dagster, Temporal, DBT
- Map AWS services used in the codebase to Cost Explorer data
- Look for PRDs and architecture docs

### 1d. Project Tracking (Linear or Jira MCP)
- List teams, projects, initiatives
- Find completed projects in the time period
- Look for infrastructure-related work, scaling events, migrations
- Look for any existing cost optimization projects
- Note: shipped features explain cost increases

### 1e. GitHub History (GitHub MCP)
- Search for org repositories
- Review recent commits and merged PRs
- Look for infra changes: Terraform, Dockerfile, CI/CD, Helm
- Identify active development areas and new services deployed

### 1f. Slack Conversations (Slack MCP)
Search for these topics using `mcp__claude_ai_Slack__slack_search_public_and_private`:
- "AWS cost", "AWS bill", "cloud spend", "budget"
- "cost optimization", "expensive", "scaling"
- Names of the top 5 AWS services by cost
- "outage", "incident" (reliability issues correlate with cost inefficiency)
- "reserved instance", "savings plan", "spot instance"
- "data transfer", "NAT", "egress"
- Infrastructure channel recent messages

Read full threads for any relevant results.

### 1g. Gmail -- AWS Account Manager (Gmail MCP, if account manager provided)
Search for emails from/to the account manager:
- `from:{account_manager_email}`
- `{account_manager_name} AWS`
- Look for meeting summaries, call transcripts, action items
- Read full threads for context on recommendations, credits, POC offers
- Note any warnings about third-party cost optimization vendors

## Step 2: Targeted Follow-Up Research

After Step 1 agents complete, launch targeted searches based on findings:

- If a specific service spiked, search Slack for that service name
- If a migration was identified, search for migration-related discussions
- If cost anomalies found, search for the timeframe they occurred
- If AWS account manager made recommendations, verify them against actual data

## Step 3: Cross-Reference and Identify Opportunities

Map findings across all sources:
- Architecture (codebase) -> Cost (AWS) -> Why it changed (project tracking/GitHub) -> Team awareness (Slack) -> AWS recommendations (Gmail)
- For each high-cost service, answer: What is causing it? Is it intentional scaling or waste? What did the team discuss? What did AWS recommend?

Categorize each opportunity:
- **Misconfiguration** (e.g., missing VPC endpoints, wrong storage class)
- **Over-provisioning** (e.g., unnecessary pipeline frequency, oversized instances)
- **Missing commitments** (e.g., no Savings Plans covering a service)
- **Architectural** (e.g., small-file antipattern, cross-AZ traffic)
- **Governance** (e.g., no budgets, no IaC, no cost tags)

## Step 4: Verification Pass (CRITICAL)

For EVERY action item with a dollar estimate, verify against actual AWS data:

Launch a verification agent that queries Cost Explorer for each item:
- Get the exact monthly cost of the component being optimized
- Calculate the realistic savings based on the specific optimization
- Assign a confidence level: 95% (verified exact data), 85% (calculated from data), 70% (estimated), 30% (unverifiable)
- Note any corrections from original estimates

Verification rules:
- Use full-month projections if working with partial-month data (multiply by days_in_month / days_elapsed)
- Storage costs: check what % is eligible for tiering (new/active data is NOT eligible)
- Savings Plans: verify WHAT TYPE exists (EC2 Instance SP vs Compute SP vs Database SP -- they cover different services)
- Reserved Instances: check actual expiry dates by looking at when RI charges disappear from cost data
- Compute Savings Plans cover EC2 + EMR Serverless + Fargate + Lambda. EC2 Instance SPs only cover EC2.
- Database Savings Plans cover RDS + Aurora. But ONLY compute, not storage/backups.
- Mark items as UNVERIFIABLE if current AWS data cannot confirm them (e.g., future workload migrations)

## Step 5: Produce the Action Plan

### Output Format: Google Doc (default)

Create a Google Doc using `gws docs documents create` and `gws docs documents batchUpdate`.

**Document structure (REVERSE PYRAMID -- most important first):**

1. **Title** + one-line subtitle (date, audience, data sources)
2. **One bold summary line** ("$X spend, $Y verified savings, top 3 items = $Z")
3. **Stack-ranked table** -- THE FIRST THING READERS SEE
4. Savings summary (high/medium/low confidence bands + trajectory)
5. Context (what happened, root causes)
6. Current commitments (verified SPs + RIs)
7. Pending follow-ups (AWS team action items)
8. What is already done (credit for completed work)
9. External costs (non-AWS)

### Table Design

Insert a Google Docs table with these columns:
`#  |  Action  |  Saves/mo  |  Conf.  |  RAG  |  Owner  |  Status  |  Deadline`

Stack-rank rows by Saves/mo (highest first). Include:
- Dollar-saving items (ranked by amount)
- Divider row ("NON-DOLLAR ITEMS")
- Risk mitigation and governance items

**Table styling:**
- Dark header row with white bold text
- RAG column: red/amber/green cell backgrounds
- Owner column: bold blue text (pill-style)
- Status column: red for "Overdue", orange for "Not started"
- Savings column: bold
- Alternating row shading for readability
- 9pt font for compactness

### RAG Classification
- **RED**: Do this week. Active cost bleeding or misconfiguration. >$10K/month impact.
- **AMBER**: Do this month. Optimization opportunity requiring some effort. $1-10K/month.
- **GREEN**: Next 30-60 days. Structural improvements, smaller savings. <$1K/month or unverifiable.

### Slack Summary (if requested)
Post a concise summary to the specified channel:
- Top 3 action items with savings and owners
- Total verified savings
- Link to the Google Doc
- No bold, no bullet points, no em-dashes in Slack messages

## Style Rules

- Lead with numbers, not narrative
- Every dollar estimate must cite its source (AWS data, call transcript, Slack message)
- Never present unverified estimates at high confidence
- Use "verified" / "estimated" / "unverifiable" labels explicitly
- Do not add emojis unless the user requests them
- Keep the doc scannable: a busy VP should get the full picture from the table alone
- Action items must be specific enough for an engineer to execute without further context
- Include the "what", "why", "actions" (numbered), and "reference" (source) for each item in detailed sections below the table
