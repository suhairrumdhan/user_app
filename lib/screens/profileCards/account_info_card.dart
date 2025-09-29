import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/AuthController.dart';
import '../../controllers/user_controller.dart';
import 'package:image_picker/image_picker.dart';

class AccountInfoCard extends StatelessWidget {
  const AccountInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final UserController userController = Get.find<UserController>();

    Future<void> _pickImage() async {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        authController.updatePhoto(pickedFile.path); // تحتاج دالة في AuthController
      }
    }

    void _editField(String title, String currentValue, Function(String) onSave) {
      TextEditingController controller = TextEditingController(text: currentValue);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('تعديل $title'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: title),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء')
            ),
            ElevatedButton(
                onPressed: () {
                  onSave(controller.text.trim());
                  Navigator.pop(context);
                },
                child: const Text('حفظ')
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            // ---------- صورة شخصية ----------
            Obx(() {
              final authUser = authController.user.value;
              final photoUrl = authUser?.photoURL;

              return Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[300],
                      backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null
                          ? const Icon(Icons.person, size: 60, color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFF7643),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),

            // ---------- الاسم ----------
            Obx(() {
              final userModel = userController.user.value;
              final authUser = authController.user.value;
              final displayName = (userModel?.name?.isNotEmpty == true
                  ? userModel!.name
                  : authUser?.displayName) ??
                  'مستخدم';

              return GestureDetector(
                onTap: () => _editField('الاسم', displayName, (val) {
                  userController.updateName(val);
                }),
                child: Text(
                  displayName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),

            // ---------- البريد ----------
            Obx(() {
              final userModel = userController.user.value;
              final authUser = authController.user.value;
              final email = (userModel?.email?.isNotEmpty == true
                  ? userModel!.email
                  : authUser?.email) ??
                  'لا يوجد بريد إلكتروني';

              return GestureDetector(
                onTap: () => _editField('البريد الإلكتروني', email, (val) {
                  userController.updateEmail(val);
                }),
                child: Text(
                  email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black.withOpacity(0.6),
                  ),
                ),
              );
            }),

            const SizedBox(height: 8),

            // ---------- تغيير كلمة المرور ----------
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('تغيير كلمة المرور'),
              trailing: const Icon(Icons.edit),
              onTap: () => _editField('كلمة المرور', '', (val) {
                authController.updatePassword(val);
              }),
            ),
          ],
        ),
      ),
    );
  }
}
