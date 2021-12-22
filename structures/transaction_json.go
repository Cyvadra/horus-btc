package structures

type TransactionRow struct {
	VirtualSize    int32    `json:"virtual_size"`
	OutputCount    int32    `json:"output_count"`
	BlockTimestamp int64    `json:"block_timestamp"`
	Outputs        []Output `json:"outputs"`
	InputValue     int32    `json:"input_value"`
	LockTime       int32    `json:"lock_time"`
	Version        int32    `json:"version"`
	IsCoinbase     bool     `json:"is_coinbase"`
	Hash           string   `json:"hash"`
	Size           int32    `json:"size"`
	BlockNumber    int32    `json:"block_number"`
	Index          int32    `json:"index"`
	BlockHash      string   `json:"block_hash"`
	InputCount     int32    `json:"input_count"`
	Fee            int64    `json:"fee"`
	Inputs         []Input  `json:"inputs"`
	OutputValue    int64    `json:"output_value"`
}

type Input struct {
	SpentTransactionHash string   `json:"spent_transaction_hash"`
	ScriptAsm            string   `json:"script_asm"`
	ScriptHex            string   `json:"script_hex"`
	Sequence             int64    `json:"sequence"`
	Addresses            []string `json:"addresses"`
	RequiredSignatures   []ReqSig `json:"required_signatures"`
	Value                int64    `json:"value"`
	Type                 string   `json:"type"`
	Index                int32    `json:"index"`
	SpentOutputIndex     int32    `json:"spent_output_index"`
}

type Output struct {
	ScriptAsm          string   `json:"script_asm"`
	ScriptHex          string   `json:"script_hex"`
	Addresses          []string `json:"addresses"`
	RequiredSignatures []ReqSig `json:"required_signatures"`
	Value              int64    `json:"value"`
	Type               string   `json:"type"`
	Index              int32    `json:"index"`
}

type ReqSig struct{}
