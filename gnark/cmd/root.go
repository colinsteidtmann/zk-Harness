package cmd

import (
	"errors"
	"fmt"
	"os"
	"strings"

	"github.com/consensys/gnark-crypto/ecc"
	"github.com/pkg/profile"
	"github.com/spf13/cobra"
	"github.com/tumberger/zk-compilers/gnark/circuits"
)

// rootCmd represents the base command when called without any subcommands
var rootCmd = &cobra.Command{
	Use:   "gnark-harness",
	Short: "runs benchmarks and profiles using gnark",
}

// Execute adds all child commands to the root command and sets flags appropriately.
// This is called by main.main(). It only needs to happen once to the rootCmd.
func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

var (
	// Variables Circuit
	fCircuit     *string
	fCircuitSize *int
	fAlgo        *string
	fProfile     *string
	fCount       *int
	fCurve       *string
	fFileType    *string
	fInputPath   *string

	// Variables Arithmetic / Curve
	fOperation *string
	fField     *string
	fGroup     *string
)

var (
	curveID ecc.ID
	p       func(p *profile.Profile)
	c       circuits.BenchCircuit
)

func init() {

	cobra.OnInitialize()

	_curves := ecc.Implemented()
	curves := make([]string, len(_curves))
	for i := 0; i < len(_curves); i++ {
		curves[i] = strings.ToLower(_curves[i].String())
	}

	// Binding the input path to a variable
	fInputPath = rootCmd.PersistentFlags().String("input", "none", "input path to the dedicated input")
	rootCmd.MarkPersistentFlagRequired("input")

	fCircuit = rootCmd.PersistentFlags().String("circuit", "expo", "name of the circuit to use")
	fCircuitSize = rootCmd.PersistentFlags().Int("size", 10000, "size of the circuit, parameter to circuit constructor")
	fCount = rootCmd.PersistentFlags().Int("count", 2, "bench count (time is averaged on number of executions)")
	fAlgo = rootCmd.PersistentFlags().String("algo", "prove", "name of the algorithm to benchmark. must be compile, setup, prove or verify")
	fProfile = rootCmd.PersistentFlags().String("profile", "none", "type of profile. must be none, trace, cpu or mem")
	fCurve = rootCmd.PersistentFlags().String("curve", "bn254", "curve name. must be "+fmt.Sprint(curves))
	fFileType = rootCmd.PersistentFlags().String("filetype", "csv", "Type of file to output for benchmarks")

	fOperation = rootCmd.PersistentFlags().String("operation", "None", "operation to benchmark")
}

func parseFlags() error {
	if *fCircuitSize <= 0 {
		return errors.New("circuit size must be >= 0")
	}
	if *fCount <= 0 {
		return errors.New("bench count must be >= 0")
	}

	switch *fAlgo {
	case "compile", "setup", "witness", "prove", "verify":
	default:
		return errors.New("invalid algo")
	}

	switch *fProfile {
	case "none":
	case "trace":
		p = profile.TraceProfile
	case "cpu":
		p = profile.CPUProfile
	case "mem":
		p = profile.MemProfile
	default:
		return errors.New("invalid profile")
	}

	curves := ecc.Implemented()
	for _, id := range curves {
		if *fCurve == strings.ToLower(id.String()) {
			curveID = id
		}
	}
	if curveID == ecc.UNKNOWN {
		return errors.New("invalid curve")
	}

	if *fFileType != "csv" {
		return errors.New("invalid file type for log")
	}

	var ok bool
	c, ok = circuits.BenchCircuits[*fCircuit]
	if !ok {
		return errors.New("unknown circuit")
	}

	return nil
}
