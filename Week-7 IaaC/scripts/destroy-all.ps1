# Destroy every lab, in the correct reverse order.
Set-Location (Join-Path $PSScriptRoot "..\code")

foreach ($dir in @("06-kubernetes","05-eks","04-ecr","03-ec2-ebs","02-iam","01-s3-state")) {
    if ((Test-Path $dir) -and (Test-Path (Join-Path $dir ".terraform"))) {
        Write-Host ""
        Write-Host "=== destroying $dir ===" -ForegroundColor Yellow
        Push-Location $dir
        terraform destroy -auto-approve
        if ($LASTEXITCODE -ne 0) { Write-Host "!! $dir failed - see labs/07-teardown.md" -ForegroundColor Red }
        Pop-Location
    } else {
        Write-Host "--- skipping $dir (never initialised) ---"
    }
}

Write-Host ""
Write-Host "Now VERIFY manually - Kubernetes-created load balancers and volumes are"
Write-Host "invisible to Terraform state:"
Write-Host "  aws eks list-clusters --region ap-south-1"
Write-Host "  aws elb describe-load-balancers --region ap-south-1"
Write-Host "  aws ec2 describe-volumes --region ap-south-1 --filters Name=status,Values=available"
