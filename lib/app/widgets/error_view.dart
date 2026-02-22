import 'package:flutter/material.dart';

class ErrorView extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;

  const ErrorView({
    super.key,
    this.text = '加载失败',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('重试'),
            ),
          ],
        ],
      ),
    );
  }
}
