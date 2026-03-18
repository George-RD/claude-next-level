# Named Guarantee Guidance — Feature Spec

**Status**: IMPLEMENTED (PR #46, merged 2026-03-18)
**Issue**: #45
**Plugin**: grandslam-offer
**Target**: `skills/grandslam-offer/SKILL.md` — Phase 5, Guarantees section
**Research**: `docs/plans/hormozi-guarantee-naming-research.md`

---

## Problem

The current Guarantees section in Phase 5 is a shallow 5-row type table with a single insight line. It doesn't guide users through Hormozi's actual guarantee creation process — specifically the **named guarantee** technique that turns generic "money-back" language into memorable, branded commitments that differentiate the offer and dramatically increase conversion.

## Integration Point

**Replace** lines 669-679 of `grandslam-offer/skills/grandslam-offer/SKILL.md` (the current `### Guarantees (Risk Reversal)` section) with the expanded section below. Also update:

- The Quick Reference formula at line 776 (`Guarantee Stack: ...`)
- The adversarial review prompts (lines 700, 703, 706) to include guarantee naming in their evaluation
- The Research Brief template gap analysis for Phase 5 (line 156) to include guarantee naming landscape data

No new files needed. No structural changes to the phase flow. This is a **depth expansion** of an existing sub-step.

---

## Expanded Section: Guarantees (Risk Reversal + Named Guarantees)

### Step 1: Map Prospect Fears

Before choosing a guarantee type, identify what the prospect fears **beyond losing money**:

| Fear Category | Question | Example |
|---------------|----------|---------|
| **Financial loss** | "What if it doesn't work and I lose $X?" | Wasted investment |
| **Time waste** | "What if I spend weeks/months and get nothing?" | Sunk time |
| **Social embarrassment** | "What if people find out I failed at this?" | Reputation risk |
| **Opportunity cost** | "What if I pick this and miss a better option?" | FOMO |
| **Emotional investment** | "What if I get my hopes up again?" | Vulnerability |

List the prospect's **top 3 fears** in order of intensity. These drive the guarantee design.

### Step 2: Choose Guarantee Type(s)

Hormozi identifies **4 categories with 13+ structures**. Choose based on ticket price, fulfillment cost, and market:

**Unconditional Guarantees** (strongest risk reversal — customer pays, then evaluates like a trial):

| Structure | Description | Best For |
|-----------|-------------|----------|
| **No Questions Asked** | Full refund, no conditions | Low-ticket B2C where refund friction naturally deters most claims |
| **Satisfaction-Based** | Refund triggered by prospect's subjective dissatisfaction | Low-mid ticket, simple fulfillment |

**Conditional Guarantees** (customer must meet specific terms — outperform generic money-back):

Formula: **"If you do not get [X result] in [Y time period], we will [Z]."**

| Structure | Description | Best For |
|-----------|-------------|----------|
| **Outsized Refund** | 2x or 3x money back, conditional on completing the work | High confidence, high-ticket |
| **Service Guarantee** | Continue working free until result achieved | Consulting, agency |
| **Extended Access** | Grant 2x+ original duration free of charge | Membership, course |
| **Credit-Based** | Refund as credit toward other offers | Ecosystem businesses |
| **Personal Service** | Switch to 1-on-1 free until result achieved | Group → personal escalation |
| **Expense Coverage** | Reimburse hotel, airfare, or ancillary costs | Events, in-person |
| **Wage-Payment** | Pay their hourly rate for time spent if no value | Workshops, seminars |
| **Contract Release** | Cancel contract free if value stops | Retainers, subscriptions |
| **Delayed Payment** | Pause 2nd payment until first outcome reached | Payment plans |
| **First Outcome Coverage** | Cover ancillary costs until first win | Coaching, programs |

**Anti-Guarantee** (frames finality as a feature, not a bug):

| Structure | Description | Best For |
|-----------|-------------|----------|
| **All Sales Final** | Explicit no-refund with creative reasoning | IP-heavy, proprietary, ultra-premium |

Script: *"We're exposing the inner workings of our business. As a result, all sales are final. If you need a guarantee before taking a jump, you're not the type of person we want to work with."*

**Implied/Performance Guarantees** (no explicit refund — seller doesn't get paid unless they perform):

| Structure | Description |
|-----------|-------------|
| Performance | Pay $X per sale, show, or milestone |
| Revenue-Share | Pay X% of revenue or revenue growth |
| Profit-Share | Pay X% of profit |
| Ratchets | Tiered: 10% if >X, 20% if >Y, 30% if >Z |
| Bonuses/Triggers | Pay X when Y event occurs |

**Selection guidance:**

| Scenario | Recommended Type |
|----------|-----------------|
| Low-ticket B2C | Unconditional (friction deters abuse) |
| Mid-ticket B2C/B2B | Conditional with specific outcomes |
| High-ticket B2B | Conditional, performance-based, or anti-guarantee |
| IP/proprietary | Anti-guarantee with creative framing |
| Consulting/agency | Service guarantee or performance partnership |
| Commoditized market | Bold named unconditional to differentiate |

### Step 3: Write the Guarantee Statement

Use the conditional formula:

```text
"If you do not get [X result] in [Y time period], we will [Z]."
```

Then apply the **"Better Than Money Back"** test: Does the guarantee address non-financial costs too?

| Non-Financial Cost | How to Reverse |
|--------------------|----------------|
| Time invested | Pay their hourly rate, cover opportunity cost |
| Emotional investment | Personal service escalation |
| Outside expenses | Reimburse travel, materials, tools |
| Opportunity cost | Cover cost of switching to competitor |

### Step 4: Name the Guarantee

A named guarantee transforms generic "satisfaction guaranteed" into a **memorable, branded commitment**.

**Why naming matters:**

- "30-day money-back guarantee" is invisible — every competitor says it
- "The Club a Baby Seal Guarantee" stops you in your tracks
- Creative naming signals confidence (you rarely have to honor it)
- Named guarantees become talkable — customers tell friends

**Named Guarantee Examples:**

| Name | What It Is | Why It Works |
|------|-----------|--------------|
| **"Club a Baby Seal Guarantee"** | 30-day unconditional | *"If you wouldn't club a baby seal to stay on as a customer, you don't pay a penny."* Shocking imagery = unforgettable |
| **"Shark Infested Waters Guarantee"** | 30-day unconditional | *"If you wouldn't jump into shark infested waters to get our product back, full refund."* Extreme imagery = extreme confidence |
| **"Triple Your Money Back"** | 3x conditional refund | Boldness signals certainty. Conditional on completing the work (self-fulfilling) |
| **"The No-Hostage Guarantee"** | Contract release | Directly attacks "feeling trapped" fear. Name tells the whole story |
| **"Love It or Leave It"** | Unconditional satisfaction | Clean, simple, zero-risk trial |

**Guarantee Naming Process:**

1. Take the prospect's **#1 fear** from Step 1
2. **Reverse it** into a vivid mental image — the more unexpected, the better
3. Combine with the MAGIC formula adapted for guarantees:

| Element | Role | Example |
|---------|------|---------|
| **Vivid Image** | Attention hook | "Club a Baby Seal", "Shark Infested Waters" |
| **Guaranteed Result** | The promise | "20 Clients", "Triple Your Money" |
| **Timeframe** | The window | "30-Day", "90-Day" |
| **Container Word** | Category | "Guarantee", "Promise", "Pact", "Pledge" |

Formula: **[Vivid Image or Anti-Fear] + [Result/Timeframe] + [Container]**

Generate **3 name options**. User chooses. The name should:

- Sound absurd in a competitor's marketing
- Create an instant mental picture
- Be easy to remember and repeat
- Imply extreme confidence

### Step 5: Categorize — Always-On vs Proposal

Not all guarantees belong on the website. Categorize each:

| Category | Visibility | Purpose | Examples |
|----------|------------|---------|----------|
| **Always-On** | Website, landing pages, ads, all marketing | Broad risk reversal for inbound leads. Must be defensible at scale. | "30-Day No Questions Asked", "Love It or Leave It" |
| **Proposal** | Sales conversations, contracts, proposals only | Targeted risk reversal for specific deal contexts. Can be bolder because it's 1:1. | "Triple Your Money Back" (conditional), Performance guarantees, contract releases |

**Rule of thumb:**

- Unconditional guarantees → usually **always-on** (simple, scalable)
- Conditional guarantees → can be **either** (depends on complexity of terms)
- Anti-guarantees → usually **always-on** (brand positioning)
- Performance/implied → usually **proposal** (deal-specific)
- Outsized refunds → usually **proposal** (too risky to broadcast broadly without qualification)

### Step 6: Consider Stacking

Combine multiple guarantees for maximum risk reversal:

**Pattern 1: Unconditional + Conditional**

```text
Layer 1: 30-day no-questions-asked refund (always-on, safety net)
Layer 2: 90-day triple-your-money-back if you complete the program and don't hit [result] (proposal)
```

Short-term safety + long-term boldness.

**Pattern 2: Sequential Milestones**

```text
Layer 1: "You'll hit [milestone 1] by day 30"
Layer 2: "You'll hit [milestone 2] by day 60"
Condition: "As long as you complete steps 1, 2, and 3"
```

Future-paces the prospect through specific outcomes.

**Pattern 3: Multi-Dimension**

```text
Layer 1: Results guarantee (financial risk)
Layer 2: Service guarantee (quality risk)
Layer 3: Convenience guarantee (time/effort risk)
```

Each layer addresses a different fear from Step 1.

### Common Mistakes to Flag

If the user's guarantee falls into these traps, call it out directly:

1. **No guarantee at all** — silence leaves risk on the customer. Even an anti-guarantee is better.
2. **Weak generic language** — "satisfaction guaranteed" is invisible. Name it.
3. **Unconditional on high-ticket + high fulfillment cost** — you eat refund AND fulfillment cost. Use conditional instead.
4. **Not tying conditions to success actions** — conditions should require the steps that produce results. If they do the work, they get results. Self-fulfilling guarantee.
5. **Treating the guarantee as an afterthought** — Hormozi says spend as much creative energy on the guarantee as the deliverables.
6. **Not stating it boldly** — present with conviction, not apologetically. Script the delivery.

---

## Changes to Other Sections

### Quick Reference (line 776)

Update from:

```
Guarantee Stack: Unconditional + Conditional = Maximum risk reversal
```

To:

```
Guarantee Stack: Map fears → Choose type → Name it (vivid image + result + container) → Always-on or Proposal → Stack layers
```

### Adversarial Review Prompts

Add to the **Skeptical Marketer** prompt (line 700):
> Is the guarantee **named** memorably or generic? Does the name attack the buyer's #1 fear? Would the name work in an ad headline?

Add to the **Customer Persona(s)** prompt (line 706):
> Does the guarantee name make you feel safe? Does it address your **specific** fear, not just "money back"? Would you tell a friend about this guarantee?

### Research Brief Gap Analysis (line 156)

Expand from:

```
- Guarantee norms: [what competitors guarantee, refund rate benchmarks]
```

To:

```
- Guarantee norms: [what competitors guarantee, refund rate benchmarks]
- Guarantee naming landscape: [competitor guarantee names, creative naming patterns in this market]
- Prospect fear mapping: [top fears beyond financial loss — time, embarrassment, opportunity cost]
```

### Phase 5 Gap Check

Add to the gap check that runs before Phase 5:

```
- Prospect fear inventory: [OK/GAP]
- Guarantee naming landscape: [OK/GAP]
- Competitor guarantee comparison: [OK/GAP]
```

---

## HTML Template Changes

### Offer Summary — Expanded Guarantee Card

The current Enhancement section has three equal cards (Scarcity, Urgency, Guarantee) with just `{{GUARANTEE_TEXT}}`. With named guarantees producing richer data, expand the Guarantee card to show:

```html
<div class="enhancement-card guarantee-card">
    <h3>Guarantee</h3>
    <div class="guarantee-name">{{GUARANTEE_NAME}}</div>
    <div class="guarantee-type-badge {{GUARANTEE_TYPE_CLASS}}">{{GUARANTEE_TYPE}}</div>
    <p class="guarantee-description">{{GUARANTEE_DESCRIPTION}}</p>
    <div class="guarantee-meta">
        <span class="guarantee-visibility {{VISIBILITY_CLASS}}">{{ALWAYS_ON_OR_PROPOSAL}}</span>
        <span class="guarantee-fear">Addresses: {{TARGET_FEAR}}</span>
    </div>
    <!-- If stacked, show layers -->
    <div class="guarantee-stack" data-if="stacked">
        <div class="stack-layer">Layer 1: {{LAYER_1}}</div>
        <div class="stack-layer">Layer 2: {{LAYER_2}}</div>
    </div>
</div>
```

Styling additions:

- `.guarantee-name`: `font-size: 1.5rem; font-weight: 800; color: #fff; margin-bottom: 0.5rem`
- `.guarantee-type-badge`: `display: inline-block; padding: 0.25rem 0.75rem; border-radius: 12px; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px`
- `.guarantee-type-badge.unconditional`: `background: rgba(34,197,94,0.15); color: #22c55e`
- `.guarantee-type-badge.conditional`: `background: rgba(74,158,255,0.15); color: #4a9eff`
- `.guarantee-type-badge.anti`: `background: rgba(239,68,68,0.15); color: #ef4444`
- `.guarantee-type-badge.performance`: `background: rgba(234,179,8,0.15); color: #eab308`
- `.guarantee-visibility`: `font-size: 0.8rem; padding: 0.2rem 0.6rem; border-radius: 4px`
- `.guarantee-visibility.always-on`: `background: rgba(34,197,94,0.1); color: #22c55e; border: 1px solid rgba(34,197,94,0.3)`
- `.guarantee-visibility.proposal`: `background: rgba(234,179,8,0.1); color: #eab308; border: 1px solid rgba(234,179,8,0.3)`
- `.guarantee-fear`: `font-size: 0.8rem; color: #888`
- `.guarantee-stack`: `margin-top: 0.75rem; border-top: 1px solid #2a2a2a; padding-top: 0.75rem`
- `.stack-layer`: `font-size: 0.85rem; color: #c0c0c0; padding: 0.25rem 0; border-left: 2px solid #4a9eff; padding-left: 0.75rem; margin-bottom: 0.5rem`

The guarantee card should be allowed to span wider than the other two cards when the data warrants it. Consider making the Enhancement grid `grid-template-columns: 1fr 1fr 1.5fr` when guarantee data is rich.

### Cross-Page Navigation (all three templates)

**Bug found**: The offer-summary page has no navigation to other pages. The workshop-progress has a link to offer-summary but not to research-dashboard. The research-dashboard has no outbound links.

Add a consistent navigation bar to **all three HTML template specs**:

```html
<nav class="page-nav">
    <a href="./{{PROJECT}}-offer-summary.html" class="nav-link {{ACTIVE_IF_SUMMARY}}">Offer Summary</a>
    <a href="./{{PROJECT}}-workshop-progress.html" class="nav-link {{ACTIVE_IF_PROGRESS}}">Workshop Progress</a>
    <a href="./{{PROJECT}}-research-dashboard.html" class="nav-link {{ACTIVE_IF_RESEARCH}}">Research Dashboard</a>
</nav>
```

Styling:

- `.page-nav`: `display: flex; gap: 0.5rem; justify-content: center; padding: 1rem 0; margin-bottom: 2rem; border-bottom: 1px solid #2a2a2a`
- `.nav-link`: `color: #888; text-decoration: none; padding: 0.5rem 1rem; border-radius: 6px; font-size: 0.85rem; font-weight: 500; transition: all 0.2s`
- `.nav-link:hover`: `color: #4a9eff; background: rgba(74,158,255,0.1)`
- `.nav-link.active`: `color: #4a9eff; background: rgba(74,158,255,0.15); font-weight: 700`

Place the nav **inside `<header>`, before the badge/title**, so it appears at the top of every page.

---

## Implementation Notes

- **No new files needed** — this is a depth expansion of existing Phase 5 content
- **No phase flow changes** — guarantees remain in Phase 5 Enhancement, same position
- **Backward compatible** — workshops in progress will simply see richer guidance at Phase 5
- The named guarantee examples (Club a Baby Seal, etc.) come directly from Hormozi's $100M Offers Chapter 15
- The "always-on vs proposal" distinction is not Hormozi's terminology but is a practical categorization for deployment — the issue specifically requests it
- The 6-step process (Map Fears → Choose Type → Write Statement → Name It → Categorize → Stack) follows the repo-clone pattern of structured, citation-backed guidance
- **HTML template changes**: Expanded guarantee card in offer-summary + cross-page navigation in all three templates
- **Cross-page nav** is a separate UX fix bundled here because it was discovered during this investigation
