import 'package:simple_live_core/simple_live_core.dart';

class PlatformService {
  static final PlatformService _instance = PlatformService._();
  static PlatformService get instance => _instance;
  PlatformService._();

  final List<LiveSite> sites = [
    BiliBiliSite(),
    DouyuSite(),
    HuyaSite(),
    DouyinSite(),
  ];

  LiveSite getSite(int index) => sites[index];

  BiliBiliSite get bilibili => sites[0] as BiliBiliSite;
  DouyuSite get douyu => sites[1] as DouyuSite;
  HuyaSite get huya => sites[2] as HuyaSite;
  DouyinSite get douyin => sites[3] as DouyinSite;
}
