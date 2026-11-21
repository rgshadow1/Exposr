import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/breach.dart';

/// How the stored passwords of a breach are described, in words.
String passwordRiskLabel(PasswordRisk risk) {
  return switch (risk) {
    PasswordRisk.plaintext => 'Stored as plain text',
    PasswordRisk.easyToCrack => 'Easy to crack',
    PasswordRisk.hardToCrack => 'Hard to crack',
    PasswordRisk.unknown => 'Not stated',
  };
}

/// The colour that goes with [passwordRiskLabel]. It is always shown beside
/// the words, never instead of them.
Color passwordRiskColor(PasswordRisk risk) {
  return switch (risk) {
    PasswordRisk.plaintext => AppColors.danger,
    PasswordRisk.easyToCrack => AppColors.warning,
    PasswordRisk.hardToCrack => AppColors.accent,
    PasswordRisk.unknown => AppColors.textMuted,
  };
}

/// Whether a kind of exposed data ("Passwords", "Password hints") is about
/// passwords, the item most worth noticing in a breach.
bool mentionsPasswords(String dataType) => dataType.toLowerCase().contains('password');
