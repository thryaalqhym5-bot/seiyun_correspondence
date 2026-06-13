import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final snap = await FirebaseFirestore.instance.collection('communications')
      .where('is_external', isEqualTo: true)
      .orderBy('created_at', descending: true)
      .limit(5)
      .get();
  
  for (var doc in snap.docs) {
    debugPrint('Doc ID: ${doc.id}');
    debugPrint('Subject: ${doc.data()['subject']}');
    debugPrint('Sender ID: ${doc.data()['sender_id']}');
    debugPrint('Target ID: ${doc.data()['target_id']}');
    debugPrint('Current RCV ID: ${doc.data()['current_rcv_id']}');
    debugPrint('Status: ${doc.data()['status']}');
    debugPrint('Is Read: ${doc.data()['is_read_by_dean']}');
    debugPrint('---');
  }
  exit(0);
}
