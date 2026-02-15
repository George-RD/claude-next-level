# $100M Leads Engine — Design Document

**Date:** 2026-02-15
**Status:** Approved
**Plugin:** `hundred-million-leads/`
**Companion to:** `grandslam-offer/`

## Overview

A Claude Code skill that builds complete lead generation systems using Alex Hormozi's $100M Leads methodology. Uses adversarial agent teams (Growth Hacker, Skeptical Marketer, Business Strategist, 2-3 dynamic customer personas) to stress-test every decision.

Key innovation: customer personas **receive outreach as real prospects** in Phase 3, not just review it as outsiders.

## Architecture

6 sequential phases with adversarial checkpoints, mirroring the grandslam-offer pattern:

| Phase | Name | Key Output |
|-------|------|------------|
| 0 | Discovery & Offer Audit | Import offer OR Value Equation check + personas |
| 1 | Lead Magnet Lab | 3+ lead magnets with full specs |
| 2 | Core Four Selection | Primary + secondary channel with scoring matrix |
| 3 | Tactical Execution | Ready-to-use scripts, ads, content calendars |
| 4 | Lead Getters | Referral system, affiliate outreach, delegation playbook |
| 5 | Rule of 100 | Daily checklist + tracking framework + milestones |

## Agent Team

| Agent | Type | Present |
|-------|------|---------|
| Skeptical Marketer | Core (reused from grandslam-offer) | All phases |
| Business Strategist | Core (reused from grandslam-offer) | All phases |
| Growth Hacker | Core (new) | All phases |
| Customer Personas (2-3) | Dynamic (built in Phase 0) | All phases, role shifts per phase |

## Connection to Grand Slam Offer

- Standalone by default
- Can import Grand Slam Offer summary if user has one
- If no offer exists, runs condensed Value Equation audit
- Recommends running grandslam-offer if offer scores < 6/10

## Key Design Decisions

1. **Full tactical output** — generates actual ready-to-use scripts, not just strategy
2. **Persona immersion** — personas receive outreach as recipients, not reviewers
3. **7/10 convergence gate** — scripts must score 7+ average from personas
4. **Research-backed** — WebSearch for platform benchmarks, competitor analysis, CPL data
5. **Rule of 100 integration** — ends with executable daily plan, not just theory

## File Structure

```
hundred-million-leads/
  plugin.json
  skills/
    hundred-million-leads/
      SKILL.md (main skill file)
```

## Sources

- Greg Faxon's $100M Leads Summary
- Shortform $100M Leads Overview
- GrowthSummary 8 Rules from $100M Leads
- VidTao Lead Magnet Framework Analysis
- Powercademy Hook/Retain/Reward Framework
- ItsMostly Content Strategy Breakdown
