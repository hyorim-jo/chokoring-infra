# 운영 Jenkins 켜기 / 끄기 / 상태 (PowerShell)
param(
    [ValidateSet('up', 'down', 'status')]
    [string]$Action = 'status'
)

$ErrorActionPreference = 'Stop'
$LocalPort = 8080

# terraform/jenkins.tf 의 Name 태그로 찾는다
$InstanceId = aws ec2 describe-instances `
    --filters 'Name=tag:Name,Values=chokoring-jenkins' 'Name=instance-state-name,Values=pending,running,stopping,stopped' `
    --query 'Reservations[0].Instances[0].InstanceId' --output text
if (-not $InstanceId -or $InstanceId -eq 'None') { throw 'chokoring-jenkins 인스턴스를 찾지 못했다. AWS 계정과 로그인을 확인할 것' }

function Get-State {
    aws ec2 describe-instances --instance-ids $InstanceId --query 'Reservations[0].Instances[0].State.Name' --output text
}

switch ($Action) {
    'status' {
        Write-Host "Jenkins: $(Get-State)"
    }

    'down' {
        aws ec2 stop-instances --instance-ids $InstanceId --output text | Out-Null
        Write-Host '끄는 중...'
        aws ec2 wait instance-stopped --instance-ids $InstanceId
        Write-Host 'Jenkins 꺼짐'
    }

    'up' {
        if ((Get-State) -ne 'running') {
            aws ec2 start-instances --instance-ids $InstanceId --output text | Out-Null
            Write-Host '켜는 중...'
            aws ec2 wait instance-running --instance-ids $InstanceId
        }

        Write-Host 'SSM 연결 기다리는 중...'
        $online = $false
        for ($i = 0; $i -lt 36; $i++) {
            $ping = aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$InstanceId" --query 'InstanceInformationList[0].PingStatus' --output text
            if ($ping -eq 'Online') { $online = $true; break }
            Start-Sleep -Seconds 5
        }
        if (-not $online) { throw 'SSM 이 3분 안에 Online 이 되지 않았다. 콘솔에서 인스턴스 상태를 확인할 것' }

        Start-Job -ScriptBlock { param($p) Start-Sleep -Seconds 5; Start-Process "http://localhost:$p" } -ArgumentList $LocalPort | Out-Null
        Write-Host "http://localhost:$LocalPort  (종료: Ctrl+C, 다 쓰면 .\scripts\jenkins.ps1 down)"
        aws ssm start-session --target $InstanceId --document-name AWS-StartPortForwardingSession --parameters "portNumber=8080,localPortNumber=$LocalPort"
    }
}
