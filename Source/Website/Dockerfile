ARG sdkImageTag=3.5-windowsservercore-ltsc2019
ARG BASEURL=/

FROM mcr.microsoft.com/dotnet/framework/aspnet:${sdkImageTag}
SHELL ["powershell", "-command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
ARG BASEURL=${BASEURL}

WORKDIR /inetpub/wwwroot
COPY obj/Docker/publish .

RUN (Get-Content web.config).replace('%BASE_URL%', $Env:BASEURL) | Set-Content web.config

# Install Windows components required for WCF service hosted on IIS
RUN Add-WindowsFeature NET-WCF-TCP-Activation45; \
Add-WindowsFeature NET-WCF-HTTP-Activation45; \
Add-WindowsFeature Web-WebSockets
 
# Enable net.tcp protocol for default web site on IIS 
RUN windows\system32\inetsrv\appcmd.exe set app 'Default Web Site/' /enabledProtocols:"http,net.tcp"
EXPOSE 80
