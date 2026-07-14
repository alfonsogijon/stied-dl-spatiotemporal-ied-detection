%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
%                       DATA PREPROCESSING FOR AI MODEL                   %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
%                             0. ADD PATHS                                %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
clear all
restoredefaultpath 
 
addpath('F:/toolboxes/new_files_Raquel')
addpath('F:/toolboxes/fieldtrip-20211122_Raquel')
ft_defaults
   addpath('F:/toolboxes/fieldtrip-20211122_Raquel/external/fastica')
   addpath('F:/toolboxes/fieldtrip-20211122_Raquel/plotting')
% SPM12
addpath(genpath('F:/toolboxes/spm12'))
% RSNNI
addpath(genpath('F:/toolboxes/RSN_Vincent'))
addpath(genpath('F:/toolboxes/RSN'))
% MATLAB COMPAT
addpath(genpath('F:/toolboxes/MATLAB_compat'))
% HMM-MAR 
addpath(genpath('F:/toolboxes/HMM-MAR-Raquel'))
% Files 
addpath(genpath('F:/toolboxes/new_files_Raquel'))

disp('Librerias y paths cargados')
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
%                   1.DATA PROCCESING FOR AI TIME ANALYSIS                %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% ---------------------------- %
% LOAD ICA RESULTS AND ANALYZE %
% ---------------------------- %
tic 
% ENTER INPUT DATA PARAMETERS
info=[];

info.general_dir='F:/AI_project';
info.subjects_dir='F:/AI_project/1.Raw_data';
info.mat_dir='2.Clean_raw_data_IC_artifacts'; 
info.prepro_AI_dir = '3.Preprocessing_AI'; % Folder where the result of the AI processing is going to be saved

info.subject={'meg_3977'}; % <-------- modify
info.condition='rest1'; % <-------- modify 
info.maxfilt='tsss_mc'; % <-------- modify 

info.noise_file='empty';
info.cor_file='meeg_ect'; 
info.space=5;
info.srctype='volume'; % 'volume' or 'cortex'
info.inversemodel='mne'; % 'mne', 'lcmv'
info.channel='all';

% -------------------------------------------------------------------------

% AUTOMATICALLY GET DATA INFOS

list=cell(1,length(info.subject)); 
% Get full meg file names 
for k=1:length(info.subject) 
     list{k} = fullfile(info.subjects_dir,info.subject{k},[[info.subject{k} '_' info.condition '_' info.maxfilt '.fiff']])
    if ~isempty(list{k}); list{k}(end)=[]; end     
end

info.meg_file=list(~strcmp(list,'')); 

if length(info.meg_file)~=length(info.subject)
    disp('WARNING : Number of meg_files different from number of subjects... Careful!')
    return
end

clear list k status
disp('Patient list created')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
nsubj = 1;

% ------------------------- %
% MNE PROJECTION OF IC MAPS %
% ------------------------- %
% Load precomputed ICA
%
load(fullfile(info.general_dir,info.mat_dir,info.subject{nsubj},info.condition,...
            [info.subject{nsubj} '_ic-montage_' info.condition '_IC1']))

disp('Loaded artifacts clean ICs of patient')
info.subject{nsubj}

% Read the data
raw=fiff_setup_read_raw(info.meg_file{nsubj}); % read .fif file  
raw.first_samp;
raw.last_samp;

% Filter data
cfg=[];
cfg.reading='cont';
cfg.filter=true;
    cfg.filt.win='boxcar';
    cfg.filt.par={'high' 'low'};
    cfg.filt.freq=[0.5 45]; 
    cfg.filt.width=[0.5 5];
cfg.rejection=false; 
cfg.blc=true;
 
[data, times]=meg_preprocess_fiff(raw,cfg);

% Project bad ICs outrawtime
data=ICmontage*data;

% Remove bad periods (cf ICA)
time_toremove=IC1.time_toremove;  
  for k=size(time_toremove,1):-1:1
      tind=(raw.info.sfreq*time_toremove(k,1)):1:(raw.info.sfreq*time_toremove(k,2));
      data(:,tind)=[]; 
      times(tind)=[]; 
  end 

rawfreq=datainfo.sfreq;
rawtime=times;

% Filter data
cfg=[];
cfg.sfreq=datainfo.sfreq; 
cfg.filt=[];
    cfg.filt.win='boxcar';
    cfg.filt.par={'high' 'low'};
    cfg.filt.freq=[4 30];
    cfg.filt.width=[0.01 0.01];
Zk=sig_filter(data,cfg);

disp('Size Zk and rawtime')
size(Zk) 
size(rawtime)


% Save files
if ~exist(fullfile(info.general_dir,info.prepro_AI_dir,info.subject{nsubj}),'dir')
        unix(['mkdir ' fullfile(info.general_dir,info.prepro_AI_dir,info.subject{nsubj})]);
end

if ~exist(fullfile(info.general_dir,info.prepro_AI_dir,info.subject{nsubj},info.condition),'dir')
        unix(['mkdir ' fullfile(info.general_dir,info.prepro_AI_dir,info.subject{nsubj},info.condition)]);
end
save(fullfile(info.general_dir,info.prepro_AI_dir,info.subject{nsubj},info.condition,[[info.subject{nsubj} '_time']]),'rawtime')

disp('Sensor space data saved for patient')
info.subject{nsubj}
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
%             2.TEMPORAL AND SPATIAL ANALYSIS: 2 INDEPENDENT PCAS         %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
% Divide the sensor data (Zk) in windows of 200ms 
%
n_timesteps = 200; 
time_end = rawtime(end);                           % final time in seconds  
time_init = rawtime(1);                            % initial time in seconds
dt = (time_end-time_init)/(size(rawtime,2)-1);     % time step in the original time series in seconds (0.001)
width = n_timesteps * dt;                          % width of each interval in seconds (0.2)
disp('width window: ')
disp(width)

total_time = size(rawtime,2);
n_components = size(Zk,1);
disp('Original data')
disp(size(Zk))

% Split original data into windows
n_windows = int16(total_time/n_timesteps);  % number of time intervals = amount of dataxdata
n_windows = double(n_windows);
disp('n_windows of 200ms')
disp(n_windows)

% Define windows for the original data
Zk_window = zeros(n_windows, n_timesteps, size(Zk,1));
Zk_T = transpose(Zk);
size(Zk_T) % time x channels

j=0;
for i = 1:n_windows
    j_ini = j*n_timesteps + 1;
    j = j + 1;
    j_end = j*n_timesteps;
    disp('')
    Zk_window(i,:,:) = Zk_T(j_ini:j_end,:);
end
disp('Size Zk_window')
size(Zk_window)

% Permute dimensions
xdata = permute(Zk_window,[1,3,2]);
disp('Size of window data xdata')
size(xdata)
size(n_windows)

% Save windows-data
%save(fullfile(info.general_dir,info.prepro_AI_dir,info.subject{nsubj},info.condition,[[info.subject{nsubj} '_window_data']]),'xdata','-v7.3')
%%%________________________________________________________________________
%
% Here the PCA analysis starts.
%
%%%%%%%%%%%%%%%%%%%%%%% TEMPORAL: GRADIOMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Select gradiometers
%
gradind=select_channels(raw.info.ch_names,'grad');
gradind=gradind-min(gradind)+1; 

nchan_grad=size(gradind,2); 
xdata_grad=xdata(:,gradind,:);
size(xdata_grad)

data_grad_1_pc = zeros(n_timesteps,n_windows); 
temporal_matrix_nwindow = zeros(n_timesteps, n_windows);

for i=1:n_windows
    clear data_grad_per_window
    clear eigenvectors_grad
    clear eigenvalues_grad

    grad_per_window = xdata_grad(i,:,:);
    grad_per_window = squeeze(grad_per_window);
    
    % PCA per window
    grad_window = grad_per_window; 
    [eigenvectors_grad, score_grad, eigenvalues_grad] = pca(grad_window); 
    first_eigenvector_grad = eigenvectors_grad(:,1); % 200x1
    first_eigenvalue_grad = eigenvalues_grad(1);
    
    % Real value in Tesla for the 1st component of the PCA gradiometer data
    first_component_real_units_grad = first_eigenvector_grad*first_eigenvalue_grad;
    temporal_matrix_nwindow(:,i) = first_component_real_units_grad;
   
end

disp('Size temporal_matrix_nwindow')
size(temporal_matrix_nwindow) % 200 x nwindows

save(fullfile(info.general_dir,info.prepro_AI_dir,info.subject{nsubj},info.condition,['t_data_' [info.subject{nsubj} '_102xnwindows']]),'temporal_matrix_nwindow') 
save(fullfile(info.general_dir,info.prepro_AI_dir,info.subject{nsubj},info.condition,['n_windows_' [info.subject{nsubj}]]),'n_windows')

%
%%%%%%%%%%%%%%%%%%%%%%% SPATIAL: MAGNETOMETERS %%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Select magnetometers
magind=select_channels(raw.info.ch_names,'magn');
magind=magind-min(magind)+1; 

nchan_mag=size(magind,2); 
xdata_mag=xdata(:,magind,:);
size(xdata_mag);

data_mag_1_pc = zeros(n_timesteps,n_windows); 
spatial_matrix_nwindow = zeros(nchan_mag,n_windows);  

for i=1:n_windows
    clear data_mag_per_window
    clear eigenvectors_mag
    clear eigenvalues_mag

    mag_per_window = xdata_mag(i,:,:);
    mag_per_window = squeeze(mag_per_window);
    
    % PCA per window
    mag_window = mag_per_window; 
    [eigenvectors_mag, score_mag, eigenvalues_mag] = pca(mag_window'); 
    first_eigenvector_mag=eigenvectors_mag(:,1); %102xnw
    first_eigenvalue_mag = eigenvalues_mag(1);
    
    % Real value in Tesla for the 1st component of the PCA magnetometer data
    first_component_real_units_mag = first_eigenvector_mag*first_eigenvalue_mag;
    spatial_matrix_nwindow(:,i) = first_component_real_units_mag;
   
end

disp('Size spatial_matrix_nwindow')
size(spatial_matrix_nwindow) % 102 x nwindows

%save(fullfile(info.general_dir,info.prepro_AI_dir,info.subject{nsubj},info.condition,['s_data_' [info.subject{nsubj} '_102xnwindows']]),'spatial_matrix_nwindow') 

%%%________________________________________________________________________
% Here the sptial maps coordinates are obtained
%
ngrid=60; 
vecX=zeros(1,ngrid);  
vecY=zeros(ngrid,1); 
vecZ=zeros(n_windows,ngrid,ngrid);

cfg=[];
 % Preparing layout
    cfg.layout='neuromag306mag.lay'; 
    layout=ft_prepare_layout(cfg);

    % Various definitions (to use ft_plot_topo)
    cfg.interpolation='v4'; 
    cfg.interplimits='mask';
    cfg.gridscale=ngrid; 
    cfg.shading='flat'; 
    cfg.contournum=6; 
    cfg.style='surf'; 
    maskdatavector=[];

for f=1:n_windows 
    [megXcoor, megYcoor, megsensorvalue] = meg_topoplot_R(raw,spatial_matrix_nwindow(:,f), 'magn');
        
    [interpXcoor, interpYcoor, interpZcoor] = meg_interpolated_coor_R(megXcoor,megYcoor,megsensorvalue,...
    'interpmethod',cfg.interpolation,...
    'interplim',cfg.interplimits,...
    'gridscale',cfg.gridscale,...
    'outline',layout.outline,...
    'shading',cfg.shading,...
    'isolines',cfg.contournum,...
    'mask',layout.mask,...
    'style',cfg.style,...
    'datmask', maskdatavector);

vecX(1,:)=interpXcoor(1,[1:ngrid]); %1x60
vecY(:,1)=interpYcoor([1:ngrid],1); % 60x1
vecZ(f,:,:)=interpZcoor; % nwindowx60x60

end

% Save
save(fullfile(info.general_dir,info.prepro_AI_dir,info.subject{nsubj},info.condition,['x_coor_' [info.subject{nsubj} '_1x60']]),'vecX') 
save(fullfile(info.general_dir,info.prepro_AI_dir,info.subject{nsubj},info.condition,['y_coor_' [info.subject{nsubj} '_1x60']]),'vecY') 
save(fullfile(info.general_dir,info.prepro_AI_dir,info.subject{nsubj},info.condition,['z_data_' [info.subject{nsubj} '_xy_image_per_window']]),'vecZ') 
   
disp('Saved spatial coordinates xyz for patient')
info.subject{nsubj} 
info.condition

results=fullfile('F:/AI_project/4.ML_program/Results',info.condition);
if ~exist(fullfile(results),'dir')
    unix(['mkdir ' fullfile(results)]);
end

toc