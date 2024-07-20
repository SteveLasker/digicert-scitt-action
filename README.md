# GitHub Action for creating and registering SCITT statements with Software Trust Manager and DataTrails

This GitHub Action provides the ability to create and sign [SCITT](https://datatracker.ietf.org/wg/scitt/about/) statements using code signing keys protected by DigiCert [Software Trust Manager](https://www.digicert.com/software-trust-manager) and register these statements to a SCITT transparency service operated by [DataTrails](https://www.datatrails.ai/).

**NOTE:**:  
This SCITT GitHub Action is in Preview, pending adoption of the [SCITT Reference APIs (SCRAPI)](https://datatracker.ietf.org/doc/draft-ietf-scitt-scrapi/).
To use a production supported implementation, please contact [DataTrails](https://www.datatrails.ai/contactus/) for more info.

## Getting Started

1. Generate a keypair and corresponding end-entity certificate in [Software Trust Manager](https://www.digicert.com/software-trust-manager)
1. [Create an account](https://app.datatrails.ai/signup) at DataTrails and [create an access token](https://docs.datatrails.ai/developers/developer-patterns/getting-access-tokens-using-app-registrations/)
1. Configure a GitHub SCITT Action, with the following [Inputs](#action-inputs) and [Example](#example-usage)

## Action Inputs

### `content-type`

**Required** The payload content type (iana mediaType) to be registered on the SCITT Service (eg: application/spdx+json, application/vnd.cyclonedx+json, Scan Result, Attestation)

### `datatrails-client_id`

**Required** The `CLIENT_ID` used to access the DataTrails SCITT APIs

### `datatrails-secret`

**Required** The `SECRET` used to access the DataTrails SCITT APIs

### `payload-file`

**Required** The payload file to be registered on the SCITT Service (eg: SBOM, Scan Result, Attestation)

### `payload-location`

**Optional** Location the content of the payload may be stored.

### `receipt-file`

**Optional** The filename to save the cbor receipt
**Default** 'receipt.cbor'

### `signed-statement-file`

**Optional** A required file representing the signed SCITT Statement that will be registered with the SCITT Transparency Service.
The parameter is optional, as it provides a default file name.  
See [Signed Statement Issuance and Registration](https://datatracker.ietf.org/doc/html/draft-ietf-scitt-architecture#name-signed-statement-issuance-a)
**Default** 'signed-statement.cbor'

### `skip-receipt`

**Optional** To skip receipt retrieval, set to 1
**Default** '0'

### `subject`

**Required** Unique ID for the collection of statements about an artifact.
For more info, see `subject` in the [IETF SCITT Terminology](https://datatracker.ietf.org/doc/html/draft-ietf-scitt-architecture#name-terminology).

## Secrets

This action requires secrets containing credentials and keypair information be configured.
Specifically, the following secrets are required:

### DIGICERT_STM_CERTIFICATE_ID

ID of the certificate and keypair protected in Software Trust Manager

### DIGICERT_STM_API_KEY

The Software Trust Manager API key

### DIGICERT_STM_API_BASE_URI

The base URI of the Software Trust Manager API

### DIGICERT_STM_API_CLIENTAUTH_P12_B64

The base-64 encoded PKCS #12 file for client authentication to the Software Trust Manager API

### DIGICERT_STM_API_CLIENTAUTH_P12_PASSWORD

The password for the PKCS #12 file for client authentication to the Software Trust Manager API

## Example usage

The following example shows a minimal implementation.
Pre-requisites:

- A DigiCert [Software Trust Manager](https://www.digicert.com/software-trust-manager) or [Key Locker account](https://www.digicert.com/blog/announcing-certcentrals-new-keylocker)
- A [DataTrails Subscription](https://www.datatrails.ai/getting-started/)
- The following GitHub Action Secrets are required:
  - `secrets.DATATRAILS_CLIENT_ID` - See [Creating Access Tokens Using a Custom Integration](https://docs.datatrails.ai/developers/developer-patterns/getting-access-tokens-using-app-registrations/)
  - `secrets.DATATRAILS_SECRET` See above
  - `secrets.DIGICERT_STM_CERTIFICATE_ID`
  - `secrets.DIGICERT_STM_API_BASE_URI`
  - `secrets.DIGICERT_STM_API_CLIENTAUTH_P12_PASSWORD`
  - `secrets.DIGICERT_STM_API_CLIENTAUTH_P12_B64`
  - `secrets.DIGICERT_STM_API_KEY`

Sample github `digicert-datatrails-scitt-action.yml`

```yaml
name: Register a DigiCert Signed SCITT Statement on DataTrails

on:
  workflow_dispatch:
  # push:
  #   branches: [ "main" ]
env:
  DATATRAILS_CLIENT_ID: ${{ secrets.DATATRAILS_CLIENT_ID }}
  DATATRAILS_SECRET: ${{ secrets.DATATRAILS_SECRET }}
  DIGICERT_STM_CERTIFICATE_ID: ${{ secrets.DIGICERT_STM_CERTIFICATE_ID }}
  DIGICERT_STM_API_BASE_URI: ${{ secrets.DIGICERT_STM_API_BASE_URI }}
  DIGICERT_STM_API_CLIENTAUTH_P12_PASSWORD: ${{ secrets.DIGICERT_STM_API_CLIENTAUTH_P12_PASSWORD }}
  DIGICERT_STM_API_CLIENTAUTH_P12_B64: ${{ secrets.DIGICERT_STM_API_CLIENTAUTH_P12_B64 }}
  DIGICERT_STM_API_KEY: ${{ secrets.DIGICERT_STM_API_KEY }}
jobs:
  build-image-register-DataTrails-SCITT:
    runs-on: ubuntu-latest
    # Sets the permissions granted to the `GITHUB_TOKEN` for the actions in this job.
    permissions:
      contents: read
      packages: write
    steps:
      - name: Create buildOutput Directory
        run: |
          mkdir -p ./buildOutput/
      - name: Create Compliance Statement
        # A sample compliance file. Replace with an SBOM, in-toto statement, image for content authenticity, ...
        run: |
          echo '{"author": "fred", "title": "my biography", "reviews": "mixed"}' > ./buildOutput/attestation.json
      - name: Upload Attestation
        id: upload-attestation
        uses: actions/upload-artifact@v4
        with:
          name: attestation.json
          path: ./buildOutput/attestation.json
      - name: Sign & Register as a SCITT Signed Statement
         # Register the DigiCert Signed Statement with the DataTrails SCITT APIs
        id: register-compliance-scitt-signed-statement
        uses: digicert/scitt-action@v0.3
        with:
          content-type: "application/vnd.unknown.attestation+json"
          datatrails-client_id: ${{ env.DATATRAILS_CLIENT_ID }}
          datatrails-secret: ${{ env.DATATRAILS_SECRET }}
          payload-file: "./buildOutput/attestation.json"
          payload-location: ${{ steps.upload-attestation.outputs.artifact-url }}
          subject: "ghcr.io/${{ github.repository }}:${{ github.sha }}"
          skip-receipt: "0"
      - name: upload-signed-statement
        uses: actions/upload-artifact@v4
        with:
          name: signed-statement
          path: signed-statement.cbor
      - name: upload-receipt
        uses: actions/upload-artifact@v4
        with:
          name: receipt
          path: receipt.cbor
  ```
