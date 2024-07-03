import 'dart:typed_data';

import 'package:event/event.dart';
import 'package:test_flutter/comm/flserial_comm.dart';
import 'package:test_flutter/comm/webserial_comm.dart';

class ReadCommEventArgs extends EventArgs {
    ReadCommEventArgs(this.dataLen, this.cts, this.dsr);
    //final Uint8List dataRecivied;
    final int dataLen;
    final bool cts;
    final bool dsr;
}

abstract class BasicComm {
  bool isOpen();
  bool openPort(Map config);
  int write( Uint8List data);
  Uint8List read(int len);
  bool closePort();
  void enableRTS(bool enable);
  void enableDTR(bool enable);
  bool getCTS();
  bool getDSR();
  static Future<List<String>> getPortNames() async {

    if(GetPlatform.isWeb) {
      return await WebSerialComm.getPortNames();
    } else {
      return await FlSerialComm.getPortNames();
    }
  }
  late Event<ReadCommEventArgs> odDataRecived;
}