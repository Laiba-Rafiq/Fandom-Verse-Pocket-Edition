import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ui_helpers.dart';

class LinkLauncher {
  LinkLauncher._();

  static Future<void> openWebsite(BuildContext context, String url) async {
    final uri = Uri.tryParse(url.trim());
    final valid = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    if (!valid) {
      UiHelpers.showSnack(context, 'This link is not valid.', isError: true);
      return;
    }
    await _launch(
      context,
      uri,
      'Could not open the link. Please try again.',
    );
  }

  static Future<void> openMap(
    BuildContext context, {
    double? latitude,
    double? longitude,
    String? place,
  }) async {
    final target = _target(latitude, longitude, place);
    if (target == null) {
      UiHelpers.showSnack(
        context,
        'No location is available for this event.',
        isError: true,
      );
      return;
    }
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': target,
    });
    await _launch(
      context,
      uri,
      'Could not open Google Maps. Please try again.',
    );
  }

  static Future<void> openDirections(
    BuildContext context, {
    double? latitude,
    double? longitude,
    String? place,
  }) async {
    final target = _target(latitude, longitude, place);
    if (target == null) {
      UiHelpers.showSnack(
        context,
        'No location is available for this event.',
        isError: true,
      );
      return;
    }
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': target,
    });
    await _launch(
      context,
      uri,
      'Could not open directions. Please try again.',
    );
  }

  static Future<void> openEmail(
    BuildContext context,
    String email, {
    String? subject,
    String? body,
  }) async {
    final address = email.trim();
    if (address.isEmpty || !address.contains('@')) {
      UiHelpers.showSnack(
        context,
        'This email address is not valid.',
        isError: true,
      );
      return;
    }
    final parts = <String>[
      if (subject != null && subject.trim().isNotEmpty)
        'subject=${Uri.encodeComponent(subject.trim())}',
      if (body != null && body.trim().isNotEmpty)
        'body=${Uri.encodeComponent(body.trim())}',
    ];
    final uri = Uri(
      scheme: 'mailto',
      path: address,
      query: parts.isEmpty ? null : parts.join('&'),
    );
    await _launch(
      context,
      uri,
      'No email app found. Please email us at $address',
    );
  }

  static Future<void> openPhone(BuildContext context, String phone) async {
    final number = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (number.length < 7) {
      UiHelpers.showSnack(
        context,
        'This phone number is not valid.',
        isError: true,
      );
      return;
    }
    await _launch(
      context,
      Uri(scheme: 'tel', path: number),
      'Could not open the dialer. Please call $phone',
    );
  }

  static String? _target(double? latitude, double? longitude, String? place) {
    if (latitude != null && longitude != null) return '$latitude,$longitude';
    final text = place?.trim() ?? '';
    if (text.isEmpty) return null;
    return text;
  }

  static Future<void> _launch(
    BuildContext context,
    Uri uri,
    String failMessage,
  ) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      UiHelpers.showSnack(context, failMessage, isError: true);
    }
  }
}
