import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // نظام التقاط الأخطاء الكارثية لمنع إغلاق النظام وتسجيل الخطأ
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _logCrash('FlutterError: ${details.exceptionAsString()}\nStack: ${details.stack}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    _logCrash('PlatformError: $error\nStack: $stack');
    return true; // منع إغلاق التطبيق
  };

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // تفعيل العمل دون اتصال (Offline Persistence) بشكل دائم
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const MyApp());
}

void _logCrash(String error) {
  try {
    final file = File('crash_log.txt');
    final now = DateTime.now();
    file.writeAsStringSync('\n\n--- Crash at $now ---\n$error', mode: FileMode.append);
  } catch (e) {
    debugPrint('Failed to write crash log: $e');
  }
}