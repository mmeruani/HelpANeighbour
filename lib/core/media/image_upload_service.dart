import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/env.dart';

class ImageUploadService {
  final ImagePicker _picker;
  final http.Client _client;

  ImageUploadService({ImagePicker? picker, http.Client? client})
    : _picker = picker ?? ImagePicker(),
      _client = client ?? http.Client();

  Future<XFile?> pickImageFromGallery() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2048,
    );
  }

  Future<String> uploadImage({
    required XFile file,
    required String folder,
  }) async {
    if (Env.cloudinaryCloudName.trim().isEmpty ||
        Env.cloudinaryUnsignedUploadPreset.trim().isEmpty) {
      throw StateError(
        'Cloudinary не настроен. Заполните cloudinaryCloudName и cloudinaryUnsignedUploadPreset в env.dart.',
      );
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${Env.cloudinaryCloudName.trim()}/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = Env.cloudinaryUnsignedUploadPreset.trim()
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = _extractCloudinaryError(response.body);
      throw StateError(
        _localizedUploadError(message) ??
            'Cloudinary вернул ошибку ${response.statusCode}. Не удалось загрузить изображение.',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final secureUrl = body['secure_url'] as String?;
    if (secureUrl == null || secureUrl.trim().isEmpty) {
      throw const FormatException(
        'Сервис хранения не вернул ссылку на загруженное изображение.',
      );
    }

    return secureUrl.trim();
  }

  String? _extractCloudinaryError(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'] as String?;
        if (message != null && message.trim().isNotEmpty) {
          return message.trim();
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String? _localizedUploadError(String? message) {
    final normalized = message?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final lower = normalized.toLowerCase();
    if (lower.contains('upload preset must be whitelisted') ||
        lower.contains('unsigned uploads')) {
      return 'Загрузка изображения пока недоступна: в Cloudinary не настроен unsigned upload preset. Проверьте настройки пресета.';
    }
    return 'Не удалось загрузить изображение. Проверьте настройки хранилища и попробуйте ещё раз.';
  }
}
