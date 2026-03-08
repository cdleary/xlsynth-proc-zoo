`timescale 1ns/1ps

module tb;
  wire clk;
  wire rst;

  initial begin
    string dump_path;
    if ($test$plusargs("dump_vcd")) begin
      if (!$value$plusargs("dump_path=%s", dump_path)) begin
        dump_path = "fetch_relu_split_tb.vcd";
      end
      $dumpfile(dump_path);
      $dumpvars(0, tb);
    end
  end

  wire [31:0] addr_in;
  wire addr_in_vld;
  wire addr_in_rdy;

  wire [31:0] ram_req;
  wire ram_req_vld;
  wire ram_req_rdy;

  wire [31:0] ram_resp;
  wire ram_resp_vld;
  wire ram_resp_rdy;

  wire [31:0] out_ch;
  wire out_ch_vld;
  wire out_ch_rdy;

  ram_fetch_relu_env #(
      .HAS_RESET(1'b1),
      .RESET_CYCLES(3),
      .TIMEOUT_CYCLES(20),
      .HOLD_LAST_ADDR_VALID(1'b0)
  ) env (
      .clk(clk),
      .rst(rst),
      .addr_in(addr_in),
      .addr_in_vld(addr_in_vld),
      .addr_in_rdy(addr_in_rdy),
      .ram_req(ram_req),
      .ram_req_vld(ram_req_vld),
      .ram_req_rdy(ram_req_rdy),
      .ram_resp(ram_resp),
      .ram_resp_vld(ram_resp_vld),
      .ram_resp_rdy(ram_resp_rdy),
      .out_ch(out_ch),
      .out_ch_vld(out_ch_vld),
      .out_ch_rdy(out_ch_rdy)
  );

  __fetch_relu_split__SendAddr_0_next send_addr (
      .clk(clk),
      .rst(rst),
      .fetch_relu_split__addr_in(addr_in),
      .fetch_relu_split__addr_in_vld(addr_in_vld),
      .fetch_relu_split__ram_req_rdy(ram_req_rdy),
      .fetch_relu_split__addr_in_rdy(addr_in_rdy),
      .fetch_relu_split__ram_req(ram_req),
      .fetch_relu_split__ram_req_vld(ram_req_vld)
  );

  __fetch_relu_split__RecvRelu_0_next recv_relu (
      .clk(clk),
      .rst(rst),
      .fetch_relu_split__ram_resp(ram_resp),
      .fetch_relu_split__ram_resp_vld(ram_resp_vld),
      .fetch_relu_split__out_ch_rdy(out_ch_rdy),
      .fetch_relu_split__ram_resp_rdy(ram_resp_rdy),
      .fetch_relu_split__out_ch(out_ch),
      .fetch_relu_split__out_ch_vld(out_ch_vld)
  );
endmodule
