### what is xui_restart
a python script, check VPS ram every 20 sec,<br>
if ram above 90% , kill xray to free up memory.<br>
then x-ui panel should start xray within 2 sec.<br>
so user feel almost nothing.<br>

### recommended for Low-RAM VPS
when a vps lack of sufficient RAM due to heavy traffic and lots of users,<br>
it swap to disk and become much slow or crash<br>
so it get down for several minutes until it recover.<br>
this script avoid this by restarting xray<br>
free up memory before swaping/crash happen.<br>

### easy install (recommended) — Ubuntu/Debian VPS
one line. it checks/installs python + requirements, then runs as a **systemd service that starts on boot**:<br>

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/GFW-knocker/xui_restart/main/install.sh)
```
(if you are not root, prefix with <code>sudo</code>)<br>

then manage everything with a single command:<br>

```bash
xui-restart
```
it shows the current running status, the last 10 restart-log lines, and a menu:<br>

```
  1) Start                4) Update (GitHub)
  2) Stop                 5) View service log
  3) Restart              6) Uninstall
  0) Exit
```
you can also call actions directly, e.g. <code>xui-restart status</code>, <code>xui-restart restart</code>, <code>xui-restart update</code>, <code>xui-restart uninstall</code>.<br>

**Update** pulls the latest version from GitHub and restarts. **Uninstall** removes the service and all files.<br>

### manual run (alternative)
make sure to have python and pip installed, otherwise:<br>
<code>sudo apt install python3</code><br>
<code>sudo apt install pip</code><br>
install requirements:<br>
<code>pip install psutil</code><br>
<code>pip install pytz</code><br>
run the script:<br>
<code>nohup python3 xui_restart.py >> xui_restart_log.txt &</code><br>
or you can execute <code>./start_xui_restart.sh</code> for convenience<br>

### how to stop (manual run)
<code>pkill -f xui_restart</code><br>
or you can execute <code>./stop_xui_restart.sh</code> for convenience<br>
(if you used the installer, use <code>xui-restart stop</code> instead)<br>

### how to verify its running
installer/service: <code>xui-restart status</code> or <code>systemctl status xui-restart</code><br>
manual run: <code>htop</code> and look for process "python xui_restart"<br>
in both cases the script logs restart events over time to <code>restart_log.txt</code><br>


 
