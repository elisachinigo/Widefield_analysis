function vidbig = ExpandVid(vidsmall, LinReconstInds, SizeVid, expand_indstart, expand_indstop,varargin)
%% vidbig = ExpandVid(vidsmall, LinReconstInds, SizeVid, expand_indstart, expand_indstop)
%  Takes brain-only-pixels reduced 2D matrix and reconstructs it
%  into full 3D matrix
%  Note: vidsmall should be in dims pixels x time

% OPTIONAL PROPERTY-VALUE INPUT PAIRS
% =========================================================================
%     Properties        Values
% -------------------------------------------------------------------------    
% 'masktype'            Can be 'nan' or 'zero', default 'nan'

% e.g. 3Dmatrix = ExpandVid(2Dmatrix, lin_brainmask, size(brainmask), 1, 1);

%%
% Defaults
p = inputParser;
addParameter(p,'masktype','nan')

% User defined
parse(p,varargin{:});
masktype = p.Results.masktype; 

% Initialize matrix
if strcmp(masktype,'nan')
    vidbig = single(nan(SizeVid(1)*SizeVid(2),expand_indstop - expand_indstart+1));
elseif strcmp(masktype,'zero') ||strcmp(masktype,'zeros')
    vidbig = single(zeros(SizeVid(1)*SizeVid(2),expand_indstop - expand_indstart+1));
else
    vidbig = single(nan(SizeVid(1)*SizeVid(2),expand_indstop - expand_indstart+1));
end

% Put tmpR values int initialized 2D matrix
for tt = expand_indstart:expand_indstop %this is looping through time....size(vidsmall,2)
    vidbig(LinReconstInds,tt-(expand_indstart-1)) = vidsmall(:,tt);
end

% Reshape into video
vidbig = reshape(vidbig,SizeVid(1),SizeVid(2),expand_indstop - expand_indstart+1);
