@echo OFF
if NOT exist %localappdata%\Twitch_Bot\server.js goto firstRun
cd %localappdata%\Twitch_Bot && call node server.js > console.txt
goto EOF

:firstRun
set filepath=%cd%
echo %filepath%
mkdir %localappdata%\Twitch_Bot && cd %localappdata%\Twitch_Bot
robocopy /E /R:5 "%filepath%" %localappdata%\Twitch_Bot
cls
call node server.js > console.txt
cls

:EOF
exit