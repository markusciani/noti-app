import 'package:flutter/material.dart';

import '../models/announcement.dart';

class AnnouncementDetailScreen extends StatelessWidget {
  const AnnouncementDetailScreen({super.key, required this.announcement});

  final Announcement announcement;

  String _formatDate(DateTime date) {
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
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day}, ${date.year} • $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 150,
            backgroundColor: colors.surface,
            foregroundColor: colors.onSurface,
            title: const Text('Announcement'),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: colors.surface,
                padding: const EdgeInsets.fromLTRB(20, 72, 20, 20),
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (announcement.pinned)
                      Chip(
                        label: const Text('Pinned'),
                        backgroundColor: colors.primaryContainer,
                        labelStyle: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(
                          color: colors.primary.withValues(alpha: 0.08),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      announcement.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w800,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  _formatDate(announcement.createdAt),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  announcement.message,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: colors.primaryContainer,
                          backgroundImage:
                              announcement.authorPhotoUrl.isNotEmpty
                              ? NetworkImage(announcement.authorPhotoUrl)
                              : null,
                          child: Text(
                            announcement.authorPhotoUrl.isNotEmpty
                                ? ''
                                : announcement.author.trim().isNotEmpty
                                ? announcement.author.trim()[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Posted by',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                announcement.author.isEmpty
                                    ? 'Church leadership'
                                    : announcement.author,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
