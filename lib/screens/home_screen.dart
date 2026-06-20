import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'upload_screen.dart';
import 'date_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DateTime _birthDate = DateTime(2026, 4, 6);
  final Map<String, List<String>> _photoMap = {};
  StreamSubscription<QuerySnapshot>? _photoSubscription;
  
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();  
    _setupPhotoListener();
  }

  @override
  void dispose() {
    _photoSubscription?.cancel();
    super.dispose();
  }

  void _setupPhotoListener() {
    _photoSubscription?.cancel();
    _photoSubscription = FirebaseFirestore.instance
        .collection('photos')
        .orderBy('timestamp')
        .snapshots()
        .listen((snapshot) {
      Map<String, List<String>> tempMap = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['date'] != null && data['url'] != null) {
          String dateKey = data['date'];
          String url = data['url'];
          
          if (tempMap.containsKey(dateKey)) {
            tempMap[dateKey]!.add(url);
          } else {
            tempMap[dateKey] = [url];
          }
        }
      }
      if (mounted) {
        setState(() {
          _photoMap.clear();
          _photoMap.addAll(tempMap);
        });
      }
    });
  }

  String get _dDay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return 'D+${today.difference(_birthDate).inDays + 1}';
  }

  void _openDetailScreen(DateTime day) {
    String dateKey = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
    List<String>? urls = _photoMap[dateKey];
    if (urls == null || urls.isEmpty) return;

    Navigator.push(context, MaterialPageRoute(builder: (context) => DateDetailScreen(date: dateKey, urls: urls)));
  }

  Widget? _buildPhotoCell(BuildContext context, DateTime day, DateTime focusedDay) {
    String dateKey = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
    if (_photoMap.containsKey(dateKey) && _photoMap[dateKey]!.isNotEmpty) {
      return Center(
        child: Container(
          width: 46, height: 46, 
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: _photoMap[dateKey]![0], 
              fit: BoxFit.cover, width: 46, height: 46,
              placeholder: (context, url) => Container(color: Colors.grey[300], child: const Icon(Icons.image, size: 20)),
              errorWidget: (context, url, error) => Container(color: Colors.grey[300], child: const Icon(Icons.error, size: 20)),
            ),
          ),
        ),
      );
    }
    return null;
  }

  Widget printCalendarWidget() {
    return TableCalendar(
      firstDay: DateTime.utc(1999, 4, 6),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      headerStyle: const HeaderStyle(formatButtonVisible: false),
      calendarFormat: _calendarFormat,
      onFormatChanged: (format) => setState(() => _calendarFormat = format),
      onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
        _openDetailScreen(selectedDay); 
      },
      calendarBuilders: CalendarBuilders(
        defaultBuilder: _buildPhotoCell,
        todayBuilder: _buildPhotoCell,     
        selectedBuilder: _buildPhotoCell,  
      ),
    );
  }

  void _showRecordBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('오늘의 성장 기록 추가', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(Icons.opacity, color: Colors.amber, size: 30),
                  title: const Text('🍼 수유 기록하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(context),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.bedtime, color: Colors.blueAccent, size: 30),
                  title: const Text('😴 잠 기록하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 100,
        leading: const Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: Align(alignment: Alignment.centerLeft, child: Text('ruVibe', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
        ),
        centerTitle: true,
        title: Text(_dDay, style: const TextStyle(fontSize: 24, color: Colors.blue, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black87),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('로그아웃'),
                  content: const Text('정말 로그아웃 하시겠습니까?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context); 
                        await FirebaseAuth.instance.signOut(); 
                      }, 
                      child: const Text('로그아웃', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      // 🔥 1. ScrollView를 없애고 안전영역(SafeArea) 내부에 Column 배치
      body: SafeArea(
        child: Column(
          children: [
            printCalendarWidget(),
            
            // 🔥 2. 남은 공간을 알아서 꽉 채우도록 Expanded로 감싸기
            Expanded(
              child: DailyActivityRing(
                records: [
                   DailyRecord(startTime: DateTime(2026, 6, 21, 0, 0), endTime: DateTime(2026, 6, 21, 2, 0), type: 'sleep'),
                DailyRecord(startTime: DateTime(2026, 6, 21, 3, 0), endTime: DateTime(2026, 6, 21, 5, 0), type: 'sleep'),
                DailyRecord(startTime: DateTime(2026, 6, 21, 6, 0), endTime: DateTime(2026, 6, 21, 9, 0), type: 'sleep'),
                DailyRecord(startTime: DateTime(2026, 6, 21, 12, 0), endTime: DateTime(2026, 6, 21, 14, 0), type: 'sleep'),
                DailyRecord(startTime: DateTime(2026, 6, 21, 16, 0), endTime: DateTime(2026, 6, 21, 17, 0), type: 'sleep'),
                DailyRecord(startTime: DateTime(2026, 6, 21, 18, 30), endTime: DateTime(2026, 6, 21, 20, 0), type: 'sleep'),
                
                // 🍼 수유 타임라인 (4시, 8시, 11시 시작 / 30분간 진행 처리)
                DailyRecord(startTime: DateTime(2026, 6, 21, 2, 0), endTime: DateTime(2026, 6, 21, 2, 30), type: 'feed'),
                DailyRecord(startTime: DateTime(2026, 6, 21, 5, 5), endTime: DateTime(2026, 6, 21, 5, 30), type: 'feed'),
                DailyRecord(startTime: DateTime(2026, 6, 21, 10, 0), endTime: DateTime(2026, 6, 21, 11, 0), type: 'feed'),
                DailyRecord(startTime: DateTime(2026, 6, 21, 14, 0), endTime: DateTime(2026, 6, 21, 14, 30), type: 'feed'),
                DailyRecord(startTime: DateTime(2026, 6, 21, 18, 0), endTime: DateTime(2026, 6, 21, 18, 30), type: 'feed'),

                ],
              ),
            ),
          ],
        ),
      ),
      // 🔥 3. 플로팅 버튼 대신 하단 네비게이션 바 영역에 고정 배치 (절대 차트를 가리지 않음)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton.large(
                heroTag: 'btn_record_activity', 
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 2,
                onPressed: _showRecordBottomSheet,
                child: const Icon(Icons.assignment, size: 32, color: Colors.blueAccent),
              ),
              const SizedBox(width: 30), 
              FloatingActionButton.large(
                heroTag: 'btn_upload_photo', 
                elevation: 2,
                onPressed: () async {
                  _photoSubscription?.cancel(); 
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const UploadScreen()));
                  _setupPhotoListener(); 
                },
                child: const Icon(Icons.add_a_photo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 👶 반응형 원형 차트 위젯 (크기 자동 조절)
// ============================================================================

class DailyRecord {
  final DateTime startTime;
  final DateTime endTime;
  final String type; 

  DailyRecord({required this.startTime, required this.endTime, required this.type});
}

class DailyActivityRing extends StatelessWidget {
  final List<DailyRecord> records;

  const DailyActivityRing({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegend(Colors.blueAccent, '잠'),
            const SizedBox(width: 25),
            _buildLegend(Colors.amber, '수유'),
          ],
        ),
        const SizedBox(height: 10),
        
        // 🔥 고정 픽셀(220) 대신 비율(AspectRatio)을 유지하며 부모 공간에 맞게 자동 축소/확대
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RingPainter(records: records),
                    ),
                  ),
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('오늘의 패턴', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('24H', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final List<DailyRecord> records;
  _RingPainter({required this.records});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    
    // 차트 크기가 작아지면 선 두께도 비례해서 얇아지도록 처리
    final dynamicStrokeWidth = math.max(14.0, radius * 0.18);

    final bgPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = dynamicStrokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    for (var record in records) {
      Paint arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = dynamicStrokeWidth
        ..strokeCap = StrokeCap.round;

      if (record.type == 'sleep') {
        arcPaint.color = Colors.blueAccent.withOpacity(0.8);
      } else if (record.type == 'feed') {
        arcPaint.color = Colors.amber; 
      }

      double startAngle = _timeToAngle(record.startTime);
      double sweepAngle = _timeToAngle(record.endTime) - startAngle;

      if (sweepAngle < 0) sweepAngle += 2 * math.pi;

      canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
    }
    
    _drawTicks(canvas, center, radius);
  }

  double _timeToAngle(DateTime time) {
    double hours = time.hour + (time.minute / 60.0);
    return (hours / 24.0) * 2 * math.pi - (math.pi / 2);
  }

  void _drawTicks(Canvas canvas, Offset center, double radius) {
    final tickPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3;
    for (int i = 0; i < 24; i += 6) {
      double angle = (i / 24.0) * 2 * math.pi - (math.pi / 2);
      // 틱(선) 길이도 동적으로 조절
      final tickLength = radius * 0.1; 
      final p1 = Offset(center.dx + (radius - tickLength) * math.cos(angle), center.dy + (radius - tickLength) * math.sin(angle));
      final p2 = Offset(center.dx + (radius + tickLength) * math.cos(angle), center.dy + (radius + tickLength) * math.sin(angle));
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}