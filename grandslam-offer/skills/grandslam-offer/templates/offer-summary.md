# Template: Offer Summary

## When to Generate

- **Trigger:** After Phase 5 completes and the final offer passes adversarial review
- **Updates:** Regenerate if offer is revised after additional feedback
- **On request:** When user asks to "show offer summary" or "generate final offer page"

## Data Sources

- Primary: `{project-name}-offer.md` — complete offer structure, pricing, scores, agent evaluations
- Extract:
  - Offer name (MAGIC-named) and elevator pitch
  - Value equation scores (Dream Outcome, Perceived Likelihood, Time Delay, Effort & Sacrifice)
  - The Stack: core offer + all bonuses with names, descriptions, and dollar values
  - Total stack value, actual price, savings percentage
  - Enhancement elements: scarcity, urgency, and guarantee details (guarantee name, type, terms, always-on vs proposal category, target fear, stacking layers)
  - Agent scores (Marketer, Strategist, each persona) with feedback
  - Overall consensus score and verdict
  - Next steps recommendations

## HTML Structure

Generate a single self-contained HTML file. All CSS and JS inline. No external dependencies.

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Grand Slam Offer — {{OFFER_NAME}}</title>
    <style>/* All CSS inline — see Styling section */</style>
</head>
<body>
    <header>
        <nav class="page-nav">
            <a href="./{{PROJECT_NAME}}-offer-summary.html" class="nav-link active">Offer Summary</a>
            <a href="./{{PROJECT_NAME}}-workshop-progress.html" class="nav-link">Workshop Progress</a>
            <a href="./{{PROJECT_NAME}}-research-dashboard.html" class="nav-link">Research Dashboard</a>
        </nav>
        <div class="offer-badge">Grand Slam Offer</div>
        <h1>{{OFFER_NAME}}</h1>
        <p class="elevator-pitch">{{ELEVATOR_PITCH}}</p>
        <button class="export-btn" onclick="exportOffer()">Export Offer</button>
    </header>

    <main>
        <!-- Section 1: Value Equation + Stack (side by side) -->
        <section class="offer-core">
            <div class="value-equation">
                <h2>Value Equation</h2>
                <div class="equation-bars">
                    <!-- Maximize variables (green bars) -->
                    <div class="equation-item">
                        <div class="equation-label">
                            <span class="equation-name">Dream Outcome</span>
                            <span class="equation-score">{{DREAM_SCORE}}/10</span>
                        </div>
                        <div class="equation-bar positive">
                            <div class="equation-fill" style="width: {{DREAM_SCORE}}0%"></div>
                        </div>
                    </div>
                    <div class="equation-item">
                        <div class="equation-label">
                            <span class="equation-name">Perceived Likelihood</span>
                            <span class="equation-score">{{LIKELIHOOD_SCORE}}/10</span>
                        </div>
                        <div class="equation-bar positive">
                            <div class="equation-fill" style="width: {{LIKELIHOOD_SCORE}}0%"></div>
                        </div>
                    </div>
                    <!-- Minimize variables (red bars, lower = better) -->
                    <div class="equation-item">
                        <div class="equation-label">
                            <span class="equation-name">Time Delay</span>
                            <span class="equation-score">{{TIME_SCORE}}/10</span>
                        </div>
                        <div class="equation-bar negative">
                            <div class="equation-fill" style="width: {{TIME_SCORE}}0%"></div>
                        </div>
                        <span class="equation-note">Lower is better</span>
                    </div>
                    <div class="equation-item">
                        <div class="equation-label">
                            <span class="equation-name">Effort & Sacrifice</span>
                            <span class="equation-score">{{EFFORT_SCORE}}/10</span>
                        </div>
                        <div class="equation-bar negative">
                            <div class="equation-fill" style="width: {{EFFORT_SCORE}}0%"></div>
                        </div>
                        <span class="equation-note">Lower is better</span>
                    </div>
                </div>
            </div>

            <div class="stack">
                <h2>The Stack</h2>
                <div class="stack-items">
                    <div class="stack-item core">
                        <div class="stack-header">
                            <span class="stack-label">Core Offer</span>
                        </div>
                        <p class="stack-description">{{CORE_OFFER_DESCRIPTION}}</p>
                    </div>
                    <!-- Repeat for each bonus -->
                    <div class="stack-item bonus">
                        <div class="stack-header">
                            <span class="stack-label">Bonus {{INDEX}}: {{BONUS_NAME}}</span>
                            <span class="stack-value">${{BONUS_VALUE}} value</span>
                        </div>
                        <p class="stack-description">{{BONUS_DESCRIPTION}}</p>
                    </div>
                </div>
                <div class="stack-summary">
                    <div class="summary-row total">
                        <span>Total Value</span>
                        <span class="summary-value">${{TOTAL_VALUE}}</span>
                    </div>
                    <div class="summary-row price">
                        <span>Your Price</span>
                        <span class="summary-value price-highlight">${{PRICE}}</span>
                    </div>
                    <div class="summary-row savings">
                        <span>You Save</span>
                        <span class="summary-value savings-highlight">{{SAVINGS_PERCENT}}%</span>
                    </div>
                </div>
            </div>
        </section>

        <!-- Section 2: Enhancement Elements -->
        <section class="enhancement">
            <h2>Enhancement</h2>
            <div class="enhancement-grid">
                <div class="enhancement-card">
                    <h3>Scarcity</h3>
                    <p>{{SCARCITY_TEXT}}</p>
                </div>
                <div class="enhancement-card">
                    <h3>Urgency</h3>
                    <p>{{URGENCY_TEXT}}</p>
                </div>
                <div class="enhancement-card guarantee-card">
                    <h3>Guarantee</h3>
                    <div class="guarantee-name">{{GUARANTEE_NAME}}</div>
                    <div class="guarantee-type-badge {{GUARANTEE_TYPE_CLASS}}">{{GUARANTEE_TYPE}}</div>
                    <p>{{GUARANTEE_DESCRIPTION}}</p>
                    <div class="guarantee-meta">
                        <span class="guarantee-visibility {{VISIBILITY_CLASS}}">{{ALWAYS_ON_OR_PROPOSAL}}</span>
                        <span class="guarantee-fear">Addresses: {{TARGET_FEAR}}</span>
                    </div>
                    <!-- If stacked, show layers -->
                    <div class="guarantee-stack">
                        <!-- Repeat for each layer -->
                        <div class="guarantee-layer">{{LAYER_DESCRIPTION}}</div>
                    </div>
                </div>
            </div>
        </section>

        <!-- Section 3: Agent Scores -->
        <section class="agent-scores">
            <h2>Agent Validation</h2>
            <div class="scores-grid">
                <div class="score-card">
                    <div class="score-content">
                        <span class="score-label">Marketer</span>
                        <span class="score-value">{{MARKETER_SCORE}}/10</span>
                    </div>
                    <details class="score-details">
                        <summary>View Feedback</summary>
                        <p>{{MARKETER_FEEDBACK}}</p>
                    </details>
                </div>
                <div class="score-card">
                    <div class="score-content">
                        <span class="score-label">Strategist</span>
                        <span class="score-value">{{STRATEGIST_SCORE}}/10</span>
                    </div>
                    <details class="score-details">
                        <summary>View Feedback</summary>
                        <p>{{STRATEGIST_FEEDBACK}}</p>
                    </details>
                </div>
                <!-- Repeat for each persona -->
                <div class="score-card">
                    <div class="score-content">
                        <span class="score-label">{{PERSONA_NAME}}</span>
                        <span class="score-value">{{PERSONA_SCORE}}/10</span>
                    </div>
                    <details class="score-details">
                        <summary>View Feedback</summary>
                        <p>{{PERSONA_FEEDBACK}}</p>
                    </details>
                </div>
            </div>
            <div class="overall-score">
                <span class="overall-label">Overall Consensus</span>
                <span class="overall-value {{OVERALL_CLASS}}">{{OVERALL_SCORE}}/10</span>
                <p class="overall-verdict">{{OVERALL_VERDICT}}</p>
            </div>
        </section>

        <!-- Section 4: Next Steps -->
        <section class="next-steps">
            <h2>Next Steps</h2>
            <div class="steps-list">
                <div class="step-item">
                    <input type="checkbox" id="step1">
                    <label for="step1">Build high-converting landing page</label>
                </div>
                <div class="step-item">
                    <input type="checkbox" id="step2">
                    <label for="step2">Create lead magnet (run $100M Leads workshop)</label>
                </div>
                <div class="step-item">
                    <input type="checkbox" id="step3">
                    <label for="step3">Write sales script and objection handlers</label>
                </div>
                <div class="step-item">
                    <input type="checkbox" id="step4">
                    <label for="step4">Test offer with small audience segment</label>
                </div>
                <div class="step-item">
                    <input type="checkbox" id="step5">
                    <label for="step5">Set up analytics and conversion tracking</label>
                </div>
            </div>
        </section>
    </main>

    <footer>
        <p>Generated by Grand Slam Offer Workshop | {{TIMESTAMP}}</p>
    </footer>

    <script>/* All JS inline — see Behavior section */</script>
</body>
</html>
```

## Styling

Apply these CSS rules inline in the `<style>` tag:

**Base:**

- `body`: `background: #0a0a0a; color: #e0e0e0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; line-height: 1.6; padding: 2rem; max-width: 1400px; margin: 0 auto`
- `header`: `text-align: center; border-bottom: 2px solid #2a2a2a; padding-bottom: 2rem; margin-bottom: 3rem`
- `.page-nav`: `display: flex; gap: 0.5rem; justify-content: center; padding: 1rem 0; margin-bottom: 2rem; border-bottom: 1px solid #2a2a2a`
- `.nav-link`: `color: #888; text-decoration: none; padding: 0.5rem 1rem; border-radius: 6px; font-size: 0.85rem; font-weight: 500; transition: all 0.2s`
- `.nav-link:hover`: `color: #4a9eff; background: rgba(74,158,255,0.1)`
- `.nav-link.active`: `color: #4a9eff; background: rgba(74,158,255,0.15); font-weight: 700`
- `.offer-badge`: `display: inline-block; background: linear-gradient(135deg, #4a9eff, #7b5cff); color: #fff; padding: 0.5rem 1.25rem; border-radius: 20px; font-size: 0.85rem; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 1rem`
- `h1`: `font-size: 3rem; font-weight: 800; color: #fff; margin-bottom: 1rem; line-height: 1.2`
- `.elevator-pitch`: `font-size: 1.25rem; color: #c0c0c0; max-width: 800px; margin: 0 auto 1.5rem; line-height: 1.8`
- `h2`: `font-size: 1.75rem; font-weight: 700; color: #fff; border-left: 4px solid #4a9eff; padding-left: 1rem; margin-bottom: 1.5rem`
- `.export-btn`: `background: transparent; color: #4a9eff; border: 2px solid #4a9eff; padding: 0.75rem 1.5rem; border-radius: 6px; font-weight: 600; cursor: pointer; transition: all 0.2s`
- `.export-btn:hover`: `background: #4a9eff; color: #0a0a0a`

**Offer Core (two-column layout):**

- `.offer-core`: `display: grid; grid-template-columns: 1fr 1fr; gap: 2rem`
- `.value-equation, .stack`: `background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 8px; padding: 2rem`

**Value Equation bars:**

- `.equation-bars`: `display: flex; flex-direction: column; gap: 1.5rem`
- `.equation-label`: `display: flex; justify-content: space-between; align-items: center`
- `.equation-name`: `font-weight: 600; color: #e0e0e0`
- `.equation-score`: `font-family: monospace; font-size: 1.1rem; font-weight: 700; color: #4a9eff`
- `.equation-bar`: `height: 12px; background: #2a2a2a; border-radius: 6px; overflow: hidden`
- `.equation-bar.positive .equation-fill`: `background: linear-gradient(90deg, #22c55e, #4ade80)`
- `.equation-bar.negative .equation-fill`: `background: linear-gradient(90deg, #ef4444, #f87171)`
- `.equation-note`: `font-size: 0.75rem; color: #888; font-style: italic`

**Stack:**

- `.stack-items`: `display: flex; flex-direction: column; gap: 1rem; margin-bottom: 1.5rem`
- `.stack-item`: `background: #0a0a0a; border-radius: 6px; padding: 1.25rem; border-left: 3px solid #4a9eff`
- `.stack-item.core`: `border-left-color: #7b5cff; background: rgba(123,92,255,0.05)`
- `.stack-header`: `display: flex; justify-content: space-between; align-items: center; margin-bottom: 0.75rem`
- `.stack-label`: `font-weight: 700; color: #fff`
- `.stack-value`: `font-family: monospace; font-weight: 700; color: #22c55e; font-size: 1.1rem`
- `.stack-summary`: `border-top: 2px solid #2a2a2a; padding-top: 1.5rem`
- `.summary-row.total .summary-value`: `color: #888; text-decoration: line-through`
- `.summary-row.price .summary-value`: `color: #4a9eff; font-size: 1.75rem; font-family: monospace; font-weight: 700`
- `.summary-row.savings .summary-value`: `color: #22c55e; font-family: monospace`

**Enhancement:**

- `.enhancement-grid`: `display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 1.5rem`
- `.enhancement-card`: `background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 8px; padding: 1.5rem; transition: border-color 0.2s`
- `.enhancement-card:hover`: `border-color: #4a9eff`
- `.enhancement-card h3`: `font-size: 1.1rem; color: #4a9eff; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 0.75rem`
- `.guarantee-card`: `grid-column: span 1` (allow wider when data is rich — agent may span full width)
- `.guarantee-name`: `font-size: 1.5rem; font-weight: 800; color: #fff; margin-bottom: 0.5rem`
- `.guarantee-type-badge`: `display: inline-block; padding: 0.25rem 0.75rem; border-radius: 12px; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 0.75rem`
- `.guarantee-type-badge.unconditional`: `background: rgba(34,197,94,0.15); color: #22c55e`
- `.guarantee-type-badge.conditional`: `background: rgba(74,158,255,0.15); color: #4a9eff`
- `.guarantee-type-badge.anti`: `background: rgba(239,68,68,0.15); color: #ef4444`
- `.guarantee-type-badge.performance`: `background: rgba(234,179,8,0.15); color: #eab308`
- `.guarantee-meta`: `display: flex; gap: 1rem; align-items: center; margin-top: 0.75rem; flex-wrap: wrap`
- `.guarantee-visibility`: `font-size: 0.8rem; padding: 0.2rem 0.6rem; border-radius: 4px`
- `.guarantee-visibility.always-on`: `background: rgba(34,197,94,0.1); color: #22c55e; border: 1px solid rgba(34,197,94,0.3)`
- `.guarantee-visibility.proposal`: `background: rgba(234,179,8,0.1); color: #eab308; border: 1px solid rgba(234,179,8,0.3)`
- `.guarantee-fear`: `font-size: 0.8rem; color: #888`
- `.guarantee-stack`: `margin-top: 0.75rem; border-top: 1px solid #2a2a2a; padding-top: 0.75rem`
- `.guarantee-layer`: `font-size: 0.85rem; color: #c0c0c0; padding: 0.25rem 0; border-left: 2px solid #4a9eff; padding-left: 0.75rem; margin-bottom: 0.5rem`

**Agent Scores:**

- `.scores-grid`: `display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1.5rem; margin-bottom: 2rem`
- `.score-card`: `background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 8px; padding: 1.5rem`
- `.score-content`: `display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem`
- `.score-value`: `font-family: monospace; font-size: 1.25rem; font-weight: 700; color: #4a9eff`
- `.score-details summary`: `cursor: pointer; color: #888; font-size: 0.85rem`
- `.overall-score`: `background: linear-gradient(135deg, #1a1a1a, #2a2a2a); border: 2px solid #4a9eff; border-radius: 8px; padding: 2rem; text-align: center`
- `.overall-value`: `display: block; font-family: monospace; font-size: 3rem; font-weight: 800; margin-bottom: 0.75rem`
- `.overall-value.excellent`: `color: #22c55e` (8+/10)
- `.overall-value.good`: `color: #4a9eff` (6-7/10)
- `.overall-value.needs-work`: `color: #eab308` (<6/10)

**Next Steps:**

- `.step-item`: `background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 6px; padding: 1.25rem; display: flex; align-items: center; gap: 1rem`
- `.step-item input[type="checkbox"]`: `width: 20px; height: 20px; accent-color: #4a9eff`
- `.step-item input:checked + label`: `color: #888; text-decoration: line-through`

**Responsive:**

- `@media (max-width: 1024px)`: `.offer-core` to single column
- `@media (max-width: 768px)`: reduce body padding, h1 size, single column grids

## Behavior

```javascript
// Export offer as formatted text to clipboard
function exportOffer() {
    const h1 = document.querySelector('h1');
    const pitchEl = document.querySelector('.elevator-pitch');
    if (!h1 || !pitchEl) return;

    let output = `GRAND SLAM OFFER\n${'='.repeat(60)}\n\n`;
    output += `${h1.textContent}\n\n${pitchEl.textContent}\n\n${'='.repeat(60)}\n\n`;

    // Value Equation
    output += 'VALUE EQUATION\n';
    document.querySelectorAll('.equation-item').forEach(eq => {
        const name = eq.querySelector('.equation-name');
        const score = eq.querySelector('.equation-score');
        if (name && score) output += `${name.textContent}: ${score.textContent}\n`;
    });

    // Stack
    output += `\n${'='.repeat(60)}\nTHE STACK\n\n`;
    document.querySelectorAll('.stack-item').forEach(item => {
        const label = item.querySelector('.stack-label');
        const desc = item.querySelector('.stack-description');
        if (!label || !desc) return;
        const value = item.querySelector('.stack-value');
        output += `${label.textContent}${value ? ` — ${value.textContent}` : ''}\n${desc.textContent}\n\n`;
    });

    // Summary
    document.querySelectorAll('.summary-row').forEach(row => {
        const spans = row.querySelectorAll('span');
        if (spans.length >= 2) output += `${spans[0].textContent}: ${spans[1].textContent}\n`;
    });

    // Enhancement
    output += `\n${'='.repeat(60)}\nENHANCEMENT\n\n`;
    document.querySelectorAll('.enhancement-card').forEach(card => {
        const h3 = card.querySelector('h3');
        if (!h3) return;

        if (card.classList.contains('guarantee-card')) {
            const name = card.querySelector('.guarantee-name');
            const type = card.querySelector('.guarantee-type-badge');
            const desc = card.querySelector('p');
            const vis = card.querySelector('.guarantee-visibility');
            const fear = card.querySelector('.guarantee-fear');
            output += `${h3.textContent}:\n`;
            if (name) output += `Name: ${name.textContent}\n`;
            if (type) output += `Type: ${type.textContent}\n`;
            if (desc) output += `${desc.textContent}\n`;
            if (vis) output += `Category: ${vis.textContent}\n`;
            if (fear) output += `${fear.textContent}\n`;
            const layers = card.querySelectorAll('.guarantee-layer');
            if (layers.length > 0) {
                output += 'Stack:\n';
                layers.forEach(l => { output += `  - ${l.textContent}\n`; });
            }
            output += '\n';
        } else {
            const p = card.querySelector('p');
            if (p) output += `${h3.textContent}:\n${p.textContent}\n\n`;
        }
    });

    // Agent Scores
    output += `${'='.repeat(60)}\nAGENT VALIDATION\n\n`;
    document.querySelectorAll('.score-card').forEach(card => {
        const label = card.querySelector('.score-label');
        const val = card.querySelector('.score-value');
        if (label && val) output += `${label.textContent}: ${val.textContent}\n`;
    });
    const overallVal = document.querySelector('.overall-value');
    const overallVerdict = document.querySelector('.overall-verdict');
    if (overallVal) output += `\nOVERALL: ${overallVal.textContent}\n`;
    if (overallVerdict) output += `${overallVerdict.textContent}\n`;

    const btn = document.querySelector('.export-btn');
    const resetBtn = (text, bg, border) => {
        if (!btn) return;
        const original = btn.textContent;
        btn.textContent = text;
        btn.style.backgroundColor = bg;
        btn.style.color = '#0a0a0a';
        btn.style.borderColor = border;
        setTimeout(() => {
            btn.textContent = original;
            btn.style.backgroundColor = 'transparent';
            btn.style.color = '#4a9eff';
            btn.style.borderColor = '#4a9eff';
        }, 2000);
    };

    navigator.clipboard.writeText(output).then(() => {
        resetBtn('Exported!', '#22c55e', '#22c55e');
    }).catch(() => {
        resetBtn('Export failed', '#ef4444', '#ef4444');
    });
}

// Animate value bars on load
document.addEventListener('DOMContentLoaded', () => {
    const fills = document.querySelectorAll('.equation-fill');
    fills.forEach(fill => {
        const width = fill.style.width;
        fill.style.width = '0%';
        setTimeout(() => { fill.style.width = width; }, 100);
    });
});

// Persist checkbox state in localStorage
document.querySelectorAll('.step-item input[type="checkbox"]').forEach(cb => {
    const key = `offer-step-${cb.id}`;
    try {
        if (localStorage.getItem(key) === 'true') cb.checked = true;
        cb.addEventListener('change', () => localStorage.setItem(key, cb.checked));
    } catch (_) {
        // Storage may be unavailable in restricted environments; proceed without persistence
    }
});
```
