import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show window;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(Uri testFile) : super(testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (!result.passed) {
      final String error = await generateFailureOutput(result, golden, basedir);
      if (result.diffPercent >= .06) {
        throw FlutterError(error);
      } else {
        print('Warning - golden differed less than .06% (${result.diffPercent}%), '
            'ignoring failure but producing output');
        print(error);
      }
    }
    return true;
  }
}

Future<void> _checkWidgetAndGolden(Key key, String filename) async {
  final Finder widgetFinder = find.byKey(key);
  expect(widgetFinder, findsOneWidget);
  await expectLater(widgetFinder, matchesGoldenFile('golden_widget/$filename'));
}

void main() {
  late FakeHttpClientResponse fakeResponse;
  late FakeHttpClientRequest fakeRequest;
  late FakeHttpClient fakeHttpClient;

  setUpAll(() {
    final LocalFileComparator oldComparator = goldenFileComparator as LocalFileComparator;
    final _TolerantComparator newComparator = _TolerantComparator(Uri.parse(oldComparator.basedir.toString() + 'test'));
    expect(oldComparator.basedir, newComparator.basedir);
    goldenFileComparator = newComparator;
  });

  setUp(() {
    PictureProvider.cache.clear();
    svg.cacheColorFilterOverride = null;
    fakeResponse = FakeHttpClientResponse();
    fakeRequest = FakeHttpClientRequest(fakeResponse);
    fakeHttpClient = FakeHttpClient(fakeRequest);
  });

  testWidgets('SvgPicture does not use a color filtering widget when no color specified', (WidgetTester tester) async {
    expect(PictureProvider.cache.count, 0);
    await tester.pumpWidget(
      SvgPicture.string(
        svgStr,
        width: 100.0,
        height: 100.0,
      ),
    );
    await tester.pumpAndSettle();
    expect(PictureProvider.cache.count, 1);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  testWidgets('SvgPicture does not invalidate the cache when color changes', (WidgetTester tester) async {
    expect(PictureProvider.cache.count, 0);
    await tester.pumpWidget(
      SvgPicture.string(
        svgStr,
        width: 100.0,
        height: 100.0,
        color: const Color(0xFF990000),
      ),
    );

    expect(PictureProvider.cache.count, 1);

    await tester.pumpWidget(
      SvgPicture.string(
        svgStr,
        width: 100.0,
        height: 100.0,
        color: const Color(0xFF990099),
      ),
    );

    expect(PictureProvider.cache.count, 1);
  });

  testWidgets('SvgPicture does invalidate the cache when color changes and color filter is cached', (WidgetTester tester) async {
    expect(PictureProvider.cache.count, 0);
    await tester.pumpWidget(
      SvgPicture.string(
        svgStr,
        width: 100.0,
        height: 100.0,
        color: const Color(0xFF990000),
        cacheColorFilter: true,
      ),
    );

    expect(PictureProvider.cache.count, 1);

    await tester.pumpWidget(
      SvgPicture.string(
        svgStr,
        width: 100.0,
        height: 100.0,
        color: const Color(0xFF990099),
        cacheColorFilter: true,
      ),
    );

    expect(PictureProvider.cache.count, 2);
  });

  testWidgets('SvgPicture does invalidate the cache when color changes and color filter is cached (override)', (WidgetTester tester) async {
    svg.cacheColorFilterOverride = true;
    expect(PictureProvider.cache.count, 0);
    await tester.pumpWidget(
      SvgPicture.string(
        svgStr,
        width: 100.0,
        height: 100.0,
        color: const Color(0xFF990000),
      ),
    );

    expect(PictureProvider.cache.count, 1);

    await tester.pumpWidget(
      SvgPicture.string(
        svgStr,
        width: 100.0,
        height: 100.0,
        color: const Color(0xFF990099),
      ),
    );

    expect(PictureProvider.cache.count, 2);
  });

  testWidgets('SvgPicture can work with a FittedBox', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(100, 100)),
        child: Row(
          key: key,
          textDirection: TextDirection.ltr,
          children: <Widget>[
            Flexible(
              child: FittedBox(
                fit: BoxFit.fitWidth,
                child: SvgPicture.string(
                  svgStr,
                  width: 20.0,
                  height: 14.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final Finder widgetFinder = find.byKey(key);
    expect(widgetFinder, findsOneWidget);
  });

  testWidgets('SvgPicture.string', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromWindow(window),
        child: RepaintBoundary(
          key: key,
          child: SvgPicture.string(
            svgStr,
            width: 100.0,
            height: 100.0,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _checkWidgetAndGolden(key, 'flutter_logo.string.png');
  });

  testWidgets('SvgPicture natural size', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromWindow(window),
        child: Center(
          key: key,
          child: SvgPicture.string(
            svgStr,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _checkWidgetAndGolden(key, 'flutter_logo.natural.png');
  });

  testWidgets('SvgPicture clipped', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromWindow(window),
        child: Center(
          key: key,
          child: SvgPicture.string(
            stickFigureSvgStr,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _checkWidgetAndGolden(key, 'stick_figure.withclipping.png');
  });

  testWidgets('Svg in svg', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromWindow(window),
        child: Center(
          key: key,
          child: SvgPicture.string(
            svgInSvgStr,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _checkWidgetAndGolden(key, 'svg_in_svg.png');
  });

  testWidgets('SvgPicture.string ltr', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromWindow(window),
        child: RepaintBoundary(
          key: key,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Container(
                    color: const Color(0xFF0D47A1),
                    height: 100.0,
                  ),
                ),
                SvgPicture.string(
                  svgStr,
                  matchTextDirection: true,
                  height: 100.0,
                  width: 100.0,
                ),
                Expanded(
                  child: Container(
                    color: const Color(0xFF42A5F5),
                    height: 100.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _checkWidgetAndGolden(key, 'flutter_logo.string.ltr.png');
  });

  testWidgets('SvgPicture.string rtl', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromWindow(window),
        child: RepaintBoundary(
          key: key,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Container(
                    color: const Color(0xFF0D47A1),
                    height: 100.0,
                  ),
                ),
                SvgPicture.string(
                  svgStr,
                  matchTextDirection: true,
                  height: 100.0,
                  width: 100.0,
                ),
                Expanded(
                  child: Container(
                    color: const Color(0xFF42A5F5),
                    height: 100.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _checkWidgetAndGolden(key, 'flutter_logo.string.rtl.png');
  });

  testWidgets('SvgPicture.memory', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromWindow(window),
        child: RepaintBoundary(
          key: key,
          child: SvgPicture.memory(
            svgBytes,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _checkWidgetAndGolden(key, 'flutter_logo.memory.png');
  });

  testWidgets('SvgPicture.asset', (WidgetTester tester) async {
    final FakeAssetBundle fakeAsset = FakeAssetBundle();
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromWindow(window),
        child: RepaintBoundary(
          key: key,
          child: SvgPicture.asset(
            'test.svg',
            bundle: fakeAsset,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _checkWidgetAndGolden(key, 'flutter_logo.asset.png');
  });

  testWidgets('SvgPicture.asset DefaultAssetBundle', (WidgetTester tester) async {
    final FakeAssetBundle fakeAsset = FakeAssetBundle();
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData.fromWindow(window),
          child: DefaultAssetBundle(
            bundle: fakeAsset,
            child: RepaintBoundary(
              key: key,
              child: SvgPicture.asset(
                'test.svg',
                semanticsLabel: 'Test SVG',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _checkWidgetAndGolden(key, 'flutter_logo.asset.png');
  });

  testWidgets('SvgPicture.network', (WidgetTester tester) async {
    await HttpOverrides.runZoned(() async {
      final GlobalKey key = GlobalKey();
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromWindow(window),
          child: RepaintBoundary(
            key: key,
            child: SvgPicture.network(
              'test.svg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _checkWidgetAndGolden(key, 'flutter_logo.network.png');
    }, createHttpClient: (SecurityContext? c) => fakeHttpClient);
  });

  testWidgets('SvgPicture.network with headers', (WidgetTester tester) async {
    await HttpOverrides.runZoned(() async {
      final GlobalKey key = GlobalKey();
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromWindow(window),
          child: RepaintBoundary(
            key: key,
            child: SvgPicture.network('test.svg', headers: const <String, String>{'a': 'b'}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fakeRequest.headers['a']!.single, 'b');
    }, createHttpClient: (SecurityContext? c) => fakeHttpClient);
  });

  testWidgets('SvgPicture can be created without a MediaQuery', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: SvgPicture.string(
          svgStr,
          width: 100.0,
          height: 100.0,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _checkWidgetAndGolden(key, 'flutter_logo.string.png');
  });

  testWidgets('SvgPicture.network HTTP exception', (WidgetTester tester) async {
    await HttpOverrides.runZoned(() async {
      expect(() async {
        fakeResponse.statusCode = 400;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData.fromWindow(window),
            child: SvgPicture.network(
              'notFound.svg',
            ),
          ),
        );
      }, isNotNull);
    }, createHttpClient: (SecurityContext? c) => fakeHttpClient);
  });

  testWidgets('SvgPicture semantics', (WidgetTester tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          child: SvgPicture.string(
            svgStr,
            semanticsLabel: 'Flutter Logo',
            width: 100.0,
            height: 100.0,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(Semantics), findsOneWidget);
    expect(find.bySemanticsLabel('Flutter Logo'), findsOneWidget);
  }, semanticsEnabled: true);

  testWidgets('SvgPicture semantics - no label', (WidgetTester tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          child: SvgPicture.string(
            svgStr,
            width: 100.0,
            height: 100.0,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(Semantics), findsOneWidget);
  }, semanticsEnabled: true);

  testWidgets('SvgPicture semantics - exclude', (WidgetTester tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          child: SvgPicture.string(
            svgStr,
            excludeFromSemantics: true,
            width: 100.0,
            height: 100.0,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(Semantics), findsNothing);
  }, semanticsEnabled: true);

  testWidgets('SvgPicture colorFilter - flutter logo', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: SvgPicture.string(
          svgStr,
          width: 100.0,
          height: 100.0,
          color: const Color(0xFF990000),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _checkWidgetAndGolden(key, 'flutter_logo.string.color_filter.png');
  });

  testWidgets('SvgPicture colorFilter - flutter logo - BlendMode.color', (WidgetTester tester) async {
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: SvgPicture.string(
          svgStr,
          width: 100.0,
          height: 100.0,
          color: const Color(0xFF990000),
          colorBlendMode: BlendMode.color,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _checkWidgetAndGolden(key, 'flutter_logo.string.color_filter.blendmode_color.png');
  });

  testWidgets('SvgPicture colorFilter with text', (WidgetTester tester) async {
    const String svgData = '''<svg font-family="arial" font-size="14" height="160" width="88" xmlns="http://www.w3.org/2000/svg">
  <g stroke="#000" stroke-linecap="round" stroke-width="2" stroke-opacity="1" fill-opacity="1" stroke-linejoin="miter">
    <g>
      <line x1="60" x2="88" y1="136" y2="136"/>
    </g>
    <g>
      <text stroke-width="1" x="9" y="28">2</text>
    </g>
    <g>
      <text stroke-width="1" x="73" y="156">1</text>
    </g>
  </g>
</svg>''';
    final GlobalKey key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: SvgPicture.string(
          svgData,
          width: 100.0,
          height: 100.0,
          color: const Color(0xFF990000),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _checkWidgetAndGolden(key, 'text_color_filter.png');
  });

  testWidgets('Can take AlignmentDirectional', (WidgetTester tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: SvgPicture.string(
        svgStr,
        alignment: AlignmentDirectional.bottomEnd,
      ),
    ));
    expect(find.byType(SvgPicture), findsOneWidget);
  });

  testWidgets('SvgPicture.string respects clipBehavior', (WidgetTester tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: SvgPicture.string(svgStr),
    ));
    await tester.pumpAndSettle();

    // Check that the render object has received the default clip behavior.
    final RenderFittedBox renderObject = tester.allRenderObjects.whereType<RenderFittedBox>().first;
    expect(renderObject.clipBehavior, equals(Clip.hardEdge));

    // Pump a new widget to check that the render object can update its clip
    // behavior.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SvgPicture.string(svgStr, clipBehavior: Clip.antiAlias),
      ),
    );
    await tester.pumpAndSettle();
    expect(renderObject.clipBehavior, equals(Clip.antiAlias));
  });

  testWidgets('SvgPicture.asset respects clipBehavior', (WidgetTester tester) async {
    final FakeAssetBundle fakeAsset = FakeAssetBundle();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: SvgPicture.asset(
        'test.svg',
        bundle: fakeAsset,
      ),
    ));
    await tester.pumpAndSettle();

    // Check that the render object has received the default clip behavior.
    final RenderFittedBox renderObject = tester.allRenderObjects.whereType<RenderFittedBox>().first;
    expect(renderObject.clipBehavior, equals(Clip.hardEdge));

    // Pump a new widget to check that the render object can update its clip
    // behavior.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SvgPicture.asset(
          'test.svg',
          bundle: fakeAsset,
          clipBehavior: Clip.antiAlias,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(renderObject.clipBehavior, equals(Clip.antiAlias));
  });

  testWidgets('SvgPicture.memory respects clipBehavior', (WidgetTester tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: SvgPicture.memory(svgBytes),
    ));
    await tester.pumpAndSettle();

    // Check that the render object has received the default clip behavior.
    final RenderFittedBox renderObject = tester.allRenderObjects.whereType<RenderFittedBox>().first;
    expect(renderObject.clipBehavior, equals(Clip.hardEdge));

    // Pump a new widget to check that the render object can update its clip
    // behavior.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SvgPicture.memory(svgBytes, clipBehavior: Clip.antiAlias),
      ),
    );
    await tester.pumpAndSettle();
    expect(renderObject.clipBehavior, equals(Clip.antiAlias));
  });

  testWidgets('SvgPicture.network respects clipBehavior', (WidgetTester tester) async {
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SvgPicture.network('test.svg'),
        ),
      );
      await tester.pumpAndSettle();

      // Check that the render object has received the default clip behavior.
      final RenderFittedBox renderObject = tester.allRenderObjects.whereType<RenderFittedBox>().first;
      expect(renderObject.clipBehavior, equals(Clip.hardEdge));

      // Pump a new widget to check that the render object can update its clip
      // behavior.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SvgPicture.network('test.svg', clipBehavior: Clip.antiAlias),
        ),
      );
      await tester.pumpAndSettle();
      expect(renderObject.clipBehavior, equals(Clip.antiAlias));
    }, createHttpClient: (SecurityContext? c) => fakeHttpClient);
  });

  testWidgets('SvgPicture respects clipBehavior', (WidgetTester tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: SvgPicture.string(svgStr),
    ));
    await tester.pumpAndSettle();

    // Check that the render object has received the default clip behavior.
    final RenderFittedBox renderObject = tester.allRenderObjects.whereType<RenderFittedBox>().first;
    expect(renderObject.clipBehavior, equals(Clip.hardEdge));

    // Pump a new widget to check that the render object can update its clip
    // behavior.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SvgPicture.string(svgStr, clipBehavior: Clip.antiAlias),
      ),
    );
    await tester.pumpAndSettle();
    expect(renderObject.clipBehavior, equals(Clip.antiAlias));
  });

  group('SvgPicture respects em units', () {
    testWidgets('circle (cx, cy, r)', (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();

      const String svgStr = '''
<svg width="800px" height="600px" xmlns="http://www.w3.org/2000/svg">
  <circle cx="0.5em" cy="0.5em" r="0.5em" fill="orange" />
</svg>
''';

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: SvgPicture.string(
            svgStr,
            theme: const SvgTheme(fontSize: 600),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _checkWidgetAndGolden(key, 'circle.em_ex.png');
    });

    testWidgets('rect (x, y, width, height, rx, ry)', (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();

      const String svgStr = '''
<svg width="800px" height="600px" xmlns="http://www.w3.org/2000/svg">
  <rect x="2em" y="1.5em" width="4em" height="3em" rx="0.5em" ry="0.5em" fill="orange" />
</svg>
''';

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: SvgPicture.string(
            svgStr,
            theme: const SvgTheme(fontSize: 100),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _checkWidgetAndGolden(key, 'rect.em_ex.png');
    });

    testWidgets('ellipse (cx, cy, rx, ry)', (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();

      const String svgStr = '''
<svg width="800px" height="600px" xmlns="http://www.w3.org/2000/svg">
  <ellipse cx="7em" cy="4em" rx="1em" ry="2em" fill="orange" />
</svg>
''';

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: SvgPicture.string(
            svgStr,
            theme: const SvgTheme(fontSize: 100),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _checkWidgetAndGolden(key, 'ellipse.em_ex.png');
    });

    testWidgets('line (x1, y1, x2, y2)', (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();

      const String svgStr = '''
<svg width="800px" height="600px" xmlns="http://www.w3.org/2000/svg">
  <line x1="0em" y1="6em" x2="4em" y2="0em" stroke="orange" />
  <line x1="4em" y1="0em" x2="8em" y2="6em" stroke="orange" />
</svg>
''';

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: SvgPicture.string(
            svgStr,
            theme: const SvgTheme(fontSize: 100),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _checkWidgetAndGolden(key, 'line.em_ex.png');
    });
  });

  group('SvgPicture respects ex units', () {
    testWidgets('circle (cx, cy, r)', (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();

      const String svgStr = '''
<svg width="800px" height="600px" xmlns="http://www.w3.org/2000/svg">
  <circle cx="0.5ex" cy="0.5ex" r="0.5ex" fill="orange" />
</svg>
''';

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: SvgPicture.string(
            svgStr,
            theme: const SvgTheme(
              fontSize: 1500,
              xHeight: 600,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _checkWidgetAndGolden(key, 'circle.em_ex.png');
    });

    testWidgets('rect (x, y, width, height, rx, ry)', (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();

      const String svgStr = '''
<svg width="800px" height="600px" xmlns="http://www.w3.org/2000/svg">
  <rect x="2ex" y="1.5ex" width="4ex" height="3ex" rx="0.5ex" ry="0.5ex" fill="orange" />
</svg>
''';

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: SvgPicture.string(
            svgStr,
            theme: const SvgTheme(
              fontSize: 300,
              xHeight: 100,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _checkWidgetAndGolden(key, 'rect.em_ex.png');
    });

    testWidgets('ellipse (cx, cy, rx, ry)', (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();

      const String svgStr = '''
<svg width="800px" height="600px" xmlns="http://www.w3.org/2000/svg">
  <ellipse cx="7ex" cy="4ex" rx="1ex" ry="2ex" fill="orange" />
</svg>
''';

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: SvgPicture.string(
            svgStr,
            theme: const SvgTheme(
              fontSize: 300,
              xHeight: 100,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _checkWidgetAndGolden(key, 'ellipse.em_ex.png');
    });

    testWidgets('line (x1, y1, x2, y2)', (WidgetTester tester) async {
      final GlobalKey key = GlobalKey();

      const String svgStr = '''
<svg width="800px" height="600px" xmlns="http://www.w3.org/2000/svg">
  <line x1="0ex" y1="6ex" x2="4ex" y2="0ex" stroke="orange" />
  <line x1="4ex" y1="0ex" x2="8ex" y2="6ex" stroke="orange" />
</svg>
''';

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: SvgPicture.string(
            svgStr,
            theme: const SvgTheme(
              fontSize: 300,
              xHeight: 100,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _checkWidgetAndGolden(key, 'line.em_ex.png');
    });
  });

  testWidgets('SvgPicture - two of the same', (WidgetTester tester) async {
    // Regression test to make sure the same SVG can render twice in the same
    // view. If layers are incorrectly reused, this will fail.
    await tester.pumpWidget(RepaintBoundary(
        child: Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: <Widget>[
          SvgPicture.string(simpleSvg),
          SvgPicture.string(simpleSvg),
        ],
      ),
    )));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(RepaintBoundary),
      matchesGoldenFile('golden_widget/two_of_same.png'),
    );
  });

  testWidgets('Update widget without a cache does not result in an disposed picture', (WidgetTester tester) async {
    final int oldCacheSize = PictureProvider.cache.maximumSize;
    PictureProvider.cache.maximumSize = 0;
    final GlobalKey key = GlobalKey();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SvgPicture(
            FakePictureProvider(
              SvgPicture.svgStringDecoderBuilder,
              simpleSvg,
            ),
            key: key),
      ),
    );

    expect(find.byKey(key), findsOneWidget);

    // Update the widget with a new incompatible key.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SvgPicture(
            FakePictureProvider(
              SvgPicture.svgStringDecoderBuilder,
              stickFigureSvgStr,
            ),
            key: key),
      ),
    );

    expect(find.byKey(key), findsOneWidget);
    await tester.pumpAndSettle();
    PictureProvider.cache.maximumSize = oldCacheSize;
  });

  testWidgets('state maintains a handle', (WidgetTester tester) async {
    final int oldCacheSize = PictureProvider.cache.maximumSize;
    PictureProvider.cache.maximumSize = 1;
    final GlobalKey key = GlobalKey();
    final FakePictureProvider provider = FakePictureProvider(
      SvgPicture.svgStringDecoderBuilder,
      simpleSvg,
    );

    final PictureStream stream = provider.resolve(
      createLocalPictureConfiguration(key.currentContext),
    );
    final Completer<PictureInfo> completer = Completer<PictureInfo>();
    void listener(PictureInfo? info, bool syncCall) {
      completer.complete(info!);
    }

    stream.addListener(listener);

    final PictureInfo info = await completer.future;
    expect(info.debugHandleCount, 1);
    stream.removeListener(listener);
    // Still in cache.
    expect(info.debugHandleCount, 1);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SvgPicture(provider, key: key),
      ),
    );
    expect(find.byKey(key), findsOneWidget);
    expect(info.debugHandleCount, 3);
    PictureProvider.cache.clear();
    expect(info.debugHandleCount, 3);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(info.debugHandleCount, 0);

    PictureProvider.cache.maximumSize = oldCacheSize;
  });
}

class FakePictureProvider extends StringPicture {
  FakePictureProvider(
    PictureInfoDecoderBuilder<String> decoderBuilder,
    String string,
  ) : super(decoderBuilder, string);

  int resolveCount = 0;

  @override
  PictureStream resolve(
    PictureConfiguration picture, {
    PictureErrorListener? onError,
  }) {
    resolveCount += 1;
    return super.resolve(picture, onError: onError);
  }

  @override
  // ignore: hash_and_equals, avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) {
    // Picture providers should be compared based on key. Make sure tests don't
    // cheat this check by using an identical provider.
    return false;
  }
}

class FakeAssetBundle extends Fake implements AssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return svgStr;
  }
}

class FakeHttpClient extends Fake implements HttpClient {
  FakeHttpClient(this.request);

  FakeHttpClientRequest request;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => request;
}

class FakeHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, String?> values = <String, String?>{};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = value.toString();
  }

  @override
  List<String>? operator [](String key) {
    return <String>[values[key]!];
  }
}

class FakeHttpClientRequest extends Fake implements HttpClientRequest {
  FakeHttpClientRequest(this.response);

  FakeHttpClientResponse response;

  @override
  final HttpHeaders headers = FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => response;
}

class FakeHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int statusCode = 200;

  @override
  int contentLength = svgStr.length;

  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<Uint8List>.fromIterable(<Uint8List>[svgBytes]).listen(
      onData,
      onDone: onDone,
      onError: onError,
      cancelOnError: cancelOnError,
    );
  }
}

const String simpleSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0 0 20 20">
  <rect x="5" y="5" width="10" height="10"/>
</svg>
''';

const String svgStr = '''
<svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0 0 166 202">
  <defs>
      <linearGradient id="triangleGradient">
          <stop offset="20%" stop-color="#000000" stop-opacity=".55" />
          <stop offset="85%" stop-color="#616161" stop-opacity=".01" />
      </linearGradient>
      <linearGradient id="rectangleGradient" x1="0%" x2="0%" y1="0%" y2="100%">
          <stop offset="20%" stop-color="#000000" stop-opacity=".15" />
          <stop offset="85%" stop-color="#616161" stop-opacity=".01" />
      </linearGradient>
  </defs>
  <path fill="#42A5F5" fill-opacity=".8" d="M37.7 128.9 9.8 101 100.4 10.4 156.2 10.4"/>
  <path fill="#42A5F5" fill-opacity=".8" d="M156.2 94 100.4 94 79.5 114.9 107.4 142.8"/>
  <path fill="#0D47A1" d="M79.5 170.7 100.4 191.6 156.2 191.6 156.2 191.6 107.4 142.8"/>
  <g transform="matrix(0.7071, -0.7071, 0.7071, 0.7071, -77.667, 98.057)">
      <rect width="39.4" height="39.4" x="59.8" y="123.1" fill="#42A5F5" />
      <rect width="39.4" height="5.5" x="59.8" y="162.5" fill="url(#rectangleGradient)" />
  </g>
  <path d="M79.5 170.7 120.9 156.4 107.4 142.8" fill="url(#triangleGradient)" />
</svg>
''';

const String stickFigureSvgStr = '''
<?xml version="1.0" encoding="UTF-8"?>
<svg width="27px" height="90px" viewBox="5 10 18 70" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
    <!-- Generator: Sketch 53 (72520) - https://sketchapp.com -->
    <title>svg/stick_figure</title>
    <desc>Created with Sketch.</desc>
    <g id="Page-1" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
        <g id="iPhone-8" transform="translate(-53.000000, -359.000000)" stroke="#979797">
            <g id="stick_figure" transform="translate(53.000000, 359.000000)">
                <ellipse id="Oval" fill="#D8D8D8" cx="13.5" cy="12" rx="12" ry="11.5"></ellipse>
                <path d="M13.5,24 L13.5,71.5" id="Line" stroke-linecap="square"></path>
                <path d="M13.5,71.5 L1,89.5" id="Line-2" stroke-linecap="square"></path>
                <path d="M13.5,37.5 L1,55.5" id="Line-2-Copy-2" stroke-linecap="square"></path>
                <path d="M26.5,71.5 L14,89.5" id="Line-2" stroke-linecap="square" transform="translate(20.000000, 80.500000) scale(-1, 1) translate(-20.000000, -80.500000) "></path>
                <path d="M26.5,37.5 L14,55.5" id="Line-2-Copy" stroke-linecap="square" transform="translate(20.000000, 46.500000) scale(-1, 1) translate(-20.000000, -46.500000) "></path>
            </g>
        </g>
    </g>
</svg>
''';

const String svgInSvgStr = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 4000 4000">
    <defs/>
    <g id="outline_shader" data-name="outline+shader">
        <g id="monKeyBody">
            <path id="frame" fill="none" d="M0 0h4000v4000H0z"/>
            <g id="body">
                <path d="M2304.67 3292.92a204.73 204.73 0 0 1-29.56-2.28c-50.77-7.42-115.16-32.27-196.86-76a25 25 0 0 1 23.59-44.09c75.45 40.37 136.18 64.12 180.5 70.6 28.93 4.23 49.75 1 61.88-9.64 13.61-11.92 12.39-33 8.83-72.39-4.17-46.12-9.36-103.53 19.78-169.51 22.06-50 60.82-97.58 106.32-130.66 24.68-17.94 50.48-31.1 76.69-39.12 29.15-8.92 58.11-11.24 86.08-6.92 34.55 5.35 69.21 20.88 97.6 43.73 32.6 26.24 54.08 59.73 62.13 96.86 6.59 30.41 4.83 66.52-4.71 96.6-12.26 38.65-36.7 66.29-68.82 77.83a102.94 102.94 0 0 1-35 6c-49.4 0-90.4-33.45-95.84-38.08a25 25 0 1 1 32.42-38.06c.43.36 43.66 36.65 81.49 23.06 21.92-7.87 32.8-29.3 38.06-45.89 6.91-21.79 8.25-49 3.5-70.89-7.07-32.63-28.16-55.26-44.61-68.5-21.34-17.18-48.27-29.3-73.9-33.27-28.11-4.34-72.73-1.44-125.72 37.07-38.58 28.05-71.38 68.29-90 110.42-23.91 54.16-19.56 102.32-15.72 144.81 4 43.84 7.71 85.25-25.67 114.5-18.03 15.9-42.34 23.82-72.46 23.82zM1580.05 3154.46a62.49 62.49 0 0 1-62.49-62.27c-.35-95.35 34-193.09 99.3-282.65 56-76.83 132.08-142.11 208.64-179.11a62.5 62.5 0 1 1 54.39 112.57c-58.66 28.35-117.72 79.46-162 140.22-34.53 47.35-75.62 122-75.3 208.54a62.5 62.5 0 0 1-62.27 62.73z" stroke-miterlimit="10" stroke="#333" stroke-width="5" fill="#656930"/>
                <path d="M1601 3260.17a72.37 72.37 0 0 1-25.27-4.57c-21.18-7.88-38.24-24.19-50.7-48.49a150.3 150.3 0 0 1-15.12-48.05 115.4 115.4 0 0 1 2.11-43.78c5.57-22 17.94-40.42 35.76-53.19a72.5 72.5 0 0 1 111 81.79 72.53 72.53 0 0 1-57.78 116.29z" fill="#f7c394" stroke-miterlimit="10" stroke="#333" stroke-width="5"/>
                <path d="M1864.5 3526.24c-1.28 0-2.56 0-3.86-.08a95 95 0 0 1-91.13-98.71c4.64-116.19 33.54-197 54.63-256 6.3-17.61 11.74-32.82 15.66-46.38a95 95 0 1 1 182.53 52.74c-5.55 19.23-12.22 37.88-19.28 57.62-18.85 52.7-40.21 112.44-43.69 199.59a95 95 0 0 1-94.86 91.22z" stroke-miterlimit="10" stroke="#333" stroke-width="5" fill="#656930"/>
                <path d="M1910 3556.61a67.37 67.37 0 0 1-21.26-3.45c-27.72-9.2-93.83-15.48-147.71.23a67.5 67.5 0 1 1-37.78-129.61c46.2-13.47 92.28-15.49 122.79-14.82 39.22.86 76.58 6.57 105.2 16.06a67.51 67.51 0 0 1-21.24 131.59z" fill="#f7c394" stroke-miterlimit="10" stroke="#333" stroke-width="5"/>
                <path d="M2135.37 3528.07a95 95 0 0 1-94.76-89.56c-5-87.08-27.4-146.43-47.17-198.81-7.4-19.61-14.39-38.14-20.28-57.27a95 95 0 0 1 181.59-55.91c4.15 13.49 9.85 28.6 16.46 46.1 22.12 58.62 52.42 138.91 59.09 255a95 95 0 0 1-89.4 100.29c-1.85.09-3.7.16-5.53.16z" stroke-miterlimit="10" stroke="#333" stroke-width="5" fill="#656930"/>
                <path d="M2090 3556.61a67.51 67.51 0 0 1-21.25-131.61c28.62-9.49 66-15.2 105.2-16.06 30.51-.67 76.59 1.35 122.79 14.82a67.5 67.5 0 1 1-37.74 129.63c-53.88-15.71-120-9.43-147.71-.23a67.41 67.41 0 0 1-21.29 3.45z" fill="#f7c394" stroke-miterlimit="10" stroke="#333" stroke-width="5"/>
                <path d="M2411.42 3137.38a62.52 62.52 0 0 1-62.26-68.8c5.42-53.52-18.62-122.19-65.95-188.39-44.74-62.6-107-117.39-162.44-143a62.5 62.5 0 1 1 52.42-113.47c37.53 17.33 76.84 43.49 113.66 75.63a638.57 638.57 0 0 1 98.05 108.15c65.71 91.92 97.19 189.11 88.63 273.68a62.51 62.51 0 0 1-62.11 56.2z" stroke-miterlimit="10" stroke="#333" stroke-width="5" fill="#656930"/>
                <path d="M2396.8 3259.89a72.53 72.53 0 0 1-58.59-115.27 72.5 72.5 0 0 1 109.6-83.72c18 12.46 30.73 30.63 36.68 52.55a115.44 115.44 0 0 1 2.88 43.75c-4.06 35.05-23.3 81.66-64.13 97.67a72.45 72.45 0 0 1-26.44 5.02z" fill="#f7c394" stroke-miterlimit="10" stroke="#333" stroke-width="5"/>
                <path d="M2025.55 2468.72c55.31 3.41 93.41 43.63 127.17 80.31 39.32 42.72 80.12 104.46 119 245.31 39.4 142.77 45.88 220.06 45.88 292 0 153.62-140.68 305.09-320 306.63-175.53 1.51-319-153-319-306.63 0-72.8 12.64-145.29 62.27-292.31 48.16-142.67 92.57-200.23 125.82-235.11 37.52-39.33 90.03-94.43 158.86-90.2z" stroke-miterlimit="10" stroke="#333" stroke-width="5" fill="#656930"/>
                <path d="M1997.29 2512.77c41-.36 82.22 51.85 113.58 106.22 48.06 83.32 65.36 157.62 70.56 181.37 32.46 148.28 54.24 271.27-6 346.6-59.91 74.89-132.36 85.58-175.41 85.58-47.55 0-118.32-8.27-177.41-81.89-58.83-73.29-34.76-194.73 3.51-350.46 3.93-16 38.3-103.8 95.44-210.33 18.21-33.99 42.82-76.8 75.73-77.09zM863.8 1836.78c-109.3 103.92-60.91 310.4 16.55 426.94 110.37 166.07 358.19 267.53 482.59 176 129.94-95.63 107.64-388.85-48.6-538.55-116.65-111.8-337.5-171.86-450.54-64.39z" fill="#f7c394" stroke-miterlimit="10" stroke="#333" stroke-width="5"/>
                <path d="M995.57 1954.6c-64.75 69.33-26.65 197.17 26.33 267.46 75.51 100.15 234.9 154.61 309.6 92.47 78-64.9 53.06-248.18-50.63-336.34-77.41-65.83-218.33-95.29-285.3-23.59z" fill="#ffc9a1"/>
                <path d="M3133.19 1832.12c111.1 102 66.32 309.29-9.09 427.16-107.46 168-353.47 273.75-479.46 184.37-131.58-93.35-114.4-386.92 39.2-539.32 114.68-113.78 334.45-177.69 449.35-72.21z" fill="#f7c394" stroke-miterlimit="10" stroke="#333" stroke-width="5"/>
                <path d="M3003.49 1952.22c66 68.19 30.1 196.68-21.65 267.88-73.75 101.45-232.17 158.69-307.94 97.86-79.14-63.53-57.39-247.22 44.75-337.18 76.26-67.16 216.64-99.08 284.84-28.56z" fill="#ffc9a1"/>
                <path d="M2500.32 839c42.32-35.85-124.32-76-146.52-139.49-26.8-76.51 395.59 127.1 331.57 261.08-5 10.51-55.43 94-417.61-23.77C2665.92 1066 2965.92 1340 2964.5 1847.06c-1.09 388.75-348.57 990.75-964.93 996.12-594.62 5.19-966-596.16-964.93-996.12 1.32-488.44 432.22-991 966.09-1028.56 319.41-22.45 464.56 50.1 499.59 20.5z" stroke-linecap="round" stroke-linejoin="round" stroke="#333" stroke-width="5" fill="#656930"/>
                <path d="M1999.57 1320.55c19.15-.16 112.39-116.75 268-116.74 223.53 0 482 324.76 482.28 643.25.16 205.85-111.65 252-111.45 275.69.19 21.13 236.88 22.58 236.88 254.71 0 209.25-420.37 512-840.86 524.16-461.31 13.34-910.31-319.74-910.31-497.74 0-232.44 237-260.58 236.85-281.27s-111.76-76.15-111.93-275.55c-.26-318.49 259.27-643.25 482.47-643.25 172.43-.01 245.34 116.94 268.07 116.74z" fill="#ffcd98" stroke-miterlimit="10" stroke="#333" stroke-width="5"/>
                <path d="M2598.46 2330.77c32.4-4.6 56 22.77 47.08 55.45-11.75 43.09-35 85.68-67.74 125.82q-11.18 13.73-23.87 27c-115.49 121.69-320.37 213.48-554.36 213.08-234 .4-438.88-91.39-554.37-213.08q-12.67-13.29-23.87-27c-32.77-40.14-56-82.73-67.74-125.83-8.9-32.67 14.68-60 47.08-55.44a4258.57 4258.57 0 0 0 1197.79 0z" fill="#3d0c0c"/>
                <path d="M2001 2770.57h-3c-112.73 0-225.78-21.46-327-62.09-95.65-38.4-178.38-92.6-239.24-156.73-8.78-9.21-17.13-18.66-24.79-28.07-34.94-42.79-58.91-87.41-71.24-132.62-6-21.92-1.43-43.51 12.46-59.24 13.5-15.31 33.55-22.34 55-19.29a4240.21 4240.21 0 0 0 596.31 42.15 4238.47 4238.47 0 0 0 596.3-42.15c21.45-3.05 41.49 4 55 19.29 13.88 15.73 18.42 37.32 12.45 59.24-12.32 45.19-36.29 89.82-71.25 132.63-7.71 9.47-16.06 18.92-24.81 28.09-60.83 64.1-143.56 118.3-239.21 156.7-101.11 40.63-214.15 62.09-326.98 62.09zm-1.5-36.85c108.65.21 217.49-20.37 314.78-59.43 90.77-36.45 169-87.6 226.25-147.91 8.11-8.51 15.82-17.24 22.95-26 31.68-38.81 53.29-78.85 64.25-119 2.65-9.73 1-18.9-4.53-25.17-5.23-5.92-13.1-8.47-22.18-7.18a4275.86 4275.86 0 0 1-1203 0c-9.08-1.29-17 1.26-22.18 7.18-5.53 6.27-7.18 15.44-4.53 25.17 11 40.19 32.57 80.24 64.24 119 7.07 8.68 14.78 17.41 22.93 26 57.27 60.34 135.5 111.49 226.27 147.93 96.85 38.89 205.16 59.44 313.29 59.44z" fill="#3d0c0c"/>
                <path d="M2645.54 2386.21c-11.75 43.09-35 85.69-67.74 125.83q-36.18 5-72.45 9.29-6.66.81-13.33 1.58a4258.42 4258.42 0 0 1-968 1.93q-8.94-1-17.87-2.06-42.43-4.94-84.78-10.74c-32.77-40.14-56-82.73-67.74-125.83-8.9-32.67 14.68-60 47.08-55.44q7.83 1.11 15.65 2.19l14.74 2a4258.54 4258.54 0 0 0 1153.33-2.23l10.13-1.41 3.94-.56c32.35-4.59 55.94 22.78 47.04 55.45z" fill="#fff"/>
                <path d="M2553.93 2539.06c-48.1 50.68-111.69 96.17-186.44 132a795 795 0 0 1-90.22 36.51c-84.24 28.31-178.35 44.76-277.7 44.59a874.36 874.36 0 0 1-243.1-33.8 814.34 814.34 0 0 1-94.37-33.52c-88-37.57-162.38-88.32-216.88-145.75q40.58 5.33 81.21 9.87c5.18.57 10.36 1.15 15.55 1.7a4257.87 4257.87 0 0 0 932.16-1.87q5.52-.62 11-1.25 34.43-3.96 68.79-8.48zM1758.29 1403.06c154.89 18 266.48 208.75 250 376.77-16.38 167.34-162.69 342-329.88 323-151.8-17.3-250.26-186.22-253.5-328.16-4.31-190.16 160.84-391.67 333.38-371.61z" fill="#fff"/>
                <ellipse cx="1768.83" cy="1790.92" rx="210.18" ry="180.94" transform="rotate(-79.02 1768.682 1790.902)" fill="#5bc34f" stroke-miterlimit="10" stroke="#333" stroke-width="5"/>
                <ellipse cx="1779.83" cy="1823.1" rx="105.94" ry="118.46"/>
                <ellipse cx="1833.61" cy="1726.3" rx="40.43" ry="42.42" transform="rotate(-70.51 1833.467 1726.281)" fill="#fff" stroke-miterlimit="10" stroke="#333" stroke-width="5"/>
                <path d="M2234 1398.91c-154.54 20.68-262.79 213.36-243.4 381.08 19.3 167 168.63 339.1 335.47 317.13 151.47-19.94 247-190.55 247.73-332.52.98-190.16-167.66-388.73-339.8-365.69z" fill="#fff"/>
                <ellipse cx="2230.21" cy="1786.89" rx="180.94" ry="210.18" transform="rotate(-11.98 2231.097 1787.458)" fill="#5bc34f" stroke-miterlimit="10" stroke="#333" stroke-width="5"/>
                <ellipse cx="2219.77" cy="1819.26" rx="105.94" ry="118.46" transform="rotate(-1 2219.92 1819.125)"/>
                <ellipse cx="2274.24" cy="1726.33" rx="42.42" ry="40.43" transform="rotate(-20.49 2274.731 1726.568)" fill="#fff" stroke-miterlimit="10" stroke="#333" stroke-width="5"/>
                <path d="M1784.05 2081.38c0 75.28 98.57 166.65 215.68 165.63 107.93-.94 213.18-91.24 213.18-165.41 0-59.68-124.17-112.16-213.18-111.39-82.63.72-215.68 40.57-215.68 111.17z" fill="#775a42"/>
            </g>
            <g id="shader-2" data-name="shader">
                <path d="M1134.51 2454.76c-97.43-32.35-195.32-102.51-254.16-191-77.46-116.54-125.85-323-16.55-426.94 45.17-42.94 107.55-59.13 173.62-56-.29 3.54-.55 7.07-.79 10.61-50.59 4.15-97.1 21.38-132.83 55.35-109.3 103.92-60.91 310.4 16.55 426.94 50.31 75.69 129.16 138 211.87 174.64.71 2.12 1.48 4.25 2.29 6.4zM3124.1 2259.28c-60.69 94.85-165.55 169.87-268 201.12.78-1.77 1.53-3.53 2.26-5.3 88.21-36.93 173.43-104 225.78-185.82 75.41-117.87 120.19-325.17 9.09-427.16-35.38-32.48-80.71-48.9-129.86-52.74q-.23-5.24-.5-10.44c64.45-3.41 125.42 11.93 170.36 53.18 111.06 101.99 66.28 309.29-9.13 427.16z" opacity=".08"/>
                <path d="M2212.91 2101.6c0 74.17-105.25 164.47-213.18 165.41-117.11 1-215.68-90.35-215.68-165.63a54.18 54.18 0 0 1 .71-8.78c9 72.83 103.62 155.38 215 154.41 102.38-.89 202.34-82.18 212.35-153.85a43.67 43.67 0 0 1 .8 8.44z" opacity=".1"/>
                <path d="M1510.91 2523.35l-4.79-.56q-42.43-5-84.78-10.75c-32.77-40.14-56-82.73-67.74-125.82-8.9-32.68 14.68-60 47.08-55.45 5.22.74 10.43 1.48 15.65 2.19l2.47.34c19.59 65.9 49.4 130.34 92.11 190.05zM1735.54 2712q-38.07-12-73.46-27.2c-88-37.57-162.38-88.32-216.88-145.75q40.58 5.33 81.21 9.87l2.48.27c52.43 61.81 120.22 117.44 206.65 162.81zM2645.54 2386.22c-11.75 43.08-35 85.68-67.74 125.82q-36.18 5-72.45 9.29-6.66.81-13.33 1.58l-3.14.36c42.55-59.77 72.34-124.18 92-190.06l3.48-.47 10.12-1.41 3.94-.56c32.43-4.6 56.02 22.77 47.12 55.45zM2553.93 2539.06c-48.1 50.68-111.69 96.17-186.44 132a795 795 0 0 1-90.22 36.52q-5.62 1.89-11.32 3.71c85.48-45.39 152.78-100.72 205.06-162.16l3.11-.34 11-1.26q34.45-3.95 68.81-8.47z" opacity=".05"/>
                <g opacity=".1">
                    <path d="M2333.57 957.05l1.81.51q-5.76-1.83-11.62-3.74 4.92 1.59 9.81 3.23z"/>
                    <path d="M2565.16 861.34c-53.4 62.41-211.81-40-531.22-17.54-533.87 37.53-942 531.82-943.3 1020.27-.3 106.94 28.59 233.52 78.72 353.81 58.8-73.84 151.53-99.67 178.59-114.16 7.94 8.57 13 14.51 13 18.89v.36a2 2 0 0 1 0 .26 3.42 3.42 0 0 1-.44 1.09l-.17.28a9 9 0 0 1-1.66 1.78l-.32.26a37.91 37.91 0 0 1-6.52 4l-1.61.79c-3.74 1.83-8.36 3.82-13.67 6l-1.23.51c-5.39 2.24-11.47 4.71-18.08 7.49l-3.09 1.3c-4.16 1.77-8.51 3.65-13 5.67l-3.4 1.54-1.72.79c-1.73.79-3.48 1.61-5.24 2.44-2.35 1.12-4.74 2.27-7.15 3.46l-1.81.9-1.82.91c-1.21.6-2.44 1.23-3.67 1.87q-4.61 2.37-9.3 4.94c-.63.34-1.25.68-1.88 1q-3.77 2.08-7.56 4.31-1.9 1.1-3.81 2.25l-.11.06q-4.71 2.85-9.44 5.89l-1.91 1.24c-1.91 1.26-3.83 2.54-5.74 3.84-.64.43-1.27.87-1.91 1.32q-4.77 3.33-9.51 6.88-3.8 2.87-7.54 5.87-2.8 2.27-5.6 4.62c-.62.51-1.24 1-1.85 1.58l-1.84 1.6q-1.85 1.59-3.66 3.27l-1.82 1.67-1.81 1.69c-1.15 1.08-2.29 2.18-3.42 3.28l-1.95 1.93c-1.19 1.18-2.36 2.37-3.52 3.59l-1.74 1.83q-3.48 3.67-6.85 7.55-1.68 1.93-3.33 3.92l-1.65 2q-1.95 2.37-3.82 4.8-1.74 2.23-3.41 4.53l-.3.39-.54.75-.41.57c-.31.44-.62.89-.94 1.33-.57.8-1.14 1.59-1.7 2.39-.87 1.25-1.73 2.51-2.56 3.79-.13.18-.25.35-.36.53l-.57.85-.32.5-1 1.61-1 1.59c-.35.54-.69 1.09-1 1.64-1 1.69-2.07 3.4-3.08 5.13-.15.25-.29.5-.43.75q-1.49 2.58-2.92 5.22a.2.2 0 0 0 0 .08q-.74 1.35-1.44 2.7c-.46.86-.9 1.73-1.35 2.6l-.08.15c-76.27-147.6-117-302.56-116.59-435.33 1.32-488.45 432.22-991 966.09-1028.57 319.41-22.45 464.56 50.1 499.59 20.46 42.18-35.75-124.46-75.9-146.65-139.39-8.57-24.46 28.82-20.27 81.55 1.13-20-2.88-31 1.83-25.55 15.87 19.38 50.39 194.51 99.08 155.35 144.83z"/>
                </g>
                <path d="M1390.82 2108.61c0 3.67-23.81 15.25-36.41 20.62 4.23-2.41 6.58-4.54 6.58-6.6-.18-20.61-111.76-76.15-111.93-275.54v-.48-6q0-3 .1-5.95c10.27 177.4 141.49 254.34 141.66 273.95z" opacity=".05"/>
                <path d="M1637.84 3250.1a72.31 72.31 0 0 1-62.11 5.5c-21.18-7.88-38.24-24.19-50.7-48.49a150.3 150.3 0 0 1-15.12-48.05 115.4 115.4 0 0 1 2.11-43.78 98.25 98.25 0 0 1 5.88-16.76 63 63 0 0 1-.34-6.33c-.33-90.45 30.55-183 89.47-268.77l.85.32q15.11 5.84 30.49 11.32c-49.47 78.73-85.32 140.89-85 223.4-17 21.83-12.63 82.94.49 114.5 27.14 65.18 76.61 76.82 83.98 77.14z" opacity=".08"/>
                <path d="M2644.33 2128.38c-12.95-5.65-34.48-16.28-34.45-19.77.16-18.89 121.63-90.8 139.95-254.23-2.45 199.63-111.6 244.95-111.4 268.37.02 1.98 2.12 3.79 5.9 5.63z" opacity=".05"/>
                <path d="M1974.07 3510.34a67.43 67.43 0 0 1-85.32 42.82c-27.72-9.2-93.83-15.48-147.71.23a67.52 67.52 0 0 1-85.66-74.81 69.07 69.07 0 0 0 2 8.89 67.52 67.52 0 0 0 83.7 45.92c53.88-15.71 120-9.43 147.71-.23a67.51 67.51 0 0 0 88-54.08 67.09 67.09 0 0 1-2.72 31.26zM2342.66 3507.47a67.45 67.45 0 0 1-83.7 45.92c-53.88-15.71-120-9.43-147.71-.23a67.51 67.51 0 0 1-88-74.08 67.45 67.45 0 0 0 88 54.08c27.72-9.2 93.83-15.48 147.71.23a67.45 67.45 0 0 0 83.7-45.92 69.07 69.07 0 0 0 2-8.89 67 67 0 0 1-2 28.89z" opacity=".1"/>
                <path d="M2487.37 3157.2c-4.06 35.05-23.3 81.66-64.13 97.67A72.32 72.32 0 0 1 2362 3251c10.47-1.34 56.85-14.72 82.77-77 13.12-31.56 17.35-93 .34-114.84.29-78.53-32-149-77.79-223.56q14.76-5.32 29.3-11c57.7 86.8 84.94 177.3 76.9 256.66-.19 1.87-.47 3.7-.81 5.51a96.49 96.49 0 0 1 11.77 26.77 115.44 115.44 0 0 1 2.89 43.66z" opacity=".08"/>
                <g opacity=".08">
                    <path d="M1959.44 3433.13c0 .63 0 1.27-.08 1.9q-.15 3.73-.58 7.39a67.23 67.23 0 0 0-27.53-17.4c-28.62-9.49-66-15.2-105.2-16.06a459.31 459.31 0 0 0-55.71 2.13c.2-3.39.43-6.74.68-10.07a462.82 462.82 0 0 1 55-2.06c39.22.86 76.58 6.57 105.2 16.06a67.16 67.16 0 0 1 28.22 18.11zM2229.17 3411a462.3 462.3 0 0 0-55.17-2c-39.22.86-76.58 6.57-105.2 16.06a67.16 67.16 0 0 0-27.8 17.69c-.15-1.39-.26-2.79-.34-4.2-.1-1.71-.2-3.4-.32-5.09a67.14 67.14 0 0 1 28.46-18.4c28.62-9.49 66-15.2 105.2-16.06a462.57 462.57 0 0 1 54.36 2l.81 10z"/>
                </g>
                <g opacity=".08">
                    <path d="M1783.72 3308.76c48.55 44.14 110.63 75 179.06 82.49q-.87 7.27-1.54 14.83c-69-7.92-131.44-39.58-180-84.59q1.2-6.49 2.48-12.73zM2216.32 3319.91c-47.76 44.29-109.47 75.84-178.59 85.21q-.87-7.51-1.91-14.74c68.6-8.88 130-39.6 177.8-83q1.38 6.18 2.7 12.53z"/>
                </g>
                <path d="M2317.59 3086.38c0 153.62-140.68 305.09-320 306.63-175.53 1.51-319-153-319-306.63 0-10 .24-20.06.79-30.27 11.56 146.84 150.22 288.35 318.23 286.9 172.85-1.48 309.81-142.31 319.43-290.07.4 11.41.55 22.49.55 33.44z" opacity=".1"/>
                <path d="M2175.41 3147c-59.91 74.88-132.36 85.57-175.41 85.57-47.55 0-118.32-8.27-177.41-81.89-27.71-34.52-37-79.73-35.13-134.17 1.64 43 12 79.3 35.13 108.17 59.09 73.62 129.86 81.89 177.41 81.89 43 0 115.5-10.69 175.41-85.57 25.37-31.72 36.2-71.88 37.82-118.83 1.77 58.18-7.88 107.37-37.82 144.83z" opacity=".08"/>
                <path d="M2396.63 2824.52c-35 13.72-71 26-107.74 36.45q-8.25 2.36-16.56 4.59c-77.34 20.83-157.6 33.74-237.88 36.06-102.94 3-205.27-11.3-302.13-37.25q-6.52-1.76-13-3.57c-38.43-10.76-76-23.34-112.26-37.39q-10.86 15.81-20.44 31.9a1242.57 1242.57 0 0 0 121.21 42.21l1.17-1.73c-.18.64-.36 1.28-.53 1.92 103.84 30.14 214.56 47.13 326 43.91 88.47-2.56 176.94-18 261.49-42.69l1.36-.4a1195 1195 0 0 0 119.15-42q-9.23-16.05-19.84-32.01z" opacity=".1"/>
                <g opacity=".2">
                    <path d="M2352.6 3244.86c-21.27 18.38-65.08 13.14-91.57 9.31q5.26-7.34 10.07-14.94 5.79 1.14 11.24 1.94c26.64 3.89 46.4 1.46 58.83-7.25a71.17 71.17 0 0 0 11.43 10.94zM2711.22 3080.89a48.07 48.07 0 0 0 6.4-2.83 51.65 51.65 0 0 1-21.4 14.83c-37.83 13.59-81.06-22.69-81.49-23.06a25 25 0 0 0-23.13-5 24.27 24.27 0 0 1 2.89-4.19 25 25 0 0 1 35.24-2.82c.43.38 43.66 36.66 81.49 23.07z"/>
                    <path d="M2796.94 3050.12c-9.47 29.84-26.19 53.12-48.11 67.49 14.6-14.05 25.94-32.88 33.11-55.49 9.54-30.08 11.3-66.18 4.71-96.59-8.05-37.13-29.53-70.63-62.13-96.87-28.39-22.85-63.05-38.38-97.6-43.73-28-4.32-56.93-2-86.08 6.92-26.21 8-52 21.19-76.69 39.12-1.26.92-2.52 1.84-3.77 2.78q9.16-7.78 18.77-14.78c24.68-17.93 50.48-31.09 76.69-39.12 29.15-8.92 58.11-11.24 86.08-6.92 34.55 5.35 69.21 20.88 97.6 43.73 32.6 26.24 54.08 59.74 62.13 96.87 6.59 30.41 4.83 66.47-4.71 96.59z"/>
                </g>
                <path d="M2212.91 2081.6c0 74.17-105.25 164.47-213.18 165.41-117.11 1-215.68-90.35-215.68-165.63a55.09 55.09 0 0 1 .79-9.31c42.18 52.17 123.35 95.66 214.39 94.95 85.09-.67 168.69-45.29 211.9-97.87a45.3 45.3 0 0 1 1.78 12.45z" opacity=".2"/>
                <path d="M1834.52 1427a214.27 214.27 0 0 0-31.9-6.17c-175.15-20.17-342.8 182.73-338.41 374.18 2.47 107.25 59.36 229.79 152.7 291.65-116.4-48.78-189.2-190.33-192-312-4.33-190.11 160.82-391.59 333.36-371.55a217.6 217.6 0 0 1 76.25 23.89zM2573.77 1764.6c-.66 123.27-72.75 268.13-190.88 317.21 95.29-61.62 152.08-188.08 152.66-297.55 1-190.6-168-389.61-340.57-366.52a211.81 211.81 0 0 0-45.38 11.34c26-15.6 54.29-26.14 84.37-30.17 172.17-23.04 340.81 175.53 339.8 365.69z" opacity=".05"/>
                <path d="M1862.25 1605.54q-6.51-1.85-13.25-3.16c-99.1-19.24-197.56 58.49-219.9 173.6-16.75 86.35 14.07 169.22 72.35 213.35-81.88-32-130.23-129.93-110.25-232.89 22.12-114 119.58-190.89 217.68-171.85a158.12 158.12 0 0 1 53.37 20.95zM2295.09 1986.4c60.86-43.65 92.6-129.07 73.87-217.3-24.16-113.85-123.21-189.28-221.22-168.48a157.39 157.39 0 0 0-17.52 4.78 158.17 158.17 0 0 1 56.34-24.11c97.76-20.75 196.54 54.48 220.65 168 22.3 105.1-27.16 206.17-112.12 237.11z" opacity=".1"/>
                <path d="M2749.41 1798.06q0 9.7-.31 18.94c-15.7-308.54-265-613.19-481.5-613.19-155.64 0-248.88 116.58-268 116.74-22.73.2-95.64-116.74-268-116.74-215.85 0-465.69 303.73-481.65 611.81l-.18 3.62c0 1.22-.11 2.43-.16 3.65s-.1 2.42-.14 3.63q-.78-13.71-.81-28.46c-.26-318.49 259.27-643.25 482.47-643.26 172.41 0 245.31 117 268 116.75 19.15-.17 112.39-116.75 268-116.75 223.53.01 482.04 324.77 482.28 643.26z" opacity=".1"/>
                <path d="M2875.31 2377.46c0 209.26-420.37 512-840.86 524.16-461.31 13.34-910.31-319.74-910.31-497.74q0-7.14.3-14c38.59 182.8 468.4 486 909.44 473.26 406.19-11.75 812.27-294.09 841-502.25q.43 8.11.43 16.57z" opacity=".08"/>
                <path d="M2964.5 1847.07c-.36 127.74-38.12 278.51-110.54 423.57-58.2-126.52-215.38-130.67-215.53-147.89 0-3.44 2.3-7.34 6.3-12.14 29.88 12.38 135.89 21.8 193.55 102.09 59.3-132.15 86.52-259.16 86.84-374.86 1.43-510.11-312.88-784.54-713.42-914.5 35.09 11.39 34.68 6.38 56.06 13.48C2665.92 1066 2965.92 1340 2964.5 1847.07z" opacity=".1"/>
            </g>
        </g>
    </g>
    <svg viewBox="0 0 4000 4000">
        <defs/>
        <path d="M2638.4 2122.8c-.2-23.7 111.61-69.84 111.45-275.69-.25-318.49-258.75-643.25-482.28-643.25-155.64 0-248.88 116.58-268 116.74-22.73.2-95.64-116.75-268-116.74-223.2 0-482.73 324.76-482.47 643.25.17 199.4 111.75 254.94 111.93 275.55s-236.85 48.83-236.85 281.27c0 178 449 511.08 910.31 497.74 420.49-12.16 840.86-314.91 840.86-524.16-.07-232.13-236.76-233.58-236.95-254.71zm-689.76-296.93c-10.8 55.65-39.63 104.35-81.16 137.14-32.82 25.91-70.48 39.45-108.51 39.45a161.3 161.3 0 0 1-30.65-3c-99.16-19.2-161.67-128.41-139.35-243.41s121.16-192.88 220.32-173.63c48.1 9.34 89.08 39.84 115.39 85.9s34.76 101.91 23.96 157.55zm439.53 81c-25.51 46.51-65.95 77.73-113.88 87.9a160.79 160.79 0 0 1-33.39 3.52c-37.09 0-73.93-12.87-106.38-37.58-42.11-32.06-71.77-80.25-83.54-135.7s-4.24-111.53 21.21-157.93 66-77.73 113.88-87.91c98.8-21 199 55.18 223.31 169.76 11.77 55.42 4.23 111.51-21.21 157.91z" fill="#ffcd98" stroke="#333" stroke-miterlimit="10" stroke-width="5"/>
        <path d="M2875.3 2377.5c0 209.26-420.37 512-840.86 524.16-461.31 13.34-910.31-319.74-910.31-497.74q0-7.14.3-14c38.59 182.8 468.4 486 909.44 473.26 406.19-11.75 812.27-294.09 841-502.25q.43 8.11.43 16.57z" opacity=".08"/>
        <path d="M1758.3 1403.1c-172.54-20-337.69 181.45-333.36 371.56 3.24 141.94 101.7 310.86 253.5 328.16 167.19 19 313.5-155.61 329.88-323 16.46-167.97-95.13-358.73-250.02-376.72zm190.38 422.76c-10.8 55.65-39.63 104.35-81.16 137.14-32.82 25.91-70.48 39.45-108.51 39.45a161.3 161.3 0 0 1-30.65-3c-99.16-19.2-161.67-128.41-139.35-243.41s121.16-192.88 220.32-173.63c48.1 9.34 89.08 39.84 115.39 85.9s34.76 101.91 23.96 157.55z" fill="#fff"/>
        <path d="M1834.5 1427a214.27 214.27 0 0 0-31.9-6.17c-175.15-20.17-342.8 182.73-338.41 374.18 2.47 107.25 59.36 229.79 152.7 291.65-116.4-48.78-189.2-190.33-192-312-4.33-190.11 160.82-391.59 333.36-371.55a217.6 217.6 0 0 1 76.25 23.89z" opacity=".05"/>
        <path d="M2234 1398.9c-154.54 20.68-262.79 213.36-243.4 381.08 19.3 167 168.63 339.1 335.47 317.13 151.47-19.94 247-190.55 247.73-332.52.98-190.16-167.66-388.73-339.8-365.69zm154.23 507.88c-25.51 46.51-65.95 77.73-113.88 87.9a160.79 160.79 0 0 1-33.39 3.52c-37.09 0-73.93-12.87-106.38-37.58-42.11-32.06-71.77-80.25-83.54-135.7s-4.24-111.53 21.21-157.93 66-77.73 113.88-87.91c98.8-21 199 55.18 223.31 169.76 11.74 55.45 4.2 111.54-21.24 157.94z" fill="#fff"/>
        <path d="M2573.8 1764.6c-.66 123.27-72.75 268.13-190.88 317.21 95.29-61.62 152.08-188.08 152.66-297.55 1-190.6-168-389.61-340.57-366.52a211.81 211.81 0 0 0-45.38 11.34c26-15.6 54.29-26.14 84.37-30.17 172.17-23.04 340.81 175.53 339.8 365.69z" opacity=".05"/>
        <path d="M1784 2081.4c0 75.28 98.57 166.65 215.68 165.63 107.93-.94 213.18-91.24 213.18-165.41 0-59.68-124.17-112.16-213.18-111.39-82.63.72-215.68 40.57-215.68 111.17z" fill="#7f6145"/>
        <path d="M2212.9 2101.6c0 74.17-105.25 164.47-213.18 165.41-117.11 1-215.68-90.35-215.68-165.63a54.18 54.18 0 0 1 .71-8.78c9 72.83 103.62 155.38 215 154.41 102.38-.89 202.34-82.18 212.35-153.85a43.67 43.67 0 0 1 .8 8.44z" opacity=".1"/>
        <path d="M2212.9 2081.6c0 74.17-105.25 164.47-213.18 165.41-117.11 1-215.68-90.35-215.68-165.63a55.09 55.09 0 0 1 .79-9.31c42.18 52.17 123.35 95.66 214.39 94.95 85.09-.67 168.69-45.29 211.9-97.87a45.3 45.3 0 0 1 1.78 12.45z" opacity=".2"/>
        <path d="M1471.5 2478.2c22-4 44-7.5 66-11 5.51-.89 11-1.73 16.53-2.56s11-1.68 16.55-2.4l33.13-4.49c44.21-5.77 88.42-11.6 132.68-16.95l66.39-8.06 66.42-7.67 66.44-7.54 66.44-7.24 66.44-7.23 66.43-7.11 132.85-14.27c22.14-2.36 44.3-4.65 66.42-7.18l66.41-7.36 132.84-14.72a9.54 9.54 0 0 1 2.52 18.91c-88.14 13.56-176.49 25.67-264.88 37.55-11 1.54-22.11 2.9-33.16 4.36l-33.17 4.28-33.17 4.24-33.2 4.05-66.4 8c-22.13 2.64-44.28 5.09-66.42 7.62l-66.42 7.53-66.43 7.28-66.41 7.35-66.43 7.19-33.21 3.65-33.21 3.57-66.43 7.19q-66.42 7.34-133.18 11.94a9.55 9.55 0 0 1-2.4-18.92z" fill="#634b37"/>
        <path d="M2538.22 2317.78a65.37 65.37 0 0 1 13.18 20.46 76 76 0 0 1 5.66 24 78 78 0 0 1-2.08 24.57 67.49 67.49 0 0 1-9.9 22.21 9 9 0 0 1-16.26-7.06l.09-.4a165.1 165.1 0 0 0 3.07-18.93 105.07 105.07 0 0 0 .16-18.51c-.21-3.07-.62-6.11-1.12-9.15s-1.15-6.07-1.89-9.1a185 185 0 0 0-5.78-18.29l-.14-.39a9.06 9.06 0 0 1 15-9.41zM1474.3 2454.24a184.53 184.53 0 0 0-2.75 19c-.24 3.11-.43 6.2-.39 9.28s.08 6.15.36 9.21a105 105 0 0 0 3.15 18.24 163.87 163.87 0 0 0 6.09 18.19l.15.37a9.05 9.05 0 0 1-14.9 9.61 67.11 67.11 0 0 1-13.36-20.33 77.93 77.93 0 0 1-6-23.9 75.81 75.81 0 0 1 1.72-24.6A65.21 65.21 0 0 1 1458 2447a9.06 9.06 0 0 1 16.34 6.86z" fill="#634b37"/>
        <path d="M1417 2472.34c-.21 5.19-.6 9.85-.64 14.4a104.78 104.78 0 0 0 .48 13.12 109.72 109.72 0 0 0 2.09 12.76c.95 4.33 2.26 8.66 3.6 13.6l.17.63a6.85 6.85 0 0 1-10.23 7.6 37.38 37.38 0 0 1-12.74-14 47.61 47.61 0 0 1-5.52-18.42 49.68 49.68 0 0 1 1.91-19 40.72 40.72 0 0 1 9.1-16.22 6.85 6.85 0 0 1 11.8 5zM2587.29 2324.51a40.68 40.68 0 0 1 12.38 13.87 50 50 0 0 1 5.94 18.1 47.58 47.58 0 0 1-1.42 19.18 37.33 37.33 0 0 1-9.42 16.43 6.85 6.85 0 0 1-11.63-5.2v-.67c.25-5.11.6-9.62.59-14a104.33 104.33 0 0 0-3.06-25.84c-1-4.42-2.41-8.89-3.73-13.91l-.13-.49a6.85 6.85 0 0 1 10.45-7.42z" fill="#333" opacity=".1"/>
        <path d="M1390.8 2108.6c0 3.67-23.81 15.25-36.41 20.62 4.23-2.41 6.58-4.54 6.58-6.6-.18-20.61-111.76-76.15-111.93-275.54v-6.48q0-3 .1-5.95c10.27 177.4 141.49 254.34 141.66 273.95zM2644.3 2128.4c-12.95-5.65-34.48-16.28-34.45-19.77.16-18.89 121.63-90.8 139.95-254.23-2.45 199.63-111.6 244.95-111.4 268.37.02 1.98 2.12 3.79 5.9 5.63z" opacity=".05"/>
    </svg>
    <svg viewBox="0 0 4000 4000">
        <defs/>
        <path d="M2091.3 1984.49c-30.62-9.25-62.92-14.52-91.57-14.27-24.08.21-52.43 3.74-80.53 10.39.4-.52.78-1 1.17-1.58 49-67 78.44-153 78.44-246.71 0-9.7-.33-19.25-1-28.72h12q-1 14.25-1 28.83c0 94.43 29.86 180.93 79.49 248.1z" fill="#ffcd98"/>
        <path d="M2705.8 1612.1c-25.77 30.7-61.74 1.58-94.1 1.64l-1224.7-3.56c-31.38.06-66.2 3.24-96.39 11.16-.63.16 2.14-6.95 1.51-6.78 82.9-226.79 271.46-410.75 439.45-410.75 172.41 0 245.31 116.94 268 116.74 19.15-.16 112.39-116.74 268-116.74 167.66 0 354.95 182.63 438.24 408.29z" stroke="#333" stroke-miterlimit="10" stroke-width="5" fill="#ffcd98"/>
        <path d="M1998.8 1732.3c0 93.76-29.49 179.72-78.44 246.71q-10.29 14.12-21.72 27.06c-32.22 36.38-70.24 69.74-113.14 89.37-39.57 18.12-83.36 23.94-128.71 23.94h-.14c-188.87 0-342-173.25-342-387.08q0-12 .67-23.73.79-14.16 2.51-28.09h677.81q1.41 11.49 2.19 23.1c.64 9.47.97 19.02.97 28.72z"/>
        <path d="M1865.5 1974.6c-50.06 40.69-111.56 64.6-178 64.6-158.48 0-288.78-136.17-304.38-310.77 56.35 99.32 159.11 183.7 287.65 224.11 66.94 21.06 133.35 27.75 194.73 22.06z" fill="#fff"/>
        <path d="M2693 1732.4c0 106.91-38.36 203.68-100.16 273.76-61.95 69.92-147.35 113.31-241.85 113.31h-.14c-46.76 0-97-8.38-137.55-27.6-51-24.13-90.06-64.08-125-111.37-49.63-67.17-79.49-153.67-79.49-248.1q0-14.6 1-28.83.8-11.57 2.19-23h677.81q1.21 10 2 20.16c.77 10.44 1.19 20.97 1.19 31.67z"/>
        <path d="M2559.7 1974.7c-50.06 40.7-111.57 64.6-178 64.6-158.47 0-288.78-136.17-304.38-310.77 56.35 99.32 159.11 183.7 287.66 224.12 66.93 21.06 133.34 27.74 194.72 22.05z" fill="#fff"/>
        <path d="M2982 1743l-1.62 24.62a17.62 17.62 0 0 1-16 17.58 17.42 17.42 0 0 1-6.83-.82l-218.51-69.06-44.15-13.95a19.29 19.29 0 0 0-5.68-.86l-679.45 3h-12l-649.95 2.87a268.36 268.36 0 0 0-78.3 12l-4 1.24-223.23 69.17a16.65 16.65 0 0 1-4.53.8 17.63 17.63 0 0 1-18.07-17.55l-1.76-24.61a16.68 16.68 0 0 1 0-1.87 17.78 17.78 0 0 1 13.31-16.18 18.1 18.1 0 0 0 2.77-1l200.69-92.56a368.91 368.91 0 0 1 153.67-33.82l1223.53-2.35a368.66 368.66 0 0 1 153.34 33.08l200.65 91.27a17.42 17.42 0 0 0 2.77 1 17.78 17.78 0 0 1 13.4 16.1 14.75 14.75 0 0 1-.05 1.9z"/>
        <path d="M1781 2081c0 76.35 100 169 218.77 168 109.48-.95 216.23-92.55 216.23-167.78 0-60.53-125.95-113.77-216.23-113-83.83.78-218.77 41.16-218.77 112.78z" fill="#7f6145"/>
        <path d="M2216 2081.21c0 75.23-106.76 166.83-216.23 167.78C1881 2250 1781 2157.35 1781 2081a55.51 55.51 0 0 1 .8-9.44c42.79 52.91 125.12 97 217.46 96.3 86.31-.67 171.11-45.93 214.93-99.27a45.85 45.85 0 0 1 1.81 12.62z" opacity=".2"/>
    </svg>
    <svg viewBox="0 0 4000 4000">
        <defs/>
        <g data-name="hat10(colorable)">
            <path d="M2962.6 1775a10.06 10.06 0 0 1-8.5-6.2c-218.06-510-974.77-575.76-1453.2-507.32-131 18.73-241.06 47.53-313.56 80a10.69 10.69 0 0 1-3.15.87 1151.5 1151.5 0 0 1 172.15-218.75c379.48-68.1 1044.5-117.29 1486.3 234.62 68.11 115.01 110.72 252.78 119.96 416.78z" opacity=".1"/>
            <path d="M2613.8 241a143.72 143.72 0 0 1-47.51 108.2c-38.34-37-76.5-59.62-113.09-63.76-25.82-2.92-64.66 4.21-113 20.08A144.09 144.09 0 1 1 2613.8 241z" stroke="#333" stroke-miterlimit="10" stroke-width="5" fill="#f2f2f2"/>
            <path d="M1209.2 1310.5a10.19 10.19 0 0 1-13.75-12.88c200.66-526.53 1070.7-1033.3 1257.8-1012.2 264.15 29.9 609.58 1021.7 520.72 1450.4-2 9.81-15.48 11.12-19.38 1.89-274.4-649.59-1412.1-578.49-1745.4-427.31z" fill="#d8bfd8" stroke="#333" stroke-miterlimit="10" stroke-width="5"/>
            <path d="M2954.6 1737.8c-274.39-649.59-1412.1-578.46-1745.4-427.27a10.19 10.19 0 0 1-13.75-12.9c43.69-114.64 119.12-228.34 212.32-335.87 405.68-96.39 1255.3-54.34 1565.3 426 24.52 159.35 23 241.26.84 348.22-2.03 9.75-15.48 11.07-19.37 1.82zM2864.1 914c-298.36-227.2-767.38-287.91-1118.3-265.83 145.74-112.17 296.37-205.62 423.57-269.63 170.81 16.59 352 53.83 509.71 118.4C2745.88 609.16 2811.37 756 2864.13 914z" stroke="#333" stroke-miterlimit="10" stroke-width="5" fill="#f2f2f2"/>
            <path d="M2954.6 1737.8c-274.39-649.59-1412.1-578.46-1745.4-427.27a10.19 10.19 0 0 1-13.75-12.9c43.69-114.64 119.12-228.34 212.32-335.87 405.68-96.39 1255.3-54.34 1565.3 426 24.52 159.35 23 241.26.84 348.22-2.03 9.75-15.48 11.07-19.37 1.82zM2864.1 914c-298.36-227.2-767.38-287.91-1118.3-265.83 145.74-112.17 296.37-205.62 423.57-269.63 170.81 16.59 352 53.83 509.71 118.4C2745.88 609.16 2811.37 756 2864.13 914z" stroke="#333" stroke-miterlimit="10" stroke-width="5" fill="#f2f2f2"/>
            <path d="M2613.81 241a143.72 143.72 0 0 1-47.51 108.2c-22-21.23-43.93-37.73-65.55-48.71A144.15 144.15 0 0 0 2454.37 99q7-.75 14.11-.81A144.08 144.08 0 0 1 2613.81 241z" fill="#333" stroke="#333" stroke-miterlimit="10" stroke-width="5" opacity=".1"/>
        </g>
        <path d="M2330.6 1213.48h-1.82c-4.58-.09-9-.57-13.76-1.09l-1-.11h-.18c-3-.79-6.12-1.44-9.37-2.13-3.66-.77-7.44-1.56-11.17-2.58a164.58 164.58 0 0 1-31.84-11.81 137.3 137.3 0 0 1-54-48.52 170.75 170.75 0 0 1-18.67-38.78 31.83 31.83 0 0 1-1.89-11.41 11.83 11.83 0 0 1 6.89-10.86c3.86-1.87 8-2.16 11.52-2.21h.69a74.69 74.69 0 0 1 10.68.84 67.34 67.34 0 0 1 11.72 3c10.93 3.59 20.4 9.4 31.25 17l6.25 4.36c8.5 5.89 17.28 12 25.41 18.78a164 164 0 0 1 13 12.14 13.83 13.83 0 0 0 8.62 4.54 12 12 0 0 0 1.48.08 17.3 17.3 0 0 0 5.09-.83 158.15 158.15 0 0 0 24.31-10.24c14.19-7.16 27-16.87 39-29.68a56.54 56.54 0 0 1 39.66-18.33c1.32-.06 2.61-.09 3.85-.09a54.33 54.33 0 0 1 17 2.47c6.58 2.14 10.34 6.62 10.87 13a21.23 21.23 0 0 1-1.15 8 156.6 156.6 0 0 1-11.38 28 154.24 154.24 0 0 1-51.24 56.84c-12 8-23.67 13.42-35.81 16.56a95.9 95.9 0 0 1-24.01 3.06z" fill="#fbdd11"/>
        <path d="M2206 1086.42a74.14 74.14 0 0 1 10.32.82 66.49 66.49 0 0 1 11.29 2.94c11.22 3.69 21 10 30.59 16.69 10.65 7.47 21.5 14.65 31.49 23a157.49 157.49 0 0 1 12.83 11.94 16.35 16.35 0 0 0 10.14 5.3 15.29 15.29 0 0 0 1.78.1 19.89 19.89 0 0 0 5.81-.94 158.94 158.94 0 0 0 24.71-10.4 143 143 0 0 0 39.7-30.19 54.08 54.08 0 0 1 38-17.55c1.24-.06 2.49-.09 3.74-.09a51.76 51.76 0 0 1 16.2 2.35c5.61 1.82 8.71 5.41 9.16 10.77a18.94 18.94 0 0 1-1 7 154.09 154.09 0 0 1-11.2 27.57 150.93 150.93 0 0 1-50.42 55.93 114.49 114.49 0 0 1-35 16.22 93.05 93.05 0 0 1-23.41 3h-1.77c-4.74-.09-9.45-.63-14.39-1.16-6.65-1.73-13.66-2.83-20.51-4.7a164.41 164.41 0 0 1-31.37-11.63 134.37 134.37 0 0 1-53-47.64 167.66 167.66 0 0 1-18.4-38.22 29.83 29.83 0 0 1-1.76-10.53c.14-4 1.85-6.95 5.48-8.7 3.31-1.6 6.86-1.91 10.47-2h.66m0-5h-.73a29.12 29.12 0 0 0-12.57 2.46c-5.22 2.52-8.09 7-8.31 13a34.41 34.41 0 0 0 2 12.29 173.63 173.63 0 0 0 18.94 39.35 139.91 139.91 0 0 0 55 49.39 167.31 167.31 0 0 0 32.32 12c3.79 1 7.61 1.83 11.3 2.61 3.23.68 6.28 1.32 9.27 2.1l.35.09h.36l.86.09c4.78.52 9.29 1 14 1.1h1.87a98.61 98.61 0 0 0 24.66-3.2c12.41-3.21 24.37-8.74 36.57-16.9a156.67 156.67 0 0 0 52.06-57.76 160.5 160.5 0 0 0 11.57-28.46 23.4 23.4 0 0 0 1.24-8.9c-.61-7.31-5.08-12.67-12.59-15.12a56.78 56.78 0 0 0-17.75-2.59c-1.28 0-2.62 0-4 .1a58.9 58.9 0 0 0-41.36 19.11c-11.86 12.59-24.39 22.13-38.31 29.16a156.16 156.16 0 0 1-23.93 10.08 14.62 14.62 0 0 1-4.34.72 12 12 0 0 1-1.21-.06 11.49 11.49 0 0 1-7.1-3.79 163.67 163.67 0 0 0-13.41-12.17c-8.21-6.86-17-13-25.58-18.91l-6.25-4.35c-11-7.75-20.68-13.66-31.9-17.35a71.14 71.14 0 0 0-12.15-3.14 76.71 76.71 0 0 0-11-.87z" fill="#333"/>
        <path d="M2331.73 1126.41c-8.34 0-16.61-1.63-23.71-3.16-5.79-1.25-10.71-4.12-15.18-7-12.07-7.89-27.86-18.42-42.9-29.94-5.16-4-10-8.39-14.58-12.69l-2.13-2c-2.16-2-4.19-3.91-6.74-4.89a12 12 0 0 0-4.36-.79 18.59 18.59 0 0 0-4.78.7c-6.79 1.78-13.28 4.88-19 7.62a146 146 0 0 0-26.9 16.07 162.77 162.77 0 0 0-18.15 16.62c-10.21 10.65-22.59 16.7-36.81 18-1.91.17-3.83.26-5.73.26a62.31 62.31 0 0 1-17.39-2.48c-7.07-2-11.46-8-10.9-14.86v-.1l.94-5.75v-.1a106.6 106.6 0 0 1 6-17.3 160 160 0 0 1 44-57.73 130.2 130.2 0 0 1 42.83-24.18 100.88 100.88 0 0 1 29.88-5.15h1.2c9.19 0 18 1.6 26.33 3.23a156.18 156.18 0 0 1 16.2 4.16c14.35 4.47 26.51 10 37.19 16.86 13 8.4 23.45 17.57 31.88 28a168.1 168.1 0 0 1 23 37.55 120.39 120.39 0 0 1 6.87 18.83 27.76 27.76 0 0 1 .82 8.66 10.76 10.76 0 0 1-6.3 9.6c-3.71 1.76-7.63 1.93-11 2z" fill="#fbdd11"/>
        <path d="M2207.29 1000c8.74 0 17.31 1.5 25.86 3.18a153.31 153.31 0 0 1 15.94 4.1 147.64 147.64 0 0 1 36.57 16.57c11.8 7.61 22.45 16.53 31.29 27.51a165 165 0 0 1 22.65 37 117.78 117.78 0 0 1 6.72 18.43 25.3 25.3 0 0 1 .76 7.89 8.3 8.3 0 0 1-4.88 7.5c-3.17 1.5-6.55 1.69-10 1.72h-.49c-7.87 0-15.55-1.46-23.19-3.1-5.27-1.14-9.88-3.78-14.34-6.69-14.55-9.5-28.94-19.25-42.75-29.82-5.6-4.29-10.71-9.13-15.88-13.92-2.49-2.3-4.91-4.73-8.19-6a14.62 14.62 0 0 0-5.26-1 21.25 21.25 0 0 0-5.42.78c-6.81 1.79-13.13 4.76-19.45 7.78a150.5 150.5 0 0 0-27.35 16.35 167.25 167.25 0 0 0-18.42 16.87c-9.64 10-21.31 16-35.23 17.22-1.85.17-3.68.25-5.51.25a59.64 59.64 0 0 1-16.69-2.38c-6-1.74-9.57-6.63-9.11-12.26l.9-5.54a102.51 102.51 0 0 1 5.87-16.88 156.67 156.67 0 0 1 43.27-56.84 127 127 0 0 1 42-23.72 97.92 97.92 0 0 1 29.14-5h1.15m0-5h-1.22a103.86 103.86 0 0 0-30.63 5.27 132.85 132.85 0 0 0-43.65 24.64 162.4 162.4 0 0 0-44.64 58.63 108.33 108.33 0 0 0-6.14 17.7l-.06.21v.21l-.44 2.69-.47 2.86v.4c-.65 8 4.46 15.07 12.7 17.46a65 65 0 0 0 18.09 2.58c2 0 4-.09 6-.27 14.83-1.34 27.75-7.65 38.39-18.74a158.83 158.83 0 0 1 17.82-16.34 143.62 143.62 0 0 1 26.45-15.8c5.62-2.69 12-5.73 18.56-7.46a16.45 16.45 0 0 1 4.15-.61 9.54 9.54 0 0 1 3.47.63c2.09.8 3.86 2.46 5.92 4.38l.66.61 1.47 1.37c4.68 4.34 9.52 8.82 14.77 12.85 15.1 11.56 30.94 22.13 43 30 4.67 3 9.84 6 16 7.38 7.22 1.56 15.65 3.22 24.25 3.22h.53c3.65 0 7.9-.23 12.07-2.2a13.32 13.32 0 0 0 7.73-11.7 30.35 30.35 0 0 0-.9-9.44 122.64 122.64 0 0 0-7-19.21 170.85 170.85 0 0 0-23.32-38.11c-8.6-10.69-19.23-20-32.48-28.58-10.86-7-23.23-12.61-37.79-17.15a159.52 159.52 0 0 0-16.47-4.23c-8.4-1.65-17.39-3.27-26.82-3.27z" fill="#333"/>
    </svg>
    <svg viewBox="0 0 4000 4000">
        <defs/>
        <path d="M2472.8 3082.9c9.21-3 14.84-7.11 15.26-12 1.07-12.66-32.6-25.84-75.21-29.43s-78 3.77-79.07 16.43c-.42 5 4.65 10.14 13.56 14.7a75.55 75.55 0 0 0-2.68 3.63 74 74 0 0 0-8.73 67.29 74.09 74.09 0 0 0 86.54 113.19c41.91-16.43 61.67-64.38 65.85-100.46 3.23-27.93-2.37-53.24-15.52-73.35z" fill="#fff" stroke="#333" stroke-miterlimit="10" stroke-width="5"/>
        <path d="M2488.4 3156.2c-4.19 36.07-24 84-65.86 100.47a73.94 73.94 0 0 1-65.52-5.67h.75a73.94 73.94 0 0 0 27-5.13c41.91-16.43 61.67-64.4 65.86-100.47 3.22-27.89-2.34-53.24-15.53-73.3 9.21-3 14.85-7.12 15.26-12 .45-5.49-5.61-11.07-16.1-15.94 32 5.48 54.77 16.28 53.9 26.74-.41 4.93-6.05 9.05-15.26 12.05 13.12 20.05 18.72 45.36 15.5 73.25z" fill="#333" opacity=".2"/>
        <path d="M1669.5 3215.72A73.77 73.77 0 0 1 1639 3252l-1 .63-.12.07c-1.33.78-2.7 1.52-4.08 2.21-.9.44-1.8.88-2.71 1.29q-1 .43-1.92.84l-1.41.57c-.78.31-1.57.61-2.36.89l-1.19.41-1.28.42q-1 .33-2.07.63l-1.49.41c-.82.22-1.63.42-2.46.6s-1.65.36-2.48.52l-1.24.23-1.31.22-1.2.17-1 .13c-.57.07-1.14.14-1.71.19l-1.13.11q-3.18.29-6.39.28a73.55 73.55 0 0 1-18.63-2.4 75.3 75.3 0 0 1-8.39-2.74 83.34 83.34 0 0 1-20.78-11.88c-.57-.43-1.13-.88-1.69-1.34q-1.66-1.36-3.25-2.79c-1.06-1-2.09-1.93-3.11-2.93a102.47 102.47 0 0 1-8.63-9.66c-.47-.59-.93-1.19-1.39-1.8s-.69-.92-1-1.38c-.63-.85-1.24-1.71-1.84-2.58a97.6 97.6 0 0 1-1.13-1.67c-.75-1.11-1.47-2.24-2.18-3.38a138.45 138.45 0 0 1-10.21-20.09c-.42-1-.84-2.09-1.24-3.14q-1.07-2.76-2-5.53c-1.63-4.76-3-9.53-4.13-14.23l-.21-.86a154.38 154.38 0 0 1-3-17.19c-3.24-27.9-3.25-51.23 10-71.29-5.11-1.74-13.28-4.31-13.6-13.38v-.46c0-3.53 2-6.82 5.48-9.82h0c9.1-7.84 28.64-13.76 52-17.31 6.91-1.05 14.16-1.9 21.58-2.52 42.61-3.59 78 3.77 79.08 16.43.42 5-4.65 10.14-13.57 14.7.93 1.18 1.83 2.38 2.69 3.63a74 74 0 0 1 8.73 67.29 74.09 74.09 0 0 1 9.47 71.22z" fill="#fff" stroke="#333" stroke-miterlimit="10" stroke-width="5"/>
        <path d="M1639 3252l-1 .63-.12.07q-2 1.16-4.08 2.21c-.9.44-1.8.88-2.71 1.29q-1 .43-1.92.84l-1.41.57c-.78.31-1.57.61-2.36.89l-1.19.41-1.28.42q-1 .33-2.07.63l-1.49.41c-.82.22-1.63.42-2.46.6s-1.65.36-2.48.52l-1.24.23-1.31.22-1.2.17-1 .13c-.57.07-1.14.14-1.71.19l-1.13.11q-3.18.29-6.39.28a74.34 74.34 0 0 1-27-5.13 82.69 82.69 0 0 1-20.77-11.89c-.57-.43-1.13-.88-1.69-1.34q-1.66-1.36-3.25-2.79c-1.06-1-2.09-1.93-3.11-2.93a102.47 102.47 0 0 1-8.63-9.66c-.47-.59-.93-1.19-1.39-1.8s-.69-.92-1-1.38c-.63-.85-1.24-1.71-1.84-2.58a97.6 97.6 0 0 1-1.13-1.67c-.75-1.11-1.47-2.24-2.18-3.38a138.45 138.45 0 0 1-10.21-20.09c-.42-1-.84-2.09-1.24-3.14q-1.07-2.76-2-5.53c-1.63-4.76-3-9.53-4.13-14.23l-.21-.86a154.38 154.38 0 0 1-3-17.19c-3.24-27.9-3.25-51.23 10-71.29-5.11-1.74-13.28-4.31-13.6-13.38v-.46c0-3.53 2-6.82 5.48-9.82 9.1-7.84 28.64-13.76 52-17.31l.27.17c-10.49 4.87-16.55 10.45-16.09 15.94.41 4.93 6 9 15.26 12-13.19 20.06-18.76 45.41-15.53 73.3 4.19 36.07 23.95 84 65.85 100.47a74 74 0 0 0 27 5.13c.21.02.47.02.69.02z" fill="#333" opacity=".2"/>
    </svg>
    <svg viewBox="0 0 4000 4000">
        <defs/>
        <path d="M2019 3458.8a31 31 0 0 1-.26-3.49l-.93-51.66c-.37-20 18.11-36.6 41.27-37l95.87-1.63c31.08-.53 58.46 13.67 73.28 35.2q13.8-.09 27.61 0c67.74.27 123.43 50.93 124.48 109.43l.53 29.24c.28 15.71-14.19 27.66-32.34 27a2653.1 2653.1 0 0 0-266.36 3.1c-33.88 2.09-61.71-19.27-62.24-48.63l-1-57.42c-.1-1.43-.05-2.79.09-4.14zM1978.9 3459a31 31 0 0 0 .2-3.49v-51.68c0-20-18.75-36.28-41.91-36.27l-95.89.05c-31.08 0-58.21 14.69-72.65 36.47q-13.8.16-27.61.46c-67.72 1.46-122.52 53.08-122.55 111.59v29.24c0 15.71 14.67 27.41 32.81 26.39a2656.2 2656.2 0 0 1 266.37-1.55c33.91 1.5 61.37-20.34 61.39-49.7v-57.43c.04-1.33-.08-2.69-.16-4.08z" stroke-linecap="round" stroke-linejoin="round" stroke-width="5" fill="#fff" stroke="#333"/>
        <g opacity=".1" stroke="#000" stroke-linecap="round" stroke-linejoin="round" stroke-width="5">
            <path d="M2380.81 3538.83c.29 15.7-14.19 27.66-32.34 27a2653.09 2653.09 0 0 0-266.36 3.1c-33.88 2.08-61.71-19.27-62.24-48.63q-.52-28.71-1-57.42c0-1.37 0-2.73.13-4.08a31.16 31.16 0 0 1-.26-3.49l-.93-51.66a31.51 31.51 0 0 1 .55-6.48l.38 20.64a31.16 31.16 0 0 0 .26 3.49c-.1 1.35-.15 2.71-.13 4.08q.51 28.71 1 57.42c.53 29.36 28.36 50.71 62.24 48.63a2653.09 2653.09 0 0 1 266.36-3.1c15.81.62 28.83-8.38 31.74-21.08 0 .8.06 1.58.07 2.38q.27 14.57.53 29.2zM1979.1 3461.8v58.75c0 29.37-27.47 51.2-61.38 49.72a2650.2 2650.2 0 0 0-266.37 1.55c-18.13 1-32.82-10.69-32.81-26.39v-29.25c0-1.79 0-3.56.15-5.33 1.7 14.2 15.67 24.42 32.65 23.47a2650.2 2650.2 0 0 1 266.37-1.55c33.91 1.48 61.37-20.35 61.38-49.72-.01-7.04.01-14.16.01-21.25z"/>
        </g>
    </svg>
</svg>
''';

final Uint8List svgBytes = utf8.encode(svgStr) as Uint8List;
