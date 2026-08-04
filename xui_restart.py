import time
import datetime
import os
import psutil    # --> (sudo apt-get install python3-psutil) or (pip install psutil)
from pytz import timezone    # --> (sudo apt-get install python3-pytz) or (pip install pytz)


mem_thr = 93
cpu_thr = 98.9


dir_path = os.path.dirname(os.path.realpath(__file__))
file_path = os.path.join(dir_path, 'restart_log.txt')

t1 = datetime.datetime.now(timezone('Asia/Tehran'))


psutil.cpu_percent(interval=None)

print("start monitoring cpu & ram ...")


while(True):
    p_cpu = psutil.cpu_percent(interval=20) # block 20 sec and average cpu over that time
    p_mem = psutil.virtual_memory().percent

    # print(p_cpu)
    # print(p_mem)
    # print("-------")

    
    if( (p_mem > mem_thr) or (p_cpu > cpu_thr) ):
        with open(file_path, 'a') as f:
            t2 = datetime.datetime.now(timezone('Asia/Tehran'))
            if( p_mem > mem_thr):
                print("RAM : "+ f"{p_mem:<5.1f}" + "    time: " + t2.strftime("%Y-%m-%d %H:%M:%S") + "    delta: " + str(t2-t1) , file=f)
            else:
                print("cpu : "+ f"{p_cpu:<5.1f}" + "    time: " + t2.strftime("%Y-%m-%d %H:%M:%S") + "    delta: " + str(t2-t1) , file=f)
            t1 = t2
        os.system("pkill -f xray-linux")

    
        


