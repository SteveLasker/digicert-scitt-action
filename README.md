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

**Required** The payload content type (iana mediaType) to be registered on the SCITT Service (eg: `application/spdx+json`, `application/vnd.cyclonedx+json`, Scan Result, Attestation)

### `payload-file`

**Required** The payload file to be registered on the SCITT Service (eg: SBOM, Scan Result, Attestation)

### `payload-location`

**Optional** Location the content of the payload may be stored. (eg: `https://storage.example/abc123`)

### `subject`

**Required** Unique ID for the collection of statements about an artifact. (eg: `ghcr.io/synsation-corp/synsation-web:sha-9233f0b`)
For more info, see `subject` in the [IETF SCITT Terminology](https://datatracker.ietf.org/doc/html/draft-ietf-scitt-architecture#name-terminology).

### `transparent-statement-file`

**Optional** The filename to save the transparent statement, which includes the signed-statement and the receipt
**Default** `transparent-statement.cbor`

## Secrets

This action requires secrets containing credentials and keypair information be configured.
Specifically, the following secrets are required:

### `DATATRAILS_CLIENT_ID`

The `CLIENT_ID` used to access the DataTrails SCITT APIs

### `DATATRAILS_CLIENT_SECRET`

**Required** The `SECRET` used to access the DataTrails SCITT APIs

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
  - `secrets.DATATRAILS_CLIENT_SECRET` See above
  - `secrets.DIGICERT_STM_CERTIFICATE_ID`
  - `secrets.DIGICERT_STM_API_BASE_URI`
  - `secrets.DIGICERT_STM_API_CLIENTAUTH_P12_PASSWORD`
  - `secrets.DIGICERT_STM_API_CLIENTAUTH_P12_B64`
  - `secrets.DIGICERT_STM_API_KEY`

### Basic Sample

A basic sample that constructs an agnostic attestation, signing with DigiCert Software Trust Manager, uploading to the DataTrails SCITT Transparency Service

`digicert-datatrails-scitt-action.yml`

```yaml
name: Register a DigiCert Signed SCITT Statement on DataTrails

on:
  workflow_dispatch:
  # push:
  #   branches: [ "main" ]
env:
  DATATRAILS_CLIENT_ID: ${{ secrets.DATATRAILS_CLIENT_ID }}
  DATATRAILS_CLIENT_SECRET: ${{ secrets.DATATRAILS_CLIENT_SECRET }}
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
      - name: SMCTL Sign & Register as a SCITT Signed Statement
         # Register the DigiCert Signed Statement with the DataTrails SCITT APIs
        id: register-compliance-scitt-signed-statement
        uses: digicert/scitt-action@v0.4
        with:
          content-type: "application/vnd.unknown.attestation+json"
          payload-file: "./buildOutput/attestation.json"
          payload-location: ${{ steps.upload-attestation.outputs.artifact-url }}
          subject: ${{ github.server_url }}/${{ github.repository }}@${{ github.sha }}
      - name: upload-transparent-statement
        uses: actions/upload-artifact@v4
        with:
          name: transparent-statement
          path: transparent-statement.cbor
  ```

### Docker Image Sample

A sample that does a Docker Build, SCOUT Scan, generates CycloneDX and SPDX SBOMs, signing with DigiCert Software Trust Manager, and registers the signed statements on the DataTrails SCITT Transparency Service.

`docker-digicert-datatrails-scitt-action.yml`

```yaml
name: DigiCert Register SBOMs as DigiCert Signed SCITT Statement on DataTrails

on:
  workflow_dispatch:
  # push:
  #   branches: [ "main" ]
env:
  # DataTrails Config
  DATATRAILS_CLIENT_ID: ${{ secrets.DATATRAILS_CLIENT_ID }}
  DATATRAILS_CLIENT_SECRET: ${{ secrets.DATATRAILS_CLIENT_SECRET }}

  # DigiCert Config
  DIGICERT_STM_CERTIFICATE_ID: ${{ secrets.DIGICERT_STM_CERTIFICATE_ID }}
  DIGICERT_STM_API_BASE_URI: ${{ secrets.DIGICERT_STM_API_BASE_URI }}
  DIGICERT_STM_API_CLIENTAUTH_P12_PASSWORD: ${{ secrets.DIGICERT_STM_API_CLIENTAUTH_P12_PASSWORD }}
  DIGICERT_STM_API_CLIENTAUTH_P12_B64: ${{ secrets.DIGICERT_STM_API_CLIENTAUTH_P12_B64 }}
  DIGICERT_STM_API_KEY: ${{ secrets.DIGICERT_STM_API_KEY }}

  # Container/Registry Configs
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}
  DOCKER_HUB_USER: ${{ secrets.DOCKER_HUB_USER }}
  DOCKER_HUB_TOKEN: ${{ secrets.DOCKER_HUB_TOKEN }}
jobs:
  build-image-DigiCert-Sign-Register-DataTrails-SCITT:
    runs-on: ubuntu-latest
    # Sets the permissions granted to the `GITHUB_TOKEN` for the actions in this job.
    permissions:
      contents: read
      packages: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      - name: Login to the Container registry
        uses: docker/login-action@65b78e6e13532edd9afa3aa52ac7964289d1a9c1
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Extract metadata (tags, labels) for Docker
        id: meta
        uses: docker/metadata-action@9ec57ed1fcdbf14dcef7dfbe97b2010124a938b7
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: | 
            type=sha
      - name: Build and Push Docker Image
        uses: docker/build-push-action@f2a1d5e99d037542a71f64918e516c093c6f3fc4
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
      - name: Docker Scout
        id: docker-scout
        uses: docker/scout-action@v1.13.0
        with:
          dockerhub-user: ${{ env.DOCKER_HUB_USER}}
          dockerhub-password: ${{ env.DOCKER_HUB_TOKEN }}
          command: cves
          image: ${{ steps.meta.outputs.tags }}
          sarif-file: "./docker-scout-sarif.json"
          summary: true
      - id: upload-scout-results
        uses: actions/upload-artifact@v4
        with:
          name: docker-scout-sarif.json
          path: ./docker-scout-sarif.json
      - name: Register Docker Scout Output as a SCITT Signed Statement
        id: register-scitt-signed-statement
        #uses: datatrails/scitt-action@steve/transparent-statement
        uses: digicert/scitt-action@v0.4
        with:
          content-type: "application/vnd.docker.scout+json"
          payload-file: "./docker-scout-sarif.json"
          payload-location: ${{ steps.upload-scout-results.outputs.artifact-url }}
          subject: ${{ fromJSON(steps.meta.outputs.json).tags[0] }}
      - id: upload-scout-transparent-statement
        uses: actions/upload-artifact@v4
        with:
          name: scout-transparent-statement
          path: transparent-statement.cbor
      - name: Create Compliance Statement
        # A sample compliance file. Replace with an SBOM, in-toto statement, image for content authenticity, ...
        run: |
          echo '{"author": "fred", "title": "my biography", "reviews": "awesome"}' > ./attestation.json
      - name: Upload Compliance Statement
        id: upload-compliance-statement
        uses: actions/upload-artifact@v4
        with:
          name: attestation.json
          path: ./attestation.json
      - name: Register Compliance Statement as a SCITT Signed Statement
        id: register-compliance-scitt-digicert-signed-statement
        uses: digicert/scitt-action@v0.4
        with:
          content-type: "application/vnd.unknown.attestation+json"
          payload-file: "./attestation.json"
          payload-location: ${{ steps.upload-compliance-statement.outputs.artifact-url }}
          subject: ${{ fromJSON(steps.meta.outputs.json).tags[0] }}
      - name: Upload Compliance Transparent Statement
        uses: actions/upload-artifact@v4
        with:
          name: compliance--transparent-statement
          path: transparent-statement.cbor
      - name: Generate CycloneDX SBOM for Python
        uses: CycloneDX/gh-python-generate-sbom@v2
        with:
          input: ./requirements.txt
          output: ./cyclone-dx.sbom.json
          format: json
      - name: Upload CycloneDX To Artifacts
        id: upload-cyclonedx-to-artifacts
        uses: actions/upload-artifact@v4
        with:
          name: cyclone-dx.sbom.json
          path: ./cyclone-dx.sbom.json
      - name: DigiCert Sign, Register CylconeDX as a SCITT Signed Statement
        id: register-cyclonedx-signed-statement
        uses: digicert/scitt-action@v0.4
        with:
          content-type: "application/vnd.cyclonedx+json"
          payload-file: "./cyclone-dx.sbom.json"
          payload-location: ${{ steps.upload-cyclonedx-to-artifacts.outputs.artifact-url }}
          subject: ${{ fromJSON(steps.meta.outputs.json).tags[0] }}
      - uses: actions/upload-artifact@v4
        with:
          name: cyclonedx--transparent-statement
          path: transparent-statement.cbor
      - name: Generate SPDX SBOM
        run: |
          curl -Lo $RUNNER_TEMP/sbom-tool https://github.com/microsoft/sbom-tool/releases/latest/download/sbom-tool-linux-x64
          chmod +x $RUNNER_TEMP/sbom-tool
          $RUNNER_TEMP/sbom-tool generate -b ./ -bc . -pn synsation-web -pv 1.0.0 -ps synsation-org -nsb https://synsation.io -V Verbose -D true
      - name: Upload SPDX to Artifacts
        id: upload-spdx-to-artifacts
        uses: actions/upload-artifact@v4
        with:
          name: spdx.sbom.json
          path: ./_manifest/spdx_2.2/manifest.spdx.json
      - name: DigiCert Sign, Register SPDX as a SCITT Signed Statement
        id: register-spdx-scitt-signed-statement
        uses: digicert/scitt-action@v0.4
        with:
          content-type: "application/spdx+json"
          payload-file: "./_manifest/spdx_2.2/manifest.spdx.json"
          payload-location: ${{ steps.upload-spdx-to-artifacts.outputs.artifact-url }}
          subject: ${{ fromJSON(steps.meta.outputs.json).tags[0] }}
      - uses: actions/upload-artifact@v4
        with:
          name: spdx--transparent-statement
          path: transparent-statement.cbor
```
