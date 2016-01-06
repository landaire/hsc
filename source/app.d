import std.file;
import std.stdio;
import std.getopt;
import hsc.parse.parse;
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
  string[] keywords = ["global"];
  keywords ~= script.values.keys;
  keywords ~= script.scriptTypes.keys;

  auto parser = new Parser(file, cast(string)read(file), keywords);
  parser.parse();

  // stdout.writeln(parser.tokens);
  stdout.writeln(parser.toString());
}
