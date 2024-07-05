

import 'dart:convert';
import 'dart:typed_data';


int SymbolToChar(String c) {
  int ret = 0;

  switch(c) {

  case "<SOH>": ret = 0x01; break;
	case "<STX>": ret = 0x02; break;
	case "<ETX>": ret = 0x03; break;
	case "<EOT>": ret = 0x04; break;
	case "<ENQ>": ret = 0x05; break;
	case "<ACK>": ret = 0x06; break;
	case "<BEL>": ret = 0x07; break;
	case "<BS>": ret = 0x08; break;
	case "<TAB>": ret = 0x09; break;
	case "<LF>": ret = 0x0A; break;
	case "<VT>": ret = 0x0B; break;
	case "<FF>": ret = 0x0C; break;
	case "<CR>": ret = 0x0D; break;
	case "<SO>": ret = 0x0E; break;
	case "<SI>": ret = 0x0F; break;
	case "<DLE>": ret = 0x10; break;
	case "<DC1>": ret = 0x11; break;
	case "<DC2>": ret = 0x12; break;
	case "<DC3>": ret = 0x13; break;
	case "<DC4>": ret = 0x14; break;
	case "<NAK>": ret = 0x15; break;
	case "<SYN>": ret = 0x16; break;
	case "<ETB>": ret = 0x17; break;
	case "<CAN>": ret = 0x18; break;
	case "<EM>": ret = 0x19; break;
	case "<SUB>": ret = 0x1A; break;
	case "<ESC>": ret = 0x1B; break;
	case "<FS>": ret = 0x1C; break;
	case "<GS>": ret = 0x1D; break;
	case "<RS>": ret = 0x1E; break;
	case "<US>": ret = 0x1F; break;
  default:
    String hexStr = c.substring(3,5);
    ret = int.parse(hexStr, radix: 16);
  }


  return ret;
}

String GetMacro(String pattern, List<String> macroList) {
    if(pattern.length < 4){
      return "";
    }

   int fno = int.parse(pattern[3]);

   return macroList[fno];
}

List<Uint8List>  StringToMacroUint8List(String strings, List<String> macroList) {
  bool isopenb = false;
  String tmpMacro = "";
  StringBuffer outData = StringBuffer();
  
  for (int i = 0 ; i< strings.length;i++) {
        var b = strings[i];
    switch(b) {
      case "{":
      tmpMacro = b;
      isopenb = true;
      break;
      case "}":
      isopenb = false;
      tmpMacro += b;
      outData.write(GetMacro(tmpMacro, macroList));
      break;
      default:
      if(isopenb) {
        tmpMacro += b;
      } else {
        outData.write(b);
      }
    }
  }

  String out = outData.toString();

  List<String> parts = out.split("==");

  List<Uint8List> list = List.empty(growable: true);
  for(int i=0;i<parts.length;i++) {
    list.add(StringToUint8List(parts[i]));
  }

  return list;
}

Uint8List StringToUint8List (String strings) {

  bool isopenb = false;
  String tmpChar = "";
  BytesBuilder outData = BytesBuilder();

  for (int i = 0 ; i< strings.length;i++) {
    var b = strings[i];
    switch(b) {
      case "<":
      tmpChar = b;
      isopenb = true;
      break;
      case ">":
      isopenb = false;
      tmpChar += b;
      outData.addByte(SymbolToChar(tmpChar));
      break;
      default:
      if(isopenb) {
        tmpChar += b;
      } else {
        outData.add(ascii.encode(b));
      }
    }
  }
  return outData.toBytes();
}


String Uint8ListToString (Uint8List data) {
  String res = "";

  for (int i=0;i< data.length ; i++)
  {
    int b = data[i];
    String charStr;

   if (b > 126) { 
        charStr = "<0x";
        charStr += b.toRadixString(16);
        charStr += ">";
    } else {
      switch (b) {
        case 0x0:
          charStr = "<NUL>";break;
        case 0x1:
          charStr = "<SOH>";break;
        case 0x2:
          charStr = "<STX>";break;
        case 0x3:
          charStr = "<ETX>";break;
        case 0x4:
          charStr = "<EOT>";break;
        case 0x5:
          charStr = "<ENQ>";break;
        case 0x6:
          charStr = "<ACK>";break;
        case 0x7:
          charStr = "<BEL>";break;
        case 0x8:
          charStr = "<BS>";break;
        case 0x9:
          charStr = "<TAB>";break;
        case 0xA:
          charStr = "<LF>";break;
        case 0xB:
          charStr = "<VT>";break;
        case 0xC:
          charStr = "<FF>";break;
        case 0xD:
          charStr = "<CR>";break;
        case 0xE:
          charStr = "<SO>";break;
        case 0xF:
          charStr = "<SI>";break;
        case 0x10:
          charStr = "<DLE>";break;
        case 0x11:
          charStr = "<DC1>";break;
        case 0x12:
          charStr = "<DC2>";break;
        case 0x13:
          charStr = "<DC3>";break;
        case 0x14:
          charStr = "<DC4>";break;
        case 0x15:
          charStr = "<NAK>";break;
        case 0x16:
          charStr = "<SYN>";break;
        case 0x17:
          charStr = "<ETB>";break;
        case 0x18:
          charStr = "<CAN>";break;
        case 0x19:
          charStr = "<EM>";break;
        case 0x1A:
          charStr = "<SUB>";break;
        case 0x1B:
          charStr = "<ESC>";break;
        case 0x1C:
          charStr = "<FS>";break;
        case 0x1D:
          charStr = "<GS>";break;
        case 0x1E:
          charStr = "<RS>";break;
        case 0x1F:
          charStr = "<US>";break;
        default:
          charStr = String.fromCharCode(b);
      }

    }

    res += charStr;
  }
  return res;
 }

 