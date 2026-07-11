clear; clc; close all;

thisDir = fileparts(mfilename('fullpath'));
projRoot = fullfile(thisDir, '..', '..');
dataDir = fullfile(projRoot, 'data');
resultDir = fullfile(projRoot, 'result');

if ~exist(resultDir, 'dir')
    mkdir(resultDir);
end

N = 64;
IN_FRAC = 10;
COEFF_FRAC = 15;
OUT_FRAC = 10;
SHIFT = IN_FRAC + COEFF_FRAC - OUT_FRAC;
OUT_MIN = int64(-2048);
OUT_MAX = int64(2047);

inputData = load(fullfile(dataDir, 'Neural_Signal_Sample .mat'));
neuralSignal = double(inputData.neural_signal(:));
xInt = readSignedBinary(fullfile(dataDir, 'x_q210.txt'), 12);
hInt = readSignedBinary(fullfile(dataDir, 'h_q115.txt'), 16);

sampleCount = numel(xInt);
yExpected = zeros(sampleCount, 1, 'int64');
scale = bitshift(int64(1), SHIFT);
halfScale = bitshift(int64(1), SHIFT - 1);

for n = 1:sampleCount
    accumulator = int64(0);
    lastTap = min(N - 1, n - 1);
    for k = 0:lastTap
        accumulator = accumulator + xInt(n - k) * hInt(k + 1);
    end
    if accumulator >= 0
        rounded = idivide(accumulator + halfScale, scale, 'floor');
    else
        rounded = -idivide(-accumulator + halfScale, scale, 'floor');
    end
    yExpected(n) = min(max(rounded, OUT_MIN), OUT_MAX);
end

yGolden = int64(readmatrix(fullfile(dataDir, 'y_matlab_q210.txt')));
ySrl0 = int64(readmatrix(fullfile(dataDir, 'fir_output_srl0.txt')));
ySrl1 = int64(readmatrix(fullfile(dataDir, 'fir_output_srl1.txt')));

assert(numel(yGolden) == sampleCount, 'Golden output length mismatch');
assert(numel(ySrl0) == sampleCount, 'SRL_REG=0 output length mismatch');
assert(numel(ySrl1) == sampleCount, 'SRL_REG=1 output length mismatch');
assert(isequal(yExpected, yGolden), 'Recomputed MATLAB output differs from saved golden output');

difference0 = abs(yExpected - ySrl0);
difference1 = abs(yExpected - ySrl1);
maxDifference0 = max(difference0);
maxDifference1 = max(difference1);

assert(maxDifference0 == 0, 'SRL_REG=0 differs from MATLAB');
assert(maxDifference1 == 0, 'SRL_REG=1 differs from MATLAB');
assert(isequal(ySrl0, ySrl1), 'The two delay-line implementations differ');

sampleIndex = (0:sampleCount - 1).';
figureHandle = figure('Visible', 'off', 'Color', 'w');
subplot(2, 1, 1);
plot(sampleIndex, neuralSignal, 'Color', [0.55 0.55 0.55]);
hold on;
plot(sampleIndex, double(ySrl0) / 2^OUT_FRAC, 'b');
plot(sampleIndex, double(ySrl1) / 2^OUT_FRAC, 'r--');
plot(sampleIndex, double(yExpected) / 2^OUT_FRAC, 'k:');
hold off;
grid on;
xlabel('Sample index');
ylabel('Amplitude');
title('Input and fixed-point FIR outputs');
legend('Raw input', 'Verilog SRL\_REG=0', 'Verilog SRL\_REG=1', 'MATLAB fixed point', 'Location', 'best');
subplot(2, 1, 2);
plot(sampleIndex, double(difference0), 'b');
hold on;
plot(sampleIndex, double(difference1), 'r--');
hold off;
grid on;
xlabel('Sample index');
ylabel('Absolute error in LSBs');
title('Absolute difference between MATLAB and Verilog');
legend('|MATLAB-Verilog SRL\_REG=0|', '|MATLAB-Verilog SRL\_REG=1|', 'Location', 'best');

savefig(figureHandle, fullfile(resultDir, 'assignment6_verification.fig'));
exportgraphics(figureHandle, fullfile(resultDir, 'assignment6_verification.png'), 'Resolution', 200);
close(figureHandle);

summaryPath = fullfile(resultDir, 'verification_summary.txt');
summaryFile = fopen(summaryPath, 'w');
fprintf(summaryFile, 'Samples: %d\n', sampleCount);
fprintf(summaryFile, 'Taps: %d\n', N);
fprintf(summaryFile, 'SRL_REG=0 maximum absolute difference: %d LSB\n', maxDifference0);
fprintf(summaryFile, 'SRL_REG=1 maximum absolute difference: %d LSB\n', maxDifference1);
fprintf(summaryFile, 'SRL_REG outputs identical: 1\n');
fclose(summaryFile);

fprintf('Verification PASS for %d samples\n', sampleCount);
fprintf('SRL_REG=0 maximum absolute difference: %d LSB\n', maxDifference0);
fprintf('SRL_REG=1 maximum absolute difference: %d LSB\n', maxDifference1);

function values = readSignedBinary(path, width)
lines = strip(readlines(path));
lines(lines == "") = [];
unsignedValues = int64(bin2dec(char(lines)));
values = unsignedValues;
threshold = bitshift(int64(1), width - 1);
modulus = bitshift(int64(1), width);
negative = values >= threshold;
values(negative) = values(negative) - modulus;
end
