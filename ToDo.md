# ToDo List - WhiteSource Prerequisite Validator

## All Environments
- For vWsServer, find a way to determine if it's onprem (and then not validate)
- Add validation for proxy
- Add external functions to compare between versions

## Bash
- Add support for Mac OS
- Find alternative way to check for port availability (nc is not OS-agnostic)
- Check if current user has access to create/modify the log file, and if not - require sudo
- Fix Gradle version when run on dockerized UA

## PowerShell
- Add support for Git Bash
