@echo off
rem Opens the MetalTweaks panel without a console window. Needs Python 3 (python.org installer includes tkinter).
where pyw >nul 2>nul && (start "" pyw "%~dp0MetalTweaksPanel.pyw" & exit /b)
where pythonw >nul 2>nul && (start "" pythonw "%~dp0MetalTweaksPanel.pyw" & exit /b)
echo Python 3 was not found. Install it from https://www.python.org/downloads/ and run this again,
echo or edit settings.txt in this folder by hand (see README).
pause
