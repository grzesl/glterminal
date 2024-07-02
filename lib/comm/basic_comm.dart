import 'dart:typed_data';

import 'package:event/event.dart';

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
  static List<String> getPortNames() {
    // TODO: implement getPortNames
    throw UnimplementedError();
  }
  late Event<ReadCommEventArgs> odDataRecived;
}