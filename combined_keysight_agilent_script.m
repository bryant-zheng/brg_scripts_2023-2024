% Code based on work by Dr. H. Frankis, Xin Xin, and Dylan G-O
% and based on the "Spectrum_acquisition_agilent_coarse.m", "Spectrum_acquisition_keysight_coarse.m"
% in the BRG-McMasterU Github. Can find them under: measurement_Scripts -> Agilent and Keysight Laser Control

% Modificaitions by Arthur Mendez-Rosales, Bryant Zheng
% Laser(Agilent 8164A) programming guide can check:
% http://www.doe.carleton.ca/~nagui/labequip/lightwave/8164A_Programming%20Guide.pdf
% Latest modifications by: Bryant Zheng
% 2024/04/15

% This singular MATLAB script allows the user to control both the Keysight
% laser/detector setup and the Aglient setup in one script. The
% functionality of this script is based on the "Spectrum_acquisition_agilent_coarse.m", "Spectrum_acquisition_keysight_coarse.m"
% scripts. The parameters and control of each laser can be change under "adjustable parameters,"
% and will export a .csv file and plot a graph based on wavelength and
% power.

%resetting the instrument
clear; instrreset;

%% adjustable parameters----------------------
outputPow = -5;
sensRange = -10;
lambdaList = {[1250, 1350]};                                        %start and stop wavelengths,, ensure that wavelength ranges are within the ranges of the respective machine
lambda_step = 0.02;                                                 %step size of the sweep
fileBeginning = '';
loc = '';                                                           %output file saved at
laserType = 0; %% set to 0 for the keysight setup, set to 1 for the agilent setup
%% adjustable parameters----------------------

%file naming and output
file_name = sprintf('%s (%0.0f-%0.0f), OP=%0.0f - %s', fileBeginning, lambdaList{1}(1), lambdaList{end}(end), outputPow, datestr(now, 'yyyy.mm.dd'));
polName = regexp(fileBeginning, 'T(E|M)', 'match', 'once');
outFolder = [pwd '\' regexprep(fileBeginning, {',',[' ' polName]}, '') '\' polName '\Coarse Sweep\'];

%keysight setup
if laserType == 0
    %setting up the laser
    obj = visa('ni', 'TCPIP0::100.65.16.165::inst0::INSTR');
    obj.EOSMode = 'read&write';
    set(obj, 'InputBufferSize', 1000000);
    fopen(obj);                                                     %open instrument
    fprintf(obj, '*CLS');                                           %instrument setting reset
    flushinput(obj);    flushoutput(obj);                           %flush the data that was stored in the buffer
    
    %setting up the detector
    det = visa('ni', 'TCPIP0::100.65.16.169::inst0::INSTR');
    det.EOSMode = 'read&write';
    set(det, 'InputBufferSize', 100000);
    fopen(det);                                                     %open instrument
    fprintf(det, '*CLS');                                           %instrument setting reset
    flushinput(det);    flushoutput(det);                           %flush the data that was stored in the buffer
    
    fprintf(obj, 'sour0:wav?');                                     %ask laser for the current wavelength before sweep
    currWavOut = fgets(obj);                                        %get result
    currWav = str2double(currWavOut)*1e9;                           %store current wavelength as number to be sent back to laser after sweep
    
    %sweep
    Itotal = [];  lambdatotal = [];
    for jj = 1:length(lambdaList)
        lambda_start = lambdaList{jj}(1);
        lambda_stop = lambdaList{jj}(2);
        lambda = lambda_start:lambda_step:lambda_stop;              % nm
        scan_speed = 40;                                            %nm/s only 0.5 5 40 allowed - is this something that could be changed?
        avg_time = 2E-4;                                            %photodiode average time - is this something that could be changed?
        fprintf(obj, 'POW:UNIT 0');                                 %set source power unit
        fprintf(obj, ['POW ' num2str(outputPow) 'DBM']);            %set laser power {unit will be according to the power unit set before}
        fprintf(obj, 'TRIG:OUTP STF');                              %TLS will send a output trigger when sweep starts (input trigger generated)
        fprintf(obj, 'TRIG:INP IGN');                               %(TLS input trigger is ignored)
        fprintf(obj, 'WAV:SWE:MODE CONT');                          %continuos sweep
        fprintf(obj, 'WAV:SWE:REP ONEW');                           %one way sweep
        fprintf(obj, ['WAV:SWE:SPE ' num2str(scan_speed) 'nm/s']);  %sweep speed
        fprintf(obj, ['WAV:SWE:STAR ' num2str(lambda_start) 'nm']); %sweep starting lambda
        fprintf(obj, ['WAV:SWE:STEP ' num2str(lambda_step) 'nm']);  %sweep step size
        fprintf(obj, ['WAV:SWE:STOP ' num2str(lambda_stop) 'nm']);  %sweep stop lambda
        fprintf(obj, 'WAV:SWE:CYCL 1');                             %one sweep cycle
    
        %detector settings
        fprintf(det, 'TRIG:OUTP DIS');                              %PD output trigger is disabled
        fprintf(det, 'TRIG:INP SME');                               %PD will finish a function when input trigger is abled
    
        fprintf(det, 'INIT1:CONT 1');                               %continuous detection mode
        fprintf(det, ['SENS1:POW:ATIM ' num2str(avg_time) 's']);    %set the averagetime to 1ms for sensor 2
        fprintf(det, 'SENS1:POW:RANGE:AUTO 0');                     %set auto ranging on
    
        fprintf(det, ['SENS1:POW:RANG ' num2str(sensRange) 'W']); 
    
      
        fprintf(det, 'SENS1:POW:UNIT 1'); %sets the unit of power: 0[dBm], 1[W]
    
    
        fprintf(det, 'SENS1:POW:WAV 1550nm');                       %set sensor wavelength centered at 1550 nm
        fprintf(det, 'SENS1:FUNC:STAT STAB,STOP');
        points = length(lambda);
        fprintf(det, ['SENS1:FUNC:PAR:LOGG ' num2str(points) ',' num2str(avg_time)]);
        query(det, 'SENS1:FUNC:PAR:LOGG?');
        fprintf(det, 'SENS1:FUNC:STAT LOGG,STAR');
        fprintf(obj, 'WAV:SWE STAR');
        pause(1)
        query(obj, 'WAV:SWE:FLAG?');
        t = 0;
        while str2num(query(obj, 'WAV:SWE:FLAG?')) ~= 2
            query(obj, 'WAV:SWE:FLAG?');
            pause(0.1)
            t = t + 1;
        end
        
        fprintf(obj, 'WAV:SWE:LLOG 1');                              %lambda logging on
        fprintf(obj, 'READ:DATA? LLOG');
        [wave_read, cont_wave, msg_1] = binblockread(obj, 'double');
        fprintf(det, 'SENS1:FUNC:RES?');
        [I, cont, msg] = binblockread(det, 'float');
        Itotal = [Itotal; I];
        lambdatotal = [lambdatotal; wave_read];
    end
    
    fprintf(det,'TRIG:INP IGN');                                    %detector input trigger is ignored to allow continous measurement again
    fprintf(obj, sprintf('sour0:wav %0.0fnm', currWav));            %set laser back to the wavelength it was at before the sweep
    fprintf(det, 'SYST:PRES');                                      %preset the detector to prevent it from freezing
    fprintf(det,'SENS1:POW:UNIT 1'); %unit change                               %set the units back to dBm on the detector
    
    fclose(obj);    fclose(det);
    delete(obj);    delete(det);
    clear obj;      clear det;        
end

%agilent setup
if laserType == 1
    %GPIB setting
    obj = gpib('ni', 0, 20);
    set(obj,'InputBufferSize', 100000);
    fopen(obj);                                             % open instrument
    fprintf(obj, '*CLS');                                   % instrument setting reset
    
    %Sweep
    Itotal = [];  lambdatotal = [];
    for jj = 1:length(lambdaList) 
        lambda_start = lambdaList{jj}(1);
        lambda_stop = lambdaList{jj}(2);
        lambda_step = 0.01;
        lambda = [lambda_start:lambda_step:lambda_stop];    % nm
        points = length(lambda);
        scan_speed = 40;                                    % nm/s only 0.5 5 40 allowed
        avg_time = 2E-4;                                    % photodiode average time
        flushinput(obj);    flushoutput(obj);               % Flush the data that was stored in the buffer.
    
        % trigger configuration
        fprintf(obj,'trig:conf LOOP');                      % An output trigger is autometically works as input trigger
        fprintf(obj,'TRIG1:OUTP DIS');                      % PD output trigger is disabled
        fprintf(obj,'TRIG1:INP SME');                       % PD will finish a function when input trigger is abled
        fprintf(obj,'TRIG0:OUTP STF');                      % TLS will send a output trigger when sweep starts (input trigger generated)
        fprintf(obj,'TRIG0:INP IGN');                       % (TLS input trigger is ignored)
    
        % sensor setting
        fprintf(obj,'init1:cont 1');                        % Continuous detection mode
        fprintf(obj,['sens1:pow:atim ' num2str(avg_time)]);     % set the averagetime to 1ms for sensor 2
        fprintf(obj,'sens1:pow:rang:auto 0');               % set auto ranging on
        fprintf(obj,'sens1:pow:rang %dDBM', sensRange);
        fprintf(obj,'sens1:pow:unit 0');                    % set the unit of power: 0[dBm],1[W]
        fprintf(obj,'sens1:pow:wav 1550nm');                % set sensor wavelength centered at 1550 nm
    
        % tunable laser setting
        fprintf(obj,'outp0:path low');                      % choose which path of tuable laser. output1 [low power high sens] output2 [high power]
        fprintf(obj,'sour0:pow:unit 0');                    % set source power unit
        fprintf(obj,'sour0:pow %d', outputPow);             % set laser power {unit will be according to the power unit set before}
        fprintf(obj,'sour0:AM:stat OFF');
    
        %continuous sweep setting
        fprintf(obj,'wav:swe:mode CONT');
        fprintf(obj,['wav:swe:spe ' num2str(scan_speed) 'nm/s']);   % only 0.5 5 40 allowed
        fprintf(obj,['wav:swe:star ' num2str(lambda_start) 'nm']);
        fprintf(obj,['wav:swe:step ' num2str(lambda_step) 'nm']);
        fprintf(obj,['wav:swe:stop ' num2str(lambda_stop) 'nm']);
        fprintf(obj,'wav:swe:cycl 1');
    
        fprintf(obj,['sens1:func:par:logg ' num2str(points) ',' num2str(avg_time)]);
        fprintf(obj,'sens1:func:stat logg,star');
        fprintf(obj,'wav:swe STAR');
        t = 0;
        while str2num(query(obj,'wav:swe?'))==1
            t = t+1;
        end 
        fprintf(obj,'sour0:wav:swe:llog 1');
        fprintf(obj,'sour0:read:data? llog');
        [wave_read,cont_wave,msg_1]=binblockread(obj,'double');
        fprintf(obj,'sens1:func:res?');
        [I,cont,msg] = binblockread(obj,'float');
        
        Itotal = [Itotal; I];
        lambdatotal = [lambdatotal; wave_read(1:end)]; 
    
        fprintf(obj,'sens1:pow:rang:auto 1');               % set auto ranging on
        fprintf(obj,'TRIG1:INP IGN');                       % PD will finish a function when input trigger is abled
    end
    fprintf(obj,'sour0:wav 1550nm');                        % set the input wavelength back to 1550 nm for the next measurment
    fclose(obj);
    delete(obj);
    clear obj;
end

%export data
if ~isempty(outFolder) && ~exist(outFolder,'dir'); mkdir(outFolder); end
%fig = figure();
%plot(lambdatotal*1e9, Itotal, 'r');
%xlabel('wavelength(nm)');   ylabel('Transmission(Watts)');    title(file_name);
%set(gca, 'FontSize', 17, 'FontWeight', 'bold', 'linewidth',  2);
%saveas(fig, [outFolder, file_name '.fig']);

%outputting the data to a csv
%DATA = [lambdatotal, Itotal,(10*log10(Itotal)+30)];                       
%headers = {'wavelength(nm)', 'power(Watts)', 'power(dBm)'};%axis label change
%dlmwrite([outFolder, file_name, '.csv'], DATA, 'delimiter',',', 'precision', '%0.16f');

DATA = [lambdatotal, Itotal];
headers = {'wavelength(nm)', 'power'};
dlmwrite([outFolder file_name, '.csv'], DATA, 'delimiter',',', 'precision', '%0.16f');

%saveFile(DATA, fileHeader, loc, filename, '', timeStampFlag)

% function saveFile(DATA, fileHeader, loc, filename, suffix, timeStampFlag)
%     if timeStampFlag
%         d = datevec(now);
%         timestamp = sprintf('%d%1.2d%1.2d_%1.2d%1.2d_',d(1),d(2),d(3),d(4),d(5));
%         filename = strcat(timestamp, filename);
%     end
%     %fname = fullfile(loc,[filename, suffix, '.txt']); 
%     fname = fullfile(loc,[filename, suffix, '.csv']);
% 
%     % Write Data Header
%     fileID = fopen(fname, 'w+');
%     fprintf(fileID, fileHeader);
%     fclose(fileID);
% 
%     % Store Data
%     writematrix(DATA, fname,'WriteMode','append')
% end





