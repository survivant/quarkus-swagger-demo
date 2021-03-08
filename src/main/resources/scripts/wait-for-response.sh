#!/bin/bash

usage() {
  echo "Usage: $0 [-u url] [-k key(case non sensitive) to search in response] [-K key(case sensitive) to search in response] [-s sleep between retry]" 
  echo "Example : $0 -u http://localhost:8080/management/health -K UP" 1>&2; 
  exit 1; 
}

SLEEP=1

while getopts ":u:k:K:s:" option; do
    case "${option}" in
        u)
            URL=${OPTARG}
            ;;
        k)
            KEY=${OPTARG}
            ;;
		K)
            KEY=${OPTARG}
            CASE_SENSITIVE=true
            ;;
		s)
            SLEEP=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

# url and key are mandatory
if [ -z "${URL}" ] || [ -z "${KEY}" ]; then
    usage
fi

echo "URL = ${URL}"
echo "KEY = ${KEY}"
echo "SLEEP = ${SLEEP}"

while true ; do
	if [ ! -z "${CASE_SENSITIVE}" ]; then
		# calling URL with grep (case sensitive)
		curl -v --silent ${URL} 2>&1 | grep ${KEY} >> /dev/null
	else	
		# calling URL with grep (case non sensitive)
		curl -v --silent ${URL} 2>&1 | grep -i ${KEY} >> /dev/null
	fi

	STATUS=$?

	# if status is 0, the key is found so we can exit
	  if [ "$STATUS" -eq 0 ]; then
		# key found, can exit now
		exit 0
	  fi
	
	echo "Sleeping for [$SLEEP] seconds"
	sleep $SLEEP;

done

exit 0


