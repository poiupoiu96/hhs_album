import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // 🔥 입력 제한(포맷터)을 위해 추가된 패키지

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  
  String? _verificationId;

  // 🔥 에러 얼럿(팝업)을 띄우는 함수
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('알림', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(), // 팝업 닫기
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('가족 앨범 로그인')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _verificationId == null ? '사진을 보려면 문자로 인증해주세요 👶' : '문자로 온 6자리 숫자를 입력해주세요 ✉️',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            
            // 1. 번호 입력창
            if (_verificationId == null) ...[
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                // 🔥 숫자만 입력 가능하게 하고, 최대 11자리까지만 입력되도록 제한!
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '휴대폰 번호 (예: 01012345678)',
                  prefixIcon: Icon(Icons.phone),
                  counterText: "", // 글자 수 제한 시 아래에 생기는 숫자 카운터 숨기기
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    String phone = _phoneController.text.trim();
                    
                    // 번호가 너무 짧으면 경고 띄우기
                    if (phone.length < 10) {
                      _showErrorDialog('올바른 휴대폰 번호를 입력해주세요.');
                      return;
                    }

                    if (phone.startsWith('0')) {
                      phone = '+82${phone.substring(1)}';
                    } else if (!phone.startsWith('+82')) {
                      phone = '+82$phone';
                    }

                    await FirebaseAuth.instance.verifyPhoneNumber(
                      phoneNumber: phone,
                      verificationCompleted: (PhoneAuthCredential credential) {},
                      verificationFailed: (FirebaseAuthException e) {
                        _showErrorDialog('인증번호 발송에 실패했습니다.\n다시 시도해주세요.');
                      },
                      codeSent: (String verificationId, int? resendToken) {
                        setState(() {
                          _verificationId = verificationId;
                        });
                      },
                      codeAutoRetrievalTimeout: (String verificationId) {},
                    );
                  },
                  child: const Text('인증번호 받기', style: TextStyle(fontSize: 18)),
                ),
              ),
            ] 
            
            // 2. 인증번호 6자리 입력창
            else ...[
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                // 🔥 숫자만 입력 가능하게 하고, 딱 6자리까지만 입력되도록 제한!
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '인증번호 6자리',
                  prefixIcon: Icon(Icons.message),
                  counterText: "", // 숫자 카운터 숨기기
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    String otp = _otpController.text.trim();
                    
                    if (otp.length != 6) {
                      _showErrorDialog('인증번호 6자리를 모두 입력해주세요.');
                      return;
                    }

                    try {
                      PhoneAuthCredential credential = PhoneAuthProvider.credential(
                        verificationId: _verificationId!,
                        smsCode: otp,
                      );
                      await FirebaseAuth.instance.signInWithCredential(credential);
                      print('로그인 성공!');
                    } catch (e) {
                      // 🔥 인증번호가 틀렸을 때 예쁜 팝업 띄우기
                      _showErrorDialog('인증번호가 틀렸습니다.\n다시 확인해주세요.');
                    }
                  },
                  child: const Text('로그인 하기', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}