import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/contact_info.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/link_launcher.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/app_user.dart';
import '../../../models/inquiry.dart';
import '../../../services/inquiry_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/state_views.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  late final Stream<List<Inquiry>> _myMessages;

  String? _subject;
  bool _showSubjectError = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
    _myMessages = InquiryService.instance.watchMine();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _openMap() {
    LinkLauncher.openMap(
      context,
      latitude: ContactInfo.latitude,
      longitude: ContactInfo.longitude,
    );
  }

  void _openDirections() {
    LinkLauncher.openDirections(
      context,
      latitude: ContactInfo.latitude,
      longitude: ContactInfo.longitude,
    );
  }

  void _emailUs() {
    LinkLauncher.openEmail(
      context,
      ContactInfo.email,
      subject: 'Fandom Verse enquiry',
    );
  }

  void _callUs() {
    LinkLauncher.openPhone(context, ContactInfo.phone);
  }

  String? _validateName(String? value) {
    if ((value ?? '').trim().length < 2) return 'Please enter your name.';
    return null;
  }

  String? _validateEmail(String? value) {
    if (!InquiryService.isValidEmail(value ?? '')) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    if (!InquiryService.isValidPhone(text)) {
      return 'Please enter a valid phone number.';
    }
    return null;
  }

  String? _validateMessage(String? value) {
    if ((value ?? '').trim().length < 10) {
      return 'Please write a message (min 10 characters).';
    }
    return null;
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    final formOk = _formKey.currentState?.validate() ?? false;
    setState(() {
      _showSubjectError = _subject == null;
      _error = null;
    });
    final subject = _subject;
    if (!formOk || subject == null) return;

    setState(() => _sending = true);
    try {
      final sentNow = await InquiryService.instance.submit(
        name: _nameController.text,
        email: _emailController.text,
        subject: subject,
        message: _messageController.text,
        phone: _phoneController.text,
      );
      if (!mounted) return;
      final keptName = _nameController.text;
      final keptEmail = _emailController.text;
      _formKey.currentState?.reset();
      _nameController.text = keptName;
      _emailController.text = keptEmail;
      setState(() => _subject = null);
      UiHelpers.showSnack(
        context,
        sentNow
            ? 'Message sent! We will reply to your email soon.'
            : 'You are offline. Your message is saved and will be sent '
                'automatically when you are back online.',
      );
    } on InquiryException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not send your message. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ContactHero(),
            Expanded(
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _QuickAction(
                                  icon: Icons.mail_rounded,
                                  label: 'Email',
                                  onTap: _emailUs,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _QuickAction(
                                  icon: Icons.call_rounded,
                                  label: 'Call',
                                  onTap: _callUs,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _QuickAction(
                                  icon: Icons.directions_rounded,
                                  label: 'Directions',
                                  onTap: _openDirections,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Reach us',
                            icon: Icons.support_agent_rounded,
                            child: Column(
                              children: [
                                _DetailRow(
                                  icon: Icons.mail_outline_rounded,
                                  title: 'Email',
                                  value: ContactInfo.email,
                                  onTap: _emailUs,
                                ),
                                const _RowDivider(),
                                _DetailRow(
                                  icon: Icons.phone_outlined,
                                  title: 'Phone',
                                  value: ContactInfo.phone,
                                  onTap: _callUs,
                                ),
                                const _RowDivider(),
                                _DetailRow(
                                  icon: Icons.place_outlined,
                                  title: ContactInfo.organization,
                                  value: ContactInfo.fullAddress,
                                  onTap: _openMap,
                                ),
                                const _RowDivider(),
                                const _DetailRow(
                                  icon: Icons.schedule_rounded,
                                  title: 'Office hours',
                                  value: ContactInfo.officeHours,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Find our office',
                            icon: Icons.map_rounded,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _OfficeMap(onTap: _openMap),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _openMap,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.pink,
                                    side: const BorderSide(
                                      color: AppColors.pink,
                                    ),
                                    shape: const StadiumBorder(),
                                    minimumSize: const Size(0, 46),
                                  ),
                                  icon: const Icon(Icons.map_rounded),
                                  label: const Text('Open in Google Maps'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SectionCard(
                            title: 'Send us a message',
                            subtitle: ContactInfo.responseTime,
                            icon: Icons.edit_note_rounded,
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_error != null) ...[
                                    FormErrorBanner(message: _error!),
                                    const SizedBox(height: 14),
                                  ],
                                  AppTextField(
                                    controller: _nameController,
                                    label: 'Your name',
                                    icon: Icons.person_outline_rounded,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.next,
                                    validator: _validateName,
                                  ),
                                  const SizedBox(height: 12),
                                  AppTextField(
                                    controller: _emailController,
                                    label: 'Email for our reply',
                                    icon: Icons.alternate_email_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    validator: _validateEmail,
                                  ),
                                  const SizedBox(height: 12),
                                  AppTextField(
                                    controller: _phoneController,
                                    label: 'Phone (optional)',
                                    hint: '03XX XXXXXXX',
                                    icon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.next,
                                    validator: _validatePhone,
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.label_outline_rounded,
                                        size: 18,
                                        color: AppColors.purple,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Subject',
                                        style: textTheme.titleSmall?.copyWith(
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
                                      for (final subject
                                          in ContactInfo.subjects)
                                        _SubjectPill(
                                          label: subject,
                                          selected: _subject == subject,
                                          onTap: () => setState(() {
                                            _subject = subject;
                                            _showSubjectError = false;
                                          }),
                                        ),
                                    ],
                                  ),
                                  if (_showSubjectError)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 8,
                                        left: 4,
                                      ),
                                      child: Text(
                                        'Please choose a subject.',
                                        style: TextStyle(
                                          color: colors.error,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 18),
                                  AppTextField(
                                    controller: _messageController,
                                    label: 'Your message',
                                    hint: 'Tell us how we can help...',
                                    icon: Icons.chat_bubble_outline_rounded,
                                    maxLines: 5,
                                    maxLength: InquiryService.maxMessageLength,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    validator: _validateMessage,
                                  ),
                                  const SizedBox(height: 16),
                                  AppButton(
                                    label: 'Send message',
                                    icon: Icons.send_rounded,
                                    isLoading: _sending,
                                    onPressed: _send,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          StreamBuilder<List<Inquiry>>(
                            stream: _myMessages,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: Text(
                                    'Could not load your previous messages.',
                                    style: textTheme.bodySmall,
                                  ),
                                );
                              }
                              final messages =
                                  snapshot.data ?? const <Inquiry>[];
                              if (messages.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 24),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _MessagesHeading(count: messages.length),
                                    const SizedBox(height: 12),
                                    for (final inquiry in messages) ...[
                                      _MyMessageCard(inquiry: inquiry),
                                      const SizedBox(height: 10),
                                    ],
                                  ],
                                ),
                              );
                            },
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
    );
  }
}

class _ContactHero extends StatelessWidget {
  const _ContactHero();

  static const String _art = 'assets/images/categories/cat_contact_us.png';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final artSize = media.size.width < 360 ? 96.0 : 110.0;
    final canPop = Navigator.of(context).canPop();

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x336C4DFF),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        child: Stack(
          children: [
            const Positioned(
              top: -40,
              right: -30,
              child: _Bubble(size: 170, opacity: 0.10),
            ),
            const Positioned(
              bottom: -50,
              left: -40,
              child: _Bubble(size: 150, opacity: 0.08),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, topInset + 6, 12, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        if (canPop)
                          _GlassIconButton(
                            icon: Icons.arrow_back_rounded,
                            tooltip: 'Back',
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Contact Us',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  height: 1.1,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Questions, feedback or problems? '
                                'We are here to help',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 14,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _HeroStat(
                                    icon: Icons.support_agent_rounded,
                                    label: 'Fan support',
                                  ),
                                  _HeroStat(
                                    icon: Icons.place_rounded,
                                    label: ContactInfo.city,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: artSize,
                          height: artSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0.35),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                              Image.asset(
                                _art,
                                width: artSize,
                                height: artSize,
                                fit: BoxFit.contain,
                                semanticLabel: 'Contact Us',
                                errorBuilder: (context, error, stack) =>
                                    CircleAvatar(
                                  radius: artSize / 3,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.2),
                                  child: Icon(
                                    Icons.support_agent_rounded,
                                    color: Colors.white,
                                    size: artSize / 3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: CircleBorder(
        side: BorderSide(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.pink),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x126C4DFF),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x26A23CF0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: AppColors.buttonGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33F0357A),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final note = subtitle;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x26A23CF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x126C4DFF),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    if (note != null) ...[
                      const SizedBox(height: 2),
                      Text(note, style: textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.softGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.pink, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.lavender,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.purple,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 8,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _OfficeMap extends StatelessWidget {
  const _OfficeMap({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const point = LatLng(ContactInfo.latitude, ContactInfo.longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 190,
        child: Stack(
          children: [
            FlutterMap(
              options: const MapOptions(
                initialCenter: point,
                initialZoom: 15,
                interactionOptions: InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.techwiz.fandom_verse',
                ),
                const MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 46,
                      height: 46,
                      alignment: Alignment.topCenter,
                      child: Icon(
                        Icons.location_on_rounded,
                        color: AppColors.pink,
                        size: 46,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IgnorePointer(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F6C4DFF),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 14,
                        color: AppColors.pink,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Tap to open',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xCCFFFFFF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 10, color: Color(0xFF333333)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectPill extends StatelessWidget {
  const _SubjectPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Container(
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          gradient: selected ? AppColors.buttonGradient : null,
          color: selected ? null : colors.surface,
        ),
        child: Material(
          color: Colors.transparent,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected ? Colors.transparent : const Color(0x40A23CF0),
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessagesHeading extends StatelessWidget {
  const _MessagesHeading({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.forum_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'My messages',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.lavender,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: AppColors.purple,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _MyMessageCard extends StatelessWidget {
  const _MyMessageCard({required this.inquiry});

  final Inquiry inquiry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final resolved = inquiry.isResolved;
    final statusColor = resolved ? AppColors.success : AppColors.purple;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x26A23CF0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F6C4DFF),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.softGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.mail_outline_rounded,
                  size: 18,
                  color: AppColors.pink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  inquiry.subject,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: resolved
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.lavender,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      resolved
                          ? Icons.check_circle_rounded
                          : Icons.mark_email_read_rounded,
                      size: 13,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      resolved ? 'Resolved' : 'Received',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            inquiry.message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(inquiry.sentLabel, style: textTheme.bodySmall),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
