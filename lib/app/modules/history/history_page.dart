import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../constants/platform_constants.dart';
import '../../services/history_service.dart';
import '../../models/room_models.dart';
import '../../widgets/net_image.dart';
import '../../widgets/empty_view.dart';
import '../../utils/responsive.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = HistoryService.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('观看历史'),
        actions: [
          Obx(() => service.histories.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: () => _showClearDialog(context, service),
                )
              : const SizedBox.shrink()),
        ],
      ),
      body: Obx(() {
        if (service.histories.isEmpty) {
          return const EmptyView(text: '暂无观看记录');
        }
        final grouped = _groupByDate(service.histories);
        return Responsive.constrainedContent(
          child: ListView.builder(
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final entry = grouped[index];
              if (entry is String) {
                return _buildSectionHeader(context, entry);
              }
              return _buildHistoryItem(context, entry as HistoryRoom, service);
            },
          ),
        );
      }),
    );
  }

  /// 按日期分组，返回混合列表（String 为分组标题，HistoryRoom 为数据项）
  List<dynamic> _groupByDate(List<HistoryRoom> histories) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final result = <dynamic>[];
    String? lastGroup;

    for (final room in histories) {
      final watchDay = DateTime(
        room.watchTime.year, room.watchTime.month, room.watchTime.day,
      );
      String group;
      if (!watchDay.isBefore(today)) {
        group = '今天';
      } else if (!watchDay.isBefore(yesterday)) {
        group = '昨天';
      } else {
        group = '更早';
      }
      if (group != lastGroup) {
        result.add(group);
        lastGroup = group;
      }
      result.add(room);
    }
    return result;
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildHistoryItem(
      BuildContext context, HistoryRoom room, HistoryService service) {
    return Dismissible(
      key: Key('${room.uniqueKey}_${room.watchTime.millisecondsSinceEpoch}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        service.removeHistory(room.roomId, room.platformIndex);
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
                child: NetImage(room.cover, fit: BoxFit.cover),
              ),
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
            ],
          ),
        ),
        title: Text(
          room.title.isNotEmpty ? room.title : room.userName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Icon(
              Icons.person_outline,
              size: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 3),
            Flexible(
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
            Text(
              ' · ${_formatTime(room.watchTime)}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () {
          Get.toNamed('/live-room', arguments: {
            'roomId': room.roomId,
            'platformIndex': room.platformIndex,
          });
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}/${time.day}';
  }

  void _showClearDialog(BuildContext context, HistoryService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空历史'),
        content: const Text('确定要清空所有观看记录吗？'),
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
