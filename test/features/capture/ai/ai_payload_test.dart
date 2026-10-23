import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_manager/core/crypto/aead.dart';
import 'package:life_manager/core/security/sensitive.dart';
import 'package:life_manager/features/capture/ai/ai_payload.dart';
import 'package:life_manager/features/capture/domain/intent_validator.dart';
import 'package:life_manager/features/capture/domain/lexicon.dart';
import 'package:life_manager/features/finance/data/budgets_repository.dart';
import 'package:life_manager/features/finance/data/rates_repository.dart';
import 'package:life_manager/features/finance/data/transactions_repository.dart';
import 'package:life_manager/features/finance/data/workspaces_repository.dart';
import 'package:life_manager/features/vault/crypto/field_cipher.dart';
import 'package:life_manager/features/vault/crypto/vault_key.dart';
import 'package:life_manager/features/vault/data/vault_items_repository.dart';
import 'package:life_manager/l10n/gen/app_localizations.dart';

import '../../../helpers/finance_fixtures.dart';

void main() {
  late FinanceFixture f;
  final now = DateTime(2026, 10, 23, 15, 40);

  setUp(() async => f = await financeFixture());
  tearDown(() => f.db.close());

  test('payload contains only the allowed keys and names', () async {
    await f.setOpening(f.personalIqd, 4455667);
    await TransactionsRepository(f.db).addSimple(
      type: 'expense',
      accountId: f.personalIqd,
      amountMinor: 987654,
      occurredAt: DateTime.utc(2026, 10, 1),
      description: 'SECRET-DESC-7731',
    );
    await BudgetsRepository(
      f.db,
      RatesRepository(f.db),
    ).create(categoryId: f.cat('food'), currencyCode: 'IQD', amountMinor: 3344556);
    await WorkspacesRepository(f.db).setAliases(f.buzzWs, ['بزفاي']);
    final vaultKey = generateVaultKey();
    await VaultItemsRepository(f.db, FieldCipher(const AesGcmAead())).create(
      vaultKey,
      VaultItemInput(
        title: 'VAULT-TITLE-5521',
        username: 'VAULT-USER-5521',
        category: 'other',
        password: const Sensitive('VAULT-PW-5521'),
      ),
    );
    vaultKey.destroy();
    final lex = await loadLexicon(f.db, lookupAppLocalizations(const Locale('ar')));
    final body = jsonEncode(buildParsePayload('غدا 15 الف', lex, now));
    final json = jsonDecode(body) as Map<String, Object?>;
    expect(json.keys.toSet(), {
      'transcript',
      'now',
      'utcOffset',
      'accounts',
      'workspaces',
      'categories',
      'buckets',
      'projects',
    });
    for (final s in [
      'SECRET-DESC-7731',
      'VAULT-TITLE-5521',
      'VAULT-USER-5521',
      'VAULT-PW-5521',
      '987654',
      '4455667',
      '3344556',
      'openingBalance',
      'balance',
    ]) {
      expect(body, isNot(contains(s)), reason: s);
    }
    expect(json['transcript'], 'غدا 15 الف');
    expect(json['now'], '2026-10-23T15:40');
    expect(json['utcOffset'], matches(RegExp(r'^[+-]\d{2}:\d{2}$')));
    expect(json['accounts'], containsAll(['Personal · Cash IQD', 'Buzzify · Cash USD']));
    expect((json['accounts'] as List).toSet().length, (json['accounts'] as List).length);
    expect(
      json['workspaces'],
      contains(
        equals({
          'name': 'Buzzify',
          'aliases': ['بزفاي'],
        }),
      ),
    );
    expect(json['categories'], contains(equals({'name': 'مواصلات', 'kind': 'expense'})));
    expect(json['buckets'], hasLength(3));
  });

  test('utc offsets are written ±HH:MM', () {
    expect(formatUtcOffset(const Duration(hours: 3)), '+03:00');
    expect(formatUtcOffset(const Duration(hours: -4, minutes: -30)), '-04:30');
    expect(formatUtcOffset(Duration.zero), '+00:00');
  });

  test('the system prompt carries the schema and the rules', () {
    expect(kParseSystemPrompt, contains(kIntentSchema));
    for (final s in ['strings', 'null', 'financial', 'investment advice', 'only JSON', 'Kurdish']) {
      expect(kParseSystemPrompt, contains(s), reason: s);
    }
  });
}
