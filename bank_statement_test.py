#!/usr/bin/env python3
"""
Bank Statement Password Finder
--------------------------------
For each bank email fetched, reads the email body and asks Gemini:
"What is the PDF password based on these user details?"

Usage:
  python3 bank_statement_test.py

Config at the top of the file — set BANK, MONTHS, and USER details.
"""

import os
import base64
import json
import re
import requests
import webbrowser
from typing import Optional
from datetime import datetime, timedelta
from wsgiref.simple_server import make_server, WSGIRequestHandler
from urllib.parse import urlparse, parse_qs

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

# ─── CONFIG ──────────────────────────────────────────────────────────────────

# Which banks to search
BANKS_TO_SEARCH = ['hdfc', 'rbl', 'idfc', 'axis', 'icici', 'sbi', 'kotak',
                   'pnb', 'canara', 'indusind', 'federal', 'csb',
                   'aubank', 'equitas', 'ujjivan']

# How many months back to search
MONTHS = 6

# Max emails to process per bank (None = all)
MAX_PER_BANK = 1

# User details for password derivation
USER = {
    'full_name': 'Prasun Kumar',
    'dob': '21/06/1997',   # DD/MM/YYYY
    'pan': 'GQWPK9281H',
    'phone': '8604650326',
    'card_last4': '1290',  # SBI Cashback card last 4
    'bank_passwords': {
        'hdfc':  '114210210',   # HDFC Customer ID
        'rbl':   '103850977',   # RBL Customer ID
        'idfc':  '6025167902',  # IDFC Customer ID
    },
}

def load_env():
    env = {}
    env_path = os.path.join(os.path.dirname(__file__), '.env')
    if os.path.exists(env_path):
        for line in open(env_path):
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                k, v = line.split('=', 1)
                v = v.split('#')[0].strip()  # strip inline comments
                env[k.strip()] = v
    return env

_env = load_env()
GEMINI_API_KEY   = _env.get('GEMINI_API_KEY', os.environ.get('GEMINI_API_KEY', ''))
GEMINI_MODEL     = _env.get('GEMINI_MODEL',   os.environ.get('GEMINI_MODEL', 'gemini-2.0-flash'))
GEMINI_BASE_URL  = _env.get('GEMINI_BASE_URL', 'https://generativelanguage.googleapis.com/v1beta')
DEEPSEEK_API_KEY = _env.get('DEEPSEEK_API_KEY', os.environ.get('DEEPSEEK_API_KEY', ''))
DEEPSEEK_MODEL   = _env.get('DEEPSEEK_MODEL',   os.environ.get('DEEPSEEK_MODEL', 'deepseek-reasoner'))

# Path to your OAuth client secret JSON (the "installed" type you downloaded)
CLIENT_SECRET_FILE = os.path.join(os.path.dirname(__file__), 'client_secret.json')
TOKEN_FILE  = os.path.join(os.path.dirname(__file__), 'gmail_token.json')
CACHE_FILE  = os.path.join(os.path.dirname(__file__), 'password_cache.json')

SCOPES = ['https://www.googleapis.com/auth/gmail.readonly']

# ─── BANK DEFINITIONS ────────────────────────────────────────────────────────
# Gmail `from:` does substring match on the full sender address.
# Use the shortest unique identifier for each bank — catches any domain
# variation (rblbank.com, rbl.co.in, icici.com, icicibank.com, etc.)
# Gemini will verify if it's actually a bank statement.
BANK_KEYWORDS = {
    'hdfc':     'hdfc',
    'sbi':      'sbi',
    'icici':    'icici',
    'axis':     'axis',
    'kotak':    'kotak',
    'rbl':      'rbl',
    'idfc':     'idfc',
    'pnb':      'pnb',
    'canara':   'canara',
    'indusind': 'indusind',
    'federal':  'federal',
    'csb':      'csb',
    'aubank':   'aubank',
    'equitas':  'equitas',
    'ujjivan':  'ujjivan',
}

# Words that strongly suggest this is a financial statement email
STATEMENT_KEYWORDS = ['statement', 'account summary', 'passbook', 'e-statement', 'smartstatement']

# ─── GMAIL AUTH ──────────────────────────────────────────────────────────────

def get_gmail_service():
    creds = None

    if os.path.exists(TOKEN_FILE):
        creds = Credentials.from_authorized_user_file(TOKEN_FILE, SCOPES)

    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            if not os.path.exists(CLIENT_SECRET_FILE):
                print(f"\n❌ Missing: {CLIENT_SECRET_FILE}")
                exit(1)

            client_config = json.load(open(CLIENT_SECRET_FILE))
            client_type = 'web' if 'web' in client_config else 'installed'

            if client_type == 'web':
                from google_auth_oauthlib.flow import Flow
                flow = Flow.from_client_secrets_file(
                    CLIENT_SECRET_FILE,
                    scopes=SCOPES,
                    redirect_uri='http://127.0.0.1:8080',
                )
                auth_url, _ = flow.authorization_url(prompt='consent')
                print(f"\n🌐 Opening browser for Google sign-in...")
                webbrowser.open(auth_url)
                print(f"   If browser didn't open, visit:\n   {auth_url}\n")

                # Capture the redirect with a one-shot local server
                auth_code = [None]
                def wsgi_app(environ, start_response):
                    qs = parse_qs(urlparse(environ['PATH_INFO'] + '?' + (environ.get('QUERY_STRING', ''))).query)
                    auth_code[0] = qs.get('code', [None])[0]
                    start_response('200 OK', [('Content-Type', 'text/html')])
                    return [b'<h2>Authenticated! You can close this tab.</h2>']

                class _Silent(WSGIRequestHandler):
                    def log_message(self, *args): pass

                httpd = make_server('127.0.0.1', 8080, wsgi_app, handler_class=_Silent)
                print("⏳ Waiting for Google to redirect back...")
                httpd.handle_request()
                httpd.server_close()

                if not auth_code[0]:
                    print("❌ Did not receive auth code. Try again.")
                    exit(1)

                flow.fetch_token(code=auth_code[0])
                creds = flow.credentials
            else:
                flow = InstalledAppFlow.from_client_secrets_file(CLIENT_SECRET_FILE, SCOPES)
                creds = flow.run_local_server(port=8080, open_browser=True)

        with open(TOKEN_FILE, 'w') as f:
            f.write(creds.to_json())
        print(f"✅ Auth token saved to {TOKEN_FILE}")

    return build('gmail', 'v1', credentials=creds)

# ─── GMAIL FETCH ─────────────────────────────────────────────────────────────

def build_query(bank_id: str, after: datetime, before: datetime) -> str:
    keyword = BANK_KEYWORDS.get(bank_id, bank_id)
    after_str  = after.strftime('%Y/%m/%d')
    before_str = before.strftime('%Y/%m/%d')
    # Cast a wide net: any email from this bank's domain with a PDF attachment.
    # We do NOT filter by subject here — let Python + Gemini decide relevance.
    return f'from:{keyword} has:attachment filename:pdf after:{after_str} before:{before_str}'


def _has_statement_signal(email: dict) -> bool:
    """Return True if subject or body contains any statement-related keyword."""
    haystack = (email['subject'] + ' ' + email['body'][:500]).lower()
    return any(kw in haystack for kw in STATEMENT_KEYWORDS)


def get_email_body(msg_payload) -> str:
    """Recursively extract plain text + HTML body from a Gmail message payload."""
    body = ''

    mime = msg_payload.get('mimeType', '')
    data = msg_payload.get('body', {}).get('data', '')

    if mime == 'text/plain' and data:
        body += base64.urlsafe_b64decode(data + '==').decode('utf-8', errors='ignore')
    elif mime == 'text/html' and data:
        html = base64.urlsafe_b64decode(data + '==').decode('utf-8', errors='ignore')
        body += re.sub(r'<[^>]+>', ' ', html)  # strip HTML tags

    for part in msg_payload.get('parts', []):
        body += get_email_body(part)

    # Collapse excessive whitespace
    return re.sub(r'\s+', ' ', body).strip()


def find_attachments(part: dict, results: list):
    """Recursively find all PDF attachments in message parts."""
    filename = part.get('filename', '')
    if filename.lower().endswith('.pdf') and part.get('body', {}).get('attachmentId'):
        results.append({
            'filename': filename,
            'attachment_id': part['body']['attachmentId'],
            'size': part['body'].get('size', 0),
        })
    for p in part.get('parts', []):
        find_attachments(p, results)


def fetch_bank_emails(service, bank_id: str, months: int):
    now   = datetime.now()
    after = datetime(now.year, now.month, now.day) - timedelta(days=months * 30)
    query = build_query(bank_id, after, now)

    print(f"\n🔍 Querying Gmail for {bank_id.upper()}:")
    print(f"   {query}")

    results = service.users().messages().list(
        userId='me', q=query, maxResults=50
    ).execute()

    messages = results.get('messages', [])
    print(f"   Raw matches: {len(messages)} emails with PDF from {bank_id}")

    emails = []
    for msg_ref in messages:
        msg = service.users().messages().get(
            userId='me', id=msg_ref['id'], format='full'
        ).execute()

        headers = {h['name']: h['value'] for h in msg['payload'].get('headers', [])}
        subject = headers.get('Subject', 'No Subject')
        sender  = headers.get('From', 'Unknown')
        date_str = headers.get('Date', '')

        body = get_email_body(msg['payload'])

        attachments = []
        find_attachments(msg['payload'], attachments)

        email = {
            'id': msg['id'],
            'subject': subject,
            'sender': sender,
            'date': date_str,
            'body': body,
            'attachments': attachments,
            'has_statement_signal': _has_statement_signal(
                {'subject': subject, 'body': body}
            ),
        }
        emails.append(email)

    # Sort: statement-signalled emails first
    emails.sort(key=lambda e: (not e['has_statement_signal'], e['date']))
    print(f"   Statement-signalled: {sum(1 for e in emails if e['has_statement_signal'])}")
    return emails

# ─── PASSWORD CACHE ───────────────────────────────────────────────────────────

def load_cache() -> dict:
    if os.path.exists(CACHE_FILE):
        try:
            return json.load(open(CACHE_FILE, encoding='utf-8'))
        except Exception:
            return {}
    return {}

def save_cache(cache: dict):
    with open(CACHE_FILE, 'w', encoding='utf-8') as f:
        json.dump(cache, f, indent=2)

def get_cached(cache: dict, filename: str) -> Optional[dict]:
    return cache.get(filename)

def set_cached(cache: dict, filename: str, result: dict):
    cache[filename] = {**result, 'cached_at': datetime.now().isoformat()}
    save_cache(cache)

# ─── PASSWORD CANDIDATES ─────────────────────────────────────────────────────
# Used when the email has no explicit password instruction.
# Returns ordered list of candidates most-to-least likely.

def generate_password_candidates(user: dict) -> list:
    parts = user['full_name'].strip().split()
    first = parts[0].lower()          # prasun
    first4 = first[:4]                # pras
    pan  = user['pan'].upper()        # GQWPK9281H
    pan5 = pan[:5]                    # GQWPK
    phone = user.get('phone', '')     # 8604650326
    phone4 = phone[-4:] if phone else ''   # 0326
    card4 = user.get('card_last4', '')     # 1290

    dd, mm, yyyy = user['dob'].split('/')
    yy = yyyy[2:]                     # 97

    candidates = []

    # name + dob combos
    for npart in [first4, first, first4.upper(), first.upper()]:
        for dpart in [dd+mm, dd+mm+yyyy, dd+mm+yy, yyyy, mm+yyyy]:
            candidates.append(npart + dpart)

    # dob + card last 4 (SBI Cashback style: ddmmyyyy + last4)
    if card4:
        candidates += [
            dd+mm+yyyy+card4,   # 210619971290
            dd+mm+yy+card4,     # 2106971290
            card4,
        ]

    # dob only
    candidates += [dd+mm+yyyy, dd+mm+yy, dd+mm, yyyy+mm+dd, mm+dd+yyyy]

    # phone combos
    if phone:
        candidates += [
            phone,
            phone4,
            first4.upper() + phone4,   # PRAS0326
            first4 + phone4,           # pras0326
            phone + dd + mm,
        ]

    # PAN combos
    candidates += [
        pan5.lower() + dd + mm,        # gqwpk2106
        pan5 + dd + mm,                # GQWPK2106
        pan5.lower() + dd + mm + yyyy,
        pan + dd + mm,
    ]

    # name only variants
    candidates += [first, first.upper(), first4, first4.upper(),
                   ''.join(parts).lower(), ''.join(parts).upper()]

    # customer IDs from bank_passwords (try all known ones)
    candidates += list(user.get('bank_passwords', {}).values())

    # deduplicate, preserve order
    seen = set()
    result = []
    for c in candidates:
        if c and c not in seen:
            seen.add(c)
            result.append(c)
    return result

# ─── DEEPSEEK EMAIL ANALYSIS ─────────────────────────────────────────────────

def ask_deepseek_about_email(email_body: str, subject: str, user: dict) -> dict:
    """Ask DeepSeek to classify the statement and derive the PDF password."""

    if not DEEPSEEK_API_KEY:
        return {'error': 'No DEEPSEEK_API_KEY found in .env'}

    prompt = f"""Analyze this bank email and return ONLY valid JSON.

Subject: {subject}

Email body:
---
{email_body}
---

User details:
- Full Name: {user['full_name']}
- Date of Birth: {user['dob']} (DD/MM/YYYY)
- PAN: {user['pan']}
- Phone: {user.get('phone', 'unknown')}
- Card last 4 digits: {user.get('card_last4', 'unknown')}
- Known Customer IDs: {json.dumps(user.get('bank_passwords', {}))}

Return ONLY this JSON (null for unknown):
{{
  "statement_type": "account_statement | credit_card_statement | loan_statement | investment_statement | other | not_a_statement",
  "bank_name": "e.g. HDFC Bank",
  "card_name": "card product name if credit card, else null",
  "statement_month": "YYYY-MM of the statement period",
  "password_instruction_found": true or false — whether the email explicitly states how the PDF is password-protected,
  "password": "computed password using the instruction and user details — null only if instruction is absent or unresolvable",
  "password_confidence": "high | medium | low | none",
  "total_amount_due": "credit card total due as string, null otherwise",
  "minimum_amount_due": "credit card minimum due as string, null otherwise",
  "payment_due_date": "YYYY-MM-DD, null otherwise"
}}
"""

    resp = requests.post(
        'https://api.deepseek.com/chat/completions',
        headers={
            'Authorization': f'Bearer {DEEPSEEK_API_KEY}',
            'Content-Type': 'application/json',
        },
        json={
            'model': DEEPSEEK_MODEL,
            'messages': [{'role': 'user', 'content': prompt}],
            'response_format': {'type': 'json_object'},
        },
        timeout=60,
    )

    if resp.status_code != 200:
        return {'error': f'DeepSeek {resp.status_code}: {resp.text[:300]}'}

    try:
        content = resp.json()['choices'][0]['message']['content']
        return json.loads(content)
    except Exception as e:
        return {'error': f'Parse error: {e}', 'raw': resp.text[:300]}


# ─── MAIN ─────────────────────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("  Bank Statement Password Finder")
    print("=" * 60)
    print(f"User : {USER['full_name']}  DOB: {USER['dob']}  PAN: {USER['pan']}")
    print(f"Banks: {', '.join(b.upper() for b in BANKS_TO_SEARCH)}")
    print(f"Range: Last {MONTHS} months")

    service = get_gmail_service()
    cache = load_cache()
    all_results = []

    for bank_id in BANKS_TO_SEARCH:
        emails = fetch_bank_emails(service, bank_id, MONTHS)

        if not emails:
            print(f"   ⚠️  No emails found for {bank_id.upper()}")
            continue

        if MAX_PER_BANK:
            emails = emails[:MAX_PER_BANK]
            print(f"   ℹ️  Test mode: processing {len(emails)}/{len(emails)} email(s) only")

        for email in emails:
            signal = "✅" if email['has_statement_signal'] else "⚠️ (no statement keyword)"
            print(f"\n{'─'*60}")
            print(f"📧  {email['subject']}  {signal}")
            print(f"    From   : {email['sender']}")
            print(f"    Date   : {email['date']}")
            filenames = [a['filename'] for a in email['attachments']]
            print(f"    PDFs   : {len(filenames)} — {', '.join(filenames)}")

            if not email['body']:
                print("    ⚠️  No readable body — skipping")
                continue

            snippet = email['body'][:300].replace('\n', ' ')
            print(f"    Body   : {snippet}...")

            # ── Cache check ──────────────────────────────────────────────────
            # Use first PDF filename as cache key (each statement file is unique)
            cache_key = filenames[0] if filenames else email['id']
            cached = get_cached(cache, cache_key)

            if cached:
                result = cached
                print(f"\n    💾 [CACHED] skipping LLM call")
            else:
                print(f"\n    🤖 Asking DeepSeek...")
                result = ask_deepseek_about_email(email['body'], email['subject'], USER)

                if 'error' not in result:
                    # If no instruction found, generate candidates for brute-force
                    if not result.get('password_instruction_found', True):
                        result['password_candidates'] = generate_password_candidates(USER)
                    set_cached(cache, cache_key, result)

            if 'error' in result:
                print(f"    ❌ Error: {result['error']}")
            else:
                print(f"    📂 {result.get('statement_type', '?')}  |  🏦 {result.get('bank_name', '?')}  |  📅 {result.get('statement_month', '?')}")
                if result.get('card_name'):
                    print(f"    💳 {result.get('card_name')}")
                if result.get('password_instruction_found') is False:
                    candidates = result.get('password_candidates', [])
                    print(f"    ⚠️  No password instruction in email — try these candidates:")
                    print(f"    🔑 {', '.join(candidates[:10])}" + (' ...' if len(candidates) > 10 else ''))
                else:
                    print(f"    🔑 Password: {result.get('password') or 'unknown'}  [{result.get('password_confidence', '?')}]")
                if result.get('total_amount_due'):
                    print(f"    💰 Due: INR {result.get('total_amount_due')}  |  Min: {result.get('minimum_amount_due')}  |  By: {result.get('payment_due_date')}")

            all_results.append({
                'bank': bank_id,
                'email_id': email['id'],
                'subject': email['subject'],
                'date': email['date'],
                'has_statement_signal': email['has_statement_signal'],
                'attachments': email['attachments'],
                'cache_key': cache_key,
                'result': result,
            })

    print(f"\n{'='*60}")
    print("  SUMMARY")
    print(f"{'='*60}")
    for r in all_results:
        g = r['result']
        if 'error' in g:
            print(f"  {r['bank'].upper()} | {r['date'][:16]} | ❌ {g['error'][:60]}")
            continue
        pwd = g.get('password') or ('candidates: ' + ', '.join(g.get('password_candidates', [])[:5]))
        cc  = f"  💳 {g.get('card_name')}" if g.get('card_name') else ''
        due = f"  💰 INR {g.get('total_amount_due')} by {g.get('payment_due_date')}" if g.get('total_amount_due') else ''
        src = '💾' if g.get('cached_at') else '🤖'
        print(f"  {src} {r['bank'].upper()} | {g.get('statement_month','?')} | {g.get('statement_type','?')} | 🔑 {pwd}{cc}{due}")

    output_file = os.path.join(os.path.dirname(__file__), 'password_results.json')
    with open(output_file, 'w') as f:
        json.dump(all_results, f, indent=2)
    print(f"\n✅ Full results saved to: {output_file}")


if __name__ == '__main__':
    main()
