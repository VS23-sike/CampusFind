import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';

class ItemDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool found;

  const ItemDetailsScreen({
    super.key,
    required this.item,
    this.found = false,
  });

  @override
  State<ItemDetailsScreen> createState() => _ItemDetailsScreenState();
}

class _ItemDetailsScreenState extends State<ItemDetailsScreen> {
  bool loadingClaims = true;
  bool checkingOwner = true;

  List<dynamic> claims = [];

  /// True when this report belongs to the current logged-in user.
  bool isOwnItem = false;

  /// ID of the person who reported/found this item.
  String? itemOwnerId;

  /// Current logged-in user ID.
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _loadClaimsAndOwner();
  }

  // ==========================================================================
  // LOAD CLAIMS + REPORTS + CURRENT USER
  // ==========================================================================

  Future<void> _loadClaimsAndOwner() async {
    try {
      final results = await Future.wait([
        ApiService.claims(),
        ApiService.myReports(),
        ApiService.me(),
      ]);

      if (!mounted) return;

      final claimsResult = results[0];
      final reportsResult = results[1];
      final meResult = results[2];

      final loadedClaims =
          claimsResult is List ? List<dynamic>.from(claimsResult) : <dynamic>[];

      final reports = reportsResult is List
          ? List<dynamic>.from(reportsResult)
          : <dynamic>[];

      final me = meResult is Map
          ? Map<String, dynamic>.from(meResult)
          : <String, dynamic>{};

      final myUserId = _normalizeId(
        _extractUserId(me),
      );

      String? ownerId = _normalizeId(
        _extractOwnerId(widget.item),
      );

      bool owner = false;

      // ----------------------------------------------------------------------
      // 1. DIRECT OWNER CHECK
      // ----------------------------------------------------------------------

      if (ownerId != null && myUserId != null) {
        owner = _sameId(ownerId, myUserId);
      }

      // ----------------------------------------------------------------------
      // 2. CHECK NESTED OWNER INFORMATION
      // ----------------------------------------------------------------------

      if (!owner && myUserId != null) {
        owner = _containsCurrentUserAsOwner(
          widget.item,
          myUserId,
        );

        if (owner) {
          ownerId ??= myUserId;
        }
      }

      // ----------------------------------------------------------------------
      // 3. FALLBACK: CHECK MY REPORTS
      //
      // If the public item endpoint does not return owner information,
      // an item appearing in /users/me/reports belongs to the current user.
      // ----------------------------------------------------------------------

      if (!owner) {
        final currentItemId = _normalizeId(_itemId());

        if (currentItemId != null) {
          for (final rawReport in reports) {
            if (rawReport is! Map) continue;

            final report = Map<String, dynamic>.from(rawReport);

            if (_mapContainsItemId(
              report,
              currentItemId,
            )) {
              owner = true;
              ownerId ??= myUserId;
              break;
            }
          }
        }
      }

      // ----------------------------------------------------------------------
      // 4. FINAL STATE
      // ----------------------------------------------------------------------

      setState(() {
        claims = loadedClaims;
        currentUserId = myUserId;
        itemOwnerId = ownerId;
        isOwnItem = owner;
        loadingClaims = false;
        checkingOwner = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loadingClaims = false;
        checkingOwner = false;
      });
    }
  }

  // ==========================================================================
  // ID HELPERS
  // ==========================================================================

  String? _normalizeId(dynamic value) {
    if (value == null) return null;

    final result = value.toString().trim().toLowerCase();

    if (result.isEmpty) return null;

    return result;
  }

  bool _sameId(
    dynamic a,
    dynamic b,
  ) {
    final first = _normalizeId(a);
    final second = _normalizeId(b);

    if (first == null || second == null) return false;

    return first == second;
  }

  // ==========================================================================
  // CURRENT USER ID
  // ==========================================================================

  String? _extractUserId(
    Map<String, dynamic> data,
  ) {
    final value = data['user_id'] ?? data['id'] ?? data['userId'];

    return _normalizeId(value);
  }

  // ==========================================================================
  // OWNER ID
  // ==========================================================================

  String? _extractOwnerId(
    Map<String, dynamic> data,
  ) {
    final possibleValues = [
      data['user_id'],
      data['reported_by'],
      data['reporter_id'],
      data['owner_id'],
      data['created_by'],
      data['created_by_user_id'],
      data['finder_id'],
      data['reported_by_user_id'],
      data['userId'],
    ];

    for (final value in possibleValues) {
      final id = _extractIdFromValue(value);

      if (id != null) {
        return id;
      }
    }

    // Nested owner/finder/reporter objects.
    final nestedKeys = [
      'owner',
      'user',
      'reporter',
      'reported_by',
      'finder',
      'created_by',
    ];

    for (final key in nestedKeys) {
      final nested = data[key];

      if (nested is Map) {
        final id = _extractOwnerId(
          Map<String, dynamic>.from(nested),
        );

        if (id != null) {
          return id;
        }
      }
    }

    return null;
  }

  String? _extractIdFromValue(
    dynamic value,
  ) {
    if (value == null) return null;

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);

      final nestedValue = map['user_id'] ??
          map['id'] ??
          map['userId'] ??
          map['finder_id'] ??
          map['owner_id'] ??
          map['reporter_id'];

      return _normalizeId(nestedValue);
    }

    return _normalizeId(value);
  }

  // ==========================================================================
  // CHECK WHETHER CURRENT USER IS OWNER
  // ==========================================================================

  bool _containsCurrentUserAsOwner(
    Map<String, dynamic> data,
    String myUserId,
  ) {
    final ownerId = _extractOwnerId(data);

    if (ownerId != null && _sameId(ownerId, myUserId)) {
      return true;
    }

    final nestedKeys = [
      'item',
      'found_item',
      'lost_item',
    ];

    for (final key in nestedKeys) {
      final nested = data[key];

      if (nested is Map) {
        if (_containsCurrentUserAsOwner(
          Map<String, dynamic>.from(nested),
          myUserId,
        )) {
          return true;
        }
      }
    }

    return false;
  }

  // ==========================================================================
  // ITEM ID
  // ==========================================================================

  String? _extractItemIdFromMap(
    Map<String, dynamic> data,
  ) {
    final directValues = [
      data['item_id'],
      data['found_item_id'],
      data['lost_item_id'],
      data['id'],
    ];

    for (final value in directValues) {
      final id = _normalizeId(value);

      if (id != null) {
        return id;
      }
    }

    final nestedKeys = [
      'item',
      'found_item',
      'lost_item',
    ];

    for (final key in nestedKeys) {
      final nested = data[key];

      if (nested is Map) {
        final id = _extractItemIdFromMap(
          Map<String, dynamic>.from(nested),
        );

        if (id != null) {
          return id;
        }
      }
    }

    return null;
  }

  String? _itemId() {
    return _extractItemIdFromMap(widget.item);
  }

  // ==========================================================================
  // CHECK REPORT MAP FOR CURRENT ITEM
  // ==========================================================================

  bool _mapContainsItemId(
    Map<String, dynamic> data,
    String currentItemId,
  ) {
    final reportId = _extractItemIdFromMap(data);

    if (reportId != null &&
        _sameId(
          reportId,
          currentItemId,
        )) {
      return true;
    }

    final nestedKeys = [
      'item',
      'found_item',
      'lost_item',
    ];

    for (final key in nestedKeys) {
      final nested = data[key];

      if (nested is Map) {
        if (_mapContainsItemId(
          Map<String, dynamic>.from(nested),
          currentItemId,
        )) {
          return true;
        }
      }
    }

    return false;
  }

  // ==========================================================================
  // CLAIM ITEM ID
  // ==========================================================================

  String? _claimItemId(
    Map<String, dynamic> claim,
  ) {
    final directValues = [
      claim['item_id'],
      claim['found_item_id'],
      claim['lost_item_id'],
    ];

    for (final value in directValues) {
      final id = _normalizeId(value);

      if (id != null) {
        return id;
      }
    }

    final nestedKeys = [
      'found_item',
      'lost_item',
      'item',
    ];

    for (final key in nestedKeys) {
      final nested = claim[key];

      if (nested is Map) {
        final id = _extractItemIdFromMap(
          Map<String, dynamic>.from(nested),
        );

        if (id != null) {
          return id;
        }
      }
    }

    return null;
  }

  // ==========================================================================
  // FIND EXISTING CLAIM
  //
  // IMPORTANT:
  //
  // The existence of a claim is more important than its status.
  //
  // If ANY claim exists for this item:
  //
  //     NEVER SHOW "CLAIM THIS ITEM"
  //
  // This includes:
  //
  // pending
  // under_review
  // more_info_required
  // rejected
  // approved
  // unknown status
  // ==========================================================================

  Map<String, dynamic>? _existingClaim() {
    final id = _normalizeId(_itemId());

    if (id == null) {
      return null;
    }

    for (final rawClaim in claims) {
      if (rawClaim is! Map) continue;

      final claim = Map<String, dynamic>.from(rawClaim);

      final claimItemId = _normalizeId(
        _claimItemId(claim),
      );

      if (claimItemId != null &&
          _sameId(
            claimItemId,
            id,
          )) {
        return claim;
      }
    }

    return null;
  }

  // ==========================================================================
  // CLAIM STATUS
  // ==========================================================================

  String? _existingClaimStatus() {
    final claim = _existingClaim();

    if (claim == null) {
      return null;
    }

    final status = claim['status'];

    if (status == null) {
      return null;
    }

    return status.toString().toLowerCase().trim();
  }

  // ==========================================================================
  // FOUND / LOST
  // ==========================================================================

  bool _isFoundItem() {
    if (widget.found) {
      return true;
    }

    final type = widget.item['item_type'] ??
        widget.item['type'] ??
        widget.item['report_type'] ??
        widget.item['item_status_type'];

    if (type != null) {
      final value = type.toString().toLowerCase().trim();

      if (value == 'found' || value == 'found_item' || value == 'found item') {
        return true;
      }

      if (value == 'lost' || value == 'lost_item' || value == 'lost item') {
        return false;
      }
    }

    final isFound = widget.item['is_found'];

    if (isFound is bool) {
      return isFound;
    }

    return false;
  }

  // ==========================================================================
  // MESSAGE BUTTON
  // ==========================================================================

  Widget _messageButton() {
    final ownerId = itemOwnerId;
    final myId = currentUserId;

    if (ownerId == null || myId == null) {
      return const SizedBox.shrink();
    }

    if (_sameId(
      ownerId,
      myId,
    )) {
      return const SizedBox.shrink();
    }

    final ownerName = (widget.item['owner_name'] ??
            widget.item['reporter_name'] ??
            widget.item['reported_by_name'] ??
            widget.item['finder_name'] ??
            'CampusFind User')
        .toString();

    return OutlinedButton.icon(
      onPressed: () {
        context.push(
          '/chat',
          extra: {
            'user_id': ownerId,
            'name': ownerName,
            'item_id': _itemId(),
          },
        );
      },
      icon: const Icon(
        Icons.chat_bubble_outline,
      ),
      label: const Text(
        'Message Reporter',
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(
          double.infinity,
          50,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  // ==========================================================================
  // CLAIM SECTION
  // ==========================================================================

  Widget _claimSection() {
    final isFound = _isFoundItem();

    // ------------------------------------------------------------------------
    // LOST ITEM
    //
    // Lost items can never be claimed.
    // ------------------------------------------------------------------------

    if (!isFound) {
      return const SizedBox.shrink();
    }

    // ------------------------------------------------------------------------
    // OWNER CHECK
    // ------------------------------------------------------------------------

    if (checkingOwner) {
      return const SizedBox(
        height: 52,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // ------------------------------------------------------------------------
    // OWN FOUND ITEM
    //
    // NEVER SHOW CLAIM BUTTON.
    // ------------------------------------------------------------------------

    if (isOwnItem) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withOpacity(.15),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              color: AppColors.primary,
              size: 23,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'This is your found-item report. Other users can claim this item.',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ------------------------------------------------------------------------
    // CLAIMS LOADING
    // ------------------------------------------------------------------------

    if (loadingClaims) {
      return const SizedBox(
        height: 52,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // ------------------------------------------------------------------------
    // EXISTING CLAIM
    //
    // THIS IS THE IMPORTANT PART.
    //
    // If a claim exists, there is NO CLAIM BUTTON.
    // ------------------------------------------------------------------------

    final existingClaim = _existingClaim();

    if (existingClaim != null) {
      final status = _existingClaimStatus();

      // APPROVED
      if (status == 'approved') {
        return _claimMessage(
          icon: Icons.verified_outlined,
          iconColor: const Color(0xFF239B56),
          background: const Color(0xFFEAF8F0),
          border: const Color(0xFFB9E6CB),
          textColor: const Color(0xFF239B56),
          text:
              'Claim approved. You can continue with the recovery process and communicate with the finder.',
        );
      }

      // PENDING / UNDER REVIEW
      if (status == 'pending' ||
          status == 'under_review' ||
          status == 'under review') {
        return _claimMessage(
          icon: Icons.hourglass_top_rounded,
          iconColor: const Color(0xFFB77900),
          background: const Color(0xFFFFF7E6),
          border: const Color(0xFFF0D28A),
          textColor: const Color(0xFF9A6500),
          text: 'Claim under review. Please wait for admin verification.',
        );
      }

      // MORE INFORMATION
      if (status == 'more_info_required' || status == 'more info required') {
        return _claimMessage(
          icon: Icons.info_outline,
          iconColor: AppColors.primary,
          background: AppColors.primaryLight,
          border: AppColors.primary.withOpacity(.20),
          textColor: AppColors.primary,
          text:
              'More information is required for this claim. Please follow the instructions provided by the administrator.',
        );
      }

      // REJECTED
      if (status == 'rejected') {
        return _claimMessage(
          icon: Icons.cancel_outlined,
          iconColor: const Color(0xFFC94B4B),
          background: const Color(0xFFFFF0F0),
          border: const Color(0xFFF2C2C2),
          textColor: const Color(0xFFC94B4B),
          text:
              'This claim was rejected. You cannot submit another claim for this item.',
        );
      }

      // UNKNOWN STATUS
      //
      // A claim exists, therefore NEVER show the claim button.
      return _claimMessage(
        icon: Icons.assignment_outlined,
        iconColor: AppColors.primary,
        background: AppColors.primaryLight,
        border: AppColors.primary.withOpacity(.15),
        textColor: AppColors.primary,
        text:
            'You have already submitted a claim for this item. No additional claim can be submitted.',
      );
    }

    // ------------------------------------------------------------------------
    // NO CLAIM EXISTS
    //
    // ONLY NOW DO WE SHOW THE CLAIM BUTTON.
    // ------------------------------------------------------------------------

    return PrimaryButton(
      text: 'Claim This Item',
      onPressed: () {
        context.push(
          '/claim',
          extra: {
            ...widget.item,
            'item_id': _itemId(),
            'item_type': 'found',
          },
        );
      },
    );
  }

  // ==========================================================================
  // CLAIM MESSAGE
  // ==========================================================================

  Widget _claimMessage({
    required IconData icon,
    required Color iconColor,
    required Color background,
    required Color border,
    required Color textColor,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    final title = item['title']?.toString() ?? 'Unnamed item';

    final category = item['category']?.toString() ?? 'Other';

    final color = item['color']?.toString() ?? '';

    final brand = item['brand']?.toString() ?? '';

    final description =
        item['description']?.toString() ?? 'No description provided.';

    final location = item['location_name']?.toString() ??
        item['campus_building']?.toString() ??
        'Campus';

    final campus =
        item['campus_building']?.toString() ?? item['campus']?.toString() ?? '';

    final status = item['status']?.toString() ?? 'active';

    final latitude = _toDouble(
      item['latitude'],
    );

    final longitude = _toDouble(
      item['longitude'],
    );

    final hasCoordinates = latitude != null && longitude != null;

    final isFound = _isFoundItem();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Item Details',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: isFound ? const Color(0xFFE8F8F7) : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isFound ? Icons.inventory_2_outlined : Icons.search,
              size: 70,
              color: isFound ? AppColors.mint : AppColors.primary,
            ),
          ),

          const SizedBox(height: 22),

          Text(
            title,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Chip(
                label: Text(category),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(status),
              ),
            ],
          ),

          const SizedBox(height: 20),

          _DetailRow(
            icon: Icons.palette_outlined,
            label: 'Colour',
            value: color.isEmpty ? 'Not specified' : color,
          ),

          if (brand.isNotEmpty)
            _DetailRow(
              icon: Icons.branding_watermark_outlined,
              label: 'Brand',
              value: brand,
            ),

          _DetailRow(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: location,
          ),

          if (campus.isNotEmpty)
            _DetailRow(
              icon: Icons.school_outlined,
              label: 'Campus / Building',
              value: campus,
            ),

          if (hasCoordinates) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withOpacity(.15),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_searching_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Map Location Available',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${latitude.toStringAsFixed(5)}, '
                          '${longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                context.push(
                  '/campus-map',
                  extra: item,
                );
              },
              icon: const Icon(
                Icons.map_outlined,
              ),
              label: const Text(
                'View on Campus Map',
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(
                  double.infinity,
                  50,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],

          const SizedBox(height: 15),

          const Text(
            'Description',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            description,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.muted,
            ),
          ),

          const SizedBox(height: 28),

          // ------------------------------------------------------------------
          // CLAIM
          // ------------------------------------------------------------------

          _claimSection(),

          // ------------------------------------------------------------------
          // COMMUNICATION
          // ------------------------------------------------------------------

          const SizedBox(height: 12),

          _messageButton(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ==========================================================================
  // DOUBLE HELPER
  // ==========================================================================

  static double? _toDouble(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }
}

// ============================================================================
// DETAIL ROW
// ============================================================================

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
