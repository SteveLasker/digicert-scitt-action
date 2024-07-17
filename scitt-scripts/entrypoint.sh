#!/bin/bash -l

set -e

# echo "content-type:            " ${1}
# echo "datatrails-client_id:    " ${2}
# echo "datatrails-secret:       " ${3}
# echo "payload-file:            " ${4}
# echo "payload-location:        " ${5}
# echo "receipt-file:            " ${6}
# echo "signed-statement-file:   " ${7}
# echo "skip-receipt:            " ${8}
# echo "subject:                 " ${9}

CONTENT_TYPE=${1}
DATATRAILS_CLIENT_ID=${2}
DATATRAILS_SECRET_ID=${3}
PAYLOAD_FILE=${4}
PAYLOAD_LOCATION=${5}
RECEIPT_FILE=${6}
SIGNED_STATEMENT_FILE=${7}
SKIP_RECEIPT=${8}
SUBJECT=${9}

TOKEN_FILE="./bearer-token.txt"

if [ ! -f $PAYLOAD_FILE ]; then
  echo "ERROR: Payload File: [$PAYLOAD_FILE] Not found!"
  exit 126
fi

# echo "Create an access token"
/scripts/create-token.sh ${DATATRAILS_CLIENT_ID} ${DATATRAILS_SECRET_ID} $TOKEN_FILE

if [ ! -f $TOKEN_FILE ]; then
  echo "ERROR: Token File: [$TOKEN_FILE] Not found!"
  exit 126
fi

echo "Sign a SCITT Statement with key protected in DigiCert Software Trust Manager"

python /scripts/create_signed_statement.py \
  --content-type $CONTENT_TYPE \
  --payload-file $PAYLOAD_FILE \
  --payload-location $PAYLOAD_LOCATION \
  --subject $SUBJECT \
  --output-file $SIGNED_STATEMENT_FILE

if [ ! -f $SIGNED_STATEMENT_FILE ]; then
  echo "ERROR: Signed Statement: [$SIGNED_STATEMENT_FILE] Not found!"
  exit 126
fi

echo "Register the SCITT SIgned Statement to https://app.datatrails.ai/archivist/v1/publicscitt/entries"

RESPONSE=$(curl -X POST -H @$TOKEN_FILE \
                --data-binary @$SIGNED_STATEMENT_FILE \
                https://app.datatrails.ai/archivist/v1/publicscitt/entries)

echo "RESPONSE: $RESPONSE"

OPERATION_ID=$(echo $RESPONSE | jq  -r .operationID)
echo "OPERATION_ID: $OPERATION_ID"

echo "skip-receipt: $SKIP_RECEIPT"

if [ -n "$SKIP_RECEIPT" ] && [ $SKIP_RECEIPT = "1" ]; then
  echo "skipping receipt retrieval"
else
  echo "Download the SCITT Receipt: $RECEIPT_FILE"
  echo "call: /scripts/check_operation_status.py"
  python /scripts/check_operation_status.py --operation-id $OPERATION_ID --token-file-name $TOKEN_FILE

  ENTRY_ID=$(python /scripts/check_operation_status.py --operation-id $OPERATION_ID --token-file-name $TOKEN_FILE)
  echo "ENTRY_ID :" $ENTRY_ID
  curl -H @$TOKEN_FILE \
    https://app.datatrails.ai/archivist/v1/publicscitt/entries/$ENTRY_ID/receipt \
    -o $RECEIPT_FILE
fi

# curl https://app.datatrails.ai/archivist/v2/publicassets/-/events?event_attributes.subject=$SUBJECT | jq
