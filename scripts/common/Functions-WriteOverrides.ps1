function Get-TimestampForLogFileName
{
    return [DateTime]::Now.ToString('yyyyMMdd');
}

function Get-CurrentLogFile
{
    if ([string]::IsNullOrEmpty($logsDirectoryPath)) { throw "LogsDirectoryPath script scoped variable not set. Thats bad, its used to create log files for Powershell output." }

    $timestamp = Get-TimestampForLogFileName

    $logFilePath = "$logsDirectoryPath\$timestamp.log";
    if (-not(Test-Path $logFilePath))
    {
        $logFile = New-Item -Type File -Path $logFilePath -Force;
        $max = 5
        $current = 0
        while (-not ($logFile.Exists))
        {
            Sleep -Seconds 1
            $current++
            if ($current -gt $max) { break }
        }
    }

    return $logFilePath
}

function Get-TimestampForLogContent
{
    return [DateTime]::Now.ToString('yyyyMMddHHmmss');
}

function Retry-NoExceptionOnRepeatedFailures
{
    [CmdletBinding()]
    param
    (
        [scriptblock]$script,
        [int]$maxAttempts=5
    )

    $attempts = 1
    while ($attempts -le $maxAttempts)
    {
        try
        {
            return & $script;
        }
        catch
        {
            $attempts++;
            Sleep -Milliseconds 500;
        }
    }
}
function Write-Debug 
{
    [CmdletBinding()]
    param
    (
       [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
       [AllowEmptyString()]
       [System.String]${Message}
    )

    begin 
    {
       try 
       {
           $outBuffer = $null
           if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
           {
               $PSBoundParameters['OutBuffer'] = 1
           }
           $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Write-Debug', [System.Management.Automation.CommandTypes]::Cmdlet)
           $scriptCmd = {& $wrappedCmd @PSBoundParameters }
           $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
           $steppablePipeline.Begin($PSCmdlet)
       } 
       catch 
       {
           throw
       }
    }

    process 
    {
       try 
       {
            $logFilePath = Get-CurrentLogFile;
            Retry-NoExceptionOnRepeatedFailures -Script { Add-Content -Path $logFilePath "$(Get-TimestampForLogContent):DEBUG:$message" -Force } -maxAttempts 5;
            $steppablePipeline.Process($_)
       } 
       catch 
       {
           throw
       }
    }

    end 
    {
       try 
       {
           $steppablePipeline.End()
       } catch 
       {
           throw
       }
    }
}

function Write-Verbose 
{
    [CmdletBinding()]
    param
    (
       [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
       [AllowEmptyString()]
       [System.String]${Message}
    )

    begin 
    {
       try 
       {
           $outBuffer = $null
           if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
           {
               $PSBoundParameters['OutBuffer'] = 1
           }
           $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Write-Verbose', [System.Management.Automation.CommandTypes]::Cmdlet)
           $scriptCmd = {& $wrappedCmd @PSBoundParameters }
           $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
           $steppablePipeline.Begin($PSCmdlet)
       } 
       catch 
       {
           throw
       }
    }

    process 
    {
       try 
       {
            $logFilePath = Get-CurrentLogFile;
            Retry-NoExceptionOnRepeatedFailures -Script { Add-Content -Path $logFilePath "$(Get-TimestampForLogContent):VERBOSE:$message" -Force } -maxAttempts 5;
            $steppablePipeline.Process($_)
       } 
       catch 
       {
           throw
       }
    }

    end 
    {
       try 
       {
           $steppablePipeline.End()
       } catch 
       {
           throw
       }
    }
}

function Write-Output 
{
    [CmdletBinding()]
    param
    (
       [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
       [AllowEmptyString()]
       [System.String]${Message}
    )

    begin 
    {
       try 
       {
           $outBuffer = $null
           if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
           {
               $PSBoundParameters['OutBuffer'] = 1
           }
           $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Write-Output', [System.Management.Automation.CommandTypes]::Cmdlet)
           $scriptCmd = {& $wrappedCmd @PSBoundParameters }
           $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
           $steppablePipeline.Begin($PSCmdlet)
       } 
       catch 
       {
           throw
       }
    }

    process 
    {
       try 
       {
            $logFilePath = Get-CurrentLogFile;
            Retry-NoExceptionOnRepeatedFailures -Script { Add-Content -Path $logFilePath "$(Get-TimestampForLogContent):OUTPUT:$message" -Force } -maxAttempts 5;
            $steppablePipeline.Process($_)
       } 
       catch 
       {
           throw
       }
    }

    end 
    {
       try 
       {
           $steppablePipeline.End()
       } catch 
       {
           throw
       }
    }
}

function Write-Host
{
    [CmdletBinding()]
    param
    (
       [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
       [AllowEmptyString()]
       [System.String]${Message}
    )

    begin 
    {
       try 
       {
           $outBuffer = $null
           if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
           {
               $PSBoundParameters['OutBuffer'] = 1
           }
           $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Write-Host', [System.Management.Automation.CommandTypes]::Cmdlet)
           $scriptCmd = {& $wrappedCmd @PSBoundParameters }
           $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
           $steppablePipeline.Begin($PSCmdlet)
       } 
       catch 
       {
           throw
       }
    }

    process 
    {
       try 
       {
            $logFilePath = Get-CurrentLogFile;
            Retry-NoExceptionOnRepeatedFailures -Script { Add-Content -Path $logFilePath "$(Get-TimestampForLogContent):HOST:$message" -Force } -maxAttempts 5;
            $steppablePipeline.Process($_)
       } 
       catch 
       {
           throw
       }
    }

    end 
    {
       try 
       {
           $steppablePipeline.End()
       } 
       catch 
       {
           throw
       }
    }
}

function Write-Warning 
{
    [CmdletBinding()]
    param
    (
       [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
       [AllowEmptyString()]
       [System.String]${Message}
    )

    begin 
    {
       try 
       {
           $outBuffer = $null
           if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
           {
               $PSBoundParameters['OutBuffer'] = 1
           }
           $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Write-Warning', [System.Management.Automation.CommandTypes]::Cmdlet)
           $scriptCmd = {& $wrappedCmd @PSBoundParameters }
           $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
           $steppablePipeline.Begin($PSCmdlet)
       } 
       catch 
       {
           throw
       }
    }

    process 
    {
       try 
       {
            $logFilePath = Get-CurrentLogFile;
            Retry-NoExceptionOnRepeatedFailures -Script { Add-Content -Path $logFilePath "$(Get-TimestampForLogContent):WARNING:$message" -Force } -maxAttempts 5;
            $steppablePipeline.Process($_)
       } 
       catch 
       {
           throw
       }
    }

    end 
    {
       try 
       {
           $steppablePipeline.End()
       } catch 
       {
           throw
       }
    }
}