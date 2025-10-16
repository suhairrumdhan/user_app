// image_upload_service.dart
import "package:firebase_storage/firebase_storage.dart";
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class ImageUploadService {
  static final ImageUploadService _instance = ImageUploadService._internal();
  factory ImageUploadService() => _instance;
  ImageUploadService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // اختيار صورة من المعرض
  Future<File?> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      return image != null ? File(image.path) : null;
    } catch (e) {
      print('❌ خطأ في اختيار الصورة: $e');
      return null;
    }
  }

  // التقاط صورة بالكاميرا
  Future<File?> captureImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      return image != null ? File(image.path) : null;
    } catch (e) {
      print('❌ خطأ في التقاط الصورة: $e');
      return null;
    }
  }

  // رفع الصورة إلى Firebase Storage
  Future<String?> uploadProfileImage(File imageFile, String userId) async {
    try {
      print('🔄 جاري رفع الصورة للمستخدم: $userId');

      // إنشاء المرجع للصورة
      final Reference ref = _storage
          .ref()
          .child('user-profile-pictures')
          .child(userId)
          .child('profile.jpg');

      // رفع الملف
      final UploadTask uploadTask = ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'uploadedBy': userId},
        ),
      );

      // متابعة التقدم
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('📊 تقدم رفع الصورة: ${progress.toStringAsFixed(1)}%');
      });

      // انتظار اكتمال الرفع
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      print('✅ تم رفع الصورة بنجاح: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ خطأ في رفع الصورة: $e');
      return null;
    }
  }

  // جلب رابط الصورة
  Future<String?> getProfileImageUrl(String userId) async {
    try {
      final Reference ref = _storage
          .ref()
          .child('user-profile-pictures')
          .child(userId)
          .child('profile.jpg');

      return await ref.getDownloadURL();
    } catch (e) {
      print('❌ لا توجد صورة للمستخدم أو خطأ في الجلب: $e');
      return null;
    }
  }

  // حذف الصورة
  Future<void> deleteProfileImage(String userId) async {
    try {
      final Reference ref = _storage
          .ref()
          .child('user-profile-pictures')
          .child(userId)
          .child('profile.jpg');

      await ref.delete();
      print('✅ تم حذف الصورة بنجاح');
    } catch (e) {
      print('❌ خطأ في حذف الصورة: $e');
    }
  }
}