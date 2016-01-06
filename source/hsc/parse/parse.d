module hsc.parse.parse;

import hsc.xml;
import hsc.parse.lex;
import hsc.parse.ast.node;
import std.conv;

class Parser {
  string name;
  string text;
  string[] keywords;
  public Token[] tokens;
  Node[] _nodes;
  size_t currTok;
  Token _previous;

  this(string name, string text, string[] keywords) {
    this.name = name;
    this.text = text;
    this.keywords = keywords;
  }

  private Token peek() {
    return tokens[currTok + 1];
  }

  private bool hasNext() {
    return currTok < tokens.length;
  }

  private bool hasPrevious() {
    return _previous != Token.init;
  }

  private Token previous() {
    return _previous;
  }

  public void parse() {
    // TODO: Error handling
    Lexer lex = new Lexer(name, text, keywords);
    lex.run();

    tokens = lex.items;

    size_t depth = 0;

    if (tokens.length == 0) {
      return;
    }


    Token tok = tokens[0];
    Node currentNode = null;

    for (currTok = 0; currTok < tokens.length; currTok++) {
      tok = tokens[currTok];

      if (tok.type == TokenType.Comment || tok.type == TokenType.Space) {
        continue;
      }

      if (depth == 0) {
        if (tok.type != TokenType.OpenParen) {
          throw new Exception("unexpected token type " ~ to!string(tok.type));
        }

        if (currentNode !is null) {
          _nodes ~= currentNode;
          currentNode = null;
        }

        depth++;

        goto _end;
      } else {
        if (depth == 1 && previous().type == TokenType.OpenParen) {
          // todo: fix logic here for open paren
          if (tok.type == TokenType.Keyword) {
              // we're in either a function decl, or global decl
              if (tok.value == "script") {
                Node newNode = new FunctionDef(tok);
                newNode.parent = currentNode;
                currentNode = newNode;

                goto _end;
              } else if (tok.value == "global") {
                Node newNode = new VariableDef(tok);
                newNode.parent = currentNode;
                currentNode = newNode;

                goto _end;
              }
          } else if (tok.type == TokenType.Identifier) {
            Node newNode = new FunctionCall(tok);
            newNode.parent = currentNode;
            currentNode = newNode;

            goto _end;
          }
        }

        assert(currentNode !is null);
        // we've already figured out that we are in a function call of function
        // definition, or variable definition
        if (tok.type == TokenType.OpenParen) {
          depth++;
          goto _end;
        }

        if (tok.type == TokenType.CloseParen) {
          if (currentNode.parent is null) {
            _nodes ~= currentNode;
          } else if (cast(VariableDef)currentNode.parent !is null) {
            auto vdef = cast(VariableDef)currentNode.parent;
            vdef.initialValue = currentNode;
          }

          currentNode = currentNode.parent;
          depth--;

          goto _end;
        }

        if (previous().type == TokenType.OpenParen) {
          Node newNode = new FunctionCall(tok);
          newNode.parent = currentNode;


          // basically everything is a function
          (cast(FunctionCall)currentNode).arguments ~= newNode;

          currentNode = newNode;

          goto _end;
        }

        if (cast(FunctionDef)currentNode !is null) {
          auto fdef = cast(FunctionDef)currentNode;

          if (tok.type == TokenType.Keyword) {
            if (fdef.scriptType is null) {
              fdef.scriptType = tok.value;

              goto _end;
            } else if (fdef.returnType is null) {
              fdef.returnType = tok.value;

              goto _end;
            }
          } else if (tok.type == TokenType.Identifier && fdef.name is null) {
            fdef.name = tok.value;
          }
        } else if (cast(VariableDef)currentNode !is null) {
          auto vdef = cast(VariableDef)currentNode;

          if (vdef.type is null) {
            vdef.type = tok.value;
          } else if (vdef.name is null) {
            vdef.name = tok.value;
          }
        } else if (cast(FunctionCall)currentNode !is null) {
          auto fcall = cast(FunctionCall)currentNode;

          if (tok.type == TokenType.Identifier) {
            fcall.arguments ~= new Identifier(tok);
          } else {
            fcall.arguments ~= new Literal(tok);
          }
        }

        goto _end;
      }

      // this is the >1 depth that everything else defaults to


    _end:
      _previous = tok;
      if (tok.type != TokenType.OpenParen && tok.type != TokenType.CloseParen) {
        currentNode.tokenStream ~= tok;
      }
    }
  }

  @property public Node[] nodes() {
    return _nodes;
  }

  void log(R)(R t) {
    // import std.stdio;

    // writef("%d:%d: %s\n", start, position, t);
  }

  override string toString() {
    string ret = "";
    import std.string;

    void recursiveWorker(Node node, size_t depth) {
      if (node is null) {
        return;
      }

      if (depth == 0) {
        ret ~= "\n";
      }

      ret ~= node.toString().rightJustify(depth + node.toString().length, '-');


      if (cast(VariableDef)node !is null) {
        auto n = cast(VariableDef)node;

        ret ~= format(" global %s\n", node.name);

        recursiveWorker(n.initialValue, depth + 1);
      } else if (cast(FunctionDef)node !is null) {
        auto n = cast(FunctionDef)node;

        ret ~= format(" %s %s %s()\n", n.scriptType, n.returnType, n.name);

        foreach (child; n.arguments) {
          recursiveWorker(child, depth + 1);
        }
      } else if (cast(FunctionCall)node !is null) {
        auto n = cast(FunctionCall)node;

        ret ~= format(" %s()\n", n.name);
        foreach (child; n.arguments) {
          recursiveWorker(child, depth + 1);
        }
      } else {
        ret ~= format(" %s\n", node.name);
      }

    }

    foreach (node; nodes) {
      recursiveWorker(node, 0);
    }

    return ret;
  }
}
