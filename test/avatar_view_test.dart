import 'package:caii_pocket/ui/widget/avatar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 1×1 透明 PNG，够用来验证 base64 头像确实能渲染。
const _pixelPng =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
    'AAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

void main() {
  group('AvatarSource', () {
    test('识别 data URI 并能解码出字节', () {
      expect(AvatarSource.isDataUri(_pixelPng), isTrue);
      expect(AvatarSource.isRemote(_pixelPng), isFalse);
      final bytes = AvatarSource.decodeDataUri(_pixelPng);
      expect(bytes, isNotNull);
      expect(bytes!.isNotEmpty, isTrue);
    });

    test('普通链接不是 data URI', () {
      const url = 'https://portal.caii.edu.cn/avatar/u.png';
      expect(AvatarSource.isDataUri(url), isFalse);
      expect(AvatarSource.isRemote(url), isTrue);
      expect(AvatarSource.decodeDataUri(url), isNull);
    });

    test('残缺的 data URI 不抛异常', () {
      expect(AvatarSource.decodeDataUri('data:image/png;base64'), isNull);
      expect(AvatarSource.decodeDataUri('data:image/png;base64,%%%'), isNull);
    });
  });

  group('AvatarView', () {
    testWidgets('base64 头像渲染成内存图而不是首字', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarView(name: '杨宏茂', avatar: _pixelPng),
          ),
        ),
      );
      await tester.pump();

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<MemoryImage>());
      expect(find.text('杨'), findsNothing);
    });

    testWidgets('没有头像时回落到姓名首字', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: AvatarView(name: '杨宏茂')),
        ),
      );
      expect(find.text('杨'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });
}
