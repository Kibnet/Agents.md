[CmdletBinding()]
param(
    [string]$InputPath,
    [string]$TelemetryRoot,
    [string]$InstallManifestPath,
    [switch]$NoTelemetry
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ClassifierVersion = "3.2.0"
$script:MaxLogBytes = 10MB
$script:MaxLogFiles = 3
$script:MaxLogAgeDays = 45
$script:RecoveryAgeDays = 7
$script:TelemetryClock = $null

function Get-SingleDirectCommand {
    param([string]$Command)
    if ([string]::IsNullOrWhiteSpace($Command)) { return $null }
    $tokens=$null; $errors=$null
    $ast=[System.Management.Automation.Language.Parser]::ParseInput($Command,[ref]$tokens,[ref]$errors)
    if ($errors.Count -or $ast.ParamBlock -or $ast.BeginBlock -or $ast.ProcessBlock -or $ast.CleanBlock -or ($null -ne $ast.EndBlock.Traps -and $ast.EndBlock.Traps.Count -gt 0)) { return $null }
    $statements=@($ast.EndBlock.Statements)
    if ($statements.Count -ne 1 -or $statements[0] -isnot [System.Management.Automation.Language.PipelineAst]) { return $null }
    $parts=@($statements[0].PipelineElements)
    if ($parts.Count -ne 1 -or $parts[0] -isnot [System.Management.Automation.Language.CommandAst]) { return $null }
    $call=$parts[0]
    if ($call.InvocationOperator -ne [System.Management.Automation.Language.TokenKind]::Unknown -or $call.Redirections.Count) { return $null }
    foreach ($element in $call.CommandElements) {
        if ($element -isnot [System.Management.Automation.Language.StringConstantExpressionAst] -and $element -isnot [System.Management.Automation.Language.CommandParameterAst]) { return $null }
        if ($element -is [System.Management.Automation.Language.CommandParameterAst] -and $null -ne $element.Argument -and $element.Argument -isnot [System.Management.Automation.Language.StringConstantExpressionAst]) { return $null }
    }
    $name=$call.CommandElements[0].Value
    if ([System.IO.Path]::GetFileName($name) -notmatch '^(?i:rg(?:\.exe)?)$') { return $null }
    return $name
}

function Get-PropertyValue {
    param(
        [object]$Object,
        [string[]]$Names
    )

    if ($null -eq $Object) {
        return $null
    }

    foreach ($name in $Names) {
        $property = $Object.PSObject.Properties[$name]
        if ($null -ne $property) {
            return $property.Value
        }
    }

    return $null
}

function Get-Sha256 {
    param([string]$Text)

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return [Convert]::ToHexString($hash).ToLowerInvariant()
}

function Get-Sha256File {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        return [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($stream)).ToLowerInvariant()
    }
    finally {
        $stream.Dispose()
    }
}

function Get-TelemetryManifest {
    if ($NoTelemetry -or [string]::IsNullOrWhiteSpace($InstallManifestPath) -or
        -not (Test-Path -LiteralPath $InstallManifestPath -PathType Leaf)) {
        return $null
    }

    try {
        $manifest = [System.IO.File]::ReadAllText($InstallManifestPath) | ConvertFrom-Json -Depth 20
        $salt = [string](Get-PropertyValue -Object $manifest -Names @("telemetrySalt"))
        $challenge = [string](Get-PropertyValue -Object $manifest -Names @("activationChallenge"))
        $runtimeChecksums = Get-PropertyValue -Object $manifest -Names @("runtimeChecksums")
        $expectedHookHash = [string](Get-PropertyValue -Object $runtimeChecksums -Names @("hook"))
        if ((Get-PropertyValue -Object $manifest -Names @("schemaVersion")) -eq 1 -and
            [string](Get-PropertyValue -Object $manifest -Names @("owner")) -eq "agent-operations" -and
            [string](Get-PropertyValue -Object $manifest -Names @("runtimeVersion")) -eq $script:ClassifierVersion -and
            $expectedHookHash -match '^[0-9a-f]{64}$' -and
            (Get-Sha256File -Path $PSCommandPath) -eq $expectedHookHash -and
            $salt -match '^[0-9a-f]{64}$' -and
            $challenge -match '^(?:[0-9a-f]{32}|[0-9a-f]{64})$') {
            return [pscustomobject]@{
                Salt = $salt
                ActivationChallenge = $challenge
            }
        }
    }
    catch {
        # Missing or malformed privacy state disables telemetry without affecting the hook.
    }
    return $null
}

function Get-TelemetryContext {
    param([object]$Payload)

    if ($NoTelemetry -or [string]::IsNullOrWhiteSpace($TelemetryRoot)) {
        return $null
    }
    $telemetryManifest = Get-TelemetryManifest
    if ($null -eq $telemetryManifest) {
        return $null
    }
    $salt = $telemetryManifest.Salt

    $repoValue = [string](Get-PropertyValue -Object $Payload -Names @("cwd", "working_directory", "workingDirectory"))
    if ([string]::IsNullOrWhiteSpace($repoValue)) {
        $repoValue = "unknown"
    }
    else {
        try { $repoValue = [System.IO.Path]::GetFullPath($repoValue) } catch { }
        $repoValue = $repoValue.TrimEnd(
            [System.IO.Path]::DirectorySeparatorChar,
            [System.IO.Path]::AltDirectorySeparatorChar
        ).ToLowerInvariant()
    }

    $sessionValue = [string](Get-PropertyValue -Object $Payload -Names @("session_id", "sessionId"))
    return [pscustomobject]@{
        Salt = $salt
        ActivationChallenge = $telemetryManifest.ActivationChallenge
        ActivationHash = Get-Sha256 -Text ("$salt|activation|$($telemetryManifest.ActivationChallenge)")
        RepoHash = Get-Sha256 -Text ("$salt|repo|$repoValue")
        SessionHash = if ([string]::IsNullOrWhiteSpace($sessionValue)) { $null } else { Get-Sha256 -Text ("$salt|session|$sessionValue") }
    }
}

function Initialize-TelemetryNative {
    if ('AgentOperations.SafeStore' -as [type]) { return }
    if (-not $IsWindows) { throw 'telemetry-platform-unsupported' }
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Linq;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text.Json;
using Microsoft.Win32.SafeHandles;
namespace AgentOperations {
// Windows local NTFS only. Every leaf operation is relative to a held root handle.
// No pathname is reopened after validation. Deadline is cooperative, not a kernel I/O timeout.
public sealed class SafeStore : IDisposable {
 [StructLayout(LayoutKind.Sequential)] struct UNICODE_STRING { public ushort Length, MaximumLength; public IntPtr Buffer; }
 [StructLayout(LayoutKind.Sequential)] struct OBJECT_ATTRIBUTES { public int Length; public IntPtr RootDirectory, ObjectName; public uint Attributes; public IntPtr SecurityDescriptor, SecurityQualityOfService; }
 [StructLayout(LayoutKind.Sequential)] struct IO_STATUS_BLOCK { public IntPtr Status, Information; }
 [StructLayout(LayoutKind.Sequential)] struct FILE_INFO { public uint Attributes; public System.Runtime.InteropServices.ComTypes.FILETIME Creation, Access, Write; public uint Volume, SizeHigh, SizeLow, Links, IndexHigh, IndexLow; }
 [DllImport("ntdll.dll")] static extern int NtCreateFile(out SafeFileHandle handle,uint access,ref OBJECT_ATTRIBUTES attributes,out IO_STATUS_BLOCK status,IntPtr allocation,uint fileAttributes,uint share,uint disposition,uint options,IntPtr ea,uint eaLength);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandle(SafeFileHandle handle,out FILE_INFO info);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool GetVolumeInformationByHandleW(SafeFileHandle handle,StringBuilder volume,uint volumeSize,out uint serial,out uint maxLength,out uint flags,StringBuilder fs,uint fsSize);
 [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetFileInformationByHandle(SafeFileHandle handle,int type,ref int info,uint size);
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] static extern uint GetDriveTypeW(string root);
 const uint Synchronize=0x100000, DeleteAccess=0x10000, Read=0x80000000, Write=0x40000000;
 const long MaxBytes=10*1024*1024, MaxScan=30*1024*1024;
 readonly Stopwatch clock; readonly long budget; readonly byte[] key;
 readonly List<SafeFileHandle> directories=new List<SafeFileHandle>();
 SafeFileHandle root, mutex; FileStream metadata; string metadataIdentity; string rootIdentity;
 Ledger ledger; byte[] originalMetadata; long scanBytes;
 readonly Dictionary<string,FileStream> files=new Dictionary<string,FileStream>();
 public string Diagnostic {get;private set;} = "";
 public sealed class Segment { public string Name {get;set;} public string Identity {get;set;} public string Generation {get;set;} public DateTimeOffset MinTime {get;set;} public DateTimeOffset Created {get;set;} }
 public sealed class Warning { public string Key {get;set;} public DateTimeOffset Timestamp {get;set;} }
 public sealed class Ledger { public int SchemaVersion {get;set;}=1; public string Generation {get;set;} public string RootIdentity {get;set;} public string MetadataIdentity {get;set;} public List<Segment> Segments {get;set;}=new List<Segment>(); public List<Warning> Warnings {get;set;}=new List<Warning>(); }
 public sealed class Envelope { public string Payload {get;set;} public string Binding {get;set;} }
 void Check() { if(clock.ElapsedMilliseconds>=budget) throw new IOException("telemetry-budget-exhausted"); }
 static void Leaf(string name) { if(String.IsNullOrEmpty(name)||name=="."||name==".."||name.IndexOfAny(new[]{'\\','/',':','\0'})>=0||name.EndsWith(".")||name.EndsWith(" ")) throw new IOException("unsafe-leaf"); }
 static FILE_INFO Info(SafeFileHandle h,bool directory) { FILE_INFO i; if(!GetFileInformationByHandle(h,out i)||(i.Attributes&0x400)!=0||((i.Attributes&0x10)!=0)!=directory||(!directory&&i.Links!=1)) throw new IOException("unsafe-file-type-or-links"); return i; }
 static string Identity(SafeFileHandle h,bool dir=false) { var i=Info(h,dir); return i.Volume.ToString("x8")+":"+i.IndexHigh.ToString("x8")+i.IndexLow.ToString("x8"); }
 SafeFileHandle Open(SafeFileHandle parent,string name,bool directory,uint disposition,out bool created,bool anchor=false) {
   Check(); if(!anchor) Leaf(name);
   IntPtr buffer=Marshal.StringToHGlobalUni(name), unicode=IntPtr.Zero;
   try { var us=new UNICODE_STRING {Length=checked((ushort)(name.Length*2)),MaximumLength=checked((ushort)(name.Length*2+2)),Buffer=buffer}; unicode=Marshal.AllocHGlobal(Marshal.SizeOf<UNICODE_STRING>()); Marshal.StructureToPtr(us,unicode,false);
    var oa=new OBJECT_ATTRIBUTES {Length=Marshal.SizeOf<OBJECT_ATTRIBUTES>(),RootDirectory=parent==null?IntPtr.Zero:parent.DangerousGetHandle(),ObjectName=unicode,Attributes=0x40|0x1000};
    IO_STATUS_BLOCK ios; SafeFileHandle h;
    // Directory handles exclude DELETE sharing, pinning every component against replacement.
    int status=NtCreateFile(out h,directory?(Synchronize|0x81u):(Read|Write|Synchronize|DeleteAccess),ref oa,out ios,IntPtr.Zero,0,directory?3u:0u,disposition,0x200000u|0x20u|(directory?1u:0x40u),IntPtr.Zero,0);
    created=ios.Information.ToInt64()==2;
    if(status<0) { if(h!=null)h.Dispose(); throw new IOException("native-open:"+status.ToString("x8")); }
    try { var info=Info(h,directory); if(root!=null&&info.Volume!=Info(root,true).Volume) throw new IOException("volume-mismatch"); return h; } catch {h.Dispose();throw;}
   } finally { if(unicode!=IntPtr.Zero)Marshal.FreeHGlobal(unicode); Marshal.FreeHGlobal(buffer); }
 }
 FileStream Stream(string name,uint disposition,out bool created) { var h=Open(root,name,false,disposition,out created); try{return new FileStream(h,FileAccess.ReadWrite,65536,false);}catch{h.Dispose();throw;} }
 byte[] ReadBounded(FileStream f,long limit) { Check(); if(f.Length>limit)throw new IOException("telemetry-oversized-input"); var bytes=new byte[checked((int)f.Length)]; f.Position=0; int pos=0; while(pos<bytes.Length) {Check();int n=f.Read(bytes,pos,Math.Min(65536,bytes.Length-pos));if(n==0)throw new IOException("short-read");pos+=n;scanBytes+=n;if(scanBytes>MaxScan+65536)throw new IOException("scan-limit");} return bytes; }
 static void WriteAll(FileStream f,byte[] bytes) { f.Position=0; for(int p=0;p<bytes.Length;p+=65536)f.Write(bytes,p,Math.Min(65536,bytes.Length-p));f.SetLength(bytes.Length);f.Flush(true); }
 string Mac(string payload) { using(var h=new HMACSHA256(key))return Convert.ToHexString(h.ComputeHash(Encoding.UTF8.GetBytes(payload))); }
 void Save() { var payload=JsonSerializer.Serialize(ledger); var bytes=Encoding.UTF8.GetBytes(JsonSerializer.Serialize(new Envelope{Payload=payload,Binding=Mac(payload)})); if(bytes.Length>65536)throw new IOException("metadata-limit"); var before=originalMetadata;try {WriteAll(metadata,bytes);originalMetadata=bytes;}catch{try{WriteAll(metadata,before);}catch{}throw;} }
 static void MarkDelete(FileStream f) {Info(f.SafeFileHandle,false);int delete=1;if(!SetFileInformationByHandle(f.SafeFileHandle,4,ref delete,4))throw new IOException("handle-delete:"+Marshal.GetLastWin32Error());}
 public SafeStore(string path,string salt,Stopwatch timer,long deadline=1500) {
  clock=timer;budget=deadline;key=Convert.FromHexString(salt);
  try {
   Check(); if(!OperatingSystem.IsWindows()||!System.Text.RegularExpressions.Regex.IsMatch(path,@"^[A-Za-z]:[\\/]"))throw new IOException("unsupported-root");
   var components=path.Substring(3).Split(new[]{'\\','/'},StringSplitOptions.RemoveEmptyEntries); foreach(var c in components)Leaf(c);
   string drive=path.Substring(0,3).Replace('/','\\'); if(GetDriveTypeW(drive)!=3)throw new IOException("nonlocal-volume");
   bool made;root=Open(null,@"\??\"+drive,true,1,out made,true);directories.Add(root);
   var fs=new StringBuilder(32);uint serial,max,flags;if(!GetVolumeInformationByHandleW(root,null,0,out serial,out max,out flags,fs,32)||fs.ToString()!="NTFS")throw new IOException("non-NTFS");
   foreach(var component in components) {root=Open(root,component,true,3,out made);directories.Add(root);}
   rootIdentity=Identity(root,true);
   // The lock is never truncated/deleted. OPEN_IF permits existing lock bytes but no mutation.
   mutex=Open(root,".agent-operations.lock",false,3,out made);
   bool created=false;
   try { metadata=Stream(".agent-operations-store.json",2,out created); }
   catch(IOException e) when(e.Message=="native-open:c0000035") { metadata=Stream(".agent-operations-store.json",1,out created); }
   metadataIdentity=Identity(metadata.SafeFileHandle);
   if(created) {
    originalMetadata=Array.Empty<byte>();ledger=new Ledger{Generation=Guid.NewGuid().ToString("N"),RootIdentity=rootIdentity,MetadataIdentity=metadataIdentity};
    try{Check();Save();}catch{MarkDelete(metadata);throw;}
   } else {
    originalMetadata=ReadBounded(metadata,65536);var envelope=JsonSerializer.Deserialize<Envelope>(originalMetadata);
    if(envelope==null||envelope.Payload==null||envelope.Binding!=Mac(envelope.Payload))throw new IOException("metadata-unowned");
    ledger=JsonSerializer.Deserialize<Ledger>(envelope.Payload);
    if(ledger==null||ledger.SchemaVersion!=1||ledger.RootIdentity!=rootIdentity||ledger.MetadataIdentity!=metadataIdentity||!Guid.TryParseExact(ledger.Generation,"N",out _)||ledger.Segments==null||ledger.Segments.Count>3||ledger.Warnings==null||ledger.Warnings.Count>128)throw new IOException("metadata-binding-mismatch");
   }
   foreach(var seg in ledger.Segments) {
    if(!new[]{"agent-operations.jsonl","agent-operations.1.jsonl","agent-operations.2.jsonl"}.Contains(seg.Name)||files.ContainsKey(seg.Name)||!Guid.TryParseExact(seg.Generation,"N",out _))throw new IOException("segment-contract");
    var file=Stream(seg.Name,1,out made);files.Add(seg.Name,file);if(Identity(file.SafeFileHandle)!=seg.Identity)throw new IOException("segment-binding-mismatch");
   }
  } catch {Dispose();throw;}
 }
 // Validation scans only identity-bound segments: filename/JSON shape never creates ownership.
 public void Maintain(DateTimeOffset now) {
  foreach(var seg in ledger.Segments.ToArray()) {
   Check();var file=files[seg.Name];byte[] bytes=ReadBounded(file,MaxBytes);bool malformed=false;DateTimeOffset? min=null;
   int start=0;for(int i=0;i<bytes.Length;i++){if(i-start>=65536)throw new IOException("oversized-line");if(bytes[i]!=10)continue;Check();try{using(var doc=JsonDocument.Parse(bytes.AsMemory(start,i-start))){var time=doc.RootElement.GetProperty("timestamp").GetDateTimeOffset();if(min==null||time<min)min=time;}}catch{malformed=true;}start=i+1;}
   if(start!=bytes.Length)malformed=true;
   if(min!=null&&min<seg.MinTime)seg.MinTime=min.Value;
   if(malformed||seg.MinTime<now.AddDays(-45)) Remove(seg);
  }
 }
 void Remove(Segment seg) {
  Check();var file=files[seg.Name];if(Identity(file.SafeFileHandle)!=seg.Identity)throw new IOException("segment-binding-mismatch");
  int index=ledger.Segments.IndexOf(seg);ledger.Segments.RemoveAt(index);
  try{Save();try{MarkDelete(file);}catch{ledger.Segments.Insert(index,seg);Save();throw;}}catch{if(!ledger.Segments.Contains(seg))ledger.Segments.Insert(index,seg);throw;}
  file.Dispose();files.Remove(seg.Name);
 }
 public void Append(string json,DateTimeOffset now) {
  Check();byte[] bytes=Encoding.UTF8.GetBytes(json+"\n");if(bytes.Length>65536)throw new IOException("oversized-event");
  var seg=ledger.Segments.LastOrDefault();if(seg!=null&&files[seg.Name].Length+bytes.Length>MaxBytes)seg=null;
  if(seg==null){
   if(ledger.Segments.Count==3)Remove(ledger.Segments[0]);Check();
   string name=new[]{"agent-operations.jsonl","agent-operations.1.jsonl","agent-operations.2.jsonl"}.First(n=>!files.ContainsKey(n));
   bool made;var f=Stream(name,2,out made); // CREATE, never adopt an existing legacy/foreign file.
   seg=new Segment{Name=name,Identity=Identity(f.SafeFileHandle),Generation=Guid.NewGuid().ToString("N"),MinTime=now,Created=now};
   files.Add(name,f);ledger.Segments.Add(seg);
   try{Save();}catch{ledger.Segments.Remove(seg);MarkDelete(f);f.Dispose();files.Remove(name);throw;}
  }
  Check();var target=files[seg.Name];if(Identity(target.SafeFileHandle)!=seg.Identity)throw new IOException("segment-binding-mismatch");long length=target.Length;var previous=seg.MinTime;
  try{target.Position=length;target.Write(bytes);target.Flush(true);if(now<seg.MinTime)seg.MinTime=now;Save();}catch{target.SetLength(length);target.Flush(true);seg.MinTime=previous;throw;}
 }
 public bool RecordWarning(string warningKey,DateTimeOffset now) {
  Check();ledger.Warnings.RemoveAll(w=>w.Timestamp<now.AddDays(-1));bool duplicate=ledger.Warnings.Any(w=>w.Key==warningKey);
  if(!duplicate)ledger.Warnings.Add(new Warning{Key=warningKey,Timestamp=now});while(ledger.Warnings.Count>128)ledger.Warnings.RemoveAt(0);Save();return duplicate;
 }
 public void Dispose(){foreach(var f in files.Values)f.Dispose();files.Clear();if(metadata!=null){metadata.Dispose();metadata=null;}if(mutex!=null){mutex.Dispose();mutex=null;}for(int i=directories.Count-1;i>=0;i--)directories[i].Dispose();directories.Clear();}
}
}
'@
}

function Open-TelemetryStore {
    param([string]$Root,[object]$Context)
    if ($NoTelemetry -or [string]::IsNullOrWhiteSpace($Root) -or $null -eq $Context) { return $null }
    if ($null -eq $script:TelemetryClock) { $script:TelemetryClock=[Diagnostics.Stopwatch]::StartNew() }
    if ($script:TelemetryClock.ElapsedMilliseconds -ge 1500) { return $null }
    Initialize-TelemetryNative
    return [AgentOperations.SafeStore]::new($Root,$Context.Salt,$script:TelemetryClock,1500)
}

function Write-TelemetryEvent {
    param([string]$Root,[object]$Context,[string]$EventName,[string]$Category,[string]$Severity,[string]$Action,[string]$ExitClass)
    $store=$null
    try {
        $store=Open-TelemetryStore $Root $Context
        if ($null -eq $store) { return }
        $now=[DateTimeOffset]::UtcNow
        $store.Maintain($now)
        $record=[ordered]@{schemaVersion=1;timestamp=$now.ToString('o');runtimeVersion=$script:ClassifierVersion;eventName=$EventName;category=$Category;severity=$Severity;action=$Action;exitClass=$ExitClass;repoHash=$Context.RepoHash}
        if (-not [string]::IsNullOrWhiteSpace([string]$Context.SessionHash)) { $record.sessionHash=$Context.SessionHash }
        $store.Append(($record|ConvertTo-Json -Compress),$now)
    } catch { [Console]::Error.WriteLine('Agent operations telemetry skipped: '+$_.Exception.GetBaseException().Message) }
    finally { if($null -ne $store){$store.Dispose()} }
}

function Test-AndRecordDuplicateWarning {
    param([string]$Root,[object]$Context,[object]$Payload,[string]$EventName,[string]$Category)
    $store=$null
    try {
        $turn=[string](Get-PropertyValue $Payload @('turn_id','turnId'))
        if ([string]::IsNullOrWhiteSpace($turn)) { return $false }
        $store=Open-TelemetryStore $Root $Context
        if($null -eq $store){return $false}
        $key=Get-Sha256 "$($Context.Salt)|warning|$turn|$EventName|$Category"
        return $store.RecordWarning($key,[DateTimeOffset]::UtcNow)
    } catch { [Console]::Error.WriteLine('Agent operations telemetry skipped: '+$_.Exception.GetBaseException().Message); return $false }
    finally { if($null -ne $store){$store.Dispose()} }
}


function Get-ExitClass {
    param(
        [string]$Category,
        [string]$Outcome
    )

    if ($Category -eq "timeout") { return "timeout" }
    switch ($Outcome) {
        "success" { return "success" }
        "expected-no-match" { return "expected-no-match" }
        "real-failure" { return "failure" }
        "environment-blocker" { return "failure" }
        "fail-open" { return "fail-open" }
        default { return "unknown" }
    }
}

function Get-CommandText {
    param([object]$Payload)

    $toolInput = Get-PropertyValue -Object $Payload -Names @("tool_input", "toolInput")
    if ($toolInput -is [string]) {
        return $toolInput
    }

    $command = Get-PropertyValue -Object $toolInput -Names @("command", "cmd", "script")
    if ($command -is [System.Collections.IEnumerable] -and $command -isnot [string]) {
        return (@($command) -join " ")
    }
    if ($command -is [string]) {
        return $command
    }

    return $null
}

function Get-CommandAsts {
    param([string]$Command)

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput(
        $Command,
        [ref]$tokens,
        [ref]$parseErrors
    )

    if (@($parseErrors).Count -gt 0) {
        return @()
    }

    return @($ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst]
    }, $true))
}

function Get-ElementText {
    param([System.Management.Automation.Language.CommandElementAst]$Element)

    if ($Element -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
        return $Element.Value
    }
    return $Element.Extent.Text.Trim('"', "'")
}

function Test-LiteralPathWildcard {
    param([System.Management.Automation.Language.CommandAst[]]$CommandAsts)

    foreach ($commandAst in $CommandAsts) {
        $elements = @($commandAst.CommandElements)
        for ($index = 0; $index -lt ($elements.Count - 1); $index++) {
            $current = Get-ElementText -Element $elements[$index]
            if ($current -ieq "-LiteralPath") {
                $next = Get-ElementText -Element $elements[$index + 1]
                if ($next -match '[*?\[]') {
                    return $true
                }
            }
        }
    }

    return $false
}

function Test-RgRawPathGlob {
    param([System.Management.Automation.Language.CommandAst[]]$CommandAsts)

    $optionsWithValues = @(
        "-e", "--regexp", "-f", "--file", "-g", "--glob", "-t", "--type",
        "-T", "--type-not", "-A", "--after-context", "-B", "--before-context",
        "-C", "--context", "--encoding", "--engine", "--max-count", "--max-depth",
        "--path-separator", "--replace", "--sort", "--sortr"
    )

    foreach ($commandAst in $CommandAsts) {
        $elements = @($commandAst.CommandElements)
        if ($elements.Count -lt 2) {
            continue
        }

        $commandName = [System.IO.Path]::GetFileNameWithoutExtension((Get-ElementText -Element $elements[0]))
        if ($commandName -ine "rg") {
            continue
        }

        $positionals = [System.Collections.Generic.List[string]]::new()
        $patternProvidedByOption = $false
        for ($index = 1; $index -lt $elements.Count; $index++) {
            $value = Get-ElementText -Element $elements[$index]
            if ($value -in @("-e", "--regexp", "-f", "--file")) {
                $patternProvidedByOption = $true
            }

            if ($value -in $optionsWithValues) {
                $index++
                continue
            }
            if ($value.StartsWith("-")) {
                continue
            }
            $positionals.Add($value)
        }

        $pathStart = if ($patternProvidedByOption) { 0 } else { 1 }
        for ($index = $pathStart; $index -lt $positionals.Count; $index++) {
            $candidate = $positionals[$index]
            $looksLikePath = $candidate -match '[\\/]' -or $candidate -match '^\.[\\/]' -or $candidate -match '\.[A-Za-z0-9]{1,8}$'
            if ($looksLikePath -and $candidate -match '[*?\[]') {
                return $true
            }
        }
    }

    return $false
}

function Test-BashHeredocOnWindows {
    param([string]$Command)

    if (-not $IsWindows) {
        return $false
    }

    return $Command -match '(?im)^\s*(?:python(?:\d+(?:\.\d+)?)?|node|pwsh|powershell)\b[^\r\n]*<<\s*["'']?[A-Za-z_][A-Za-z0-9_]*'
}

function Test-TUnitFilter {
    param(
        [string]$Command,
        [object]$Payload,
        [System.Management.Automation.Language.CommandAst[]]$CommandAsts
    )

    $hasFilter = $false
    $isDotnetTest = $false
    foreach ($commandAst in $CommandAsts) {
        $elements = @($commandAst.CommandElements | ForEach-Object { Get-ElementText -Element $_ })
        if ($elements.Count -lt 2) {
            continue
        }
        if (([System.IO.Path]::GetFileNameWithoutExtension($elements[0]) -ieq "dotnet") -and ($elements[1] -in @("test", "run"))) {
            $isDotnetTest = $true
            $hasFilter = @($elements | Where-Object { $_ -eq "--filter" -or $_ -like "--filter=*" }).Count -gt 0
        }
    }

    if (-not ($isDotnetTest -and $hasFilter)) {
        return $false
    }

    $cwd = Get-PropertyValue -Object $Payload -Names @("cwd", "working_directory", "workingDirectory")
    if ([string]::IsNullOrWhiteSpace([string]$cwd) -or -not (Test-Path -LiteralPath $cwd -PathType Container)) {
        return $false
    }

    try {
        $projectFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
        Get-ChildItem -LiteralPath $cwd -File -Filter "*.csproj" -ErrorAction Stop |
            Select-Object -First 16 |
            ForEach-Object { $projectFiles.Add($_) }
        Get-ChildItem -LiteralPath $cwd -Directory -ErrorAction Stop |
            Select-Object -First 16 |
            ForEach-Object {
                Get-ChildItem -LiteralPath $_.FullName -File -Filter "*.csproj" -ErrorAction SilentlyContinue |
                    Select-Object -First 2 |
                    ForEach-Object { $projectFiles.Add($_) }
            }

        foreach ($projectFile in @($projectFiles | Select-Object -First 32)) {
            $content = Get-Content -LiteralPath $projectFile.FullName -Raw -ErrorAction Stop
            if ($content -match '(?i)(?:PackageReference|ProjectReference)[^>]*(?:Include|Update)\s*=\s*["'']TUnit(?:\.|["''])') {
                return $true
            }
        }
    }
    catch {
        return $false
    }

    return $false
}

function Get-ResponseShape {
    param([object]$Payload)
    $response=Get-PropertyValue $Payload @('tool_response','toolResponse')
    if ($null -eq $response -or $response -is [string]) { return $null }
    $exit=Get-PropertyValue $response @('exit_code','exitCode')
    $timeout=Get-PropertyValue $response @('timed_out','timedOut')
    $errorFlag=Get-PropertyValue $response @('isError')
    $success=Get-PropertyValue $response @('success')
    $integer=$exit -is [int] -or $exit -is [long]
    $typedTimeout=$timeout -is [bool]
    $typedError=$errorFlag -is [bool]
    $typedSuccess=$success -is [bool]
    if(-not $integer -and -not $typedTimeout -and -not $typedError -and -not $typedSuccess){return $null}
    return [pscustomobject]@{
        ExitCode=$(if($integer){$exit}else{$null})
        TimedOut=($typedTimeout -and $timeout)
        IsError=($typedError -and $errorFlag)
        ExplicitFailure=(($typedError -and $errorFlag) -or ($typedSuccess -and -not $success))
        HasEmptyStdErr=($null -ne $response.PSObject.Properties['stderr'] -and $response.stderr -is [string] -and $response.stderr.Length -eq 0)
        StdErr=[string](Get-PropertyValue $response @('stderr','error','error_message','errorMessage'))
        Summary=[string](Get-PropertyValue $response @('summary','message','status'))
    }
}

function Get-PostClassification {
    param(
        [object]$Payload,
        [string]$ToolName,
        [string]$Command
    )

    $shape = Get-ResponseShape -Payload $Payload
    if ($null -eq $shape) {
        return [pscustomobject]@{ Category = "unclassified"; Outcome = "unknown-shape"; Context = $null }
    }

    $signal = ($shape.StdErr + "`n" + $shape.Summary).Trim()
    if ($shape.TimedOut) {
        return [pscustomobject]@{
            Category = "timeout"
            Outcome = "environment-blocker"
            Context = "The tool timed out. Do not repeat the identical invocation; inspect progress or logs and form a new bounded hypothesis."
        }
    }

    $confirmedFailure = $shape.ExplicitFailure -or ($null -ne $shape.ExitCode -and $shape.ExitCode -ne 0)
    if ($confirmedFailure -and $signal -match '(?i)(index\.lock|being used by another process|another git process|cannot access.+used by another process|permission denied|access.+denied|unauthori[sz]ed|authentication|\b401\b|\b403\b|NU1301|unable to load the service index|SSL|certificate)') {
        return [pscustomobject]@{
            Category = if ($signal -match '(?i)(index\.lock|being used by another process|another git process|cannot access.+used by another process)') { "lock" } else { "auth-restore-permission" }
            Outcome = "environment-blocker"
            Context = "This result is an environment, authentication, permission, restore, or lock blocker. Confirm the external state before changing product code or retrying."
        }
    }

    $commandName = Get-SingleDirectCommand -Command $Command

    if ((-not [string]::IsNullOrWhiteSpace($commandName)) -and $shape.ExitCode -eq 1 -and $shape.HasEmptyStdErr -and -not $shape.ExplicitFailure) {
        return [pscustomobject]@{
            Category = "rg-no-match"
            Outcome = "expected-no-match"
            Context = "ripgrep exit code 1 without stderr means expected no-match, not a tool failure. Narrow or broaden the query only if the missing match changes the hypothesis."
        }
    }

    if (($ToolName -ieq "apply_patch") -and $confirmedFailure -and $signal -match '(?i)(invalid context|context.+not found|patch.+failed|does not apply)') {
        return [pscustomobject]@{
            Category = "stale-patch"
            Outcome = "real-failure"
            Context = "The patch context is stale. Re-read the exact current section, confirm file ownership, and retry with a smaller updated hunk rather than repeating the patch."
        }
    }

    if ($null -eq $shape.ExitCode -and -not $shape.ExplicitFailure) {
        return [pscustomobject]@{ Category = "unclassified"; Outcome = "unknown-shape"; Context = $null }
    }

    if ($confirmedFailure) {
        return [pscustomobject]@{
            Category = "tool-failure"
            Outcome = "real-failure"
            Context = $null
        }
    }

    return [pscustomobject]@{ Category = "success"; Outcome = "success"; Context = $null }
}

function New-HookOutput {
    param(
        [string]$EventName,
        [string]$AdditionalContext,
        [string]$SystemMessage
    )

    if ([string]::IsNullOrWhiteSpace($AdditionalContext) -and [string]::IsNullOrWhiteSpace($SystemMessage)) {
        return [ordered]@{}
    }

    $output = [ordered]@{}
    if (-not [string]::IsNullOrWhiteSpace($AdditionalContext)) {
        $output.hookSpecificOutput = [ordered]@{
            hookEventName = $EventName
            additionalContext = $AdditionalContext
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($SystemMessage)) {
        $output.systemMessage = $SystemMessage
    }
    return $output
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$eventName = "unknown"
$category = "unclassified"
$outcome = "no-warning"
$warning = $false
$telemetryContext = $null

try {
    $rawInput = if (-not [string]::IsNullOrWhiteSpace($InputPath)) {
        Get-Content -LiteralPath $InputPath -Raw
    }
    else {
        [Console]::In.ReadToEnd()
    }

    if ([string]::IsNullOrWhiteSpace($rawInput)) {
        throw "Hook input is empty."
    }

    $payload = $rawInput | ConvertFrom-Json -Depth 50
    $telemetryContext = Get-TelemetryContext -Payload $payload
    $eventName = [string](Get-PropertyValue -Object $payload -Names @("hook_event_name", "hookEventName", "event"))
    $toolName = [string](Get-PropertyValue -Object $payload -Names @("tool_name", "toolName"))
    $command = Get-CommandText -Payload $payload
    $additionalContext = $null
    $systemMessage = $null

    if ($eventName -eq "PreToolUse") {
        $commandAsts = if ([string]::IsNullOrWhiteSpace($command)) { @() } else { Get-CommandAsts -Command $command }
        $activationMarker = if ($null -eq $telemetryContext) { $null } else { "CODEX_AGENT_OPERATIONS_PROBE_$($telemetryContext.ActivationChallenge)" }
        if (-not [string]::IsNullOrWhiteSpace($activationMarker) -and
            $command -match ("(?<![A-Za-z0-9_]){0}(?![A-Za-z0-9_])" -f [regex]::Escape($activationMarker))) {
            $category = "activation-probe"
            $telemetryContext.SessionHash = $telemetryContext.ActivationHash
        }
        elseif ((-not [string]::IsNullOrWhiteSpace($command)) -and (Test-BashHeredocOnWindows -Command $command)) {
            $category = "bash-heredoc"
            $additionalContext = "This is a Bash heredoc shape in a Windows PowerShell task. Use a PowerShell here-string or a checked temporary input file."
        }
        elseif (Test-LiteralPathWildcard -CommandAsts $commandAsts) {
            $category = "literal-path-wildcard"
            $additionalContext = "A wildcard was passed to -LiteralPath. Inventory the path first, then use -Path/-Filter intentionally or pass the exact literal path."
        }
        elseif (Test-RgRawPathGlob -CommandAsts $commandAsts) {
            $category = "rg-path-glob"
            $additionalContext = "A Windows wildcard appears in a positional ripgrep path. Use a literal scope plus -g for glob filtering."
        }
        elseif ((-not [string]::IsNullOrWhiteSpace($command)) -and (Test-TUnitFilter -Command $command -Payload $payload -CommandAsts $commandAsts)) {
            $category = "tunit-filter"
            $additionalContext = "TUnit evidence is present, so VSTest --filter is unsafe here. Use the repository's TUnit command with --treenode-filter."
        }

        if (-not [string]::IsNullOrWhiteSpace($additionalContext)) {
            $warning = $true
            $outcome = "warn-only"
            $systemMessage = "Known operational hazard detected; the tool call remains allowed."
        }
    }
    elseif ($eventName -eq "PostToolUse") {
        $classification = Get-PostClassification -Payload $payload -ToolName $toolName -Command $command
        $category = $classification.Category
        $outcome = $classification.Outcome
        $additionalContext = $classification.Context
        $warning = -not [string]::IsNullOrWhiteSpace($additionalContext)
    }

    if ($warning -and (Test-AndRecordDuplicateWarning -Root $TelemetryRoot -Context $telemetryContext -Payload $payload -EventName $eventName -Category $category)) {
        $additionalContext = $null
        $systemMessage = $null
        $warning = $false
        $outcome = "duplicate-suppressed"
    }

    $stopwatch.Stop()
    Write-TelemetryEvent -Root $TelemetryRoot -Context $telemetryContext -EventName $eventName -Category $category `
        -Severity $(if ($warning) { "warning" } else { "info" }) `
        -Action $(if ($warning) { "warn" } else { "observe" }) `
        -ExitClass (Get-ExitClass -Category $category -Outcome $outcome)
    New-HookOutput -EventName $eventName -AdditionalContext $additionalContext -SystemMessage $systemMessage |
        ConvertTo-Json -Depth 10 -Compress
}
catch {
    $stopwatch.Stop()
    if ($null -eq $telemetryContext) {
        $telemetryContext = Get-TelemetryContext -Payload $null
    }
    Write-TelemetryEvent -Root $TelemetryRoot -Context $telemetryContext -EventName $eventName -Category "hook-error" `
        -Severity "warning" -Action "observe" -ExitClass "fail-open"
    New-HookOutput -EventName $eventName -AdditionalContext $null -SystemMessage "Operational hook check was skipped; the tool call remains allowed." |
        ConvertTo-Json -Depth 5 -Compress
}
