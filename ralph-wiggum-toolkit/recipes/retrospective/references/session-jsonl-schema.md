# Session JSONL Parsing Reference

Reference for the session-historian agent (Phase 5). Covers where Claude Code session files live, how to parse them, and what gap signals to look for.

---

## Where Sessions Live

Claude Code stores session history at:

```
~/.claude/projects/{encoded-path}/
```

### Path Encoding

The absolute project path has every `/` replaced with `-`.

**Example:**

```
/Users/george/repos/myproject  ->  -Users-george-repos-myproject
```

The encoded path starts with a leading `-` (from the root `/`).

### Safe Detection

Do NOT compute the encoded path blindly. Directory names within the project path may already contain hyphens, creating ambiguity when decoding.

**Recommended approach:**

1. List `~/.claude/projects/` to see all encoded directories
2. Match visually -- look for the directory that contains the expected path segments
3. Confirm by listing the contents and checking for `.jsonl` files with plausible timestamps

```bash
ls ~/.claude/projects/ | grep "repos-myproject"
```

---

## File Characteristics

- Each `.jsonl` file represents one Claude Code session
- Typical size: 300-1600 lines, 1.5-2.5 MB
- Safely loadable whole -- no need for streaming or chunked reads
- One JSON object per line (standard JSONL)
- Files are named with UUIDs or session identifiers

---

## JSON Line Types

Each line in the JSONL file is a JSON object representing a message in the conversation. The key fields for extraction are `type` and `message.content`.

### User Text Messages

**Detection:**

```
msg.type == "user" AND typeof msg.message.content === "string"
```

User messages have their content as a plain string, not an array. This is the user's typed input.

**jq extraction:**

```bash
jq -r 'select(.type == "user" and (.message.content | type) == "string") | .message.content' session.jsonl
```

### Assistant Text Messages

**Detection:**

```
msg.type == "assistant"
```

Assistant content is an array of content blocks. Extract text blocks:

```
msg.message.content[] where .type == "text" -> .text
```

**jq extraction:**

```bash
jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' session.jsonl
```

### Tool Calls (Assistant)

Tool calls appear as content blocks within assistant messages:

```
msg.message.content[] where .type == "tool_use"
  -> .name    (tool name: "Read", "Edit", "Bash", etc.)
  -> .input   (tool arguments object)
```

**jq extraction:**

```bash
jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | "\(.name): \(.input | tostring[:100])"' session.jsonl
```

### Tool Results

Tool results appear as content blocks, typically in user-type messages that follow tool calls:

```
msg.message.content[] where .type == "tool_result"
```

These contain the output returned by the tool. Usually less interesting for gap analysis than the tool call itself.

### Course Corrections

A course correction is a user text message that has a non-null `parentUuid`, meaning the user interrupted or redirected the assistant mid-conversation.

**Detection:**

```
msg.type == "user"
AND typeof msg.message.content === "string"
AND msg.parentUuid != null
```

Course corrections are high-signal for gap analysis -- they indicate the agent was going in the wrong direction.

### Timestamps

All timestamps are ISO 8601 UTC format:

```
"2026-03-18T14:22:01.234Z"
```

Available on the message object. Use timestamps to establish chronological order and correlate with git commits.

---

## Gap Signal Patterns

When scanning session history, look for these specific patterns that indicate gaps in the agent's work.

### 1. User Repeating an Ignored Instruction

The user states an instruction, the agent does not follow it, and the user restates the same instruction later in the session.

**What to look for:** Similar user messages appearing more than once with agent work between them. The repetition implies the agent did not act on the first instruction.

**Example signal:**

```
User (early):   "Make sure to handle the case where config file is missing"
... agent works on other things ...
User (later):   "You still haven't handled missing config files"
```

### 2. User Corrections

Explicit user corrections indicate the agent produced wrong output or took a wrong approach.

**Trigger phrases:**

- "no", "wait", "stop"
- "that's not what I meant"
- "you missed", "you forgot"
- "actually, I want"
- "go back", "undo that"
- "that's wrong", "that's incorrect"

**jq extraction for correction signals:**

```bash
jq -r 'select(.type == "user" and (.message.content | type) == "string") | .message.content' session.jsonl \
  | grep -iE "(no,|wait,|stop |that's not|you missed|you forgot|actually|go back|undo|that's wrong|that's incorrect)"
```

### 3. Agent Claiming Completion Prematurely

The agent states work is complete, but the user follows up indicating it is not.

**Pattern:** Assistant message containing completion language ("done", "finished", "completed", "all set") followed by a user message indicating more work is needed.

**What to look for:**

```
Assistant: "I've completed the implementation of the auth module."
User:      "The error handling is missing. You need to add retry logic."
```

### 4. Agent Skipping Steps

The agent acknowledges a multi-step plan but only executes some steps.

**What to look for:** Assistant messages listing steps (numbered lists, "first... then... finally...") where subsequent work does not cover all listed steps.

### 5. User Course-Corrections (Structural)

Beyond textual signals, structural course corrections are detectable: a user text message with a non-null `parentUuid` that follows an assistant message. This means the user interrupted the flow to redirect.

These are especially valuable because they indicate real-time dissatisfaction -- the user did not wait for the agent to finish before correcting course.

---

## Practical Extraction Examples

### List All User Messages with Timestamps

```bash
jq -r 'select(.type == "user" and (.message.content | type) == "string") | "\(.timestamp // "no-ts"): \(.message.content[:200])"' session.jsonl
```

### List All Tool Calls (What the Agent Did)

```bash
jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "tool_use") | .name' session.jsonl \
  | sort | uniq -c | sort -rn
```

This gives a frequency count of tool usage -- useful for understanding the agent's work pattern (heavy on Read? lots of Bash? many Edits?).

### Extract Conversation Flow (User + Assistant Text Only)

```bash
jq -r '
  if .type == "user" and (.message.content | type) == "string" then
    "USER: \(.message.content[:300])"
  elif .type == "assistant" then
    .message.content[]? | select(.type == "text") | "AGENT: \(.text[:300])"
  else empty end
' session.jsonl
```

### Find Course Corrections

```bash
jq -r 'select(.type == "user" and (.message.content | type) == "string" and .parentUuid != null) | "CORRECTION: \(.message.content[:200])"' session.jsonl
```

### Agent Pseudocode for Gap Matching

For agents that cannot run jq directly, here is the logic in pseudocode:

```
for each line in session.jsonl:
    msg = JSON.parse(line)

    if msg.type == "user" and typeof msg.message.content == "string":
        user_text = msg.message.content
        check for correction phrases
        check for repeated instructions (compare to previous user messages)
        if msg.parentUuid != null:
            flag as course correction

    if msg.type == "assistant":
        for block in msg.message.content:
            if block.type == "text":
                assistant_text = block.text
                check for premature completion claims
            if block.type == "tool_use":
                record tool call (block.name, block.input)
```

### Match Signals to EVR Themes

After collecting gap signals from a session, match each signal to the closest EVR theme from `retro/synthesis.md`:

1. Read the EVR document and extract theme summaries
2. For each gap signal, compare the signal context (what was being discussed) to EVR theme descriptions
3. Assign the signal to the most relevant EVR-NNN
4. If no theme matches, note it as an unmatched signal (potential new finding)

Output each match as an `EXP-NNN` item with the session filename, timestamp, relevant quotes, and the matched EVR theme.
