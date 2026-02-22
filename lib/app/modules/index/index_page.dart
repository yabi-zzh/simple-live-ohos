import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'index_controller.dart';
import '../home/home_page.dart';
import '../category/category_page.dart';
import '../follow/follow_page.dart';
import '../mine/mine_page.dart';

class IndexPage extends GetView<IndexController> {
  const IndexPage({super.key});

  static const _pageBuilders = [
    HomePage.new,
    CategoryPage.new,
    FollowPage.new,
    MinePage.new,
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final index = controller.currentIndex.value;
      return Scaffold(
        body: _LazyIndexedStack(
          index: index,
          builders: _pageBuilders,
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: index,
          onTap: controller.changePage,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '首页',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.category_outlined),
              activeIcon: Icon(Icons.category),
              label: '分类',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_outline),
              activeIcon: Icon(Icons.favorite),
              label: '关注',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        ),
      );
    });
  }
}

/// 懒加载版 IndexedStack：只在首次切换到某个 Tab 时才构建对应页面
class _LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget Function({Key? key})> builders;

  const _LazyIndexedStack({
    required this.index,
    required this.builders,
  });

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  late final List<bool> _initialized;
  late final List<Widget?> _children;

  @override
  void initState() {
    super.initState();
    _initialized = List.filled(widget.builders.length, false);
    _children = List.filled(widget.builders.length, null);
    _ensureBuilt(widget.index);
  }

  @override
  void didUpdateWidget(covariant _LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureBuilt(widget.index);
  }

  void _ensureBuilt(int index) {
    if (!_initialized[index]) {
      _initialized[index] = true;
      _children[index] = widget.builders[index]();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: [
        for (int i = 0; i < _children.length; i++)
          _children[i] ?? const SizedBox.shrink(),
      ],
    );
  }
}
