package scan

import (
	"io"

	"github.com/landaire/hsc/source/token"
)

type scanFunc func(s *Scanner) scanFunc

type Scanner struct {
	ch      rune
	offset  int64
	line    int64
	text    io.Reader
	lastTok token.TokPosition
}

// New returns a new instance of a Scanner
func New(text io.Reader) Scanner {
	return Scanner{
		ch:     0,
		offset: 0,
		line:   1,
		text:   text,
	}
}

func (s *Scanner) Scan(out chan<- token.TokPosition) {
	scan := scanText

	for scan != nil {
		scan = scan(s)
		out <- s.lastTok
	}
}

func (s *Scanner) next() rune {
	var out [1]byte

	read, err := s.text.Read(out[:])
	if read == 0 || err != nil {
		return 0
	}

	s.ch = rune(out[0])
	s.offset++

	if s.ch == '\n' {
		s.line++
	}

	return s.ch
}

func scanText(s *Scanner) scanFunc {
	for s.next() != rune(0) {
		switch token.LookupRune(s.ch) {
		case token.OpenParen:
			return scanSExpr
		case token.Comment:
			return scanComment
		default:
			return nil
		}
	}

	return nil
}

func scanSExpr(s *Scanner) scanFunc {
	return nil
}

func scanComment(s *Scanner) scanFunc {
	return nil
}
