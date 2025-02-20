## Config File Creation

You can export a printer config using the following command:

```
rundll32 printui.dll,PrintUIEntry /Ss /n "<Printer Name>" /a "config.dat"
```

E.g. 

```
rundll32 printui.dll,PrintUIEntry /Ss /n "Upstairs Printer" /a "config.dat"
```

This should be placed in the root of the main folder you're packaging the script in.
[Microsoft Learn Documentation](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/rundll32-printui)
