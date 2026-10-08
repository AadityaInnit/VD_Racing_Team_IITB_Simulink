function metrics=skidpad_run_metrics(out,scoreLaps)
%SKIDPAD_RUN_METRICS Reject incomplete courses and nonfinite recorded signals.
metrics=struct('Status',"Incomplete",'Message',"Course did not finish.",'Score_s',NaN);
laps=matrix(out.diagLapTimes); final=laps(end,:);
assert(numel(final)==4,'Expected the corrected model''s four-channel diagLapTimes log.');
for j=1:4, metrics.(sprintf('Lap%d_s',j))=final(j); end
metrics.EndTime_s=out.tout(end);
v=matrix(out.diagBody.BdyFrm.Cg.Vel.xdot);t=out.diagBody.BdyFrm.Cg.Vel.xdot.Time;early=t<=3;
metrics.MinStartupSpeed_mps=min(v(early));
metrics.StartupReverseDistance_m=trapz(t(early),max(-v(early),0));
fz=matrix(out.diagWheel.GndFz);metrics.MinWheelLoad_N=min(fz,[],'all');metrics.MaxWheelLoad_N=max(fz,[],'all');
slip=matrix(out.diagWheel.Kappa);metrics.MaxAbsSlipRatio=max(abs(slip),[],'all');
finite=allFinite(out.diagBody)&&allFinite(out.diagWheel)&&allFinite(out.diagSusp)&& ...
    allFinite(out.logsout)&&allFinite(out.diagLapTimes);
if ~finite, metrics.Status="Nonfinite";metrics.Message="Nonfinite values in logged signals.";return;end
% The stock course stops after the exit straight at X=15 m. A positive live
% timer alone does NOT prove that the fourth lap was completed.
x=out.diagBody.InertFrm.Cg.Disp.X.Data(end);
tail=out.diagLapTimes.Time>=out.diagLapTimes.Time(end)-0.2;
lastTimerStopped=max(laps(tail,4))-min(laps(tail,4))<1e-8;
completed=strcmp(out.SimulationMetadata.ExecutionInfo.StopEvent,'ModelStop') && ...
    x>=14.9 && all(final>0) && lastTimerStopped;
if completed
    metrics.Status="Completed";metrics.Message="Course completed; finite logs. Physical validity still requires review.";
    metrics.Score_s=mean(final(scoreLaps));
end
end
function yes=allFinite(value)
yes=true;
if isa(value,'timeseries'),yes=all(isfinite(value.Data(:)));
elseif isa(value,'Simulink.SimulationData.Dataset')
    for j=1:value.numElements,yes=yes&&allFinite(value.getElement(j).Values);end
elseif isstruct(value)
    names=fieldnames(value);for j=1:numel(names),yes=yes&&allFinite(value.(names{j}));end
end
end
function data=matrix(ts)
data=ts.Data;if ~ts.IsTimeFirst,data=permute(data,[ndims(data),1:ndims(data)-1]);end
data=reshape(data,numel(ts.Time),[]);
end
