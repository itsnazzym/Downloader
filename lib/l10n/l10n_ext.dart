import 'package:flutter/widgets.dart';
import 'app_localizations.dart';

extension AppL10nX on BuildContext {
  AppLocalizations get l10n {
    return AppLocalizations.of(this) ??
        lookupAppLocalizations(const Locale('en'));
  }
}
