import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  final String text;

  const LoadingView({
    super.key,
    this.text = '加载中...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(text, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
