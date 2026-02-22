import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home_controller.dart';
import '../../widgets/room_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../services/platform_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late HomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(HomeController());
    final platforms = PlatformService.instance.sites;
    _tabController = TabController(length: platforms.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _controller.switchPlatform(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final platforms = PlatformService.instance.sites;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple Live'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Get.toNamed('/search'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: platforms.map((site) => Tab(text: site.name)).toList(),
        ),
      ),
      body: Obx(() {
        if (_controller.isLoading.value && _controller.rooms.isEmpty) {
          return const LoadingView(text: '加载中...');
        }

        if (_controller.rooms.isEmpty) {
          return ErrorView(
            text: '暂无推荐直播',
            onRetry: _controller.refreshRooms,
          );
        }

        return RefreshIndicator(
          onRefresh: _controller.refreshRooms,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  notification.metrics.extentAfter < 300) {
                _controller.loadMore();
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
            itemCount: _controller.rooms.length,
            itemBuilder: (context, index) {
              final room = _controller.rooms[index];
              return RoomCard(
                room: room,
                platformIndex: _controller.currentPlatform.value,
                onTap: () => Get.toNamed('/live-room', arguments: {
                  'roomId': room.roomId,
                  'platformIndex': _controller.currentPlatform.value,
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
