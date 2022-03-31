@echo OFF
rem Checking Disk 0 of System to see if it's a USB.
:diskcheck
title Diskpart - Diskcheck...
(
echo sel disk 0
echo detail disk
)>%cd%\diskpart_script.txt
diskpart /s %cd%\diskpart_script.txt > %cd%\diskpart_result.txt
find /i "type   : usb" %cd%\Diskpart_Result.txt
if %ERRORLEVEL% == 0 echo Disk 0 is a USB type drive. Exiting... && pause && exit
if %ERRORLEVEL% == 1 goto formatdisk

rem Formatting disk using clean all 7 times
rem Since "clean all" writes 0 to the entire disk in a single pass, running it 7 times assures us it passes DoD spec for wiping drives.
:formatdisk
title Diskpart - Formatting Disk...
(
echo sel disk 0
echo clean all
echo clean all
echo clean all
echo clean all
echo clean all
echo clean all
echo clean all
)>%cd%\diskpart_cleanall.txt
diskpart /s %cd%\diskpart_cleanall.txt
if %ERRORLEVEL% == 0 echo Drive has been cleaned! && del /f /q %cd%\diskpart_script.txt && del /f /q %cd%\diskpart_result.txt && del /f /q %cd%\diskpart_cleanall.txt && pause && exit
if %ERRORLEVEL% GTR 0 goto formatdisk
