%% Simulink skidpad parameter sweep
% Open vdynblksskidpad_final.slx in this folder, then run this script.
% The model is the lap-time solver. No bicycle-model approximation is used.
% This script does not clear the workspace or change saved model parameters.
tuningFolder = fileparts(mfilename('fullpath'));
addpath(tuningFolder);
setup_skidpad();

%% Select one parameter and its range
parameter_name = "body.m"; % See parameter_catalog.csv or catalog below
parameter_min = 300;
parameter_max = 350;
parameter_step = 10;
parameter_values = parameter_min:parameter_step:parameter_max;

% Examples (use one at a time):
% parameter_name="body.m"; parameter_values=[310 330 350];
% parameter_name="suspension.Kz"; parameter_values=[30000 35000 40000];
% parameter_name="body.Cl"; parameter_values=[3.8 4.3 4.8];
% parameter_name="steering.PctAck"; parameter_values=[80 90 100];
% parameter_name="tire.PDY1"; parameter_values=[2.0 2.15 2.29899];
% parameter_name="road.friction"; parameter_values=[0.9 1 1.1]; % Mode="scale"
% parameter_name="body.Iveh"; parameter_values=[120 140 160]; % Index=[3 3]

%% Options
options = struct;
options.Mode = "absolute"; % "absolute" or "scale" (multiply the baseline)
options.Index = [];         % []=whole scalar/array; [3 3]=matrix element
options.ScoreLaps = [2 4];  % Mean of these actual lap times; all four are saved
options.StopTime = 90;      % Simulated seconds; unfinished course is invalid
options.TimeOut = 300;      % Wall-clock seconds per individual simulation
options.AutoTrim = true;   % Stationary settling for equilibrium-sensitive knobs
options.TrimTime = 5;
options.AllowUnverified = false; % Opt in to hidden/alternate-mode parameters
options.SaveRuns = true;    % Saves all logged output signals for every point
options.MakePlots = true;
options.OutputFolder = fullfile(tuningFolder,"results", ...
    string(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));

%% Run and inspect
sweepArguments = namedargs2cell(options);
[results,best,catalog] = run_skidpad_sweep(parameter_name,parameter_values,sweepArguments{:});
disp(results);
disp(best); % Empty if no point completed the course and passed validation.
