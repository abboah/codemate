import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';

class HelpTourButton extends StatelessWidget {
  final List<GlobalKey> tourKeys;
  const HelpTourButton({required this.tourKeys, super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        ShowCaseWidget.of(context).startShowCase(tourKeys);
      },
      child: Icon(Icons.help_outline),
      tooltip: 'Show Tutorials',
    );
  }
}
