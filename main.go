package main

import (
	"bufio"
	"fmt"
	"os"

	"github.com/Cyvadra/horus-btc/structures"
	"github.com/NpoolPlatform/go-service-framework/pkg/logger"
	jsoniter "github.com/json-iterator/go"
)

var json = jsoniter.ConfigCompatibleWithStandardLibrary

func main() {
	scanner, err := readSampleFile("./sample/txRow-json.txt")
	if err != nil {
		logger.Sugar().Error(err)
		return
	}
	parseData(scanner)
}

func readSampleFile(path string) (scanner *bufio.Scanner, err error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	return bufio.NewScanner(file), nil
}

func parseData(scanner *bufio.Scanner) {
	jsonCache := &structures.TransactionRow{}
	for i := 0; i < 3; i++ {
		scanner.Scan()
		if err := json.Unmarshal(scanner.Bytes(), jsonCache); err != nil {
			logger.Sugar().Error(err)
		}
		fmt.Println(jsonCache)
	}
}
