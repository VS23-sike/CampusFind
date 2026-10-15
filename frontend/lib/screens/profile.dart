import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/api_service.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'settings.dart';

const Color _ink = Color(0xFF193C46);
const Color _muted = Color(0xFF607780);
const Color _teal = Color(0xFF176B73);
const Color _blue = Color(0xFF326F9A);
const Color _mint = Color(0xFF287D63);
const Color _page = Color(0xFFF2F7F8);
const Color _border = Color(0xFFDCE8EB);
const Color _card = Colors.white;

String _pdfValue(dynamic value, {String fallback = 'Not available'}) {
  if (value == null) return fallback;
  final result = value.toString().trim();
  if (result.isEmpty || result.toLowerCase() == 'null') return fallback;
  return result;
}

Map<String, dynamic> _pdfMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String _firstValue(Map<String, dynamic> map, List<String> keys,
    {String fallback = 'Not available'}) {
  for (final key in keys) {
    final value = _pdfValue(map[key], fallback: '');
    if (value.isNotEmpty) return value;
  }
  return fallback;
}

String _pdfDate(dynamic value) {
  if (value == null) return 'Not available';
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return _pdfValue(value);
  final date = parsed.toLocal();
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _reportTitle(Map<String, dynamic> report) {
  final item =
      _pdfMap(report['item'] ?? report['lost_item'] ?? report['found_item']);
  return _firstValue(
    report,
    ['title', 'item_title', 'item_name'],
    fallback: _firstValue(item, ['title', 'item_title', 'item_name'],
        fallback: 'Untitled item'),
  );
}

String _reportType(Map<String, dynamic> report) {
  final type = _firstValue(
    report,
    ['type', 'report_type', 'item_type'],
    fallback: '',
  ).toLowerCase();
  if (type.contains('lost') || report.containsKey('date_lost')) return 'Lost';
  if (type.contains('found') || report.containsKey('date_found'))
    return 'Found';
  return 'Report';
}

String _reportLocation(Map<String, dynamic> report) {
  final item =
      _pdfMap(report['item'] ?? report['lost_item'] ?? report['found_item']);
  return _firstValue(
    report,
    ['location', 'last_seen_location', 'found_location'],
    fallback: _firstValue(item, ['location', 'last_seen_location'],
        fallback: 'Not available'),
  );
}

String _reportStatus(Map<String, dynamic> report) =>
    _firstValue(report, ['status', 'report_status'], fallback: 'Not available')
        .replaceAll('_', ' ')
        .toUpperCase();

String _reportDescription(Map<String, dynamic> report) {
  return _firstValue(report, [
    'description',
    'item_description',
    'details',
    'additional_details',
  ]);
}

String _reportId(Map<String, dynamic> report) =>
    _firstValue(report, ['id', 'report_id', 'lost_item_id', 'found_item_id']);

String _claimTitle(Map<String, dynamic> claim) {
  final item =
      _pdfMap(claim['item'] ?? claim['found_item'] ?? claim['foundItem']);
  return _firstValue(
    claim,
    ['item_title', 'title', 'item_name'],
    fallback: _firstValue(item, ['title', 'item_title', 'item_name'],
        fallback: 'Found item'),
  );
}

String _claimLocation(Map<String, dynamic> claim) {
  final item =
      _pdfMap(claim['item'] ?? claim['found_item'] ?? claim['foundItem']);
  return _firstValue(
    claim,
    ['location', 'found_location'],
    fallback: _firstValue(item, ['location', 'found_location']),
  );
}

String _claimStatus(Map<String, dynamic> claim) =>
    _firstValue(claim, ['status'], fallback: 'Pending')
        .replaceAll('_', ' ')
        .toUpperCase();

String _claimId(Map<String, dynamic> claim) =>
    _firstValue(claim, ['id', 'claim_id']);

String _claimNote(Map<String, dynamic> claim) =>
    _firstValue(claim, ['admin_notes', 'admin_note', 'review_note'],
        fallback: '');

String _claimDate(Map<String, dynamic> claim) =>
    _pdfDate(claim['submitted_at'] ?? claim['created_at'] ?? claim['date']);

Future<void> _generatePersonalPdf({
  required String name,
  required String email,
  required List<dynamic> reports,
  required List<dynamic> claims,
}) async {
  final pdf = pw.Document();
  final normalizedReports = reports
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  final normalizedClaims =
      claims.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

  final lostCount =
      normalizedReports.where((r) => _reportType(r) == 'Lost').length;
  final foundCount =
      normalizedReports.where((r) => _reportType(r) == 'Found').length;
  final approvedClaims =
      normalizedClaims.where((c) => _claimStatus(c) == 'APPROVED').length;
  final pendingClaims = normalizedClaims
      .where((c) =>
          _claimStatus(c) == 'PENDING' || _claimStatus(c) == 'UNDER REVIEW')
      .length;
  final rejectedClaims =
      normalizedClaims.where((c) => _claimStatus(c) == 'REJECTED').length;

  final headingColor = PdfColor.fromHex('#193C46');
  final borderColor = PdfColor.fromHex('#DCE8EB');

  pw.Widget sectionHeading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 9),
        child: pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: headingColor,
          ),
        ),
      );

  pw.Widget detailLine(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: '$label: ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.TextSpan(text: value),
            ],
          ),
        ),
      );

  pw.Widget detailCard(String title, List<List<String>> details,
      {String accent = '#326F9A'}) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor),
        borderRadius: pw.BorderRadius.circular(7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex(accent),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          ...details.map((row) => detailLine(row[0], row[1])),
        ],
      ),
    );
  }

  pw.Widget summaryCard(String label, String value) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#F2F7F8'),
            border: pw.Border.all(color: borderColor),
            borderRadius: pw.BorderRadius.circular(7),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: headingColor)),
            ],
          ),
        ),
      );

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 42),
      header: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.only(bottom: 8),
        child: pw.Text(
          'CAMPUSFIND • PERSONAL ACTIVITY REPORT',
          style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
              fontWeight: pw.FontWeight.bold),
        ),
      ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'CampusFind  •  Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (context) {
        final widgets = <pw.Widget>[
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#174F61'),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('CampusFind',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 25,
                        fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Text('Personal Activity Report',
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 13)),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Generated on ${_pdfDate(DateTime.now().toIso8601String())}',
                  style:
                      const pw.TextStyle(color: PdfColors.white, fontSize: 9),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          sectionHeading('Account Details'),
          detailLine('Name', name),
          if (email.isNotEmpty) detailLine('Email', email),
          pw.SizedBox(height: 12),
          sectionHeading('Activity Summary'),
          pw.Row(children: [
            summaryCard('Total reports', '${normalizedReports.length}'),
            pw.SizedBox(width: 8),
            summaryCard('Lost reports', '$lostCount'),
            pw.SizedBox(width: 8),
            summaryCard('Found reports', '$foundCount'),
          ]),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            summaryCard('Total claims', '${normalizedClaims.length}'),
            pw.SizedBox(width: 8),
            summaryCard('Approved', '$approvedClaims'),
            pw.SizedBox(width: 8),
            summaryCard('Pending / review', '$pendingClaims'),
            pw.SizedBox(width: 8),
            summaryCard('Rejected', '$rejectedClaims'),
          ]),
          pw.SizedBox(height: 22),
          sectionHeading('My Submitted Reports'),
        ];

        if (normalizedReports.isEmpty) {
          widgets.add(pw.Text('No submitted reports were found.'));
        } else {
          for (var i = 0; i < normalizedReports.length; i++) {
            final report = normalizedReports[i];
            final dateLost = _pdfDate(report['date_lost']);
            final dateFound = _pdfDate(report['date_found']);
            final submitted = _pdfDate(
              report['created_at'] ??
                  report['submitted_at'] ??
                  report['createdAt'],
            );
            final details = <List<String>>[
              ['Report ID', _reportId(report)],
              ['Type', _reportType(report)],
              ['Status', _reportStatus(report)],
              ['Location', _reportLocation(report)],
              ['Description', _reportDescription(report)],
              ['Date lost', dateLost],
              ['Date found', dateFound],
              ['Submitted on', submitted],
              [
                'Category',
                _firstValue(report, ['category', 'item_category'])
              ],
            ];
            widgets.add(detailCard(
              '${i + 1}. ${_reportTitle(report)}',
              details,
              accent: _reportType(report) == 'Lost' ? '#B65C36' : '#287D63',
            ));
          }
        }

        widgets.addAll([
          pw.SizedBox(height: 16),
          sectionHeading('My Claims'),
        ]);

        if (normalizedClaims.isEmpty) {
          widgets.add(pw.Text('No claims were found.'));
        } else {
          for (var i = 0; i < normalizedClaims.length; i++) {
            final claim = normalizedClaims[i];
            final note = _claimNote(claim);
            final details = <List<String>>[
              ['Claim ID', _claimId(claim)],
              ['Item', _claimTitle(claim)],
              ['Location', _claimLocation(claim)],
              ['Status', _claimStatus(claim)],
              ['Submitted on', _claimDate(claim)],
              if (note.isNotEmpty) ['Administrator note', note],
            ];
            widgets.add(detailCard(
              '${i + 1}. Claim — ${_claimTitle(claim)}',
              details,
              accent: '#7654A6',
            ));
          }
        }

        widgets.addAll([
          pw.SizedBox(height: 15),
          pw.Divider(color: borderColor),
          pw.SizedBox(height: 6),
          pw.Text(
            'This report contains the reports and claims returned for the signed-in CampusFind account. Fields not provided by the service are marked “Not available”.',
            style: const pw.TextStyle(
                fontSize: 8, color: PdfColors.grey700, lineSpacing: 2),
          ),
        ]);
        return widgets;
      },
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) async => pdf.save(),
    name: 'CampusFind_Personal_Report.pdf',
  );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends State<ProfileScreen> {
  Map<String, dynamic>? me;
  List<dynamic> claims = [];
  List<dynamic> reports = [];
  bool loading = true;
  bool generatingReport = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() => loading = true);
    Map<String, dynamic>? profile;
    List<dynamic> loadedClaims = [];
    List<dynamic> loadedReports = [];

    try {
      profile = await ApiService.me();
    } catch (e) {
      if (mounted) showError(context, ApiService.errorMessage(e));
    }
    try {
      loadedClaims = await ApiService.claims();
    } catch (_) {}
    try {
      loadedReports = await ApiService.myReports();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      me = profile;
      claims = loadedClaims;
      reports = loadedReports;
      loading = false;
    });
  }

  String cleanValue(dynamic value) {
    if (value == null) return '';
    final result = value.toString().trim();
    return result.isEmpty || result.toLowerCase() == 'null' ? '' : result;
  }

  String profileValue(List<String> keys) {
    if (me == null) return '';
    for (final key in keys) {
      final value = cleanValue(me![key]);
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  String get role {
    final value = profileValue(['role', 'user_role']);
    return value.isEmpty ? 'student' : value.toLowerCase();
  }

  String get fullName {
    final value =
        profileValue(['full_name', 'name', 'display_name', 'username']);
    return value.isEmpty ? 'CampusFind Member' : value;
  }

  String get email => profileValue(['college_email', 'email', 'email_address']);
  String get phone => profileValue([
        'phone_number',
        'phone',
        'mobile_number',
        'mobile',
        'contact_number',
        'contact'
      ]);
  String get institutionId => profileValue([
        'student_staff_id',
        'student_id',
        'staff_id',
        'college_id',
        'institution_id',
        'roll_number',
        'employee_id'
      ]);
  String get department =>
      profileValue(['department', 'branch', 'course_department']);
  String get year =>
      profileValue(['year', 'academic_year', 'study_year', 'semester_year']);

  String prettyRole(String value) {
    if (value.isEmpty) return 'Member';
    return value
        .split(RegExp(r'[_\s-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }

  Future<void> generatePersonalReport() async {
    if (generatingReport) return;
    setState(() => generatingReport = true);
    try {
      var ownReports = reports;
      var ownClaims = claims;
      var profile = me;
      try {
        ownReports = await ApiService.myReports();
      } catch (_) {}
      try {
        ownClaims = await ApiService.claims();
      } catch (_) {}
      try {
        profile = await ApiService.me();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        reports = ownReports;
        claims = ownClaims;
        me = profile;
      });
      await _generatePersonalPdf(
        name: fullName,
        email: email,
        reports: ownReports,
        claims: ownClaims,
      );
    } catch (_) {
      if (mounted) {
        showError(context, 'Could not generate the PDF. Please try again.');
      }
    } finally {
      if (mounted) setState(() => generatingReport = false);
    }
  }

  Future<void> editProfile() async {
    if (me == null) return;
    final nameController = TextEditingController(
        text: fullName == 'CampusFind Member' ? '' : fullName);
    final phoneController = TextEditingController(text: phone);
    final idController = TextEditingController(text: institutionId);
    final departmentController = TextEditingController(text: department);
    final yearController = TextEditingController(text: year);
    bool saving = false;

    try {
      await showDialog(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Edit Profile',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w800)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _editField(nameController, 'Full name', Icons.person_outline),
                const SizedBox(height: 12),
                _editField(
                    phoneController, 'Phone number', Icons.phone_outlined,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _editField(
                    idController, 'Student / Staff ID', Icons.badge_outlined),
                const SizedBox(height: 12),
                _editField(
                    departmentController, 'Department', Icons.school_outlined),
                const SizedBox(height: 12),
                _editField(
                    yearController, 'Year', Icons.calendar_today_outlined),
              ]),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel', style: TextStyle(color: _muted)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _teal),
                onPressed: saving
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Name cannot be empty.')),
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          final updated = await ApiService.updateProfile({
                            'full_name': name,
                            'phone_number': phoneController.text.trim(),
                            'student_staff_id': idController.text.trim(),
                            'department': departmentController.text.trim(),
                            'year': yearController.text.trim(),
                          });
                          if (!mounted) return;
                          setState(
                              () => me = Map<String, dynamic>.from(updated));
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                                content: Text('Profile updated successfully.')),
                          );
                        } catch (e) {
                          setDialogState(() => saving = false);
                          if (mounted) {
                            showError(this.context, ApiService.errorMessage(e));
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save changes'),
              ),
            ],
          ),
        ),
      );
    } finally {
      nameController.dispose();
      phoneController.dispose();
      idController.dispose();
      departmentController.dispose();
      yearController.dispose();
    }
  }

  Widget _editField(
      TextEditingController controller, String label, IconData icon,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _teal),
        filled: true,
        fillColor: _page,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _teal, width: 1.5)),
      ),
    );
  }

  Future<void> logout() async {
    await ApiService.logout();
    if (mounted) context.go('/login');
  }

  Widget sectionTitle(String title, {String? subtitle}) => Padding(
        padding: const EdgeInsets.only(left: 3, bottom: 11),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  letterSpacing: -0.3)),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: _muted)),
          ],
        ]),
      );

  Widget profileInfoRow(IconData icon, String label, String value,
      {bool missing = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: const Color(0xFFEAF4F5),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 19, color: _teal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    color: _muted, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    color: missing ? _muted : _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget activityCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required VoidCallback onTap,
    String? count,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF23434B).withOpacity(0.035),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: accent, size: 23),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: const TextStyle(
                              color: _muted, fontSize: 12, height: 1.35)),
                    ]),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                      color: accent.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(count,
                      style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ),
              ],
              const SizedBox(width: 5),
              const Icon(Icons.chevron_right_rounded, color: _muted, size: 22),
            ]),
          ),
        ),
      ),
    );
  }

  Widget generateReportCard() => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF174F61), Color(0xFF326F9A)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: _blue.withOpacity(0.16),
                blurRadius: 16,
                offset: const Offset(0, 5)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: generatingReport ? null : generatePersonalReport,
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Row(children: [
                Container(
                  width: 47,
                  height: 47,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14)),
                  child: generatingReport
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.picture_as_pdf_rounded,
                          color: Colors.white, size: 24),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            generatingReport
                                ? 'Preparing your report…'
                                : 'Generate My Report',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 5),
                        const Text(
                            'Create a PDF of your submitted reports and claims',
                            style: TextStyle(
                                color: Color(0xFFE5F1F7),
                                fontSize: 12,
                                height: 1.4)),
                      ]),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 21),
              ]),
            ),
          ),
        ),
      );

  Future<void> confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Log out?',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to log out of CampusFind?',
            style: TextStyle(color: _muted, height: 1.45)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFAE3943)),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Log Out')),
        ],
      ),
    );
    if (confirm == true) await logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: _page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          onPressed: () => context.go('/'),
        ),
        title: const Text('My Profile',
            style: TextStyle(
                color: _ink, fontWeight: FontWeight.w800, fontSize: 20)),
        actions: [
          IconButton(
              tooltip: 'Edit profile',
              onPressed: loading ? null : editProfile,
              icon: const Icon(Icons.edit_outlined, color: _teal)),
          const SizedBox(width: 5),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : RefreshIndicator(
              color: _teal,
              onRefresh: load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF174F61),
                            Color(0xFF176B73),
                            Color(0xFF328A84)
                          ]),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                            color: _teal.withOpacity(0.18),
                            blurRadius: 22,
                            offset: const Offset(0, 10))
                      ],
                    ),
                    child: Stack(children: [
                      Positioned(
                        right: -25,
                        top: -40,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.055)),
                        ),
                      ),
                      Positioned(
                        left: -35,
                        bottom: -55,
                        child: Container(
                          width: 135,
                          height: 135,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.045)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.60),
                                    width: 1.5)),
                            child: CircleAvatar(
                              radius: 39,
                              backgroundColor: Colors.white.withOpacity(0.16),
                              child: const Icon(Icons.person_rounded,
                                  size: 43, color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(fullName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4)),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(email,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.84),
                                    fontSize: 12)),
                          ],
                          const SizedBox(height: 13),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 7),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.25))),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.verified_user_outlined,
                                  color: Color(0xFFD9F6E9), size: 15),
                              const SizedBox(width: 6),
                              Text(prettyRole(role).toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1)),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 25),
                  sectionTitle('Personal Information',
                      subtitle: 'Your campus account details'),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                    decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _border),
                        boxShadow: [
                          BoxShadow(
                              color: _ink.withOpacity(0.025),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ]),
                    child: Column(children: [
                      if (email.isNotEmpty)
                        profileInfoRow(Icons.alternate_email_rounded,
                            'College Email', email),
                      if (email.isNotEmpty)
                        const Divider(height: 1, color: _border),
                      profileInfoRow(Icons.phone_rounded, 'Phone Number',
                          phone.isNotEmpty ? phone : 'Add your phone number',
                          missing: phone.isEmpty),
                      if (institutionId.isNotEmpty) ...[
                        const Divider(height: 1, color: _border),
                        profileInfoRow(
                            Icons.badge_outlined,
                            role == 'admin' ? 'Staff ID' : 'Student / Staff ID',
                            institutionId),
                      ],
                      if (department.isNotEmpty) ...[
                        const Divider(height: 1, color: _border),
                        profileInfoRow(
                            Icons.school_outlined, 'Department', department),
                      ],
                      if (year.isNotEmpty) ...[
                        const Divider(height: 1, color: _border),
                        profileInfoRow(
                            Icons.calendar_month_rounded, 'Year', year),
                      ],
                      if (email.isEmpty &&
                          institutionId.isEmpty &&
                          department.isEmpty &&
                          year.isEmpty &&
                          phone.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 17),
                          child: Text(
                              'Add your account details using Edit Profile.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: _muted, fontSize: 13, height: 1.4)),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 25),
                  sectionTitle('My Activity',
                      subtitle: 'Keep track of your reports and claims'),
                  activityCard(
                    icon: Icons.description_outlined,
                    title: 'My Reports',
                    subtitle: 'View and manage your submitted reports',
                    accent: _blue,
                    count: '${reports.length}',
                    onTap: () async {
                      await context.push('/my-reports');
                      if (mounted) await load();
                    },
                  ),
                  activityCard(
                    icon: Icons.verified_user_outlined,
                    title: 'My Claims',
                    subtitle: 'Track your claim and review status',
                    accent: const Color(0xFF7654A6),
                    count: '${claims.length}',
                    onTap: () async {
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MyClaimsScreen()));
                      if (mounted) await load();
                    },
                  ),
                  generateReportCard(),
                  activityCard(
                    icon: Icons.auto_awesome_rounded,
                    title: 'AI Matches',
                    subtitle: 'View potential matches for your reports',
                    accent: _teal,
                    onTap: () => context.push('/matches'),
                  ),
                  const SizedBox(height: 15),
                  sectionTitle('Communication',
                      subtitle: 'Stay connected with your campus community'),
                  activityCard(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    subtitle: 'Alerts, matches and claim updates',
                    accent: const Color(0xFFB77922),
                    onTap: () => context.push('/notifications'),
                  ),
                  activityCard(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'Messages',
                    subtitle: 'Chat with other CampusFind users',
                    accent: _blue,
                    onTap: () => context.push('/messages'),
                  ),
                  const SizedBox(height: 15),
                  if (role == 'admin') ...[
                    sectionTitle('Administration',
                        subtitle: 'CampusFind management tools'),
                    activityCard(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Admin Dashboard',
                      subtitle: 'Manage reports, claims and users',
                      accent: _teal,
                      onTap: () => context.push('/admin'),
                    ),
                    const SizedBox(height: 15),
                  ],
                  sectionTitle('Account',
                      subtitle: 'Manage your preferences and access'),
                  activityCard(
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    subtitle: 'Notifications, security and preferences',
                    accent: _blue,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen())),
                  ),
                  activityCard(
                    icon: Icons.edit_outlined,
                    title: 'Edit Profile',
                    subtitle: 'Update your personal information',
                    accent: _mint,
                    onTap: editProfile,
                  ),
                  activityCard(
                    icon: Icons.logout_rounded,
                    title: 'Log Out',
                    subtitle: 'Sign out of your CampusFind account',
                    accent: const Color(0xFFAE3943),
                    onTap: confirmLogout,
                  ),
                  const SizedBox(height: 22),
                  Center(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              color: _mint, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const Text('CampusFind',
                          style: TextStyle(
                              color: _ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4)),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text('Lost something? Find it on campus.',
                        style: TextStyle(color: _muted, fontSize: 11)),
                  ),
                  const SizedBox(height: 15),
                ],
              ),
            ),
      bottomNavigationBar: BottomNav(
        index: 4,
        onTap: (i) {
          if (i == 0) context.go('/');
          if (i == 1) context.go('/search');
          if (i == 2) context.go('/report');
          if (i == 3) context.go('/matches');
        },
      ),
    );
  }
}

class MyClaimsScreen extends StatefulWidget {
  const MyClaimsScreen({super.key});

  @override
  State<MyClaimsScreen> createState() => _MyClaimsScreenState();
}

class _MyClaimsScreenState extends State<MyClaimsScreen> {
  bool loading = true;
  List<dynamic> claims = [];

  @override
  void initState() {
    super.initState();
    loadClaims();
  }

  Future<void> loadClaims() async {
    if (mounted) setState(() => loading = true);
    try {
      final result = await ApiService.claims();
      if (!mounted) return;
      setState(() {
        claims = List<dynamic>.from(result);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      showError(context, ApiService.errorMessage(e));
    }
  }

  String textValue(dynamic value, {String fallback = 'Not available'}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  Map<String, dynamic> mapValue(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  String getStatus(dynamic claim) {
    if (claim is! Map) return 'pending';
    return textValue(claim['status'], fallback: 'pending').toLowerCase();
  }

  String statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'APPROVED';
      case 'rejected':
        return 'REJECTED';
      case 'under_review':
      case 'under review':
        return 'UNDER REVIEW';
      case 'pending':
        return 'PENDING';
      default:
        return status.toUpperCase();
    }
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF17603A);
      case 'rejected':
        return const Color(0xFFA52834);
      case 'pending':
        return const Color(0xFF895400);
      case 'under_review':
      case 'under review':
        return const Color(0xFF2457A6);
      default:
        return _muted;
    }
  }

  Color statusBackground(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFFDDF3E4);
      case 'rejected':
        return const Color(0xFFFCE7E8);
      case 'pending':
        return const Color(0xFFFFF0D2);
      case 'under_review':
      case 'under review':
        return const Color(0xFFE5EDFF);
      default:
        return const Color(0xFFEDF1F3);
    }
  }

  IconData statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.verified_rounded;
      case 'rejected':
        return Icons.cancel_outlined;
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'under_review':
      case 'under review':
        return Icons.manage_search_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  String claimItemTitle(Map<String, dynamic> claim) {
    final item =
        mapValue(claim['item'] ?? claim['found_item'] ?? claim['foundItem']);
    return textValue(claim['item_title'] ?? claim['title'] ?? item['title'],
        fallback: 'Found item');
  }

  String claimItemLocation(Map<String, dynamic> claim) {
    final item =
        mapValue(claim['item'] ?? claim['found_item'] ?? claim['foundItem']);
    return textValue(claim['location'] ?? item['location'],
        fallback: 'Location not available');
  }

  String claimDate(Map<String, dynamic> claim) =>
      textValue(claim['submitted_at'] ?? claim['created_at'] ?? claim['date'],
          fallback: 'Date not available');

  String adminNote(Map<String, dynamic> claim) => textValue(
      claim['admin_notes'] ?? claim['admin_note'] ?? claim['review_note'],
      fallback: '');

  Widget statusBadge(String status) {
    final foreground = statusColor(status);
    final background = statusBackground(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: foreground.withOpacity(0.14))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(statusIcon(status), size: 14, color: foreground),
        const SizedBox(width: 6),
        Text(statusLabel(status),
            style: TextStyle(
                color: foreground,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.45)),
      ]),
    );
  }

  Widget claimCard(Map<String, dynamic> claim) {
    final status = getStatus(claim);
    final title = claimItemTitle(claim);
    final location = claimItemLocation(claim);
    final date = claimDate(claim);
    final note = adminNote(claim);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
                color: _ink.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 5))
          ]),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 49,
              height: 49,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFE2F2F3), Color(0xFFF0F7FA)]),
                  borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.verified_user_outlined,
                  color: _teal, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    statusBadge(status),
                  ]),
            ),
          ]),
          const SizedBox(height: 19),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.location_on_outlined, size: 18, color: _teal),
            const SizedBox(width: 8),
            Expanded(
                child: Text(location,
                    style: const TextStyle(
                        color: _ink, fontSize: 13, height: 1.4))),
          ]),
          const SizedBox(height: 11),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: _muted),
            const SizedBox(width: 9),
            Expanded(
                child: Text('Submitted: $date',
                    style: const TextStyle(
                        color: _muted, fontSize: 12, height: 1.4))),
          ]),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 15),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F6F8),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _border)),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: _blue),
                const SizedBox(width: 9),
                Expanded(
                    child: Text(note,
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 12,
                            height: 1.45,
                            fontWeight: FontWeight.w500))),
              ]),
            ),
          ],
          if (status == 'pending' ||
              status == 'under_review' ||
              status == 'under review') ...[
            const SizedBox(height: 15),
            _claimMessage(
                const Color(0xFF895400),
                const Color(0xFFFFF6E4),
                Icons.schedule_rounded,
                'Your claim is awaiting admin review. You do not need to submit another claim for this item.'),
          ],
          if (status == 'approved') ...[
            const SizedBox(height: 15),
            _claimMessage(
                const Color(0xFF17603A),
                const Color(0xFFE8F6EC),
                Icons.check_circle_outline_rounded,
                'Your claim has been approved. You can continue with the recovery process and communicate with the finder.'),
          ],
          if (status == 'rejected') ...[
            const SizedBox(height: 15),
            _claimMessage(
                const Color(0xFFA52834),
                const Color(0xFFFCEDEE),
                Icons.info_outline_rounded,
                'This claim was rejected by the administrator. Check the review note above for more information.'),
          ],
        ]),
      ),
    );
  }

  Widget _claimMessage(
      Color foreground, Color background, IconData icon, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(13)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: foreground),
        const SizedBox(width: 9),
        Expanded(
            child: Text(message,
                style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w600))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: _page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back to Profile',
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('My Claims',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
              tooltip: 'Refresh claims',
              onPressed: loading ? null : loadClaims,
              icon: const Icon(Icons.refresh_rounded, color: _teal)),
          const SizedBox(width: 5),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : claims.isEmpty
              ? RefreshIndicator(
                  color: _teal,
                  onRefresh: loadClaims,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(25),
                    children: [
                      const SizedBox(height: 75),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                            color: const Color(0xFFE2F1F3),
                            borderRadius: BorderRadius.circular(30)),
                        child: const Icon(Icons.verified_user_outlined,
                            size: 47, color: _teal),
                      ),
                      const SizedBox(height: 22),
                      const Text('No claims yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: _ink,
                              fontSize: 21,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 9),
                      const Text(
                          'When you submit a claim for a matching found item, your claim and its review status will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: _muted, height: 1.55, fontSize: 13)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: _teal,
                  onRefresh: loadClaims,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: claims.length,
                    itemBuilder: (context, index) {
                      final raw = claims[index];
                      final claim = raw is Map
                          ? Map<String, dynamic>.from(raw)
                          : <String, dynamic>{};
                      return claimCard(claim);
                    },
                  ),
                ),
    );
  }
}
