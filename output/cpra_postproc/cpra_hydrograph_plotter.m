%####################################################
% AUTHORS: Matthew V Bilskie, PhD
%          Louisiana State University
%
%          Jason Fleming, PhD
%          Seahorse Coastal Consulting
%
% COPYRIGHT 2018-2020
%
%####################################################
% 
% All time are in CDT. The model values are adjusted from UTC to CDT
% by subtracting 5 hours.
%
clear all;
close all;
%
%%
%
msg = sprintf('cpra_hydrograph_plotter.m: BEGIN cpra_hydrograph_plotter.m %s CDT',...
    datestr(datetime('now','TimeZone','America/Chicago'),'yyyymmdd HH:MM'));
disp(msg);
%
%%
% User-defined inputs

% productionMode = true; % for ASGS
productionMode = false; % Manual mode

% Used for automatically calculating a static offset
% autoOffset = false;   
autoOffset = true;

if productionMode == false
    plotSubset = false; % for ASGS
%     plotSubset = true; % for debugging, etc.
%     subsetIndex = [3];

    overrideedate = false; % for ASGS
%     overrideedate = true; % for post-run analysis
%     edate_final = datenum('2020061000','yyyymmddHH');
end

if (productionMode)
%     ASGS Production mode.
    numEns = 1;
    ensFileNames = {'fort.61.nc'};
    propFile = {'run.properties'};
    plotPrevious = false;
    overrideedate = false; % for ASGS
    plotSubset = false; % for ASGS
else
%     Manual Mode
%     The nhcConsensus for the last advisory, if used, advsiory should be
%     FIRST in the array
%     The nhcConsensus for the current advsiory should be LAST in the array
    numEns = 2;
    ensFileNames = {'2021060406_namforecast.fort.61.nc', '2021060506_namforecast.fort.61.nc'};
    propFile = {'2021060406_namforecast.run.properties', '2021060506_namforecast.run.properties'};
    plotPrevious = true;
end
%
%%

% Hydrograph ensemble colors
colors = [0.9290 0.6940 0.1250; 175/255 54/255 60/255; 0/255 128/255 0/255;...
    143/255 0/255 255/255; 0/255 0/255 255/255; 47/255 79/255 79/255];

% These lists are used in order to look-up the appropriate name based on
% the USACE Station ID found when parsing the fort.15/fort.61.
%
% Station Agency and ID
fstations={'USACE 85625','USGS 073802332','USACE 76030','USACE 76265',...
    'USACE 82762','USACE 82742','USACE 85760',...
    'USACE 76010','USACE 82715',...
    'USGS 07380260',...
    'USACE 01440',...
    'USACE 85670','USACE 85575','USACE 85700','USACE 82875',...
    'USACE 76230','USACE 76025','USGS 073802516',...
    'USGS 08017118',...
    'USACE 76305',... % Houma Nava Canal
    'USACE 01400','USACE 01390','USACE 01300','USACE 01280',...
    'USACE 01275','USACE 01260','USACE 03780'...
    'USACE 01480','USACE 76560','USGS 073814675'};
fstationsSplit = regexp(fstations, ' ', 'split');
fstationsSplit = vertcat(fstationsSplit{:});
% Station ID
stations={'85625','073802332','76030','76265','82762','82742',...
    '85760','76010','82715','07380260','01440','85670','85575','85700',...
    '82875','76230','76025','073802516','8017118',...
    '76305',... % Houma Nav Canal
    '01400','01390','01300','01280','01275','01260','03780',...
    '01480','76560','073814675'};
gageStationsName={'West End',...
    'Seabrook CC - Flood Side',...
    'IHNC Surge Barrier East - Flood Side',...
    'GIWW at West Closure Complex - Flood Side',...
    'Hero Canal Bulkhead Control Structure - Flood Side/West',...
    'Bayou Segnette Sector Gate - Flood Side',...
    'Caernarvon Canal Sector Gate - South/Flood Side',...
    'Bayou Dupre Sector Gate - East/Flood Side',...
    'Bayou Verret / Western Tie-In Sector Gate - Flood Side',...
    'MS River at Empire',...
    'MS River at Empire',...
    'Lake Pontchartrain at Lakefront Airport',...
    'Lake Pontchartrain at Mandeville',...
    'Rigolets near Lake Pontchartrain',...
    'Barataria Waterway at Lafitte',...
    'Harvey Canal at Boomtown Casino',...
    'Bayou Bienvenue Floodgate - East/Flood Side',...
    'Barataria Pass at Grand Isle',...
    'Calcasieu River at Cameron',...
    'Houma Navigation Canal',...
    'MS River at West Point a la Hache',...
    'MS River at Alliance',...
    'MS River at Carrollton',...
    'MS River at Bonnet Carre Spillway',...
    'MS River at Bonnet Carre Spillway North',...
    'MS River at Reserve',...
    'Lower Atchafalaya River at Morgan City',...
    'MS River at Venice',...
    'GIWW at Bayou Sale Ridge',...
    'Bayou Boeuf at Railroad Bridge'};
% The stationID in parenthesis must match what is in the fort.15
cpraStationNames = {'17th St. Outfall Canal (17StCanal)',...
    'Seabrook Complex (IHNC01)',...
    'IHNC  Surge Barrier (IHNC02)',...
    'West Closure Complex (WBV90)',...
    'Hero Canal Stop-Log Gage (WBV09b)',...
    'Bayou Segnette Closure (WBV162)',...
    'Caernarvon Canal Sector Gate (LPV149)',...
    'Bayou Dupre Sector Gate (LPV144)',...
    'Western Tie-In (WBV7274)',...
    'Empire Floodgate (NOV13)',...
    'Empire Lock (NOV14)',...
    'Lakefront Airport (LakefrontAirport)',...
    'Mandeville (Mandeville)',...
    'Rigolets (Rigolets)',...
    'Lafitte (Lafitte)',...
    'Harvey Canal at Boomtown (HarveyCanalBoom)',...
    'Bayou Bienvenue Floodgate (BayouBienv)',...
    'Barataria Pass at Grand Isle (BaraPass)',...
    'Calcasieu River (CalcRiver)',...
    'Houma Navigation Canal (HoumaNavCanal)',...
    'MS River at West Point a la Hache (WestPoint)',...
    'MS River at Alliance (Alliance)',...
    'MS River at Carrollton (Carrollton)',...
    'MS River at Bonnet Carre Spillway (BCSpillway)',...
    'MS River at Bonnet Carre Spillway North (BCSpillwayN)',...
    'MS River at Reserve (Reserve)',...
    'Lower Atchafalaya River at Morgan City (MorganCity)',...
    'MS River at Venice (Venice)',...
    'GIWW at Bayou Sale Ridge (BayouSale)',...
    'Bayou Boeuf at Railroad Bridge (BayouBoeuf)'};
%
%% 
% What if I only want to plot a subset of the stations?
if (plotSubset)
    fstations = {fstations{subsetIndex}};
    fstationsSplit = regexp(fstations, ' ', 'split');
    fstationsSplit = vertcat(fstationsSplit{:});
    
    stations = {stations{subsetIndex}};
    gageStationsName = {gageStationsName{subsetIndex}};
    cpraStationNames = {cpraStationNames{subsetIndex}};
end

%%

% The static offset (ft)
if autoOffset
    msg = sprintf('pra_hydrograph_plotter.m: An automatic offset will be applied.');
    disp(msg);
    fid_offset_out = fopen('Automatic_Offset.csv','w'); % open file
else
    staticOffsetFile = 'Static_Offset.xlsx';
    if exist(staticOffsetFile)
        fid = fopen(staticOffsetFile,'r');
        msg = sprintf('cpra_hydrograph_plotter.m: File %s was found.', staticOffsetFile);
        disp(msg);
    else
        msg = sprintf('cpra_hydrograph_plotter.m FATAL ERROR: %s was NOT found.', staticOffsetFile);
        disp(msg);
        %quit;
    end
    msg = sprintf('cpra_hydrograph_plotter.m: Reading static offsets information from %s.', staticOffsetFile);
    disp(msg);
    [~, ~, raw] = xlsread(staticOffsetFile);
    for idx = 1:numel(raw)
       if isnumeric(raw{idx})
          raw{idx} = num2str(raw{idx});
       end
    end
    offsetMap = containers.Map(raw(:,2),str2num(char(raw(:,3)))*0.3048);
    msg = sprintf('cpra_hydrograph_plotter.m: Success reading static offset information from %s.', staticOffsetFile);
    disp(msg);
end

%
%% 

if (plotPrevious)
    useEnsemble = numEns;
else
    useEnsemble = 1;
end

%%
% The USACE Gate Closure Trigger (ft, NAVD88)
gateFile = 'Gate_Closure_Trigger.xlsx';
if exist(gateFile)
    fid = fopen(gateFile,'r');
    msg = sprintf('cpra_hydrograph_plotter.m: File %s was found.', gateFile);
    disp(msg);
else
    msg = sprintf('cpra_hydrograph_plotter.m FATAL ERROR: %s was NOT found.', gateFile);
    disp(msg);
    %quit;
end
msg = sprintf('cpra_hydrograph_plotter.m: Reading gate closure information from %s.', gateFile);
disp(msg);
[num,txt,raw] = xlsread(gateFile);
trigger = num;
for idx = 1:numel(raw)
   if isnumeric(raw{idx})
      raw{idx} = num2str(raw{idx});
   end
end
triggerMap = containers.Map(raw(:,3),str2num(char(raw(:,4))));
triggerMap2 = containers.Map(raw(:,3),str2num(char(raw(:,5))));
msg = sprintf('cpra_hydrograph_plotter.m: Success reading gate closure information from %s.', gateFile);
disp(msg);
%
%%
% The Datum Conversion (ft -> Gage Datum to NAVD88)
datumConvFile = 'Datum_Conversion.xlsx';
if exist(datumConvFile)
    fid = fopen(datumConvFile,'r');
    msg = sprintf('cpra_hydrograph_plotter.m: File %s was found.', datumConvFile);
    disp(msg);
else
    msg = sprintf('cpra_hydrograph_plotter.m FATAL ERROR: %s was NOT found.', datumConvFile);
    disp(msg);
    %quit;
end
msg = sprintf('cpra_hydrograph_plotter.m: Reading datum conversion information from %s.', datumConvFile);
disp(msg);
[~, ~, raw] = xlsread(datumConvFile);
for idx = 1:numel(raw)
   if isnumeric(raw{idx})
      raw{idx} = num2str(raw{idx});
   end
end
datumConvMap = containers.Map(raw(:,2),str2num(char(raw(:,3))));
msg = sprintf('cpra_hydrograph_plotter.m: Success reading datum conversion information from %s.', datumConvFile);
disp(msg);
%
%% 
% -------------------------------------------------------------------------

% Loop through the number of ensemble simulations
msg = sprintf('cpra_hydrograph_plotter.m: Begin reading ADCIRC station data.');
disp(msg);
for i = 1:numEns
    % Read in ADCIRC time-series water levels
    msg = sprintf('cpra_hydrograph_plotter.m: Reading %s', char(ensFileNames(i)));
    disp(msg);
    adcData(i) = read61nc(char(ensFileNames(i)));
    % Change from UTC to CDT by subtracting 5 hours
    % Adjust hydrograph based on offset
    for j = 1:adcData(i).NumStations
        adcData(i).STATION{j}.DATE = adcData(i).STATION{j}.DATE - (5/24);
        
        adcData(i).STATION{j}.DATA(adcData(i).STATION{j}.DATA < -999) = NaN;
        adcData(i).STATION{j}.DATA = adcData(i).STATION{j}.DATA / 0.3048; % convert m to ft
%         adcData(i).STATION{j}.DATA = adcData(i).STATION{j}.DATA;
%         adcData(i).STATION{j}.DATA = adcData(i).STATION{j}.DATA + offset;
    end
    msg = sprintf('cpra_hydrograph_plotter.m: Success reading %s', char(ensFileNames(i)));;
    disp(msg);
    
    if i == numEns
        % Load run.properties file
        % Utilize Matlab Map object data structure - similar to Python dict.
        % http://www.mathworks.com/help/matlab/ref/containers.map.html;jsessionid=e51d09845dede42c23d71ce2851a
        if exist(propFile{i})
            fid = fopen(propFile{i},'r');
            msg = sprintf('cpra_hydrograph_plotter.m: File %s was found.', propFile{i});
            disp(msg);
        else
            msg = sprintf('cpra_hydrograph_plotter.m FATAL ERROR: %s was NOT found.', propFile{i});
            disp(msg);
            %quit;
        end
        data = textscan(fid,'%s %s %s %s','delimiter',{':'});
        fclose(fid);
        keySet = strtrim(data{1});
        valueSet = data{2};
        M = containers.Map(keySet,valueSet);
        clear keySet valueSet data

        forecastValidStart = M('forecastValidStart');

        % Get the current date/time of the advisory
        % Subtract 5 hours to convert from UTC to CDT.
        dtAdvisory = datenum(forecastValidStart,'yyyymmddHHMMSS') - (5/24);
        clear keySet valueSet data M forecastValidStart
    end
end
% NEED TO ADD CHECK TO MAKE SURE THE NUMBER OF STAdfTIONS ARE THE SAME FOR
% EACH ENSEMBLE SIMULATION

% Get the start and end date of the ADCIRC simulation and round off
% Used for plotting purposes and grabbing USACE gage data
% sdate = round(adcData(useEnsemble).STATION{1}.DATE(1));
sdate = adcData(useEnsemble).STATION{1}.DATE(1);
sdate = floor(sdate);
edate = round(adcData(useEnsemble).STATION{1}.DATE(length(adcData(useEnsemble).STATION{1}.DATE)));
if (overrideedate)
    edate = edate_final;
end

%datetime(adcData(1).STATION{1}.DATE(1),'ConvertFrom','datenum')
            
%% 
ax = gca;
fig = gcf;

%% 
for f = 1:adcData(1).NumStations
    
    legendCount = 1;
  
    % This will provide you with the index in the cpraStationNames vector
    % assigned earlier in the script
    cpraStationIndex = find(~cellfun(@isempty,strfind(cpraStationNames,adcData(1).STATION{f}.NAME)));
    
    % Check if cpraStationIndex was found -> If not, then cycle 
    % to next iteration.
    if isempty(cpraStationIndex) == 1
        msg = sprintf('cpra_hydrograph_plotter.m: NON-FATAL WARNING: cpra_hydrograph_plotter.m: Could not find %s',adcData(1).STATION{f}.NAME);
        %disp(msg);
        continue;
    end
    
    gageAgency = char(fstationsSplit(cpraStationIndex,1));
    gageID = char(fstationsSplit(cpraStationIndex,2));
    
    % Quick fix
    if f == 243
        gageAgency = gageAgency(1,:);
        gageID = gageID(1,:);
    end 
   
    if strcmp(gageAgency,'USGS')
        % Get USGS water level data for station cpraStationIndex
        % If the USGS function fails, then create a dummy value to plot.
        try
            msg = sprintf('cpra_hydrograph_plotter.m: Finding gage data for USGS %s', gageID);
            disp(msg);
            if (overrideedate)
                wl = USGS_Service(gageID,'waterml,2.0','00065',datestr(sdate-3),datestr(edate),false);
            else
                wl = USGS_Service(gageID,'waterml,2.0','00065',datestr(sdate-3),datestr(dtAdvisory),false);
            end
            if isempty(wl) == 0 % Data was obtained
                msg = sprintf('cpra_hydrograph_plotter.m: Gage data for USGS %s was found!', gageID);
                disp(msg);
                oDataExist = 1;
                            
                % Adjust datum, if necessary
                wl(:,2) = wl(:,2) + datumConvMap(gageID);
                msg = sprintf('cpra_hydrograph_plotter.m: Adjusting datum to NAVD by %0.5f', datumConvMap(gageID));
                disp(msg);

                % Find the min and max observed water levels
                maxOWL = ceil(max(wl(:,2)));
                minOWL = floor(min(wl(:,2)));
            else
                msg = sprintf('cpra_hydrograph_plotter.m: NON-FATAL WARNING: Gage data for USGS %s was NOT found!', gageID);
                disp(msg);
                wl(1,1) = sdate; wl(1,2) = -20; % Create a fake point for legend purposes
                oDataExist = 0;
            end
        catch ME
            % USGS is down... :(
            msg = sprintf('cpra_hydrograph_plotter.m: NON-FATAL WARNING: Gage data for USGS %s was NOT found!', gageID);
            disp(msg);
            % Create some dummy values so the legned can still be plotted
            wl(1,1) = sdate;
            wl(1,2) = -20;
            maxOWL = 1;
            minOWL = 0;
            oDataExist = 0;
        end
    elseif strcmp(gageAgency,'USACE')
        % Get USACE water level data for station cpraStationIndex
        % If the rivergages function fails, then create a dummy value to plot.
        try
            msg = sprintf('cpra_hydrograph_plotter.m: Finding gage data for USACE %s', gageID);
            disp(msg);
            if (overrideedate)
                wl=rivergages2(gageID,datestr(sdate-3),datestr(edate),'HG');
            else
                wl=rivergages2(gageID,datestr(sdate-3),datestr(dtAdvisory),'HG');
            end
            
            % Plot USACE Observations
            if isempty(wl) == 0 % Data was obtained
                msg = sprintf('cpra_hydrograph_plotter.m: Gage data for USACE %s was found!', gageID);
                disp(msg);
                oDataExist = 1;
                
                % Adjust datum, if necessary
                wl(:,2) = wl(:,2) + datumConvMap(gageID);
                msg = sprintf('cpra_hydrograph_plotter.m: Adjusting datum to NAVD by %0.5f', datumConvMap(gageID));
                disp(msg);
                
                % Remove data points less than -99
                tidx = find(wl(:,2) < -99);
                wl(tidx,2) = NaN;
                               
                if strcmp(gageID(1,:),'76030') == 0
                    % Remove data points > 10 x the average
                    tidx = find(wl(:,2) > 10*mean(wl(:,2)));
                    wl(tidx,2) = NaN;
                else
                    tidx = find(wl(:,2) < -4);
                    wl(tidx,2) = NaN;
                end

                % Find the min and max observed water levels
                maxOWL = ceil(max(wl(:,2)));
                minOWL = floor(min(wl(:,2)));
            else
                msg = sprintf('cpra_hydrograph_plotter.m: NON-FATAL WARNING: Gage data for USACE %s was NOT found!', gageID);
                disp(msg);
                wl(1,1) = sdate; wl(1,2) = -20; % Create a fake point for legend purposes
                oDataExist = 0;
            end
        catch ME
            % USACE is down... :(
            msg = sprintf('cpra_hydrograph_plotter.m: NON-FATAL WARNING: Gage data for USACE %s was NOT found!', gageID);
            disp(msg);
            % Create some dummy values so the legned can still be plotted
            wl(1,1) = sdate;
            wl(1,2) = -20;
            maxOWL = 1;
            minOWL = 0;
            oDataExist = 0;
        end
    else
        msg = sprintf('cpra_hydrograph_plotter.m: Did not recognize %s %s',...
            gageAgency, gageID);
            disp(msg);
    end
        
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Remove bogus values from observations
    if strcmp(gageID(1,:),'76030') == 0
        if length(wl) > 2
            meanObs = mean(wl(:,2));
            for numObs = 2:length(wl)
                if ( abs(wl(numObs,2)  - meanObs)) > 2
                    wl(numObs,2) = NaN;
                    maxOWL = ceil(max(wl(:,2)));
                    minOWL = floor(min(wl(:,2)));
                end
            end
        end   
    end
    
    % Plot water levels as scatter points
    plotMe(legendCount) = scatter(wl(:,1),wl(:,2),50,'MarkerEdgeColor','black','Linewidth',1);hold on;
    legendCount = legendCount + 1;
    legendCell{1} = 'Gage Observations';
        
    %% 
% -------------------------------------------------------------------------
    
    % Get ADCIRC data from station f and loop through each available ensemble
    for i = 1:numEns

        % Load run.properties file
        % Utilize Matlab Map object data structure - similar to Python dict.
        % http://www.mathworks.com/help/matlab/ref/containers.map.html;jsessionid=e51d09845dede42c23d71ce2851a
        if exist(propFile{i})
            fid = fopen(propFile{i},'r');
            msg = sprintf('cpra_hydrograph_plotter.m: File %s was found.', propFile{i});
            disp(msg);
        else
            msg = sprintf('cpra_hydrograph_plotter.m FATAL ERROR: %s was NOT found.', propFile{i});
            disp(msg);
            %quit;
        end
        data = textscan(fid,'%s %s %s %s','delimiter',{':'});
        fclose(fid);
        keySet = strtrim(data{1});
        valueSet = data{2};
        M = containers.Map(keySet,valueSet);
        clear keySet valueSet data

        adcGrid = M('adcirc.gridname');
        advisory = M('advisory');
        enstorm = M('asgs.enstorm');
        forecastValidStart = M('forecastValidStart');
%         
%         % Get the current date/time of the advisory
%         % Subtract 5 hours to convert from UTC to CDT.
        dtAdvisory = datenum(forecastValidStart,'yyyymmddHHMMSS') - (5/24);
        
        if ~isKey(M,'stormname')
%             storm = 'NAM';
            storm = enstorm;
        else
            storm = M('stormname');
        end
        
        msg = sprintf('cpra_hydrograph_plotter.m: Success reading %s', propFile{i});
        disp(msg);

        dtformat = 'mmm. dd HH:MM AM';
        if strcmp(storm,enstorm)
            if strcmp(enstorm,'namforecast')
                legendCell{i+1} = strcat('NAM Cycle',' (',datestr(dtAdvisory, dtformat),' CDT)');  
            else
                legendCell{i+1} = strcat(enstorm,' (',datestr(dtAdvisory, dtformat),' CDT)');
            end
        else  
            legendCell{i+1} = char(strcat(enstorm,{' (Advisory '},advisory, {' '}, datestr(dtAdvisory, dtformat),' CDT{)}'));      
        end
        
        clear tempOffset;
        if autoOffset

            % Offset using the last observation date/time
            [ d, ix ] = min( abs(wl(end,1) - adcData(i).STATION{f}.DATE(:)));
            if length(wl(:,2)) < 2
                tempOffset = 0.0;
            elseif isnan(adcData(i).STATION{f}.DATA(1))
                tempOffset = 0.0;
%             elseif isnan(wl(ix,1))
%                 tempOffset = 0.0;
            else
                lenwl = length(wl);
                if isnan(wl(lenwl,2)) == 1
                    tempOffset = wl(lenwl-1,2) - adcData(i).STATION{f}.DATA(ix);
%                 if ( abs(wl(lenwl,2) - wl(lenwl-1,2)) > 2 )
%                     tempOffset = wl(lenwl-1,2) - adcData(i).STATION{f}.DATA(ix);
                else
                tempOffset = wl(end,2) - adcData(i).STATION{f}.DATA(ix);
                end
            end
            
            % Catch all
            if isnan(tempOffset)
                tempOffset = 0.0;
            end
            
            if strcmp(gageID,'76030')
                tempOffset = 0.001;
            end 
            if strcmp(gageID,'073802516')
                tempOffset = 0.0;
            end 

                        
            if tempOffset > 3.0
                msg = sprintf('cpra_hydrograph_plotter.m: ***WARNING - An offset > 3 ft (%f ft) is being applied.***', tempOffset);
                disp(msg);
            end
            
            msg = sprintf('cpra_hydrograph_plotter.m: An automatic offset of %f ft will be used', tempOffset);
            disp(msg);
            
            % Store offset used
            offsetMap(gageID) = tempOffset;
            fprintf(fid_offset_out, '%s\t%f\n',gageID,tempOffset);
            
            adcData(i).STATION{f}.DATA = adcData(i).STATION{f}.DATA + tempOffset;
            
        else 
            
            % Quick Fix
            if f==243
                adcData(i).STATION{f}.DATA = adcData(i).STATION{f}.DATA + ...
                    offsetMap('01280');
            else
                adcData(i).STATION{f}.DATA = adcData(i).STATION{f}.DATA + ...
                    offsetMap(gageID);
            end
            
        end
     
%         adcData(i).STATION{f}.DATA(adcData(i).STATION{f}.DATA < -999) = NaN;
        % Find min/max water surface elevation from ADCIRC result
        res = ~any(~isnan(adcData(i).STATION{f}.DATA(:)));
        if res == false
            msg = sprintf('cpra_hydrograph_plotter.m: ADCIRC data for %s - Storm %s - Advisory %s was found!',...
                adcData(i).STATION{f}.NAME, storm, advisory);
            disp(msg);
            mDataExist = 1;
            % Find min/max water surface elevation from ADCIRC result
%             maxMWL = ceil(max(adcData(i).STATION{f}.DATA / 0.3048));
%             minMWL = floor(min(adcData(i).STATION{f}.DATA / 0.3048));
            maxMWL = ceil(max(adcData(i).STATION{f}.DATA ));
            minMWL = floor(min(adcData(i).STATION{f}.DATA));
            % Only plot trigger for consensus track for current advisory
            if (i == useEnsemble)
%                 max4Trigger = max(adcData(i).STATION{f}.DATA / 0.3048);
                max4Trigger = max(adcData(i).STATION{f}.DATA);
            end
        else
            msg = sprintf('cpra_hydrograph_plotter.m: ADCIRC data for %s - Storm %s - Advisory %s was NOT found!',...
                adcData(i).STATION{f}.NAME, storm, advisory);
            disp(msg);
            mDataExist = 0;
            % Create some dummy values so the legned can still be plotted
            adcData(i).STATION{f}.DATE(1) = sdate;
            adcData(i).STATION{f}.DATE(2) = sdate+0.01;
            adcData(i).STATION{f}.DATA(1) = -20;
            adcData(i).STATION{f}.DATA(2) = -20;

            % Force max and min water level bounds
            maxMWL = 1;
            minMWL = 0;
        end
        
        % Plot ADCIRC Simulation
%         plot(adcData(i).STATION{f}.DATE,...
%             adcData(i).STATION{f}.DATA / 0.3048,...
%             'Linewidth',3,'color',colors(i,:))
        plotMe(legendCount) = plot(adcData(i).STATION{f}.DATE,...
            adcData(i).STATION{f}.DATA,...
            'Linewidth',3,'color',colors(i,:));
        legendCount = legendCount + 1;
    end
    
    minWL = min(minOWL,minMWL) - 1;
    maxWL = max(maxOWL,maxMWL) + 3;

%     if strcmp(gageID(1,:),'76560') == 1
%         maxWL = 10;
%         minWL = -1;
%     end
%     if strcmp(gageID(1,:),'08017118') == 1
%         maxWL = 12;
%         minWL = -1;
%     end
%     if strcmp(gageID(1,:),'01275') == 1
%         maxWL = 10;
%         minWL = 3;
%     end
    
    % Final bounds check...
    if minWL < -10
        minWL = -10;
    end
    if maxWL > 25
        maxWL = 25;
    end

    %%
    
    % Include some text stating that no observed gage data is available.
    if oDataExist == 0
        text(sdate-2.85,minWL + 1.5,'Gage observations are not available.','Interpreter','None');
    end
    % Include some text stating that no model data is available.
    % Removed on 09-18-2018 based on review from CPRA
%     if mDataExist == 0
%         text(sdate+2.5,minWL + 1.5,'Model result indicate location is dry.','Interpreter','None');
%     end

    %% 
% -----------------------------------------------------------------------
    % Find out if forecasted water level is above the trigger
    triggerL = false;
    triggerL2 = false;
    % Only plot trigger for consensus track for current advisory
    % This is why the index of adcData is useEnsemble
    % Quick Fix
    if f == 243
        cpraStationIndex = 27;
    end
    
    if strcmp(gageID,'85625')
        if (triggerMap(gageID) > 0) && (max4Trigger >= triggerMap(gageID))
            triggerL = true;
            % Find the index at which this occurs. Use the first time it
            % occurs.
            idx = find(adcData(useEnsemble).STATION{f}.DATA > triggerMap(gageID));
            if isempty(idx) == 0
                trigDate = adcData(useEnsemble).STATION{f}.DATE(idx(1));
                % Plot gate closure trigger
                plotMe(legendCount) = plot([trigDate-0.5 trigDate+0.5],[triggerMap(gageID) triggerMap(gageID)],...
                    '-', 'color', 'green','Linewidth',2.0);
                legendCount = legendCount + 1;
                if gageID == '85625'
                    triggerText = strcat('Water Level Trigger (',num2str(triggerMap(gageID),'%4.1f'),' ft), Orleans, 17th');
                else
                    triggerText = strcat('Water Level Trigger (',num2str(triggerMap(gageID),'%4.1f'),' ft)');
                end
                llc = length(legendCell);
                legendCell{llc+1} = triggerText;
                
                plot([trigDate trigDate],[minWL maxWL],...
                    '--', 'color', 'black','Linewidth',0.75);

                tt = text(trigDate-0.1,maxWL,strcat(datestr(trigDate,'HH:MM'),' CDT'));
                tt(1).HorizontalAlignment = 'right';
                set(tt,'Rotation',90);
            end
        end
        if (triggerMap2(gageID) > 0) && (max4Trigger >= triggerMap2(gageID))
            triggerL2 = true;
            % Find the index at which this occurs. Use the first time it
            % occurs.
            idx = find(adcData(useEnsemble).STATION{f}.DATA > triggerMap2(gageID));
            if isempty(idx) == 0
                trigDate = adcData(useEnsemble).STATION{f}.DATE(idx(1));
                % Plot gate closure trigger
                plotMe(legendCount) = plot([trigDate-0.5 trigDate+0.5],[triggerMap2(gageID) triggerMap2(gageID)],...
                    '-', 'color', 'green','Linewidth',2.0);
                legendCount = legendCount + 1;
                if gageID == '85625'
                    triggerText2 = strcat('Water Level Trigger (',num2str(triggerMap2(gageID),'%4.1f'),' ft), London');
                else
                    triggerText2 = strcat('Water Level Trigger (',num2str(triggerMap2(gageID),'%4.1f'),' ft)');
                end
                llc = length(legendCell);
                legendCell{llc+1} = triggerText2;
                
                plot([trigDate trigDate],[minWL maxWL],...
                    '--', 'color', 'black','Linewidth',0.75);
                tt = text(trigDate-0.1,maxWL,strcat(datestr(trigDate,'HH:MM'),' CDT'));
                tt(1).HorizontalAlignment = 'right';
                set(tt,'Rotation',90);
            end
        end   
        
    else
        if (triggerMap(gageID) > 0) && (max4Trigger >= triggerMap(gageID))
            triggerL = true;
            % Find the index at which this occurs. Use the first time it
            % occurs.
            idx = find(adcData(useEnsemble).STATION{f}.DATA > triggerMap(gageID));
            if isempty(idx) == 0
                trigDate = adcData(useEnsemble).STATION{f}.DATE(idx(1));
                % Plot gate closure trigger
                plotMe(legendCount) = plot([trigDate-0.5 trigDate+0.5],[triggerMap(gageID) triggerMap(gageID)],...
                    '-', 'color', 'green','Linewidth',2.0);
                legendCount = legendCount + 1;
                triggerText = strcat('Water Level Trigger (',num2str(triggerMap(gageID),'%4.1f'),' ft)');
                legendCell{i+2} = triggerText;

                plot([trigDate trigDate],[minWL maxWL],...
                    '--', 'color', 'black','Linewidth',0.75);
                tt = text(trigDate-0.1,maxWL,strcat(datestr(trigDate,'HH:MM'),' CDT'));
                tt(1).HorizontalAlignment = 'right';
                set(tt,'Rotation',90);
            end
        end
    end
    
    %% 
% -------------------------------------------------------------------------
    % Plot advisory date/time and vertical line
    plot([dtAdvisory dtAdvisory],[minWL maxWL],...
        '--', 'color', 'black','Linewidth',0.75);
    at = text(dtAdvisory-0.1,maxWL,...
        strcat(datestr(dtAdvisory,'HH:MM'),' CDT'));
    at(1).HorizontalAlignment = 'right';
    set(at,'Rotation',90);
    
    % Plot horizonal line at the top
    plot([sdate-3 edate+1],[maxWL maxWL],...
        '-', 'color', 'black','Linewidth',1.0);
    
    % Plot vertical line to close off the plot
    plot([edate+1 edate+1],[minWL maxWL],...
        '-', 'color', 'black','Linewidth',1.0);
     
    %% 
% -------------------------------------------------------------------------

% Setup Axis Properties
    % X-Axis Properties
    xlim([sdate-3,edate+1]);
    ax.XAxis.TickValues = [sdate-3:1:edate+1];
    ax.XAxis.MinorTickValues = [sdate-3:0.25:edate+1];
    datetick('x','mmm-dd HH:MM','keeplimits','keepticks')
    ax.XMinorTick = 'on';
    ax.XTickLabelRotation = 90;
    ax.FontSize = 10;
    xlabel('Date (CDT)');
     
    % Y-Axis Properties
    ylim([minWL,maxWL])
    if (maxWL - minWL) < 10
        ax.YAxis.TickValues = [minWL:1:maxWL];
        ax.YMinorTick = 'on';
        ax.YAxis.MinorTickValues = [minWL:0.5:maxWL];
    else
        ax.YAxis.TickValues = [minWL:2:maxWL];
        ax.YMinorTick = 'on';
        ax.YAxis.MinorTickValues = [minWL:1:maxWL];
    end
    ylabel('Water Level (ft, NAVD88)');
    
    grid on;
    %ax.YMinorGrid = 'on';
    
    %% 
% -------------------------------------------------------------------------
    
    % Arrange plot titles accordingly for NAM/daily runs vs STORM runs
    if (strcmp(storm,enstorm))
        title1 = strcat({'NAM Forecast Cycle '},M('currentcycle'),{' Issued on '},...
            datestr(dtAdvisory,dtformat),{' CDT'},{' - grid: '},adcGrid);
    else
        title1 = strcat({'Storm: '},storm,{' - Advisory: '},advisory,{' Issued on '},...
            datestr(dtAdvisory,dtformat),{' CDT'},{' - grid: '},adcGrid);
    end
     
	if (strcmp(cpraStationNames(cpraStationIndex),'Western Tie-In (WBV7274)') == 1)
		title2 = strcat('Western Tie-In (WBV-72/74)  -  USACE Gage ID:',stations(cpraStationIndex),...
              {' - Datum Converstion to NAVD88: '},num2str(datumConvMap(gageID),'%0.2f'),{' ft'});
	elseif (strcmp(cpraStationNames(cpraStationIndex),'Bayou Segnette Closure (WBV162)') == 1)
		title2 = strcat('Bayou Segnette Closure (WBV-16.2) -  USACE Gage ID:',stations(cpraStationIndex),...
              {' - Datum Converstion to NAVD88: '},num2str(datumConvMap(gageID),'%0.2f'),{' ft'});
	else
		title2 = strcat(cpraStationNames(cpraStationIndex),{'  -  '},gageAgency,{' Gage ID: '},stations(cpraStationIndex),...
            {' - Datum Converstion to NAVD88: '},num2str(datumConvMap(gageID),'%0.2f'),{' ft'});
    end
        
    text(0,1.07,title1,'Units','normalized','Interpreter','None');
    text(0,1.03,title2,'Units','normalized','Interpreter','None');
    
%     legend(plotMe,legendCell,'Location','northeast');
    legend(plotMe,legendCell,'Location','northwest');
%     legend(plotMe,legendCell,'Location','southwest');
       
    % Override some defaults
    set(gca,'LineWidth',1,'TickLength',[0.015 0.015]);
    set(gca,'FontSize',12,'FontWeight','bold');
    
    hold off;
    
    % Plot Figure
    fig.PaperUnits = 'inches';
    fig.PaperPosition = [0 0 12.5 6.0];
    
    fname = char(strcat('WSE_',adcData(i).STATION{f}.NAME,'_',gageAgency,'_',gageID));
    print(fname,'-dpng','-r200');
    
    clear legendCell plotMe;
    
    msg = sprintf('cpra_hydrograph_plotter.m: Station %s jpeg success.\n', stations{1,cpraStationIndex});
    disp(msg);
    
    clear wl;
end

fclose(fid_offset_out); % close file

msg = sprintf('cpra_hydrograph_plotter.m: END cpra_hydrograph_plotter.m %s CDT',...
    datestr(datetime('now','TimeZone','America/Chicago'),'yyyymmdd HH:MM'));
disp(msg);

%clear all; close all;
