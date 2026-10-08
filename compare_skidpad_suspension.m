function summary=compare_skidpad_suspension(reuseSaved)
% Four one-parameter experiments; saved model and its initial trim stay fixed.
if nargin<1,reuseSaved=false;end
tuning=fileparts(mfilename('fullpath'));addpath(tuning);
root=tuning;
destination=fullfile(root,'results','suspension_comparison');
if ~isfolder(destination),mkdir(destination);end
model=setup_skidpad();
if ~bdIsLoaded(model),open_system(fullfile(tuning,model+".slx"));end
assert(strcmp(get_param(model,'FileName'),fullfile(tuning,model+".slx")), ...
    'Open the tuning model, not another copy.');
block=Simulink.ID.getFullName(model+":2735");
k0=str2double(get_param(block,'Kz'));c0=str2double(get_param(block,'Cz'));
assert(isfinite(k0)&&isfinite(c0),'Expected scalar numeric Kz and Cz.');
names=["Baseline","Low stiffness","High stiffness","Low damping","High damping"];
stiffness=k0*[1;.1;10;1;1];damping=c0*[1;1;1;.1;10];
if reuseSaved
    load(fullfile(destination,'suspension_comparison.mat'), ...
        'outputs','metrics','names','stiffness','damping','k0','c0');
else
outputs=cell(5,1);errors=strings(5,1);metrics=cell(5,1);
for j=1:5
    fprintf('Case %d/5: %s; Kz %.0f N/m, Cz %.0f N*s/m\n',j,names(j),stiffness(j),damping(j));
    in=skidpad_simulation_input(model);
    in=in.setModelParameter('StopTime','60','SimulationMode','normal');
    if j==2 || j==3
        in=in.setBlockParameter(block,'Kz',num2str(stiffness(j),17));
    elseif j==4 || j==5
        in=in.setBlockParameter(block,'Cz',num2str(damping(j),17));
    end
    try
        out=sim(in);
        outputs{j}=out;metrics{j}=skidpad_run_metrics(out,[2 4]);
        disp(metrics{j});
    catch exception
        if contains(exception.identifier,'Interrupt'),rethrow(exception);end
        errors(j)=string(getReport(exception,'extended','hyperlinks','off'));
        fprintf(2,'%s failed: %s\n',names(j),exception.message);
    end
    save(fullfile(destination,'suspension_comparison.mat'), ...
        'outputs','metrics','errors','names','stiffness','damping','k0','c0','-v7.3');
end
end
assert(strcmp(get_param(block,'Kz'),num2str(k0))&&strcmp(get_param(block,'Cz'),num2str(c0)), ...
    'Simulation overrides must not persist in the model.');
Status=repmat("Simulation failed",5,1);EndTime_s=nan(5,1);Score_s=nan(5,1);
PeakRoll_deg=nan(5,1);PeakPitch_deg=nan(5,1);MaxSuspensionTravel_mm=nan(5,1);
MinWheelLoad_N=nan(5,1);MaxWheelLoad_N=nan(5,1);ReverseDistance_m=nan(5,1);
LapTimes_s=nan(5,4);
entries=cell(5,1);
for j=1:5
    if isempty(outputs{j}),continue;end
    m=metrics{j};Status(j)=m.Status;EndTime_s(j)=m.EndTime_s;Score_s(j)=m.Score_s;
    MinWheelLoad_N(j)=m.MinWheelLoad_N;MaxWheelLoad_N(j)=m.MaxWheelLoad_N;
    ReverseDistance_m(j)=m.StartupReverseDistance_m;
    entries{j}=skidpad_signal_entries(outputs{j});
    PeakRoll_deg(j)=max(abs(outputs{j}.diagBody.InertFrm.Cg.Ang.phi.Data),[],'all')*180/pi;
    PeakPitch_deg(j)=max(abs(outputs{j}.diagBody.InertFrm.Cg.Ang.theta.Data),[],'all')*180/pi;
    MaxSuspensionTravel_mm(j)=max(abs(outputs{j}.diagSusp.Height.Data),[],'all')*1000;
    if Status(j)=="Completed"
        LapTimes_s(j,:)=[m.Lap1_s,m.Lap2_s,m.Lap3_s,m.Lap4_s];
    end
end
Case=names';Stiffness_N_per_m=stiffness;Damping_Ns_per_m=damping;
summary=table(Case,Stiffness_N_per_m,Damping_Ns_per_m,Status,EndTime_s,Score_s, ...
    LapTimes_s,PeakRoll_deg,PeakPitch_deg,MaxSuspensionTravel_mm,MinWheelLoad_N,MaxWheelLoad_N,ReverseDistance_m);
writetable(summary,fullfile(destination,'suspension_comparison_summary.csv'));
disp(summary);
exportComparison(entries,names,stiffness,damping,summary,fullfile(destination,'suspension_comparison.pdf'));
end

function exportComparison(entries,names,stiffness,damping,summary,destination)
spec={
 'diagBody.InertFrm.Cg.Ang.phi','Roll angle',180/pi,'deg';
 'diagBody.InertFrm.Cg.Ang.theta','Pitch angle',180/pi,'deg';
 'diagBody.BdyFrm.Cg.AngVel.p','Roll rate',180/pi,'deg/s';
 'diagBody.BdyFrm.Cg.AngVel.q','Pitch rate',180/pi,'deg/s';
 'diagBody.BdyFrm.Cg.AngVel.r','Yaw rate',180/pi,'deg/s';
 'diagBody.BdyFrm.Cg.Vel.xdot','Longitudinal velocity',1,'m/s';
 'diagBody.BdyFrm.Cg.Vel.zdot','Vertical velocity',1,'m/s';
 'diagBody.BdyFrm.Cg.Acc.ax','Longitudinal acceleration',9.80665,'m/s^2';
 'diagBody.BdyFrm.Cg.Acc.ay','Lateral acceleration',9.80665,'m/s^2';
 'diagBody.BdyFrm.Cg.Acc.az','Vertical acceleration',9.80665,'m/s^2';
 'diagBody.BdyFrm.Cg.Ang.Beta','Sideslip angle',180/pi,'deg';
 'diagBody.InertFrm.Cg.Disp.Z','Body vertical position (track Z-down)',1,'m';
 'logsout.unnamed_4','Steering command',1,'normalized';
 'diagSusp.Height','Suspension relative height / travel',1000,'mm';
 'diagWheel.GndFz','Tire contact load',1,'N';
 'diagWheel.Kappa','Wheel slip ratio',1,'dimensionless';
 'diagWheel.Fy','Tire lateral force',1,'N';
 'diagWheel.Fx','Tire longitudinal force',1,'N';
 'diagWheel.Omega','Wheel angular velocity',1,'rad/s';
 'diagWheel.AxlTrq','Wheel drive torque',1,'N*m'};
wheels=["Front left","Front right","Rear left","Rear right"];
panels=struct('Signal',{},'Title',{},'Scale',{},'Unit',{},'Channel',{},'Startup',{},'CompletedOnly',{});
for s=1:size(spec,1)
    count=1;if s>=14,count=4;end
    for w=1:count
        titleText=string(spec{s,2});if count==4,titleText=titleText+" - "+lower(wheels(w));end
        panels(end+1)=struct('Signal',string(spec{s,1}),'Title',titleText, ...
            'Scale',spec{s,3},'Unit',string(spec{s,4}),'Channel',w,'Startup',false,'CompletedOnly',false); %#ok<AGROW>
    end
end
% Also show launch settling without compressing it into the full-course view.
for index=[1 2 6 7 10 14:21]
    if index>numel(panels),continue;end
    p=panels(index);p.Startup=true;p.Title=p.Title+" - first 3 seconds";
    panels(end+1)=p; %#ok<AGROW>
end
% Keep subtle differences visible when an unstable case overwhelms the scale.
for index=[1:12 14:21]
    p=panels(index);p.CompletedOnly=true;p.Title=p.Title+" - completed cases only";
    panels(end+1)=p; %#ok<AGROW>
end
tempPdf=[tempname '.pdf'];
f=figure('Visible','off','Color','white','Position',[30 30 1400 1000]);
ax=axes(f,'Position',[.07 .06 .86 .88]);axis(ax,'off');
text(ax,0,1,'Suspension stiffness and damping comparison','Units','normalized', ...
    'FontSize',22,'FontWeight','bold','VerticalAlignment','top','Interpreter','none','Color','black');
lines=["Each experiment changes just one constant; all other model settings and initial conditions are held fixed.", ...
    "Fixed motor-to-wheel reduction: 11.5:1. Baseline is rerun with the four experiments.", ...
    "No retrimming: startup differences include settling from the same initial state and unchanged preload.", ...
    "Suspension travel is recorded relative height; body Z is positive downward. Body acceleration uses 9.80665 m/s^2 per g.", ...
    "Curves stop at each run's recorded end. Failure / incomplete runs do not receive valid lap times.", ...
    "Comparisons use simulation time: different lap pace can shift cornering events between curves."];
lines(end+1)="Extra completed-case views omit the unstable case so smaller differences remain visible.";
for j=1:5
    lines(end+1)=names(j)+": K = "+stiffness(j)+" N/m; C = "+damping(j)+ ...
        " N*s/m; "+summary.Status(j)+"; end time "+compose("%.3f",summary.EndTime_s(j))+" s."; %#ok<AGROW>
end
text(ax,0,.9,strjoin(lines,sprintf('\n\n')),'Units','normalized','FontSize',12, ...
    'VerticalAlignment','top','Interpreter','none','Color','black');
exportgraphics(f,tempPdf,'Resolution',150);close(f);
palette=[0 0 0;0 .4 .8;.85 .3 .05;0 .55 .3;.6 .15 .65];
for first=1:6:numel(panels)
    f=figure('Visible','off','Color','white','Position',[30 30 1400 1000]);
    layout=tiledlayout(f,3,2,'TileSpacing','compact','Padding','compact');
    for index=first:min(first+5,numel(panels))
        p=panels(index);ax=nexttile(layout);hold(ax,'on');
        for j=1:5
            if p.CompletedOnly && summary.Status(j)~="Completed",continue;end
            e=entries{j};if isempty(e),continue;end
            hit=find(string({e.Name})==p.Signal,1);if isempty(hit),continue;end
            d=e(hit);if size(d.Data,2)<p.Channel,continue;end
            t=d.Time;y=d.Data(:,p.Channel)*p.Scale;
            if p.Startup,keep=t<=3;t=t(keep);y=y(keep);end
            plot(ax,t,y,'Color',palette(j,:),'LineWidth',1,'DisplayName',names(j));
        end
        title(ax,p.Title,'Interpreter','none','FontSize',10,'Color','black');
        xlabel(ax,'Time (s)','Color','black');ylabel(ax,p.Unit,'Interpreter','none','Color','black');grid(ax,'on');
        set(ax,'Color','white','XColor','black','YColor','black','FontSize',9);
        legend(ax,'Location','best','FontSize',7,'TextColor','black','Color','white');
    end
    title(layout,"Suspension comparison - page "+ceil(first/6),'Color','black');
    exportgraphics(f,tempPdf,'Resolution',150,'Append',true);
    if first==1 || first==13 || first==55
        exportgraphics(f,fullfile(tempdir,"suspension_comparison_page_"+ceil(first/6)+".png"),'Resolution',100);
    end
    close(f);
end
f=figure('Visible','off','Color','white','Position',[30 30 1400 1000]);
ax=axes(f);bar(ax,summary.LapTimes_s');xlabel(ax,'Lap number','Color','black');ylabel(ax,'Lap time (s)','Color','black');
set(ax,'Color','white','XColor','black','YColor','black');
title(ax,'Completed-course lap times (incomplete cases omitted)','Color','black');grid(ax,'on');
legend(ax,names,'Location','best','TextColor','black','Color','white');exportgraphics(f,tempPdf,'Resolution',150,'Append',true);close(f);
movefile(tempPdf,destination,'f');
fprintf('Comparison PDF: %s\n',destination);
end
