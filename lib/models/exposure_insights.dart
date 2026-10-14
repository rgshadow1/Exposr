import 'breach.dart';



class ExposureInsights {
  const ExposureInsights({required this.totalBreaches, required this.totalRecords, required this.latestYear, required this.breachesPerYear, required this.dataTypeCounts, required this.passwordRiskCounts});

  final int totalBreaches;
  final int totalRecords;
  final int? latestYear;

  final Map<int, int> breachesPerYear;
  final Map<String, int> dataTypeCounts;
  final Map<PasswordRisk, int> passwordRiskCounts;

  factory ExposureInsights.fromBreaches(List<Breach> breaches) {
    final totalBreaches = breaches.length;
    final totalRecords = breaches.fold<int>(0, (sum, breach) => sum + (breach.records ?? 0));

    final breachesPerYear = <int, int>{};
    int? latestYear;
    for (final breach in breaches) {
      final year = breach.year;
      if (year != null) {
        breachesPerYear[year] = (breachesPerYear[year] ?? 0) + 1;
        if (latestYear == null || year > latestYear) {
          latestYear = year;
        }
      }
    }

    final dataTypeCounts = <String, int>{};
    for (final breach in breaches) {
      for (final dataType in breach.exposedData) {
        dataTypeCounts[dataType] = (dataTypeCounts[dataType] ?? 0) + 1;
      }
    }

    final passwordRiskCounts = <PasswordRisk, int>{};
    for (final breach in breaches) {
      passwordRiskCounts[breach.passwordRisk] = (passwordRiskCounts[breach.passwordRisk] ?? 0) + 1;
    }

    return ExposureInsights(
      totalBreaches: totalBreaches,
      totalRecords: totalRecords,
      latestYear: latestYear,
      breachesPerYear: breachesPerYear,
      dataTypeCounts: dataTypeCounts,
      passwordRiskCounts: passwordRiskCounts,
    );
  }


}
