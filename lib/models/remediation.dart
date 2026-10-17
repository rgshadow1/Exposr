/// One thing a person can do to recover from a breach.
class RemediationTask {
  const RemediationTask({required this.id, required this.title, required this.detail});

  /// Stable, so a ticked box stays ticked: built from the breach name or a fixed word.
  final String id;
  final String title;
  final String detail;
}

/// The checklist for an address found in [breachNames].
///
/// One "change your password" task per breach (the first [maxBreachTasks], so a
/// very long list doesn't bury the rest), then the general advice that applies
/// whichever breaches they were. Empty when there are no breaches.
List<RemediationTask> remediationTasksFor(List<String> breachNames, {int maxBreachTasks = 5}) {
  if (breachNames.isEmpty) return const [];

  final shown = breachNames.take(maxBreachTasks).toList();
  final hidden = breachNames.length - shown.length;

  return [
    for (final name in shown)
      RemediationTask(
        id: 'breach:${name.toLowerCase()}',
        title: 'Change your password on $name',
        detail: 'Then change it anywhere else you used the same one.',
      ),
    if (hidden > 0)
      RemediationTask(
        id: 'more-breaches',
        title: 'Review the other $hidden ${hidden == 1 ? 'breach' : 'breaches'}',
        detail: 'Open Insights after checking this address on Home to see them all.',
      ),
    const RemediationTask(
      id: 'unique-passwords',
      title: 'Use a different password for every account',
      detail: 'A password manager makes this practical.',
    ),
    const RemediationTask(
      id: 'two-factor',
      title: 'Turn on two-factor authentication',
      detail: 'An authenticator app is safer than text messages where it is offered.',
    ),
    const RemediationTask(
      id: 'phishing',
      title: 'Be wary of messages that mention these services',
      detail: 'Breached details are often used to make scam emails look genuine.',
    ),
  ];
}
