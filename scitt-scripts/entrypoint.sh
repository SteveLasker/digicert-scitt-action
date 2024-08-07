#!/bin/bash -l

set -e

# echo "content-type:              " ${1}
# echo "datatrails-client_id:      " ${2}
# echo "datatrails-client_secret:  " ${3}
# echo "payload-file:              " ${4}
# echo "payload-location"          " ${5}
# echo "subject:                   " ${6}
# echo "transparent-statement-file:" ${7}

CONTENT_TYPE=${1}
export DATATRAILS_CLIENT_ID=${2}
export DATATRAILS_CLIENT_SECRET=${3}
PAYLOAD_FILE=${4}
PAYLOAD_LOCATION=${5}
SUBJECT=${6}
TRANSPARENT_STATEMENT_FILE=${7}

SIGNED_STATEMENT_FILE="signed-statement.cbor"

TOKEN_FILE="./bearer-token.txt"

if [ ! -f $PAYLOAD_FILE ]; then
  echo "ERROR: Payload File: [$PAYLOAD_FILE] Not found!"
  exit 126
fi

# echo "Create an access token"

/scripts/create-token.sh $DATATRAILS_CLIENT_ID \
  $DATATRAILS_CLIENT_SECRET \
  $TOKEN_FILE

if [ ! -f $TOKEN_FILE ]; then
  echo "ERROR: Token File: [$TOKEN_FILE] Not found!"
  exit 126
fi

echo "Sign a SCITT Statement with key protected in DigiCert Software Trust Manager"

python /scripts/create_signed_statement.py \

  --subject $SUBJECT \
  --payload-file $PAYLOAD_FILE \
  --content-type $CONTENT_TYPE \

  --output-file $SIGNED_STATEMENT_FILE

if [ ! -f $SIGNED_STATEMENT_FILE ]; then
  echo "ERROR: Signed Statement: [$SIGNED_STATEMENT_FILE] Not found!"
  exit 126
fi

echo "Register the SCITT Signed Statement to https://app.datatrails.ai/archivist/v1/publicscitt/entries"

python /scripts/register_signed_statement.py \
      --signed-statement-file $SIGNED_STATEMENT_FILE \
      --output-file $TRANSPARENT_STATEMENT_FILE \
      --log-level INFO

python /scripts/dump_cbor.py \
      --input $TRANSPARENT_STATEMENT_FILE

# curl https://app.datatrails.ai/archivist/v2/publicassets/-/events?event_attributes.feed_id=$SUBJECT | jq
