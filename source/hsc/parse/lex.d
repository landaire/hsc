module hsc.parse.lex;

import std.stdio : stdout;
import std.conv;
import std.format : format;
import std.range;
import std.range.primitives;
import std.algorithm.searching : canFind;

enum TokenType {
	EOF,
	Identifier,
	Keyword,
	Error,
	Number,
	Text,
	OpenParen,
	CloseParen,
	Bool,
	ParamSeparator,
	Comment,
}

/**
 * Position inside of a file
 */
struct Position {
	size_t line;
	size_t col;
	size_t index;

	string toString() {
		return format("%d:%d offset %d", line, col, index);
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
	size_t lastLineNumIndex = 0;
	string[] keywords;

	static immutable char escape = '\\';
	static immutable char[] escapes = ['"', '\\'];

	enum : char {
		eof = cast(char)-1,
		openParen = '(',
		closeParen = ')',
		comment = ';',
		quote = '"',
		paramSeparator = ',',
	};

	this(string name, string input) {
		this(name, input, []);
	}

	this(string name, string input, string[] keywords) {
		this.name = name;
		this.input = input;
		this.state = &lexText;
		this.keywords = keywords;

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
		import std.algorithm.iteration : map;
		import std.range : zip;
		import std.array : assocArray;
		import std.array : replace;

		string value = input[start..position].idup;
		auto tokenPosition = currentPosition();

		if (item == TokenType.Space) {
			// this avoids something like <SPC><SPC><CR><LF><SPC> having
			// an integer underflow since the last linefeed would have been marked as part of that buffer
			if (canFind(value, '\n')) {
				assert(start > lastLineNumIndex);

				tokenPosition.line--;
				tokenPosition.col = start - lastLineNumIndex;
			}
		} else if (item == TokenType.Text) {

			// remove escape sequence
			const dchar[string] escapeMap = assocArray(zip(escapes.map!(e => to!string(escape) ~ to!string(e)), escapes));

			foreach (escapeSequence, replacement; escapeMap) {
				value = value.replace(escapeSequence, to!string(replacement));
			}
		}

		addItem(Token(item, value, tokenPosition));
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

	unittest {
		Lexer lex = new Lexer("input", ";foo hooo\n(foo (+ (x) y))\r\n;foo\r\n");
		lex.run();

		auto items = [
									Token(TokenType.Comment, ";foo hooo", Position(1, 0, 0)),
									Token(TokenType.Space, "\n", Position(1, 9, 9)),
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
									Token(TokenType.Space, "\r\n", Position(2, 15, 25)),
									Token(TokenType.Comment, ";foo", Position(3, 0, 27)),
									Token(TokenType.Space, "\r\n", Position(3, 4, 31)),
								 ];

		assert(lex.items.length == items.length);
		assert(lex.items == items);
	}

	/**
	 * Consumes and returns the next character in the buffer. Returns EOF if we've gone outside the buffer
	 */
	char next() {
		if (position >= input.length) {
			// increment position here so that callers don't need to explicitly check for EOF and backup()
			// only if it's not EOF... this just makes things easier
			position++;
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

		auto nextc = next();

		while (nextc != eof) {
			if (nextc == comment) {
				state = &lexComment;
				return;
			} else if (nextc == openParen) {
				state = &lexOpenParen;
				return;
			} else if (isSpace(nextc)) {
				state = &lexSpace;
				return;
			}

			nextc = next();
		}

		state = null;
	}

	/**
	 * Positions the buffer to wherever the first non-CR/LF character is
	 */
	void skipEOL(out bool eolMarked) {
		log("skipping EOL");

		// backup so we can consume the linebreak that whatever lex method read. this is so we can
		// identify if it's a CR or LF and mark EOL if it's LF
		backup();
		char nextc = next();

		size_t pos = position;

		while (nextc == '\r' || nextc == '\n') {
			if (nextc == '\n') {
				markEOL(eolMarked);
				eolMarked = true;
			}

			nextc = next();
		}

		// if we don't do this upon exiting then we'll be off-by-one
		if (position > pos) {
			backup();
		}
	}

	void markEOL(ref bool hasEolBeenMarked) {
		lineNum++;

		if (!hasEolBeenMarked) {
			lastLineNumIndex = lineNumIndex;
		}

		lineNumIndex = position;
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

				break;
			} else if (isEndOfLine(nextc)) {
				// this is consumed elsewhere
				state = &lexSpace;

				break;
			}
		}

		backup();

		addItem(TokenType.Comment);
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

		if (parenDepth == 0) {
			error("unexpected " ~ TokenType.CloseParen);
		}

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

		bool eolMarked = false;

		while (isSpace(peek())) {
			auto nextc = next();

			if (isEndOfLine(nextc)) {
				skipEOL(eolMarked);
			}
		}

		addItem(TokenType.Space);

		if (parenDepth == 0) {
			state = &lexText;
		} else {
			state = &lexInsideParens;
		}
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
				}
				else if (canFind(keywords, word)) {
					addItem(TokenType.Keyword);
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

		auto nextc = next();
		bool inEscape = false;
		while(nextc != quote || inEscape) {
			// check escape sequence
			if (inEscape) {
				if (!canFind(escapes, nextc)) {
					error("unknown escape sequence " ~ to!string(escape) ~ to!string(nextc));
					return;
				}

				inEscape = false;
			} else if (nextc == escape) {
				inEscape = true;
			}

			nextc = next();
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

	static pure bool isEndOfLine(char c) {
		return c == '\r' || c == '\n';
	}

	static pure bool isSpace(char c) {
		import std.ascii : isWhite;

		return isWhite(c);
	}

	unittest {
		auto spaces = ['\t', '\n', '\r', ' '];

		foreach (space; spaces) {
			assert(isSpace(space));
		}

		assert(!isSpace('!'));
		assert(!isSpace('x'));
	}

	static pure bool isIdentifierChar(char c) {
		import core.stdc.ctype : isalnum;
		import std.algorithm.searching : canFind;
		import std.ascii : isAlphaNum;

		return canFind(['_', '!', '/', '+', '=', '*', '-', '<', '>'], c) || isAlphaNum(c);
	}

	unittest {
		string[] validIdentifiers = ["foo", "_foo_", "!foo", "-fo", "foo!", "+", "=", "*", "/", "!", "<", ">", "<=", ">="];

		foreach (identifier; validIdentifiers) {
			foreach (c; identifier) {
				assert(isIdentifierChar(c));
			}
		}

		assert(!isIdentifierChar('#'));
		assert(!isIdentifierChar('^'));
		assert(!isIdentifierChar('\"'));
		assert(!isIdentifierChar('`'));
	}

	static pure bool isNumber(char c) {
		return c >= '0' && c <= '9';
	}

	unittest {
		import std.conv;

		foreach (i; 0..9) {
			assert(isNumber(to!string(i)[0]));
		}
	}

	void log(R)(R t) {
		// import std.stdio;

		// writef("%d:%d: %s\n", start, position, t);
	}
}
