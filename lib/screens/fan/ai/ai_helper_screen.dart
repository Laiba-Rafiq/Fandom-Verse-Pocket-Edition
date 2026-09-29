import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/ai_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../services/ai_helper_service.dart';
import '../../../widgets/floating_ai_button.dart';

class AiHelperScreen extends StatefulWidget {
  const AiHelperScreen({super.key, required this.userName});

  final String userName;

  @override
  State<AiHelperScreen> createState() => _AiHelperScreenState();
}

class _AiHelperScreenState extends State<AiHelperScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<AiMessage> _messages = [];
  bool _thinking = false;
  String? _lastQuestion;

  String get _firstName {
    final name = widget.userName.trim();
    if (name.isEmpty) return 'fan';
    return name.split(RegExp(r'\s+')).first;
  }

  @override
  void initState() {
    super.initState();
    FanAssistant.setChatOpen(true);
  }

  @override
  void dispose() {
    FanAssistant.setChatOpen(false);
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? preset]) async {
    if (_thinking) return;
    final question = (preset ?? _inputController.text).trim();
    if (question.isEmpty) return;
    if (question.length > AiConfig.maxQuestionLength) {
      UiHelpers.showSnack(
        context,
        'Please keep your question under ${AiConfig.maxQuestionLength} '
        'characters.',
        isError: true,
      );
      return;
    }

    final history = List<AiMessage>.from(_messages);
    FocusScope.of(context).unfocus();
    _inputController.clear();
    setState(() {
      _messages.add(
        AiMessage(text: question, fromUser: true, time: DateTime.now()),
      );
      _thinking = true;
      _lastQuestion = question;
    });
    _scrollToBottom();

    await _ask(question, history);
  }

  Future<void> _ask(String question, List<AiMessage> history) async {
    try {
      final answer = await AiHelperService.instance.ask(question, history);
      if (!mounted) return;
      setState(() {
        _messages.add(
          AiMessage(
              text: _clean(answer), fromUser: false, time: DateTime.now()),
        );
      });
    } on AiHelperException catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          AiMessage(
            text: error.message,
            fromUser: false,
            time: DateTime.now(),
            isError: true,
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          AiMessage(
            text: 'Something went wrong. Please try again.',
            fromUser: false,
            time: DateTime.now(),
            isError: true,
          ),
        );
      });
    } finally {
      if (mounted) setState(() => _thinking = false);
      _scrollToBottom();
    }
  }

  Future<void> _retry() async {
    final question = _lastQuestion;
    if (question == null || _thinking) return;
    setState(() {
      if (_messages.isNotEmpty && _messages.last.isError) {
        _messages.removeLast();
      }
      _thinking = true;
    });
    final history = List<AiMessage>.from(_messages);
    if (history.isNotEmpty && history.last.fromUser) history.removeLast();
    _scrollToBottom();
    await _ask(question, history);
  }

  Future<void> _clearChat() async {
    if (_messages.isEmpty) return;
    final confirmed = await UiHelpers.confirm(
      context,
      title: 'Clear chat?',
      message: 'This removes all messages from this conversation.',
      confirmText: 'Clear',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _messages.clear();
      _lastQuestion = null;
    });
  }

  String _clean(String text) {
    final lines = text.replaceAll('**', '').split('\n').map((line) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('* ') || trimmed.startsWith('- ')) {
        return '• ${trimmed.substring(2)}';
      }
      if (trimmed.startsWith('#')) {
        return trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
      }
      return line;
    });
    return lines.join('\n').trim();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF8F3FF), Color(0xFFFFF4F9)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChatHeader(
                thinking: _thinking,
                canClear: _messages.isNotEmpty && !_thinking,
                onClear: _clearChat,
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ListView(
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      children: [
                        _WelcomeCard(name: _firstName),
                        if (_messages.isEmpty) ...[
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              const Icon(
                                Icons.lightbulb_rounded,
                                size: 18,
                                color: AppColors.pink,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Try asking',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final suggestion in AiConfig.suggestions)
                                _SuggestionChip(
                                  label: suggestion,
                                  onTap: () => _send(suggestion),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 16),
                        for (var i = 0; i < _messages.length; i++) ...[
                          _MessageBubble(
                            message: _messages[i],
                            onRetry: _messages[i].isError &&
                                    i == _messages.length - 1 &&
                                    !_thinking
                                ? _retry
                                : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_thinking) const _ThinkingBubble(),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(26)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F6C4DFF),
                      blurRadius: 18,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _inputController,
                                    minLines: 1,
                                    maxLines: 4,
                                    maxLength: AiConfig.maxQuestionLength,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _send(),
                                    enabled: !_thinking,
                                    decoration: InputDecoration(
                                      hintText: _thinking
                                          ? 'Fan Helper is typing...'
                                          : 'Ask about any fandom...',
                                      counterText: '',
                                      filled: true,
                                      fillColor: AppColors.lavender,
                                      prefixIcon: const Icon(
                                        Icons.auto_awesome_rounded,
                                        color: AppColors.pink,
                                        size: 20,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 12,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(26),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(26),
                                        borderSide: const BorderSide(
                                          color: Color(0x26A23CF0),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(26),
                                        borderSide: const BorderSide(
                                          color: AppColors.pink,
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    style:
                                        const TextStyle(color: AppColors.ink),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _SendButton(
                                  enabled: !_thinking,
                                  onTap: () => _send(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 12,
                                  color: colors.outline,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'AI answers can be wrong. Double-check '
                                    'important facts.',
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.thinking,
    required this.canClear,
    required this.onClear,
  });

  final bool thinking;
  final bool canClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x336C4DFF),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        child: Stack(
          children: [
            Positioned(
              top: -50,
              right: -30,
              child: IgnorePointer(
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.10),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(8, topInset + 8, 12, 16),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    width: 50,
                    height: 50,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.4),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: const ClipOval(child: _BotImage()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          AiConfig.assistantName,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 19,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: thinking
                                    ? const Color(0xFFFFD166)
                                    : const Color(0xFF7CF5B4),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                thinking
                                    ? 'Typing...'
                                    : 'Online • Powered by Gemini',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: CircleBorder(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: IconButton(
                      tooltip: 'Clear chat',
                      onPressed: canClear ? onClear : null,
                      icon: Icon(
                        Icons.delete_sweep_outlined,
                        color:
                            Colors.white.withValues(alpha: canClear ? 1 : 0.45),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotImage extends StatelessWidget {
  const _BotImage();

  static const String path = 'assets/images/categories/cat_ai_helper.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.buttonGradient),
        child: Center(
          child: Icon(Icons.smart_toy_rounded, color: Colors.white),
        ),
      ),
    );
  }
}

class _BotAvatar extends StatelessWidget {
  const _BotAvatar({this.radius = 16});

  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        gradient: AppColors.buttonGradient,
        shape: BoxShape.circle,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const ClipOval(child: _BotImage()),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final artSize = MediaQuery.of(context).size.width < 360 ? 84.0 : 100.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x26A23CF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x146C4DFF),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) =>
                      AppColors.buttonGradient.createShader(bounds),
                  child: Text(
                    'Hi $name! 👋',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  "I'm Fan Helper",
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Ask me about fandom terms, lore, trivia, conventions, '
                  'cosplay or how to use this app. I keep things '
                  'spoiler-safe!',
                  style: TextStyle(
                    color: AppColors.ink,
                    height: 1.4,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: artSize,
            height: artSize,
            child: Image.asset(
              _BotImage.path,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) =>
                  const _BotAvatar(radius: 28),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      elevation: 1,
      shadowColor: const Color(0x406C4DFF),
      shape: const StadiumBorder(
        side: BorderSide(color: Color(0x55F0357A)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 15,
                color: AppColors.pink,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.pink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.onRetry});

  final AiMessage message;
  final VoidCallback? onRetry;

  static String _timeLabel(DateTime time) {
    final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour12:$minute $period';
  }

  static TextStyle _timeStyle(ColorScheme colors) {
    return TextStyle(
      color: colors.outline,
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxWidth = MediaQuery.of(context).size.width * 0.78;
    final time = _timeLabel(message.time);

    if (message.fromUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(6),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x33F0357A),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: const TextStyle(color: Colors.white, height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(time, style: _timeStyle(colors)),
          ],
        ),
      );
    }

    final isError = message.isError;
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BotAvatar(radius: 14),
          const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isError ? const Color(0x1AE5484D) : colors.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  border: Border.all(
                    color: isError
                        ? const Color(0x55E5484D)
                        : colors.outlineVariant,
                  ),
                  boxShadow: isError
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0x0F6C4DFF),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isError)
                      Text(
                        message.text,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      SelectableText(
                        message.text,
                        style: TextStyle(
                          color: colors.onSurface,
                          height: 1.5,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(time, style: _timeStyle(colors)),
                    if (onRetry != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: onRetry,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.pink,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Try again'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BotAvatar(radius: 14),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.pink,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Fan Helper is thinking...',
                  style: TextStyle(
                    color: AppColors.purple,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Send',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: enabled ? AppColors.buttonGradient : null,
            color: enabled ? null : Colors.grey.shade400,
            shape: BoxShape.circle,
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: Color(0x40F0357A),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
