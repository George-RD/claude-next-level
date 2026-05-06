# Mermaid patterns

Use Mermaid to make task dependencies visible. Keep diagrams small enough to read. Put the DAG in the coordinator's visible progress update or swarm shared context before dispatching a wave.

## Improvement wave

```mermaid
flowchart TD
  P[Inspect and rank tasks] --> A[Implement task A]
  P --> B[Implement task B]
  A --> RA[Review task A]
  B --> RB[Review task B]
  RA --> G[Gate batch]
  RB --> G
  G --> C{Continue?}
  C -- yes --> P
  C -- no --> S[Stop and summarize]
```

## Review gate

```mermaid
flowchart TD
  D[Diff ready] --> L[Run local gates]
  L --> R[Structured reviewer]
  R --> X{Risky or process-sensitive?}
  X -- yes --> A[Adversarial reviewer]
  X -- no --> J[Coordinator judgment]
  A --> J
  J -- Critical or BLOCK --> F[Fix or stop]
  J -- clean --> M[Commit or submit]
```

## Dead-letter path

```mermaid
flowchart TD
  T[Task] --> I[Implement]
  I --> G[Gate]
  G -- fail once --> R[Repair]
  R --> G
  G -- fail twice --> B[Blocked report]
  B --> H[Human or higher-level decision]
```

## Full improve loop with review failure loopback

Use `assets/swarm-improve-loop.mmd` as the default diagram for implementation waves. It shows: implement, gate, simplify, multi-review fanout, loopback on failure, commit on pass, and checkpoint before continuing.

## Checkpoint wave

Use `assets/checkpoint-wave.mmd` when a larger swarm reaches a milestone. At checkpoints, pause normal implementation, run refactor and extended tests, then decide whether to continue.
