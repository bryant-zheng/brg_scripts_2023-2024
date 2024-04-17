#-*- coding: utf-8 -*-
# Python for Test and Measurement

# Requires VISA installed on Control PC
# 'http://www.agilent.com/find/visa'
# Requires PyVISA to use VISA in Python
# 'http://pyvisa.sourceforge.net/pyvisa/'

# Keysight IO Libraries 18.1.24130.0
# Anaconda Python 3.7.1 64 bit
# pyvisa 1.10.1 

##"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
## Copyright © 2020 Agilent Technologies Inc. All rights reserved.
##
## You have a royalty-free right to use, modify, reproduce and distribute this
## example files (and/or any modified version) in any way you find useful, provided
## that you agree that Agilent has no warranty, obligations or liability for any
## Sample Application Files.
##
##"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

# Example Description:  
#    This example setups a tunable laser sweep and power meter logging operation to measure power vs. wavelength

# Required Instrument Setup to Execute Example: 
#    N777xC Tunable Laser
#    N774xA/C MultiPort Power Meter

# import python modules
 
import pyvisa
import sys
import math
import time
import matplotlib.pyplot as plt
import numpy as np

# =========================================================
# Settings:
# PMaddr = "GPIB0::10::INSTR"
# TLSaddr = "GPIB0::22::INSTR"''

PMaddr = "TCPIP0::100.65.16.169::inst0::INSTR" #POWER METER
TLSaddr = "TCPIP0::100.65.16.165::inst0::INSTR" #TUNABLE LASER SOURCE

PMslot = "1"
TLSslot = "0"
start = "1250" #wavelength start
stop = "1350" #wavelength end
step = "1"  #wavelength steps
speed = "40"
TLSpower = "5"
path = "high"  #lows / high
PMrange = "10"
PMavg = "100"
calcpoints = (float(stop)-float(start))*1000/float(step)+1
exppoints = str(int(calcpoints))

# =========================================================

# ERROR HANDLING

def inst_err(inst):
    ## Query for Errors
    error_list = []
    i=0
    while True:
        inst.write(":SYSTem:ERRor?")
        error = inst.read()
        error_list.append(error)
        i = i + 1
        if 'No error' in error:
            break
    return error_list

try:
    #Open Connection
    rm = pyvisa.ResourceManager()
    #Connect to VISA Address
    #LAN - VXI-11 Connection:  'TCPIP0::xxx.xxx.xxx.xxx::inst0::INSTR'
    #LAN - HiSLIP Connection:  'TCPIP0::xxx.xxx.xxx.xxx::hislip0::INSTR'
    #USB Connection: 'USB0::xxxxxx::xxxxxx::xxxxxxxxxx::0::INSTR'
    #GPIB Connection:  'GPIP0::xx::INSTR'
    
    #Open Visa Connections
    tls = rm.open_resource(TLSaddr)
    if PMaddr == TLSaddr:
        pm = tls
    else:
        pm = rm.open_resource(PMaddr)

    #Set Timeout - 5 seconds
    tls.timeout = 10000
    pm.timeout =  10000
    
    #*IDN? - Query Instrumnet ID
    tls_id = tls.query("*IDN?")
    print("TLS_idn: " + str(tls_id))
    pm_id = pm.query("*IDN?")
    print("PM_idn: " + str(pm_id))
    
    # SETTING UP THE SWEEP
    
    # LambdaScan Program - TLS sweep setup
    tls.write("lock 0,1234")
    tls.write("outp"+TLSslot+":path "+path)
    tls.write("trig:conf loop")
    tls.write("sour"+TLSslot+":pow:stat 1")#switches laser/power source on/off
    tls.write("sour"+TLSslot+":pow:stat?")#queries the power state
    tlsState = tls.read() #waits for laser ready
    tls.write("trig"+TLSslot+":outp stf")
    tls.write("trig"+TLSslot+":inp sws")
    tls.write("sour"+TLSslot+":wav:swe:star "+start+"nm")
    tls.write("sour"+TLSslot+":wav:swe:stop "+stop+"nm")
    tls.write("sour"+TLSslot+":wav:swe:step "+step+"pm")
    tls.write("sour"+TLSslot+":wav:swe:spe "+speed+"nm/s")
    tls.write("sour"+TLSslot+":wav:swe:mode cont")
    tls.write("sour"+TLSslot+":wav:swe:llog 1")
    tls.write("sour"+TLSslot+":wav:swe:chec?")
    sweepcheck =  tls.read()
    if sweepcheck[0] == "0":
        pass
    else:
        print(sweepcheck)
        tls.close()
        if PMaddr == TLSaddr:
            pass
        else:
            pm.close()
        sys.exit()
    
    # CHECKING POWER: LambdaScan Program - TLS power check
    #pm.write("*CLS") #preset system?
    
    tls.write("sour"+TLSslot+":wav:swe:pmax? "+start+"nm,"+stop+"nm")
    SWPpower = 10*math.log10(1000*float(tls.read()))
    if SWPpower < float(TLSpower):
        TLSpower = str(SWPpower)
    tls.write("sour"+TLSslot+":pow "+TLSpower+"dbm")
    
    # CHECKING TIME: LambdaScan Program - PM averaging time check
   
    tls.write("sour"+TLSslot+":wav:swe:exp?")
    exppoints = str(int(tls.read()))
    interval = 1000*float(step)/float(speed)
    if float(PMavg)<interval:
        pass
    else:
        pm.write("sens"+PMslot+":pow:atim "+str(interval)+"us")
        pm.write("sens"+PMslot+":pow:atim?")
        atimeSetting = pm.read()
        if float(atimeSetting)*1E6<=interval:
            PMavg = atimeSetting
            print("Averaging Time was reduced to "+atimeSetting)
        else:
            print("Step duration too short for power meter.")
            tls.close()
            if PMaddr == TLSaddr:
                pass
            else:
                pm.close()
            sys.exit()
            
    # LambdaScan Program - Arm TLS sweep
    tls.write("sour"+TLSslot+":wav:swe 1")
    
    # SETTING UP POWER METER LOGS: LambdaScan Program - Setup PM logging
    
    pm.write("trig"+PMslot+":inp SME")
    pm.write("sens"+PMslot+":pow:unit 1") #0 for dBm, 1 for watts
    pm.write("sens"+PMslot+":pow:rang:auto 0")
    pm.write("sens"+PMslot+":pow:rang "+PMrange+"dbm")
    pm.write("sens"+PMslot+":pow:rang?")
    answer = pm.read() #wait for range setting
    pm.write("sens"+PMslot+":pow:wav 1550nm")
    pm.write("sens"+PMslot+":func:par:logg "+exppoints+","+PMavg+"us")
    pm.write("sens"+PMslot+":func:stat logg,star")
    
    tlsFlag = 0
    while tlsFlag == 0:
        tls.write("sour"+TLSslot+":wav:swe:flag?")
        tlsFlag = int(tls.read())
    
    # STARTING THE SWEEP: LambdaScan Program - Initiate sweep
   
    tls.write("sour"+TLSslot+":wav:swe:soft")
    estSweepTime = (float(stop)-float(start))/float(speed)
    time.sleep(estSweepTime)
    
    # CHECKING THAT POWER METER LOGS ARE DONE: LambdaScan Program - Check for PM logging complete
    
    loggingStatus = "PROGRESS"
    while loggingStatus.endswith("PROGRESS"):
        pm.write("sens"+PMslot+":func:stat?")
        loggingStatus = pm.read().strip()
        time.sleep(0.1)
        
    # ADDING THE DATA: LambdaScan Program - Query PM data
    
    powerdata = pm.query_binary_values("sens"+PMslot+":func:result?","f", False)
    
    # CHECKING THAT THE SWEEPS ARE DONE: LambdaScan Program - Check for laser sweep complete
   
    tls.write("sour"+TLSslot+":wav:swe:flag?")
    tlsFlag2 = int(tls.read())
    while tlsFlag == tlsFlag2:
        tls.write("sour"+TLSslot+":wav:swe:flag?")
        tlsFlag2 = int(tls.read())
        time.sleep(0.1)
        
    # LambdaScan Program - Query TLS lambda logging 
    wavelengthdata = tls.query_binary_values("sour"+TLSslot+":read:data? llog","d", False)

    # ERROR HANDLING: Query for Errors
    
    print("tls errors: " + str(inst_err(tls)))
    print("pm errors: " + str(inst_err(pm)))
    
    tls.close()
    if PMaddr == TLSaddr:
        pass
    else:
        pm.close()
        
    # FILE WRITING: Open file for output.
    
    strPath = "apr10_keysight_python_testing_G=0.2.csv"
    f = open(strPath, "w")
    # Output spectrum in CSV format.
    for i in range(int(exppoints)):
        f.write("%E, %f\n" % (wavelengthdata[i], powerdata[i]))

    # Close output file.
    f.close()  
    
    # PLOTTING: plot results of sweep
    # mywavelength = np.array(wavelengthdata)
    # mypower = np.array(powerdata)
    #
    # plt.plot(mywavelength,mypower)
    # plt.xlabel('Wavelength')
    # plt.ylabel('Power')
    # plt.title('Power vs Wavelength G=TESTING')
    #
    # plt.savefig('testsweep_G=TESTING_MAR14.png')
    #
    # plt.show()
    
    ## Close Visa Connection
    print ("tls_pm sweep complete")
    
except Exception as err:
    print ('Exception: ' + str(err))
    
finally:
    #perform clean up operations
    print ('complete')
        
   