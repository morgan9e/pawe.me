import os, sys, re
import datetime
from pprint import pprint

base_path = sys.argv[1]
assert os.path.exists(base_path)

log_path = os.path.join(base_path, "logs/all.log")
assert os.path.exists(log_path)

html_path = os.path.join(base_path, "scripts/base.html")
index = os.path.join(base_path, "index.html")
assert os.path.exists(html_path)

with open(log_path, 'r') as f:
    log_file = f.read().splitlines()
log_file.reverse()

with open(html_path, 'r') as f:
    html_file = f.read()
dists = re.findall("@@([^@@]+)@@", html_file)
pprint(dists)

logs = {}
for dist in dists:
    logs[dist] = []

for logline in log_file:
    print(logline)
    time, stat, dist = logline.split(" ")
    if stat == "DONE":
    	time = datetime.datetime.strptime(time, '%Y%m%d_%H%M')
    	if dist in logs.keys():
    		logs[dist].append(time)

last = {}
for dist in logs:
    if logs[dist]:
    	last[dist] = sorted(logs[dist])[-1].strftime("%Y-%m-%d %H:%M") 
    else:
    	last[dist] = "Not Synced"
pprint(last)

for dist in last:
    html_file = html_file.replace(f"@@{dist}@@", last[dist])

with open(index, 'w') as f:
    f.write(html_file)
