[CmdletBinding()]
param
(
    [string]$elasticsearchUrl="http://localhost:9200",
    [string]$indexMatchRegex="logstash-2017\.08\.07\.00",
    [switch]$whatIf=$true,
    [string]$logsDirectoryPath=$null
)

$error.Clear();

$ErrorActionPreference = "Stop";

$here = Split-Path $script:MyInvocation.MyCommand.Path;

. "$here\_Find-RootDirectory.ps1";

$rootDirectory = Find-RootDirectory $here;
$rootDirectoryPath = $rootDirectory.FullName;

if ([string]::IsNullOrEmpty($logsDirectoryPath))
{
    # Ahhh static state, necessary for the WriteOverrides :(
    $logsDirectoryPath = "$here\output\$((Get-Date).ToString("yyyyMMddHHmmss"))";
}

. "$rootDirectoryPath\scripts\common\Functions-WriteOverrides.ps1";
. "$rootDirectoryPath\scripts\common\Functions-Waiting.ps1";

if ($whatIf)
{
    Write-Verbose "Running a theoretical reindex of all indexes in [$elasticsearchUrl] that match pattern [$indexMatchRegex]";
}

$ErrorActionPreference = "Stop";

class ReindexResult
{
    ReindexResult([bool]$whatIf, [string]$index)
    {
        $this.WhatIf = $whatIf;
        $this.Name = $index;
        $this.Comment="Index [$index] has not been actioned";
    }

    [bool]$WhatIf;
    [string]$Name;
    [string]$Comment;
    [long]$TimeTaken;

    [bool]$Matches = $false;
    [bool]$Reindexed = $false;
}

function Test-Index
{
    [CmdletBinding()]
    param
    (
        [string]$elasticsearchUrl,
        [string]$indexName,
        [switch]$whatIf=$true
    )

    if ($whatIf)
    {
        Write-Verbose "WHATIF: Would have checked to see if the index [$indexName] existed here. Instead just returning false";
        return $false;
    }
    else 
    {
        try 
        {
            $index = Invoke-RestMethod -Method GET -Uri ("$elasticsearchUrl/$indexName") -Headers @{"accept"="application/json"};
            return $true;
        }
        catch 
        {
            if ($_.Exception.Message -match "404") { return $false; }
            else { throw $_; }
        }
    }
}

function Remove-Index
{
    [CmdletBinding()]
    param
    (
        [string]$elasticsearchUrl,
        [string]$indexName,
        [switch]$whatIf=$true
    )

    if ($WhatIf)
    {
        Write-Verbose "WHATIF: Would have deleted the index named [$indexName] here";
    }
    else 
    {
        Write-Verbose "Deleting index named [$indexName]";
        $delete = Invoke-WebRequest -Method DELETE -Uri ("$elasticsearchUrl/$indexName" + "?pretty") -Headers @{"accept"="application/json"};
        Write-Verbose "Delete response";
        Write-Verbose "-------------------------------------------";
        Write-Verbose $delete.Content;
        Write-Verbose "-------------------------------------------";

        $waitForIndexResult = Wait -ScriptToFillActualValue { Test-Index -elasticsearchUrl $elasticsearchUrl -indexName $indexName -whatIf:$whatIf; } -Condition { $actual -eq $false } -TimeoutSeconds 120 -IncrementSeconds 10;
    }
}

function Count-Index
{
    [CmdletBinding()]
    param
    (
        [string]$elasticsearchUrl,
        [string]$indexName,
        [switch]$whatIf=$true
    )

    if ($whatIf)
    {
        Write-Verbose "WHATIF: Would have retrieved the count of documents from index [$indexName] here. Instead just returning 0";
        return 0;
    }
    else 
    {
        $count = Invoke-RestMethod -Method GET -Uri ("$elasticsearchUrl/$indexName/_count?pretty") -Headers @{"accept"="application/json"};
        return $count.count;    
    }
}

function Reindex
{
    [CmdletBinding()]
    param
    (
        [string]$elasticsearchUrl,
        [string]$sourceIndex,
        [string]$destinationIndex,
        [switch]$whatIf=$true
    )

    if ($WhatIf)
    {
        Write-Verbose "WHATIF: Would have created a new index with name [$destinationIndex] here";
    }
    else 
    {
        Write-Verbose "Creating a new index with name [$destinationIndex]";
        $create = Invoke-WebRequest -Method PUT -Uri ("$elasticsearchUrl/$destinationIndex" + "?pretty") -Headers @{"accept"="application/json"};
        Write-Verbose "Create response";
        Write-Verbose "-------------------------------------------";
        Write-Verbose $create.Content;
        Write-Verbose "-------------------------------------------";
    }

    $sourceCount = Count-Index -elasticsearchUrl $elasticsearchUrl -indexName $sourceIndex -whatIf:$whatIf;
    Write-Verbose "Source index [$sourceIndex] has document count of [$sourceCount]. This will be used for comparison purposes after the reindex to check if it completed correctly";

    $reindexPayload = "{ `"source`": { `"index`": `"$($sourceIndex)`" }, `"dest`": { `"index`": `"$destinationIndex`", `"version_type`": `"external`" } }";

    if ($WhatIf)
    {
        Write-Verbose "WHATIF: Would have created a reindex request using payload [$reindexPayload]";
    }
    else
    {
        Write-Verbose "Reindexing using payload [$reindexPayload]";
        $reindex = Invoke-WebRequest -Method POST -Uri "$elasticsearchUrl/_reindex?wait_for_completion=false&pretty" -Body $reindexPayload -Headers @{"accept"="application/json";"content-type"="application/json"} -TimeoutSec 3600;
        Write-Verbose "Reindex response";
        Write-Verbose "-------------------------------------------";
        Write-Verbose $reindex.Content;
        Write-Verbose "-------------------------------------------";
    }

    # Wait for the reindex to complete, giving time for the document counts to synchronize
    $reindexCompleteWaitArgs = @{
        ScriptToFillActualValue={ Count-Index -elasticsearchUrl $elasticsearchUrl -indexName $destinationIndex -whatIf:$whatIf; };
        Condition={ $actual -eq $sourceCount };
        ConditionDescription="Actual document count in destination index [$destinationIndex] is equal to document count in source index [$sourceIndex], which is [$sourceCount]";
        TimeoutSeconds=600;
        IncrementSeconds=15;
    };

    try 
    {
        $destinationCount = Wait @reindexCompleteWaitArgs;
        $safeToDeleteSource = $sourceCount -le $destinationCount;
    }
    catch 
    {
        $safeToDeleteSource = $false;
    }

    if ($safeToDeleteSource)
    {
        Write-Verbose "Analysis has confirmed that it is safe to delete the source index [$sourceIndex ($sourceCount)], because there are the same number of documents in the destination index [$destinationIndex ($destinationCount)]";
        Remove-Index -elasticsearchUrl $elasticsearchUrl -indexName $sourceIndex -whatIf:$whatIf;
        return $true;
    }
    else 
    {
        Write-Warning "Analysis has pointed towards the new index [$destinationIndex ($destinationCount)] being incomplete due to document count differences. It will be deleted, and the source index [$sourceIndex ($sourceCount)] will remain";
        Remove-Index -elasticsearchUrl $elasticsearchUrl -indexName $destinationIndex -whatIf:$whatIf;
        return $false;
    }
}

$indices = Invoke-RestMethod "$elasticsearchUrl/_cat/indices?pretty" -Headers @{"accept"="application/json"};
$sortedIndices = $indices | Sort-Object { $_.index };
$results = @();
foreach ($index in $sortedIndices)
{
    $oldIndexName = $index.index;
    try
    {
        $result = new-object ReindexResult($WhatIf.IsPresent, $oldIndexName);
        $timer = [System.Diagnostics.Stopwatch]::StartNew();

        if ($oldIndexName -match $indexMatchRegex)
        {
            $result.Matches = $true;
            Write-Verbose "Index [$oldIndexName] matches pattern [$indexMatchRegex]. Beginning reindex"
            $newIndexName = "$oldIndexName-r";
            Write-Verbose "Reindexing into a temporary index [$newIndexName]";
            if (Reindex -elasticsearchUrl $elasticsearchUrl -sourceIndex $oldIndexName -destinationIndex $newIndexName -whatIf:$whatIf)
            {
                Write-Verbose "Initial reindex into a temporary index [$newIndexName] was successful. Reindexing back into an index with the original name [$oldIndexName] now";
                if (Reindex -elasticsearchUrl $elasticsearchUrl -sourceIndex $newIndexName -destinationIndex $oldIndexName -whatIf:$whatIf)
                {
                    $result.Reindexed = $true;
                    $result.Comment = "Index [$oldIndexName] successfully reindexed. It should now have the correct mappings";
                }
                else
                {
                    $result.Reindexed = $false;
                    $result.Comment = "Something went wrong with the reindex of [$oldIndexName]. Specifically something bad happened when reindexing the temporary index [$newIndexName] into a new index matching the original one. The temporary index remains, but the old one is gone forever";
                }
            }
            else 
            {
                $result.Reindexed = $false;
                $result.Comment = "Something went wrong with the reindex of [$oldIndexName]. The index has probably not been reindexed at all. Depending on the error, data might have been lost";
            }
        }
        else 
        {
            $result.Matches = $false;
            $result.Reindexed = $false;
            $result.Comment = "Index [$oldIndexName] does not match pattern [$indexMatchRegex]";
        }
    }
    finally
    {
        $result.TimeTaken = $timer.ElapsedMilliseconds;
        $results += $result;
    }
}

$formatted = $results | Format-Table -Auto | Out-String;
Write-Output $formatted;