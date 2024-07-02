
import 'dart:typed_data';

import 'package:event/event.dart';
import 'package:test_flutter/comm/basic_comm.dart';
import 'package:flserial/flserial.dart';

class FlSerialComm implements BasicComm {
  FlSerial? _port;

  @override
  bool closePort() {
    return _port!.closePort() > 0? true: false;
  }

  FlSerial get port {
    return _port!;
  }

  static Future< List<String>> getPortNames() async {

    return await FlSerial.listPorts();
  }

  @override
  bool openPort(Map settings) {


    _port = FlSerial();
    _port?.openPort(settings["portName"], int.parse(settings["baudRate"]));
                  _port?.onSerialData.subscribe((args) {
                    odDataRecived.broadcast(ReadCommEventArgs(args!.len, args!.cts, args!.dsr));
                  });

    switch(settings["byte_size"])
    {
      case "5":
      _port?.setByteSize5();
      break;
      case "6":
      _port?.setByteSize6();
      break;
      case "7":
      _port?.setByteSize7();
      break;
      case "8":
      _port?.setByteSize8();
      break;
    } 

    switch(settings["parity"])
    {
      case "none":
      port?.setByteParityNone();
      break;
      case "even":
      port?.setByteParityEven();
      break;
      case "odd":
      port?.setByteParityOdd();
      break;
      case "mark":
      port?.setByteParityMark();
      break;
      case "space":
      port?.setByteParitySpace();
      break;
    }      


    switch(settings["bit_stop"])
    {
      case "1":
      port?.setStopBits1();
      break;
            case "1.5":
      port?.setStopBits1_5();
      break;
            case "2":
      port?.setStopBits2();
      break;
    }       

    switch (settings["flow_control"]) {
      case "none":
        port?.setFlowControlNone();
        break;
      case "hardware":
        port?.setFlowControlHardware();
        break;
      case "software":
        port?.setFlowControlSoftware();
        break;
    }

    return _port!.isOpen() == FLOpenStatus.open?true:false;;
  }


  void enableRTS(bool value) {
    _port!.setRTS(value);
  //  _config.rts = value?1:0;
  //  _port!.config = _config;
  }

  void enableDTR(bool value) {
    _port!.setDTR(value);
   // _config.dtr = value?1:0;
   // _port!.config = _config;
  }

  
  bool getCTS() {
    return _port!.getCTS();
  }

  bool getDSR() {
    return _port!.getDSR();
  }


  @override
  Uint8List read(int len) {
    Uint8List dataRead  = Uint8List(0);
    var lenavaliable = _port!.readBuff.length ;
    if(lenavaliable > 0) {
      dataRead =  _port!.readListLen(len);
    }
    return dataRead;
  }

  @override
  int write(Uint8List data) {
    int wrt = _port!.write(data.length, data );
    return wrt;
  }

  @override
  Event<ReadCommEventArgs> odDataRecived = Event();
  
  @override
  bool isOpen() {
    return port!.isOpen() == FLOpenStatus.open? true: false;
  }
  
}