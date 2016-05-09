#!/bin/sh

CONFIG=$1

if [ ! -f "$CONFIG" ];then
    echo "ERROR, CONFIG NOT EXIST."
    exit 1
fi 

. $CONFIG

if [ -f "$LAST_IP_FILE" ];then
    . $LAST_IP_FILE
fi

IP=$(curl -sL http://1212.ip138.com/ic.asp | grep -Eo '\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b')

if [ "$IP" = "$LAST_IP" ];then
    echo "$(date) -- Already updated."
    exit 0
fi

URL_D="https://www.cloudxns.net/api2/domain"
DATE=$(date)
HMAC_D=$(echo -n "$API_KEY$URL_D$DATE$SECRET_KEY"|md5sum|cut -d" " -f1)
DOMAIN_ID=$(curl -k -s $URL_D -H "API-KEY: $API_KEY" -H "API-REQUEST-DATE: $DATE" -H "API-HMAC: $HMAC_D"|grep -o "id\":\"[0-9]*\",\"domain\":\"$DOMAIN\.\""|grep -o "[0-9]*"|head -n1)

echo "DOMAIN ID: "$DOMAIN_ID

URL_R="https://www.cloudxns.net/api2/record/$DOMAIN_ID?host_id=0&row_num=500"


NUM_HOSTS=$((`echo $HOST | tr -cd ',' | wc -c`+1))
for i in `seq $NUM_HOSTS`; do
	ONEHOST=`echo $HOST | cut -d ',' -f$i`
	
	HMAC_R=$(echo -n "$API_KEY$URL_R$DATE$SECRET_KEY"|md5sum|cut -d" " -f1)

	RECORD_ID=$(curl -k -s $URL_R -H "API-KEY: $API_KEY" -H "API-REQUEST-DATE: $DATE" -H "API-HMAC: $HMAC_R"|grep -o "record_id\":\"[0-9]*\",\"host_id\":\"[0-9]*\",\"host\":\"$ONEHOST\""|grep -o "record_id\":\"[0-9]*"|grep -o "[0-9]*")

	echo "RECORD ID: "$RECORD_ID

	URL_U="https://www.cloudxns.net/api2/record/$RECORD_ID"

	PARAM_BODY="{\"domain_id\":\"$DOMAIN_ID\",\"host\":\"$ONEHOST\",\"value\":\"$IP\"}"
	HMAC_U=$(echo -n "$API_KEY$URL_U$PARAM_BODY$DATE$SECRET_KEY"|md5sum|cut -d" " -f1)

	RESULT=$(curl -k -s $URL_U -X PUT -d $PARAM_BODY -H "API-KEY: $API_KEY" -H "API-REQUEST-DATE: $DATE" -H "API-HMAC: $HMAC_U" -H 'Content-Type: application/json')

	echo $RESULT

	if [ $(echo -n "$RESULT"|grep -o "message\":\"success\""|wc -l) = 1 ];then
		echo "$(date) -- Update success"
		echo "LAST_IP=\"$IP\"" > $LAST_IP_FILE
	else
		echo "$(date) -- Update failed"
	fi
done
