# Behavioral Spec: AuthRepository

**Source:** lib/features/auth/data/repositories/auth_repository.dart
**Mode:** source

## Behaviors

### 1. Repository Construction

**Description:** Constructs the auth repository by initializing a connection to the authentication backend service. The client is obtained from a shared configuration singleton.
**Inputs:** None (uses global configuration).
**Expected Output:** A repository instance ready to perform authentication operations.
**Side Effects:** Establishes a reference to the authentication backend client.
**Error Cases:** None at construction time.
**Citations:** [src:lib/features/auth/data/repositories/auth_repository.dart:23-26]

### 2. Auth State Stream

**Description:** Provides a reactive stream of authentication state changes. Callers can subscribe to be notified when the user signs in, signs out, or their session changes.
**Inputs:** None.
**Expected Output:** A continuous stream of auth state events.
**Side Effects:** None (read-only observation of auth state).
**Error Cases:** None.
**Citations:** [src:lib/features/auth/data/repositories/auth_repository.dart:28]

### 3. Get Current User

**Description:** Returns the currently authenticated user, or null if no user is signed in.
**Inputs:** None.
**Expected Output:** The current user object or null.
**Side Effects:** None.
**Error Cases:** None.
**Citations:** [src:lib/features/auth/data/repositories/auth_repository.dart:30]

### 4. Get Current Session

**Description:** Returns the current authentication session, or null if no active session exists.
**Inputs:** None.
**Expected Output:** The current session object or null.
**Side Effects:** None.
**Error Cases:** None.
**Citations:** [src:lib/features/auth/data/repositories/auth_repository.dart:32]

### 5. Sign Up

**Description:** Registers a new user account with email, password, and optional metadata. On success, persists the session for future use.
**Inputs:**

- `email` (required): The user's email address.
- `password` (required): The user's chosen password.
- `metadata` (optional): Additional key-value data to attach to the user profile.
**Expected Output:** An auth response containing the new user and session information.
**Side Effects:** Creates a new user account in the auth backend; persists the session locally if one is returned.
**Error Cases:**
- Auth-specific exceptions are caught and re-mapped via `_handleAuthException` (400: invalid email/password, 422: email already registered, 429: rate limited).
- Unexpected exceptions are wrapped as "An unexpected error occurred during sign up".
**Citations:** [src:lib/features/auth/data/repositories/auth_repository.dart:34-56]

### 6. Sign In

**Description:** Authenticates an existing user with email and password. On success, persists the session. Provides enhanced error messaging for invalid credentials without revealing whether the email exists.
**Inputs:**

- `email` (required): The user's email address.
- `password` (required): The user's password.
**Expected Output:** An auth response containing the authenticated user and session.
**Side Effects:** Authenticates against the backend; persists the session locally if successful.
**Error Cases:**
- Invalid credentials (wrong password, non-existent user): throws a specific "Invalid email or password" error. The error message is deliberately generic to avoid revealing whether the email exists (security measure).
- Other auth exceptions are mapped via `_handleAuthException`.
- Unexpected exceptions are wrapped as "An unexpected error occurred during sign in".
**Citations:** [src:lib/features/auth/data/repositories/auth_repository.dart:58-91]

### 7. Sign Out

**Description:** Signs the current user out and clears the persisted session.
**Inputs:** None.
**Expected Output:** None (void).
**Side Effects:** Signs out from the auth backend; clears the locally persisted session.
**Error Cases:**

- Auth exceptions mapped via `_handleAuthException`.
- Unexpected exceptions wrapped as "An unexpected error occurred during sign out".
**Citations:** [src:lib/features/auth/data/repositories/auth_repository.dart:93-102]

### 8. Reset Password

**Description:** Sends a password reset email to the specified address. Includes a deep link redirect URL for the reset flow.
**Inputs:**

- `email` (required): The email address to send the reset link to.
**Expected Output:** None (void). The reset email is sent asynchronously by the backend.
**Side Effects:** Triggers a password reset email from the auth backend.
**Error Cases:**
- Auth exceptions mapped via `_handleAuthException`.
- Unexpected exceptions wrapped as "An unexpected error occurred during password reset".
**Citations:** [src:lib/features/auth/data/repositories/auth_repository.dart:104-115]

### 9. Update Password

**Description:** Updates the current user's password to a new value. Requires an active authenticated session.
**Inputs:**

- `newPassword` (required): The new password to set.
**Expected Output:** A user response containing the updated user data.
**Side Effects:** Updates the password in the auth backend.
**Error Cases:**
- Auth exceptions mapped via `_handleAuthException`.
- Unexpected exceptions wrapped as "An unexpected error occurred during password update".
**Citations:** [src:lib/features/auth/data/repositories/auth_repository.dart:117-128]

### 10. Refresh Session

**Description:** Refreshes the current authentication session to extend its validity. Persists the new session if successful.
**Inputs:** None.
**Expected Output:** The refreshed session object, or null if refresh fails due to a non-auth error.
**Side Effects:** Refreshes the session with the auth backend; persists the new session locally.
**Error Cases:**

- Auth exceptions are thrown via `_handleAuthException`.
- Non-auth exceptions silently return null (graceful degradation).
**Citations:** [src:lib/features/auth/data/repositories/auth_repository.dart:130-142]

### 11. Update Profile

**Description:** Updates the current user's profile information including email, phone, and custom metadata.
**Inputs:**

- `email` (optional): New email address.
- `phone` (optional): New phone number.
- `data` (optional): Additional key-value metadata.
**Expected Output:** A user response containing the updated user data.
**Side Effects:** Updates the user profile in the auth backend.
**Error Cases:**
- Auth exceptions mapped via `_handleAuthException`.
- Unexpected exceptions wrapped as "An unexpected error occurred during profile update".
**Citations:** [src:lib/features/auth/data/repositories/auth_repository.dart:144-163]

### 12. Verify OTP

**Description:** Verifies a one-time password sent to the user's email for email verification purposes.
**Inputs:**

- `email` (required): The email address the OTP was sent to.
- `token` (required): The OTP code to verify.
**Expected Output:** None (void). Successful verification updates the user's email verification status.
**Side Effects:** Verifies the OTP with the auth backend; marks email as verified on success.
**Error Cases:**
- Auth exceptions mapped via `_handleAuthException`.
- Unexpected exceptions wrapped as "An unexpected error occurred during OTP verification".
**Citations:** [src:lib/features/auth/data/repositories/auth_repository.dart:165-180]

## Internal Invariants

1. All auth-backend-specific exceptions are caught and remapped to generic exceptions, preventing implementation details from leaking to callers.
2. Sign-in credential errors are deliberately made generic ("Invalid email or password") regardless of whether the email exists or the password is wrong — this is a security invariant to prevent user enumeration.
3. Session persistence is performed after every successful sign-up, sign-in, and session refresh.
4. The `_handleAuthException` method maps HTTP status codes to user-friendly messages: 400 (invalid input), 422 (duplicate email), 429 (rate limiting).
5. The `recoverSession` method never throws — it always returns null and clears the session on any error, preventing stale token issues.

## Dependencies

- `supabase_flutter` — Supabase authentication client SDK
- `SupabaseConfig` — Application configuration providing the Supabase client instance and session persistence methods
