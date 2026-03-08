`timescale 1ns/1ps

module tb;
  reg clk = 0;
  always #5 clk = ~clk;

  initial begin
    string dump_path;
    if ($test$plusargs("dump_vcd")) begin
      if (!$value$plusargs("dump_path=%s", dump_path)) begin
        dump_path = "fetch_relu_single_nonblocking_tb.vcd";
      end
      $dumpfile(dump_path);
      $dumpvars(0, tb);
    end
  end

  reg rst = 1'b1;

  reg [31:0] addr_in = 32'd0;
  reg addr_in_vld = 1'b0;
  wire addr_in_rdy;

  wire [31:0] ram_req;
  wire ram_req_vld;
  reg ram_req_rdy = 1'b1;

  reg [31:0] ram_resp = 32'd0;
  reg ram_resp_vld = 1'b0;
  wire ram_resp_rdy;

  wire [31:0] out_ch;
  wire out_ch_vld;
  reg out_ch_rdy = 1'b1;

  reg pending_valid = 1'b0;
  reg [31:0] pending_addr = 32'd0;
  integer addr_count = 0;
  integer out_count = 0;

  __fetch_relu_single_nonblocking__FetchReluSingleNonBlocking_0_next dut (
      .clk(clk),
      .rst(rst),
      .fetch_relu_single_nonblocking__addr_in(addr_in),
      .fetch_relu_single_nonblocking__addr_in_vld(addr_in_vld),
      .fetch_relu_single_nonblocking__ram_req_rdy(ram_req_rdy),
      .fetch_relu_single_nonblocking__ram_resp(ram_resp),
      .fetch_relu_single_nonblocking__ram_resp_vld(ram_resp_vld),
      .fetch_relu_single_nonblocking__out_ch_rdy(out_ch_rdy),
      .fetch_relu_single_nonblocking__addr_in_rdy(addr_in_rdy),
      .fetch_relu_single_nonblocking__ram_req(ram_req),
      .fetch_relu_single_nonblocking__ram_req_vld(ram_req_vld),
      .fetch_relu_single_nonblocking__ram_resp_rdy(ram_resp_rdy),
      .fetch_relu_single_nonblocking__out_ch(out_ch),
      .fetch_relu_single_nonblocking__out_ch_vld(out_ch_vld)
  );

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

  always @(negedge clk) begin
    if (!rst) begin
      addr_in_vld <= 1'b1;
      addr_in <= addr_count[31:0];
    end else begin
      addr_in_vld <= 1'b0;
      addr_in <= 32'd0;
    end
  end

  always @(posedge clk) begin
    if (rst) begin
      addr_count <= 0;
      out_count <= 0;
      pending_valid <= 1'b0;
      pending_addr <= 32'd0;
      ram_resp_vld <= 1'b0;
      ram_resp <= 32'd0;
    end else begin
      if (addr_in_vld && addr_in_rdy) begin
        if (addr_count < 4) begin
          addr_count <= addr_count + 1;
        end
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
        if (out_count == 3) begin
          $display("PASS");
          $finish;
        end
      end
    end
  end

  initial begin
    repeat (3) @(posedge clk);
    rst <= 1'b0;
  end

  initial begin
    repeat (20) @(posedge clk);
    $display("timeout");
    $fatal;
  end
endmodule
