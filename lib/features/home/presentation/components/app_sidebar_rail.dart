import 'dart:async';

import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class AppSidebarRail extends ConsumerStatefulWidget {
  const AppSidebarRail({
    super.key,
    required this.activeType,
    this.onTypeSelected,
    this.settingsSelected = false,
  });

  static const double width = 50;

  final HomeSidebarType? activeType;
  final ValueChanged<HomeSidebarType>? onTypeSelected;
  final bool settingsSelected;

  @override
  ConsumerState<AppSidebarRail> createState() => _AppSidebarRailState();
}

class _AppSidebarRailState extends ConsumerState<AppSidebarRail>
    with WidgetsBindingObserver {
  final _railKey = GlobalKey();
  final _dmsTargetKey = GlobalKey();
  final _peopleTargetKey = GlobalKey();
  final _dmsFocusNode = FocusNode();
  final _peopleFocusNode = FocusNode();
  final _firstRowFocusNode = FocusNode();
  Timer? _closeTimer;
  OverlayEntry? _popoutEntry;
  HomeSidebarType? _openPopout;
  bool _hasRows = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _closeTimer?.cancel();
    _popoutEntry?.remove();
    _dmsFocusNode.dispose();
    _peopleFocusNode.dispose();
    _firstRowFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    _popoutEntry?.markNeedsBuild();
  }

  void _open(HomeSidebarType type) {
    _closeTimer?.cancel();
    _closeTimer = null;
    if (_openPopout == type) return;
    if (type == HomeSidebarType.dms) {
      final state = ref.read(dmListProvider);
      if (state.hasError) {
        ref.read(dmListProvider.notifier).refresh();
      }
    } else if (type == HomeSidebarType.people) {
      final state = ref.read(userProfileNotifierProvider);
      if (state.error != null) {
        ref.read(userProfileNotifierProvider.notifier).load();
      }
    }
    _openPopout = type;
    _hasRows = false;
    setState(() {});
    if (_popoutEntry == null) {
      _popoutEntry = OverlayEntry(builder: _buildPopoutOverlay);
      Overlay.of(context, rootOverlay: true).insert(_popoutEntry!);
    } else {
      _popoutEntry!.markNeedsBuild();
    }
  }

  void _scheduleClose() {
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 125), _close);
  }

  void _cancelClose() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  void _close() {
    _cancelClose();
    _openPopout = null;
    _hasRows = false;
    if (mounted) setState(() {});
    _popoutEntry?.remove();
    _popoutEntry = null;
  }

  Future<void> _openPersonChat(TeamMember person) async {
    final orgId = ref.read(currentOrgIdProvider);
    if (orgId.isEmpty) {
      AppToastService.show(
        context,
        type: AppToastType.error,
        message: "Couldn't open chat. Please try again.",
      );
      return;
    }

    try {
      final response = await locator<ApiBaseService>()
          .post<Map<String, dynamic>>(
            path: '/organisations/$orgId/dms',
            data: {'chat_type': 'user', 'participant_id': person.id},
          );
      final data = response.data['data'];
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid direct message response.');
      }
      final channelId = data['channel_id'] as String?;
      final participantId = data['participant_id'] as String?;
      if (channelId == null ||
          channelId.isEmpty ||
          participantId == null ||
          participantId.isEmpty) {
        throw const FormatException('Invalid direct message response.');
      }
      ref
          .read(selectedDmProvider.notifier)
          .select(
            DmConversation(
              channelId: channelId,
              username: person.name ?? person.email,
              participantId: participantId,
              participantEmail: person.email,
              avatarUrl: person.avatarUrl,
              previewMessage: '',
              unreadCount: 0,
            ),
          );
      selectSidebarType(HomeSidebarType.dms);
      _close();
    } catch (error) {
      AppLogger.e('Failed to open direct message', error: error);
      if (!mounted) return;
      AppToastService.show(
        context,
        type: AppToastType.error,
        message: "Couldn't open chat. Please try again.",
      );
    }
  }

  void selectSidebarType(HomeSidebarType type) {
    if (widget.onTypeSelected != null) {
      widget.onTypeSelected!(type);
      return;
    }
    ref.read(homeSidebarProvider.notifier).setType(type);
  }

  Widget _buildPopoutOverlay(BuildContext context) {
    final type = _openPopout;
    if (type == null) return const SizedBox.shrink();
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayObject = overlay.context.findRenderObject();
    final railObject = _railKey.currentContext?.findRenderObject();
    final triggerObject =
        (type == HomeSidebarType.dms
                ? _dmsTargetKey.currentContext
                : _peopleTargetKey.currentContext)
            ?.findRenderObject();
    if (overlayObject is! RenderBox ||
        railObject is! RenderBox ||
        triggerObject is! RenderBox) {
      return const SizedBox.shrink();
    }
    final railRight = overlayObject
        .globalToLocal(
          railObject.localToGlobal(Offset(railObject.size.width, 0)),
        )
        .dx;
    final triggerTop = overlayObject
        .globalToLocal(triggerObject.localToGlobal(Offset.zero))
        .dy;
    return CustomSingleChildLayout(
      delegate: _SidebarPopoutLayoutDelegate(
        left: railRight + 4,
        top: triggerTop,
      ),
      child: SidebarPopoutCard(
        type: type,
        firstRowFocusNode: _firstRowFocusNode,
        onPointerEnter: _cancelClose,
        onPointerExit: _scheduleClose,
        onFocusChange: (focused) => focused ? _cancelClose() : _scheduleClose(),
        onKeyEvent: _handleCardKey,
        onRowsChanged: (hasRows) => _hasRows = hasRows,
        onConversationTap: (conversation) {
          ref.read(selectedDmProvider.notifier).select(conversation);
          selectSidebarType(HomeSidebarType.dms);
          _close();
        },
        onPersonTap: _openPersonChat,
      ),
    );
  }

  KeyEventResult _handleTriggerKey(
    HomeSidebarType type,
    FocusNode node,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape && _openPopout != null) {
      final active = _openPopout!;
      _close();
      (active == HomeSidebarType.dms ? _dmsFocusNode : _peopleFocusNode)
          .requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.tab &&
        !HardwareKeyboard.instance.isShiftPressed &&
        _openPopout == type &&
        node.hasPrimaryFocus &&
        _hasRows) {
      _firstRowFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleCardKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      final active = _openPopout;
      _close();
      (active == HomeSidebarType.dms ? _dmsFocusNode : _peopleFocusNode)
          .requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.tab &&
        HardwareKeyboard.instance.isShiftPressed &&
        _firstRowFocusNode.hasPrimaryFocus) {
      (_openPopout == HomeSidebarType.dms ? _dmsFocusNode : _peopleFocusNode)
          .requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _popoutTrigger({
    required HomeSidebarType type,
    required FocusNode focusNode,
    required Widget child,
  }) {
    return Focus(
      canRequestFocus: false,
      onFocusChange: (focused) => focused ? _open(type) : _scheduleClose(),
      onKeyEvent: (node, event) => _handleTriggerKey(type, focusNode, event),
      child: MouseRegion(
        onEnter: (_) => _open(type),
        onExit: (_) => _scheduleClose(),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      key: _railKey,
      width: AppSidebarRail.width,
      decoration: BoxDecoration(
        color: colors.sidebar,
        border: Border(
          right: BorderSide(color: colors.onPrimary.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _RailNavItem(
            icon: Icons.home_filled,
            label: 'Home',
            isActive: widget.activeType == HomeSidebarType.home,
            onTap: () => selectSidebarType(HomeSidebarType.home),
          ),
          _popoutTrigger(
            type: HomeSidebarType.dms,
            focusNode: _dmsFocusNode,
            child: _RailNavItem(
              positionKey: _dmsTargetKey,
              icon: Icons.chat_bubble_outline,
              label: 'DMs',
              isActive: widget.activeType == HomeSidebarType.dms,
              isHighlighted: _openPopout == HomeSidebarType.dms,
              focusNode: _dmsFocusNode,
              onTap: () => selectSidebarType(HomeSidebarType.dms),
            ),
          ),
          _popoutTrigger(
            type: HomeSidebarType.people,
            focusNode: _peopleFocusNode,
            child: _RailNavItem(
              positionKey: _peopleTargetKey,
              icon: Icons.people_outline,
              label: 'People',
              isActive: widget.activeType == HomeSidebarType.people,
              isHighlighted: _openPopout == HomeSidebarType.people,
              focusNode: _peopleFocusNode,
              onTap: () => selectSidebarType(HomeSidebarType.people),
            ),
          ),
          _RailNavItem(
            icon: Icons.folder_open_outlined,
            label: 'Files',
            isActive: widget.activeType == HomeSidebarType.files,
            onTap: () => selectSidebarType(HomeSidebarType.files),
          ),
          _BuzzRailItem(
            isActive: widget.activeType == HomeSidebarType.buzz,
            onTap: () => selectSidebarType(HomeSidebarType.buzz),
          ),
          const Spacer(),
          _RailBottomIcon(
            icon: Icons.notifications_none_outlined,
            hasNotification: true,
            onTap: () {
              // Fire a test notification replicating DM notification
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification will fire in 5 seconds.'),
                  duration: Duration(seconds: 3),
                ),
              );
              Future.delayed(const Duration(seconds: 5), () {
                ref
                    .read(notificationServiceProvider)
                    .handleIncomingMessage(
                      {
                        'user_id': 'system_notification',
                        'content': 'This is a test notification from Zedu.',
                      },
                      'system',
                      'Zedu',
                      forceShow: true,
                    );
              });
            },
          ),
          _RailBottomIcon(
            icon: Icons.settings_outlined,
            selected: widget.settingsSelected,
            onTap: () {
              context.go(AppRouter.profile);
            },
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 16, top: 8),
            child: UserMenuButton(),
          ),
        ],
      ),
    );
  }
}

class _SidebarPopoutLayoutDelegate extends SingleChildLayoutDelegate {
  const _SidebarPopoutLayoutDelegate({required this.left, required this.top});

  final double left;
  final double top;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints(
      maxWidth: (constraints.maxWidth - left - 8).clamp(0.0, 358.0).toDouble(),
      maxHeight: (constraints.maxHeight - 16)
          .clamp(0.0, double.infinity)
          .toDouble(),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxLeft = size.width - childSize.width - 8;
    final maxTop = size.height - childSize.height - 8;
    return Offset(
      maxLeft < left ? left : left.clamp(8.0, maxLeft).toDouble(),
      maxTop < 8 ? 8 : top.clamp(8.0, maxTop).toDouble(),
    );
  }

  @override
  bool shouldRelayout(_SidebarPopoutLayoutDelegate oldDelegate) =>
      left != oldDelegate.left || top != oldDelegate.top;
}

class _BuzzRailItem extends ConsumerWidget {
  const _BuzzRailItem({required this.isActive, required this.onTap});

  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(activeCallProvider).state;
    final tooltip = call.lastCallAt == null
        ? 'Buzz'
        : 'Last Buzz: ${_formatDateTime(call.lastCallAt!)}';

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: _RailNavItem(
        icon: Icons.phone_outlined,
        label: 'Buzz',
        isActive: isActive,
        onTap: onTap,
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour > 12
        ? local.hour - 12
        : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month}/${local.year} $hour:$minute $period';
  }
}

class _RailNavItem extends StatefulWidget {
  const _RailNavItem({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.isHighlighted = false,
    this.focusNode,
    this.positionKey,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final bool isHighlighted;
  final FocusNode? focusNode;
  final GlobalKey? positionKey;
  final VoidCallback? onTap;

  @override
  State<_RailNavItem> createState() => _RailNavItemState();
}

class _RailNavItemState extends State<_RailNavItem> {
  bool _isHovered = false;
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      focusNode: widget.focusNode,
      onTap: widget.onTap,
      onHover: (hovered) {
        if (_isHovered != hovered) setState(() => _isHovered = hovered);
      },
      onFocusChange: (focused) {
        if (_hasFocus != focused) setState(() => _hasFocus = focused);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        child: Column(
          children: [
            Container(
              key: widget.positionKey,
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color:
                    widget.isActive ||
                        widget.isHighlighted ||
                        _isHovered ||
                        _hasFocus
                    ? colors.primary.withValues(alpha: 0.95)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(widget.icon, color: colors.onPrimary, size: 18),
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: TextStyle(
                color: colors.onPrimary.withValues(alpha: 0.92),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailBottomIcon extends StatelessWidget {
  const _RailBottomIcon({
    required this.icon,
    this.hasNotification = false,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final bool hasNotification;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: selected
                    ? colors.primary.withValues(alpha: 0.95)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: colors.onPrimary, size: 18),
            ),
            if (hasNotification)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: colors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
