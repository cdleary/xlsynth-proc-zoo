`timescale 1ns/1ps

module ram_fetch_relu_env #(
  parameter bit HAS_RESET = 1'b1,
  parameter int RESET_CYCLES = 3,
  parameter int TIMEOUT_CYCLES = 20,
  parameter int NUM_EXPECTED_OUTPUTS = 4,
  parameter bit HOLD_LAST_ADDR_VALID = 1'b0,
  parameter int DEFAULT_RAM_LATENCY = 1,
  parameter int DEFAULT_RAM_REQ_STALL_PERIOD = 0,
  parameter int DEFAULT_RAM_REQ_STALL_CYCLES = 0,
  parameter int DEFAULT_OUT_CH_STALL_PERIOD = 0,
  parameter int DEFAULT_OUT_CH_STALL_CYCLES = 0,
  parameter int MAX_RAM_LATENCY = 8,
  parameter int RESPONSE_QUEUE_DEPTH = 8
) (
  output reg clk,
  output reg rst,
  output reg [31:0] addr_in,
  output reg addr_in_vld,
  input wire addr_in_rdy,
  input wire [31:0] ram_req,
  input wire ram_req_vld,
  output reg ram_req_rdy,
  output wire [31:0] ram_resp,
  output wire ram_resp_vld,
  input wire ram_resp_rdy,
  input wire [31:0] out_ch,
  input wire out_ch_vld,
  output reg out_ch_rdy
);
  reg latency_valid [0:MAX_RAM_LATENCY-1];
  reg [31:0] latency_addr [0:MAX_RAM_LATENCY-1];
  reg [31:0] response_queue [0:RESPONSE_QUEUE_DEPTH-1];
  integer addr_count;
  integer out_count;
  integer active_cycle;
  integer timeout_cycles;
  integer ram_latency;
  integer ram_req_stall_period;
  integer ram_req_stall_cycles;
  integer out_ch_stall_period;
  integer out_ch_stall_cycles;
  integer resp_head;
  integer resp_tail;
  integer resp_count;
  reg do_resp_enqueue;
  reg do_resp_dequeue;
  integer i;

  function automatic [31:0] ram_read(input [31:0] addr);
    begin
      case (addr)
        32'd0: ram_read = 32'hffff_fffd;  // -3
        32'd1: ram_read = 32'd7;
        32'd2: ram_read = 32'd0;
        default: ram_read = 32'd5;
      endcase
    end
  endfunction

  function automatic [31:0] expected_relu(input integer index);
    begin
      case (index)
        0: expected_relu = 32'd0;
        1: expected_relu = 32'd7;
        2: expected_relu = 32'd0;
        default: expected_relu = 32'd5;
      endcase
    end
  endfunction

  function automatic bit ready_for_cycle(
      input integer cycle,
      input integer stall_period,
      input integer stall_cycles
  );
    begin
      if (stall_period <= 0 || stall_cycles <= 0) begin
        ready_for_cycle = 1'b1;
      end else begin
        ready_for_cycle = (cycle % stall_period) >= stall_cycles;
      end
    end
  endfunction

  assign ram_resp_vld = resp_count > 0;
  assign ram_resp = (resp_count > 0) ? response_queue[resp_head] : 32'd0;

  initial begin
    clk = 1'b0;
    rst = HAS_RESET;
    addr_in = 32'd0;
    addr_in_vld = 1'b0;
    ram_req_rdy = 1'b1;
    out_ch_rdy = 1'b1;
    addr_count = 0;
    out_count = 0;
    active_cycle = 0;
    timeout_cycles = TIMEOUT_CYCLES;
    ram_latency = DEFAULT_RAM_LATENCY;
    ram_req_stall_period = DEFAULT_RAM_REQ_STALL_PERIOD;
    ram_req_stall_cycles = DEFAULT_RAM_REQ_STALL_CYCLES;
    out_ch_stall_period = DEFAULT_OUT_CH_STALL_PERIOD;
    out_ch_stall_cycles = DEFAULT_OUT_CH_STALL_CYCLES;
    resp_head = 0;
    resp_tail = 0;
    resp_count = 0;
    for (i = 0; i < MAX_RAM_LATENCY; i = i + 1) begin
      latency_valid[i] = 1'b0;
      latency_addr[i] = 32'd0;
    end
    for (i = 0; i < RESPONSE_QUEUE_DEPTH; i = i + 1) begin
      response_queue[i] = 32'd0;
    end
    if ($value$plusargs("timeout_cycles=%d", timeout_cycles)) begin end
    if ($value$plusargs("ram_latency=%d", ram_latency)) begin end
    if ($value$plusargs("ram_req_stall_period=%d", ram_req_stall_period)) begin end
    if ($value$plusargs("ram_req_stall_cycles=%d", ram_req_stall_cycles)) begin end
    if ($value$plusargs("out_ch_stall_period=%d", out_ch_stall_period)) begin end
    if ($value$plusargs("out_ch_stall_cycles=%d", out_ch_stall_cycles)) begin end
    if (ram_latency < 1 || ram_latency > MAX_RAM_LATENCY) begin
      $display("invalid ram_latency=%0d max=%0d", ram_latency, MAX_RAM_LATENCY);
      $fatal;
    end
    if (ram_req_stall_cycles < 0 || out_ch_stall_cycles < 0) begin
      $display("stall cycle counts must be non-negative");
      $fatal;
    end
  end

  always #5 clk = ~clk;

  always @(negedge clk) begin
    if ((!HAS_RESET || !rst) && (HOLD_LAST_ADDR_VALID || addr_count < NUM_EXPECTED_OUTPUTS)) begin
      addr_in_vld <= 1'b1;
      addr_in <= addr_count[31:0];
    end else begin
      addr_in_vld <= 1'b0;
      addr_in <= 32'd0;
    end
    ram_req_rdy <= ready_for_cycle(active_cycle, ram_req_stall_period, ram_req_stall_cycles);
    out_ch_rdy <= ready_for_cycle(active_cycle, out_ch_stall_period, out_ch_stall_cycles);
  end

  always @(posedge clk) begin
    if (HAS_RESET && rst) begin
      addr_count <= 0;
      out_count <= 0;
      active_cycle <= 0;
      resp_head <= 0;
      resp_tail <= 0;
      resp_count <= 0;
      for (i = 0; i < MAX_RAM_LATENCY; i = i + 1) begin
        latency_valid[i] <= 1'b0;
        latency_addr[i] <= 32'd0;
      end
    end else begin
      do_resp_enqueue = latency_valid[0];
      do_resp_dequeue = ram_resp_vld && ram_resp_rdy;

      if (addr_in_vld && addr_in_rdy && addr_count < NUM_EXPECTED_OUTPUTS) begin
        addr_count <= addr_count + 1;
      end

      if (do_resp_dequeue) begin
        resp_head <= (resp_head + 1) % RESPONSE_QUEUE_DEPTH;
      end

      if (do_resp_enqueue) begin
        if (resp_count == RESPONSE_QUEUE_DEPTH && !do_resp_dequeue) begin
          $display("response queue overflow");
          $fatal;
        end
        response_queue[resp_tail] <= ram_read(latency_addr[0]);
        resp_tail <= (resp_tail + 1) % RESPONSE_QUEUE_DEPTH;
      end

      if (do_resp_enqueue && !do_resp_dequeue) begin
        resp_count <= resp_count + 1;
      end else if (!do_resp_enqueue && do_resp_dequeue) begin
        resp_count <= resp_count - 1;
      end

      for (i = 0; i < MAX_RAM_LATENCY - 1; i = i + 1) begin
        latency_valid[i] <= latency_valid[i + 1];
        latency_addr[i] <= latency_addr[i + 1];
      end
      latency_valid[MAX_RAM_LATENCY - 1] <= 1'b0;
      latency_addr[MAX_RAM_LATENCY - 1] <= 32'd0;

      if (ram_req_vld && ram_req_rdy) begin
        latency_valid[ram_latency - 1] <= 1'b1;
        latency_addr[ram_latency - 1] <= ram_req;
      end

      if (out_ch_vld && out_ch_rdy) begin
        if (out_ch !== expected_relu(out_count)) begin
          $display("unexpected relu output idx=%0d got=%0d expected=%0d", out_count, $signed(out_ch), $signed(expected_relu(out_count)));
          $fatal;
        end
        out_count <= out_count + 1;
        if (out_count == NUM_EXPECTED_OUTPUTS - 1) begin
          $display("PASS");
          $finish;
        end
      end

      active_cycle <= active_cycle + 1;
    end
  end

  initial begin
    if (HAS_RESET) begin
      repeat (RESET_CYCLES) @(posedge clk);
      rst <= 1'b0;
    end
  end

  initial begin
    repeat (timeout_cycles) @(posedge clk);
    $display("timeout");
    $fatal;
  end
endmodule
