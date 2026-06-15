import 'package:flutter_test/flutter_test.dart';

import 'package:seiyun_correspondence/app/app.dart';
import 'package:seiyun_correspondence/features/auth/presentation/pages/login_page.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app starts with the LoginPage
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
