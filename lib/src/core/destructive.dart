import 'package:flutter/material.dart';

/// Deep red reserved for actions that lose something: a place, a seat, data.
/// 5.9:1 against white, so labels stay readable (the coral accent is only 3.7:1).
const destructiveRed = Color(0xFFB33A3A);

/// Solid red for the confirming button in a destructive dialog.
final destructiveFilledStyle = FilledButton.styleFrom(
  backgroundColor: destructiveRed,
  foregroundColor: Colors.white,
);

/// Outlined red for a destructive action that sits under a safer primary one.
final destructiveOutlinedStyle = OutlinedButton.styleFrom(
  foregroundColor: destructiveRed,
  side: const BorderSide(color: Color(0x66B33A3A)),
);

/// Red text for a quiet entry point into a destructive flow.
final destructiveTextStyle = TextButton.styleFrom(
  foregroundColor: destructiveRed,
);
