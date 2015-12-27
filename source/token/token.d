module hsc.lex;

import std.conv;
import std.range;
import std.range.primitives;

enum CellType {
  EOF,
  Symbol,
  Number,
  List,
  Proc,
  Lambda,
}

//                                "!#$%&|*+-/:<=>?@^_~"

enum Token {
  EOF,
  OpenParen = '(',
  CloseParen = ')',
  Bang = '!',
  Hash = '#',
  Dollar = '$',
  Percent = '%',
  Amersand = '&',
  Pipe = '|',
  Asterisk = '*',
  Plus = '+',
  Minus = '-',
  Slash = '/',
  Colon = ':',
  OpenAngleBracket = '<',
  Equals = '=',
  CloseAngleBracket = '>',
  QuestionMark = '?',
  At = '@',
  Caret = '^',
  Underscore = '_',
  Tilde = '~',
}

class Parser {
  string parseSymbol(dchar input) {
    foreach (m; __traits(allMembers, Token)) {
      auto member = to!Token(m);
      if (member == input) {
        return "Found match: " ~ m;
      }
    }
    return "No match";
  }

  unittest {
    Parser p = new Parser();

    assert(p.parseSymbol('%') == "Found match: Percent");
    assert(p.parseSymbol('(') == "Found match: OpenParen");
    assert(p.parseSymbol(')') == "Found match: CloseParen");
  }
}
