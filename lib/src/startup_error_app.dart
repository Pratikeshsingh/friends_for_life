import 'package:flutter/material.dart' hide Text;
import 'core/i18n.dart';

class VriendTimeStartupErrorApp extends StatelessWidget {
  const VriendTimeStartupErrorApp({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VriendTime',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFFFCF7),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFE4DDD4)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14150806),
                        blurRadius: 24,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1EB),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.cloud_off_rounded,
                            color: Color(0xFFD85F4D),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'VriendTime could not start',
                          style: TextStyle(
                            color: Color(0xFF062B55),
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          message,
                          style: const TextStyle(
                            color: Color(0xFF4F6671),
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'If this keeps happening, close the app and open it again.',
                          style: TextStyle(
                            color: Color(0xFF60727A),
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
