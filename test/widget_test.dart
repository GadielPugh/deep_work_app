import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:deep_work/main.dart';
import 'package:deep_work/services/app_services.dart';
import 'package:deep_work/services/feedback/feedback_service.dart';
import 'package:deep_work/services/storage/fake_session_storage_service.dart';
import 'package:deep_work/state/categories_state.dart';
import 'package:deep_work/state/sessions_state.dart';

void main() {
  late _FakeFeedbackService feedbackService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppServices.sessionStorage = FakeSessionStorageService();
    feedbackService = _FakeFeedbackService();
    AppServices.feedbackService = feedbackService;
    CategoriesState.instance.resetForTesting();
    SessionsState.instance.resetForTesting();
  });

  testWidgets('app renders the main tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Sessions'), findsWidgets);
    expect(find.text('Insights'), findsWidgets);
  });

  testWidgets('home settings icon opens settings screen', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.settings));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
    expect(find.text('Manage Categories'), findsOneWidget);
    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Dark Mode'), findsNothing);
    expect(find.text('Write feedback in the app'), findsOneWidget);

    await tester.tap(find.text('Manage Categories'));
    await tester.pumpAndSettle();

    expect(find.byIcon(CupertinoIcons.add_circled), findsOneWidget);
    expect(find.text('Reading'), findsOneWidget);
  });

  testWidgets('feedback form enables sending after feedback is entered', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send Feedback').last);
    await tester.pumpAndSettle();

    expect(_feedbackSendButton(tester).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('feedback_message_field')),
      'Please add weekly summaries.',
    );
    await tester.pumpAndSettle();

    expect(_feedbackSendButton(tester).onPressed, isNotNull);
    expect(feedbackService.submissions, isEmpty);
  });

  testWidgets('feedback form disables send while submitting', (tester) async {
    feedbackService.pendingSend = Completer<void>();
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send Feedback').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('feedback_message_field')),
      'Please add weekly summaries.',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('feedback_send_button')));
    await tester.pump();

    expect(_feedbackSendButton(tester).onPressed, isNull);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

    feedbackService.pendingSend!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Feedback sent. Thank you.'), findsOneWidget);
    expect(
      feedbackService.submissions.single.message,
      'Please add weekly summaries.',
    );
  });

  testWidgets('feedback form shows controlled error when sending fails', (
    tester,
  ) async {
    feedbackService.shouldFail = true;

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send Feedback').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('feedback_message_field')),
      'Please add weekly summaries.',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('feedback_send_button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Feedback could not be sent. Please try again.'),
      findsOneWidget,
    );
  });
}

CupertinoButton _feedbackSendButton(WidgetTester tester) {
  return tester.widget<CupertinoButton>(
    find.byKey(const ValueKey('feedback_send_button')),
  );
}

class _FakeFeedbackService implements FeedbackService {
  bool shouldFail = false;
  Completer<void>? pendingSend;
  final submissions = <FeedbackSubmission>[];

  @override
  Future<void> sendFeedback(FeedbackSubmission submission) async {
    if (pendingSend != null) {
      await pendingSend!.future;
    }
    if (shouldFail) {
      throw const FeedbackSendException('Failed for test.');
    }
    submissions.add(submission);
  }
}
