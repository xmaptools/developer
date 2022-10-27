function [Output,Antidote_VARIABLES] = Antidote_1_OptPTX(WorkVariXMap,MinimOptions,Text2Disp,HTML_1,HTML_2,app)
%
%
%

% Load MinimOptions to enable TEST mode
load('MinimOptions.mat');

Tmin = app.TminEditField.Value;
Tmax = app.TmaxEditField.Value;
Pmin = app.PminEditField.Value;
Pmax = app.PmaxEditField.Value;
Res = app.AntidoteGridresolutionEditField.Value;

Ti = [Tmin:(Tmax-Tmin)/(Res-1):Tmax];
Pi = [Pmin:(Pmax-Pmin)/(Res-1):Pmax];

LIMS = [Ti(1),Ti(end),Pi(1),Pi(end)];

dT4Plot = (Ti(2) - Ti(1))/2;
dP4Plot = (Pi(2) - Pi(1))/2;

Axis_Maps = [LIMS(1)-dT4Plot LIMS(2)+dT4Plot (LIMS(3)-dP4Plot) (LIMS(4)+dP4Plot)];

[BinSet] = SetBin(app);

Text2Disp = [Text2Disp,['Antidote: Recipe [1] - Find Optimal P-T(-X)'],'<br />'];
Text2Disp = [Text2Disp,['Bulk: ',BinSet.Bulk2Display],'<br />'];
Text2Disp = [Text2Disp,['Database: ',BinSet.Database],'<br /><br />'];
app.HTML_AntidoteReport.HTMLSource = [HTML_1,Text2Disp,HTML_2];

if isequal(MinimOptions.Search.Symplex.FirstOpt,1)
    
    tic
    
    % -------------------------------------------------------------
    %                 ** P-T scanning ** starts here...
    % -------------------------------------------------------------
    
    Text2Disp = [Text2Disp,['##### Exploratory P-T scanning (',num2str(Res),' x ',num2str(Res),') #####'],'<br /><br />'];
    app.HTML_AntidoteReport.HTMLSource = [HTML_1,Text2Disp,HTML_2];
    
    E1 = nan(length(Pi),length(Ti));
    E2 = nan(length(Pi),length(Ti));
    E3 = nan(length(Pi),length(Ti));
    E4 = nan(length(Pi),length(Ti));
    
    IsHSat = nan(length(Pi),length(Ti));
    
    cla(app.UIAxes_LiveAntidote1,'reset');
    
    app.TabGroup2.SelectedTab = app.LiveTab;
    
    app.LiveUpdate = 0;
    app.LIVE_Qtot_Gauge.Value = 0;
    app.EditField_BestQtot.Value = 0;
    
    for iTC = 1:length(Ti)
        for iP = 1:length(Pi)
            
            [Res,Evaluation,WorkVariMod] = OptiBingoPT([1,1],[Ti(iTC),Pi(iP)],LIMS,BinSet,WorkVariXMap,MinimOptions,app);
            E4(iP,iTC) = Res;
            
            if isequal(app.LiveDisplaySwitch.Value,'On')
                app.LIVE_Qtot_Gauge.Value = abs(min(E4(:)));
                app.EditField_BestQtot.Value = app.LIVE_Qtot_Gauge.Value;
            else
                app.LIVE_Qtot_Gauge.Value = 0;
                app.EditField_BestQtot.Value = 0;
            end
            
            E1(iP,iTC) = Evaluation.assemblage;
            E2(iP,iTC) = Evaluation.Volume;
            E3(iP,iTC) = Evaluation.Compositions;
            
            IsHSat(iP,iTC) = SaturationCheck4H(WorkVariMod);
            
        end
        
        imagesc(app.UIAxes_LiveAntidote1,Ti,Pi,E4);
        app.UIAxes_LiveAntidote1.YDir = 'normal';
        axis(app.UIAxes_LiveAntidote1,Axis_Maps)
        colormap(app.UIAxes_LiveAntidote1,[0,0,0;RdYlBu(64)]);
        colorbar(app.UIAxes_LiveAntidote1)
        xlabel(app.UIAxes_LiveAntidote1,'Temperature (°C)');
        ylabel(app.UIAxes_LiveAntidote1,'Pressure (GPa)');
        title(app.UIAxes_LiveAntidote1,'Objective function (-Q_{tot})');
        
        drawnow
    end
    
    % Find pixels with H saturation...
    WhereSaturation  = find(IsHSat);
    if length(WhereSaturation)
        
        Text2Disp = [Text2Disp,[' ** WARNING **'],'<br />'];
        Text2Disp = [Text2Disp,[' The component H2O is "saturated" for ',num2str(length(WhereSaturation)),'/',num2str(length(IsHSat(:))),' P-T couples'],'<br />'];
        Text2Disp = [Text2Disp,[' This may cause convergence to local minima if H is part of the optimization'],'<br />'];
        Text2Disp = [Text2Disp,[' Further warning messages related to this issue will be displayed below'],'<br /><br />'];
        app.HTML_AntidoteReport.HTMLSource = [HTML_1,Text2Disp,HTML_2];
        
        TGrid4Plot = repmat(Ti,length(Pi),1);
        PGrid4Plot = repmat(Pi',1,length(Ti));
        
        hold(app.UIAxes_LiveAntidote1,'on');
        
        plot(app.UIAxes_LiveAntidote1,TGrid4Plot(WhereSaturation),PGrid4Plot(WhereSaturation),'xw');
        drawnow
    end
    
    [sP,sTC] = find(E4==min(E4(:)));
    
    if length(sP) > 1
        sP = sP(1);
        sTC = sTC(1);
    end
    
    X0 = [Ti(sTC),Pi(sP)];
    
    Text2Disp = [Text2Disp,['RESULTS (Exploratory P-T scanning)'],'<br />'];
    Text2Disp = [Text2Disp,['X0(1) = ',num2str(Pi(sP)),' (P,GPa)'],'<br />'];
    Text2Disp = [Text2Disp,['X0(2) = ',num2str(Ti(sTC)),' (T,°C)'],'<br /><br />'];
    
    ht1 = toc;
    Text2Disp = [Text2Disp,['CPU time ',num2str(ht1),' s'],'<br /><br />'];
    app.HTML_AntidoteReport.HTMLSource = [HTML_1,Text2Disp,HTML_2];
    
    plot(app.UIAxes_LiveAntidote1,Ti(sTC),Pi(sP),'pw','markerfacecolor','w','markersize',10);
    
    drawnow
    
else
    % From bingo P-T input
    X0 = [app.BingoTemperatureEditField.Value,app.BingoPressureEditField.Value];
end

% Get started with possible X variables:  (Syros - March 2019)
BinGfDef = app.BinGfDef;

%AdditionalVariables = zeros(3,1);
IsHOptimized = 0;
ElementB = {};
Min= [];
Max = [];
AdditionalVariables = 0;
Compt = 0;
if BinGfDef.Fluids.Optimize
    for i = 1:length(BinGfDef.Fluids.Spec)
        if BinGfDef.Fluids.Spec(i).IsActive
            Compt = Compt+1;
            ElementB{Compt} = char(BinGfDef.Fluids.Spec(i).ListVariAntidote);
            Min(Compt) = BinGfDef.Fluids.Spec(i).Lower;
            Max(Compt) = BinGfDef.Fluids.Spec(i).Upper;
            AdditionalVariables(Compt) = 1;
            
            if isequal(ElementB(Compt),{'H'})
                IsHOptimized = 1;
            end
        end
    end
    %AdditionalVariables(1) = 1;
end

% Add Oxygen here...
if BinGfDef.Oxygen.ActivateExtraO
    if BinGfDef.Oxygen.OptimizeExtraO
        Compt = Compt+1;
        ElementB{Compt} = 'O';
        Min(Compt) = BinGfDef.Oxygen.ExtraO.Lower;
        Max(Compt) = BinGfDef.Oxygen.ExtraO.Upper;
        AdditionalVariables(Compt) = 1;
    end
end


if sum(AdditionalVariables) > 0  && isequal(MinimOptions.Search.Symplex.FirstOpt,1)
    
    MaxQ1 = max(E1(:));
    WhereMaxQ1 = find(E1 == MaxQ1);
    NbMaxQ1 = length(WhereMaxQ1);
    
    Text2Disp = [Text2Disp,[' ++ Diagnostic before Exploratory P-T-X scanning ++ '],'<br />'];
    Text2Disp = [Text2Disp,['Min(-Qass) = ',num2str(-MaxQ1)],'<br />'];
    Text2Disp = [Text2Disp,['Nb pixels = ',num2str(NbMaxQ1)],'<br /><br />'];
    
    app.HTML_AntidoteReport.HTMLSource = [HTML_1,Text2Disp,HTML_2];
    
    if isequal(MinimOptions.TestMode,1)     % TEST mode 
        LimitMax = 1e5;                     % i.e. no limit
        disp(' ')
        disp(' ')
        disp(' <> TEST MODE   ##   No selection if Nb > 50')
        disp(' ')
    else
        LimitMax = 50;
    end
    
    if NbMaxQ1 > LimitMax
        % Random selection: 
        
        Perm = randperm(NbMaxQ1);
        Perm = Perm(1:LimitMax);
        
        WhereMaxQ1 = WhereMaxQ1(Perm);
        NbMaxQ1 = length(WhereMaxQ1);
        
        Text2Disp = [Text2Disp,['** WARNING ** '],'<br />'];
        Text2Disp = [Text2Disp,['the number of P-T initial guesses for stage 2 exceeded the limit of ',num2str(LimitMax)],'<br />'];
        Text2Disp = [Text2Disp,['A random selection has been made to reduce the size of the problem '],'<br />'];
        Text2Disp = [Text2Disp,['Min(-Qass) = ',num2str(-MaxQ1)],'<br />'];
        Text2Disp = [Text2Disp,['Nb pixels = ',num2str(NbMaxQ1)],'<br /><br />'];
        
        app.HTML_AntidoteReport.HTMLSource = [HTML_1,Text2Disp,HTML_2];
    end
    
    TGrid = repmat(Ti,length(Pi),1);
    PGrid = repmat(Pi',1,length(Ti));
    
    ScanT = TGrid(WhereMaxQ1);
    ScanP = PGrid(WhereMaxQ1);
    
    IsSatScanPT = IsHSat(WhereMaxQ1);
    
    plot(app.UIAxes_LiveAntidote1,ScanT,ScanP,'sw','markerfacecolor','w','markersize',3);
    
    
    % -------------------------------------------------------------
    %              ** P-T-X scanning ** starts here...
    % -------------------------------------------------------------
    % This stage is critical, otherwise the P-T-X optimization
    % fails to find the global minimum if the initial guess is far
    % from the optimal solution.
    %
    % Here we assume that the shape of the P-T objective function
    % does not change too much with X (as in Lanari et al. 2017).
    
    
    ScanDim = length(Max);
    switch ScanDim
        case 1
            if isequal(MinimOptions.TestMode,1)  % TEST mode 
                Answ = inputdlg('X scan resolution','TEST mode',1,{'100'});
                ScanRes = str2num(Answ{1});
                %ScanRes = 10;
                disp([' <> TEST MODE   ##   Scan resolution (X) increased to: ',num2str(10)])
                disp(' ')
            else
                ScanRes = 10;
            end
        case 2
            ScanRes = 5;
        case 3
            ScanRes = 3;
    end
    
    ScanNb = NbMaxQ1*ScanRes^ScanDim;
    
    Text2Disp = [Text2Disp,['##### Exploratory P-T-X scanning (',num2str(ScanNb),') #####'],'<br />'];
    Text2Disp = [Text2Disp,['* X(1) P-T: ',num2str(length(ScanT))],'<br />'];
    if IsHOptimized
        if sum(IsSatScanPT) > 0
            Text2Disp = [Text2Disp,['  ... Warning',sum(IsSatScanPT)/length(IsSatScanPT)*100,' % of initial P-T couples are saturated (H)'],'<br />'];
        end
    end
    app.HTML_AntidoteReport.HTMLSource = [HTML_1,Text2Disp,HTML_2];
    
    drawnow
    
    tic
    
    % We need plenty of variables for the optimization of H
    SelectedBinBulk = app.ROITree.SelectedNodes.NodeData;
    BinBulkOri = app.BinBulk(SelectedBinBulk);
    TempBinBulk = BinBulkOri;
    
    LIMSx = [LIMS(1:2);LIMS(3:4)];
    
    for i = 1:length(Min)
        X0(end+1) = Min(i)+(Max(i)-Min(i))/2;
        LIMSx(end+1,:) = [Min(i);Max(i)];
        Text2Disp = [Text2Disp,['* X(',num2str(i+1),') ',char(ElementB{i}),': ',num2str(ScanRes)],'<br />'];
    end
    Text2Disp = [Text2Disp,[''],'<br />'];
    app.HTML_AntidoteReport.HTMLSource = [HTML_1,Text2Disp,HTML_2];
    
    ScanX = X0(3:end);    % size: ScanDim
    ScandX = (Max-Min)/(ScanRes+1);
    
    switch length(ScanX)
        case 1
            Xteps1 = [Min+ScandX:ScandX:Max-ScandX]';
            
            BinMtx1 = repmat(Xteps1,1,length(ScanT));
            
            TMtx = repmat(ScanT',length(Xteps1),1);
            PMtx = repmat(ScanP',length(Xteps1),1);
            
            ScanXsteps = BinMtx1(:);
            ScanTsteps = TMtx(:);
            ScanPsteps = PMtx(:);
            
        case 2
            Xteps1 = [Min(1)+ScandX(1):ScandX(1):Max(1)-ScandX(1)];
            Xteps2 = [Min(2)+ScandX(2):ScandX(2):Max(2)-ScandX(2)];
            
            BinMtL1x1 = repmat(Xteps1,ScanRes,1);
            BinMtL1x2 = repmat(Xteps2',1,ScanRes);
            
            ScanXteps1 = [BinMtL1x1(:),BinMtL1x2(:)];
            
            BinMtL2x1 = repmat(ScanXteps1(:,1),1,length(ScanT));
            BinMtL2x2 = repmat(ScanXteps1(:,2),1,length(ScanT));
            
            TMtx = repmat(ScanT',size(BinMtL2x1,1),1);
            PMtx = repmat(ScanP',size(BinMtL2x1,1),1);
            
            ScanXsteps = [BinMtL2x1(:),BinMtL2x2(:)];
            ScanTsteps = TMtx(:);
            ScanPsteps = PMtx(:);
            
            
        case 3
            
            disp(' NOT YET AVAILABLE... Because it is tricky in this case')
            Output.WeCallBingo = 0;
            Output.WeSaveWorkspace = 0;
            Output.Message = 'Error';
            
            Antidote_VARIABLES = [];
            return
            keyboard
            
            Xteps1 = [Min(1)+ScandX(1):ScandX(1):Max(1)-ScandX(1)];
            Xteps2 = [Min(2)+ScandX(2):ScandX(2):Max(2)-ScandX(2)];
            Xteps3 = [Min(3)+ScandX(3):ScandX(3):Max(3)-ScandX(3)];
            
            BinMtx1 = repmat(Xteps1,ScanRes,1,1);
            BinMtx2 = repmat(Xteps2',1,ScanRes,1);
            BinMtx3 = repmat(Xteps3',1,1);
            
            ScanXteps = [BinMtx1(:),BinMtx2(:),BinMtx3(:)];
            
            % TO BE TESTED !!!!!!!!!!!!!!!!!!
            keyboard
    end
    
    E4 = nan(size(ScanXsteps,1),1);
    IsHSat2 = nan(size(ScanXsteps,1),1);
    
    for i = 1:length(ScanXsteps)
        
        % update the bulk
        [Bulk,TempBinBulk] = SuperFast_X_Update(TempBinBulk,ElementB,ScanXsteps(i,:));
        Bulk(1) = '1';
        BinSet.Bulk2Display = Bulk;
        
        %disp(' ')
        %fprintf('%s\t%.0f\n','STEP',i);
        %disp(Bulk)
        %for j = 1:length(ElementB)
        %    fprintf('%s\t%.5f\n',ElementB{j},ScanXteps(i,j));
        %end
        
        % Method 1:
        [Res,Evaluation,WorkVariMod] = OptiBingoPT([1,1],[ScanTsteps(i),ScanPsteps(i)],LIMS,BinSet,WorkVariXMap,MinimOptions,app);
        
        IsHSat2(i) = SaturationCheck4H(WorkVariMod);
        
        % Method 2 (for testing - done 09.03.2019 - 2 variables)
        % D_Temp = num2str(X0(1));
        % D_Press = num2str(X0(2));
        % [WorkVariMod] = TheriakCall(BinSet,D_Temp,D_Press);
        % DoWePrint = 0;
        % [Emin_T,Evaluation_T] = Opti_EpsiMinimCalc(WorkVariMod,WorkVariXMap,MinimOptions,DoWePrint,handles);
        
        E4(i) = Res;
        
        %fprintf('%s\t%.3f\n','Res.',Res);
        
    end
    
    PerSat = sum(IsHSat2)/length(IsHSat2)*100;
    %fprintf('\t%s\t%.0f%s\n','  ... Warning',PerSat,' % of them saturated (H)');
    if IsHOptimized && PerSat > 25
        Text2Disp = [Text2Disp,['** WARNING ** '],'<br />'];
        Text2Disp = [Text2Disp,['There are too many P-T-X points with H2O saturation (',num2str(PerSat),' %)'],'<br />'];
        Text2Disp = [Text2Disp,['It is strongly recommended to restrict the range of possible H values for better efficency of the exploratory scans'],'<br />'];
        Text2Disp = [Text2Disp,['Further warning messages related to this issue will be displayed below'],'<br /><br />'];
        app.HTML_AntidoteReport.HTMLSource = [HTML_1,Text2Disp,HTML_2];
    end
    
    if isequal(MinimOptions.TestMode,1)  % TEST mode
        disp([' <> TEST MODE   ##   Results of P-T-X explanatory ']);
        disp(' ');
        
        E4Map = reshape(E4,size(TMtx));
        for i = 1:size(E4Map,2)
            [E4MinCol(i),IdxMin] = min(E4Map(:,i));
            XOptiCol(i) = Xteps1(IdxMin);
        end
        
        MapE4Min = zeros(numel(P),numel(TC));
        MapXOpti = zeros(numel(P),numel(TC));
        [Is,IdxTC] = ismember(ScanT,TC);
        [Is,IdxP] = ismember(ScanP,P);
        
        for i = 1:length(IdxP)
            MapE4Min(IdxP(i),IdxTC(i)) = E4MinCol(i);
            MapXOpti(IdxP(i),IdxTC(i)) = XOptiCol(i);
        end
        
        figure, 
        imagesc(TC,P,MapE4Min); set(gca,'Ydir','normal');
        TheMinE4 = min(MapE4Min(find(MapE4Min)));
        TheMaxE4 = max(MapE4Min(find(MapE4Min)));
        AdjustE4ColorBar = (TheMaxE4-TheMinE4)*0.05;
        caxis([TheMinE4-AdjustE4ColorBar,TheMaxE4+AdjustE4ColorBar])
        colormap([0,0,0;RdYlBu(256);1,1,1])
        colorbar;
        
        figure, 
        imagesc(TC,P,MapXOpti); set(gca,'Ydir','normal');
        TheMinE4 = min(MapXOpti(find(MapXOpti)));
        TheMaxE4 = max(MapXOpti(find(MapXOpti)));
        AdjustE4ColorBar = (TheMaxE4-TheMinE4)*0.01;
        caxis([TheMinE4-AdjustE4ColorBar,TheMaxE4+AdjustE4ColorBar])
        colormap([1,1,1;RdYlBu(256);0,0,0])
        colorbar;
        
        if 0  % turn to 1 to activate this extra plot (3D bar diagram)
            figure,
            hh = bar3(MapXOpti);

            figure,
            h = bar3(MapE4Min.*-1);
            h2 = get(h(3),'parent');
            set(h2,'yLim', [0.5 20.5]);
            gtick=get(h2,'ytick');
            set(h2,'yticklabel',P(gtick));
            set(h2,'ytickmode','manual');
            set(h2,'xLim', [0.5 20.5]);
            gtick=get(h2,'xtick');
            set(h2,'xticklabel',TC(gtick));
            set(h2,'xtickmode','manual');
            TC(gtick);
            zlim([ 80 100])
            colorbar
            for k = 1:length(h)
                zdata = hh(k).ZData;
                h(k).CData = zdata;
                h(k).FaceColor = 'texturemap';
            end
        end
        
        %keyboard
        
        VariablesStruc = whos;       % this does not save the figures in MATLAB 2014b on
        Compt = 0;
        for i = 1:length(VariablesStruc)
            if ~isequal(VariablesStruc(i).name,'eventdata') && ~isequal(VariablesStruc(i).name,'hObject') && ~isequal(VariablesStruc(i).name,'handles')
                Compt = Compt+1;
                NewStruc(Compt).name = VariablesStruc(i).name;
            end
        end
        save('Last_Optimal-PTX-map.mat',NewStruc.name);
        
        
%         figure,
%         scatter(ScanT,ScanP,100*ones(size(E4MinCol)),E4MinCol,'filled');
%         colormap([0,0,0;RdYlBu(64)])
%         colorbar;
    end
    
    % Ok, here we have to exclude all the points that were
    % saturated in H2O...
    
    WhereBestStep2 = find(E4 == min(E4));
    if length(WhereBestStep2 > 1)
        WhereBestStep2 = WhereBestStep2(1);
    end
    
    if IsHOptimized
        WhereUnsat = find(IsHSat2 == 0);
        
        if ~length(WhereUnsat)
            
            Text2Disp = [Text2Disp,['** FATAL ERROR ** '],'<br />'];
            Text2Disp = [Text2Disp,['Sorry fellas but the objective function seems to be flat in H and further optimization is not possible!'],'<br />'];
            Text2Disp = [Text2Disp,['You can try to reduce the upper limit of H values'],'<br />'];
            Text2Disp = [Text2Disp,['Scanning H at fixed PT might help to fix this issue'],'<br /><br />'];
            
            Text2Disp = [Text2Disp,[' >>> End ANTIDOTE job: ',datestr(now),'  <<<'],'<br />'];
            Text2Disp = [Text2Disp,['- - - - - - - - - - - - - - - - - - - - - - - - - - -'],'<br /><br />'];
            app.HTML_AntidoteReport.HTMLSource = [HTML_1,Text2Disp,HTML_2];
            
            Output.WeCallBingo = 0;
            Output.WeSaveWorkspace = 0;
            Output.Message = 'Error';
            
            Antidote_VARIABLES = [];
            return
        end
        
        WhereMinUnsat = find(E4(WhereUnsat) == min(E4(WhereUnsat)));
        WhereBestStep2_UnSat = WhereUnsat(WhereMinUnsat);
        if length(WhereBestStep2_UnSat > 1)
            WhereBestStep2_UnSat = WhereBestStep2_UnSat(1);
        end
        
        if ~isequal(WhereBestStep2,WhereBestStep2_UnSat)
            
            Text2Disp = [Text2Disp,['** WARNING **'],'<br />'];
            Text2Disp = [Text2Disp,['The following minimum was skipped because of H saturation:'],'<br />'];
            Text2Disp = [Text2Disp,['T = ',num2str(ScanTsteps(WhereBestStep2))],'<br />'];
            Text2Disp = [Text2Disp,['P = ',num2str(ScanPsteps(WhereBestStep2))],'<br />'];
            Text2Disp = [Text2Disp,['X = ',num2str(ScanXsteps(WhereBestStep2))],'<br />'];
            Text2Disp = [Text2Disp,['-Qtot = ',num2str(E4(WhereBestStep2))],'<br />'];
            Text2Disp = [Text2Disp,[' ... and replaced by: '],'<br />'];
            Text2Disp = [Text2Disp,['T = ',num2str(ScanTsteps(WhereBestStep2_UnSat))],'<br />'];
            Text2Disp = [Text2Disp,['P = ',num2str(ScanPsteps(WhereBestStep2_UnSat))],'<br />'];
            Text2Disp = [Text2Disp,['X = ',num2str(ScanXsteps(WhereBestStep2_UnSat))],'<br />'];
            Text2Disp = [Text2Disp,['-Qtot = ',num2str(E4(WhereBestStep2_UnSat))],'<br />'];
            Text2Disp = [Text2Disp,['Note: If P and T are different, the result of the optimization is probably not robust... '],'<br />'];
            Text2Disp = [Text2Disp,['-> You can try to set the upper H limit to the saturation point at: ',num2str(ScanTsteps(WhereBestStep2)),' - ',num2str(ScanPsteps(WhereBestStep2))],'<br /><br />'];
            app.HTML_AntidoteReport.HTMLSource = [HTML_1,Text2Disp,HTML_2];
            
            WhereBestStep2 = WhereBestStep2_UnSat;
        end
    end
    
    X0(1) = ScanTsteps(WhereBestStep2);
    X0(2) = ScanPsteps(WhereBestStep2);
    
    plot(app.UIAxes_LiveAntidote1,X0(1),X0(2),'o','MarkerEdgeColor','k','MarkerFaceColor','r');
    
    %disp(' '), disp(' ')
    Text2Disp = [Text2Disp,['RESULTS (Exploratory P-T-X scanning)'],'<br />'];
    Text2Disp = [Text2Disp,['T = ',num2str(ScanTsteps(WhereBestStep2))],'<br />'];
    Text2Disp = [Text2Disp,['P = ',num2str(ScanPsteps(WhereBestStep2))],'<br />'];
    for i = 1:length(ElementB)
        Text2Disp = [Text2Disp,[char(ElementB{i}),' = ',num2str(ScanXsteps(WhereBestStep2,i))],'<br />'];
        X0(2+i) = ScanXsteps(WhereBestStep2,i);
    end
    Text2Disp = [Text2Disp,['Minimum: ',num2str(E4(WhereBestStep2)),' (real minimum: ',num2str(min(E4)),')'],'<br /><br />'];
    
    ht1 = toc;
    Text2Disp = [Text2Disp,['CPU time: ',num2str(ht1)],'<br /><br />'];
    
    app.HTML_AntidoteReport.HTMLSource = [HTML_1,Text2Disp,HTML_2];
    drawnow
    
    % -------------------------------------------------------------
    %  ** P-T-X Optimization ** starts here...
    % -------------------------------------------------------------
    
    options = optimset('fminsearch'); options=optimset(options,'TolX',0.0001,'TolFun',0.0001,'display','iter','MaxFunEvals',1000,'MaxIter',300);
    
    NORM = X0;
    %NORM(3) = NORM(3)/100;
    X0 = X0./NORM;
    
    Text2Disp = [Text2Disp,['##### Final P-T-X Optimization (from: T = ',num2str(NORM(1)),' degree C; P = ',num2str(NORM(2)),' bar) #####'],'<br />'];
    for i = 1:length(Min)
        Text2Disp = [Text2Disp,[' * Additional variable:   X',num2str(i),'(',char(ElementB{i}),') = ',num2str(NORM(2+i)),'   [',num2str(Min(i)),' - ',num2str(Max(i)),']'],'<br />'];
    end
    Text2Disp = [Text2Disp,[''],'<br />'];
    Text2Disp = [Text2Disp,['Method: Simplex'],'<br />'];
    if MinimOptions.Weights.Use
        Text2Disp = [Text2Disp,['Equation: Other [E4 = -(',num2str(MinimOptions.Weights.Values(MinimOptions.Weights.Selected,1)),'*E1 + ',num2str(MinimOptions.Weights.Values(MinimOptions.Weights.Selected,2)),'*E2 + ',num2str(MinimOptions.Weights.Values(MinimOptions.Weights.Selected,3)),'*E3)]'],'<br /><br />'];
    else
        Text2Disp = [Text2Disp,['Equation: Classic','[E4 = -1/3*(E1 + (E1/100)*E2 + (E1/100)*(E2/100)*E3)]'],'<br /><br />'];
    end
    app.HTML_AntidoteReport.HTMLSource = [HTML_1,Text2Disp,HTML_2];
    
    % goto bypass
    
    % *** BYPASS MODE *** (PL 09.03.2019)
    % temporary to avoid optimizing PT (only X for testing
    % purposes only);
    
    Bypass = [];
    %Bypass = NORM(1:2);
    
    if length(Bypass)
        disp(' ')
        disp('*** WARNING *** the Bypass mode is activated (P-T are not optimized)')
        %disp(' ')
    end
    
    tic
    f = @OptiBingoPTX;
    [Result,Res] = fminsearch(f, X0,options,NORM,LIMSx,BinSet,WorkVariXMap,MinimOptions,TempBinBulk,ElementB,Bypass,IsHOptimized,app);
    ht2 = toc;
    
    if length(Bypass)
        AddComment = '** bypass mode is on (this variable was skipped)';
        TCf = Bypass(1);
        Pf = Bypass(2);
    else
        AddComment = '';
        TCf = round(Result(1)*NORM(1));   % round is important for convergence if X is involved (tested agin june 2019)
        Pf = Result(2)*NORM(2); % cannot round in GPa
    end
    %Hf = Result(3)*NORM(3);
    X_Vari = Result(3:end).*NORM(3:end);
    
    Text2Disp = [Text2Disp,['RESULTS (Final P-T-X optimization)'],'<br />'];
    Text2Disp = [Text2Disp,['T = ',num2str(TCf)],'<br />'];
    Text2Disp = [Text2Disp,['P = ',num2str(Pf)],'<br />'];
    for i = 1:length(X_Vari)
        Text2Disp = [Text2Disp,['X(',num2str(i),') ',char(ElementB{i}),' = ',num2str(X_Vari(i))],'<br />'];
    end
    Text2Disp = [Text2Disp,['Minimum: ',num2str(Res)],'<br /><br />'];
    app.HTML_AntidoteReport.HTMLSource = [HTML_1,Text2Disp,HTML_2];
    
    % Here we need to update the bulk
    %[Bulk,TempBinBulk] = SuperFast_H_Update(TempBinBulk,Hf);
    [Bulk,TempBinBulk] = SuperFast_X_Update(TempBinBulk,ElementB,X_Vari);
    
    app.BinBulk(SelectedBinBulk) = TempBinBulk;
    app.LBCEditField.Value = Bulk;
    
    Text2Disp = [Text2Disp,['Bulk: ',Bulk],'<br /><br />'];
    app.HTML_AntidoteReport.HTMLSource = [HTML_1,Text2Disp,HTML_2];
    
    
else
    
    options = optimset('fminsearch'); options=optimset(options,'TolX',0.0001,'TolFun',0.0001,'display','iter','MaxFunEvals',300,'MaxIter',100);
    
    NORM = X0;
    X0 = X0./NORM;
    
    %[E4] = OptiBingoPT(X0,NORM,LIMS,InvMet,WorkVariXMap,MinimOptions,handles);
    
    disp(['##### Final P-T Optimization (from: ',num2str(NORM(1)),' bar; ',num2str(NORM(2)),' C) #####']);
    
    disp(' ')
    fprintf('%s\t\t%s\n','Method:','Simplex');
    if MinimOptions.Weights.Use
        fprintf('%s\t%s\t%s\n','Equation:','Other',['[E4 = -(',num2str(MinimOptions.Weights.Values(MinimOptions.Weights.Selected,1)),'*E1 + ',num2str(MinimOptions.Weights.Values(MinimOptions.Weights.Selected,2)),'*E2 + ',num2str(MinimOptions.Weights.Values(MinimOptions.Weights.Selected,3)),'*E3)]']);
    else
        %fprintf('%s\t%s\t%s\n','Equation:','Classic','[E4 = -1/3*(E1 + (E1/100)*E2 + (E1/100)*(E2/100)*E3)]');
        fprintf('%s\t%s\t%s\n','Equation:','Classic','[E4 = -1/3*(E1 + (E1/100)*E2 + (E1/100)*E3)]');
    end
    
    app.LiveUpdate = 1;
    
    tic
    f = @OptiBingoPT;
    [Result,Res] = fminsearch(f, X0,options,NORM,LIMS,BinSet,WorkVariXMap,MinimOptions,app);
    ht2 = toc;
    
    TCf = Result(1)*NORM(1);
    Pf = Result(2)*NORM(2);
    
    
    Text2Disp = [Text2Disp,['RESULTS (Final P-T optimization)'],'<br />'];
    Text2Disp = [Text2Disp,['X(1) = ',num2str(Pf),' (P,GPa)'],'<br />'];
    Text2Disp = [Text2Disp,['X(2) = ',num2str(TCf),' (T,°C)'],'<br /><br />'];
    
    ht1 = toc;
    Text2Disp = [Text2Disp,['CPU time ',num2str(ht2),' s'],'<br /><br />'];
    app.HTML_AntidoteReport.HTMLSource = [HTML_1,Text2Disp,HTML_2];
    
end

% E4 = Res;

app.BingoTemperatureEditField.Value = TCf;
app.BingoPressureEditField.Value = Pf;

% 
Output.WeCallBingo = 1;
Output.WeSaveWorkspace = 1;
Output.Message = 'Success';

w = whos;
for a = 1:length(w)
    if ~isequal(w(a).name,'eventdata') && ~isequal(w(a).name,'hObject') && ~isequal(w(a).name,'handles')
        Antidote_VARIABLES.(w(a).name) = eval(w(a).name); 
    end
end


return



