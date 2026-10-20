' AIRA SMTP Bridge Background Runner
' Starts the Python SMTP Bridge daemon silently in the background on port 8088.
Set objShell = CreateObject("WScript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")
strScriptDir = objFSO.GetParentFolderName(WScript.ScriptFullName)
strPyScript = chr(34) & strScriptDir & "\smtp_bridge.py" & chr(34)

' Launch pythonw silently (0 = hide window, false = do not wait)
objShell.Run "pythonw -u " & strPyScript, 0, False
