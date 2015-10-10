# ServMan
-------------------------------------------------------------------
SERVMAN SERVER MANAGEMENT MOD V3.x
-------------------------------------------------------------------
1. Introduction
-------------------------------------------------------------------

Hello,
and thank you for downloading the ServMan Server Management Mod for DCS:A-10C Warthog
The aim of this mod is to improve the multiplayer experience. ServMan enables a chat based server management interface and gives both server hosts and regular players a few additional options that normally would be expected from a dedicated server, like:

- load and rotate missions automaticly or on demand.
- automatic kicking for teamkills (human and AI)
- automatic kicking for too low score
- automatic kicking for team-damaging other players
- automatic kicking for high average ping
- automatic banning after too many kicks
- reporting/logging of team collisions
- banning single IPs and whole IP ranges
- penalty time after kick
- extended event logging including a chatlog
- manual kicking, banning and mission loading
- message of the day and server rules
- (un-)locking the server
- appointing subadmins
- votekicks
- missionvotes/-polls

Happy Server administration.
- Panzertard out.



-------------------------------------------------------------------
2. Disclaimer
-------------------------------------------------------------------

This mod is not an official add-on supported by Eagle Dynamics/The Fighter Collection, it is a third party addition created and supported by us. You understand that DCS currently does not contain a dedicated server option, so installing this mod to use DCS as a "pseudo-dedicated" server may cause unforeseeable problems. You agree that you may only use this mod at your own risk, and that you cannot hold me liable for any issue or damage caused by its usage. You also understand that by using this mod you allow players a significant amount of control both over your server and the gameplay experience of other players, so use it with care!

The mod extends the original server.lua and events.lua files in the ./Scripts/Net/ folder. 
It does not overwrite any files except Main.lua, however it will take control over all the FUNCTIONS loaded from SERVER.LUA and EVENTS.LUA.
All rights regarding these file belong to Eagle Dynamics. The mod also uses parts of the LuaSocket and LuaFileSystem libraries that are free software, released under the MIT license.

-------------------------------------------------------------------
3. Changelog
-------------------------------------------------------------------
Please see separate file.

-------------------------------------------------------------------
4. Installation
-------------------------------------------------------------------

The mod requires DCS:A-10C Warthog 1.1.0.7 or higher.
You can only install the mod manually, currently there are no modman version available.
 
Installation: 
1. Download the ZIP/RAR archive.
2. Make a backup copy of the file ".\Scripts\net\main.lua", call it "orig1107_main.lua".
3. Unrar the download to a temp location
4. Drag "Scripts" folder into .\<your DCS install folder> replacing the content, answer YES to replace files and folders.

For further instructions, please see the "installation instructions" at: http://forums.eagle.ru/showthread.php?t=53732

-------------------------------------------------------------------
5. Uninstalling
-------------------------------------------------------------------
Disable:
1. Rename the "\Scripts\Addons\ServMan3" folder into something else, ex "\Scripts\Addons\ServMan3-DISABLED".
ServMan is now disabled, the original files in DCS will be for the server.

Uninstall:
1. Copy the original copy you made during install, and replace "main.lua"
You may also find a working copy of the original main.lua in ".\Scripts\Addons\ServMan3\Scripts-Net, Backup\main.lua"
2. Delete "\Scripts\Addons\ServMan3" if you wish, or just rename it.
ServMan is now removed.

-------------------------------------------------------------------
6. Setup and server configuration variables
-------------------------------------------------------------------

Please see post #2 - #7
http://forums.eagle.ru/showthread.php?t=53732

-------------------------------------------------------------------
7. Support and Bugreports
-------------------------------------------------------------------

NOTE: If you think that you have found a problem/bug that could possibly be exploited by players, please do not post this issue publicly in the below threads, instead send a private message to Panzertard.

I have created a thread at the official Eagle Dynamics forum where you can get support for the mod, report bugs/issues, provide constructive criticism and fearure requests (which might be implemented in a future revision):

ServMan 3.0 for DCS:A-10C Warthog:
http://forums.eagle.ru/showthread.php?t=73625
ServMan 2.5 for DCS:BS and FC2:
http://forums.eagle.ru/showthread.php?t=53732


-------------------------------------------------------------------
8. CREDITS
-------------------------------------------------------------------
+++++ BETA TESTING +++++

Many thanks to the following people/organisations for helping us beta testing the mod and/or providing valuable feedback/bug reports:
Tyger, LouckyBob9, PoleCat and EtherealN.

And everybody who played on the beta servers!


+++++ EAGLE DYNAMICS +++++

ServMan uses DCS networking API and extends the files of these engines. 
All rights regarding these files belong to Eagle Dynamics, Russia/The Fighter Collection, UK.

We would especially like to thank c0ff, Dmut, Ulrich, dsb, Chizh for their help and for adding suggested functionality to the API.


+++++ LUASOCKET +++++

Powered by Lua 5.1 with LuaSocket 2.0 library by the following notice:
Copyright © 1994-2008 Lua.org, PUC-Rio. 
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions: 
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 
http://www.lua.org


+++++ LUAFILESYSTEM +++++

This project uses LuaFileSystem
Copyright © 2003 Kepler Project.
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
http://www.keplerproject.org/luafilesystem/

