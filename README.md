# Cloud Run Custom Domain Mapping (sGTM)

Bash script to set up **custom domain mapping via HTTPS Load Balancer** for **Server-side Google Tag Manager (sGTM) on Cloud Run**.

## What it does

- **Option 1:** Create a new load balancer with a subdomain, SSL cert, NEG, backend, URL map, proxy, and forwarding rule.
- **Option 2:** Add another domain to an existing load balancer (reuses the same global IP and proxy).

At the end you get a **global IP** to add as an A record in your DNS.

## Requirements

- [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) (`gcloud`) installed and logged in
- Project set: `gcloud config set project YOUR_PROJECT_ID`
- Permissions to create Compute resources (e.g. Compute Admin or Editor)

## Usage

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/selnekovic/sgtm-load-balancer-shell-script/main/load_balancer_shell.sh)"
```

You’ll be prompted for:

- **Subdomain** (e.g. `data.yourdomain.com`)
- **Cloud Run service name** (e.g. `sgtm-server-eu-prod`)
- **Region** (e.g. `europe-west4`)

Confirm, then choose **1** (new load balancer) or **2** (add domain). Add the printed IP as an **A record** in your DNS for that subdomain.

## License and references

- **Author:** [Julius Selnekovic](https://selnekovic.com)  
- **License:** [MIT](LICENSE) 
- **Article:** [Server-side GTM Domain Mapping with Load Balancer](https://selnekovic.com/blog/sgtm-domain-mapping-load-balancer/)
