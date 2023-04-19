function Invoke-Git {
    param([Parameter(Mandatory)][string] $Command)
    
    try {
        $exit = 0
        $path = [System.IO.Path]::GetTempFileName()
        Invoke-Expression "git $Command 2> $path"
        if ( $LASTEXITCODE -gt 0 ) {
            Write-Warning (Get-Content $path | Out-String)
        }
        else { Get-Content $path | Select-Object -First 1 }
    } catch {
        $exit = 0
        Write-Error "Error in script: $_`n$_.ScriptStackTrace"
    } finally {
        if ( Test-Path $path ) { Remove-Item $path }
    }
}