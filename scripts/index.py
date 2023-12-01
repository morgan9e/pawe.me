#!/usr/bin/python

import os, sys, re
import datetime

base_path = sys.argv[1]
out_path = sys.argv[2]
assert os.path.exists(base_path)

log_path = os.path.join(base_path, "logs/all.log")
assert os.path.exists(log_path)

html_path = os.path.join(base_path, "scripts/base.html")
index = os.path.join(out_path, "index.html")
assert os.path.exists(html_path)

with open(log_path, 'r') as f:
    log_file = f.read().splitlines()
log_file.reverse()

with open(html_path, 'r') as f:
    html_file = f.read()
dists = re.findall("@@([^@@]+)@@", html_file)

print(dists)

logs = {}
for dist in dists:
    logs[dist] = []

for dist in logs:
    for logline in log_file:
        time, stat, disk = logline.split(" ")
        if stat == "DONE" and dist == disk:
            logs[dist] = datetime.datetime.strptime(time, '%Y%m%d_%H%M').strftime("%Y-%m-%d %H:%M")
            break
        logs[dist] = "Not Synced"

stats = {}
for dist in dists:
    for logline in log_file:
        time, stat, disk = logline.split(" ")
        if dist == disk:
            stats[dist] = stat, datetime.datetime.strptime(time, '%Y%m%d_%H%M').strftime("%Y-%m-%d %H:%M")
            break
        stats[dist] = (-1, "Not Synced")

print(logs)
print(stats)

for dist in dists:
    stat, tt = stats[dist]
    if stat == "ERROR":
        stat = f" (Error @ {tt})"
    elif stat == "STARTED":
        stat = f" (Running @ {tt})"
    else:
        stat = ""
    
    if stat:
        stat = f"</p><p class=\"text-gray-500 dark:text-gray-400\">{stat}</p>"
    html_file = html_file.replace(f"@@{dist}@@", f"{logs[dist]}{stat}")

with open(index, 'w') as f:
    f.write(html_file)

print("Written to index.html")
