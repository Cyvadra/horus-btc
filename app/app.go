package app

import (
	"bufio"
	"encoding/json"
	"io"
	"os"

	"github.com/Cyvadra/horus-btc/structures"
)

func OpenSampleFile(path string) (scanner *bufio.Scanner, err error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	return bufio.NewScanner(file), nil
}

func ParseLine(scanner *bufio.Scanner) (*structures.TransactionRow, error) {
	jsonCache := &structures.TransactionRow{}
	if scanner.Scan() {
		err := json.Unmarshal(scanner.Bytes(), jsonCache)
		return jsonCache, err
	}
	return jsonCache, io.EOF
}
