// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, prefer_final_fields
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:test_flutter/comm/basic_comm.dart';
import 'package:test_flutter/comm/webserial_comm.dart';
import 'package:test_flutter/db/web_storage.dart';
import 'package:test_flutter/pages/log_view.dart';
import 'package:test_flutter/pages/utils/log_direction.dart';
import 'package:test_flutter/pages/utils/symbol.dart';
import 'package:test_flutter/widgets/led_ctrl.dart';

void main() async {
  //await Hive.initFlutter();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GL Terminal',
      
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.grey),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'GL Terminal 1.09'),
      routes: {
        '/logview':(context)=>LogView(),
      },
    );
  }
}


class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  late BasicComm _comm;

  List<String> _baudRates = <String>['9600', '19200', '57600', '115200'];
  String _baudRate = "9600";

  List<String> _byteSizes = <String>[ '7', '8'];
  String _byteSize = "8";

  List<String> _parities = <String>['none', 'even', 'odd',];
  String _parity = "none";

  List<String> _stopBits = <String>['1', '2'];
  String _stopBit = "1";

  List<String> _flowControls = <String>['none', 'hardware', ];
  String _flowControl = "none";

  List<String> _portNames = [];
  String _portName = "<BRAK>";
  TextEditingController _portNameController = TextEditingController();

  String _portOpenText = "Open";
  IconData _portOpenIcon = Icons.play_arrow;

  List<String> _sendTextHistory = ["", ""];
  TextEditingController _sendTextController = TextEditingController();

  List<String> _macroList = ["", "", "", "", "", "", "", ""];

  bool _isCommOpen = false;

  TextEditingController _logController = TextEditingController();
  ScrollController _logScrollController = ScrollController();

  //late Box _settings;
  late WebStorage _settings;

  bool _appendCR = false;
  bool _appendLF = false;

  bool _enableRTS = true;
  bool _enableDTR = true;

  bool _ctsEnabled = false;
  bool _dsrEnabled = false;

  Future< List<String>> refreshPrtNames() async
   {
      var  portNames = await BasicComm.getPortNames();
    return portNames;
   }

   String buildLog(LogDirection dir, String msg) {

    String res = "";

    DateTime now = DateTime.now().toLocal();
    String dateStr = "";
    String dirStr = "";
    switch (dir) {
      case LogDirection.input:
        dateStr = "${now.hour.toString()}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}.${now.millisecond.toString().padLeft(3,'0')}";
        dirStr = "<-";
        break;
      case LogDirection.output:
        dateStr = "${now.hour.toString()}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}.${now.millisecond.toString().padLeft(3,'0')}";
        dirStr = "->";
        break;
      default:
        dateStr = now.toString();
        dirStr = "  ";
    }
    res = "$dateStr $dirStr $msg\n";
    return res;
   }





   bool onMacroClick(KeyboardKey key, {bool clear = false}) {
    int map = -1;
    switch(key) {
      case  LogicalKeyboardKey.f1:
      map = 0; break;
      case  LogicalKeyboardKey.f2:
      map = 1; break;
      case  LogicalKeyboardKey.f3:
      map = 2; break;
      case  LogicalKeyboardKey.f4:
      map = 3; break;
      case  LogicalKeyboardKey.f5:
      map = 4; break;
      case  LogicalKeyboardKey.f6:
      map = 5; break;
      case  LogicalKeyboardKey.f7:
      map = 6; break;
      case  LogicalKeyboardKey.f8:
      map = 7; break;
      default :
        return false;
    }

    if(clear && _macroList[map].isEmpty == false) {
      setState(() {
       _macroList[map] = ""; 
      });
      
      _logController.text += buildLog(LogDirection.none, "MACRO Cleard...");
      _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);

      _settings.putList("macro_list", _macroList);
      _settings.flush();
    } else if(clear == false) {
      if(_macroList[map].isEmpty) {

      setState(() {
        _macroList[map] = _sendTextController.text;
      });
      
       

        _logController.text += buildLog(LogDirection.none, "MACRO Programmed...");
        _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);

       _settings.putList("macro_list", _macroList);
       _settings.flush();
      } else if(clear == false){
        onSendAction(_macroList[map]);
      }
    } 

      return true;
   }


  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {

      if (event is KeyDownEvent) {
        return onMacroClick(event.logicalKey)?KeyEventResult.handled: KeyEventResult.ignored;
      }
      else if (event is KeyRepeatEvent) {
        return onMacroClick(event.logicalKey, clear: true)?KeyEventResult.handled: KeyEventResult.ignored;
        _logController.text += buildLog(LogDirection.none, "MACRO Cleared...");
        _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);
      } else {
        return KeyEventResult.ignored;
      }
    }
    
   void onSendAction(String value)
   {

    if(_isCommOpen == false) {
      _logController.text += buildLog(LogDirection.output, "Port closed!");
      _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);
      return;
    }

    value ??= _sendTextController.text;


    _sendTextHistory.remove(value);

    setState(() {
      _sendTextHistory.insert(1, value);
    });

      if (_appendCR) {
        value += "<CR>";
      }

      if (_appendLF) {
        value += "<LF>";
      }
    
    _comm.write(StringToUint8List(value));

    _logController.text += buildLog(LogDirection.output, value);
    _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);

    _settings.put("send_history", _sendTextHistory.join(" **;** "));
    _settings.flush();
   }

   String getStringShortut(String macro) {
    String result = "";
    if(macro.isNotEmpty && macro.length < 6) {
      result = macro;
    } else if (macro.isNotEmpty) {
      result = "${macro.substring(0,5)}...";
    }
    return result;
   }


   void onPortOpen(){
             
                        if(_isCommOpen) {
                         
                          /*setState(() {
                            _portOpenText = "Open";
                            _portOpenIcon = Icons.play_arrow;
                            _isCommOpen = false;
                          });
                          _comm.closePort();
        
        
        
                          _logController.text += buildLog(LogDirection.none, "Port closed...");
                          _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);
        
                          _logController.text += buildLog(LogDirection.none, "Close browser tab to close port...");
                          _settings.put("log_string", _logController.text);
                          _settings.flush();*/

                          _logController.text += buildLog(LogDirection.none, "Close browser tab to close Serial Port...");
                          _settings.put("log_string", _logController.text);
                          _settings.flush();
                        } else {
                      

                          _comm.odDataRecived.unsubscribeAll();
                          _comm.odDataRecived.subscribe(
                            (args) {


                              if (args != null) {
                                if (args.cts != _ctsEnabled || args.dsr != _dsrEnabled) {
                                  setState(() {
                                    _ctsEnabled = args.cts;
                                    _dsrEnabled = args.dsr;
                                  });

                                  _logController.text += buildLog(
                                      LogDirection.input, "CTS: $_ctsEnabled DSR: $_dsrEnabled");
                                  _logScrollController
                                      .jumpTo(_logScrollController.position.maxScrollExtent);
                                }
                                if(args.dataLen > 0) {

                                  String data =
                                      Uint8ListToString(_comm.read(args.dataLen));
                        
                                  _logController.text +=
                                      buildLog(LogDirection.input, data);
                                  _logScrollController.jumpTo(_logScrollController
                                      .position.maxScrollExtent);
                                }
                              }
                          },);
                          if(_comm.openPort({ "portName":_portName, "baudRate":_baudRate, 
                          "byte_size": _byteSize, "parity": _parity, "bit_stop": _stopBit, 
                          "flow_control": _flowControl})) {
                            setState(() {
                              _portOpenText = "Close";
                              _portOpenIcon = Icons.close;
                              _isCommOpen = true;
                            });

                            

        
                             _settings.put("baud_rate", _baudRate);
                             _settings.put("port_name", _portName);
                             _settings.put("byte_size", _byteSize);
                             _settings.put("parity", _parity);
                             _settings.put("bit_stop", _stopBit);
                             _settings.put("flow_control", _flowControl);
                             _settings.flush();
                            
        
                            _logController.text += buildLog(LogDirection.none, "Port openned $_portName $_baudRate $_byteSize $_parity $_stopBit $_flowControl...");
                            _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);
        
                          }
                        }
   }

  @override
  void initState()  {
    super.initState();


  //if(GetPlatform.isWeb) {
    _comm = WebSerialComm();
  //} else {
  //  _comm = FlSerialComm();
  //}


   // refreshPrtNames();

   // _baudRate = _baudRates.first;
    //_portName = _portNames.first;

    //final box = Hive.openBox("settings").then(
    //(value) {

      setState(() {

      _settings = WebStorage();
      _logController.text =  _settings.get("log_string", "");
      _baudRate  =  _settings.get("baud_rate", "9600");
      _portName  =  _settings.get("port_name", "WebSerial");

      _byteSize =  _settings.get("byte_size", "8");
      _parity =  _settings.get("parity", "none");
      _stopBit =  _settings.get("bit_stop", "1");
      _flowControl =  _settings.get("flow_control", "none");

      _sendTextHistory =  _settings.getStringList("send_history", "  **;** <BEL>");
      _macroList =  _settings.getStringList("macro_list", "  **;** <BEL> **;** <ENQ> **;** <DLE> **;** ABC **;**  **;**  **;** ");
      _appendCR =  _settings.getBool("append_cr", "false");
      _appendLF =  _settings.getBool("append_lf", "false");
              
      });
      
  //  },
  //);


    //_settings.invalidate("send_history");

    if(_sendTextHistory.isNotEmpty) {
      _sendTextController.text = _sendTextHistory.first;
    }
/*
    recivedData.subscribe((args) {
      if(args != null){
        String data = Uint8ListToString(args.dataRecivied);

        _logController.text += buildLog(LogDirection.input, data);
        _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);
      }
    },);*/

  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      drawer: Drawer(
        backgroundColor: Colors.amber,
        child:Column (children: [
          DrawerHeader(child: Icon(Icons.favorite, size: 64,),),

          ListTile(
            leading: Icon(Icons.home),
            title: Text("LOG VIEW"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, "/logview");
            },
          )
        ],)
        
        
      ),
      appBar: AppBar(
        centerTitle: true,
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        actions: [IconButton(icon: Icon(Icons.delete), onPressed: () {
          setState(() {
            _logController.text = "";
          });

          _settings.put("log_string", _logController.text);
          _settings.flush();
          
        },),
        IconButton(icon: Icon(_portOpenIcon), onPressed: () {
            onPortOpen();
        },),
      
        ],
      ),
      body: Focus(
        onKeyEvent: handleKeyEvent,
        child: ListView(
          
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                Row(
                  children: [
                    SizedBox(width: 4,),
                    Text("Port\nName: "),
                    SizedBox(width: 4,),
                    DropdownMenu(
                      controller: _portNameController,
                      initialSelection: _portName,
                      
                      onSelected: (value) {
                        if (value != null) {
                        _portName = value;
                        } else {
                        _portName = _portNameController.text;
                        }
                      },
                      dropdownMenuEntries: _portNames.map<DropdownMenuEntry<String>>((val) {

                        final splitted = val.split(" - ");
                        return DropdownMenuEntry(value: splitted[0], label: val);
                      },).toList()),
                        IconButton(
                          icon: Icon(Icons.refresh),
                          onPressed: () async {
                            _portNames = await refreshPrtNames();
                            if(!_comm.isOpen()) return ;
                            if (_portNames.isEmpty) {
                              _portNames.add("<EMPTY>");
                            }
                            setState(() {
                              _portNames.add(" ");
                              _portName = _portNames[0];
                              _portNameController.text = _portName;
                            });
 
                    },),
                    SizedBox(width: 4,),
                    Text("Port\nBaudRate: "),
                    SizedBox(width: 4,),
                    DropdownMenu(
                      width: 120,
                      initialSelection: _baudRate,
                      onSelected: (value) {
                        _baudRate = value!;
                      },
                      dropdownMenuEntries: _baudRates.map<DropdownMenuEntry<String>>((val) {
                        return DropdownMenuEntry(value: val, label: val);
                      },).toList()),
                      SizedBox(width: 4,),
                      Row(
                        children: [
                            DropdownMenu(
                                width: 70,
                                initialSelection: _byteSize,
                                onSelected: (value) {
                                  _byteSize = value!;
                                },
                                dropdownMenuEntries:
                                    _byteSizes.map<DropdownMenuEntry<String>>(
                                  (val) {
                                    return DropdownMenuEntry(
                                        value: val, label: val);
                                  },
                                ).toList()),
                            SizedBox(width: 4,),
                            DropdownMenu(
                                width: 110,
                                initialSelection: _parity,
                                onSelected: (value) {
                                  _parity = value!;
                                },
                                dropdownMenuEntries:
                                    _parities.map<DropdownMenuEntry<String>>(
                                  (val) {
                                    return DropdownMenuEntry(
                                        value: val, label: val);
                                  },
                                ).toList()),
                            SizedBox(width: 4,),    
                            DropdownMenu(
                                width: 70,
                                initialSelection: _stopBit,
                                onSelected: (value) {
                                  _stopBit = value!;
                                },
                                dropdownMenuEntries:
                                    _stopBits.map<DropdownMenuEntry<String>>(
                                  (val) {
                                    return DropdownMenuEntry(
                                        value: val, label: val);
                                  },
                                ).toList()),
                            SizedBox(width: 4,),    
                            DropdownMenu(
                                width: 130,
                                initialSelection: _flowControl,
                                onSelected: (value) {
                                  _flowControl = value!;
                                },
                                dropdownMenuEntries:
                                    _flowControls.map<DropdownMenuEntry<String>>(
                                  (val) {
                                    return DropdownMenuEntry(
                                        value: val, label: val);
                                  },
                                ).toList()),
                        ],
                      ),
                      Expanded(child: SizedBox()),
                      FilledButton(  onPressed: _portNames.length > 0? () { 
                              onPortOpen();
                      } : null,
                      child: Row(children: [Icon(_portOpenIcon), Text(_portOpenText)],),
                      ),
                  ],
                ),
                SizedBox(height: 2,),
        
                SizedBox(
                  height: MediaQuery.of(context).size.height - 220,
                  child: TextField(
                    textAlign: TextAlign.start,
                    decoration: InputDecoration(border: OutlineInputBorder(borderSide: BorderSide(width: 1)), hintText: "Log window..."),
                    maxLines: null, 
                    expands: true, 
                    readOnly: true,
                    scrollController: _logScrollController,
                    scrollPhysics: ClampingScrollPhysics(),
                    controller: _logController,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
                SizedBox(
                  height: 2,
                ),
                Row(
                  children: [
                    IconButton(icon: Icon( Icons.clear_rounded), onPressed: () {
                      setState(() {
                        _sendTextController.text = "";
                      });
                    },),
                    Expanded(
                      child: DropdownMenu(
                          width: MediaQuery.of(context).size.width - 370,
                          controller: _sendTextController,
                          initialSelection: _sendTextHistory.length > 1? _sendTextHistory[1]: _sendTextHistory[0],
                          dropdownMenuEntries:
                              _sendTextHistory.map<DropdownMenuEntry<String>>(
                            (val) {
                              return DropdownMenuEntry(value: val, label: val);
                            },
                          ).toList()),
                    ),
                    SizedBox(
                      width: 2,
                    ),
                    Text("+CR"),
                    Switch(value: _appendCR, onChanged: (value) {
                      setState(() {
                        _appendCR = value;
                      });
                      _settings.put("append_cr", _appendCR.toString());
                      _settings.flush();
                    },),
                    SizedBox(
                      width: 2,
                    ),
                    Text("+LF"),
                    Switch(value: _appendLF, onChanged: (value) {
                      setState(() {
                        _appendLF = value;
                      });
                      _settings.put("append_lf", _appendLF.toString());
                      _settings.flush();
                    },),
                    SizedBox(
                      width: 2,
                    ),
                    FilledButton(
                      onPressed: _isCommOpen
                          ? () {
                              onSendAction(_sendTextController.text);
                            }
                          : null,
                      child: Row(
                        children: [Icon(Icons.send), Text("SEND")],
                      ),
                    ),
                  ],
                ),
                SizedBox(
                      height: 2,
                    ),
                Row(
                  children: [
                    SizedBox( height: 48, child: ElevatedButton(onPressed: _isCommOpen ? () => onMacroClick(LogicalKeyboardKey.f1): null, child:  Column(
                      children: [
                        Text("F1"),
                        Text(getStringShortut(_macroList[0]), style: TextStyle(fontSize: 8),),
                      ],
                    ))),
                    SizedBox( width: 2),
                    SizedBox( height: 48, child: ElevatedButton(onPressed: _isCommOpen ? () => onMacroClick(LogicalKeyboardKey.f2) : null, child:  Column(
                      children: [
                        Text("F2"),
                        Text(getStringShortut(_macroList[1]), style: TextStyle(fontSize: 8),),
                      ],
                    ))),
                    SizedBox( width: 2),
                    SizedBox( height: 48, child: ElevatedButton(onPressed:_isCommOpen ?  () => onMacroClick(LogicalKeyboardKey.f3) : null, child:  Column(
                      children: [
                        Text("F3"),
                        Text(getStringShortut(_macroList[2]), style: TextStyle(fontSize: 8),),
                      ],
                    ))),
                    SizedBox( width: 2),
                    SizedBox( height: 48, child: ElevatedButton(onPressed: _isCommOpen ? () => onMacroClick(LogicalKeyboardKey.f4) : null,  child:  Column(
                      children: [
                        Text("F4"),
                        Text(getStringShortut(_macroList[3]), style: TextStyle(fontSize: 8),),
                      ],
                    ))),
                    SizedBox( width: 2),
                    SizedBox( height: 48, child: ElevatedButton(onPressed: _isCommOpen ? () => onMacroClick(LogicalKeyboardKey.f5) : null,  child:  Column(
                      children: [
                        Text("F5"),
                        Text(getStringShortut(_macroList[4]), style: TextStyle(fontSize: 8),),
                      ],
                    ))),
                    SizedBox( width: 2),
                    SizedBox( height: 48, child: ElevatedButton(onPressed: _isCommOpen ?  () => onMacroClick(LogicalKeyboardKey.f6) : null,  child:  Column(
                      children: [
                        Text("F6"),
                        Text(getStringShortut(_macroList[5]), style: TextStyle(fontSize: 8),),
                      ],
                    ))),
                    SizedBox( width: 2),
                    SizedBox( height: 48, child: ElevatedButton(onPressed: _isCommOpen ? () => onMacroClick(LogicalKeyboardKey.f7) : null,  child:  Column(
                      children: [
                        Text("F7"),
                        Text(getStringShortut(_macroList[6]), style: TextStyle(fontSize: 8),),
                      ],
                    ))),
                    SizedBox( width: 2),
                    SizedBox( height: 48, child: ElevatedButton(onPressed: _isCommOpen ?  () => onMacroClick(LogicalKeyboardKey.f8) : null, child:  Column(
                      children: [
                        Text("F8"),
                        Text(getStringShortut(_macroList[7]), style: TextStyle(fontSize: 8),),
                      ],
                    ))),

                    SizedBox( width: 10),
                    Text("RTS"),
                    Switch(value: _enableRTS, onChanged: (value) {
                      setState(() {
                        _enableRTS = value;
                         _comm.enableRTS(_enableRTS);
                      });
                      _settings.put("enable_rts", _enableRTS.toString());
                      _settings.flush();
                    },),
                    SizedBox(
                      height: 2,
                    ),
                   Text("DTR"),
                    Switch(value: _enableDTR, onChanged: (value) {
                      setState(() {
                        _enableDTR = value;
                        _comm.enableDTR(_enableDTR);
                      });
                     _settings.put("enable_dtr", _enableDTR.toString());
                     _settings.flush();
                    },),
                    SizedBox(
                      height: 10,
                    ),
                    Text("CTS"),
                    LedCtrl(isOn:  _ctsEnabled),
                    SizedBox(
                      height: 2,
                    ),
                    Text("DSR"),
                    LedCtrl(isOn:  _dsrEnabled),

                  ],
                ),
              ]
              ),
            ),
          ],
        ),
      ),
    );
  }
}
