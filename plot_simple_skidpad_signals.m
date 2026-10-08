function plot_simple_skidpad_signals(result,destination)
% Focused tuning report: body dynamics, commands, and four-wheel diagnostics.
entries=skidpad_signal_entries(result);
panels=struct('Title',{},'Unit',{},'Time',{},'Data',{},'Legends',{},'Source',{});
wheels=["Front left","Front right","Rear left","Rear right"];
body={
'diagBody.BdyFrm.Cg.AngVel.r','Yaw rate (vehicle axis)',180/pi,'deg/s';
'diagBody.InertFrm.Cg.Ang.phi','Roll angle',180/pi,'deg';
'diagBody.BdyFrm.Cg.AngVel.p','Roll rate (vehicle axis)',180/pi,'deg/s';
'diagBody.InertFrm.Cg.Ang.theta','Pitch angle',180/pi,'deg';
'diagBody.BdyFrm.Cg.AngVel.q','Pitch rate (vehicle axis)',180/pi,'deg/s';
'diagBody.InertFrm.Cg.Ang.psi','Yaw / heading angle',180/pi,'deg';
'diagBody.BdyFrm.Cg.Vel.xdot','Longitudinal velocity',1,'m/s';
'diagBody.BdyFrm.Cg.Acc.ax','Longitudinal acceleration',9.80665,'m/s^2';
'diagBody.BdyFrm.Cg.Vel.ydot','Lateral velocity',1,'m/s';
'diagBody.BdyFrm.Cg.Acc.ay','Lateral acceleration',9.80665,'m/s^2';
'diagBody.BdyFrm.Cg.Vel.zdot','Vertical velocity (vehicle axis)',1,'m/s';
'diagBody.BdyFrm.Cg.Acc.az','Vertical acceleration (vehicle axis)',9.80665,'m/s^2';
'diagBody.BdyFrm.Cg.Ang.Beta','Vehicle sideslip angle',180/pi,'deg';
'diagBody.InertFrm.Cg.Disp.Z','Vehicle center-of-mass vertical position (track axis)',1,'m';
'diagLapTimes','Recorded lap timers',1,'s';
'logsout.Acc','Accelerator command',1,'Fraction of full command';
'logsout.Decel','Brake command',1,'Fraction of full command';
'logsout.unnamed_4','Steering command (normalized)',1,'Normalized command';
'logsout.TotalBattCurr','Total battery current',1,'A';
'logsout.MtrPwrkW','Mechanical motor power',1,'kW';
'logsout.MtrTrq','Delivered motor torque',1,'N*m';
'logsout.GearCmd','Requested gear',1,'Gear number'};
missing=strings(0,1);
for k=1:size(body,1)
    index=find(string({entries.Name})==string(body{k,1}),1);
    if isempty(index),missing(end+1)=string(body{k,1});continue;end %#ok<AGROW>
    e=entries(index);data=e.Data*body{k,3};legends=compose("Component %d",1:size(data,2));
    if e.Name=="diagLapTimes",legends=["Lap 1","Lap 2","Lap 3","Lap 4"];
    elseif size(data,2)==4,legends=compose("Motor %d",1:4);end
    panels(end+1)=make(string(body{k,2}),string(body{k,4}),e.Time,data,legends,e.Name); %#ok<AGROW>
end
wheelGroups={
'diagWheel.Kappa','Wheel slip ratio',1,'Dimensionless';
'diagWheel.Omega','Wheel angular velocity',1,'rad/s';
'diagWheel.Fx','Tire longitudinal force (tire axes)',1,'N';
'diagWheel.Fy','Tire lateral force (tire axes)',1,'N';
'diagWheel.Fz','Tire vertical force at axle (tire axes)',1,'N';
'diagWheel.GndFz','Tire load on the road',1,'N';
'diagWheel.AxlTrq','Torque applied to wheel axle',1,'N*m';
'diagWheel.WhlTrq','Tire contact torque about rolling axis',1,'N*m';
'diagWheel.BrkTrq','Wheel brake torque',1,'N*m';
'diagWheel.Mz','Tire aligning moment (not steering-rack feedback)',1,'N*m';
'diagSusp.Height','Suspension deflection (recorded relative height)',1000,'mm';
'diagWheel.RadialDeflct','Tire radial compression',1000,'mm';
'diagWheel.Alpha','Tire slip angle',180/pi,'deg';
'diagSusp.Toe','Suspension toe / steering angle',180/pi,'deg';
'diagWheel.Gamma','Camber angle supplied to tire',180/pi,'deg';
'diagWheel.Vx','Wheel longitudinal velocity (tire axes)',1,'m/s';
'diagWheel.Vy','Wheel lateral velocity (tire axes)',1,'m/s';
'diagWheel.zdot','Wheel vertical velocity (tire frame)',1,'m/s';
'diagWheel.Re','Effective tire rolling radius',1000,'mm';
'diagWheel.BrkPrs','Wheel brake pressure',1e-5,'bar'};
% Each wheel metric gets one full page: comparison, four wheels, startup zoom.
while mod(numel(panels),6)~=0
    e=entries(find(string({entries.Name})=="diagBody.BdyFrm.Cg.Vel.xdot",1));
    index=e.Time<=3;
    panels(end+1)=make("Longitudinal velocity - first 3 seconds","m/s",e.Time(index),e.Data(index,:),"Vehicle",e.Name); %#ok<AGROW>
    if mod(numel(panels),6)~=0
        e=entries(find(string({entries.Name})=="diagBody.BdyFrm.Cg.Acc.ay",1));
        panels(end+1)=make("Lateral acceleration in g","g",e.Time,e.Data,"Vehicle",e.Name); %#ok<AGROW>
    end
end
for k=1:size(wheelGroups,1)
    index=find(string({entries.Name})==string(wheelGroups{k,1}),1);
    if isempty(index),missing(end+1)=string(wheelGroups{k,1});continue;end %#ok<AGROW>
    e=entries(index);data=e.Data*wheelGroups{k,3};
    assert(size(data,2)==4,'Expected four wheels for %s',e.Name);
    name=string(wheelGroups{k,2});unit=string(wheelGroups{k,4});
    panels(end+1)=make(name+" - all four wheels",unit,e.Time,data,wheels,e.Name); %#ok<AGROW>
    for w=1:4
        panels(end+1)=make(name+" - "+lower(wheels(w)),unit,e.Time,data(:,w),wheels(w),e.Name); %#ok<AGROW>
    end
    early=e.Time<=3;
    panels(end+1)=make(name+" - first 3 seconds",unit,e.Time(early),data(early,:),wheels,e.Name); %#ok<AGROW>
end
recordedEnd=max(arrayfun(@(entry)max(entry.Time),entries));
notes=["Source: supplied saved simulation output; recorded end time "+compose("%.3f",recordedEnd)+" s.", ...
    "Angles use degrees; body angular rates use deg/s; wheel angular velocity uses rad/s.", ...
    "Body accelerations use recorded inertial acceleration in vehicle axes: g converted with 9.80665 m/s^2 per g.", ...
    "Vehicle axes rotate with the body (Z-down); tire-frame and suspension-frame signs are retained.", ...
    "Suspension deflection is the block's recorded relative height, not a measured coil-spring displacement.", ...
    "Each wheel metric has a comparison, four individual wheel plots, and a first-3-second startup view.", ...
    "Steering-rack / handwheel torque feedback is NOT recorded. Tire aligning moment is shown separately and is not equivalent.", ...
    "Roll/pitch/yaw rates are body-axis angular velocities, not numerical derivatives of Euler angles.", ...
    "Motor curves are labeled Motor 1-4; their wheel assignment has not been inferred. CSV index retains source names."];
if ~isempty(missing),notes(end+1)="Unavailable signals: "+strjoin(missing,', ');end
skidpad_export_panels(panels,destination,"Simple signal plots for tuning",notes);
end
function p=make(title,unit,time,data,legends,source)
p=struct('Title',title,'Unit',unit,'Time',time,'Data',data,'Legends',legends,'Source',source);
end
