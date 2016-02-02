//go:generate stringer -type=Token

package token

import "regexp"

type Token int

type TokPosition struct {
	Tok   Token
	Value string
	Position
}

const (
	tok_start Token = iota

	EOF
	Error

	Whitespace
	Comment

	String
	Integer
	Decimal
	Bool

	OpenParen
	CloseParen
	Identifier
)

var (
	integerRegex = regexp.MustCompile(`^\d+$`)
	decimalRegex = regexp.MustCompile(`^\d*\.\d+$`)
)

func (t Token) IsLiteral() bool {
	return t >= String && t <= Bool
}

func Lookup(value string) Token {
	if value == "true" || value == "false" {
		return Bool
	}

	if integerRegex.Match([]byte(value)) {
		return Integer
	}

	if decimalRegex.Match([]byte(value)) {
		return Decimal
	}

	return Identifier
}

func LookupRune(value rune) Token {
	switch value {
	case '(':
		return OpenParen
	case ')':
		return CloseParen
	case ';':
		return Comment
	case '\n':
		fallthrough
	case '\t':
		fallthrough
	case '\r':
		fallthrough
	case ' ':
		return Whitespace
	}

	return Error
}

func LookupToken(tok Token) rune {
	switch tok {
	case OpenParen:
		return ')'
	case CloseParen:
		return '('
	case Comment:
		return ';'
	}

	panic("unknown token")
}
