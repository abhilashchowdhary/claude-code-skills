# Claude Code Skills

Production-tested skills for [Claude Code](https://claude.ai/claude-code) that turn Claude into a specialized operator.

Each skill is a battle-tested workflow extracted from real operations -- not a toy demo. Install any skill into Claude Code CLI, Claude Desktop, or Claude Code Cowork and get an expert-level operator that knows exactly what to research, verify, and produce.

## Skills

| Skill | What it does | Estimated savings |
|-------|-------------|-------------------|
| [aws-cost-audit](./aws-cost-audit/) | Full AWS cost audit with verified optimization plan | $50-100K/month for mid-scale AWS accounts |

## How to Install

### Claude Code CLI

```bash
# Copy any SKILL.md to your commands directory
cp aws-cost-audit/SKILL.md ~/.claude/commands/aws-cost-audit.md

# Then invoke with:
# /aws-cost-audit
```

### Claude Desktop / Cowork

1. Download the `.skill` file from [Releases](../../releases)
2. Open Claude Desktop > Customize > Skills
3. Import the `.skill` file

Or manually copy the `SKILL.md` into your skills plugin directory.

## What Makes These Different

**Multi-source cross-referencing.** These skills don't just query one tool. They launch 5-7 parallel research agents across AWS Cost Explorer, your codebase, Linear/Jira, GitHub, Slack, and Gmail -- then cross-reference findings to surface insights no single tool would catch.

**Verification passes.** Every dollar estimate is verified against actual data with confidence scores (95%, 85%, 70%, 30%). Unverifiable claims are labeled as such. No hallucinated savings numbers.

**Production-ready output.** Each skill produces a formatted Google Doc (or Slack summary) with tables, RAG ratings, owner assignments, status tracking, and deadlines. Ready to share with your team, not a wall of text you need to reformat.

**Battle-tested corrections baked in.** These skills encode dozens of corrections from real usage -- like knowing that EC2 Instance Savings Plans don't cover EMR Serverless (you need Compute Savings Plans), or that Database Savings Plans only cover compute, not storage. The kind of nuance you only learn by getting it wrong.

## Required MCP Servers / Tools

These skills use MCP (Model Context Protocol) servers for data access. You'll need:

| MCP Server | Used by | What it provides |
|------------|---------|------------------|
| [AWS Cost Explorer](https://github.com/awslabs/mcp) | aws-cost-audit | Cost data, usage breakdown, forecasts |
| [GitHub](https://github.com/modelcontextprotocol/servers) | aws-cost-audit | Commit history, PR review, infra changes |
| [Linear](https://linear.app) | aws-cost-audit | Project tracking, shipped features |
| [Slack](https://slack.com) | aws-cost-audit | Team conversations, cost discussions |
| [Gmail](https://gmail.com) | aws-cost-audit | AWS account manager transcripts |
| Google Workspace (gws CLI) | aws-cost-audit | Google Docs output |

## Contributing

Have a workflow that took you hours and you want to turn it into a 5-minute skill? PRs welcome.

A good skill:
- Solves a real problem you've personally faced
- Uses 3+ data sources in parallel
- Includes a verification step
- Produces formatted, shareable output
- Has been corrected at least twice by a human (that's where the intelligence lives)

## License

MIT
