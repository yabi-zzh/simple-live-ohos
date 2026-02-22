import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'category_controller.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/error_view.dart';
import '../../widgets/net_image.dart';
import '../../services/platform_service.dart';
import '../../routes/app_routes.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CategoryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(CategoryController());
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
        title: const Text('分类'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: platforms.map((site) => Tab(text: site.name)).toList(),
        ),
      ),
      body: Obx(() {
        if (_controller.isLoading.value) {
          return const LoadingView();
        }

        if (_controller.categories.isEmpty) {
          return ErrorView(
            text: '暂无分类',
            onRetry: _controller.loadCategories,
          );
        }

        return RefreshIndicator(
          onRefresh: _controller.refreshCategories,
          child: ListView.builder(
            itemCount: _controller.categories.length,
            itemBuilder: (context, index) {
              final category = _controller.categories[index];
              return _buildCategorySection(category);
            },
          ),
        );
      }),
    );
  }

  Widget _buildCategorySection(dynamic category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            category.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (category.children as List).map<Widget>((sub) {
              return ActionChip(
                avatar: sub.pic != null && sub.pic!.isNotEmpty
                    ? CircleAvatar(
                        backgroundImage: NetworkImage(sub.pic!),
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      )
                    : null,
                label: Text(sub.name, style: const TextStyle(fontSize: 13)),
                onPressed: () {
                  Get.toNamed(
                    AppRoutes.categoryRoom,
                    arguments: {
                      'subCategory': sub,
                      'platformIndex': _controller.currentPlatform.value,
                    },
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
