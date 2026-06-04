// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, prefer_final_fields


import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:file_selector/file_selector.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:test_flutter/comm/basic_comm.dart';
import 'package:test_flutter/comm/flserial_comm.dart';
import 'package:test_flutter/pages/utils/log_direction.dart';
import 'package:test_flutter/pages/utils/log_record.dart';
import 'package:test_flutter/pages/utils/symbol.dart';
import 'package:test_flutter/widgets/led_ctrl.dart';

/// App-wide theme mode, persisted in the "settings" box under "dark_mode".
/// MyApp rebuilds the MaterialApp whenever this changes.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Read the saved theme before the first frame to avoid a light-mode flash.
  try {
    final box = await Hive.openBox("settings");
    if (box.get("dark_mode", defaultValue: false) == true) {
      themeNotifier.value = ThemeMode.dark;
    }
  } catch (_) {
    // Box may be locked by another instance; fall back to the default theme.
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blueGrey,
        brightness: brightness,
      ),
      useMaterial3: true,
    );
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'GL Terminal',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: mode,
          home: const MyHomePage(title: 'GL Terminal 1.07'),
        );
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
  BasicComm _comm = FlSerialComm();
  List<String> _baudRates = <String>['9600', '19200', '57600', '115200'];
  String _baudRate = "9600";

  List<String> _byteSizes = <String>['5', '6', '7', '8'];
  String _byteSize = "8";

  // flserial 0.6.0 supports parity none/odd/even and stop bits 1/2 only.
  List<String> _parities = <String>['none', 'even', 'odd'];
  String _parity = "none";

  List<String> _stopBits = <String>['1', '2'];
  String _stopBit = "1";

  List<String> _flowControls = <String>['none', 'hardware', 'software'];
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

  List<LogRecord> _logRecords = [];
  ScrollController _logScrollController = ScrollController();
  Timer? _logRefreshTimer;

  Box? _settings;

  bool _appendCR = false;
  bool _appendLF = false;

  bool _enableRTS = true;
  bool _enableDTR = true;

  bool _ctsEnabled = false;
  bool _dsrEnabled = false;

  bool _darkMode = themeNotifier.value == ThemeMode.dark;

  void refreshPrtNames() async
   {
    _portNames = await FlSerialComm.getPortNames();
    if(_portNames.isEmpty) {
    _portNames.add("<EMPTY>");
    }
   }

   /// Appends a record to the log window (oldest at the top, newest at the
   /// bottom) and keeps the newest record in view. [len] is the raw byte
   /// count for data entries and null for informational/status lines.
   void appendLog(LogDirection dir, String msg, {int? len}) {
     _logRecords.add(LogRecord(
       time: DateTime.now().toLocal(),
       direction: dir,
       message: msg,
       length: len,
     ));
     scheduleLogRefresh();
   }

   /// Coalesces rapid log appends into at most one rebuild per ~50 ms so a burst
   /// of incoming data (e.g. when an RTS/DTR toggle resets the device and it
   /// floods output) can't storm setState and freeze the UI thread.
   void scheduleLogRefresh() {
     if (_logRefreshTimer != null) return;
     _logRefreshTimer = Timer(const Duration(milliseconds: 50), () {
       _logRefreshTimer = null;
       if (!mounted) return;
       setState(() {});
       scrollLogToBottom();
     });
   }

   /// Persists the current log records to settings.
   void saveLog() {
     _settings?.put("log_records", _logRecords.map((r) => r.toMap()).toList());
     _settings?.flush();
   }

   /// Scrolls the log window to the bottom after the new record has been laid
   /// out. Doing it post-frame ensures maxScrollExtent reflects the appended
   /// row; the hasClients guard avoids crashing before the list is built.
   void scrollLogToBottom() {
     WidgetsBinding.instance.addPostFrameCallback((_) {
       if (_logScrollController.hasClients) {
         _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);
       }
     });
   }

   /// Builds a single log record row: time | direction | length | data.
   Widget buildLogRow(LogRecord record) {
     final scheme = Theme.of(context).colorScheme;
     final bool dark = Theme.of(context).brightness == Brightness.dark;

     Color dirColor;
     String dirStr;
     switch (record.direction) {
       case LogDirection.input:
         dirStr = "<-";
         dirColor = dark ? Colors.lightBlue.shade300 : Colors.blue.shade700;
         break;
       case LogDirection.output:
         dirStr = "->";
         dirColor = dark ? Colors.lightGreen.shade300 : Colors.green.shade700;
         break;
       default:
         dirStr = "--";
         dirColor = scheme.onSurfaceVariant;
     }

     const mono = TextStyle(fontFamily: 'monospace', fontSize: 13);
     final muted = mono.copyWith(color: scheme.onSurfaceVariant);

     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
       decoration: BoxDecoration(
         border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
       ),
       child: Row(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           SizedBox(
             width: 96,
             child: Text(record.timeText, style: muted),
           ),
           SizedBox(
             width: 26,
             child: Text(dirStr,
                 style: mono.copyWith(
                     color: dirColor, fontWeight: FontWeight.bold)),
           ),
           SizedBox(
             width: 44,
             child: Text(record.length?.toString() ?? "",
                 textAlign: TextAlign.right, style: muted),
           ),
           const SizedBox(width: 8),
           Expanded(
             child: SelectableText(record.message, style: mono),
           ),
         ],
       ),
     );
   }

   /// Dense, rounded input decoration shared by every port-setting dropdown.
   InputDecorationTheme settingInputTheme() => InputDecorationTheme(
         isDense: true,
         contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
       );

   /// Builds a compact, dense dropdown with a floating label and rounded border
   /// for the port settings bar so each control stays small and self-describing.
   Widget buildSettingDropdown({
     required String label,
     required double width,
     required String initial,
     required List<String> items,
     required ValueChanged<String> onSelected,
   }) {
     return DropdownMenu<String>(
       width: width,
       label: Text(label),
       initialSelection: initial,
       textStyle: const TextStyle(fontSize: 13),
       inputDecorationTheme: settingInputTheme(),
       onSelected: (value) {
         if (value != null) onSelected(value);
       },
       dropdownMenuEntries: items
           .map((val) => DropdownMenuEntry<String>(value: val, label: val))
           .toList(),
     );
   }

   /// Column-title header row that sits above the log rows.
   Widget buildLogHeader() {
     final scheme = Theme.of(context).colorScheme;
     final style = TextStyle(
       fontFamily: 'monospace',
       fontSize: 12,
       fontWeight: FontWeight.bold,
       color: scheme.onSurfaceVariant,
     );
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
       decoration: BoxDecoration(
         color: scheme.surfaceContainerHighest,
         border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
       ),
       child: Row(
         children: [
           SizedBox(width: 96, child: Text("Time", style: style)),
           SizedBox(width: 26, child: Text("Dir", style: style)),
           SizedBox(
               width: 44,
               child: Text("Len", style: style, textAlign: TextAlign.right)),
           const SizedBox(width: 8),
           Expanded(child: Text("Data", style: style)),
         ],
       ),
     );
   }

   /// One macro (F1..F8) button with its programmed-shortcut preview.
   Widget buildMacroButton(LogicalKeyboardKey key, String label, int index) {
     return SizedBox(
       height: 48,
       width: 64,
       child: ElevatedButton(
         style: ElevatedButton.styleFrom(
           padding: EdgeInsets.zero,
           shape:
               RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
         ),
         onPressed: _isCommOpen ? () => onMacroClick(key) : null,
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Text(label),
             Text(getStringShortut(_macroList[index]),
                 style: const TextStyle(fontSize: 8)),
           ],
         ),
       ),
     );
   }

   /// A labelled switch used for the RTS/DTR lines.
   Widget buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
     return Row(
       mainAxisSize: MainAxisSize.min,
       children: [
         Text(label),
         Switch(value: value, onChanged: onChanged),
       ],
     );
   }

   /// A labelled status LED used for the CTS/DSR lines.
   Widget buildLed(String label, bool isOn) {
     return Row(
       mainAxisSize: MainAxisSize.min,
       children: [
         Text(label),
         const SizedBox(width: 4),
         LedCtrl(isOn: isOn),
       ],
     );
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
      
      appendLog(LogDirection.none, "MACRO Cleard...");

      _settings?.put("macro_list", _macroList);
      _settings?.flush();
    } else if(clear == false) {
      if(_macroList[map].isEmpty) {

      setState(() {
        _macroList[map] = _sendTextController.text;
      });
      
       

        appendLog(LogDirection.none, "MACRO Programmed...");

        _settings?.put("macro_list", _macroList);
        _settings?.flush();
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
      } else {
        return KeyEventResult.ignored;
      }
    }
    
   void onSendAction(String value)
   {

    if(_isCommOpen == false) {
      appendLog(LogDirection.output, "Port closed!");
      return;
    }

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
    
    final bytes = stringToUint8List(value);
    _comm.write(bytes);

    appendLog(LogDirection.output, value, len: bytes.length);

    _settings?.put("send_history", _sendTextHistory);
    _settings?.flush();
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


   void onPortOpen() async {
             
                        if(_isCommOpen) {
                         
                          setState(() {
                            _portOpenText = "Open";
                            _portOpenIcon = Icons.play_arrow;
                            _isCommOpen = false;
                          });
                          _comm.closePort();
        
        
        
                          appendLog(LogDirection.none, "Port closed...");

                          saveLog();
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

                                  appendLog(LogDirection.input,
                                      "CTS: $_ctsEnabled DSR: $_dsrEnabled");
                                }
                                if(args.dataLen > 0) {

                                  String data =
                                      uint8ListToString(_comm.read(args.dataLen));

                                  appendLog(LogDirection.input, data, len: args.dataLen);
                                }
                              }
                          },);
                          if(await _comm.openPort({ "portName":_portName, "baudRate":_baudRate,
                          "byte_size": _byteSize, "parity": _parity, "bit_stop": _stopBit,
                          "flow_control": _flowControl})) {
                            setState(() {
                              _portOpenText = "Close";
                              _portOpenIcon = Icons.close;
                              _isCommOpen = true;
                            });

                            

        
                            _settings?.put("baud_rate", _baudRate);
                            _settings?.put("port_name", _portName);
                            _settings?.put("byte_size", _byteSize);
                            _settings?.put("parity", _parity);
                            _settings?.put("bit_stop", _stopBit);
                            _settings?.put("flow_control", _flowControl);
                            _settings?.flush();
                            
        
                            appendLog(LogDirection.none, "Port openned $_portName $_baudRate $_byteSize $_parity $_stopBit $_flowControl...");
        
                          }
                        }
   }

  @override
  void initState() {
    super.initState();
    refreshPrtNames();
    loadSettings();

    if(_sendTextHistory.isNotEmpty) {
      _sendTextController.text = _sendTextHistory.first;
    }
  }

  @override
  void dispose() {
    _logRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> loadSettings() async {
    try {
      final box = await Hive.openBox("settings");
      if (!mounted) return;
      setState(() {
        _settings = box;
        _logRecords = (box.get("log_records", defaultValue: []) as List)
            .map((e) => LogRecord.fromMap(Map.from(e as Map)))
            .toList();
        _baudRate = box.get("baud_rate", defaultValue: _baudRate);
        _portName = box.get("port_name", defaultValue: _portName);

        _byteSize = box.get("byte_size", defaultValue: _byteSize);
        _parity = box.get("parity", defaultValue: _parity);
        _stopBit = box.get("bit_stop", defaultValue: _stopBit);
        _flowControl = box.get("flow_control", defaultValue: _flowControl);

        _sendTextHistory = List<String>.from(box.get("send_history", defaultValue: _sendTextHistory) as List);
        _macroList = List<String>.from(box.get("macro_list", defaultValue: _macroList) as List);
        _appendCR = box.get("append_cr", defaultValue: _appendCR);
        _appendLF = box.get("append_lf", defaultValue: _appendLF);
        _enableRTS = box.get("enable_rts", defaultValue: _enableRTS);
        _enableDTR = box.get("enable_dtr", defaultValue: _enableDTR);
        _darkMode = box.get("dark_mode", defaultValue: _darkMode);
        themeNotifier.value = _darkMode ? ThemeMode.dark : ThemeMode.light;

        if (_sendTextHistory.isNotEmpty) {
          _sendTextController.text = _sendTextHistory.first;
        }
      });
    } catch (e) {
      // The settings box may be locked by another running instance, or the
      // storage may be unavailable. The app keeps working with in-memory
      // defaults; settings just won't persist for this session.
      debugPrint("Hive settings unavailable: $e");
    }
  }

  /// Toggles night mode and persists the choice. The whole app re-themes via
  /// [themeNotifier].
  void toggleDarkMode() {
    setState(() {
      _darkMode = !_darkMode;
    });
    themeNotifier.value = _darkMode ? ThemeMode.dark : ThemeMode.light;
    _settings?.put("dark_mode", _darkMode);
    _settings?.flush();
  }

  /// Shows a transient message both in the log and as a SnackBar.
  void notify(String message) {
    appendLog(LogDirection.none, message);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Exports all current log records to a JSON file chosen by the user.
  Future<void> exportLog() async {
    try {
      final location = await getSaveLocation(
        suggestedName: "glterminal_log.json",
        acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON', extensions: ['json']),
        ],
      );
      if (location == null) return;
      final data = jsonEncode(_logRecords.map((r) => r.toMap()).toList());
      await File(location.path).writeAsString(data);
      notify("Log exported (${_logRecords.length} records) -> ${location.path}");
    } catch (e) {
      notify("Export failed: $e");
    }
  }

  /// Imports log records from a JSON file, replacing the current log.
  Future<void> importLog() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(label: 'JSON', extensions: ['json']),
        ],
      );
      if (file == null) return;
      final decoded = jsonDecode(await file.readAsString()) as List;
      final imported = decoded
          .map((e) => LogRecord.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      setState(() {
        _logRecords = imported;
      });
      saveLog();
      scrollLogToBottom();
      notify("Log imported (${imported.length} records) from ${file.name}");
    } catch (e) {
      notify("Import failed: $e");
    }
  }

  /// Picks a file and streams its raw bytes out over the serial port.
  Future<void> sendFile() async {
    if (!_isCommOpen) {
      notify("Port closed!");
      return;
    }
    try {
      final file = await openFile();
      if (file == null) return;
      final bytes = await file.readAsBytes();
      _comm.write(bytes);
      appendLog(LogDirection.output, "<FILE: ${file.name}>", len: bytes.length);
      notify("Sent file ${file.name} (${bytes.length} bytes)");
    } catch (e) {
      notify("Send file failed: $e");
    }
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
      appBar: AppBar(
        centerTitle: true,
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: _darkMode ? "Light mode" : "Night mode",
            icon: Icon(_darkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: toggleDarkMode,
          ),
          IconButton(
            tooltip: "Clear log",
            icon: const Icon(Icons.delete),
            onPressed: () {
              setState(() {
                _logRecords.clear();
              });
              saveLog();
            },
          ),
          IconButton(
            tooltip: _portOpenText,
            icon: Icon(_portOpenIcon),
            onPressed: onPortOpen,
          ),
          PopupMenuButton<String>(
            tooltip: "More",
            onSelected: (value) {
              switch (value) {
                case "export":
                  exportLog();
                  break;
                case "import":
                  importLog();
                  break;
                case "sendfile":
                  sendFile();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: "export",
                child: ListTile(
                  leading: Icon(Icons.file_download),
                  title: Text("Export log"),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: "import",
                child: ListTile(
                  leading: Icon(Icons.file_upload),
                  title: Text("Import log"),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: "sendfile",
                enabled: _isCommOpen,
                child: const ListTile(
                  leading: Icon(Icons.upload_file),
                  title: Text("Send file over port"),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Focus(
        onKeyEvent: handleKeyEvent,
        child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    DropdownMenu(
                      width: 240,
                      label: const Text("Port"),
                      textStyle: const TextStyle(fontSize: 13),
                      inputDecorationTheme: settingInputTheme(),
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
                      tooltip: "Refresh ports",
                      icon: const Icon(Icons.refresh),
                      onPressed: () {
                        setState(() {
                          refreshPrtNames();
                        });
                      },
                    ),
                    buildSettingDropdown(
                      label: "Baud",
                      width: 120,
                      initial: _baudRate,
                      items: _baudRates,
                      onSelected: (v) => _baudRate = v,
                    ),
                    buildSettingDropdown(
                      label: "Bits",
                      width: 80,
                      initial: _byteSize,
                      items: _byteSizes,
                      onSelected: (v) => _byteSize = v,
                    ),
                    buildSettingDropdown(
                      label: "Parity",
                      width: 120,
                      initial: _parity,
                      items: _parities,
                      onSelected: (v) => _parity = v,
                    ),
                    buildSettingDropdown(
                      label: "Stop",
                      width: 80,
                      initial: _stopBit,
                      items: _stopBits,
                      onSelected: (v) => _stopBit = v,
                    ),
                    buildSettingDropdown(
                      label: "Flow",
                      width: 140,
                      initial: _flowControl,
                      items: _flowControls,
                      onSelected: (v) => _flowControl = v,
                    ),
                    FilledButton(
                      onPressed: () => onPortOpen(),
                      child: Row(mainAxisSize: MainAxisSize.min,
                          children: [Icon(_portOpenIcon), Text(_portOpenText)]),
                    ),
                  ],
                ),
                ),
                SizedBox(height: 12,),
        
                Expanded(
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      children: [
                        buildLogHeader(),
                        Expanded(
                          child: _logRecords.isEmpty
                              ? Center(
                                  child: Text("Log window...",
                                      style: TextStyle(
                                          color: Theme.of(context).hintColor)),
                                )
                              : ListView.builder(
                                  controller: _logScrollController,
                                  physics: ClampingScrollPhysics(),
                                  padding: EdgeInsets.zero,
                                  itemCount: _logRecords.length,
                                  itemBuilder: (context, index) =>
                                      buildLogRow(_logRecords[index]),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 8,
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: "Clear input",
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        setState(() {
                          _sendTextController.text = "";
                        });
                      },
                    ),
                    Expanded(
                      child: DropdownMenu(
                          expandedInsets: EdgeInsets.zero,
                          controller: _sendTextController,
                          initialSelection: _sendTextHistory[1],
                          hintText: "Text to send...",
                          inputDecorationTheme: settingInputTheme(),
                          dropdownMenuEntries:
                              _sendTextHistory.map<DropdownMenuEntry<String>>(
                            (val) {
                              return DropdownMenuEntry(value: val, label: val);
                            },
                          ).toList()),
                    ),
                    const SizedBox(width: 8),
                    buildToggle("+CR", _appendCR, (value) {
                      setState(() {
                        _appendCR = value;
                      });
                      _settings?.put("append_cr", _appendCR);
                      _settings?.flush();
                    }),
                    buildToggle("+LF", _appendLF, (value) {
                      setState(() {
                        _appendLF = value;
                      });
                      _settings?.put("append_lf", _appendLF);
                      _settings?.flush();
                    }),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _isCommOpen
                          ? () {
                              onSendAction(_sendTextController.text);
                            }
                          : null,
                      icon: const Icon(Icons.send),
                      label: const Text("SEND"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    buildMacroButton(LogicalKeyboardKey.f1, "F1", 0),
                    buildMacroButton(LogicalKeyboardKey.f2, "F2", 1),
                    buildMacroButton(LogicalKeyboardKey.f3, "F3", 2),
                    buildMacroButton(LogicalKeyboardKey.f4, "F4", 3),
                    buildMacroButton(LogicalKeyboardKey.f5, "F5", 4),
                    buildMacroButton(LogicalKeyboardKey.f6, "F6", 5),
                    buildMacroButton(LogicalKeyboardKey.f7, "F7", 6),
                    buildMacroButton(LogicalKeyboardKey.f8, "F8", 7),
                    const SizedBox(width: 8),
                    buildToggle("RTS", _enableRTS, (value) {
                      setState(() {
                        _enableRTS = value;
                      });
                      if (_isCommOpen) {
                        try {
                          (_comm as FlSerialComm).enableRTS(value);
                        } catch (e) {
                          debugPrint("setRTS failed: $e");
                        }
                      }
                      _settings?.put("enable_rts", value);
                      _settings?.flush();
                    }),
                    buildToggle("DTR", _enableDTR, (value) {
                      setState(() {
                        _enableDTR = value;
                      });
                      if (_isCommOpen) {
                        try {
                          (_comm as FlSerialComm).enableDTR(value);
                        } catch (e) {
                          debugPrint("setDTR failed: $e");
                        }
                      }
                      _settings?.put("enable_dtr", value);
                      _settings?.flush();
                    }),
                    const SizedBox(width: 8),
                    buildLed("CTS", _ctsEnabled),
                    buildLed("DSR", _dsrEnabled),
                  ],
                ),
              ]
              ),
            ),
      ),
    );
  }
}
