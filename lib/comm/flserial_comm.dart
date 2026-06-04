import 'dart:async';
import 'dart:typed_data';

import 'package:event/event.dart';
import 'package:test_flutter/comm/basic_comm.dart';
import 'package:flserial/flserial.dart';

class FlSerialComm implements BasicComm {
  FlSerial? _port;
  StreamSubscription<SerialEvent>? _eventsSub;

  // flserial 0.6.0 delivers received bytes directly through the events stream
  // instead of the old readBuff/readListLen polling model, so we buffer them
  // here to keep the BasicComm read(len) contract intact.
  final List<int> _readBuffer = [];

  bool _isOpen = false;
  bool _cts = false;
  bool _dsr = false;

  FlSerial get port {
    return _port!;
  }

  @override
  bool closePort() {
    _isOpen = false;
    _eventsSub?.cancel();
    _eventsSub = null;
    _readBuffer.clear();
    _port?.dispose();
    _port = null;
    return true;
  }

  static Future<List<String>> getPortNames() async {
    final ports = await FlSerial.availablePorts();
    return ports.map((p) => "${p.path} - ${p.description}").toList();
  }

  @override
  Future<bool> openPort(Map settings) async {
    _port = FlSerial();
    _readBuffer.clear();

    _eventsSub = _port!.events.listen(_onSerialEvent);

    final config = SerialConfig(
      baudRate: int.parse(settings["baudRate"]),
      dataBits: _mapDataBits(settings["byte_size"]),
      stopBits: _mapStopBits(settings["bit_stop"]),
      parity: _mapParity(settings["parity"]),
      flowControl: _mapFlowControl(settings["flow_control"]),
    );

    final ok = await _port!.open(settings["portName"], config);

    if (!ok) {
      _eventsSub?.cancel();
      _eventsSub = null;
      await _port!.dispose();
      _port = null;
    }

    _isOpen = ok;
    return ok;
  }

  void _onSerialEvent(SerialEvent event) {
    switch (event.type) {
      case SerialEventType.data:
        final bytes = event.data as Uint8List;
        _readBuffer.addAll(bytes);
        odDataRecived.broadcast(ReadCommEventArgs(bytes.length, _cts, _dsr));
        break;
      case SerialEventType.lineStatusChanged:
        final status = Map<String, bool>.from(event.data as Map);
        _cts = status['CTS'] ?? _cts;
        _dsr = status['DSR'] ?? _dsr;
        odDataRecived.broadcast(ReadCommEventArgs(0, _cts, _dsr));
        break;
      case SerialEventType.disconnected:
        _isOpen = false;
        break;
      default:
        break;
    }
  }

  int _mapDataBits(String? value) {
    return int.tryParse(value ?? "8") ?? 8;
  }

  int _mapStopBits(String? value) {
    // flserial 0.6.0 supports only 1 or 2 stop bits.
    switch (value) {
      case "2":
        return 2;
      default:
        return 1;
    }
  }

  int _mapParity(String? value) {
    // flserial 0.6.0 supports 0: none, 1: odd, 2: even.
    switch (value) {
      case "odd":
        return 1;
      case "even":
        return 2;
      default:
        return 0;
    }
  }

  int _mapFlowControl(String? value) {
    // flserial 0.6.0 supports 0: none, 1: RTS/CTS, 2: XON/XOFF.
    switch (value) {
      case "hardware":
        return 1;
      case "software":
        return 2;
      default:
        return 0;
    }
  }

  void enableRTS(bool value) {
    _port?.setRTS(value);
  }

  void enableDTR(bool value) {
    _port?.setDTR(value);
  }

  bool getCTS() {
    return _port?.getModemStatus()['CTS'] ?? false;
  }

  bool getDSR() {
    return _port?.getModemStatus()['DSR'] ?? false;
  }

  @override
  Uint8List read(int len) {
    if (_readBuffer.isEmpty) {
      return Uint8List(0);
    }
    final take = len < _readBuffer.length ? len : _readBuffer.length;
    final dataRead = Uint8List.fromList(_readBuffer.sublist(0, take));
    _readBuffer.removeRange(0, take);
    return dataRead;
  }

  @override
  int write(Uint8List data) {
    _port?.write(data);
    return data.length;
  }

  @override
  Event<ReadCommEventArgs> odDataRecived = Event();

  @override
  bool isOpen() {
    return _isOpen;
  }
}
