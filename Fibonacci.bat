@echo OFF

set /p countLimit="What is the amount of times you want this to loop? "
:SetCalcLimit
set /p calcLimit="What is the maximum number you would like the loop to go to? "
if %calcLimit% GTR 2147483646 echo "calcLimit is too large to process. Please re-enter your maximum number, less than 2,147,483,646." && goto SetCalcLimit

:Top
set /a count+=1
if %count% GTR %countLimit% goto End
set x=0
set y=1
:CalcLoop
if NOT %x% LSS %calcLimit% goto Top
echo %x%
set /a z=%x%+%y%
set x=%y%
set y=%z%
goto CalcLoop

:End
set /a count-=1
echo Current cycle: %count%. Exiting per User cycle limit. && pause
exit