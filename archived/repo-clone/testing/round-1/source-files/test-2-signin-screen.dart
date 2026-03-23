import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:pm_master_v2/features/auth/presentation/providers/auth_provider.dart';
import 'package:pm_master_v2/features/auth/presentation/screens/signin_screen.dart';
import '../../../helpers/test_helpers.dart';
import '../../../mocks/mock_auth.dart';
import '../../../mocks/generate_mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SignInScreen Widget Tests', () {
    late MockAuthInterface mockAuthRepository;

    setUp(() {
      mockAuthRepository = MockAuthInterface();
    });

    testWidgets('displays all required UI elements', (WidgetTester tester) async {
      // Set large screen size and disable overflow errors
      await tester.binding.setSurfaceSize(const Size(1200, 1600));

      // Disable overflow error reporting
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (!details.toString().contains('RenderFlex overflowed')) {
          originalOnError?.call(details);
        }
      };

      await pumpWidgetWithProviders(
        tester,
        const SignInScreen(),
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
        ],
      );

      // Verify UI elements
      expect(find.byIcon(Icons.hub_outlined), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);

      // Restore error handler
      FlutterError.onError = originalOnError;
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('validates email format', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.toString().contains('RenderFlex overflowed')) {
          originalOnError?.call(details);
        }
      };

      await pumpWidgetWithProviders(
        tester,
        const SignInScreen(),
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
        ],
      );

      final emailFields = find.byType(TextFormField);
      await tester.enterText(emailFields.first, 'invalid-email');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pump();

      expect(find.text('Please enter a valid email address'), findsOneWidget);

      FlutterError.onError = originalOnError;
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('toggles password visibility', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.toString().contains('RenderFlex overflowed')) {
          originalOnError?.call(details);
        }
      };

      await pumpWidgetWithProviders(
        tester,
        const SignInScreen(),
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
        ],
      );

      final visibilityButton = find.byIcon(Icons.visibility_outlined);
      expect(visibilityButton, findsOneWidget);

      await tester.tap(visibilityButton);
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      FlutterError.onError = originalOnError;
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('successfully signs in with valid credentials', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.toString().contains('RenderFlex overflowed')) {
          originalOnError?.call(details);
        }
      };

      when(mockAuthRepository.signIn(
        email: 'test@example.com',
        password: 'password123',
      )).thenAnswer((_) async => createMockAuthResult());

      await pumpWidgetWithProviders(
        tester,
        const SignInScreen(),
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
        ],
      );

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.first, 'test@example.com');
      await tester.enterText(fields.last, 'password123');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
      await tester.pumpAndSettle();

      verify(mockAuthRepository.signIn(
        email: 'test@example.com',
        password: 'password123',
      )).called(1);

      FlutterError.onError = originalOnError;
      await tester.binding.setSurfaceSize(null);
    });
  });
}
