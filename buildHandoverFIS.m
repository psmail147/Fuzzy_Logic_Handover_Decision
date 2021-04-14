function fis = buildHandoverFIS()
%BUILDHANDOVERFIS Create fuzzy inference system for handover urgency.
%
%   FIS = BUILDHANDOVERFIS() returns a Mamdani-type fuzzy inference system
%   with two inputs:
%       1) RSS difference (RSS_target - RSS_serving) in dB
%       2) User speed in km/h
%   and one output:
%       - Handover urgency in [0, 1]

% Mamdani FIS settings
fis = mamfis( ...
    'Name', 'HandoverDecision', ...
    'AndMethod', 'min', ...
    'OrMethod', 'max', ...
    'ImplicationMethod', 'min', ...
    'AggregationMethod', 'max', ...
    'DefuzzificationMethod', 'centroid');

%% Input 1: RSS difference (dB), RSS_target - RSS_serving
fis = addInput(fis, [-20 20], 'Name', 'RSSdiff');

fis = addMF(fis, 'RSSdiff', 'trapmf', [-20 -20 -15 -10], 'Name', 'VeryNegative');
fis = addMF(fis, 'RSSdiff', 'trimf',  [-15 -8 -1],       'Name', 'Negative');
fis = addMF(fis, 'RSSdiff', 'trimf',  [-4 0 4],          'Name', 'Zero');
fis = addMF(fis, 'RSSdiff', 'trimf',  [1 8 15],          'Name', 'Positive');
fis = addMF(fis, 'RSSdiff', 'trapmf', [10 15 20 20],     'Name', 'VeryPositive');

%% Input 2: Speed (km/h)
fis = addInput(fis, [0 130], 'Name', 'Speed');

fis = addMF(fis, 'Speed', 'trapmf', [0 0 20 40],        'Name', 'Low');
fis = addMF(fis, 'Speed', 'trimf',  [30 60 90],         'Name', 'Medium');
fis = addMF(fis, 'Speed', 'trapmf', [80 100 130 130],   'Name', 'High');

%% Output: Handover urgency (0 to 1)
fis = addOutput(fis, [0 1], 'Name', 'Urgency');

fis = addMF(fis, 'Urgency', 'trapmf', [0 0 0.1 0.3], 'Name', 'VeryLow');
fis = addMF(fis, 'Urgency', 'trimf',  [0.1 0.3 0.5], 'Name', 'Low');
fis = addMF(fis, 'Urgency', 'trimf',  [0.3 0.5 0.7], 'Name', 'Medium');
fis = addMF(fis, 'Urgency', 'trimf',  [0.5 0.7 0.9], 'Name', 'High');
fis = addMF(fis, 'Urgency', 'trapmf', [0.7 0.9 1 1], 'Name', 'VeryHigh');

%% Rule base
% MF indices:
%   Input 1 (RSSdiff): 1=VeryNegative, 2=Negative, 3=Zero, 4=Positive, 5=VeryPositive
%   Input 2 (Speed):   1=Low, 2=Medium, 3=High
%   Output (Urgency):  1=VeryLow, 2=Low, 3=Medium, 4=High, 5=VeryHigh

ruleList = [ ...
    1 0 1 1 1;  % VeryNegative -> VeryLow
    2 0 2 1 1;  % Negative     -> Low
    3 1 3 1 1;  % Zero & Low   -> Medium
    3 3 4 1 1;  % Zero & High  -> High
    4 1 4 1 1;  % Positive & Low  -> High
    4 3 5 1 1;  % Positive & High -> VeryHigh
    5 0 5 1 1;  % VeryPositive -> VeryHigh
];

fis = addRule(fis, ruleList);

end
