import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<dynamic> conversations = [];
  String? currentUserId;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadConversations();
  }

  // ===========================================================================
  // LOAD CONVERSATIONS
  // ===========================================================================

  Future<void> loadConversations() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final me = await ApiService.me();

      final id = me['user_id'] ?? me['id'] ?? me['uuid'] ?? me['userId'];

      currentUserId = id?.toString();

      final result = await ApiService.conversations();

      if (!mounted) return;

      final cleaned = <dynamic>[];

      if (result is List) {
        for (final item in result) {
          if (item is Map) {
            cleaned.add(
              Map<String, dynamic>.from(item),
            );
          }
        }
      }

      setState(() {
        conversations = cleaned;
        loading = false;
      });
    } catch (e) {
      debugPrint('MESSAGES LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        loading = false;
        conversations = [];
      });

      showError(
        context,
        ApiService.errorMessage(e),
      );
    }
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  String? normalizeId(dynamic value) {
    if (value == null) return null;

    final result = value.toString().trim();

    if (result.isEmpty || result == 'null') {
      return null;
    }

    return result.toLowerCase();
  }

  String formatTime(dynamic value) {
    if (value == null) return '';

    try {
      final date = DateTime.parse(
        value.toString(),
      ).toLocal();

      final now = DateTime.now();

      final sameDay = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;

      if (sameDay) {
        final hour = date.hour > 12
            ? date.hour - 12
            : date.hour == 0
                ? 12
                : date.hour;

        final minute = date.minute.toString().padLeft(2, '0');

        final period = date.hour >= 12 ? 'PM' : 'AM';

        return '$hour:$minute $period';
      }

      if (date.year == now.year) {
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];

        return '${months[date.month - 1]} ${date.day}';
      }

      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }

  String initials(String name) {
    final trimmed = name.trim();

    if (trimmed.isEmpty) return '?';

    final parts =
        trimmed.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}'
            '${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  // ===========================================================================
  // BACKEND CONVERSATION FORMAT
  //
  // Backend returns:
  //
  // {
  //   "user_id": "...",
  //   "name": "...",
  //   "profile_photo": "...",
  //   "item_id": "...",
  //   "item_type": "found",
  //   "last_message": "Hello",
  //   "last_message_at": "...",
  //   "unread_count": 1
  // }
  // ===========================================================================

  String? _getOtherUserId(
    Map<String, dynamic> conversation,
  ) {
    return normalizeId(
      conversation['user_id'] ??
          conversation['other_user_id'] ??
          conversation['participant_id'],
    );
  }

  String _getName(
    Map<String, dynamic> conversation,
  ) {
    final value = conversation['name'] ??
        conversation['full_name'] ??
        conversation['other_user_name'];

    final name = value?.toString().trim();

    if (name == null || name.isEmpty) {
      return 'CampusFind User';
    }

    return name;
  }

  String _getMessage(
    Map<String, dynamic> conversation,
  ) {
    final value =
        conversation['last_message'] ?? conversation['last_message_text'];

    final message = value?.toString().trim();

    if (message == null || message.isEmpty) {
      return 'No messages yet';
    }

    return message;
  }

  String _getTime(
    Map<String, dynamic> conversation,
  ) {
    return formatTime(
      conversation['last_message_at'],
    );
  }

  int _getUnreadCount(
    Map<String, dynamic> conversation,
  ) {
    final value = conversation['unread_count'] ?? conversation['unread'] ?? 0;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  String? _getItemId(
    Map<String, dynamic> conversation,
  ) {
    return normalizeId(
      conversation['item_id'] ?? conversation['related_item_id'],
    );
  }

  String? _getItemType(
    Map<String, dynamic> conversation,
  ) {
    final value =
        conversation['item_type'] ?? conversation['related_item_type'];

    if (value == null) return null;

    final result = value.toString().trim();

    return result.isEmpty ? null : result;
  }

  // ===========================================================================
  // OPEN CHAT
  // ===========================================================================

  Future<void> openChat(
    Map<String, dynamic> conversation,
  ) async {
    final otherUserId = _getOtherUserId(
      conversation,
    );

    if (otherUserId == null || otherUserId.isEmpty) {
      if (!mounted) return;

      showError(
        context,
        'Unable to identify this conversation.',
      );

      return;
    }

    final name = _getName(
      conversation,
    );

    final itemId = _getItemId(
      conversation,
    );

    final itemType = _getItemType(
      conversation,
    );

    await context.push(
      '/chat',
      extra: {
        'user_id': otherUserId,
        'name': name,
        if (itemId != null) 'item_id': itemId,
        if (itemType != null) 'item_type': itemType,
      },
    );

    if (!mounted) return;

    await loadConversations();
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          'Messages',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading ? null : loadConversations,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : conversations.isEmpty
              ? RefreshIndicator(
                  onRefresh: loadConversations,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 150),
                      _emptyState(),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadConversations,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      18,
                      18,
                      28,
                    ),
                    children: [
                      _introCard(),
                      const SizedBox(height: 18),
                      ...conversations.map(
                        (conversation) {
                          if (conversation is! Map) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: 10,
                            ),
                            child: _conversationCard(
                              Map<String, dynamic>.from(
                                conversation,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
    );
  }

  // ===========================================================================
  // INTRO CARD
  // ===========================================================================

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFEAF8F2),
            Color(0xFFEAF3FB),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.85),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.forum_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your conversations',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Stay connected with students about lost and found items.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // CONVERSATION CARD
  // ===========================================================================

  Widget _conversationCard(
    Map<String, dynamic> conversation,
  ) {
    final unread = _getUnreadCount(
      conversation,
    );

    final name = _getName(
      conversation,
    );

    final message = _getMessage(
      conversation,
    );

    final time = _getTime(
      conversation,
    );

    final itemId = _getItemId(
      conversation,
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => openChat(
          conversation,
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: unread > 0
                  ? AppColors.primary.withOpacity(.20)
                  : const Color(0xFFE9EEEE),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: unread > 0 ? 10 : 5,
                offset: const Offset(0, 2),
                color: Colors.black.withOpacity(.035),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 27,
                    backgroundColor: AppColors.primaryLight,
                    child: Text(
                      initials(name),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (unread > 0)
                    Positioned(
                      right: -1,
                      top: -2,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: unread > 0
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (time.isNotEmpty)
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 10,
                              color: unread > 0
                                  ? AppColors.primary
                                  : AppColors.muted,
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color:
                                  unread > 0 ? Colors.black87 : AppColors.muted,
                              fontWeight: unread > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (unread > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            constraints: const BoxConstraints(
                              minWidth: 24,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(
                                20,
                              ),
                            ),
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (itemId != null) ...[
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 13,
                            color: AppColors.primary.withOpacity(.75),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Item conversation',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 7),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // EMPTY STATE
  // ===========================================================================

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.forum_outlined,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'No conversations yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'When you message another student about a lost or found item, your conversation will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              context.go('/search');
            },
            icon: const Icon(
              Icons.search_rounded,
            ),
            label: const Text(
              'Find an item',
            ),
          ),
        ],
      ),
    );
  }
}
