@echo off
title Generar Release Base de Shorebird
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
cd /d "C:\asistente\asistente"
echo ============================================================
echo   COMPILANDO Y REGISTRANDO RELEASE BASE EN SHOREBIRD
echo ============================================================
call "C:\Users\ctruj\.shorebird\bin\shorebird.bat" release android --artifact=apk --target-platform=android-arm64
echo.
echo ============================================================
echo   Release finalizado y registrado en la consola de Shorebird.
echo ============================================================
pause
