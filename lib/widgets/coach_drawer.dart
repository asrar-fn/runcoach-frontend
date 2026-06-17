import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CoachDrawer extends StatelessWidget {
  final ValueChanged<String> onTabSelected;
  final String currentTab;
  final int pendingMessagesCount; // To display message count

  const CoachDrawer({
    super.key,
    required this.onTabSelected,
    this.currentTab = 'dashboard',
    this.pendingMessagesCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    // Define navigation items
    final List<Map<String, dynamic>> navigationItems = [
      {'id': 'dashboard', 'label': 'Dashboard', 'icon': Icons.home},
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
            // Drawer Header (RunCoach Logo and Title)
            DrawerHeader(
              decoration: BoxDecoration(
                color: colorScheme.primary, // Using primary color for consistency
                gradient: LinearGradient( // Mimic gradient from React
                  colors: [colorScheme.primary, colorScheme.primaryContainer],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.onPrimary,
                    radius: 20,
                    child: Text(
                      'RC',
                      style: GoogleFonts.poppins(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'PeakForm',
                    style: GoogleFonts.poppins(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Search Input (Optional, can be integrated into main content if preferred)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search, color: colorScheme.onSurface.withOpacity(0.6)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: colorScheme.background,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                ),
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.zero, // Remove default ListView padding
                itemCount: navigationItems.length,
                itemBuilder: (context, index) {
                  final item = navigationItems[index];
                  final bool isActive = currentTab == item['id'];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Material(
                      color: isActive ? colorScheme.primary.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () {
                          onTabSelected(item['id']);
                          Navigator.of(context).pop(); // Close drawer on item tap
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                          child: Row(
                            children: [
                              Icon(item['icon'] as IconData,
                                  color: isActive ? colorScheme.primary : colorScheme.onSurface.withOpacity(0.7)),
                              const SizedBox(width: 16),
                              Text(
                                item['label'] as String,
                                style: textTheme.titleMedium?.copyWith(
                                  color: isActive ? colorScheme.primary : colorScheme.onSurface,
                                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              if (item['badge'] != null && item['badge'] > 0) ...[
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.error,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    item['badge'].toString(),
                                    style: textTheme.labelSmall?.copyWith(color: colorScheme.onError, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Divider
            Divider(height: 1, color: colorScheme.onSurface.withOpacity(0.1)),

            // Logout and Profile
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.person_outline, color: colorScheme.onSurface.withOpacity(0.7)),
                    title: Text('Profile', style: textTheme.titleMedium),
                    onTap: () {
                      Navigator.of(context).pop(); // Close drawer
                      // TODO: Navigate to Profile screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Navigate to Profile')),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.logout, color: colorScheme.error),
                    title: Text('Logout', style: textTheme.titleMedium?.copyWith(color: colorScheme.error)),
                    onTap: () {
                      Navigator.of(context).pop(); // Close drawer
                      // TODO: Implement logout functionality
                      Navigator.of(context).pushReplacementNamed('/'); // Go back to sign-in or home
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}