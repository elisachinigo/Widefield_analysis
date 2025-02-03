
function LoopImage(data, caxisscale, start, stop, framerate, colormap_pref, varargin)
%% LoopImage(data, caxisscale, start, stop, varargin) 
%  Loop Image within MATLAB to look at vid or save looped image to .avi video file with scale bar

% Input
% data - data file; casxisscale - scale for caxis; start and stop
% indices,3d
% framerate vid, colormap - can write as text/not - if put default will be
% perula

% Optional Input
% If want to save and add scalebar of 500 microns and savid vid, add 3 additional inputs:
% 1. fpath
% 2. fname - where want to save video
% 3. approx length in microns of FOV (length not width) %6500 um = 6.5 mm
% 4. linear map - mask background to make it white instead of black
% 5. ROIs if want time series subplot; give single time series 
% 6. If put 5, put in desired spacing between ROIs

% e.g. 
% LoopImage(data, [-140 140], 1, size(data,3),26.69)
% LoopImage(data, [-140 140], 1, size(data,3), 26.69, '/Users/rachelaswanson/Dropbox/BLab/WideFieldTest/mouse6_thinskull_gcamp6f/stacks', 'test', 6500)

% 12/20/16 RS: Add optional label for colorbar and title...should always
% have there so can know what the vid is;
% &&Option to auto-set caxis based on distribution of fluorescence values
% *Change this so continues to make .avi of entire file by loading in subsets of the data
% Need auto caxis scaling
% Add option for memory mapping this 


%%
% figure('units','normalized','outerposition',[.5 .5 .6 .75],'color','w')


% Open video object 
if  nargin > 6
        vidObj = VideoWriter([fullfile(varargin{1},varargin{2}) '.avi']);
        vidObj.FrameRate = framerate;
        open(vidObj);
        
        if nargin >=10
        brainmap = varargin{4};
        end
end

% Add functionality to make entire df video in segments. 
% Option: provide data or provide path to video....perhaps add to
% gridsmooth/gridaverage? 

% Loop through frames
for frame = start:stop
    
        % Draw
        hold off
        drawnow
        if nargin == 12
          subplot(5,1,1:3)
        end
        if nargin >= 10 %6
            imagesc(data(:,:,frame),'alphadata',brainmap)
        else
            imagesc(data(:,:,frame))
        end;
        caxis(caxisscale)
        colorbar
        colormap(colormap_pref)
        c = colorbar;
        c.Label.String = 'dF/F';
        box off
        set(gca,'xcolor',get(gcf,'color'),'ycolor',get(gcf,'color'),'xtick',[],'ytick',[]);

        hold on

        % Time
        time = 0:1/framerate:size(data,3)/framerate;
        time = time(1:end-1);
        
        
        % Add time text box, displays every 10 
            loc1 = .92*size(data,1); %width was +12; 30
            loc2 = .90*size(data,2); %length; 40
            text(loc2-20, loc1+0,[num2str(round(((frame/framerate)*10))/10) 's'],'Color','k','FontSize',18,'fontweight','bold', 'FontName', 'Helvetica')
                        
        % Add scale bar
%             pixeldiam = varargin{3}/size(data,2); %pixeldiam = 8 %6500 microns divided by 336 pixels = size of each micron
%             scalebarlength = floor(500/pixeldiam); %500 microns
%             plot([loc2:loc2+scalebarlength], repmat(loc1,1,length(loc2:loc2+scalebarlength)),'k','LineWidth',3);
%             
  
        if nargin > 6
        % Optional ROIs
            if nargin == 12
                rois = varargin{5}; 
                spacing = 0:1:min(size(rois))-1;
                spacing = spacing.*varargin{6};
                rois = rois+repmat(spacing,length(time),1);
                
                subplot(5,1,4:5)
                plot(time,rois,'k','Linewidth',1.1)
                axis tight 
                hold on
                plot([time(frame) time(frame)],get(gca,'YLim'),':r','LineWidth',2)
                plot([time(round(length(time)/2)) time(round(length(time)/2))],get(gca,'YLim'),':k','Linewidth',1)
                hold off
                box off
                set(gca,'ycolor',get(gcf,'color'),'ytick',[]);
                xlabel('time(s)') 
                %plot(varargin{5}+repmat([3000 2000 1000 0],1000,1))
            end
        % Save video object    
            imgFrame = getframe(gcf); %// Capture figure's content
            writeVideo(vidObj,imgFrame.cdata); %// The actual pixel values are in 'cdata'.
       
        
        end
        
        %Use to find desired spacing 
%         rois=squeeze(meanROIs(:,:,4));
%         spacing = 0:1:min(size(rois))-1;
%         spacing = spacing.*0.0009;
%         rois = rois+repmat(spacing,length(t_lag),1);
%         plot(t_lag,rois)
          
       % If want to add xlabel and ylabel
            % y=linspace(0,size(file2save,1).*pixeldiam,size(data,1));
            % x=linspace(0,size(file2save,2).*pixeldiam,size(data,2));
            % xlabel(['med-lat (' num2str(char(181)) 'm)']); ylabel(['rost-caud (' num2str(char(181)) 'm)'])
  
        % Add time box uicontrol - less flexible than just using 'text' command
            % mTextBox = uicontrol('style','text');
            % string = set(mTextBox,'String',[num2str(round(((frame/vidObj.FrameRate)*10))/10) 's']); %make sure this is right
            % set(mTextBox,'BackgroundColor',[1 1 1])
            % set(mTextBox,'Position',[400   50    60    20])
            % set(mTextBox,'fontsize',11);
            % set(mTextBox,'fontweight','bold');
        

end
    
% Close video object
if nargin > 6
    close(gcf)
    close(vidObj);
end  
%% for dan
% 
% fpathopen = '/Users/rachelaswanson/Dropbox/BLab/WideFieldTest/mouse6_thinskull_gcamp6f/stacks';
% name = 'video10_4x.tif';
% 
% TiffStack = TIFFStack(fullfile(fpathopen,name)); %@DylanMuir; working for all sized tif stacks
% %%
% fs = 26.69;
% time = 0:1/fs:size(TiffStack,3)/fs;
% time = time(1:end-1);
% ind1 = 1;%13266;
% ind2 = 1350;%17180;
% timesub = time(ind1:ind2);
% 
% %%
% tic
%             TmpCube = double(TiffStack(:,:,ind1:ind2));
%             TmpPixelPlane = reshape(TmpCube,size(TmpCube,1)*size(TmpCube,2),size(TmpCube,3))'; 
%             
%             % Perform smoothing operation
%             [Xdn, Sigma, npars] = MP(TmpPixelPlane); 
%             
%             % Reshape cube and write to NEW matrix (OR ORIGINAL MATRIX - MAKE MEMORY ALLOCATION DECISION LATER)      
%             tmpZ_smooth = reshape(Xdn',size(TmpCube,1),size(TmpCube,2),size(TmpCube,3));
% 
%             % df           
%             df_tmpZ = tmpZ_smooth - median(tmpZ_smooth,3);
%             toc
