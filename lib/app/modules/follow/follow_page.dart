import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/platform_constants.dart';
import '../../services/favorite_service.dart';
import '../../models/room_models.dart';
import '../../widgets/net_image.dart';
import '../../widgets/empty_view.dart';
import '../index/index_controller.dart';
import '../../utils/responsive.dart';

class FollowPage extends StatefulWidget {
  const FollowPage({super.key});

  @override
  State<FollowPage> createState() => _FollowPageState();
}

class _FollowPageState extends State<FollowPage> {
  Worker? _tabWorker;

  @override
  void initState() {
    super.initState();
    // 监听 Tab 切换，切到关注页时自动刷新开播状态
    final indexController = Get.find<IndexController>();
    _tabWorker = ever(indexController.currentIndex, (index) {
      if (index == 2) {
        FavoriteService.instance.autoRefreshIfNeeded();
      }
    });
  }

  @override
  void dispose() {
    _tabWorker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = FavoriteService.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('关注'),
        actions: [
          Obx(() => service.isChecking.value
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: service.refreshLiveStatus,
                )),
          Obx(() => service.favorites.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: () => _showClearDialog(context, service),
                )
              : const SizedBox.shrink()),
        ],
      ),
      body: Obx(() {
        if (service.favorites.isEmpty) {
          return const EmptyView(text: '还没有关注的直播间');
        }
        return RefreshIndicator(
          onRefresh: service.refreshLiveStatus,
          child: Responsive.constrainedContent(
            child: ListView.builder(
              itemCount: service.favorites.length,
              itemBuilder: (context, index) {
                final room = service.favorites[index];
                return _buildFavoriteItem(context, room, service);
              },
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFavoriteItem(
      BuildContext context, FavoriteRoom room, FavoriteService service) {
    final isLive = room.isLive == true;
    return Dismissible(
      key: Key(room.uniqueKey),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        service.removeFavorite(room.roomId, room.platformIndex);
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: SizedBox(
          width: 80,
          height: 50,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: isLive
                    ? NetImage(room.cover, fit: BoxFit.cover)
                    : ColorFiltered(
                        colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
                        child: NetImage(room.cover, fit: BoxFit.cover),
                      ),
              ),
              // 平台角标
              Positioned(
                left: 3,
                top: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: PlatformConstants.getColor(room.platformIndex),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    PlatformConstants.getShortName(room.platformIndex),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // 直播状态
              if (isLive)
                Positioned(
                  right: 3,
                  bottom: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        title: Text(
          room.title.isNotEmpty ? room.title : room.userName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isLive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(
              Icons.person_outline,
              size: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 3),
            Expanded(
              child: Text(
                room.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        trailing: isLive
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '进入',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : Text(
                '未开播',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
        onTap: () {
          if (isLive) {
            Get.toNamed('/live-room', arguments: {
              'roomId': room.roomId,
              'platformIndex': room.platformIndex,
            });
          } else {
            Get.snackbar(
              '提示',
              '主播未开播',
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 2),
              margin: const EdgeInsets.all(12),
            );
          }
        },
      ),
    );
  }

  void _showClearDialog(BuildContext context, FavoriteService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空关注'),
        content: const Text('确定要清空所有关注吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              service.clearAll();
              Navigator.pop(ctx);
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
