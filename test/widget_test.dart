import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyper_inventory/widgets/common_widgets.dart';

void main() {
  testWidgets('section heading shows Arabic title and subtitle', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SectionHeading('حالة المخزون', subtitle: 'ملخص حسب بيانات التقرير'),
      ),
    ));

    expect(find.text('حالة المخزون'), findsOneWidget);
    expect(find.text('ملخص حسب بيانات التقرير'), findsOneWidget);
  });
}
