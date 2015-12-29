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

enum TokenType {
  EOF,
  Identifier,
  Keyword,
  Error,
  Number,
  Space,
  Text,
  OpenParen,
  CloseParen,
  Bool,
  ParamSeparator,
}

/**
 * Position inside of a file
 */
struct Position {
  size_t line;
  size_t col;
  size_t index;

  string toString() {
    return format("%d:%d", line, col);
  }
}

/**
 * A lexed token
 */
struct Token {
  TokenType type;
  string value;
  Position position;

  string toString() {
    switch (type) {
    case TokenType.EOF:
      return "EOF";
    case TokenType.Error:
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
  Token[] items; // emitted items
  void delegate() state; // current state
  size_t position = 0; // current position in the input
  size_t start = 0; // position of wherever we started lexing the last item
  size_t lastPosition; // position of the last item we lexed
  size_t parenDepth = 0; // depth of parenthesis
  size_t lineNum = 1;
  size_t lineNumIndex = 0;

  enum : char {
    eof = cast(char)-1,
    openParen = '(',
    closeParen = ')',
    comment = ';',
    quote = '"',
    paramSeparator = ',',
  };

  this(string name, string input) {
    this.name = name;
    this.input = input;
    this.state = &lexText;

    items.reserve(input.length);
  }

  /**
   * Adds a pre-built item to the lexed items list
   */
  void addItem(Token item) {
    items ~= item;

    lastPosition = start;
    start = position;
  }

  /**
   * Adds an Token to the lexed items list
   */
  void addItem(TokenType item) {
    addItem(Token(item, input[start..position], currentPosition()));
  }

  /**
   * Sets the lexer's current token start position to position, ignoring all characters
   * between position and start when this is called
   */
  void ignore() {
    start = position;
  }

  /**
   * Begins lexing
   */
  void run() {
    while (state !is null) {
      state();
    }
  }

  /**
   * Consumes and returns the next character in the buffer. Returns EOF if we've gone outside the buffer
   */
  char next() {
    if (position >= input.length) {
      return eof;
    }

    // this is the type of thing you're told not to do
    return input[position++];
  }

  char previous() {
    return input[position - 1];
  }

  /**
   * Returns but does not consume the next character in the buffer
   */
  char peek() {
    auto n = next();
    backup();

    return n;
  }

  /**
   * Backs up the buffer by one character
   */
  void backup() {
    position--;
  }

  /**
   * Lexes top-level text. This will usually skip whitespace, encounter EOF, or set the state to lexing a comment /
   * script
   */
  void lexText() {
    log("lexing text");

  loop: while (true) {
      switch (next()) {
      case comment:
        state = &lexComment;
        return;
      case openParen:
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

  /**
   * Positions the buffer to wherever the first non-CR/LF character is
   */
  void skipEOL() {
    log("skipping EOL");

    backup();

    char nextc = next();
    while (nextc == '\r' || nextc == '\n') {
      if (nextc == '\n') {
        lineNum++;
        lineNumIndex = position;
      }

      nextc = next();
    }

    backup();

    ignore();
  }

  /**
   * Lexes comments and does not emit any tokens
   */
  void lexComment() {
    log("lexing comment");

    // consume characters until we hit EOL
    char nextc;
    while(true) {
      nextc = next();

      if (nextc == eof) {
        state = null;
        return;
      } else if (isEndOfLine(nextc)) {
        skipEOL();
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
    log("lexing open paren");

    addItem(TokenType.OpenParen);
    parenDepth++;

    // check for a comment since these can go here
    if (peek() == comment) {
      state = &lexComment;
      return;
    }


    state = &lexInsideParens;
  }

  void lexCloseParen() {
    log("lexing closing paren");

    addItem(TokenType.CloseParen);
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

    log("lexing inside parens");

    immutable(char) nextChar = next();
    if (nextChar == comment) {
      state = &lexComment;
      return;
    } else if (isSpace(nextChar)) {
      if (isEndOfLine(nextChar)) {
        skipEOL();
      }

      state = &lexSpace;
      return;
    } else if (nextChar == openParen) {
      state = &lexOpenParen;
      return;
    } else if (nextChar == closeParen) {
      state = &lexCloseParen;
      return;
    } else if (isNumber(nextChar)) {
      state = &lexNumber;
      return;
    } else if (isIdentifierChar(nextChar)) {
      state = &lexIdentifier;
      return;
    } else if (nextChar == quote) {
      state = &lexString;
      return;
    } else if (nextChar == paramSeparator) {
      addItem(TokenType.ParamSeparator);

      state = &lexInsideParens;
      return;
    } else if (nextChar == eof) {
      error("unclosed open paren");
    } else {
      error("unrecognized character \"" ~ nextChar ~"\"");
    }
  }

  void lexSpace() {
    log("lexing space");

    while (isSpace(peek())) {
      if (next() == eof) {
        state = null;
        return;
      }
    }

    addItem(TokenType.Space);

    state = &lexInsideParens;
  }

  void lexIdentifier() {
    log("lexing identifier");

    while(true) {
      auto nextChar = next();

      if (isIdentifierChar(nextChar)) {
        // do nothing
      } else {
        backup();

        string word = input[start..position];

        if (word == "true" || word == "false") {
          addItem(TokenType.Bool);
        } else {
          // do something with word later
          addItem(TokenType.Identifier);
        }

        break;
      }
    }

    state = &lexInsideParens;
  }

  void lexString() {
    log("lexing string");

    while(next() != quote) {
      // do nothing, just consume
    }

    addItem(TokenType.Text);

    state = &lexInsideParens;
  }

  void lexNumber() {
    log("lexing number");

    char nextc = next();
    while (isNumber(nextc) || nextc == '.') {
      nextc = next();
    }

    backup();

    addItem(TokenType.Number);

    state = &lexInsideParens;
  }

  void error(string message) {
    addItem(Token(TokenType.Error, message, currentPosition()));

    state = null;
  }

  Position currentPosition() {
    return Position(lineNum, (start - lineNumIndex), start);
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

    return canFind(['_', '!', '/', '+', '=', '*', '-', '<', '>'], c) || isalnum(cast(int)c) != 0;
  }

  bool isNumber(char c) {
    return c >= '0' && c <= '9';
  }

  void log(R)(R t) {
    // import std.stdio : stdout;

    // stdout.writef("%d:%d: %s\n", start, position, t);
  }

  unittest {
    Lexer lex = new Lexer("input", ";foo hooo\n(foo (+ (x) y))");
    lex.run();

    std.stdio.stdout.writeln(lex.items);
    assert(lex.items == [
                         Token(TokenType.OpenParen, "(", Position(2, 0, 10)),
                         Token(TokenType.Identifier, "foo", Position(2, 1, 11)),
                         Token(TokenType.Space, " ", Position(2, 4, 14)),
                         Token(TokenType.OpenParen, "(", Position(2, 5, 15)),
                         Token(TokenType.Identifier, "+", Position(2, 6, 16)),
                         Token(TokenType.Space, " ", Position(2, 7, 17)),
                         Token(TokenType.OpenParen, "(", Position(2, 8, 18)),
                         Token(TokenType.Identifier, "x", Position(2, 9, 19)),
                         Token(TokenType.CloseParen, ")", Position(2, 10, 20)),
                         Token(TokenType.Space, " ", Position(2, 11, 21)),
                         Token(TokenType.Identifier, "y", Position(2, 12, 22)),
                         Token(TokenType.CloseParen, ")", Position(2, 13, 23)),
                         Token(TokenType.CloseParen, ")", Position(2, 14, 24)),
                         ]);
  }
}
