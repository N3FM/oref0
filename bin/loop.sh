#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

die() { echo "$@" ; exit 1; }

# only one process can talk to the pump at a time
ls /tmp/openaps.lock >/dev/null 2>/dev/null && die "OpenAPS already running: exiting" && exit

echo "No lockfile: continuing"
touch /tmp/openaps.lock
/home/pi/decocare/insert.sh 2>/dev/null >/dev/null

function finish {
    rm /tmp/openaps.lock
}
trap finish EXIT

cd /home/pi/openaps-dev
#git fetch --all && git reset --hard origin/master && git pull


echo "Querying CGM"
openaps report invoke glucose.json.new || openaps report invoke glucose.json.new 
grep glucose glucose.json.new && cp glucose.json.new glucose.json && git commit -m"glucose.json has glucose data: committing" glucose.json
git pull && git push
#grep glucose glucose.json || git reset --hard origin/master
find glucose.json -mmin 3 && grep glucose glucose.json || die "Can't read from CGM"
head -15 glucose.json

#find *.json -mmin 15 -exec mv {} {}.old \;

numprocs=$(fuser -n file $(python -m decocare.scan) 2>&1 | wc -l)
if [[ $numprocs -gt 0 ]] ; then
  die "Carelink USB already in use."
fi

echo "Checking pump status"
openaps status || openaps status || die "Can't get pump status"
grep status status.json.new && cp status.json.new status.json
git pull && git push
echo "Querying pump"
#openaps pumpquery || openaps pumpquery || die "Can't query pump" && git pull && git push
openaps pumpquery || openaps pumpquery
grep T clock.json.new && cp clock.json.new clock.json
grep temp currenttemp.json.new && cp currenttemp.json.new currenttemp.json
grep timestamp pumphistory.json.new && cp pumphistory.json.new pumphistory.json
git pull && git push

openaps suggest
grep sens profile.json.new && cp profile.json.new profile.json
grep iob iob.json.new && cp iob.json.new iob.json
grep temp requestedtemp.json.new && cp requestedtemp.json.new requestedtemp.json
git pull && git push

tail clock.json
tail currenttemp.json
head -20 pumphistory.json

echo "Querying pump settings"
openaps pumpsettings || openaps pumpsettings || die "Can't query pump settings" && git pull && git push

openaps suggest || die "Can't calculate IOB or basal" && git pull && git push
tail profile.json
tail iob.json
tail requestedtemp.json

grep rate requestedtemp.json && ( openaps enact || openaps enact ) && tail enactedtemp.json
#openaps report invoke enactedtemp.json

#if /usr/bin/curl -sk https://diyps.net/closedloop.txt | /bin/grep set; then
    #echo "No lockfile: continuing"
    #touch /tmp/carelink.lock
    #/usr/bin/curl -sk https://diyps.net/closedloop.txt | while read x rate y dur op; do cat <<EOF
        #{ "duration": $dur, "rate": $rate, "temp": "absolute" }
#EOF
    #done | tee requestedtemp.json

    #openaps report invoke enactedtemp.json
#fi
        

