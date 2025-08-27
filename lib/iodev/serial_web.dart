import 'dart:async';
import 'dart:typed_data';
import 'package:test_flutter/iodev/basic_dev.dart';
import 'package:webserial/webserial.dart';
import 'dart:js_interop';

class SerialDev extends BasicDev {
  //FlSerial serial = FlSerial();
  JSSerialPort? _port;
  WritableStreamDefaultWriter? _writer = null;
  ReadableStreamDefaultReader? _reader = null;
  int ocount = 0;

  @override
  Future<int> closeDev() async {
    _writer?.releaseLock();
    _reader?.releaseLock();
    _port?.close();
    super.closeDev();
    return 0;
  }

  @override
  Future<int> openDev(Map config) async {
    super.openDev(config);

    try {
      // Create filter options for specific vendor ID
      final filters = [
        //  JSFilterObject(usbVendorId: 0xcafe, usbProductId: 0x4009)
      ];

      _port = await requestWebSerialPort(null);
      print("got serial port: $_port");
    } catch (e) {
      print(e);
      return 0;
    }

    if (_port?.readable == null) {
      // Open the serial port.
      await _port
          ?.open(
            JSSerialOptions(
              baudRate: int.parse(config["baudRate"]),
              dataBits: int.parse(config["byte_size"]),
              stopBits: int.parse(config["bit_stop"]),
              parity: config["parity"],
              bufferSize: 64,
              flowControl: config["flow_control"],
            ),
          )
          .toDart;
      _writer = _port?.writable?.getWriter();
      _reader = _port?.readable?.getReader() as ReadableStreamDefaultReader;
      print("port opened: ${_port?.readable}");
    } else {
      print("port already opened: ${_port?.readable}");
    }

    return 1;
  }

  @override
  Future<Uint8List> readDev() async {
    final result = await _reader?.read().toDart;
    if (result != null) {
      if (result.done) return Uint8List(0);
      return result.value as Uint8List;
    }
    return Uint8List(0);
  }

  @override
  Future<int> writeDev(Uint8List data) async {
    for (int i = 0; i < data.length; i++) {
      final JSUint8Array jsReq = data.sublist(i, i + 1).toJS;
      _writer?.write(jsReq);
      _writer?.ready;
    }
    // _writer?.releaseLock();
    return data.length;
  }

  @override
  bool isDevOpen() {
    return _port != null;
  }
}
