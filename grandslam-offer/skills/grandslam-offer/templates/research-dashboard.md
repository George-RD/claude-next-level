# Template: Research Dashboard

## When to Generate

- **Initial generation:** After Phase 0 completes and `{project-name}-research.md` is created
- **Updates:** After each subsequent phase (1-5) as research evolves and new findings are added
- **On request:** When user asks to "show research dashboard" or "update research view"

## Data Sources

- Primary: `{project-name}-research.md` — all research findings, personas, market analysis, and sources
- Extract:
  - Business name and industry
  - Market Identity section (core market, niche, audience)
  - Starving Crowd Indicators with score
  - Value Equation Inputs
  - Offer Landscape data
  - Enhancement Data
  - All persona profiles with pain scores, budgets, and buying triggers
  - Gap analysis status (green/yellow/red) for each phase requirement
  - Sources with URLs and evidence snippets

## HTML Structure

Generate a single self-contained HTML file. All CSS and JS inline. No external dependencies.

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Research Dashboard — {{BUSINESS_NAME}}</title>
    <style>/* All CSS inline — see Styling section */</style>
</head>
<body>
    <header>
        <h1>Research Dashboard — {{BUSINESS_NAME}}</h1>
        <p class="subtitle">{{CORE_MARKET}} | {{NICHE_DEFINITION}} | Last Updated: {{TIMESTAMP}}</p>
    </header>

    <main>
        <!-- Section 1: Market Snapshot -->
        <section class="market-snapshot">
            <h2>Market Snapshot</h2>
            <div class="snapshot-grid">
                <!-- One card per framework variable -->
                <div class="snapshot-card">
                    <h3>Pain Severity</h3>
                    <p>{{PAIN_SEVERITY_SUMMARY}}</p>
                    <span class="insight-badge">{{PAIN_SOURCE_COUNT}} sources</span>
                </div>
                <div class="snapshot-card">
                    <h3>Purchasing Power</h3>
                    <p>{{PURCHASING_POWER_SUMMARY}}</p>
                    <span class="insight-badge">{{POWER_SOURCE_COUNT}} sources</span>
                </div>
                <div class="snapshot-card">
                    <h3>Targeting Specificity</h3>
                    <p>{{TARGETING_SUMMARY}}</p>
                    <span class="insight-badge">{{TARGET_SOURCE_COUNT}} sources</span>
                </div>
                <div class="snapshot-card">
                    <h3>Market Growth</h3>
                    <p>{{GROWTH_SUMMARY}}</p>
                    <span class="insight-badge">{{GROWTH_SOURCE_COUNT}} sources</span>
                </div>
            </div>
        </section>

        <!-- Section 2: Gap Analysis Grid -->
        <section class="gap-analysis">
            <h2>Gap Analysis</h2>
            <div class="gap-grid">
                <div class="gap-header">
                    <span>Phase</span>
                    <span>Requirement</span>
                    <span>Status</span>
                </div>
                <!-- One row per requirement per phase -->
                <!-- Status classes: green, yellow, red -->
                <div class="gap-row">
                    <span class="phase-num">{{PHASE}}</span>
                    <span class="requirement">{{REQUIREMENT_TEXT}}</span>
                    <span class="status-indicator {{STATUS}}">{{STATUS_LABEL}}</span>
                </div>
                <!-- Repeat for all requirements -->
            </div>
        </section>

        <!-- Section 3: Persona Cards -->
        <section class="personas">
            <h2>Target Personas</h2>
            <div class="persona-grid">
                <!-- 2-3 persona cards side by side -->
                <div class="persona-card">
                    <h3>{{PERSONA_NAME}}</h3>
                    <p class="persona-snapshot">{{PERSONA_SNAPSHOT}}</p>
                    <div class="persona-metrics">
                        <div class="metric">
                            <span class="metric-label">Pain Level</span>
                            <div class="pain-bar">
                                <div class="pain-fill" style="width: {{PAIN_SCORE}}0%"></div>
                            </div>
                            <span class="metric-value">{{PAIN_SCORE}}/10</span>
                        </div>
                        <div class="metric">
                            <span class="metric-label">Budget Range</span>
                            <span class="metric-value budget">{{BUDGET}}</span>
                        </div>
                        <div class="metric">
                            <span class="metric-label">Buying Trigger</span>
                            <span class="metric-value">{{TRIGGER}}</span>
                        </div>
                    </div>
                    <details class="persona-details">
                        <summary>View Full Profile</summary>
                        <div class="persona-full">
                            <p><strong>Demographics:</strong> {{DEMOGRAPHICS}}</p>
                            <p><strong>Current Solution:</strong> {{CURRENT_SOLUTION}}</p>
                            <p><strong>Frustrations:</strong> {{FRUSTRATIONS}}</p>
                            <p><strong>Decision Criteria:</strong> {{DECISION_CRITERIA}}</p>
                            <!-- Phase evolution entries appended here -->
                            <p><strong>Evolution:</strong> {{PERSONA_EVOLUTION_NOTES}}</p>
                        </div>
                    </details>
                </div>
                <!-- Repeat for each persona -->
            </div>
        </section>

        <!-- Section 4: Sources & Evidence -->
        <section class="sources">
            <h2>Sources & Evidence</h2>
            <button class="copy-btn" onclick="copyResearchBrief()">Copy Research Brief</button>
            <div class="sources-list">
                <!-- One collapsible section per topic category -->
                <details class="source-category">
                    <summary>{{CATEGORY_NAME}} ({{SOURCE_COUNT}} sources)</summary>
                    <div class="source-items">
                        <div class="source-item">
                            <a href="{{URL}}" target="_blank" rel="noopener">{{TITLE}}</a>
                            <p class="evidence">{{EVIDENCE_SNIPPET}}</p>
                        </div>
                        <!-- Repeat for each source -->
                    </div>
                </details>
                <!-- Repeat for each category -->
            </div>
        </section>
    </main>

    <script>/* All JS inline — see Behavior section */</script>
</body>
</html>
```

## Styling

Apply these CSS rules inline in the `<style>` tag:

**Base:**

- `body`: `background: #0a0a0a; color: #e0e0e0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; line-height: 1.6; padding: 2rem; max-width: 1400px; margin: 0 auto`
- `h1`: `font-size: 2.5rem; font-weight: 700; color: #fff; margin-bottom: 0.5rem`
- `h2`: `font-size: 1.75rem; font-weight: 600; color: #fff; border-left: 4px solid #4a9eff; padding-left: 1rem; margin-bottom: 1.5rem`
- `section`: `margin-bottom: 3rem`
- `.subtitle`: `color: #888; font-size: 1rem`

**Market Snapshot:**

- `.snapshot-grid`: `display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1.5rem`
- `.snapshot-card`: `background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 8px; padding: 1.5rem; transition: border-color 0.2s`
- `.snapshot-card:hover`: `border-color: #4a9eff`
- `.snapshot-card h3`: `font-size: 1.1rem; color: #4a9eff; margin-bottom: 0.75rem`
- `.insight-badge`: `display: inline-block; background: #2a2a2a; color: #888; padding: 0.25rem 0.75rem; border-radius: 12px; font-size: 0.85rem; font-family: monospace`

**Gap Analysis:**

- `.gap-grid`: `background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 8px; overflow: hidden`
- `.gap-header`: `display: grid; grid-template-columns: 80px 1fr 120px; gap: 1rem; padding: 1rem 1.5rem; background: #2a2a2a; font-weight: 600; font-size: 0.9rem; text-transform: uppercase`
- `.gap-row`: `display: grid; grid-template-columns: 80px 1fr 120px; gap: 1rem; padding: 1rem 1.5rem; border-top: 1px solid #2a2a2a`
- `.phase-num`: `font-family: monospace; color: #888; font-weight: 600`
- `.status-indicator`: `text-align: center; padding: 0.25rem 0.75rem; border-radius: 4px; font-size: 0.85rem; font-weight: 600; text-transform: uppercase`
- `.status-indicator.green`: `background: rgba(34,197,94,0.2); color: #22c55e; border: 1px solid #22c55e`
- `.status-indicator.yellow`: `background: rgba(234,179,8,0.2); color: #eab308; border: 1px solid #eab308`
- `.status-indicator.red`: `background: rgba(239,68,68,0.2); color: #ef4444; border: 1px solid #ef4444`

**Persona Cards:**

- `.persona-grid`: `display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 1.5rem`
- `.persona-card`: `background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 8px; padding: 1.5rem`
- `.persona-card h3`: `font-size: 1.3rem; color: #fff; margin-bottom: 0.75rem`
- `.persona-snapshot`: `color: #c0c0c0; font-style: italic; margin-bottom: 1.5rem`
- `.pain-bar`: `width: 100%; height: 8px; background: #2a2a2a; border-radius: 4px; overflow: hidden`
- `.pain-fill`: `height: 100%; background: linear-gradient(90deg, #ef4444, #f59e0b)`
- `.metric-value`: `font-family: monospace; font-weight: 600`
- `.metric-value.budget`: `color: #22c55e; font-size: 1.1rem`
- `.persona-details summary`: `cursor: pointer; color: #4a9eff; font-weight: 600; font-size: 0.9rem`

**Sources:**

- `.copy-btn`: `background: #4a9eff; color: #0a0a0a; border: none; padding: 0.75rem 1.5rem; border-radius: 6px; font-weight: 600; cursor: pointer; margin-bottom: 1.5rem`
- `.source-category`: `background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 8px; padding: 1rem 1.5rem`
- `.source-item`: `padding: 1rem; background: #0a0a0a; border-radius: 6px; border-left: 3px solid #4a9eff`
- `.source-item a`: `color: #4a9eff; text-decoration: none; font-weight: 600`
- `.evidence`: `color: #c0c0c0; font-size: 0.9rem; margin-top: 0.5rem`

**Responsive:**

- `@media (max-width: 768px)`: reduce body padding to 1rem, h1 to 1.75rem, gap columns to 60px

## Behavior

```javascript
// Copy research brief to clipboard as formatted text
function copyResearchBrief() {
    const h1 = document.querySelector('h1');
    if (!h1) return;
    const businessName = h1.textContent.replace('Research Dashboard — ', '');
    let brief = `RESEARCH BRIEF — ${businessName}\n${'='.repeat(50)}\n\n`;

    // Market snapshot
    brief += 'MARKET SNAPSHOT\n';
    document.querySelectorAll('.snapshot-card').forEach(card => {
        const h3 = card.querySelector('h3');
        const p = card.querySelector('p');
        if (h3 && p) brief += `\n${h3.textContent}:\n${p.textContent}\n`;
    });

    // Personas
    brief += `\n${'='.repeat(50)}\nTARGET PERSONAS\n\n`;
    document.querySelectorAll('.persona-card').forEach(card => {
        const nameEl = card.querySelector('h3');
        const snapshotEl = card.querySelector('.persona-snapshot');
        if (nameEl && snapshotEl) brief += `${nameEl.textContent}\n${snapshotEl.textContent}\n\n`;
    });

    navigator.clipboard.writeText(brief).then(() => {
        const btn = document.querySelector('.copy-btn');
        if (!btn) return;
        const original = btn.textContent;
        btn.textContent = 'Copied!';
        btn.style.backgroundColor = '#22c55e';
        setTimeout(() => { btn.textContent = original; btn.style.backgroundColor = '#4a9eff'; }, 2000);
    }).catch(() => {
        const btn = document.querySelector('.copy-btn');
        if (!btn) return;
        const original = btn.textContent;
        btn.textContent = 'Copy failed';
        btn.style.backgroundColor = '#ef4444';
        setTimeout(() => { btn.textContent = original; btn.style.backgroundColor = '#4a9eff'; }, 2000);
    });
}

// Auto-expand first persona on load
document.addEventListener('DOMContentLoaded', () => {
    const first = document.querySelector('.persona-details');
    if (first) first.open = true;
});
```
