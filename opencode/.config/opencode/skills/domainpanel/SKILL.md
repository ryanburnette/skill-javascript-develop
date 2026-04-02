---
name: domainpanel
description: Manage domains and DNS records across registrars. Use when working with domainpanel CLI, importing DNS records, or configuring registrar credentials.
---

## Config Files

All config files are gitignored. Create in project directory:

| File | Format |
|------|--------|
| `config.tsv` | `registrar\tslug` per line |
| `domains.tsv` | `domain\tregistrar\temail[\tYYYY-MM-DD[\tcost_usd]]` |

Credentials live in `~/.config/{registrar}/{slug}.env`:

| Registrar | Env Vars |
|-----------|----------|
| `namedotcom` | `NAMEDOTCOM_USERNAME`, `NAMEDOTCOM_TOKEN` |
| `namecheap` | `NAMECHEAP_USERNAME`, `NAMECHEAP_API_KEY`, `NAMECHEAP_CLIENT_IP` (auto-detected) |
| `cloudflare` | `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` |
| `digitalocean-domains` | `DIGITALOCEAN_TOKEN` |
| `hover` | `HOVER_USERNAME`, `HOVER_PASSWORD`, `HOVER_TOTP_SECRET` |
| `dnsimple` | `DNSIMPLE_TOKEN`, `DNSIMPLE_ACCOUNT_ID` (auto-discovered) |
| `nearlyfreespeech` | `NFSN_LOGIN`, `NFSN_API_KEY` |
| `iwantmyname` | `IWANTMYNAME_USERNAME`, `IWANTMYNAME_PASSWORD` |
| `duckdns` | `DUCKDNS_TOKEN` |

## Setup

```sh
# Clone and enter
git clone https://github.com/therootcompany/domainpanel.git
cd domainpanel

# Create config
echo "namedotcom	myslug" > config.tsv

# Create credentials
mkdir -p ~/.config/namedotcom
cat > ~/.config/namedotcom/myslug.env << 'EOF'
NAMEDOTCOM_USERNAME=your-username
NAMEDOTCOM_TOKEN=your-api-token
EOF
```

## Commands

```sh
# List domains with expiry
go run ./cmd/domainpanel/

# List DNS records across all zones
go run ./cmd/domainpanel/ -records

# Import DNS records from CSV/TSV
go run ./cmd/domainpanel/ -import records.csv --dry-run  # preview
go run ./cmd/domainpanel/ -import records.csv            # apply

# Create/update/delete single records
go run ./cmd/domainpanel/ -create-host test.example.com -type A -data 1.2.3.4
go run ./cmd/domainpanel/ -update-host test.example.com -type A -data 5.6.7.8
go run ./cmd/domainpanel/ -delete-host test.example.com -type A

# Web UI
go run ./cmd/domainpanel/ -serve :8080
```

## Import CSV Format

Required columns: `zone`, `name`, `type`, `data`
Optional: `ttl_sec` (default 300)

```csv
zone,name,type,data,ttl_sec
example.com,@,A,192.0.2.1,3600
example.com,www,CNAME,example.com,300
example.com,@,MX,10 mail.example.com,14400
example.com,_dmarc,TXT,"v=DMARC1; p=quarantine",3600
```

- `@` = apex record
- Quoted values for commas/spaces
- SRV format: `priority weight port target` in data field

## Notes

- ANAME (name.com ALIAS at apex) supported for apex records that would otherwise be CNAME
- Records are upserted: matching name+type replaced, others preserved
- Zone must use registrar's nameservers before API allows record operations
- Multi-account: each line in config.tsv loads separate credentials