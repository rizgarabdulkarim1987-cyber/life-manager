import 'package:flutter/widgets.dart';

/// Shared motion tokens. Strong ease-out for UI entering or changing state.
const kEaseOut = Cubic(0.23, 1, 0.32, 1);
const kEaseInOut = Cubic(0.77, 0, 0.175, 1);

const kDurationFast = Duration(milliseconds: 120);
const kDurationBase = Duration(milliseconds: 200);

/// True when the system "Remove animations" setting is on.
bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
