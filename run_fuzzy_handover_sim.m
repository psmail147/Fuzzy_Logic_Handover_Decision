% Script to simulate fuzzy-logic-based handover between two base stations.

clear; clc; close all;

% Folder for saving figures
figDir = fullfile(pwd, 'figures');
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

% Build fuzzy inference system
fprintf('Building fuzzy inference system...\n');
fis = buildHandoverFIS();

%% Simulation parameters

% Geometry: two base stations separated by distance D (m)
D = 1000;
x_bs1 = 0;
x_bs2 = D;

% User motion: from BS1 towards BS2
v_ms = 20;                  % m/s  (≈ 72 km/h)
speed_kmh = v_ms * 3.6;

dt = 0.1;                   % time step (s)
T  = (D / v_ms) * 1.2;      % simulate a bit beyond crossing point
t  = 0:dt:T;
N  = numel(t);

% User position along x-axis
x = v_ms .* t;
x(x < 0) = 0;
x(x > D) = D;

% Path-loss model
Ptx          = -30;         % dBm (reference)
n_path       = 3.5;         % path-loss exponent
sigma_shadow = 2;           % shadowing std (dB)

rng(1);                     % reproducible noise

RSS1 = zeros(1, N);
RSS2 = zeros(1, N);

for k = 1:N
    d1 = max(1, abs(x(k) - x_bs1));  % avoid log10(0)
    d2 = max(1, abs(x(k) - x_bs2));

    RSS1(k) = Ptx - 10 * n_path * log10(d1) + sigma_shadow * randn;
    RSS2(k) = Ptx - 10 * n_path * log10(d2) + sigma_shadow * randn;
end

% RSS difference: target cell is BS2, serving cell is BS1
rssDiff = RSS2 - RSS1;

% Clip to input range of the FIS
rssDiff_clipped = max(min(rssDiff, 20), -20);

%% Evaluate fuzzy system (handover urgency)

fprintf('Evaluating fuzzy system over time...\n');

speedInput = speed_kmh * ones(N, 1);
fisInput   = [rssDiff_clipped(:) speedInput];

urgency = evalfis(fis, fisInput);
urgency = urgency(:)';

%% Handover decision logic

% Fuzzy-based handover
urgencyThr   = 0.6;
hoIdx_fuzzy  = NaN;
hoTime_fuzzy = NaN;
hoPos_fuzzy  = NaN;
hoFlag_fuzzy = false;

for k = 1:N
    if ~hoFlag_fuzzy && urgency(k) >= urgencyThr
        hoFlag_fuzzy  = true;
        hoIdx_fuzzy   = k;
        hoTime_fuzzy  = t(k);
        hoPos_fuzzy   = x(k);
    end
end

% Threshold-based handover on raw RSS difference
rssDiffThr   = 3;   % dB
hoIdx_thr    = NaN;
hoTime_thr   = NaN;
hoPos_thr    = NaN;
hoFlag_thr   = false;

for k = 1:N
    if ~hoFlag_thr && rssDiff(k) >= rssDiffThr
        hoFlag_thr  = true;
        hoIdx_thr   = k;
        hoTime_thr  = t(k);
        hoPos_thr   = x(k);
    end
end

%% Simple call-drop indicator

dropThr = -100;     % dBm

% Fuzzy scheme
if hoFlag_fuzzy
    idx_before       = 1:hoIdx_fuzzy;
    idx_after        = hoIdx_fuzzy:N;
    drop_before_fuzzy = any(RSS1(idx_before) < dropThr);
    drop_after_fuzzy  = any(RSS2(idx_after)  < dropThr);
else
    idx_before        = 1:N;
    idx_after         = [];
    drop_before_fuzzy = any(RSS1(idx_before) < dropThr);
    drop_after_fuzzy  = false;
end

% Threshold scheme
if hoFlag_thr
    idx_before_thr       = 1:hoIdx_thr;
    idx_after_thr        = hoIdx_thr:N;
    drop_before_thr      = any(RSS1(idx_before_thr) < dropThr);
    drop_after_thr       = any(RSS2(idx_after_thr)  < dropThr);
else
    idx_before_thr       = 1:N;
    idx_after_thr        = [];
    drop_before_thr      = any(RSS1(idx_before_thr) < dropThr);
    drop_after_thr       = false;
end

%% Print summary

fprintf('\n=== Simulation summary ===\n');
fprintf('User speed: %.1f km/h\n', speed_kmh);

if hoFlag_fuzzy
    fprintf('Fuzzy HO:       t = %.2f s, x = %.1f m\n', hoTime_fuzzy, hoPos_fuzzy);
else
    fprintf('Fuzzy HO:       never triggered.\n');
end

if hoFlag_thr
    fprintf('Threshold HO:   t = %.2f s, x = %.1f m\n', hoTime_thr, hoPos_thr);
else
    fprintf('Threshold HO:   never triggered.\n');
end

fprintf('Fuzzy scheme - any drop before HO on BS1?  %d\n', drop_before_fuzzy);
fprintf('Fuzzy scheme - any drop after HO on BS2?   %d\n', drop_after_fuzzy);
fprintf('Thresh scheme - any drop before HO on BS1? %d\n', drop_before_thr);
fprintf('Thresh scheme - any drop after HO on BS2?  %d\n', drop_after_thr);

%% Plots

% Membership functions
fig1 = figure('Name', 'Membership functions - Inputs');
subplot(2,1,1);
plotmf(fis, 'input', 1);
title('Input 1: RSS difference (dB)');
xlabel('RSS_{target} - RSS_{serving} (dB)');

subplot(2,1,2);
plotmf(fis, 'input', 2);
title('Input 2: Speed (km/h)');
xlabel('Speed (km/h)');

saveas(fig1, fullfile(figDir, 'fig_mf_inputs.png'));
savefig(fig1, fullfile(figDir, 'fig_mf_inputs.fig'));

fig2 = figure('Name', 'Membership functions - Output');
plotmf(fis, 'output', 1);
title('Output: Handover urgency');
xlabel('Urgency');

saveas(fig2, fullfile(figDir, 'fig_mf_output.png'));
savefig(fig2, fullfile(figDir, 'fig_mf_output.fig'));

% RSS vs time with handover instants
fig3 = figure('Name', 'RSS vs time and handover instants');
plot(t, RSS1, 'LineWidth', 1.2); hold on;
plot(t, RSS2, 'LineWidth', 1.2);

if hoFlag_fuzzy
    xline(t(hoIdx_fuzzy), '--', 'Fuzzy HO', 'LabelOrientation', 'horizontal', ...
        'LabelVerticalAlignment', 'bottom');
end
if hoFlag_thr
    xline(t(hoIdx_thr), ':', 'Threshold HO', 'LabelOrientation', 'horizontal', ...
        'LabelVerticalAlignment', 'top');
end

yline(dropThr, '--r', 'Drop threshold');

grid on;
xlabel('Time (s)');
ylabel('RSS (dBm)');
legend({'RSS from BS1 (serving)', 'RSS from BS2 (target)'}, 'Location', 'best');
title('Received signal strength vs time');

saveas(fig3, fullfile(figDir, 'fig_rss_vs_time.png'));
savefig(fig3, fullfile(figDir, 'fig_rss_vs_time.fig'));

% RSS difference and handover urgency
fig4 = figure('Name', 'RSS difference and fuzzy urgency');
yyaxis left;
plot(t, rssDiff, 'LineWidth', 1.2);
ylabel('RSS_{target} - RSS_{serving} (dB)');
grid on;

yyaxis right;
plot(t, urgency, 'LineWidth', 1.2);
hold on;
yline(urgencyThr, '--', 'Urgency threshold');
ylabel('Fuzzy handover urgency');

xlabel('Time (s)');
title('RSS difference and fuzzy handover urgency');
legend({'RSS diff', 'Urgency', 'Urgency threshold'}, 'Location', 'best');

saveas(fig4, fullfile(figDir, 'fig_rssdiff_urgency.png'));
savefig(fig4, fullfile(figDir, 'fig_rssdiff_urgency.fig'));

% User position and handover points
fig5 = figure('Name', 'User position and handover points');
plot(t, x, 'LineWidth', 1.2);
hold on;
yline(x_bs1, '--k', 'BS1');
yline(x_bs2, '--k', 'BS2');

if hoFlag_fuzzy
    plot(hoTime_fuzzy, hoPos_fuzzy, 'ro', 'MarkerSize', 8, 'DisplayName', 'Fuzzy HO');
end
if hoFlag_thr
    plot(hoTime_thr, hoPos_thr, 'gx', 'MarkerSize', 8, 'DisplayName', 'Threshold HO');
end

grid on;
xlabel('Time (s)');
ylabel('Position x (m)');
title('User trajectory between base stations');
legend('User position', 'BS1', 'BS2', 'Location', 'best');

saveas(fig5, fullfile(figDir, 'fig_position.png'));
savefig(fig5, fullfile(figDir, 'fig_position.fig'));

fprintf('\nSimulation complete. Figures saved in folder: %s\n', figDir);
