import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ranch/screens/login_screen.dart';
import 'package:smart_ranch/widgets/stats_bar.dart';

void main() {
  testWidgets('LoginScreen renders brand, inputs and action buttons', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(onAuthenticated: () {}),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Verify brand and buttons
    expect(find.text('Smart Ranch'), findsWidgets);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
    expect(find.text('Crear Cuenta Nueva'), findsOneWidget);
    expect(find.text('Entrar como Invitado (Modo Demo)'), findsOneWidget);
  });

  testWidgets('LoginScreen validates empty input fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(onAuthenticated: () {}),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // Tap login with empty inputs
    await tester.tap(find.text('Iniciar Sesión'));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify error message
    expect(find.text('Ingresa correo electrónico y contraseña'), findsOneWidget);
  });

  testWidgets('StatsBar renders correct metric counters', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatsBar(
            isConnected: true,
            totalAnimals: 10,
            normalCount: 7,
            alertCount: 2,
            dangerCount: 1,
            emergencyCount: 0,
            avgThi: 71.5,
          ),
        ),
      ),
    );

    expect(find.text('En Línea'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('71.5'), findsOneWidget);
  });
}
