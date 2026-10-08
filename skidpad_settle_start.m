function [in,trim,ok,message]=skidpad_settle_start(in,model,options)
% Re-estimate body height/pitch and common wheel compression at standstill.
% The current tyre interface only supports a scalar initial compression.
% Consequently reject cases where corner compression cannot be represented.
mw=get_param(model,'ModelWorkspace');trim=mw.getVariable('StartupTrim');
courseInput=in;ok=false;message="Stationary initialization did not converge.";
launchPath=Simulink.ID.getFullName(model+":370");
courseStart=get_param(launchPath,'start');
for j=1:numel(courseInput.BlockParameters)
    bp=courseInput.BlockParameters(j);
    if strcmp(char(bp.BlockPath),launchPath) && strcmp(bp.Name,'start')
        courseStart=bp.Value;
    end
end
courseInput=courseInput.setBlockParameter(launchPath,'start',courseStart);
for iteration=1:3
    in=courseInput.setVariable('StartupTrim',trim,'Workspace',char(model));
    in=in.setModelParameter('StopTime',num2str(options.TrimTime,17));
    in=in.setBlockParameter(launchPath,'start',num2str(options.TrimTime+100));
    try
        out=sim(in);
    catch exception
            if contains(exception.identifier,'Interrupt','IgnoreCase',true) || ...
                    contains(exception.message,'Operation terminated','IgnoreCase',true)
                rethrow(exception);
            end
        message=string(getReport(exception,'extended','hyperlinks','off'));
        fprintf(2,'Stationary initialization failed: %s\n',message);
        in=courseInput;return
    end
    z=tsMatrix(out.diagWheel.z);vz=tsMatrix(out.diagWheel.zdot);
    bodyVz=tsMatrix(out.diagBody.BdyFrm.Cg.Vel.zdot);
    q=tsMatrix(out.diagBody.BdyFrm.Cg.AngVel.q);
    speed=tsMatrix(out.diagBody.BdyFrm.Cg.Vel.xdot);
    loads=tsMatrix(out.diagWheel.GndFz);
    tail=out.diagWheel.z.Time>=options.TrimTime-0.5;
    if ~any(tail) || any(~isfinite([z(:);vz(:);bodyVz(:);q(:);loads(:)]))
        message="Settling run ended early or produced nonfinite states.";break
    end
    % Validate this initialization, not only the eventual settled endpoint.
    early=out.diagWheel.z.Time<=0.5;
    spread=max(z(end,:))-min(z(end,:));
    stable=max(abs(vz(tail,:)),[],'all')<0.015 && abs(bodyVz(end))<0.015 && abs(q(end))<0.015;
    quietStart=max(abs(vz(early,:)),[],'all')<0.08;
    if stable && quietStart && spread<0.003 && min(loads(tail,:),[],'all')>0 && max(abs(speed))<0.1
        ok=true;message="Stationary trim verified.";break
    end
    trim.BodyZ=out.diagBody.InertFrm.Cg.Disp.Z.Data(end);
    trim.Pitch=out.diagBody.InertFrm.Cg.Ang.theta.Data(end);
    trim.TireCompression=-mean(z(end,:));
    radius=tsMatrix(out.diagWheel.Re);trim.WheelRadius=radius(end,:);
    message=sprintf('Trim not representable/converged: wheel spread %.4g m, final vertical speed %.4g m/s.',spread,bodyVz(end));
end
in=courseInput.setVariable('StartupTrim',trim,'Workspace',char(model));
end

function data=tsMatrix(ts)
data=ts.Data;if ~ts.IsTimeFirst,data=permute(data,[ndims(data),1:ndims(data)-1]);end
data=reshape(data,numel(ts.Time),[]);
end
