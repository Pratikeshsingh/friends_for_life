import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'screens/prototype_shell.dart';

class BakkieBondApp extends StatelessWidget {
  const BakkieBondApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BakkieBond',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const PrototypeShell(),
    );
  }
}
