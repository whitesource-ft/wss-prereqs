#!/bin/bash
opt=$1
#opt="" # [ua|prioritize|onprem|bitbucket|github|gitlab|ws4dev|all]

appName="wss-prereqs"
appTitle="WhiteSource Prerequisite Validator"
appVersion=1.0

###########  MINIMUM REQUIREMENTS  ##########
minCPUs=2
minMemGB=16
minHddGB=16

# Supported Java Versions
declare -a supportedJava=("1.8" "8.0" "11.0")

# Supported Operating Systems (name:version)
declare -a supportedOs=("Windows:10" "Windows:2016" "ubuntu:14" "ubuntu:16" "ubuntu:18" "centos:7" "centos:8" "debian:8" "debian:9" "debian:10" "rhel:7" "rhel:8")

# Supported NodeJS Version
minNodeVer=9.0

# Supported Python Version
minPythonVer=2.7

# Supported .NET Versions
minNetCoreAppVer=3
minNetCoreFwVer=4.8

# Supported Docker Versions
minDockerVer=18
minDockerVerRhel=1.13

# Package Managers
declare -a supportedPkgMgrs=("Ant" "Bower" "Bundler" "Cabal" "Cargo" "Cocoapods" "Composer" "Go" "Gradle" "Hex" "Maven" "NPM" "NuGet" "Packrat" "Paket" "Pip" "SBT" "Yarn")

declare -a pkgMgrIncludes

#################  SETINGS  #################

validateRootUser=false
promptOptions=true # Prompt for product selection if no $opt specified via CLI (if false, defaults to All Products)
defaultSaasEnv="saas"
wsIdxHost="index.whitesourcesoftware.com"
wsUrlIndex="https://$wsIdxHost"

# Log file
logToFile=true
logFile="prereqs-report.txt"
logFileIncludeTimestamp=false
maxLineLen=43

# Software validation
vJava=false
vDocker=false
vJdeps=false
vNodeJs=false
vPython=false
vNetCore=false

# Connectivity validation
vWsIndex=false
vWsServer=false
vPorts=false


# General validations
vPkgMgrs=false

################ Internal #################
scriptFile=`basename "$0"`

dt=$(date '+%d/%m/%Y %H:%M:%S')
logFileTs=$(date '+%F_%H%M')
SECONDS=0

unmetPrereqs=""

# Console colors
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[34m'
LGRAY='\e[37m'
DGRAY='\e[90m'
WHITE='\e[97m'
WHITEonRED='\e[21;97;41m'
WHITEonGREEN='\e[21;97;42m'
YELLOWonBLUE='\e[21;33;44m'
WHITEonBLUE='\e[21;97;44m'
LGRAYonBLUE='\e[21;37;44m'
BLACKonYELLOW='\e[21;30;103m'
NC='\e[0m' # No Color

############# Error Handling ##############
# trap 'catch $? $LINENO' ERR
# catch() {
  # if (($? > 2)); then
    # printf " Error $1, line $2 "
  # fi
# }

############################################

# Product Descriptions and CLI options
declare -A prdDsc=(
  ["1"]="WhiteSource Unified Agent"
  ["2"]="WhiteSource Prioritize (EUA)"
  ["3"]="WhiteSource On-Premises"
  ["4"]="WhiteSource for Bitbucket (WS4Dev)"
  ["5"]="WhiteSource for GitHub Enterprise (WS4Dev)"
  ["6"]="WhiteSource for GitLab Core (WS4Dev)"
  ["7"]="WhiteSource for Developers (WS4Dev)"
  ["8"]="All WhiteSource products"
)
declare -A prdOpts=(
  ["ua"]=1
  ["eua"]=2
  ["prioritize"]=2
  ["op"]=3
  ["onprem"]=3
  ["bb"]=4
  ["bitbucket"]=4
  ["gh"]=5
  ["github"]=5
  ["gl"]=6
  ["gitlab"]=6
  ["ws4d"]=7
  ["ws4dev"]=7
  ["all"]=8
)

################ Functions ################

logTitle() {
  ttlTxt=$1
  [[ ! -z $2 ]] && noLog=$2 || if $logToFile ; then noLog=false ; else noLog=true ; fi
  dlmLine=$(printf '%0.s=' $(seq 1 $maxLineLen))
  ttlTxtIndtLen=$((($maxLineLen - ${#ttlTxt}) / 2))
  ttlTxtIndt="$(printf '%*s' $ttlTxtIndtLen)"
  prtTitle="\n$dlmLine\n$ttlTxtIndt$ttlTxt\n$dlmLine\n"
  printf "$prtTitle"
  if ! $noLog ; then
    printf "$prtTitle" >> $logFile
  fi
}

logLine() {
  lineTxt=$1
  [[ ! -z $2 ]] && noNewLine=$2 || noNewLine=false
  [[ ! -z $3 ]] && noEcho=$3 || noEcho=false
  [[ ! -z $4 ]] && noLog=$4 || if $logToFile ; then noLog=false ; else noLog=true ; fi
  if ! $noNewLine ; then lineTxt="${lineTxt}\n" ; fi
  if ! $noEcho ; then printf "$lineTxt" ; fi
  if ! $noLog ; then
    printf "$lineTxt" >> $logFile
  fi
}

logPrereq() {
  pn=$1 # Pkg name
  pv=$2 # Pkg version
  pr=$3 # Validation result
  mr=$4 # Minimum requirement
  nv=$5 # Disable validation
  if [ $((${#pn})) -lt 3 ]; then delim1="\t\t"; elif [ $((${#pn})) -lt 8 ]; then delim1="\t\t"; else delim1="\t"; fi
  if [ $((${#pv})) -gt 12 ]; then delim2="\t"; elif [ $((${#pv})) -le 8 ]; then delim2="\t\t\t"; else delim2="\t"; fi
  [[ ! -z $mr ]] && mrtxt="$delim2-> $mr" || mrtxt=""
  unmetPrq="$pn:$delim1$pv$mrtxt\n"
  
  if [[ -z $pr ]] || [[ $nv -gt 0 ]] ; then
    logLn="      |\t"
    printf "      |\t"
  elif [[ "$pr" == "N/A" ]] ; then
    logLn=" $pr  |\t"
    printf ${DGRAY}" N/A"${NC}"  |\t"
  elif [ $pr -gt 0 ] ; then
    logLn=" Pass |\t"
    printf ${GREEN}" Pass"${NC}" |\t"
  else
    unmetPrereqs+="$unmetPrq"
    logLn=" Fail |\t"
    printf ${RED}" Fail"${NC}" |\t"
  fi

  if [ "$pv" == "(none)" ] || [ "$pv" == "(not set)" ] || [ "$pv" == "(unreachable)" ]; then
    printf "$pn$delim1"${DGRAY}"$pv"${NC}"\n"
  else
    printf "$pn$delim1$pv\n"
  fi

  logLn="$logLn$pn$delim1$pv\n"
  if $logToFile ; then
    printf "$logLn" >> $logFile
  fi
}

printAvailProducts() {
  [[ ! -z $1 ]] && noLog=$1 || if $logToFile ; then noLog=false ; else noLog=true ; fi
  clear

  logTitle "$appTitle" $noLog
  uInput=""
  logLine "Displaying product selection prompt" false true $noLog
  printf "\nSelect product:\n"
  for i in "${!prdDsc[@]}"; do printf "    %s)\t%s\n" "$i" "${prdDsc[$i]}" ; done
  printf "\n"
  read -p "Selection (1-${#prdDsc[@]}): " -n1 uInput
  printf "\n"

  if ! [[ $uInput =~ ^[0-9]+$ ]] ; then
    logLine "Only numbers are accepted" false false $noLog
    return -1
  elif [ "$uInput" -ge 1 ] && [ "$uInput" -le ${#prdDsc[@]} ]; then
    return $uInput
  else
    logLine "Invalid option selected" false false $noLog
    return -1
  fi
}

testPort() {
  pPort=$1
  [[ ! -z $2 ]] && pHost=$2 || pHost="$wsIdxHost"
  nc -z $pHost $pPort -w 2 >/dev/null 2>&1
  nccode=$?
  return $nccode
}




isSupportedVersion() {
  isvVersion=$1
  isvMinVer=$2
  function ver { printf "%03d%03d%03d%03d" $(echo "$1" | tr '.' ' '); }
  [ $(ver $isvVersion) -ge $(ver $isvMinVer) ] && return 0 || return 1
}

############### CLI Options ###############

opt=$(echo $opt | awk '{print tolower($0)}')
# Options that do not require sudo:
case "$opt" in
  ################ --help #################
  -h|--help)
    echo -e "\n$appName $appVersion\n"
    echo -e "usage: $0 [options]"
    echo -e "\nOptions:"
    echo -e " -ua \t\t\t Verify prerequisites for WhiteSource Unified Agent"
    echo -e " -eu, --prioritize \t Verify prerequisites for WhiteSource Prioritize"
    echo -e " -op, --onprem \t\t Verify prerequisites for WhiteSource On-Premises deployment"
    echo -e " -bb, --bitbucket \t Verify prerequisites for WS4Dev Bitbucket integration"
    echo -e " -gh, --github \t\t Verify prerequisites for WS4Dev GitHub Enterprise integration"
    echo -e " -gl, --gitlab \t\t Verify prerequisites for WS4Dev GitLab Core integration"
    echo -e " -dv, --ws4dev \t\t Verify prerequisites for all WS4Dev (WhiteSource for Developers) deployments"
    echo -e " -a,  --all \t\t Verify prerequisites for all WhiteSource deployments"
    echo ""
    echo -e " -h,--help \t\t Display help information"
    echo -e " -v,--version \t\t Display version information"
    exit 0
    ;;
  ############### --version ###############
  version|-v|--version)
    echo "$appName $appVersion"
    exit 0
    ;;
esac

if $validateRootUser ; then
  [ `whoami` != root ] && printf " Permission denied. \n This script option requires root permissions. \n Please run it again using sudo. \n\n Use '$0 --help' for usage information. \n" && exit 1
fi
# Options that require sudo:
case "$opt" in
  ############# Unified Agent #############
  ua|-ua|--ua)
    vType="ua"
    productName="${prdDsc[${prdOpts[ua]}]}"
    vJava=true
    vDocker=true
    vNodeJs=true
    vPython=true
    vNetCore=true
    vWsServer=true
    vPkgMgrs=true
    pkgMgrIncludes=${supportedPkgMgrs[@]}
    ;;
  ############## Prioritize ###############
  eu|-eu|eua|-eua|prioritize|--prioritize)
    vType="eua"
    productName="${prdDsc[${prdOpts[eua]}]}"
    vJava=true
    vJdeps=true
    vNodeJs=true
    vPython=true
    vNetCore=true
    vWsServer=true
    vPkgMgrs=true
    pkgMgrIncludes=("Maven" "NPM" "Gradle" "Pip") # "NuGet"
    supportedOs=("ubuntu:18" "Windows:10" "Windows:2016")
    # if OS=centos, supportedJava=("11.0")
    ;;
  ############## On-Premises ##############
  op|-op|onprem|--onprem)
    vType="op"
    productName="${prdDsc[${prdOpts[op]}]}"
    vDocker=true
    vWsIndex=true
    vPorts=true
    ;;
  ############### Bitbucket ###############
  bb|-bb|bitbucket|--bitbucket)
    vType="bb"
    productName="${prdDsc[${prdOpts[bb]}]}"
    vDocker=true
    vWsIndex=true
    vWsServer=true
    vPorts=true
    ;;
  ################ GitHub #################
  gh|-gh|github|--github)
    vType="gh"
    productName="${prdDsc[${prdOpts[gh]}]}"
    vDocker=true
    vWsIndex=true
    vWsServer=true
    vPorts=true
    ;;
  ################ GitLab #################
  gl|-gl|gitlab|--gitlab)
    vType="gl"
    productName="${prdDsc[${prdOpts[gl]}]}"
    vDocker=true
    vWsIndex=true
    vWsServer=true
    vPorts=true
    ;;
  ################ WS4Dev #################
  dv|-dv|dev|-dev|ws4d|--ws4d|ws4dev|--ws4dev)
    vType="ws4d"
    productName="${prdDsc[${prdOpts[ws4d]}]}"
    vDocker=true
    vWsIndex=true
    vWsServer=true
    vPorts=true
    ;;
  ############# All Products ##############
  all|-a|--all)
    vType="all"
    productName="${prdDsc[${prdOpts[all]}]}"
    vJava=true
    vDocker=true
    vJdeps=true
    vNodeJs=true
    vPython=true
    vNetCore=true
    vWsIndex=true
    vWsServer=true
    vPorts=true
    vPkgMgrs=true
    pkgMgrIncludes=${supportedPkgMgrs[@]}
    ;;
  ################ Prompt #################
  prompt|-p|--prompt)
    vType="prompt"
    printAvailProducts true
    [ $uInput -lt 0 ] && exit 1
    for i in "${!prdOpts[@]}"; do
      [ "${prdOpts[$i]}" == "$uInput" ] && vType="$i" && break
    done
    clear
    ./$scriptFile $vType && exit
    ;;
  ############### No Option ###############
  "")
    if $promptOptions ; then
      clear
      ./$scriptFile "prompt" && exit
    else
      clear
      ./$scriptFile "all" && exit
    fi
    ;;
  ################ Default ################
  *)
    echo "NOTE: To skip this prompt, use the command '$0 [option]'."
    echo "      Use '$0 --help' for usage information."
    echo ""
    printAvailProducts true
    [ $uInput -lt 0 ] && exit 1
    for i in "${!prdOpts[@]}"; do
      [ "${prdOpts[$i]}" == "$uInput" ] && vType="$i" && break
    done
    clear
    ./$scriptFile $vType && exit
    ;;
esac


########################################################
#                   START VALIDATION                   #
########################################################
# Overwrite the existing report file if exists
[ ! -z "$vType" ] && logFile="${logFile/.txt/-$vType.txt}" || exit 1
if $logFileIncludeTimestamp ; then logFile="$logFileTs_$logFile" ; fi
if $logToFile ; then printf "\n" > $logFile ; fi
printf "\n"

# Print Header
logTitle "$appTitle"
logLine "Product: $productName\n\n$dt"

############################################
logTitle "System Prerequisites"

############  Hostname  ############
logPrereq "Hostname" "$HOSTNAME"

############  Env Type  ############
if [ -f /.dockerenv ]; then
  envType="Container"
elif [ ! -z "$(cat /proc/version | grep "Microsoft")" ]; then
  envType="WSL 1"
elif [ ! -z "$(cat /proc/version | grep "microsoft")" ]; then
  envType="WSL 2"
else
  envType="Standard"
fi

logPrereq "Env Type" "$envType"

############  Hardware  ############
[[ " eua ua " =~ " $vType " ]] && noHwValidation=1 || noHwValidation=0

############  CPU  ############
CPU=$(getconf _NPROCESSORS_ONLN) # Should it be CPU(s) or Core(s) per socket?
[ $CPU -ge $minCPUs ] && CPUresult=1 || CPUresult=0

logPrereq "CPUs" "$CPU" $CPUresult "Min. $minCPUs CPUs" $noHwValidation

############  Memory  ############
MEMkb=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
let MEMint=MEMkb/1048576
let MEMdec=MEMkb%1048576
[ "${MEMdec:0:1}" == "0" ] && MEM="$MEMint" || MEM="$MEMint.${MEMdec:0:1}"
minMemActualKb=$(($minMemGB * 1048576))
[ $MEMkb -ge $minMemActualKb ] && MEMresult=1 || MEMresult=0

logPrereq "RAM" "$MEM GB" $MEMresult "Min. $minMemGB GB" $noHwValidation

############  Available Disk  ############
[[ $envType == "Container" ]] && noHddValidation=1 || noHddValidation=$noHwValidation
HDDkb=$(df -T | tr -s ' ' | grep -oP '.*(l?xfs).*' | awk '{print $5}')
let HDD=HDDkb/1048576
minHddActual=$(($minHddGB - 1))
[ $HDD -ge $minHddActual ] && HDDresult=1 || HDDresult=0
[ $HDD -eq 0 ] && [ "$envType" == "Container" ] && HDD="(none)"

logPrereq "Disk" "$HDD GB" $HDDresult "Min. $minHddGB GB" $noHddValidation

############  OS Version  ############
pName="OS"
osSupported=0

OSID=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
OSVER=$(grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"')
pVer=$OSID:$OSVER

for osv in "${supportedOs[@]}"; do if [[ "$pVer" =~ ^$osv.* ]] ; then osSupported=1 ; break; fi ; done
[ $osSupported -gt 0 ] && pResult=1 || pResult=0

logPrereq "$pName" "$pVer" $pResult "Unsupported operating system for $productName"


logTitle "Software Prerequisites"

if $vJava ; then
  ############  Java version  ############
  pName="Java"
  javaSupported=0
  pVer=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
  if [ -z "$pVer" ] ; then
    pVer="(none)"
  else
    IFS=. read jMajor jMinor jMicro <<<"${pVer}"
    for jv in "${supportedJava[@]}"; do
      [[ $jv == *.* ]] && jvStr="$jMajor.$jMinor" || jvStr="$jMajor"
      if [[ "$jvStr" == "$jv" ]] ; then
        javaSupported=1
        break
      fi
    done
  fi
  logPrereq "$pName" "$pVer" $javaSupported
  
  if [ $javaSupported -gt 0 ] ; then
    pName="JAVA_HOME"
    javaHome=$(dirname $(dirname $(readlink -f $(which java))))
    if [ -n "$javaHome" ] ; then
      if [ -n "$(echo $PATH | grep "JAVA_HOME")" ] || [ -n "$(echo $PATH | grep "$javaHome")" ] ; then
        pVer="Found"
        javaHomeSet=1
        javaMinAI=""
      else
        pVer='Not in $PATH'
        javaHomeSet=0
        javaMinAI='Add $JAVA_HOME to $PATH'
      fi
    else
      pVer="(not set)"
      javaHomeSet=0
      javaMinAI='Set $JAVA_HOME and add to $PATH'
    fi
    logPrereq "$pName" "$pVer" $javaHomeSet "$javaMinAI"
  fi
fi

if $vDocker ; then
  [[ " ua " =~ " $vType " ]] && noValidation=1 || noValidation=0
  ############  Docker version  ############
  pName="Docker"
  pVer=$(docker version 2>&1 | grep 'Version' -m 1 | awk -F ' ' '{print $NF}')
  [ "$OSID" == "rhel" ] && minDkrVerOs="$minDockerVerRhel" || minDkrVerOs="$minDockerVer"
  dockerMinAi="Install Docker v$minDkrVerOs or later"
  if [ -z "$pVer" ] ; then
    pVer="(none)"
    [ $noValidation -gt 0 ] && pResult="N/A" || pResult=0
  else
    IFS=. read dMajor dMinor dMicro <<<"${pVer}" ;
    if [[ "$OSID" == "rhel" ]] ; then
      if [ "$dMajor.$dMinor" == "$minDockerVerRhel" ] ; then
        pResult=1
      elif [ $dMajor -ge $minDockerVer ] ; then
        pResult=1
      else
        pResult=0
      fi
    else
      [ $dMajor -ge $minDkrVerOs ] && pResult=1 || pResult=0
    fi
  fi
  if [[ $envType == "Container" ]]; then
    logPrereq "$pName" "N/A"
  else
    logPrereq "$pName" "$pVer" $pResult "$dockerMinAi" $noValidation
  fi
fi

if $vJdeps ; then
  ############  jdeps version  ############
  pName="jdeps"
  pVer=$(jdeps -version 2>&1)
  if [[ $pVer =~ ^[0-9\.]{2,14}$ ]] ; then
    pResult=1
  else
    pVer="(none)"
    pResult=0
  fi
  logPrereq "$pName" "$pVer" $pResult "Install JDK 8 or later"
fi

if $vNodeJs ; then
  [[ " ua " =~ " $vType " ]] && noValidation=1 || noValidation=0
  ###########  NodeJS version  ############
  pName="NodeJS"
  pVer=$(node -v 2>&1)
  if [[ $pVer =~ ^(v)[0-9\.]{2,14}$ ]] ; then
    pVer=${pVer#?}
    IFS=. read nMajor nMinor nMicro <<<"${pVer}" ;
    [ $nMajor -ge ${minNodeVer%.*} ] && pResult=1 || pResult=0
  else
    pVer="(none)"
    [ $noValidation -gt 0 ] && pResult="N/A" || pResult=0
  fi
  logPrereq "$pName" "$pVer" $pResult "Install NodeJS $minNodeVer or later" $noValidation
fi

if $vPython ; then
  [[ " ua " =~ " $vType " ]] && noValidation=1 || noValidation=0
  ###########  Python version  ############
  pName="Python"
  pVer=$(python -V 2>&1 | awk -F ' ' '{print $NF}')
  if [ -z "$pVer" ] || [[ $pVer =~ found ]] ; then
    pVer="(none)"
    [ $noValidation -gt 0 ] && pResult="N/A" || pResult=0
  else
    IFS=. read pMajor pMinor pMicro <<<"${pVer}" ;
    if [ $pMajor -gt ${minPythonVer%.*} ] ; then
      pResult=1
    elif [ $pMajor -eq ${minPythonVer%.*} ] && [ $pMinor -ge ${minPythonVer: -1} ] ; then
      pResult=1
    else
      pResult=0
    fi
  fi
  logPrereq "$pName" "$pVer" $pResult "Install Python $minPythonVer or later" $noValidation
fi

if $vNetCore ; then
  [[ " ua " =~ " $vType " ]] && noValidation=1 || noValidation=0
  ######  .NET Core runtime version  ######
  pName=".NET App"
  pVerInfo=$(dotnet --list-runtimes 2>&1 | grep "NETCore.App")
  if [ -z "$pVerInfo" ] || [[ $pVerInfo =~ found ]] ; then
    pVer="(none)"
    [ $noValidation -gt 0 ] && pResult="N/A" || pResult=0
  else
    latestRt=$(echo "$pVerInfo" | sed -n "$(echo "$pVerInfo" | wc -l)"p | sed "s/\[.*//g")
    pVer=$(echo "$latestRt" | awk -F ' ' '{print $NF}')
    IFS=. read naMajor naMinor naMicro <<<"${pVer}" ;
    [ $naMajor -ge $minNetCoreAppVer ] && pResult=1 || pResult=0
  fi
  logPrereq "$pName" "$pVer" $pResult "Install .NET Core $minNetCoreAppVer or later" $noValidation
  
  #####  .NET Core framework version  #####
  if [[ ${OSID,,} == *"windows"* ]]; then # .NET FW validation required only on Windows
    pName=".NET FW"
    pVerInfo=$(command4dotnetFW --version 2>&1) ### PLACEHOLDER (irrelevant for Linux) ###
    if [ -z "$pVerInfo" ] || [[ $pVerInfo =~ found ]] ; then
      pVer="(none)"
      [ $noValidation -gt 0 ] && pResult="N/A" || pResult=0
    else
      pver="1.2.3"  ### PLACEHOLDER (irrelevant for Linux) ###
      IFS=. read nfMajor nfMinor nfMicro <<<"${pVer}" ;
      if [ $nfMajor -gt ${minNetCoreFwVer%.*} ] ; then
        pResult=1
      elif [ $nfMajor -eq ${minNetCoreFwVer%.*} ] && [ $nfMinor -ge ${minNetCoreFwVer: -1} ] ; then
        pResult=1
      else
        pResult=0
      fi
    fi
    logPrereq "$pName" "$pVer" $pResult "Install .NET Framework $minNetCoreFwVer or later" $noValidation
  fi
fi

if $vWsIndex ; then
  ############  WhiteSource Index  ############
  pName="WS Index"
  pVer="(unreachable)"
  pResult=0
  idxUrl="$wsUrlIndex"
  idxUrlCheck="$idxUrl/gri/app/check/ok"
  
  if [ ! -z $(which curl) ] ; then
    idxAccess=$(curl -s "$idxUrlCheck" 2>&1)
    eCode=$?
    [ $eCode -gt 0 ] && idxAccess="failed ($eCode)"
  elif [ ! -z $(which wget) ] ; then
    wget --spider -q "$idxUrlCheck" >/dev/null 2>&1
    eCode=$?
    [ $eCode -gt 0 ] && idxAccess="failed ($eCode)" || idxAccess="ok"
  fi
  
  if [ "$idxAccess" == "ok" ] ; then
    pVer="$idxAccess"
    pResult=1
  fi
  logPrereq "$pName" "$pVer" $pResult "Allow access to $idxUrl"
fi

if $vWsServer ; then
  ###########  WhiteSource Server  ############
  pName="WS Server"
  pVer="(unreachable)"
  pResult=0
  wsUrl="https://$defaultSaasEnv.whitesourcesoftware.com"
  
  if [ -n $(which curl) ] ; then
    wsAccess=$(curl -s "$wsUrl" 2>&1)
  elif [ -n $(which wget) ] ; then
    wget --spider -q "$wsUrl" >/dev/null 2>&1
  fi
  eCode=$?
  [ $eCode -gt 0 ] && wsAccess="failed ($eCode)" || wsAccess="ok"
  
  if [ "$wsAccess" == "ok" ] ; then
    pVer="$wsAccess"
    pResult=1
  fi
  logPrereq "$pName" "$pVer" $pResult "Allow access to WhiteSource server"
fi

if $vPorts ; then
  pName="Ports"
  if [[ " op " =~ " $vType " ]] ; then
    ports=("8080" "443")
  elif [[ " ws4d bb gh gl " =~ " $vType " ]] ; then
    ports=("8080" "5678" "9494" "9393")
  else
    ports=("8080" "443" "5678" "9494" "9393")
  fi
  portCnt=${#ports[@]}
  portAvl=0
  nonc=0
  naPortsTxt=""
  for (( i=0; i<${#ports[@]}; i++ )); do
    curPort=${ports[$i]}
    testPort $curPort
    if [ $nccode -eq 127 ] ; then
      nonc=1
      naPortsTxt=$(printf ",%s" "${ports[@]}")
      break ;
    elif [ $nccode -eq 0 ] ; then
      portAvl=$((portAvl + 1))
    else
      naPortsTxt+=",$curPort"
    fi
  done
  naPortsTxt=${naPortsTxt:1}
  portsMinAi=""
  if [ $nonc -gt 0 ] ; then
    pVer="(none)"
    pResult=0
    portsMinAi="Cannot validate availability of ports: $naPortsTxt"
  elif [ $portAvl -eq $portCnt ] ; then
    pVer="Full"
    pResult=1
  elif [ $portAvl -gt 0 ] ; then
    pVer="Partial"
    pResult=0
    portsMinAi="Allow communication on port(s): $naPortsTxt"
  else
    pVer="None"
    pResult=0
    portsMinAi="Allow communication on port(s): $naPortsTxt"
  fi
  logPrereq "$pName" "$pVer" $pResult "$portsMinAi"
fi

if $vPkgMgrs ; then
  logTitle "Package Managers"
  
  ############  Package Managers  ############
  # PM Name|PM Command|version command|Min Version|version info awk lookup text|version info text to replace
  declare -a pmParams
  pmParams[0]="Ant|ant|-version||Apache Ant(TM) version|compiled.*" # Java
  pmParams[1]="Bower|bower|-v|1.0||" # JavaScript
  pmParams[2]="Bundler|bundle|-v|1.0|Bundler version|" # Ruby
  pmParams[3]="Cabal|cabal|--version||cabal-install version|compiled using.*" # Haskell
  pmParams[4]="Cargo|cargo|--version||cargo|(.*" # Rust
  pmParams[5]="Cocoapods|pod|--version|||" # Swift
  pmParams[6]="Composer|composer|-V||Composer version|[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}" # PHP
  pmParams[7]="Go|go|version||go version|linux.*" # Go
  pmParams[8]="Gradle|gradle|-v|4.0|Gradle|" # Java
  pmParams[9]="Hex|mix|-v||Mix|(compiled.*" # Mix manages hex packages for Elixir and Erlang
  pmParams[10]="Maven|mvn|-v|3.0|Apache Maven|(.*" # Java
  pmParams[11]="NPM|npm|-v|6.0||" # JavaScript
  pmParams[12]="NuGet|nuget|help||NuGet Version:|" # .NET
  pmParams[13]="Packrat|packrat||||" # R
  # pmParams[13]="Renv|renv||||" # R # TBD - When renv will replace Packrat
  pmParams[14]="Paket|paket|--version|||" # .NET  ####### Verify
  pmParams[15]="Pip|pip|-V|1.0|pip|from.*" # Python
  pmParams[16]="SBT|sbt|sbtVersion||\[info\] [0-9].[0-9]|" # Scala
  pmParams[17]="Yarn|yarn|-v|||" # JavaScript

  pmIncludes=$(printf " %s" "${pkgMgrIncludes[@]} ")
  
  for (( i=0; i<${#pmParams[@]}; i++ )); do
    IFS=\| read -r pmName pmCmd pmVerCmd pmMinVer pmAwkTxt pmAwkTtr <<<"${pmParams[$i]}"
    if [ -z "$pmVerCmd" ] ; then pmVerCmd='-v' ; fi
    
    if [[ "$pmIncludes" =~ " $pmName " ]] ; then
      if [[ "$pmName" == "NuGet" ]] && [[ "$OSID" != "Windows" ]] ; then
        pmVerInfo="$($pmCmd $pmVerCmd 2>&1 | head -1)"
      else
        pmVerInfo=$($pmCmd $pmVerCmd 2>&1)
      fi
      
      if [ -z "$pmVerInfo" ] || [[ $pmVerInfo =~ found ]] || [[ $pmVerInfo =~ requires ]] || [[ $pmVerInfo =~ "No such file or directory" ]] ; then
        pmVer="(none)"
        pmResult="N/A"
        minVerAi=""
      else
        pmVerToken="$(echo "$pmVerInfo" | sed "s/\x1b\[[0-9;]*m//g" | grep "$pmAwkTxt")"
        if [ -z "$pmAwkTtr" ] ; then
          pmVerToken="$(echo "$pmVerToken" | awk -F ' ' '{print $NF}')" ;
        else
          pmVerToken="$(echo "$pmVerToken" | sed "s/$pmAwkTtr//g" | awk -F ' ' '{print $NF}')" ;
        fi
        pmVer=$(sed "s/[^0-9\.]//g" <<< $pmVerToken)
        IFS=. read pmMajor pmMinor pmMicro <<<"${pmVer}" ;
        IFS=. read minMajor minMinor minMicro <<<"${pmMinVer}" ;
        # Currently this only checks if the Major version is greater or equal to the minimum Major version
        validVer=true
        pmResult=1
        minVerAi=""
        if [ ! -z $pmMinVer ] ; then
          [ $pmMajor -ge $minMajor ] && validVer=true || validVer=false
          if ! $validVer ; then
            pmResult=0
            minVerAi="$pmName min. version: $pmMinVer"
          fi
        fi
      fi
      logPrereq "$pmName" "$pmVer" $pmResult "$minVerAi"
      # Go dep managers
      if [[ "$pmName" == "Go" ]] && [[ "$pmVer" != "(none)" ]] ; then
        declare -a goDepMgrs
        goDepMgrs[0]="dep|version|^ version     : |"
        goDepMgrs[1]="godep|version|godep|(.*"
        goDepMgrs[2]="vndr|vndr has no version opt||" # TBD
        goDepMgrs[3]="gogradle|not sure if can be installed independently||" # TBD
        goDepMgrs[4]="govendor|-version||"
        goDepMgrs[5]="gopm|-version|Gopm version|[a-zA-Z]"
        goDepMgrs[6]="glide|-version|glide version|"
        goDepMgrs[7]="vgo|vgo was merged into the Go tree||" # TBD
        goDepMgrs[8]="modules|modules is part of Go||"

        for (( g=0; g<${#goDepMgrs[@]}; g++ )); do
          IFS=\| read -r gdmName gdmVerCmd gdmAwkTxt gdmAwkTtr <<<"${goDepMgrs[$g]}"
          gdmVerInfo="$($gdmName $gdmVerCmd 2>&1)"
          if [ $? -eq 0 ] && [ ! -z "$gdmVerInfo" ] ; then
            if [ -z "$gdmAwkTtr" ] ; then
              gdmVer="$(echo "$gdmVerInfo" | grep "$gdmAwkTxt" | awk -F ' ' '{print $NF}')" ;
            else
              gdmVer="$(echo "$gdmVerInfo" | grep "$gdmAwkTxt" | sed "s/$gdmAwkTtr//g" | awk -F ' ' '{print $NF}')" ;
            fi
            [ ! -z "$gdmVer" ] && logPrereq "$pmName - $gdmName" "$gdmVer"
          fi
        done
      fi
    fi
  done
fi

dlmLine=$(printf '%0.s=' $(seq 1 $maxLineLen))
printf "\n$dlmLine\n"
duration=$SECONDS
printf "Process Complete\nDuration: %02d:%02d\n\n" $(($duration / 60)) $(($duration % 60))

if $logToFile ; then
  printf "Report generated:\n  $(pwd)/$logFile\n"
fi

if [[ ! -z $unmetPrereqs ]] ; then
  logTitle "Unmet Prerequisites Summary"
  summaryTxt="Product: $productName\n\n$unmetPrereqs"
else
  summaryTxt="\nAll prerequisites are confirmed\n"
fi

if $logToFile ; then
  printf "$summaryTxt" >> $logFile
fi
printf "$summaryTxt\n$dlmLine\n\n\n"
