' GitLab Duo Proxy - Starts silently in background (no window)
Set FSO = CreateObject("Scripting.FileSystemObject")
ScriptDir = FSO.GetParentFolderName(WScript.ScriptFullName)
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "node """ & ScriptDir & "\server.js""", 0, False
