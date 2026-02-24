class DanmakuSettings {
  final double fontSize;
  final double opacity;
  final double duration;
  final double area;
  final double strokeWidth;
  final int fontWeight; // FontWeight 索引: 0=w100 ... 3=w400 ... 8=w900
  final List<String> shieldWords;

  const DanmakuSettings({
    this.fontSize = 16.0,
    this.opacity = 0.85,
    this.duration = 8.0,
    this.area = 0.8,
    this.strokeWidth = 1.5,
    this.fontWeight = 4, // w500
    this.shieldWords = const [],
  });

  Map<String, dynamic> toMap() => {
    'fontSize': fontSize,
    'opacity': opacity,
    'duration': duration,
    'area': area,
    'strokeWidth': strokeWidth,
    'fontWeight': fontWeight,
    'shieldWords': shieldWords,
  };

  factory DanmakuSettings.fromMap(Map<String, dynamic> map) => DanmakuSettings(
    fontSize: (map['fontSize'] as num?)?.toDouble() ?? 16.0,
    opacity: (map['opacity'] as num?)?.toDouble() ?? 0.85,
    duration: (map['duration'] as num?)?.toDouble() ?? 8.0,
    area: (map['area'] as num?)?.toDouble() ?? 0.8,
    strokeWidth: (map['strokeWidth'] as num?)?.toDouble() ?? 1.5,
    fontWeight: (map['fontWeight'] as num?)?.toInt() ?? 4,
    shieldWords: (map['shieldWords'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
  );

  DanmakuSettings copyWith({
    double? fontSize,
    double? opacity,
    double? duration,
    double? area,
    double? strokeWidth,
    int? fontWeight,
    List<String>? shieldWords,
  }) => DanmakuSettings(
    fontSize: fontSize ?? this.fontSize,
    opacity: opacity ?? this.opacity,
    duration: duration ?? this.duration,
    area: area ?? this.area,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    fontWeight: fontWeight ?? this.fontWeight,
    shieldWords: shieldWords ?? this.shieldWords,
  );
}
