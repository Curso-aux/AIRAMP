$port = New-Object System.IO.Ports.SerialPort "COM3", 115200, "None", 8, "One"
$port.ReadTimeout = 1000
try {
    $port.Open()
    $endTime = (Get-Date).AddSeconds(3)
    while ((Get-Date) -lt $endTime) {
        try {
            $data = $port.ReadExisting()
            if ($data.Length -gt 0) {
                Write-Host -NoNewline $data
            }
            Start-Sleep -Milliseconds 50
        } catch {
            break
        }
    }
} catch {
    Write-Output "Serial error: $_"
} finally {
    if ($port.IsOpen) {
        $port.Close()
    }
}
