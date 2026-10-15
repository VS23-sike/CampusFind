import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../core/theme.dart';
import '../services/api_service.dart';
import '../widgets/common.dart';
import 'campus_map.dart';

class ReportScreen extends StatefulWidget {
  final String? type;

  const ReportScreen({
    super.key,
    this.type,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final itemController = TextEditingController();
  final otherCategoryController = TextEditingController();
  final colorController = TextEditingController();
  final brandController = TextEditingController();
  final descriptionController = TextEditingController();
  final locationController = TextEditingController();
  final campusController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<XFile> selectedImages = [];

  DateTime selectedDate = DateTime.now();

  bool loading = false;
  String? selectedCategory;
  String uploadStatus = '';

  double? selectedLatitude;
  double? selectedLongitude;

  static const Color _page = Color(0xFFF3F8F9);
  static const Color _ink = Color(0xFF193C46);
  static const Color _muted = Color(0xFF607780);
  static const Color _teal = Color(0xFF176B73);
  static const Color _blue = Color(0xFF326F9A);
  static const Color _mint = Color(0xFF287D63);

  static const Color _lostRed = Color(0xFFD9534F);
  static const Color _foundGreen = Color(0xFF287D63);

  static const Color _border = Color(0xFFDCE8EB);
  static const Color _paleTeal = Color(0xFFE6F3F3);
  static const Color _paleBlue = Color(0xFFEAF1F9);

  final List<String> categories = [
    'Accessories',
    'Electronics',
    'Stationery',
    'Documents',
    'Clothing',
    'Keys',
    'ID / Cards',
    'Bags',
    'Books',
    'Other',
  ];

  String get reportType => widget.type == 'found' ? 'found' : 'lost';

  bool get isTypeSelected => widget.type == 'lost' || widget.type == 'found';

  bool get isFound => reportType == 'found';

  Color get reportAccent => isFound ? _foundGreen : _lostRed;

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  void dispose() {
    itemController.dispose();
    otherCategoryController.dispose();
    colorController.dispose();
    brandController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    campusController.dispose();
    super.dispose();
  }

  InputDecoration _decoration({
    required String label,
    String? hint,
    required IconData icon,
    String? helper,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      prefixIcon: Icon(icon, color: reportAccent, size: 21),
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: const Color(0xFFFAFCFD),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: reportAccent, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _border),
      ),
      labelStyle: const TextStyle(
        color: _muted,
        fontSize: 13,
      ),
      hintStyle: const TextStyle(
        color: Color(0xFF9AAAB0),
        fontSize: 13,
      ),
      helperStyle: const TextStyle(
        color: _muted,
        fontSize: 11,
        height: 1.4,
      ),
    );
  }

  Widget _sectionCard({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(17),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.035),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle({
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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_paleTeal, _paleBlue],
            ),
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Icon(icon, color: reportAccent, size: 21),
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
                  fontSize: 16,
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
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: reportAccent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _ink,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> selectCampusLocation() async {
    if (loading) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CampusMapScreen(
          selectionMode: true,
        ),
      ),
    );

    if (result is! Map || !mounted) return;

    setState(() {
      final locationName = result['location_name']?.toString() ?? '';
      final building = result['campus_building']?.toString() ?? '';

      if (locationName.isNotEmpty) {
        locationController.text = locationName;
      }

      if (building.isNotEmpty) {
        campusController.text = building;
      }

      final latitude = result['latitude'];
      final longitude = result['longitude'];

      if (latitude is num) {
        selectedLatitude = latitude.toDouble();
      }

      if (longitude is num) {
        selectedLongitude = longitude.toDouble();
      }
    });
  }

  Future<void> pickImages() async {
    if (selectedImages.length >= 5) {
      showError(context, 'You can upload a maximum of 5 photos.');
      return;
    }

    try {
      final remaining = 5 - selectedImages.length;

      final images = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (images.isEmpty || !mounted) return;

      final availableImages = images.take(remaining).toList();

      setState(() => selectedImages.addAll(availableImages));

      if (images.length > remaining && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maximum 5 photos can be selected.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        showError(context, 'Unable to select photos.');
      }
    }
  }

  Future<void> takePhoto() async {
    if (selectedImages.length >= 5) {
      showError(context, 'You can upload a maximum of 5 photos.');
      return;
    }

    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (image == null || !mounted) return;

      setState(() => selectedImages.add(image));
    } catch (_) {
      if (mounted) {
        showError(context, 'Unable to open camera.');
      }
    }
  }

  void removeImage(int index) {
    setState(() => selectedImages.removeAt(index));
  }

  void showImageOptions() {
    if (loading) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add photos',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose how you want to add item photos.',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _photoOption(
                  icon: Icons.photo_library_outlined,
                  title: 'Choose from gallery',
                  subtitle: 'Select multiple photos',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    pickImages();
                  },
                ),
                const SizedBox(height: 10),
                _photoOption(
                  icon: Icons.camera_alt_outlined,
                  title: 'Take a photo',
                  subtitle: 'Use your camera',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    takePhoto();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _photoOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _page,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: _paleTeal,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: reportAccent, size: 23),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: _muted,
            ),
          ],
        ),
      ),
    );
  }

  String get finalCategory {
    if (selectedCategory == 'Other') {
      return otherCategoryController.text.trim();
    }

    return selectedCategory ?? '';
  }

  Future<void> submitReport() async {
    if (itemController.text.trim().isEmpty) {
      showError(context, 'Please enter the item name.');
      return;
    }

    if (selectedCategory == null) {
      showError(context, 'Please select a category.');
      return;
    }

    if (selectedCategory == 'Other' &&
        otherCategoryController.text.trim().isEmpty) {
      showError(context, 'Please enter the item category.');
      return;
    }

    if (descriptionController.text.trim().isEmpty) {
      showError(context, 'Please enter a description.');
      return;
    }

    if (locationController.text.trim().isEmpty) {
      showError(context, 'Please enter or select the location.');
      return;
    }

    if (campusController.text.trim().isEmpty) {
      showError(context, 'Please enter or select the campus/building.');
      return;
    }

    setState(() {
      loading = true;
      uploadStatus = 'Creating report...';
    });

    try {
      final formattedDate = '${selectedDate.year.toString().padLeft(4, '0')}-'
          '${selectedDate.month.toString().padLeft(2, '0')}-'
          '${selectedDate.day.toString().padLeft(2, '0')}';

      final Map<String, dynamic> data = {
        'title': itemController.text.trim(),
        'category': finalCategory,
        'description': descriptionController.text.trim(),
        'color': colorController.text.trim().isEmpty
            ? null
            : colorController.text.trim(),
        'brand': brandController.text.trim().isEmpty
            ? null
            : brandController.text.trim(),
        'location_name': locationController.text.trim(),
        'campus_building': campusController.text.trim(),
        'contact_preference': 'chat',
      };

      if (selectedLatitude != null) {
        data['latitude'] = selectedLatitude;
      }

      if (selectedLongitude != null) {
        data['longitude'] = selectedLongitude;
      }

      if (isFound) {
        data['date_found'] = formattedDate;
      } else {
        data['date_lost'] = formattedDate;
      }

      late final Map<String, dynamic> createdItem;

      if (isFound) {
        createdItem = await ApiService.createFound(data);
      } else {
        createdItem = await ApiService.createLost(data);
      }

      final itemId = createdItem['item_id']?.toString();

      if (itemId == null || itemId.isEmpty) {
        throw Exception(
          'Report was created, but the item ID was not returned.',
        );
      }

      if (selectedImages.isNotEmpty) {
        setState(() {
          uploadStatus = 'Uploading ${selectedImages.length} photo'
              '${selectedImages.length == 1 ? '' : 's'}...';
        });

        // XFile is supported on Flutter Web and Android.
        // ApiService must accept List<XFile> and upload image bytes.
        if (isFound) {
          await ApiService.uploadFoundPhotos(itemId, selectedImages);
        } else {
          await ApiService.uploadLostPhotos(itemId, selectedImages);
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFound
                ? 'Found item reported successfully!'
                : 'Lost item reported successfully!',
          ),
        ),
      );

      context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() => uploadStatus = '');
        showError(context, ApiService.errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Widget buildPhotoSection(bool foundItem) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          title: 'Item photos',
          subtitle: foundItem
              ? 'Clear photos can help the owner identify their item.'
              : 'Photos can help improve the chances of finding a match.',
          icon: Icons.add_a_photo_outlined,
        ),
        const SizedBox(height: 15),
        if (selectedImages.isNotEmpty)
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: selectedImages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final image = selectedImages[index];

                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: FutureBuilder<Uint8List>(
                        future: image.readAsBytes(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Container(
                              width: 112,
                              height: 112,
                              color: _page,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: _muted,
                                size: 28,
                              ),
                            );
                          }

                          if (!snapshot.hasData) {
                            return Container(
                              width: 112,
                              height: 112,
                              color: _page,
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }

                          return Image.memory(
                            snapshot.data!,
                            width: 112,
                            height: 112,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: loading ? null : () => removeImage(index),
                          child: const SizedBox(
                            width: 29,
                            height: 29,
                            child: Icon(
                              Icons.close_rounded,
                              size: 17,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        if (selectedImages.isNotEmpty) const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed:
              loading || selectedImages.length >= 5 ? null : showImageOptions,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(
            selectedImages.isEmpty
                ? 'Add photos'
                : 'Add more photos (${selectedImages.length}/5)',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: reportAccent,
            backgroundColor: reportAccent.withValues(alpha: 0.06),
            side: BorderSide(color: reportAccent.withValues(alpha: 0.4)),
            minimumSize: const Size(double.infinity, 51),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 14,
              color: _muted,
            ),
            const SizedBox(width: 6),
            Text(
              '${selectedImages.length} of 5 photos selected',
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        if (uploadStatus.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _paleBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: reportAccent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    uploadStatus,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _reportTypeCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(19),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.16),
                Colors.white,
              ],
            ),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 20, color: color),
            ],
          ),
        ),
      ),
    );
  }

  Widget _introBanner({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool foundItem,
  }) {
    final accent = foundItem ? _foundGreen : _lostRed;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE0F1EF),
            Color(0xFFE9F1FA),
            Color(0xFFF6FAFB),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: accent, size: 25),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateSelector() {
    final dateText = '${selectedDate.day.toString().padLeft(2, '0')}/'
        '${selectedDate.month.toString().padLeft(2, '0')}/'
        '${selectedDate.year}';

    return InkWell(
      onTap: loading ? null : selectDate,
      borderRadius: BorderRadius.circular(15),
      child: InputDecorator(
        decoration: _decoration(
          label: isFound ? 'Date found' : 'Date lost',
          icon: Icons.calendar_month_outlined,
          helper: 'Choose the date the item was lost or found.',
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                dateText,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              Icons.edit_calendar_outlined,
              color: reportAccent,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _locationPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Where did it happen?',
                style: TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: loading ? null : selectCampusLocation,
              icon: const Icon(Icons.map_outlined, size: 17),
              label: const Text('Choose on map'),
              style: OutlinedButton.styleFrom(
                foregroundColor: reportAccent,
                backgroundColor: reportAccent.withValues(alpha: 0.06),
                side: BorderSide(
                  color: reportAccent.withValues(alpha: 0.4),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: locationController,
          enabled: !loading,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: _decoration(
            label: 'Specific location',
            hint: 'e.g. Near Library, 2nd floor, Room 204',
            icon: Icons.place_outlined,
            helper: 'Type a precise location or choose one on the map.',
          ),
          onChanged: (_) {
            if (selectedLatitude != null || selectedLongitude != null) {
              setState(() {
                selectedLatitude = null;
                selectedLongitude = null;
              });
            }
          },
        ),
        const SizedBox(height: 14),
        TextField(
          controller: campusController,
          enabled: !loading,
          textCapitalization: TextCapitalization.words,
          decoration: _decoration(
            label: 'Campus / Building',
            hint: 'e.g. APSIT Main Building',
            icon: Icons.school_outlined,
            helper: 'Enter the campus or building name.',
          ),
        ),
      ],
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 15,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isTypeSelected) {
      return Scaffold(
        backgroundColor: _page,
        appBar: AppBar(
          backgroundColor: _page,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            color: _ink,
            onPressed: _goBack,
          ),
          title: const Text(
            'Report an item',
            style: TextStyle(
              color: _ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE1F2EF),
                    Color(0xFFEAF1FA),
                    Color(0xFFF8FBFC),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 51,
                    height: 51,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.volunteer_activism_outlined,
                      color: _teal,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 19),
                  const Text(
                    'Every item has a way home.',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      height: 1.18,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Choose what happened, and we’ll guide you through reporting it.',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'What would you like to report?',
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Select the option that best describes your situation.',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 17),
            _reportTypeCard(
              icon: Icons.search_rounded,
              title: 'I lost something',
              description:
                  'Report a missing item so others can help you find a match.',
              color: _lostRed,
              onTap: () => context.push('/report?type=lost'),
            ),
            const SizedBox(height: 13),
            _reportTypeCard(
              icon: Icons.inventory_2_outlined,
              title: 'I found something',
              description:
                  'Report an item you found so its owner can identify it.',
              color: _foundGreen,
              onTap: () => context.push('/report?type=found'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Keep track of your activity',
              style: TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Return to these areas whenever you need to follow up.',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 13),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _quickAction(
                  icon: Icons.folder_open_outlined,
                  title: 'My Reports',
                  subtitle: 'Review your submitted items',
                  color: _teal,
                  onTap: () => context.go('/profile'),
                ),
                const SizedBox(width: 12),
                _quickAction(
                  icon: Icons.auto_awesome_outlined,
                  title: 'AI Matches',
                  subtitle: 'Look for possible matches',
                  color: _blue,
                  onTap: () => context.go('/matches'),
                ),
              ],
            ),
            const SizedBox(height: 19),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.auto_awesome_outlined,
                    color: _blue,
                    size: 21,
                  ),
                  SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      'Adding clear details and photos helps CampusFind identify possible matches.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: _page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          color: _ink,
          onPressed: loading ? null : _goBack,
        ),
        title: Text(
          isFound ? 'Report found item' : 'Report lost item',
          style: const TextStyle(
            color: _ink,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(17, 10, 17, 28),
        children: [
          _introBanner(
            title: isFound ? 'Found something?' : 'Lost something?',
            subtitle: isFound
                ? 'Help reunite an item with its owner. Add accurate details so they can recognise it.'
                : 'Tell us what went missing. Clear details and photos help improve the chances of a match.',
            icon: isFound
                ? Icons.volunteer_activism_outlined
                : Icons.search_rounded,
            foundItem: isFound,
          ),
          const SizedBox(height: 21),
          _sectionCard(child: buildPhotoSection(isFound)),
          const SizedBox(height: 15),
          _sectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(
                  title: 'Item details',
                  subtitle: 'Describe the item so it can be identified.',
                  icon: Icons.inventory_2_outlined,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: itemController,
                  enabled: !loading,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration(
                    label: 'Item name',
                    hint: 'e.g. Black water bottle',
                    icon: Icons.sell_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: _decoration(
                    label: 'Category',
                    icon: Icons.category_outlined,
                  ),
                  hint: const Text(
                    'Select item category',
                    style: TextStyle(fontSize: 13),
                  ),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  items: categories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: loading
                      ? null
                      : (value) {
                          setState(() {
                            selectedCategory = value;
                            if (value != 'Other') {
                              otherCategoryController.clear();
                            }
                          });
                        },
                ),
                if (selectedCategory == 'Other') ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: otherCategoryController,
                    enabled: !loading,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _decoration(
                      label: 'Specify category',
                      hint: 'e.g. Sports equipment',
                      icon: Icons.edit_outlined,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: colorController,
                  enabled: !loading,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration(
                    label: 'Colour',
                    hint: 'e.g. Black',
                    icon: Icons.palette_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: brandController,
                  enabled: !loading,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration(
                    label: 'Brand',
                    hint: 'e.g. Milton',
                    icon: Icons.branding_watermark_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: descriptionController,
                  enabled: !loading,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _decoration(
                    label: 'Description',
                    hint: 'Describe the item and identifying details',
                    icon: Icons.description_outlined,
                    alignLabelWithHint: true,
                    helper: 'Include distinctive marks, patterns or features.',
                  ),
                ),
                const SizedBox(height: 17),
                _dateSelector(),
              ],
            ),
          ),
          const SizedBox(height: 15),
          _sectionCard(child: _locationPicker()),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _paleTeal.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFFD0E8E6)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: _teal,
                  size: 19,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Please check your item details and location before submitting.',
                    style: TextStyle(
                      color: _ink,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 54,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: loading
                      ? const [Color(0xFF789B9E), Color(0xFF789B9E)]
                      : [reportAccent, reportAccent.withValues(alpha: 0.82)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: loading
                    ? []
                    : [
                        BoxShadow(
                          color: reportAccent.withValues(alpha: 0.18),
                          blurRadius: 13,
                          offset: const Offset(0, 5),
                        ),
                      ],
              ),
              child: ElevatedButton.icon(
                onPressed: loading ? null : submitReport,
                icon: loading
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  loading
                      ? 'Submitting report...'
                      : isFound
                          ? 'Submit found item'
                          : 'Submit lost item',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
