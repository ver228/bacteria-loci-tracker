clear all
addpath(genpath(fullfile(pwd, 'Main_Code')));

%% INPUT PARAMETERS
%where the results of the tracking analysis are stored?

track_results_dir = './Example/Tracking_Results/'; 

%database file with the data from the videos
%*Notes: the database must contain the following columns:
%name -> Experiments name, all the videos corresponding to the same condition must have the same name.
%delta_time	-> Time between frames.
%datadirs -> Where the movie (as a set of images) is stored.
%type -> I used it to group according to the type of medium but for the moment is not used.
%phc_file -> path to the phase contrast file.
%it is very important that the headers are spelled correctly in the
%database. I use the header name (not the column position) to extract the
%information.
data_base_file = './Example/database.csv'; 


expected_number_of_frames = 40; %what is the number of frames expected, to filter trajectories that are to short and likely to be spurious

%rows in the database to be analysed. Leave empty if you want to recalculate the whole database.
rows2analyze = [];

%% SETTINGS PARAMETERS
%minimun number of frames a trajectory to be plotted (only for
%visulaization purposes.
min_track_lenght = expected_number_of_frames; 

%pixel size in micrometers
del_pix= 0.106; 

%max displacement that two particles can be in separated frames in order to
%be linked.
SET.MAXMOVE = 2;

%minimum number of particles allowed
set_dedrift.minParticles = 5; %'NORMALY 10'

%minimum length of a track to be included in the dedrifting procedure.
set_dedrift.minTrackDedrift = expected_number_of_frames;
set_dedrift.particlesUsed = [];
%exclude trajectories with anomalus large movements in the dedriting
%procedure.
set_dedrift.excludeBigMov = true;

%use a mask to identify location of possible cells in the image.
SET.isMask = true;

%For the first approximation of the peak locations parameters
SET.gKernel = fspecial('gaussian',7,1); %smoothing kernel 
SET.alphaLocMax = 0.01; %threshold used to identify pixels
SET.integWindow = 1; %number of images averaged. This can help located dots in noisy images.

%parameters used to fit data with subpixel resolution. 
%This fitting is used done in the raw images (no smoothing or average)
fminuit_cmd = 'set lim 1 -1 65536; set lim 2 0 5; set lim 3 -2.2 2.2;set lim 4 -2.2 2.2;set lim 5 -1 65536; fix 2;minigrad';
SET.cmd = fminuit_cmd;
SET.fun2fit = 'MLEwG_Xi';
wavelength = 510; %expected wavelength of the fluorochrome emission.
SET.sigma = 0.21*wavelength/(1.4*(del_pix*1000)); %expected width of the difraction limited spot.


%empty frames allowed
SET.EMPTY_ALLOWED = 5;

%region used used to calculate signal and bgnd
SET.TOTALPIX = 5;

%initial image
SET.iniImage = 1;

%can be used to select a particular set in imList
SET.numImagesRaw = []; 

%parameters used to segmed cells from the phase contrast images.
imSize = [512 512];
SET_PhC.polVal = getPolyVal(imSize, 3); %used for the flat field correction.
SET_PhC.gKernel = fspecial('gaussian',7,1); 
SET_PhC.alphaLocMax = 0.1;

%% PREPROCESSING STEP
%load database
fileData = getFileData2(data_base_file);

%get the directories to save image in order to visualize the results
results_visualization = [fullfile(track_results_dir, 'results_visualization'), filesep];

%create directories if they do not exist
if ~exist(track_results_dir,'dir'), mkdir(track_results_dir), end
if ~exist(results_visualization,'dir'), mkdir(results_visualization), end

%% REAL PROGRAM
if isempty(rows2analyze)
    rows2analyze = 1:numel(fileData.datadirs);
end

tot_rows = numel(rows2analyze);
for n_row = 1:tot_rows; 
    
    row_id = rows2analyze(n_row);
    fprintf('Analysing movie %i of %i ...\n', n_row, tot_rows); 
    
    SET.imageDir = fileData.datadirs{row_id};
    imList = getImList(SET.imageDir);
    SET.MASKCELL = [];
    
    %% Get file names of the output files.
    tracking_file = fullfile(track_results_dir, sprintf('TrackData_%i.mat', row_id));
    seg_PhC_file = sprintf('%sseg_%i_PhC.mat', track_results_dir, n_row);
    
    show_tracks_image = fullfile(results_visualization, sprintf('showTracks_%i.jpg', row_id));
    show_seg_PhC = sprintf('%sseg_%i_PhC.bmp', results_visualization, n_row);
    
    %% DOT TRACKING
    
    dots = find_peaks_diffsub_av(SET);
    
    [positionsx_raw, positionsy_raw, indSparse] = create_trajectories_ind(dots,SET);
    [positionsx_raw, positionsy_raw, indSparse] = join_tracks_ind(positionsx_raw, positionsy_raw, indSparse, []);
    SNRStats = calculate_snr2_av(positionsx_raw, positionsy_raw, imList, SET);
    
    [positionsx, positionsy, CM] = dedrift_correction(positionsx_raw, positionsy_raw, set_dedrift);
    
    save(tracking_file, 'dots', 'positionsx_raw','positionsy_raw', 'indSparse', ...
        'positionsx', 'positionsy', 'CM', 'SET', 'SNRStats')
    %%
    %create an image showing the trajectories calculated. 
    if ~isempty(positionsx)
        showTracks_label(imList, positionsx, positionsy, min_track_lenght)
    else
        if SET.iniImage<= numel(imList), dum = SET.iniImage; else dum = 1; end
        figure, imshow(imread(imList{dum}),[]);
    end
    saveas(gcf, show_tracks_image, 'jpg')
    close(gcf)
    
    %% Segment phase contrast images
    [Iph, L, Ibg, shapeData] = segBacteriaImg(fileData.phc_file{row_id}, SET_PhC, SET.imageDir);
    save(seg_PhC_file, 'L','Ibg', 'shapeData')
    
    rgbI = drawRGBfinal(Iph, shapeData, true);
    imwrite(rgbI, show_seg_PhC,'BMP')

end