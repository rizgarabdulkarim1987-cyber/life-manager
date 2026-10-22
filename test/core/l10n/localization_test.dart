import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/l10n/ckb_fallback_localizations.dart';

void main() {
  Future<(TextDirection, String)> render(WidgetTester t, Locale l) async {
    late TextDirection d;
    late String home;
    await t.pumpWidget(MaterialApp(
      locale: l,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      home: Builder(builder: (c) {
        d = Directionality.of(c);
        home = c.l10n.navHome;
        // Touch a Material string so a missing Material delegate would throw.
        MaterialLocalizations.of(c).okButtonLabel;
        return const SizedBox();
      }),
    ));
    return (d, home);
  }

  testWidgets('ar is RTL with Arabic strings', (t) async {
    final (d, home) = await render(t, const Locale('ar'));
    expect(d, TextDirection.rtl);
    expect(home, 'الرئيسية');
  });

  testWidgets('ckb is RTL and loads material strings', (t) async {
    final (d, home) = await render(t, const Locale('ckb'));
    expect(d, TextDirection.rtl);
    expect(home, isNotEmpty);
    expect(t.takeException(), isNull);
  });

  testWidgets('en is LTR', (t) async {
    final (d, home) = await render(t, const Locale('en'));
    expect(d, TextDirection.ltr);
    expect(home, 'Home');
  });

  test('default locale is Arabic', () {
    expect(kDefaultLocale, const Locale('ar'));
  });

  test('every locale has every key', () {
    Set<String> keys(String code) {
      final m = jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync()) as Map<String, dynamic>;
      return m.keys.where((k) => !k.startsWith('@')).toSet();
    }

    final en = keys('en');
    expect(keys('ar'), en);
    expect(keys('ckb'), en);
  });
}
