import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;
import 'package:exif/exif.dart'; 

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<File> _selectedImages = [];
  bool _isUploading = false;
  double _uploadProgress = 0.0; 

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final List<XFile> pickedFiles = await picker.pickMultiImage(
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85, 
    );

    if (pickedFiles.isNotEmpty) {
      final List<File> newImages = pickedFiles.map((file) => File(file.path)).toList();
      setState(() => _selectedImages.addAll(newImages));
      print('📸 [LOG 0] 사진 선택 완료: ${_selectedImages.length}장 선택됨');
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<String> _getImageTakenDate(File file, int index) async {
    print('🔍 [LOG-EXIF START] ($index번째 사진) 날짜 추출 분석 시작');
    try {
      print('🔍 [LOG-EXIF 1] ($index번째 사진) 파일의 앞부분 128KB 오픈 시도');
      final raf = await file.open(mode: FileMode.read);
      final length = await raf.length();
      final bytesToRead = length < 131072 ? length : 131072; 
      final bytes = await raf.read(bytesToRead);
      await raf.close();
      print('🔍 [LOG-EXIF 2] ($index번째 사진) 128KB 바이트 로드 성공, EXIF 디코딩 시작');

      final tags = await readExifFromBytes(bytes);
      print('🔍 [LOG-EXIF 3] ($index번째 사진) EXIF 디코딩 완료, 태그 매핑 검사');

      if (tags.containsKey('EXIF DateTimeOriginal')) {
        final dateStr = tags['EXIF DateTimeOriginal']!.toString(); 
        print('🔍 [LOG-EXIF 4-A] 원본 촬영일 태그 발견: $dateStr');
        if (dateStr.length >= 10) {
          final datePart = dateStr.substring(0, 10); 
          return datePart.replaceAll(':', '-'); 
        }
      }
      
      if (tags.containsKey('Image DateTime')) {
        final dateStr = tags['Image DateTime']!.toString();
        print('🔍 [LOG-EXIF 4-B] 이미지 수정일 태그 발견: $dateStr');
        if (dateStr.length >= 10) {
          final datePart = dateStr.substring(0, 10);
          return datePart.replaceAll(':', '-');
        }
      }
      print('🔍 [LOG-EXIF 5] ($index번째 사진) 내부에 촬영일 메타데이터 없음');
    } catch (e) {
      print('❌ [LOG-EXIF ERROR] ($index번째 사진) 분석 중 예외 발생: $e');
    }

    final now = DateTime.now();
    print('🔍 [LOG-EXIF END] ($index번째 사진) 정보 없음 -> 오늘 날짜로 결정');
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<void> _uploadImages() async {
    if (_selectedImages.isEmpty) return;
    
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    print('🚀 [LOG 1] 대규모 업로드 프로세스 전역 시작 (총 개수: ${_selectedImages.length}장)');

    try {
      final int totalFiles = _selectedImages.length;

      for (int i = 0; i < totalFiles; i++) {
        print('\n----------------------------------------');
        print('🔄 [LOG 2] 루프 내부 진입 -> 현재 [$i / ${totalFiles - 1}] 번째 이미지 처리 중');
        final File image = _selectedImages[i];
        
        print('📌 [LOG 3] 날짜 추출 함수 호출 직전');
        final String photoDate = await _getImageTakenDate(image, i);
        print('📌 [LOG 4] 날짜 추출 완료 -> 최종 결정된 날짜: $photoDate');

        final String fileName = 'uploads/${DateTime.now().millisecondsSinceEpoch}_$i${path.extension(image.path)}';
        print('📌 [LOG 5] 스토리지 저장 경로 설정 완료: $fileName');
        
        final ref = FirebaseStorage.instance.ref().child(fileName);
        print('📌 [LOG 6] Firebase Storage 참조 객체 생성 완료, 업로드 태스크 시작 직전');
        
        final UploadTask uploadTask = ref.putFile(image);
        print('📌 [LOG 7] putFile 호출 완료 (Task 시작됨)');

        StreamSubscription<TaskSnapshot>? subscription;
        subscription = uploadTask.snapshotEvents.listen(
          (TaskSnapshot snapshot) {
            if (mounted && snapshot.totalBytes > 0) {
              double fileProgress = snapshot.bytesTransferred / snapshot.totalBytes;
              setState(() {
                _uploadProgress = (i + fileProgress) / totalFiles;
              });
              print('📊 [LOG 8-STREAM] 진행률 업데이트 중: P=(${(_uploadProgress * 100).toStringAsFixed(1)}%)');
            }
          },
          onError: (error) {
            print('❌ [LOG 8-STREAM ERROR] 스트림 내부 통신 에러 발생: $error');
          }
        );

        print('📌 [LOG 9] await uploadTask 대기 시작 (스토리지 전송 끝날 때까지 멈춤)');
        await uploadTask;
        print('📌 [LOG 10] await uploadTask 완료! (스토리지 전송 성공)');

        print('📌 [LOG 11] 리스너 스트림 구독 해제 시도');
        await subscription.cancel();
        print('📌 [LOG 12] 리스너 스트림 구독 해제 성공');

        print('📌 [LOG 13] 다운로드 URL 추출 대기 시작');
        final String downloadUrl = await ref.getDownloadURL();
        print('📌 [LOG 14] 다운로드 URL 추출 완료 -> URL: $downloadUrl');

        print('📌 [LOG 15] Firestore 데이터베이스 장부 작성 시도 직전');
        
        // 🔥🔥🔥 [최종 방어막] await를 아예 빼버립니다! (비동기 던져놓기)
        // 파이어스토어가 고장 나서 응답이 없어도 무시하고 루프는 바로 다음 장으로 넘어갑니다.
        FirebaseFirestore.instance.collection('photos').doc().set({
          'url': downloadUrl,
          'date': photoDate, 
          'timestamp': Timestamp.now(), 
        }).then((_) {
          print('✅ [LOG 16-ASYNC] 백그라운드 장부 작성 완료 ($photoDate)');
        }).catchError((e) {
          print('❌ [LOG 16-ERROR] 백그라운드 장부 에러: $e');
        });
        
        print('📌 [LOG 16] Firestore 명령 던져놓고 쿨하게 통과!!!');
        print('🏁 [LOG 17] [$i] 번째 사진 프로세스 완료 -> 다음 사진으로 넘어갑니다!');
        print('----------------------------------------\n');
      }

      print('🎉 [LOG 18] 모든 사진 루프 정상 종료 -> UI 닫기 처리 진행');
      if (mounted) {
        setState(() {
          _uploadProgress = 1.0;
          _isUploading = false;
        });
        Navigator.pop(context); 
      }
    } catch (e) {
      print('🚨 [LOG GLOBAL CRITICAL ERROR] 전역 에러: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('업로드 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('아가 사진 올리셩')),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (_selectedImages.isEmpty) ...[
                    const SizedBox(height: 50),
                    Container(
                      width: double.infinity, height: 250, color: Colors.grey[200], 
                      child: const Icon(Icons.photo_library, size: 80, color: Colors.grey),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity, height: 50, 
                      child: ElevatedButton(
                        onPressed: _pickImages, child: const Text('앨범에서 사진 선택 (여러 장 가능)'),
                      ),
                    ),
                  ] 
                  else ...[
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(), 
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, crossAxisSpacing: 8.0, mainAxisSpacing: 8.0,  
                      ),
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Positioned.fill(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6), 
                                  child: Image.file(_selectedImages[index], fit: BoxFit.cover),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0, right: 0,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                  padding: const EdgeInsets.all(3.0),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 25),
                    Text('선택된 사진: ${_selectedImages.length}장', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 25),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: () => setState(() => _selectedImages = []), 
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                          child: const Text('전체 취소'),
                        ),
                        const SizedBox(width: 25),
                        ElevatedButton(
                          onPressed: _uploadImages, 
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                          child: const Text('올리기'), 
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: _pickImages, child: const Text('사진 추가하기 (+)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (_isUploading)
            Container(
              color: Colors.black.withOpacity(0.4), 
              child: Center(
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 30.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, 
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 60, height: 60,
                              child: CircularProgressIndicator(
                                value: _uploadProgress, 
                                strokeWidth: 5,
                                backgroundColor: Colors.grey[200],
                                color: Colors.blueAccent,
                              ),
                            ),
                            Text(
                              '${(_uploadProgress * 100).toInt()}%',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text('사진 날짜 분석 및 업로드 중...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
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