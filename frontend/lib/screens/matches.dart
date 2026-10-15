import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesState();
}

class _MatchesState extends State<MatchesScreen> {
  bool loading = true;

  List<dynamic> data = [];
  List<dynamic> userClaims = [];
  List<dynamic> foundItems = [];

  Map<String, dynamic> currentUser = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final results = await Future.wait([
        ApiService.matches(),
        ApiService.claims(),
        ApiService.me(),
        ApiService.found(size: 100),
      ]);

      debugPrint(
        '========== CAMPUSFIND MATCHES ==========',
      );
      debugPrint(
          'MATCH COUNT: ${results[0] is List ? (results[0] as List).length : 'NOT LIST'}');
      debugPrint('CLAIMS: ${results[1]}');
      debugPrint('USER: ${results[2]}');
      debugPrint('FOUND ITEMS: ${results[3]}');
      debugPrint(
        '=========================================',
      );

      if (!mounted) return;

      setState(() {
        data = results[0] is List ? List<dynamic>.from(results[0] as List) : [];

        userClaims =
            results[1] is List ? List<dynamic>.from(results[1] as List) : [];

        currentUser = results[2] is Map
            ? Map<String, dynamic>.from(results[2] as Map)
            : {};

        foundItems =
            results[3] is List ? List<dynamic>.from(results[3] as List) : [];

        loading = false;
      });
    } catch (e) {
      debugPrint(
        'MATCH LOAD ERROR: $e',
      );

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

  // ============================================================
  // ID HELPERS
  // ============================================================

  String? normalizeId(dynamic value) {
    if (value == null) {
      return null;
    }

    final result = value.toString().trim().toLowerCase();

    if (result.isEmpty || result == 'null') {
      return null;
    }

    return result;
  }

  bool sameId(
    dynamic first,
    dynamic second,
  ) {
    final a = normalizeId(first);
    final b = normalizeId(second);

    return a != null && b != null && a == b;
  }

  String? get currentUserId {
    return normalizeId(
      currentUser['id'] ??
          currentUser['user_id'] ??
          currentUser['uuid'] ??
          currentUser['userId'],
    );
  }

  // ============================================================
  // MAP HELPERS
  // ============================================================

  Map<String, dynamic> mapValue(
    dynamic value,
  ) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  // ============================================================
  // ITEM IDs
  // ============================================================

  String? itemId(
    Map<String, dynamic> item,
  ) {
    return normalizeId(
      item['item_id'] ??
          item['id'] ??
          item['lost_item_id'] ??
          item['found_item_id'],
    );
  }

  String? foundId(
    Map<String, dynamic> match,
    Map<String, dynamic> found,
  ) {
    return normalizeId(
      match['found_item_id'] ??
          found['item_id'] ??
          found['found_item_id'] ??
          found['id'],
    );
  }

  String? lostId(
    Map<String, dynamic> match,
    Map<String, dynamic> lost,
  ) {
    return normalizeId(
      match['lost_item_id'] ??
          lost['item_id'] ??
          lost['lost_item_id'] ??
          lost['id'],
    );
  }

  // ============================================================
  // FIND FOUND ITEM FROM API
  // ============================================================

  Map<String, dynamic> foundItemFromList(
    String? exactFoundId,
  ) {
    if (exactFoundId == null) {
      return {};
    }

    for (final raw in foundItems) {
      if (raw is! Map) {
        continue;
      }

      final item = Map<String, dynamic>.from(raw);

      final id = normalizeId(
        item['item_id'] ?? item['id'] ?? item['found_item_id'],
      );

      if (id != null && sameId(id, exactFoundId)) {
        return item;
      }
    }

    return {};
  }

  // ============================================================
  // OWNER / FINDER HELPERS
  // ============================================================

  String? ownerId(
    Map<String, dynamic> item,
  ) {
    final nestedUser = mapValue(
      item['user'],
    );

    return normalizeId(
      item['user_id'] ??
          item['owner_id'] ??
          item['reporter_id'] ??
          item['created_by'] ??
          nestedUser['user_id'] ??
          nestedUser['id'],
    );
  }

  String? lostOwnerId(
    Map<String, dynamic> match,
  ) {
    final lost = mapValue(
      match['lost_item'],
    );

    final nestedUser = mapValue(
      lost['user'],
    );

    return normalizeId(
      match['lost_item_user_id'] ??
          match['lost_owner_id'] ??
          match['owner_id'] ??
          lost['user_id'] ??
          lost['owner_id'] ??
          lost['reporter_id'] ??
          lost['created_by'] ??
          nestedUser['user_id'] ??
          nestedUser['id'],
    );
  }

  String? finderId(
    Map<String, dynamic> found,
  ) {
    final finder = mapValue(
      found['finder'],
    );

    return normalizeId(
      found['finder_id'] ??
          found['user_id'] ??
          found['owner_id'] ??
          found['reporter_id'] ??
          found['created_by'] ??
          finder['user_id'] ??
          finder['id'],
    );
  }

  String finderName(
    Map<String, dynamic> found,
  ) {
    final finder = mapValue(
      found['finder'],
    );

    final name = (found['finder_name'] ??
            found['user_name'] ??
            found['owner_name'] ??
            found['reporter_name'] ??
            finder['full_name'] ??
            finder['name'] ??
            finder['display_name'] ??
            'Finder')
        .toString()
        .trim();

    if (name.isEmpty || name == 'null') {
      return 'Finder';
    }

    return name;
  }

  // ============================================================
  // LOST OWNER
  // ============================================================

  bool isLostOwner(
    Map<String, dynamic> match,
  ) {
    final me = currentUserId;

    if (me == null) {
      return false;
    }

    final owner = lostOwnerId(
      match,
    );

    return owner != null && sameId(owner, me);
  }

  // ============================================================
  // OWN FOUND ITEM
  // ============================================================

  bool isOwnFoundItem(
    Map<String, dynamic> found,
  ) {
    final me = currentUserId;
    final finder = finderId(found);

    if (me == null || finder == null) {
      return false;
    }

    return sameId(
      me,
      finder,
    );
  }

  // ============================================================
  // FIND CLAIM FOR EXACT AI MATCH
  // ============================================================

  Map<String, dynamic>? existingClaimForMatch(
    Map<String, dynamic> match,
  ) {
    final me = currentUserId;

    if (me == null) {
      return null;
    }

    final found = mapValue(
      match['found_item'],
    );

    final exactFoundId = foundId(
      match,
      found,
    );

    if (exactFoundId == null) {
      return null;
    }

    for (final raw in userClaims) {
      if (raw is! Map) {
        continue;
      }

      final claim = Map<String, dynamic>.from(
        raw,
      );

      final claimantId = normalizeId(
        claim['claimant_id'] ??
            claim['user_id'] ??
            claim['owner_id'] ??
            mapValue(
              claim['claimant'],
            )['user_id'] ??
            mapValue(
              claim['claimant'],
            )['id'],
      );

      if (claimantId == null ||
          !sameId(
            claimantId,
            me,
          )) {
        continue;
      }

      final type =
          (claim['item_type'] ?? claim['type'] ?? claim['claim_type'] ?? '')
              .toString()
              .trim()
              .toLowerCase()
              .replaceAll('-', '_')
              .replaceAll(' ', '_');

      if (type != 'found') {
        continue;
      }

      final claimFoundId = normalizeId(
        claim['item_id'] ??
            claim['found_item_id'] ??
            claim['related_item_id'] ??
            mapValue(
              claim['found_item'],
            )['item_id'] ??
            mapValue(
              claim['found_item'],
            )['id'],
      );

      if (claimFoundId == null) {
        continue;
      }

      if (!sameId(
        claimFoundId,
        exactFoundId,
      )) {
        continue;
      }

      return claim;
    }

    return null;
  }

  // ============================================================
  // NORMALIZE STATUS
  // ============================================================

  String? normalizeStatus(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final result = value
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    return result.isEmpty || result == 'null' ? null : result;
  }

  // ============================================================
  // SHARED CLAIM STATUS
  // ============================================================

  String? sharedClaimStatus(
    Map<String, dynamic> match,
  ) {
    return normalizeStatus(
      match['claim_status'],
    );
  }

  // ============================================================
  // CLAIM STATUS
  // ============================================================

  String? claimStatusForMatch(
    Map<String, dynamic> match,
  ) {
    final shared = sharedClaimStatus(
      match,
    );

    if (shared != null) {
      return shared;
    }

    final claim = existingClaimForMatch(
      match,
    );

    if (claim == null) {
      return null;
    }

    return normalizeStatus(
      claim['status'] ?? claim['claim_status'] ?? claim['verification_status'],
    );
  }

  // ============================================================
  // AI MATCH STATUS
  // ============================================================

  String? aiMatchStatus(
    Map<String, dynamic> match,
  ) {
    final raw =
        match['status'] ?? match['match_status'] ?? match['ai_match_status'];

    return normalizeStatus(
      raw,
    );
  }

  // ============================================================
  // CLAIM SECTION
  // ============================================================

  Widget claimSection(
    Map<String, dynamic> found,
    Map<String, dynamic> match,
  ) {
    if (found.isEmpty) {
      return const SizedBox.shrink();
    }

    // ----------------------------------------------------------
    // OWN FOUND ITEM
    // ----------------------------------------------------------
    //
    // The finder cannot claim their own found item.
    //
    // HOWEVER, after the lost user's claim is approved,
    // the finder must be able to message the lost-item owner.
    // ----------------------------------------------------------

    if (isOwnFoundItem(found)) {
      final sharedStatus = sharedClaimStatus(match);

      if (sharedStatus == 'approved') {
        final lost = mapValue(
          match['lost_item'],
        );

        final lostOwner = lostOwnerId(
          match,
        );

        final foundItemId = foundId(
          match,
          found,
        );

        final lostItemId = lostId(
          match,
          lost,
        );

        final lostUser = mapValue(
          lost['user'],
        );

        final lostOwnerName = (lost['user_name'] ??
                lost['owner_name'] ??
                lost['reporter_name'] ??
                lostUser['full_name'] ??
                lostUser['name'] ??
                lostUser['display_name'] ??
                'Lost Item Owner')
            .toString()
            .trim();

        if (lostOwner != null &&
            (foundItemId != null || lostItemId != null) &&
            !sameId(
              lostOwner,
              currentUserId,
            )) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _statusMessage(
                icon: Icons.inventory_2_outlined,
                iconColor: AppColors.primary,
                background: AppColors.primaryLight,
                border: AppColors.primary.withOpacity(.15),
                textColor: AppColors.primary,
                text: 'This is your found item.',
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  context.push(
                    '/chat',
                    extra: {
                      'user_id': lostOwner,
                      'name': lostOwnerName.isEmpty
                          ? 'Lost Item Owner'
                          : lostOwnerName,
                      'item_id': foundItemId ?? lostItemId,
                      'item_type': 'found',
                      'item_title':
                          (found['title'] ?? found['item_name'] ?? 'Found item')
                              .toString(),
                    },
                  );
                },
                icon: const Icon(
                  Icons.chat_bubble_outline,
                ),
                label: const Text(
                  'Message Lost Item Owner',
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(
                    double.infinity,
                    48,
                  ),
                ),
              ),
            ],
          );
        }
      }

      return _statusMessage(
        icon: Icons.inventory_2_outlined,
        iconColor: AppColors.primary,
        background: AppColors.primaryLight,
        border: AppColors.primary.withOpacity(.15),
        textColor: AppColors.primary,
        text: 'This is your found item.',
      );
    }

    // ----------------------------------------------------------
    // ONLY LOST OWNER CAN CLAIM
    // ----------------------------------------------------------

    if (!isLostOwner(match)) {
      return const SizedBox.shrink();
    }

    final claim = existingClaimForMatch(
      match,
    );

    // ----------------------------------------------------------
    // NO CLAIM
    // ----------------------------------------------------------

    if (claim == null) {
      final id = itemId(found);

      if (id == null) {
        return const SizedBox.shrink();
      }

      return OutlinedButton.icon(
        onPressed: () {
          context.push(
            '/claim',
            extra: {
              ...found,
              'item_id': id,
              'item_type': 'found',
            },
          );
        },
        icon: const Icon(
          Icons.verified_user_outlined,
        ),
        label: const Text(
          'Start claim verification',
        ),
      );
    }

    // ----------------------------------------------------------
    // EXISTING CLAIM
    // ----------------------------------------------------------

    final status = claimStatusForMatch(
      match,
    );

    debugPrint(
      'AI MATCH CLAIM STATUS = $status',
    );

    if (status == 'approved') {
      return _approvedSection(
        found,
        match,
      );
    }

    if (status == 'pending') {
      return _statusMessage(
        icon: Icons.hourglass_top_rounded,
        iconColor: const Color(0xFFB77900),
        background: const Color(0xFFFFF7E6),
        border: const Color(0xFFF0D28A),
        textColor: const Color(0xFF9A6500),
        text: 'Claim submitted. Please wait for admin verification.',
      );
    }

    if (status == 'under_review') {
      return _statusMessage(
        icon: Icons.manage_search,
        iconColor: const Color(0xFF246BCE),
        background: const Color(0xFFEFF6FF),
        border: const Color(0xFFBFD9FF),
        textColor: const Color(0xFF246BCE),
        text: 'Claim is under admin review.',
      );
    }

    if (status == 'more_info_required') {
      return _statusMessage(
        icon: Icons.info_outline,
        iconColor: AppColors.primary,
        background: const Color(0xFFF1EDFF),
        border: const Color(0xFFD4CCFF),
        textColor: AppColors.primary,
        text: 'More information is required for this claim.',
      );
    }

    if (status == 'rejected') {
      return _statusMessage(
        icon: Icons.cancel_outlined,
        iconColor: const Color(0xFFC94B4B),
        background: const Color(0xFFFFF0F0),
        border: const Color(0xFFF2C2C2),
        textColor: const Color(0xFFC94B4B),
        text:
            'This claim was rejected. You cannot submit another claim for this item.',
      );
    }

    return _statusMessage(
      icon: Icons.assignment_outlined,
      iconColor: AppColors.primary,
      background: AppColors.primaryLight,
      border: AppColors.primary.withOpacity(.15),
      textColor: AppColors.primary,
      text: 'You have already submitted a claim for this item.',
    );
  }

  // ============================================================
  // APPROVED + MESSAGE FINDER
  // ============================================================

  Widget _approvedSection(
    Map<String, dynamic> found,
    Map<String, dynamic> match,
  ) {
    final exactFoundId = foundId(
      match,
      found,
    );

    Map<String, dynamic> finderSource = found;

    if (exactFoundId != null) {
      final enriched = foundItemFromList(
        exactFoundId,
      );

      if (enriched.isNotEmpty) {
        finderSource = {
          ...found,
          ...enriched,
        };
      }
    }

    final finder = finderId(
      finderSource,
    );

    final name = finderName(
      finderSource,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statusMessage(
          icon: Icons.verified_outlined,
          iconColor: const Color(0xFF239B56),
          background: const Color(0xFFEAF8F0),
          border: const Color(0xFFB9E6CB),
          textColor: const Color(0xFF239B56),
          text:
              'Claim approved. You can now continue with the recovery process.',
        ),
        const SizedBox(height: 10),
        if (finder != null &&
            exactFoundId != null &&
            !sameId(
              finder,
              currentUserId,
            ))
          ElevatedButton.icon(
            onPressed: () {
              context.push(
                '/chat',
                extra: {
                  'user_id': finder,
                  'name': name,
                  'item_id': exactFoundId,
                  'item_type': 'found',
                  'item_title': (finderSource['title'] ??
                          finderSource['item_name'] ??
                          'Found item')
                      .toString(),
                },
              );
            },
            icon: const Icon(
              Icons.chat_bubble_outline,
            ),
            label: const Text(
              'Message Finder',
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(
                double.infinity,
                48,
              ),
            ),
          )
        else
          _statusMessage(
            icon: Icons.info_outline,
            iconColor: AppColors.muted,
            background: Colors.grey.shade100,
            border: Colors.grey.shade300,
            textColor: AppColors.muted,
            text: 'Finder contact information is not available for this match.',
          ),
      ],
    );
  }

  // ============================================================
  // STATUS MESSAGE
  // ============================================================

  Widget _statusMessage({
    required IconData icon,
    required Color iconColor,
    required Color background,
    required Color border,
    required Color textColor,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MATCH STATUS BADGE
  // ============================================================

  Widget matchStatusBadge(
    Map<String, dynamic> match,
  ) {
    final sharedStatus = sharedClaimStatus(
      match,
    );

    if (sharedStatus != null) {
      switch (sharedStatus) {
        case 'pending':
          return _smallBadge(
            'Claim pending',
            Icons.hourglass_top_rounded,
            const Color(0xFF9A6500),
            const Color(0xFFFFF7E6),
          );

        case 'under_review':
          return _smallBadge(
            'Under review',
            Icons.manage_search,
            const Color(0xFF246BCE),
            const Color(0xFFEFF6FF),
          );

        case 'approved':
          return _smallBadge(
            'Claim approved',
            Icons.verified_rounded,
            const Color(0xFF239B56),
            const Color(0xFFEAF8F0),
          );

        case 'rejected':
          return _smallBadge(
            'Claim rejected',
            Icons.cancel_outlined,
            const Color(0xFFC94B4B),
            const Color(0xFFFFF0F0),
          );

        case 'more_info_required':
          return _smallBadge(
            'More information',
            Icons.info_outline,
            AppColors.primary,
            const Color(0xFFF1EDFF),
          );
      }
    }

    final claim = existingClaimForMatch(
      match,
    );

    final claimStatus = claimStatusForMatch(
      match,
    );

    if (claim != null && claimStatus != null) {
      switch (claimStatus) {
        case 'pending':
          return _smallBadge(
            'Claim pending',
            Icons.hourglass_top_rounded,
            const Color(0xFF9A6500),
            const Color(0xFFFFF7E6),
          );

        case 'under_review':
          return _smallBadge(
            'Under review',
            Icons.manage_search,
            const Color(0xFF246BCE),
            const Color(0xFFEFF6FF),
          );

        case 'approved':
          return _smallBadge(
            'Claim approved',
            Icons.verified_rounded,
            const Color(0xFF239B56),
            const Color(0xFFEAF8F0),
          );

        case 'rejected':
          return _smallBadge(
            'Claim rejected',
            Icons.cancel_outlined,
            const Color(0xFFC94B4B),
            const Color(0xFFFFF0F0),
          );

        case 'more_info_required':
          return _smallBadge(
            'More information',
            Icons.info_outline,
            AppColors.primary,
            const Color(0xFFF1EDFF),
          );
      }
    }

    final aiStatus = aiMatchStatus(
      match,
    );

    if (aiStatus != null) {
      return _smallBadge(
        'AI ${formatStatus(aiStatus)}',
        Icons.auto_awesome,
        AppColors.primary,
        AppColors.primaryLight,
      );
    }

    return const SizedBox.shrink();
  }

  // ============================================================
  // SMALL BADGE
  // ============================================================

  Widget _smallBadge(
    String text,
    IconData icon,
    Color foreground,
    Color background,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
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
            size: 14,
            color: foreground,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FORMAT STATUS
  // ============================================================

  String formatStatus(
    String value,
  ) {
    final text = value.replaceAll('_', ' ').trim();

    if (text.isEmpty) {
      return 'Status';
    }

    return text[0].toUpperCase() + text.substring(1);
  }

  // ============================================================
  // MATCH SCORE
  // ============================================================

  int matchScore(
    Map<String, dynamic> match,
  ) {
    final value = match['score_percent'] ??
        match['similarity_percent'] ??
        ((match['similarity_score'] ?? 0) * 100);

    if (value is num) {
      return value.round();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  // ============================================================
  // MATCHING FEATURES
  // ============================================================

  List<dynamic> matchingFeatures(
    Map<String, dynamic> match,
  ) {
    final value = match['matching_features'];

    if (value is List) {
      return value;
    }

    return [];
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI Matches',
        ),
        actions: [
          IconButton(
            onPressed: loading ? null : load,
            tooltip: 'Refresh matches',
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : data.isEmpty
              ? RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 220),
                      Padding(
                        padding: EdgeInsets.all(30),
                        child: Text(
                          'No matches yet. Report an item and the AI matching engine will compare it with active campus reports.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'AI suggestions combine category, color, brand, location and date signals. A match is not proof of ownership.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...data.map(
                        (raw) {
                          if (raw is! Map) {
                            return const SizedBox.shrink();
                          }

                          final match = Map<String, dynamic>.from(
                            raw,
                          );

                          final found = mapValue(
                            match['found_item'],
                          );

                          final lost = mapValue(
                            match['lost_item'],
                          );

                          final item = found.isNotEmpty ? found : lost;

                          final isFound = found.isNotEmpty;

                          final score = matchScore(match);

                          final features = matchingFeatures(match);

                          return Card(
                            margin: const EdgeInsets.only(
                              bottom: 14,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(15),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.auto_awesome,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 10,
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$score% match',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 2,
                                            ),
                                            Text(
                                              score >= 80
                                                  ? 'Strong similarity'
                                                  : 'Possible similarity',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      matchStatusBadge(
                                        match,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: 12,
                                  ),
                                  if (item.isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        final id = itemId(item);

                                        if (id == null) {
                                          return;
                                        }

                                        context.push(
                                          '/item-details?found=${isFound ? 'true' : 'false'}',
                                          extra: item,
                                        );
                                      },
                                      child: ItemCard(
                                        item: item,
                                        found: isFound,
                                      ),
                                    ),
                                  const SizedBox(
                                    height: 8,
                                  ),
                                  if (features.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 4,
                                        bottom: 8,
                                      ),
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: features
                                            .map(
                                              (
                                                feature,
                                              ) =>
                                                  Chip(
                                                label: Text(
                                                  feature.toString(),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  if (isFound)
                                    claimSection(
                                      found,
                                      match,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: BottomNav(
        index: 3,
        onTap: (index) {
          if (index == 0) {
            context.go('/');
          }

          if (index == 1) {
            context.go('/search');
          }

          if (index == 2) {
            context.go('/report');
          }

          if (index == 4) {
            context.go('/profile');
          }
        },
      ),
    );
  }
}
