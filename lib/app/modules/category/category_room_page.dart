import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'category_room_controller.dart';
import '../../widgets/room_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';

class CategoryRoomPage extends StatelessWidget {
  const CategoryRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>;
    final controller = Get.put(CategoryRoomController(
      subCategory: args['subCategory'],
      platformIndex: args['platformIndex'],
    ));

    return Scaffold(
      appBar: AppBar(
        title: Text(args['subCategory'].name),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.rooms.isEmpty) {
          return const LoadingView();
        }

        if (controller.rooms.isEmpty) {
          return ErrorView(
            text: '暂无直播',
            onRetry: controller.refreshRooms,
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refreshRooms,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  notification.metrics.extentAfter < 300) {
                controller.loadMore();
              }
              return false;
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 1.05,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: controller.rooms.length,
                  itemBuilder: (context, index) {
                    final room = controller.rooms[index];
                    return RoomCard(
                      room: room,
                      platformIndex: controller.platformIndex,
                      onTap: () => Get.toNamed('/live-room', arguments: {
                        'roomId': room.roomId,
                        'platformIndex': controller.platformIndex,
                      }),
                    );
                  },
                );
              },
            ),
          ),
        );
      }),
    );
  }
}
