import 'package:test_flutter/iodev/enums.dart';

class DevConfig {
  final DevType devType;
  final String hostName;
  final String channelName;
  final String portName;
  final int localPort;
  final int remotePort;
  final int baudRate;

  DevConfig(this.devType, this.hostName, this.channelName, this.portName,
      this.localPort, this.remotePort, this.baudRate);
  DevConfig.empty() : this(DevType.none, "", "", "", 0, 0, 0);
  DevConfig.setupTCPClient(String tcpHost, int tcpPort)
      : this(DevType.tcpCli, tcpHost, "", "", 0, tcpPort, 0);
  DevConfig.setupTCPServer(int tcpPort)
      : this(DevType.tcpSrv, "", "", "", tcpPort, 0, 0);
  DevConfig.setupSerialPort(String portName, int baudRate)
      : this(DevType.serial, "", "", portName, 0, 0, baudRate);
  DevConfig.setupUDP(String udpHost, int localPort, int remotePort)
      : this(DevType.udp, udpHost, "", "", localPort, remotePort, 0);
  DevConfig.setupWS(String channelName)
      : this(DevType.websocket, "", channelName, "", 0, 0, 0);
}
