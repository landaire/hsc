module hsc.parse.ast.node;

import hsc.parse.lex : Token;
import hsc.parse.lex : TokenType;
import std.conv;

abstract class Node {
  Node parent;

  Token[] tokenStream;

  static immutable stringFunc = "override string toString() { return typeof(this).stringof; }";

  private this() {}

  public this(Token t) {
    tokenStream ~= t;
  }

  @property public string name() {
    return tokenStream[0].value;
  }
}

class FunctionCall : Node {
  public Node[] arguments;

  private this() {}

  public this(Token t) {
    tokenStream ~= t;
  }

  mixin(stringFunc);
}

class FunctionDef : FunctionCall {
  public string returnType;
  public string scriptType;
  private string _name;

  public this(Token t) {
    tokenStream ~= t;
  }

  @property override public string name() {
    return _name;
  }

  @property public string name(string n) {
    return _name = n;
  }

  mixin(stringFunc);
}

class VariableDef : FunctionCall {
  public string type;
  public string _name;
  public Node initialValue;

  public this(Token t) {
    tokenStream ~= t;
  }

  @property override public string name() {
    return _name;
  }

  @property public string name(string val) {
    return _name = val;
  }

  mixin(stringFunc);
}

class Literal : Node {
  public this(Token t) {
    tokenStream ~= t;
  }

  @property string type() {
    switch (value.type) {
    case TokenType.Number:
      return "Number";
    case TokenType.Text:
      return "Text";
    default:
      return "unk";
    }
  }

  @property Token value() {
    return tokenStream[0];
  }

  mixin(stringFunc);
}

class Identifier : Node {
  public this(Token t) {
    tokenStream ~= t;
  }

  @property Token value() {
    return tokenStream[0];
  }

  mixin(stringFunc);
}
