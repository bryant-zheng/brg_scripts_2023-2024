% Code based on work by Dr. H. Frankis, Xin Xin, and Dylan G-O
% Modificaitions by Arthur Mendez-Rosales, Bryant Zheng
% Laser(Agilent 8164A) programming guide can check:
% http://www.doe.carleton.ca/~nagui/labequip/lightwave/8164A_Programming%20Guide.pdf
% Latest modificaitions by: Bryant Zheng
% 2024/04/01

%This code takes in paramters (output power, wavelenth range, number of
%wavelength steps) and outputs a matlab graph and an excel file with the
%wavelength in column 1, the power in watts, and the converted power in
%dBm. The laser is measured in watts.

%the only parameters that should be changed are below, under "adjustable parameters" 

%1550 agilent
%1310 keysight

clear; instrreset;

%% adjustable parameters start----------------------
outputPow = 2;
sensRange = -10;
lambdaList = {[1250, 1350]};                                        %start and stop wavelengths
lambda_step = 0.02;                                                 %step size of the sweep
fileBeginning = 'tester';
loc = ""                                                            
fileName = ""
suffix = ""
timeStampFlag = true
%% adjustable parameters end----------------------

%file naming and output
file_name = sprintf('%s (%0.0f-%0.0f), OP=%0.0f - %s', fileBeginning, lambdaList{1}(1), lambdaList{end}(end), outputPow, datestr(now, 'yyyy.mm.dd'));
polName = regexp(fileBeginning, 'T(E|M)', 'match', 'once');
outFolder = [pwd '\' regexprep(fileBeginning, {',',[' ' polName]}, '') '\' polName '\Coarse Sweep\'];

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

  
    %fprintf(det, 'SENS1:POW:UNIT 1'); %sets the unit of power: 0[dBm], 1[W]
    fprintf(det, 'SENS1:POW:UNIT 0');

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

%export data
if ~isempty(outFolder) && ~exist(outFolder,'dir'); mkdir(outFolder); end
fig = figure();
plot(lambdatotal*1e9, Itotal, 'r');
xlabel('wavelength(nm)');   ylabel('Transmission(Watts)');    title(file_name);
set(gca, 'FontSize', 17, 'FontWeight', 'bold', 'linewidth',  2);
saveas(fig, [outFolder, file_name '.fig']);

%outputting the data to a csv
%DATA = [lambdatotal, Itotal,(10*log10(Itotal*1000))];                       
%headers = {'wavelength(nm)', 'power(Watts)', 'power(dBm)'};%axis label change

DATA = [lambdatotal, Itotal];                       
headers = {'wavelength(nm)', 'power(dBm)'};%axis label change
% headers = {'wavelength(nm)', 'power(Watts)', 'power(dBm)'};%axis label change

dlmwrite([outFolder, file_name, '.csv'], DATA, 'delimiter',',', 'precision', '%0.16f');
%saveFile(DATA, fileHeader, loc, filename, suffix, timeStampFlag)

%% AUXILIARY FUNCTIONS
function saveFile(DATA, fileHeader, loc, filename, suffix, timeStampFlag)
    if timeStampFlag
        d = datevec(now);
        timestamp = sprintf('%d%1.2d%1.2d_%1.2d%1.2d_',d(1),d(2),d(3),d(4),d(5));
        filename = strcat(timestamp, filename);
    end
    fname = fullfile(loc,[filename, suffix, '.txt']);
    
    % Write Data Header
    fileID = fopen(fname, 'w+');
    fprintf(fileID, fileHeader);
    fclose(fileID);
    
    % Store Data
    writematrix(DATA, fname,'WriteMode','append')
end

