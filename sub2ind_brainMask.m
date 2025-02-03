function [outputIndices] = sub2ind_brainMask(inputIndices,brainMaskStruct)

% for now does 2d to 1d conversion, add 1d to 2d 

%% 

% 2d -> 1d masked index 
outputIndices = sub2ind(size(brainMaskStruct.WarpData.brainMask),inputIndices(1),inputIndices(2));
outputIndices = find(brainMaskStruct.WarpData.lin_brainMask==outputIndices); %linear index