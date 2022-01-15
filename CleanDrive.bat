@echo OFF
setlocal enabledelayedexpansion
cls
title CleanDrive - Checking drives...
:top
set /a count=0
title CleanDrive - CMD %count% - Searching for existing CleanDrive instance...
:checkInstance
for /f "tokens=*" %%z in ('tasklist ^/v ^/fo list ^| findstr ^/i "CleanDrive" ^| findstr ^/i "cmd"') do (
	set /a count+=1
)
if %count% GTR 1 set /a count=0 && title CleanDrive - CMD - Conflicting Instance found, waiting to resolve... && goto checkInstance

:User_Input_Area
title CleanDrive - CMD %count% - Taking User input...
set /p driveletter="What Drive letter do you want? (ex. "M", no quotes or other characters) Size is in BYTES. "

:diskcheck
title CleanDrive - CMD %count% - Checking disk information...
set fail=0
if exist %driveletter%:\ echo %driveletter% is taken & set fail=1
if not %fail%==0 echo %driveletter% is taken currently, please choose a different letter if possible. && goto User_Input_Area
if %fail%==0 goto whichdrive

:whichdrive
for /f "tokens=*" %%a in ('wmic diskdrive where "InterfaceType="USB"" get Caption^,Index^,Size /format:table ^| findstr ^/r ^/v "^$"') do (echo %%a)

set /p pickadrive="Pick whichever drive is the drive you are attempting to clean. (Use the "Index" number without quotes.) "
for /f %%z in (%pickadrive%) do (set selecteddisk=%%z)
set /a checkSelected = %selecteddisk% %% 2
if NOT %checkSelected% == 1 echo "Invalid Disk Selection" && goto whichdrive
:diskpartLoop
if exist %temp%\diskpart.txt ren %temp%\diskpart.txt diskpart.txt || timeout /T 15 /NOBREAK && goto diskpartLoop

:diskpartScriptFormatting
(
echo rem =INITIATE=
echo sel disk %selecteddisk%
echo clean
echo create part primary
echo format quick override fs=exFAT label=NewVol
echo assign letter=%driveletter%
echo exit
)>%temp%\diskpart.txt
goto formatLoop

:formatLoop
title CleanDrive - CMD %count% - Formatting drive...
call diskpart /s %temp%\diskpart.txt
if not exist %driveletter%:\ goto formatLoop
if exist %driveletter%:\ echo Done! && del %temp%\diskpart.txt && pause
timeout 15 && goto top
