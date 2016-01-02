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

enum Game : string {
  Halo3Xbox = "Halo3_Xbox",
}

class HaloScript {
  Game game;
  Global[] globals;
  Function[string] builtins; // indexed by name
  ValueType[] values;
  ScriptType[] scriptTypes;

  static HaloScript parseXml(string text) {
    import std.xml;

    // make sure input is well-formed xml
    check(text);

    HaloScript script = new HaloScript;

    auto xml = new DocumentParser(text);

    static void tryParseScriptType (T)(out T type, in Tag t) {
      if (!isScriptValue!(typeof(type))()) {
        return;
      }

      type.name = t.attr["name"];
      // need to remove 0x from number here, hence the slice
      type.opcode = t.attr["opcode"][2..$].to!Opcode(16);
    }

    script.game = cast(Game)xml.tag.attr["game"];

    xml.onStartTag["scriptTypes"] = (ElementParser xml) {
      xml.onEndTag["type"] = (in Element e) {
        ScriptType type;

        tryParseScriptType(type, e.tag);

        script.scriptTypes ~= type;

        writeln(type);
      };


      xml.parse();
    };

    xml.onStartTag["valueTypes"] = (ElementParser xml) {
      xml.onStartTag["type"] = (ElementParser xml) {
        ValueType value;
        const(Tag) tag = xml.tag;

        tryParseScriptType(value, tag);

        value.size = to!size_t(tag.attr["size"]);
        value.quoted = "quoted" in tag.attr ? to!bool(tag.attr["quoted"]) : false;
        value.tag = "tag" in tag.attr ? tag.attr["tag"] : null;
        value.object = "object" in tag.attr ? to!bool(tag.attr["object"]) : false;

        xml.onEndTag["enum"] = (in Element e) {
          value.options ~= e.text();
        };

        xml.parse();

        writeln(value);

        script.values ~= value;
      };

      xml.parse();
    };

    xml.parse();

    return script;
  }
}
