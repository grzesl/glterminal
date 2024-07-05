import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:html';
import 'package:event/event.dart';
import 'package:test_flutter/comm/basic_comm.dart';
import 'package:test_flutter/serialport/serial.dart';

class WebSerialComm implements BasicComm {
  Timer? _timer;
  late ReadableStreamReader? _reader = null;
  late WritableStreamDefaultWriter? _writer = null;

  static SerialPort? _port;
  List<int> _readBuff = List.empty(growable: true);
  static bool isSelectedPort = false;

  bool oldCTS = false;
  bool oldDSR = false;

  Future<void> waitForTimer() async {
    while (_timer != null) {
      Future.delayed(Duration(milliseconds: 100));
    }
  }

  @override
  bool closePort() {
    closePortAsync();
    return true;
  }

  Future<bool> closePortAsync() async {
    _timer!.cancel();

    _writer!.ready;
    _writer!.close();

    _reader!.cancel();
    _reader!.releaseLock();

    _port!.close();
    _reader = null;
    return true;
  }

  SerialPort get port {
    return _port!;
  }

  Future<void> _startReceiving(SerialPort p) async {
    if (_reader == null) {
      _reader = p.readable.reader;
    }
    final result = await _reader!.read();

    if (!_timer!.isActive) return;

    int intres = result.value.length;
    // _readBuff.add(result.value);
    // final ptrNameCodeUnits = result.value.cast<int>();
    // var list = ptrNameCodeUnits.asTypedList<int>(intres);
    _readBuff.addAll(result.value);

    odDataRecived
        .broadcast(ReadCommEventArgs(_readBuff.length, oldCTS, oldDSR, true));
  }

  @override
  Event<ReadCommEventArgs> odDataRecived = Event();

  static Future<List<String>> getPortNames() async {
    // return await FlSerial.listPorts();

    try {
      _port = await window.navigator.serial.requestPort();

      if (_port != null) return ["WebSerial"];
    } catch (e) {
      _port = null;
    }

    return [""];
  }

  @override
  bool openPort(Map settings) {
    if (_port == null) return false;

    FlowControl flowControlChoose = FlowControl.none;
    if(settings["flow_control"] == "hardware"){
      flowControlChoose = FlowControl.hardware;
    }

    DataBits dataBitsChoose = DataBits.eight;
     if(settings["byte_size"] == "7"){
      dataBitsChoose = DataBits.eight;}
    
    Parity parityChoose = Parity.none;
    if(settings["parity"] == "even"){
      parityChoose = Parity.even;
      }
    else if (settings["parity"] == "odd"){
      parityChoose = Parity.odd;
      }

    StopBits stopBitsChoose = StopBits.one;
    if(settings["bit_stop"] == "2"){
      stopBitsChoose = StopBits.two;
    }

    _port!.open(
        baudRate: int.parse(settings["baudRate"]),
        flowControl: flowControlChoose,
        bufferSize: 8096,
        dataBits: dataBitsChoose,
        parity: parityChoose,
        stopBits: stopBitsChoose);

    _timer = Timer.periodic(
      const Duration(milliseconds: 100),
      (timer) async {
        if (!timer.isActive || _port == null) {
          timer.cancel();
          _timer = null;
          return;
        }


        // await _port?.readable.cancel();
        // _port?.readable.cancel();
        await _sterRecivingSignals();
        await _startReceiving(_port!);
      },
    );
    return true;
  }

  Future<void> _sterRecivingSignals()
  async {
    bool newCTS = getCTS();
    bool newDSR = getDSR();

    if(oldCTS != newCTS || newDSR != oldDSR)
    {
        odDataRecived.broadcast(ReadCommEventArgs(_readBuff.length, newCTS, newDSR, true));

        oldCTS = newCTS;
        oldDSR = newDSR;
    }
  }

  void enableRTS(bool value) {
    (_port)!.setSignals(requestToSend: value);
  }

  void enableDTR(bool value) {
    _port!.setSignals(dataTerminalReady: value);
  }

  bool getCTS() {
    return _port!.getSignals().clearToSend == null?false:_port!.getSignals().clearToSend!;
  }

  bool getDSR() {
    return _port!.getSignals().dataSetReady == null?false:_port!.getSignals().dataSetReady!;
  }

  @override
  Uint8List read(int len) {
    Uint8List old = Uint8List(0);
    if (_readBuff.isNotEmpty) {
      if (len > _readBuff.length) {
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

    if (_writer == null) {
      _writer = _port!.writable.writer;
    }

    _writer!.ready;
    _writer!.write(data);

    return 0;
  }

  @override
  bool isOpen() {
    //return port!.isOpen() == FLOpenStatus.open? true: false;

    return _port == null ? false: true;
  }

  @override
  bool isSelected() {
    //return port!.isOpen() == FLOpenStatus.open? true: false;
    
    return isSelectedPort;
  }
  
  @override
  int available() {
    return _readBuff.length;
  }
  
  @override
  Future<void> processRead() async {
    await _startReceiving(_port!);
  }
}
