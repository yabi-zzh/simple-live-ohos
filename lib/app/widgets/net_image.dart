import 'package:flutter/material.dart';

class NetImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const NetImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      cacheWidth: width != null ? (width! * 2).toInt() : null,
      cacheHeight: height != null ? (height! * 2).toInt() : null,
      headers: {
        'Referer': _getReferer(url),
        'User-Agent': 'Mozilla/5.0',
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) return child;
        return Container(
          width: width,
          height: height,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[200],
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[800]
              : Colors.grey[200],
          child: Icon(Icons.broken_image, color: Colors.grey[400], size: 20),
        );
      },
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  static String _getReferer(String url) {
    if (url.contains('bilibili') || url.contains('hdslb')) {
      return 'https://live.bilibili.com';
    }
    if (url.contains('douyu')) {
      return 'https://www.douyu.com';
    }
    if (url.contains('huya')) {
      return 'https://www.huya.com';
    }
    if (url.contains('douyin') || url.contains('douyinpic')) {
      return 'https://live.douyin.com';
    }
    return '';
  }
}
