import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';

class ApiService {
  static const baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  static const storage = FlutterSecureStorage();

  // ============================================================
  // INITIALIZATION
  // ============================================================

  static Future<void> init() async {
    final token = await storage.read(key: 'token');

    if (token != null) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  // ============================================================
  // AUTH
  // ============================================================

  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final r = await dio.post(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    await _saveAuth(r.data);
    return Map<String, dynamic>.from(r.data);
  }

  static Future<Map<String, dynamic>> register(
    Map<String, dynamic> data,
  ) async {
    final r = await dio.post('/auth/register', data: data);
    await _saveAuth(r.data);
    return Map<String, dynamic>.from(r.data);
  }

  static Future<void> _saveAuth(Map data) async {
    final token = data['access_token'];

    if (token != null) {
      await storage.write(key: 'token', value: token.toString());
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  static Future<void> logout() async {
    await storage.delete(key: 'token');
    dio.options.headers.remove('Authorization');
  }

  static Future<bool> hasToken() async {
    return (await storage.read(key: 'token')) != null;
  }

  // ============================================================
  // USER
  // ============================================================

  static Future<Map<String, dynamic>> me() async {
    final r = await dio.get('/users/me');
    return Map<String, dynamic>.from(r.data);
  }

  static Future<List<dynamic>> myReports() async {
    final r = await dio.get('/users/me/reports');
    return List<dynamic>.from(r.data);
  }

  static Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data,
  ) async {
    final r = await dio.put('/users/me', data: data);
    return Map<String, dynamic>.from(r.data);
  }

  // ============================================================
  // LOST ITEMS
  // ============================================================

  static Future<List<dynamic>> lost({int size = 20}) async {
    final r = await dio.get(
      '/lost-items',
      queryParameters: {'size': size},
    );

    return List<dynamic>.from(r.data['items'] ?? []);
  }

  static Future<Map<String, dynamic>> createLost(
    Map<String, dynamic> data,
  ) async {
    final r = await dio.post('/lost-items', data: data);
    return Map<String, dynamic>.from(r.data);
  }

  static Future<void> deleteLost(String itemId) async {
    await dio.delete('/lost-items/$itemId');
  }

  // ============================================================
  // FOUND ITEMS
  // ============================================================

  static Future<List<dynamic>> found({int size = 20}) async {
    final r = await dio.get(
      '/found-items',
      queryParameters: {'size': size},
    );

    return List<dynamic>.from(r.data['items'] ?? []);
  }

  static Future<Map<String, dynamic>> createFound(
    Map<String, dynamic> data,
  ) async {
    final r = await dio.post('/found-items', data: data);
    return Map<String, dynamic>.from(r.data);
  }

  static Future<void> deleteFound(String itemId) async {
    await dio.delete('/found-items/$itemId');
  }

  // ============================================================
  // PHOTO UPLOADS — WEB + ANDROID
  // ============================================================

  static Future<Map<String, dynamic>> uploadLostPhotos(
    String itemId,
    List<XFile> images,
  ) async {
    return _uploadPhotos('/lost-items/$itemId/photos', images);
  }

  static Future<Map<String, dynamic>> uploadFoundPhotos(
    String itemId,
    List<XFile> images,
  ) async {
    return _uploadPhotos('/found-items/$itemId/photos', images);
  }

  static Future<Map<String, dynamic>> _uploadPhotos(
    String endpoint,
    List<XFile> images,
  ) async {
    final formData = FormData();

    for (final image in images) {
      final bytes = await image.readAsBytes();

      formData.files.add(
        MapEntry(
          'files',
          MultipartFile.fromBytes(
            bytes,
            filename: image.name,
          ),
        ),
      );
    }

    final r = await dio.post(
      endpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return Map<String, dynamic>.from(r.data);
  }

  // ============================================================
  // SEARCH
  // ============================================================

  static Future<Map<String, dynamic>> search(String q) async {
    final r = await dio.get('/search', queryParameters: {'q': q});
    return Map<String, dynamic>.from(r.data);
  }

  static Future<List<dynamic>> searchSuggestions(String q) async {
    if (q.trim().isEmpty) return [];

    final r = await dio.get(
      '/search/suggestions',
      queryParameters: {'q': q.trim()},
    );

    return List<dynamic>.from(r.data['suggestions'] ?? []);
  }

  static Future<Map<String, dynamic>> smartSearch(String q) async {
    final r = await dio.get('/search/smart', queryParameters: {'q': q});
    return Map<String, dynamic>.from(r.data);
  }

  // ============================================================
  // ADVANCED SEARCH
  // ============================================================

  static Future<Map<String, dynamic>> advancedSearch({
    String? q,
    String? type,
    String? category,
    String? subcategory,
    String? color,
    String? brand,
    String? location,
    DateTime? dateFrom,
    DateTime? dateTo,
    String sort = 'newest',
  }) async {
    final params = <String, dynamic>{};

    if (q != null && q.trim().isNotEmpty) params['q'] = q.trim();
    if (type != null && type.isNotEmpty && type != 'all') {
      params['type'] = type;
    }
    if (category != null && category.isNotEmpty) {
      params['category'] = category;
    }
    if (subcategory != null && subcategory.isNotEmpty) {
      params['subcategory'] = subcategory;
    }
    if (color != null && color.isNotEmpty) params['color'] = color;
    if (brand != null && brand.isNotEmpty) params['brand'] = brand;
    if (location != null && location.isNotEmpty) {
      params['location'] = location;
    }
    if (dateFrom != null) params['date_from'] = _formatDate(dateFrom);
    if (dateTo != null) params['date_to'] = _formatDate(dateTo);

    params['sort'] = sort;

    final r = await dio.get(
      '/search/advanced',
      queryParameters: params,
    );

    return Map<String, dynamic>.from(r.data);
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  // ============================================================
  // NEARBY SEARCH
  // ============================================================

  static Future<Map<String, dynamic>> nearbySearch({
    required double latitude,
    required double longitude,
    double radiusKm = 1.0,
    String? type,
    String? category,
    String? query,
  }) async {
    final params = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'radius_km': radiusKm,
    };

    if (type != null && type.isNotEmpty && type != 'all') {
      params['type'] = type;
    }
    if (category != null && category.isNotEmpty) {
      params['category'] = category;
    }
    if (query != null && query.trim().isNotEmpty) {
      params['q'] = query.trim();
    }

    try {
      final r = await dio.get(
        '/search/nearby',
        queryParameters: params,
      );
      return Map<String, dynamic>.from(r.data);
    } on DioException catch (e) {
      throw Exception(errorMessage(e));
    }
  }

  // ============================================================
  // MATCHES
  // ============================================================

  static Future<List<dynamic>> matches() async {
    final r = await dio.get('/matches');
    return List<dynamic>.from(r.data);
  }

  // ============================================================
  // CLAIMS
  // ============================================================

  static Future<Map<String, dynamic>> claim(
    Map<String, dynamic> data,
  ) async {
    final r = await dio.post('/claims', data: data);
    return Map<String, dynamic>.from(r.data);
  }

  static Future<List<dynamic>> claims() async {
    final r = await dio.get('/claims');
    return List<dynamic>.from(r.data);
  }

  static Future<Map<String, dynamic>> getClaim(String claimId) async {
    final r = await dio.get('/claims/$claimId');
    return Map<String, dynamic>.from(r.data);
  }

  static Future<Map<String, dynamic>> updateClaim(
    String claimId,
    Map<String, dynamic> data,
  ) async {
    final r = await dio.put('/claims/$claimId', data: data);
    return Map<String, dynamic>.from(r.data);
  }

  // ============================================================
  // MESSAGES
  // ============================================================

  static Future<List<dynamic>> conversations() async {
    final r = await dio.get('/messages/conversations');
    return List<dynamic>.from(r.data);
  }

  static Future<List<dynamic>> conversationMessages(
    String userId, {
    String? itemId,
  }) async {
    late Response r;

    if (itemId != null && itemId.isNotEmpty) {
      r = await dio.get('/messages/conversations/$userId/$itemId');
    } else {
      r = await dio.get('/messages/conversations/$userId');
    }

    return List<dynamic>.from(r.data);
  }

  static Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    required String message,
    String? itemId,
    String? itemType,
  }) async {
    final data = <String, dynamic>{
      'receiver_id': receiverId,
      'message_text': message,
    };

    if (itemId != null && itemId.isNotEmpty) {
      data['related_item_id'] = itemId;
    }
    if (itemType != null && itemType.isNotEmpty) {
      data['related_item_type'] = itemType;
    }

    final r = await dio.post('/messages', data: data);
    return Map<String, dynamic>.from(r.data);
  }

  static Future<void> markConversationRead(
    String userId, {
    String? itemId,
  }) async {
    await dio.put(
      '/messages/conversations/$userId/read',
      queryParameters: itemId == null ? null : {'item_id': itemId},
    );
  }

  static Future<Map<String, dynamic>> deleteMessage(
    String messageId,
  ) async {
    final r = await dio.delete('/messages/$messageId');
    return Map<String, dynamic>.from(r.data);
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  static Future<List<dynamic>> notifications() async {
    final r = await dio.get('/notifications');
    return List<dynamic>.from(r.data);
  }

  static Future<int> notificationUnreadCount() async {
    final r = await dio.get('/notifications/unread-count');
    return (r.data['unread_count'] ?? 0) as int;
  }

  static Future<Map<String, dynamic>> markNotificationRead(
    String notificationId,
  ) async {
    final r = await dio.put('/notifications/$notificationId/read');
    return Map<String, dynamic>.from(r.data);
  }

  static Future<Map<String, dynamic>> markAllNotificationsRead() async {
    final r = await dio.put('/notifications/read-all');
    return Map<String, dynamic>.from(r.data);
  }

  static Future<Map<String, dynamic>> deleteNotification(
    String notificationId,
  ) async {
    final r = await dio.delete('/notifications/$notificationId');
    return Map<String, dynamic>.from(r.data);
  }

  // ============================================================
  // ADMIN - DASHBOARD
  // ============================================================

  static Future<Map<String, dynamic>> adminDashboard() async {
    final r = await dio.get('/admin/dashboard');
    return Map<String, dynamic>.from(r.data);
  }

  // ============================================================
  // ADMIN - CLAIMS
  // ============================================================

  static Future<List<dynamic>> adminClaims() async {
    final r = await dio.get('/claims/admin/all');
    return List<dynamic>.from(r.data);
  }

  static Future<Map<String, dynamic>> reviewClaim(
    String claimId,
    String status, {
    String? adminNotes,
  }) async {
    final r = await dio.put(
      '/claims/$claimId/review',
      data: {
        'status': status,
        'admin_notes': adminNotes,
      },
    );
    return Map<String, dynamic>.from(r.data);
  }

  static Future<Map<String, dynamic>> reviewAdminClaim(
    String claimId,
    String status,
  ) async {
    return reviewClaim(claimId, status);
  }

  // ============================================================
  // ADMIN - USER MANAGEMENT
  // ============================================================

  static Future<List<dynamic>> adminUsers({
    String? search,
    String? status,
    String? role,
  }) async {
    final params = <String, dynamic>{};

    if (search != null && search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (role != null && role.isNotEmpty) params['role'] = role;

    final r = await dio.get(
      '/admin/users',
      queryParameters: params.isEmpty ? null : params,
    );
    return List<dynamic>.from(r.data);
  }

  static Future<Map<String, dynamic>> adminUser(String userId) async {
    final r = await dio.get('/admin/users/$userId');
    return Map<String, dynamic>.from(r.data);
  }

  static Future<Map<String, dynamic>> updateAdminUserStatus(
    String userId,
    String status,
  ) async {
    final r = await dio.put(
      '/admin/users/$userId/status',
      queryParameters: {'status': status},
    );
    return Map<String, dynamic>.from(r.data);
  }

  static Future<Map<String, dynamic>> updateAdminUserRole(
    String userId,
    String role,
  ) async {
    final r = await dio.put(
      '/admin/users/$userId/role',
      queryParameters: {'role': role},
    );
    return Map<String, dynamic>.from(r.data);
  }

  static Future<Map<String, dynamic>> deleteAdminUser(String userId) async {
    final r = await dio.delete('/admin/users/$userId');
    return Map<String, dynamic>.from(r.data);
  }

  // ============================================================
  // ADMIN - ITEMS
  // ============================================================

  static Future<List<dynamic>> adminLostItems({
    String? status,
    String? category,
    String? location,
  }) async {
    final params = <String, dynamic>{};

    if (status != null && status.isNotEmpty && status != 'all') {
      params['status'] = status;
    }
    if (category != null && category.trim().isNotEmpty) {
      params['category'] = category.trim();
    }
    if (location != null && location.trim().isNotEmpty) {
      params['location'] = location.trim();
    }

    final r = await dio.get(
      '/admin/lost-items',
      queryParameters: params.isEmpty ? null : params,
    );
    return List<dynamic>.from(r.data);
  }

  static Future<List<dynamic>> adminFoundItems({
    String? status,
    String? category,
    String? location,
  }) async {
    final params = <String, dynamic>{};

    if (status != null && status.isNotEmpty && status != 'all') {
      params['status'] = status;
    }
    if (category != null && category.trim().isNotEmpty) {
      params['category'] = category.trim();
    }
    if (location != null && location.trim().isNotEmpty) {
      params['location'] = location.trim();
    }

    final r = await dio.get(
      '/admin/found-items',
      queryParameters: params.isEmpty ? null : params,
    );
    return List<dynamic>.from(r.data);
  }

  static Future<List<dynamic>> adminItems() async {
    final lostItems = await adminLostItems();
    final foundItems = await adminFoundItems();
    return [...lostItems, ...foundItems];
  }

  static Future<Map<String, dynamic>> moderateItem({
    required String itemId,
    required String itemType,
    required String action,
  }) async {
    final r = await dio.put(
      '/admin/items/$itemId/moderate',
      queryParameters: {
        'action': action,
        'item_type': itemType,
      },
    );
    return Map<String, dynamic>.from(r.data);
  }

  static Future<Map<String, dynamic>> updateAdminItemStatus(
    String itemId,
    String status,
  ) async {
    final r = await dio.put(
      '/admin/items/$itemId/moderate',
      queryParameters: {'action': status},
    );
    return Map<String, dynamic>.from(r.data);
  }

  // ============================================================
  // ADMIN - REPORTS
  // ============================================================

  static Future<List<dynamic>> adminReports({
    String? status,
    String? reportType,
  }) async {
    final params = <String, dynamic>{};

    if (status != null && status.isNotEmpty && status != 'all') {
      params['status'] = status;
    }
    if (reportType != null && reportType.isNotEmpty) {
      params['report_type'] = reportType;
    }

    final r = await dio.get(
      '/admin/reports',
      queryParameters: params.isEmpty ? null : params,
    );
    return List<dynamic>.from(r.data);
  }

  static Future<Map<String, dynamic>> updateAdminReport(
    String reportId,
    String status,
  ) async {
    final r = await dio.put(
      '/admin/reports/$reportId',
      queryParameters: {'status': status},
    );
    return Map<String, dynamic>.from(r.data);
  }

  // ============================================================
  // ADMIN - ANALYTICS
  // ============================================================

  static Future<Map<String, dynamic>> adminAnalytics() async {
    final r = await dio.get('/admin/analytics');
    return Map<String, dynamic>.from(r.data);
  }

  // ============================================================
  // ADMIN - AUDIT LOGS
  // ============================================================

  static Future<List<dynamic>> adminAuditLogs() async {
    final r = await dio.get('/admin/audit-logs');
    return List<dynamic>.from(r.data);
  }

  // ============================================================
  // ADMIN - ANNOUNCEMENTS
  // ============================================================

  static Future<Map<String, dynamic>> createAnnouncement(
    String message,
  ) async {
    final r = await dio.post(
      '/admin/announcements',
      queryParameters: {'message': message},
    );
    return Map<String, dynamic>.from(r.data);
  }

  // ============================================================
  // ERROR HANDLING
  // ============================================================

  static String errorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;

      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }

      return e.message ?? 'Network error';
    }

    return e.toString().replaceFirst('Exception: ', '');
  }
}
