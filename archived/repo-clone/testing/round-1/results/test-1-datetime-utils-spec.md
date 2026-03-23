# Behavioral Spec: DateTimeUtils

**Source:** test/core/utils/datetime_utils_test.dart
**Mode:** test

## Behaviors

### 1. parseUtcToLocal

**Description:** Parses a UTC datetime string and converts it to local time. Returns an optional value — null for invalid/empty/null inputs, a valid local datetime for valid inputs.
**Inputs:** A string representing a UTC datetime (with or without "Z" suffix, with or without milliseconds), null, empty string, or an invalid string.
**Expected Output:**

- Valid UTC string with Z suffix: returns a local datetime with correct year/month/day, isUtc is false
- Valid UTC string without Z suffix: returns a local datetime with correct year/month/day
- Valid UTC string with milliseconds: returns a local datetime with correct year
- Null input: returns null
- Invalid string: returns null
- Empty string: returns null
**Error Cases:** None (returns null for invalid inputs instead of throwing).
**Citations:** [test:test/core/utils/datetime_utils_test.dart:7-48]

### 2. parseUtcToLocalRequired

**Description:** Parses a UTC datetime string and converts it to local time. Unlike the optional variant, this throws on invalid input rather than returning null.
**Inputs:** A string representing a UTC datetime (with or without Z suffix, with or without milliseconds), or an invalid string.
**Expected Output:**

- Valid UTC string with Z suffix: returns a local datetime with correct year/month/day, isUtc is false
- Valid UTC string without Z suffix: returns a local datetime with correct year/month/day
- Valid UTC string with milliseconds: returns a local datetime with correct year and millisecond values
- Invalid string: throws a format exception
**Error Cases:** Throws format exception for invalid datetime strings.
**Citations:** [test:test/core/utils/datetime_utils_test.dart:51-79]

### 3. formatDate

**Description:** Formats a datetime value into a human-readable date string in "MMM DD, YYYY" format. Converts UTC inputs to local time before formatting.
**Inputs:** A datetime value (local or UTC).
**Expected Output:**

- Local datetime (Jan 15, 2024): returns "Jan 15, 2024"
- UTC datetime: returns a non-empty string containing the year
- Single-digit day (Jan 5): returns "Jan 05, 2024" (zero-padded)
- Different months: correctly abbreviates month names (Jan, Jun, Dec)
**Error Cases:** None.
**Citations:** [test:test/core/utils/datetime_utils_test.dart:81-106]

### 4. formatTime

**Description:** Formats a datetime value into a 24-hour time string in "HH:MM" format. Converts UTC inputs to local time before formatting.
**Inputs:** A datetime value (local or UTC).
**Expected Output:**

- Afternoon time (14:30): returns "14:30"
- Single-digit hour/minute (9:05): returns "09:05" (zero-padded)
- UTC datetime: returns a string matching HH:MM pattern
- Midnight (0:00): returns "00:00"
- Noon (12:00): returns "12:00"
**Error Cases:** None.
**Citations:** [test:test/core/utils/datetime_utils_test.dart:108-138]

### 5. formatDateTime

**Description:** Formats a datetime value into a combined date-time string in "MMM D, YYYY - HH:MM" format with a bullet separator. Converts UTC to local before formatting.
**Inputs:** A datetime value (local or UTC).
**Expected Output:**

- Local datetime (Jan 15, 2024 14:30): returns "Jan 15, 2024 - 14:30" (with bullet separator)
- UTC datetime: returns a string containing the year and bullet separator
- Single-digit day (Jan 5, 09:05): returns "Jan 5, 2024 - 09:05"
**Error Cases:** None.
**Citations:** [test:test/core/utils/datetime_utils_test.dart:140-159]

### 6. formatDateTimeShort

**Description:** Formats a datetime value into a short date-time string without the year, in "MMM DD, HH:MM" format. Converts UTC to local before formatting.
**Inputs:** A datetime value (local or UTC).
**Expected Output:**

- Local datetime (Jan 15, 14:30): returns "Jan 15, 14:30"
- UTC datetime: returns a string containing month abbreviation and HH:MM pattern
- Omits the year from the output (verified: "2024" not present in result)
**Error Cases:** None.
**Citations:** [test:test/core/utils/datetime_utils_test.dart:161-181]

### 7. formatTimeAgo — "Just now" threshold

**Description:** Returns a relative time description. Times less than 60 seconds ago (including exactly 0 seconds and 59 seconds) return "Just now".
**Inputs:** A datetime 0-59 seconds before the current time.
**Expected Output:** "Just now"
**Error Cases:** None.
**Citations:** [test:test/core/utils/datetime_utils_test.dart:184-238]

### 8. formatTimeAgo — minutes ago

**Description:** Returns a relative time description in minutes for times between 1 and 59 minutes ago.
**Inputs:** A datetime 1-59 minutes before the current time.
**Expected Output:** "{N}m ago" (e.g., "15m ago", "1m ago")
**Error Cases:** None.
**Citations:** [test:test/core/utils/datetime_utils_test.dart:191-196, 240-245]

### 9. formatTimeAgo — hours ago

**Description:** Returns a relative time description in hours for times between 1 and 23 hours ago.
**Inputs:** A datetime 1-23 hours before the current time.
**Expected Output:** "{N}h ago" (e.g., "5h ago")
**Error Cases:** None.
**Citations:** [test:test/core/utils/datetime_utils_test.dart:198-203]

### 10. formatTimeAgo — days ago

**Description:** Returns a relative time description in days for times between 1 and 6 days ago.
**Inputs:** A datetime 1-6 days before the current time.
**Expected Output:** "{N}d ago" (e.g., "3d ago")
**Error Cases:** None.
**Citations:** [test:test/core/utils/datetime_utils_test.dart:205-210]

### 11. formatTimeAgo — formatted date fallback

**Description:** Returns a full formatted date (MMM DD, YYYY) for times more than 7 days ago, instead of a relative description.
**Inputs:** A datetime more than 7 days before the current time.
**Expected Output:** A date string matching "MMM DD, YYYY" pattern, without "ago" in the output.
**Error Cases:** None.
**Citations:** [test:test/core/utils/datetime_utils_test.dart:212-218]

### 12. formatRelativeTime

**Description:** Returns a relative time description with time-of-day context. Uses "Today at HH:MM" for same-day, "Yesterday at HH:MM" for previous day, "{N}d ago at HH:MM" for 2-6 days, and "MMM DD, YYYY at HH:MM" for 7+ days. Handles UTC inputs by converting to local first.
**Inputs:** A datetime value (local or UTC).
**Expected Output:**

- Same day: "Today at HH:MM"
- Previous day: "Yesterday at HH:MM"
- 2-6 days ago: "{N}d ago at HH:MM"
- 7+ days ago: "MMM DD, YYYY at HH:MM"
- Midnight edge case: "Today at 00:00"
- UTC input: correctly converts and returns "Today at" prefix
**Error Cases:** None.
**Citations:** [test:test/core/utils/datetime_utils_test.dart:248-294]

### 13. toIsoString

**Description:** Converts a datetime value to an ISO 8601 string in UTC, always ending with "Z". Local datetimes are converted to UTC before serialization.
**Inputs:** A datetime value (local or UTC), with or without milliseconds.
**Expected Output:**

- Local datetime: an ISO string containing the date, ending with "Z"
- UTC datetime (2024-01-15 10:30:45): returns "2024-01-15T10:30:45.000Z"
- UTC datetime with milliseconds (123): returns "2024-01-15T10:30:45.123Z"
- Always returns a UTC string (ends with "Z")
**Error Cases:** None.
**Citations:** [test:test/core/utils/datetime_utils_test.dart:297-322]

### 14. ensureLocal and Edge Cases

**Description:** Converts a UTC datetime to local time if needed, preserving all fields. If already local, returns unchanged. Also verifies that formatting functions handle edge cases: leap year dates, year boundaries, very old dates (1900), and far future dates (2100).
**Inputs:**

- ensureLocal: A UTC or local datetime with optional milliseconds
- Edge cases: leap year (Feb 29, 2024), year boundary (Dec 31, 2023 23:59), old date (Jan 1, 1900), future date (Dec 31, 2100)
**Expected Output:**
- UTC datetime: returns local datetime with isUtc false, same year/month/day, preserved milliseconds
- Local datetime: returns the same datetime unchanged
- Leap year: formats as "Feb 29, 2024", ISO string contains "2024-02-29"
- Year boundary: formats as "Dec 31, 2023", time as "23:59"
- Very old date: formats as "Jan 01, 1900"
- Far future date: formats as "Dec 31, 2100"
**Error Cases:** None.
**Citations:** [test:test/core/utils/datetime_utils_test.dart:324-371]
