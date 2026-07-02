// lib/widgets/coach_drawer.dart

import 'package:flutter/material.dart';
import '../screens/profile_settings_screen.dart';
import '../widgets/app_logo.dart';

class CoachDrawer extends StatelessWidget {
  final ValueChanged<String> onTabSelected;
  final String currentTab;
  final int pendingMessagesCount;
  final VoidCallback onLogout;
  final bool isCurrentUserCoach;           // ← new
  final Map<String, dynamic> coachJson;    // ← new
  final Future<void> Function() onProfileUpdated; // ← new

  const CoachDrawer({
    super.key,
    required this.onTabSelected,
    required this.onLogout,
    required this.onProfileUpdated,        // ← new
    this.currentTab = 'dashboard',
    this.pendingMessagesCount = 0,
    this.isCurrentUserCoach = true,        // ← new
    this.coachJson = const {},             // ← new
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final List<Map<String, dynamic>> navigationItems = [
      {'id': 'dashboard', 'label': 'Dashboard',  'icon': Icons.home},
      {'id': 'profile',   'label': 'Settings',   'icon': Icons.person_outline},
      {'id': 'logout',    'label': 'Logout',     'icon': Icons.logout, 'isDestructive': true},
    ];

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            // In _buildDrawer, replace the logo Container:
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: const AppLogo(
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search,
                      color: colorScheme.onSurface.withOpacity(0.6)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: colorScheme.surface,
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                ),
                style: textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurface),
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: navigationItems.length,
                itemBuilder: (context, index) {
                  final item = navigationItems[index];
                  final bool isActive = currentTab == item['id'];

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 4.0),
                    child: Material(
                      color: isActive
                          ? colorScheme.primary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () async {
                          if (item['id'] == 'profile') {
                            Navigator.of(context).pop();
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProfileSettingsScreen(
                                  isCoach: isCurrentUserCoach,
                                  userJson: coachJson,
                                ),
                              ),
                            );
                            await onProfileUpdated();
                          } else if (item['id'] == 'logout') {
                            Navigator.of(context).pop();
                            onLogout();
                          } else {
                            onTabSelected(item['id']);
                            Navigator.of(context).pop();
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12.0, horizontal: 16.0),
                          child: Row(
                            children: [
                              Icon(item['icon'] as IconData,
                                  color: (item['isDestructive'] == true)
                                      ? colorScheme.error
                                      : isActive
                                      ? colorScheme.primary
                                      : colorScheme.onSurface.withOpacity(0.7)),
                              const SizedBox(width: 16),
                              Text(
                                item['label'] as String,
                                style: textTheme.titleMedium?.copyWith(
                                  color: (item['isDestructive'] == true)
                                      ? colorScheme.error
                                      : isActive
                                      ? colorScheme.primary
                                      : colorScheme.onSurface,
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              if (item['badge'] != null &&
                                  item['badge'] > 0) ...[
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.error,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    item['badge'].toString(),
                                    style: textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onError,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Divider(height: 1, color: colorScheme.onSurface.withOpacity(0.1)),
            //
            // // Only Logout remains at the bottom
            // Padding(
            //   padding: const EdgeInsets.all(16.0),
            //   child: ListTile(
            //     leading: Icon(Icons.logout, color: colorScheme.error),
            //     title: Text('Logout',
            //         style: textTheme.titleMedium
            //             ?.copyWith(color: colorScheme.error)),
            //     onTap: () {
            //       Navigator.of(context).pop();
            //       onLogout();
            //     },
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}