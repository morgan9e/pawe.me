#!/usr/bin/python3

import os, sys
import yaml
import jinja2
import datetime

BASE_DIR = "."
CONFIG_PATH = os.path.join(BASE_DIR, "scripts/config.yml")
TEMPLATES_DIR = os.path.join(BASE_DIR, "scripts/templates")
LOG_DIR = os.path.join(BASE_DIR, "logs")
SYNC_LOG = os.path.join(LOG_DIR, "sync.log")
OUTPUT_PATH = os.path.join(BASE_DIR, "index.html")

def get_last_sync(repo_name):
    if os.path.exists(SYNC_LOG):
        with open(SYNC_LOG, 'r') as log_file:
            log_all = reversed(log_file.readlines())
            for logline in log_all:
                dist, time, stat = logline.split()
                if repo_name == dist and stat =="SUCCESS":
                    return datetime.datetime.strptime(time, '%Y-%m-%dT%H:%MZ').strftime("%Y-%m-%d %H:%M")
    return "Not Synced"

# main()

if __name__=="__main__":
    with open(CONFIG_PATH, 'r') as f:
        config = yaml.safe_load(f)

    env = jinja2.Environment(loader=jinja2.FileSystemLoader(TEMPLATES_DIR))
    base_template = env.get_template('base.html')
    full_template = env.get_template('full.html')
    half_template = env.get_template('half.html')

    main_repos = []
    additional_repos = []

    DIV = 0
    for line in config['index']:
        if line == "DIVIDER":
            DIV = 1
            continue
        repos_line = line.split()
        for repo_name in repos_line:
            repo_data = config['repos'].get(repo_name)
            if not repo_data:
                continue

            context = {
                'path': repo_data['path'],
                'name': repo_data['name'],
                'lastsync': get_last_sync(repo_name),
                # 'lastsync': repo_data.get('lastsync', "Not Synced"),
                'upstream': repo_data['url']
            }
            print(context)
            if len(repos_line) > 1:
                (main_repos if not DIV else additional_repos).append(half_template.render(**context))
            else:
                (main_repos if not DIV else additional_repos).append(full_template.render(**context))

    html_output = base_template.render(
        repos="\n".join(main_repos),
        repos_more="\n".join(additional_repos)
    )

    try:
        with open(OUTPUT_PATH, 'w') as f:
            f.write(html_output)

    except:
        if len(sys.argv) == 2:
            if os.path.exists(sys.argv[1]):
                if not os.path.isdir(sys.argv[1]):
                    print(f"Writing to {sys.argv[1]}")
                    with open(sys.argv[1], 'w') as f:
                        f.write(html_output)
        else:
            print(html_output)
