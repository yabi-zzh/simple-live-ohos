import 'package:get/get.dart';
import '../modules/index/index_page.dart';
import '../modules/index/index_controller.dart';
import '../modules/category/category_room_page.dart';
import '../modules/search/search_page.dart';
import '../modules/live_room/live_room_page.dart';
import '../modules/history/history_page.dart';
import '../modules/parse/parse_page.dart';
import '../routes/app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.index,
      page: () => const IndexPage(),
      binding: BindingsBuilder(() {
        Get.lazyPut(() => IndexController());
      }),
    ),
    GetPage(
      name: AppRoutes.categoryRoom,
      page: () => const CategoryRoomPage(),
    ),
    GetPage(
      name: AppRoutes.search,
      page: () => const SearchPage(),
    ),
    GetPage(
      name: AppRoutes.liveRoom,
      page: () => const LiveRoomPage(),
    ),
    GetPage(
      name: AppRoutes.history,
      page: () => const HistoryPage(),
    ),
    GetPage(
      name: AppRoutes.parse,
      page: () => const ParsePage(),
    ),
  ];
}
