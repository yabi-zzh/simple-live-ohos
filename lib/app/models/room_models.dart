class FavoriteRoom {
  final String roomId;
  final int platformIndex;
  String title;
  String userName;
  String cover;
  final DateTime addTime;
  bool? isLive;

  FavoriteRoom({
    required this.roomId,
    required this.platformIndex,
    required this.title,
    required this.userName,
    required this.cover,
    required this.addTime,
    this.isLive,
  });

  String get platformName {
    const names = ['哔哩哔哩', '斗鱼', '虎牙', '抖音'];
    return platformIndex < names.length ? names[platformIndex] : '未知';
  }

  /// 唯一标识: platformIndex_roomId
  String get uniqueKey => '${platformIndex}_$roomId';

  Map<String, dynamic> toMap() => {
        'roomId': roomId,
        'platformIndex': platformIndex,
        'title': title,
        'userName': userName,
        'cover': cover,
        'addTime': addTime.millisecondsSinceEpoch,
      };

  factory FavoriteRoom.fromMap(Map map) => FavoriteRoom(
        roomId: map['roomId'] as String,
        platformIndex: map['platformIndex'] as int,
        title: map['title'] as String? ?? '',
        userName: map['userName'] as String? ?? '',
        cover: map['cover'] as String? ?? '',
        addTime: DateTime.fromMillisecondsSinceEpoch(map['addTime'] as int),
      );
}

class HistoryRoom {
  final String roomId;
  final int platformIndex;
  String title;
  String userName;
  String cover;
  DateTime watchTime;

  HistoryRoom({
    required this.roomId,
    required this.platformIndex,
    required this.title,
    required this.userName,
    required this.cover,
    required this.watchTime,
  });

  String get platformName {
    const names = ['哔哩哔哩', '斗鱼', '虎牙', '抖音'];
    return platformIndex < names.length ? names[platformIndex] : '未知';
  }

  String get uniqueKey => '${platformIndex}_$roomId';

  Map<String, dynamic> toMap() => {
        'roomId': roomId,
        'platformIndex': platformIndex,
        'title': title,
        'userName': userName,
        'cover': cover,
        'watchTime': watchTime.millisecondsSinceEpoch,
      };

  factory HistoryRoom.fromMap(Map map) => HistoryRoom(
        roomId: map['roomId'] as String,
        platformIndex: map['platformIndex'] as int,
        title: map['title'] as String? ?? '',
        userName: map['userName'] as String? ?? '',
        cover: map['cover'] as String? ?? '',
        watchTime: DateTime.fromMillisecondsSinceEpoch(map['watchTime'] as int),
      );
}
