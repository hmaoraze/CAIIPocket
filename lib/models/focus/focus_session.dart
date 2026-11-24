/// 一次专注记录。
class FocusSession {
  const FocusSession({
    required this.id,
    required this.tag,
    required this.startedAt,
    required this.minutes,
    required this.completed,
  });

  final String id;
  final String tag;
  final DateTime startedAt;
  final int minutes;
  final bool completed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tag': tag,
        'startedAt': startedAt.toIso8601String(),
        'minutes': minutes,
        'completed': completed,
      };

  factory FocusSession.fromJson(Map<String, dynamic> json) => FocusSession(
        id: json['id'] as String,
        tag: (json['tag'] as String?) ?? '学习',
        startedAt:
            DateTime.tryParse(json['startedAt'] as String? ?? '') ?? DateTime.now(),
        minutes: (json['minutes'] as num?)?.toInt() ?? 0,
        completed: (json['completed'] as bool?) ?? false,
      );
}

/// 正在进行的专注：只存开始时刻与目标时长，靠时间戳恢复，进程被杀也不丢。
class ActiveFocus {
  const ActiveFocus({
    required this.startedAt,
    required this.targetMinutes,
    required this.tag,
    required this.pausedSeconds,
  });

  final DateTime startedAt;
  final int targetMinutes;
  final String tag;

  /// 累计暂停秒数。
  final int pausedSeconds;

  Map<String, dynamic> toJson() => {
        'startedAt': startedAt.toIso8601String(),
        'targetMinutes': targetMinutes,
        'tag': tag,
        'pausedSeconds': pausedSeconds,
      };

  factory ActiveFocus.fromJson(Map<String, dynamic> json) => ActiveFocus(
        startedAt:
            DateTime.tryParse(json['startedAt'] as String? ?? '') ?? DateTime.now(),
        targetMinutes: (json['targetMinutes'] as num?)?.toInt() ?? 25,
        tag: (json['tag'] as String?) ?? '学习',
        pausedSeconds: (json['pausedSeconds'] as num?)?.toInt() ?? 0,
      );
}
