import 'dart:ui';

import 'package:flutter/material.dart';

Future<void> showOnboardingDialog(BuildContext context, VoidCallback onStartTour) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false, // force user to choose

    builder: (BuildContext context) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.black87.withAlpha(50),
          title: Row(
            children: const [
              Icon(Icons.explore_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Welcome to Robin!',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            "👋 It looks like this is your first time here.\n\n"
            "Would you like a quick guided tour through the app?",
            style: TextStyle(color: Colors.white70, height: 1.4),
          ), actionsPadding: EdgeInsets.symmetric(vertical:  10,),
          actionsAlignment: MainAxisAlignment.center,
          
          actions: [
            TextButton(
              child: const Text("Skip", 
                style: TextStyle(color: Colors.white, decoration: TextDecoration.underline),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("Start Tour", style: TextStyle(color: Colors.white),),
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                onStartTour(); // start showcase
              },
            ),
          ],
        ),
      );
    },
  );
}
