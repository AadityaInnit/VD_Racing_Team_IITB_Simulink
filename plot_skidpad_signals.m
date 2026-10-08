function plot_skidpad_signals(result,destination)
% All recorded signals with readable titles, physical units and full legends.
entries=skidpad_signal_entries(result);
labels=readtable(fullfile(fileparts(mfilename('fullpath')),'skidpad_signal_titles.csv'),'TextType','string');
panels=struct('Title',{},'Unit',{},'Time',{},'Data',{},'Legends',{},'Source',{});
wheels=["Front left","Front right","Rear left","Rear right"];
for k=1:numel(entries)
    e=entries(k);index=find(labels.Signal==e.Name,1);
    if isempty(index)
        titleText="Recorded "+replace(e.Name,[".","_"]," ");
    else
        titleText=labels.Title(index);
    end
    unit=e.Unit;if unit=="gn",unit="g";elseif ismember(unit,["1","one"]),unit="dimensionless";end
    if strlength(unit)==0,unit="Recorded value (unit unavailable)";end
    shape=e.Shape;n=size(e.Data,2);
    if numel(shape)>=2 && shape(1)==3 && ismember(shape(2),[3 4])
        components=["Track X component","Track Y component","Track Z component"];
        if endsWith(e.Name,'.WhlAng'),components=["Camber angle","Caster angle","Toe / steering angle"];end
        if shape(2)==3,components=["Matrix row 1","Matrix row 2","Matrix row 3"];end
        for c=1:3
            columns=c:3:n;legends=wheels;
            if shape(2)==3,legends=["Matrix column 1","Matrix column 2","Matrix column 3"];end
            panels(end+1)=make(titleText+" - "+components(c),unit,e,e.Data(:,columns),legends); %#ok<AGROW>
        end
    else
        legends=compose("Component %d",1:n);
        if n==4
            if e.Name=="diagLapTimes",legends=["Lap 1","Lap 2","Lap 3","Lap 4"];
            elseif startsWith(e.Name,["diagWheel.","diagSusp."]),legends=wheels;
            else
                legends=compose("Motor %d",1:4);
            end
        elseif e.Name=="logsout.Accxyz",legends=["Longitudinal","Lateral","Vertical"];
        end
        panels(end+1)=make(titleText,unit,e,e.Data,legends); %#ok<AGROW>
    end
end
notes=["Every recorded signal and every matrix component is retained.", ...
    "Wheel order: front left, front right, rear left, rear right. Multi-signal plots have explicit legends.", ...
    "Track coordinates are earth-fixed; vehicle coordinates rotate with the car; tire signals use their tire frame.", ...
    "Values and coordinate signs are unchanged. Angular units are preserved; acceleration in g is labeled explicitly.", ...
    "Zero body tire inputs are not zero tire forces: the current model routes active forces through suspension.", ...
    "The companion CSV index maps each readable title to the original recorded signal and PDF page."];
skidpad_export_panels(panels,destination,"All recorded signal plots",notes);
end
function p=make(title,unit,e,data,legends)
p=struct('Title',title,'Unit',unit,'Time',e.Time,'Data',data,'Legends',legends,'Source',e.Name);
end
