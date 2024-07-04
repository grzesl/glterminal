import 'dart:html';

class WebStorage {
  final Storage _localStorage = window.localStorage;


  Future putList(String id, List<String> value) async {
    _localStorage[id] = value.join(" **-** ");
  }
  Future putBool(String id, bool value) async {
    _localStorage[id] = value.toString();
  }
  Future put(String id, String value) async {
    _localStorage[id] = value;
  }

  Future flush() async  {

  }

  String get(String id, String def)  => _localStorage[id]==null?def:_localStorage[id]!;
  bool getBool(String id, String def)  => bool.parse(_localStorage[id] == null?def:_localStorage[id]!);
  List<String> getStringList(String id, String def)  =>(_localStorage[id] == null? def :_localStorage[id]! ).split(" **;** ");

  Future invalidate(String id) async {
    _localStorage.remove(id);
  }
}