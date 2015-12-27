module hsc.lex;

import std.conv;
import std.format : format;
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
enum Delimeters {
  OpenParen = '(',
  CloseParen = ')',

}

enum ItemType {
  EOF,
  Symbol,
  Keyword,
  Error,
  Number,
  Whitespace,
  Comment,

  LeftParen,
  RightParen,
  Bang,
  Hash,
  Dollar,
  Percent,
  Amersand,
  Pipe,
  Asterisk,
  Plus,
  Minus,
  Slash,
  Colon,
  LeftAngleBracket,
  Equals,
  RightAngleBracket,
  QuestionMark,
  At,
  Caret,
  Underscore,
  Tilde,


}

class Item {
  ItemType type;
  string value;
  size_t position;

  override string toString() {
    switch (type) {
    case ItemType.EOF:
      return "EOF";
    case ItemType.Error:
      return value;
    default:
      return format("%s - %s: %d", type, value, position);
    }
  }
}

class Lexer {

  // used for debugging
  string name;
  string input;
  Item[] items;

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
    Lexer lex = new Lexer();

    assert(lex.parseSymbol('%') == "Found match: Percent");
    assert(lex.parseSymbol('(') == "Found match: OpenParen");
    assert(lex.parseSymbol(')') == "Found match: CloseParen");
  }
}
