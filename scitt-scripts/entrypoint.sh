#!/bin/bash -l

# echo "content-type:            " ${1}
# echo "datatrails-client_id:    " ${2}
# echo "datatrails-secret:       " ${3}
# echo "issuer:                  " ${4}
# echo "subject:                 " ${5}
# echo "payload-file:            " ${6}
# echo "payload-location:        " ${7}
# echo "receipt-file:            " ${8}
# echo "signed-statement-file:   " ${9}
# echo "signing-key-file:        " ${10}
# echo "skip-receipt:            " ${11}

CONTENT_TYPE=${1}
DATATRAILS_CLIENT_ID=${2}
DATATRAILS_SECRET_ID=${3}
ISSUER=${4}
SUBJECT=${5}
PAYLOAD_FILE=${6}
PAYLOAD_LOCATION=${7}
RECEIPT_FILE=${8}
SIGNED_STATEMENT_FILE=${9}
SIGNING_KEY_FILE=${10}
SKIP_RECEIPT=${11}

TOKEN_FILE="./bearer-token.txt"

if [ ! -f $PAYLOAD_FILE ]; then
  echo "ERROR: Payload File: [$PAYLOAD_FILE] Not found!"
  return 404
fi

# echo "Create an access token"
/scripts/create-token.sh ${DATATRAILS_CLIENT_ID} ${DATATRAILS_SECRET_ID} $TOKEN_FILE

if [ ! -f $TOKEN_FILE ]; then
  echo "ERROR: Token File: [$TOKEN_FILE] Not found!"
  return 404
fi

echo "Sign a SCITT Statement with key protected in DigiCert Software Trust Manager"

python /scripts/create_signed_statement.py \
  --subject $SUBJECT \
  --payload-file $PAYLOAD_FILE \
  --content-type $CONTENT_TYPE \
  --payload-location $PAYLOAD_LOCATION \
  --output-file $SIGNED_STATEMENT_FILE

if [ ! -f $SIGNED_STATEMENT_FILE ]; then
  echo "ERROR: Signed Statement: [$SIGNED_STATEMENT_FILE] Not found!"
  return 404
fi

echo "Register the SCITT SIgned Statement to https://app.datatrails.ai/archivist/v1/publicscitt/entries"

curl -X POST -H @$TOKEN_FILE \
                --data-binary @$SIGNED_STATEMENT_FILE \
                https://app.datatrails.ai/archivist/v1/publicscitt/entries

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
