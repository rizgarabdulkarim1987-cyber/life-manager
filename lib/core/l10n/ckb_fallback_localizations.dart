import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../l10n/gen/app_localizations.dart';

export '../../l10n/gen/app_localizations.dart';

const kDefaultLocale = Locale('ar');
const kSupportedLocales = [Locale('ar'), Locale('en'), Locale('ckb')];

/// Flutter ships no Material/Cupertino/Widgets strings for Kurdish Sorani
/// (`ckb`). Sorani is written right-to-left in Arabic script, so it borrows
/// the Arabic framework strings and RTL direction; our own strings come from
/// app_ckb.arb.
const _fallback = Locale('ar');

bool _isCkb(Locale l) => l.languageCode == 'ckb';

class CkbMaterialLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const CkbMaterialLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => _isCkb(locale);
  @override
  Future<MaterialLocalizations> load(Locale locale) => GlobalMaterialLocalizations.delegate.load(_fallback);
  @override
  bool shouldReload(CkbMaterialLocalizationsDelegate old) => false;
}

class CkbCupertinoLocalizationsDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const CkbCupertinoLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => _isCkb(locale);
  @override
  Future<CupertinoLocalizations> load(Locale locale) => GlobalCupertinoLocalizations.delegate.load(_fallback);
  @override
  bool shouldReload(CkbCupertinoLocalizationsDelegate old) => false;
}

class CkbWidgetsLocalizationsDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const CkbWidgetsLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => _isCkb(locale);
  @override
  Future<WidgetsLocalizations> load(Locale locale) => GlobalWidgetsLocalizations.delegate.load(_fallback);
  @override
  bool shouldReload(CkbWidgetsLocalizationsDelegate old) => false;
}

const List<LocalizationsDelegate<Object>> appLocalizationDelegates = [
  AppLocalizations.delegate,
  CkbMaterialLocalizationsDelegate(),
  CkbCupertinoLocalizationsDelegate(),
  CkbWidgetsLocalizationsDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
