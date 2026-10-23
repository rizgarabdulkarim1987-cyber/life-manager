import 'package:flutter/material.dart';

import '../../../../core/l10n/ckb_fallback_localizations.dart';

/// How long every Undo stays on screen (redesign §10).
const kUndoWindow = Duration(seconds: 10);

/// Replaces any snackbar on [messenger] with [message] and an Undo button.
void showUndoSnack(
  ScaffoldMessengerState messenger,
  AppLocalizations l, {
  required String message,
  required Future<void> Function() onUndo,
}) {
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: kUndoWindow,
      content: Text(message),
      action: SnackBarAction(label: l.undo, onPressed: onUndo),
    ),
  );
}
