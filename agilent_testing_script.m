% Code based on work by Dr. H. Frankis, Xin Xin, and Dylan G-O
% Modificaitions by Arthur Mendez-Rosales, Bryant Zheng
% Laser(Agilent 8164A) programming guide can check:
% http://www.doe.carleton.ca/~nagui/labequip/lightwave/8164A_Programming%20Guide.pdf
% Latest modificaitions by: Bryant Zheng
% 2024/04/01

%This code takes in paramters (output power, wavelenth range, number of
%wavelength steps) and outputs a matlab graph and an excel file

%the only parameters that should be changed are below, under "adjustable parameters" 

% close all;
clear; clc;
% reset connected instrument
instrreset

% % Adjustable Parameters
outputPow = -5;
sensRange = -20;
lambdaList = {[1510 1580], [1580 1640]};

% fileBeginning = 'P304_L1-1.7_L2-1.1_GW10_T112, TE';
% fileBeginning = 'W450_R20_G0.6_P420_L300_GW10_T112pulley, TE';
% fileBeginning = 'C5, L=5, W=1.5, Chip 5 (2102PH), TE';
fileBeginning = 'tester';

% % Main Code
file_name = sprintf('%s (%0.0f-%0.0f), OP=%0.0f - %s', fileBeginning, lambdaList{1}(1), lambdaList{end}(end), outputPow, datestr(now, 'yyyy.mm.dd'));
polName = regexp(fileBeginning, 'T(E|M)', 'match', 'once');
outFolder = [pwd '\' regexprep(fileBeginning, {',',[' ' polName]}, '') '\' polName '\Coarse Sweep\'];

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

%Export Data
if ~isempty(outFolder) && ~exist(outFolder,'dir'); mkdir(outFolder); end

%fig = figure();
%plot(lambdatotal*1e9, 10*log10(Itotal/0.001), 'r');
%xlabel('wavelength(nm)');   ylabel('Transmission(dBm)');    title(file_name);
%set(gca, 'FontSize', 17, 'FontWeight', 'bold', 'linewidth', 2);
%saveas(fig, [outFolder file_name '.fig']);
DATA = [lambdatotal, Itotal];
headers = {'wavelength(nm)', 'power(Watt)'};
dlmwrite([outFolder file_name, '.csv'], DATA, 'delimiter',',', 'precision', '%0.16f');



