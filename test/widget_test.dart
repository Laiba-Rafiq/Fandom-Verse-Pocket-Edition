import 'package:fandom_verse/core/utils/validators.dart';
import 'package:fandom_verse/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.email('fan@example.com'), isNull);
    });

    test('password needs at least 6 characters', () {
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('123456'), isNull);
    });

    test('confirm password must match', () {
      final validator = Validators.confirmPassword(() => 'secret1');
      expect(validator('secret2'), 'Passwords do not match');
      expect(validator('secret1'), isNull);
    });

    test('name', () {
      expect(Validators.name(' '), isNotNull);
      expect(Validators.name('Al'), isNull);
    });
  });

  testWidgets('Password field toggles visibility', (tester) async {
    final controller = TextEditingController(text: 'secret');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppTextField(
            controller: controller,
            label: 'Password',
            isPassword: true,
          ),
        ),
      ),
    );

    EditableText field() =>
        tester.widget<EditableText>(find.byType(EditableText));

    expect(field().obscureText, isTrue);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(field().obscureText, isFalse);
  });
}
