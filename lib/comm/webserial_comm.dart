import 'dart:async';
import 'dart:typed_data';
import 'dart:html';
import 'package:event/event.dart';
import 'package:test_flutter/comm/basic_comm.dart';
// ignore: depend_on_referenced_packages
import 'package:serial/serial.dart';


class WebSerialComm implements BasicComm {
  //WeSerial? _port;
  int flh = 0;
  late Timer _timer;
  static SerialPort? _port;
  List<int> _readBuff = List.empty(growable: true);
  @override
  bool closePort() {
    flh = -1;
    //_port!.abort();
    //_port!.cancel();
    _port!.close();
    return true;
  }

 // FlSerial get port {
 //   return _port!;
  //}

static Future<List<String>> getPortNames() async  {

   // return await FlSerial.listPorts();

   
  _port = await window.navigator.serial.requestPort();
   return ["WebSerial"];
  }



  @override
  bool openPort(Map settings) {

    _port!.open(baudRate: int.parse(settings["baudRate"]),
             flowControl: FlowControl.none);
    final reader = _port!.readable.reader;
    _timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) async {
        if (flh < 0) {
          _timer.cancel();
          return;
        }
        await _startReceiving(reader);
      },
    );
    return true;
  }


  void enableRTS(bool value) {
   // _port!.setRTS(value);
  //  _config.rts = value?1:0;
  //  _port!.config = _config;
  }

  void enableDTR(bool value) {
    //_port!.setDTR(value);
   // _config.dtr = value?1:0;
   // _port!.config = _config;
  }

  
  bool getCTS() {
    //return _port!.getCTS();
    return false;
  }

  bool getDSR() {
    //return _port!.getDSR();
    return false;
  }


  @override
  Uint8List read(int len) {
    Uint8List old = Uint8List(0);
    if (_readBuff.isNotEmpty) {
      if(len > _readBuff.length){
        len = _readBuff.length;
      }
      old = Uint8List.fromList(_readBuff.sublist(0, len));
      _readBuff.removeRange(0, len);
    } 
    return old;
  }

  @override
  int write(Uint8List data) {
    if (data.isEmpty) {
      return 0;
    }

    if (_port == null) {
      return 0;
    }

    final writer = _port!.writable.writer;
    

     writer.ready;
     writer.write(data);

     writer.ready;
     writer.close();
    return 0;
  }



    Future<void> _startReceiving( ReadableStreamReader  reader) async {
  
    final result = await reader.read();
    int intres = result.value.length;
   // _readBuff.add(result.value); 
   // final ptrNameCodeUnits = result.value.cast<int>();
   // var list = ptrNameCodeUnits.asTypedList<int>(intres);
    _readBuff.addAll(result.value);
    odDataRecived.broadcast(ReadCommEventArgs(
              _readBuff.length, false, false));
  }

  @override
  Event<ReadCommEventArgs> odDataRecived = Event();
  
  @override
  bool isOpen() {
    //return port!.isOpen() == FLOpenStatus.open? true: false;

    return true;
  }
  
}