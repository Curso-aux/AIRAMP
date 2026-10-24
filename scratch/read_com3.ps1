$port = New-Object System.IO.Ports.SerialPort "COM3", 115200, "None", 8, "One"
$port.ReadTimeout = 3000
try {
    $port.Open()
    Write-Output "--- SERIAL LOG START ---"
    for ($i = 0; $i -lt 30; $i++) {
        try {
            $line = $port.ReadLine()
            Write-Output $line
        } catch {
            break
        }
    }
    Write-Output "--- SERIAL LOG END ---"
} catch {
    Write-Output "Serial error: $_"
} finally {
    if ($port.IsOpen) {
        $port.Close()
    }
}
