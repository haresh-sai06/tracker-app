import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_app/presentation/widgets/panel_entrance.dart';

void main() {
  group('shouldPlayPanelEntrance', () {
    test('does not animate when disableAnimations is true', () {
      expect(shouldPlayPanelEntrance(true), isFalse);
    });

    test('animates when disableAnimations is false', () {
      expect(shouldPlayPanelEntrance(false), isTrue);
    });

    test('keeps the entrance within the fade and 8px slide budget', () {
      expect(panelEntranceDuration, const Duration(milliseconds: 240));
      expect(panelEntranceSlidePixels, lessThanOrEqualTo(8));
      expect(panelEntranceSlidePixels, greaterThan(0));
    });
  });

  testWidgets('shows the panel immediately when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: PanelEntrance(child: Text('Income')),
        ),
      ),
    );

    expect(find.text('Income'), findsOneWidget);
    expect(find.byKey(const Key('panel-entrance-opacity')), findsNothing);
    expect(find.byKey(const Key('panel-entrance-slide')), findsNothing);
  });

  testWidgets('fades and slides the panel in when motion is allowed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: false),
          child: PanelEntrance(child: Text('Recent transactions')),
        ),
      ),
    );

    final opacity = tester.widget<Opacity>(
      find.byKey(const Key('panel-entrance-opacity')),
    );
    final slide = tester.widget<Transform>(
      find.byKey(const Key('panel-entrance-slide')),
    );
    expect(opacity.opacity, 0);
    expect(slide.transform.getTranslation().y, panelEntranceSlidePixels);

    await tester.pump(panelEntranceDuration);

    final settledOpacity = tester.widget<Opacity>(
      find.byKey(const Key('panel-entrance-opacity')),
    );
    final settledSlide = tester.widget<Transform>(
      find.byKey(const Key('panel-entrance-slide')),
    );
    expect(settledOpacity.opacity, 1);
    expect(settledSlide.transform.getTranslation().y, 0);
    expect(find.text('Recent transactions'), findsOneWidget);
  });
}
