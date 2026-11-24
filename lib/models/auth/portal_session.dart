import 'dart:convert';

/// 本机会话记录。只存"谁登录过"，真正的凭据是 cookie jar 里的 Cookie。
class PortalSession {
  const PortalSession({
    required this.username,
    required this.displayName,
    required this.loggedInAt,
    this.avatarUrl = '',
    this.department = '',
  });

  final String username;
  final String displayName;
  final DateTime loggedInAt;

  /// 头像地址（门户 userInfo 的 userPhoto，或个人信息页里抓到的）
  final String avatarUrl;

  /// 院系（门户 userInfo 的 userDepartment）
  final String department;

  /// 头像上显示的首字（中文取第一个字，学号取首位）。
  String get initial {
    final name = displayName.trim();
    if (name.isNotEmpty) return name.substring(0, 1).toUpperCase();
    return username.isEmpty ? '?' : username.substring(0, 1).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'displayName': displayName,
        'loggedInAt': loggedInAt.toIso8601String(),
        'avatarUrl': avatarUrl,
        'department': department,
      };

  factory PortalSession.fromJson(Map<String, dynamic> json) => PortalSession(
        username: json['username'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        loggedInAt:
            DateTime.tryParse(json['loggedInAt'] as String? ?? '') ??
                DateTime.now(),
        avatarUrl: json['avatarUrl'] as String? ?? '',
        department: json['department'] as String? ?? '',
      );

  static PortalSession? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) return PortalSession.fromJson(map);
    } catch (_) {
      return null;
    }
    return null;
  }

  String encode() => jsonEncode(toJson());
}
