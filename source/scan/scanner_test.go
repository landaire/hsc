package scan

import (
	"fmt"
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

	fmt.Printf("%#v\n", expectedTokens)

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
		compareTokens(t, expectedTokens[tokenCount], tok, tokenCount, len(expectedTokens))

		tokenCount++
	}

	if tokenCount != len(expectedTokens) {
		t.Errorf("Expected %d tokens, got %d", len(expectedTokens), tokenCount)
	}
}

func TestScannerScanInteger(t *testing.T) {
	integer := `(0123456789)`

	l := int64(1)

	tokens := makeTokens(
		makeTok(l, "(", token.OpenParen), makeTok(l, "0123456789", token.Integer),
		makeTok(l, ")", token.CloseParen), makeTok(l, "", token.EOF))

	c := make(chan token.TokPosition)

	scanner := New(strings.NewReader(integer), c)

	go scanner.Scan()

	tokenCount := 0
	for tok := range c {
		compareTokens(t, tokens[tokenCount], tok, tokenCount, len(tokens))

		tokenCount++
	}
}

func TestScannerScanDecimal(t *testing.T) {
	decimal := `(00.123)`

	l := int64(1)

	tokens := makeTokens(
		makeTok(l, "(", token.OpenParen), makeTok(l, "00.123", token.Decimal),
		makeTok(l, ")", token.CloseParen), makeTok(l, "", token.EOF))

	c := make(chan token.TokPosition)

	scanner := New(strings.NewReader(decimal), c)

	go scanner.Scan()

	tokenCount := 0
	for tok := range c {
		compareTokens(t, tokens[tokenCount], tok, tokenCount, len(tokens))

		tokenCount++
	}
}

func compareTokens(t *testing.T, expected, actual token.TokPosition, tokenCount, expectedCount int) {
	if tokenCount >= expectedCount {
		t.Error("More tokens were reported than expected")
		t.Error(actual)
		return
	}

	if expected.Tok != actual.Tok {
		t.Errorf("Unexpected token at %d of type %s (expected %s). Expected %#v, got %#v",
			tokenCount,
			actual.Tok,
			expected.Tok,
			expected,
			actual)
	} else if expected != actual {
		t.Errorf("Mismatch token values. Expected %#v, got %#v", expected, actual)
	}
}

func makeTok(line int64, value string, tokType token.Token) token.TokPosition {
	tok := token.TokPosition{}
	tok.Line = line
	tok.Value = value
	tok.Tok = tokType
	tok.Column = 0

	return tok
}

func makeTokens(tokens ...token.TokPosition) []token.TokPosition {
	var returnTokens []token.TokPosition
	offset := int64(0)

	for i := 0; i < len(tokens); i++ {
		currentTok := &tokens[i]

		if i > 0 {
			previousTok := tokens[i-1]
			if previousTok.Line == currentTok.Line {

				currentTok.Column = previousTok.Column + len(previousTok.Value)
			} else {
				currentTok.Column = 0
			}

			currentTok.Offset = offset
		}

		offset += int64(len(currentTok.Value))

		returnTokens = append(returnTokens, *currentTok)
	}

	return returnTokens
}
