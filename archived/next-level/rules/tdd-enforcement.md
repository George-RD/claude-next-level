# TDD Enforcement

- Write a failing test BEFORE writing implementation code — always
- Follow the RED → GREEN → REFACTOR cycle strictly
- RED: Write a test that fails for the right reason
- GREEN: Write the MINIMAL code to make the test pass — nothing more
- REFACTOR: Clean up while keeping all tests green
- Never skip tests "to save time" or "just this once"
- If editing an implementation file, check that a corresponding test file exists
- If no test file exists, create one first with a failing test
- Run tests after every change — don't batch
- Test behavior, not implementation details
