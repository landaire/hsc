module parse.lex;

import std.stdio : stdout;
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
  Identifier,
  Keyword,
  Error,
  Number,
  Space,
  Text,

  OpenParen,
  CloseParen,
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
  OpenAngleBracket,
  Equals,
  RightAngleBracket,
  QuestionMark,
  At,
  Caret,
  Underscore,
  Tilde,
}

struct Position {
  size_t line;
  size_t col;
  size_t index;

  string toString() {
    return format("%d:%d", line, col);
  }
}

struct Item {
  ItemType type;
  string value;
  Position position;

  string toString() {
    switch (type) {
    case ItemType.EOF:
      return "EOF";
    case ItemType.Error:
      return value;
    default:
      return format("%s \"%s\": line %s", type, value, position);
    }
  }
}

class Lexer {
  // used for debugging
  immutable(string) name;
  string input;
  Item[] items; // emitted items
  void delegate() state; // current state
  size_t position = 0; // current position in the input
  size_t start = 0; // position of wherever we started lexing the last item
  size_t lastPosition; // position of the last item we lexed
  size_t parenDepth = 0; // depth of parenthesis

  enum : char {
    eof = cast(char)-1,
    openParen = '(',
    closeParen = ')',
    comment = ';'
  };

  this(string name, string input) {
    this.name = name;
    this.input = input;
    this.state = &lexText;
  }

  void addItem(Item item) {
    items ~= item;

    start = position;
  }

  void addItem(ItemType item) {
    addItem(Item(item, input[start..position], currentPosition()));
  }

  void ignore() {
    start = position;
  }

  void run() {
    while (state !is null) {
      state();
    }
  }

  // string parseSymbol(dchar input) {
  //   foreach (m; __traits(allMembers, Token)) {
  //     auto member = to!Token(m);
  //     if (member == input) {
  //       return "Found match: " ~ m;
  //     }
  //   }
  //   return "No match";
  // }

  char next() {
    if (position >= input.length) {
      return eof;
    }

    // this is the type of thing you're told not to do
    return input[position++];
  }

  char peek() {
    auto n = next();
    backup();

    return n;
  }

  void backup() {
    position--;
  }

  // Lexes abitrary text until we hit an opening paren
  void lexText() {
  loop: while (true) {
      switch (next()) {
      case comment:
        state = &lexComment;
        return;
      case openParen:
        // addItem(ItemType.Text);
        state = &lexOpenParen;
        return;
      case eof:
        state = null;
        return;
      default:
        break;
      }
    }
  }

  void lexComment() {
    // consume characters until we hit EOL
    char nextc;
    while(true) {
      nextc = next();

      if (nextc == eof) {
        state = null;
        return;
      } else if (isEndOfLine(nextc)) {
        break;
      }
    }

    ignore();

    if (parenDepth > 0) {
      state = &lexInsideParens;
    } else {
      state = &lexText;
    }
  }

  void lexOpenParen() {
    // check for a comment since these can go here
    if (peek() == comment) {
      state = &lexComment;
      return;
    }

    addItem(ItemType.OpenParen);
    parenDepth++;

    state = &lexInsideParens;
  }

  void lexCloseParen() {
    addItem(ItemType.CloseParen);
    parenDepth--;

    if (parenDepth == 0) {
      state = &lexText;
    } else {
      state = &lexInsideParens;
    }
  }

  void lexInsideParens() {
    // Parens signify a function call, so it will be something like:
    // (;comment
    // function-name argument ; another comment
    // )
    // and that can be recursive

    immutable(char) nextChar = next();
    if (nextChar == comment) {
      state = &lexComment;
      return;
    } else if (isSpace(nextChar)) {
      state = &lexSpace;
      return;
    } else if (nextChar == openParen) {
      state = &lexOpenParen;
      return;
    } else if (nextChar == closeParen) {
      state = &lexCloseParen;
      return;
    } else if (isIdentifierChar(nextChar)) {
      state = &lexIdentifier;
      return;
    } else if (nextChar == eof) {
      error("unclosed open paren");
    } else {
      error("unrecognized character \"" ~ nextChar ~"\"");
    }
  }

  void lexSpace() {
    while (isSpace(peek())) {
      if (next() == eof) {
        state = null;
        return;
      }
    }

    addItem(ItemType.Space);

    state = &lexInsideParens;
  }

  void lexIdentifier() {
    while(true) {
      auto nextChar = next();

      if (isIdentifierChar(nextChar)) {
        // do nothing
      } else {
        backup();

        string word = input[start..position];

        // do something with word later
        addItem(ItemType.Identifier);

        break;
      }
    }

    state = &lexInsideParens;
  }

  void error(string message) {
    addItem(Item(ItemType.Error, message, currentPosition()));

    state = null;
  }

  Position currentPosition() {
    import std.range : retro;
    import std.algorithm.searching : count, countUntil;

    auto charsUntilPosition = input[0..position];

    size_t lines = count(charsUntilPosition, '\n');
    size_t indexOfLastLinebreak = countUntil(charsUntilPosition, '\n');

    // countUntil is 1-indexed so we -1 since columns should be 0-indexed
    return Position(lines, (start - indexOfLastLinebreak) - 1, start);
  }

  bool isEndOfLine(char c) {
    return c == '\r' || c == '\n';
  }

  bool isSpace(char c) {
    return c == '\t' || c == ' ' || isEndOfLine(c);
  }

  bool isIdentifierChar(char c) {
    import core.stdc.ctype : isalnum;
    import std.algorithm.searching : canFind;

    return canFind(['!', '/', '+', '=', '*', '-', '<', '>'], c) || isalnum(cast(int)c) != 0;
  }

  unittest {
    Lexer lex = new Lexer("input", ";foo hooo\n(foo (+ (x) y))");
    lex.run();

    std.stdio.stdout.writeln(lex.items);
    assert(lex.items == [
                         Item(ItemType.OpenParen, "(", Position(1, 0, 10)),
                         Item(ItemType.Identifier, "foo", Position(1, 1, 11)),
                         Item(ItemType.Space, " ", Position(1, 4, 14)),
                         Item(ItemType.OpenParen, "(", Position(1, 5, 15)),
                         Item(ItemType.Identifier, "+", Position(1, 6, 16)),
                         Item(ItemType.Space, " ", Position(1, 7, 17)),
                         Item(ItemType.OpenParen, "(", Position(1, 8, 18)),
                         Item(ItemType.Identifier, "x", Position(1, 9, 19)),
                         Item(ItemType.CloseParen, ")", Position(1, 10, 20)),
                         Item(ItemType.Space, " ", Position(1, 11, 21)),
                         Item(ItemType.Identifier, "y", Position(1, 12, 22)),
                         Item(ItemType.CloseParen, ")", Position(1, 13, 23)),
                         Item(ItemType.CloseParen, ")", Position(1, 14, 24)),
                         ]);
  }
}
