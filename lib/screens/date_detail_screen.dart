import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

class DateDetailScreen extends StatelessWidget {
  final String date;
  final List<String> urls;

  const DateDetailScreen({super.key, required this.date, required this.urls});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$date 사진첩', style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(2.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,     
          crossAxisSpacing: 2.0, 
          mainAxisSpacing: 2.0,  
        ),
        itemCount: urls.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            // 🔥 사진을 터치하면 전체화면 클래스로 슉 넘어갑니다!
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenImageScreen(
                    imageUrl: urls[index], 
                    date: date,
                  ),
                ),
              );
            },
            child: CachedNetworkImage(
              imageUrl: urls[index],
              fit: BoxFit.cover, 
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.error, color: Colors.grey),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// 🔥 새로 추가된 화면: 사진 전체화면 및 줌인/줌아웃 & 저장 기능
// ==========================================
class FullScreenImageScreen extends StatefulWidget {
  final String imageUrl;
  final String date;

  const FullScreenImageScreen({super.key, required this.imageUrl, required this.date});

  @override
  State<FullScreenImageScreen> createState() => _FullScreenImageScreenState();
}

class _FullScreenImageScreenState extends State<FullScreenImageScreen> {
  bool _isSaving = false;

  // 📸 기기에 사진을 다운로드하고 갤러리에 저장하는 함수
  Future<void> _saveImageToGallery() async {
    setState(() => _isSaving = true);
    
    try {
      // 1. Dio 패키지를 써서 이미지 URL의 데이터를 바이트(Byte) 단위로 싹 긁어옵니다.
      var response = await Dio().get(
        widget.imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      // 2. 긁어온 데이터를 스마트폰 갤러리에 'ruvibe_날짜시간' 이름으로 쾅 저장합니다.
      final result = await ImageGallerySaver.saveImage(
        Uint8List.fromList(response.data),
        quality: 100,
        name: "ruvibe_${DateTime.now().millisecondsSinceEpoch}",
      );

      if (mounted) {
        setState(() => _isSaving = false);
        // 저장 성공 시 기분 좋은 안내 문구
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 갤러리에 사진이 저장되었습니다!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 사진에 집중할 수 있게 배경을 새까맣게(Colors.black) 만듭니다.
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, // 상단바도 블랙으로 통일
        iconTheme: const IconThemeData(color: Colors.white), // 뒤로가기 버튼 하얗게
        title: Text(widget.date, style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          // 💾 상단 우측 저장(다운로드) 버튼
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20, height: 20, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white, size: 28),
                  onPressed: _saveImageToGallery,
                ),
          const SizedBox(width: 8),
        ],
      ),
      // 🔥 InteractiveViewer를 써서 인스타그램처럼 두 손가락으로 줌인/줌아웃이 가능하게 만듭니다.
      body: Center(
        child: InteractiveViewer(
          minScale: 1.0,  // 최소 축소 비율
          maxScale: 4.0,  // 최대 확대 비율 (4배까지 줌인 가능)
          child: CachedNetworkImage(
            imageUrl: widget.imageUrl,
            fit: BoxFit.contain, // 사진이 잘리지 않고 화면 안에 온전히 다 보이도록 설정
            placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
            errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white, size: 50),
          ),
        ),
      ),
    );
  }
}