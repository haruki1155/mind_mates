$ErrorActionPreference = 'Stop'

$testFiles = @(
  'lib/assessment_rules.rules.js',
  'lib/breathing_session_rules.rules.js',
  'lib/firebase_secret_chat_rules.rules.js',
  'lib/firestore_sleep_rules.rules.js',
  'lib/inquiry_rules.rules.js',
  'lib/mind_aid_feedback_rules.rules.js',
  'lib/mind_aid_message_rules.rules.js',
  'lib/mind_aid_preference_rules.rules.js',
  'lib/mood_rules.rules.js',
  'lib/notification_rules.rules.js',
  'lib/profile_rules.rules.js',
  'lib/user_activity_rules.rules.js',
  'lib/user_device_token_rules.rules.js'
)

function Get-FirestoreEmulatorListener {
  Get-NetTCPConnection -LocalPort 8180 -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1
}

$existing = Get-FirestoreEmulatorListener
if ($null -ne $existing) {
  throw "Firestore emulator port 8180 is already in use by PID $($existing.OwningProcess). Stop that process before running the rule suite."
}

$logPath = Join-Path $env:TEMP 'mind-mates-firestore-emulator.log'
$errorPath = Join-Path $env:TEMP 'mind-mates-firestore-emulator-error.log'
$emulator = $null

try {
  $emulator = Start-Process -FilePath 'npx.cmd' -ArgumentList @(
    'firebase', 'emulators:start', '--project', 'mind-mates-rules-test',
    '--config', '..\firebase.test.json', '--only', 'firestore,storage'
  ) -WorkingDirectory (Get-Location) -RedirectStandardOutput $logPath -RedirectStandardError $errorPath -PassThru

  $deadline = (Get-Date).AddSeconds(45)
  do {
    Start-Sleep -Milliseconds 250
    if ($null -ne (Get-FirestoreEmulatorListener)) { break }
  } while ((Get-Date) -lt $deadline)

  if ($null -eq (Get-FirestoreEmulatorListener)) {
    $details = (Get-Content $logPath, $errorPath -ErrorAction SilentlyContinue | Select-Object -Last 40) -join [Environment]::NewLine
    throw "Firestore emulator did not become ready within 45 seconds.`n$details"
  }

  # The Rules Unit Testing SDK discovers emulators through these variables.
  # firebase emulators:exec normally injects them, but this runner owns the
  # emulator lifecycle so it must provide the same contract explicitly.
  $env:GCLOUD_PROJECT = 'mind-mates-rules-test'
  $env:FIRESTORE_EMULATOR_HOST = '127.0.0.1:8180'
  $env:FIREBASE_FIRESTORE_EMULATOR_ADDRESS = '127.0.0.1:8180'
  $env:FIREBASE_STORAGE_EMULATOR_HOST = '127.0.0.1:9299'
  $env:STORAGE_EMULATOR_HOST = 'http://127.0.0.1:9299'

  & node --test @testFiles
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally {
  if ($null -ne $emulator -and -not $emulator.HasExited) {
    Stop-Process -Id $emulator.Id -Force -ErrorAction SilentlyContinue
  }

  $listener = Get-FirestoreEmulatorListener
  if ($null -ne $listener) {
    $process = Get-CimInstance Win32_Process -Filter "ProcessId = $($listener.OwningProcess)"
    if ($process.CommandLine -match 'cloud-firestore-emulator') {
      Stop-Process -Id $listener.OwningProcess -Force -ErrorAction SilentlyContinue
    }
  }
}
