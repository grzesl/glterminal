import 'dart:async';
import 'dart:core';
import 'dart:typed_data';
import 'package:test_flutter/iodev/dev_config.dart';
import 'package:test_flutter/iodev/enums.dart';

abstract class BasicDev {
  late DevConfig configData;
  List<Uint8List> data = List.empty(growable: true);
  String lastError = "";
  StreamController<EventType> controller = StreamController<EventType>();

  void config(DevConfig config) {
    configData = config;
  }

  Stream getStream() {
    return controller.stream;
  }

  Stream get stream {
    return getStream();
  }

  Future<int> openDev(Map config) async {
    return 1;
  }

  Future<int> closeDev() async {
    if (!controller.isClosed) {
      controller.close();
    }
    return 0;
  }

  Future<Uint8List> readDev() async {
    if (data.isNotEmpty) {
      return data.removeAt(0);
    }
    return Uint8List(0);
  }

  Future<int> writeDev(Uint8List data) async {
    return 0;
  }

  bool isDevOpen();
  int devLen() {
    return data.length;
  }
}
