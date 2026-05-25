Import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() {
  runApp(const TimeTableApp());
}

class TimeTableApp extends StatelessWidget {
  const TimeTableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ကျောင်းချိန်ဇယား',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF6200EE),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6200EE)),
        fontFamily: 'NotoSansMyanmar',
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _timetable = [];
  int _totalPresent = 0;
  int _totalAbsent = 0;
  
  String _currentClassStatus = "လောလောဆယ် တက်ရမယ့် အတန်းမရှိသေးပါ";
  String _currentClassRoom = "";
  Timer? _timer;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadData().then((_) {
      _checkCurrentClass();
      _timer = Timer.periodic(const Duration(minutes: 1), (timer) => _checkCurrentClass());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await _notificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'timetable_channel', 'Timetable Notifications',
      importance: Importance.max, priority: Priority.high, showWhen: true,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    await _notificationsPlugin.show(0, title, body, platformChannelSpecifics);
  }

  void _checkCurrentClass() {
    final now = DateTime.now();
    final List<String> myanmarDays = ['တနင်္ဂနွေ', 'တနင်္လာ', 'အင်္ဂါ', 'ဗုဒ္ဓဟူး', 'ကြာသပတေး', 'သောကြာ', 'စနေ'];
    String currentDay = myanmarDays[now.weekday % 7];
    bool foundClass = false;

    for (var item in _timetable) {
      if (item['day'] == currentDay) {
        try {
          String timeStr = item['time'].toString().toLowerCase();
          int startHour = 0;
          int endHour = 0;

          if (timeStr.contains('am') || timeStr.contains('pm')) {
            final parts = timeStr.split(RegExp(r'to|-'));
            if (parts.length == 2) {
              startHour = int.parse(parts[0].replaceAll(RegExp(r'[^0-9]'), '').trim());
              endHour = int.parse(parts[1].replaceAll(RegExp(r'[^0-9]'), '').trim());
              if (parts[0].contains('pm') && startHour != 12) startHour += 12;
              if (parts[1].contains('pm') && endHour != 12) endHour += 12;
            }
          } else if (timeStr.contains(':')) {
            final parts = timeStr.split('-');
            if (parts.length == 2) {
              startHour = int.parse(parts[0].split(':')[0].trim());
              endHour = int.parse(parts[1].split(':')[0].trim());
            }
          }

          if (now.hour >= startHour && now.hour < endHour) {
            setState(() {
              _currentClassStatus = "ယခုတက်ရောက်ရန် - ${item['subject']}";
              _currentClassRoom = "သွားရမည့်နေရာ - ${item['room']}";
            });
            _showNotification("အတန်းချိန်ရောက်ပါပြီ!", "ယခု ${item['subject']} အတန်းချိန်ဖြစ်ပါသည်။ အခန်း ${item['room']} သို့ သွားပါ။");
            foundClass = true;
            break;
          }
        } catch (e) {
          // Error handling
        }
      }
    }

    if (!foundClass) {
      setState(() {
        _currentClassStatus = "လောလောဆယ် တက်ရမယ့် အတန်းမရှိသေးပါ";
        _currentClassRoom = "";
      });
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? timetableString = prefs.getString('timetable');
    if (timetableString != null) {
      final List<dynamic> decodedList = jsonDecode(timetableString);
      setState(() {
        _timetable = decodedList.map((item) => Map<String, dynamic>.from(item)).toList();
        _countAttendance();
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedList = jsonEncode(_timetable);
    await prefs.setString('timetable', encodedList);
  }

  void _countAttendance() {
    _totalPresent = _timetable.where((item) => item['status'] == 'တက်တယ်').length;
    _totalAbsent = _timetable.where((item) => item['status'] == 'ပျက်တယ်').length;
  }

  double _calculatePercentage() {
    int totalChecked = _totalPresent + _totalAbsent;
    if (totalChecked == 0) return 0.0;
    return (_totalPresent / totalChecked) * 100;
  }

  void _updateAttendance(int index, String status) {
    setState(() {
      _timetable[index]['status'] = status;
      _countAttendance();
    });
    _saveData();
  }

  void _addClass(String day, String time, String subject, String room) {
    setState(() {
      _timetable.add({
        'day': day, 'time': time, 'subject': subject, 'room': room, 'status': 'မရွေးရသေး'
      });
    });
    _saveData();
    _checkCurrentClass();
  }

  void _deleteClass(int index) {
    setState(() {
      _timetable.removeAt(index);
      _countAttendance();
    });
    _saveData();
    _checkCurrentClass();
  }

  void _showAddClassDialog() {
    String selectedDay = 'တနင်္လာ';
    final List<String> days = ['တနင်္လာ', 'အင်္ဂါ', 'ဗုဒ္ဓဟူး', 'ကြာသပတေး', 'သောကြာ', 'စနေ', 'တနင်္ဂနွေ'];
    final subjectController = TextEditingController();
    final timeController = TextEditingController(text: "9am to 11 am");
    final roomController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('စာသင်ချိန်အသစ် ထည့်ရန်', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: selectedDay,
              decoration: const InputDecoration(labelText: 'နေ့ရက်', border: OutlineInputBorder()),
              items: days.map((day) => DropdownMenuItem(value: day, child: Text(day))).toList(),
              onChanged: (value) => selectedDay = value!,
            ),
            const SizedBox(height: 10),
            TextField(controller: timeController, decoration: const InputDecoration(labelText: 'အချိန် (ဥပမာ - 9am to 11 am)', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: subjectController, decoration: const InputDecoration(labelText: 'ဘာသာရပ်အမည် (ဥပမာ - CST)', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: roomController, decoration: const InputDecoration(labelText: 'အခန်း/ဓာတ်ခွဲခန်း (ဥပမာ - LAB D)', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6200EE), foregroundColor: Colors.white, padding: const EdgeInsets.all(15)),
                onPressed: () {
                  if (subjectController.text.isNotEmpty && roomController.text.isNotEmpty) {
                    _addClass(selectedDay, subjectController.text, timeController.text, roomController.text);
                    Navigator.pop(context);
                  }
                },
                child: const Text('သိမ်းဆည်းမည်'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ကျောင်းချိန်ဇယား & Roll Call', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF6200EE),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(25),
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6200EE), Color(0xFF8B5CF6)]),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('တက်ရောက်မှု', style: TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.bold)),
                      Text('${_calculatePercentage().toStringAsFixed(1)}%', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
                      const Text('စုစုပေါင်းရာခိုင်နှုန်း', style: TextStyle(fontSize: 14, color: Colors.white60)),
                    ],
                  ),
                  Row(
                    children: [
                      _buildAttendanceStat(Colors.green, Icons.check_circle_outline, _totalPresent),
                      const SizedBox(width: 15),
                      _buildAttendanceStat(Colors.red, Icons.cancel_outlined, _totalAbsent),
                    ],
                  )
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _currentClassRoom.isNotEmpty ? Colors.green.shade50 : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: _currentClassRoom.isNotEmpty ? Colors.green : Colors.amber, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.stars, color: _currentClassRoom.isNotEmpty ? Colors.green : Colors.amber, size: 35),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_currentClassStatus, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _currentClassRoom.isNotEmpty ? Colors.green.shade900 : Colors.amber.shade900)),
                        if (_currentClassRoom.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(_currentClassRoom, style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.bold)),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 15)),
          _timetable.isEmpty
              ? const SliverFillRemaining(child: Center(child: Text('စာသင်ချိန်များ မရှိသေးပါ။ အောက်ကခလုတ်ဖြင့် အသစ်ထည့်ပါ။')))
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = _timetable[index];
                      final statusColor = item['status'] == 'တက်တယ်' ? Colors.green : (item['status'] == 'ပျက်တယ်' ? Colors.red : Colors.grey);
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          children: [
                            Container(color: statusColor, width: 6, height: 130),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(15.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${item['day']} (${item['time']})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _deleteClass(index)),
                                      ],
                                    ),
                                    Text(item['subject'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Text('အခန်း - ${item['room']}', style: const TextStyle(color: Colors.black54)),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        _buildAttendanceButton(index, 'တက်တယ်', Colors.green),
                                        const SizedBox(width: 10),
                                        _buildAttendanceButton(index, 'ပျက်တယ်', Colors.red),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: _timetable.length, // 🌟 အမှားပြင်ဆင်လိုက်တဲ့နေရာလေးပါ
                  ),
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddClassDialog,
        backgroundColor: const Color(0xFF6200EE),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAttendanceStat(Color color, IconData icon, int count) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        Text('$count ကြိမ်', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAttendanceButton(int index, String status, Color color) {
    bool isSelected = _timetable[index]['status'] == status;
    return InkWell(
      onTap: () => _updateAttendance(index, status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Text(status, style: TextStyle(color: isSelected ? color : Colors.grey.shade700, fontSize: 12)),
      ),
    );
  }
}
