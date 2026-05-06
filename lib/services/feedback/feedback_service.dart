import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

const formspreeFeedbackEndpoint = 'https://formspree.io/f/xeenkzbq';
const _defaultFeedbackTimeout = Duration(seconds: 15);

class FeedbackSubmission {
  const FeedbackSubmission({this.name, this.contact, required this.message});

  final String? name;
  final String? contact;
  final String message;

  Map<String, dynamic> toFormspreePayload({
    DateTime? timestamp,
    TargetPlatform? platform,
  }) {
    final cleanName = _clean(name);
    final cleanContact = _clean(contact);
    final payload = <String, dynamic>{
      'message': message.trim(),
      'app': 'Deep Work App',
      'platform': (platform ?? defaultTargetPlatform).name,
      'timestamp': (timestamp ?? DateTime.now()).toUtc().toIso8601String(),
    };
    if (cleanName != null) payload['name'] = cleanName;
    if (cleanContact != null) payload['contact'] = cleanContact;
    return payload;
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}

abstract class FeedbackService {
  Future<void> sendFeedback(FeedbackSubmission submission);
}

class FeedbackSendException implements Exception {
  const FeedbackSendException(
    this.message, {
    this.statusCode,
    this.responseBody,
    this.cause,
  });

  final String message;
  final int? statusCode;
  final String? responseBody;
  final Object? cause;

  @override
  String toString() => message;
}

class FormspreeFeedbackService implements FeedbackService {
  FormspreeFeedbackService({
    http.Client? client,
    String endpoint = formspreeFeedbackEndpoint,
    Duration timeout = _defaultFeedbackTimeout,
  }) : _client = client ?? http.Client(),
       _endpoint = Uri.parse(endpoint),
       _timeout = timeout;

  final http.Client _client;
  final Uri _endpoint;
  final Duration _timeout;

  @override
  Future<void> sendFeedback(FeedbackSubmission submission) async {
    final payload = submission.toFormspreePayload();
    _logFeedbackDebug(
      'Posting feedback to $_endpoint with fields ${payload.keys.toList()} '
      'and messageLength=${submission.message.trim().length}.',
    );

    try {
      final response = await _client
          .post(
            _endpoint,
            headers: const {
              'accept': 'application/json',
              'content-type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(_timeout);

      _logFeedbackDebug(
        'Formspree response status=${response.statusCode}, '
        'body=${_preview(response.body)}',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FeedbackSendException(
          'Formspree returned ${response.statusCode}.',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }
    } on TimeoutException catch (error, stackTrace) {
      _logFeedbackDebug('Feedback request timed out.', error, stackTrace);
      throw FeedbackSendException('Feedback request timed out.', cause: error);
    } on FeedbackSendException {
      rethrow;
    } catch (error, stackTrace) {
      _logFeedbackDebug('Feedback request failed.', error, stackTrace);
      throw FeedbackSendException('Could not send feedback.', cause: error);
    }
  }
}

void _logFeedbackDebug(
  String message, [
  Object? error,
  StackTrace? stackTrace,
]) {
  if (!kDebugMode) return;

  debugPrint('[Feedback] $message');
  if (error != null) {
    debugPrint('[Feedback] ${error.runtimeType}: $error');
  }
  if (stackTrace != null) {
    debugPrintStack(label: '[Feedback] stack', stackTrace: stackTrace);
  }
}

String _preview(String value) {
  const maxLength = 500;
  if (value.length <= maxLength) return value;
  return '${value.substring(0, maxLength)}...';
}
