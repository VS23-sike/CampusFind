import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../core/theme.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const ChatScreen({
    super.key,
    required this.data,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  List<dynamic> messages = [];

  bool loading = true;
  bool sending = false;

  // ============================================================
  // ACTUAL LOGGED-IN USER ID
  // ============================================================

  String? _currentUserId;

  String? userId;
  String userName = 'Finder';

  String? itemId;
  String itemType = 'found';

  @override
  void initState() {
    super.initState();

    _readData();
    loadMessages();
  }

  // ============================================================
  // READ CHAT DATA
  // ============================================================

  void _readData() {
    final data = widget.data;

    userId = _normalizeId(
      data['user_id'] ??
          data['receiver_id'] ??
          data['finder_id'] ??
          data['other_user_id'],
    );

    final rawName = data['name'] ??
        data['full_name'] ??
        data['finder_name'] ??
        data['user_name'];

    if (rawName != null && rawName.toString().trim().isNotEmpty) {
      userName = rawName.toString().trim();
    }

    itemId = _normalizeId(
      data['item_id'] ?? data['found_item_id'] ?? data['related_item_id'],
    );

    final rawType =
        data['item_type'] ?? data['type'] ?? data['related_item_type'];

    if (rawType != null) {
      final normalized = rawType
          .toString()
          .trim()
          .toLowerCase()
          .replaceAll('-', '_')
          .replaceAll(' ', '_');

      if (normalized == 'lost') {
        itemType = 'lost';
      } else {
        itemType = 'found';
      }
    }

    debugPrint(
      '========== CAMPUSFIND CHAT ==========',
    );
    debugPrint('Receiver/User ID: $userId');
    debugPrint('User Name: $userName');
    debugPrint('Item ID: $itemId');
    debugPrint('Item Type: $itemType');
    debugPrint(
      '=====================================',
    );
  }

  // ============================================================
  // NORMALIZE ID
  // ============================================================

  String? _normalizeId(dynamic value) {
    if (value == null) {
      return null;
    }

    final result = value.toString().trim();

    if (result.isEmpty || result == 'null') {
      return null;
    }

    return result;
  }

  // ============================================================
  // LOAD CURRENT USER
  // ============================================================

  Future<void> _loadCurrentUser() async {
    try {
      final profile = await ApiService.me();

      if (profile is Map) {
        final resolvedId = _normalizeId(
          profile['user_id'] ?? profile['id'] ?? profile['uid'],
        );

        if (resolvedId != null) {
          _currentUserId = resolvedId;

          debugPrint(
            'CURRENT LOGGED-IN USER ID: $_currentUserId',
          );
        }
      }
    } catch (e) {
      debugPrint(
        'CURRENT USER LOAD ERROR: $e',
      );
    }
  }

  // ============================================================
  // LOAD MESSAGES
  // ============================================================

  Future<void> loadMessages() async {
    final receiverId = userId;

    if (receiverId == null) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      return;
    }

    try {
      // Get the actual logged-in user before displaying messages.
      await _loadCurrentUser();

      final result = await ApiService.conversationMessages(
        receiverId,
        itemId: itemId,
      );

      if (!mounted) return;

      setState(() {
        messages = result;
        loading = false;
      });

      try {
        await ApiService.markConversationRead(
          receiverId,
          itemId: itemId,
        );
      } catch (e) {
        debugPrint(
          'MARK READ ERROR: $e',
        );
      }

      _scrollToBottom();
    } catch (e) {
      debugPrint(
        'CHAT LOAD ERROR: $e',
      );

      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.errorMessage(e),
          ),
        ),
      );
    }
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || sending) {
      return;
    }

    final receiverId = userId;

    if (receiverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to identify the other user.',
          ),
        ),
      );

      return;
    }

    setState(() {
      sending = true;
    });

    try {
      debugPrint(
        '========== SEND MESSAGE ==========',
      );
      debugPrint(
        'Receiver: $receiverId',
      );
      debugPrint(
        'Item ID: $itemId',
      );
      debugPrint(
        'Item Type: $itemType',
      );
      debugPrint(
        'Message: $text',
      );
      debugPrint(
        '==================================',
      );

      await ApiService.sendMessage(
        receiverId: receiverId,
        message: text,
        itemId: itemId,
        itemType: itemType,
      );

      _messageController.clear();

      await loadMessages();
    } catch (e) {
      debugPrint(
        'SEND MESSAGE ERROR: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.errorMessage(e),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          sending = false;
        });
      }
    }
  }

  // ============================================================
  // DELETE MESSAGE
  // ============================================================

  Future<void> _deleteMessage(
    Map<String, dynamic> message,
  ) async {
    final messageId = _normalizeId(
      message['message_id'] ?? message['id'],
    );

    if (messageId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to identify this message.',
          ),
        ),
      );

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete message?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Are you sure you want to delete this message?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ApiService.deleteMessage(messageId);

      if (!mounted) return;

      setState(() {
        messages.removeWhere(
          (raw) {
            if (raw is! Map) {
              return false;
            }

            final rawId = _normalizeId(
              raw['message_id'] ?? raw['id'],
            );

            return rawId == messageId;
          },
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Message deleted.',
          ),
          duration: Duration(
            seconds: 2,
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'DELETE MESSAGE ERROR: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.errorMessage(e),
          ),
        ),
      );
    }
  }

  // ============================================================
  // MESSAGE LONG-PRESS MENU
  // ============================================================

  Future<void> _showMessageOptions(
    Map<String, dynamic> message,
  ) async {
    // Only OUR messages can be deleted.
    if (!_isMine(message)) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListTile(
            leading: const Icon(
              Icons.delete_outline,
              color: Colors.red,
            ),
            title: const Text(
              'Delete message',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.of(sheetContext).pop();

              _deleteMessage(message);
            },
          ),
        );
      },
    );
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!_scrollController.hasClients) {
          return;
        }

        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(
            milliseconds: 250,
          ),
          curve: Curves.easeOut,
        );
      },
    );
  }

  // ============================================================
  // MESSAGE HELPERS
  // ============================================================

  bool _isMine(
    Map<String, dynamic> message,
  ) {
    final senderId = _normalizeId(
      message['sender_id'] ??
          message['sender_user_id'] ??
          message['from_user_id'] ??
          message['sender']?['user_id'] ??
          message['sender']?['id'] ??
          message['user']?['user_id'] ??
          message['user']?['id'],
    );

    // PRIMARY CHECK:
    // Actual sender ID == actual logged-in user ID.
    if (senderId != null && _currentUserId != null) {
      final mine = senderId == _currentUserId;

      debugPrint(
        'MESSAGE ALIGNMENT | sender=$senderId | me=$_currentUserId | mine=$mine',
      );

      return mine;
    }

    // Fallbacks for APIs that explicitly provide ownership.
    final myIdFromMessage = _normalizeId(
      message['current_user_id'],
    );

    if (myIdFromMessage != null && senderId != null) {
      return senderId == myIdFromMessage;
    }

    final explicitMine = message['is_mine'];

    if (explicitMine is bool) {
      return explicitMine;
    }

    final sentByMe = message['sender_is_me'];

    if (sentByMe is bool) {
      return sentByMe;
    }

    return false;
  }

  String _messageText(
    Map<String, dynamic> message,
  ) {
    return (message['content'] ??
            message['message'] ??
            message['message_text'] ??
            message['text'] ??
            '')
        .toString();
  }

  // ============================================================
  // MESSAGE DATE
  //
  // Backend timestamps are treated as UTC.
  // The displayed time is explicitly converted to IST.
  // ============================================================

  DateTime? _messageDate(
    Map<String, dynamic> message,
  ) {
    final raw = message['created_at'] ??
        message['sent_at'] ??
        message['timestamp'] ??
        message['createdAt'];

    if (raw == null) {
      return null;
    }

    final value = raw.toString().trim();

    if (value.isEmpty) {
      return null;
    }

    try {
      DateTime parsed = DateTime.parse(value);

      final hasExplicitTimezone = value.endsWith('Z') ||
          RegExp(
            r'[+-]\d{2}:\d{2}$',
          ).hasMatch(value);

      if (hasExplicitTimezone) {
        parsed = parsed.toUtc();
      } else {
        parsed = DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
          parsed.microsecond,
        );
      }

      return parsed.add(
        const Duration(
          hours: 5,
          minutes: 30,
        ),
      );
    } catch (e) {
      debugPrint(
        'MESSAGE DATE PARSE ERROR: $e | raw=$value',
      );

      return null;
    }
  }

  // ============================================================
  // DATE + TIME FORMAT
  // ============================================================

  String _formatDateTime(
    DateTime? dateTime,
  ) {
    if (dateTime == null) {
      return '';
    }

    final day = dateTime.day.toString().padLeft(2, '0');

    final month = dateTime.month.toString().padLeft(2, '0');

    final year = dateTime.year.toString();

    var hour = dateTime.hour;

    final minute = dateTime.minute.toString().padLeft(2, '0');

    final period = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;

    if (hour == 0) {
      hour = 12;
    }

    return '$day/$month/$year • $hour:$minute $period';
  }

  // ============================================================
  // MESSAGE BUBBLE
  // ============================================================

  Widget _messageBubble(
    Map<String, dynamic> message,
  ) {
    final mine = _isMine(message);

    final text = _messageText(message);

    final dateTime = _messageDate(message);

    final formattedDateTime = _formatDateTime(dateTime);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: mine ? () => _showMessageOptions(message) : null,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * .78,
          ),
          margin: EdgeInsets.only(
            left: mine ? 55 : 8,
            right: mine ? 8 : 55,
            bottom: 10,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: mine ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(17),
              topRight: const Radius.circular(17),
              bottomLeft: Radius.circular(
                mine ? 17 : 4,
              ),
              bottomRight: Radius.circular(
                mine ? 4 : 17,
              ),
            ),
            border: mine
                ? null
                : Border.all(
                    color: AppColors.border,
                  ),
            boxShadow: [
              BoxShadow(
                blurRadius: 8,
                offset: const Offset(0, 2),
                color: Colors.black.withOpacity(.04),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: mine ? Colors.white : Colors.black87,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
              if (formattedDateTime.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  formattedDateTime,
                  style: TextStyle(
                    color:
                        mine ? Colors.white.withOpacity(.72) : AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY CHAT
  // ============================================================

  Widget _emptyChat() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Start a conversation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Send a message to $userName to coordinate the item recovery.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/messages');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: AppColors.primaryLight,
              child: const Icon(
                Icons.person_outline,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : messages.isEmpty
                    ? _emptyChat()
                    : RefreshIndicator(
                        onRefresh: loadMessages,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(
                            12,
                            18,
                            12,
                            18,
                          ),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final raw = messages[index];

                            if (raw is! Map) {
                              return const SizedBox.shrink();
                            }

                            return _messageBubble(
                              Map<String, dynamic>.from(raw),
                            );
                          },
                        ),
                      ),
          ),

          // ======================================================
          // MESSAGE INPUT
          // ======================================================

          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                12,
                9,
                12,
                10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: AppColors.border,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 11,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(
                            color: AppColors.border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(
                            color: AppColors.primary.withOpacity(.45),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: sending ? null : sendMessage,
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: Center(
                          child: sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 21,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
