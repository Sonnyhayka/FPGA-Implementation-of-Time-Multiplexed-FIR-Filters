clear; clc;

thisDir = fileparts(mfilename('fullpath'));
projRoot = fullfile(thisDir, '..', '..');
dataDir = fullfile(projRoot, 'data');

N = 64;
M = 4;
CYCLES = N / M;

coeffFile = fullfile(dataDir, 'HW6_BPF .mat');
inputFile = fullfile(dataDir, 'Neural_Signal_Sample .mat');

Sh = load(coeffFile);
Sx = load(inputFile);
coefficients = double(Sh.coefficients(:));
neural_signal = double(Sx.neural_signal(:));

Fmac = fimath('RoundingMethod', 'Nearest', 'OverflowAction', 'Saturate', 'ProductMode', 'SpecifyPrecision', 'ProductWordLength', 28, 'ProductFractionLength', 25, 'SumMode', 'SpecifyPrecision', 'SumWordLength', 34, 'SumFractionLength', 25);
Fout = fimath('RoundingMethod', 'Nearest', 'OverflowAction', 'Saturate');

xq = fi(neural_signal, 1, 12, 10, Fmac);
hq = fi(coefficients, 1, 16, 15, Fmac);

L = numel(xq);
yq = fi(zeros(L, 1), 1, 12, 10, Fout);

for n = 1:L
    acc = fi(0, 1, 34, 25, Fmac);
    for k = 0:N-1
        idx = n - k;
        if idx >= 1
            acc = acc + hq(k+1) * xq(idx);
        end
    end
    yq(n) = fi(acc, 1, 12, 10, Fout);
end

yfloat = filter(coefficients, 1, neural_signal);

yfixed = double(yq);
maxErr = max(abs(yfixed - yfloat));
meanErr = mean(abs(yfixed - yfloat));
fprintf('samples %d\n', L);
fprintf('taps %d macs %d cycles %d\n', N, M, CYCLES);
fprintf('max abs error %.6f\n', maxErr);
fprintf('mean abs error %.6f\n', meanErr);

xbin = bin(xq);
hbin = bin(hq);
yint = storedInteger(yq);

xPath = fullfile(dataDir, 'x_q210.txt');
hPath = fullfile(dataDir, 'h_q115.txt');
yPath = fullfile(dataDir, 'y_matlab_q210.txt');

fid = fopen(xPath, 'w');
for i = 1:size(xbin, 1)
    fprintf(fid, '%s\n', xbin(i, :));
end
fclose(fid);

fid = fopen(hPath, 'w');
for i = 1:size(hbin, 1)
    fprintf(fid, '%s\n', hbin(i, :));
end
fclose(fid);

fid = fopen(yPath, 'w');
for i = 1:numel(yint)
    fprintf(fid, '%d\n', yint(i));
end
fclose(fid);

save(fullfile(dataDir, 'y_matlab.mat'), 'yq', 'yfloat', 'N', 'M', 'CYCLES');

figure;
plot(neural_signal);
hold on;
plot(yfloat);
plot(yfixed);
hold off;
grid on;
legend('input', 'float fir', 'fixed fir');
xlabel('sample index');
ylabel('amplitude');
title('Stage 2 golden model fixed point FIR');
