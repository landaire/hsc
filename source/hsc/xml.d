module hsc.xml;

import std.conv;
import std.stdio;

alias Opcode = ushort;

pure bool isScriptValue(T)() {
  import std.traits;

  return hasMember!(T, "opcode") && hasMember!(T, "name");
}

enum ObjectTypeMask {
  Object = 0xFFFF,
  Unit = 0x1003,
  Vehicle = 0x0002,
  Weapon = 0x0004,
  Device = 0x0190,
  Scenery = 0x0040,
  EffectScenery = 0x2000,
}

enum FunctionGroup {
  Begin,
  Cond,
  Set,
  Logical,
  Arithmetic,
  Equality,
  Inequality,
  Sleep,
  SleepForever,
  SleepUntil,
  Wake,
  Inspect,
  ObjectCast,
}

struct ScriptType {
  Opcode opcode;
  string name;
}

struct ValueType {
  Opcode opcode;
  size_t size; // size of the value in bytes
  string name;
  string[] options; // enum
  string tag; // .map tag
  bool quoted; // if this value requires quotes around it
  bool object;
}

struct Parameter {
  ValueType type;
  string name;
}

struct Function {
  Opcode opcode;
  string name;
  ValueType returnType;
  size_t flags;
  FunctionGroup group;
  Parameter[] parameters;
}

struct Global {
  Opcode opcode;
  string name;
  ValueType type;
}

enum Game {
  Halo3Xbox = "Halo3_Xbox",
}

class HaloScript {
  Game game;
  Global[] globals;
  Function[string] builtins; // indexed by name
  ValueType[] values;
  ScriptType[] scriptTypes;

  static HaloScript[] parseXml(string text) {
    import std.xml;

    // make sure input is well-formed xml
    check(text);

    HaloScript[] scripts;

    auto xml = new DocumentParser(text);

    xml.onStartTag["BlamScript"] = (ElementParser xml) {
      writeln("blam");
      static void tryParseScriptType (T)(out T type, in Element e) {
        if (!isScriptValue!(typeof(type))()) {
          return;
        }

        type.name = e.tag.attr["name"];
        type.opcode = to!Opcode(e.tag.attr["name"]);
      }

      HaloScript script = HaloScript.init;

      script.game = to!Game(xml.tag.attr["game"]);

      xml.onStartTag["scriptTypes"] = (ElementParser xml) {
        xml.onEndTag["type"] = (in Element e) {
          ScriptType type = ScriptType.init;

          tryParseScriptType(type, e);

          script.scriptTypes ~= type;

          writeln(type);
        };

        xml.parse();
      };

      xml.parse();

      writeln(script);

      scripts ~= script;
    };

    xml.parse();

    return scripts;
  }
}
