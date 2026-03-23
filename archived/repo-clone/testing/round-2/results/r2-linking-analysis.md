# Round 2 Linking Test Result

## Test Setup

- **Test Spec (#4):** SIGNIN_SCREEN_SPEC.md (UI test behaviors for signin_screen_test.dart)
- **Source Spec (#5):** AUTH_REPOSITORY_SPEC.md (auth_repository.dart source behaviors)
- **Model:** Claude Haiku
- **Duration:** 28 seconds
- **Output:** Returned inline (not written to file)

---

## Strong Direct Correspondences

These test behaviors directly exercise specific source behaviors:

| Test Spec Behavior | Source Spec Behavior | Relationship |
|---|---|---|
| "Submitting valid credentials navigates to home" | Behavior 3: signIn(email, password) success path | Test verifies the UI flow that triggers signIn, expects navigation on success |
| "Submitting invalid credentials shows error message" | Behavior 3: signIn error handling + credential error masking | Test verifies the UI displays a unified error message (same for wrong email or wrong password) |
| "Shows loading indicator during sign-in" | Behavior 3: signIn async execution | Test verifies UI state during the async signIn call |
| "Password reset link triggers reset flow" | Behavior 5: resetPassword(email) | Test verifies the UI action that calls resetPassword |

## Indirect/Layered Correspondences

These test behaviors depend on source behaviors but through an abstraction layer (ViewModel/Cubit):

| Test Spec Behavior | Source Spec Behavior | Layer Between |
|---|---|---|
| "Already-authenticated user is redirected" | Behavior 1: authState stream + Behavior 2: getCurrentUser | UI checks auth state on screen load; state comes from repository stream |
| "Sign-in button is disabled when fields empty" | (No direct source behavior) | Pure UI validation — does not reach repository layer |
| "Email field validates format" | (No direct source behavior) | Pure UI validation — repository never sees invalid-format emails |

## What a Porting Agent Would Need

To port the signin_screen tests to TypeScript, an agent would need:

1. **The test spec** to know WHAT to test (UI behaviors)
2. **The source spec** to know what the underlying auth repository provides (the contract being tested against)
3. **The correspondence mapping** (this analysis) to know which source behaviors to mock/stub in the test

### Mock Requirements Derived from Linking

- Mock `signIn(email, password)` — must simulate success (return AuthResponse) and failure (throw with unified error message)
- Mock `resetPassword(email)` — must simulate success (resolve void)
- Mock `authState$` stream — must emit authenticated/unauthenticated states
- Mock `getCurrentUser()` — must return User or null

### Key Insight

The linking test demonstrated that semantic correspondence works without any explicit tagging scheme. The agent matched test behaviors to source behaviors by understanding what each behavior describes, not by following citation links. This means the citation format does not need cross-spec reference tags — the behavioral descriptions themselves are sufficient for an agent to discover the relationships.
