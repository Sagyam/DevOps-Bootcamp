# Desktop notification helper for Windows — NO text-to-speech.
# Usage: powershell -ExecutionPolicy Bypass -File finops\notify.ps1 "Title" "Message"
# Never fails the step.
param([string]$Title = "GitHub Actions", [string]$Message = "")
try {
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  $n = New-Object System.Windows.Forms.NotifyIcon
  $n.Icon = [System.Drawing.SystemIcons]::Information
  $n.BalloonTipTitle = $Title
  $n.BalloonTipText  = $Message
  $n.Visible = $true
  $n.ShowBalloonTip(4000)
  # a soft, reliable system sound (this is NOT tts)
  [System.Media.SystemSounds]::Asterisk.Play()
  Start-Sleep -Milliseconds 400
  $n.Dispose()
} catch { }
exit 0
