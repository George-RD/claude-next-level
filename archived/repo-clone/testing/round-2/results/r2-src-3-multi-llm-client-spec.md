# Behavioral Specification: Multi-Provider LLM Client

**File:** `/tmp/claude/tellmemo-app/backend/services/llm/multi_llm_client.py`

---

## Module Overview

This module provides a multi-provider LLM (Large Language Model) client service that supports Claude (Anthropic), OpenAI, and DeepSeek providers. It implements dynamic provider switching and intelligent fallback mechanisms based on organization configuration and error conditions. [source:file:1-3]

---

## Cost Estimation

### `estimate_llm_cost(provider: str, model: str, input_tokens: int, output_tokens: int) -> float`

**Purpose:** Computes the estimated cost in USD cents for LLM API usage. [source:file:63-83]

**Behavior:**

- Accepts a provider name ("claude", "openai", "deepseek") and a model identifier [source:file:68-69]
- Looks up provider-specific token costs from the `LLM_COSTS` dictionary [source:file:41-60] which contains pricing data in USD per 1 million tokens [source:file:41]
- Uses fallback pricing of $1.00 per million input tokens and $2.00 per million output tokens if the model is not found [source:file:77]
- Calculates total cost by: (input_tokens / 1,000,000 x input_rate x 100 cents) + (output_tokens / 1,000,000 x output_rate x 100 cents) [source:file:80-81]
- Returns the result rounded to 4 decimal places [source:file:83]

---

## Provider Client Abstraction

### `BaseProviderClient` (Abstract)

**Purpose:** Defines the contract that all provider-specific clients must implement. [source:file:86-133]

#### Methods

**`async create_message(prompt: str, *, model: str, max_tokens: int, temperature: float, system: Optional[str] = None, **kwargs) -> Optional[Any]`**

- Creates a single LLM message in response to a prompt [source:file:90-101]
- Accepts keyword arguments via `**kwargs` for provider-specific parameters

**`async create_conversation(messages: List[Dict[str, str]], *, model: str, max_tokens: int, temperature: float, **kwargs) -> Optional[Any]`**

- Processes a full conversation with message history [source:file:104-114]
- Takes a list of message dictionaries with roles and content

**`def is_available() -> bool`**

- Checks whether the provider client is operational [source:file:117-119]

**`async create_message_stream(prompt: str, *, model: str, max_tokens: int, temperature: float, system: Optional[str] = None, **kwargs) -> AsyncGenerator[Any, None]`**

- Generates streaming responses [source:file:122-133]
- Returns an async generator that yields response chunks

---

## Claude Provider Implementation

### `ClaudeProviderClient(BaseProviderClient)`

**Purpose:** Implements Anthropic Claude API integration. [source:file:136-250]

#### Constructor

**`__init__(api_key: str, settings: Settings)`**

- Stores API key and settings [source:file:139-142]
- Initializes the Anthropic client via `_initialize_client()` [source:file:142]

#### Initialization

**`_initialize_client() -> Optional[AsyncAnthropic]`**

- Returns `None` if no API key is provided [source:file:146-147]
- In development environments, creates an AsyncAnthropic client with SSL verification disabled [source:file:150-155]
- In production environments, creates a standard AsyncAnthropic client [source:file:157]
- Catches initialization exceptions, logs errors, and returns `None` on failure [source:file:159-161]

#### Availability

**`is_available() -> bool`**

- Returns `True` if the client is initialized, `False` otherwise [source:file:163-164]

#### Message Creation

**`async create_message(prompt: str, *, model: str, max_tokens: int, temperature: float, system: Optional[str] = None, **kwargs) -> Optional[Any]`**

- Returns `None` if client is not initialized [source:file:177-178]
- Wraps the prompt in a user message [source:file:180]
- Builds API parameters with model, max_tokens, temperature, and messages [source:file:181-186]
- Includes system prompt if provided [source:file:188-189]
- Filters out OpenAI-incompatible parameters including "response_format", "stream", "n", "logprobs", "top_logprobs", and "system_prompt" [source:file:193-196]
- Merges remaining kwargs into API parameters [source:file:197]
- Returns the response from `client.messages.create()` [source:file:199-201]

#### Conversation

**`async create_conversation(messages: List[Dict[str, str]], *, model: str, max_tokens: int, temperature: float, **kwargs) -> Optional[Any]`**

- Returns `None` if client is not initialized [source:file:213-214]
- Filters out OpenAI-incompatible parameters from kwargs [source:file:218-221]
- Builds API parameters with model, max_tokens, temperature, and messages [source:file:223-229]
- Returns the response from `client.messages.create()` [source:file:231]

#### Streaming (Unimplemented)

**`async create_message_stream(...) -> AsyncGenerator[Any, None]`**

- Raises `NotImplementedError` as streaming is not yet supported for Claude [source:file:248-250]

---

## OpenAI Provider Implementation

### `OpenAIProviderClient(BaseProviderClient)`

**Purpose:** Implements OpenAI API integration with special handling for GPT-5/o1 models. [source:file:254-451]

#### Constructor and Initialization

**`__init__(api_key: str, settings: Settings)`**

- Stores API key and settings, initializes client [source:file:257-260]

**`_initialize_client() -> Optional[AsyncOpenAI]`**

- Returns `None` if no API key provided [source:file:264-265]
- In development, creates AsyncOpenAI with disabled SSL verification [source:file:268-273]
- In production, creates standard AsyncOpenAI client [source:file:275]
- Logs and suppresses initialization errors [source:file:277-279]

#### Availability

**`is_available() -> bool`**

- Returns `True` if client initialized [source:file:281-282]

#### Message Creation

**`async create_message(prompt: str, *, model: str, max_tokens: int, temperature: float, system: Optional[str] = None, **kwargs) -> Optional[Any]`**

- Returns `None` if client not initialized [source:file:295-296]
- Builds message list with system message first (if provided), then user prompt [source:file:298-301]
- For GPT-5 and o1 models: uses `max_completion_tokens` instead of `max_tokens`, omits temperature parameter (fixed at 1.0) [source:file:312-316]
- For other models: uses standard `max_tokens` and respects temperature parameter [source:file:318-320]
- Calls `client.chat.completions.create()` with parameters [source:file:322]
- Wraps response via `_wrap_openai_response()` to match Claude-like interface [source:file:324-325]

#### Conversation

**`async create_conversation(messages: List[Dict[str, str]], *, model: str, max_tokens: int, temperature: float, **kwargs) -> Optional[Any]`**

- Returns `None` if client not initialized [source:file:337-338]
- Applies GPT-5/o1 model-specific parameters: `max_completion_tokens`, omitted temperature [source:file:349-352]
- Uses standard parameters for other models [source:file:354-356]
- Calls API and wraps response [source:file:358-360]

#### Response Wrapping

**`_wrap_openai_response(response)`**

- Creates a nested response object that mirrors Claude's API interface [source:file:362-387]
- Extracts message text from `response.choices[0].message.content` into a `WrappedContent` object [source:file:382]
- Normalizes token counts: OpenAI's `prompt_tokens` and `completion_tokens` are mapped to Claude's `input_tokens` and `output_tokens` respectively [source:file:374-375]
- Preserves original OpenAI attribute names for backward compatibility [source:file:377-378]
- Includes model name in response for logging [source:file:384]
- Stores raw OpenAI response for debugging [source:file:385]

#### Streaming

**`async create_message_stream(prompt: str, *, model: str, max_tokens: int, temperature: float, system: Optional[str] = None, **kwargs) -> AsyncGenerator[Dict[str, Any], None]`**

- Delegates to `GPT5StreamingClient` for NDJSON parsing and streaming support [source:file:399-451]
- Creates a `GPT5StreamingClient` instance with the OpenAI client and model parameters [source:file:427-433]
- Enforces temperature=1.0 for GPT-5/o1 models; uses provided temperature for others [source:file:430]
- Extracts context from kwargs: `recent_questions`, `recent_actions`, `session_id` [source:file:436-440]
- Uses system parameter or falls back to kwargs["system_prompt"] or default "You are a meeting intelligence assistant." [source:file:443]
- Streams intelligence detections via `streaming_client.stream_intelligence()` [source:file:446-450]
- Yields each parsed object from the stream [source:file:451]

---

## DeepSeek Provider Implementation

### `DeepSeekProviderClient(BaseProviderClient)`

**Purpose:** Implements DeepSeek API integration using OpenAI-compatible endpoints. [source:file:454-607]

#### Constructor and Initialization

**`__init__(api_key: str, settings: Settings)`**

- Stores API key and settings [source:file:457-460]

**`_initialize_client() -> Optional[AsyncOpenAI]`**

- Returns `None` if no API key [source:file:464-465]
- In development: creates AsyncOpenAI with base URL "<https://api.deepseek.com/v1>", disabled SSL verification, follow_redirects enabled, 30-second timeout [source:file:470-481]
- In production: same configuration but with SSL verification enabled [source:file:483-492]
- Logs and suppresses initialization errors [source:file:494-496]

#### Availability

**`is_available() -> bool`**

- Returns whether client is initialized [source:file:498-500]

#### Message Creation

**`async create_message(prompt: str, *, model: str, max_tokens: int, temperature: float, system: Optional[str] = None, **kwargs) -> Optional[Any]`**

- Returns `None` if client not initialized [source:file:513-514]
- Builds message list with optional system message, then user prompt [source:file:516-519]
- Calls `client.chat.completions.create()` with model, messages, max_tokens, temperature, and kwargs [source:file:521-527]
- Wraps response via `_wrap_deepseek_response()` [source:file:530]

#### Conversation

**`async create_conversation(messages: List[Dict[str, str]], *, model: str, max_tokens: int, temperature: float, **kwargs) -> Optional[Any]`**

- Returns `None` if client not initialized [source:file:542-543]
- Calls API with provided messages and parameters [source:file:545-551]
- Wraps response [source:file:553]

#### Response Wrapping

**`_wrap_deepseek_response(response)`**

- Logs an error and raises `ValueError` if response is a string (indicating API error) [source:file:558-560]
- Creates nested response objects matching Claude's interface [source:file:563-589]
- Extracts message content from `response.choices[0].message.content` [source:file:581]
- Normalizes token counts: `prompt_tokens` -> `input_tokens`, `completion_tokens` -> `output_tokens` [source:file:572-573]
- Preserves original attribute names for backward compatibility [source:file:575-576]
- Includes model name and raw response [source:file:583-584]
- Catches `AttributeError` and `IndexError`, logs details, and re-raises [source:file:585-587]

#### Streaming (Unimplemented)

**`async create_message_stream(...) -> AsyncGenerator[Any, None]`**

- Raises `NotImplementedError` as streaming is not supported [source:file:604-606]

---

## Provider Cascade (Fallback Management)

### `ProviderCascade`

**Purpose:** Manages intelligent fallback between primary and secondary LLM providers with circuit breaker support and error classification. [source:file:610-1010]

#### Constructor

**`__init__(primary_client: Optional[BaseProviderClient], primary_provider_name: str, fallback_client: Optional[BaseProviderClient], fallback_provider_name: str, settings: Settings)`**

- Stores references to primary and fallback clients with their display names [source:file:621-643]
- Initializes circuit breaker if enabled in settings and purgatory library is available [source:file:645-667]
- Sets circuit breaker threshold and timeout from settings [source:file:652-653]
- Logs warning if circuit breaker requested but purgatory library unavailable [source:file:664-667]

#### Model Translation

**`_translate_model_for_fallback(source_model: str) -> Optional[str]`**

- Determines the target provider type from the fallback client instance [source:file:679-688]
- Uses `get_equivalent_model()` to find a model equivalent in the target provider [source:file:691]
- Logs success with model mapping details [source:file:694-697]
- Logs warning and returns `None` if no equivalent found [source:file:699-703]

#### Fallback Execution

**`async _execute_fallback(operation: str, primary_model: str, fallback_reason: str, metadata: Dict[str, Any], **kwargs) -> tuple[Optional[Any], Dict[str, Any]]`**

- Logs fallback trigger with reason [source:file:733-736]
- Sets `metadata["fallback_triggered"] = True` and `metadata["fallback_reason"]` [source:file:737-738]
- Translates model to fallback provider equivalent; raises exception if translation fails [source:file:741-746]
- Updates metadata with translated model and provider name [source:file:748-749]
- Configures retry with max attempts from settings, exponential backoff, and jitter [source:file:755-766]
- Calls fallback provider's `create_message()` or `create_conversation()` based on operation [source:file:771-776]
- Records attempt metadata with success/failure status and error details [source:file:778-795]
- Applies retry mechanism and returns (response, updated_metadata) [source:file:802-803]

#### Cascading Execution with Error Classification

**`async execute_with_fallback(operation: str, primary_model: str, **kwargs) -> tuple[Optional[Any], Dict[str, Any]]`**

**Overall Strategy:** Try primary with limited retries; on overload (529/503) immediately fallback; on rate limit (429) retry with exponential backoff; on other errors re-raise. [source:file:813-827]

**Phase 1 - Primary Provider Attempt:**

- Initializes metadata tracking: provider_used, fallback_triggered, fallback_enabled, primary_model, attempts [source:file:838-844]
- Checks fallback availability: enabled, client exists, is available [source:file:847-851]
- Configures retry for rate limits and timeouts only (not overload) [source:file:860-871]
- Calls primary provider's operation method [source:file:876-881]
- Records successful attempt in metadata [source:file:883-887]
- Classifies errors by string matching:
  - "529" or "overloaded" or "503": raises `LLMOverloadedException` [source:file:894-904]
  - "429" or "rate_limit": raises `LLMRateLimitException` [source:file:906-914]
  - "timeout" or "504": raises `LLMTimeoutException` [source:file:916-924]
  - "401" or "unauthorized": raises `LLMAuthenticationException` [source:file:926-934]
  - Other errors: re-raises without classification [source:file:936-944]
- If circuit breaker enabled: wraps call in circuit breaker context; on `OpenedState` exception, logs and raises `LLMOverloadedException` [source:file:947-964]
- If no circuit breaker: executes with retry directly [source:file:965-967]

**Phase 2 - Fallback on Overload:**

- On `LLMOverloadedException`: checks fallback availability [source:file:969-975]
- Respects `settings.fallback_on_overload` configuration flag [source:file:977-982]
- Calls `_execute_fallback()` with "overloaded" reason [source:file:984-991]

**Phase 2 - Fallback on Rate Limit:**

- On `LLMRateLimitException`: checks if fallback enabled AND `settings.fallback_on_rate_limit` [source:file:993-1002]
- Calls `_execute_fallback()` if conditions met [source:file:996-1002]
- Re-raises rate limit exception if fallback not available [source:file:1004-1005]

**Phase 2 - Non-Retryable Errors:**

- On other exceptions: logs error and re-raises without fallback [source:file:1007-1010]

---

## Multi-Provider LLM Client

### `MultiProviderLLMClient`

**Purpose:** Top-level client that orchestrates multiple providers, manages organization-specific configurations via database integration, and provides a unified interface for LLM operations. [source:file:1013-1620]

#### Singleton Pattern

**`get_instance(settings: Optional[Settings] = None) -> MultiProviderLLMClient`** (classmethod)

- Returns cached singleton instance if available [source:file:1118-1119]
- Creates new instance on first call [source:file:1119]

**`reset_instance()`** (classmethod)

- Clears the singleton instance for testing purposes [source:file:1123-1125]

#### Constructor

**`__init__(settings: Optional[Settings] = None)`**

- Loads settings via `get_settings()` if not provided [source:file:1022-1024]
- Initializes empty providers dictionary [source:file:1027]
- Sets default organization ID to UUID "00000000-0000-0000-0000-000000000001" [source:file:1028]
- Initializes fallback configuration from settings (fallback_model, max_tokens, temperature) [source:file:1031-1034]
- Calls `_initialize_providers_from_env()` to set up primary and secondary providers [source:file:1042]
- Logs initialization summary [source:file:1044-1049]

#### Provider Initialization from Environment

**`_initialize_providers_from_env()`**

- Checks for API keys in settings: anthropic_api_key, openai_api_key, deepseek_api_key [source:file:1060-1062]
- Maps provider names ("claude", "openai", "deepseek") to configuration tuples [source:file:1065-1069]
- Initializes primary provider from `settings.primary_llm_provider` [source:file:1072-1093]
  - Creates client instance if API key available [source:file:1075-1076]
  - Sets primary_provider_name for logging [source:file:1077]
  - Stores in fallback_provider for backward compatibility [source:file:1078]
  - Logs failure if API key missing [source:file:1082]
  - Falls back to legacy Claude mode if provider name unknown [source:file:1084-1093]
- Initializes secondary provider if `settings.enable_llm_fallback` is True [source:file:1096-1109]
  - Skips if same as primary [source:file:1100, 1104]
  - Logs API key missing or unknown provider warnings [source:file:1107-1109]
- Logs error if primary provider initialization fails [source:file:1112-1113]

#### Availability and Configuration

**`is_available() -> bool`**

- Returns `True` if fallback_provider exists and is available [source:file:1127-1132]

**`get_model_info() -> Dict[str, Any]`**

- Returns dictionary with model, max_tokens, temperature, and availability status [source:file:1134-1144]

#### Active Provider Resolution

**`async get_active_provider(session: Optional[AsyncSession], organization_id: Optional[str] = None) -> tuple[Optional[BaseProviderClient], Optional[Dict[str, Any]]]`**

- Uses organization_id parameter or default_org_id [source:file:1156]
- If session provided: attempts to load AI_BRAIN integration from database [source:file:1159-1172]
  - Queries Integration table for organization with type=AI_BRAIN and status=CONNECTED [source:file:1163-1168]
  - Extracts provider and model from integration.custom_settings [source:file:1176-1178]
  - Validates provider enum; falls back to environment if invalid [source:file:1180-1184]
  - Decrypts API key from integration [source:file:1189]
  - Checks if provider cached in self.providers dictionary [source:file:1192-1193]
  - Creates new provider client if not cached [source:file:1196-1199]
  - Returns (provider_client, config_dict) with model, max_tokens, temperature, provider [source:file:1201-1209]
  - Catches all exceptions and falls back to environment [source:file:1211-1212]
- Falls back to environment variables if no session or integration query fails [source:file:1214-1223]
  - Returns fallback_provider with fallback configuration [source:file:1215-1223]
- Returns (None, None) if no provider available [source:file:1225-1226]

#### Provider Factory

**`_create_provider_client(provider: AIProvider, api_key: str) -> Optional[BaseProviderClient]`**

- Maps AIProvider enum to corresponding client class [source:file:1234-1239]
- Returns ClaudeProviderClient, OpenAIProviderClient, or DeepSeekProviderClient [source:file:1234-1239]
- Logs error and returns `None` for unknown providers [source:file:1241-1242]

#### Single Message Creation

**`async create_message(prompt: str, *, session: Optional[AsyncSession] = None, organization_id: Optional[str] = None, model: Optional[str] = None, max_tokens: Optional[int] = None, temperature: Optional[float] = None, system: Optional[str] = None, **kwargs) -> Optional[Any]`**

- Gets active provider via `get_active_provider()` if session provided; otherwise uses fallback [source:file:1264-1269]
- Returns `None` if no provider available [source:file:1271-1273]
- Resolves parameters from ai_config or fallback defaults [source:file:1276-1284]
- Determines provider name for logging [source:file:1287-1294]
- Creates `ProviderCascade` with primary and secondary clients [source:file:1297-1303]
- Executes operation via cascade.execute_with_fallback() [source:file:1306-1315]
- Logs warning if fallback was triggered [source:file:1318-1322]
- Records metrics: LLM request metrics via metrics.record_llm_request() [source:file:1336-1344]
- Calculates and records cost via business_metrics.record_llm_cost() if tokens available [source:file:1347-1359]
- Records org-level LLM cost via business_metrics.record_org_query() [source:file:1364-1368]
- Suppresses metric recording errors and logs warning [source:file:1369-1370]
- Returns response [source:file:1372]

#### Conversation Creation

**`async create_conversation(session: AsyncSession, messages: List[Dict[str, str]], *, organization_id: Optional[str] = None, model: Optional[str] = None, max_tokens: Optional[int] = None, temperature: Optional[float] = None, **kwargs) -> Optional[Any]`**

- Requires session parameter [source:file:1376]
- Gets active provider and configuration [source:file:1393]
- Returns `None` if no provider [source:file:1395-1397]
- Resolves parameters from ai_config or defaults [source:file:1400-1407]
- Determines provider name [source:file:1410-1417]
- Creates ProviderCascade and executes with fallback [source:file:1420-1437]
- Logs fallback events [source:file:1440-1444]
- Returns response [source:file:1446]

#### Streaming Message Creation

**`async create_message_stream(prompt: str, *, session: Optional[AsyncSession] = None, organization_id: Optional[str] = None, model: Optional[str] = None, max_tokens: Optional[int] = None, temperature: Optional[float] = None, system: Optional[str] = None, **kwargs) -> AsyncGenerator[Dict[str, Any], None]`**

- Gets active provider if session available; uses fallback otherwise [source:file:1482-1487]
- Raises `ValueError` if no provider available [source:file:1489-1491]
- Resolves model, max_tokens, temperature from config or defaults [source:file:1493-1501]
- Logs provider and model information [source:file:1504]
- Delegates to provider_client.create_message_stream() [source:file:1506-1514]
- Yields each object from streaming response [source:file:1514]

#### Configuration Testing

**`async test_configuration(provider: AIProvider, api_key: str, model: str) -> Dict[str, Any]`**

- Creates temporary provider client via `_create_provider_client()` [source:file:1529]
- Returns `{"success": False, "error": "..."}` if provider initialization fails [source:file:1531-1535]
- Calls provider's `create_message()` with minimal test prompt [source:file:1538-1543]
- Returns `{"success": True, "message": "Configuration test successful"}` if response received [source:file:1545-1549]
- Returns `{"success": False, "error": "No response from API"}` if no response [source:file:1551-1554]
- Catches exceptions and returns `{"success": False, "error": str(e)}` [source:file:1556-1560]

#### Model List

**`get_available_models(provider: AIProvider) -> List[str]`**

- Filters `MODEL_PROVIDER_MAP` by provider [source:file:1562-1567]
- Returns list of model value strings for the specified provider [source:file:1564-1566]

#### Health Check

**`async health_check(session: Optional[AsyncSession] = None, organization_id: Optional[str] = None) -> Dict[str, Any]`**

- Gets active provider configuration [source:file:1573]
- Returns `{"status": "unavailable", "reason": "No provider configured"}` if no provider [source:file:1575-1579]
- Resolves model from config or fallback [source:file:1583]
- Calls `provider_client.create_message()` with "Hello" test prompt [source:file:1587-1592]
- Returns `{"status": "healthy", "provider": provider, "model": model, "source": "integration"|"environment"}` on success [source:file:1595-1601]
- Returns `{"status": "error", "reason": error_message}` on failure [source:file:1603-1606]
- Catches exceptions and returns error status [source:file:1608-1612]

---

## Module-Level Functions

### `get_multi_llm_client(settings: Optional[Settings] = None) -> MultiProviderLLMClient`

- Returns the singleton `MultiProviderLLMClient` instance via `MultiProviderLLMClient.get_instance(settings)` [source:file:1616-1620]
- Convenience function for accessing the global client instance

---

## Key Design Patterns

1. **Circuit Breaker Pattern:** Integrated with optional purgatory library to prevent cascading failures [source:file:645-667, 947-964]

2. **Adapter Pattern:** Provider clients wrap different APIs (Anthropic, OpenAI, DeepSeek) behind a common interface [source:file:86-133]

3. **Response Normalization:** OpenAI and DeepSeek responses wrapped to match Claude's interface (token naming: prompt_tokens -> input_tokens) [source:file:362-387, 555-589]

4. **Singleton Pattern:** MultiProviderLLMClient uses singleton pattern for global client instance [source:file:1018-1125]

5. **Fallback/Cascade Pattern:** ProviderCascade implements intelligent error-based fallback with model translation [source:file:610-1010]

6. **Organization-First Resolution:** Prefers database integration configuration over environment variables [source:file:1146-1226]

7. **Error Classification and Routing:** Distinguishes between retryable (429, 504) and non-retryable (401) errors, and immediate-fallback errors (529, 503) [source:file:890-944]

---

## Configuration Dependencies

The module requires configuration through a `Settings` object with keys including:

- `api_env`: "development" or "production" (affects SSL verification)
- `primary_llm_provider`: Primary provider name
- `fallback_llm_provider`: Secondary provider name
- `enable_llm_fallback`: Boolean to enable fallback mechanism
- `fallback_on_overload`: Whether to fallback on 529/503 errors
- `fallback_on_rate_limit`: Whether to fallback on 429 errors
- `enable_circuit_breaker`: Whether to enable circuit breaker
- `circuit_breaker_failure_threshold`: Failure count before opening
- `circuit_breaker_timeout_seconds`: Duration to keep circuit open
- `primary_provider_max_retries`: Max retry attempts for primary
- `fallback_provider_max_retries`: Max retry attempts for fallback
- `anthropic_api_key`, `openai_api_key`, `deepseek_api_key`: Provider API keys
- `primary_llm_model`, `fallback_llm_model`: Default models per provider
- `max_tokens`: Default token limit
- `temperature`: Default temperature

[source:file:1020-1113]
