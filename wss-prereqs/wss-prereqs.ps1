#PowerShell
param($opt)
#$opt = ""  # [ua|prioritize|onprem|bitbucket|github|gitlab|ws4dev|all]

$appName = "wss-prereqs"
$appTitle = "WhiteSource Prerequisite Validator"
$appVersion = 1.0

###########  MINIMUM REQUIREMENTS  ##########
$minCPUs = 2
$minMemGB = 16
$minHddGB = 16

# Supported Java Versions
$supportedJava = @("1.8", "8.0", "11.0")

# Supported Operating Systems (name:version)
$supportedOs = @("Windows:10", "Windows:2016", "ubuntu:14", "ubuntu:16", "ubuntu:18", "centos:7", "centos:8", "debian:8", "debian:9", "debian:10", "rhel:7", "rhel:8")

# Supported NodeJS Version
$minNodeVer = "9.0"

# Supported Python Version
$minPythonVer = 2.7

# Supported .NET Versions
$minNetCoreAppVer = 3
$minNetCoreFwVer = 4.8

# Supported Docker Versions
$minDockerVer = 18
$minDockerVerRhel = 1.13

# Package Managers
$supportedPkgMgrs = @("Ant", "Bower", "Bundler", "Cabal", "Cargo", "Cocoapods", "Composer", "Go", "Gradle", "Hex", "Maven", "NPM", "NuGet", "Packrat", "Paket", "Pip", "SBT", "Yarn")

$pkgMgrIncludes = @()

#################  SETINGS  #################

$validateRootUser = $false
$promptOptions = $true # Prompt for product selection if no $opt specified via CLI (if false, defaults to All Products)
$defaultSaasEnv = "saas"
$wsIdxHost = "index.whitesourcesoftware.com"
$wsUrlIndex = 'https://' + "$wsIdxHost"

# Log file
$logToFile = $true
$logFile = "prereqs-report.txt"
$logFileIncludeTimestamp = $false
$maxLineLen = 43

# Software validation
$vJava = $false
$vDocker = $false
$vJdeps = $false
$vNodeJs = $false
$vPython = $false
$vNetCore = $false

# Connectivity validation
$vWsIndex = $false
$vWsServer = $false
$vPorts = $false
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# General validations
$vPkgMgrs = $false

################ Internal #################
$scriptFile = Split-Path -Path $MyInvocation.MyCommand.Path -Leaf

$dt = (Get-Date -Format "dd/MM/yyyy HH:mm:ss")
$logFileTs = (Get-Date -Format "yyyy-MM-dd_HH-mm")
$StartTime = (Get-Date)

$script:unmetPrereqs = ""

# Console colors
$RED = '\e[31m'
$GREEN = '\e[32m'
$YELLOW = '\e[33m'
$BLUE = '\e[34m'
$LGRAY = '\e[37m'
$DGRAY = '\e[90m'
$WHITE = '\e[97m'
$WHITEonRED = '\e[21;97;41m'
$WHITEonGREEN = '\e[21;97;42m'
$YELLOWonBLUE = '\e[21;33;44m'
$WHITEonBLUE = '\e[21;97;44m'
$LGRAYonBLUE = '\e[21;37;44m'
$BLACKonYELLOW = '\e[21;30;103m'
$NC = '\e[0m' # No Color

############# Error Handling ##############
# trap 'catch $? $LINENO' ERR
# catch() {
  # if (($? > 2)); then
    # printf " Error $1, line $2 "
  # fi
# }

############################################

# Product Descriptions and CLI options
$prdDsc = @{
    "1" = "WhiteSource Unified Agent"
    "2" = "WhiteSource Prioritize (EUA)"
    "3" = "WhiteSource On-Premises"
    "4" = "WhiteSource for Bitbucket (WS4Dev)"
    "5" = "WhiteSource for GitHub Enterprise (WS4Dev)"
    "6" = "WhiteSource for GitLab Core (WS4Dev)"
    "7" = "WhiteSource for Developers (WS4Dev)"
    "8" = "All WhiteSource products"
}
$prdOpts = @{
    "ua" = 1
    "eua" = 2
    "prioritize" = 2
    "op" = 3
    "onprem" = 3
    "bb" = 4
    "bitbucket" = 4
    "gh" = 5
    "github" = 5
    "gl" = 6
    "gitlab" = 6
    "ws4d" = 7
    "ws4dev" = 7
    "all" = 8
}

################ Functions ################

Function logTitle([string]$ttlTxt, [switch]$noLog) {
    If (!($noLog.IsPresent)) {$noLog = (!$logToFile)}
    $dlmLine = $('=' * $maxLineLen)
    $ttlTxtIndtLen = [int]$(($maxLineLen - $ttlTxt.Length) / 2)
    $ttlTxtIndt = $(' ' * $ttlTxtIndtLen)
    $prtTitle = "`n$dlmLine`n$ttlTxtIndt$ttlTxt`n$dlmLine`n"
    Write-Host "$prtTitle" -NoNewline
    If (!$noLog) {
        "$prtTitle" >> $logFile
    }
}


Function logLine([string]$lineTxt, [switch]$noNewLine, [switch]$noEcho, [switch]$noLog) {
    If (!($noLog.IsPresent)) {$noLog = (!$logToFile)}
    If (!$noEcho) {
        Write-Host "$lineTxt" -NoNewline:$noNewLine
    }
    If (!$noLog) {
        "$lineTxt" >> $logFile
    }
}



Function logPrereq( [string]$pn, # Pkg name
                    [string]$pv, # Pkg version
                    [string]$pr, # Validation result
                    [string]$mr, # Minimum requirement
                    [switch]$nv  # Disable validation
                  ) {
    $delim1 = If ($pn.Length -lt 3) {" `t`t"} ElseIf ($pn.Length -lt 7) {"`t`t"} Else {"`t"}
    $delim2 = If ($pv.Length -gt 12) {"`t"} ElseIf ($pv.Length -lt 7) {"`t`t`t"} Else {"`t`t"}
    $mrtxt = If ($mr) {"$delim2-> $mr"} Else {""}
    $unmetPrq = "${pn}:$delim1$pv$mrtxt`n"

    If ((!$pr) -or ($nv)) {
        $logLn = "      |`t"
        Write-Host "      |`t" -NoNewline
    } ElseIf ("$pr" -eq "N/A") {
        $logLn = " $pr  |`t"
        Write-Host " $pr" -NoNewline -f DarkGray; Write-Host "  |`t" -NoNewLine
    } ElseIf ($pr -gt 0) {
        $logLn = " Pass |`t"
        Write-Host " Pass" -NoNewline -f Green; Write-Host " |`t" -NoNewLine
    } Else {
        $script:unmetPrereqs += "$unmetPrq"
        $logLn = " Fail |`t"
        Write-Host " Fail" -NoNewline -f Red; Write-Host " |`t" -NoNewLine
    }
    
    If (("$pv" -eq "(none)") -or ("$pv" -eq "(not set)") -or ("$pv" -eq "(unreachable)")) {
        Write-Host "$pn $delim1" -NoNewline; Write-Host "$pv" -f DarkGray
    } Else {
        Write-Host "$pn $delim1$pv"
    }
    
    $logLn = "$logLn$pn $delim1$pv"
    If ($logToFile) {
        "$logLn" >> $logFile
    }
}

Function printAvailProducts([switch]$noLog) {
    
    cls

    logTitle "$appTitle" -noLog:$noLog
    $uInput = ""
    logLine "Displaying product selection prompt" -noEcho -noLog:$noLog
    Write-Host "`nSelect product:"
    ForEach ($key in ($prdDsc.Keys | Sort)) { Write-Host ("    {0})`t{1}" -f "$key", $prdDsc."$key")}
    Write-Host ("`nSelection (1-{0}): " -f $prdDsc.Count) -NoNewline
    Do {$uInput = ([string]$(([Console]::ReadKey($true)).KeyChar) -as [int])} Until (![string]::IsNullOrEmpty($prdDsc."$uInput"))
    Write-Host "$uInput"

    If ($uInput -isnot [int]) {
        logLine "Only numbers are accepted" -noLog:$noLog
        return -1
    } ElseIf (($uInput -ge 1) -and ($uInput -le $prdDsc.Count)) {
        return $uInput
    } Else {
        logLine "Invalid option selected" -noLog:$noLog
        return -1
    }
}

Function testPort([int]$pPort, [string]$pHost = $wsIdxHost) {
	try {
        $TcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpCon = $TcpClient.BeginConnect($pHost,$pPort,$null,$null)
    } catch {return 127}
	Sleep -m 3000
	If ($TcpClient.Connected) { $portOpen = 0 } Else { $portOpen = 1 }
	$TcpClient.Close()
	return $portOpen
}

Function isSupportedVersion([string]$isvVersion, [string]$isvMinVer) {
    try {
        If ([version]$isvVersion -ge [version]$isvMinVer) {return 0} Else {return 1}
    } catch {return 2}
}


############### CLI Options ###############

If ($opt) {$opt = $opt.ToLower()}
# Options that do not require admin permissions:
Switch -Regex ($opt) {
    ################ --help #################
    '^(-h|--help)$' {
        Write-Host "`n$appName $appVersion`n"
        Write-Host "usage: $scriptFile [options]"
        Write-Host "`nOptions:"
        Write-Host " -ua `t`t`t Verify prerequisites for WhiteSource Unified Agent"
        Write-Host " -eu, --prioritize `t Verify prerequisites for WhiteSource Prioritize"
        Write-Host " -op, --onprem `t`t Verify prerequisites for WhiteSource On-Premises deployment"
        Write-Host " -bb, --bitbucket `t Verify prerequisites for WS4Dev Bitbucket integration"
        Write-Host " -gh, --github `t`t Verify prerequisites for WS4Dev GitHub Enterprise integration"
        Write-Host " -gl, --gitlab `t`t Verify prerequisites for WS4Dev GitLab Core integration"
        Write-Host " -dv, --ws4dev `t`t Verify prerequisites for all WS4Dev (WhiteSource for Developers) deployments"
        Write-Host " -a,  --all `t`t Verify prerequisites for all WhiteSource deployments"
        Write-Host
        Write-Host " -h,--help `t`t Display help information"
        Write-Host " -v,--version `t`t Display version information"
        exit 0
    }
    ############### --version ###############
    '^(version|-v|--version)$' {
        Write-Host "$appName $appVersion"
        exit 0
    }
}

If ($validateRootUser){
    If (!((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {Write-Host " Permission denied.`n This script option requires admin permissions.`n Please run it again using sudo.`n`n Use '$scriptFile --help' for usage information."; exit 1}
}
# Options that require admin permissions:
Switch -Regex ($opt) {
    ############# Unified Agent #############
    '^(ua|-ua|--ua)$' {
        $vType = "ua"
        $productName = $prdDsc."$($prdOpts."$vType")"
        $vJava = $true
        $vDocker = $true
        $vNodeJs = $true
        $vPython = $true
        $vNetCore = $true
        $vWsServer = $true
        $vPkgMgrs = $true
        $pkgMgrIncludes = $supportedPkgMgrs
    }
  ############## Prioritize ###############
  '^(eu|-eu|eua|-eua|prioritize|--prioritize)$' {
        $vType = "eua"
        $productName = $prdDsc."$($prdOpts."$vType")"
        $vJava = $true
        $vJdeps = $true
        $vNodeJs = $true
        $vPython = $true
        $vNetCore = $true
        $vWsServer = $true
        $vPkgMgrs = $true
        $pkgMgrIncludes = @("Maven", "NPM", "Gradle", "Pip") # "NuGet"
        $supportedOs = ("ubuntu:18", "Windows:10", "Windows:2016")
        # If OS = centos, supportedJava = ("11.0")
    }
    ############## On-Premises ##############
    '^(op|-op|onprem|--onprem)$' {
        $vType = "op"
        $productName = $prdDsc."$($prdOpts."$vType")"
        $vDocker = $true
        $vWsIndex = $true
        $vPorts = $true
    }
    ############### Bitbucket ###############
    '^(bb|-bb|bitbucket|--bitbucket)$' {
        $vType = "bb"
        $productName = $prdDsc."$($prdOpts."$vType")"
        $vDocker = $true
        $vWsIndex = $true
        $vWsServer = $true
        $vPorts = $true
    }
    ################ GitHub #################
    '^(gh|-gh|github|--github)$' {
        $vType = "gh"
        $productName = $prdDsc."$($prdOpts."$vType")"
        $vDocker = $true
        $vWsIndex = $true
        $vWsServer = $true
        $vPorts = $true
    }
    ################ GitLab #################
    '^(gl|-gl|gitlab|--gitlab)$' {
        $vType = "gl"
        $productName = $prdDsc."$($prdOpts."$vType")"
        $vDocker = $true
        $vWsIndex = $true
        $vWsServer = $true
        $vPorts = $true
    }
    ################ WS4Dev #################
    '^(dv|-dv|dev|-dev|ws4d|--ws4d|ws4dev|--ws4dev)$' {
        $vType = "ws4d"
        $productName = $prdDsc."$($prdOpts."$vType")"
        $vDocker = $true
        $vWsIndex = $true
        $vWsServer = $true
        $vPorts = $true
    }
    ############# All Products ##############
    '^(all|-a|--all)$' {
        $vType = "all"
        $productName = $prdDsc."$($prdOpts."$vType")"
        $vJava = $true
        $vDocker = $true
        $vJdeps = $true
        $vNodeJs = $true
        $vPython = $true
        $vNetCore = $true
        $vWsIndex = $true
        $vWsServer = $true
        $vPorts = $true
        $vPkgMgrs = $true
        $pkgMgrIncludes = $supportedPkgMgrs
    }
    ################ Prompt #################
    '^(prompt|-p|--prompt)$' {
        $vType = "prompt"
        $uInput = printAvailProducts -noLog
        If ($uInput -lt 0) {exit 1}
        ForEach ($i in ($prdOpts.GetEnumerator() | ? {$_.Value -eq "$uInput"})) {
            $vType = $i.Name; break
        }
        cls
        powershell -File $MyInvocation.MyCommand.Definition -opt "$vType"; exit
    }
    ############### No Option ###############
    '^$' {
        If ($promptOptions) {
            cls
            powershell -File $MyInvocation.MyCommand.Definition -opt "prompt"; exit
        } Else {
            cls
            powershell -File $MyInvocation.MyCommand.Definition -opt "all"; exit
        }
    }
    ################ Default ################
    Default {
        Write-Host "NOTE: To skip this prompt, use the command '$scriptFile [option]'."
        Write-Host "      Use '$scriptFile --help' for usage information."
        Write-Host ""
        $uInput = printAvailProducts -noLog
        If ($uInput -lt 0) {exit 1}
        ForEach ($i in ($prdOpts.GetEnumerator() | ? {$_.Value -eq "$uInput"})) {
            $vType = $i.Name; break
        }
        cls
        powershell -File $MyInvocation.MyCommand.Definition -opt "$vType"; exit
    }
}


########################################################
#                   START VALIDATION                   #
########################################################
# Overwrite the existing report file if exists
If ($vType) { $logFile = $logFile.Replace('.txt',"-$vType.txt")  } Else {exit 1}
If ($logFileIncludeTimestamp) { $logFile = "$logFileTs_$logFile" }
If ($logToFile) {"" > $logFile}
#Write-Host ""

# Print Header
logTitle "$appTitle"
logLine "Product: $productName`n`n$dt"

############################################
logTitle "System Prerequisites"

############  Hostname  ############
logPrereq "Hostname" "$env:COMPUTERNAME"

############  Env Type  ############
$ComputerSystemInfo = Get-WmiObject -Class "Win32_ComputerSystem"
If ($ComputerSystemInfo.Model -ilike "*virtual*") {
    $envType = "Virtual"
} Else {
    $envType = "Standard"
}




logPrereq "Env type" "$envType"

############  Hardware  ############
If ($vType -imatch "^(ua|eua)$") {$noHwValidation = $true} Else {$noHwValidation = $false}

############  CPU  ############
$CPU = $ComputerSystemInfo.NumberOfLogicalProcessors
If ($CPU -ge $minCPUs) {$CPUresult = 1} Else {$CPUresult = 0}

logPrereq "CPUs" "$CPU" $CPUresult "Min. $minCPUs CPUs" -nv:$noHwValidation

############  Memory  ############
$MEMkb = $(((Get-WmiObject -Class "Win32_PhysicalMemory" -Namespace "root\CIMV2").Capacity | Measure-Object -Sum).Sum/1KB)
$MEM = [math]::Round(($MEMkb/1MB),1)
If ($MEM -ge $minMemActualKb) {$MEMresult = 1} Else {$MEMresult = 0}




logPrereq "RAM" "$MEM GB" $MEMresult "Min. $minMemGB GB" -nv:$noHwValidation

############  Available Disk  ############
$noHddValidation = If ($envType -eq "Container") {$true} Else {$noHwValidation}
$HDDkb = $((Get-WmiObject -Class "Win32_LogicalDisk" -Filter ("DeviceID='{0}:'" -f $pwd.Drive.Name)).Size/1KB)
$HDD = [math]::Round(($HDDkb/1MB),1)
If ($HDD -ge $minHddGB) {$HDDresult = 1} Else {$HDDresult = 0}
If (($HDD -eq 0) -and ($envType -eq "Container")) { $HDD = "(none)" }


logPrereq "Disk" "$HDD GB" $HDDresult "Min. $minHddGB GB" -nv:$noHddValidation

############  OS Version  ############
$pName = "OS"
$osSupported = 0

$ThisOS = (Get-WMIObject -Class "Win32_OperatingSystem")
$OSID = If ($ThisOS.Caption -ilike "*windows*") {"Windows"} Else {$ThisOS.Caption}
$OSVER = $ThisOS.Version
$pVer = "${OSID}:${OSVER}"
$supportedOs | % {If ("$pVer" -ilike "$_*") {$osSupported = 1} }
$pResult = $osSupported

logPrereq "$pName" "$pVer" $pResult "Unsupported operating system for $productName"


logTitle "Software Prerequisites"

If ($vJava) {
    ############  Java version  ############
    $pName = "Java"
    $javaSupported = 0
    try { $pVer = $(java -version 2>&1)[0] -ireplace "(java|openjdk) version ",'' | % {$_.Split(' _')[0]-replace '"',''} } catch {$pVer = ""}
    If ([string]::IsNullOrEmpty("$pVer")) {
        $pVer = "(none)"
    } Else {
        
        ForEach ($jv in $supportedJava) {
            try {$checkVer = [version]$pVer} catch {break}
            If ($checkVer -ge [version]$jv) {
                $javaSupported = 1
                break
            }
        }
    }
    logPrereq "$pName" "$pVer" $javaSupported
  
    If ($javaSupported -gt 0) {
        $pName = "JAVA_HOME"
        $javaHome = $env:JAVA_HOME
        If ("$javaHome") {
            If (($env:PATH -ilike "*JAVA_HOME*") -or ($env:PATH -ilike "*$javaHome*")) {
                $pVer = "Found"
                $javaHomeSet = 1
                $javaMinAI = ""
            } Else {
                $pVer = 'Not in $PATH'
                $javaHomeSet = 0
                $javaMinAI = 'Add $JAVA_HOME to $PATH'
            }
        } Else {
            $pVer = "(not set)"
            $javaHomeSet = 0
            $javaMinAI = 'Set $JAVA_HOME and add to $PATH'
        }
        logPrereq "$pName" "$pVer" $javaHomeSet "$javaMinAI"
    }
}

If ($vDocker) {
    If ($vType -imatch "^(ua)$") {$noValidation = $true} Else {$noValidation = $false}
    ############  Docker version  ############
    $pName="Docker"
    try { $pVer = $(docker --version 2>&1) -ireplace 'docker version ','' | % {$_.Split(' ,')[0]} } catch {$pVer = ""}
    $minDkrVerOs = "$minDockerVer" # $minDockerVerRhel N/A to $OSID = Windows
    $dockerMinAi = "Install Docker v$minDkrVerOs or later"
    If (!$pVer) {
        $pVer = "(none)"
        If ($noValidation) { $pResult = "N/A"} Else { $pResult = 0 }
    } Else {
        $dMajor,$dMinor,$dMicro = $pVer.Split('.')
        If ("$OSID" -eq "rhel") {
            # N/A to Windows






        } Else {
            If ($dMajor -ge $minDkrVerOs) { $pResult = 1 } Else { $pResult = 0}
        }
    }
    If ($envType -eq "Container") {
        logPrereq "$pName" "N/A"
    } Else {
        logPrereq "$pName" "$pVer" $pResult "$dockerMinAi" -nv:$noValidation
    }
}

If ($vJdeps) {
    ############  jdeps version  ############
    $pName = "jdeps"
    try { $pVer = $(jdeps -version 2>&1) } catch { $pVer = "" }
    If ($pVer -match "^[0-9\.]{2,14}$") {
        $pResult = 1
    } Else {
        $pVer = "(none)"
        $pResult = 0
    }
    logPrereq "$pName" "$pVer" $pResult "Install JDK 8 or later"
}

If ($vNodeJs) {
    If ($vType -imatch "^(ua)$") {$noValidation = $true} Else {$noValidation = $false}
    ###########  NodeJS version  ############
    $pName = "NodeJS"
    try { $pVer = $(node -v 2>&1) } catch { $pVer = "" }
    If ($pVer -match "^(v)[0-9\.]{2,14}$") {
        $pVer = $pVer.Substring(1)
        
        If ([version]$pVer -ge [version]$minNodeVer) { $pResult = 1 } Else { $pResult = 0 }
    } Else {
        $pVer = "(none)"
        If ($noValidation) { $pResult = "N/A"} Else { $pResult = 0 }
    }
    logPrereq "$pName" "$pVer" $pResult "Install NodeJS $minNodeVer or later" -nv:$noValidation
}

If ($vPython) {
    If ($vType -imatch "^(ua)$") {$noValidation = $true} Else {$noValidation = $false}
    ###########  Python version  ############
    $pName = "Python"
    try { $pVer = $(python -V 2>&1) | % {$_.Split(' ')[1]} } catch { $pVer = "" }
    If (!$pVer) {
        $pVer = "(none)"
        If ($noValidation) { $pResult = "N/A"} Else { $pResult = 0 }
    } Else {
        $pMajor,$pMinor,$pMicro = $pVer.Split('.')
        If ($pMajor -gt [int]$("$minPythonVer".Split('.')[0])) {
            $pResult = 1
        } ElseIf (($pMajor -eq [int]$("$minPythonVer".Split('.')[0])) -and ($pMinor -ge [int]$("$minPythonVer".Split('.')[1]))) {
            $pResult = 1
        } Else {
            $pResult = 0
        }
    }
    logPrereq "$pName" "$pVer" $pResult "Install Python $minPythonVer or later" -nv:$noValidation
}

If ($vNetCore) {
    If ($vType -imatch "^(ua)$") {$noValidation = $true} Else {$noValidation = $false}
    ######  .NET Core runtime version  ######
    $pName = ".NET App"
    try { $pVerInfo = $(dotnet --list-runtimes 2>&1 | ? { $_ -like "*NETCore.App*" }) } catch { $pVerInfo = "" }
    If (!$pVerInfo) {
        $pVer = "(none)"
        If ($noValidation) { $pResult = "N/A"} Else { $pResult = 0 }
    } Else {
        $latestRt = $pVerInfo[-1] -replace '( \[).*',''
        $pVer = $($latestRt -split ' ')[-1]
        $naMajor,$naMinor,$naMicro = $pVer.Split('.')
        If ($naMajor -ge $minNetCoreAppVer) { $pResult = 1 } Else { $pResult = 0 }
    }
    logPrereq "$pName" "$pVer" $pResult "Install .NET Core $minNetCoreAppVer or later" -nv:$noValidation
  
    #####  .NET Core framework version  #####
    If ($OSID -ilike "*windows*") {
        $pName = ".NET FW"
        try { $pVerInfo = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v*' -Recurse | Get-ItemProperty -Name Version -ea 4 | % {[System.Version]$_.Version} | Sort -Unique } catch { $pVerInfo = "" }
        If (!$pVerInfo) {
            $pVer = "(none)"
            If ($noValidation) { $pResult = "N/A"} Else { $pResult = 0 }
        } Else {
            $pver = $pVerInfo[-1]

            If ([system.version]$pver -ge [system.version]"$minNetCoreFwVer") {
                $pResult = 1


            } Else {
                $pResult = 0
            }
        }
        logPrereq "$pName" "$pVer" $pResult "Install .NET Framework $minNetCoreFwVer or later" -nv:$noValidation
    }
}

If ($vWsIndex) {
    ############  WhiteSource Index  ############
    $pName = "WS Index"
    $pVer = "(unreachable)"
    $pResult = 0
    $idxUrl = "$wsUrlIndex"
    $idxUrlCheck = '{0}/gri/app/check/ok' -f "$idxUrl"
    
    try { $idxAccessInfo = Invoke-WebRequest -Uri $idxUrlCheck | Select StatusCode,Content } catch {$idxAccessInfo = @{StatusCode=$_.Exception.Response.StatusCode.value__}}
    $eCode = $idxAccessInfo.StatusCode
    If ($eCode -ne 200) {
        $idxAccess = "failed ($eCode)"
    } Else {
        $idxAccess = $idxAccessInfo.Content
    }
    


    If ("$idxAccess" -eq "ok") {
        $pVer = "$idxAccess"
        $pResult = 1
    }
    logPrereq "$pName" "$pVer" $pResult "Allow access to $idxUrl"
}

If ($vWsServer) {
    ###########  WhiteSource Server  ############
    $pName = "WS Server"
    $pVer = "(unreachable)"
    $pResult = 0
    $wsUrl = "https://{0}.whitesourcesoftware.com" -f "$defaultSaasEnv"
    
    try { $wsAccess = (Invoke-WebRequest -Uri $wsUrl) } catch {$wsAccess = @{StatusCode=$_.Exception.Status.value__}}
    $eCode = $wsAccess.StatusCode
    If ($eCode -ne 200) {
        $wsAccess = "failed ($eCode)"
    } Else {
        $wsAccess = "ok"
    }
    
    If ("$wsAccess" -eq "ok") {
        $pVer = "$wsAccess"
        $pResult = 1
    }
    logPrereq "$pName" "$pVer" $pResult "Allow access to WhiteSource server"
}

If ($vPorts) {
    $pName = "Ports"
    If ($vType -imatch "^(op)$") {
        $ports = @("8080", "443")
    } ElseIf ($vType -imatch "^(ws4d|bb|gh|gl)$") {
        $ports = @("8080", "5678", "9494", "9393")
    } Else {
        $ports = @("8080", "443", "5678", "9494", "9393")
    }
    $portCnt = $ports.Count
    $portAvl = 0
    $nonc = 0
    $naPortsTxt = ""
    For ($i = 0; $i -lt $ports.Count; $i++) {
        $curPort = $ports[$i]
        $nccode = testPort -pPort $curPort -pHost $wsIdxHost
        If ($nccode -eq 127) {
            $nonc = 1
            $naPortsTxt = $ports -join ','
            break ;
        } ElseIf ($nccode -eq 0) {
            $portAvl++
        } Else {
            $naPortsTxt += ",$curPort"
        }
    }
    $naPortsTxt = $naPortsTxt.Substring(1)
    $portsMinAi = ""
    If ($nonc -gt 0) {
        $pVer = "(none)"
        $pResult = 0
        $portsMinAi = "Cannot validate availability of ports: $naPortsTxt"
    } ElseIf ($portAvl -eq $portCnt) {
        $pVer = "Full"
        $pResult = 1
    } ElseIf ($portAvl -gt 0) {
        $pVer = "Partial"
        $pResult = 0
        $portsMinAi = "Allow communication on port(s): $naPortsTxt"
    } Else {
        $pVer = "None"
        $pResult = 0
        $portsMinAi = "Allow communication on port(s): $naPortsTxt"
    }
    logPrereq "$pName" "$pVer" $pResult "$portsMinAi"
}

If ($vPkgMgrs) {
    logTitle "Package Managers"
  
    ############  Package Managers  ############
    # PM Name|PM Command|version command|Min Version|version info awk lookup text|version info text to replace
    $pmParams = @()
    $pmParams += ("Ant|ant|-version||Apache Ant(TM) version|compiled.*") # Java
    $pmParams += ("Bower|bower|-v|||") # JavaScript
    $pmParams += ("Bundler|bundle|-v||Bundler version|") # Ruby
    $pmParams += ("Cabal|cabal|--version||cabal-install version|compiled using.*") # Haskell
    $pmParams += ("Cargo|cargo|--version||cargo|\(.*") # Rust
    # $pmParams += ("Cocoapods|pod|--version|||") # Swift
    $pmParams += ("Composer|composer|-V||Composer version|[0-9]{4}-[0-9]{2}-[0-9]{2}.*") # PHP
    $pmParams += ("Go|go|version||go version|windows.*") # Go
    $pmParams += ("Gradle|gradle|-v|4.0|Gradle|") # Java
    $pmParams += ("Hex|mix|-v||Mix|(compiled.*") # Mix manages hex packages for Elixir and Erlang
    $pmParams += ("Maven|mvn|-v|3.0|Apache Maven|\(.*") # Java
    $pmParams += ("NPM|npm|-v|6.0||") # JavaScript
    $pmParams += ("NuGet|nuget|help||NuGet Version:|") # .NET
    $pmParams += ("Packrat|packrat||||") # R
    # $pmParams += ("Renv|renv||||") # R # TBD - When renv will replace Packrat
    $pmParams += ("Paket|paket|--version|||") # .NET  ####### Verify
	$pmParams += ("Pip|pip|-V|1.0|pip|from.*") # Python
	$pmParams += ("SBT|sbt|--numeric-version|||") # Scala
    $pmParams += ("Yarn|yarn|-v|||") # JavaScript

    $pmIncludes = $pkgMgrIncludes
    
    For ($i = 0; $i -lt $pmParams.Count; $i++) {
        $pmName,$pmCmd,$pmVerCmd,$pmMinVer,$pmAwkTxt,$pmAwkTtr = $($pmParams[$i]).Split('|')
        If (!$pmVerCmd) { $pmVerCmd = '-v' }
        
        If ($pmIncludes.Contains($pmName)) {
            If (("$pmName" -eq "NuGet") -and ("$OSID" -ine "Windows")) {
                # N/A in PowerShell, only in Bash
            } Else {
                try { $pmVerInfo = iex ('{0} {1} 2>&1' -f "$pmCmd","$pmVerCmd") } catch { $pmVerInfo = "" }
            }
            
            If (!$pmVerInfo) {
                $pmVer = "(none)"
                $pmResult = "N/A"
                $minVerAi = ""
            } Else {
                [string]$pmVerToken = $pmVerInfo | ? {("$_" -replace '\x1b\[[0-9;]*m','') -imatch "$pmAwkTxt"}
                If (!$pmAwkTtr) {
                    $pmVerToken = @($pmVerToken.Trim() -split ' ')[-1]
                } Else {
                    $pmVerToken = $(($pmVerToken -replace "$pmAwkTtr","").Trim() -split ' ')[-1]
                }
                $pmVer = $pmVerToken -replace "[^0-9\.]",""
                #$pmMajor,$pmMinor,$pmMicro = $pmVer.Split('.')
                #$minMajor,$minMinor,$minMicro = $pmMinVer.Split('.')
                
                $validVer = $true
                $pmResult = 1
                $minVerAi = ""
                If ($pmMinVer) {
                    try { $validVer = ([version]$pmVer -ge [version]$pmMinVer) } catch { $validVer = $true }
                    If (!$validVer) {
                        $pmResult = 0
                        $minVerAi = "$pmName min. version: $pmMinVer"
                    }
                }
            }
            logPrereq "$pmName" "$pmVer" $pmResult "$minVerAi"
            # Go dep managers
            If (("$pmName" -ieq "Go") -and ("$pmVer" -ne "(none)")) {
                $goDepMgrs = @()
                $goDepMgrs += ("dep|version|^ version     : |")
                $goDepMgrs += ("godep|version|godep|(.*")
                $goDepMgrs += ("vndr|vndr has no version opt||") # TBD
                $goDepMgrs += ("gogradle|not sure if can be installed independently||") # TBD
                $goDepMgrs += ("govendor|-version||")
                $goDepMgrs += ("gopm|-version|Gopm version|[a-zA-Z]")
                $goDepMgrs += ("glide|-version|glide version|")
                $goDepMgrs += ("vgo|vgo was merged into the Go tree||") # TBD
                $goDepMgrs += ("modules|modules is part of Go||")

                For ($g = 0; $g -lt $goDepMgrs.Count; $g++) {
                    $gdmName,$gdmVerCmd,$gdmAwkTxt,$gdmAwkTtr = $($goDepMgrs[$g]).Split('|')
                    try { $gdmVerInfo = iex ('{0} {1} 2>&1' -f "$gdmName","$gdmVerCmd") } catch { $gdmVerInfo = "" }
                    If ($LASTEXITCODE -eq 0 -and ![string]::IsNullOrEmpty($gdmVerInfo)) {
                        If (!$gdmAwkTtr) {
                            $gdmVer = @(($gdmVerInfo | ? {"$_" -imatch "$gdmAwkTxt"}).Trim() -split ' ')[-1]
                        } Else {
                            $gdmVer = $((($gdmVerInfo | ? {"$_" -imatch "$gdmAwkTxt"}) -replace "$gdmAwkTtr","").Trim() -split ' ')[-1]
                        }
                        If ($gdmVer) {logPrereq "$pmName - $gdmName" "$gdmVer"}
                    }
                }
            }
        }
    }
}

$dlmLine = $('=' * $maxLineLen)
Write-Host "`n$dlmLine"
$duration = New-TimeSpan -Start $StartTime -End (Get-Date)
Write-Host ("Process Complete`nDuration: {0}`n" -f ("{0:mm\:ss}" -f $duration))

If ($logToFile) {
    Write-Host ("Report generated:`n  {0}" -f (Join-Path $PWD "$logFile"))
}

If ($unmetPrereqs) {
    logTitle "Unmet Prerequisites Summary"
    $summaryTxt = "Product: $productName`n`n$unmetPrereqs"
} Else {
    $summaryTxt = "`nAll prerequisites are confirmed`n"
}

If ($logToFile) {
    "$summaryTxt" >> $logFile
}
Write-Host "$summaryTxt`n$dlmLine`n`n"
