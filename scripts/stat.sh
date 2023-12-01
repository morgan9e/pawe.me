#!/bin/bash
echo "<h3><bold>$(date +%Y%m%d)</bold></h3><h4><bold>Log</bold></h4>"> /srv/mirror/pub/stat/stat.html
echo "<pre>$(/srv/mirror/scripts/ngparse html /var/log/nginx/mirror/access.log)</pre>" >> /srv/mirror/pub/stat/stat.html
echo "<h4><bold>Traffic</bold></h4>" >> /srv/mirror/pub/stat/stat.html
echo "<pre>$(vnstat -i enp1s0 --days 10 | sed 's/    //' | tail -n +4)</pre>" >> /srv/mirror/pub/stat/stat.html

for i in /var/log/nginx/mirror/access.log-*; 
do
  DATE=${i#*-}
  echo $DATE
  if [ ! -f /srv/mirror/pub/stat/$DATE.html ];
  then
	  echo $DATE.html;
	  echo "<date>$DATE</date>" > /srv/mirror/pub/stat/$DATE.html;
	  echo "<pre>$(/srv/mirror/scripts/ngparse html $i)</pre>" >> /srv/mirror/pub/stat/$DATE.html
	  echo "<br/><br/>" >>  /srv/mirror/pub/stat/$DATE.html
  fi
done