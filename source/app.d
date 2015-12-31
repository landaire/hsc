import std.file;
import std.stdio;
import std.getopt;
import hsc.parse.lex;
import hsc.xml;

void main(string[] args)
{
  auto xml = cast(string)std.file.read("H3_Scripting.xml");
  stdout.writeln(HaloScript.parseXml(xml));

  string file;
  auto info = getopt(args,
                     "file", &file);

  if (!file) {
    defaultGetoptPrinter("Usage:", info.options);

    return;
  }

  Lexer lex = new Lexer(file, cast(string)read(file));
  lex.run();

  stdout.writeln(lex.items);
}
