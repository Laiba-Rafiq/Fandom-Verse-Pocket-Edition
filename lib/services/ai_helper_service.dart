import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../config/ai_config.dart';

class AiMessage {
  const AiMessage({
    required this.text,
    required this.fromUser,
    required this.time,
    this.isError = false,
  });

  final String text;
  final bool fromUser;
  final DateTime time;
  final bool isError;
}

class AiHelperException implements Exception {
  const AiHelperException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiHelperService {
  AiHelperService._();

  static final AiHelperService instance = AiHelperService._();

  static const Duration _timeout = Duration(seconds: 40);

  static const List<String> _backupModels = [
    AiConfig.fallbackModel,
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];

  String _activeModel = AiConfig.primaryModel;

  String get activeModel => _activeModel;

  GenerativeModel _buildModel(String name) {
    return FirebaseAI.googleAI().generativeModel(
      model: name,
      systemInstruction: Content.system(AiConfig.systemInstruction),
      generationConfig: GenerationConfig(
        temperature: AiConfig.temperature,
        maxOutputTokens: AiConfig.maxOutputTokens,
      ),
    );
  }

  Future<String> ask(String question, List<AiMessage> history) async {
    final text = question.trim();
    if (text.isEmpty) {
      throw const AiHelperException('Please type a question first.');
    }
    if (text.length > AiConfig.maxQuestionLength) {
      throw const AiHelperException(
        'Your question is too long. Please keep it under '
        '${AiConfig.maxQuestionLength} characters.',
      );
    }

    final contents = _buildHistory(history);
    final candidates = <String>[
      _activeModel,
      for (final name in _backupModels)
        if (name != _activeModel) name,
    ];

    Object? lastError;
    for (final name in candidates) {
      try {
        final answer = await _send(name, contents, text);
        _activeModel = name;
        return answer;
      } catch (error) {
        lastError = error;
        debugPrint('Fan Helper error with model "$name": $error');
        if (!_isModelMissing(error)) break;
      }
    }

    throw AiHelperException(_messageFor(lastError ?? 'unknown error'));
  }

  List<Content> _buildHistory(List<AiMessage> history) {
    final usable = history.where((message) => !message.isError).toList();
    var recent = usable.length > AiConfig.maxHistoryMessages
        ? usable.sublist(usable.length - AiConfig.maxHistoryMessages)
        : usable;
    while (recent.isNotEmpty && !recent.first.fromUser) {
      recent = recent.sublist(1);
    }
    return [
      for (final message in recent)
        message.fromUser
            ? Content.text(message.text)
            : Content.model([TextPart(message.text)]),
    ];
  }

  Future<String> _send(
    String modelName,
    List<Content> history,
    String question,
  ) async {
    final chat = _buildModel(modelName).startChat(history: history);
    final response =
        await chat.sendMessage(Content.text(question)).timeout(_timeout);

    String? reply;
    try {
      reply = response.text;
    } catch (_) {
      reply = null;
    }

    final cleaned = reply?.trim() ?? '';
    if (cleaned.isEmpty) {
      return 'Sorry, I could not answer that one. Try asking in a different '
          'way, or ask me about another fandom topic!';
    }
    return cleaned;
  }

  bool _isModelMissing(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('not found') ||
        text.contains('404') ||
        text.contains('is not supported') ||
        text.contains('unknown model') ||
        text.contains('does not exist') ||
        text.contains('invalid model');
  }

  String _messageFor(Object error) {
    final friendly = _friendlyMessage(error);
    if (kDebugMode) {
      final raw = error.toString();
      final short = raw.length > 300 ? '${raw.substring(0, 300)}...' : raw;
      return '$friendly\n\n[Debug] $short';
    }
    return friendly;
  }

  String _friendlyMessage(Object error) {
    if (error is TimeoutException) {
      return 'Fan Helper is taking too long. Please check your internet and '
          'try again.';
    }
    final text = error.toString().toLowerCase();
    if (text.contains('quota') ||
        text.contains('429') ||
        text.contains('resource_exhausted') ||
        text.contains('rate limit')) {
      return 'Fan Helper is very busy right now. Please try again in a '
          'minute.';
    }
    if (text.contains('safety') || text.contains('blocked')) {
      return 'I can\'t help with that one. Let\'s talk about fandoms instead!';
    }
    if (text.contains('location') || text.contains('region')) {
      return 'Fan Helper is not available in your region yet.';
    }
    if (text.contains('socket') ||
        text.contains('network') ||
        text.contains('host lookup') ||
        text.contains('connection') ||
        text.contains('unavailable')) {
      return 'No internet connection. Fan Helper needs internet to answer.';
    }
    if (text.contains('api key') ||
        text.contains('permission') ||
        text.contains('403') ||
        text.contains('not enabled') ||
        text.contains('has not been used') ||
        text.contains('disabled')) {
      return 'Fan Helper is not set up yet. Please make sure Firebase AI '
          'Logic (Gemini Developer API) is enabled.';
    }
    return 'Something went wrong while asking Fan Helper. Please try again.';
  }
}