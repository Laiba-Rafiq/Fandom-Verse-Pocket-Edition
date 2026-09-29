import 'package:flutter/material.dart';

import '../../core/utils/ui_helpers.dart';
import '../../routes/app_navigator.dart';
import '../../services/auth_service.dart';

Future<void> confirmLogout(BuildContext context) async {
  final ok = await UiHelpers.confirm(
    context,
    title: 'Log out?',
    message: 'You will need to log in again to use Fandom Verse.',
    confirmText: 'Log out',
  );
  if (!ok) return;

  await AuthService.instance.signOut();
  if (context.mounted) AppNavigator.backToRoot(context);
}
