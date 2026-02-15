# Template: Workshop Progress

## When to Generate

- **Initial generation:** After Phase 0 completes
- **Updates:** After each phase (1-5) completes
- **On request:** When user asks to "show progress" or "show workshop status"

## Data Sources

- Primary: `{project-name}-offer.md` — phase completion status, decisions, agent consensus, scores
- Extract:
  - Business name
  - Current phase number (0-5)
  - Completion status for each phase (completed, current, locked)
  - Key decisions made in each completed phase
  - Agent consensus statements per phase
  - Phase scores where applicable (e.g., Starving Crowd 32/40)
  - Gate status (green/yellow/red)
  - Workshop start date (for days elapsed)

## HTML Structure

Generate a single self-contained HTML file. All CSS and JS inline. No external dependencies.

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Workshop Progress — {{BUSINESS_NAME}}</title>
    <style>/* All CSS inline — see Styling section */</style>
</head>
<body>
    <header>
        <h1>Workshop Progress — {{BUSINESS_NAME}}</h1>
        <p class="subtitle">Phase {{CURRENT_PHASE}} of 5 | {{COMPLETION_STATUS}}</p>
    </header>

    <main>
        <!-- Section 1: Phase Timeline (horizontal visual) -->
        <section class="timeline">
            <h2>Phase Timeline</h2>
            <div class="timeline-track">
                <div class="timeline-phases">
                    <!-- Repeat for phases 0-5 -->
                    <!-- Status classes: completed, current, locked -->
                    <div class="timeline-phase" data-phase="{{PHASE_NUM}}">
                        <div class="phase-dot {{STATUS_CLASS}}">
                            <!-- Show checkmark if completed, number otherwise -->
                            {{PHASE_NUM_OR_CHECK}}
                        </div>
                        <div class="phase-connector {{CONNECTOR_STATUS}}"></div>
                        <div class="phase-label">
                            <span class="phase-name">{{PHASE_NAME}}</span>
                            <!-- Show "Current" badge on active phase -->
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <!-- Section 2: Phase Details (accordion) -->
        <section class="phase-details">
            <h2>Phase Details</h2>
            <div class="phases-accordion">
                <!-- Phase 0: Discovery -->
                <details class="phase-section {{STATUS}}" data-phase="0"
                    {{OPEN_IF_CURRENT_OR_COMPLETED}}>
                    <summary>
                        <span class="phase-icon {{STATUS}}">{{ICON}}</span>
                        <span class="phase-title">Phase 0: Discovery</span>
                        <span class="phase-status-badge {{STATUS}}">{{STATUS_TEXT}}</span>
                    </summary>
                    <div class="phase-content">
                        <!-- If completed: show decisions + consensus -->
                        <div class="decision-block">
                            <h4>Key Decisions</h4>
                            <ul>
                                <li>{{DECISION}}</li>
                            </ul>
                        </div>
                        <div class="consensus-block">
                            <h4>Agent Consensus</h4>
                            <p>{{CONSENSUS}}</p>
                        </div>
                        <!-- If locked: show unlock message -->
                    </div>
                </details>

                <!-- Phase 1: Starving Crowd -->
                <details class="phase-section {{STATUS}}" data-phase="1">
                    <summary>
                        <span class="phase-icon {{STATUS}}">{{ICON}}</span>
                        <span class="phase-title">Phase 1: Starving Crowd</span>
                        <span class="phase-status-badge {{STATUS}}">{{STATUS_TEXT}}</span>
                    </summary>
                    <div class="phase-content">
                        <!-- If completed: show score block + decisions -->
                        <div class="score-block">
                            <h4>Starving Crowd Score</h4>
                            <div class="score-display">
                                <span class="score-value">{{SCORE}}/40</span>
                                <span class="score-gate {{GATE_COLOR}}">{{GATE_TEXT}}</span>
                            </div>
                        </div>
                        <div class="decision-block">
                            <h4>Key Decisions</h4>
                            <ul><li>{{DECISION}}</li></ul>
                        </div>
                        <div class="consensus-block">
                            <h4>Agent Consensus</h4>
                            <p>{{CONSENSUS}}</p>
                        </div>
                    </div>
                </details>

                <!-- Phases 2-4: Same pattern -->
                <!-- Phase 2: Pricing -->
                <!-- Phase 3: Value Equation -->
                <!-- Phase 4: Offer Creation -->

                <!-- Phase 5: Enhancement (final) -->
                <details class="phase-section {{STATUS}}" data-phase="5">
                    <summary>
                        <span class="phase-icon {{STATUS}}">{{ICON}}</span>
                        <span class="phase-title">Phase 5: Enhancement</span>
                        <span class="phase-status-badge {{STATUS}}">{{STATUS_TEXT}}</span>
                    </summary>
                    <div class="phase-content">
                        <!-- If completed: show final score + link to offer summary -->
                        <div class="score-block">
                            <h4>Final Offer Score</h4>
                            <div class="score-display">
                                <span class="score-value final">{{FINAL_SCORE}}/10</span>
                                <span class="score-verdict">{{VERDICT}}</span>
                            </div>
                        </div>
                        <div class="consensus-block">
                            <h4>Agent Consensus</h4>
                            <p>{{CONSENSUS}}</p>
                        </div>
                        <div class="next-action">
                            <a href="./{{PROJECT_NAME}}-offer-summary.html" class="view-offer-btn">
                                View Final Offer
                            </a>
                        </div>
                    </div>
                </details>
            </div>
        </section>

        <!-- Section 3: Quick Stats -->
        <section class="quick-stats">
            <h2>Quick Stats</h2>
            <div class="stats-grid">
                <div class="stat-card">
                    <span class="stat-value">{{COMPLETED_PHASES}}/6</span>
                    <span class="stat-label">Phases Complete</span>
                </div>
                <div class="stat-card">
                    <span class="stat-value">{{TOTAL_DECISIONS}}</span>
                    <span class="stat-label">Key Decisions</span>
                </div>
                <div class="stat-card">
                    <span class="stat-value">{{DAYS_ELAPSED}}</span>
                    <span class="stat-label">Days Elapsed</span>
                </div>
                <div class="stat-card">
                    <span class="stat-value">{{COMPLETION_PERCENT}}%</span>
                    <span class="stat-label">Complete</span>
                </div>
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

- `body`: `background: #0a0a0a; color: #e0e0e0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; line-height: 1.6; padding: 2rem; max-width: 1200px; margin: 0 auto`
- `h1`: `font-size: 2.5rem; font-weight: 700; color: #fff; margin-bottom: 0.5rem`
- `h2`: `font-size: 1.75rem; font-weight: 600; color: #fff; border-left: 4px solid #4a9eff; padding-left: 1rem; margin-bottom: 1.5rem`
- `section`: `margin-bottom: 3rem`
- `.subtitle`: `color: #888; font-size: 1.1rem`

**Timeline:**

- `.timeline-track`: `background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 8px; padding: 3rem 2rem; overflow-x: auto`
- `.timeline-phases`: `display: flex; justify-content: space-between; align-items: flex-start; min-width: 800px; position: relative`
- `.timeline-phase`: `display: flex; flex-direction: column; align-items: center; position: relative; flex: 1`
- `.phase-dot`: `width: 48px; height: 48px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: 700; font-size: 1.25rem; border: 3px solid #2a2a2a; background: #1a1a1a; color: #888; position: relative; z-index: 2; transition: all 0.3s`
- `.phase-dot.completed`: `background: #22c55e; border-color: #22c55e; color: #fff`
- `.phase-dot.current`: `background: #4a9eff; border-color: #4a9eff; color: #fff; box-shadow: 0 0 0 4px rgba(74,158,255,0.2)`
- `.phase-dot.locked`: `background: #0a0a0a; border-color: #2a2a2a; color: #555`
- `.phase-connector`: `position: absolute; top: 24px; left: 50%; width: 100%; height: 3px; background: #2a2a2a; z-index: 1`
- `.phase-connector.completed`: `background: #22c55e`
- Last phase connector: `display: none`
- `.phase-name`: `font-weight: 600; color: #e0e0e0; font-size: 0.9rem`
- `.phase-badge.current`: `background: rgba(74,158,255,0.2); color: #4a9eff; font-size: 0.75rem; padding: 0.25rem 0.5rem; border-radius: 10px; font-weight: 600; text-transform: uppercase`

**Phase Accordion:**

- `.phase-section`: `background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 8px; overflow: hidden; transition: border-color 0.2s`
- `.phase-section.completed`: `border-left: 4px solid #22c55e`
- `.phase-section.current`: `border-left: 4px solid #4a9eff; border-color: #4a9eff`
- `.phase-section.locked`: `opacity: 0.6`
- `summary`: `padding: 1.25rem 1.5rem; cursor: pointer; display: flex; align-items: center; gap: 1rem; user-select: none; list-style: none`
- `summary::-webkit-details-marker`: `display: none`
- `.phase-icon`: `width: 32px; height: 32px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: 700; border: 2px solid #2a2a2a; background: #0a0a0a; color: #888; flex-shrink: 0`
- `.phase-icon.completed`: `background: #22c55e; border-color: #22c55e; color: #fff`
- `.phase-icon.current`: `background: #4a9eff; border-color: #4a9eff; color: #fff`
- `.phase-title`: `flex: 1; font-weight: 600; font-size: 1.1rem; color: #fff`
- `.phase-status-badge.completed`: `background: rgba(34,197,94,0.2); color: #22c55e; padding: 0.25rem 0.75rem; border-radius: 12px; font-size: 0.85rem; font-weight: 600; text-transform: uppercase`
- `.phase-status-badge.current`: `background: rgba(74,158,255,0.2); color: #4a9eff`
- `.phase-status-badge.locked`: `background: rgba(136,136,136,0.2); color: #888`
- `.phase-content`: `padding: 1.5rem; border-top: 1px solid #2a2a2a`
- `.phase-locked`: `color: #888; font-style: italic; text-align: center; padding: 1rem`

**Phase Content Blocks:**

- `.decision-block h4, .consensus-block h4, .score-block h4`: `font-size: 0.95rem; color: #4a9eff; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 0.75rem`
- `.decision-block ul`: `list-style-position: inside; color: #c0c0c0; padding-left: 0.5rem`
- `.consensus-block p`: `color: #c0c0c0; font-style: italic`
- `.score-block`: `background: #0a0a0a; border-radius: 6px; padding: 1.25rem; border-left: 3px solid #4a9eff`
- `.score-value`: `font-family: monospace; font-size: 2rem; font-weight: 800; color: #4a9eff`
- `.score-value.final`: `font-size: 2.5rem; color: #22c55e`
- `.score-gate.green`: `background: rgba(34,197,94,0.2); color: #22c55e; border: 1px solid #22c55e; padding: 0.5rem 1rem; border-radius: 6px; font-weight: 700; text-transform: uppercase`
- `.score-gate.yellow`: `background: rgba(234,179,8,0.2); color: #eab308; border: 1px solid #eab308`
- `.score-gate.red`: `background: rgba(239,68,68,0.2); color: #ef4444; border: 1px solid #ef4444`
- `.view-offer-btn`: `display: inline-block; background: #4a9eff; color: #0a0a0a; padding: 0.75rem 1.5rem; border-radius: 6px; font-weight: 700; text-decoration: none`

**Quick Stats:**

- `.stats-grid`: `display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1.5rem`
- `.stat-card`: `background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 8px; padding: 1.5rem; display: flex; flex-direction: column; align-items: center; gap: 0.5rem`
- `.stat-value`: `font-family: monospace; font-size: 2.25rem; font-weight: 800; color: #4a9eff`
- `.stat-label`: `color: #888; font-size: 0.9rem; text-transform: uppercase; letter-spacing: 0.5px`

**Responsive:**

- `@media (max-width: 768px)`: reduce body padding, h1 size, timeline padding, stats to 2-column grid

## Behavior

```javascript
document.addEventListener('DOMContentLoaded', () => {
    // Auto-expand current phase section
    const current = document.querySelector('.phase-section.current');
    if (current) current.open = true;

    // Prevent locked phases from opening
    document.querySelectorAll('.phase-section.locked').forEach(phase => {
        phase.querySelector('summary').addEventListener('click', e => {
            if (phase.classList.contains('locked')) e.preventDefault();
        });
    });

    // Animate timeline dots on load
    document.querySelectorAll('.phase-dot').forEach((dot, i) => {
        setTimeout(() => {
            dot.style.transform = 'scale(1.1)';
            setTimeout(() => { dot.style.transform = 'scale(1)'; }, 200);
        }, i * 100);
    });

    // Click timeline dot to scroll to corresponding phase section
    document.querySelectorAll('.timeline-phase').forEach(phase => {
        phase.style.cursor = 'pointer';
        phase.addEventListener('click', () => {
            const num = phase.dataset.phase;
            const section = document.querySelector(`.phase-section[data-phase="${num}"]`);
            if (section && !section.classList.contains('locked')) {
                section.scrollIntoView({ behavior: 'smooth', block: 'center' });
                section.open = true;
            }
        });
    });
});
```
