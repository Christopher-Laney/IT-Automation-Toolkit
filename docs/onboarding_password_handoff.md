# Secure Temporary Password Handoff

`scripts/identity/onboarding.ps1` omits generated temporary passwords from the normal run report by default.
When a workflow needs one-time credential delivery, use the separate encrypted handoff artifact instead of placing passwords into the CSV report.

## Create A Local AES Key

Create a 32 byte key once and store it outside source control:

```powershell
$key = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Fill($key)
[Convert]::ToBase64String($key) | Set-Content .\logs\onboarding-handoff.key
```

Keep the key file in a protected secret store or a tightly controlled local path.
Do not commit it to the repository.

## Write An Encrypted Handoff Artifact

```powershell
.\scripts\identity\onboarding.ps1 `
  -UserList .\config\new_users.csv `
  -SetTempPassword `
  -ApprovalRecordPath .\config\approval_record.sample.json `
  -ReportPath .\logs\onboarding_run.csv `
  -TemporaryPasswordHandoffPath .\logs\onboarding_password_handoff.json `
  -TemporaryPasswordKeyPath .\logs\onboarding-handoff.key
```

The standard report remains free of temporary passwords.
The handoff JSON stores each password as a `ConvertFrom-SecureString` AES value keyed by user principal name.

## Decrypt For A Controlled Handoff

```powershell
$key = [Convert]::FromBase64String((Get-Content -Raw .\logs\onboarding-handoff.key).Trim())
$handoff = Get-Content -Raw .\logs\onboarding_password_handoff.json | ConvertFrom-Json

foreach ($entry in $handoff.entries) {
  $secure = ConvertTo-SecureString $entry.encryptedPassword -Key $key
  $plain = [System.Net.NetworkCredential]::new('', $secure).Password
  [pscustomobject]@{
    UserPrincipalName = $entry.userPrincipalName
    TemporaryPassword = $plain
  }
}
```

Use the decrypted output only inside an approved handoff process, then remove the exported material according to your retention policy.

## Guardrails

- Prefer secure delivery systems such as a vault, password manager, or approved ticket workflow when available.
- Use the handoff artifact only with `-SetTempPassword`; no artifact is written when no temporary passwords are generated.
- Keep the AES key separate from the encrypted JSON file.
- Rotate or retire the key after the batch if your process requires one-time material.
