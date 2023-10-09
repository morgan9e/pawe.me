## PAWE.ME
Simple mirroring &amp; archiving server.

- This script is used to serve [pawe.me](https://pawe.me) mirroring server.

- config.yaml contains various config options, can add more repo/upstream with just adding to config. supports http, rsync, ftpsync(debian).

- ~~HTTP Mirroring uses custom python script using aiohttp, may change to wget recursive mirroring..~~ fixing script, currently just fetches in order.

- $BASE_DIR is where all data is stored. Need to change manually in script index.py
 
- index.py renders index.html file after each sync, order and half-size card can be configured in config.yml

- element DIVIDER in .index (from config) is used to divide card between "main" and "additional mirroring" in index.html
