Fork of AlertMaster lua by Special Ed on Redguides.

https://www.redguides.com/community/threads/alert-master.77146/

2024-Jan-28 Grimmier.

This spawned from combining a side project I was working on to make an LUA tracking window with some features. 
I was able to get the GUI loading and refreshing, navTo working but hadn't tackled the backend for storing and retrieving the spawns I wanted to search for all the time. I thought about trying to tie the UI with SpawnMaster, then I found AlertMaster.  So mostly for personal use I integrated the UI into AlertMaster, Originally I made them work hand in hand, but wanted to combine them.

Alas we have this: 

** AlertMaster ** with a Search GUI, Alert PopUp's and NavTo abilities for any mob in zone.

** NEW Commands **

* /am show will toggle the search window.
* /am popup will toggle the alert popup window.
* /am beep will toggle on and off beep notifications
* /am doalert will toggle wether we want to see popup alert windows. default is false

** NEW Settings **

* beep=true|false default is false. turns on or off beep notifications for NPC spawns.
* popup=true|false default is false. turns on or off popup alert notifications for NPC spawns. You can still /am popup to display the window if you have popup alerts turned off.

** Search Window **

* You can search with the search box
* Sort by columns (Shift-Clicking Columns will MultiSort based onthe order you click.)
* Clicking the check box for track, and the spawn will be added to spawnlist
* Clicking ignore will remove the spawn from the list if it exists.
* You can NavTo any spawn in the search window by clicking the button,
* Right-Clicking the name will target the spawn.
* Columns can be toggled on and off as well as re-arranged in the table.

** Alert PopUp Window **

* The Alert Popup Window lists the spawns that you are tracking and are alive. Shown as "Name : Distance"
* Clicking the button on the Alert Window will NavTo the spawn.
* Closing the Alert Popup will keep it closed until something changes or your remind timer is up.
* If you have remind set in your ini or via /am remind #seconds:
* The alert window will re-popup if there is something on it after that many seconds since last appearance.


![alt text](https://github.com/grimmier378/AlertMaster/blob/info/searchGui.png)

![alt text](https://github.com/grimmier378/AlertMaster/blob/info/alertGui.png)
