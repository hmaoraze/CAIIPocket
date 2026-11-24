// 真实网络探针：验证 Dart 侧的密码加密与登录请求是否被服务端接受。
//
// 用法：dart run tool/cas_probe.dart <学号>
// 只发一次登录请求，密码固定为错误值，用来确认服务端回的是"密码有误"而不是"参数错误"。
import 'dart:convert';
import 'dart:io';

import 'package:caii_pocket/services/cas/cas_crypto.dart';
import 'package:caii_pocket/services/cas/cas_login_form.dart';
import 'package:caii_pocket/services/portal/portal_endpoints.dart';

Future<void> main(List<String> args) async {
  final username = args.isEmpty ? 'testuser0001' : args.first;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  final cookie = <String, String>{};

  Future<HttpClientResponse> get(String url) async {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set('User-Agent', 'caii-pocket-probe/0.1');
    if (cookie.isNotEmpty) {
      request.headers.set(
        'Cookie',
        cookie.entries.map((e) => '${e.key}=${e.value}').join('; '),
      );
    }
    final response = await request.close();
    for (final c in response.cookies) {
      cookie[c.name] = c.value;
    }
    return response;
  }

  stdout.writeln('GET ${PortalEndpoints.loginUrl}');
  final pageResponse = await get(PortalEndpoints.loginUrl);
  final html = await pageResponse.transform(utf8.decoder).join();
  final form = CasLoginForm.parse(html);
  stdout.writeln('status=${pageResponse.statusCode} '
      'salt=${form.salt} execution=${form.execution} '
      'cookies=${cookie.keys.join(",")}');

  final body = <String, String>{
    'username': username,
    'password': CasCrypto.encryptPassword('probe-not-a-real-password', form.salt!),
    'captcha': '',
    '_eventId': 'submit',
    'cllt': 'userNameLogin',
    'dllt': 'generalLogin',
    'lt': form.lt,
    'execution': form.execution,
    'rmShown': '1',
  };

  final request = await client.postUrl(Uri.parse(PortalEndpoints.loginUrl));
  request.headers
    ..set('Content-Type', 'application/x-www-form-urlencoded')
    ..set('User-Agent', 'caii-pocket-probe/0.1')
    ..set('Referer', PortalEndpoints.loginUrl);
  if (cookie.isNotEmpty) {
    request.headers.set(
      'Cookie',
      cookie.entries.map((e) => '${e.key}=${e.value}').join('; '),
    );
  }
  request.write(body.entries
      .map((e) => '${Uri.encodeQueryComponent(e.key)}='
          '${Uri.encodeQueryComponent(e.value)}')
      .join('&'));

  final response = await request.close();
  final text = await response.transform(utf8.decoder).join();
  stdout.writeln('POST status=${response.statusCode} '
      'location=${response.headers.value('location')}');
  stdout.writeln('errorTip=${CasLoginForm.parseError(text) ?? "(none)"}');
  stdout.writeln('needCaptcha=${CasLoginForm.needCaptcha(text)}');
  client.close(force: true);
}
