import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// 一卡通平台（ykt2025.caii.edu.cn）接口。
///
/// 业务接口均为 AES-CBC 加密表单（密钥硬编码在平台 H5 前端 JS 里）：
/// - 请求体: `iv=<base64随机IV>&ciphertext=<base64(AES(JSON))>&r=<13位毫秒时间戳>`
/// - 明文: `{"uuid": "<用户UUID>"}`（认证即 UUID，无 Cookie）
class YktService {
  YktService();

  static const String _base =
      'https://ykt2025.caii.edu.cn/04310144/v2/FdjZ05';
  static const String _key = '!QAZxsw214235698';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/124.0 Mobile Safari/537.36',
        'Referer':
            'https://ykt2025.caii.edu.cn/04310144/app/webview/use-code.html',
        'Origin': 'https://ykt2025.caii.edu.cn',
      },
      responseType: ResponseType.json,
    ),
  );

  Map<String, String> _encryptBody(String jsonPlain) {
    final encrypter = enc.Encrypter(
      enc.AES(
        enc.Key.fromUtf8(_key),
        mode: enc.AESMode.cbc,
        padding: 'PKCS7',
      ),
    );
    final iv = enc.IV.fromSecureRandom(16);
    final ciphertext = encrypter.encrypt(jsonPlain, iv: iv);
    return {
      'iv': iv.base64,
      'ciphertext': ciphertext.base64,
      'r': DateTime.now().millisecondsSinceEpoch.toString(),
    };
  }

  Future<Map<String, dynamic>> _call(String action, String uuid) async {
    final resp = await _dio.post<Map<String, dynamic>>(
      '$_base/$action',
      data: _encryptBody(jsonEncode({'uuid': uuid})),
    );
    final data = resp.data ?? const {};
    final code = (data['resultCode'] as num?)?.toInt() ?? -1;
    if (code != 0) {
      throw YktException(
        (data['resultMsg'] as String?) ?? '接口返回异常（resultCode=$code）',
      );
    }
    return data;
  }

  /// 查询用户信息与当前使用码。
  Future<YktUser> getUser(String uuid) async {
    final data = await _call('GetUser', uuid);
    final rows = data['rows'] as List?;
    if (rows == null || rows.isEmpty) {
      throw const YktException('未查询到用户信息，请检查 UUID 是否正确');
    }
    return YktUser.fromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  /// 生成新的使用码（临时码，未激活）。
  Future<String> generateUseKey(String uuid) async {
    final data = await _call('GenerateUseKey', uuid);
    final rows = data['rows'] as List?;
    if (rows == null || rows.isEmpty) {
      throw const YktException('生成使用码失败：服务器未返回码值');
    }
    return rows.first.toString();
  }

  /// 激活使用码（领取）。
  Future<void> applyUseKey(String uuid) => _call('ApplyUseKey', uuid);

  /// 完整领取流程：生成 → 激活 → 回读最新码。
  Future<YktUser> reissueUseKey(String uuid) async {
    await generateUseKey(uuid);
    await applyUseKey(uuid);
    return getUser(uuid);
  }
}

class YktException implements Exception {
  const YktException(this.message);
  final String message;

  @override
  String toString() => message;
}

class YktUser {
  const YktUser({
    required this.userId,
    required this.accountNo,
    required this.name,
    required this.cardNo,
    required this.state,
    required this.useKey,
    required this.useKeyTemp,
    required this.openId,
  });

  factory YktUser.fromJson(Map<String, dynamic> json) => YktUser(
        userId: (json['user_id'] as num?)?.toInt() ?? 0,
        accountNo: (json['account_no'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        cardNo: (json['card_no'] ?? '').toString(),
        state: (json['state'] ?? '').toString(),
        useKey: (json['use_key'] ?? '').toString(),
        useKeyTemp: (json['use_key_temp'] ?? '').toString(),
        openId: (json['open_id'] ?? '').toString(),
      );

  final int userId;
  final String accountNo;
  final String name;
  final String cardNo;
  final String state;
  final String useKey;
  final String useKeyTemp;
  final String openId;

  /// state == '0' 视为已开启可使用。
  bool get enabled => state == '0';

  /// 当前生效的使用码（临时码优先，与前端行为一致）。
  String get currentKey => useKeyTemp.isNotEmpty ? useKeyTemp : useKey;

  /// 页面只展示前 8 位（水控机输入的数字）。
  String get displayKey =>
      currentKey.length >= 8 ? currentKey.substring(0, 8) : currentKey;
}
