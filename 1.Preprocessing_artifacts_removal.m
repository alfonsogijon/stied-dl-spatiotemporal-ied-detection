%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
%                     PREPROCESSING ARTIFACTS REMOVAL                     %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%                             0. ADD PATHS                                %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
clear all
restoredefaultpath 

addpath('F:/toolboxes/fieldtrip-20161113')
ft_defaults 
    addpath('F:/toolboxes/fieldtrip-20161113/external/fastica')

% SPM12
addpath(genpath('F:/toolboxes/spm12'))
% RSNNI
addpath(genpath('F:/toolboxes/RSN_Vincent'))
% MATLAB COMPAT
addpath(genpath('F:/toolboxes/MATLAB_compat'))
% HMM-MAR 
addpath(genpath('F:/toolboxes/HMM-MAR-Raquel'))

disp('Librerias y paths cargados')
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
%                        1. ICA PREPROCESSING                             %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Generate the artifact list 
%
% ------------------- %
% GENERAL FILES INFOS %
% ------------------- %

info=[]; 

info.general_dir='F:/AI_project';
info.subjects_dir='F:/AI_project/1.Raw_data'; % Where your raw MEG data is
info.mat_dir='2.Clean_raw_data_IC_artifacts'; % Folder where the result of the processing is going to be saved

info.subject={'meg_3923'}; % <-------- modify
info.condition='rest2'; % <-------- modify 
info.maxfilt='tsss_mc'; % <-------- modify 

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

% Make result directory where analysis results shall be stored 
if ~exist(fullfile(info.general_dir,info.mat_dir),'dir')
        unix(['mkdir ' fullfile(info.general_dir,info.mat_dir)]);
end

if ~exist(fullfile(info.general_dir,info.mat_dir,info.subject{1}),'dir')
        unix(['mkdir ' fullfile(info.general_dir,info.mat_dir,info.subject{1})]);
end

if ~exist(fullfile(info.general_dir,info.mat_dir,info.subject{1},info.condition),'dir')
        unix(['mkdir ' fullfile(info.general_dir,info.mat_dir,info.subject{1},info.condition)]);
end

% -------------------------------------------------------------------------

% ENTER PROCESSING INFOS
info.mat_file='ic-montage'; % Output mat format style
nsubj=1; 

% Read the data
raw=fiff_setup_read_raw(info.meg_file{nsubj}); % read .fif file

% -------------------------------------------------------------------------

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

[data,times,cfg]=meg_preprocess_fiff(raw,cfg);

disp('MEG data filtered in frequency')

% -------------------------------------------------------------------------

% Apply ICA cleaning
% Read EMG, EOG, ECG
chans_index=select_channels(raw.info.ch_names,'E.*G.*'); 
cfg.chans=raw.info.ch_names(chans_index); 
if ~isempty(cfg.chans)
    extdata=sig_preprocess_fiff(raw,times,cfg);
end
extname=cfg.chans;

IC=meg_ica_estimate(data,[]);
% IC.S, IC.A and IC.W

disp('30 ICA done')

%%%________________________________________________________________________

% From time to frequency domain
cfg=[];
cfg.epoch=10e3;
IC=meg_ica_powerspectrum(IC,cfg);
% IC.S, IC.A and IC.W, powspcrm and freq

% Skew and kurtosis 
IC=meg_ica_cumulantanalysis(IC,[]);
% IC.S, IC.A, IC.W, powspcrm and freq; cumulant (skew, kurt, list, Tskew
% and Tkurt)

if ~isempty(extname)
    cfg=[];
    cfg.extname=extname;     
    IC=meg_ica_corranalysis(IC,extdata,cfg);
end

% ---------------------
% Check out ICA results
cfg=[]; 
cfg.dim='time'; 
cfg.twin=10; 
cfg.tstep=5; 
cfg.num=size(IC.S,1); 

meg_ica_viewer_NC(raw,times,IC,cfg);

disp('meg_ica_viewer finished for patient')
%%%________________________________________________________________________

%%% Stop here to select visually the ICs artifacts and the 
%%% bad times and anotate them for remove them below
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                         %
%                       2. ICA ARTIFACT REMOVAL                           %
%                                                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Given list of ICs and time period to be removed. 
%
list_ICtoremove=[1 2]; % <-------- modify
time_toremove=[]; 

% Remove the artifact ICs
[cleandata,ICmontage]=remartIC(data,IC,list_ICtoremove); 

disp('Size(data)')
size(data)

close all 

% Remove selected time periods
data=cleandata;
for k=size(time_toremove,1):-1:1
    tind=(raw.info.sfreq*time_toremove(k,1)):1:(raw.info.sfreq*time_toremove(k,2));
    data(:,tind)=[];
    times(tind)=[];
    if ~isempty(extname), extdata(:,tind)=[]; end
end

disp('Size(data)')
size(data)

%%%________________________________________________________________________

% Save first ICA
datainfo=info;
datainfo.subject=info.subject{nsubj};
datainfo.meg_file=datainfo.meg_file{nsubj}; 
datainfo.mat_file=info.mat_file;
datainfo.sfreq=raw.info.sfreq;
datainfo.nic_removed=length(list_ICtoremove);
IC.list_ICtoremove=list_ICtoremove;
IC.time_toremove=time_toremove;
IC1=IC;

save(fullfile(info.general_dir,info.mat_dir,info.subject{1},info.condition,...
            [datainfo.subject '_' datainfo.mat_file '_' info.condition '_IC1']),...
            'ICmontage','IC1','datainfo','times')

disp('Removal artifacts ICA saved for patient')
info.subject{nsubj}
close all

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
