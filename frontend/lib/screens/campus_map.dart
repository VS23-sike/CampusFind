import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';

class CampusLocation {
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final IconData icon;

  const CampusLocation({
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.icon,
  });
}

class CampusMapScreen extends StatefulWidget {
  final bool selectionMode;
  final Map<String, dynamic>? selectedItem;

  const CampusMapScreen({
    super.key,
    this.selectionMode = false,
    this.selectedItem,
  });

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  final MapController mapController = MapController();

  static const CampusLocation campusCenter = CampusLocation(
    name: 'Campus',
    description: 'Main campus area',
    latitude: 19.2183,
    longitude: 72.9781,
    icon: Icons.school_outlined,
  );

  final List<CampusLocation> locations = const [
    CampusLocation(
      name: 'Main Building',
      description: 'Administration and main academic block',
      latitude: 19.2183,
      longitude: 72.9781,
      icon: Icons.account_balance_outlined,
    ),
    CampusLocation(
      name: 'Library',
      description: 'Central college library',
      latitude: 19.2188,
      longitude: 72.9786,
      icon: Icons.local_library_outlined,
    ),
    CampusLocation(
      name: 'Computer Lab',
      description: 'Computer and Data Science laboratories',
      latitude: 19.2178,
      longitude: 72.9775,
      icon: Icons.computer_outlined,
    ),
    CampusLocation(
      name: 'Canteen',
      description: 'Main student canteen',
      latitude: 19.2175,
      longitude: 72.9787,
      icon: Icons.restaurant_outlined,
    ),
    CampusLocation(
      name: 'Sports Ground',
      description: 'College sports and activity area',
      latitude: 19.2190,
      longitude: 72.9772,
      icon: Icons.sports_soccer_outlined,
    ),
    CampusLocation(
      name: 'Parking Area',
      description: 'Student and staff parking',
      latitude: 19.2192,
      longitude: 72.9790,
      icon: Icons.local_parking_outlined,
    ),
  ];

  List<dynamic> lostItems = [];
  List<dynamic> foundItems = [];

  List<Map<String, dynamic>> nearbyReports = [];

  bool loading = true;
  bool nearbyLoading = false;

  String filter = 'all';

  double radiusKm = 1.0;

  CampusLocation? selectedLocation;
  Map<String, dynamic>? selectedReport;

  @override
  void initState() {
    super.initState();

    selectedReport = widget.selectedItem;

    loadMapData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerOnSelectedItem();
    });
  }

  // ============================================================
  // MAP CENTERING
  // ============================================================

  Future<void> _centerOnSelectedItem() async {
    final item = widget.selectedItem;

    if (item == null) return;

    final latitude = _toDouble(item['latitude']);
    final longitude = _toDouble(item['longitude']);

    if (latitude == null || longitude == null) {
      return;
    }

    await Future.delayed(
      const Duration(milliseconds: 300),
    );

    if (!mounted) return;

    try {
      mapController.move(
        LatLng(latitude, longitude),
        18,
      );
    } catch (_) {
      // Map controller may not be ready yet.
    }
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value);
    }

    return null;
  }

  // ============================================================
  // LOAD MAP DATA
  // ============================================================

  Future<void> loadMapData() async {
    setState(() {
      loading = true;
    });

    try {
      final results = await Future.wait([
        ApiService.lost(size: 100),
        ApiService.found(size: 100),
      ]);

      if (!mounted) return;

      setState(() {
        lostItems = results[0];
        foundItems = results[1];
      });

      _centerOnSelectedItem();
    } catch (e) {
      if (mounted) {
        showError(
          context,
          ApiService.errorMessage(e),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ============================================================
  // NEARBY LOCATION INTELLIGENCE
  // ============================================================

  Future<void> loadNearbyReports(
    CampusLocation location,
  ) async {
    if (widget.selectionMode) return;

    setState(() {
      nearbyLoading = true;
      selectedLocation = location;
      selectedReport = null;
      nearbyReports = [];
    });

    try {
      final result = await ApiService.nearbySearch(
        latitude: location.latitude,
        longitude: location.longitude,
        radiusKm: radiusKm,
        type: filter == 'all' ? null : filter,
      );

      if (!mounted) return;

      final reports = <Map<String, dynamic>>[];

      final lost = result['lost'];
      final found = result['found'];

      if (lost is List) {
        for (final item in lost) {
          if (item is Map) {
            final report = Map<String, dynamic>.from(item);

            report['_isFound'] = false;
            reports.add(report);
          }
        }
      }

      if (found is List) {
        for (final item in found) {
          if (item is Map) {
            final report = Map<String, dynamic>.from(item);

            report['_isFound'] = true;
            reports.add(report);
          }
        }
      }

      reports.sort(
        (a, b) {
          final distanceA = _toDouble(a['distance_km']) ?? 999999;

          final distanceB = _toDouble(b['distance_km']) ?? 999999;

          return distanceA.compareTo(distanceB);
        },
      );

      setState(() {
        nearbyReports = reports;
      });

      mapController.move(
        LatLng(
          location.latitude,
          location.longitude,
        ),
        _zoomForRadius(radiusKm),
      );
    } catch (e) {
      if (mounted) {
        showError(
          context,
          ApiService.errorMessage(e),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          nearbyLoading = false;
        });
      }
    }
  }

  double _zoomForRadius(double radius) {
    if (radius <= 0.2) return 19;
    if (radius <= 0.5) return 18;
    if (radius <= 1.0) return 17;
    return 16;
  }

  Future<void> refreshNearbyReports() async {
    if (selectedLocation == null) return;

    await loadNearbyReports(
      selectedLocation!,
    );
  }

  // ============================================================
  // MAPPED REPORTS
  // ============================================================

  List<Map<String, dynamic>> get mappedReports {
    final reports = <Map<String, dynamic>>[];

    if (filter == 'all' || filter == 'lost') {
      for (final item in lostItems) {
        if (item is Map) {
          final report = Map<String, dynamic>.from(item);

          final latitude = _toDouble(report['latitude']);

          final longitude = _toDouble(report['longitude']);

          if (latitude != null && longitude != null) {
            report['_isFound'] = false;
            reports.add(report);
          }
        }
      }
    }

    if (filter == 'all' || filter == 'found') {
      for (final item in foundItems) {
        if (item is Map) {
          final report = Map<String, dynamic>.from(item);

          final latitude = _toDouble(report['latitude']);

          final longitude = _toDouble(report['longitude']);

          if (latitude != null && longitude != null) {
            report['_isFound'] = true;
            reports.add(report);
          }
        }
      }
    }

    return reports;
  }

  List<Map<String, dynamic>> get displayedReports {
    if (selectedLocation != null && !widget.selectionMode) {
      return nearbyReports;
    }

    return mappedReports;
  }

  // ============================================================
  // SELECTION
  // ============================================================

  bool _isSelectedReport(
    Map<String, dynamic> report,
  ) {
    if (selectedReport == null) return false;

    final selectedId = selectedReport!['item_id']?.toString();

    final reportId = report['item_id']?.toString();

    return selectedId != null && reportId != null && selectedId == reportId;
  }

  void selectCampusLocation(
    CampusLocation location,
  ) {
    if (widget.selectionMode) {
      Navigator.pop(
        context,
        {
          'location_name': location.name,
          'campus_building': location.name,
          'latitude': location.latitude,
          'longitude': location.longitude,
        },
      );

      return;
    }

    loadNearbyReports(location);
  }

  void selectReport(
    Map<String, dynamic> report,
  ) {
    final latitude = _toDouble(report['latitude']);

    final longitude = _toDouble(report['longitude']);

    setState(() {
      selectedReport = report;
      selectedLocation = null;
    });

    if (latitude != null && longitude != null) {
      mapController.move(
        LatLng(latitude, longitude),
        18,
      );
    }

    if (widget.selectionMode) {
      Navigator.pop(
        context,
        {
          'location_name':
              report['location_name']?.toString() ?? 'Selected location',
          'campus_building': report['campus_building']?.toString() ??
              report['location_name']?.toString() ??
              'Campus',
          'latitude': latitude,
          'longitude': longitude,
        },
      );
    }
  }

  void openReport(
    Map<String, dynamic> report,
  ) {
    if (widget.selectionMode) {
      selectReport(report);
      return;
    }

    final isFound = report['_isFound'] == true;

    context.push(
      '/item-details?found=$isFound',
      extra: report,
    );
  }

  void clearSelection() {
    setState(() {
      selectedLocation = null;
      selectedReport = null;
      nearbyReports = [];
    });

    mapController.move(
      LatLng(
        campusCenter.latitude,
        campusCenter.longitude,
      ),
      17,
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget buildFilterChip(
    String label,
    String value,
  ) {
    final selected = filter == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: loading || nearbyLoading
          ? null
          : (_) async {
              setState(() {
                filter = value;
                selectedReport = null;
              });

              if (selectedLocation != null && !widget.selectionMode) {
                await loadNearbyReports(
                  selectedLocation!,
                );
              }
            },
    );
  }

  Widget buildRadiusSelector() {
    if (widget.selectionMode) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        const Icon(
          Icons.radar_outlined,
          size: 19,
        ),
        const SizedBox(width: 7),
        const Text(
          'Search radius',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 10),
        DropdownButton<double>(
          value: radiusKm,
          underline: const SizedBox.shrink(),
          items: const [
            DropdownMenuItem(
              value: 0.2,
              child: Text('200 m'),
            ),
            DropdownMenuItem(
              value: 0.5,
              child: Text('500 m'),
            ),
            DropdownMenuItem(
              value: 1.0,
              child: Text('1 km'),
            ),
            DropdownMenuItem(
              value: 2.0,
              child: Text('2 km'),
            ),
          ],
          onChanged: nearbyLoading
              ? null
              : (value) async {
                  if (value == null) return;

                  setState(() {
                    radiusKm = value;
                  });

                  if (selectedLocation != null) {
                    await loadNearbyReports(
                      selectedLocation!,
                    );
                  }
                },
        ),
      ],
    );
  }

  // ============================================================
  // MAP MARKER
  // ============================================================

  Widget buildMapMarker({
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: selected ? 48 : 42,
        height: selected ? 48 : 42,
        decoration: BoxDecoration(
          color:
              selected ? Colors.black : Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 8,
              offset: Offset(0, 3),
              color: Colors.black26,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: selected ? 25 : 22,
        ),
      ),
    );
  }

  // ============================================================
  // SELECTED CARD
  // ============================================================

  Widget buildSelectedCard() {
    if (selectedReport != null) {
      final report = selectedReport!;

      final isFound = report['_isFound'] == true;

      final title = report['title']?.toString() ?? 'Reported Item';

      final location = report['location_name']?.toString() ?? 'Campus';

      final building = report['campus_building']?.toString() ?? '';

      final distance = _toDouble(report['distance_km']);

      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 21,
                    child: Icon(
                      isFound
                          ? Icons.inventory_2_outlined
                          : Icons.search_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isFound ? 'Found item' : 'Lost item',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: clearSelection,
                    icon: const Icon(
                      Icons.close,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      building.isEmpty ? location : '$location • $building',
                      style: const TextStyle(
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              if (distance != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.near_me_outlined,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatDistance(distance)} away',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              if (!widget.selectionMode)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      openReport(
                        report,
                      );
                    },
                    icon: const Icon(
                      Icons.open_in_new,
                    ),
                    label: const Text(
                      'View Item Details',
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (selectedLocation != null) {
      final location = selectedLocation!;

      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Icon(
                      location.icon,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          location.description,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: clearSelection,
                    icon: const Icon(
                      Icons.close,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.radar_outlined,
                    size: 19,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${nearbyReports.length} report${nearbyReports.length == 1 ? '' : 's'} within ${_formatRadius(radiusKm)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String _formatRadius(
    double radius,
  ) {
    if (radius < 1) {
      return '${(radius * 1000).round()} m';
    }

    return '${radius.toStringAsFixed(radius == radius.roundToDouble() ? 0 : 1)} km';
  }

  String _formatDistance(
    double distance,
  ) {
    if (distance < 1) {
      return '${(distance * 1000).round()} m';
    }

    return '${distance.toStringAsFixed(2)} km';
  }

  // ============================================================
  // CAMPUS LOCATIONS
  // ============================================================

  Widget buildCampusLocations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Campus Locations',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        if (!widget.selectionMode)
          const Text(
            'Tap a location to find nearby Lost & Found reports.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: locations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final location = locations[index];

              final selected = selectedLocation?.name == location.name;

              return SizedBox(
                width: 180,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(
                      16,
                    ),
                    onTap: nearbyLoading
                        ? null
                        : () => selectCampusLocation(
                              location,
                            ),
                    child: Padding(
                      padding: const EdgeInsets.all(
                        12,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: selected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary
                                : null,
                            child: Icon(
                              location.icon,
                              size: 20,
                              color: selected ? Colors.white : null,
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child: Text(
                              location.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ============================================================
  // REPORT LIST
  // ============================================================

  Widget buildMappedReports() {
    final reports = displayedReports;

    final isNearby = selectedLocation != null && !widget.selectionMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isNearby ? 'Nearby Reports' : 'Mapped Reports',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (nearbyLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            else
              Text(
                '${reports.length}',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (reports.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(
                18,
              ),
              child: Row(
                children: [
                  Icon(
                    isNearby
                        ? Icons.radar_outlined
                        : Icons.location_off_outlined,
                    color: Theme.of(
                      context,
                    ).colorScheme.primary,
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child: Text(
                      isNearby
                          ? 'No Lost or Found reports were found within ${_formatRadius(radiusKm)} of ${selectedLocation!.name}.'
                          : 'No reports with map coordinates were found for this filter.',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...reports.map(
            (report) {
              final isFound = report['_isFound'] == true;

              final title = report['title']?.toString() ?? 'Untitled item';

              final location = report['location_name']?.toString() ?? 'Campus';

              final selected = _isSelectedReport(
                report,
              );

              final distance = _toDouble(
                report['distance_km'],
              );

              String subtitle = '${isFound ? 'Found' : 'Lost'} • $location';

              if (distance != null) {
                subtitle += ' • ${_formatDistance(distance)} away';
              }

              return Card(
                margin: const EdgeInsets.only(
                  bottom: 10,
                ),
                child: ListTile(
                  selected: selected,
                  leading: CircleAvatar(
                    child: Icon(
                      isFound
                          ? Icons.inventory_2_outlined
                          : Icons.search_outlined,
                    ),
                  ),
                  title: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                  ),
                  onTap: () => openReport(
                    report,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // ============================================================
  // MAP MARKERS
  // ============================================================

  List<Marker> buildMarkers() {
    final markers = <Marker>[];

    // Campus location markers
    for (final location in locations) {
      final selected = selectedLocation?.name == location.name;

      markers.add(
        Marker(
          point: LatLng(
            location.latitude,
            location.longitude,
          ),
          width: selected ? 54 : 48,
          height: selected ? 54 : 48,
          child: buildMapMarker(
            icon: location.icon,
            selected: selected,
            onTap: () => selectCampusLocation(
              location,
            ),
          ),
        ),
      );
    }

    // Report markers
    for (final report in displayedReports) {
      final latitude = _toDouble(
        report['latitude'],
      );

      final longitude = _toDouble(
        report['longitude'],
      );

      if (latitude == null || longitude == null) {
        continue;
      }

      final isFound = report['_isFound'] == true;

      final selected = _isSelectedReport(
        report,
      );

      markers.add(
        Marker(
          point: LatLng(
            latitude,
            longitude,
          ),
          width: selected ? 58 : 48,
          height: selected ? 58 : 48,
          child: buildMapMarker(
            icon: isFound ? Icons.inventory_2_outlined : Icons.search_outlined,
            selected: selected,
            onTap: () => selectReport(
              report,
            ),
          ),
        ),
      );
    }

    return markers;
  }

  // ============================================================
  // LEGEND
  // ============================================================

  Widget buildLegend() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        child: Row(
          children: [
            _legendItem(
              Icons.school_outlined,
              'Campus',
            ),
            const SizedBox(
              width: 18,
            ),
            _legendItem(
              Icons.search_outlined,
              'Lost',
            ),
            const SizedBox(
              width: 18,
            ),
            _legendItem(
              Icons.inventory_2_outlined,
              'Found',
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(
    IconData icon,
    String label,
  ) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
          ),
          const SizedBox(
            width: 5,
          ),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
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
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(
            Icons.arrow_back,
          ),
          onPressed: () {
            if (widget.selectionMode) {
              Navigator.pop(
                context,
              );
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          widget.selectionMode ? 'Select Campus Location' : 'Campus Map',
        ),
        actions: [
          if (!widget.selectionMode && selectedLocation != null)
            IconButton(
              tooltip: 'Refresh nearby reports',
              onPressed: nearbyLoading ? null : refreshNearbyReports,
              icon: const Icon(
                Icons.refresh,
              ),
            ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading || nearbyLoading ? null : loadMapData,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadMapData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(
            16,
          ),
          children: [
            if (widget.selectionMode)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(
                    14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.touch_app_outlined,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      const Expanded(
                        child: Text(
                          'Tap a campus location or mapped report to use it for your report.',
                          style: TextStyle(
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (widget.selectionMode)
              const SizedBox(
                height: 12,
              ),

            // FILTERS
            Row(
              children: [
                buildFilterChip(
                  'All',
                  'all',
                ),
                const SizedBox(
                  width: 8,
                ),
                buildFilterChip(
                  'Lost',
                  'lost',
                ),
                const SizedBox(
                  width: 8,
                ),
                buildFilterChip(
                  'Found',
                  'found',
                ),
              ],
            ),

            if (!widget.selectionMode) ...[
              const SizedBox(
                height: 8,
              ),
              buildRadiusSelector(),
            ],

            const SizedBox(
              height: 12,
            ),

            // MAP
            SizedBox(
              height: 420,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  20,
                ),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: mapController,
                      options: MapOptions(
                        initialCenter: LatLng(
                          campusCenter.latitude,
                          campusCenter.longitude,
                        ),
                        initialZoom: 17,
                        minZoom: 14,
                        maxZoom: 20,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.campusfind',
                        ),
                        MarkerLayer(
                          markers: buildMarkers(),
                        ),
                      ],
                    ),

                    // Center button
                    Positioned(
                      top: 12,
                      right: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'campus_center_button',
                        tooltip: 'Center on campus',
                        onPressed: () {
                          if (selectedLocation != null) {
                            mapController.move(
                              LatLng(
                                selectedLocation!.latitude,
                                selectedLocation!.longitude,
                              ),
                              _zoomForRadius(
                                radiusKm,
                              ),
                            );
                          } else {
                            mapController.move(
                              LatLng(
                                campusCenter.latitude,
                                campusCenter.longitude,
                              ),
                              17,
                            );
                          }
                        },
                        child: const Icon(
                          Icons.my_location,
                        ),
                      ),
                    ),

                    if (loading || nearbyLoading)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(),
                      ),

                    // Nearby label
                    if (selectedLocation != null && !widget.selectionMode)
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 7,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.radar_outlined,
                                  size: 17,
                                ),
                                const SizedBox(
                                  width: 6,
                                ),
                                Text(
                                  'Within ${_formatRadius(radiusKm)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            buildLegend(),

            if (selectedReport != null || selectedLocation != null) ...[
              const SizedBox(
                height: 12,
              ),
              buildSelectedCard(),
            ],

            const SizedBox(
              height: 24,
            ),

            buildCampusLocations(),

            const SizedBox(
              height: 24,
            ),

            buildMappedReports(),

            const SizedBox(
              height: 24,
            ),
          ],
        ),
      ),
    );
  }
}
