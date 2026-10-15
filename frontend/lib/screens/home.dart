import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  int nav = 0;

  Map<String, dynamic>? me;

  List<dynamic> reports = [];
  List<dynamic> lostItems = [];
  List<dynamic> foundItems = [];
  List<dynamic> matches = [];
  List<dynamic> userClaims = [];

  bool loading = true;

  // UI-only colours. No application behaviour is changed.
  static const Color _pageBackground = Color(0xFFF4F8FA);
  static const Color _ink = Color(0xFF193C46);
  static const Color _secondaryText = Color(0xFF526A73);
  static const Color _softBorder = Color(0xFFDCE7EA);
  static const Color _teal = Color(0xFF176B73);
  static const Color _blue = Color(0xFF326F9A);
  static const Color _mint = Color(0xFF287D63);
  static const Color _peach = Color(0xFFB65C36);

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
    });

    try {
      final results = await Future.wait([
        ApiService.me(),
        ApiService.myReports(),
        ApiService.lost(size: 10),
        ApiService.found(size: 10),
        ApiService.matches(),
        ApiService.claims(),
      ]);

      if (!mounted) return;

      setState(() {
        me = Map<String, dynamic>.from(results[0] as Map);
        reports = List<dynamic>.from(results[1] as List);
        lostItems = List<dynamic>.from(results[2] as List);
        foundItems = List<dynamic>.from(results[3] as List);
        matches = List<dynamic>.from(results[4] as List);
        userClaims = List<dynamic>.from(results[5] as List);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      showError(
        context,
        ApiService.errorMessage(e),
      );
    }
  }

  void navTo(int i) {
    setState(() {
      nav = i;
    });

    if (i == 1) {
      context.go('/search');
    }

    if (i == 2) {
      context.push('/report');
    }

    if (i == 3) {
      context.go('/matches');
    }

    if (i == 4) {
      context.go('/profile');
    }
  }

  void openReport(
    Map<String, dynamic> item, {
    bool? found,
  }) {
    final isFound =
        found ?? item['report_type']?.toString().toLowerCase() == 'found';

    context.push(
      '/item-details?found=${isFound ? 'true' : 'false'}',
      extra: item,
    );
  }

  void openMatch(Map<String, dynamic> match) {
    final foundItem = match['found_item'];
    final lostItem = match['lost_item'];

    if (foundItem is Map) {
      openReport(
        Map<String, dynamic>.from(foundItem),
        found: true,
      );
      return;
    }

    if (lostItem is Map) {
      openReport(
        Map<String, dynamic>.from(lostItem),
        found: false,
      );
      return;
    }

    context.go('/matches');
  }

  // ========================================================================
  // CLAIM STATUS FOR AN AI MATCH — EXISTING LOGIC PRESERVED
  // ========================================================================

  String? _claimStatusForMatch(
    Map<String, dynamic> match,
  ) {
    final sharedStatus = match['claim_status']?.toString().trim().toLowerCase();

    if (sharedStatus != null && sharedStatus.isNotEmpty) {
      return sharedStatus;
    }

    final foundRaw = match['found_item'];

    final foundItem = foundRaw is Map
        ? Map<String, dynamic>.from(foundRaw)
        : <String, dynamic>{};

    final foundItemId = foundItem['item_id']?.toString() ??
        foundItem['id']?.toString() ??
        match['found_item_id']?.toString();

    if (foundItemId == null || foundItemId.isEmpty) {
      return null;
    }

    for (final rawClaim in userClaims) {
      if (rawClaim is! Map) continue;

      final claim = Map<String, dynamic>.from(rawClaim);
      final claimItemId = claim['item_id']?.toString();

      if (claimItemId == foundItemId) {
        final status = claim['status']?.toString().trim().toLowerCase();

        if (status != null && status.isNotEmpty) {
          return status;
        }
      }

      final nestedItem = claim['item'];

      if (nestedItem is Map) {
        final nestedMap = Map<String, dynamic>.from(nestedItem);
        final nestedId =
            nestedMap['item_id']?.toString() ?? nestedMap['id']?.toString();

        if (nestedId == foundItemId) {
          final status = claim['status']?.toString().trim().toLowerCase();

          if (status != null && status.isNotEmpty) {
            return status;
          }
        }
      }

      final nestedFound = claim['found_item'];

      if (nestedFound is Map) {
        final nestedMap = Map<String, dynamic>.from(nestedFound);
        final nestedId =
            nestedMap['item_id']?.toString() ?? nestedMap['id']?.toString();

        if (nestedId == foundItemId) {
          final status = claim['status']?.toString().trim().toLowerCase();

          if (status != null && status.isNotEmpty) {
            return status;
          }
        }
      }
    }

    return null;
  }

  String _matchDisplayStatus(
    Map<String, dynamic> match,
  ) {
    final claimStatus = _claimStatusForMatch(match);

    if (claimStatus != null) {
      switch (claimStatus) {
        case 'approved':
          return 'Approved';
        case 'rejected':
          return 'Rejected';
        case 'pending':
          return 'Pending';
        case 'under_review':
        case 'under review':
          return 'Under Review';
        case 'more_info_required':
          return 'More Info';
        default:
          return _capitalizeStatus(claimStatus);
      }
    }

    final rawStatus = match['status']?.toString();

    if (rawStatus != null && rawStatus.trim().isNotEmpty) {
      return _capitalizeStatus(rawStatus);
    }

    return 'Possible Match';
  }

  // ========================================================================
  // BUILD
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    final fullName = (me?['full_name'] ?? 'Student').toString().trim();
    final name = fullName.isEmpty ? 'Student' : fullName.split(' ').first;

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: _teal.withOpacity(.08),
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF176B73),
                    Color(0xFF398F91),
                  ],
                ),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: _teal.withOpacity(.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.find_in_page_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Hi, $name 👋',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'CampusFind',
                    style: TextStyle(
                      fontSize: 12,
                      color: _secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Campus Map',
            onPressed: () {
              context.push('/campus-map');
            },
            icon: const Icon(Icons.map_outlined),
          ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {
              context.push('/notifications');
            },
            icon: const Icon(Icons.notifications_none),
          ),
          const SizedBox(width: 4),
        ],
      ),

      // BODY — original content and section order preserved.
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: _teal,
              ),
            )
          : RefreshIndicator(
              color: _teal,
              onRefresh: load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  // WELCOME HEADER
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFE0F1EF),
                          Color(0xFFE6F0F8),
                          Color(0xFFF7FAFC),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFC9E1E1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _teal.withOpacity(.055),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Lost something?',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Find it on campus.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _secondaryText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 40,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _teal,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    context.go('/search');
                                  },
                                  icon: const Icon(
                                    Icons.search,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Search Items',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.white,
                                Color(0xFFE8F5F4),
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.find_in_page_outlined,
                            size: 38,
                            color: _teal,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // SEARCH
                  InkWell(
                    onTap: () {
                      context.go('/search');
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _softBorder),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.search,
                            color: _secondaryText,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Search lost & found items...',
                              style: TextStyle(
                                color: _secondaryText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: _secondaryText,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // CAMPUS MAP
                  InkWell(
                    onTap: () {
                      context.push('/campus-map');
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFE5F2F3),
                            Color(0xFFEAF2F9),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFD0E3E8),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFDCE9EC),
                              ),
                            ),
                            child: const Icon(
                              Icons.map_outlined,
                              color: _teal,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Explore Campus Map',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: _ink,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Find campus locations and item reports nearby.',
                                  style: TextStyle(
                                    color: _secondaryText,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: _secondaryText,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // MY RECENT REPORTS
                  _sectionHeader(
                    'My Recent Reports',
                    reports.isNotEmpty ? 'View all' : null,
                    reports.isNotEmpty
                        ? () {
                            context.go('/profile');
                          }
                        : null,
                  ),

                  const SizedBox(height: 10),

                  if (reports.isEmpty)
                    _emptyCard(
                      icon: Icons.assignment_outlined,
                      text: 'You have not submitted any reports yet.',
                      buttonText: 'Report an Item',
                      onPressed: () {
                        context.push('/report');
                      },
                    ),

                  ...reports.take(5).map((x) {
                    final item = Map<String, dynamic>.from(x);
                    return _reportCard(item);
                  }),

                  const SizedBox(height: 24),

                  // LOST ON CAMPUS
                  _sectionHeader(
                    'Lost on Campus',
                    lostItems.isNotEmpty ? 'View all' : null,
                    lostItems.isNotEmpty
                        ? () {
                            context.go('/search');
                          }
                        : null,
                  ),

                  const SizedBox(height: 10),

                  if (lostItems.isEmpty)
                    _emptyCard(
                      icon: Icons.search_off,
                      text: 'No lost items have been reported yet.',
                      buttonText: 'Search Items',
                      onPressed: () {
                        context.go('/search');
                      },
                    ),

                  ...lostItems.take(5).map((x) {
                    final item = Map<String, dynamic>.from(x);
                    return _publicItemCard(
                      item,
                      isFound: false,
                    );
                  }),

                  const SizedBox(height: 24),

                  // FOUND ON CAMPUS
                  _sectionHeader(
                    'Found on Campus',
                    foundItems.isNotEmpty ? 'View all' : null,
                    foundItems.isNotEmpty
                        ? () {
                            context.go('/search');
                          }
                        : null,
                  ),

                  const SizedBox(height: 10),

                  if (foundItems.isEmpty)
                    _emptyCard(
                      icon: Icons.inventory_2_outlined,
                      text: 'No found items have been reported yet.',
                      buttonText: 'Search Items',
                      onPressed: () {
                        context.go('/search');
                      },
                    ),

                  ...foundItems.take(5).map((x) {
                    final item = Map<String, dynamic>.from(x);
                    return _publicItemCard(
                      item,
                      isFound: true,
                    );
                  }),

                  const SizedBox(height: 24),

                  // SEARCH REMINDER
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFFFF2E9),
                          Color(0xFFFFF8F1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFF0DCCE),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          color: _peach,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Looking for someone else\'s item? Search all campus reports.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: _ink,
                            ),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: _peach,
                          ),
                          onPressed: () {
                            context.go('/search');
                          },
                          child: const Text(
                            'Search',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // AI MATCHES — LAST SECTION ON HOME
                  _sectionHeader(
                    'AI Suggested Matches',
                    matches.isNotEmpty ? 'View all' : null,
                    matches.isNotEmpty
                        ? () {
                            context.go('/matches');
                          }
                        : null,
                  ),

                  const SizedBox(height: 10),

                  if (matches.isEmpty)
                    _emptyCard(
                      icon: Icons.auto_awesome,
                      text:
                          'No AI matches yet. We will show suggestions when a similar report is found.',
                      buttonText: 'View Matches',
                      onPressed: () {
                        context.go('/matches');
                      },
                    ),

                  ...matches.take(3).map((x) {
                    final match = Map<String, dynamic>.from(x);
                    return _matchCard(match);
                  }),

                  const SizedBox(height: 12),
                ],
              ),
            ),

      // EXISTING BOTTOM NAVIGATION — PRESERVED.
      bottomNavigationBar: BottomNav(
        index: nav,
        onTap: navTo,
      ),
    );
  }

  // ========================================================================
  // SECTION HEADER
  // ========================================================================

  Widget _sectionHeader(
    String title,
    String? actionText,
    VoidCallback? onAction,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppText.heading.copyWith(
              color: _ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (actionText != null && onAction != null)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: _teal,
            ),
            onPressed: onAction,
            child: Text(
              actionText,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  // ========================================================================
  // MY REPORT CARD
  // ========================================================================

  Widget _reportCard(
    Map<String, dynamic> item,
  ) {
    final isFound = item['report_type']?.toString().toLowerCase() == 'found';

    return _itemCard(
      item,
      isFound: isFound,
      showOwnerLabel: true,
    );
  }

  // ========================================================================
  // PUBLIC LOST / FOUND CARD
  // ========================================================================

  Widget _publicItemCard(
    Map<String, dynamic> item, {
    required bool isFound,
  }) {
    return _itemCard(
      item,
      isFound: isFound,
      showOwnerLabel: false,
    );
  }

  // ========================================================================
  // COMMON ITEM CARD
  // ========================================================================

  Widget _itemCard(
    Map<String, dynamic> item, {
    required bool isFound,
    required bool showOwnerLabel,
  }) {
    final title = (item['title'] ?? item['name'] ?? 'Untitled item').toString();

    final category = (item['category'] ?? 'Item').toString();
    final location = (item['location_name'] ?? '').toString();

    final status = _statusForItem(
      item,
      isFound: isFound,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _softBorder),
      ),
      child: InkWell(
        onTap: () {
          openReport(
            item,
            found: isFound,
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isFound
                        ? const [
                            Color(0xFFE0F2E9),
                            Color(0xFFEDF7F1),
                          ]
                        : const [
                            Color(0xFFFFEDE3),
                            Color(0xFFFFF5EF),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isFound ? Icons.inventory_2_outlined : Icons.search,
                  color: isFound ? _mint : _peach,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _statusChip(status),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${isFound ? 'Found' : 'Lost'} • $category',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: _secondaryText,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _secondaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (showOwnerLabel) ...[
                      const SizedBox(height: 5),
                      const Text(
                        'Your report',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _teal,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                color: _secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // ITEM STATUS — EXISTING LOGIC PRESERVED
  // ========================================================================

  String _statusForItem(
    Map<String, dynamic> item, {
    required bool isFound,
  }) {
    final rawStatus = item['status']?.toString().trim();

    if (rawStatus != null && rawStatus.isNotEmpty) {
      switch (rawStatus.toLowerCase()) {
        case 'active':
          return isFound ? 'Found' : 'Lost';
        case 'pending':
          return 'Pending';
        case 'claimed':
          return 'Claimed';
        case 'returned':
          return 'Returned';
        case 'recovered':
          return 'Recovered';
        case 'closed':
          return 'Closed';
        case 'resolved':
          return 'Resolved';
        default:
          return _capitalizeStatus(rawStatus);
      }
    }

    return isFound ? 'Found' : 'Lost';
  }

  String _capitalizeStatus(String value) {
    if (value.isEmpty) {
      return value;
    }

    return value
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}'
                  '${word.substring(1)}',
        )
        .join(' ');
  }

  // ========================================================================
  // STATUS CHIP — IMPROVED CONTRAST
  // ========================================================================

  Widget _statusChip(String status) {
    final normalized = status.toLowerCase();

    Color background;
    Color foreground;
    IconData icon;

    switch (normalized) {
      case 'lost':
        background = const Color(0xFFFFE8DC);
        foreground = const Color(0xFF994523);
        icon = Icons.search;
        break;

      case 'found':
        background = const Color(0xFFDDF2E6);
        foreground = const Color(0xFF216747);
        icon = Icons.inventory_2_outlined;
        break;

      case 'pending':
        background = const Color(0xFFFFEBCB);
        foreground = const Color(0xFF87520A);
        icon = Icons.schedule_outlined;
        break;

      case 'approved':
        background = const Color(0xFFDDF3E4);
        foreground = const Color(0xFF17603A);
        icon = Icons.verified_outlined;
        break;

      case 'under review':
      case 'under_review':
        background = const Color(0xFFFFEBCB);
        foreground = const Color(0xFF87520A);
        icon = Icons.manage_search;
        break;

      case 'rejected':
        background = const Color(0xFFFCE5E5);
        foreground = const Color(0xFFA12F36);
        icon = Icons.cancel_outlined;
        break;

      case 'claimed':
        background = const Color(0xFFE0ECFA);
        foreground = const Color(0xFF285C91);
        icon = Icons.verified_user_outlined;
        break;

      case 'returned':
      case 'recovered':
      case 'resolved':
        background = const Color(0xFFDDF2E5);
        foreground = const Color(0xFF216747);
        icon = Icons.check_circle_outline;
        break;

      case 'closed':
        background = const Color(0xFFE9EEF0);
        foreground = const Color(0xFF52636B);
        icon = Icons.lock_outline;
        break;

      default:
        background = const Color(0xFFE1EFF1);
        foreground = _teal;
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: foreground,
          ),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // AI MATCH CARD — MATCH LOGIC PRESERVED
  // ========================================================================

  Widget _matchCard(
    Map<String, dynamic> match,
  ) {
    final score = match['similarity_score'];
    final percentage = score is num ? (score * 100).round() : null;
    final features = match['matching_features'];

    String featureText = 'Similar item detected';

    if (features is List && features.isNotEmpty) {
      featureText = features.first.toString();
    }

    final displayStatus = _matchDisplayStatus(match);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _softBorder),
      ),
      child: InkWell(
        onTap: () {
          openMatch(match);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFE6E8FA),
                      Color(0xFFE5F0FA),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF5557A5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'AI Match',
                            style: TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _statusChip(displayStatus),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      featureText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: _secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              if (percentage != null) ...[
                const SizedBox(width: 8),
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: _teal,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                color: _secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // EMPTY STATE
  // ========================================================================

  Widget _emptyCard({
    required IconData icon,
    required String text,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _softBorder),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFE7F1F3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 28,
              color: _teal,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _secondaryText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: _teal,
            ),
            onPressed: onPressed,
            child: Text(
              buttonText,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
