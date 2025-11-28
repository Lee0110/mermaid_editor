import 'package:flutter_test/flutter_test.dart';
import 'package:mermaid_editor/main.dart';

void main() {
  testWidgets('App should build without errors', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MermaidEditorApp());

    // Verify that the app builds successfully
    expect(find.byType(MermaidEditorApp), findsOneWidget);
  });
}
