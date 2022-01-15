#start

# CHANGELOG:
# Added/Changed Slot D, 1c.0 for secondary M.2 Slot, changed the other slot names to match
# Changed Run functions to be Subprocess.Popen (was Subprocess.call) due to issues where one drive would fail and cause the script to stop all drives,
# this opens an individual process for each window.
#
# Changed Backplane name to Sideboard
# Added Variables for the find functions on each slot (UID's for Individual Slots)
# Added Information regarding Finding the UID Location and identifying a UID in a new setup.
# Added secondary input loop to make re-entering user input less spammy.
# Changed Run functions to now be multiple Subprocess.Popen's, attempting potential speed improvement by importing threading. If fails will rollback change.
 
import subprocess
import os

#Main Menu of Variables (for quickly changing script values in case new setup)
#Find Variables
"""
Used with finding the Unique Identifier (UID) for either the Motherboard or the Backplane / Sideboard / Expansion Slots,
and then finding that UID between the Find_Start and Find_End variables.
Use ONLY 1 PCIE drive IN THE ENTIRE SYSTEM to test with each slot, using "ls -l /sys/block/nvme0n1" in the terminal.
For each slot, note which #'s change. Most of what that command prints will be largely the same, but there is a difference.

Use this script as an example to see UID's in this setup. (90 for Mobo, 142 for Sideboard). You can count along the 
characters to see what the UID in the current setup is, if you use the "ls -l /sys/block/nvme0n1" command in this setup.
To see if the UID you have selected is correct, enter the following commands in the terminal, in order;

#start
python
import os, subprocess
UID_nvme0n1 = subprocess.check_output(['ls', '-l', '/sys/block/nvme0n1'])
UID_nvme0n1.find('INSERT_YOUR_UID_HERE_WITHIN_SINGLE_QUOTES_EXAMPLE_IS_'01.0'_', 1, 10000)
#end

Whatever number is printed from the "UID_nvme0n1.find" command is, will be your UID's location (and thus the UID_Location 
variable down below).  
"""
#Motherboard 
UID_Location_Motherboard = 90
Find_Start_Motherboard = 64
Find_End_Motherboard = 96

#Sideboard / Backplane / Expansion Slots
UID_Location_Sideboard = 142
Find_Start_Sideboard = 130
Find_End_Sideboard = 150

#UID's for Individual Slots
Slot_A = '01.0'
Slot_B = '01.2'
Slot_C = '01.1'
Slot_D = '1c.0'
Slot_E = '1c.4'
Slot_F = '01.0'
Slot_G = '05.0'
Slot_H = '07.0'
Slot_I = '09.0'

#UID (Unique Identification (ID)) Variable Creation & Error Checking
#UID nvme0n1
if subprocess.call(['ls', '-l', '/sys/block/nvme0n1'], stdout=open(os.devnull, 'wb'), stderr=open(os.devnull, 'wb')) == 2:
	print("/dev/nvme0n1 not found!")
	UID_nvme0n1 = "NULL"
else:
	UID_nvme0n1 = subprocess.check_output(['ls', '-l', '/sys/block/nvme0n1'])

#UID nvme1n1
if subprocess.call(['ls', '-l', '/sys/block/nvme1n1'], stdout=open(os.devnull, 'wb'), stderr=open(os.devnull, 'wb')) == 2:
	print("/dev/nvme1n1 not found!")
	UID_nvme1n1 = "NULL"
else:
	UID_nvme1n1 = subprocess.check_output(['ls', '-l', '/sys/block/nvme1n1'])

#UID nvme2n1
if subprocess.call(['ls', '-l', '/sys/block/nvme2n1'], stdout=open(os.devnull, 'wb'), stderr=open(os.devnull, 'wb')) == 2:
	print("/dev/nvme2n1 not found!")
	UID_nvme2n1 = "NULL"
else:
	UID_nvme2n1 = subprocess.check_output(['ls', '-l', '/sys/block/nvme2n1'])

#UID nvme3n1
if subprocess.call(['ls', '-l', '/sys/block/nvme3n1'], stdout=open(os.devnull, 'wb'), stderr=open(os.devnull, 'wb')) == 2:
	print("/dev/nvme3n1 not found!")
	UID_nvme3n1 = "NULL"
else:
	UID_nvme3n1 = subprocess.check_output(['ls', '-l', '/sys/block/nvme3n1'])

#UID nvme4n1
if subprocess.call(['ls', '-l', '/sys/block/nvme4n1'], stdout=open(os.devnull, 'wb'), stderr=open(os.devnull, 'wb')) == 2:
	print("/dev/nvme4n1 not found!")
	UID_nvme4n1 = "NULL"
else:
	UID_nvme4n1 = subprocess.check_output(['ls', '-l', '/sys/block/nvme4n1'])

#UID nvme5n1
if subprocess.call(['ls', '-l', '/sys/block/nvme5n1'], stdout=open(os.devnull, 'wb'), stderr=open(os.devnull, 'wb')) == 2:
	print("/dev/nvme5n1 not found!")
	UID_nvme5n1 = "NULL"
else:
	UID_nvme5n1 = subprocess.check_output(['ls', '-l', '/sys/block/nvme5n1'])

#UID nvme6n1
if subprocess.call(['ls', '-l', '/sys/block/nvme6n1'], stdout=open(os.devnull, 'wb'), stderr=open(os.devnull, 'wb')) == 2:
	print("/dev/nvme6n1 not found!")
	UID_nvme6n1 = "NULL"
else:
	UID_nvme6n1 = subprocess.check_output(['ls', '-l', '/sys/block/nvme6n1'])

#UID nvme7n1
if subprocess.call(['ls', '-l', '/sys/block/nvme7n1'], stdout=open(os.devnull, 'wb'), stderr=open(os.devnull, 'wb')) == 2:
	print("/dev/nvme7n1 not found!")
	UID_nvme7n1 = "NULL"
else:
	UID_nvme7n1 = subprocess.check_output(['ls', '-l', '/sys/block/nvme7n1'])

print(30 * "-")

#Slot Checking Locations/Names
#Slot A (01.0)
if (UID_nvme0n1.find(Slot_A, Find_Start_Motherboard, Find_End_Motherboard)) == UID_Location_Motherboard:
	print("nvme0n1 is in Slot A! (aka 01.0)")
elif UID_nvme1n1.find(Slot_A, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme1n1 is in Slot A! (aka 01.0)")
elif UID_nvme2n1.find(Slot_A, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme2n1 is in Slot A! (aka 01.0)")
elif UID_nvme3n1.find(Slot_A, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme3n1 is in Slot A! (aka 01.0)")
elif UID_nvme4n1.find(Slot_A, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme4n1 is in Slot A! (aka 01.0)")
elif UID_nvme5n1.find(Slot_A, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme5n1 is in Slot A! (aka 01.0)")
elif UID_nvme6n1.find(Slot_A, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme6n1 is in Slot A! (aka 01.0)")
elif UID_nvme7n1.find(Slot_A, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme7n1 is in Slot A! (aka 01.0)")
else:
	print("Nothing is in Slot A! (aka 01.0)")

#Slot B (01.2)
if (UID_nvme0n1.find(Slot_B, Find_Start_Motherboard, Find_End_Motherboard)) == UID_Location_Motherboard:
	print("nvme0n1 is in Slot B! (aka 01.2)")
elif UID_nvme1n1.find(Slot_B, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme1n1 is in Slot B! (aka 01.2)")
elif UID_nvme2n1.find(Slot_B, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme2n1 is in Slot B! (aka 01.2)")
elif UID_nvme3n1.find(Slot_B, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme3n1 is in Slot B! (aka 01.2)")
elif UID_nvme4n1.find(Slot_B, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme4n1 is in Slot B! (aka 01.2)")
elif UID_nvme5n1.find(Slot_B, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme5n1 is in Slot B! (aka 01.2)")
elif UID_nvme6n1.find(Slot_B, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme6n1 is in Slot B! (aka 01.2)")
elif UID_nvme7n1.find(Slot_B, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme7n1 is in Slot B! (aka 01.2)")
else:
	print("Nothing is in Slot B! (aka 01.2)")

#Slot C (01.1)
if (UID_nvme0n1.find(Slot_C, Find_Start_Motherboard, Find_End_Motherboard)) == UID_Location_Motherboard:
	print("nvme0n1 is in Slot C! (aka 01.1)")
elif UID_nvme1n1.find(Slot_C, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme1n1 is in Slot C! (aka 01.1)")
elif UID_nvme2n1.find(Slot_C, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme2n1 is in Slot C! (aka 01.1)")
elif UID_nvme3n1.find(Slot_C, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme3n1 is in Slot C! (aka 01.1)")
elif UID_nvme4n1.find(Slot_C, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme4n1 is in Slot C! (aka 01.1)")
elif UID_nvme5n1.find(Slot_C, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme5n1 is in Slot C! (aka 01.1)")
elif UID_nvme6n1.find(Slot_C, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme6n1 is in Slot C! (aka 01.1)")
elif UID_nvme7n1.find(Slot_C, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme7n1 is in Slot C! (aka 01.1)")
else:
	print("Nothing is in Slot C! (aka 01.1)")

#Slot D (1c.0)
if (UID_nvme0n1.find(Slot_D, Find_Start_Motherboard, Find_End_Motherboard)) == UID_Location_Motherboard:
	print("nvme0n1 is in Slot D! (aka 1c.0)")
elif UID_nvme1n1.find(Slot_D, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme1n1 is in Slot D! (aka 1c.0)")
elif UID_nvme2n1.find(Slot_D, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme2n1 is in Slot D! (aka 1c.0)")
elif UID_nvme3n1.find(Slot_D, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme3n1 is in Slot D! (aka 1c.0)")
elif UID_nvme4n1.find(Slot_D, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme4n1 is in Slot D! (aka 1c.0)")
elif UID_nvme5n1.find(Slot_D, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme5n1 is in Slot D! (aka 1c.0)")
elif UID_nvme6n1.find(Slot_D, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme6n1 is in Slot D! (aka 1c.0)")
elif UID_nvme7n1.find(Slot_D, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme7n1 is in Slot D! (aka 1c.0)")
else:
	print("Nothing is in Slot D! (aka 1c.0)")

#Slot E (1c.4)
if (UID_nvme0n1.find(Slot_E, Find_Start_Motherboard, Find_End_Motherboard)) == UID_Location_Motherboard:
	print("nvme0n1 is in Slot E! (aka 1c.4)")
elif UID_nvme1n1.find(Slot_E, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme1n1 is in Slot E! (aka 1c.4)")
elif UID_nvme2n1.find(Slot_E, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme2n1 is in Slot E! (aka 1c.4)")
elif UID_nvme3n1.find(Slot_E, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme3n1 is in Slot E! (aka 1c.4)")
elif UID_nvme4n1.find(Slot_E, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme4n1 is in Slot E! (aka 1c.4)")
elif UID_nvme5n1.find(Slot_E, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme5n1 is in Slot E! (aka 1c.4)")
elif UID_nvme6n1.find(Slot_E, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme6n1 is in Slot E! (aka 1c.4)")
elif UID_nvme7n1.find(Slot_E, Find_Start_Motherboard, Find_End_Motherboard) == UID_Location_Motherboard:
	print("nvme7n1 is in Slot E! (aka 1c.4)")
else:
	print("Nothing is in Slot E! (aka 1c.4)")

#Slot F (1c.3, 01.0)
if (UID_nvme0n1.find(Slot_F, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme0n1 is in Slot F! (aka 1c.3, 01.0)")
elif (UID_nvme1n1.find(Slot_F, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme1n1 is in Slot F! (aka 1c.3, 01.0)")
elif (UID_nvme2n1.find(Slot_F, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme2n1 is in Slot F! (aka 1c.3, 01.0)")
elif (UID_nvme3n1.find(Slot_F, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme3n1 is in Slot F! (aka 1c.3, 01.0)")
elif (UID_nvme4n1.find(Slot_F, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme4n1 is in Slot F! (aka 1c.3, 01.0)")
elif (UID_nvme5n1.find(Slot_F, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme5n1 is in Slot F! (aka 1c.3, 01.0)")
elif (UID_nvme6n1.find(Slot_F, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme6n1 is in Slot F! (aka 1c.3, 01.0)")
elif (UID_nvme7n1.find(Slot_F, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme7n1 is in Slot F! (aka 1c.3, 01.0)")
else:
	print("Nothing is in Slot F! (aka 1c.3, 01.0)")

#Slot G (1c.3, 05.0)
if (UID_nvme0n1.find(Slot_G, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme0n1 is in Slot G! (aka 1c.3, 05.0)")
elif (UID_nvme1n1.find(Slot_G, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme1n1 is in Slot G! (aka 1c.3, 05.0)")
elif (UID_nvme2n1.find(Slot_G, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme2n1 is in Slot G! (aka 1c.3, 05.0)")
elif (UID_nvme3n1.find(Slot_G, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme3n1 is in Slot G! (aka 1c.3, 05.0)")
elif (UID_nvme4n1.find(Slot_G, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme4n1 is in Slot G! (aka 1c.3, 05.0)")
elif (UID_nvme5n1.find(Slot_G, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme5n1 is in Slot G! (aka 1c.3, 05.0)")
elif (UID_nvme6n1.find(Slot_G, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme6n1 is in Slot G! (aka 1c.3, 05.0)")
elif (UID_nvme7n1.find(Slot_G, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme7n1 is in Slot G! (aka 1c.3, 05.0)")
else:
	print("Nothing is in Slot G! (aka 1c.3, 05.0)")

#Slot H (1c.3, 07.0)
if (UID_nvme0n1.find(Slot_H, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme0n1 is in Slot H! (aka 1c.3, 07.0)")
elif (UID_nvme1n1.find(Slot_H, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme1n1 is in Slot H! (aka 1c.3, 07.0)")
elif (UID_nvme2n1.find(Slot_H, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme2n1 is in Slot H! (aka 1c.3, 07.0)")
elif (UID_nvme3n1.find(Slot_H, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme3n1 is in Slot H! (aka 1c.3, 07.0)")
elif (UID_nvme4n1.find(Slot_H, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme4n1 is in Slot H! (aka 1c.3, 07.0)")
elif (UID_nvme5n1.find(Slot_H, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme5n1 is in Slot H! (aka 1c.3, 07.0)")
elif (UID_nvme6n1.find(Slot_H, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme6n1 is in Slot H! (aka 1c.3, 07.0)")
elif (UID_nvme7n1.find(Slot_H, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme7n1 is in Slot H! (aka 1c.3, 07.0)")
else:
	print("Nothing is in Slot H! (aka 1c.3, 07.0)")

#Slot I (1c.3, 09.0)
if (UID_nvme0n1.find(Slot_I, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme0n1 is in Slot I! (aka 1c.3, 09.0)")
elif (UID_nvme1n1.find(Slot_I, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme1n1 is in Slot I! (aka 1c.3, 09.0)")
elif (UID_nvme2n1.find(Slot_I, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme2n1 is in Slot I! (aka 1c.3, 09.0)")
elif (UID_nvme3n1.find(Slot_I, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme3n1 is in Slot I! (aka 1c.3, 09.0)")
elif (UID_nvme4n1.find(Slot_I, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme4n1 is in Slot I! (aka 1c.3, 09.0)")
elif (UID_nvme5n1.find(Slot_I, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme5n1 is in Slot I! (aka 1c.3, 09.0)")
elif (UID_nvme6n1.find(Slot_I, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme6n1 is in Slot I! (aka 1c.3, 09.0)")
elif (UID_nvme7n1.find(Slot_I, Find_Start_Sideboard, Find_End_Sideboard)) == UID_Location_Sideboard:
	print("nvme7n1 is in Slot I! (aka 1c.3, 09.0)")
else:
	print("Nothing is in Slot I! (aka 1c.3, 09.0)")

#Run NVME option from user input (NVME.py originally)
def run_NVMEpy()
	subprocess.Popen(['mate-terminal', '--window', '--geometry=61x9+0+0', '--title="/dev/nvme0n1"', '-e', 'bash -c "{ shred -fvzn0 /dev/nvme0n1 ; wait $1 & echo "Attempting_Hexdump" ; hexdump /dev/nvme0n1 ;}; exec /bin/bash -i;"'])
	subprocess.Popen(['mate-terminal', '--window', '--geometry=61x9+0+183', '--title="/dev/nvme1n1"', '-e', 'bash -c "{ shred -fvzn0 /dev/nvme1n1 ; wait $1 & echo "Attempting_Hexdump" ; hexdump /dev/nvme1n1 ;}; exec /bin/bash -i;"'])
	subprocess.Popen(['mate-terminal', '--window', '--geometry=61x9+0+366', '--title="/dev/nvme2n1"', '-e', 'bash -c "{ shred -fvzn0 /dev/nvme2n1 ; wait $1 & echo "Attempting_Hexdump" ; hexdump /dev/nvme2n1 ;}; exec /bin/bash -i;"'])
	subprocess.Popen(['mate-terminal', '--window', '--geometry=61x9+0+549', '--title="/dev/nvme3n1"', '-e', 'bash -c "{ shred -fvzn0 /dev/nvme3n1 ; wait $1 & echo "Attempting_Hexdump" ; hexdump /dev/nvme3n1 ;}; exec /bin/bash -i;"'])
	subprocess.Popen(['mate-terminal', '--window', '--geometry=61x9+520+0', '--title="/dev/nvme4n1"', '-e', 'bash -c "{ shred -fvzn0 /dev/nvme4n1 ; wait $1 & echo "Attempting_Hexdump" ; hexdump /dev/nvme4n1 ;}; exec /bin/bash -i;"'])
	subprocess.Popen(['mate-terminal', '--window', '--geometry=61x9+520+183', '--title="/dev/nvme5n1"', '-e', 'bash -c "{ shred -fvzn0 /dev/nvme5n1 ; wait $1 & echo "Attempting_Hexdump" ; hexdump /dev/nvme5n1 ;}; exec /bin/bash -i;"'])
	subprocess.Popen(['mate-terminal', '--window', '--geometry=61x9+520+366', '--title="/dev/nvme6n1"', '-e', 'bash -c "{ shred -fvzn0 /dev/nvme6n1 ; wait $1 & echo "Attempting_Hexdump" ; hexdump /dev/nvme6n1 ;}; exec /bin/bash -i;"'])
	subprocess.Popen(['mate-terminal', '--window', '--geometry=61x9+520+549', '--title="/dev/nvme7n1"', '-e', 'bash -c "{ shred -fvzn0 /dev/nvme7n1 ; wait $1 & echo "Attempting_Hexdump" ; hexdump /dev/nvme7n1 ;}; exec /bin/bash -i;"'])

#Run SATA / APPLE / USB option from user input (APPLE.py originally)
#Named SCSIpy due to Linux usage of SCSI drivers (sdb = SCSI Device "B")
def run_SCSIpy()
	subprocess.Popen(['mate-terminal', '--window', '--geometry=61x9+0+0', '--title="/dev/sdb"', '-e', 'bash -c "{ shred -fvzn0 /dev/sdb ; wait $1 & echo "Attempting_Hexdump" ; hexdump /dev/sdb ;}; exec /bin/bash -i;"'])
	subprocess.Popen(['mate-terminal', '--window', '--geometry=61x9+0+183', '--title="/dev/sdc"', '-e', 'bash -c "{ shred -fvzn0 /dev/sdc ; wait $1 & echo "Attempting_Hexdump" ; hexdump /dev/sdc ;}; exec /bin/bash -i;"'])
	subprocess.Popen(['mate-terminal', '--window', '--geometry=61x9+0+366', '--title="/dev/sdd"', '-e', 'bash -c "{ shred -fvzn0 /dev/sdd ; wait $1 & echo "Attempting_Hexdump" ; hexdump /dev/sdd ;}; exec /bin/bash -i;"'])
	subprocess.Popen(['mate-terminal', '--window', '--geometry=61x9+0+549', '--title="/dev/sde"', '-e', 'bash -c "{ shred -fvzn0 /dev/sde ; wait $1 & echo "Attempting_Hexdump" ; hexdump /dev/sde ;}; exec /bin/bash -i;"'])
	subprocess.Popen(['mate-terminal', '--window', '--geometry=61x9+520+0', '--title="/dev/sdf"', '-e', 'bash -c "{ shred -fvzn0 /dev/sdf ; wait $1 & echo "Attempting_Hexdump" ; hexdump /dev/sdf ;}; exec /bin/bash -i;"'])
	subprocess.Popen(['mate-terminal', '--window', '--geometry=61x9+520+183', '--title="/dev/sdg"', '-e', 'bash -c "{ shred -fvzn0 /dev/sdg ; wait $1 & echo "Attempting_Hexdump" ; hexdump /dev/sdg ;}; exec /bin/bash -i;"'])
	subprocess.Popen(['mate-terminal', '--window', '--geometry=61x9+520+366', '--title="/dev/sdh"', '-e', 'bash -c "{ shred -fvzn0 /dev/sdh ; wait $1 & echo "Attempting_Hexdump" ; hexdump /dev/sdh ;}; exec /bin/bash -i;"'])
	subprocess.Popen(['mate-terminal', '--window', '--geometry=61x9+520+549', '--title="/dev/sdi"', '-e', 'bash -c "{ shred -fvzn0 /dev/sdi ; wait $1 & echo "Attempting_Hexdump" ; hexdump /dev/sdi ;}; exec /bin/bash -i;"'])

#User Input Section (to choose which type of drive to shred / which function to run)
is_valid = 0
while is_valid != 1
	script_request = raw_input("Type 'APPLE', 'SATA', 'USB', or 'NVME' to shred the drive type based on the what you typed in! PLEASE DOUBLE CHECK THE MOUNT POINT OF THE CURRENT OS (ex. /dev/sda) AS THE SCRIPT WILL NOT SHRED /dev/sda!! >> ")
	if script_request == 'NVME':
		run_NVMEpy()
		is_valid = 1
	elif script_request == 'APPLE':
		run_SCSIpy()
		is_valid = 1
	elif script_request == 'SATA':
		run_SCSIpy()
		is_valid = 1
	elif script_request == 'USB':
		run_SCSIpy()
		is_valid = 1
	elif script_request == 'Exit':
		print("Oh, okay. See you soon!")
		is_valid = 1
	else:
		fail = 1
		while fail = 1
			script_request = raw_input("Sorry, I couldn't understand what you entered, please try again. (Please use all Capitals.) >> ")
			if script_request == 'NVME':
				run_NVMEpy()
				is_valid = 1
				fail = 0
			elif script_request == 'APPLE':
				run_SCSIpy()
				is_valid = 1
				fail = 0
			elif script_request == 'SATA':
				run_SCSIpy()
				is_valid = 1
				fail = 0
			elif script_request == 'USB':
				run_SCSIpy()
				is_valid = 1
				fail = 0
			elif script_request == 'Exit':
				print("Oh, okay. See you soon!")
				is_valid = 1
				fail = 0
		

print("Thank you for using Frankenstein.py! Have a great day.")
