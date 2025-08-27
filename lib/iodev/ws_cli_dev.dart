import 'dart:async';
import 'dart:typed_data';

import 'package:test_flutter/iodev/enums.dart';

import 'basic_dev.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WsCliDev extends BasicDev {
  WebSocketChannel? sock;

  @override
  Future<int> closeDev() async {
    sock?.sink.close();
    super.closeDev();
    return 0;
  }

  @override
  Future<int> openDev(Map config) async {
    super.openDev(config);
    sock = IOWebSocketChannel.connect(configData.channelName);

    sock?.stream.listen(
      (event) {
        data.add(Uint8List.fromList(event.toString().codeUnits));
        controller.add(EventType.input);
      },
      onError: (error) {
        print('Error: $error');
        lastError = error.toString();
        sock?.sink.close();
        sock = null;
      },
      onDone: () {
        print('Server disconnected.');
        sock?.sink.close();
        sock = null;
      },
    );
    return isDevOpen() ? 0 : 1;
  }

  @override
  Future<int> writeDev(Uint8List data) async {
    sock?.sink.add(data);
    return data.length;
  }

  @override
  bool isDevOpen() {
    return sock != null;
  }
}
