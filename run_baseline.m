function [out,metrics]=run_baseline(makePlots)
% Run the final baseline; optionally replace its two reports in plots/.
if nargin<1,makePlots=false;end
model=setup_skidpad();in=skidpad_simulation_input(model);
in=in.setModelParameter('StopTime','60','SimulationMode','normal');
out=sim(in);metrics=skidpad_run_metrics(out,[2 4]);disp(metrics);
assert(metrics.Status=="Completed",'Baseline course did not complete.');
if makePlots
    folder=fileparts(mfilename('fullpath'));scratch=tempname;mkdir(scratch);
    cleanup=onCleanup(@()rmdir(scratch,'s'));
    plot_skidpad_signals(out,fullfile(scratch,'all_signal_plots_plain_language.pdf'));
    plot_simple_skidpad_signals(out,fullfile(scratch,'simple_signal_plots.pdf'));
    files=[dir(fullfile(scratch,'*.pdf'));dir(fullfile(scratch,'*_index.csv'))];
    for k=1:numel(files)
        movefile(fullfile(scratch,files(k).name),fullfile(folder,'plots',files(k).name),'f');
    end
end
end
