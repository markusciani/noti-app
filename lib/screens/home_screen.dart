import 'package:flutter/material.dart';

import '../models/announcement.dart';
import 'admin_entry_screen.dart';
import '../services/device_service.dart';
import '../services/firestore_service.dart';
import '../widgets/adaptive_page_body.dart';
import 'announcement_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final DeviceService _deviceService = DeviceService();
  final TextEditingController _searchController = TextEditingController();

  String _query = '';
  bool _registeredDevice = false;

  @override
  void initState() {
    super.initState();
    _registerDevice();
  }

  Future<void> _registerDevice() async {
    if (_registeredDevice) return;
    _registeredDevice = true;
    try {
      await _deviceService.registerDevice();
      await _deviceService.updatePresence();
    } catch (_) {
      _registeredDevice = false;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Noti'),
        actions: [
          IconButton(
            tooltip: 'Admin login',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminEntryScreen()),
              );
            },
            icon: const Icon(Icons.lock_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: AdaptivePageBody(
          child: StreamBuilder<List<Announcement>>(
            stream: _firestoreService.getAnnouncements(),
            builder: (context, snapshot) {
              final announcements = snapshot.data ?? const <Announcement>[];
              final filteredAnnouncements = announcements.where((announcement) {
                if (_query.isEmpty) return true;
                final haystack =
                    '${announcement.title} ${announcement.message} ${announcement.author}'
                        .toLowerCase();
                return haystack.contains(_query.toLowerCase());
              }).toList();

              final pinnedCount = announcements.where((a) => a.pinned).length;
              final totalCount = announcements.length;
              final latestAnnouncement = announcements.isNotEmpty
                  ? announcements.first
                  : null;
              final latestTitle =
                  latestAnnouncement?.title ?? 'No announcements yet';
              final latestSubtitle = latestAnnouncement == null
                  ? 'Once leadership posts, the feed updates here automatically.'
                  : latestAnnouncement.message;

              return RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor:
                                              colors.primaryContainer,
                                          foregroundColor: colors.primary,
                                          child: const Icon(
                                            Icons.notifications_active_rounded,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Noti',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleLarge
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                              Text(
                                                'Church announcements',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: colors
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      latestTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      latestSubtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 14),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        _StatChip(
                                          label: 'Total',
                                          value: '$totalCount',
                                        ),
                                        _StatChip(
                                          label: 'Pinned',
                                          value: '$pinnedCount',
                                        ),
                                        _StatChip(
                                          label: 'Visible',
                                          value:
                                              '${filteredAnnouncements.length}',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() => _query = value.trim());
                              },
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search_rounded),
                                hintText: 'Search announcements',
                                filled: true,
                                fillColor: colors.surface,
                                hintStyle: TextStyle(
                                  color: colors.onSurfaceVariant,
                                ),
                                suffixIcon: _query.isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _query = '');
                                        },
                                        icon: const Icon(Icons.clear_rounded),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Announcements',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                if (_query.isNotEmpty)
                                  Text(
                                    'Filtered',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: colors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap any announcement to read the full message.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (snapshot.hasError)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _StatusState(
                          icon: Icons.error_outline_rounded,
                          title: 'Could not load announcements',
                          message: 'Check your connection or Firestore setup.',
                          actionLabel: 'Retry',
                          onAction: _refresh,
                        ),
                      )
                    else if (snapshot.connectionState ==
                            ConnectionState.waiting &&
                        announcements.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _StatusState(
                          icon: Icons.hourglass_empty_rounded,
                          title: 'Loading announcements',
                          message: 'Fetching the latest church updates.',
                        ),
                      )
                    else if (filteredAnnouncements.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _StatusState(
                          icon: Icons.notifications_off_rounded,
                          title: _query.isEmpty
                              ? 'No announcements yet'
                              : 'No results found',
                          message: _query.isEmpty
                              ? 'When leadership posts here, the announcements will appear in this feed.'
                              : 'Try a different keyword or clear the search field.',
                          actionLabel: _query.isEmpty ? null : 'Clear search',
                          onAction: _query.isEmpty
                              ? null
                              : () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                        ),
                      )
                    else
                      SliverList.separated(
                        itemCount: filteredAnnouncements.length + 1,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == filteredAnnouncements.length) {
                            return const SizedBox(height: 24);
                          }

                          final announcement = filteredAnnouncements[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: AnnouncementCard(
                              announcement: announcement,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AnnouncementDetailScreen(
                                      announcement: announcement,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({super.key, required this.announcement, this.onTap});

  final Announcement announcement;
  final VoidCallback? onTap;

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
    final day = date.day.toString().padLeft(2, '0');
    return '${months[date.month - 1]} $day, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (announcement.pinned)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.push_pin_rounded,
                            size: 16,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Pinned',
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Announcement',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    _formatDate(announcement.createdAt),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                announcement.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                announcement.message,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: colors.primaryContainer,
                    child: Text(
                      announcement.author.trim().isNotEmpty
                          ? announcement.author.trim()[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      announcement.author.isEmpty
                          ? 'Church leadership'
                          : announcement.author,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: colors.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Chip(
      label: Text('$label $value'),
      labelStyle: TextStyle(
        color: colors.onSurface,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: colors.surfaceContainerHighest,
      side: BorderSide(color: colors.primary.withValues(alpha: 0.08)),
    );
  }
}

class _StatusState extends StatelessWidget {
  const _StatusState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
