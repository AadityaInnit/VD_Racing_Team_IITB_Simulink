function entries=skidpad_signal_entries(result)
% Flatten recorded signals, preserving MATLAB column-major component order.
entries=struct('Name',{},'Time',{},'Data',{},'Shape',{},'Unit',{},'BlockPath',{});
names=result.who;
for k=1:numel(names)
    if ~strcmp(names{k},'tout'),entries=[entries;collect(result.(names{k}),names{k},'')];end %#ok<AGROW>
end
end
function entries=collect(value,prefix,block)
entries=struct('Name',{},'Time',{},'Data',{},'Shape',{},'Unit',{},'BlockPath',{});
if isa(value,'timeseries')
    data=value.Data;dims=size(data);
    if value.IsTimeFirst,shape=dims(2:end);
    else,shape=dims(1:end-1);data=permute(data,[ndims(data),1:ndims(data)-1]);end
    if isempty(shape),shape=1;end
    unit=value.DataInfo.Units;
    if isa(unit,'Simulink.SimulationData.Unit'),unit=unit.Name;end
    if isempty(unit),unit='';end
    entries=struct('Name',string(prefix),'Time',value.Time(:),'Data', ...
        reshape(data,numel(value.Time),[]),'Shape',shape,'Unit',string(unit),'BlockPath',string(block));
elseif isa(value,'Simulink.SimulationData.Dataset')
    for k=1:value.numElements
        item=value.getElement(k);label=item.Name;if isempty(label),label=sprintf('unnamed_%d',k);end
        itemBlock='';
        if isa(item,'Simulink.SimulationData.Signal') && item.BlockPath.getLength>0,itemBlock=item.BlockPath.getBlock(1);end
        entries=[entries;collect(item.Values,[prefix '.' label],itemBlock)]; %#ok<AGROW>
    end
elseif isstruct(value)
    names=fieldnames(value);
    for k=1:numel(names),entries=[entries;collect(value.(names{k}),[prefix '.' names{k}],block)];end %#ok<AGROW>
end
end
