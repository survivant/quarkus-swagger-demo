#!/bin/bash

usage() {
  echo "Usage: $0 [-h iep-codec host] [-p iep-codec port] [-c probe url] [-w wait for it service:port (could have multiple -w)]"
  echo "Example : $0 -h iep-codec -p 8181 -c http://localhost:8080/management/health -w twin-api-service:8080 -w kubernetes-api:8080" 1>&2; 
  exit 1; 
}

while getopts ":h:p:w:c:" option; do
    case "${option}" in
        h)
            iep_codec_host=${OPTARG}
            ;;
        p)
            iep_codec_port=${OPTARG}
            ;;
        w)
            services+=(${OPTARG})
            ;;
        c)
            health_url=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# iep host and port are mandatory
if [ -z "${iep_codec_host}" ] || [ -z "${iep_codec_port}" ] || [ -z "${health_url}" ]; then
    usage
fi

echo "IEP Codec Host = ${iep_codec_host}"
echo "IEP Codec Port = ${iep_codec_port}"
echo "Health url     = ${health_url}"

if [ "${services}" ]; then
  # generating wait-for-it command
  for val in "${services[@]}"; do
    echo "wait for it - $val"
    wait_for_it+="./wait-for-it.sh $val -t 1 -s -- "
  done
fi

# calling wait-for-it for timeouts
if [ ! -z "${wait_for_it}" ]; then
  echo "wait for it command : $wait_for_it"
  ${wait_for_it}

  STATUS=$?

  # if there are no timeout, the status will be 0, if there are timeouts try to update HEALTH STATUS in IEP if IEP is available
  if [ "$STATUS" -ne 0 ]; then
    echo "GOT TIMEOUT !"
    # check if iep-codec is UP, if not don't send health update
	  ./wait-for-it.sh $iep_codec_host:$iep_codec_port -t 1 -s -- curl -s -m 1 -H "Content-Type:text/plain" --data-binary "$(cat /etc/podinfo/labels > readinessProbe; echo PROBE=READINESS_PROBE; echo PROBE_STATUS=FAILED; cat readinessProbe)" -X POST http://$iep_codec_host:$iep_codec_port/health/probe/alerts
    exit 1
  fi
fi  

# try to get Health STATUS
STATUS=$(curl -s -m 1 -o /dev/null -w '%{http_code}' ${health_url})

# must be >=200 and <400
if [ "$STATUS" -ge 200 ] && [ "$STATUS" -lt 400 ]; then
  echo "Got 200! All done!"
  # create readiness status file for liveness probe
	touch /READINESS_PROBE_OK
  # check if iep-codec is UP, if not don't send health update
	./wait-for-it.sh $iep_codec_host:$iep_codec_port -t 1 -s -- curl -s -m 1 -H "Content-Type:text/plain" --data-binary "$(cat /etc/podinfo/labels > readinessProbe; echo PROBE=READINESS_PROBE; echo PROBE_STATUS=OK; cat readinessProbe)" -X POST http://$iep_codec_host:$iep_codec_port/health/probe/alerts
  exit 0
else
  echo "Got $STATUS : PROBE IN ERROR !"
  # check if iep-codec is UP, if not don't send health update
	./wait-for-it.sh $iep_codec_host:$iep_codec_port -t 1 -s -- curl -s -m 1 -H "Content-Type:text/plain" --data-binary "$(cat /etc/podinfo/labels > readinessProbe; echo PROBE=READINESS_PROBE; echo PROBE_STATUS=FAILED; cat readinessProbe)" -X POST http://$iep_codec_host:$iep_codec_port/health/probe/alerts
  exit 1
fi