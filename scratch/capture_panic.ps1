$port = New-Object System.IO.Ports.SerialPort "COM3", 115200, "None", 8, "One"
$port.ReadTimeout = 500
try {
    $port.Open()
    $endTime = (Get-Date).AddSeconds(2)
    while ((Get-Date) -lt $endTime) {
        $data = $port.ReadExisting()
        if ($data) {
            Write-Host -NoNewline $data
        }
        Start-Sleep -Milliseconds 20
    }
} finally {
    if ($port.IsOpen) {
        $port.Close()
    }
}
