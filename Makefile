.PHONY: all dslx-test codegen-check rtl-sim rtl-sim-split rtl-sim-single-pipelined rtl-sim-single-cold-steady-drain rtl-sim-single-dual-token rtl-sim-single-nonblocking rtl-sim-single-nonblocking-internal-counter wave-analysis wave-sweep wave-io-kind-sweep characterize-send-recv-patterns

all: dslx-test codegen-check rtl-sim

dslx-test:
	bash scripts/test_dslx_examples.sh

codegen-check:
	bash scripts/check_codegen_throughput.sh

rtl-sim: rtl-sim-split rtl-sim-single-pipelined rtl-sim-single-cold-steady-drain rtl-sim-single-dual-token rtl-sim-single-nonblocking rtl-sim-single-nonblocking-internal-counter

rtl-sim-split:
	bash scripts/run_iverilog_split.sh

rtl-sim-single-pipelined:
	bash scripts/run_iverilog_single_pipelined.sh

rtl-sim-single-cold-steady-drain:
	bash scripts/run_iverilog_single_cold_steady_drain.sh

rtl-sim-single-dual-token:
	bash scripts/run_iverilog_single_dual_token.sh

rtl-sim-single-nonblocking:
	bash scripts/run_iverilog_single_nonblocking.sh

rtl-sim-single-nonblocking-internal-counter:
	bash scripts/run_iverilog_single_nonblocking_internal_counter.sh

wave-analysis:
	bash scripts/run_wave_analysis.sh

wave-sweep:
	bash scripts/run_ram_fetch_relu_sweep.sh

wave-io-kind-sweep:
	bash scripts/run_ram_fetch_relu_io_kind_sweep.sh

characterize-send-recv-patterns:
	bash scripts/characterize_send_recv_patterns.sh
