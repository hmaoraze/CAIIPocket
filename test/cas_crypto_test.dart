import 'dart:convert';

import 'package:caii_pocket/models/course/course.dart';
import 'package:caii_pocket/services/cas/cas_crypto.dart';
import 'package:caii_pocket/services/cas/cas_login_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CasCrypto', () {
    test('加密结果是合法 base64，且长度是 16 的整数倍', () {
      final encrypted = CasCrypto.encryptPassword('passw0rd', '69Mgdu4vezJjyPSP');
      final bytes = base64Decode(encrypted);
      expect(bytes.length % 16, 0);
      expect(bytes, isNotEmpty);
    });

    test('同一个密码两次加密结果不同（随机 iv 与随机填充）', () {
      final a = CasCrypto.encryptPassword('passw0rd', '69Mgdu4vezJjyPSP');
      final b = CasCrypto.encryptPassword('passw0rd', '69Mgdu4vezJjyPSP');
      expect(a, isNot(b));
    });

    test('明文是 64 位随机前缀 + 密码，密文长度可推算', () {
      // (64 + 8) 字节 → 补齐到 80 → base64 后 108 个字符（含 padding）
      final encrypted = CasCrypto.encryptPassword('12345678', '69Mgdu4vezJjyPSP');
      final bytes = base64Decode(encrypted);
      expect(bytes.length, 80);
    });

    test('随机串只使用与 encrypt.js 相同的字符表', () {
      const charset = 'ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678';
      final sample = CasCrypto.randomString(200);
      expect(sample.split('').every(charset.contains), isTrue);
      expect(sample.length, 200);
    });
  });

  group('CasLoginForm.parse', () {
    const html = '''
      <input type="hidden" id="pwdEncryptSalt" value="69Mgdu4vezJjyPSP" />
      <input type="hidden" id="execution" name="execution" value="e1s2" />
      <input type="hidden" id="lt" name="lt" value="" />
      <span id="showErrorTip"><span>该账号非常用账号或用户名密码有误</span></span>
    ''';

    test('能取出 salt / execution / 错误提示', () {
      final form = CasLoginForm.parse(html);
      expect(form.salt, '69Mgdu4vezJjyPSP');
      expect(form.execution, 'e1s2');
      expect(form.valid, isTrue);
      expect(CasLoginForm.parseError(html), '该账号非常用账号或用户名密码有误');
    });

    test('页面不带 needCaptcha=true 时不要求验证码', () {
      expect(CasLoginForm.needCaptcha(html), isFalse);
      expect(
        CasLoginForm.needCaptcha('<script>var needCaptcha = "true";</script>'),
        isTrue,
      );
    });

    test('页面结构变化时给出保守默认值而不是抛异常', () {
      final form = CasLoginForm.parse('<html></html>');
      expect(form.valid, isFalse);
      expect(form.execution, 'e1s1');
    });
  });

  group('Course', () {
    test('JSON 往返不丢字段', () {
      const course = Course(
        id: 'c1',
        name: '民航概论',
        weekday: 3,
        startPeriod: 3,
        endPeriod: 4,
        teacher: '张老师',
        location: '教学楼 A301',
        startWeek: 2,
        endWeek: 16,
        colorSeed: 4,
      );
      final restored = Course.fromJson(
        jsonDecode(jsonEncode(course.toJson())) as Map<String, dynamic>,
      );
      expect(restored.name, course.name);
      expect(restored.weekday, 3);
      expect(restored.spanPeriods, 2);
      expect(restored.timeRange, isNotEmpty);
      expect(restored.activeInWeek(1), isFalse);
      expect(restored.activeInWeek(8), isTrue);
    });
  });
}
