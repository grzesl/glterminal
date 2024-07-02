import 'dart:ffi';

import 'package:flutter/material.dart';

class LedCtrl extends StatefulWidget {
  const LedCtrl({super.key, required this.isOn});
  final bool isOn;

  @override
  State<LedCtrl> createState() => _LedCtrlState();
}

class _LedCtrlState extends State<LedCtrl> {

  Image led_red =  Image.asset('images/led_red_30.png');
  Image led_green = Image.asset('images/led_green_30.png');
  Image? currentLed = null;
 

  @override
  Widget build(BuildContext context) {

    if (widget.isOn) {
      currentLed = led_green;
    } else {
      currentLed = led_red;
    }

    return Container(
      child: currentLed!,
    );
  }
}