`timescale 1ns/1ps

module ram_fetch_relu_env #(
  parameter bit HAS_RESET = 1'b1,
  parameter int RESET_CYCLES = 3,
  parameter int TIMEOUT_CYCLES = 20,
  parameter int NUM_EXPECTED_OUTPUTS = 4,
  parameter bit HOLD_LAST_ADDR_VALID = 1'b0
) (
  output reg clk,
  output reg rst,
  output reg [31:0] addr_in,
  output reg addr_in_vld,
  input wire addr_in_rdy,
  input wire [31:0] ram_req,
  input wire ram_req_vld,
  output reg ram_req_rdy,
  output reg [31:0] ram_resp,
  output reg ram_resp_vld,
  input wire ram_resp_rdy,
  input wire [31:0] out_ch,
  input wire out_ch_vld,
  output reg out_ch_rdy
);
  reg pending_valid;
  reg [31:0] pending_addr;
  integer addr_count;
  integer out_count;

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

  initial begin
    clk = 1'b0;
    rst = HAS_RESET;
    addr_in = 32'd0;
    addr_in_vld = 1'b0;
    ram_req_rdy = 1'b1;
    ram_resp = 32'd0;
    ram_resp_vld = 1'b0;
    out_ch_rdy = 1'b1;
    pending_valid = 1'b0;
    pending_addr = 32'd0;
    addr_count = 0;
    out_count = 0;
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
  end

  always @(posedge clk) begin
    if (HAS_RESET && rst) begin
      addr_count <= 0;
      out_count <= 0;
      pending_valid <= 1'b0;
      pending_addr <= 32'd0;
      ram_resp_vld <= 1'b0;
      ram_resp <= 32'd0;
    end else begin
      if (addr_in_vld && addr_in_rdy && addr_count < NUM_EXPECTED_OUTPUTS) begin
        addr_count <= addr_count + 1;
      end

      ram_resp_vld <= pending_valid;
      ram_resp <= ram_read(pending_addr);
      pending_valid <= 1'b0;

      if (ram_req_vld && ram_req_rdy) begin
        pending_valid <= 1'b1;
        pending_addr <= ram_req;
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
    end
  end

  initial begin
    if (HAS_RESET) begin
      repeat (RESET_CYCLES) @(posedge clk);
      rst <= 1'b0;
    end
  end

  initial begin
    repeat (TIMEOUT_CYCLES) @(posedge clk);
    $display("timeout");
    $fatal;
  end

  wire unused_ram_resp_rdy = ram_resp_rdy;
endmodule
