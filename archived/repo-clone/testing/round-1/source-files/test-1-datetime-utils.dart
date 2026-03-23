import 'package:flutter_test/flutter_test.dart';
import 'package:pm_master_v2/core/utils/datetime_utils.dart';

void main() {
  group('DateTimeUtils', () {
    group('parseUtcToLocal', () {
      test('parses valid UTC datetime string', () {
        final result = DateTimeUtils.parseUtcToLocal('2024-01-15T10:30:00Z');
        expect(result, isNotNull);
        expect(result!.year, 2024);
        expect(result.month, 1);
        expect(result.day, 15);
      });

      test('parses UTC datetime without Z suffix', () {
        final result = DateTimeUtils.parseUtcToLocal('2024-01-15T10:30:00');
        expect(result, isNotNull);
        expect(result!.year, 2024);
        expect(result.month, 1);
        expect(result.day, 15);
      });

      test('converts UTC to local time', () {
        final result = DateTimeUtils.parseUtcToLocal('2024-01-15T10:30:00Z');
        expect(result, isNotNull);
        expect(result!.isUtc, false);
      });

      test('returns null for null input', () {
        final result = DateTimeUtils.parseUtcToLocal(null);
        expect(result, isNull);
      });

      test('returns null for invalid datetime string', () {
        final result = DateTimeUtils.parseUtcToLocal('invalid date');
        expect(result, isNull);
      });

      test('returns null for empty string', () {
        final result = DateTimeUtils.parseUtcToLocal('');
        expect(result, isNull);
      });

      test('parses datetime with milliseconds', () {
        final result = DateTimeUtils.parseUtcToLocal('2024-01-15T10:30:00.123Z');
        expect(result, isNotNull);
        expect(result!.year, 2024);
      });
    });

    group('parseUtcToLocalRequired', () {
      test('parses valid UTC datetime string', () {
        final result = DateTimeUtils.parseUtcToLocalRequired('2024-01-15T10:30:00Z');
        expect(result.year, 2024);
        expect(result.month, 1);
        expect(result.day, 15);
        expect(result.isUtc, false);
      });

      test('parses UTC datetime without Z suffix', () {
        final result = DateTimeUtils.parseUtcToLocalRequired('2024-01-15T10:30:00');
        expect(result.year, 2024);
        expect(result.month, 1);
        expect(result.day, 15);
      });

      test('throws on invalid datetime string', () {
        expect(
          () => DateTimeUtils.parseUtcToLocalRequired('invalid date'),
          throwsFormatException,
        );
      });

      test('parses datetime with milliseconds', () {
        final result = DateTimeUtils.parseUtcToLocalRequired('2024-01-15T10:30:00.999Z');
        expect(result.year, 2024);
        expect(result.millisecond, 999);
      });
    });

    group('formatDate', () {
      test('formats date correctly', () {
        final dateTime = DateTime(2024, 1, 15, 10, 30);
        final result = DateTimeUtils.formatDate(dateTime);
        expect(result, 'Jan 15, 2024');
      });

      test('converts UTC to local before formatting', () {
        final dateTime = DateTime.utc(2024, 1, 15, 10, 30);
        final result = DateTimeUtils.formatDate(dateTime);
        expect(result, isNotEmpty);
        expect(result, contains('2024'));
      });

      test('formats date with single digit day', () {
        final dateTime = DateTime(2024, 1, 5, 10, 30);
        final result = DateTimeUtils.formatDate(dateTime);
        expect(result, 'Jan 05, 2024');
      });

      test('formats date with different months', () {
        expect(DateTimeUtils.formatDate(DateTime(2024, 1, 15)), 'Jan 15, 2024');
        expect(DateTimeUtils.formatDate(DateTime(2024, 6, 15)), 'Jun 15, 2024');
        expect(DateTimeUtils.formatDate(DateTime(2024, 12, 31)), 'Dec 31, 2024');
      });
    });

    group('formatTime', () {
      test('formats time correctly in 24-hour format', () {
        final dateTime = DateTime(2024, 1, 15, 14, 30);
        final result = DateTimeUtils.formatTime(dateTime);
        expect(result, '14:30');
      });

      test('formats time with leading zeros', () {
        final dateTime = DateTime(2024, 1, 15, 9, 5);
        final result = DateTimeUtils.formatTime(dateTime);
        expect(result, '09:05');
      });

      test('converts UTC to local before formatting', () {
        final dateTime = DateTime.utc(2024, 1, 15, 10, 30);
        final result = DateTimeUtils.formatTime(dateTime);
        expect(result, matches(r'\d{2}:\d{2}'));
      });

      test('formats midnight correctly', () {
        final dateTime = DateTime(2024, 1, 15, 0, 0);
        final result = DateTimeUtils.formatTime(dateTime);
        expect(result, '00:00');
      });

      test('formats noon correctly', () {
        final dateTime = DateTime(2024, 1, 15, 12, 0);
        final result = DateTimeUtils.formatTime(dateTime);
        expect(result, '12:00');
      });
    });

    group('formatDateTime', () {
      test('formats datetime correctly', () {
        final dateTime = DateTime(2024, 1, 15, 14, 30);
        final result = DateTimeUtils.formatDateTime(dateTime);
        expect(result, 'Jan 15, 2024 • 14:30');
      });

      test('converts UTC to local before formatting', () {
        final dateTime = DateTime.utc(2024, 1, 15, 10, 30);
        final result = DateTimeUtils.formatDateTime(dateTime);
        expect(result, contains('2024'));
        expect(result, contains('•'));
      });

      test('formats datetime with single digit day', () {
        final dateTime = DateTime(2024, 1, 5, 9, 5);
        final result = DateTimeUtils.formatDateTime(dateTime);
        expect(result, 'Jan 5, 2024 • 09:05');
      });
    });

    group('formatDateTimeShort', () {
      test('formats short datetime correctly', () {
        final dateTime = DateTime(2024, 1, 15, 14, 30);
        final result = DateTimeUtils.formatDateTimeShort(dateTime);
        expect(result, 'Jan 15, 14:30');
      });

      test('converts UTC to local before formatting', () {
        final dateTime = DateTime.utc(2024, 1, 15, 10, 30);
        final result = DateTimeUtils.formatDateTimeShort(dateTime);
        expect(result, contains('Jan'));
        expect(result, matches(r'\d{2}:\d{2}'));
      });

      test('formats without year', () {
        final dateTime = DateTime(2024, 6, 20, 16, 45);
        final result = DateTimeUtils.formatDateTimeShort(dateTime);
        expect(result, 'Jun 20, 16:45');
        expect(result, isNot(contains('2024')));
      });
    });

    group('formatTimeAgo', () {
      test('returns "Just now" for times less than 60 seconds ago', () {
        final now = DateTime.now();
        final dateTime = now.subtract(const Duration(seconds: 30));
        final result = DateTimeUtils.formatTimeAgo(dateTime);
        expect(result, 'Just now');
      });

      test('returns minutes ago for times less than 1 hour', () {
        final now = DateTime.now();
        final dateTime = now.subtract(const Duration(minutes: 15));
        final result = DateTimeUtils.formatTimeAgo(dateTime);
        expect(result, '15m ago');
      });

      test('returns hours ago for times less than 24 hours', () {
        final now = DateTime.now();
        final dateTime = now.subtract(const Duration(hours: 5));
        final result = DateTimeUtils.formatTimeAgo(dateTime);
        expect(result, '5h ago');
      });

      test('returns days ago for times less than 7 days', () {
        final now = DateTime.now();
        final dateTime = now.subtract(const Duration(days: 3));
        final result = DateTimeUtils.formatTimeAgo(dateTime);
        expect(result, '3d ago');
      });

      test('returns formatted date for times more than 7 days ago', () {
        final now = DateTime.now();
        final dateTime = now.subtract(const Duration(days: 10));
        final result = DateTimeUtils.formatTimeAgo(dateTime);
        expect(result, isNot(contains('ago')));
        expect(result, matches(r'\w{3} \d{2}, \d{4}'));
      });

      test('handles UTC datetime', () {
        final now = DateTime.now();
        final dateTime = now.toUtc().subtract(const Duration(minutes: 30));
        final result = DateTimeUtils.formatTimeAgo(dateTime);
        expect(result, contains('ago'));
      });

      test('returns "Just now" for exact current time', () {
        final dateTime = DateTime.now();
        final result = DateTimeUtils.formatTimeAgo(dateTime);
        expect(result, 'Just now');
      });

      test('handles edge case at 59 seconds', () {
        final now = DateTime.now();
        final dateTime = now.subtract(const Duration(seconds: 59));
        final result = DateTimeUtils.formatTimeAgo(dateTime);
        expect(result, 'Just now');
      });

      test('handles edge case at 60 seconds', () {
        final now = DateTime.now();
        final dateTime = now.subtract(const Duration(seconds: 60));
        final result = DateTimeUtils.formatTimeAgo(dateTime);
        expect(result, '1m ago');
      });
    });

    group('formatRelativeTime', () {
      test('returns "Today at" for current day', () {
        final now = DateTime.now();
        final dateTime = DateTime(now.year, now.month, now.day, 10, 30);
        final result = DateTimeUtils.formatRelativeTime(dateTime);
        expect(result, startsWith('Today at'));
        expect(result, contains('10:30'));
      });

      test('returns "Yesterday at" for previous day', () {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        final dateTime = DateTime(yesterday.year, yesterday.month, yesterday.day, 15, 45);
        final result = DateTimeUtils.formatRelativeTime(dateTime);
        expect(result, startsWith('Yesterday at'));
        expect(result, contains('15:45'));
      });

      test('returns days ago for times less than 7 days', () {
        final now = DateTime.now();
        final dateTime = now.subtract(const Duration(days: 3));
        final result = DateTimeUtils.formatRelativeTime(dateTime);
        expect(result, matches(r'\d+d ago at \d{2}:\d{2}'));
      });

      test('returns formatted date with time for times more than 7 days ago', () {
        final now = DateTime.now();
        final dateTime = now.subtract(const Duration(days: 10));
        final result = DateTimeUtils.formatRelativeTime(dateTime);
        expect(result, contains('at'));
        expect(result, matches(r'\w{3} \d{2}, \d{4} at \d{2}:\d{2}'));
      });

      test('handles UTC datetime', () {
        final now = DateTime.now();
        final dateTime = DateTime.utc(now.year, now.month, now.day, 10, 30);
        final result = DateTimeUtils.formatRelativeTime(dateTime);
        expect(result, startsWith('Today at'));
      });

      test('handles midnight edge case', () {
        final now = DateTime.now();
        final dateTime = DateTime(now.year, now.month, now.day, 0, 0);
        final result = DateTimeUtils.formatRelativeTime(dateTime);
        expect(result, startsWith('Today at'));
        expect(result, contains('00:00'));
      });
    });

    group('toIsoString', () {
      test('converts local datetime to ISO string', () {
        final dateTime = DateTime(2024, 1, 15, 10, 30, 45);
        final result = DateTimeUtils.toIsoString(dateTime);
        expect(result, contains('2024-01-15'));
        expect(result, endsWith('Z'));
      });

      test('converts UTC datetime to ISO string', () {
        final dateTime = DateTime.utc(2024, 1, 15, 10, 30, 45);
        final result = DateTimeUtils.toIsoString(dateTime);
        expect(result, '2024-01-15T10:30:45.000Z');
      });

      test('includes milliseconds in ISO string', () {
        final dateTime = DateTime.utc(2024, 1, 15, 10, 30, 45, 123);
        final result = DateTimeUtils.toIsoString(dateTime);
        expect(result, '2024-01-15T10:30:45.123Z');
      });

      test('always returns UTC time', () {
        final dateTime = DateTime(2024, 1, 15, 10, 30);
        final result = DateTimeUtils.toIsoString(dateTime);
        expect(result, endsWith('Z'));
      });
    });

    group('ensureLocal', () {
      test('converts UTC datetime to local', () {
        final dateTime = DateTime.utc(2024, 1, 15, 10, 30);
        final result = DateTimeUtils.ensureLocal(dateTime);
        expect(result.isUtc, false);
        expect(result.year, 2024);
        expect(result.month, 1);
        expect(result.day, 15);
      });

      test('returns local datetime unchanged', () {
        final dateTime = DateTime(2024, 1, 15, 10, 30);
        final result = DateTimeUtils.ensureLocal(dateTime);
        expect(result.isUtc, false);
        expect(result, dateTime);
      });

      test('preserves milliseconds when converting', () {
        final dateTime = DateTime.utc(2024, 1, 15, 10, 30, 45, 999);
        final result = DateTimeUtils.ensureLocal(dateTime);
        expect(result.isUtc, false);
        expect(result.millisecond, 999);
      });
    });

    group('edge cases', () {
      test('handles leap year dates', () {
        final dateTime = DateTime(2024, 2, 29, 10, 30);
        expect(DateTimeUtils.formatDate(dateTime), 'Feb 29, 2024');
        expect(DateTimeUtils.toIsoString(dateTime), contains('2024-02-29'));
      });

      test('handles year boundary', () {
        final dateTime = DateTime(2023, 12, 31, 23, 59);
        expect(DateTimeUtils.formatDate(dateTime), 'Dec 31, 2023');
        expect(DateTimeUtils.formatTime(dateTime), '23:59');
      });

      test('handles very old dates', () {
        final dateTime = DateTime(1900, 1, 1, 0, 0);
        expect(DateTimeUtils.formatDate(dateTime), 'Jan 01, 1900');
      });

      test('handles far future dates', () {
        final dateTime = DateTime(2100, 12, 31, 23, 59);
        expect(DateTimeUtils.formatDate(dateTime), 'Dec 31, 2100');
      });
    });
  });
}
