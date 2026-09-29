import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../screens/fan/ai/ai_helper_screen.dart';

class FanAssistant {
  FanAssistant._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static final ValueNotifier<String?> userName = ValueNotifier<String?>(null);

  static final ValueNotifier<bool> chatOpen = ValueNotifier<bool>(false);

  static void show(String name) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      userName.value = name;
    });
  }

  static void hide() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      userName.value = null;
    });
  }

  static void setChatOpen(bool open) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      chatOpen.value = open;
    });
  }

  static void openChat() {
    final name = userName.value;
    final navigator = navigatorKey.currentState;
    if (name == null || navigator == null || chatOpen.value) return;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => AiHelperScreen(userName: name),
      ),
    );
  }
}

class FloatingAiOverlay extends StatefulWidget {
  const FloatingAiOverlay({super.key});

  @override
  State<FloatingAiOverlay> createState() => _FloatingAiOverlayState();
}

class _FloatingAiOverlayState extends State<FloatingAiOverlay> {
  static const double _size = 58;
  static const double _edge = 10;
  static const double _bottomSafeSpace = 96;

  Offset? _position;
  bool _dragging = false;

  late final Listenable _listenable = Listenable.merge([
    FanAssistant.userName,
    FanAssistant.chatOpen,
  ]);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _listenable,
      builder: (context, _) {
        final media = MediaQuery.of(context);
        final keyboardOpen = media.viewInsets.bottom > 0;
        final visible = FanAssistant.userName.value != null &&
            !FanAssistant.chatOpen.value &&
            !keyboardOpen;
        if (!visible) return const SizedBox.shrink();

        final screen = media.size;
        final minX = _edge;
        final maxX = screen.width - _size - _edge;
        final minY = media.padding.top + _edge;
        final maxY =
            screen.height - _size - media.padding.bottom - _bottomSafeSpace;

        final start = _position ?? Offset(maxX, maxY - 60);
        final left = start.dx.clamp(minX, maxX < minX ? minX : maxX);
        final top = start.dy.clamp(minY, maxY < minY ? minY : maxY);

        return Stack(
          alignment: Alignment.topLeft,
          children: [
            AnimatedPositioned(
              duration:
                  _dragging ? Duration.zero : const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              left: left,
              top: top,
              child: Semantics(
                button: true,
                label: 'Open AI Fan Helper',
                child: GestureDetector(
                  onTap: FanAssistant.openChat,
                  onPanStart: (_) => setState(() => _dragging = true),
                  onPanUpdate: (details) => setState(() {
                    _position = Offset(left, top) + details.delta;
                  }),
                  onPanEnd: (_) => setState(() {
                    _dragging = false;
                    final snapLeft = left + _size / 2 < screen.width / 2;
                    _position = Offset(snapLeft ? minX : maxX, top);
                  }),
                  child: const _AiBubble(size: _size),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AiBubble extends StatelessWidget {
  const _AiBubble({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.topLeft,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: AppColors.buttonGradient,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55F0357A),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 4),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: AppColors.pink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
