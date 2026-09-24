import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/utils/state_renderers.dart';
import '../../../core/widgets/custom_card.dart';

/// Shared notifications feed.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(FirestoreCollections.notifications)
              .limit(60)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return ErrorRetry(
                message: snap.error.toString(),
                onRetry: () => (context as Element).markNeedsBuild(),
              );
            }
            if (!snap.hasData) {
              return const ShimmerListSkeleton(itemCount: 5);
            }

            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const EmptyState(
                message: 'No notifications',
                subtitle:
                    'Application updates, new assignments and notices show '
                    'up here.',
                icon: Icons.notifications_off_outlined,
              );
            }

            // Newest first — sorted client-side so no index is needed.
            final items = docs.map((d) => {...d.data(), 'id': d.id}).toList()
              ..sort((a, b) {
                final at = (a['createdAt'] as Timestamp?)?.toDate();
                final bt = (b['createdAt'] as Timestamp?)?.toDate();
                if (at == null && bt == null) return 0;
                if (at == null) return 1;
                if (bt == null) return -1;
                return bt.compareTo(at);
              });

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final n = items[index];
                    final created = (n['createdAt'] as Timestamp?)?.toDate();
                    return CustomCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(Icons.notifications,
                                color: AppColors.primary, size: 19),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (n['title'] ?? 'Notification').toString(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  (n['message'] ?? '').toString(),
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                ),
                                if (created != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    '${created.day.toString().padLeft(2, '0')}/'
                                    '${created.month.toString().padLeft(2, '0')}/'
                                    '${created.year}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
