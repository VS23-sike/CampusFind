import 'package:flutter/material.dart';

import '../core/theme.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final TextEditingController _searchController = TextEditingController();

  String searchQuery = '';

  final List<Map<String, dynamic>> faqs = [
    {
      'category': 'Getting Started',
      'icon': Icons.play_circle_outline,
      'question': 'What is CampusFind?',
      'answer':
          'CampusFind is an AI-powered college lost and found system that helps students and staff report, search for, and recover lost belongings within campus.',
    },
    {
      'category': 'Getting Started',
      'icon': Icons.add_circle_outline,
      'question': 'How do I report a lost item?',
      'answer':
          'Open the Report section from the bottom navigation, select Lost Item, enter the item details, add photos if available, provide the location and submit the report.',
    },
    {
      'category': 'Getting Started',
      'icon': Icons.inventory_2_outlined,
      'question': 'How do I report a found item?',
      'answer':
          'Open the Report section, select Found Item, provide the item description, location and other relevant information, add photos if available, and submit the report.',
    },
    {
      'category': 'Reports',
      'icon': Icons.edit_note_outlined,
      'question': 'Can I edit my report?',
      'answer':
          'Report editing depends on the current status and available options. Open your report from your activity section to check the available actions.',
    },
    {
      'category': 'Reports',
      'icon': Icons.search_outlined,
      'question': 'How can I find my reported items?',
      'answer':
          'You can view your submitted reports through your Profile under My Reports. You can also use Search and Advanced Search to find relevant campus items.',
    },
    {
      'category': 'AI Matching',
      'icon': Icons.auto_awesome_outlined,
      'question': 'How does AI matching work?',
      'answer':
          'CampusFind compares information from lost and found reports, including item descriptions, categories and other available attributes, to identify potential matches.',
    },
    {
      'category': 'AI Matching',
      'icon': Icons.notifications_outlined,
      'question': 'How will I know when a match is found?',
      'answer':
          'When CampusFind identifies a potential match, you can receive a notification. Open the AI Matches section to review potential matches for your reports.',
    },
    {
      'category': 'Claims',
      'icon': Icons.verified_user_outlined,
      'question': 'How do I claim a found item?',
      'answer':
          'Open the relevant found item and use the available claim option. Provide the requested information so the claim can be reviewed.',
    },
    {
      'category': 'Claims',
      'icon': Icons.fact_check_outlined,
      'question': 'What happens after I submit a claim?',
      'answer':
          'Your claim is recorded and can be reviewed through the CampusFind claim management process. You can view claim updates from your Profile.',
    },
    {
      'category': 'Claims',
      'icon': Icons.pending_actions_outlined,
      'question': 'Why is my claim still pending?',
      'answer':
          'A claim may remain pending while the required information is being reviewed. Check your claim status for the latest update.',
    },
    {
      'category': 'Messaging',
      'icon': Icons.chat_bubble_outline,
      'question': 'How does messaging work?',
      'answer':
          'CampusFind provides in-app messaging so users can communicate regarding relevant lost and found items without relying on external messaging platforms.',
    },
    {
      'category': 'Notifications',
      'icon': Icons.notifications_active_outlined,
      'question': 'What notifications can I receive?',
      'answer':
          'Notifications can include potential AI matches, claim updates, messages and other important CampusFind activity.',
    },
    {
      'category': 'Maps & Location',
      'icon': Icons.location_on_outlined,
      'question': 'Why does CampusFind use my location?',
      'answer':
          'Location information can help identify where an item was lost or found and support location-based search and campus map features.',
    },
    {
      'category': 'Maps & Location',
      'icon': Icons.map_outlined,
      'question': 'Can I select a location manually?',
      'answer':
          'Yes. CampusFind provides location selection features when reporting items so that you can specify the relevant campus location.',
    },
    {
      'category': 'Account',
      'icon': Icons.person_outline,
      'question': 'How do I update my profile?',
      'answer':
          'Open Profile and select Edit Profile. You can update information such as your name, phone number, student or staff ID, department and year.',
    },
    {
      'category': 'Account',
      'icon': Icons.lock_outline,
      'question': 'How do I change my password?',
      'answer':
          'Open Profile → Settings → Change Password. You will be asked to verify your current password before setting a new one.',
    },
    {
      'category': 'Account',
      'icon': Icons.security_outlined,
      'question': 'How can I keep my account secure?',
      'answer':
          'Use a strong password, do not share your login credentials and log out when using CampusFind on a shared device.',
    },
    {
      'category': 'General',
      'icon': Icons.help_outline,
      'question': 'Who can use CampusFind?',
      'answer':
          'CampusFind is designed for members of the college campus community, including students and staff, according to the access rules configured by the institution.',
    },
    {
      'category': 'General',
      'icon': Icons.report_problem_outlined,
      'question': 'What should I do if I find a valuable item?',
      'answer':
          'Report the item through CampusFind as soon as possible and provide an accurate location and description. Avoid sharing sensitive identifying details publicly.',
    },
    {
      'category': 'General',
      'icon': Icons.support_agent_outlined,
      'question': 'What if I have a problem with the app?',
      'answer':
          'Check the relevant FAQ first. If the problem continues, contact your college administrator or the support contact provided by your institution.',
    },
  ];

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get filteredFaqs {
    if (searchQuery.isEmpty) {
      return faqs;
    }

    return faqs.where((faq) {
      final question = faq['question'].toString().toLowerCase();

      final answer = faq['answer'].toString().toLowerCase();

      final category = faq['category'].toString().toLowerCase();

      return question.contains(searchQuery) ||
          answer.contains(searchQuery) ||
          category.contains(searchQuery);
    }).toList();
  }

  void showContactSupport() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Contact Support'),
          content: const Text(
            'For account, moderation or technical issues, please contact your college administrator or the designated CampusFind support team.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget categoryHeader(String category) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
        top: 14,
        bottom: 8,
      ),
      child: Text(
        category,
        style: AppText.heading,
      ),
    );
  }

  Widget faqTile(Map<String, dynamic> faq) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 2,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16,
        ),
        leading: Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            faq['icon'] as IconData,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          faq['question'].toString(),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              faq['answer'].toString(),
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = filteredFaqs;

    final grouped = <String, List<Map<String, dynamic>>>{};

    for (final faq in results) {
      final category = faq['category'].toString();

      grouped.putIfAbsent(
        category,
        () => [],
      );

      grouped[category]!.add(faq);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & FAQ'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          18,
          10,
          18,
          35,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.support_agent_outlined,
                  color: AppColors.primary,
                  size: 38,
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How can we help?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Find answers to common CampusFind questions.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search help topics...',
              prefixIcon: const Icon(
                Icons.search,
              ),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                      },
                      icon: const Icon(
                        Icons.clear,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          if (results.isEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_outlined,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No matching help topics found.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Try searching with a different keyword.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ...grouped.entries.map(
              (entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    categoryHeader(entry.key),
                    ...entry.value.map(faqTile),
                  ],
                );
              },
            ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.support_agent,
                  color: AppColors.primary,
                  size: 32,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Still need help?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Contact your college administrator or CampusFind support team.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: showContactSupport,
                  icon: const Icon(
                    Icons.mail_outline,
                  ),
                  label: const Text(
                    'Contact Support',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          const Center(
            child: Text(
              'CampusFind',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 5),
          const Center(
            child: Text(
              'Lost something? Find it on campus.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
