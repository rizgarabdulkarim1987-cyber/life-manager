import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/features/finance/export/pdf_export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pdf starts with %PDF and embeds the Vazirmatn font', () async {
    final bytes = await reportPdf(
      const ReportPdfData(
        localeCode: 'ar',
        title: 'التقارير',
        range: '1 أكتوبر 2026 – 31 أكتوبر 2026',
        scope: 'كل المساحات · IQD',
        summaryTitle: 'الملخص',
        summary: [('الدخل', '250,000 د.ع'), ('المصاريف', '100,000 د.ع')],
        categoryTitle: 'حسب الفئة',
        categories: [('اكل', '60,000 د.ع')],
        debtsTitle: 'الديون',
        debts: [('أحمد', '300,000 د.ع')],
      ),
    );
    expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
    expect(latin1.decode(bytes), contains('Vazirmatn'));
  });
}
