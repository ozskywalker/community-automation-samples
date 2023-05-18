# process commandline arguments
[CmdletBinding()]
param (
    [Parameter()][string]$vip = 'helios.cohesity.com',
    [Parameter()][string]$username = 'helios',
    [Parameter()][string]$domain = 'local',
    [Parameter()][string]$tenant = $null,
    [Parameter()][switch]$useApiKey,
    [Parameter()][string]$password = $null,
    [Parameter()][switch]$noPrompt,
    [Parameter()][switch]$mcm,
    [Parameter()][string]$mfaCode = $null,
    [Parameter()][string]$clusterName = $null,
    [Parameter()][string]$policyName,
    [Parameter()][ValidateSet('list', 'create', 'edit', 'delete', 'addextension', 'deleteextension', 'logbackup', 'addreplica', 'deletereplica', 'addarchive', 'deletearchive', 'editretries')][string]$action = 'list',
    [Parameter()][int]$retention,
    [Parameter()][ValidateSet('days', 'weeks', 'months', 'years')]$retentionUnit = 'days',
    [Parameter()][int]$frequency = 1,
    [Parameter()][ValidateSet('runs', 'minutes', 'hours', 'days', 'weeks', 'months', 'years')][string]$frequencyUnit = 'runs',
    [Parameter()][int]$retries = 3,
    [Parameter()][int]$retryMinutes = 5,
    [Parameter()][int]$lockDuration,
    [Parameter()][ValidateSet('days', 'weeks', 'months', 'years')]$lockUnit = 'days',
    [Parameter()][string]$targetName,
    [Parameter()][switch]$all
)

$textInfo = (Get-Culture).TextInfo
$frequentSchedules = @('Minutes', 'Hours', 'Days')

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -passwd $password -apiKeyAuthentication $useApiKey -mfaCode $mfaCode -heliosAuthentication $mcm -tenant $tenant -noPromptForPassword $noPrompt

# select helios/mcm managed cluster
if($USING_HELIOS){
    if($clusterName){
        $thisCluster = heliosCluster $clusterName
    }else{
        Write-Host "Please provide -clusterName when connecting through helios" -ForegroundColor Yellow
        exit 1
    }
}

if(!$cohesity_api.authorized){
    Write-Host "Not authenticated" -ForegroundColor Yellow
    exit 1
}

# outfile
$cluster = api get cluster
$dateString = (get-date).ToString('yyyy-MM-dd')
$outfileName = "policies-$($cluster.name)-$dateString.txt"

$policies = (api get -v2 data-protect/policies).policies | Sort-Object -Property name

if($policyname){
    $policy = $policies | Where-Object name -eq $policyName
    if(!$policy){
        if($action -ne 'create'){
            Write-Host "Policy $policyName not found!" -ForegroundColor Yellow
            exit
        }
    }else{
        if($action -eq 'create'){
            Write-Host "Policy $policyName already exists!" -ForegroundColor Yellow
            exit
        }
    }
}else{
    if($action -ne 'list'){
        Write-Host "-policyName required" -ForegroundColor Yellow
        exit
    }
}

# create new policy
if($action -eq 'create'){
    if(!$retention){
        Write-Host "-retention is required" -ForegroundColor Yellow
        exit
    }
    if(!$frequency){
        $frequency = 1
    }
    if($frequencyUnit -eq 'runs'){
        $frequencyUnit = 'days'
    }
    $policy = @{
        "backupPolicy" = @{
            "regular" = @{
                "incremental" = @{
                    "schedule" = @{
                        "unit" = $textInfo.ToTitleCase($frequencyUnit.ToLower())
                    }
                };
                "retention" = @{
                    "unit" = $textInfo.ToTitleCase($retentionUnit.ToLower())
                    "duration" = $retention
                }
            }
        };
        "id" = $null;
        "name" = $policyname;
        "description" = $null;
        "remoteTargetPolicy" = @{};
        "retryOptions" = @{
            "retries" = $retries;
            "retryIntervalMins" = $retryMinutes
        }
    }

    if($frequencyUnit -eq 'days'){
        $policy.backupPolicy.regular.incremental.schedule['daySchedule'] = @{
            "frequency" = $frequency
        }
    }
    if($frequencyUnit -eq 'hours'){
        $policy.backupPolicy.regular.incremental.schedule['hourSchedule'] = @{
            "frequency" = $frequency
        }
    }
    if($frequencyUnit -eq 'minutes'){
        $policy.backupPolicy.regular.incremental.schedule['minuteSchedule'] = @{
            "frequency" = $frequency
        }
    }
    if($lockDuration){
        if($cluster.clusterSoftwareVersion -lt '6.6.0d'){
            setApiProperty -object $policy -name 'dataLock' -value 'Compliance'
        }else{
            $policy.backupPolicy.regular.retention['dataLockConfig'] = @{
                "mode" = "Compliance";
                "unit" = $textInfo.ToTitleCase($lockUnit.ToLower());
                "duration" = $lockDuration
            }
        }
    }
    $newPolicy = api post -v2 data-protect/policies $policy
    $policies = @($newPolicy)
}

if($action -eq 'delete'){
    Write-Host "Deleting policy $($policy.name)"
    $null = api delete -v2 data-protect/policies/$($policy.id)
    exit
}

# edit policy
if($action -eq 'edit'){
    if(!$retention){
        Write-Host "-retention is required" -ForegroundColor Yellow
        exit
    }
    if(!$frequency){
        $frequency = 1
    }
    if($frequencyUnit -eq 'runs'){
        $frequencyUnit = 'days'
    }
    $policy.backupPolicy.regular.incremental = @{
        "schedule" = @{
            "unit" = $textInfo.ToTitleCase($frequencyUnit.ToLower())
        }
    }
    if($frequencyUnit -eq 'days'){
        setApiProperty -object $policy.backupPolicy.regular.incremental.schedule -name 'daySchedule' -value @{
            "frequency" = $frequency
        }
    }
    if($frequencyUnit -eq 'hours'){
        setApiProperty -object $policy.backupPolicy.regular.incremental.schedule -name 'hourSchedule' -value @{
            "frequency" = $frequency
        }
    }
    if($frequencyUnit -eq 'minutes'){
        setApiProperty -object $policy.backupPolicy.regular.incremental.schedule -name 'minuteSchedule' -value @{
            "frequency" = $frequency
        }
    }
    $policy.backupPolicy.regular.retention = @{
        "unit" = $textInfo.ToTitleCase($retentionUnit.ToLower())
        "duration" = $retention
    }
    if($lockDuration){
        if($cluster.clusterSoftwareVersion -lt '6.6.0d'){
            setApiProperty -object $policy -name 'dataLock' -value 'Compliance'
        }else{
            setApiProperty -object $policy.backupPolicy.regular.retention -name 'dataLockConfig' -value @{
                "mode" = "Compliance";
                "unit" = $textInfo.ToTitleCase($lockUnit.ToLower());
                "duration" = $lockDuration
            }
        }
    }
    $null = api put -v2 data-protect/policies/$($policy.id) $policy
}

# edit retry settings
if($action -eq 'editretries'){
    $policy.retryOptions = @{
        'retries' = $retries;
        'retryIntervalMins' = $retryMinutes
    }
    $null = api put -v2 data-protect/policies/$($policy.id) $policy
}

# add extend retention
if($action -eq 'addextension'){
    if(!$retention){
        Write-Host "-retention is required" -ForegroundColor Yellow
        exit
    }
    if(!$frequency){
        $frequency = 1
    }
    if($frequencyUnit -eq 'runs'){
        $frequencyUnit = 'days'
    }
    if(!$policy.PSObject.Properties['extendedRetention']){
        setApiPropery -object $policy -name 'extendedRetention' -value @()
        $existingRetention = $null
    }else{
        $existingRetention = $policy.extendedRetention | Where-Object {$_.schedule.unit -eq $frequencyUnit -and $_.schedule.frequency -eq $frequency}
    }
    if($existingRetention -eq $null){
        $newRetention = @{
            "schedule" = @{
                "unit" = $textInfo.ToTitleCase($frequencyUnit.ToLower());
                "frequency" = $frequency
            };
            "retention" = @{
                "unit" = $textInfo.ToTitleCase($retentionUnit.ToLower());
                "duration" = $retention
            }
        }
        if($lockDuration){
            if($cluster.clusterSoftwareVersion -lt '6.6.0d'){
                setApiProperty -object $policy -name 'dataLock' -value 'Compliance'
            }else{
                setApiProperty -object $newRetention.retention -name 'dataLockConfig' -value @{
                    "mode" = "Compliance";
                    "unit" = $textInfo.ToTitleCase($lockUnit.ToLower());
                    "duration" = $lockDuration
                }
            }
        }
        $policy.extendedRetention = @($policy.extendedRetention + $newRetention)
    }else{
        $existingRetention.retention.unit = $textInfo.ToTitleCase($retentionUnit.ToLower())
        $existingRetention.retention.duration = $retention
        if($lockDuration){
            if($cluster.clusterSoftwareVersion -lt '6.6.0d'){
                setApiProperty -object $policy -name 'dataLock' -value 'Compliance'
            }else{
                setApiProperty -object $existingRetention.retention -name 'dataLockConfig' -value @{
                    "mode" = "Compliance";
                    "unit" = $textInfo.ToTitleCase($lockUnit.ToLower());
                    "duration" = $lockDuration
                }
            }
        }
    }
    $null = api put -v2 data-protect/policies/$($policy.id) $policy
}

# delete extended retention
if($action -eq 'deleteextension'){
    if($policy.PSObject.Properties['extendedRetention']){
        $policy.extendedRetention = @($policy.extendedRetention | Where-Object {!($_.schedule.unit -eq $frequencyUnit -and $_.schedule.frequency -eq $frequency)})
    }
    $null = api put -v2 data-protect/policies/$($policy.id) $policy
}

# log backup
if($action -eq 'logbackup'){
    if(!$retention){
        Write-Host "-retention is required" -ForegroundColor Yellow
        exit
    }
    if(!$frequency){
        $frequency = 1
    }
    if($frequencyUnit -eq 'runs'){
        $frequencyUnit = 'hours'
    }
    if($frequencyUnit -notin @('minutes', 'hours')){
        Write-Host "log frequencyUnit must be minutes or hours"
        exit
    }
    if($policy.backupPolicy.PSObject.Properties['log']){
        $policy.backupPolicy.log = @{
            "schedule" = @{
                "unit" = $textInfo.ToTitleCase($frequencyUnit.ToLower());
            };
            "retention" = @{
                "unit" = $textInfo.ToTitleCase($retentionUnit.ToLower());
                "duration" = $retention
            }
        }
    }else{
        setApiProperty -object $policy.backupPolicy -name 'log' -value @{
            "schedule" = @{
                "unit" = $textInfo.ToTitleCase($frequencyUnit.ToLower());
            };
            "retention" = @{
                "unit" = $textInfo.ToTitleCase($retentionUnit.ToLower());
                "duration" = $retention
            }
        }
    }
    if($lockDuration){
        if($cluster.clusterSoftwareVersion -lt '6.6.0d'){
            setApiProperty -object $policy -name 'dataLock' -value 'Compliance'
        }else{
            setApiProperty -object $policy.backupPolicy.log.retention -name 'dataLockConfig' -value @{
                "mode" = "Compliance";
                "unit" = $textInfo.ToTitleCase($lockUnit.ToLower());
                "duration" = $lockDuration
            }
        }
    }
    if($frequencyUnit -eq 'hours'){
        setApiProperty -object $policy.backupPolicy.log.schedule -name 'hourSchedule' -value @{
            "frequency" = $frequency
        }
    }else{
        setApiPropery $policy.backupPolicy.log.schedule -name 'minuteSchedule' -value @{
            "frequency" = $frequency
        }
    }
    $null = api put -v2 data-protect/policies/$($policy.id) $policy
}

# add replica
if($action -eq 'addreplica'){
    if(!$targetName){
        Write-Host "-targetName required" -ForegroundColor Yellow
        exit
    }
    if(!$retention){
        Write-Host "-retention required" -ForegroundColor Yellow
        exit
    }
    if($frequencyUnit -eq 'minutes'){
        Write-Host "-frequencyUnit "minutes" not valid for replication" -ForegroundColor Yellow
        exit
    }
    $remoteClusters = api get remoteClusters
    $thisRemoteCluster = $remoteClusters | Where-Object name -eq $targetName
    if(!$thisRemoteCluster){
        Write-Host "Remote cluster $targetName not found" -ForegroundColor Yellow
        exit
    }
 
    if(!$policy.PSObject.Properties['remoteTargetPolicy']){
        setApiProperty -object $policy -name 'remoteTargetPolicy' -value @{ 'replicationTargets' = @()}
    }elseif(!$policy.remoteTargetPolicy.PSObject.Properties['replicationTargets']){
        setApiProperty -object $policy.remoteTargetPolicy -name 'replicationTargets' -value @()
    }
    $existingReplica = $policy.remoteTargetPolicy.replicationTargets | Where-Object {$_.targetType -eq "RemoteCluster" -and 
                                                                                     $_.remoteTargetConfig.clusterName -eq $targetName -and
                                                                                     $_.schedule.unit -eq $frequencyUnit -and
                                                                                     (!$_.schedule.PSObject.Properties['frequency'] -or
                                                                                      $_.schedule.frequency -eq $frequency)}
    if(!$existingReplica){
        $newReplica = @{
            "schedule" = @{
                "unit" = $textInfo.ToTitleCase($frequencyUnit.ToLower());
            };
            "retention" = @{
                "unit" = $textInfo.ToTitleCase($retentionUnit.ToLower());
                "duration" = $retention
            };
            "copyOnRunSuccess" = $false;
            "targetType" = "RemoteCluster";
            "remoteTargetConfig" = @{
                "clusterId" = $thisRemoteCluster.clusterId;
                "clusterName" = $thisRemoteCluster.name
            }
        }
        if($frequencyUnit -ne 'runs'){
            $newReplica.schedule['frequency'] = $frequency
        }
        if($lockDuration){
            if($cluster.clusterSoftwareVersion -lt '6.6.0d'){
                setApiProperty -object $policy -name 'dataLock' -value 'Compliance'
            }else{
                $newReplica.retention['dataLockConfig'] = @{
                    "mode" = "Compliance";
                    "unit" = $textInfo.ToTitleCase($lockUnit.ToLower());
                    "duration" = $lockDuration
                }
            }
        }
        $policy.remoteTargetPolicy.replicationTargets = @($policy.remoteTargetPolicy.replicationTargets + $newReplica)
    }else{
        $existingReplica.retention.unit = $textInfo.ToTitleCase($retentionUnit.ToLower());
        $existingReplica.retention.duration = $retention
        if($lockDuration){
            if($cluster.clusterSoftwareVersion -lt '6.6.0d'){
                setApiProperty -object $policy -name 'dataLock' -value 'Compliance'
            }else{
                setApiProperty -object $existingReplica.retention -name 'dataLockConfig' -value @{
                    "mode" = "Compliance";
                    "unit" = $textInfo.ToTitleCase($lockUnit.ToLower());
                    "duration" = $lockDuration
                }
            }
        }
    }

    $null = api put -v2 data-protect/policies/$($policy.id) $policy
}

# delete replica
if($action -eq 'deletereplica'){
    if(!$targetName){
        Write-Host "-targetName required" -ForegroundColor Yellow
        exit
    }
    if($frequencyUnit -eq 'minutes'){
        Write-Host "-frequencyUnit "minutes" not valid for replication" -ForegroundColor Yellow
        exit
    }
    $newReplicationTargets = @()
    $changedReplicationTargets = $false
    foreach($replicationTarget in $policy.remoteTargetPolicy.replicationTargets){
        $includeThisReplica = $True
        if($replicationTarget.targetType -eq "RemoteCluster" -and $replicationTarget.remoteTargetConfig.clusterName -eq $targetName){
            if($all){
                $includeThisReplica = $false
            }else{
                if($replicationTarget.schedule.unit -eq $frequencyUnit -and (!$replicationTarget.schedule.PSObject.Properties['frequency'] -or $replicationTarget.schedule.frequency -eq $frequency)){
                    $includeThisReplica = $false
                }
            }
            if($includeThisReplica -eq $True){
                $newReplicationTargets = @($newReplicationTargets + $replicationTarget)
            }else{
                $changedReplicationTargets = $True
            }
        }
    }
    if($changedReplicationTargets -eq $True){
        $policy.remoteTargetPolicy.replicationTargets = $newReplicationTargets
        $null = api put -v2 data-protect/policies/$($policy.id) $policy
    }
}

# add archive
if($action -eq 'addarchive'){
    if(!$targetName){
        Write-Host "-targetName required" -ForegroundColor Yellow
        exit
    }
    if(!$retention){
        Write-Host "-retention required" -ForegroundColor Yellow
        exit
    }
    if($frequencyUnit -eq 'minutes'){
        Write-Host "-frequencyUnit "minutes" not valid for archive" -ForegroundColor Yellow
        exit
    }
    $vaults = api get vaults
    $thisVault = $vaults | Where-Object name -eq $targetName
    if(!$thisVault){
        Write-Host "External target $targetName not found" -ForegroundColor Yellow
        exit
    }
    if(!$policy.PSObject.Properties['remoteTargetPolicy']){
        setApiProperty -object $policy -name 'remoteTargetPolicy' -value @{ 'archivalTargets' = @()}
    }elseif(!$policy.remoteTargetPolicy.PSObject.Properties['archivalTargets']){
        setApiProperty -object $policy.remoteTargetPolicy -name 'archivalTargets' -value @()
    }
    $existingTarget = $policy.remoteTargetPolicy.archivalTargets | Where-Object targetId -eq $thisVault.id
    if(!$existingTarget){
        $newTarget = @{
            "schedule" = @{
                "unit" = $textInfo.ToTitleCase($frequencyUnit.ToLower())
            };
            "retention" = @{
                "unit" = $textInfo.ToTitleCase($retentionUnit.ToLower());
                "duration" = $retention
            };
            "copyOnRunSuccess" = $alse;
            "targetId" = $thisVault.id;
            "targetName" = $thisVault.name;
            "targetType" = "Cloud"
        }
        if($lockDuration){
            if($cluster.clusterSoftwareVersion -lt '6.6.0d'){
                setApiProperty -object $policy -name 'dataLock' -value 'Compliance'
            }else{
                setApiProperty -object $newTarget.retention -name 'dataLockConfig' -value @{
                    "mode" = "Compliance";
                    "unit" = $textInfo.ToTitleCase($lockUnit.ToLower());
                    "duration" = $lockDuration
                }
            }
        }
        if($frequencyUnit -ne 'runs'){
            $newTarget.schedule.frequency = $frequency
        }
        $policy.remoteTargetPolicy.archivalTargets = @($policy.remoteTargetPolicy.archivalTargets + $newTarget)
    }else{
        $existingTarget.retention.unit = $textInfo.ToTitleCase($retentionUnit.ToLower())
        $existingTarget.retention.duration = $retention
        $existingTarget.schedule.unit = $textInfo.ToTitleCase($frequencyUnit.ToLower())
        if($frequencyUnit -ne 'runs'){
            setApiProperty $existingTarget.schedule -name 'frequency' -value $frequency
        }
        if($lockDuration){
            if($cluster.clusterSoftwareVersion -lt '6.6.0d'){
                setApiProperty -object $policy -name 'dataLock' -value 'Compliance'
            }else{
                setApiProperty -object $existingTarget.retention -name 'dataLockConfig' -value @{
                    "mode" = "Compliance";
                    "unit" = $textInfo.ToTitleCase($lockUnit.ToLower());
                    "duration" = $lockDuration
                }
            }
        }
    }
    $null = api put -v2 data-protect/policies/$($policy.id) $policy
}

# delete archive
if($action -eq 'deletearchive'){
    if(!$targetName){
        Write-Host "-targetName required" -ForegroundColor Yellow
        exit
    }
    if($frequencyUnit -eq 'minutes'){
        Write-Host "-frequencyUnit "minutes" not valid for replication" -ForegroundColor Yellow
        exit
    }
    if(!$policy.PSObject.Properties['remoteTargetPolicy']){
        setApiProperty -object $policy -name 'remoteTargetPolicy' -value @{}
    }
    if($policy.remoteTargetPolicy.PSObject.Properties['archivalTargets']){
        $newArchivalTargets = @()
        $changedArchivalTargets = $false
        foreach($archivalTarget in $policy.remoteTargetPolicy.archivalTargets){
            $includeThisArchive = $True
            if($archiveTarget['targetName'] -eq $targetName){
                $includeThisArchive = $false
            }
            if($includeThisArchive -eq $True){
                $newArchivalTargets = @($newArchivalTargets + $archivalTarget)
            }else{
                $changedArchivalTargets = $True
            }
        }
        if($changedArchivalTargets -eq $True){
            $policy.remoteTargetPolicy.archivalTargets = $newArchivalTargets
        }
        $null = api put -v2 data-protect/policies/$($policy.id) $policy
    }
}

# list policies
"" | Out-File -FilePath $outfileName
foreach($policy in $policies){
    $thisPolicyName = $policy.name
    "`n$('-' * $thisPolicyName.length)" | Tee-Object -FilePath $outfileName -Append
    "$thisPolicyName" | Tee-Object -FilePath $outfileName -Append
    "$('-' * $thisPolicyName.length)`n" | Tee-Object -FilePath $outfileName -Append
    # retry options
    if($policy.PSObject.Properties['retryOptions']){
        "             Retries:  $($policy.retryOptions.retries) times after $($policy.retryOptions.retryIntervalMins) minutes" | Tee-Object -FilePath $outfileName -Append
    }
    # base retention
    $baseRetention = $policy.backupPolicy.regular.retention
    $dataLock = ""
    if($baseRetention.PSObject.Properties['dataLockConfig']){
        $dataLock = ", datalock for $($baseRetention.dataLockConfig.duration) $($baseRetention.dataLockConfig.unit)"
    }
    if($policy.PSObject.Properties['datalock']){
        $dataLock = ", datalock for $($baseRetention.duration) $($baseRetention.unit)"
    }
    # incremental backup
    if($policy.backupPolicy.regular.PSObject.Properties['incremental']){
        $backupSchedule = $policy.backupPolicy.regular.incremental.schedule
        $unit = $backupSchedule.unit
        $unitPath = "{0}Schedule" -f ($unit.ToLower() -replace “.$”)
        if($unit -in $frequentSchedules){
            $frequency = $backupSchedule.$unitPath.frequency
            "  Incremental backup:  Every $frequency $unit  (keep for $($baseRetention.duration) $($baseRetention.unit)$dataLock)" | Tee-Object -FilePath $outfileName -Append
        }else{
            if($unit -eq 'Weeks'){
                "  Incremental backup:  Weekly on $($backupSchedule.$unitPath.dayOfWeek -join ', ')  (keep for $($baseRetention.duration) $($baseRetention.unit)$dataLock)" | Tee-Object -FilePath $outfileName -Append
            }
            if($unit -eq 'Months'){
                "  Incremental backup:  Monthly on the $($backupSchedule.$unitPath.weekOfMonth) $($backupSchedule.$unitPath.dayOfWeek[0])  (keep for $($baseRetention.duration) $($baseRetention.unit)$dataLock)" | Tee-Object -FilePath $outfileName -Append
            }
        }
    }
    # full backup
    if($policy.backupPolicy.regular.PSObject.Properties['full']){
        $backupSchedule = $policy.backupPolicy.regular.full.schedule
        $unit = $backupSchedule.unit
        $unitPath = "{0}Schedule" -f ($unit.ToLower() -replace “.$”)
        if($unit -in $frequentSchedules){
            $frequency = $backupSchedule.$unitPath.frequency
            "         Full backup:  Every $frequency $unit  (keep for $($baseRetention.duration) $($baseRetention.unit)$dataLock)" | Tee-Object -FilePath $outfileName -Append
        }else{
            if($unit -eq 'Weeks'){
                "         Full backup:  Weekly on $($backupSchedule.$unitPath.dayOfWeek -join ', ')  (keep for $($baseRetention.duration) $($baseRetention.unit)$dataLock)" | Tee-Object -FilePath $outfileName -Append
            }
            if($unit -eq 'Months'){
                "         Full backup:  Monthly on the $($backupSchedule.$unitPath.weekOfMonth) $($backupSchedule.$unitPath.dayOfWeek[0])  (keep for $($baseRetention.duration) $($baseRetention.unit)$dataLock)" | Tee-Object -FilePath $outfileName -Append
            }
            if($unit -eq 'ProtectOnce'){
                "         Full backup:  Once  (keep for $($baseRetention.duration) $($baseRetention.unit)$dataLock)" | Tee-Object -FilePath $outfileName -Append
            }
        }
    }
    # log backup
    if($policy.backupPolicy.PSObject.Properties['log']){
        $logRetention = $policy.backupPolicy.log.retention
        $backupSchedule = $policy.backupPolicy.log.schedule
        $unit = $backupSchedule.unit
        $unitPath = "{0}Schedule" -f ($unit.ToLower() -replace “.$”)
        $frequency = $backupSchedule.$unitPath.frequency
        $dataLock = ""
        if($logRetention.PSObject.Properties['dataLockConfig']){
            $dataLock = ", datalock for $($logRetention.dataLockConfig.duration) $($logRetention.dataLockConfig.unit)"
        }
        if($policy.PSObject.Properties['datalock']){
            $dataLock = ", datalock for $($logRetention.duration) $($logRetention.unit)"
        }
        "          Log backup:  Every $($frequency) $($unit)  (keep for $($logRetention.duration) $($logRetention.unit)$($dataLock))" | Tee-Object -FilePath $outfileName -Append
    }
    # extended retention
    if($policy.PSObject.Properties['extendedRetention'] -and $policy.extendedRetention){
        "  Extended retention:" | Tee-Object -FilePath $outfileName -Append
        foreach($extendedRetention in $policy.extendedRetention){
            $dataLock = ""
            if($extendedRetention.retention.PSObject.Properties['dataLockConfig']){
                $dataLock = ", datalock for $($extendedRetention.retention.dataLockConfig.duration) $($extendedRetention.retention.dataLockConfig.unit)"
            }
            if($policy.PSObject.Properties['datalock']){
                $dataLock = ", datalock for $($extendedRetention.retention.duration) $($extendedRetention.retention.unit)"
            }
            "                       Every $($extendedRetention.schedule.frequency) $($extendedRetention.schedule.unit)  (keep for $($extendedRetention.retention.duration) $($extendedRetention.retention.unit)$($dataLock))" | Tee-Object -FilePath $outfileName -Append
        }
    }
    # remote targets
    if($policy.PSObject.Properties['remoteTargetPolicy']){
        # replication targets
        if($policy.remoteTargetPolicy.PSObject.Properties['replicationTargets'] -and $policy.remoteTargetPolicy.replicationTargets){
            "        Replicate To:" | Tee-Object -FilePath $outfileName -Append
            foreach($replicationTarget in $policy.remoteTargetPolicy.replicationTargets){
                if($replicationTarget.targetType -eq "RemoteCluster"){
                    $targetName = $replicationTarget.remoteTargetConfig.clusterName
                }else{
                    $targetName = $replicationTarget.remoteTargetConfig.targetType
                }
                $frequencyUnit = $replicationTarget.schedule.unit
                if($frequencyUnit -eq 'runs'){
                    $frequency = 1
                }else{
                    $frequency = $replicationTarget.schedule.frequency
                }
                $dataLock = ""
                if($replicationTarget.retention.PSObject.Properties['dataLockConfig']){
                    $dataLock = ", datalock for $($replicationTarget.retention.dataLockConfig.duration) $($replicationTarget.retention.dataLockConfig.unit)"
                }
                if($policy.PSObject.Properties['datalock']){
                    $dataLock = ", datalock for $($replicationTarget.retention.duration) $($replicationTarget.retention.unit)"
                }
                "                       $($targetName):  Every $($frequency) $($frequencyUnit)  (keep for $($replicationTarget.retention.duration) $($replicationTarget.retention.unit)$($dataLock))" | Tee-Object -FilePath $outfileName -Append
            }
        }
        # archive targets
        if($policy.remoteTargetPolicy.PSObject.Properties['archivalTargets'] -and $policy.remoteTargetPolicy.archivalTargets){
            "          Archive To:" | Tee-Object -FilePath $outfileName -Append
            foreach($archivalTarget in $policy.remoteTargetPolicy.archivalTargets){
                $frequencyUnit = $archivalTarget.schedule.unit
                if($frequencyUnit -eq 'Runs'){
                    $frequency = 1
                }else{
                    $frequency = $archivalTarget.schedule.frequency
                }
                $dataLock = ""
                if($archivalTarget.retention.PSObject.Properties['dataLockConfig']){
                    $dataLock = ", datalock for $($archivalTarget.retention.dataLockConfig.duration) $($archivalTarget.retention.dataLockConfig.unit)"
                }
                if($policy.PSObject.Properties['datalock']){
                    $dataLock = ", datalock for $($archivalTarget.retention.duration) $($archivalTarget.retention.unit)"
                }
                "                       $($archivalTarget.targetName):  Every $($frequency) $($frequencyUnit)  (keep for $($archivalTarget.retention.duration) $($archivalTarget.retention.unit)$($dataLock))" | Tee-Object -FilePath $outfileName -Append
            }
        }

    }
    ""
}

"`nOutput saved to $outfilename`n"