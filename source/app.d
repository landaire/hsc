import std.file;
import std.stdio;
import std.getopt;
import hsc.parse.lex;
import hsc.xml;

void main(string[] args)
{
  string file;
  auto info = getopt(args,
                     "file", &file);
  if (!file) {
    defaultGetoptPrinter("Usage:", info.options);

    return;
  }

  // Parse the xml file that gives us info about opcodes and such
  auto xml = cast(string)std.file.read("H3_Scripting.xml");
  auto script = HaloScript.parseXml(xml);

  // These are our keywords
  string[] keywords;
  keywords ~= script.values.keys;
  keywords ~= script.scriptTypes.keys;

  Lexer lex = new Lexer(file, cast(string)read(file), keywords);
  lex.run();

  stdout.writeln(lex.items);
}
