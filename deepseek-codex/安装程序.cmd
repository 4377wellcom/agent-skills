@echo off
cd /d %~dp0
start "" mshta.exe "%~dp0install-ui.hta"
