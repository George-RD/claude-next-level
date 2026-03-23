# Behavioral Spec: MultiLLMClient

**Source:** backend/services/llm/multi_llm_client.py
**Mode:** source

## Behaviors

### 1. Singleton Instance Access

**Description:** Provides a global singleton instance of the multi-provider LLM client. The singleton is lazily initialized on first access and reused for all subsequent calls.
**Inputs:** None.
**Expected Output:** The single shared instance of the LLM client service.
**Side Effects:** Creates the instance on first call; subsequent calls return the cached instance.
**Error Cases:** None.
**Citations:** [src:backend/services/llm/multi_llm_client.py:62-72]

### 2. Client Initialization

**Description:** Initializes the multi-provider LLM client with application settings. Sets up provider clients (Claude, OpenAI, DeepSeek), configures circuit breakers if available, and initializes metrics and cost tracking structures.
**Inputs:** Application settings object containing API keys and configuration for each provider.
**Expected Output:** A fully initialized client ready to route requests to any configured provider.
**Side Effects:** Creates HTTP client connections, initializes circuit breaker factory, sets up provider client instances.
**Error Cases:** None at construction time; missing API keys are handled at request time.
**Citations:** [src:backend/services/llm/multi_llm_client.py:74-130]

### 3. Claude Provider — Send Message

**Description:** Sends a message to the Claude AI provider with the specified model, system prompt, messages, and optional parameters (temperature, max tokens, tools). Tracks token usage and cost metrics.
**Inputs:**

- Model identifier (string)
- System prompt (string)
- List of message objects with role and content
- Optional: temperature, max_tokens, tools, tool_choice
**Expected Output:** A standardized response object containing the generated text, token usage counts (input/output), and model identifier.
**Side Effects:** Makes an HTTP request to the Claude API; records token usage and cost metrics; updates circuit breaker state.
**Error Cases:** API errors, rate limiting, network timeouts, circuit breaker open state.
**Citations:** [src:backend/services/llm/multi_llm_client.py:132-220]

### 4. Claude Provider — Stream Message

**Description:** Streams a message response from the Claude AI provider, yielding content chunks as they arrive. Collects token usage from the final message event.
**Inputs:** Same as Send Message (model, system prompt, messages, optional parameters).
**Expected Output:** An async generator yielding string chunks of the response, followed by a final usage summary.
**Side Effects:** Makes a streaming HTTP request to the Claude API; records metrics on completion.
**Error Cases:** API errors, network interruption during stream, circuit breaker open state.
**Citations:** [src:backend/services/llm/multi_llm_client.py:222-310]

### 5. OpenAI Provider — Send Message

**Description:** Sends a message to the OpenAI API with the specified model and parameters. Converts the internal message format to OpenAI's expected format and standardizes the response.
**Inputs:**

- Model identifier (string)
- System prompt (string)
- List of message objects
- Optional: temperature, max_tokens, tools
**Expected Output:** A standardized response object containing generated text, token usage, and model identifier.
**Side Effects:** Makes an HTTP request to the OpenAI API; records token usage and cost metrics.
**Error Cases:** API errors, rate limiting, network timeouts, circuit breaker open state.
**Citations:** [src:backend/services/llm/multi_llm_client.py:312-400]

### 6. OpenAI Provider — Stream Message

**Description:** Streams a message response from the OpenAI API, yielding content chunks as they arrive.
**Inputs:** Same as OpenAI Send Message.
**Expected Output:** An async generator yielding string chunks of the response.
**Side Effects:** Makes a streaming HTTP request to the OpenAI API; records metrics on completion.
**Error Cases:** API errors, network interruption, circuit breaker open state.
**Citations:** [src:backend/services/llm/multi_llm_client.py:402-480]

### 7. DeepSeek Provider — Send Message

**Description:** Sends a message to the DeepSeek API. Uses OpenAI-compatible API format with a DeepSeek-specific base URL and API key.
**Inputs:**

- Model identifier (string)
- System prompt (string)
- List of message objects
- Optional: temperature, max_tokens
**Expected Output:** A standardized response object containing generated text, token usage, and model identifier.
**Side Effects:** Makes an HTTP request to the DeepSeek API; records token usage and cost metrics.
**Error Cases:** API errors, rate limiting, circuit breaker open state.
**Citations:** [src:backend/services/llm/multi_llm_client.py:482-550]

### 8. DeepSeek Provider — Stream Message

**Description:** Streams a message response from the DeepSeek API, yielding content chunks.
**Inputs:** Same as DeepSeek Send Message.
**Expected Output:** An async generator yielding string chunks.
**Side Effects:** Makes a streaming HTTP request to the DeepSeek API; records metrics on completion.
**Error Cases:** API errors, network interruption, circuit breaker open state.
**Citations:** [src:backend/services/llm/multi_llm_client.py:552-620]

### 9. Provider Resolution

**Description:** Determines which LLM provider to use for a given model identifier. Maps model names to their respective providers (Claude, OpenAI, DeepSeek) using a predefined model-provider mapping.
**Inputs:** A model identifier string.
**Expected Output:** The provider enum value corresponding to the model.
**Side Effects:** None.
**Error Cases:** Unknown model identifier raises a value error.
**Citations:** [src:backend/services/llm/multi_llm_client.py:622-650]

### 10. Unified Send Message (Router)

**Description:** Top-level method that routes a send-message request to the appropriate provider based on the model identifier. Handles circuit breaker wrapping, retry logic, and fallback to equivalent models if the primary provider fails.
**Inputs:**

- Organization ID or database session for provider configuration lookup
- Model identifier
- System prompt and messages
- Optional parameters (temperature, max_tokens, tools)
**Expected Output:** A standardized response from whichever provider handles the request.
**Side Effects:** May try multiple providers if fallback is triggered; records metrics for each attempt.
**Error Cases:** All providers fail — raises the last encountered error. Circuit breaker open — attempts fallback.
**Citations:** [src:backend/services/llm/multi_llm_client.py:652-740]

### 11. Unified Stream Message (Router)

**Description:** Top-level streaming method that routes to the appropriate provider. Similar to the unified send method but returns an async generator of content chunks.
**Inputs:** Same as Unified Send Message.
**Expected Output:** An async generator yielding string chunks from the resolved provider.
**Side Effects:** May try multiple providers on fallback; records metrics.
**Error Cases:** All providers fail — raises the last error. Circuit breaker open — attempts fallback.
**Citations:** [src:backend/services/llm/multi_llm_client.py:742-830]

### 12. Circuit Breaker Integration

**Description:** Wraps each provider call with a circuit breaker that tracks failures. After a configurable number of consecutive failures, the circuit opens and subsequent calls fail fast without hitting the provider. The circuit resets after a cooldown period.
**Inputs:** Provider name (used as circuit breaker key), the callable to protect.
**Expected Output:** The result of the callable if circuit is closed/half-open; raises circuit open error if open.
**Side Effects:** Updates circuit breaker state (failure/success counters, open/closed transitions).
**Error Cases:** Circuit open state causes immediate failure with a descriptive error.
**Citations:** [src:backend/services/llm/multi_llm_client.py:832-890]

### 13. Fallback Cascade

**Description:** When a provider fails (due to error or open circuit breaker), attempts to find an equivalent model from a different provider and retry the request. The cascade order is determined by the model equivalence mapping.
**Inputs:** The failed model identifier, the original request parameters, the error that triggered fallback.
**Expected Output:** A response from the fallback provider, or re-raises the original error if no fallback succeeds.
**Side Effects:** Logs fallback attempts; records fallback metrics; may try multiple alternative providers.
**Error Cases:** No equivalent model available; all fallback providers also fail.
**Citations:** [src:backend/services/llm/multi_llm_client.py:892-950]

### 14. Token Usage Tracking

**Description:** Records input and output token counts for every LLM API call. Aggregates usage per provider, per model, and per organization for billing and monitoring purposes.
**Inputs:** Provider name, model name, input token count, output token count, organization ID.
**Expected Output:** None (updates internal metrics state).
**Side Effects:** Updates internal counters; emits metrics to the observability system.
**Error Cases:** None.
**Citations:** [src:backend/services/llm/multi_llm_client.py:952-1000]

### 15. Cost Estimation

**Description:** Estimates the cost of an LLM API call based on token usage and a predefined cost-per-token table. Costs are calculated separately for input and output tokens at different rates per model.
**Inputs:** Model name, input token count, output token count.
**Expected Output:** Estimated cost in USD as a floating-point number.
**Side Effects:** None (pure calculation).
**Error Cases:** Unknown model defaults to zero cost (does not raise).
**Citations:** [src:backend/services/llm/multi_llm_client.py:42-60, 1002-1040]

### 16. Organization Provider Configuration

**Description:** Resolves which LLM provider and model to use based on the organization's integration configuration. Queries the database for active AI provider integrations and their configured models.
**Inputs:** Database session, organization ID.
**Expected Output:** A tuple of (provider, model, API key) based on the organization's active configuration.
**Side Effects:** Database query to read integration configuration.
**Error Cases:** No active integration found — falls back to default provider/model.
**Citations:** [src:backend/services/llm/multi_llm_client.py:1042-1100]

### 17. Message Format Conversion

**Description:** Converts between internal message format and provider-specific formats. Handles differences in how Claude, OpenAI, and DeepSeek expect messages (system prompt handling, role names, content structure).
**Inputs:** Internal message list, system prompt, target provider.
**Expected Output:** Provider-formatted message list ready for API submission.
**Side Effects:** None (pure transformation).
**Error Cases:** None.
**Citations:** [src:backend/services/llm/multi_llm_client.py:1102-1150]

### 18. Tool/Function Calling Support

**Description:** Passes tool definitions to providers that support function calling (Claude, OpenAI). Converts tool definitions between provider-specific schemas and handles tool-use responses.
**Inputs:** List of tool definitions, tool choice preference, provider context.
**Expected Output:** Formatted tool definitions for the target provider; parsed tool-use results from responses.
**Side Effects:** None for formatting; tool execution is handled externally.
**Error Cases:** Provider does not support tools — tools parameter is ignored.
**Citations:** [src:backend/services/llm/multi_llm_client.py:1152-1220]

### 19. Request Timeout Configuration

**Description:** Configures per-provider HTTP request timeouts. Each provider can have a different timeout value to account for varying response latencies.
**Inputs:** Provider name or settings configuration.
**Expected Output:** Timeout value in seconds for HTTP client configuration.
**Side Effects:** None.
**Error Cases:** Timeout exceeded raises a timeout error that triggers circuit breaker/fallback.
**Citations:** [src:backend/services/llm/multi_llm_client.py:1222-1260]

### 20. Retry Logic

**Description:** Implements retry with exponential backoff for transient errors (rate limits, server errors). The number of retries and backoff factor are configurable per provider.
**Inputs:** The callable to retry, max retries, backoff factor.
**Expected Output:** The successful result after retries, or raises the final error.
**Side Effects:** Introduces delays between retries; logs retry attempts.
**Error Cases:** All retries exhausted — raises the last error.
**Citations:** [src:backend/services/llm/multi_llm_client.py:1262-1310]

### 21. Health Check

**Description:** Checks the health status of each configured LLM provider by verifying API key presence and optionally making a lightweight API call. Returns a per-provider health status report.
**Inputs:** None.
**Expected Output:** A dictionary mapping provider names to their health status (healthy/unhealthy/unconfigured).
**Side Effects:** May make lightweight API calls to verify connectivity.
**Error Cases:** Provider API unreachable — reported as unhealthy in the status map.
**Citations:** [src:backend/services/llm/multi_llm_client.py:1312-1370]

### 22. Metrics Export

**Description:** Exports accumulated LLM usage metrics including total requests, token counts, costs, error rates, and circuit breaker states for each provider.
**Inputs:** None.
**Expected Output:** A structured metrics report with per-provider and per-model breakdowns.
**Side Effects:** Reads from internal metrics counters.
**Error Cases:** None.
**Citations:** [src:backend/services/llm/multi_llm_client.py:1372-1420]

### 23. Provider Client Initialization — Claude

**Description:** Initializes the Claude provider client with API key from settings. Uses the async variant for non-blocking API calls.
**Inputs:** API key from application settings.
**Expected Output:** An initialized async Claude client ready for API calls.
**Side Effects:** Creates an HTTP client connection pool.
**Error Cases:** Missing API key — client not initialized, provider marked as unavailable.
**Citations:** [src:backend/services/llm/multi_llm_client.py:85-95]

### 24. Provider Client Initialization — OpenAI

**Description:** Initializes the OpenAI provider client with API key from settings.
**Inputs:** API key from application settings.
**Expected Output:** An initialized async OpenAI client.
**Side Effects:** Creates an HTTP client connection pool.
**Error Cases:** Missing API key — client not initialized, provider marked as unavailable.
**Citations:** [src:backend/services/llm/multi_llm_client.py:97-107]

### 25. Provider Client Initialization — DeepSeek

**Description:** Initializes the DeepSeek provider client using OpenAI-compatible client with a custom base URL and DeepSeek API key.
**Inputs:** DeepSeek API key and base URL from application settings.
**Expected Output:** An initialized async client configured for the DeepSeek endpoint.
**Side Effects:** Creates an HTTP client connection pool.
**Error Cases:** Missing API key — client not initialized.
**Citations:** [src:backend/services/llm/multi_llm_client.py:109-120]

### 26. Error Classification

**Description:** Classifies LLM API errors into categories (rate_limit, auth_error, server_error, timeout, unknown) for appropriate handling. Different error types trigger different behaviors (retry, fallback, fail fast).
**Inputs:** The caught exception from a provider API call.
**Expected Output:** An error category enum/string and whether the error is retryable.
**Side Effects:** None.
**Error Cases:** None (this is error handling itself).
**Citations:** [src:backend/services/llm/multi_llm_client.py:1422-1470]

### 27. Response Standardization

**Description:** Converts provider-specific response formats into a standardized internal response object with consistent fields (content, usage, model, provider) regardless of which provider generated it.
**Inputs:** A raw provider-specific response object and the provider identifier.
**Expected Output:** A standardized response object with content string, input/output token counts, model name, and provider name.
**Side Effects:** None (pure transformation).
**Error Cases:** Unexpected response format — logs warning and extracts what is available.
**Citations:** [src:backend/services/llm/multi_llm_client.py:1472-1520]

### 28. Concurrent Request Limiting

**Description:** Limits the number of concurrent LLM API requests to prevent overwhelming providers. Uses a semaphore to queue excess requests.
**Inputs:** Concurrency limit from settings.
**Expected Output:** Requests proceed when a slot is available; excess requests wait.
**Side Effects:** May delay request processing when at capacity.
**Error Cases:** None.
**Citations:** [src:backend/services/llm/multi_llm_client.py:1522-1550]

### 29. Provider API Key Validation

**Description:** Validates that API keys are present and non-empty for providers before attempting API calls. Returns a clear error if a required provider is not configured.
**Inputs:** Provider identifier.
**Expected Output:** Boolean indicating whether the provider is configured.
**Side Effects:** None.
**Error Cases:** Provider not configured — raises a configuration error with instructions.
**Citations:** [src:backend/services/llm/multi_llm_client.py:1552-1580]

### 30. Model Equivalence Mapping

**Description:** Maps models across providers for fallback purposes. When a Claude model fails, the system can fall back to an equivalent OpenAI model, and vice versa. Uses a predefined mapping imported from the models module.
**Inputs:** Failed model identifier.
**Expected Output:** A list of equivalent models from other providers, ordered by preference.
**Side Effects:** None (pure lookup).
**Error Cases:** No equivalent found — returns empty list.
**Citations:** [src:backend/services/llm/multi_llm_client.py:31, 892-950]

### 31. Logging and Observability

**Description:** Logs significant events throughout the LLM request lifecycle: request initiation, provider selection, fallback attempts, errors, circuit breaker state changes, and performance metrics. Uses structured logging with contextual fields.
**Inputs:** Various contextual data (provider, model, duration, error details).
**Expected Output:** Log entries at appropriate levels (info, warning, error).
**Side Effects:** Writes to application logging system.
**Error Cases:** None.
**Citations:** [src:backend/services/llm/multi_llm_client.py:37-39]

### 32. Business Metrics Recording

**Description:** Records business-level metrics for LLM usage: requests per organization, cost per organization, model popularity, and error rates. These metrics feed into billing and analytics dashboards.
**Inputs:** Organization ID, provider, model, token counts, cost, success/failure status.
**Expected Output:** None (fires and forgets metric recording).
**Side Effects:** Updates business metrics counters via the observability system.
**Error Cases:** Metrics recording failure does not affect the main request flow.
**Citations:** [src:backend/services/llm/multi_llm_client.py:38-39, 952-1000]

### 33. Graceful Degradation Without Circuit Breaker Library

**Description:** If the circuit breaker library (purgatory) is not installed, the client operates without circuit breaker protection. A warning is logged at import time, and the circuit breaker wrapping is skipped.
**Inputs:** Import availability of the purgatory library.
**Expected Output:** Client functions normally without circuit breaker; a warning is logged.
**Side Effects:** Logs a warning at module load time.
**Error Cases:** None (graceful fallback).
**Citations:** [src:backend/services/llm/multi_llm_client.py:14-28]

### 34. LLM Cost Table

**Description:** Maintains a static cost table mapping model identifiers to their per-token pricing (input and output rates per million tokens). Covers Claude, OpenAI, and DeepSeek model variants.
**Inputs:** None (static data structure).
**Expected Output:** Cost rates for input and output tokens per model.
**Side Effects:** None.
**Error Cases:** None.
**Citations:** [src:backend/services/llm/multi_llm_client.py:42-60]

## Internal Invariants

1. The client is a singleton — only one instance exists per process, ensuring shared circuit breaker state and metrics.
2. Circuit breaker state is per-provider, not per-model — all models from the same provider share a circuit breaker.
3. Fallback never cascades back to the original provider — prevents infinite loops.
4. Token usage is recorded for every successful API call, even if the caller discards the response.
5. Cost estimation uses the static LLM_COSTS table — costs are approximations, not actuals from provider billing.
6. The client is async-only — all provider calls use async HTTP clients.
7. Provider clients are initialized eagerly at construction but only used when a matching model is requested.
8. Streaming responses collect token usage from the stream's final event — usage is not available until the stream completes.

## Untested Behaviors

1. Circuit breaker state transitions (open -> half-open -> closed) under concurrent load
2. Fallback cascade with more than 2 providers failing simultaneously
3. DeepSeek streaming with tool calling (DeepSeek may not support tools)
4. Cost estimation accuracy for models not in the LLM_COSTS table
5. Concurrent request limiting under high contention (semaphore behavior)
6. Session/connection pool exhaustion with long-running streams
7. Graceful shutdown and cleanup of HTTP client connections
8. Behavior when organization has multiple active AI integrations of the same type

## Dependencies

1. `anthropic` (AsyncAnthropic) — Claude provider client SDK
2. `openai` (AsyncOpenAI) — OpenAI provider client SDK (also used for DeepSeek)
3. `httpx` — HTTP client library for custom requests
4. `purgatory` (optional) — Circuit breaker library (AsyncCircuitBreakerFactory)
5. `sqlalchemy` (AsyncSession) — Database access for organization configuration
6. `config.Settings` — Application settings with API keys and configuration
7. `models.integration` — AI provider/model enums, model-provider mapping, integration ORM models
8. `models.organization` — Organization ORM model
9. `observability.metrics` — Technical metrics recording
10. `observability.business_metrics` — Business-level metrics recording
11. `jwt` / auth middleware — Implicit dependency via organization context in requests
12. `logging` — Python standard library logging
13. `time` — Performance timing
14. `abc` — Abstract base class definitions
