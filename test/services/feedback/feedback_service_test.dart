import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:deep_work/services/feedback/feedback_service.dart';

void main() {
  test(
    'Formspree feedback service maps submissions to a POST request',
    () async {
      http.Request? capturedRequest;
      final service = FormspreeFeedbackService(
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response('{"ok":true}', 200);
        }),
      );

      await service.sendFeedback(
        const FeedbackSubmission(
          name: 'Gadiel',
          contact: 'gadiel@example.com',
          message: 'Please add weekly summaries.',
        ),
      );

      expect(capturedRequest?.method, 'POST');
      expect(capturedRequest?.url.toString(), formspreeFeedbackEndpoint);
      expect(capturedRequest?.headers['accept'], 'application/json');
      expect(capturedRequest?.headers['content-type'], 'application/json');

      final payload = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(payload['name'], 'Gadiel');
      expect(payload['contact'], 'gadiel@example.com');
      expect(payload['message'], 'Please add weekly summaries.');
      expect(payload['app'], 'Deep Work App');
      expect(payload['platform'], isA<String>());
      expect(payload['timestamp'], isA<String>());
    },
  );

  test('Formspree payload omits blank optional fields', () {
    final payload =
        const FeedbackSubmission(
          name: ' ',
          contact: '',
          message: 'Hello',
        ).toFormspreePayload(
          timestamp: DateTime.utc(2026, 5, 6),
          platform: TargetPlatform.iOS,
        );

    expect(payload.containsKey('name'), isFalse);
    expect(payload.containsKey('contact'), isFalse);
    expect(payload['message'], 'Hello');
    expect(payload['platform'], 'iOS');
    expect(payload['timestamp'], '2026-05-06T00:00:00.000Z');
  });

  test('Formspree feedback service accepts 2xx responses', () async {
    final service = FormspreeFeedbackService(
      client: MockClient((request) async => http.Response('', 204)),
    );

    await expectLater(
      service.sendFeedback(const FeedbackSubmission(message: 'Hello')),
      completes,
    );
  });

  test('Formspree feedback service reports non-success responses', () async {
    final service = FormspreeFeedbackService(
      client: MockClient(
        (request) async => http.Response('{"error":"bad"}', 500),
      ),
    );

    await expectLater(
      service.sendFeedback(const FeedbackSubmission(message: 'Hello')),
      throwsA(
        isA<FeedbackSendException>()
            .having((error) => error.statusCode, 'statusCode', 500)
            .having(
              (error) => error.responseBody,
              'responseBody',
              '{"error":"bad"}',
            ),
      ),
    );
  });

  test('Formspree feedback service reports network errors', () async {
    final service = FormspreeFeedbackService(
      client: MockClient((request) async => throw Exception('offline')),
    );

    expect(
      () => service.sendFeedback(const FeedbackSubmission(message: 'Hello')),
      throwsA(isA<FeedbackSendException>()),
    );
  });

  test('Formspree feedback service reports timeouts', () async {
    final service = FormspreeFeedbackService(
      timeout: const Duration(milliseconds: 1),
      client: MockClient(
        (request) => Future<http.Response>.delayed(
          const Duration(seconds: 1),
          () => http.Response('', 200),
        ),
      ),
    );

    expect(
      () => service.sendFeedback(const FeedbackSubmission(message: 'Hello')),
      throwsA(isA<FeedbackSendException>()),
    );
  });
}
