import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class SidebarPopoutCard extends ConsumerWidget {
  const SidebarPopoutCard({
    super.key,
    required this.type,
    required this.firstRowFocusNode,
    required this.onPointerEnter,
    required this.onPointerExit,
    required this.onFocusChange,
    required this.onKeyEvent,
    required this.onRowsChanged,
    required this.onConversationTap,
    required this.onPersonTap,
  });

  final HomeSidebarType type;
  final FocusNode firstRowFocusNode;
  final VoidCallback onPointerEnter;
  final VoidCallback onPointerExit;
  final ValueChanged<bool> onFocusChange;
  final FocusOnKeyEventCallback onKeyEvent;
  final ValueChanged<bool> onRowsChanged;
  final ValueChanged<DmConversation> onConversationTap;
  final ValueChanged<TeamMember> onPersonTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDms = type == HomeSidebarType.dms;
    final dmState = isDms ? ref.watch(dmListProvider) : null;
    final profileState = isDms ? null : ref.watch(userProfileNotifierProvider);
    final conversations =
        dmState?.asData?.value.take(4).toList() ?? const <DmConversation>[];
    final people =
        profileState?.teamMembers.take(4).toList() ?? const <TeamMember>[];
    onRowsChanged(isDms ? conversations.isNotEmpty : people.isNotEmpty);

    return Focus(
      onFocusChange: onFocusChange,
      onKeyEvent: onKeyEvent,
      child: MouseRegion(
        onEnter: (_) => onPointerEnter(),
        onExit: (_) => onPointerExit(),
        child: Material(
          color: Colors.transparent,
          elevation: 0,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 358,
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width - 16,
              maxHeight: MediaQuery.sizeOf(context).height - 16,
            ),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  offset: const Offset(0, 12),
                  blurRadius: 32,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isDms ? 'Direct messages' : 'People',
                          style: const TextStyle(
                            color: Color(0xFF182230),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isDms)
                        Text(
                          'Recent',
                          style: const TextStyle(
                            color: Color(0xFF5959A8),
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isDms && dmState!.isLoading)
                    const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (isDms && dmState!.hasError)
                    _EmptyMessage(
                      message: 'Failed to load DMs: ${dmState.error}',
                    )
                  else if (!isDms && profileState!.isLoading)
                    const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (!isDms && profileState!.error != null)
                    _EmptyMessage(message: profileState.error!)
                  else if (isDms)
                    if (conversations.isEmpty)
                      _EmptyMessage(message: 'No recent conversations')
                    else
                      for (var index = 0; index < conversations.length; index++)
                        _ConversationRow(
                          conversation: conversations[index],
                          focusNode: index == 0 ? firstRowFocusNode : null,
                          onTap: () => onConversationTap(conversations[index]),
                          isLast: index == conversations.length - 1,
                        )
                  else if (people.isEmpty)
                    _EmptyMessage(message: 'No people to show')
                  else
                    for (var index = 0; index < people.length; index++)
                      _PersonRow(
                        person: people[index],
                        focusNode: index == 0 ? firstRowFocusNode : null,
                        onTap: () => onPersonTap(people[index]),
                        isLast: index == people.length - 1,
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

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.focusNode,
    required this.onTap,
    required this.isLast,
  });

  final DmConversation conversation;
  final FocusNode? focusNode;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final name = conversation.displayName;
    final message = conversation.previewMessage
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final description = message.isEmpty ? 'No recent message' : message;
    return _PopoutRow(
      focusNode: focusNode,
      name: name,
      description: description,
      avatarUrl: conversation.effectiveAvatarUrl,
      onTap: onTap,
      isLink: true,
      isLast: isLast,
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.person,
    required this.focusNode,
    required this.onTap,
    required this.isLast,
  });

  final TeamMember person;
  final FocusNode? focusNode;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return _PopoutRow(
      focusNode: focusNode,
      name: person.name?.isNotEmpty == true
          ? person.name!
          : 'Organisation member',
      description: person.role.isNotEmpty ? person.role : 'Organisation member',
      avatarUrl: person.avatarUrl,
      onTap: onTap,
      isLink: false,
      status: person.status.name,
      isLast: isLast,
    );
  }
}

class _PopoutRow extends StatelessWidget {
  const _PopoutRow({
    required this.focusNode,
    required this.name,
    required this.description,
    required this.avatarUrl,
    required this.onTap,
    required this.isLink,
    this.status,
    this.isLast = false,
  });

  final FocusNode? focusNode;
  final String name;
  final String description;
  final String? avatarUrl;
  final VoidCallback onTap;
  final bool isLink;
  final String? status;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final displayStatus = status == null || status!.isEmpty
        ? status ?? ''
        : '${status![0].toUpperCase()}${status!.substring(1)}';
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Semantics(
        label: '$name: $description',
        link: isLink,
        button: !isLink,
        onTap: onTap,
        child: ExcludeSemantics(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              focusNode: focusNode,
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              onTap: onTap,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    alignment: Alignment.center,
                    child: avatarUrl?.isNotEmpty == true
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.network(
                              avatarUrl!,
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _avatarFallback(),
                            ),
                          )
                        : _avatarFallback(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF182230),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF5959A8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      displayStatus,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        color: Color(0xFF5959A8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback() => Text(
    name[0].toUpperCase(),
    style: const TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        message,
        style: const TextStyle(color: Color(0xFF667085), fontSize: 14),
      ),
    );
  }
}
