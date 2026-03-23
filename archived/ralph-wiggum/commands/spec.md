---
description: "Phase 1: Define JTBD requirements and write specs"
argument-hint: "[topic description]"
---

# Ralph Wiggum: Spec (Phase 1 - Define Requirements)

You are helping the user define Jobs to Be Done (JTBD) and write requirement specs for their project. This is Phase 1 of the Ralph methodology.

## Your role

Guide the user through identifying what needs to be built, breaking it into discrete topics, and writing clear specs. You are having a conversation - ask questions, clarify requirements, and probe for edge cases before writing anything.

## Process

### 1. Understand the JTBD

Ask the user what they're trying to build and for whom. Identify the high-level Jobs to Be Done - the outcomes users want to achieve.

### 2. Break into topics of concern

Each JTBD decomposes into topics. Apply the **"One Sentence Without And" test**:
- Can you describe the topic in one sentence without conjoining unrelated capabilities?
- "The color extraction system analyzes images to identify dominant colors" - one topic
- "The user system handles authentication, profiles, and billing" - three topics

### 3. Interview for each topic

For each topic of concern, use AskUserQuestion to systematically clarify:
- What does success look like? (acceptance criteria)
- What are the edge cases?
- What constraints exist? (performance, compatibility, etc.)
- What dependencies does this have on other topics?

### 4. Write specs

For each topic, create `specs/TOPIC_NAME.md` with:
- Clear description of what this component does
- Acceptance criteria (behavioral outcomes, not implementation details)
- Edge cases and error handling expectations
- Dependencies on other specs

Let the format emerge naturally - don't force a rigid template. The spec should be clear enough that someone (or Ralph) can implement from it without ambiguity.

### 5. Verify completeness

Before finishing, review the full set of specs:
- Do they cover all identified JTBDs?
- Are there gaps between specs (things that fall through the cracks)?
- Are acceptance criteria verifiable?

## Key principles

- **Specs are the source of truth** for what gets built. Get them right.
- **Behavioral, not prescriptive** - describe WHAT success looks like, not HOW to build it.
- **One spec per topic** - keep them focused and independently implementable.
- **Acceptance criteria matter** - they become the backpressure that keeps Ralph honest during building.

## If the user provides a topic description

If arguments were provided, treat them as the starting point for the first topic. Begin the interview process for that topic immediately.

Arguments: $ARGUMENTS
