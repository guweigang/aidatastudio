param(
  [Parameter(Mandatory = $true)]
  [string]$Sidecar,

  [Parameter(Mandatory = $true)]
  [string]$ReadyFile,

  [Parameter(Mandatory = $true)]
  [string]$Token
)

$ErrorActionPreference = "Stop"
$runtimeInfo = [System.Diagnostics.ProcessStartInfo]::new()
$runtimeInfo.FileName = $Sidecar
[void]$runtimeInfo.ArgumentList.Add("database-runtime-daemon")
$runtimeInfo.UseShellExecute = $false
$runtimeInfo.CreateNoWindow = $true
$runtimeInfo.RedirectStandardInput = $true
$runtimeInfo.RedirectStandardOutput = $true
$runtime = [System.Diagnostics.Process]::new()
$runtime.StartInfo = $runtimeInfo
if (!$runtime.Start()) {
  throw "failed to start database runtime daemon"
}

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
try {
  $listener.Start()
  $endpoint = $listener.LocalEndpoint.ToString()
  [System.IO.File]::WriteAllText($ReadyFile, $endpoint)
  Write-Host "database runtime broker listening at $endpoint"

  while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
      $stream = $client.GetStream()
      $reader = [System.IO.StreamReader]::new($stream, [System.Text.UTF8Encoding]::new($false), $false, 4096, $true)
      $writer = [System.IO.StreamWriter]::new($stream, [System.Text.UTF8Encoding]::new($false), 4096, $true)
      $writer.AutoFlush = $true
      $response = $null
      try {
        $requestLine = $reader.ReadLine()
        $request = $requestLine | ConvertFrom-Json
        if ($request.token -ne $Token) {
          $response = @{ ok = $false; error = "database runtime broker authentication failed" }
        } else {
          if ($runtime.HasExited) {
            throw "database runtime daemon exited with code $($runtime.ExitCode)"
          }
          $requestId = [Guid]::NewGuid().ToString("N")
          $runtimeRequest = @{
            requestId = $requestId
            command = [string]$request.command
            args = @($request.args)
          } | ConvertTo-Json -Compress -Depth 20
          $runtime.StandardInput.WriteLine($runtimeRequest)
          $runtime.StandardInput.Flush()
          $runtimeResponseLine = $runtime.StandardOutput.ReadLine()
          if (!$runtimeResponseLine) {
            throw "database runtime daemon closed without a response"
          }
          $runtimeResponse = $runtimeResponseLine | ConvertFrom-Json
          if ($runtimeResponse.requestId -ne $requestId) {
            throw "database runtime response id mismatch"
          }
          $response = $runtimeResponse.response
        }
      } catch {
        $response = @{ ok = $false; error = $_.Exception.Message }
      }
      $writer.WriteLine(($response | ConvertTo-Json -Compress -Depth 20))
      $writer.Dispose()
      $reader.Dispose()
    } finally {
      $client.Dispose()
    }
  }
} finally {
  $listener.Stop()
  if (!$runtime.HasExited) {
    $runtime.Kill($true)
    $runtime.WaitForExit()
  }
  $runtime.Dispose()
}
