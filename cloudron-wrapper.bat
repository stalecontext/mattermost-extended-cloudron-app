@echo off
:: Wrapper to run cloudron with correct USERPROFILE
set "USERPROFILE=C:\Users\%USERNAME%"
set "HOME=C:\Users\%USERNAME%"
cloudron %*
