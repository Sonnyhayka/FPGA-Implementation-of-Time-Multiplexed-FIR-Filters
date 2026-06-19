`timescale 1ns/1ps

module tb_fir;

  parameter N = 64;
  parameter M = 4;
  parameter IN_WIDTH = 12;
  parameter OUT_WIDTH = 12;
  parameter NSAMP = 4000;
  parameter INPUT_FILE = "x_q210.txt";
  parameter COEFF_FILE = "h_q115.txt";
  parameter OUT0_FILE = "fir_output_srl0.txt";
  parameter OUT1_FILE = "fir_output_srl1.txt";

  reg clk;
  reg rst;
  reg in_valid;
  reg [$clog2(NSAMP)-1:0] idx;
  reg [IN_WIDTH-1:0] xmem [0:NSAMP-1];

  wire in_ready0;
  wire in_ready1;
  wire out_valid0;
  wire out_valid1;
  wire signed [OUT_WIDTH-1:0] y0;
  wire signed [OUT_WIDTH-1:0] y1;
  wire signed [IN_WIDTH-1:0] x;

  integer f0;
  integer f1;
  integer n0;
  integer n1;

  assign x = xmem[idx];

  fir_time_mux_top #(
    .N(N),
    .M(M),
    .SRL_REG(0),
    .COEFF_FILE(COEFF_FILE)
  ) dut0 (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .in_ready(in_ready0),
    .x_in(x),
    .out_valid(out_valid0),
    .y_out(y0)
  );

  fir_time_mux_top #(
    .N(N),
    .M(M),
    .SRL_REG(1),
    .COEFF_FILE(COEFF_FILE)
  ) dut1 (
    .clk(clk),
    .rst(rst),
    .in_valid(in_valid),
    .in_ready(in_ready1),
    .x_in(x),
    .out_valid(out_valid1),
    .y_out(y1)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  initial begin
    $readmemb(INPUT_FILE, xmem);
    rst = 1'b1;
    in_valid = 1'b0;
    idx = 0;
    n0 = 0;
    n1 = 0;
    f0 = $fopen(OUT0_FILE, "w");
    f1 = $fopen(OUT1_FILE, "w");
    repeat (8) @(posedge clk);
    rst <= 1'b0;
  end

  always @(posedge clk) begin
    if (rst) begin
      in_valid <= 1'b0;
      idx <= 0;
    end else begin
      in_valid <= (idx < NSAMP);
      if (in_valid && in_ready0 && in_ready1 && (idx < NSAMP)) begin
        idx <= idx + 1'b1;
      end
    end
  end

  always @(posedge clk) begin
    if (!rst) begin
      if (out_valid0) begin
        $fwrite(f0, "%0d\n", y0);
        n0 <= n0 + 1;
      end
      if (out_valid1) begin
        $fwrite(f1, "%0d\n", y1);
        n1 <= n1 + 1;
      end
      if ((n0 >= NSAMP) && (n1 >= NSAMP)) begin
        $fclose(f0);
        $fclose(f1);
        $display("tb_fir done srl0=%0d srl1=%0d samples written", n0, n1);
        $finish;
      end
    end
  end

  initial begin
    #5000000;
    $display("tb_fir timeout srl0=%0d srl1=%0d", n0, n1);
    $fclose(f0);
    $fclose(f1);
    $finish;
  end

endmodule
