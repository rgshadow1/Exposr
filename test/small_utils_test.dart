import 'package:breach_checker/models/remediation.dart';
import 'package:breach_checker/utils/count_format.dart';
import 'package:breach_checker/utils/time_ago.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('timeAgo', () {
    final now = DateTime(2026, 10, 15, 12);

    test('under a minute is "just now"', () {
      expect(timeAgo(now.subtract(const Duration(seconds: 20)), now), 'just now');
    });

    test('a time in the future is "just now" rather than negative', () {
      expect(timeAgo(now.add(const Duration(minutes: 5)), now), 'just now');
    });

    test('minutes, hours and days', () {
      expect(timeAgo(now.subtract(const Duration(minutes: 5)), now), '5 min ago');
      expect(timeAgo(now.subtract(const Duration(hours: 3, minutes: 20)), now), '3 h ago');
      expect(timeAgo(now.subtract(const Duration(days: 2, hours: 5)), now), '2 d ago');
    });
  });

  group('formatCompact', () {
    test('leaves small numbers alone', () {
      expect(formatCompact(0), '0');
      expect(formatCompact(999), '999');
    });

    test('shortens thousands, millions and billions', () {
      expect(formatCompact(12000), '12K');
      expect(formatCompact(1500), '1.5K');
      expect(formatCompact(152445165), '152.4M');
      expect(formatCompact(3200000000), '3.2B');
    });
  });

  group('remediationTasksFor', () {
    test('is empty when there are no breaches', () {
      expect(remediationTasksFor(const []), isEmpty);
    });

    test('has a password task per breach, then the general advice', () {
      final tasks = remediationTasksFor(['Adobe', 'LinkedIn']);

      expect(tasks.map((t) => t.id), [
        'breach:adobe',
        'breach:linkedin',
        'unique-passwords',
        'two-factor',
        'phishing',
      ]);
      expect(tasks.first.title, 'Change your password on Adobe');
    });

    test('caps the per-breach tasks and says how many were left out', () {
      final names = [for (var i = 1; i <= 8; i++) 'Breach $i'];

      final tasks = remediationTasksFor(names);

      expect(tasks.where((t) => t.id.startsWith('breach:')), hasLength(5));
      expect(tasks.firstWhere((t) => t.id == 'more-breaches').title, 'Review the other 3 breaches');
    });

    test('ids are stable, so a ticked box stays ticked', () {
      expect(
        remediationTasksFor(['Adobe']).map((t) => t.id),
        remediationTasksFor(['Adobe']).map((t) => t.id),
      );
    });
  });
}
