# Behavioral Spec: SignInScreen

**Source:** test/widget/screens/auth/signin_screen_test.dart
**Mode:** test

## Behaviors

### 1. Display UI Elements

**Description:** The sign-in screen renders all required user interface elements for authentication: an app icon, a welcome heading, email and password input fields, a remember-me checkbox, and a sign-in submit button.
**Inputs:** The sign-in screen is rendered with a mock authentication repository.
**Expected Output:**

- An outlined hub icon is displayed
- "Welcome back" text is displayed
- "Email" label is displayed
- "Password" label is displayed
- A checkbox is displayed
- A filled button with text "Sign In" is displayed
**Error Cases:** None.
**Citations:** [test:test/widget/screens/auth/signin_screen_test.dart:20-51]

### 2. Validate Email Format

**Description:** When the user submits the sign-in form with an invalid email format, the screen displays a validation error message. The validation is triggered on form submission, not on field change.
**Inputs:** User enters "invalid-email" in the email field and taps the Sign In button.
**Expected Output:** A validation message "Please enter a valid email address" is displayed.
**Error Cases:** Invalid email format triggers a validation error displayed inline.
**Citations:** [test:test/widget/screens/auth/signin_screen_test.dart:53-82]

### 3. Toggle Password Visibility

**Description:** The sign-in screen provides a toggle button to show/hide the password field contents. Initially the password is obscured (visibility_outlined icon shown); tapping the toggle switches to visible mode (visibility_off_outlined icon shown).
**Inputs:** User taps the visibility toggle icon button.
**Expected Output:**

- Initially: a visibility_outlined icon is present
- After tap: the icon changes to visibility_off_outlined
**Error Cases:** None.
**Citations:** [test:test/widget/screens/auth/signin_screen_test.dart:84-112]

### 4. Successfully Sign In

**Description:** When the user enters valid credentials (email and password) and submits the form, the screen invokes the authentication service with the provided credentials exactly once.
**Inputs:**

- Email field: "<test@example.com>"
- Password field: "password123"
- Mock auth repository configured to return a successful auth result
**Expected Output:** The authentication service's sign-in method is called exactly once with the provided email and password.
**Error Cases:** None tested in this behavior (only the happy path is verified).
**Citations:** [test:test/widget/screens/auth/signin_screen_test.dart:114-152]
