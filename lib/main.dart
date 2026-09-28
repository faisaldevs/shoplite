import 'package:flutter/material.dart';
import 'package:shoplite/app.dart';
import 'package:shoplite/core/di/di.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized(); 
await initializeDependencies();

  runApp(
    
    
    const MyApp());
}
