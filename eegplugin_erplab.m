% Author: Javier Lopez-Calderon & Steven Luck
% Center for Mind and Brain
% University of California, Davis,
% Davis, CA
% 2007-2010

%b8d3721ed219e65100184c6b95db209bb8d3721ed219e65100184c6b95db209b
%
% ERPLAB Toolbox
% Copyright � 2007 The Regents of the University of California
% Created by Javier Lopez-Calderon and Steven Luck
% Center for Mind and Brain, University of California, Davis,
% javlopez@ucdavis.edu, sjluck@ucdavis.edu
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.

function currvers = eegplugin_erplab(fig, trystrs, catchstrs)

erplab_default_values % script
currvers  = ['erplab_' erplabver];

if nargin < 3
        error('eegplugin_erplab requires 3 arguments');
end

%
% ADD FOLDER TO PATH
%
p = which('eegplugin_erplab','-all');
if length(p)>1
        fprintf('\nERPLAB WARNING: More than one ERPLAB folder was found.\n\n');
end
p = p{1};
p = p(1:findstr(p,'eegplugin_erplab.m')-1);
if ~exist('pop_binlister.m','file')
        addpath(genpath(p))
        %         addpath(p);
        %         addpath([p 'erplab_Box'], [p 'functions'], [p 'GUIs'], [p 'images'], [p 'pop_functions'], [p 'deprecated_functions']); % Thanks to Grega Repovs
end

%
% CHECK VERSION NUMBER & FOLDER NAME
%
foldernum = p(end-7:end-1);   % Grab the end of the path, like '5.1.1.0'
if isempty(foldernum)
        fprintf('\nERPLAB WARNING: ERPLAB''s folder name was found to be modified from the original.\n\n')
else
        if ~strcmp(foldernum, erplabver)
                fprintf('\nERPLAB''s folder does not show the current version number.\n\n')
        end
end

%
% CHECK EEGLAB Version
%
if exist('memoryerp.erpm','file')==2
        iserpmem = 1; % file for memory exists
else
        iserpmem = 0; % does not exist file for memory
end
egv = regexp(eeg_getversion,'^(\d+)\.+','tokens','ignorecase');
eegversion = str2num(char(egv{:}));
if eegversion==11
        if iserpmem==1
                warning('ERPLAB:Warning', 'ERPLAB is not compatible with EEGLAB 11. Please try either a newer or an older version of EEGLAB.')
        else
                warndlg(sprintf('ERPLAB is not compatible with EEGLAB 11.\nPlease try either a newer or an older version of EEGLAB.'),'!! Warning !!', 'modal')
        end
end

%
% TEMPORARY ERPLAB's Files
%
dirBox    = fullfile(p,'erplab_Box');
filst     = dir(dirBox);
filenames = {filst.name};

if length(filenames)>3    % '.'    '..'    'erplab_box_readme.md'
        recycle on;
        delete(fullfile(dirBox,'*'))
        fprintf('\nERPLAB WARNING: Temporary files (from your last session) within erplab_Box folder were sent to recycle bin.\n\n')
        
        file_id = fopen(fullfile(dirBox, 'erplab_box_readme.md'), 'w');
        fprintf(file_id, 'This is a placeholder file, so that git does not delete the `erplab_Box` folder.');
        fclose(file_id);
end

%
% ERPLAB's WORKING MEMORY
%
if iserpmem==0
        mshock = 0;
        try
                % saves memory file
                %
                % IMPORTANT: If this file (saved variables inside memoryerp.erpm) is modified then also must be modified the same line at erplabamnesia.m
                %
                save(fullfile(p,'memoryerp.erpm'),'erplabrel','erplabver','ColorB','ColorF','errorColorB', 'errorColorF','fontsizeGUI','fontunitsGUI','mshock');
        catch
                % saves memory variable at workspace
                msgboxText = ['\nERPLAB could not find a file for storing its GUI memory or \n'...
                        'does not have permission for writting on it.\n\n'...
                        'Therefore, ERPLAB''s memory will be stored at Matlab''s workspace and will last 1 session.\n\n'];
                
                % message on command window
                fprintf('%s\n', repmat('*',1,50));
                fprintf('"Houston, we''ve had a problem here": \n %s\n', sprintf(msgboxText));
                bottomline = 'If you think this is a bug, please report the error to erplab@erpinfo.org and not to the EEGLAB developers.';
                disp(bottomline)
                fprintf('%s\n', repmat('*',1,50));
                
                %
                % IMPORTANT: If this strucure (vmemoryerp) is modified then also must be modified the same line at erplabamnesia.m
                %
                vmemoryerp = struct('erplabrel',erplabrel,'erplabver',erplabver,'ColorB',ColorB,'ColorF',ColorF,'fontsizeGUI',fontsizeGUI,...
                        'fontunitsGUI',fontunitsGUI,'mshock',mshock, 'errorColorF', errorColorF, 'errorColorB', errorColorB);
                assignin('base','vmemoryerp',vmemoryerp);
        end
end

%
% ERPLAB's VARIABLES TO WORKSPACE
%
ERP              = [];  % Start ERP Structure on workspace
ALLERP           = [];  % Start ALLERP Structure on workspace
ALLERPCOM        = [];
CURRENTERP       = 0;
plotset.ptime    = [];
plotset.pscalp   = [];
plotset.pfrequ   = [];

assignin('base','ERP',ERP);
assignin('base','ALLERP', ALLERP);
assignin('base','ALLERPCOM', ALLERPCOM);
assignin('base','CURRENTERP', CURRENTERP);
assignin('base','plotset', plotset);

%---------------------------------------------------------------------------------------------------
%                                                                                                   |
%
% EEGLAB import multiple dataset (Biosig MENU)
%
e_try        = 'try,';
e_catch      = 'catch, eeglab_error; LASTCOM= ''''; clear EEGTMP ALLEEGTMP STUDYTMP; end;';
nocheck      = e_try;
storeallcall = [ 'if ~isempty(ALLEEG) & ~isempty(ALLEEG(1).data), ALLEEG = eeg_checkset(ALLEEG);' ...
        'EEG = eeg_retrieve(ALLEEG, CURRENTSET); eegh(''ALLEEG = eeg_checkset(ALLEEG); EEG = eeg_retrieve(ALLEEG, CURRENTSET);''); end;' ];
ifeeg            =  'if ~isempty(LASTCOM) & ~isempty(EEG),';
e_storeall_nh    = [e_catch 'eegh(LASTCOM);' ifeeg storeallcall 'disp(''Done.''); end; eeglab(''redraw'');'];
% cb_loaderplabset = [ nocheck '[ALLEEG EEG CURRENTSET LASTCOM] = pop_loadmerplabset(ALLEEG, EEG);' e_storeall_nh];

%
%  Create menu import multiple datasets (deprecated)
%
% menu_import_erplab = findobj(fig,'tag','import data');
% uimenu( menu_import_erplab,'Label', ['Load multiple EEGLAB/ERPLAB ' erplabver ' datasets'],...
%         'CallBack', cb_loaderplabset,'Separator','on');
%                                                                                                   |
%---------------------------------------------------------------------------------------------------

%
% ERPLAB NEST-MENU  (ERPLAB at the EEGLAB's Main Menu)
%
if ispc      % windows
        wfactor1 = 1.20;
        wfactor2 = 1.21;
elseif ismac % Mac OSX
        wfactor1 = 1.45;
        wfactor2 = 1.46;
else
        wfactor1 = 1.30;
        wfactor2 = 1.31;
end
posmainfig = get(gcf,'Position');
hframe     = findobj('parent', gcf,'tag','Frame1');
posframe   = get(hframe,'position');
set(gcf,'position', [posmainfig(1:2) posmainfig(3)*wfactor1 posmainfig(4)]);
set(hframe,'position', [posframe(1:2) posframe(3)*wfactor2 posframe(4)]);

menuERPLAB = findobj(fig,'tag','EEGLAB');   % At EEGLAB Main Menu

%****************************************************************************************************
%****************************************|        MENU      |****************************************
%****************************************|      CALLBACKS   |****************************************
%****************************************************************************************************
%
% ARTIFACT DETECTION FOR CONTINUOUS DATA callback
%
comTrim   = [trystrs.no_check '[EEG, LASTCOM]   = pop_eegtrim(EEG);' catchstrs.new_and_hist ];
comREJCON = [trystrs.no_check '[EEG, LASTCOM] = pop_continuousartdet(EEG);' catchstrs.store_and_hist ];

%
% EVENTLIST callback
%
comCLF1    = [trystrs.no_check '[EEG, LASTCOM] = pop_creabasiceventlist(EEG);' catchstrs.new_and_hist ];
comSMMRZ   = [trystrs.no_check '[EEG, LASTCOM] = pop_squeezevents(EEG);' catchstrs.add_to_hist ];
comSLFeeg  = [trystrs.no_check '[EEG, LASTCOM] = pop_exporteegeventlist(EEG);' catchstrs.add_to_hist ];
comRLFeeg  = [trystrs.no_check '[EEG, LASTCOM] = pop_importeegeventlist(EEG);' catchstrs.new_and_hist];
comEXRTeeg = [trystrs.no_check '[EEG, values LASTCOM] = pop_rt2text(EEG);' catchstrs.add_to_hist];
comEXRTerp = ['[ERP, values ERPCOM] = pop_rt2text(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];

%
% BINLISTER callback
%
comCBL    = [trystrs.no_check '[EEG, LASTCOM] = pop_binlister(EEG);' catchstrs.store_and_hist];
comMEL    = [trystrs.no_check '[EEG, LASTCOM] = pop_overwritevent(EEG);' catchstrs.new_and_hist];

%
% BIN-BASED EPOCHING callback
%
comEB     = [trystrs.no_check '[EEG, LASTCOM] = pop_epochbin(EEG);' catchstrs.new_and_hist];
comBV     = 'bdfVisualizer;';



%
% EEG CHANNEL OPERATION callback
%
comCHOP   = [trystrs.no_check '[EEG, LASTCOM] = pop_eegchanoperator(EEG);' catchstrs.store_and_hist ]; % ERPLAB 1.1.718 and higher

%
% EEG (epoched) ARTIFACT DETECTION callbacks
%
comAR0     = [trystrs.no_check '[EEG, LASTCOM] = pop_artextval(EEG);' catchstrs.new_and_hist]; % Extreme Values
comAR1     = [trystrs.no_check '[EEG, LASTCOM] = pop_artmwppth(EEG);' catchstrs.new_and_hist]; % Peak to peak window voltage threshold
comAR3     = [trystrs.no_check '[EEG, LASTCOM] = pop_artblink(EEG);' catchstrs.new_and_hist];  % Blink
comAR4     = [trystrs.no_check '[EEG, LASTCOM] = pop_artstep(EEG);' catchstrs.new_and_hist];   % Step-like artifacts
comAR6     = [trystrs.no_check '[EEG, LASTCOM] = pop_artdiff(EEG);' catchstrs.new_and_hist];   % sample-to-sample diff
comAR7     = [trystrs.no_check '[EEG, LASTCOM] = pop_artderiv(EEG);' catchstrs.new_and_hist];  % Rate of change
comAR8     = [trystrs.no_check '[EEG, LASTCOM] = pop_artflatline(EEG);' catchstrs.new_and_hist];  % Blocking & flat line
comRSTAR   = [trystrs.no_check '[EEG, LASTCOM] = pop_resetrej(EEG);' catchstrs.new_and_hist];  % Rate of change
comARSinc1 = [trystrs.no_check '[EEG, LASTCOM] = pop_syncroartifacts(EEG);' catchstrs.new_and_hist];

%
% ERP and EEG (epoched) summary for ARTIFACT DETECTION callback
%
comARSUMM  = [trystrs.no_check '[EEG, goodbad, histeEF, histoflags,  LASTCOM] = pop_summary_rejectfields(EEG);' catchstrs.add_to_hist];
comARSUMM2 = [trystrs.no_check '[EEG, pr, acce rej, histoflags,  LASTCOM] = pop_summary_AR_eeg_detection(EEG);' catchstrs.add_to_hist];
comARSUMM3 = [trystrs.no_check '[EEG, MPD, LASTCOM] = getardetection(EEG, 1);' catchstrs.add_to_hist];
comARSUMerp1 = ['[ERP, tacce, trej, histoflags,  ERPCOM] = pop_summary_AR_erp_detection(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];

%
% UTILITIES  callbacks
%
comEEC     = [trystrs.no_check '[EEG, LASTCOM] = pop_eraseventcodes(EEG);' catchstrs.new_and_hist];
comICOF    = [trystrs.no_check '[EEG, LASTCOM] = pop_insertcodeonthefly(EEG);' catchstrs.new_and_hist];
comICLA    = [trystrs.no_check '[EEG, LASTCOM] = pop_insertcodearound(EEG);' catchstrs.new_and_hist];
comICTTL   = [trystrs.no_check '[EEG, LASTCOM] = pop_insertcodeatTTL(EEG);' catchstrs.new_and_hist];
comShuff   = [trystrs.no_check '[EEG, LASTCOM] = pop_eventshuffler(EEG);' catchstrs.new_and_hist];
comEEGBDR  = [trystrs.no_check '[EEG, LASTCOM] = pop_bdfrecovery(EEG);' catchstrs.add_to_hist];
comBCOL    = 'Bcolorerplab' ;
comFCOL    = 'Fcolorerplab' ;
comBerrCOL = 'Bcolorerror' ;
comFerrCOL = 'Fcolorerror' ;
comFS      = 'Seterplabfontsize';
comRECB    = [trystrs.no_check '[EEG, LASTCOM] = pop_setcodebit(EEG);' catchstrs.new_and_hist];
comEP2CON  = [trystrs.no_check '[EEG, LASTCOM] = pop_epoch2continuous(EEG);' catchstrs.new_and_hist];
comBlab2eve  = [trystrs.no_check '[EEG, LASTCOM] = pop_binlabel2type(EEG);' catchstrs.new_and_hist];

%
% FILTER EEG callbacks
%
comBFCD    = [trystrs.no_check '[EEG, LASTCOM] = pop_basicfilter(EEG);' catchstrs.new_and_hist];
comPAS     = [trystrs.no_check '[EEG, LASTCOM] = pop_fourieeg(EEG);' catchstrs.add_to_hist];
comESIM    = [trystrs.no_check '[EEG, LASTCOM] = pop_EEGsimulate(EEG);' catchstrs.new_and_hist];
comTK1     = [trystrs.no_check '[EEG, LASTCOM] = pop_polydetrend(EEG);' catchstrs.new_and_hist ];
comTK2     = [trystrs.no_check '[EEG, LASTCOM] = pop_eeglindetrend(EEG);' catchstrs.new_and_hist ];
comTK3     = '[ERP, ERPCOM]  = pop_erplindetrend(ERP); [ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);';

%
% ERP processing callbacks
%
comERPBDR    = ['[ERP, ERPCOM] = pop_bdfrecovery(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comSLFerp    = ['[ERP, ERPCOM] = pop_exporterpeventlist(ERP);'  '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comRLFerp    = ['[ERP, ERPCOM] = pop_importerpeventlist(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comAPP       = ['[ERP, ERPCOM] = pop_appenderp(ALLERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comRERPBL    = ['[ERP, ERPCOM] = pop_blcerp(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comCERPch    = ['[ERP, ERPCOM] = pop_clearerpchanloc(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comAVG       = ['[ERP, ERPCOM] = pop_averager(ALLEEG);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comBOP       = ['[ERP, ERPCOM] = pop_binoperator(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comCHOP2     = ['[ERP, ERPCOM] = pop_erpchanoperator(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comPLOT      = ['[ERP, ERPCOM] = pop_ploterps(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comSCALP     = ['[ERP, ERPCOM] = pop_scalplot(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comCHLOC     = ['[ERP, ERPCOM] = pop_erpchanedit(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comCHLOCEEGLAB = ['[ERP ERPCOM] = pop_getChanInfoFromEeglab(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comSAVE      = ['[ERP, issave ERPCOM] = pop_savemyerp(ERP,''gui'',''save'');' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comSAVEas    = ['[ERP, issave ERPCOM] = pop_savemyerp(ERP,''gui'',''saveas'');' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comDUPLI     = ['[ERP, issave ERPCOM] = pop_savemyerp(ERP,''gui'',''erplab'');' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comSendemail = ['[ALLERP, ERPCOM]     = pop_senderpbymail(ALLERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comSaveH     = ['[ERP, ERPCOM] = pop_saveERPhistory(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comSetemail  = 'setemailGUI;';

% export ERP
comEXPAVG    = ['[ERP, ERPCOM] = pop_erp2asc(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comEXPUNI    = ['[ERP, ERPCOM] = pop_export2text(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];

% import ERP
comIMPERP    = ['[ERP, ERPCOM] = pop_importerp;' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comIMPERPSS  = ['[ERP, ALLERP, ERPCOM] = pop_importerpss; ' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comIMPNEURO  = ['[ERP, ERPCOM] = pop_importavg(''''); ' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];

% load ERP
comLDERP     = ['[ERP, ALLERP, ERPCOM] = pop_loaderp('''');' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);' ];
comDELERP    = ['[ALLERP, ERPCOM]      = pop_deleterpset(ALLERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comCALIERP   = ['[ERP, ERPCOM]         = pop_calibraterp(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];

% Measurement and viewer
comGAVG      = ['[ERP, ERPCOM]     = pop_gaverager(ALLERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comERPMT     = ['[ALLERP, Amp, Lat, ERPCOM] = pop_geterpvalues(ALLERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comERPView   = ['[ALLERP, Amp, Lat, ERPCOM] = pop_geterpvalues(ALLERP,[],[],[],''Erpsets'', 0,''Viewer'', ''on'');' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];

% export figure
comEXPPDF    = ['[ERP, ERPCOM] = pop_exporterplabfigure(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];

% help
comhelpman   = 'pop_erphelp;' ;
comhelptut   = 'pop_erphelptut;' ;
comhelpsrp   = 'pop_erphelpscript;' ;
comhelpvideo = 'web http://erpinfo.org/erplab/erplab-documentation/video-documentation -browser';

%
% Filter ERP callbacks
%
comFil    = ['[ERP, ERPCOM] = pop_filterp(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comPASerp = ['ERP, LASTCOM = pop_fourierp(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];
comEPSerp = ['ERP, LASTCOM = pop_getFFTfromERP(ERP);' '[ERP, ALLERPCOM] = erphistory(ERP, ALLERPCOM, ERPCOM);'];


% Working memory
comLoadWM = ['clear vmemoryerp; vmemoryerp = working_mem_save_load(2); assignin(''base'',''vmemoryerp'',vmemoryerp);'];


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        MAIN      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        MENU      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Create ERPLAB menu
%
submenu = uimenu( menuERPLAB,'Label','ERPLAB','separator','on','tag','ERPLAB','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
set(submenu,'position', 6); % thanks Arno!

%
% Artifact detection in continuous data
%
uimenu( submenu,'Label','Artifact rejection in continuous data','CallBack', comREJCON,'userdata','startup:off;continuous:on;epoch:off;study:off;erpset:off');

%
% EVENTLIST for EEG menu and submenu
%
ELmenu = uimenu( submenu,'Label','EventList','tag','EventList','separator','on','userdata','startup:off;continuous:on;epoch:on;study:on;erpset:on');
uimenu( ELmenu,'Label','Create EEG EVENTLIST ','CallBack', comCLF1,'userdata','startup:off;continuous:on;epoch:off;study:on;erpset:off');
uimenu( ELmenu,'Label','Import EEG EVENTLIST from text file ','CallBack', comRLFeeg,'separator','on','userdata','startup:off;continuous:on;epoch:off;study:off;erpset:off');
uimenu( ELmenu,'Label','Export EEG EVENTLIST to text file ','CallBack', comSLFeeg,'userdata','startup:off;continuous:on;epoch:on;study:off;erpset:off');
uimenu( ELmenu,'Label','Shuffle events/bins/samples ','CallBack', comShuff,'separator','on','userdata','startup:off;continuous:on;epoch:off;study:on;erpset:off');
uimenu( ELmenu,'Label','Summarize current EEG event codes (output at command window) ','CallBack', comSMMRZ,'separator','on','userdata','startup:off;continuous:on;epoch:off;study:off;erpset:off');
mRTs = uimenu( ELmenu,'Label','Export reaction times to text','tag','ReactionTime','ForegroundColor', [0.6 0 0],'separator','on','userdata','startup:off;continuous:on;epoch:off;study:off;erpset:on'); % Reaction Times
uimenu( mRTs,'Label','From EEG ','CallBack', comEXRTeeg,'userdata','startup:off;continuous:on;epoch:on;study:off;erpset:off'); % Reaction Times
uimenu( mRTs,'Label','From ERP ','CallBack', comEXRTerp,'userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on'); % Reaction Times
% EVENTLIST for ERP submenu
uimenu( ELmenu,'Label','Import ERP EVENTLIST from text file ','CallBack',comRLFerp,'separator','on','userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( ELmenu,'Label','Export ERP EVENTLIST to text file ','CallBack',comSLFerp,'userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
% Binlister
uimenu( submenu,'Label','Assign bins (BINLISTER)','CallBack', comCBL,'userdata','startup:on;continuous:on;epoch:on;study:off;erpset:on');
if(verLessThan('matlab', '8.2'))
    % Do not add BDF Visualizer tool if Matlab version is less that 8.2
    uimenu( submenu,'Label','BDF Visualizer - Disabled','CallBack',comBV,'separator','off','userdata','startup:off;continuous:off;epoch:off;study:off;erpset:off');
else
    uimenu( submenu,'Label','BDF Visualizer','CallBack',comBV,'separator','off','userdata','startup:on;continuous:on;epoch:on;study:off;erpset:off');
end

uimenu( submenu,'Label','Transfer eventinfo to EEG.event (optional)','CallBack',comMEL,'separator','on','userdata','startup:off;continuous:on;epoch:off;study:off;erpset:off');
% bepoching
uimenu( submenu,'Label','Extract bin-based epochs','CallBack',comEB,'separator','on','userdata','startup:off;continuous:on;epoch:on;study:off;erpset:off');

%
% EEG CHANNEL OPERATIONS
%
uimenu( submenu,'Label','EEG Channel operations','CallBack',comCHOP,'separator','on','userdata','startup:off;continuous:on;epoch:on;study:off;erpset:off');

%
% FREQUENCY TOOLS & FILTERS EEG/ERP submenus
%
mFI = uimenu( submenu,'Label','Filter & Frequency Tools','separator','on','userdata','startup:off;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mFI,'Label','Filters for EEG data ','CallBack',comBFCD,'userdata','startup:off;continuous:on;epoch:on;study:on;erpset:off');
uimenu( mFI,'Label','Plot amplitude spectrum for EEG data ','CallBack', comPAS,'userdata','startup:off;continuous:on;epoch:on;study:off;erpset:off');
uimenu( mFI,'Label','Filters for ERP data ','CallBack',comFil,'separator','on','userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( mFI,'Label','Plot amplitude spectrum for ERP data ','CallBack', comPASerp,'userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( mFI,'Label','Compute Evoked Power Spectrum from current ERPset','CallBack', comEPSerp,'userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( mFI,'Label','EEG Linear detrend ','CallBack',comTK2,'separator','on','userdata','startup:off;continuous:off;epoch:on;study:on;erpset:on');
uimenu( mFI,'Label','ERP Linear detrend ','CallBack',comTK3,'userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( mFI,'Label','EEG Polynomial detrend (continuous) (alpha version)','CallBack', comTK1,'separator','on','userdata','startup:off;continuous:on;epoch:off;study:on;erpset:off');

%
% ARTIFACT DETECTION FOR EPOCHED DATA submenus
%
mAR = uimenu( submenu,'Label','Artifact detection in epoched data','tag','ART','separator','on','userdata','startup:off;continuous:off;epoch:on;study:on;erpset:off');
uimenu( mAR,'Label','Simple voltage threshold','CallBack', comAR0,'userdata','startup:off;continuous:off;epoch:on;study:on;erpset:off');
uimenu( mAR,'Label','Moving window peak-to-peak threshold','CallBack', comAR1,'userdata','startup:off;continuous:off;epoch:on;study:on;erpset:off');
uimenu( mAR,'Label','Blink rejection (alpha version)','CallBack', comAR3,'userdata','startup:off;continuous:off;epoch:on;study:on;erpset:off');
uimenu( mAR,'Label','Step-like artifacts','CallBack', comAR4,'userdata','startup:off;continuous:off;epoch:on;study:on;erpset:off');
uimenu( mAR,'Label','Sample to sample voltage threshold','CallBack', comAR6,'userdata','startup:off;continuous:off;epoch:on;study:on;erpset:off');
uimenu( mAR,'Label','Rate of change -time derivative- (alpha version)','CallBack', comAR7,'userdata','startup:off;continuous:off;epoch:on;study:on;erpset:off');
uimenu( mAR,'Label','Blocking & flat line','CallBack', comAR8,'userdata','startup:off;continuous:off;epoch:on;study:on;erpset:off');
uimenu( mAR,'Label','Clear artifact detection marks on EEG ','CallBack', comRSTAR,'separator','on','ForegroundColor', [0.6 0 0],'userdata','startup:off;continuous:off;epoch:on;study:on;erpset:off');
uimenu( mAR,'Label','Synchronize artifact info in EEG and EVENTLIST ','CallBack', comARSinc1,'separator','on','userdata','startup:off;continuous:off;epoch:on;study:on;erpset:off');

%
% ARTIFACT DETECTION summaries submenus
%
mSAR = uimenu( submenu,'Label','Summarize artifact detection','tag','ART','userdata','startup:off;continuous:off;epoch:on;study:off;erpset:on');
uimenu( mSAR,'Label','Summarize EEG artifacts in one value','CallBack', comARSUMM3,'ForegroundColor', [0 0 0.6],'userdata','startup:off;continuous:off;epoch:on;study:off;erpset:off');
uimenu( mSAR,'Label','Summarize EEG artifacts in a table','CallBack', comARSUMM2,'ForegroundColor', [0 0 0.6],'userdata','startup:off;continuous:off;epoch:on;study:off;erpset:off');
uimenu( mSAR,'Label','Summarize EEG artifacts in a graphic','CallBack', comARSUMM,'ForegroundColor', [0 0 0.6],'userdata','startup:off;continuous:off;epoch:on;study:off;erpset:off');
uimenu( mSAR,'Label','Summarize ERP artifacts in a table ','CallBack', comARSUMerp1,'ForegroundColor', [0 0 0.6],'separator','on','userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');

%
% AVERAGE ERP
%
uimenu( submenu,'Label','Compute averaged ERPs ','CallBack',comAVG,'separator','on','userdata','startup:off;continuous:off;epoch:on;study:off;erpset:off');

%
% ERP OPERATIONS submenus
%
mERPOP = uimenu( submenu,'Label','ERP Operations','tag','ERPop','separator','on','userdata','startup:on;continuous:on;epoch:on;study:off;erpset:on');
uimenu( mERPOP,'Label','ERP Bin operations ','CallBack', comBOP,'userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( mERPOP,'Label','ERP Channel operations ','CallBack', comCHOP2,'userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( mERPOP,'Label','Append ERPsets ','CallBack', comAPP,'userdata','startup:on;continuous:on;epoch:on;study:off;erpset:on');
uimenu( mERPOP,'Label','Remove ERP baseline ','CallBack', comRERPBL,'separator','on','userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( mERPOP,'Label','ERP Calibration ','CallBack', comCALIERP,'separator','on','userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');



%
% PLOT ERP WAVEFORMS AND MAPS
%
mERPLOT = uimenu( submenu,'Label','Plot ERP','tag','ERPlot','separator','on','userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( mERPLOT,'Label','Plot ERP waveforms ','CallBack', comPLOT,'userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( mERPLOT,'Label','Plot ERP scalp maps ','CallBack', comSCALP,'userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( mERPLOT,'Label','Print plotted figure(s) to a file','CallBack', comEXPPDF,'separator','on','userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( mERPLOT,'Label','Load ERP channel location file','CallBack', comCHLOC,'separator','on','userdata','startup:on;continuous:on;epoch:on;study:off;erpset:on');
uimenu( mERPLOT,'Label','Load ERP channel location info using EEGLAB','CallBack', comCHLOCEEGLAB,'userdata','startup:on;continuous:on;epoch:on;study:off;erpset:on');
uimenu( mERPLOT,'Label','Clear ERP channel location info ','CallBack', comCERPch,'userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( mERPLOT,'Label','Close all ERPLAB figures ','CallBack','clerpf','separator','on','userdata','startup:on;continuous:on;epoch:on;study:off;erpset:on');

%
% EXPORT & IMPORT ERP submenus
%
mEXERP = uimenu( submenu,'Label','Export & Import ERP','tag','Exerp','separator','on','userdata','startup:on;continuous:on;epoch:on;study:off;erpset:on');
uimenu( mEXERP,'Label','Export ERP to text (readable by ERPSS) ','CallBack', comEXPAVG,'userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( mEXERP,'Label','Export ERP to text (universal) ','CallBack', comEXPUNI,'userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( mEXERP,'Label','Import ERP from text (ERPSS) ','CallBack', comIMPERPSS,'separator','on','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mEXERP,'Label','Import ERP from Neuroscan (*.avg) ','CallBack', comIMPNEURO,'userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mEXERP,'Label','Import ERP from text (universal) ','CallBack', comIMPERP,'userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');

%
% LOAD & SAVE ERPset(s)
%
uimenu( submenu,'Label','Load existing ERPset','CallBack',comLDERP,'separator','on','userdata','startup:on;continuous:on;epoch:on;study:off;erpset:on');
uimenu( submenu,'Label','Clear ERPset(s)','CallBack',comDELERP,'userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( submenu,'Label','Save current ERPset','CallBack',comSAVE,'userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( submenu,'Label','Save current ERPset as '   ,'CallBack', comSAVEas,'userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( submenu,'Label','Duplicate or rename current ERPset '   ,'CallBack', comDUPLI,'userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( submenu,'Label','Send ERPset by e-mail '   ,'CallBack', comSendemail,'userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');

%
% MEASUREMENT TOOL
%
uimenu( submenu,'Label','ERP Measurement Tool ','CallBack', comERPMT,'separator','on','userdata','startup:on;continuous:on;epoch:on;study:off;erpset:on');
uimenu( submenu,'Label','ERP Viewer ','CallBack', comERPView,'userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');

%
% GRAND AVERAGE
%
uimenu( submenu,'Label','Average across ERPsets (Grand Average) ','CallBack', comGAVG,'separator','on','userdata','startup:on;continuous:on;epoch:on;study:off;erpset:on');

%
% UTILITIES submenus
%
mUTI = uimenu( submenu,'Label','Utilities','tag','Utilities','separator','on','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mUTI,'Label','Trim continuous data','CallBack', comTrim, 'userdata','startup:off;continuous:on;epoch:off;study:off;erpset:off');
uimenu( mUTI,'Label','Convert an epoched dataset into a continuous one','CallBack', comEP2CON, 'separator','on','userdata','startup:off;continuous:off;epoch:on;study:off;erpset:off');
uimenu( mUTI,'Label','Recover event codes from Bin Labels (recommended)','CallBack', comBlab2eve,'userdata','startup:off;continuous:on;epoch:off;study:off;erpset:off');

mINS = uimenu( mUTI, 'Label','Insert event codes','tag','insertcodes','separator','on','userdata','startup:off;continuous:on;epoch:off;study:off;erpset:off');
uimenu( mINS,'Label','Insert event codes using threshold (continuous EEG) ','CallBack', comICOF,'userdata','startup:off;continuous:on;epoch:off;study:off;erpset:off');
uimenu( mINS,'Label','Insert event codes using latency(ies) (continuous EEG) ','CallBack', comICLA,'userdata','startup:off;continuous:on;epoch:off;study:off;erpset:off');
uimenu( mINS,'Label','Insert event codes at TTL onsets (continuous EEG) ','CallBack', comICTTL,'userdata','startup:off;continuous:on;epoch:off;study:off;erpset:off');
uimenu( mUTI,'Label','Erase undesired event codes (continuous EEG) ','CallBack', comEEC,'separator','on','userdata','startup:off;continuous:on;epoch:off;study:off;erpset:off');
uimenu( mUTI,'Label','Recover bin descriptor file from EEG ','CallBack', comEEGBDR,'separator','on','userdata','startup:off;continuous:on;epoch:on;study:off;erpset:off');
uimenu( mUTI,'Label','Recover bin descriptor file from ERP ','CallBack', comERPBDR,'userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( mUTI,'Label','Reset event code bytes','CallBack', comRECB,'separator','on','userdata','startup:off;continuous:on;epoch:off;study:off;erpset:off');
uimenu( mUTI,'Label','Save current ERPset history for scripting','CallBack', comSaveH,'separator','on','userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
uimenu( mUTI,'Label','Find more here! (for scripting) ','CallBack','web(''http://www.erpinfo.org/erplab/erplab-documentation/utilities/view'',''-browser'');','separator','on',...
        'userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mUTI,'Label','Simulate EEG/ERP data  (alpha version)','CallBack',comESIM,'separator','on' );

%
% Settings submenus
%
mSETT = uimenu( submenu,'Label','Settings','tag','Settings','separator','on','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mSETT,'Label','Set font size for ERPLAB''s GUIs','CallBack', comFS,'userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mSETT,'Label','Edit ERPLAB''s completion statement','CallBack','msg2endGUI','separator','on','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mSETT,'Label','Set e-mail account'   ,'CallBack', comSetemail,'separator','on','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mSETT,'Label','ERPLAB Background Color ','CallBack',comBCOL,'separator','on','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mSETT,'Label','ERPLAB Foreground Color ','CallBack', comFCOL,'userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mSETT,'Label','Error window Background Color ','CallBack',comBerrCOL,'separator','on','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mSETT,'Label','Error window Foreground Color ','CallBack', comFerrCOL,'userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
%uimenu( mSETT,'Label','Reset ERPLAB''s working memory','CallBack','erplabamnesia(1)','separator','on','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mSETT,'Label','Backup this ERPLAB version','CallBack','backuperplab','separator','on','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mSETT,'Label','Set Backup location','CallBack','setbackuploc','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
% erpmem submenu in Settings
mMEM = uimenu( mSETT, 'Label','ERPLAB Memory Settings','tag','MemoryOps','separator','on','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mMEM,'Label','Reset ERPLAB''s working memory','CallBack','erplabamnesia(1)','separator','off','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mMEM,'Label','Save a copy of the current working memory as...','CallBack','working_mem_save_load(1)','separator','off','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mMEM,'Label','Load a previous working memory file','CallBack',comLoadWM,'separator','off','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');


%
% SUPPORT
%
mhelp = uimenu( submenu,'Label','Help','tag','erphelp','separator','on','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mhelp,'Label','About ERPLAB','CallBack','abouterplabGUI','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mhelp,'Label','ERPLAB Manual','CallBack', comhelpman,'separator','on', 'userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mhelp,'Label','ERPLAB Tutorial','CallBack', comhelptut,'userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mhelp,'Label','ERPLAB Scripting','CallBack', comhelpsrp,'userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mhelp,'Label','ERPLAB video tutorials','CallBack', comhelpvideo,'separator','on','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mhelp,'Label','Contact us','CallBack','web(''mailto:erplabtoolbox@gmail.com?subject=contact&body=Dear%20Steve%20and%20Javier,'');','separator','on','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');
uimenu( mhelp,'Label','Send question/feedback to the ERPLAB email list','CallBack','web(''mailto:erplab@ucdavis.edu?subject=feedback'');','separator','on','userdata','startup:on;continuous:on;epoch:on;study:on;erpset:on');

%
% CREATE ERPset MAIN MENU
%
erpmenu = uimenu( menuERPLAB,'Label','ERPsets','separator','on','tag','erpsets','userdata','startup:off;continuous:off;epoch:off;study:off;erpset:on');
set(erpmenu,'position', 7);
set(erpmenu,'enable','off');
