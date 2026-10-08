function model=setup_skidpad()
% Open this package's model and make its bundled tire data available.
folder=fileparts(mfilename('fullpath'));addpath(folder,fullfile(folder,'tires'));
model="vdynblksskidpad_final";
if ~bdIsLoaded(model),open_system(fullfile(folder,model+".slx"));end
assert(strcmp(get_param(model,'FileName'),fullfile(folder,model+".slx")), ...
    'Another model copy is open. Close it and run setup_skidpad again.');
cache=fullfile(tempdir,'Skidpad_Final_cache');
Simulink.fileGenControl('set','CacheFolder',cache,'CodeGenFolder',cache,'createDir',true);
catalog=skidpad_parameter_catalog(model);
catalog.Baseline=cellfun(@(x)string(jsonencode(x)),catalog.Baseline);
writetable(catalog,fullfile(folder,'parameter_catalog.csv'));
end
