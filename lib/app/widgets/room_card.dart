import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:simple_live_core/simple_live_core.dart';
import '../constants/platform_constants.dart';
import '../models/room_models.dart';
import '../services/favorite_service.dart';
import 'net_image.dart';

class RoomCard extends StatelessWidget {
  final LiveRoomItem room;
  final VoidCallback? onTap;
  final int? platformIndex;

  const RoomCard({
    super.key,
    required this.room,
    this.onTap,
    this.platformIndex,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subColor = Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6);

    return GestureDetector(
      onTap: onTap,
      onLongPressStart: platformIndex != null
          ? (details) => _showContextMenu(context, details.globalPosition)
          : null,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: isDark ? 2 : 1,
        shadowColor: isDark ? Colors.black54 : Colors.black26,
        color: Theme.of(context).colorScheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面 16:9
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetImage(room.cover, fit: BoxFit.cover),
                  // 底部渐变
                  const Positioned(
                    left: 0, right: 0, bottom: 0, height: 28,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black45],
                        ),
                      ),
                    ),
                  ),
                  // 平台角标
                  if (platformIndex != null)
                    Positioned(
                      left: 6, top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: PlatformConstants.getColor(platformIndex!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          PlatformConstants.getShortName(platformIndex!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // 观看人数
                  Positioned(
                    right: 6, bottom: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.visibility, size: 11, color: Colors.white70,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatOnline(room.online),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // 标题 + 主播名
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      room.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline, size: 12, color: subColor,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            room.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12, color: subColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final service = FavoriteService.instance;
    final isFav = service.isFavorite(room.roomId, platformIndex!);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, position.dy, position.dx, position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'favorite',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: isFav ? Colors.red : null,
              ),
              const SizedBox(width: 8),
              Text(isFav ? '取消收藏' : '收藏'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link, size: 18),
              SizedBox(width: 8),
              Text('复制链接'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'favorite') {
        _toggleFavorite(service, isFav);
      } else if (value == 'copy') {
        _copyRoomLink();
      }
    });
  }

  void _toggleFavorite(FavoriteService service, bool isFav) {
    if (isFav) {
      service.removeFavorite(room.roomId, platformIndex!);
      Get.snackbar('提示', '已取消收藏',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(12),
      );
    } else {
      service.addFavorite(FavoriteRoom(
        roomId: room.roomId,
        platformIndex: platformIndex!,
        title: room.title,
        userName: room.userName,
        cover: room.cover,
        addTime: DateTime.now(),
      ));
      Get.snackbar('提示', '已收藏',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(12),
      );
    }
  }

  void _copyRoomLink() {
    const urlMap = {
      0: 'https://live.bilibili.com/',
      1: 'https://www.douyu.com/',
      2: 'https://www.huya.com/',
      3: 'https://live.douyin.com/',
    };
    final base = urlMap[platformIndex] ?? '';
    final link = '$base${room.roomId}';
    Clipboard.setData(ClipboardData(text: link));
    Get.snackbar('已复制', link,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(12),
    );
  }

  String _formatOnline(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    }
    return count.toString();
  }

}
