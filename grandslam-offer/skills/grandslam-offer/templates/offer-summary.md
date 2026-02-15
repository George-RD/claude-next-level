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
  - Enhancement elements (scarcity, urgency, guarantee details)
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
                <div class="enhancement-card">
                    <h3>Guarantee</h3>
                    <p>{{GUARANTEE_TEXT}}</p>
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
    const offerName = document.querySelector('h1').textContent;
    const pitch = document.querySelector('.elevator-pitch').textContent;

    let output = `GRAND SLAM OFFER\n${'='.repeat(60)}\n\n`;
    output += `${offerName}\n\n${pitch}\n\n${'='.repeat(60)}\n\n`;

    // Value Equation
    output += 'VALUE EQUATION\n';
    document.querySelectorAll('.equation-item').forEach(eq => {
        output += `${eq.querySelector('.equation-name').textContent}: ${eq.querySelector('.equation-score').textContent}\n`;
    });

    // Stack
    output += `\n${'='.repeat(60)}\nTHE STACK\n\n`;
    document.querySelectorAll('.stack-item').forEach(item => {
        const label = item.querySelector('.stack-label').textContent;
        const desc = item.querySelector('.stack-description').textContent;
        const value = item.querySelector('.stack-value');
        output += `${label}${value ? ` — ${value.textContent}` : ''}\n${desc}\n\n`;
    });

    // Summary
    document.querySelectorAll('.summary-row').forEach(row => {
        const spans = row.querySelectorAll('span');
        output += `${spans[0].textContent}: ${spans[1].textContent}\n`;
    });

    // Enhancement
    output += `\n${'='.repeat(60)}\nENHANCEMENT\n\n`;
    document.querySelectorAll('.enhancement-card').forEach(card => {
        output += `${card.querySelector('h3').textContent}:\n${card.querySelector('p').textContent}\n\n`;
    });

    // Agent Scores
    output += `${'='.repeat(60)}\nAGENT VALIDATION\n\n`;
    document.querySelectorAll('.score-card').forEach(card => {
        output += `${card.querySelector('.score-label').textContent}: ${card.querySelector('.score-value').textContent}\n`;
    });
    output += `\nOVERALL: ${document.querySelector('.overall-value').textContent}\n`;
    output += `${document.querySelector('.overall-verdict').textContent}\n`;

    navigator.clipboard.writeText(output).then(() => {
        const btn = document.querySelector('.export-btn');
        const original = btn.textContent;
        btn.textContent = 'Exported!';
        btn.style.backgroundColor = '#22c55e';
        btn.style.color = '#0a0a0a';
        btn.style.borderColor = '#22c55e';
        setTimeout(() => {
            btn.textContent = original;
            btn.style.backgroundColor = 'transparent';
            btn.style.color = '#4a9eff';
            btn.style.borderColor = '#4a9eff';
        }, 2000);
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
    if (localStorage.getItem(key) === 'true') cb.checked = true;
    cb.addEventListener('change', () => localStorage.setItem(key, cb.checked));
});
```
