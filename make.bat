@echo off
if [%1]==[nuke] (
	del .\lt\*.lua
) else (
	luajit -e "package.path=package.path .. 'c:\\luaty\\?.lua'" c:\luaty\lt.lua -f lt.lt .
	pause
	luajit run-test.lua
)
