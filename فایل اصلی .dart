import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'مبدل پول ایرانی',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Vazir',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
          labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white.withOpacity(0.8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 4,
          ),
        ),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.teal,
        fontFamily: 'Vazir',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16, color: Colors.white70),
          labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.grey[800]!.withOpacity(0.8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 4,
          ),
        ),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.grey[900],
      ),
      themeMode: ThemeMode.system,
      home: const CurrencyConverter(),
    );
  }
}

class CurrencyConverter extends StatefulWidget {
  const CurrencyConverter({super.key});

  @override
  _CurrencyConverterState createState() => _CurrencyConverterState();
}

class _CurrencyConverterState extends State<CurrencyConverter> with SingleTickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  String _result = '';
  String _wordResult = '';
  double _percentage = 0.0;
  bool _isToman = true;
  bool _isCalculating = false;
  bool _isPaying = false;
  Timer? _debounce;
  bool _isDarkMode = false;
  List<String> _history = [];

  // اسکناس‌های موجود
  final List<int> _denominations = [200000, 100000, 50000, 10000, 5000, 2000, 1000, 500];

  // کش برای بهینه‌سازی تبدیل عدد به حروف
  final Map<int, String> _numberToWordsCache = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // بارگذاری تاریخچه از SharedPreferences
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList('calculation_history') ?? [];
    });
  }

  // ذخیره تاریخچه در SharedPreferences
  Future<void> _saveHistory(String entry) async {
    final prefs = await SharedPreferences.getInstance();
    _history.insert(0, entry);
    if (_history.length > 10) _history = _history.sublist(0, 10);
    await prefs.setStringList('calculation_history', _history);
    setState(() {});
  }

  // تبدیل عدد به حروف (به فارسی)
  String _numberToWords(int number) {
    if (number == 0) return 'صفر';
    if (number > 1000000000000) return 'مبلغ بیش از حد بزرگ است';

    if (_numberToWordsCache.containsKey(number)) {
      return _numberToWordsCache[number]! + (_isToman ? ' تومان' : ' ریال');
    }

    const List<String> units = ['', 'هزار', 'میلیون', 'میلیارد', 'تریلیون'];
    const List<String> ones = ['', 'یک', 'دو', 'سه', 'چهار', 'پنج', 'شش', 'هفت', 'هشت', 'نه'];
    const List<String> teens = ['ده', 'یازده', 'دوازده', 'سیزده', 'چهارده', 'پانزده', 'شانزده', 'هفده', 'هجده', 'نوزده'];
    const List<String> tens = ['', 'ده', 'بیست', 'سی', 'چهل', 'پنجاه', 'شصت', 'هفتاد', 'هشتاد', 'نود'];
    const List<String> hundreds = ['', 'صد', 'دویست', 'سیصد', 'چهارصد', 'پانصد', 'ششصد', 'هفتصد', 'هشتصد', 'نهصد'];

    List<String> words = [];
    int unitIndex = 0;

    while (number > 0) {
      int chunk = number % 1000;
      if (chunk > 0) {
        List<String> chunkWords = [];
        int hundred = chunk ~/ 100;
        int ten = (chunk % 100) ~/ 10;
        int one = chunk % 10;

        if (hundred > 0) chunkWords.add(hundreds[hundred]);
        if (ten == 1) {
          chunkWords.add(teens[one]);
        } else {
          if (ten > 1) chunkWords.add(tens[ten]);
          if (one > 0) chunkWords.add(ones[one]);
        }

        if (chunkWords.isNotEmpty && unitIndex > 0) {
          chunkWords.add(units[unitIndex]);
        }
        words.insertAll(0, chunkWords);
      }
      number ~/= 1000;
      unitIndex++;
    }

    String result = words.join(' ');
    _numberToWordsCache[number] = result;
    return result + (_isToman ? ' تومان' : ' ریال');
  }

  // محاسبه تعداد اسکناس‌ها
  String _calculateDenominations(int amount) {
    List<String> result = [];
    int remaining = _isToman ? amount : (amount >= 10 ? amount ~/ 10 : 0);

    if (!_isToman && amount < 10) {
      return 'مبلغ خیلی کم است برای محاسبه اسکناس';
    }

    for (int denom in _denominations) {
      int count = remaining ~/ denom;
      if (count > 0) {
        result.add('$count اسکناس ${NumberFormat.decimalPattern('fa').format(denom)} تومانی');
        remaining %= denom;
      }
    }

    return result.isEmpty ? 'بدون اسکناس' : result.join('\n');
  }

  // تبدیل اعداد فارسی به انگلیسی
  String _convertPersianToEnglish(String input) {
    const persianNumbers = '۰۱۲۳۴۵۶۷۸۹';
    const englishNumbers = '0123456789';
    String result = input;
    for (int i = 0; i < persianNumbers.length; i++) {
      result = result.replaceAll(persianNumbers[i], englishNumbers[i]);
    }
    return result.replaceAll(RegExp(r'[,٫\s]'), '');
  }

  // شبیه‌سازی پرداخت مستقیم
  Future<bool> _initiateDirectPayment(int amount, bool isToman) async {
    try {
      // فرض کنید درگاه پرداخت واقعی استفاده می‌شود
      // مثال: درخواست به API زرین‌پال یا ملت
      await Future.delayed(const Duration(seconds: 2)); // شبیه‌سازی درخواست شبکه
      // فرضاً پاسخ موفقیت‌آمیز است
      return true;
    } catch (e) {
      _scaffoldKey.currentState?.removeCurrentSnackBar();
      _scaffoldKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('خطا در پرداخت: $e', textDirection: TextDirection.rtl),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }
  }

  // محاسبه و نمایش نتیجه
  void _calculate() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!_formKey.currentState!.validate()) return;

      setState(() {
        _isCalculating = true;
        String cleanedInput = _convertPersianToEnglish(_amountController.text);
        int amount = int.tryParse(cleanedInput) ?? 0;
        if (amount <= 0) {
          _scaffoldKey.currentState?.removeCurrentSnackBar();
          _scaffoldKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('لطفاً مبلغ معتبر و مثبت وارد کنید', textDirection: TextDirection.rtl),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 2),
            ),
          );
          _result = '';
          _wordResult = '';
          _isCalculating = false;
          return;
        }

        // تبدیل تومان به ریال یا بالعکس
        int convertedAmount = _isToman ? amount * 10 : amount ~/ 10;
        String formattedAmount = NumberFormat.decimalPattern('fa').format(amount);

        _result = _isToman
            ? 'معادل: ${NumberFormat.decimalPattern('fa').format(convertedAmount)} ریال\n'
            : 'معادل: ${convertedAmount > 0 ? NumberFormat.decimalPattern('fa').format(convertedAmount) : 'کمتر از یک تومان'} تومان\n';
        _result += _calculateDenominations(amount);

        // محاسبه درصد
        if (_percentage > 0) {
          double percentAmount = amount * (_percentage / 100);
          _result += '\n${_percentage.toStringAsFixed(0)} درصد: ${NumberFormat.decimalPattern('fa').format(percentAmount.round())} ${_isToman ? 'تومان' : 'ریال'}';
        }

        _wordResult = _numberToWords(amount);
        _isCalculating = false;

        // ذخیره در تاریخچه
        String historyEntry = 'مبلغ: $formattedAmount ${_isToman ? 'تومان' : 'ریال'}\n$_result\n$_wordResult';
        _saveHistory(historyEntry);
      });

      Vibrate.canVibrate.then((canVibrate) {
        if (canVibrate) Vibrate.feedback(FeedbackType.light);
      });
    });
  }

  // شروع پرداخت مستقیم
  void _startDirectPayment() async {
    if (_result.isEmpty) {
      _scaffoldKey.currentState?.removeCurrentSnackBar();
      _scaffoldKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('ابتدا مبلغ را محاسبه کنید', textDirection: TextDirection.rtl),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isPaying = true;
    });

    String cleanedInput = _convertPersianToEnglish(_amountController.text);
    int amount = int.tryParse(cleanedInput) ?? 0;

    bool paymentSuccess = await _initiateDirectPayment(amount, _isToman);

    if (paymentSuccess) {
      String paymentEntry = 'پرداخت موفق: ${NumberFormat.decimalPattern('fa').format(amount)} ${_isToman ? 'تومان' : 'ریال'}\nتاریخ: ${DateTime.now().toString()}';
      await _saveHistory(paymentEntry);
      _scaffoldKey.currentState?.removeCurrentSnackBar();
      _scaffoldKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('پرداخت با موفقیت انجام شد', textDirection: TextDirection.rtl),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }

    setState(() {
      _isPaying = false;
    });

    Vibrate.canVibrate.then((canVibrate) {
      if (canVibrate && paymentSuccess) Vibrate.feedback(FeedbackType.success);
    });
  }

  // ریست کردن
  void _reset() {
    setState(() {
      _amountController.clear();
      _result = '';
      _wordResult = '';
      _percentage = 0.0;
      _isCalculating = false;
      if (_debounce?.isActive ?? false) _debounce!.cancel();
    });

    Vibrate.canVibrate.then((canVibrate) {
      if (canVibrate) Vibrate.feedback(FeedbackType.medium);
    });
  }

  // تغییر تم
  void _toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
  }

  // نمایش تاریخچه
  void _showHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final textScaleFactor = MediaQuery.of(context).textScaleFactor;
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'تاریخچه محاسبات و پرداخت‌ها',
                    style: TextStyle(fontSize: 20 * textScaleFactor, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: _history.isEmpty
                      ? Center(child: Text('بدون تاریخچه', style: TextStyle(fontSize: 16 * textScaleFactor)))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _history.length,
                          itemBuilder: (context, index) {
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _history[index],
                                        textDirection: TextDirection.rtl,
                                        style: TextStyle(fontSize: 14 * textScaleFactor),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.share, size: 20 * textScaleFactor),
                                      onPressed: () {
                                        Share.share(_history[index], subject: 'نتیجه محاسبه یا پرداخت');
                                      },
                                      tooltip: 'اشتراک‌گذاری',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double textScaleFactor = MediaQuery.of(context).textScaleFactor;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      key: _scaffoldKey,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: Theme.of(context).brightness == Brightness.light
                ? [Colors.teal[50]!, Colors.teal[300]!]
                : [Colors.grey[900]!, Colors.grey[700]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: Text(
                'مبدل پول ایرانی',
                style: TextStyle(fontSize: 20 * textScaleFactor),
              ),
              centerTitle: true,
              backgroundColor: Colors.teal.withOpacity(0.9),
              elevation: 0,
              pinned: true,
              actions: [
                IconButton(
                  icon: Icon(_isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 24 * textScaleFactor),
                  onPressed: _toggleTheme,
                  tooltip: 'تغییر تم',
                  semanticsLabel: 'تغییر تم',
                ),
                IconButton(
                  icon: Icon(Icons.history, size: 24 * textScaleFactor),
                  onPressed: _showHistory,
                  tooltip: 'نمایش تاریخچه',
                  semanticsLabel: 'نمایش تاریخچه',
                ),
              ],
            ),
            SliverPadding(
              padding: EdgeInsets.all(screenWidth > 600 ? 24.0 : 16.0 * textScaleFactor),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.rtl,
                          decoration: InputDecoration(
                            labelText: _isToman ? 'مبلغ (تومان)' : 'مبلغ (ریال)',
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(10)),
                            ),
                            prefixIcon: const Icon(Icons.monetization_on),
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]!.withOpacity(0.8)
                                : Colors.white.withOpacity(0.8),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹,٫]')),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'مبلغ را وارد کنید';
                            }
                            String cleaned = _convertPersianToEnglish(value);
                            int? parsed = int.tryParse(cleaned);
                            if (parsed == null || parsed <= 0) {
                              return 'عدد معتبر و مثبت وارد کنید';
                            }
                            if (parsed > 1000000000000) {
                              return 'مبلغ بیش از حد بزرگ است';
                            }
                            return null;
                          },
                          onChanged: (value) => _calculate(),
                          semanticsLabel: 'مبلغ ورودی',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16 * textScaleFactor),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.swap_horiz, color: Colors.teal, size: 24 * textScaleFactor),
                          SizedBox(width: 8 * textScaleFactor),
                          const Text('واحد: ', style: TextStyle(fontSize: 16)),
                          AnimatedOpacity(
                            opacity: _isToman ? 1.0 : 0.5,
                            duration: const Duration(milliseconds: 200),
                            child: Radio<bool>(
                              value: true,
                              groupValue: _isToman,
                              onChanged: (value) {
                                setState(() {
                                  _isToman = value!;
                                  _calculate();
                                });
                              },
                              activeColor: Colors.teal,
                              semanticsLabel: 'انتخاب تومان',
                            ),
                          ),
                          const Text('تومان'),
                          AnimatedOpacity(
                            opacity: !_isToman ? 1.0 : 0.5,
                            duration: const Duration(milliseconds: 200),
                            child: Radio<bool>(
                              value: false,
                              groupValue: _isToman,
                              onChanged: (value) {
                                setState(() {
                                  _isToman = value!;
                                  _calculate();
                                });
                              },
                              activeColor: Colors.teal,
                              semanticsLabel: 'انتخاب ریال',
                            ),
                          ),
                          const Text('ریال'),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16 * textScaleFactor),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('درصد:', style: TextStyle(fontSize: 16 * textScaleFactor)),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                            ),
                            child: Slider(
                              value: _percentage,
                              min: 0,
                              max: 100,
                              divisions: 100,
                              label: '${_percentage.toStringAsFixed(0)}%',
                              onChanged: (value) {
                                setState(() {
                                  _percentage = value;
                                });
                              },
                              onChangeEnd: (value) {
                                _calculate();
                                Vibrate.canVibrate.then((canVibrate) {
                                  if (canVibrate) Vibrate.feedback(FeedbackType.light);
                                });
                              },
                              activeColor: Colors.teal,
                              inactiveColor: Colors.teal[100],
                              semanticsLabel: 'انتخاب درصد',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16 * textScaleFactor),
                  AnimatedScaleButton(
                    onPressed: _calculate,
                    color: Colors.teal,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.teal, Colors.teal[700]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
                      child: _isCalculating
                          ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2 * textScaleFactor)
                          : Text('محاسبه', style: TextStyle(fontSize: 16 * textScaleFactor, color: Colors.white)),
                    ),
                  ),
                  SizedBox(height: 16 * textScaleFactor),
                  AnimatedSlide(
                    offset: _result.isEmpty ? const Offset(0, 0.2) : const Offset(0, 0),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: AnimatedOpacity(
                      opacity: _result.isEmpty ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('نتیجه تبدیل:', style: TextStyle(fontSize: 18 * textScaleFactor, fontWeight: FontWeight.bold)),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.share, size: 20 * textScaleFactor),
                                        onPressed: () {
                                          Share.share(_result, subject: 'نتیجه تبدیل');
                                        },
                                        tooltip: 'اشتراک‌گذاری نتیجه',
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.payment, size: 20 * textScaleFactor),
                                        onPressed: _isPaying ? null : _startDirectPayment,
                                        tooltip: 'پرداخت مستقیم',
                                        color: Colors.green,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: 8 * textScaleFactor),
                              Text(
                                _result,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(fontSize: 16 * textScaleFactor),
                                semanticsLabel: 'نتیجه محاسبه',
                              ),
                              if (_isPaying)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: LinearProgressIndicator(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16 * textScaleFactor),
                  AnimatedSlide(
                    offset: _wordResult.isEmpty ? const Offset(0, 0.2) : const Offset(0, 0),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: AnimatedOpacity(
                      opacity: _wordResult.isEmpty ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('مبلغ به حروف:', style: TextStyle(fontSize: 18 * textScaleFactor, fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: Icon(Icons.share, size: 20 * textScaleFactor),
                                    onPressed: () {
                                      Share.share(_wordResult, subject: 'مبلغ به حروف');
                                    },
                                    tooltip: 'اشتراک‌گذاری مبلغ به حروف',
                                  ),
                                ],
                              ),
                              SizedBox(height: 8 * textScaleFactor),
                              Text(
                                _wordResult,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(fontSize: 16 * textScaleFactor, fontWeight: FontWeight.bold),
                                semanticsLabel: 'نتیجه به حروف',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _reset,
        backgroundColor: Colors.redAccent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.redAccent, Colors.red[700]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.refresh, size: 24 * textScaleFactor, color: Colors.white),
        ),
        tooltip: 'ریست',
        semanticsLabel: 'ریست کردن',
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amountController.dispose();
    super.dispose();
  }
}

// ویجت دکمه با انیمیشن مقیاس
class AnimatedScaleButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Color color;
  final Widget child;

  const AnimatedScaleButton({
    super.key,
    required this.onPressed,
    required this.color,
    required this.child,
  });

  @override
  _AnimatedScaleButtonState createState() => _AnimatedScaleButtonState();
}

class _AnimatedScaleButtonState extends State<AnimatedScaleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
          ),
          onPressed: null,
          child: widget.child,
        ),
      ),
    );
  }
}