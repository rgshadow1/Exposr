# Breach Checker

Phone app (Flutter) to check emails against known data breaches and test password strength.

## Setup

1. Install Flutter and run `flutter doctor`.
2. In an empty folder run `flutter create breach_checker`, then copy this project's `lib/` and `pubspec.yaml` over the generated ones (this gives you the android/ios folders).
3. Run `flutter pub get`.
4. Run `flutter run`.

## Build order

1. `core/app_colors.dart`, `core/app_theme.dart`
2. `widgets/section_card.dart`, `widgets/stat_card.dart`
3. `screens/home_shell.dart` + empty screens
4. `widgets/charts/*` with fake data
5. `services/breach_api_service.dart`, then replace fake data with real results
