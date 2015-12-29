module hsc;

import std.file;
import std.stdio;
import std.getopt;
import parse.lex;

void main(string[] args)
{
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
