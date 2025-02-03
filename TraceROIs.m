function [roiMask, indroiMasks, roiBounds, meanROIs, areaROIs, centroidROIs, testmean] = TraceROIs(video, roitype, returninfo, varargin)
% [roiMask, indroiMasks, roiBounds, meanROIs, areaROIs, centroidROIs, testmean] = TraceROIs(video, roitype, returninfo)

% DESCRIPTION
% This function allows user to draw multiple masks that will be combined into one 'ROI' mask.

% INPUT
% video - can be a single video or image, cannot be 2d vid
% roitype - 'freehand' or 'rectangle'; if providing input, leave this var []
% returninfo - boolian 1 for yes, 0 for no; returns mean of each roi, centroid, and area

% OPTIONAL INPUT
% If roitype left empty, then provide as input indroiMasks and roiBounds

% OUTPUT
% roiMask - mask containing all rois
% indroiMasks - 3D matrix containing all rois, 3rd d = each ROI, logical
% masks
% roiBounds - boundaries of rois - in order from highest to lowest area,
% cell array, each cell = ROI, [x y] pixel values 
% meanROIs - average fluorescence value in each ROI
% areaROIs - area of each ROI
% centroidROIs - centroid of ROI


% To Do
% Right now, this fx works for a single image or for a 3d video,
% REWRITE so ALSO works with COMPRESSED VIDS if given indices to which they
% are assigned
% something about freehand option of this fx not working

% Write now can just open vidbig

%%
% Image or video Tracing

if isempty(roitype) ~= 1  % If user does not provide masks
    
    %Trace Rois
    figure
    
    subplot(1,2,1)
    if length(size(video)) < 3
        imagesc(video)
    else
        imagesc(mean(video,3))
    end;
    title({'Trace the brain','Click when done tracing'})
    sz = [size(video,1) size(video,2)];
    roiMask = false( sz ); % accumulate all single object masks to this one
    
    if strcmp(roitype,'freehand') == 1
        h = imfreehand( gca );
    elseif strcmp(roitype,'rectangle') == 1
        h = imrect( gca );
    else
        error('Must specify freehand or rectangle string input for variable roitype')
    end
    
    setColor(h,'red');
    BW = createMask( h );
    indroiMasks = createMask(h);
    
    while sum(BW(:)) > 2 % less than 10 pixels is considered empty mask
        roiMask = roiMask | BW; % add mask to global mask
        % ask user for another mask
        if strcmp(roitype,'freehand') == 1
            h = imfreehand( gca );
        elseif strcmp(roitype,'rectangle') == 1
            h = imrect( gca );
        else
            error('Must specify freehand or rectangle string input for variable roitype')
        end
        setColor(h,'red');
        %position = wait( h );
        BW = createMask( h );
        indroiMasks(:,:,size(indroiMasks,3)+1) = createMask( h );
    end
    
    % adjust indroiMask
    indroiMasks = indroiMasks(:,:,1:end-1);
    
    % show the resulting mask
    subplot(1,2,2)
    imagesc( roiMask ); title('multi-object mask');
    
    % get row,column location of bounds of rois
    roiBounds = bwboundaries(roiMask); % use to index into matrix
    
    % replot with xy bounds
    subplot(1,2,1)
    if length(size(video)) < 3
        imagesc(video)
    else imagesc(video(:,:,1))
    end;
    hold on
    for i=1:length(roiBounds)
        plot(roiBounds{i}(:,2),roiBounds{i}(:,1),'LineWidth',2,'color','w') %note must flip row and col bc using imagesc and need x/y
    end;

else
    indroiMasks = varargin{1};
    indroiMasks = logical(indroiMasks); 
    roiBounds = varargin{2};
    roiMask = [];
end

%% Return info for each roi

if length(size(video)) == 2
    nT = 1;
else
    nT = size(video,3);
end;

meanROIs = zeros(nT,length(roiBounds)); % time x roi
areaROIs = zeros(nT,length(roiBounds)); % time x roi
centroidROIs = zeros(nT,length(roiBounds)); % time x roi

if returninfo == 1
    for i=1:nT %for each frame
        for ii=1:length(roiBounds) %for each roi
            if length(size(indroiMasks)) == 3
                if length(size(video)) == 2
                    measurements = regionprops(indroiMasks(:,:,ii),video,'area', 'Centroid','MeanIntensity');
                    testmean(i,ii) = nanmean(video(indroiMasks(:,:,ii)));
                elseif length(size(video)) == 3 
                    measurements = regionprops(indroiMasks(:,:,ii),video(:,:,i),'area', 'Centroid','MeanIntensity');
                    frame = video(:,:,i);
                    testmean(i,ii) = nanmean(frame(indroiMasks(:,:,ii)));
                end
            elseif length(size(indroiMasks)) == 2
                if length(size(video)) == 2
                    measurements = regionprops(indroiMasks,video,'area', 'Centroid','MeanIntensity');
                    testmean(i,ii) = nanmean(video(indroiMasks));
                elseif length(size(video)) == 3 
                    measurements = regionprops(indroiMasks,video(:,:,i),'area', 'Centroid','MeanIntensity');
                    frame = video(:,:,i);
                    testmean(i,ii) = nanmean(frame(indroiMasks(:,:,ii)));
                end
            end
            meanROIs(i,ii) = measurements.MeanIntensity;
            areaROIs(i,ii) = measurements.Area;
            % Are multiple centroids - don't need, come back an edit later
            % if do
%             centroidROIs(i,ii,1) = measurements.Centroid(2);
%             centroidROIs(i,ii,2) = measurements.Centroid(1); %switching this - make sure is correct later
        end;
    end;
end;

if sum(meanROIs) == 0
    meanROIs = [];
end
if sum(areaROIs) == 0
    areaROIs = [];
end
if sum(centroidROIs) == 0
    centroidROIs = [];
    %testmean = [];
end;

