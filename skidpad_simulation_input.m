function in=skidpad_simulation_input(model)
% Override the tire file with the package-local copy, independent of laptop paths.
folder=fileparts(mfilename('fullpath'));
in=Simulink.SimulationInput(model);
in=in.setBlockParameter(Simulink.ID.getFullName(model+":2390"), ...
    'tireParamSet',fullfile(folder,'tires','FSAE_16_inch_new_converted_to_MF62.tir'));
end
