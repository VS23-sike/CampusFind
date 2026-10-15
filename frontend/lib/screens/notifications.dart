import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../core/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool loading = true;
  List<dynamic> notifications = [];

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    setState(() {
      loading = true;
    });

    try {
      notifications = await ApiService.notifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.errorMessage(e)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await ApiService.markNotificationRead(notificationId);

      setState(() {
        for (final item in notifications) {
          final notification = Map<String, dynamic>.from(item);

          if (notification['notification_id']?.toString() == notificationId) {
            notification['read_status'] = true;
          }
        }
      });

      await loadNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.errorMessage(e)),
          ),
        );
      }
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await ApiService.markAllNotificationsRead();

      await loadNotifications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.errorMessage(e)),
          ),
        );
      }
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await ApiService.deleteNotification(notificationId);

      setState(() {
        notifications.removeWhere(
          (item) => item['notification_id']?.toString() == notificationId,
        );
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.errorMessage(e)),
          ),
        );
      }
    }
  }

  IconData notificationIcon(String type) {
    switch (type) {
      case 'match':
        return Icons.auto_awesome;

      case 'claim':
        return Icons.verified_outlined;

      case 'message':
        return Icons.chat_bubble_outline;

      case 'recovery':
        return Icons.check_circle_outline;

      case 'system':
        return Icons.info_outline;

      default:
        return Icons.notifications_none;
    }
  }

  String notificationTypeLabel(String type) {
    switch (type) {
      case 'match':
        return 'AI Match';

      case 'claim':
        return 'Claim Update';

      case 'message':
        return 'Message';

      case 'recovery':
        return 'Recovery';

      case 'system':
        return 'System';

      default:
        return 'Notification';
    }
  }

  String formatDate(dynamic value) {
    if (value == null) return '';

    try {
      final date = DateTime.parse(value.toString()).toLocal();

      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '${date.day}/${date.month}/${date.year} '
          '$hour:$minute $period';
    } catch (_) {
      return value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = notifications.where((item) {
      return item['read_status'] != true;
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: markAllAsRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadNotifications,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : notifications.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 180),
                      Center(
                        child: Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: AppColors.muted,
                        ),
                      ),
                      SizedBox(height: 16),
                      Center(
                        child: Text(
                          'No notifications yet.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final notification = Map<String, dynamic>.from(
                        notifications[index],
                      );

                      final id =
                          notification['notification_id']?.toString() ?? '';

                      final type = notification['type']?.toString() ?? 'system';

                      final isRead = notification['read_status'] == true;

                      return Card(
                        elevation: isRead ? 0 : 2,
                        color: isRead
                            ? Theme.of(context).cardColor
                            : AppColors.primaryLight.withOpacity(0.35),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(
                              notificationIcon(type),
                              color: AppColors.primary,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notification['title'] ?? 'Notification',
                                  style: TextStyle(
                                    fontWeight: isRead
                                        ? FontWeight.w500
                                        : FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 5),
                              Text(
                                notification['message'] ?? '',
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    notificationTypeLabel(type),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (notification['created_at'] != null)
                                    Text(
                                      formatDate(
                                        notification['created_at'],
                                      ),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          onTap: !isRead && id.isNotEmpty
                              ? () => markAsRead(id)
                              : null,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'read' && id.isNotEmpty) {
                                markAsRead(id);
                              }

                              if (value == 'delete' && id.isNotEmpty) {
                                deleteNotification(id);
                              }
                            },
                            itemBuilder: (_) => [
                              if (!isRead)
                                const PopupMenuItem(
                                  value: 'read',
                                  child: Text('Mark as read'),
                                ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
