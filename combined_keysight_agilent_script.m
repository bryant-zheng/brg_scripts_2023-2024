% Code based on work by Dr. H. Frankis, Xin Xin, and Dylan G-O
% Modificaitions by Arthur Mendez-Rosales

% Laser(Agilent 8164A) programming guide can check:
% http://www.doe.carleton.ca/~nagui/labequip/lightwave/8164A_Programming%20Guide.pdf

% Latest modificaitions by: Arthur Mendez-Rosales
% Rev4
% 2024/04/09

%% INITIALIZATION
clc;
close all;
clear;
instrreset;
set(0,'DefaultFigureWindowStyle','docked'); % 'normal' for flaoting figure

%% USER PARAMETERS
% File
loc = 'C:\Users\buhry\OneDrive\Desktop\scriptdata';
% film = 'T90wCytop';
film = 'T98';
pol = 'TM'; % polarization
R = 500;  % [um]
G = 600;  % [nm]
W = 1600;  % [nm]
filename = sprintf('%s_%spol_R%d_G%d_W%d',...
    film, pol, R, G, W);
timeStampFlag = false; % Add timestamp to filwe ending

% Laser
laserOff = false;  % Turn laser off after sweep?
sweepParams.laserPower = -5;  % [dBm] laser output power

sweepParams.lambda_start = 1575; % [nm] start wavelength
sweepParams.lambda_stop = 1615; % [nm] stop wavelength
sweep_type = 'coarse';
%sweep_type = 'fine';

sweepParams.avg_time = 2E-4; % photodiode average time

% Sensor
sweepParams.sensRange = -10; % -110 dBm < x < 30 dBm 

%% DEPENDENT AND DEFAULT PARAMETERS
% Set Sweep Type resolution and speed parameters
switch sweep_type
    case 'fine'
        sweepParams.lambda_step = 0.0002; % [nm] wavelength step
        sweepParams.scan_speed = 0.5; % nm/s Only 0.5 5 40 allowed
    case 'coarse'
        sweepParams.lambda_step = 0.01; % [nm] wavelength step
        sweepParams.scan_speed = 5; % nm/s Only 0.5 5 40 allowed
    otherwise

end
% Append wavelength range to name
filename = [filename sprintf('_%d-%dnm_%s', sweepParams.lambda_start,sweepParams.lambda_stop, sweep_type)];
% Handle laser internal memory limitations
lam = (sweepParams.lambda_start:sweepParams.lambda_step:sweepParams.lambda_stop)'; % unit 'nm'
points = length(lam); % set number of points
maxPoints = 12e3;  % Agilent max. sensor menory 12k points
n_full_sweeps = floor(points/maxPoints);
points_remainining = points - maxPoints * n_full_sweeps;
for ii = 1:n_full_sweeps
    ind_start = 1 + maxPoints * (ii - 1);
    ind_end = maxPoints * ii; 
    lambda{ii} = lam(ind_start:ind_end);
end
if n_full_sweeps == 0  % no sub-sweeps needed
    lambda = lam;
    n_sweeps = 1;
else
    lambda{end+1} = lam(end-points_remainining:end);
    n_sweeps = length(lambda);  % total number of sub-sweeps
end
sweepParams.lambda = lambda;
% Output file header
fileHeader = 'Wavelength (nm),  Power (dBm), Power (mW)';

%% GPIB SETTINGS
fprintf('GPIB-Laser Connection Setup...\n');
% Aglient(Tunable Laser) Setting
laser = visadev("GPIB0::20::INSTR");  % Agilent
% laser = visadev("TCPIP0::100.65.16.165::inst0::INSTR");  % BSBB204 O-band Keysight
set(laser,'InputBufferSize', 1000000);

fprintf('GPIB-Laser Connection Successfull.\n');

%% SWEEP
DATA = [];
for ii = 1:n_sweeps
    clc;
    fprintf('Wavelength Sweep in Progress (%2.1f%%)...\n',100 * (ii-1)/n_sweeps);
    DATA = [DATA; laserSweep(laser, sweepParams, ii)];
end
clc;
fprintf('Wavelength Sweep in Progress (%2.1f%%)...\n',100 * ii/n_sweeps);

% Close Instrument Connections
if laserOff
    write(laser,'OUTP:STAT OFF');
end
clear laser;
fprintf('Wavelength Sweep Finished.\n');

%% VISUALIZE AND SAVE
fprintf('Plotting and Saving Data...\n');
hold on
plot(1e9 .* DATA(:,1), DATA(:,2));
plot(1e9 .* DATA(:,1), DATA(:,2));
plot(1e9 .* DATA(:,1), DATA(:,2));
plot(1e9 .* DATA(:,1), DATA(:,2));



hold off
grid on; grid minor;
legend('Raw', 'Smooth 3', 'Smooth 5', 'Smooth 10')
xlim([sweepParams.lambda_start sweepParams.lambda_stop]);
xlabel('Wavelength [nm]'); ylabel('Power [dBm]');

saveFile(DATA, fileHeader, loc, filename, '', timeStampFlag)
fprintf('Program Finished.\n');

%% AUXILIARY FUNCTIONS
function sweep_data = laserSweep(laser, sweepParams, sweep_index)
    % Unpack Sweep Parameters
    laserPower = sweepParams.laserPower;
    try
        lambda = sweepParams.lambda{sweep_index};
    catch
        lambda = sweepParams.lambda;
    end
    lambda_start = lambda(1);
    lambda_stop = lambda(end);
    lambda_step = sweepParams.lambda_step;
    scan_speed = sweepParams.scan_speed;
    avg_time = sweepParams.avg_time;
    sensRange = sweepParams.sensRange;
    points = length(lambda); % set number of points
    lambda_reset = sweepParams.lambda_start;  % [nm] wavelength after sweep
    % ---------------------------------------------------------------------
    % Aglient(Tunable Laser) Setting
    write(laser,'*RST'); write(laser,'*CLS'); % instrument setting reset
    flush(laser,'input'); flush(laser,'output'); % flush the data that was stored in the buffer.
    write(laser,'OUTP:STAT OFF');  % turn laser emission off before confiFguration
    % % Trigger configuration
    write(laser,'trig:conf LOOP'); % an output trigger is autometically works as input trigger
    write(laser,'TRIG1:OUTP DIS'); % PD output trigger is disabled
    write(laser,'TRIG1:INP SME'); % PD will finish a function when input trigger is abled
    write(laser,'TRIG0:OUTP STF'); % TLS will send a output trigger when sweep starts (input trigger generated)
    write(laser,'TRIG0:INP IGN'); % (TLS input trigger is ignored)
    % % Sensor settings
    write(laser,'init1:cont 1'); % continuous detection mode
    write(laser,['sens1:pow:atim ' num2str(avg_time)]); % set the averagetime to 1ms for sensor 2
    write(laser,'sens1:pow:rang:auto 0'); % set auto ranging on
    write(laser,['sens1:pow:rang ' num2str(sensRange) 'DBM']);
    write(laser,'sens1:pow:unit 0'); % set the unit of power: 0[dBm],1[W]
    write(laser,'sens1:pow:wav 1550nm'); % set senser wavelength centered at 1550 nm
    % % Tunable laser settings
    % write(laser,'output0:path low');  % [low power high sens]
    write(laser,'output0:path high'); % [high power]
    write(laser,'sour0:pow:unit 0'); % set source power unit
    write(laser,['sour0:pow ' num2str(laserPower)]); % sset laser power {unit will be according to the power unit set before}
    write(laser,'sour0:AM:stat OFF');
    % % Continuous sweep setting
    write(laser,'wav:swe:mode CONT');
    write(laser,['wav:swe:spe ' num2str(scan_speed) 'nm/s']); % only 0.5 5 40 allowed
    write(laser,['wav:swe:star ' num2str(lambda_start) 'nm']);
    write(laser,['wav:swe:step ' num2str(lambda_step) 'nm']);
    write(laser,['wav:swe:stop ' num2str(lambda_stop) 'nm']);
    write(laser,'wav:swe:cycl 1');
    % ---------------------------------------------------------------------
    % Sweep Pre-Settings
    write(laser,'OUTP:STAT ON');
    write(laser,['sens1:func:par:logg ' num2str(points) ',' num2str(avg_time)]);
    write(laser,'sens1:func:stat logg,star');
    % ---------------------------------------------------------------------
    % % % % % SWEEP % % % % % 
    write(laser,'sour0:wav:swe:llog 1');
    write(laser,'wav:swe STAR');
    t=0;
    while str2double(writeread(laser,'wav:swe:stat?')) == 1
        t=t+1; % +1 sweep is running, +0 sweep is not running
    end
    % ---------------------------------------------------------------------
    % Data Extraction
    % % Get Sensor Data from Laser
    write(laser,'sens1:func:res?');
    T_W = readbinblock(laser,'single');
    T_dBm = 10.*log10(T_W ./ 0.001);  % [W] --> [dBm]
    % % Get Wavelength Range from Laser
    % write(laser,'sour0:wav:swe:llog 1');
    write(laser,'sour0:read:data? llog');
    lam = readbinblock(laser,'double');
    % % Store Data [nm dBm mW]
    sweep_data = [lam' T_dBm' 1e3.*(T_W)'];
    % ---------------------------------------------------------------------
    % Finalize
    write(laser,'sens1:pow:rang:auto 1'); % set auto ranging on
    write(laser,'TRIG1:INP IGN'); % PD will finish a function when input trigger is enabled
    write(laser,['sour0:wav ' num2str(lambda_reset) 'nm']); % set reset wavelength
end

function saveFile(DATA, fileHeader, loc, filename, suffix, timeStampFlag)
    if timeStampFlag
        d = datevec(now);
        timestamp = sprintf('%d%1.2d%1.2d_%1.2d%1.2d_',d(1),d(2),d(3),d(4),d(5));
        filename = strcat(timestamp, filename);
    end
    %fname = fullfile(loc,[filename, suffix, '.txt']); 
    fname = fullfile(loc,[filename, suffix, '.csv']);
    
    % Write Data Header
    fileID = fopen(fname, 'w+');
    fprintf(fileID, fileHeader);
    fclose(fileID);
    
    % Store Data
    writematrix(DATA, fname,'WriteMode','append')
end
