import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linsy/features/room/presentation/widgets/room_panel_handle.dart';

void main() {
  testWidgets('collapse control works away from the top of a long list', (
    tester,
  ) async {
    final controller = ScrollController(initialScrollOffset: 1200);
    addTearDown(controller.dispose);
    var expanded = true;
    var dragged = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                RoomPanelHandle(
                  expanded: expanded,
                  keyboardVisible: false,
                  onTap: () => setState(() => expanded = !expanded),
                  onDragUpdate: (_) => dragged = true,
                ),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemExtent: 50,
                    itemCount: 100,
                    itemBuilder: (_, i) => Text('Message $i'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(controller.offset, 1200);
    expect(
      tester.getSize(find.byType(RoomPanelHandle)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('Collapse'));
    await tester.pump();
    expect(find.text('Expand'), findsOneWidget);
    expect(controller.offset, 1200);
    await tester.tap(find.text('Expand'));
    await tester.pump();
    await tester.drag(find.byType(RoomPanelHandle), const Offset(0, 60));
    await tester.pump();
    expect(dragged, isTrue);
    expect(controller.offset, 1200);
    expect(tester.takeException(), isNull);
  });
}
