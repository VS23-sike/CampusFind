import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../services/api_service.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  List<dynamic> reports = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  // ============================================================
  // LOAD REPORTS
  // ============================================================

  Future<void> loadReports() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final data = await ApiService.myReports();

      if (!mounted) return;

      setState(() {
        reports = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.errorMessage(e),
          ),
        ),
      );
    }
  }

  // ============================================================
  // GET REPORT ID
  // ============================================================

  String getReportId(
    Map<String, dynamic> report,
  ) {
    return (report['item_id'] ??
            report['id'] ??
            report['lost_item_id'] ??
            report['found_item_id'] ??
            '')
        .toString();
  }

  // ============================================================
  // GET REPORT TYPE
  // ============================================================

  String getReportType(
    Map<String, dynamic> report,
  ) {
    final type =
        (report['report_type'] ?? report['type'] ?? report['item_type'] ?? '')
            .toString()
            .toLowerCase();

    if (type.contains('found')) {
      return 'Found';
    }

    if (type.contains('lost')) {
      return 'Lost';
    }

    // Fallback detection for found reports.
    if (report.containsKey('finder_id') || report.containsKey('date_found')) {
      return 'Found';
    }

    return 'Lost';
  }

  // ============================================================
  // GET TITLE
  // ============================================================

  String getTitle(
    Map<String, dynamic> report,
  ) {
    final title = (report['title'] ??
            report['item_name'] ??
            report['name'] ??
            'Untitled report')
        .toString()
        .trim();

    if (title.isEmpty) {
      return 'Untitled report';
    }

    return title;
  }

  // ============================================================
  // GET CATEGORY
  // ============================================================

  String getCategory(
    Map<String, dynamic> report,
  ) {
    final category = (report['category'] ?? 'No category').toString().trim();

    if (category.isEmpty) {
      return 'No category';
    }

    return category;
  }

  // ============================================================
  // GET STATUS
  // ============================================================

  String getStatus(
    Map<String, dynamic> report,
  ) {
    final status = (report['status'] ?? 'active').toString().trim();

    if (status.isEmpty) {
      return 'active';
    }

    return status;
  }

  // ============================================================
  // STATUS LABEL
  // ============================================================

  String formatStatus(
    String status,
  ) {
    final value = status.replaceAll('_', ' ').replaceAll('-', ' ').trim();

    if (value.isEmpty) {
      return 'Active';
    }

    return value
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color statusColor(
    String status,
  ) {
    final value = status.toLowerCase();

    if (value.contains('resolved') ||
        value.contains('returned') ||
        value.contains('completed') ||
        value.contains('approved')) {
      return Colors.green;
    }

    if (value.contains('pending') || value.contains('review')) {
      return Colors.orange;
    }

    if (value.contains('rejected') ||
        value.contains('cancelled') ||
        value.contains('deleted')) {
      return Colors.red;
    }

    return Colors.blue;
  }

  // ============================================================
  // DELETE REPORT
  // ============================================================

  Future<void> deleteReport(
    Map<String, dynamic> report,
  ) async {
    final id = getReportId(report);
    final type = getReportType(report);

    debugPrint('========================================');
    debugPrint('DELETE REPORT: $report');
    debugPrint('DELETE ID: $id');
    debugPrint('DELETE TYPE: $type');
    debugPrint(
      'DELETE ENDPOINT: /${type.toLowerCase()}-items/$id',
    );
    debugPrint('========================================');

    if (id.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to find the report ID.',
          ),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // CONFIRM DELETE
    // ----------------------------------------------------------

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Delete report?',
          ),
          content: Text(
            'Delete this $type report permanently?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    // ----------------------------------------------------------
    // DELETE
    // ----------------------------------------------------------

    try {
      if (type == 'Found') {
        debugPrint(
          'Calling ApiService.deleteFound($id)',
        );

        await ApiService.deleteFound(id);
      } else {
        debugPrint(
          'Calling ApiService.deleteLost($id)',
        );

        await ApiService.deleteLost(id);
      }

      if (!mounted) return;

      setState(() {
        reports.removeWhere(
          (item) {
            final map = Map<String, dynamic>.from(
              item,
            );

            return getReportId(map) == id;
          },
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report deleted successfully.',
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'DELETE ERROR: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.errorMessage(e),
          ),
        ),
      );
    }
  }

  // ============================================================
  // REPORT ICON
  // ============================================================

  IconData reportIcon(
    String type,
  ) {
    if (type == 'Found') {
      return Icons.search_rounded;
    }

    return Icons.help_outline_rounded;
  }

  // ============================================================
  // REPORT CARD
  // ============================================================

  Widget reportCard(
    Map<String, dynamic> report,
  ) {
    final type = getReportType(report);
    final title = getTitle(report);
    final category = getCategory(report);
    final status = getStatus(report);

    final color = type == 'Found' ? Colors.teal : Colors.indigo;

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ----------------------------------------------------
            // ICON
            // ----------------------------------------------------

            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(
                  alpha: 0.10,
                ),
                borderRadius: BorderRadius.circular(
                  15,
                ),
              ),
              child: Icon(
                reportIcon(type),
                color: color,
                size: 26,
              ),
            ),

            const SizedBox(width: 14),

            // ----------------------------------------------------
            // REPORT INFORMATION
            // ----------------------------------------------------

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(
                            alpha: 0.10,
                          ),
                          borderRadius: BorderRadius.circular(
                            20,
                          ),
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Status: ',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        formatStatus(status),
                        style: TextStyle(
                          color: statusColor(status),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ----------------------------------------------------
            // DELETE BUTTON
            // ----------------------------------------------------

            PopupMenuButton<String>(
              tooltip: 'Report options',
              onSelected: (value) {
                if (value == 'delete') {
                  deleteReport(report);
                }
              },
              itemBuilder: (context) {
                return const [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Delete report',
                        ),
                      ],
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget emptyState() {
    return RefreshIndicator(
      onRefresh: loadReports,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 150),
          Icon(
            Icons.description_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Center(
            child: Text(
              'You have no reports yet.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 40,
              ),
              child: Text(
                'Your lost and found reports will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
          'My Reports',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading ? null : loadReports,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : reports.isEmpty
              ? emptyState()
              : RefreshIndicator(
                  onRefresh: loadReports,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      30,
                    ),
                    itemCount: reports.length,
                    itemBuilder: (
                      context,
                      index,
                    ) {
                      final report = Map<String, dynamic>.from(
                        reports[index],
                      );

                      return reportCard(
                        report,
                      );
                    },
                  ),
                ),
    );
  }
}
