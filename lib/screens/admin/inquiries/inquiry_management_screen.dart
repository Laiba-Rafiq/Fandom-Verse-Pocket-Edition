import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/link_launcher.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../models/inquiry.dart';
import '../../../services/inquiry_service.dart';
import '../../../widgets/state_views.dart';
import '../widgets/admin_ui.dart';

enum _InquiryFilter { open, resolved, all }

extension on _InquiryFilter {
  String get label {
    switch (this) {
      case _InquiryFilter.open:
        return 'New';
      case _InquiryFilter.resolved:
        return 'Resolved';
      case _InquiryFilter.all:
        return 'All';
    }
  }
}

class InquiryManagementScreen extends StatefulWidget {
  const InquiryManagementScreen({super.key});

  @override
  State<InquiryManagementScreen> createState() =>
      _InquiryManagementScreenState();
}

class _InquiryManagementScreenState extends State<InquiryManagementScreen> {
  late Stream<List<Inquiry>> _stream = InquiryService.instance.watchAll();
  final _searchController = TextEditingController();
  String _query = '';
  _InquiryFilter _filter = _InquiryFilter.open;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _retry() {
    setState(() => _stream = InquiryService.instance.watchAll());
  }

  List<Inquiry> _apply(List<Inquiry> all) {
    final query = _query.trim().toLowerCase();
    return all.where((inquiry) {
      if (_filter == _InquiryFilter.open && inquiry.isResolved) return false;
      if (_filter == _InquiryFilter.resolved && !inquiry.isResolved) {
        return false;
      }
      if (query.isEmpty) return true;
      return inquiry.name.toLowerCase().contains(query) ||
          inquiry.email.toLowerCase().contains(query) ||
          inquiry.subject.toLowerCase().contains(query) ||
          inquiry.message.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _toggleResolved(Inquiry inquiry) async {
    final resolve = !inquiry.isResolved;
    try {
      await InquiryService.instance.setResolved(inquiry.id, resolve);
      if (mounted) {
        UiHelpers.showSnack(
          context,
          resolve ? 'Marked as resolved.' : 'Marked as new.',
        );
      }
    } on InquiryException catch (error) {
      if (mounted) UiHelpers.showSnack(context, error.message, isError: true);
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not update the message. Please try again.',
          isError: true,
        );
      }
    }
  }

  Future<void> _delete(Inquiry inquiry) async {
    final confirmed = await UiHelpers.confirm(
      context,
      title: 'Delete message?',
      message: 'The message from ${inquiry.name} will be removed. '
          'This cannot be undone.',
      confirmText: 'Delete',
    );
    if (!confirmed) return;
    try {
      await InquiryService.instance.delete(inquiry.id);
      if (mounted) UiHelpers.showSnack(context, 'Message deleted.');
    } on InquiryException catch (error) {
      if (mounted) UiHelpers.showSnack(context, error.message, isError: true);
    } catch (_) {
      if (mounted) {
        UiHelpers.showSnack(
          context,
          'Could not delete the message. Please try again.',
          isError: true,
        );
      }
    }
  }

  void _reply(Inquiry inquiry) {
    LinkLauncher.openEmail(
      context,
      inquiry.email,
      subject: 'Re: ${inquiry.subject} - Fandom Verse',
      body: 'Hi ${inquiry.name},\n\nThank you for contacting Fandom Verse.\n\n',
    );
  }

  void _call(Inquiry inquiry) {
    final phone = inquiry.phone;
    if (phone == null) return;
    LinkLauncher.openPhone(context, phone);
  }

  void _openDetails(Inquiry inquiry) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _InquiryDetailSheet(
        inquiry: inquiry,
        onReply: () => _reply(inquiry),
        onCall: inquiry.hasPhone ? () => _call(inquiry) : null,
        onToggle: () {
          Navigator.of(sheetContext).pop();
          _toggleResolved(inquiry);
        },
        onDelete: () {
          Navigator.of(sheetContext).pop();
          _delete(inquiry);
        },
      ),
    );
  }

  Widget _header({int? openCount, int? total}) {
    return AdminPageHeader(
      title: 'Enquiries',
      subtitle: 'Read and reply to messages fans send from Contact Us.',
      icon: Icons.mark_email_unread_rounded,
      chips: [
        if (openCount != null && total != null) ...[
          AdminHeaderChip(
            icon: Icons.mark_email_unread_rounded,
            label: '$openCount new',
            color: AppColors.pink,
          ),
          AdminHeaderChip(
            icon: Icons.inbox_rounded,
            label: '$total total',
            color: AppColors.primary,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Inquiry>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return AdminPageScaffold(
            header: _header(),
            body: ErrorView(
              message: 'Could not load enquiries.\n${snapshot.error}',
              onRetry: _retry,
            ),
          );
        }
        if (!snapshot.hasData) {
          return AdminPageScaffold(
            header: _header(),
            body: const LoadingView(message: 'Loading enquiries...'),
          );
        }

        final all = snapshot.data!;
        if (all.isEmpty) {
          return AdminPageScaffold(
            header: _header(openCount: 0, total: 0),
            body: const EmptyStateView(
              icon: Icons.mark_email_read_outlined,
              title: 'No enquiries yet',
              message: 'Messages that fans send from the Contact Us screen '
                  'will appear here.',
            ),
          );
        }

        final openCount = all.where((i) => !i.isResolved).length;
        final visible = _apply(all);

        return AdminPageScaffold(
          header: _header(openCount: openCount, total: all.length),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AdminStatBox(
                          label: 'New',
                          value: '$openCount',
                          icon: Icons.mark_email_unread_rounded,
                          color: AppColors.pink,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AdminStatBox(
                          label: 'Resolved',
                          value: '${all.length - openCount}',
                          icon: Icons.task_alt_rounded,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AdminStatBox(
                          label: 'Total',
                          value: '${all.length}',
                          icon: Icons.inbox_rounded,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AdminSearchField(
                    controller: _searchController,
                    hint: 'Search by name, email, subject or message',
                    query: _query,
                    onChanged: (value) => setState(() => _query = value),
                    onClear: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final filter in _InquiryFilter.values)
                        AdminFilterPill(
                          label: filter.label,
                          selected: _filter == filter,
                          onTap: () => setState(() => _filter = filter),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  AdminSectionTitle(
                    title: '${_filter.label} messages',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lavender,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${visible.length} '
                        '${visible.length == 1 ? 'message' : 'messages'}',
                        style: const TextStyle(
                          color: AppColors.purple,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (visible.isEmpty)
                    AdminEmptyNote(
                      icon: _query.isEmpty
                          ? Icons.mark_email_read_outlined
                          : Icons.search_off_rounded,
                      text: _query.isEmpty
                          ? 'No ${_filter.label.toLowerCase()} messages.'
                          : 'No messages match "$_query".',
                    )
                  else
                    for (final inquiry in visible) ...[
                      _InquiryCard(
                        inquiry: inquiry,
                        onTap: () => _openDetails(inquiry),
                        onToggle: () => _toggleResolved(inquiry),
                      ),
                      const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.resolved});

  final bool resolved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: resolved ? const Color(0x221FA971) : AppColors.softPink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        resolved ? 'Resolved' : 'New',
        style: TextStyle(
          color: resolved ? AppColors.success : AppColors.pink,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InquiryCard extends StatelessWidget {
  const _InquiryCard({
    required this.inquiry,
    required this.onTap,
    required this.onToggle,
  });

  final Inquiry inquiry;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final initial = inquiry.name.isEmpty ? '?' : inquiry.name[0].toUpperCase();
    final isNew = !inquiry.isResolved;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isNew ? const Color(0x66F0357A) : const Color(0x26A23CF0),
          width: isNew ? 1.4 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x146C4DFF),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: isNew ? AppColors.buttonGradient : null,
                        color: isNew ? null : AppColors.lavender,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        initial,
                        style: TextStyle(
                          color: isNew ? Colors.white : AppColors.purple,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  inquiry.subject,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _StatusTag(resolved: inquiry.isResolved),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${inquiry.name} • ${inquiry.email}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.lavender.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    inquiry.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.ink,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: colors.outline,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        inquiry.sentLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall,
                      ),
                    ),
                    Tooltip(
                      message: inquiry.isResolved
                          ? 'Mark as new'
                          : 'Mark as resolved',
                      child: Material(
                        color: (inquiry.isResolved
                                ? colors.outline
                                : AppColors.success)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: onToggle,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  inquiry.isResolved
                                      ? Icons.undo_rounded
                                      : Icons.check_circle_outline_rounded,
                                  size: 16,
                                  color: inquiry.isResolved
                                      ? colors.outline
                                      : AppColors.success,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  inquiry.isResolved ? 'Reopen' : 'Resolve',
                                  style: TextStyle(
                                    color: inquiry.isResolved
                                        ? colors.outline
                                        : AppColors.success,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InquiryDetailSheet extends StatelessWidget {
  const _InquiryDetailSheet({
    required this.inquiry,
    required this.onReply,
    required this.onToggle,
    required this.onDelete,
    this.onCall,
  });

  final Inquiry inquiry;
  final VoidCallback onReply;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.mail_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      inquiry.subject,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusTag(resolved: inquiry.isResolved),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0x26A23CF0)),
                ),
                child: Column(
                  children: [
                    _SheetLine(
                      icon: Icons.person_outline_rounded,
                      text: inquiry.name,
                    ),
                    _SheetLine(
                      icon: Icons.alternate_email_rounded,
                      text: inquiry.email,
                    ),
                    if (inquiry.hasPhone)
                      _SheetLine(
                        icon: Icons.phone_outlined,
                        text: inquiry.phone!,
                      ),
                    _SheetLine(
                      icon: Icons.schedule_rounded,
                      text: 'Sent ${inquiry.sentLabel}',
                    ),
                    if (inquiry.resolvedAt != null)
                      _SheetLine(
                        icon: Icons.task_alt_rounded,
                        text: 'Resolved '
                            '${Inquiry.formatDateTime(inquiry.resolvedAt!)}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const AdminSectionTitle(title: 'Message'),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: AppColors.softGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SelectableText(
                  inquiry.message,
                  style: textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33F0357A),
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: FilledButton.icon(
                        onPressed: onReply,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.reply_rounded),
                        label: const Text(
                          'Reply by email',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  if (onCall != null) ...[
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      tooltip: 'Call',
                      onPressed: onCall,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.lavender,
                        foregroundColor: AppColors.purple,
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.call_rounded),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onToggle,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: inquiry.isResolved
                            ? colors.onSurface
                            : AppColors.success,
                        side: BorderSide(
                          color: inquiry.isResolved
                              ? colors.outlineVariant
                              : AppColors.success.withValues(alpha: 0.5),
                        ),
                        minimumSize: const Size(0, 46),
                        shape: const StadiumBorder(),
                      ),
                      icon: Icon(
                        inquiry.isResolved
                            ? Icons.undo_rounded
                            : Icons.task_alt_rounded,
                      ),
                      label: Text(
                        inquiry.isResolved ? 'Mark as new' : 'Mark as resolved',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: onDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.5),
                      ),
                      minimumSize: const Size(0, 46),
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text(
                      'Delete',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetLine extends StatelessWidget {
  const _SheetLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.lavender,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: AppColors.purple),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
