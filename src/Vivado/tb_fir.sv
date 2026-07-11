`timescale 1ns/1ps

module tb_fir;

  localparam int N = 64;
  localparam int M = 4;
  localparam int IN_WIDTH = 12;
  localparam int OUT_WIDTH = 12;
  localparam int NSAMP = 4000;
  localparam INPUT_FILE = "x_q210.txt";
  localparam COEFF_FILE = "h_q115_packed.txt";
  localparam EXPECTED_FILE = "y_matlab_q210.txt";
  localparam OUT0_FILE = "fir_output_srl0.txt";
  localparam OUT1_FILE = "fir_output_srl1.txt";

  logic clk;
  logic rst;
  logic in_valid;
  logic [$clog2(NSAMP)-1:0] idx;
  logic [IN_WIDTH-1:0] xmem [0:NSAMP-1];
  integer expected [0:NSAMP-1];

  logic in_ready0;
  logic in_ready1;
  logic out_valid0;
  logic out_valid1;
  logic signed [OUT_WIDTH-1:0] y0;
  logic signed [OUT_WIDTH-1:0] y1;
  logic signed [IN_WIDTH-1:0] x;

  int f0;
  int f1;
  int fe;
  int scan_status;
  int n0;
  int n1;
  int errors;

  assign x = idx < NSAMP ? xmem[idx] : '0;

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
    fe = $fopen(EXPECTED_FILE, "r");
    if (fe == 0) begin
      $fatal(1, "cannot open %s", EXPECTED_FILE);
    end
    for (int i = 0; i < NSAMP; i++) begin
      scan_status = $fscanf(fe, "%d", expected[i]);
      if (scan_status != 1) begin
        $fatal(1, "invalid expected sample at index %0d", i);
      end
    end
    $fclose(fe);
    rst = 1'b1;
    in_valid = 1'b0;
    idx = 0;
    n0 = 0;
    n1 = 0;
    errors = 0;
    f0 = $fopen(OUT0_FILE, "w");
    f1 = $fopen(OUT1_FILE, "w");
    if (f0 == 0 || f1 == 0) begin
      $fatal(1, "cannot open output files");
    end
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
        if ($signed(y0) != expected[n0]) begin
          errors <= errors + 1;
          $display("srl0 mismatch index=%0d got=%0d expected=%0d", n0, $signed(y0), expected[n0]);
        end
        n0 <= n0 + 1;
      end
      if (out_valid1) begin
        $fwrite(f1, "%0d\n", y1);
        if ($signed(y1) != expected[n1]) begin
          errors <= errors + 1;
          $display("srl1 mismatch index=%0d got=%0d expected=%0d", n1, $signed(y1), expected[n1]);
        end
        n1 <= n1 + 1;
      end
      if ((n0 >= NSAMP) && (n1 >= NSAMP)) begin
        $fclose(f0);
        $fclose(f1);
        if (errors == 0) begin
          $display("tb_fir PASS srl0=%0d srl1=%0d", n0, n1);
          $finish;
        end else begin
          $fatal(1, "tb_fir FAIL errors=%0d", errors);
        end
      end
    end
  end

  initial begin
    #5000000;
    $display("tb_fir timeout srl0=%0d srl1=%0d", n0, n1);
    $fclose(f0);
    $fclose(f1);
    $fatal(1, "tb_fir timeout");
  end

endmodule
