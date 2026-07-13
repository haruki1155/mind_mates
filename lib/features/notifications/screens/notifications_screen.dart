import 'package:flutter/material.dart';

import '../../../models/app_notification_model.dart';
import '../../../repositories/notification_repository.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({required this.userId, super.key, this.repository});

  final String userId;
  final NotificationRepository? repository;

  @override
  Widget build(BuildContext context) {
    final source = repository ?? NotificationRepository();
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<AppNotificationModel>>(
        stream: source.watchNotifications(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Unable to load notifications.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    item.type == 'appointment'
                        ? Icons.event_note_outlined
                        : Icons.notifications_outlined,
                  ),
                  title: Text(item.title),
                  subtitle: Text(item.body),
                  trailing: item.isRead
                      ? null
                      : const Icon(Icons.circle, size: 10),
                  onTap: () async {
                    if (!item.isRead) await source.markRead(item.id);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
