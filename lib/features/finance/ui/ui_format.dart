import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../core/db/app_database.dart';
import '../../../l10n/gen/app_localizations.dart';

String langOf(BuildContext context) => Localizations.localeOf(context).languageCode;

/// intl has no Sorani data; Sorani dates borrow Arabic month names.
String dateLocaleOf(BuildContext context) {
  final tag = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.localeExists(tag) ? tag : 'ar';
}

String formatDate(BuildContext context, DateTime d) => DateFormat.yMMMd(dateLocaleOf(context)).format(d);

/// A rate × 10⁶ as a grouped decimal with trailing zeros trimmed: 1310000000 → "1,310".
String formatRateE6(int rateE6) {
  final whole = NumberFormat.decimalPattern('en').format(rateE6 ~/ 1000000);
  final frac = (rateE6 % 1000000).toString().padLeft(6, '0').replaceFirst(RegExp(r'0+$'), '');
  return frac.isEmpty ? whole : '$whole.$frac';
}

/// Seeded names are `<workspace> · <label>`; under a workspace header only the label is needed.
String shortAccountName(String name, String workspace) {
  final prefix = '$workspace · ';
  return name.startsWith(prefix) ? name.substring(prefix.length) : name;
}

String accountKindLabel(String kind, AppLocalizations l) => switch (kind) {
  'cash' => l.kindCash,
  'bank' => l.kindBank,
  'savings' => l.kindSavings,
  _ => l.kindCustom,
};

String txTypeLabel(Transaction t, AppLocalizations l) => switch (t.type) {
  'income' => l.typeIncome,
  'expense' => l.typeExpense,
  'refund' => l.typeRefund,
  'adjustment' => l.typeAdjustment,
  'transfer' => t.transferKind == 'owner_draw' ? l.typeOwnerDraw : l.typeTransfer,
  _ => l.typeDebtPayment,
};
