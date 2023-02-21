SHELL = zsh

benchmark_directory = benchmarks

gnark_directory = gnark
gnark_benchmarks_directory = $(benchmark_directory)/$(gnark_directory)


all: benchmark-toy

benchmark-toy-circom:
	$(info --------------------------------------------)
	$(info ---------- CIRCOM TOY BENCHMARKS -----------)
	$(info --------------------------------------------)
	python3 -m _scripts.reader --config _input/config/circom/config_all_toy.json  

benchmark-toy-gnark:
	$(info --------------------------------------------)
	$(info ----------- GNARK TOY BENCHMARKS -----------)
	$(info --------------------------------------------)
	python3 -m _scripts.reader --config _input/config/gnark/config_all_toy.json  

benchmark-prf:
	python3 -m _scripts.reader --config _input/config/gnark/config_prf.json  

test-simple:
	python3 -m _scripts.reader --config _input/config/gnark/config_gnark_simple.json  

clean:
	rm -r $(gnark_benchmarks_directory)/*
