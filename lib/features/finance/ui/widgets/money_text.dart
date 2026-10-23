import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/money/money.dart';
import '../../../../core/money/money_format.dart';
import '../../../../core/security/money_privacy.dart';
import '../../../../core/theme/tokens.dart';
import '../ui_format.dart';

/// An amount as one left-to-right run, so `−25,000 د.ع` never flips in RTL.
/// With [signed], positive amounts get a plus and the success colour, negative
/// ones the danger colour. Masked until the owner taps the eye, unless
/// [alwaysShow] (an amount the owner just typed).
class MoneyText extends ConsumerWidget {
  const MoneyText(this.m, {super.key, this.style, this.signed = false, this.alwaysShow = false});

  final Money m;
  final TextStyle? style;
  final bool signed;
  final bool alwaysShow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.tokens;
    final base = style ?? DefaultTextStyle.of(context).style;
    final shown = alwaysShow || ref.watch(alwaysRevealMoneyProvider) || ref.watch(moneyRevealedProvider);
    if (!shown) {
      return Text(
        kMaskedMoney,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        softWrap: false,
        style: base.copyWith(color: k.textMuted, letterSpacing: 2),
      );
    }
    final text = formatMoney(m, localeCode: langOf(context));
    final color = !signed || m.minor == 0
        ? base.color
        : m.minor > 0
        ? k.success
        : k.danger;
    return Text(
      signed && m.minor > 0 ? '+$text' : text,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      softWrap: false,
      style: base.copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}

/// [MoneyText] that shrinks instead of overflowing in a narrow slot.
class FittedMoney extends StatelessWidget {
  const FittedMoney(
    this.m, {
    super.key,
    this.style,
    this.signed = false,
    this.alignment = AlignmentDirectional.centerEnd,
    this.alwaysShow = false,
  });

  final Money m;
  final TextStyle? style;
  final bool signed;
  final AlignmentDirectional alignment;
  final bool alwaysShow;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: alignment,
    child: MoneyText(m, style: style, signed: signed, alwaysShow: alwaysShow),
  );
}
