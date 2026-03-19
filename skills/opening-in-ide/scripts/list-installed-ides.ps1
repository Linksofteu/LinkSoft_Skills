#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (Get-Command rider -ErrorAction SilentlyContinue -CommandType Application) {
    'rider'
}
elseif (Get-Command rider.bat -ErrorAction SilentlyContinue -CommandType Application) {
    'rider'
}
elseif (Get-Command rider64.exe -ErrorAction SilentlyContinue -CommandType Application) {
    'rider'
}

if (Get-Command code -ErrorAction SilentlyContinue -CommandType Application) {
    'code'
}
elseif (Get-Command code.cmd -ErrorAction SilentlyContinue -CommandType Application) {
    'code'
}
