package token

import "fmt"

// Represents the position of a token
type Position struct {
	Line   int64
	Column int64
	Offset int64
}

func (p Position) String() string {
	return fmt.Sprintf("%d:%d", p.Line, p.Column)
}
