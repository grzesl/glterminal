import 'dart:typed_data';

import 'package:test_flutter/iodev/basic_dev.dart';

class NullDev extends BasicDev {
  @override
  bool isDevOpen() {
    return true;
  }

  @override
  Future<int> writeDev(Uint8List data) async {
    return data.length;
  }
}
