# DateTimeUtils Behavioral Specification

This document specifies the behavior of the `DateTimeUtils` utility class, which provides date and time formatting, parsing, and manipulation capabilities for the tellmemo application.

## Overview

`DateTimeUtils` provides a set of static methods for working with DateTime objects. The utility handles UTC-to-local conversions, various formatting options, relative time display, and ISO string serialization.

---

## parseUtcToLocal

The `parseUtcToLocal` method parses UTC datetime strings and converts them to local time, returning a nullable DateTime object.

### Specification

**Accepts Valid UTC Datetime String (ISO 8601 with Z suffix)**
The method shall parse a valid ISO 8601 formatted UTC datetime string with Z suffix and return a non-null DateTime object with correct date components. [test:parseUtcToLocal:7-13]

**Accepts Datetime String Without Z Suffix**
The method shall parse an ISO 8601 formatted datetime string without the Z suffix and return a non-null DateTime object with correct date components. [test:parseUtcToLocal:15-21]

**Converts UTC to Local Time**
The method shall convert the parsed UTC datetime to local time, indicated by `isUtc` property being false. [test:parseUtcToLocal:23-27]

**Returns Null for Null Input**
The method shall return null when passed a null input value. [test:parseUtcToLocal:29-32]

**Returns Null for Invalid Datetime String**
The method shall return null when given an unparseable string that does not conform to datetime format. [test:parseUtcToLocal:34-37]

**Returns Null for Empty String**
The method shall return null when given an empty string. [test:parseUtcToLocal:39-42]

**Accepts Datetime With Milliseconds**
The method shall parse ISO 8601 formatted datetime strings that include millisecond precision and return a non-null DateTime object. [test:parseUtcToLocal:44-48]

---

## parseUtcToLocalRequired

The `parseUtcToLocalRequired` method parses UTC datetime strings and converts them to local time, raising an exception for invalid input.

### Specification

**Parses Valid UTC Datetime String**
The method shall parse a valid ISO 8601 formatted UTC datetime string and return a non-null DateTime object with correct date components that is in local time (isUtc false). [test:parseUtcToLocalRequired:52-58]

**Accepts Datetime String Without Z Suffix**
The method shall parse an ISO 8601 formatted datetime string without the Z suffix and return a DateTime object with correct date components. [test:parseUtcToLocalRequired:60-65]

**Throws FormatException on Invalid Input**
The method shall raise a FormatException when given an unparseable string. [test:parseUtcToLocalRequired:67-72]

**Accepts Datetime With Milliseconds**
The method shall parse ISO 8601 formatted datetime strings that include millisecond precision and preserve the milliseconds in the returned DateTime object. [test:parseUtcToLocalRequired:74-78]

---

## formatDate

The `formatDate` method formats a DateTime object as a date string in the format "MMM DD, YYYY".

### Specification

**Formats Date Correctly**
The method shall format a DateTime object as a date string in the format "MMM DD, YYYY" (e.g., "Jan 15, 2024"). [test:formatDate:82-86]

**Converts UTC to Local Before Formatting**
The method shall convert UTC DateTime objects to local time before formatting, resulting in a non-empty string containing the year. [test:formatDate:88-93]

**Formats Date With Single Digit Day**
The method shall pad single-digit days with a leading zero (e.g., January 5th becomes "Jan 05, 2024"). [test:formatDate:95-99]

**Formats Date With Different Months**
The method shall correctly format dates across all months of the year, using three-letter month abbreviations. [test:formatDate:101-105]

---

## formatTime

The `formatTime` method formats a DateTime object as a time string in 24-hour format "HH:MM".

### Specification

**Formats Time Correctly in 24-Hour Format**
The method shall format a DateTime object as a time string in 24-hour format "HH:MM" (e.g., "14:30"). [test:formatTime:109-113]

**Formats Time With Leading Zeros**
The method shall pad single-digit hours and minutes with leading zeros (e.g., 9:05 becomes "09:05"). [test:formatTime:115-119]

**Converts UTC to Local Before Formatting**
The method shall convert UTC DateTime objects to local time before formatting, resulting in a string matching the time format pattern. [test:formatTime:121-125]

**Formats Midnight Correctly**
The method shall format midnight (00:00) correctly as "00:00". [test:formatTime:127-131]

**Formats Noon Correctly**
The method shall format noon (12:00) correctly as "12:00". [test:formatTime:133-137]

---

## formatDateTime

The `formatDateTime` method formats a DateTime object as a combined date and time string.

### Specification

**Formats DateTime Correctly**
The method shall format a DateTime object as a combined date and time string in the format "MMM DD, YYYY • HH:MM" (e.g., "Jan 15, 2024 • 14:30"). [test:formatDateTime:141-145]

**Converts UTC to Local Before Formatting**
The method shall convert UTC DateTime objects to local time before formatting, resulting in a string containing both the year and the separator bullet character. [test:formatDateTime:147-152]

**Formats DateTime With Single Digit Day**
The method shall format single-digit days without leading zeros in the date portion while maintaining proper time formatting (e.g., "Jan 5, 2024 • 09:05"). [test:formatDateTime:154-158]

---

## formatDateTimeShort

The `formatDateTimeShort` method formats a DateTime object as a compact date and time string without the year.

### Specification

**Formats Short DateTime Correctly**
The method shall format a DateTime object as a short date-time string in the format "MMM DD, HH:MM" (e.g., "Jan 15, 14:30"). [test:formatDateTimeShort:162-166]

**Converts UTC to Local Before Formatting**
The method shall convert UTC DateTime objects to local time before formatting, resulting in a string containing the month abbreviation and time. [test:formatDateTimeShort:168-173]

**Formats Without Year**
The method shall format the date-time string without including the year component. [test:formatDateTimeShort:175-180]

---

## formatTimeAgo

The `formatTimeAgo` method formats a DateTime object as a relative time representation (e.g., "5m ago", "3d ago").

### Specification

**Returns "Just now" for Times Less Than 60 Seconds Ago**
The method shall return the string "Just now" for datetimes within 60 seconds of the current time. [test:formatTimeAgo:184-189]

**Returns Minutes Ago for Times Less Than 1 Hour**
The method shall return a string in the format "Nm ago" for datetimes that occurred less than 1 hour ago (e.g., "15m ago"). [test:formatTimeAgo:191-196]

**Returns Hours Ago for Times Less Than 24 Hours**
The method shall return a string in the format "Nh ago" for datetimes that occurred less than 24 hours ago (e.g., "5h ago"). [test:formatTimeAgo:198-203]

**Returns Days Ago for Times Less Than 7 Days**
The method shall return a string in the format "Nd ago" for datetimes that occurred less than 7 days ago (e.g., "3d ago"). [test:formatTimeAgo:205-210]

**Returns Formatted Date for Times More Than 7 Days Ago**
The method shall return a formatted date string (e.g., "Jan 10, 2024") for datetimes that occurred more than 7 days ago, not containing the "ago" suffix. [test:formatTimeAgo:212-218]

**Handles UTC Datetime**
The method shall correctly process UTC DateTime objects and return a relative time string containing "ago". [test:formatTimeAgo:220-225]

**Returns "Just now" for Exact Current Time**
The method shall return "Just now" when the input datetime equals the current time. [test:formatTimeAgo:227-231]

**Handles Edge Case at 59 Seconds**
The method shall return "Just now" for a datetime 59 seconds in the past. [test:formatTimeAgo:233-238]

**Handles Edge Case at 60 Seconds**
The method shall return "1m ago" for a datetime exactly 60 seconds in the past. [test:formatTimeAgo:240-245]

---

## formatRelativeTime

The `formatRelativeTime` method formats a DateTime object as a relative description with time of day (e.g., "Today at 10:30", "Yesterday at 15:45").

### Specification

**Returns "Today at" for Current Day**
The method shall return a string starting with "Today at" followed by the time in 24-hour format for datetimes on the current date. [test:formatRelativeTime:249-255]

**Returns "Yesterday at" for Previous Day**
The method shall return a string starting with "Yesterday at" followed by the time in 24-hour format for datetimes on the previous calendar day. [test:formatRelativeTime:257-264]

**Returns Days Ago for Times Less Than 7 Days**
The method shall return a string in the format "Nd ago at HH:MM" for datetimes between 2 and 7 days ago. [test:formatRelativeTime:266-271]

**Returns Formatted Date With Time for Times More Than 7 Days Ago**
The method shall return a string in the format "MMM DD, YYYY at HH:MM" for datetimes more than 7 days ago. [test:formatRelativeTime:273-279]

**Handles UTC Datetime**
The method shall correctly process UTC DateTime objects and return a relative time string starting with "Today at" when applicable. [test:formatRelativeTime:281-286]

**Handles Midnight Edge Case**
The method shall correctly format datetimes at midnight (00:00) on the current day, returning a string starting with "Today at" and containing "00:00". [test:formatRelativeTime:288-294]

---

## toIsoString

The `toIsoString` method converts a DateTime object to an ISO 8601 formatted UTC string.

### Specification

**Converts Local Datetime to ISO String**
The method shall convert a local DateTime object to an ISO 8601 formatted string and append the Z suffix to indicate UTC. [test:toIsoString:298-303]

**Converts UTC Datetime to ISO String**
The method shall convert a UTC DateTime object to an ISO 8601 formatted string in the format "YYYY-MM-DDTHH:MM:SS.sssZ" (e.g., "2024-01-15T10:30:45.000Z"). [test:toIsoString:305-309]

**Includes Milliseconds in ISO String**
The method shall include millisecond precision in the ISO string output (e.g., "2024-01-15T10:30:45.123Z"). [test:toIsoString:311-315]

**Always Returns UTC Time**
The method shall always return an ISO string that ends with the Z suffix, indicating UTC time regardless of input timezone. [test:toIsoString:317-321]

---

## ensureLocal

The `ensureLocal` method ensures a DateTime object is in local time, converting from UTC if necessary.

### Specification

**Converts UTC Datetime to Local**
The method shall convert a UTC DateTime object to local time, indicated by `isUtc` property being false, while preserving date and time values. [test:ensureLocal:325-332]

**Returns Local Datetime Unchanged**
The method shall return a local DateTime object unchanged without conversion. [test:ensureLocal:334-339]

**Preserves Milliseconds When Converting**
The method shall preserve the millisecond component when converting from UTC to local time. [test:ensureLocal:341-346]

---

## Edge Cases

### Specification

**Handles Leap Year Dates**
The utility methods shall correctly handle dates on February 29th in leap years (e.g., 2024-02-29). [test:edge_cases:350-354]

**Handles Year Boundary**
The utility methods shall correctly handle dates at the end of a calendar year (e.g., 2023-12-31 at 23:59). [test:edge_cases:356-360]

**Handles Very Old Dates**
The utility methods shall correctly handle dates from historical periods (e.g., 1900-01-01). [test:edge_cases:362-365]

**Handles Far Future Dates**
The utility methods shall correctly handle dates in the distant future (e.g., 2100-12-31). [test:edge_cases:367-370]
