import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../core/theme.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _loading = true;
  bool _usersLoading = false;
  bool _itemsLoading = false;
  bool _claimsLoading = false;

  List<dynamic> _users = [];
  List<dynamic> _items = [];
  List<dynamic> _claims = [];

  String _userSearch = '';
  String _itemSearch = '';
  String _itemStatus = 'all';
  String _claimStatus = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadDashboard();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    await Future.wait([
      _loadUsers(),
      _loadItems(),
      _loadClaims(),
    ]);

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadUsers() async {
    if (mounted) {
      setState(() {
        _usersLoading = true;
      });
    }

    try {
      final response = await ApiService.adminUsers();

      if (mounted) {
        setState(() {
          _users = response;
        });
      }
    } catch (e) {
      _showError(ApiService.errorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _usersLoading = false;
        });
      }
    }
  }

  Future<void> _loadItems() async {
    if (mounted) {
      setState(() {
        _itemsLoading = true;
      });
    }

    try {
      final lostItems = await ApiService.adminLostItems();
      final foundItems = await ApiService.adminFoundItems();

      final combined = <dynamic>[
        ...lostItems,
        ...foundItems,
      ];

      if (mounted) {
        setState(() {
          _items = combined;
        });
      }
    } catch (e) {
      _showError(ApiService.errorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _itemsLoading = false;
        });
      }
    }
  }

  Future<void> _loadClaims() async {
    if (mounted) {
      setState(() {
        _claimsLoading = true;
      });
    }

    try {
      final response = await ApiService.adminClaims();

      if (mounted) {
        setState(() {
          _claims = response;
        });
      }
    } catch (e) {
      _showError(ApiService.errorMessage(e));
    } finally {
      if (mounted) {
        setState(() {
          _claimsLoading = false;
        });
      }
    }
  }

  Future<void> _refreshAll() async {
    await _loadDashboard();
  }

  Future<void> _logout() async {
    try {
      await ApiService.logout();
    } catch (_) {}

    if (!mounted) return;

    context.go('/role');
  }

  Future<void> _changeUserStatus(
    dynamic user,
    String status,
  ) async {
    final id = user['user_id'] ?? user['id'];

    if (id == null) {
      _showError('User ID not found.');
      return;
    }

    try {
      await ApiService.updateAdminUserStatus(
        id.toString(),
        status,
      );

      _showSuccess(
        status == 'active'
            ? 'User activated successfully.'
            : 'User suspended successfully.',
      );

      await _loadUsers();
    } catch (e) {
      _showError(ApiService.errorMessage(e));
    }
  }

  Future<void> _changeUserRole(
    dynamic user,
    String role,
  ) async {
    final id = user['user_id'] ?? user['id'];

    if (id == null) {
      _showError('User ID not found.');
      return;
    }

    try {
      await ApiService.updateAdminUserRole(
        id.toString(),
        role,
      );

      _showSuccess('User role updated successfully.');

      await _loadUsers();
    } catch (e) {
      _showError(ApiService.errorMessage(e));
    }
  }

  Future<void> _deleteUser(dynamic user) async {
    final id = user['user_id'] ?? user['id'];

    if (id == null) {
      _showError('User ID not found.');
      return;
    }

    final name = _userName(user);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete User'),
          content: Text(
            'Are you sure you want to permanently delete $name?\n\n'
            'This will remove the user profile and associated data. '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ApiService.deleteAdminUser(id.toString());

      _showSuccess('User deleted successfully.');

      await _loadUsers();
    } catch (e) {
      _showError(ApiService.errorMessage(e));
    }
  }

  Future<void> _changeItemStatus(
    dynamic item,
    String status,
  ) async {
    final id = item['item_id'] ?? item['id'];

    if (id == null) {
      _showError('Item ID not found.');
      return;
    }

    String itemType = _itemType(item).toLowerCase();

    if (itemType != 'lost' && itemType != 'found') {
      itemType = (item['type'] ?? 'lost').toString().toLowerCase();
    }

    try {
      await ApiService.moderateItem(
        itemId: id.toString(),
        itemType: itemType,
        action: status,
      );

      _showSuccess('Item status updated successfully.');

      await _loadItems();
    } catch (e) {
      _showError(ApiService.errorMessage(e));
    }
  }

  Future<void> _reviewClaim(
    dynamic claim,
    String status,
  ) async {
    final id = claim['claim_id'] ?? claim['id'];

    if (id == null) {
      _showError('Claim ID not found.');
      return;
    }

    try {
      await ApiService.reviewClaim(
        id.toString(),
        status,
      );

      _showSuccess('Claim updated successfully.');

      await _loadClaims();
    } catch (e) {
      _showError(ApiService.errorMessage(e));
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _userName(dynamic user) {
    if (user is Map) {
      return (user['full_name'] ?? user['name'] ?? user['email'] ?? 'User')
          .toString();
    }

    return 'User';
  }

  String _userEmail(dynamic user) {
    if (user is Map) {
      return (user['college_email'] ?? user['email'] ?? 'No email').toString();
    }

    return 'No email';
  }

  String _userRole(dynamic user) {
    if (user is Map) {
      return (user['role'] ?? 'student').toString();
    }

    return 'student';
  }

  String _userStatus(dynamic user) {
    if (user is Map) {
      return (user['account_status'] ?? user['status'] ?? 'active').toString();
    }

    return 'active';
  }

  String _itemTitle(dynamic item) {
    if (item is Map) {
      return (item['title'] ??
              item['item_name'] ??
              item['name'] ??
              'Unnamed item')
          .toString();
    }

    return 'Unnamed item';
  }

  String _itemType(dynamic item) {
    if (item is Map) {
      return (item['item_type'] ?? item['type'] ?? 'Unknown').toString();
    }

    return 'Unknown';
  }

  String _itemStatusValue(dynamic item) {
    if (item is Map) {
      return (item['status'] ?? 'unknown').toString();
    }

    return 'unknown';
  }

  String _claimStatusValue(dynamic claim) {
    if (claim is Map) {
      return (claim['status'] ?? 'pending').toString();
    }

    return 'pending';
  }

  List<dynamic> get _filteredUsers {
    final query = _userSearch.trim().toLowerCase();

    if (query.isEmpty) {
      return _users;
    }

    return _users.where((user) {
      final name = _userName(user).toLowerCase();
      final email = _userEmail(user).toLowerCase();
      final role = _userRole(user).toLowerCase();

      return name.contains(query) ||
          email.contains(query) ||
          role.contains(query);
    }).toList();
  }

  List<dynamic> get _filteredItems {
    final query = _itemSearch.trim().toLowerCase();

    return _items.where((item) {
      final title = _itemTitle(item).toLowerCase();
      final type = _itemType(item).toLowerCase();
      final status = _itemStatusValue(item).toLowerCase();

      final matchesSearch =
          query.isEmpty || title.contains(query) || type.contains(query);

      final matchesStatus =
          _itemStatus == 'all' || status == _itemStatus.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();
  }

  List<dynamic> get _filteredClaims {
    if (_claimStatus == 'all') {
      return _claims;
    }

    return _claims.where((claim) {
      return _claimStatusValue(claim).toLowerCase() ==
          _claimStatus.toLowerCase();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(
              icon: Icon(Icons.dashboard_rounded),
              text: 'Dashboard',
            ),
            Tab(
              icon: Icon(Icons.people_alt_rounded),
              text: 'Users',
            ),
            Tab(
              icon: Icon(Icons.inventory_2_rounded),
              text: 'Items',
            ),
            Tab(
              icon: Icon(Icons.verified_user_rounded),
              text: 'Claims',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDashboard(),
                _buildUsersTab(),
                _buildItemsTab(),
                _buildClaimsTab(),
              ],
            ),
    );
  }

  Widget _buildDashboard() {
    final activeUsers = _users.where((user) {
      return _userStatus(user).toLowerCase() == 'active';
    }).length;

    final suspendedUsers = _users.where((user) {
      return _userStatus(user).toLowerCase() == 'suspended';
    }).length;

    final lostItems = _items.where((item) {
      return _itemType(item).toLowerCase() == 'lost';
    }).length;

    final foundItems = _items.where((item) {
      return _itemType(item).toLowerCase() == 'found';
    }).length;

    final pendingClaims = _claims.where((claim) {
      return _claimStatusValue(claim).toLowerCase() == 'pending';
    }).length;

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Overview',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage CampusFind users, items and claims.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.45,
            children: [
              _statCard(
                'Total Users',
                _users.length.toString(),
                Icons.people_alt_rounded,
              ),
              _statCard(
                'Active Users',
                activeUsers.toString(),
                Icons.person_rounded,
              ),
              _statCard(
                'Suspended',
                suspendedUsers.toString(),
                Icons.person_off_rounded,
              ),
              _statCard(
                'Total Items',
                _items.length.toString(),
                Icons.inventory_2_rounded,
              ),
              _statCard(
                'Lost Items',
                lostItems.toString(),
                Icons.search_rounded,
              ),
              _statCard(
                'Found Items',
                foundItems.toString(),
                Icons.find_in_page_rounded,
              ),
              _statCard(
                'Total Claims',
                _claims.length.toString(),
                Icons.assignment_turned_in_rounded,
              ),
              _statCard(
                'Pending Claims',
                pendingClaims.toString(),
                Icons.pending_actions_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () {
                          _tabController.animateTo(1);
                        },
                        icon: const Icon(Icons.people_alt_rounded),
                        label: const Text('Manage Users'),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          _tabController.animateTo(2);
                        },
                        icon: const Icon(Icons.inventory_2_rounded),
                        label: const Text('Manage Items'),
                      ),
                      FilledButton.icon(
                        onPressed: () {
                          _tabController.animateTo(3);
                        },
                        icon: const Icon(Icons.verified_user_rounded),
                        label: const Text('Review Claims'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              icon,
              size: 28,
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search users...',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _userSearch = value;
                });
              },
            ),
          ),
          Expanded(
            child: _usersLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _filteredUsers.isEmpty
                    ? _emptyState(
                        'No users found.',
                        Icons.people_outline_rounded,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          24,
                        ),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          return _buildUserCard(
                            _filteredUsers[index],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(dynamic user) {
    final name = _userName(user);
    final email = _userEmail(user);
    final role = _userRole(user);
    final status = _userStatus(user);

    final isActive = status.toLowerCase() == 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 14),
            _infoChip(
              Icons.badge_rounded,
              role.toUpperCase(),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    _showUserDetails(user);
                  },
                  icon: const Icon(Icons.visibility_rounded),
                  label: const Text('View'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _showRoleDialog(user);
                  },
                  icon: const Icon(
                    Icons.admin_panel_settings_rounded,
                  ),
                  label: const Text('Role'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _confirmDialog(
                      title: isActive ? 'Suspend User' : 'Activate User',
                      message: isActive
                          ? 'Suspend $name? They will not be able to use the account normally.'
                          : 'Activate $name?',
                      confirmText: isActive ? 'Suspend' : 'Activate',
                      onConfirm: () {
                        _changeUserStatus(
                          user,
                          isActive ? 'suspended' : 'active',
                        );
                      },
                    );
                  },
                  icon: Icon(
                    isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                  ),
                  label: Text(
                    isActive ? 'Suspend' : 'Activate',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _deleteUser(user);
                  },
                  icon: const Icon(
                    Icons.delete_forever_rounded,
                  ),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsTab() {
    return RefreshIndicator(
      onRefresh: _loadItems,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search items...',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _itemSearch = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 150,
                  child: _dropdown(
                    value: _itemStatus,
                    items: const [
                      'all',
                      'active',
                      'pending',
                      'resolved',
                      'recovered',
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        _itemStatus = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _itemsLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _filteredItems.isEmpty
                    ? _emptyState(
                        'No items found.',
                        Icons.inventory_2_outlined,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          24,
                        ),
                        itemCount: _filteredItems.length,
                        itemBuilder: (context, index) {
                          return _buildItemCard(
                            _filteredItems[index],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(dynamic item) {
    final title = _itemTitle(item);
    final type = _itemType(item);
    final status = _itemStatusValue(item);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: CircleAvatar(
          child: Icon(
            type.toLowerCase() == 'lost'
                ? Icons.search_rounded
                : Icons.find_in_page_rounded,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '$type • $status',
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'view') {
              _showItemDetails(item);
            } else if (value == 'report') {
              _generateItemReport(item);
            } else if (value == 'active') {
              _changeItemStatus(item, 'active');
            } else if (value == 'resolved') {
              _changeItemStatus(item, 'resolved');
            } else if (value == 'recovered') {
              _changeItemStatus(item, 'recovered');
            }
          },
          itemBuilder: (context) {
            return const [
              PopupMenuItem(
                value: 'view',
                child: Text('View Details'),
              ),
              PopupMenuItem(
                value: 'report',
                child: Text('Generate PDF Report'),
              ),
              PopupMenuItem(
                value: 'active',
                child: Text('Mark Active'),
              ),
              PopupMenuItem(
                value: 'resolved',
                child: Text('Mark Resolved'),
              ),
              PopupMenuItem(
                value: 'recovered',
                child: Text('Mark Recovered'),
              ),
            ];
          },
        ),
      ),
    );
  }

  Widget _buildClaimsTab() {
    return RefreshIndicator(
      onRefresh: _loadClaims,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: _dropdown(
                value: _claimStatus,
                items: const [
                  'all',
                  'pending',
                  'approved',
                  'rejected',
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _claimStatus = value;
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: _claimsLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : _filteredClaims.isEmpty
                    ? _emptyState(
                        'No claims found.',
                        Icons.assignment_outlined,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          24,
                        ),
                        itemCount: _filteredClaims.length,
                        itemBuilder: (context, index) {
                          return _buildClaimCard(
                            _filteredClaims[index],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimCard(dynamic claim) {
    final status = _claimStatusValue(claim);

    String claimant = 'Unknown claimant';
    String item = 'Unknown item';

    if (claim is Map) {
      claimant = (claim['claimant_name'] ??
              claim['user_name'] ??
              claim['claimant_email'] ??
              'Unknown claimant')
          .toString();

      item = (claim['item_title'] ??
              claim['item_name'] ??
              claim['title'] ??
              'Unknown item')
          .toString();
    }

    final pending = status.toLowerCase() == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  child: Icon(
                    Icons.assignment_turned_in_rounded,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                _statusChip(status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Claimant: $claimant',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (claim is Map && claim['created_at'] != null) ...[
              const SizedBox(height: 4),
              Text(
                'Submitted: ${claim['created_at']}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _generateClaimReport(claim),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Generate Claim Report'),
            ),
            if (pending) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      _confirmDialog(
                        title: 'Approve Claim',
                        message: 'Approve this claim?',
                        confirmText: 'Approve',
                        onConfirm: () {
                          _reviewClaim(
                            claim,
                            'approved',
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      _confirmDialog(
                        title: 'Reject Claim',
                        message: 'Reject this claim?',
                        confirmText: 'Reject',
                        onConfirm: () {
                          _reviewClaim(
                            claim,
                            'rejected',
                          );
                        },
                      );
                    },
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items.first,
      isExpanded: true,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(
            item == 'all' ? 'All' : item[0].toUpperCase() + item.substring(1),
          ),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoChip(
    IconData icon,
    String text,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _emptyState(
    String message,
    IconData icon,
  ) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Icon(
          icon,
          size: 64,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  void _showUserDetails(dynamic user) {
    final name = _userName(user);
    final email = _userEmail(user);
    final role = _userRole(user);
    final status = _userStatus(user);

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Name', name),
              _detailRow('Email', email),
              _detailRow('Role', role),
              _detailRow('Status', status),
              if (user is Map && user['user_id'] != null)
                _detailRow(
                  'User ID',
                  user['user_id'].toString(),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showItemDetails(dynamic item) {
    final title = _itemTitle(item);
    final type = _itemType(item);
    final status = _itemStatusValue(item);

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Title', title),
              _detailRow('Type', type),
              _detailRow('Status', status),
              if (item is Map && item['location_name'] != null)
                _detailRow(
                  'Location',
                  item['location_name'].toString(),
                ),
              if (item is Map && item['description'] != null)
                _detailRow(
                  'Description',
                  item['description'].toString(),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REPORT DATA HELPERS
  // ============================================================

  String _textValue(dynamic value, {String fallback = 'Not available'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _prettyLabel(dynamic value) {
    final raw = _textValue(value, fallback: 'Unknown');
    return raw
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String _reportDate(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return 'Not available';
    }
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return value.toString();
    final local = parsed.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  String _itemCategory(dynamic item) {
    if (item is! Map) return 'Not available';
    return _textValue(item['category'] ?? item['item_category']);
  }

  String _itemLocation(dynamic item) {
    if (item is! Map) return 'Not available';
    return _textValue(
      item['location_name'] ??
          item['location'] ??
          item['found_location'] ??
          item['lost_location'],
    );
  }

  String _itemDate(dynamic item) {
    if (item is! Map) return 'Not available';
    return _reportDate(
      item['item_date'] ??
          item['date_reported'] ??
          item['reported_at'] ??
          item['created_at'] ??
          item['date'],
    );
  }

  String _itemColor(dynamic item) =>
      item is Map ? _textValue(item['color']) : 'Not available';

  String _itemBrand(dynamic item) =>
      item is Map ? _textValue(item['brand']) : 'Not available';

  String _itemModel(dynamic item) =>
      item is Map ? _textValue(item['model']) : 'Not available';

  String _itemDescription(dynamic item) =>
      item is Map ? _textValue(item['description']) : 'Not available';

  String _itemId(dynamic item) {
    if (item is! Map) return '';
    return _textValue(item['item_id'] ?? item['id'], fallback: '');
  }

  String _itemReporterName(dynamic item) {
    if (item is! Map) return 'Reporter not available';
    final reporter = item['reporter'] ?? item['user'] ?? item['owner'];
    if (reporter is Map) {
      return _textValue(
        item['reporter_name'] ??
            item['user_name'] ??
            reporter['full_name'] ??
            reporter['name'] ??
            reporter['display_name'],
        fallback: 'Reporter not available',
      );
    }
    return _textValue(
      item['reporter_name'] ??
          item['user_name'] ??
          item['full_name'] ??
          item['name'],
      fallback: 'Reporter not available',
    );
  }

  String _itemReporterEmail(dynamic item) {
    if (item is! Map) return 'Email not available';
    final reporter = item['reporter'] ?? item['user'] ?? item['owner'];
    return _textValue(
      item['reporter_email'] ??
          item['user_email'] ??
          (reporter is Map
              ? reporter['college_email'] ?? reporter['email']
              : null),
      fallback: 'Email not available',
    );
  }

  String _itemReporterId(dynamic item) {
    if (item is! Map) return '';
    final reporter = item['reporter'] ?? item['user'] ?? item['owner'];
    return _textValue(
      item['reporter_id'] ??
          item['user_id'] ??
          (reporter is Map ? reporter['user_id'] ?? reporter['id'] : null),
      fallback: '',
    );
  }

  Map<String, dynamic> _claimItem(dynamic claim) {
    if (claim is! Map) return {};
    final nested = claim['item'] ??
        claim['found_item'] ??
        claim['lost_item'] ??
        claim['claimed_item'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return {};
  }

  dynamic _claimItemId(dynamic claim) {
    if (claim is! Map) return null;
    final item = _claimItem(claim);
    return claim['item_id'] ??
        claim['found_item_id'] ??
        claim['lost_item_id'] ??
        item['item_id'] ??
        item['id'];
  }

  Map<String, dynamic> _findClaimItem(dynamic claim) {
    final nested = _claimItem(claim);
    if (nested.isNotEmpty) return nested;
    final id = _claimItemId(claim)?.toString();
    if (id == null || id.isEmpty) return {};
    for (final raw in _items) {
      if (raw is! Map) continue;
      final candidate = Map<String, dynamic>.from(raw);
      final candidateId = (candidate['item_id'] ?? candidate['id'])?.toString();
      if (candidateId == id) return candidate;
    }
    return {};
  }

  String _claimantName(dynamic claim) {
    if (claim is! Map) return 'Unknown claimant';
    final nested = claim['claimant'] ?? claim['user'] ?? claim['claimant_user'];
    return _textValue(
      claim['claimant_name'] ??
          claim['user_name'] ??
          claim['claimant_full_name'] ??
          (nested is Map ? nested['full_name'] ?? nested['name'] : null) ??
          claim['claimant_email'],
      fallback: 'Unknown claimant',
    );
  }

  String _claimantEmail(dynamic claim) {
    if (claim is! Map) return 'Email not available';
    final nested = claim['claimant'] ?? claim['user'] ?? claim['claimant_user'];
    return _textValue(
      claim['claimant_email'] ??
          claim['user_email'] ??
          (nested is Map ? nested['college_email'] ?? nested['email'] : null),
      fallback: 'Email not available',
    );
  }

  String _claimantId(dynamic claim) {
    if (claim is! Map) return '';
    final nested = claim['claimant'] ?? claim['user'] ?? claim['claimant_user'];
    return _textValue(
      claim['claimant_id'] ??
          claim['user_id'] ??
          (nested is Map ? nested['user_id'] ?? nested['id'] : null),
      fallback: '',
    );
  }

  String _claimItemTitle(dynamic claim) {
    if (claim is! Map) return 'Unknown item';
    final item = _findClaimItem(claim);
    return _textValue(
      claim['item_title'] ??
          claim['item_name'] ??
          claim['title'] ??
          item['title'] ??
          item['item_name'] ??
          item['name'],
      fallback: 'Unknown item',
    );
  }

  // ============================================================
  // PDF REPORT GENERATION AND PREVIEW
  // ============================================================

  Future<void> _generateItemReport(dynamic rawItem) async {
    if (rawItem is! Map) {
      _showError('Item details are unavailable.');
      return;
    }
    final item = Map<String, dynamic>.from(rawItem);
    await _openPdfPreview(
      title: 'Item Report',
      fileName: 'CampusFind_Item_Report.pdf',
      buildDocument: (_) => _buildItemPdf(item),
    );
  }

  Future<void> _generateClaimReport(dynamic rawClaim) async {
    if (rawClaim is! Map) {
      _showError('Claim details are unavailable.');
      return;
    }
    final claim = Map<String, dynamic>.from(rawClaim);
    await _openPdfPreview(
      title: 'Official Claim Report',
      fileName: 'CampusFind_Claim_Report.pdf',
      buildDocument: (_) => _buildClaimPdf(claim),
    );
  }

  Future<void> _openPdfPreview({
    required String title,
    required String fileName,
    required Future<Uint8List> Function(PdfPageFormat format) buildDocument,
  }) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReportPreviewScreen(
          title: title,
          fileName: fileName,
          buildDocument: buildDocument,
        ),
      ),
    );
  }

  Future<Uint8List> _buildItemPdf(Map<String, dynamic> item) async {
    final document = pw.Document();
    final title = _itemTitle(item);
    final type = _prettyLabel(_itemType(item));
    final status = _prettyLabel(_itemStatusValue(item));
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: _pdfPageFooter,
        build: (_) => [
          _pdfHeader('CAMPUSFIND ITEM CASE REPORT'),
          pw.SizedBox(height: 14),
          _pdfStatusBanner(status, label: 'CASE STATUS'),
          pw.SizedBox(height: 14),
          _pdfSectionTitle('Case Information'),
          _pdfTable([
            [
              'Item ID',
              _itemId(item).isEmpty ? 'Not available' : _itemId(item)
            ],
            ['Item Name', title],
            ['Report Type', type],
            ['Case Status', status],
            ['Category', _itemCategory(item)],
            ['Location', _itemLocation(item)],
            ['Date', _itemDate(item)],
          ]),
          pw.SizedBox(height: 12),
          _pdfSectionTitle('Item Identification Details'),
          _pdfTable([
            ['Color', _itemColor(item)],
            ['Brand', _itemBrand(item)],
            ['Model', _itemModel(item)],
          ]),
          pw.SizedBox(height: 12),
          _pdfSectionTitle('Item Description'),
          _pdfTextBox(_itemDescription(item)),
          pw.SizedBox(height: 12),
          _pdfSectionTitle(type.toLowerCase() == 'found'
              ? 'Finder Information'
              : 'Reporter Information'),
          _pdfTable([
            ['Name', _itemReporterName(item)],
            ['Email', _itemReporterEmail(item)],
            [
              'Reporter ID',
              _itemReporterId(item).isEmpty
                  ? 'Not available'
                  : _itemReporterId(item)
            ],
          ]),
          pw.SizedBox(height: 16),
          _pdfSignatureBlock(),
        ],
      ),
    );
    return document.save();
  }

  Future<Uint8List> _buildClaimPdf(Map<String, dynamic> claim) async {
    final document = pw.Document();
    final item = _findClaimItem(claim);
    final claimStatus = _prettyLabel(_claimStatusValue(claim));
    final itemStatus = _prettyLabel(_itemStatusValue(item));
    final itemType = _prettyLabel(
      item['item_type'] ?? item['report_type'] ?? item['type'] ?? 'found',
    );
    final proof = _textValue(
      claim['proof_description'] ?? claim['proof'],
      fallback: 'Not provided',
    );
    final verification = claim['verification_answers'];
    final evidence = claim['evidence_photos'];
    final adminNotes = _textValue(
      claim['admin_notes'] ?? claim['admin_note'] ?? claim['review_note'],
      fallback: 'None',
    );
    final submitted = _reportDate(
      claim['submitted_at'] ?? claim['created_at'] ?? claim['date'],
    );
    final reviewed = _reportDate(claim['reviewed_at'] ?? claim['reviewed_on']);
    final itemId = _itemId(item);
    final linkedItemId = _claimItemId(claim)?.toString() ?? '';

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: _pdfPageFooter,
        build: (_) => [
          _pdfHeader('OFFICIAL CLAIM VERIFICATION REPORT'),
          pw.SizedBox(height: 12),
          _pdfStatusBanner(claimStatus, label: 'CLAIM STATUS'),
          pw.SizedBox(height: 14),
          _pdfSectionTitle('Claim Information'),
          _pdfTable([
            ['Claim ID', _textValue(claim['claim_id'] ?? claim['id'])],
            ['Claim Status', claimStatus],
            ['Submitted On', submitted],
            ['Reviewed On', reviewed],
          ]),
          pw.SizedBox(height: 12),
          _pdfSectionTitle('Claimant Information'),
          _pdfTable([
            ['Name', _claimantName(claim)],
            ['Email', _claimantEmail(claim)],
            [
              'Claimant ID',
              _claimantId(claim).isEmpty ? 'Not available' : _claimantId(claim)
            ],
          ]),
          pw.SizedBox(height: 12),
          _pdfSectionTitle('Related Item Information'),
          _pdfTable([
            ['Item Name', _claimItemTitle(claim)],
            ['Item Type', itemType],
            ['Case Status', itemStatus],
            [
              'Item ID',
              itemId.isNotEmpty
                  ? itemId
                  : (linkedItemId.isEmpty ? 'Not available' : linkedItemId)
            ],
            ['Category', _itemCategory(item)],
            ['Location', _itemLocation(item)],
            ['Date', _itemDate(item)],
            ['Color', _itemColor(item)],
            ['Brand', _itemBrand(item)],
            ['Model', _itemModel(item)],
          ]),
          pw.SizedBox(height: 12),
          _pdfSectionTitle('Item Description'),
          _pdfTextBox(_itemDescription(item)),
          pw.SizedBox(height: 12),
          _pdfSectionTitle('Finder / Item Reporter'),
          _pdfTable([
            ['Name', _itemReporterName(item)],
            ['Email', _itemReporterEmail(item)],
          ]),
          pw.SizedBox(height: 12),
          _pdfSectionTitle('Claim Verification'),
          _pdfTable([
            ['Proof Description', proof],
          ]),
          if (verification != null) ...[
            pw.SizedBox(height: 10),
            _pdfSectionTitle('Verification Answers'),
            _pdfTextBox(verification.toString()),
          ],
          if (evidence != null) ...[
            pw.SizedBox(height: 10),
            _pdfSectionTitle('Submitted Evidence'),
            _pdfTextBox(evidence is List
                ? '${evidence.length} evidence photo(s) submitted.'
                : evidence.toString()),
          ],
          pw.SizedBox(height: 12),
          _pdfSectionTitle('Administrative Review'),
          _pdfTable([
            ['Final Claim Status', claimStatus],
            ['Related Item Case Status', itemStatus],
            ['Admin Review Notes', adminNotes],
          ]),
          pw.SizedBox(height: 14),
          _pdfSignatureBlock(),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _pdfHeader(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('CAMPUSFIND',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 3),
        pw.Text('AI-Powered College Lost & Found System',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 8),
        pw.Text(title,
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.Widget _pdfStatusBanner(String status, {String label = 'STATUS'}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Text('$label: ${status.toUpperCase()}',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _pdfSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(title,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _pdfTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
      columnWidths: const {
        0: pw.FixedColumnWidth(120),
        1: pw.FlexColumnWidth(),
      },
      children: rows
          .map((row) => pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(row[0],
                      style: pw.TextStyle(
                          fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(row.length > 1 ? row[1] : '',
                      style: const pw.TextStyle(fontSize: 8.5)),
                ),
              ]))
          .toList(),
    );
  }

  pw.Widget _pdfTextBox(String text) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(9),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 8.5)),
    );
  }

  pw.Widget _pdfSignatureBlock() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Administrative Authorization',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Text('Admin Signature: ______________________________',
              style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 6),
          pw.Text('Date: __________________',
              style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  pw.Widget _pdfPageFooter(pw.Context context) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Generated by CampusFind Admin Dashboard',
                style:
                    const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style:
                    const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          ],
        ),
      ],
    );
  }

  void _showRoleDialog(dynamic user) {
    final currentRole = _userRole(user);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        String selectedRole = currentRole;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Change User Role'),
              content: DropdownButtonFormField<String>(
                value: [
                  'student',
                  'staff',
                  'admin',
                ].contains(selectedRole)
                    ? selectedRole
                    : 'student',
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'student',
                    child: Text('Student'),
                  ),
                  DropdownMenuItem(
                    value: 'staff',
                    child: Text('Staff'),
                  ),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Admin'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setDialogState(() {
                    selectedRole = value;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();

                    _changeUserRole(
                      user,
                      selectedRole,
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required VoidCallback onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      onConfirm();
    }
  }
}

// In-app PDF preview. The Back arrow returns to the Admin Dashboard.
class ReportPreviewScreen extends StatelessWidget {
  final String title;
  final String fileName;
  final Future<Uint8List> Function(PdfPageFormat format) buildDocument;

  const ReportPreviewScreen({
    super.key,
    required this.title,
    required this.fileName,
    required this.buildDocument,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: PdfPreview(
        build: buildDocument,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: fileName,
      ),
    );
  }
}
