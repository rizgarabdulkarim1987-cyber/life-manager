import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/l10n/ckb_fallback_localizations.dart';
import 'package:life_manager/core/money/money.dart';
import 'package:life_manager/core/security/money_privacy.dart';
import 'package:life_manager/core/theme/app_theme.dart';
import 'package:life_manager/features/finance/ui/widgets/money_text.dart';

Future<ProviderContainer> _pump(WidgetTester t, Widget child) async {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  await t.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: buildAppTheme(Brightness.light),
        locale: const Locale('en'),
        supportedLocales: kSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: Scaffold(
          appBar: AppBar(actions: const [RevealMoneyButton()]),
          body: child,
        ),
      ),
    ),
  );
  return c;
}

void main() {
  testWidgets('MoneyText hides digits by default', (t) async {
    await _pump(t, const MoneyText(Money(25000, 'IQD')));
    expect(find.text(kMaskedMoney), findsOneWidget);
    expect(find.textContaining('25'), findsNothing);
  });

  testWidgets('alwaysShow shows the amount', (t) async {
    await _pump(t, const MoneyText(Money(25000, 'IQD'), alwaysShow: true));
    expect(find.textContaining('25'), findsOneWidget);
    expect(find.text(kMaskedMoney), findsNothing);
  });

  testWidgets('the eye reveals, hide masks again', (t) async {
    final c = await _pump(t, const FittedMoney(Money(25000, 'IQD')));
    await t.tap(find.byKey(const ValueKey('reveal-money')));
    await t.pump();
    expect(find.textContaining('25'), findsOneWidget);
    c.read(moneyRevealedProvider.notifier).hide();
    await t.pump();
    expect(find.text(kMaskedMoney), findsOneWidget);
  });

  testWidgets('route changes mask again', (t) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          navigatorKey: nav,
          navigatorObservers: [MoneyHideObserver(() => c.read(moneyRevealedProvider.notifier).hide())],
          home: const Scaffold(body: MoneyText(Money(25000, 'IQD'))),
        ),
      ),
    );
    c.read(moneyRevealedProvider.notifier).toggle();
    await t.pump();
    expect(find.textContaining('25'), findsOneWidget);
    nav.currentState!.push(MaterialPageRoute<void>(builder: (_) => const SizedBox()));
    await t.pumpAndSettle();
    expect(c.read(moneyRevealedProvider), isFalse);
  });
}
