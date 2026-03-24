# AWS Cost Audit Skill

A comprehensive AWS cost optimization skill for Claude Code that performs a full infrastructure cost audit, cross-references findings across 7 data sources, verifies every recommendation against actual AWS data, and produces a stack-ranked action plan in a Google Doc.

**Built from a real audit that identified $76-101K/month in verified savings on a ~$140K/month AWS bill.**

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

## Quick Start

### Prerequisites

You need these MCP servers configured:

- **AWS Cost Explorer MCP** -- for cost data ([aws-cost MCP](https://github.com/awslabs/mcp))
- **GitHub MCP** -- for repo analysis
- **Slack MCP** -- for conversation search
- **Gmail MCP** -- for account manager emails
- **Linear MCP** -- for project tracking (or substitute Jira)
- **gws CLI** -- for Google Docs output

### Install

**Claude Code CLI:**
```bash
cp SKILL.md ~/.claude/commands/aws-cost-audit.md
```

Then run:
```
/aws-cost-audit
```

**Claude Desktop / Cowork:**

Download `aws-cost-audit.skill` from [Releases](../../releases) and import via Customize > Skills.

### Parameters

The skill will ask you:

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

Specific verification rules baked in:
- Compute Savings Plans cover EC2 + EMR + Fargate + Lambda. EC2 Instance SPs only cover EC2.
- Database Savings Plans cover RDS + Aurora compute only -- not storage, backups, or proxy.
- S3 Intelligent-Tiering only helps for data that's 30+ days old and infrequently accessed.
- NAT Gateway costs are per-GB processed -- check VPC Flow Logs to confirm traffic patterns.
- EMR Serverless Graviton/ARM is ~20% cheaper but savings depend on sequencing with other optimizations.
- Partial-month data must be projected using days_in_month / days_elapsed.

## RAG Classification

| Rating | Criteria | Typical items |
|--------|----------|---------------|
| RED | Do this week. Active cost bleeding or misconfiguration. >$10K/mo impact. | Missing VPC endpoints, runaway pipelines, small-file antipatterns |
| AMBER | Do this month. Optimization requiring some effort. $1-10K/mo. | Savings Plans, Graviton migration, cadence reduction |
| GREEN | Next 30-60 days. Structural improvements, <$1K/mo or unverifiable. | Terraform, cross-AZ optimization, vendor evaluations |

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
