import time
import datetime
import os
import psutil    # --> pip install psutil
from pytz import timezone    # --> pip install pytz




dir_path = os.path.dirname(os.path.realpath(__file__))
file_path = os.path.join(dir_path, 'restart_log.txt')

t1 = datetime.datetime.now(timezone('Asia/Tehran'))

while(True):
    time.sleep(10)
    p_mem = psutil.virtual_memory().percent
    #print(p_mem)
    if(p_mem > 90):
        with open(file_path, 'a') as f:
            t2 = datetime.datetime.now(timezone('Asia/Tehran'))
            print(str(p_mem) + "    time: " + t2.strftime("%Y-%m-%d %H:%M:%S") + "    delta: " + str(t2-t1) , file=f)
            t1 = t2
        os.system("pkill -f xray-linux")

    
        


