package scan

import (
	"bufio"
	"fmt"
	"io"
	"unicode"
	"unicode/utf8"

	"github.com/landaire/hsc/source/token"
)

type scanFunc func(s *Scanner) scanFunc

type Scanner struct {
	ch         rune
	lastOffset int64
	offset     int64
	lineOffset int64
	line       int64
	text       *bufio.Reader
	out        chan<- token.TokPosition
	parenDepth int
}

// New returns a new instance of a Scanner
func New(text io.Reader, out chan<- token.TokPosition) Scanner {
	return Scanner{
		ch:     0,
		offset: 0,
		line:   1,
		text:   bufio.NewReader(text),
		out:    out,
	}
}

func (s *Scanner) Scan() {
	scan := scanText

	for scan != nil {
		scan = scan(s)
	}

	if s.ch == rune(0) {
		s.Emit(token.EOF, "")
	}

	close(s.out)
}

func (s *Scanner) emitRaw(tok token.Token, value string, line int64, lineOffset int64) {
	outTok := token.TokPosition{
		Tok:   tok,
		Value: value,
	}

	outTok.Line = line

	outTok.Offset = s.lastOffset

	outTok.Column = int(s.lastOffset - (lineOffset + 1))

	if outTok.Column == -1 {
		outTok.Column = 0
	}

	s.out <- outTok

	s.lastOffset = s.offset
}

func (s *Scanner) Emit(tok token.Token, value string) {
	s.emitRaw(tok, value, s.line, s.lineOffset)
}

func (s *Scanner) next() rune {
	read, size, err := s.text.ReadRune()
	if read == unicode.ReplacementChar || err != nil {
		s.ch = 0
	} else {
		s.ch = read
		s.offset += int64(size)
	}

	return s.ch
}

func (s *Scanner) backup() {
	s.offset -= int64(utf8.RuneLen(s.ch))
	s.text.UnreadRune()
}

func (s *Scanner) peek() rune {
	rune := s.next()
	s.backup()

	return rune
}

func scanText(s *Scanner) scanFunc {
	for s.peek() != rune(0) {
		switch token.LookupRune(s.ch) {
		case token.OpenParen:
			return scanOpenParen
		case token.Comment:
			return scanComment
		case token.Whitespace:
			return scanWhitespace
		default:
			s.Emit(token.Error, fmt.Sprintf("Unexpected sequence: %X", []byte(string(s.ch))))
			return nil
		}
	}

	return nil
}

func scanWhitespace(s *Scanner) scanFunc {
	value := ""
	line := s.line
	lineOffset := s.lineOffset

	hasLinebreak := false

	for {
		char := s.next()

		if !isWhitespace(char) {
			s.backup()

			break
		}

		if isNewline(char) {
			hasLinebreak = true
			s.line++

			if s.offset > 0 {
				s.lineOffset = s.offset - 1
			}
		}

		value += string(char)
	}

	if hasLinebreak {
		s.emitRaw(token.Whitespace, value, line, lineOffset)
	} else {
		s.Emit(token.Whitespace, value)
	}

	if s.parenDepth == 0 {
		return scanText
	}

	return scanInsideParen
}

func scanOpenParen(s *Scanner) scanFunc {
	s.parenDepth++
	s.Emit(token.OpenParen, string(s.next()))

	return scanInsideParen
}

func scanInsideParen(s *Scanner) scanFunc {
	// starting out here can be either whitespace, some text (identifier),
	// more parens, or a number

	if s.parenDepth == 0 {
		return scanText
	}

	// check the first char here
	char := s.peek()

	if isIdentifier(char) {
		return scanIdentifier
	} else if isWhitespace(char) {
		return scanWhitespace
	} else if isDigit(char) {
		return scanNumber
	} else if token.LookupRune(char) == token.CloseParen {
		return scanCloseParen
	} else if token.LookupRune(char) == token.OpenParen {
		return scanOpenParen
	} else if char == rune(0) {
		s.Emit(token.Error, "Unexpected EOF")

		return nil
	}

	s.Emit(token.Error, fmt.Sprintf("Unexpected %s", string(char)))

	return nil
}

func scanIdentifier(s *Scanner) scanFunc {
	value := ""

	for isIdentifier(s.peek()) {
		value += string(s.next())
	}

	s.Emit(token.Identifier, value)

	return scanInsideParen
}

func scanNumber(s *Scanner) scanFunc {
	return nil
}

func scanString(s *Scanner) scanFunc {
	return nil
}

func scanCloseParen(s *Scanner) scanFunc {
	s.Emit(token.CloseParen, string(s.next()))

	s.parenDepth--

	return scanInsideParen
}

func scanComment(s *Scanner) scanFunc {
	value := ""

	for s.next() != rune(0) {
		if s.ch == '\n' {
			s.backup()
			s.Emit(token.Comment, value)

			return scanWhitespace
		}

		value += string(s.ch)
	}

	if s.parenDepth > 0 {
		return scanInsideParen
	}

	return scanText
}

func isIdentifier(r rune) bool {
	return (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || isSymbol(r) || isDigit(r)
}

func isDigit(r rune) bool {
	return r >= '0' && r <= '9'
}

func isSymbol(r rune) bool {
	// quotes are used for strings
	if r == '"' {
		return false
	}

	switch token.LookupRune(r) {
	case token.OpenParen:
		fallthrough
	case token.CloseParen:
		fallthrough
	case token.Comment:
		return false
	default:
		break
	}

	return r >= '!' && r <= '/'
}

func isNewline(r rune) bool {
	return r == '\n'
}

func isWhitespace(r rune) bool {
	switch r {
	case '\n':
		fallthrough
	case '\t':
		fallthrough
	case '\r':
		fallthrough
	case ' ':
		return true
	default:
		return false
	}
}
