import 'package:flutter/material.dart';

class LedCtrl extends StatefulWidget {
  const LedCtrl({super.key, required this.isOn});
  final bool isOn;

  @override
  State<LedCtrl> createState() => _LedCtrlState();
}

class _LedCtrlState extends State<LedCtrl> {

  Image ledRed = Image.asset('images/led_red_30.png');
  Image ledGreen = Image.asset('images/led_green_30.png');
  Image? currentLed;


  @override
  Widget build(BuildContext context) {

    if (widget.isOn) {
      currentLed = ledGreen;
    } else {
      currentLed = ledRed;
    }

    return Container(
      child: currentLed!,
    );
  }
}