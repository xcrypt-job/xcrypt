start /B "" %3 > %1 2> %2
for /f "TOKENS=2" %%i in ('tasklist.exe  /NH /fi "IMAGENAME eq bash.exe"') do echo %%i
