package scan

import (
	"testing"

	"github.com/landaire/hsc/source/scan"
	"github.com/landaire/hsc/source/token"
)

func TestScannerScan(t *testing.T) {
	line := int64(1)
	lineCount := func(increment bool) {
		if increment {
			line++
		}

		return line
	}

	expectedTokens := makeTokens(
		makeTok(lineCount(false), " ", token.Whitespace), makeTok(lineCount(true), ";foo hooo", token.Comment),
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
	reader := io.StringReader(`
;foo hooo
(foo (+ (x) y))
;foo

`)
	scanner := scan.New()

	go scanner.Scan(c)

	tokenCount := 0
	for tok := range <-c {
		if tok != expectedTokens[tokenCount] {
			t.Errorf("Unexpected token of type %s, value: %s", tok.Tok, tok.Value)
		}

		tokenCount++
	}
}

func makeTok(line int64, value string, tokType token.Token) token.TokPosition {
	return token.TokPosition{
		Line:  line,
		Value: value,
		Tok:   tokType,
	}
}

func makeTokens(tokens ...tok.TokPosition) []tok.TokPosition {
	var returnTokens []tok.TokPosition
	offset := int64(0)

	for i := 0; i < len(tokens); i++ {
		currentTok := tokens[i]

		if i > 0 {
			if currentTok[i-1].Line == currentTok[i].Line {
				currentTok.Column = tokens[i-1].Column + len(tokens[i-1].Value)
			} else {
				currentTok.Column = 0
			}
		}

		currentTok.Offset = offset
		offset += len(currentTok.Value)
	}

	return returnTokens
}
