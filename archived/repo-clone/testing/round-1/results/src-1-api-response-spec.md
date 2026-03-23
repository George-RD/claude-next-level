# Behavioral Spec: ApiResponse

**Source:** lib/core/models/api_response.dart
**Mode:** source

## Behaviors

### 1. ApiResponse Construction

**Description:** Constructs an API response data object with a required status field, an optional message field, and an optional key-value data payload. All fields are immutable after construction.
**Inputs:**

- `status` (required): A string representing the response status.
- `message` (optional): A string message providing additional context.
- `data` (optional): A key-value map of dynamic values for the response payload.
**Expected Output:** An immutable data object containing the provided fields.
**Side Effects:** None.
**Error Cases:** None.
**Citations:** [src:lib/core/models/api_response.dart:6-15]

### 2. ApiResponse Deserialization (fromJson)

**Description:** Creates an ApiResponse instance from a JSON-compatible key-value map. Uses @JsonSerializable code generation for mapping.
**Inputs:** A key-value map with string keys: must contain "status", may contain "message" and "data".
**Expected Output:** A fully populated ApiResponse instance with fields mapped from the input map.
**Side Effects:** None.
**Error Cases:** Missing required "status" key would cause a deserialization error.
**Citations:** [src:lib/core/models/api_response.dart:17-18]

### 3. ApiResponse Serialization (toJson)

**Description:** Converts an ApiResponse instance to a JSON-compatible key-value map suitable for network transmission or storage.
**Inputs:** An existing ApiResponse instance.
**Expected Output:** A key-value map containing "status", and optionally "message" and "data" fields.
**Side Effects:** None.
**Error Cases:** None.
**Citations:** [src:lib/core/models/api_response.dart:20]

### 4. HealthCheckResponse Construction

**Description:** Constructs a health check response data object with a required status field and a required services map describing the health state of each dependent service.
**Inputs:**

- `status` (required): A string representing the overall health status.
- `services` (required): A key-value map where keys are service names and values are their health details.
**Expected Output:** An immutable data object containing the provided fields.
**Side Effects:** None.
**Error Cases:** None.
**Citations:** [src:lib/core/models/api_response.dart:23-31]

### 5. HealthCheckResponse Deserialization (fromJson)

**Description:** Creates a HealthCheckResponse instance from a JSON-compatible key-value map. Uses @JsonSerializable code generation for mapping.
**Inputs:** A key-value map with string keys: must contain "status" and "services".
**Expected Output:** A fully populated HealthCheckResponse instance.
**Side Effects:** None.
**Error Cases:** Missing required keys would cause a deserialization error.
**Citations:** [src:lib/core/models/api_response.dart:33-34]

### 6. HealthCheckResponse Serialization (toJson)

**Description:** Converts a HealthCheckResponse instance to a JSON-compatible key-value map.
**Inputs:** An existing HealthCheckResponse instance.
**Expected Output:** A key-value map containing "status" and "services" fields.
**Side Effects:** None.
**Error Cases:** None.
**Citations:** [src:lib/core/models/api_response.dart:36]

## Internal Invariants

1. All fields on both classes are declared `final` — instances are immutable after construction.
2. ApiResponse's `message` and `data` fields are nullable; `status` is always required.
3. HealthCheckResponse's `status` and `services` fields are both required (non-nullable).
4. Both classes use generated code (`api_response.g.dart`) for JSON serialization — the `part` directive and `@JsonSerializable` annotation enforce this contract.

## Dependencies

- `json_annotation` package — provides `@JsonSerializable` annotation for code generation
- `api_response.g.dart` — generated serialization/deserialization code (via `build_runner`)
