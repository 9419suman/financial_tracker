#!/usr/bin/env python3
"""
Fetch bank statement emails and save to files — NO LLM calls.

Output: email_dump/<BANK>_emails.txt  (one file per bank)

Usage:
  python3 fetch_emails.py
"""

import os
import base64
import json
import re
import webbrowser
from datetime import datetime, timedelta
from wsgiref.simple_server import make_server, WSGIRequestHandler
from urllib.parse import urlparse, parse_qs

from google.auth.transport.requests import Request
from google.oauth2.credentials import Credentials
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

# ─── CONFIG ──────────────────────────────────────────────────────────────────

BANKS_TO_SEARCH = ['hdfc', 'rbl', 'idfc', 'axis', 'icici', 'sbi', 'kotak',
                   'pnb', 'canara', 'indusind', 'federal', 'csb',
                   'aubank', 'equitas', 'ujjivan']

MONTHS = 6

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), 'email_dump')

# ─── ENV / AUTH ──────────────────────────────────────────────────────────────

def load_env():
    env = {}
    env_path = os.path.join(os.path.dirname(__file__), '.env')
    if os.path.exists(env_path):
        for line in open(env_path):
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                k, v = line.split('=', 1)
                env[k.strip()] = v.split('#')[0].strip()
    return env

_env = load_env()
CLIENT_SECRET_FILE = os.path.join(os.path.dirname(__file__), 'client_secret.json')
TOKEN_FILE         = os.path.join(os.path.dirname(__file__), 'gmail_token.json')
SCOPES             = ['https://www.googleapis.com/auth/gmail.readonly']

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
                print(f"❌ Missing: {CLIENT_SECRET_FILE}")
                exit(1)

            client_config = json.load(open(CLIENT_SECRET_FILE))
            client_type = 'web' if 'web' in client_config else 'installed'

            if client_type == 'web':
                from google_auth_oauthlib.flow import Flow
                flow = Flow.from_client_secrets_file(
                    CLIENT_SECRET_FILE, scopes=SCOPES, redirect_uri='http://127.0.0.1:8080'
                )
                auth_url, _ = flow.authorization_url(prompt='consent')
                print(f"\n🌐 Opening browser for Google sign-in...")
                webbrowser.open(auth_url)

                auth_code = [None]
                def wsgi_app(environ, start_response):
                    qs = parse_qs(urlparse(environ['PATH_INFO'] + '?' + (environ.get('QUERY_STRING', ''))).query)
                    auth_code[0] = qs.get('code', [None])[0]
                    start_response('200 OK', [('Content-Type', 'text/html')])
                    return [b'<h2>Authenticated! You can close this tab.</h2>']

                class _Silent(WSGIRequestHandler):
                    def log_message(self, *args): pass

                httpd = make_server('127.0.0.1', 8080, wsgi_app, handler_class=_Silent)
                print("⏳ Waiting for Google redirect...")
                httpd.handle_request()
                httpd.server_close()

                if not auth_code[0]:
                    print("❌ No auth code received.")
                    exit(1)

                flow.fetch_token(code=auth_code[0])
                creds = flow.credentials
            else:
                flow = InstalledAppFlow.from_client_secrets_file(CLIENT_SECRET_FILE, SCOPES)
                creds = flow.run_local_server(port=8080, open_browser=True)

        with open(TOKEN_FILE, 'w') as f:
            f.write(creds.to_json())

    return build('gmail', 'v1', credentials=creds)

# ─── EMAIL PARSING ────────────────────────────────────────────────────────────

def get_email_body(msg_payload) -> str:
    body = ''
    mime = msg_payload.get('mimeType', '')
    data = msg_payload.get('body', {}).get('data', '')

    if mime == 'text/plain' and data:
        body += base64.urlsafe_b64decode(data + '==').decode('utf-8', errors='ignore')
    elif mime == 'text/html' and data:
        html = base64.urlsafe_b64decode(data + '==').decode('utf-8', errors='ignore')
        body += re.sub(r'<[^>]+>', ' ', html)

    for part in msg_payload.get('parts', []):
        body += get_email_body(part)

    return re.sub(r'\s+', ' ', body).strip()


def find_attachments(part: dict, results: list):
    filename = part.get('filename', '')
    if filename.lower().endswith('.pdf') and part.get('body', {}).get('attachmentId'):
        results.append({
            'filename': filename,
            'size_kb': round(part['body'].get('size', 0) / 1024, 1),
        })
    for p in part.get('parts', []):
        find_attachments(p, results)


def _has_statement_signal(subject: str, body: str) -> bool:
    haystack = (subject + ' ' + body[:500]).lower()
    return any(kw in haystack for kw in STATEMENT_KEYWORDS)

# ─── FETCH ───────────────────────────────────────────────────────────────────

def fetch_bank_emails(service, bank_id: str, months: int) -> list:
    keyword   = BANK_KEYWORDS.get(bank_id, bank_id)
    now       = datetime.now()
    after     = datetime(now.year, now.month, now.day) - timedelta(days=months * 30)
    after_str = after.strftime('%Y/%m/%d')
    before_str = now.strftime('%Y/%m/%d')
    query = f'from:{keyword} has:attachment filename:pdf after:{after_str} before:{before_str}'

    print(f"  🔍 {bank_id.upper()}: {query}")
    results = service.users().messages().list(userId='me', q=query, maxResults=50).execute()
    messages = results.get('messages', [])
    print(f"     → {len(messages)} emails found")

    emails = []
    for msg_ref in messages:
        msg = service.users().messages().get(userId='me', id=msg_ref['id'], format='full').execute()
        headers = {h['name']: h['value'] for h in msg['payload'].get('headers', [])}

        subject  = headers.get('Subject', 'No Subject')
        sender   = headers.get('From', 'Unknown')
        date_str = headers.get('Date', '')
        body     = get_email_body(msg['payload'])

        attachments = []
        find_attachments(msg['payload'], attachments)

        emails.append({
            'id':                 msg['id'],
            'subject':            subject,
            'sender':             sender,
            'date':               date_str,
            'body':               body,
            'attachments':        attachments,
            'has_statement_signal': _has_statement_signal(subject, body),
        })

    emails.sort(key=lambda e: (not e['has_statement_signal'], e['date']))
    return emails

# ─── SAVE ────────────────────────────────────────────────────────────────────

def save_bank_emails(bank_id: str, emails: list):
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    filepath = os.path.join(OUTPUT_DIR, f'{bank_id}_emails.txt')

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(f"{'='*70}\n")
        f.write(f"  {bank_id.upper()} — {len(emails)} emails  (fetched {datetime.now().strftime('%Y-%m-%d %H:%M')})\n")
        f.write(f"{'='*70}\n\n")

        for i, email in enumerate(emails, 1):
            signal = '✅ statement' if email['has_statement_signal'] else '⚠️  no statement keyword'
            f.write(f"{'─'*70}\n")
            f.write(f"EMAIL {i}/{len(emails)}  [{signal}]\n")
            f.write(f"Subject : {email['subject']}\n")
            f.write(f"From    : {email['sender']}\n")
            f.write(f"Date    : {email['date']}\n")
            f.write(f"Msg ID  : {email['id']}\n")

            if email['attachments']:
                f.write(f"PDFs    :\n")
                for a in email['attachments']:
                    f.write(f"          {a['filename']}  ({a['size_kb']} KB)\n")
            else:
                f.write(f"PDFs    : none\n")

            f.write(f"\n--- BODY ---\n")
            f.write(email['body'] if email['body'] else '(empty)')
            f.write(f"\n\n")

    print(f"     → saved: email_dump/{bank_id}_emails.txt")
    return filepath

# ─── MAIN ────────────────────────────────────────────────────────────────────

def main():
    print("=" * 70)
    print("  Bank Email Fetcher  (no LLM)")
    print(f"  Banks : {', '.join(b.upper() for b in BANKS_TO_SEARCH)}")
    print(f"  Range : last {MONTHS} months")
    print("=" * 70)

    service = get_gmail_service()
    summary = []

    for bank_id in BANKS_TO_SEARCH:
        emails = fetch_bank_emails(service, bank_id, MONTHS)
        if not emails:
            print(f"     → no emails, skipping file")
            continue
        save_bank_emails(bank_id, emails)
        summary.append((bank_id, len(emails), sum(1 for e in emails if e['has_statement_signal'])))

    print(f"\n{'='*70}")
    print("  SUMMARY")
    print(f"{'='*70}")
    for bank_id, total, signalled in summary:
        print(f"  {bank_id.upper():<12} {total:>3} emails  ({signalled} with statement keyword)")
    print(f"\n  Files saved in: {OUTPUT_DIR}/")

if __name__ == '__main__':
    main()
