package scan

import (
	"strings"
	"testing"

	"github.com/landaire/hsc/source/token"
)

func TestScannerScan(t *testing.T) {
	line := int64(1)
	lineCount := func(increment bool) int64 {
		if increment {
			line++
		}

		return line
	}

	expectedTokens := makeTokens(
		makeTok(lineCount(false), "\n", token.Whitespace), makeTok(lineCount(true), ";foo hooo", token.Comment),
		makeTok(lineCount(false), "\n", token.Whitespace), makeTok(lineCount(true), "(", token.OpenParen),
		makeTok(lineCount(false), "foo", token.Identifier), makeTok(lineCount(false), " ", token.Whitespace),
		makeTok(lineCount(false), "(", token.OpenParen), makeTok(lineCount(false), "+", token.Identifier),
		makeTok(lineCount(false), " ", token.Whitespace), makeTok(lineCount(false), "(", token.OpenParen),
		makeTok(lineCount(false), "x", token.Identifier), makeTok(lineCount(false), ")", token.CloseParen),
		makeTok(lineCount(false), " ", token.Whitespace), makeTok(lineCount(false), "y", token.Identifier),
		makeTok(lineCount(false), ")", token.CloseParen), makeTok(lineCount(false), ")", token.CloseParen),
		makeTok(lineCount(false), "\n", token.Whitespace), makeTok(lineCount(true), ";foo", token.Comment),
		makeTok(lineCount(false), "\n", token.Whitespace), makeTok(lineCount(true), "", token.EOF),
	)

	c := make(chan token.TokPosition)
	reader := strings.NewReader(`
;foo hooo
(foo (+ (x) y))
;foo

`)
	scanner := New(reader, c)

	go scanner.Scan()

	tokenCount := 0
	for tok := range c {
		if tokenCount >= len(expectedTokens) {
			t.Error("More tokens were reported than expected")
			t.Error(tok)
			return
		}

		if tok.Tok != expectedTokens[tokenCount].Tok {
			t.Errorf("Unexpected token at %d of type %s, value: %#v", tokenCount, tok.Tok, tok.Value)
		} else if tok != expectedTokens[tokenCount] {
			t.Errorf("Mismatch token values. Expected %#v, got %#v", expectedTokens[tokenCount], tok)
		}

		tokenCount++
	}

	if tokenCount != len(expectedTokens) {
		t.Errorf("Expected %d tokens, got %d", len(expectedTokens), tokenCount)
	}
}

func makeTok(line int64, value string, tokType token.Token) token.TokPosition {
	tok := token.TokPosition{}
	tok.Line = line
	tok.Value = value
	tok.Tok = tokType

	return tok
}

func makeTokens(tokens ...token.TokPosition) []token.TokPosition {
	var returnTokens []token.TokPosition
	offset := int64(0)

	for i := 0; i < len(tokens); i++ {
		currentTok := tokens[i]

		if i > 0 {
			if tokens[i-1].Line == currentTok.Line {
				currentTok.Column = tokens[i-1].Column + len(tokens[i-1].Value)
			} else {
				currentTok.Column = 0
			}
		}

		currentTok.Offset = offset
		offset += int64(len(currentTok.Value))

		returnTokens = append(returnTokens, currentTok)
	}

	return returnTokens
}
