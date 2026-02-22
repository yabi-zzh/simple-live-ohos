import 'package:flutter/material.dart';

class EmptyView extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback? onRefresh;

  const EmptyView({
    super.key,
    this.text = '暂无数据',
    this.icon = Icons.inbox_outlined,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          if (onRefresh != null) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: onRefresh,
              child: const Text('点击刷新'),
            ),
          ],
        ],
      ),
    );
  }
}
