@echo OFF
setlocal enabledelayedexpansion

set i=0

:checkLoop
set /a i+=1

:FizzBuzz
set FizzBuzz=0
set /a FizzCheck=%i% %% 3
if %FizzCheck%==0 set /a FizzBuzz+=1

set /a BuzzCheck=%i% %% 5
if %BuzzCheck%==0 set /a FizzBuzz+=1

if %FizzBuzz%==2 echo FizzBuzz && goto checkLoop

:Fizz
set FizzCheck=0
set /a FizzCheck=%i% %% 3
if %FizzCheck%==0 echo Fizz && goto checkLoop

:Buzz
set BuzzCheck=0
set /a BuzzCheck=%i% %% 5
if %BuzzCheck%==0 echo Buzz && goto checkLoop


if %i% LSS 100 echo %i% && goto checkLoop
goto Exit

:Exit
echo Done! && pause
exit