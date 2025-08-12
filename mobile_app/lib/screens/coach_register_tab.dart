// screens/coach_register_tab.dart
// 修复版：注册时正确设置 Firebase Auth displayName
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'coach_main_navigation_screen.dart'; // 教练主页

class CoachRegisterTab extends StatefulWidget {
  const CoachRegisterTab({super.key});

  @override
  State<CoachRegisterTab> createState() => _CoachRegisterTabState();
}

class _CoachRegisterTabState extends State<CoachRegisterTab> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _certificationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();

  bool _isLoading = false; // ✅ 添加加载状态

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _certificationController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  /// ✅ 修复版注册方法 - 正确设置 displayName
  void _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final phone = _phoneController.text.trim();
    final certification = _certificationController.text.trim();
    final experience = _experienceController.text.trim();

    // 验证输入
    if ([name, email, username, password, confirmPassword, phone, certification, experience].any((e) => e.isEmpty)) {
      _showMessage('Please fill in all fields', isError: true);
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Passwords do not match', isError: true);
      return;
    }

    if (password.length < 6) {
      _showMessage('Password must be at least 6 characters long', isError: true);
      return;
    }

    // 验证邮箱格式
    if (!_isValidEmail(email)) {
      _showMessage('Please enter a valid email address', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('🚀 开始注册教练账户...');
      print('📝 教练姓名: $name');
      print('📧 邮箱: $email');

      // 1. 创建 Firebase Auth 账户
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User user = userCredential.user!;
      print('✅ Firebase Auth 账户创建成功: ${user.uid}');

      // 2. 🔥 关键修复：立即设置 displayName
      await user.updateDisplayName(name);
      await user.reload(); // 重新加载用户数据确保更新生效
      print('✅ Firebase Auth displayName 设置成功: $name');

      // 3. 存储详细信息到 Firestore
      await FirebaseFirestore.instance.collection('coaches').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'username': username,
        'phone': phone,
        'certification': certification,
        'experience': experience,
        'role': 'coach',
        'status': 'pending', // 初始状态为待审核
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Firestore 教练记录创建成功');

      // 4. 显示成功消息
      _showMessage('Registration successful! Welcome, $name!', isError: false);

      // 5. 延迟一下让用户看到成功消息，然后跳转
      await Future.delayed(const Duration(seconds: 1));

      // 6. 跳转到教练主页
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CoachMainNavigationScreen()),
        );
      }

    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth 错误: ${e.code} - ${e.message}');
      String errorMessage;

      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password is too weak';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists for this email';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled';
          break;
        default:
          errorMessage = e.message ?? 'Registration failed';
      }

      _showMessage(errorMessage, isError: true);
    } catch (e) {
      print('❌ 注册过程中发生未知错误: $e');
      _showMessage('Registration failed: ${e.toString()}', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// ✅ 邮箱格式验证
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// ✅ 改进的消息显示方法
  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        duration: Duration(seconds: isError ? 4 : 2),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// ✅ 改进的表单字段构建方法
  Widget _buildFormField(
      String label,
      TextEditingController controller, {
        bool isPassword = false,
        TextInputType keyboardType = TextInputType.text,
        String? hint,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.black, fontSize: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade500),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/2.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.6),
                Colors.black.withOpacity(0.8),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 40),

                // ✅ 标题部分
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    'Coach\nRegister',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                      height: 1.2,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // ✅ 注册表单
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      // 第一行：姓名和邮箱
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              'Your Name:',
                              _nameController,
                              hint: 'Enter your full name',
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: _buildFormField(
                              'Email:',
                              _emailController,
                              keyboardType: TextInputType.emailAddress,
                              hint: 'your@email.com',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      // 第二行：用户名和密码
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              'User Name:',
                              _usernameController,
                              hint: 'Choose a username',
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: _buildFormField(
                              'Password:',
                              _passwordController,
                              isPassword: true,
                              hint: 'At least 6 characters',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      // 第三行：确认密码和电话
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              'Confirm Password:',
                              _confirmPasswordController,
                              isPassword: true,
                              hint: 'Confirm your password',
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: _buildFormField(
                              'Phone Number:',
                              _phoneController,
                              keyboardType: TextInputType.phone,
                              hint: '+60123456789',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      // 第四行：认证和经验
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              'Certification:',
                              _certificationController,
                              hint: 'Your fitness certification',
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: _buildFormField(
                              'Experience (Years):',
                              _experienceController,
                              keyboardType: TextInputType.number,
                              hint: 'Years of experience',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // ✅ 注册按钮
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isLoading
                                ? Colors.grey.shade400
                                : Colors.deepPurple,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)
                            ),
                            elevation: _isLoading ? 0 : 8,
                          ),
                          child: _isLoading
                              ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Creating Account...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                              : const Text(
                            'Register',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ✅ 提示信息
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.blue.shade200.withOpacity(0.3),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.white70,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Your account will be reviewed by the gym administrator',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}