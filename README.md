tips and intro to the keysight and agilent laser/detector setups.
last modified on april 3, 2024 by bryant zheng, zhengb33@mcmaster.ca

use a windows machine

keysight:
- newer
- separate machines for laser and detector
- the laser is called n777 and the dectector is called n774 on your computer
- each needs to be connected via usb. inputs for both should show up on your file explorer; click the "start" for both and control instruments
- both the laser and detector will have to be turned on physically on the machine
- visa connection

agilent:
- older
- single machine for laser and detector
- will not be a popup when connected via usb
- will have to be turned on physically on the machine
- gpib connection

main scripts to look at are the individual scripts for the keysight setup, the individual scripts for the agilent setup, and "combined_keysight_agilent_script.m"

at the most basic form, the individual code essentially consists of
1. adjustable parameters, where the user can change wavelengths, output power, file name, etc.
2. file naming and output
3. setting up connections
4. setting up the laser and detector
5. doing the wavelength sweep
6. exporting the data
7. writing the data to a csv file and plotting it

the scripts for the keysight and agilent are different, especially concerning parts 3-5, but there are comments in the individual codes for clarity. the combined script is basically the individual scripts meshed together into one script.
