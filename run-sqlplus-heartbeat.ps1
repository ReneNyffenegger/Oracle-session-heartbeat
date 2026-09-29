param(
   [string]$connectString,
   [string]$clientId                 = 'sqlplus',
   [int   ]$intervalSeconds          =  300,
   [int   ]$reconnectDelaySeconds    =  300
)

function write-log {
   param( [string]$message)

   write-host "[$(get-date -format 'yyyy-MM-dd HH:mm:ss')] $message"
}

function write-sqlLine {
   param(
      [System.Diagnostics.Process]$proc,
      [string]$line
   )

   if ($proc.HasExited) {
      throw "SQL*Plus exited with code $($proc.ExitCode)."
   }

   $proc.StandardInput.WriteLine($line)
   $proc.StandardInput.Flush()
}

while ($true) {
   $process        = $null
   $processStarted = $false

   try {

      $proc           = new-object System.Diagnostics.Process
      $proc.StartInfo = new-object System.Diagnostics.ProcessStartInfo
      $proc.StartInfo.FileName              = 'sqlplus.exe'
      $proc.StartInfo.Arguments             = "-L `"$connectString`""
      $proc.StartInfo.UseShellExecute       = $false
      $proc.StartInfo.RedirectStandardInput = $true

      write-log 'Starting a new SQL*Plus session.'
      $processStarted = $proc.Start()

    # Register once, then keep this SQL*Plus session idle between committed pings.
      write-sqlLine $proc 'whenever sqlerror exit sql.sqlcode'
      write-sqlLine $proc 'var id number'
      write-sqlLine $proc ("insert into tq84_heartbeat_session(client_id) values ('{0}') returning id into :id ;" -f $clientId.Replace("'", "''"))

      while (-not $proc.HasExited) {
         write-sqlLine $proc 'insert into tq84_heartbeat_ping(id_session) values (:id);'
         write-sqlLine $proc 'commit;'
         write-log 'Sent and flushed a ping.'

       # Poll during the client-side wait so a terminated SQL*Plus is restarted promptly.
         for ($seconds = 0; $seconds -lt $intervalSeconds -and -not $proc.HasExited; $seconds++) {
            start-sleep -seconds 1
         }
      }

      throw "SQL*Plus exited with code $($proc.ExitCode)."
   }
   catch {
      write-log $_.Exception.Message
   }
   finally {
      if ($proc) {
         if ($processStarted -and -not $proc.HasExited) {
            $proc.Kill()
            $proc.WaitForExit()
         }

         $proc.Dispose()
      }
   }

   write-log "Restarting SQL*Plus in $reconnectDelaySeconds seconds."
   start-sleep -seconds $reconnectDelaySeconds
}
