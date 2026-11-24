import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import 'package:encrypt/encrypt.dart' as enc;

/// 金智 authserver 的密码加密（与页面 encrypt.js 等价）。
///
/// 页面做法（实测 encrypt.js）：
///   encryptPassword(pwd, salt) =>
///     AES-CBC( randomString(64) + pwd , key = salt , iv = randomString(16) ) → base64
/// 其中 randomString 的字符表与 JS 完全一致。服务端只解前 64 个填充字符。
class CasCrypto {
  const CasCrypto._();

  static const _chars = 'ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678';

  static final Random _random = Random.secure();

  static String randomString(int length) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(_chars[_random.nextInt(_chars.length)]);
    }
    return buffer.toString();
  }

  static String encryptPassword(String password, String salt) {
    final keyBytes = _normalizeKey(salt);
    final encrypter = enc.Encrypter(
      enc.AES(keyBytes, mode: enc.AESMode.cbc, padding: 'PKCS7'),
    );
    final iv = enc.IV.fromUtf8(randomString(16));
    final plain = utf8.encode('${randomString(64)}$password');
    return encrypter.encryptBytes(plain, iv: iv).base64;
  }

  /// salt 正常是 16 字符；个别部署给 64 字符，AES 只接受 16/24/32 字节，
  /// 这里做一次保守截断，保证不会因为密钥长度直接抛错。
  static enc.Key _normalizeKey(String salt) {
    final bytes = utf8.encode(salt);
    if (bytes.length == 16 || bytes.length == 24 || bytes.length == 32) {
      return enc.Key(Uint8List.fromList(bytes));
    }
    final trimmed = bytes.length > 32
        ? bytes.sublist(0, 32)
        : List<int>.from(bytes)..addAll(List<int>.filled(16 - bytes.length, 0));
    return enc.Key(Uint8List.fromList(trimmed));
  }
}
