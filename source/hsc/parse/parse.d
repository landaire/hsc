module hsc.parse.parse;

import hsc.xml;
import hsc.parse.lex;
import hsc.parse.ast.node;

class Tree {
  string name;
  string text;
  string[] keywords;
  Token[] tokens;
  Node[] _nodes;

  this(string name, string text, string[] keywords) {
    this.name = name;
    this.tokens = tokens;
    this.text = text;
    this.keywords = keywords;
  }

  public void parse() {
    Lexer lex = new Lexer(name, text);
    lex.run();

    this.tokens = lex.items;
  }

  @property public Node[] nodes() {
    return _nodes;
  }
}
