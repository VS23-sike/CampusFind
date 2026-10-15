import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../widgets/common.dart';

class ClaimScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const ClaimScreen({
    super.key,
    required this.data,
  });

  @override
  State<ClaimScreen> createState() => _ClaimState();
}

class _ClaimState extends State<ClaimScreen> {
  final proofController = TextEditingController();
  final answerController = TextEditingController();

  bool loading = false;

  String get itemTitle {
    return (widget.data['title'] ?? 'this item').toString();
  }

  String get itemType {
    return (widget.data['item_type'] ?? '').toString().toLowerCase().trim();
  }

  dynamic get itemId {
    return widget.data['item_id'];
  }

  bool get isFoundItem {
    return itemType == 'found';
  }

  bool get hasItemId {
    return itemId != null && itemId.toString().trim().isNotEmpty;
  }

  Future<void> submitClaim() async {
    // ------------------------------------------------------------
    // SAFETY CHECK 1:
    // ONLY FOUND ITEMS CAN BE CLAIMED.
    // ------------------------------------------------------------
    if (!isFoundItem) {
      showError(
        context,
        Exception(
          'Only found items can be claimed. A lost report cannot be claimed.',
        ),
      );
      return;
    }

    // ------------------------------------------------------------
    // SAFETY CHECK 2:
    // THE FOUND ITEM MUST HAVE A REAL ID.
    // ------------------------------------------------------------
    if (!hasItemId) {
      showError(
        context,
        Exception(
          'This item cannot be claimed because its item ID is missing.',
        ),
      );
      return;
    }

    final proof = proofController.text.trim();
    final answer = answerController.text.trim();

    if (proof.isEmpty) {
      showError(
        context,
        Exception(
          'Please describe why you believe this found item belongs to you.',
        ),
      );
      return;
    }

    if (answer.isEmpty) {
      showError(
        context,
        Exception(
          'Please provide at least one private verification detail.',
        ),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await ApiService.claim({
        'item_id': itemId,
        'item_type': 'found',
        'proof_description': proof,
        'verification_answers': {
          'ownership_answer': answer,
        },
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Claim submitted successfully. It is now pending admin verification.',
          ),
        ),
      );

      context.go('/profile');
    } catch (e) {
      if (!mounted) return;

      showError(
        context,
        ApiService.errorMessage(e),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    proofController.dispose();
    answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ------------------------------------------------------------
    // IF THIS SCREEN WAS OPENED FOR A LOST ITEM, DO NOT SHOW
    // THE CLAIM FORM AT ALL.
    // ------------------------------------------------------------
    if (!isFoundItem) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Claim item'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.block_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 18),
                const Text(
                  'This item cannot be claimed',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Only found items can be claimed. '
                  'A lost report belongs to the person who reported it '
                  'and should not have a claim option.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  text: 'Go back',
                  onPressed: () {
                    context.pop();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Claim found item'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withValues(
                            alpha: 0.12,
                          ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Claiming found item',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        itemTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You are claiming an item that someone else reported as found. '
                    'Your claim will be reviewed before the finder is allowed '
                    'to connect with you.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Private verification',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'These details are used by the CampusFind admin to verify '
            'that the found item belongs to you. They are not shown '
            'publicly to the finder.',
            style: TextStyle(
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: proofController,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Why is this item yours?',
              hintText: 'Describe private details that help prove ownership.',
              prefixIcon: Icon(Icons.description_outlined),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: answerController,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              labelText: 'Private verification detail',
              hintText: 'Example: a unique mark, sticker, serial detail, '
                  'case design, or another identifying detail.',
              prefixIcon: Icon(Icons.lock_outline),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your claim will initially be marked Pending. '
                    'An admin must verify your information before '
                    'the claim is approved. Messaging between you '
                    'and the finder becomes available only after approval.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            text: 'Submit claim',
            loading: loading,
            onPressed: submitClaim,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: loading
                ? null
                : () {
                    context.pop();
                  },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
