### what is xui_restart
a python script, check VPS ram every 10 sec,<br>
if ram above 90% , kill xray to free up memory.<br>
then x-ui panel should start xray within 2 sec.<br>
so user feel almost nothing.<br>

### recommended for Low-RAM VPS
when a vps lack of sufficient RAM due to heavy traffic and lots of users,<br>
it swap to disk and become much slow or crash<br>
so it get down for several minutes until it recover.<br>
this script avoid this by restarting xray<br>
free up memory before swaping/crash happen.<br>

### how to run
make sure to have python and pip installed, otherwise:<br>
<code>sudo apt install python3</code><br>
<code>sudo apt install pip</code><br>
install requirements:<br>
<code>pip install psutil</code><br>
<code>pip install pytz</code><br>
run the script:<br>
<code>nohup python3 xui_restart.py >> xui_restart_log.txt &</code><br>
or you can execute <code>./start_xui_restart.sh</code> for convenience<br>

### how to stop
<code>pkill -f xui_restart</code><br>
or you can execute <code>./stop_xui_restart.sh</code> for convenience<br>

### how to verify its running
run <code>htop</code> command and look for process "python xui_restart"<br>
also the scrpit, log restart event along time in txt file<br>


 
