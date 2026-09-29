import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';

class CloudinaryFolders {
  CloudinaryFolders._();

  static const String _root = AppConfig.cloudinaryRootFolder;

  static const String avatars = '$_root/avatars';
  static const String posts = '$_root/posts';
  static const String categories = '$_root/categories';
  static const String events = '$_root/events';
  static const String products = '$_root/products';
  static const String gallery = '$_root/gallery';
}

class CloudinaryUploadResult {
  const CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
  });

  final String secureUrl;
  final String publicId;
}

class CloudinaryException implements Exception {
  const CloudinaryException(this.message);
  final String message;

  @override
  String toString() => message;
}

class CloudinaryService {
  CloudinaryService._();
  static final CloudinaryService instance = CloudinaryService._();

  final ImagePicker _picker = ImagePicker();

  static const Duration _timeout = Duration(seconds: 60);

  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) {
    return _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
  }

  Future<List<XFile>> pickMultipleImages({int maxImages = 5}) async {
    if (maxImages <= 0) return <XFile>[];
    final files = await _picker.pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (files.length <= maxImages) return files;
    return files.sublist(0, maxImages);
  }

  Future<CloudinaryUploadResult> uploadImage(
    XFile file, {
    required String folder,
  }) async {
    if (!AppConfig.isCloudinaryConfigured) {
      throw const CloudinaryException(
        'Image upload is not set up yet. Please add the Cloudinary settings.',
      );
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${AppConfig.cloudinaryCloudName}/image/upload',
    );

    final bytes = await file.readAsBytes();

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = AppConfig.cloudinaryUploadPreset
      ..fields['folder'] = folder
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: file.name),
      );

    final http.Response response;
    try {
      final streamed = await request.send().timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const CloudinaryException(
        'Upload timed out. Please check your internet connection and try again.',
      );
    } catch (_) {
      throw const CloudinaryException(
        'Could not reach the image server. Please check your internet connection.',
      );
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = <String, dynamic>{};
    }

    if (response.statusCode != 200) {
      final error = body['error'];
      final message = error is Map && error['message'] != null
          ? error['message'].toString()
          : 'Upload failed (code ${response.statusCode}).';
      throw CloudinaryException('Image upload failed: $message');
    }

    return CloudinaryUploadResult(
      secureUrl: body['secure_url'] as String,
      publicId: body['public_id'] as String,
    );
  }

  Future<CloudinaryUploadResult?> pickAndUpload({
    required String folder,
    ImageSource source = ImageSource.gallery,
  }) async {
    final file = await pickImage(source: source);
    if (file == null) return null;
    return uploadImage(file, folder: folder);
  }

  static String optimizedUrl(String url, {int? width}) {
    if (!url.contains('res.cloudinary.com') || !url.contains('/upload/')) {
      return url;
    }
    final transformation =
        width == null ? 'f_auto,q_auto' : 'f_auto,q_auto,w_$width,c_limit';
    return url.replaceFirst('/upload/', '/upload/$transformation/');
  }
}
