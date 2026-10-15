import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/api_service.dart';
import '../widgets/common.dart';
import '../core/theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchState();
}

class _SearchState extends State<SearchScreen> {
  final TextEditingController q = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  final TextEditingController subcategoryController = TextEditingController();
  final TextEditingController colorController = TextEditingController();
  final TextEditingController brandController = TextEditingController();
  final TextEditingController locationController = TextEditingController();

  Timer? _debounce;

  bool loading = false;
  bool loadingSuggestions = false;
  bool showFilters = false;

  List<dynamic> lost = [];
  List<dynamic> found = [];
  List<dynamic> suggestions = [];

  String mode = 'all';
  String sort = 'newest';

  DateTime? dateFrom;
  DateTime? dateTo;

  static const Color _page = Color(0xFFF3F8F9);
  static const Color _ink = Color(0xFF193C46);
  static const Color _muted = Color(0xFF607780);
  static const Color _teal = Color(0xFF176B73);
  static const Color _blue = Color(0xFF326F9A);
  static const Color _mint = Color(0xFF287D63);
  static const Color _border = Color(0xFFDCE8EB);
  static const Color _paleTeal = Color(0xFFE6F3F3);
  static const Color _paleBlue = Color(0xFFEAF1F9);

  @override
  void initState() {
    super.initState();
    q.addListener(_onQueryChanged);
  }

  void _onQueryChanged() {
    final text = q.text.trim();

    _debounce?.cancel();

    if (text.isEmpty) {
      setState(() {
        suggestions = [];
        lost = [];
        found = [];
      });
      return;
    }

    _debounce = Timer(
      const Duration(milliseconds: 300),
      () {
        loadSuggestions(text);
      },
    );
  }

  Future<void> loadSuggestions(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      loadingSuggestions = true;
    });

    try {
      final result = await ApiService.searchSuggestions(text);

      if (!mounted) return;

      setState(() {
        suggestions = result;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          suggestions = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loadingSuggestions = false;
        });
      }
    }
  }

  Future<void> runSearch([String? searchText]) async {
    final text = (searchText ?? q.text).trim();

    if (text.isEmpty &&
        categoryController.text.trim().isEmpty &&
        subcategoryController.text.trim().isEmpty &&
        colorController.text.trim().isEmpty &&
        brandController.text.trim().isEmpty &&
        locationController.text.trim().isEmpty &&
        dateFrom == null &&
        dateTo == null) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (q.text.trim() != text) {
      q.text = text;
      q.selection = TextSelection.fromPosition(
        TextPosition(offset: q.text.length),
      );
    }

    setState(() {
      loading = true;
      suggestions = [];
    });

    try {
      final r = await ApiService.advancedSearch(
        q: text.isEmpty ? null : text,
        type: mode == 'all' ? null : mode,
        category: _value(categoryController),
        subcategory: _value(subcategoryController),
        color: _value(colorController),
        brand: _value(brandController),
        location: _value(locationController),
        dateFrom: dateFrom,
        dateTo: dateTo,
        sort: sort,
      );

      if (!mounted) return;

      setState(() {
        lost = List<dynamic>.from(r['lost'] ?? []);
        found = List<dynamic>.from(r['found'] ?? []);
      });
    } catch (e) {
      if (mounted) {
        showError(context, ApiService.errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  String? _value(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  void selectSuggestion(String value) {
    q.text = value;
    q.selection = TextSelection.fromPosition(
      TextPosition(offset: q.text.length),
    );
    runSearch(value);
  }

  void clearSearch() {
    q.clear();

    setState(() {
      suggestions = [];
      lost = [];
      found = [];
    });
  }

  void clearFilters() {
    categoryController.clear();
    subcategoryController.clear();
    colorController.clear();
    brandController.clear();
    locationController.clear();

    setState(() {
      dateFrom = null;
      dateTo = null;
      sort = 'newest';
    });
  }

  bool get hasFilters {
    return categoryController.text.trim().isNotEmpty ||
        subcategoryController.text.trim().isNotEmpty ||
        colorController.text.trim().isNotEmpty ||
        brandController.text.trim().isNotEmpty ||
        locationController.text.trim().isNotEmpty ||
        dateFrom != null ||
        dateTo != null ||
        sort != 'newest';
  }

  Future<void> pickDate({required bool from}) async {
    final initialDate = from
        ? (dateFrom ?? DateTime.now())
        : (dateTo ?? dateFrom ?? DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _teal,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _ink,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (from) {
        dateFrom = picked;

        if (dateTo != null && dateTo!.isBefore(picked)) {
          dateTo = picked;
        }
      } else {
        dateTo = picked;

        if (dateFrom != null && picked.isBefore(dateFrom!)) {
          dateFrom = picked;
        }
      }
    });
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Select date';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  void openItem(
    Map<String, dynamic> item, {
    bool foundItem = false,
  }) {
    context.push(
      '/item-details?found=${foundItem ? 'true' : 'false'}',
      extra: item,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    q.removeListener(_onQueryChanged);

    q.dispose();
    categoryController.dispose();
    subcategoryController.dispose();
    colorController.dispose();
    brandController.dispose();
    locationController.dispose();

    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _teal, size: 21),
      filled: true,
      fillColor: const Color(0xFFF8FBFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _teal, width: 1.5),
      ),
      labelStyle: const TextStyle(color: _muted),
      hintStyle: const TextStyle(color: Color(0xFF93A5AB)),
    );
  }

  Widget _sectionHeading({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_paleTeal, _paleBlue],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _teal, size: 21),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _modeChip(String value, String label, IconData icon) {
    final selected = mode == value;

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 17,
        color: selected ? Colors.white : _muted,
      ),
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      backgroundColor: Colors.white,
      selectedColor: _teal,
      side: BorderSide(
        color: selected ? _teal : _border,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : _ink,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      onSelected: (_) {
        setState(() {
          mode = value;
        });

        if (q.text.trim().isNotEmpty || hasFilters) {
          runSearch();
        }
      },
    );
  }

  Widget _dateButton({
    required String label,
    required DateTime? date,
    required VoidCallback onPressed,
  }) {
    final selected = date != null;

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_month_outlined, size: 17),
      label: Text(
        selected ? formatDate(date) : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? _teal : _muted,
        backgroundColor: selected ? _paleTeal : Colors.white,
        side: BorderSide(color: selected ? _teal : _border),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_paleTeal, _paleBlue],
              ),
            ),
            child: Icon(icon, color: _teal, size: 30),
          ),
          const SizedBox(height: 15),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              height: 1.5,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _suggestionsPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.045),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: loadingSuggestions
          ? const Padding(
              padding: EdgeInsets.all(15),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _teal,
                    ),
                  ),
                  SizedBox(width: 11),
                  Text(
                    'Finding suggestions...',
                    style: TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
            )
          : Column(
              children: suggestions.take(8).map((suggestion) {
                final value = suggestion.toString();

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => selectSuggestion(value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _paleTeal,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: _teal,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            value,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.north_west_rounded,
                          size: 16,
                          color: _muted,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = lost.isNotEmpty || found.isNotEmpty;

    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: _page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search items',
              style: TextStyle(
                color: _ink,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Find what belongs on campus',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _border),
              ),
              child: IconButton(
                tooltip: 'Advanced filters',
                onPressed: () {
                  setState(() {
                    showFilters = !showFilters;
                  });
                },
                icon: Badge(
                  isLabelVisible: hasFilters,
                  smallSize: 8,
                  backgroundColor: _mint,
                  child: Icon(
                    showFilters ? Icons.tune_rounded : Icons.tune_outlined,
                    color: _teal,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // SEARCH INTRODUCTION
          Container(
            padding: const EdgeInsets.all(19),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE3F2F0),
                  Color(0xFFEAF2FA),
                  Color(0xFFF7FAFC),
                ],
              ),
              borderRadius: BorderRadius.circular(23),
              border: Border.all(color: Colors.white, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.travel_explore_rounded,
                        color: _teal,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'A little search can reunite you.',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                const Text(
                  'Search campus reports by item name, description, brand or location.',
                  style: TextStyle(
                    color: _muted,
                    height: 1.45,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _border),
                    boxShadow: [
                      BoxShadow(
                        color: _teal.withValues(alpha: 0.055),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: q,
                    onSubmitted: (_) => runSearch(),
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Try “blue water bottle”',
                      hintStyle: const TextStyle(
                        color: Color(0xFF91A4AA),
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _teal,
                        size: 23,
                      ),
                      suffixIcon: q.text.isNotEmpty
                          ? IconButton(
                              onPressed: clearSearch,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: _muted,
                              ),
                            )
                          : IconButton(
                              onPressed: runSearch,
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                color: _teal,
                              ),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: _teal,
                          width: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
                if (q.text.trim().isNotEmpty &&
                    (suggestions.isNotEmpty || loadingSuggestions))
                  _suggestionsPanel(),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // SEARCH TYPE
          _sectionHeading(
            title: 'Explore reports',
            subtitle: 'Choose which campus reports to search.',
            icon: Icons.filter_list_rounded,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 8,
            children: [
              _modeChip('all', 'All items', Icons.grid_view_rounded),
              _modeChip('lost', 'Lost', Icons.search_off_rounded),
              _modeChip('found', 'Found', Icons.inventory_2_outlined),
            ],
          ),

          // ADVANCED FILTERS
          if (showFilters) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: _ink.withValues(alpha: 0.035),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _paleTeal,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: _teal,
                        ),
                      ),
                      const SizedBox(width: 11),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Advanced filters',
                              style: TextStyle(
                                color: _ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Narrow down your search',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasFilters)
                        TextButton(
                          onPressed: clearFilters,
                          child: const Text(
                            'Clear all',
                            style: TextStyle(
                              color: _teal,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: categoryController,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      label: 'Category',
                      hint: 'e.g. Electronics',
                      icon: Icons.category_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: subcategoryController,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      label: 'Subcategory',
                      hint: 'e.g. Mobile phone',
                      icon: Icons.account_tree_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: colorController,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      label: 'Color',
                      hint: 'e.g. Black',
                      icon: Icons.palette_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: brandController,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      label: 'Brand',
                      hint: 'e.g. Samsung',
                      icon: Icons.branding_watermark_outlined,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: locationController,
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      label: 'Location',
                      hint: 'e.g. Library',
                      icon: Icons.location_on_outlined,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Date range',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: _dateButton(
                          label: 'From',
                          date: dateFrom,
                          onPressed: () => pickDate(from: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dateButton(
                          label: 'To',
                          date: dateTo,
                          onPressed: () => pickDate(from: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: sort,
                    decoration: _fieldDecoration(
                      label: 'Sort results',
                      hint: 'Choose order',
                      icon: Icons.sort_rounded,
                    ),
                    dropdownColor: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    items: const [
                      DropdownMenuItem(
                        value: 'newest',
                        child: Text('Newest first'),
                      ),
                      DropdownMenuItem(
                        value: 'oldest',
                        child: Text('Oldest first'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        sort = value;
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: loading ? null : () => runSearch(),
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Apply filters'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _teal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 22),

          // LOADING
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: Center(
                child: CircularProgressIndicator(
                  color: _teal,
                  strokeWidth: 2.5,
                ),
              ),
            ),

          // NO RESULTS
          if (!loading &&
              (q.text.trim().isNotEmpty || hasFilters) &&
              !hasResults)
            _emptyState(
              icon: Icons.search_off_rounded,
              title: 'No matching reports yet',
              subtitle:
                  'Try a different keyword, location or date range to discover more campus reports.',
            ),

          // LOST RESULTS
          if (!loading && mode != 'found' && lost.isNotEmpty) ...[
            _sectionHeading(
              title: 'Lost items',
              subtitle:
                  '${lost.length} report${lost.length == 1 ? '' : 's'} found',
              icon: Icons.search_rounded,
            ),
            const SizedBox(height: 12),
            ...lost.map((x) {
              final item = Map<String, dynamic>.from(x);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ItemCard(
                  item: item,
                  onTap: () => openItem(item),
                ),
              );
            }),
          ],

          // FOUND RESULTS
          if (!loading && mode != 'lost' && found.isNotEmpty) ...[
            if (lost.isNotEmpty) const SizedBox(height: 12),
            _sectionHeading(
              title: 'Found items',
              subtitle:
                  '${found.length} report${found.length == 1 ? '' : 's'} found',
              icon: Icons.inventory_2_outlined,
            ),
            const SizedBox(height: 12),
            ...found.map((x) {
              final item = Map<String, dynamic>.from(x);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ItemCard(
                  item: item,
                  found: true,
                  onTap: () => openItem(
                    item,
                    foundItem: true,
                  ),
                ),
              );
            }),
          ],

          // EMPTY SEARCH STATE
          if (!loading && q.text.trim().isEmpty && !hasFilters)
            _emptyState(
              icon: Icons.travel_explore_rounded,
              title: 'What are you looking for?',
              subtitle:
                  'Search by item name or description, or open advanced filters to narrow results by category, brand, color, location and date.',
            ),
        ],
      ),
      bottomNavigationBar: BottomNav(
        index: 1,
        onTap: (i) {
          if (i == 0) {
            context.go('/');
          }

          if (i == 2) {
            context.go('/report');
          }

          if (i == 3) {
            context.go('/matches');
          }

          if (i == 4) {
            context.go('/profile');
          }
        },
      ),
    );
  }
}
