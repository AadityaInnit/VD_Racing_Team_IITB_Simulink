function catalog = skidpad_parameter_catalog(model)
%SKIDPAD_PARAMETER_CATALOG Numeric mask controls in the corrected skidpad model.
% Requires the corrected model to be open. Baselines are resolved from the
% current model, including its model workspace. Does not change parameters.
arguments
    model (1,1) string = "vdynblksskidpad_final"
end
assert(bdIsLoaded(model),'Open the corrected vdynblksskidpad_final.slx first.');
groups = {"body",2850;"suspension",2735;"tire",2390;"driver",11; ...
    "motor",2625;"steering",2714;"brakeValve",2379;"motorFilter",2647;"launch",370};
rows = cell(0,10);
exclude = ["aMode","NumAxl","NumWhlsByAxl","StrgEnByAxl", ...
    "AntiSwayEnByAxl","WhlNumVec","AxleNumVec","SuspTypesByAxle", ...
    "IdealSuspAxles","MappedSuspAxles","Xe_o","eul_o","xbdot_o","p_o", ...
    "zo","zdoto","omegao","omega_o","vecPose"];
for g = 1:size(groups,1)
    prefix=groups{g,1}; sid=groups{g,2};
    path=Simulink.ID.getFullName(model+":"+sid);
    names=get_param(path,'MaskNames'); expressions=get_param(path,'MaskValues');
    prompts=get_param(path,'MaskPrompts'); enabled=get_param(path,'MaskEnables');
    for j=1:numel(names)
        name=string(names{j});
        if ismember(name,exclude), continue; end
        try
            value=slResolve(expressions{j},path);
        catch
            continue % Non-numeric options and unresolved hidden mask defaults.
        end
        if ~isnumeric(value) || isempty(value) || ~isreal(value) || ...
                any(~isfinite(value(:))) || numel(value)>5000, continue; end
        status="Review mode"; note="Verify this parameter is used by the selected block mode.";
        if strcmp(enabled{j},'off'), status="Disabled"; end
        switch prefix
            case "body"
                active=ismember(name,["m","a","b","d","h","Iveh","w", ...
                    "Af","Cd","Cl","Cpm","beta_w","Cs","Cym","Pabs","Tair","g","xdot_tol"]);
            case "suspension"
                active=ismember(name,["Kz","F0z","Cz","Hmax","Toe","RollStrgSlp", ...
                    "ToeStrgSlp","Caster","CasterHslp","CasterStrgSlp", ...
                    "Camber","CamberHslp","CamberStrgSlp","StrgHgtSlp"]);
            case "tire"
                active=~startsWith(name,["drum_","brake_"]) && name~="f_brake_t";
            case "motor"
                active=ismember(name,["torque_max","power_max","Tc","eff","w_eff","T_eff","Piron","Pbase"]);
            case "steering"
                active=ismember(name,["TrckWdth","WhlBase","StrgRatio","PctAck","Db","StrgRng"]);
            case "driver"
                active=ismember(name,["tauerr","tau","L","Kpt","aR","bR","cR", ...
                    "PositionGainF","PositionGainR","YawRateGain","DelayGain","theta","Ksteer"]);
            otherwise
                active=true;
        end
        if active && status~="Disabled"
            status="Candidate"; note="Exposed in the current configuration; validate sensitivity and physical range.";
        end
        retrim=ismember(prefix,["body","suspension","tire"]);
        if prefix=="body" && ismember(name,["Af","Cd","Cl","Cpm","beta_w","Cs","Cym","Pabs","Tair"]), retrim=false; end
        if prefix=="suspension" && startsWith(name,"Camber")
            note="Suspension camber is not currently connected to the tyre Gamma input; use tireInput.camber for tyre camber sensitivity.";
        end
        rows(end+1,:)={prefix+"."+name,string(sid),name,string(prompts{j}), ...
            string(expressions{j}),value,mat2str(size(value)),status,retrim,note}; %#ok<AGROW>
    end
end
extra={"course.speedLimit",374,"UpperLimit","Reference speed ramp upper limit (km/h)"; ...
    "brakes.frontBias",2373,"Value","Front brake command multiplier"; ...
    "brakes.rearBias",2377,"Value","Rear brake command multiplier"; ...
    "brakes.pressureGain",2374,"Gain","Command to brake pressure gain"; ...
    "tireInput.pressure",2398,"const","Actual tyre inflation pressure (Pa)"; ...
    "tireInput.camber",2394,"const","Tyre camber input (rad)"; ...
    "road.friction",2340,"Value","Per-wheel road friction input"; ...
    "battery.voltage",2618,"Value","Per-motor supply voltage (V)"};
for j=1:size(extra,1)
    path=Simulink.ID.getFullName(model+":"+extra{j,2});
    expr=get_param(path,extra{j,3}); value=slResolve(expr,path);
    rows(end+1,:)={extra{j,1},string(extra{j,2}),extra{j,3},extra{j,4}, ...
        string(expr),value,mat2str(size(value)),"Candidate", ...
        startsWith(extra{j,1},"tireInput"),"Changes this input only; other parameters remain at baseline."}; %#ok<AGROW>
end
catalog=cell2table(rows,'VariableNames',{'Key','SID','Parameter','Description', ...
    'Expression','Baseline','Shape','Status','Retrim','Notes'});
for n=["Key","SID","Parameter","Description","Expression","Shape","Status","Notes"]
    catalog.(n)=string(catalog.(n));
end
catalog.Retrim=logical(catalog.Retrim);
catalog=sortrows(catalog,'Key');
end
