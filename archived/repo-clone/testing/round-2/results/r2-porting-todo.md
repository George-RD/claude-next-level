# AuthRepository TypeScript Port — TODO List

**Source:** lib/features/auth/data/repositories/auth_repository.dart (Dart/Flutter)
**Target:** TypeScript implementation
**Date Created:** 2026-03-18

---

## Task 1: Define Core Types and Interfaces

**What to implement:**

- `AuthState` type — union/enum for authentication state transitions (login, logout, user changes)
- `User` interface — properties for authenticated user data
- `AuthResponse` interface — user data + session tokens
- `Session` interface — tokens (access, refresh) + validity metadata
- `PasswordResetRequest` type — for reset flow requests

**Covers Spec Behaviors:** 1 (stream auth state), 2 (get current user), 3 (sign in), 6 (refresh session)

**Citations:**

- [source:auth_repository.dart:28] — AuthState stream structure
- [source:auth_repository.dart:30] — User type for current user retrieval
- [source:auth_repository.dart:58-91] — AuthResponse structure from sign in
- [source:auth_repository.dart:130-142] — Session structure with tokens

---

## Task 2: Create AuthRepository Class with State Management

**What to implement:**

- Class declaration: `class AuthRepository`
- Private state field: `_authStateSubject` (RxJS `BehaviorSubject<AuthState>` or equivalent)
- Public getter: `authState$` — Observable/Stream returning `Observable<AuthState>`
- Private field: `_currentUser` — optional User, initialized to null
- Constructor — initialize state subject with initial state (unauthenticated)
- Dependency injection fields for: HTTP client, secure storage adapter, auth service

**Covers Spec Behaviors:** 1 (stream auth state setup), 2 (current user storage)

**Citations:**

- [source:auth_repository.dart:28] — Stream subscription setup and initialization

---

## Task 3: Implement getCurrentUser() Method

**What to implement:**

- Public method: `getCurrentUser(): User | null`
- Returns current authenticated user or null
- Non-blocking getter from internal `_currentUser` field

**Covers Spec Behaviors:** 2 (get current user)

**Citations:**

- [source:auth_repository.dart:30]

---

## Task 4: Implement signIn(email, password) Method

**What to implement:**

- Public async method: `signIn(email: string, password: string): Promise<AuthResponse>`
- Call HTTP endpoint with email and password
- **Error handling:** Catch credential errors and respond with unified message (same message for invalid email OR password to prevent user enumeration)
- **Success path:**
  - Persist session tokens to secure storage
  - Update internal `_currentUser` with returned user data
  - Emit `authenticated` state to `_authStateSubject`
  - Return `AuthResponse` (user + tokens)
- **Error path:** Throw/reject with sanitized error

**Covers Spec Behaviors:** 3 (sign in with email/password)

**Internal Invariants Applied:**

- Credential error masking — unified message for security

**Citations:**

- [source:auth_repository.dart:58-91] — Full sign in flow including credential validation and session establishment

---

## Task 5: Implement signOut() Method

**What to implement:**

- Public async method: `signOut(): Promise<void>`
- Clear session tokens from secure storage
- Clear internal `_currentUser` (set to null)
- Emit `unauthenticated` state to `_authStateSubject`
- Handle errors gracefully (don't throw if storage clear fails)

**Covers Spec Behaviors:** 4 (sign out)

**Citations:**

- [source:auth_repository.dart:93-102] — Session termination and state cleanup

---

## Task 6: Implement resetPassword(email) Method

**What to implement:**

- Public async method: `resetPassword(email: string): Promise<void>`
- Call HTTP endpoint to request password reset
- Email should include reset link with app scheme redirect (e.g., `myapp://reset?token=...`)
- **Error handling:** Throw/reject on API failure (can expose email-not-found for password reset)
- No state changes to auth state (user remains in current auth state)

**Covers Spec Behaviors:** 5 (password reset)

**Citations:**

- [source:auth_repository.dart:104-115] — Password reset email flow with app scheme

---

## Task 7: Implement refreshSession() Method

**What to implement:**

- Public async method: `refreshSession(): Promise<Session | null>`
- Call HTTP endpoint with refresh token to obtain new access token
- **Success path:**
  - Persist renewed session to secure storage
  - Return updated `Session` object with new tokens
- **Failure path:**
  - Do NOT throw — return null
  - Clear persisted session state (important: prevent stale token reuse)
  - Emit `unauthenticated` state to `_authStateSubject`
- Handles case where refresh token is expired or invalid

**Covers Spec Behaviors:** 6 (session refresh)

**Internal Invariants Applied:**

- Session recovery always clears persisted state on any error to prevent stale token reuse

**Citations:**

- [source:auth_repository.dart:130-142] — Token refresh with null return on failure and state clearing

---

## Task 8: Implement Session Persistence Layer

**What to implement:**

- Private method: `_persistSession(session: Session): Promise<void>`
  - Serialize and store session tokens to secure storage (OS-level keychain/keystore equivalent)
  - Handle storage errors gracefully
- Private method: `_retrieveSession(): Promise<Session | null>`
  - Deserialize and retrieve session from secure storage
  - Return null if not found or corrupted
- Private method: `_clearSession(): Promise<void>`
  - Remove all persisted session data
  - Idempotent (safe to call multiple times)

**Covers Spec Behaviors:** 3 (persist on sign in), 4 (clear on sign out), 6 (persist refreshed session, clear on failure)

**Citations:**

- [source:auth_repository.dart:58-91] — Secure storage persistence on sign in
- [source:auth_repository.dart:93-102] — Session clearing on sign out
- [source:auth_repository.dart:130-142] — Refresh token persistence and error-state clearing

---

## Task 9: Add Session Recovery/Restore Flow (Optional Enhancement)

**What to implement:**

- Public async method: `restoreSession(): Promise<void>` — called on app startup
- Retrieve persisted session from storage
- If found and valid: emit `authenticated` state, restore `_currentUser` from token claims or backend fetch
- If found but invalid/expired: attempt `refreshSession()`
  - If refresh succeeds: restore with new tokens
  - If refresh fails: clear state and emit `unauthenticated`
- If not found: emit `unauthenticated`

**Covers Spec Behaviors:** 1 (state recovery), 6 (refresh on restore failure)

**Internal Invariants Applied:**

- Session recovery always clears persisted state on any error

**Citations:**

- [source:auth_repository.dart:130-142] — Error handling on refresh (clear state instead of throwing)

---

## Task 10: Add HTTP Error Translation

**What to implement:**

- Private method: `_translateAuthError(error: any): AuthError`
  - Map HTTP status codes to domain errors (401, 403, 422 for credentials, 5xx for server, etc.)
  - For credential errors (422): return unified "Invalid email or password" message
  - For network errors: return "Network error" or similar
  - Preserve other error types (server errors, etc.)

**Covers Spec Behaviors:** 3 (sign in error handling), 5 (reset password error handling)

**Internal Invariants Applied:**

- Credential error masking — same message for email vs password failures

**Citations:**

- [source:auth_repository.dart:58-91] — Credential error unification

---

## Task 11: Add Integration Tests

**What to implement:**

- Test `signIn` success path (credentials valid, tokens persisted, state emitted)
- Test `signIn` error path (invalid email, invalid password — both return same error message)
- Test `getCurrentUser` (returns user after sign in, null after sign out)
- Test `signOut` (clears session, emits unauthenticated)
- Test `refreshSession` success (returns new tokens, persists)
- Test `refreshSession` failure (returns null, clears persisted state, emits unauthenticated)
- Test `resetPassword` (sends email, doesn't change auth state)
- Test state stream (emits on login, logout, user changes)

**Covers Spec Behaviors:** All (1-6)

**Citations:**

- [source:auth_repository.dart:28-142] — All public methods

---

## Implementation Order (Recommended)

1. Task 1 — Type definitions (foundation)
2. Task 2 — AuthRepository class + state setup
3. Task 8 — Session persistence (blocking dependency for all flow methods)
4. Task 3 — getCurrentUser (simple getter)
5. Task 4 — signIn (core auth flow)
6. Task 5 — signOut (core auth flow)
7. Task 6 — resetPassword (independent flow)
8. Task 7 — refreshSession (depends on persistence layer)
9. Task 9 — Session recovery (depends on refresh + signIn logic)
10. Task 10 — HTTP error translation (supports all error paths)
11. Task 11 — Integration tests

---

## Key Implementation Notes

### Error Handling Strategy

- **signIn**: Throw on credential errors (unified message) or auth exceptions
- **signOut**: Never throw (best effort clearing)
- **refreshSession**: Never throw — return null on any failure
- **resetPassword**: Throw on API failures

### Security Considerations

- All tokens stored in OS-level secure storage (not localStorage/memory)
- Credential errors must use identical messages to prevent user enumeration
- Session refresh on failure must clear stale tokens (critical invariant)
- Never expose refresh token in logs or error messages

### State Management Pattern

- RxJS BehaviorSubject or equivalent async generator for authState$
- Single source of truth for auth state (the Subject)
- All state changes go through Subject to maintain consistency
- Subscribers get immediate state on subscription (BehaviorSubject semantics)

---

**Next Steps:** Implementation agent will use this TODO list to port each task with the citations as reference points to the original Dart implementation.
