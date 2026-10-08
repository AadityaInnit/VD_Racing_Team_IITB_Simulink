function skidpad_export_panels(panels,destination,heading,notes)
% Export white-background PDF pages, legends, source index and PNG previews.
assert(~isfile(destination),'Destination already exists: %s',destination);
folder=fileparts(destination);if ~isfolder(folder),mkdir(folder);end
f=figure('Visible','off','Color','white','Position',[50 50 1400 1000]);
ax=axes(f,'Position',[.07 .08 .86 .84]);axis(ax,'off');
text(ax,0,1,heading,'Units','normalized','VerticalAlignment','top','FontSize',22,'FontWeight','bold','Color','black','Interpreter','none');
text(ax,0,.88,strjoin(notes,sprintf('\n\n')),'Units','normalized','VerticalAlignment','top','FontSize',12,'Color','black','Interpreter','none');
exportgraphics(f,destination,'ContentType','image','Resolution',150);close(f);
palette=[0 .35 .65;.85 .33 .05;.13 .55 .25;.55 .2 .65];
reportEnd=max(arrayfun(@(panel)max(panel.Time),panels));
for first=1:6:numel(panels)
    f=figure('Visible','off','Color','white','Position',[50 50 1400 1000]);
    tiles=tiledlayout(f,3,2,'TileSpacing','compact','Padding','compact');
    for j=first:min(first+5,numel(panels))
        p=panels(j);ax=nexttile(tiles);colororder(ax,palette);
        if isscalar(p.Time)
            % Constant blocks can log only one sample. Display their held value.
            plot(ax,[p.Time;max(reportEnd,p.Time+eps)],repmat(p.Data,2,1),'LineWidth',1);
        else
            plot(ax,p.Time,p.Data,'LineWidth',1);
        end
        set(ax,'Color','white','XColor','black','YColor','black','GridColor',[.65 .65 .65],'FontSize',9);
        title(ax,wrapTitle(p.Title),'Interpreter','none','FontSize',10,'Color','black');
        xlabel(ax,'Time (s)','Color','black');ylabel(ax,p.Unit,'Interpreter','none','Color','black');grid(ax,'on');
        if size(p.Data,2)>1
            assert(numel(p.Legends)==size(p.Data,2),'Legend mismatch: %s',p.Title);
            legend(ax,p.Legends,'Location','best','FontSize',8,'TextColor','black','Color','white','Interpreter','none');
        end
    end
    title(tiles,heading+" - plot page "+ceil(first/6),'Color','black','FontSize',14,'Interpreter','none');
    exportgraphics(f,destination,'ContentType','image','Resolution',150,'Append',true);
    if first==1 || first==19 || first==43
        [~,base]=fileparts(destination);exportgraphics(f,fullfile(folder,base+"_page_"+ceil(first/6)+".png"),'Resolution',100);
    end
    close(f);
end
sources=string({panels.Source})';titles=string({panels.Title})';units=string({panels.Unit})';
channels=arrayfun(@(p)size(p.Data,2),panels)';pages=ceil((1:numel(panels))'/6)+1;
writetable(table(sources,titles,units,channels,pages,'VariableNames', ...
    {'RecordedSignal','PlotTitle','Units','Channels','PDFPage'}),replace(destination,'.pdf','_index.csv'));
fprintf('Exported %d plots, %d pages including cover: %s\n',numel(panels),ceil(numel(panels)/6)+1,destination);
end

function label=wrapTitle(label)
if strlength(label)>75
    chars=char(label);spaces=find(chars(1:min(70,end))==' ');
    if ~isempty(spaces),cut=spaces(end);label=string(chars(1:cut-1))+newline+string(chars(cut+1:end));end
end
end
