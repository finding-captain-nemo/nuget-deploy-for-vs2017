# Version 1.1

$file = (Get-ChildItem -Path . -Filter *.nupkg)[0]
$arguments = @("push",".\$file","(API Key)","-Source", "(nuget URL)")
& "C:\Program Files (x86)\Nuget\nuget.exe" $arguments
