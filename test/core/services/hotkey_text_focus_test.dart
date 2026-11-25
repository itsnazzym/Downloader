import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:modern_downloader/core/services/hotkey_service.dart';

void main() {
  testWidgets('Esc is left to a focused text field', (tester) async {
    final field = FocusNode();
    final button = FocusNode();
    addTearDown(field.dispose);
    addTearDown(button.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(focusNode: field),
              TextButton(
                focusNode: button,
                onPressed: () {},
                child: const Text('b'),
              ),
            ],
          ),
        ),
      ),
    );

    field.requestFocus();
    await tester.pump();
    expect(HotkeyHandler.isEditingText(), isTrue);

    button.requestFocus();
    await tester.pump();
    expect(HotkeyHandler.isEditingText(), isFalse);
  });

  testWidgets('read-only selectable text does not keep Esc', (tester) async {
    final node = FocusNode();
    addTearDown(node.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SelectableText('log', focusNode: node)),
      ),
    );
    node.requestFocus();
    await tester.pump();
    expect(HotkeyHandler.isEditingText(), isFalse);
  });
}
