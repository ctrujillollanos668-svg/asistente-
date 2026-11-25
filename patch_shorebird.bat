@echo off
title Enviar Parche Silencioso a Todos los Clientes (Shorebird)
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
cd /d "C:\asistente\asistente"
echo ============================================================
echo   ENVIANDO PARCHE SILENCIOSO A TODOS LOS CLIENTES
echo ============================================================
call "C:\Users\ctruj\.shorebird\bin\shorebird.bat" patch android --target-platform=android-arm64
echo.
echo ============================================================
echo   Parche publicado con exito en los servidores de Shorebird.
echo   Los celulares se actualizaran solos en silencio al abrir la app.
echo ============================================================
pause
