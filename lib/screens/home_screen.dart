import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/announcement.dart';
import '../models/device_registration.dart';
import '../models/organization.dart';
import 'admin_entry_screen.dart';
import '../services/device_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';
import '../widgets/adaptive_page_body.dart';
import 'announcement_detail_screen.dart';
import '../services/music_directory_service.dart';
import 'music_folder_screen.dart';

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
  bool _showStaffEntry = false;
  bool _directorRole = false;
  bool _secureDirectorTablet = false;
  bool _deviceDisabled = false;
  StreamSubscription? _deviceSubscription;
  StreamSubscription<Map<String, dynamic>>? _notificationOpenSubscription;
  DateTime? _lastTitleTap;
  int _titleTapCount = 0;

  @override
  void initState() {
    super.initState();
    _registerDevice();
    _watchDeviceApproval();
    _notificationOpenSubscription = NotificationService().openedNotifications
        .listen(_handleOpenedNotification);
  }

  Future<void> _registerDevice() async {
    if (_registeredDevice) return;
    _registeredDevice = true;
    try {
      final secureDirectorTablet = await AuthService()
          .hasSecureDeviceCredential();
      final authService = AuthService();
      final currentRole = await authService.currentStaffRole();
      if (secureDirectorTablet && currentRole != StaffRole.director) {
        try {
          await authService.claimDirectorAccess(
            fallbackCode: AuthService.directorFallbackCode,
          );
        } catch (_) {
          // Keep the device usable offline even if role sync is delayed.
        }
      }
      if (mounted) {
        setState(() {
          _secureDirectorTablet = secureDirectorTablet;
        });
      }
      DeviceRegistration? registration;
      if (await _deviceService.needsOnboarding()) {
        registration = DeviceRegistration(
          organizationId: Organization.defaultId,
          organizationName: Organization.defaultName,
          deviceType: secureDirectorTablet ? 'director_tablet' : 'tablet',
          displayName: secureDirectorTablet
              ? 'Maranatha Director Tablet'
              : 'Maranatha Choir Tablet',
        );
      }
      if (registration != null) {
        await _deviceService.registerDevice(registration: registration);
        await _askForMusicAccess();
      }
      if (registration == null && await _deviceService.needsOnboarding()) {
        _registeredDevice = false;
        return;
      }
      await _deviceService.updatePresence();
      await _watchDeviceApproval();
      await _syncNotifications();
      final showStaffEntry = await _deviceService.staffAccessEnabled();
      final directorRole =
          await authService.currentStaffRole() == StaffRole.director;
      if (mounted) {
        setState(() {
          _showStaffEntry = showStaffEntry;
          _directorRole = directorRole;
          _secureDirectorTablet = secureDirectorTablet;
        });
      }
    } catch (_) {
      _registeredDevice = false;
    }
  }

  Future<void> _showVersionDialog() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    final roleLabel = _directorRole || _showStaffEntry || _secureDirectorTablet
        ? 'Director tablet'
        : 'Choir member tablet';
    final roleSubtitle = _directorRole || _showStaffEntry
        ? 'Director tools are enabled on this tablet.'
        : _secureDirectorTablet
        ? 'Director tools are available and protected by the tablet lock screen.'
        : 'Director tools stay hidden on this tablet.';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.notifications_active_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: const Text('Noti'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Version ${info.version} (${info.buildNumber})'),
            const SizedBox(height: 14),
            const Text(
              'Managed by Ciani01 Organization.\nBuilt for Maranatha Church.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _directorRole || _showStaffEntry || _secureDirectorTablet
                    ? Icons.verified_user_rounded
                    : Icons.group_rounded,
              ),
              title: const Text('Detected role'),
              subtitle: Text(roleSubtitle),
              trailing: Text(
                roleLabel,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handleTitleTap() {
    final now = DateTime.now();
    if (_lastTitleTap == null ||
        now.difference(_lastTitleTap!) > const Duration(milliseconds: 850)) {
      _titleTapCount = 0;
    }
    _lastTitleTap = now;
    _titleTapCount++;
    if (_titleTapCount < 3) return;
    _titleTapCount = 0;
    _showVersionDialog();
  }

  Future<void> _askForMusicAccess() async {
    try {
      if (await MusicDirectoryService().hasMusicFolder || !mounted) return;
      final allow = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Allow access to your files?'),
          content: const Text(
            'Noti can use the default Music folder on this device so song notifications can open the matching file for you. Android may ask for storage access. Noti does not upload your files.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Allow'),
            ),
          ],
        ),
      );
      if (allow == true && mounted) {
        await MusicDirectoryService().chooseMusicFolder();
      }
    } on Object catch (_) {
      // File access is optional for members who only read announcements.
    }
  }

  Future<void> _watchDeviceApproval() async {
    final localStaffAccess = await _deviceService.staffAccessEnabled();
    final localDirectorRole =
        await AuthService().currentStaffRole() == StaffRole.director;
    final secureDirectorTablet = await AuthService()
        .hasSecureDeviceCredential();
    if (mounted) {
      setState(() {
        _showStaffEntry = localStaffAccess;
        _directorRole = localDirectorRole;
        _secureDirectorTablet = secureDirectorTablet;
      });
    }
    await _deviceSubscription?.cancel();
    _deviceSubscription = _deviceService.watchCurrentDevice().listen((
      snapshot,
    ) {
      final data = snapshot.data();
      if (mounted) {
        setState(() {
          _deviceDisabled = data?['isDisabled'] == true;
        });
      }
      unawaited(_syncNotifications());
    });
  }

  Future<void> _syncNotifications() async {
    final organizationId = await _deviceService.approvedOrganizationId();
    await NotificationService().syncOrganizationTopic(organizationId);
    final directorEnabled = _directorRole || _secureDirectorTablet;
    await NotificationService().syncDirectorTopic(
      organizationId,
      enabled: directorEnabled,
    );
  }

  void _handleOpenedNotification(Map<String, dynamic> data) {
    if (!mounted) return;
    final type = data['type']?.toString();
    if (type == 'device_review') return;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _deviceSubscription?.cancel();
    _notificationOpenSubscription?.cancel();
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
        title: GestureDetector(
          onTap: _handleTitleTap,
          child: const Text('Noti'),
        ),
        actions: !_deviceDisabled
            ? [
                IconButton(
                  tooltip: 'File access',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MusicFolderScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.folder_shared_rounded),
                ),
                if (_showStaffEntry || _directorRole || _secureDirectorTablet)
                  IconButton(
                    tooltip: 'Director tools',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AdminEntryScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.lock_rounded),
                  ),
              ]
            : const [],
      ),
      body: _deviceDisabled
          ? SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.block_rounded,
                        size: 48,
                        color: colors.primary,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'This device is disabled.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : SafeArea(
              child: AdaptivePageBody(
                child: StreamBuilder<List<Announcement>>(
                  stream: _firestoreService.getAnnouncements(),
                  builder: (context, snapshot) {
                    final announcements =
                        snapshot.data ?? const <Announcement>[];
                    final filteredAnnouncements = announcements.where((
                      announcement,
                    ) {
                      if (_query.isEmpty) return true;
                      final haystack =
                          '${announcement.title} ${announcement.message} ${announcement.author}'
                              .toLowerCase();
                      return haystack.contains(_query.toLowerCase());
                    }).toList();

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
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                12,
                                20,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor:
                                                    colors.primaryContainer,
                                                foregroundColor: colors.primary,
                                                child: const Icon(
                                                  Icons
                                                      .notifications_active_rounded,
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
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
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
                                      prefixIcon: const Icon(
                                        Icons.search_rounded,
                                      ),
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
                                              icon: const Icon(
                                                Icons.clear_rounded,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Announcements',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
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
                                        ?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
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
                                message:
                                    'Check your connection or Firestore setup.',
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
                                actionLabel: _query.isEmpty
                                    ? null
                                    : 'Clear search',
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

                                final announcement =
                                    filteredAnnouncements[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: AnnouncementCard(
                                    announcement: announcement,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              AnnouncementDetailScreen(
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
                    backgroundImage: announcement.authorPhotoUrl.isNotEmpty
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
