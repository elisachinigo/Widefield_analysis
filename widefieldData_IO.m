%% Script for Elisa - I/O for widefield data 

%%%%%%%%%%%%%%%%%%%%%%
%% Basic I/O
%%%%%%%%%%%%%%%%%%%%%%
%% Variables of interest 

% 1. pathsToSessionsAll.mat
    % Col 1: path to mouse session (change drive when referencing)
    % Col 2: Mouse number
    % Col 3: 1 headfixed; 2 homecage
    % Col 4: list of deconvolved video numbers within session folder
    
% 2. allROIsDOWNDetected.mat = SlowWavesWF when loaded
    % This is a struct w fields 'ints' and 'vidThreshDOWNAll'. This exists for each mouse at the 'CumulativeVars' level. 
    % SlowWavesWF.ints.DOWN = cell array dims pixels (20500) x total number videos for mouse; time is @ level cumulative vars
    % SlowWavesWF.intsUP = same as above but UP states
    % SlowWavesWF.ints.useDOWN = 1 if detection good, 0 if messed up (some pixels had extra DOWNs; need to deal w later but for now just ignored when happend. Use 1 only.
    % SlowWavesWF.ints.useUP = same but UP
    % SlowWavesWF.vidThreshDOWNAll = image of threshold used for each vid
    % (dims: pixels x pixels x video). Note - use (:,:,2:end); first frame is blank/does not correspond to any video

% 3. brainMaskStruct.mat = brainMaskStruct when loaded
    % struct with info about how the videos were warped to fit Allen CCF.
    % You need this struct to move between: "linear indices" 
    % - there are 20500 brain pixels, and widefield.data is stored in this format - pixels (20500) x time. 
    % If you plot this it will look like nothing, it must be re-constructed to be in 2D / pixels to their 2d location, 
    % bc the dead pixels are dropped from the flattened images. 
    % You therefore need the linear index of each pixel to "expand" the flattened image. I do this below in one of the cells.

% 4. HBCorrect.p5to12.UP100.MUAm53_norm0-1.deconvolve.widefield.mat = widefield when loaded
    % In every session folder, there will be a widefield struct with this
    % name. These are the final videos (hemo corrected, fit to allen CCF, deconv) used for the paper. The struct will have fields: 
    % widefield.data = pixels x time (upsampled to 100 Hz)
    % widefield.timestamps = timestamps (sec)
    % widefield.deconv = deconv params
    % widefield.WarpData = info used for warping data to allen CCF
    % widefield.channels = channels used (could be 2 or 3 wavelength)
    % widefield.processingNotes = what was done to the video 
    
% 5. SlowWavesWFVid.mat = SlowWavesWFVid when loaded
    % In every video folder within a given session. Same format as
    % allROIsDOWNDetected.mat file, but time here is wrt that session time.
    % Useful if looking at WF data within a given session; but otherwise
    % use @ level mouse variable.
    
%% Fxs of interest 

% 1. ExpandVid - moves from 2d to 3d wf data; see fx for description 
% 2. TraceROIs - see fx for description
% 3. LoopImage - makes video; see fx for description 
% 4. sub2ind_brainMask - does 2d to 1d conversion of indices
% 5. reconstructData - reconstructs wf data from U and VS; eg [~,data] = reconstructData(widefield.U,widefield.VS);

%% Global parameters/variables:

% Parms 
basePathAllData = fullfile('/Users', 'elisachinigo', 'Documents', 'Widefield_Data'); % basepath for entire dataset;
vidname = 'HBCorrect.p5to12.UP100.MUAm53_norm0-1.deconvolve.widefield'; % vid @ final stage preprocessing; used in analysis. Widefield data has been: hemodynamically corrected, upsampled, filtered, deconvolved
ManualSelection = true; % specifies which sessions of set all sessions to analyze. true = manually select sessions via GUI; alt specify rows in pathsToSessionsAll to be analyzed explicitly to skip GUI 

% Vars 
load(fullfile(basePathAllData,'pathsToSessionsAll.mat')); % list of all sessions all mice; column 4 = list of videos with ch525 data
load(fullfile(basePathAllData,'brainMaskStruct.mat')); % struct generated when fit data to AllenCCF, used for transforming data between pixels x time matrix (excludes null pixels (outside of brain) to reduce data size) and pixels x pixels x time 3d matrix (includes null pixels so is square).
mice4eachSesh=[pathsToSessionsAll{:,2}]; % keep duplicates to find correct rows in pathsToSessionsAll var
mice = unique(mice4eachSesh);
allbasePaths = {pathsToSessionsAll{1:end-1,1}}; % - 1 is here to remove empty row @ end

%% Identified UP/DOWN in WF @ level mouse:

mouseUse = 47; % use any mouse
load(fullfile(basePathAllData, ['mouse' num2str(mouseUse)], 'CumulativeVars', 'WidefieldROIs','allROIsDOWNDetected')); % takes ~3 min to load

% EG
figure
imagesc(SlowWavesWF.vidThreshDOWNAll(:,:,2))
title(['Thresh for vid 1, mouse' num2str(mouseUse)])

% EG: 'Plot dist UP/DOWN dwell times for pixel 2 across all videos for mouse 47'
pixel = 2;
vids = 1:size(SlowWavesWF.ints.DOWN,2); % combine0 all vids

DOWN = {SlowWavesWF.ints.DOWN{pixel,vids}}'; % DOWN state intervals for pixel 1
DOWN = vertcat(DOWN{:}); % vertical concatenation
DOWNdur = DOWN(:,2)-DOWN(:,1); 
DOWNdur(DOWNdur<0)=[]; % get rid of negative durations - from mismatched DOWN start/stop

UP = {SlowWavesWF.ints.UP{pixel,vids}}';
UP = vertcat(UP{:}); 
UPdur = UP(:,2)-UP(:,1); 
UPdur(UPdur<0)=[]; % get rid of negative durations - from mismatched UP start/stop

figure
hold on
histogram(DOWNdur,50,'faceAlpha',.1)
histogram(UPdur,50,'faceAlpha',.1)
title(['Hist UP/DOWN dwell times pixel ' num2str(pixel) ' vids ' num2str(vids) '; mouse' num2str(mouseUse)])

%% Identify where each pixel is (~ 1min):

% Load example widefield video
mouseUse = 47;
sessionUse = 09102020;
vidUse = 4; 
load(fullfile(basePathAllData,['mouse' num2str(mouseUse)],'Conv', num2str(sessionUse),['Processedvid' num2str(vidUse)],vidname)); 

%% Expand vid:
frameStart = 1;
frameEnd = 1000;
vid=ExpandVid(widefield.data,brainMaskStruct.WarpData.lin_brainMask, size(brainMaskStruct.WarpData.brainMask), frameStart, frameEnd);
edges = brainMaskStruct.resizedDorsalMap.edgeOutline;

% Look at vid 
% use fx LoopImage to save a video file; bones of it below
figure
for i=1:size(vid,3)
    drawnow
    imagesc(vid(:,:,i),'alphaData',brainMaskStruct.WarpData.brainMask)
    caxis([-.2 .2])
    % Plot edges
    hold on
    if ~isempty(edges)
        for p = 1:length(edges)
            plot(edges{p}(:, 2), edges{p}(:, 1),'w');
        end
    end
    
    pause(1/5)
end
title('Deconv wf data example video')

%% Move from collapsed linear <-> 2d brain index:
% Use fx sub2ind_brainMask to go from 2D to 1D
% EG
% Use single pixel or RSC time series 
rscROI = [158 23]; % for now just use single pixel, will be in approx same area 
rscROILinear = sub2ind_brainMask(rscROI,brainMaskStruct);
motorROI = [45 58]; % for now just use single pixel, will be in approx same area 
motorROILinear = sub2ind_brainMask(motorROI,brainMaskStruct);

% Confirm look the same
figure
subplot 411
plot(widefield.timestamps(frameStart:frameEnd),squeeze(vid(rscROI(1),rscROI(2),:)),'linewidth',1.2)
axis tight
title('RSC pixel 2d')
subplot 412
plot(widefield.timestamps(frameStart:frameEnd),widefield.data(rscROILinear,frameStart:frameEnd),'linewidth',1.2);axis tight; box off
axis tight
title('RSC pixel 1d')
subplot 413
plot(widefield.timestamps(frameStart:frameEnd),squeeze(vid(motorROI(1),motorROI(2),:)),'linewidth',1.2)
axis tight
title('M1 pixel 2d')
subplot 414
plot(widefield.timestamps(frameStart:frameEnd),widefield.data(motorROILinear,frameStart:frameEnd),'linewidth',1.2);axis tight; box off
axis tight
title('M1 pixel 1d')
xlabel('time(s)')

%% Identify the center pixel for each brain region (center of mass):

edges = brainMaskStruct.resizedDorsalMap.edgeOutline;
brain_mask = brainMaskStruct.WarpData.brainMask;

% Calculate the center of mass of each region
numRegions = length(edges) - 1;  % Number of regions in the edges
centroids = zeros(numRegions, 2);  % Preallocate a 2D array for centroids
for i = 1:size(edges, 1)-1
    if ~isempty(edges)
        for p = 1:length(edges)-1

            % Calculate the centroid:
            x_coords = edges{p}(:, 2);
            y_coords = edges{p}(:, 1);

            % Create a binary mask for the region inside the boundary
            mask = poly2mask(x_coords, y_coords, size(brain_mask, 1), size(brain_mask, 2));

            % Calculate the centroid using regionprops on the filled mask
            stats = regionprops(mask, 'Centroid');
            centroid = stats.Centroid;
            centroids(p,:) = centroid;  % Store centroid
        end
    end
end

disp(centroids)

%% Plot the center pixels on top of the region outlines:

fig =figure;
hold on;
set(gcf, 'Position', [100, 100, 600, 600]);

imshow(brain_mask, [], 'InitialMagnification', 'fit');
colormap gray;
alpha(0.5);

for i = 1:numRegions
    if ~isempty(edges{i}) % Extract boundary coordinates:
        x_coords = edges{i}(:, 2); % Horizontal (columns)
        y_coords = edges{i}(:, 1); % Vertical (rows)
        
        mask = poly2mask(x_coords, y_coords, size(brain_mask, 1), size(brain_mask, 2));
        stats = regionprops(mask, 'Centroid');
        
        if ~isempty(stats)
            centroid = round([stats.Centroid]); 
            
            plot(x_coords, y_coords, 'g-', 'LineWidth', 2); % boundary
            plot(centroid(1), centroid(2), 'r*', 'MarkerSize', 8); % centroid
            
            if i <= length(brainMaskStruct.resizedDorsalMap.labels)
                regionName = brainMaskStruct.resizedDorsalMap.labels{i}; 
                text(centroid(1) + 2, centroid(2), regionName, 'Color', 'blue', 'FontSize', 10, 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
            end
        end
    end
end

title('Center Pixels Overlaid on Region Outlines', 'FontSize', 16, 'FontWeight', 'bold');
legend('Region Boundary', 'Region Centroid', 'Location', 'bestoutside');
set(gca, 'XColor', 'none', 'YColor', 'none');
set(gcf, 'Color', 'w');
hold off;

% Specify save directory
saveDir = fullfile('/Users', 'elisachinigo', 'Documents', 'Widefield_Data'); % basepath for entire dataset;

% Or save as PDF with higher quality
exportgraphics(fig, fullfile(saveDir, 'cortex_regions_with_centroid.pdf'), 'Resolution', 300)

%% Convert 2D center coordinates to 1D linear index for each brain region:

edges = brainMaskStruct.resizedDorsalMap.edgeOutline;
labels = brainMaskStruct.resizedDorsalMap.labels; 
brain_mask = brainMaskStruct.WarpData.brainMask;

numRegions = length(edges); 
regionCenters = struct(); 
centroids = NaN(numRegions, 2);

for i = 1:numRegions
    if ~isempty(edges{i})
        x_coords = edges{i}(:, 2); % X-coordinates (columns)
        y_coords = edges{i}(:, 1); % Y-coordinates (rows)
        
        % Create a binary mask for the region inside the boundary
        mask = poly2mask(x_coords, y_coords, size(brain_mask, 1), size(brain_mask, 2));
        stats = regionprops(mask, 'Centroid'); % Calculate the centroid using regionprops
        
        if ~isempty(stats)
            centroid = stats.Centroid;
            centroids(i, :) = centroid; 
            sanitizedRegionName = strrep(labels{i}, '-', '_');
            regionCenters.(sanitizedRegionName) = centroid;
        end
    end
end

disp('Region Centers Structure:');
disp(regionCenters);

%% Convert centroids to linear indices
regionLinearIndices = struct();

% Swap x and y coordinates if needed
swappedCentroids = [centroids(:, 2), centroids(:, 1)]; % Swap x and y to match mask orientation

for i = 1:numRegions
    sanitizedRegionName = strrep(labels{i}, '-', '_'); % Sanitize region names

    if ~isempty(swappedCentroids(i, :)) && ~any(isnan(swappedCentroids(i, :)))
        roundedCentroid = round(swappedCentroids(i, :));

        % Clip coordinates to valid ranges
        roundedCentroid(1) = max(1, min(size(brainMaskStruct.WarpData.brainMask, 1), roundedCentroid(1))); % Clip y-axis
        roundedCentroid(2) = max(1, min(size(brainMaskStruct.WarpData.brainMask, 2), roundedCentroid(2))); % Clip x-axis

        % Convert to linear index using sub2ind_brainMask
        linearIndex = sub2ind_brainMask(roundedCentroid, brainMaskStruct);

        if ~isnan(linearIndex) && ~isempty(linearIndex)
            regionLinearIndices.(sanitizedRegionName) = linearIndex;
        end
    end
end

disp('Region Linear Indices:');
disp(regionLinearIndices);

figure;
imshow(brainMaskStruct.WarpData.brainMask, []);
hold on;
plot(swappedCentroids(:, 2), swappedCentroids(:, 1), 'r*'); % Plot swapped centroids
title('Centroids Overlaid on Brain Mask');
%% 

%% Extract UP and DOWN durations for the central pixel of each brain region
upDurations = struct();
downDurations = struct();

for i = 1:numRegions
    regionName = labels{i};
    sanitizedRegionName = strrep(regionName, '-', '_'); 

    if isfield(regionLinearIndices, sanitizedRegionName)
        pixelIndex = regionLinearIndices.(sanitizedRegionName);

        if ~isempty(pixelIndex) && ~isnan(pixelIndex)
            vids = 1:size(SlowWavesWF.ints.DOWN, 2); % List of videos

            % Extract DOWN state intervals
            DOWN = {SlowWavesWF.ints.DOWN{pixelIndex, vids}}';
            DOWN = vertcat(DOWN{:}); % Combine intervals across videos
            DOWNdur = DOWN(:, 2) - DOWN(:, 1); % Calculate durations
            DOWNdur(DOWNdur < 0) = []; % Remove invalid durations
            downDurations.(sanitizedRegionName) = DOWNdur; % Store DOWN durations

            % Extract UP state intervals
            UP = {SlowWavesWF.ints.UP{pixelIndex, vids}}';
            UP = vertcat(UP{:}); % Combine intervals across videos
            UPdur = UP(:, 2) - UP(:, 1); % Calculate durations
            UPdur(UPdur < 0) = []; % Remove invalid durations
            upDurations.(sanitizedRegionName) = UPdur; % Store UP durations
        end
    end
end

disp('UP and DOWN durations for each region.');
disp('UP Durations:');
disp(upDurations);
disp('DOWN Durations:');
disp(downDurations);

%% Plot Histogram of UP and DOWN State Durations (Probability Density vs Durations)

outputFile= fullfile('/Users', 'elisachinigo', 'Documents', 'Widefield_Data','single_pixel_Duration_Distribution_histo.pdf'); % where to save the figure

figures = [];

% Edges for probability density plots (logarithmic bins in seconds)
edges = 10.^(0:0.13:8) / 1000;
upDownDurations = struct();

for i = 1:length(labels)
    regionName = labels{i};
    sanitizedRegionName = strrep(regionName, '-', '_');
    
    if isfield(upDurations, sanitizedRegionName) && isfield(downDurations, sanitizedRegionName)
        UPdur = upDurations.(sanitizedRegionName);
        DOWNdur = downDurations.(sanitizedRegionName);
        
        if ~isempty(UPdur) && ~isempty(DOWNdur)
            fig = figure('Name', ['Region: ', regionName], 'NumberTitle', 'off', 'Color', 'w', 'Position', [100, 100, 800, 600]);
            hold on;

            % DOWN durations probability density
            [N_down, edges_down] = histcounts(DOWNdur, edges, 'Normalization', 'probability');
            histogram('BinEdges', edges_down, 'BinCounts', N_down, 'Normalization', 'probability', ...
                'FaceColor', 'r', 'EdgeColor', 'r', 'FaceAlpha', 0.5, 'DisplayName', 'DOWN durations');

            % UP durations probability density
            [N_up, edges_up] = histcounts(UPdur, edges);
            histogram('BinEdges', edges_up, 'BinCounts', N_up, 'Normalization', 'probability', ...
                'FaceColor', 'b', 'EdgeColor', 'b', 'FaceAlpha', 0.5, 'DisplayName', 'UP durations');

            % Plot mean and median lines
            xline(geomean(DOWNdur(DOWNdur>0)), '--r', 'LineWidth', 1.5, 'DisplayName', ['DOWN geomean (' num2str(geomean(DOWNdur), '%.2f') 's)']);
            xline(mean(DOWNdur), ':r', 'LineWidth', 1.5, 'DisplayName', ['DOWN mean (' num2str(mean(DOWNdur), '%.2f') 's)']);
            xline(geomean(UPdur(UPdur>0)), '--b', 'LineWidth', 1.5, 'DisplayName', ['UP geomean (' num2str(geomean(DOWNdur), '%.2f') 's)']);
            xline(mean(UPdur), ':b', 'LineWidth', 1.5, 'DisplayName', ['UP mean (' num2str(mean(UPdur), '%.2f') 's)']);

            title(['UP and DOWN State Durations for Region ', regionName], 'FontSize', 14, 'FontWeight', 'bold');
            xlabel('Duration (s)', 'FontSize', 12);
            ylabel('Probability Density', 'FontSize', 12);
            
            % x-axis to logarithmic scale
            set(gca, 'XScale', 'log');
            xlim([0.01, 100]); 
            xticks([0.01, 0.02, 0.03, 0.1, 1, 10, 100]);
            xticklabels({'0.01', '0.02','0.03','0.1', '1', '10', '100'});

            grid on;
            legend('show', 'Location', 'northeast');
            hold off;

            upDownDurations.(sanitizedRegionName).UP = UPdur;
            upDownDurations.(sanitizedRegionName).DOWN = DOWNdur;

            figures = [figures, fig];
        end
    end
end

% Export all figures to a single PDF
if ~isempty(figures)
   for i = 1:length(figures)
       exportgraphics(figures(i), outputFile, 'Append', true);
       disp(['Figure for Region ' labels{i} ' saved to PDF.']);
   end
end
%% figure;
histogram(DOWNdur, 200);  % 100 is number of bins, adjust as needed
xlabel('Duration (s)');
ylabel('Count');

%% Kernel Density Estimation (KDE) Curves

outputFile = fullfile('/Volumes', 'Extreme_SSD', 'RESEARCH', 'TPCN', 'Widefield_data', 'UP_DOWN_Duration_Distribution_Curves.pdf');
figures = [];

% Logarithmic edges for x-axis
edges = 10.^(0:0.13:8) / 1000;

for i = 1:length(labels)
    regionName = labels{i};
    sanitizedRegionName = strrep(regionName, '-', '_'); 
    
    if isfield(upDurations, sanitizedRegionName) && isfield(downDurations, sanitizedRegionName)
        UPdur = upDurations.(sanitizedRegionName);
        DOWNdur = downDurations.(sanitizedRegionName);
        
        UPdur = UPdur(UPdur > 0);
        DOWNdur = DOWNdur(DOWNdur > 0);

        if ~isempty(UPdur) && ~isempty(DOWNdur)
            fig = figure('Name', ['Region: ', regionName], 'NumberTitle', 'off', 'Color', 'w', 'Position', [100, 100, 800, 600]);
            hold on;
            
            % KDE for DOWN durations 
            bw_down = 1.06 * std(DOWNdur) * length(DOWNdur)^(-1/5); % Silverman's Rule of Thumb
            [f_down, x_down] = ksdensity(DOWNdur, 'Bandwidth', bw_down); 
            plot(x_down, f_down, 'r-', 'LineWidth', 1.5, 'DisplayName', 'DOWN Duration KDE');
            
            % KDE for UP durations 
            bw_up = 1.06 * std(UPdur) * length(UPdur)^(-1/5); % Silverman's Rule of Thumb
            [f_up, x_up] = ksdensity(UPdur, 'Bandwidth', bw_up);
            plot(x_up, f_up, 'b-', 'LineWidth', 1.5, 'DisplayName', 'UP Duration KDE');
            
            % Mean and median for DOWN durations
            xline(mean(DOWNdur), '--r', 'LineWidth', 1.5, 'DisplayName', ['DOWN Mean (' num2str(mean(DOWNdur), '%.2f') ' s)']);
            xline(median(DOWNdur), ':r', 'LineWidth', 1.5, 'DisplayName', ['DOWN Median (' num2str(median(DOWNdur), '%.2f') ' s)']);
            
            % Mean and median for UP durations
            xline(mean(UPdur), '--b', 'LineWidth', 1.5, 'DisplayName', ['UP Mean (' num2str(mean(UPdur), '%.2f') ' s)']);
            xline(median(UPdur), ':b', 'LineWidth', 1.5, 'DisplayName', ['UP Median (' num2str(median(UPdur), '%.2f') ' s)']);
            
            title(['KDE of UP and DOWN Durations for Region ', regionName], 'FontSize', 14, 'FontWeight', 'bold');
            xlabel('Duration (s)', 'FontSize', 12);
            ylabel('Density', 'FontSize', 12);
            
            set(gca, 'XScale', 'log');
            xlim([0.01, 100]);
            xticks([0.01, 0.1, 1, 10, 100]);
            xticklabels({'0.01', '0.1', '1', '10', '100'});
            
            legend('show', 'Location', 'northeast');
            grid on;
            hold off;
            
            figures = [figures, fig];
        end
    end
end

% if ~isempty(figures)
%     try
%         exportgraphics(figures(1), outputFile);
%         disp('First figure saved to PDF.');
%         
%         for i = 2:length(figures)
%             exportgraphics(figures(i), outputFile, 'Append', true);
%             disp(['Figure ' num2str(i) ' saved to PDF.']);
%         end
% end

%% Save all the data including upDurations, downDurations, and upDownDurations to a .mat file
save('/Volumes/Extreme_SSD/RESEARCH/TPCN/Widefield_data/upDownDurationsData.mat', 'upDurations', 'downDurations', 'upDownDurations');

%% Stacked Bar Plot: Probability Density of Time Spent in UP and DOWN States

outputFile = fullfile('/Volumes', 'Extreme_SSD', 'RESEARCH', 'TPCN', 'Widefield_data', 'Improved_UpDown_ProbabilityDensity.pdf');
barData = [normalizedUpStateDensity; normalizedDownStateDensity]';

figure;
hold on;
b = bar(barData, 'stacked');

b(1).FaceColor = [0.9, 0.4, 0.4]; % Red for UP state
b(2).FaceColor = [0.4, 0.7, 0.9]; % Blue for DOWN state

ylabel('Probability Density (%)', 'FontSize', 12, 'FontWeight', 'bold');
xticks(1:numRegions);
xticklabels(regionLabels);
xtickangle(45); 
ylim([0, 1]); 
yticks(0:0.2:1);
yticklabels(arrayfun(@(x) sprintf('%d', x * 100), yticks, 'UniformOutput', false));

grid on;
set(gca, 'YGrid', 'on', 'GridLineStyle', '--', 'GridColor', [0.8, 0.8, 0.8], 'GridAlpha', 0.5);

title('Probability Density of Time Spent in UP and DOWN States for Each Brain Region', 'FontSize', 14, 'FontWeight', 'bold');
legend({'UP State', 'DOWN State'}, 'Location', 'southoutside', 'Orientation', 'horizontal', 'FontSize', 10);

set(gcf, 'Position', [100, 100, 1400, 600]);
set(gcf, 'PaperUnits', 'inches');
set(gcf, 'PaperPosition', [0, 0, 14, 7]); 
set(gcf, 'PaperSize', [14, 7]); 
print(gcf, outputFile, '-dpdf', '-bestfit'); 

hold off;

%% Kolmogorov-Smirnov Test: KS Distances for UP and DOWN Durations

regionLabels = brainMaskStruct.resizedDorsalMap.labels;
numRegions = length(regionLabels);

% Preallocate matrices for KS distances
ksDistancesUP = zeros(numRegions, numRegions);
ksDistancesDOWN = zeros(numRegions, numRegions);

% Calculate KS distances for each pair of regions
for i = 1:numRegions
    for j = i+1:numRegions  % Only calculate for upper triangular matrix
        regionName1 = regionLabels{i};
        regionName2 = regionLabels{j};
        sanitizedRegionName1 = strrep(regionName1, '-', '_');
        sanitizedRegionName2 = strrep(regionName2, '-', '_');
        
        if isfield(upDurations, sanitizedRegionName1) && isfield(upDurations, sanitizedRegionName2) && ...
           isfield(downDurations, sanitizedRegionName1) && isfield(downDurations, sanitizedRegionName2)
           
            % UP:
            UPdur1 = upDurations.(sanitizedRegionName1);
            UPdur2 = upDurations.(sanitizedRegionName2);
            
            % KS distance for UP durations
            if ~isempty(UPdur1) && ~isempty(UPdur2)
                [~, p, ksStatUP] = kstest2(UPdur1', UPdur2'); % Get KS statistic
                ksDistancesUP(i, j) = p; % Store in upper triangular matrix
                ksDistancesUP(j, i) = p; % Mirror to lower triangular matrix
            end
            
            % DOWN:
            DOWNdur1 = downDurations.(sanitizedRegionName1);
            DOWNdur2 = downDurations.(sanitizedRegionName2);
            
            % KS distance for DOWN durations
            if ~isempty(DOWNdur1) && ~isempty(DOWNdur2)
                [~, p, ksStatDOWN] = kstest2(DOWNdur1, DOWNdur2); % Get KS statistic
                ksDistancesDOWN(i, j) = p; % Store in upper triangular matrix
                ksDistancesDOWN(j, i) = p; % Mirror to lower triangular matrix
            end
        end
    end
end

% Table of KS distance:
ksDistancesUPTable = array2table(ksDistancesUP, 'VariableNames', regionLabels, 'RowNames', regionLabels);
ksDistancesDOWNTable = array2table(ksDistancesDOWN, 'VariableNames', regionLabels, 'RowNames', regionLabels);

disp('KS Distances for UP Durations Between Each Pair of Brain Regions:');
disp(ksDistancesUPTable);

disp('KS Distances for DOWN Durations Between Each Pair of Brain Regions:');
disp(ksDistancesDOWNTable);
%% %% p-value Heatmaps

regionLabels = brainMaskStruct.resizedDorsalMap.labels;
numRegions = length(regionLabels);

% Matrices
p_down = zeros(numRegions, numRegions);
p_up = zeros(numRegions, numRegions);
similarity = zeros(numRegions, numRegions);

% Calculate KS distances and similarity metric
for i = 1:numRegions
    for j = i+1:numRegions  
        regionName1 = regionLabels{i};
        regionName2 = regionLabels{j};
        sanitizedRegionName1 = strrep(regionName1, '-', '_');
        sanitizedRegionName2 = strrep(regionName2, '-', '_');

        if isfield(upDurations, sanitizedRegionName1) && isfield(upDurations, sanitizedRegionName2) && ...
           isfield(downDurations, sanitizedRegionName1) && isfield(downDurations, sanitizedRegionName2)
            
            % Extract UP and DOWN durations
            UPdur1 = upDurations.(sanitizedRegionName1);
            UPdur2 = upDurations.(sanitizedRegionName2);
            DOWNdur1 = downDurations.(sanitizedRegionName1);
            DOWNdur2 = downDurations.(sanitizedRegionName2);
            
            % KS distance for DOWN
            if ~isempty(DOWNdur1) && ~isempty(DOWNdur2)
                [h, p, ksStatDOWN] = kstest2(DOWNdur1, DOWNdur2);
                p_down(i, j) = p;
                p_down(j, i) = p_down(i, j);
            end
            
            % KS distance for UP
            if ~isempty(UPdur1) && ~isempty(UPdur2)
                [h, p, ksStatUP] = kstest2(UPdur1, UPdur2);
                p_up(i, j) =  p;
                p_up(j, i) = p_up(i, j);
            end
            
        else
            warning('Missing durations for regions: %s or %s. Skipping.', regionName1, regionName2);
        end
    end
end

% Set diagonal to 1 (self-similarity)
%KSdown(logical(eye(numRegions))) = 1;
%KSup(logical(eye(numRegions))) = 1;
similarity(logical(eye(numRegions))) = 1;

colormapChoice = jet; % Use 'jet' colormap
colorLimits = [0, 0.1]; % Scale from 0 to 1

% Heatmap for (1 - KS distance) DOWN
figure;
h1 = heatmap(regionLabels, regionLabels, p_down, 'Colormap', colormapChoice, 'ColorLimits', colorLimits);
h1.Title = 'p-value for DOWN states KS tests';
h1.XLabel = 'Brain Region';
h1.YLabel = 'Brain Region';
h1.CellLabelFormat = '%.2f'; % Annotate cells with values
set(gcf, 'Position', [100, 100, 700, 700]);

% Heatmap for (1 - KS distance) UP
figure;
h2 = heatmap(regionLabels, regionLabels, p_up, 'Colormap', colormapChoice, 'ColorLimits', colorLimits);
h2.Title = 'p-value UP states KS tests';
h2.XLabel = 'Brain Region'; 
h2.YLabel = 'Brain Region';
h2.CellLabelFormat = '%.2f'; 
set(gcf, 'Position', [100, 100, 700, 700]);


% Heatmap for Similarity Metric
% figure;
% h3 = heatmap(regionLabels, regionLabels, similarity, 'Colormap', colormapChoice, 'ColorLimits', colorLimits);
% h3.Title = 'Similarity Metric ((1 - KSdown) * (1 - KSup))';
% h3.XLabel = 'Brain Region';
% h3.YLabel = 'Brain Region';
% h3.CellLabelFormat = '%.2f'; 
% set(gcf, 'Position', [300, 300, 800, 800]);

outputPath= '/Users/elisachinigo/Documents/Widefield_Data';

saveas(h1, fullfile(outputPath, 'p_vals_DOWN.pdf'));
saveas(h2, fullfile(outputPath, 'p_vals_UP.pdf'));
%saveas(h3, fullfile(outputPath, 'Similarity_Metric.pdf'));


%% K-S Distance Heatmaps

regionLabels = brainMaskStruct.resizedDorsalMap.labels;
numRegions = length(regionLabels);

% Matrices
KSdown = zeros(numRegions, numRegions);
KSup = zeros(numRegions, numRegions);
similarity = zeros(numRegions, numRegions);

% Calculate KS distances and similarity metric
for i = 1:numRegions
    for j = i+1:numRegions  
        regionName1 = regionLabels{i};
        regionName2 = regionLabels{j};
        sanitizedRegionName1 = strrep(regionName1, '-', '_');
        sanitizedRegionName2 = strrep(regionName2, '-', '_');

        if isfield(upDurations, sanitizedRegionName1) && isfield(upDurations, sanitizedRegionName2) && ...
           isfield(downDurations, sanitizedRegionName1) && isfield(downDurations, sanitizedRegionName2)
            
            % Extract UP and DOWN durations
            UPdur1 = upDurations.(sanitizedRegionName1);
            UPdur2 = upDurations.(sanitizedRegionName2);
            DOWNdur1 = downDurations.(sanitizedRegionName1);
            DOWNdur2 = downDurations.(sanitizedRegionName2);
            
            % KS distance for DOWN
            if ~isempty(DOWNdur1) && ~isempty(DOWNdur2)
                [~, ~, ksStatDOWN] = kstest2(DOWNdur1, DOWNdur2);
                KSdown(i, j) = 1 - ksStatDOWN;
                KSdown(j, i) = KSdown(i, j);
            end
            
            % KS distance for UP
            if ~isempty(UPdur1) && ~isempty(UPdur2)
                [~, ~, ksStatUP] = kstest2(UPdur1, UPdur2);
                KSup(i, j) = 1 - ksStatUP;
                KSup(j, i) = KSup(i, j);
            end
            
            % Similarity metric
            similarity(i, j) = KSdown(i, j) * KSup(i, j);
            similarity(j, i) = similarity(i, j);
        else
            warning('Missing durations for regions: %s or %s. Skipping.', regionName1, regionName2);
        end
    end
end

% Set diagonal to 1 (self-similarity)
KSdown(logical(eye(numRegions))) = 1;
KSup(logical(eye(numRegions))) = 1;
similarity(logical(eye(numRegions))) = 1;

colormapChoice = jet; % Use 'jet' colormap
colorLimits = [0.7, 1]; % Scale from 0 to 1

% Heatmap for (1 - KS distance) DOWN
figure;
h1 = heatmap(regionLabels, regionLabels, KSdown, 'Colormap', colormapChoice, 'ColorLimits', colorLimits);
h1.Title = '(1 - KS distance) for DOWN states';
h1.XLabel = 'Brain Region';
h1.YLabel = 'Brain Region';
h1.CellLabelFormat = '%.2f'; % Annotate cells with values
set(gcf, 'Position', [100, 100, 700, 700]);

% Heatmap for (1 - KS distance) UP
figure;
h2 = heatmap(regionLabels, regionLabels, KSup, 'Colormap', colormapChoice, 'ColorLimits', colorLimits);
h2.Title = '(1 - KS distance) for UP states';
h2.XLabel = 'Brain Region';
h2.YLabel = 'Brain Region';
h2.CellLabelFormat = '%.2f'; 
set(gcf, 'Position', [100, 100, 700, 700]);

% Heatmap for Similarity Metric
% figure;
% h3 = heatmap(regionLabels, regionLabels, similarity, 'Colormap', colormapChoice, 'ColorLimits', colorLimits);
% h3.Title = 'Similarity Metric ((1 - KSdown) * (1 - KSup))';
% h3.XLabel = 'Brain Region';
% h3.YLabel = 'Brain Region';
% h3.CellLabelFormat = '%.2f'; 
% set(gcf, 'Position', [300, 300, 800, 800]);

outputpath= '/Users/elisachinigo/Documents/Widefield_Data';

saveas(h1, fullfile(outputPath, 'KS_Distance_DOWN.pdf'));
saveas(h2, fullfile(outputPath, 'KS_Distance_UP.pdf'));
%saveas(h3, fullfile(outputPath, 'Similarity_Metric.pdf'));

%% Hierarchically Ordered Heatmaps for K-S Distances and Similarity Metric

% Perform hierarchical clustering for each metric
Z_down = linkage(pdist(1 - KSdown), 'average'); 
Z_up = linkage(pdist(1 - KSup), 'average');    
Z_similarity = linkage(pdist(1 - similarity), 'average'); % Clustering for similarity metric

% Optimal leaf order
order_down = optimalleaforder(Z_down, pdist(1 - KSdown));
order_up = optimalleaforder(Z_up, pdist(1 - KSup));
order_similarity = optimalleaforder(Z_similarity, pdist(1 - similarity));

% Reorder matrices and labels based on clustering order
KSdown_clustered = KSdown(order_down, order_down);
KSup_clustered = KSup(order_up, order_up);
similarity_clustered = similarity(order_similarity, order_similarity);

regionLabels_clustered_down = regionLabels(order_down);
regionLabels_clustered_up = regionLabels(order_up);
regionLabels_clustered_similarity = regionLabels(order_similarity);

colormapChoice = jet; 
colorLimits = [0, 1]; 

% Heatmap for (1 - KS distance) for DOWN states
figure;
heatmap(regionLabels_clustered_down, regionLabels_clustered_down, KSdown_clustered, ...
    'Colormap', colormapChoice, 'ColorLimits', colorLimits, 'GridVisible', 'on');
title('(1 - KS distance) for DOWN states (Clustered)');
xlabel('Brain Region');
ylabel('Brain Region');
set(gcf, 'Position', [100, 100, 800, 800]);

% Heatmap for (1 - KS distance) for UP states
figure;
heatmap(regionLabels_clustered_up, regionLabels_clustered_up, KSup_clustered, ...
    'Colormap', colormapChoice, 'ColorLimits', colorLimits, 'GridVisible', 'on');
title('(1 - KS distance) for UP states (Clustered)');
xlabel('Brain Region');
ylabel('Brain Region');
set(gcf, 'Position', [200, 200, 800, 800]);

% Heatmap for Similarity Metric ((1 - KS_down) * (1 - KS_up))
figure;
heatmap(regionLabels_clustered_similarity, regionLabels_clustered_similarity, similarity_clustered, ...
    'Colormap', colormapChoice, 'ColorLimits', colorLimits, 'GridVisible', 'on');
title('Similarity Metric ((1 - KSdown) * (1 - KSup)) (Clustered)');
xlabel('Brain Region');
ylabel('Brain Region');
set(gcf, 'Position', [300, 300, 800, 800]);

% outputPath = '/Volumes/Extreme_SSD/RESEARCH/TPCN/Widefield_data';
% saveas(gcf, fullfile(outputPath, 'Clustered_Similarity_Metric.pdf'));
% saveas(gcf, fullfile(outputPath, 'Clustered_KS_DOWN.pdf'));
% saveas(gcf, fullfile(outputPath, 'Clustered_KS_UP.pdf'));

%% Pull average fluorescence from a 'region'; ID all 1D indices for that region
%% You'll need this if you want to ID UP/DOWN in a given region rather than for individual pixels (what I have done) 

% EG pull average time series from RSC
% Labels for each ROI are in: brainMaskStruct.resizedDorsalMap.labels
% Edge outlines for corresponding labels are in: brainMaskStuct.resizedDorsalMap.edgeOutline


%% EG Reorder ROIs from posterior -> anterior (I found useful, not
% necessary)
if strcmp(brainMaskStruct.resizedDorsalMap.labels{1},'RSPv1') == 0 
    orderManual=[27;26;21;22;20;19;18;17;16;23;15;14;13;6;5;10;11;4;8;24;25;3;2;1;9;7;12]; % sorting in brainMaskStruct labels
    [~,ind] = sort(orderManual);
    x={};y={};
    for i=1:length(brainMaskStruct.resizedDorsalMap.labels)-1
        x{i,1} = brainMaskStruct.resizedDorsalMap.labels{ind(i)};
        y{i,1} = brainMaskStruct.resizedDorsalMap.edgeOutline{ind(i)};
    end
    brainMaskStruct.resizedDorsalMap.labels = x;
    brainMaskStruct.resizedDorsalMap.edgeOutline = y; 
end

%% EG Make masks from edges 
indroiMasks = [];
roiBounds = brainMaskStruct.resizedDorsalMap.edgeOutline; 
sizeBrain = size(brainMaskStruct.resizedDorsalMap.maskScaled);
for i=1:size(brainMaskStruct.resizedDorsalMap.edgeOutline)
    indroiMasks(:,:,i) = poly2mask(brainMaskStruct.resizedDorsalMap.edgeOutline{i}(:,2),brainMaskStruct.resizedDorsalMap.edgeOutline{i}(:,1),sizeBrain(1),sizeBrain(2));
end
indroiMasks = logical(indroiMasks); 
% Look
figure
for i = 1:size(indroiMasks,3)
    imagesc(indroiMasks(:,:,i))
    title(['Mask: ' brainMaskStruct.resizedDorsalMap.labels{i}])
    pause %click to continue to move through
end

%% Get average activity within ROIs 
[~, ~, ~, meanROIs, areaROI, ~, ~] = TraceROIs(vid, [], 1, indroiMasks,roiBounds);

% Clean up
excludeROI = []; %any ROIs you want to exclude post facto
meanROIs(:,all(meanROIs == 0))=[];
if ~isempty(excludeROI)
    meanROIs(:,excludeROI) = []; 
end

%% Add masks if you want to find a combined average trace, eg for one RSC mask

RSC = indroiMasks(:,:,1) + indroiMasks(:,:,2) + indroiMasks(:,:,3); 
roiBounds = [brainMaskStruct.resizedDorsalMap.edgeOutline{1};brainMaskStruct.resizedDorsalMap.edgeOutline{2};brainMaskStruct.resizedDorsalMap.edgeOutline{3}]; 
roiBoundsCell{1} = roiBounds; % gotta make input into cell aray

figure; imagesc(RSC); title('Combined RSC mask')
[~, ~, ~, meanROI_RSC, areaROI_RSC, ~, ~] = TraceROIs(vid, [], 1, RSC,roiBoundsCell);


%% ROIs and heatmap plot 

t_lag = 1:size(meanROIs,1); 
spacing = .06;
x = copper(size(meanROIs,2)); 
meanROIs = meanROIs(:,2:end); 
figure
set(gcf,'color','w');
subplot(1,2,1)
hold on

%spacing = .000015; 
flipROIs = flip(meanROIs')';
for i=1:size(meanROIs,2)
    plot(t_lag,flipROIs(:,i)+spacing*i,'color',x(i,:),'linewidth',1.2)
end
axis tight
plot([0 0], get(gca,'ylim'),'r','linewidth',1.5)
xlabel( 'time(s)')
ylabel('Clusters')
set(gca,'YTick', [])
subplot(1,2,2)
 %imagesc(zscore(flipROIs)'); colormap(redblue); colorbar; caxis([-3 5])
 imagesc(t_lag,1:size(flipROIs,2),(flipROIs)'); h=colorbar; box off; %colormap(redblue)
 caxis([-caxisval caxisval2])
 hold on
 plot([0 0],get(gca,'ylim'),'r','linewidth',1.5)
 axis xy
ylabel(h, 'dF/F')
NiceSave(['ROIHeatmap_' namesave ],savePath,basename)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Get to individual videos within sessions and do stuff %%
%% GUI: Select sessions want to evaluate for analysis - just a mock up
switch ManualSelection
    case true
        [rowsPaths,~] = listdlg('PromptString','Which recording(s) would you like to analyze?','ListString',allbasePaths);
        basePaths = allbasePaths(rowsPaths);
        for bp = 1:length(basePaths) % replace with correct basePathAll for user data set
            basePaths{bp} = fullfile(basePathAllData,basePaths{bp}(4:end));
        end
    case isnumeric(BPin)
        disp('this should be a vector of rows corresponding to desired sessions in pathsToSessionsAll')
        basePaths = allbasePaths(rowsPaths);
        for bp = 1:length(basePaths) % replace with correct basePathAll for data set
            basePaths{bp} = fullfile(basePathAllData,basePaths{bp}(4:end));
        end
end

%% Loop through each session
for i = 1:length(basePaths) % index into basePaths
    
    ss=rowsPaths(i); % index into pathsToSessionsAll
    disp(['session: ' basePaths{i}]) % a check to make sure correct
    
    % Loop vars of interest @ session level
    basePath = basePaths{i};
    cd(basePath)
    baseName = bz_BasenameFromBasepath(basePath);
    [sessionInfo] = bz_getSessionInfo(basePath);
    % Load some session stuff
    load([baseName '.SlowWavesWFVid.events.mat']) %
    load([baseName 'SleepState.states.mat'])
    
    % Loop through each video within session
    if ~isempty(pathsToSessionsAll{ss,4})
        sessionVids = pathsToSessionsAll{ss,4}; % video numbers to use
        
        for ii=1:length(sessionVids) % about 3.5 min to load / vid
            vidnum = sessionVids(ii);
            disp(['vid: ' num2str(vidnum)])
            cd(fullfile(basePath,['Processedvid' num2str(vidnum)])) % cd to vid folder
            
            if isfile([vidname '.mat'])
                load([vidname '.mat'])
                
                % DO STUFF TO VID 
                % EG
                %% Expand vid
                frameStart = 1;
                frameEnd = 1000;
                vid=ExpandVid(widefield.data,brainMaskStruct.WarpData.lin_brainMask, size(brainMaskStruct.WarpData.brainMask), frameStart, frameEnd);
                     
                %% ID states in time window of WF video
                % Find ints in interval (so can label WAKE/REM/NREM)
                [inds,~,~] = InIntervals(SleepState.ints.REMstate(:,1),[widefield.timestamps(1) widefield.timestamps(end)]);
                REM = SleepState.ints.REMstate(inds,:);
                [inds,~,~] = InIntervals(SleepState.ints.WAKEstate(:,1),[widefield.timestamps(1) widefield.timestamps(end)]);
                WAKE = SleepState.ints.WAKEstate(inds,:);
                [inds,~,~] = InIntervals(SleepState.ints.NREMstate(:,1),[widefield.timestamps(1) widefield.timestamps(end)]);
                NREM = SleepState.ints.NREMstate(inds,:);
                
                % SAVE SOME STUFF
            end
        end
    end
end

%% All pixels in a brain region:
regionStateDurations = struct();

% Define threshold for UP state classification
upThreshold = 0.5; % 50% or more pixels in UP state

for i = 1:length(brainMaskStruct.resizedDorsalMap.labels)
    
    regionName = brainMaskStruct.resizedDorsalMap.labels{i};
    sanitizedRegionName = strrep(regionName, '-', '_');
    
    % Generate binary mask for this region
    boundaryCoords = brainMaskStruct.resizedDorsalMap.edgeOutline{i};
    mask = poly2mask(boundaryCoords(:,1), boundaryCoords(:,2), size(brainMaskStruct.resizedDorsalMap.maskScaled, 1), size(brainMaskStruct.resizedDorsalMap.maskScaled, 2));
    
    % Indices of pixels:
    [row, col] = find(mask);
    pixelIndices = arrayfun(@(r, c) sub2ind_brainMask([c, r], brainMaskStruct), row, col);
    
    % Initialize variables to track UP state for each time frame
    numFrames = size(SlowWavesWF.ints.DOWN, 2); % All videos
    upStateCounts = zeros(1, numFrames);
    
    % Loop through each pixel in the region
    for j = 1:length(pixelIndices)
        pixelIndex = pixelIndices(j);
        
        % Get UP and DOWN intervals for the current pixel
        UP = SlowWavesWF.ints.UP{pixelIndex, :};
        DOWN = SlowWavesWF.ints.DOWN{pixelIndex, :};
        
        % Track UP state for each frame
        for frame = 1:numFrames
            % Check if pixel is in UP or DOWN state for each frame
            isInUpState = any(arrayfun(@(k) frame >= UP(k, 1) && frame <= UP(k, 2), 1:size(UP, 1)));
            if isInUpState
                upStateCounts(frame) = upStateCounts(frame) + 1;
            end
        end
    end
    
    % Determine region state based on threshold
    regionState = upStateCounts >= (upThreshold * length(pixelIndices));
    
    % Calculate durations of UP and DOWN states for the region
    regionUpDurations = [];
    regionDownDurations = [];
    currentState = regionState(1);
    duration = 0;
    
    for frame = 1:numFrames
        if regionState(frame) == currentState
            duration = duration + 1;
        else
            if currentState == 1
                regionUpDurations = [regionUpDurations, duration];
            else
                regionDownDurations = [regionDownDurations, duration];
            end
            currentState = regionState(frame);
            duration = 1;
        end
    end
    
    % Store final duration:
    if currentState == 1
        regionUpDurations = [regionUpDurations, duration];
    else
        regionDownDurations = [regionDownDurations, duration];
    end
    
    % Store results for this region:
    regionStateDurations.(sanitizedRegionName).UP = regionUpDurations;
    regionStateDurations.(sanitizedRegionName).DOWN = regionDownDurations;
    
    % Plot histogram of UP and DOWN durations for each region
    figure;
    hold on;
    histogram(regionUpDurations, 50, 'FaceAlpha', 0.1, 'DisplayName', 'UP Durations', 'FaceColor', 'b');
    histogram(regionDownDurations, 50, 'FaceAlpha', 0.1, 'DisplayName', 'DOWN Durations', 'FaceColor', 'r');
    title(['UP and DOWN State Durations for Region ', regionName]);
    xlabel('Duration (s)');
    ylabel('Frequency');
    legend('show');
    hold off;
end
%% % Get indices of 1s in brainMask
% Create logical mask and use it to index each frame
mask = logical(brain_mask);

% Initialize matrix for masked time series
masked_timeseries = zeros(sum(mask(:)), 1000);

% Extract masked pixels from each frame
for t = 1:1000
   frame = vid(:,:,t);
   masked_timeseries(:,t) = frame(mask);
end

% Calculate correlation matrix
corrMatrix = corr(masked_timeseries');
%% 

figure;
imshow(corrMatrix);
%% 
% K-means clustering on time series
k = 35;  % Choose number of clusters
[idx,C] = kmeans(corrMatrix, k);

% Create spatial map of clusters
cluster_map = zeros(size(brain_mask));
mask = logical(brain_mask);
cluster_map(mask) = idx;

% Visualize
figure;
subplot(1,2,1)
imagesc(cluster_map);
colormap('jet');
colorbar;
title('Spatial Distribution of Clusters');

subplot(1,2,2)
[~,order] = sort(idx);
imagesc(corrMatrix(order,order));
colorbar;
title('Sorted Correlation Matrix');