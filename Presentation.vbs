Set objShell = CreateObject("WScript.Shell")

' Ouvre un fichier avec l'application par défaut
fileToOpen = "Presentation1.pptx" ' Remplacez par le chemin de votre fichier
objShell.Run Chr(34) & fileToOpen & Chr(34)

' Chemin vers le script PowerShell
ps1Script = "autres\script.ps1"  ' Remplacez ce chemin par celui de votre fichier .ps1

' Exécuter le script PowerShell via cmd.exe
objShell.Run "powershell.exe -ExecutionPolicy Bypass -File """ & ps1Script & """", 0, False