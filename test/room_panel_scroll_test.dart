import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linsy/features/room/presentation/widgets/room_panel_scroll_physics.dart';

void main() {
  testWidgets('scroll unlocks after expansion and locks after collapse', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var expanded = false;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return ListView.builder(
              controller: controller,
              physics: roomPanelScrollPhysics(
                onHandoff: null,
                allowContentScroll: expanded,
              ),
              itemExtent: 60,
              itemCount: 50,
              itemBuilder: (_, index) => Text('Message $index'),
            );
          },
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    update(() => expanded = true);
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    update(() => expanded = false);
    await tester.pump();
    final previous = controller.offset;
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(controller.offset, previous);
    expect(tester.takeException(), isNull);
  });

  for (final count in [1, 50]) {
    testWidgets('downward handoff only at top ($count messages)', (
      tester,
    ) async {
      final controller = ScrollController(
        initialScrollOffset: count == 1 ? 0 : 300,
      );
      addTearDown(controller.dispose);
      var handoffs = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ListView.builder(
            controller: controller,
            physics: roomPanelScrollPhysics(
              allowContentScroll: true,
              onHandoff: (delta, metrics) {
                if (delta > 0 &&
                    metrics.pixels <= metrics.minScrollExtent + 1) {
                  handoffs++;
                  return true;
                }
                return false;
              },
            ),
            itemExtent: 60,
            itemCount: count,
            itemBuilder: (_, index) => Text('Message $index'),
          ),
        ),
      );
      if (count > 1) {
        await tester.drag(find.byType(ListView), const Offset(0, 80));
        await tester.pump();
        expect(handoffs, 0);
        expect(controller.offset, lessThan(300));
      }
      controller.jumpTo(0);
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(handoffs, greaterThan(0));
      expect(controller.offset, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
