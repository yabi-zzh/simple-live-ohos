class DanmakuSettings {
  final double fontSize;
  final double opacity;
  final double duration;
  final double area;
  final List<String> shieldWords;

  const DanmakuSettings({
    this.fontSize = 16.0,
    this.opacity = 0.85,
    this.duration = 8.0,
    this.area = 0.8,
    this.shieldWords = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'fontSize': fontSize,
      'opacity': opacity,
      'duration': duration,
      'area': area,
      'shieldWords': shieldWords,
    };
  }

  factory DanmakuSettings.fromMap(Map<String, dynamic> map) {
    return DanmakuSettings(
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 16.0,
      opacity: (map['opacity'] as num?)?.toDouble() ?? 0.85,
      duration: (map['duration'] as num?)?.toDouble() ?? 8.0,
      area: (map['area'] as num?)?.toDouble() ?? 0.8,
      shieldWords: (map['shieldWords'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  DanmakuSettings copyWith({
    double? fontSize,
    double? opacity,
    double? duration,
    double? area,
    List<String>? shieldWords,
  }) {
    return DanmakuSettings(
      fontSize: fontSize ?? this.fontSize,
      opacity: opacity ?? this.opacity,
      duration: duration ?? this.duration,
      area: area ?? this.area,
      shieldWords: shieldWords ?? this.shieldWords,
    );
  }
}
