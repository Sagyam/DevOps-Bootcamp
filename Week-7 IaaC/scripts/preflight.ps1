# Verify the lab machine is ready. Windows PowerShell 5.1 or PowerShell 7.
$ok = 0; $fail = 0

function Test-Tool($name, $cmd, $versionArgs, $hint) {
    Write-Host ("{0,-24}" -f $name) -NoNewline
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        $v = (& $cmd $versionArgs 2>&1 | Select-Object -First 1)
        Write-Host "OK   $v" -ForegroundColor Green
        $script:ok++
    } else {
        Write-Host "MISSING  -> $hint" -ForegroundColor Red
        $script:fail++
    }
}

Write-Host "Terraform lab preflight"
Write-Host "-----------------------"
Test-Tool "terraform" "terraform" "version"           "winget install HashiCorp.Terraform"
Test-Tool "aws cli"   "aws"       "--version"         "winget install Amazon.AWSCLI"
Test-Tool "kubectl"   "kubectl"   "version"           "winget install Kubernetes.kubectl"
Test-Tool "docker"    "docker"    "--version"         "optional - only for the ECR bonus"

Write-Host ("{0,-24}" -f "credentials") -NoNewline
$arn = aws sts get-caller-identity --query Arn --output text 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK   $arn" -ForegroundColor Green
    $ok++
} else {
    Write-Host "FAILED   -> run: aws configure" -ForegroundColor Red
    $fail++
}

$region = aws configure get region 2>$null
Write-Host ""
Write-Host "region: $region"
Write-Host "passed: $ok   failed: $fail"

if ($fail -gt 0) {
    Write-Host ""
    Write-Host "Fix the items above before starting Lab 01."
    Write-Host "(docker is optional - ignore it if that is the only failure)"
    exit 1
}
