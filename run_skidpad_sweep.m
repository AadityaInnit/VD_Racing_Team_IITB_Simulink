function [results,best,catalog] = run_skidpad_sweep(parameterKey,values,options)
%RUN_SKIDPAD_SWEEP Use the corrected transient Simulink model as lap solver.
% Each point starts from the SAME open-model baseline. Overrides are temporary.
% Mode="scale" preserves array shape. Index=[row column] changes one element.
% Failed/incomplete/unsettled points have NaN Score_s and cannot win.
arguments
    parameterKey (1,1) string
    values (1,:) double {mustBeFinite,mustBeReal,mustBeNonempty}
    options.Mode (1,1) string {mustBeMember(options.Mode,["absolute","scale"])} = "absolute"
    options.Index (1,:) double = []
    options.ScoreLaps (1,:) double = [2 4]
    options.StopTime (1,1) double {mustBePositive} = 90
    options.TimeOut (1,1) double {mustBePositive} = 300
    options.AutoTrim (1,1) logical = true
    options.TrimTime (1,1) double {mustBePositive} = 5
    options.AllowUnverified (1,1) logical = false
    options.SaveRuns (1,1) logical = true
    options.MakePlots (1,1) logical = true
    options.OutputFolder (1,1) string = ""
end
model="vdynblksskidpad_final";
assert(bdIsLoaded(model),'Open the corrected tuning/vdynblksskidpad_final.slx first.');
assert(strcmp(get_param(model,'SimulationStatus'),'stopped'),'Stop the current simulation first.');
assert(strcmp(get_param(model,'Dirty'),'off'),'Save your intended model baseline before sweeping.');
assert(all(ismember(options.ScoreLaps,1:4)) && ~isempty(options.ScoreLaps) && ...
    numel(unique(options.ScoreLaps))==numel(options.ScoreLaps),'ScoreLaps must contain unique indices from 1:4.');
catalog=skidpad_parameter_catalog(model);
selected=catalog(catalog.Key==parameterKey,:);
assert(height(selected)==1,'Unknown parameter key: %s. Inspect skidpad_parameter_catalog.',parameterKey);
assert(selected.Status=="Candidate" || options.AllowUnverified, ...
    'This parameter is disabled or mode-dependent. Inspect catalog Notes before allowing it.');
base=selected.Baseline{1};
% Validate shape/index before creating any results or launching a simulation.
for k=1:numel(values), makeValue(base,values(k),options.Mode,options.Index); end
launchPath=Simulink.ID.getFullName(model+":370");
launchStart=get_param(launchPath,'start');
numericLaunchStart=str2double(launchStart);
assert(~isfinite(numericLaunchStart) || numericLaunchStart<options.StopTime, ...
    'The saved launch start (%s s) is beyond StopTime (%g s). Restore the course launch (normally 2 s) before sweeping.', ...
    launchStart,options.StopTime);
if options.OutputFolder==""
    options.OutputFolder=fullfile(fileparts(mfilename('fullpath')),'results', ...
        string(datetime('now','Format','yyyyMMdd_HHmmss_SSS')));
end
assert(~isfolder(options.OutputFolder),'OutputFolder already exists; choose a new folder to preserve prior runs.');
mkdir(options.OutputFolder);
modelFile=string(get_param(model,'FileName'));
mkdir(fullfile(options.OutputFolder,'baseline'));
copyfile(modelFile,fullfile(options.OutputFolder,'baseline','vdynblksskidpad_final.slx'));
configuration=struct('Parameter',parameterKey,'Values',values,'Options',options, ...
    'ModelFile',modelFile,'MATLABVersion',version,'Products',ver,'Timestamp',datetime('now'));
save(fullfile(options.OutputFolder,'configuration.mat'),'configuration','catalog');
exportCatalog=catalog; exportCatalog.Baseline=cellfun(@(x)string(jsonencode(x)),catalog.Baseline);
writetable(exportCatalog,fullfile(options.OutputFolder,'parameter_catalog.csv'));
results=table(values(:),'VariableNames',{'Value'});
results.Parameter=repmat(parameterKey,numel(values),1);
results.Status=repmat("Pending",numel(values),1);
for n=["Score_s","Lap1_s","Lap2_s","Lap3_s","Lap4_s","EndTime_s", ...
        "MinStartupSpeed_mps","StartupReverseDistance_m","MinWheelLoad_N", ...
        "MaxWheelLoad_N","MaxAbsSlipRatio","WallTime_s"]
    results.(n)=nan(numel(values),1);
end
results.Trimmed=false(numel(values),1);
results.Override=repmat("",numel(values),1);
results.Message=repmat("",numel(values),1);
path=Simulink.ID.getFullName(model+":"+selected.SID);
batchTimer=tic;
for k=1:numel(values)
    timer=tic;
    fprintf('[%d/%d] %s = %.8g (%s)\n',k,numel(values),parameterKey,values(k),options.Mode);
    override=makeValue(base,values(k),options.Mode,options.Index);
    results.Override(k)=numericExpression(override);
    trim=[];
    in=makeInput(values(k));
    if selected.Retrim && options.AutoTrim
        fprintf('  Checking stationary initialization...\n');
        [in,trim,trimOK,trimMessage]=skidpad_settle_start(in,model,options);
        if ~trimOK
            results.Status(k)="TrimFailed"; results.Message(k)=trimMessage;
            fprintf(2,'  Initialization rejected: %s\n',trimMessage);
            results.WallTime_s(k)=toc(timer);checkpoint;continue
        end
        results.Trimmed(k)=true;
    elseif selected.Retrim
        results.Message(k)="Startup trim reused: equilibrium may be invalid for this parameter.";
    end
    fprintf('  Running the four-lap course (wall timeout %.0f s)...\n',options.TimeOut);
    try
        out=sim(in);
    catch exception
        if contains(exception.identifier,'Interrupt','IgnoreCase',true) || ...
                contains(exception.message,'Operation terminated','IgnoreCase',true)
            rethrow(exception);
        end
        results.Status(k)="SimulationFailed";
        results.Message(k)=string(getReport(exception,'extended','hyperlinks','off'));
        fprintf(2,'  Simulation failed: %s\n',results.Message(k));
        results.WallTime_s(k)=toc(timer);checkpoint;continue
    end
    results.WallTime_s(k)=toc(timer);
    % Access a successful SimulationOutput directly (outside simulation catch).
    metrics=skidpad_run_metrics(out,options.ScoreLaps);
    results.Status(k)=metrics.Status;
    for n=["Score_s","Lap1_s","Lap2_s","Lap3_s","Lap4_s","EndTime_s", ...
            "MinStartupSpeed_mps","StartupReverseDistance_m","MinWheelLoad_N", ...
            "MaxWheelLoad_N","MaxAbsSlipRatio"]
        results.(n)(k)=metrics.(n);
    end
    results.Message(k)=strtrim(results.Message(k)+" "+metrics.Message);
    if options.SaveRuns
        save(fullfile(options.OutputFolder,sprintf('run_%03d.mat',k)),'out','in','trim','metrics','override','-v7.3');
    end
    if options.MakePlots
        plotRun(out,fullfile(options.OutputFolder,sprintf('run_%03d.png',k)),parameterKey,values(k));
    end
    checkpoint;
    fprintf('  %s; score %.5g s; laps %s\n',results.Status(k),results.Score_s(k), ...
        mat2str([metrics.Lap1_s metrics.Lap2_s metrics.Lap3_s metrics.Lap4_s],5));
end
valid=find(results.Status=="Completed" & isfinite(results.Score_s));
best=results([],:);
if ~isempty(valid), [~,idx]=min(results.Score_s(valid)); best=results(valid(idx),:); end
configuration.TotalWallTime_s=toc(batchTimer);
save(fullfile(options.OutputFolder,'sweep_results.mat'),'results','best','configuration','catalog');
if options.MakePlots
    fig=figure('Name','Simulink skidpad sweep','Visible','off');
    layout=tiledlayout(fig,2,1); ax=nexttile(layout);
    plot(ax,results.Value,results.Score_s,'o-','LineWidth',1.5);grid(ax,'on');
    xlabel(ax,parameterKey+" ("+options.Mode+")",'Interpreter','none');ylabel(ax,'Selected-lap mean (s)');
    title(ax,"Score laps: "+strjoin(string(options.ScoreLaps),", "));
    ax=nexttile(layout);plot(ax,results.Value,results{:,{'Lap1_s','Lap2_s','Lap3_s','Lap4_s'}},'o-');
    xlabel(ax,parameterKey,'Interpreter','none');ylabel(ax,'Recorded lap time (s)');grid(ax,'on');
    legend(ax,{'Lap 1','Lap 2','Lap 3','Lap 4'},'Location','best');
    exportgraphics(fig,fullfile(options.OutputFolder,'sweep_plot.png'),'Resolution',160);close(fig);
end
fprintf('Results: %s\n',options.OutputFolder);
    function in=makeInput(x)
        overrideValue=makeValue(base,x,options.Mode,options.Index);
        in=skidpad_simulation_input(model);
        in=in.setModelParameter('StopTime',num2str(options.StopTime,17), ...
            'TimeOut',options.TimeOut,'SimulationMode','normal','ReturnWorkspaceOutputs','on');
        % Pin the course launch before settling temporarily postpones it.
        in=in.setBlockParameter(launchPath,'start',launchStart);
        in=in.setBlockParameter(path,char(selected.Parameter),char(numericExpression(overrideValue)));
        in=in.setBlockParameter(Simulink.ID.getFullName(model+":387"),'Commented','on');
        for sid=[2903 2904 2905]
            in=in.setBlockParameter(Simulink.ID.getFullName(model+":"+sid),'SampleTime','0.01');
        end
    end
    function checkpoint
        writetable(results,fullfile(options.OutputFolder,'sweep_results.csv'));
        save(fullfile(options.OutputFolder,'checkpoint.mat'),'results','configuration');
    end
end

function value=makeValue(base,x,mode,index)
value=base;
if isempty(index)
    if mode=="scale", value=base*x;
    else
        assert(isscalar(base),'Array parameter: use Mode="scale" or specify Index=[row column].');
        value=x;
    end
else
    assert(ismatrix(base) && numel(index)==2 && all(index>=1 & index==fix(index)) && ...
        index(1)<=size(base,1) && index(2)<=size(base,2),'Index must be an in-range [row column].');
    if mode=="scale", value(index(1),index(2))=base(index(1),index(2))*x;
    else, value(index(1),index(2))=x; end
end
assert(all(isfinite(value(:))),'Override contains nonfinite values.');
end


function plotRun(out,file,key,value)
fig=figure('Name','Sweep run diagnostics','Visible','off');layout=tiledlayout(fig,3,2);
plotTS(nexttile(layout),out.diagBody.BdyFrm.Cg.Vel.xdot,'Body longitudinal speed (m/s)');
plotTS(nexttile(layout),out.diagWheel.GndFz,'Four tyre normal loads (N)');
plotTS(nexttile(layout),out.diagBody.InertFrm.Cg.Disp.Z,'Body Z (m, model frame)');
plotTS(nexttile(layout),out.diagBody.InertFrm.Cg.Ang.theta,'Pitch (rad)');
plotTS(nexttile(layout),out.diagWheel.Kappa,'Four tyre slip ratios');
plotTS(nexttile(layout),out.diagLapTimes,'Live lap timers (s)');
title(layout,sprintf('%s = %.6g',key,value),'Interpreter','none');
exportgraphics(fig,file,'Resolution',150);close(fig);
end
function plotTS(ax,ts,label)
plot(ax,ts.Time,tsMatrix(ts));grid(ax,'on');xlabel(ax,'Time (s)');ylabel(ax,label);
end
function data=tsMatrix(ts)
data=ts.Data;if ~ts.IsTimeFirst,data=permute(data,[ndims(data),1:ndims(data)-1]);end
data=reshape(data,numel(ts.Time),[]);
end

function expression=numericExpression(value)
if ismatrix(value),expression=string(mat2str(value,17));
else,expression="reshape("+string(mat2str(value(:),17))+","+string(mat2str(size(value)))+")";end
end
