import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'search_controller.dart' as search;
import '../../widgets/room_card.dart';
import '../../widgets/empty_view.dart';
import '../../services/platform_service.dart';
import '../../utils/responsive.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with TickerProviderStateMixin {
  late TabController _platformTabController;
  late TabController _typeTabController;
  late search.SearchController _controller;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = Get.put(search.SearchController());
    final platforms = PlatformService.instance.sites;
    _platformTabController = TabController(length: platforms.length, vsync: this);
    _typeTabController = TabController(length: 2, vsync: this);

    _platformTabController.addListener(() {
      if (!_platformTabController.indexIsChanging) {
        _controller.switchPlatform(_platformTabController.index);
      }
    });

    _typeTabController.addListener(() {
      if (!_typeTabController.indexIsChanging) {
        _controller.switchSearchType(_typeTabController.index);
      }
    });
  }

  @override
  void dispose() {
    _platformTabController.dispose();
    _typeTabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final platforms = PlatformService.instance.sites;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: 48,
        title: Container(
          height: 36,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 14),
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              hintText: '搜索直播间或主播',
              hintStyle: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              border: InputBorder.none,
              isDense: true,
              isCollapsed: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              prefixIcon: Icon(
                Icons.search,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (_, value, __) => value.text.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _controller.keyword.value = '';
                      },
                      child: Icon(Icons.clear, size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    )
                  : const SizedBox.shrink(),
            ),
            suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          onSubmitted: _controller.search,
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => _controller.search(_searchController.text),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
            ),
            child: const Text('搜索', style: TextStyle(fontSize: 14)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              TabBar(
                controller: _platformTabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: platforms.map((site) => Tab(text: site.name)).toList(),
              ),
              TabBar(
                controller: _typeTabController,
                isScrollable: false,
                labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 14),
                indicatorSize: TabBarIndicatorSize.label,
                tabs: const [
                  Tab(text: '直播间'),
                  Tab(text: '主播'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Obx(() {
        if (_controller.keyword.value.isEmpty) {
          return _buildHistoryView();
        }

        if (_controller.isLoading.value &&
            _controller.rooms.isEmpty &&
            _controller.anchors.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_controller.searchType.value == 0) {
          return _buildRoomList();
        } else {
          return _buildAnchorList();
        }
      }),
    );
  }

  Widget _buildRoomList() {
    if (_controller.rooms.isEmpty) {
      return const EmptyView(text: '暂无搜索结果');
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 300) {
          _controller.loadMore();
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = Responsive.gridCrossAxisCount(constraints.maxWidth);
          return GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: Responsive.gridChildAspectRatio(constraints.maxWidth, crossAxisCount),
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
    );
  }

  Widget _buildAnchorList() {
    if (_controller.anchors.isEmpty) {
      return const EmptyView(text: '暂无搜索结果');
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 300) {
          _controller.loadMore();
        }
        return false;
      },
      child: Responsive.constrainedContent(
        child: ListView.builder(
          itemCount: _controller.anchors.length,
          itemBuilder: (context, index) {
            final anchor = _controller.anchors[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(anchor.avatar),
              ),
              title: Text(anchor.userName),
              subtitle: Text(anchor.liveStatus ? '直播中' : '未开播'),
              trailing: anchor.liveStatus
                  ? const Icon(Icons.play_circle_outline, color: Colors.red)
                  : null,
              onTap: () {
                if (anchor.liveStatus) {
                  Get.toNamed('/live-room', arguments: {
                    'roomId': anchor.roomId,
                    'platformIndex': _controller.currentPlatform.value,
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
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistoryView() {
    return Obx(() {
      final history = _controller.searchHistory;
      if (history.isEmpty) {
        return const EmptyView(
          text: '输入关键词搜索',
          icon: Icons.search,
        );
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Text('搜索历史',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              GestureDetector(
                onTap: _controller.clearHistory,
                child: Text(
                  '清空',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: history.map<Widget>((word) => InputChip(
              label: Text(word, style: const TextStyle(fontSize: 13)),
              onPressed: () {
                _searchController.text = word;
                _controller.search(word);
              },
              onDeleted: () => _controller.removeHistory(word),
              deleteIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
              deleteIcon: const Icon(Icons.close, size: 16),
            )).toList(),
          ),
        ],
      );
    });
  }
}
