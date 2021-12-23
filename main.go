package main

import (
	"fmt"
	"log"

	"github.com/Cyvadra/horus-btc/app"
	jsoniter "github.com/json-iterator/go"
)

var (
	json               = jsoniter.ConfigCompatibleWithStandardLibrary
	mapAddressTxCount  map[string]int64
	mapAddressTxAmount map[string]float64
	limitLines         = 280000
)

func init() {
	mapAddressTxCount = make(map[string]int64)
	mapAddressTxAmount = make(map[string]float64)
}

func main() {
	// open file
	scanner, err := app.OpenSampleFile("./sample/txRow-json.txt")
	if err != nil {
		log.Fatal(err)
	}

	// iterate
	for z := 0; z < limitLines; z++ {
		row, err := app.ParseLine(scanner)
		if err != nil {
			log.Default().Println(err)
			break
		}

		// statistics
		// what the hell?.... adapt bitcoinetl format for now
		for i := range row.Inputs {
			for _, addr := range row.Inputs[i].Addresses {
				mapAddressTxCount[addr]++
				if row.Inputs[i].Value <= 0 {
					mapAddressTxAmount[addr] += float64(row.OutputValue) / 100000000
				} else {
					mapAddressTxAmount[addr] += float64(row.Inputs[i].Value) / 100000000
				}
			}
		}
		for _, output := range row.Outputs {
			for _, addr := range output.Addresses {
				mapAddressTxCount[addr]++
				mapAddressTxAmount[addr] += float64(output.Value) / 100000000
			}
		}
	}

	txAmount, err := json.Marshal(mapAddressTxAmount)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(string(txAmount))

	txCount, err := json.Marshal(mapAddressTxCount)
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(string(txCount))
}
