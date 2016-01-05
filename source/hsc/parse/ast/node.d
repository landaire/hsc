module hsc.parse.ast.node;

import hsc.parse.lex : Token;
import hsc.parse.lex : TokenType;

abstract class Node {
  Token tok;

  this() {}

  public this(Token t) {
    this.tok = t;
  }

  @property string name() {
    return tok.value;
  }
}

class VariableDef : Node {
  public string type;
}

class FunctionCall : Node {
  public Node[] arguments;
}

class FunctionDef : Node {
  public string returnType;
  public string scriptType;
}

class Literal : Node {
  @property string type() {
    switch (tok.type) {
    case TokenType.Number:
      return "Number";
    case TokenType.Text:
      return "Text";
    default:
      return "unk";
    }
  }
}
