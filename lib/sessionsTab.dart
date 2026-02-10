import 'package:flutter/cupertino.dart';

class SessionsTab extends StatelessWidget {
  const SessionsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text(
          'Sessions',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Focus sessions History',
                style: TextStyle(
                  fontSize: 18,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
