import 'package:breach_checker/models/breach.dart';
import 'package:breach_checker/models/exposure_insights.dart';
import 'package:flutter_test/flutter_test.dart';

/// A short way to build a Breach for a test: only say what the test cares about.
Breach breach(
  String name, {
  String? date,
  int? records,
  List<String> data = const [],
  PasswordRisk risk = PasswordRisk.unknown,
}) {
  return Breach(
    name: name,
    date: date,
    records: records,
    exposedData: data,
    passwordRisk: risk,
  );
}

void main() {
  group('ExposureInsights.fromBreaches', () {
    test('an empty list gives zeros and empty maps', () {
      final insights = ExposureInsights.fromBreaches(const []);

      expect(insights.totalBreaches, 0);
      expect(insights.totalRecords, 0);
      expect(insights.latestYear, isNull);
      expect(insights.breachesPerYear, isEmpty);
      expect(insights.dataTypeCounts, isEmpty);
      expect(insights.passwordRiskCounts, isEmpty);
    });

    test('counts breaches and adds up records, ignoring unknown sizes', () {
      final insights = ExposureInsights.fromBreaches([
        breach('A', records: 100),
        breach('B', records: 250),
        breach('C'), // size unknown: counts as a breach, adds nothing
      ]);

      expect(insights.totalBreaches, 3);
      expect(insights.totalRecords, 350);
    });

    test('groups breaches by year and skips ones with no usable year', () {
      final insights = ExposureInsights.fromBreaches([
        breach('A', date: '2013'),
        breach('B', date: '2013-10-04'),
        breach('C', date: '2020'),
        breach('D'), // no date at all
        breach('E', date: 'unknown'), // a date we can't read
      ]);

      expect(insights.breachesPerYear, {2013: 2, 2020: 1});
      // Skipped for the timeline, but still counted as breaches.
      expect(insights.totalBreaches, 5);
    });

    test('latestYear is the newest year, or null when no breach has one', () {
      final withYears = ExposureInsights.fromBreaches([
        breach('A', date: '2013'),
        breach('B', date: '2020'),
        breach('C', date: '2016'),
      ]);
      final withoutYears = ExposureInsights.fromBreaches([breach('A')]);

      expect(withYears.latestYear, 2020);
      expect(withoutYears.latestYear, isNull);
    });

    test('counts each kind of exposed data across all breaches', () {
      final insights = ExposureInsights.fromBreaches([
        breach('A', data: ['Email addresses', 'Passwords']),
        breach('B', data: ['Email addresses']),
        breach('C', data: ['Phone numbers']),
      ]);

      expect(insights.dataTypeCounts, {
        'Email addresses': 2,
        'Passwords': 1,
        'Phone numbers': 1,
      });
    });

    test('counts breaches by password risk, only for risks that occur', () {
      final insights = ExposureInsights.fromBreaches([
        breach('A', risk: PasswordRisk.plaintext),
        breach('B', risk: PasswordRisk.plaintext),
        breach('C', risk: PasswordRisk.easyToCrack),
        breach('D', risk: PasswordRisk.none),
      ]);

      // No entry at all for hardToCrack or unknown: they never appeared.
      expect(insights.passwordRiskCounts, {
        PasswordRisk.plaintext: 2,
        PasswordRisk.easyToCrack: 1,
        PasswordRisk.none: 1,
      });
    });
  });
}
