`timescale 1ns/1ps

module tb;
  wire clk;
  wire rst;

  wire [31:0] addr_in;
  wire addr_in_vld;
  reg addr_in_rdy;

  reg [31:0] ram_req;
  reg ram_req_vld;
  wire ram_req_rdy;

  wire [31:0] ram_resp;
  wire ram_resp_vld;
  reg ram_resp_rdy;

  reg [31:0] out_ch;
  reg out_ch_vld;
  wire out_ch_rdy;

  integer cycle_count;
  integer req_cycle;
  integer resp_visible_cycle;
  integer resp_handshake_cycle;
  reg saw_req;
  reg saw_resp_visible;
  reg saw_resp_handshake;

  ram_fetch_relu_env #(
      .HAS_RESET(1'b1),
      .RESET_CYCLES(3),
      .TIMEOUT_CYCLES(12),
      .NUM_EXPECTED_OUTPUTS(0),
      .HOLD_LAST_ADDR_VALID(1'b0),
      .DEFAULT_RAM_LATENCY(1)
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

  initial begin
    addr_in_rdy = 1'b0;
    ram_req = 32'd1;
    ram_req_vld = 1'b0;
    ram_resp_rdy = 1'b1;
    out_ch = 32'd0;
    out_ch_vld = 1'b0;
    cycle_count = 0;
    req_cycle = -1;
    resp_visible_cycle = -1;
    resp_handshake_cycle = -1;
    saw_req = 1'b0;
    saw_resp_visible = 1'b0;
    saw_resp_handshake = 1'b0;
  end

  always @(negedge clk) begin
    if (!rst && !saw_req) begin
      ram_req_vld <= 1'b1;
      ram_req <= 32'd1;
    end else begin
      ram_req_vld <= 1'b0;
      ram_req <= 32'd0;
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      cycle_count = 0;
      req_cycle = -1;
      resp_visible_cycle = -1;
      resp_handshake_cycle = -1;
      saw_req = 1'b0;
      saw_resp_visible = 1'b0;
      saw_resp_handshake = 1'b0;
    end else begin
      cycle_count = cycle_count + 1;

      if (!saw_req && ram_req_vld && ram_req_rdy) begin
        req_cycle = cycle_count;
        saw_req = 1'b1;
      end

      if (!saw_resp_handshake && ram_resp_vld && ram_resp_rdy) begin
        resp_handshake_cycle = cycle_count;
        saw_resp_handshake = 1'b1;
      end

      #1;
      if (!saw_resp_visible && ram_resp_vld) begin
        resp_visible_cycle = cycle_count;
        saw_resp_visible = 1'b1;
      end

      if (saw_req && saw_resp_visible && saw_resp_handshake) begin
        $display(
            "ram_latency=%0d req_cycle=%0d resp_visible_cycle=%0d resp_handshake_cycle=%0d visible_latency=%0d handshake_latency=%0d",
            env.ram_latency,
            req_cycle,
            resp_visible_cycle,
            resp_handshake_cycle,
            resp_visible_cycle - req_cycle,
            resp_handshake_cycle - req_cycle
        );
        if ((resp_visible_cycle - req_cycle) != env.ram_latency) begin
          $display("response visibility latency mismatch");
          $fatal;
        end
        if ((resp_handshake_cycle - req_cycle) != env.ram_latency + 1) begin
          $display("response handshake latency mismatch");
          $fatal;
        end
        $display("PASS");
        $finish;
      end
    end
  end
endmodule
