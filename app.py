from flask import Flask, request, jsonify
from flask_cors import CORS
from openai import OpenAI
import os
import hmac
import hashlib
import logging
import requests
import uuid
import json
import mimetypes
from functools import wraps
from datetime import datetime, timezone
from urllib.parse import quote
from supabase import create_client, Client
from dotenv import load_dotenv
import firebase_admin
from firebase_admin import credentials, messaging

# Load environment variables
load_dotenv()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("skinbydrfizzag")

# Initialize Firebase (idempotent — initialize_app raises if the default app
# already exists, e.g. under gunicorn --preload or the dev reloader).
firebase_initialized = False
try:
    firebase_cred_config = {
        "type": "service_account",
        "project_id": os.environ.get("FIREBASE_PROJECT_ID"),
        "private_key_id": os.environ.get("FIREBASE_PRIVATE_KEY_ID"),
        "private_key": os.environ.get("FIREBASE_PRIVATE_KEY").replace('\\n', '\n') if os.environ.get("FIREBASE_PRIVATE_KEY") else None,
        "client_email": os.environ.get("FIREBASE_CLIENT_EMAIL"),
        "client_id": os.environ.get("FIREBASE_CLIENT_ID", "111959171691144632402"),
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    }

    if firebase_admin._apps:
        firebase_initialized = True
    elif all([os.environ.get("FIREBASE_PROJECT_ID"),
              os.environ.get("FIREBASE_PRIVATE_KEY"),
              os.environ.get("FIREBASE_CLIENT_EMAIL")]):
        firebase_cred = credentials.Certificate(firebase_cred_config)
        firebase_admin.initialize_app(firebase_cred)
        firebase_initialized = True
        logger.info("Firebase initialized successfully")
    else:
        logger.warning("Firebase credentials incomplete")
except Exception as e:
    logger.warning(f"Firebase initialization failed: {e}")

app = Flask(__name__)

# Restrict CORS to the routes the app/browser actually call. The mobile app
# is not bound by CORS, so a narrow allow-list here only tightens browser access
# without breaking the Flutter client. Override with the ALLOWED_ORIGINS env var
# (comma-separated) when serving a web build.
_allowed_origins = [o.strip() for o in os.environ.get("ALLOWED_ORIGINS", "").split(",") if o.strip()]
CORS(app, origins=_allowed_origins or "*")

# Shared HTTP session with connection pooling for all outbound calls.
http_session = requests.Session()
DEFAULT_TIMEOUT = 30

# Initialize Clients
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") # Use Service Role Key for backend
SUPABASE_ANON_KEY = os.environ.get("SUPABASE_ANON_KEY") # Anon key for API calls
WHATSAPP_TOKEN = os.environ.get("WHATSAPP_TOKEN")
WHATSAPP_PHONE_NUMBER_ID = os.environ.get("WHATSAPP_PHONE_NUMBER_ID")
WHATSAPP_APP_SECRET = os.environ.get("WHATSAPP_APP_SECRET")  # Meta app secret for webhook signature verification
VERIFY_TOKEN = os.environ.get("VERIFY_TOKEN")
ADMIN_ID = os.environ.get("ADMIN_ID") # The UUID of Dr. Fizza's profile

openai_client = OpenAI(api_key=OPENAI_API_KEY) if OPENAI_API_KEY else None
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY) if SUPABASE_URL and SUPABASE_KEY else None


# ==================== Auth helpers ====================

def _extract_admin_token():
    """Read the admin/access token from the Authorization header or JSON body."""
    auth_header = request.headers.get('Authorization', '')
    if auth_header.startswith('Bearer '):
        return auth_header[7:].strip()
    body = request.get_json(silent=True) or {}
    return body.get('admin_token')


def verify_admin():
    """Validate the caller's Supabase JWT and confirm they are an admin.

    Returns the admin profile dict on success, or None if the token is
    missing/invalid or the user is not an admin.
    """
    token = _extract_admin_token()
    if not token or not supabase:
        return None
    try:
        user_resp = supabase.auth.get_user(token)
        user = getattr(user_resp, 'user', None)
        if user is None:
            return None
        prof = supabase.table('profiles').select('*').eq('id', user.id).limit(1).execute()
        if prof.data and prof.data[0].get('role') == 'admin':
            return prof.data[0]
    except Exception as e:
        logger.warning(f"Admin token verification failed: {e}")
    return None


def admin_required(view):
    """Decorator that rejects requests lacking a valid admin token."""
    @wraps(view)
    def wrapper(*args, **kwargs):
        admin_profile = verify_admin()
        if not admin_profile:
            return jsonify({"error": "Unauthorized"}), 401
        request.admin_profile = admin_profile
        return view(*args, **kwargs)
    return wrapper


def normalize_message_type(message_type):
    """Map external/platform message types to app-supported message types."""
    normalized = (message_type or 'text').lower()
    if normalized in {'image', 'sticker'}:
        return 'image'
    if normalized in {'audio', 'voice'}:
        return 'audio'
    if normalized in {'document', 'video'}:
        return 'file'
    return 'text'


def default_message_text(message_type):
    """Fallback preview text for non-text messages."""
    normalized = normalize_message_type(message_type)
    if normalized == 'image':
        return 'Image'
    if normalized == 'audio':
        return 'Voice message'
    if message_type == 'video':
        return 'Video'
    return 'Attachment'


def upload_bytes_to_supabase_storage(bucket, object_path, file_bytes, content_type='application/octet-stream'):
    """Upload raw bytes to a public Supabase storage bucket and return its public URL."""
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise ValueError("Supabase storage is not configured.")

    encoded_path = quote(object_path, safe='/')
    upload_url = f"{SUPABASE_URL}/storage/v1/object/{bucket}/{encoded_path}"
    headers = {
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "apikey": SUPABASE_KEY,
        "Content-Type": content_type or "application/octet-stream",
        "x-upsert": "true",
    }
    response = http_session.post(upload_url, headers=headers, data=file_bytes, timeout=60)
    if response.status_code not in (200, 201):
        raise ValueError(f"Supabase storage upload failed: {response.status_code} {response.text}")

    return f"{SUPABASE_URL}/storage/v1/object/public/{bucket}/{encoded_path}"


def download_whatsapp_media(media_id):
    """Download media bytes from WhatsApp Cloud API."""
    if not WHATSAPP_TOKEN:
        raise ValueError("WHATSAPP_TOKEN is not configured.")

    metadata_response = http_session.get(
        f"https://graph.facebook.com/v19.0/{media_id}",
        headers={"Authorization": f"Bearer {WHATSAPP_TOKEN}"},
        timeout=30,
    )
    metadata_response.raise_for_status()
    metadata = metadata_response.json()

    media_url = metadata.get('url')
    if not media_url:
        raise ValueError("WhatsApp media URL missing from metadata response.")

    media_response = http_session.get(
        media_url,
        headers={"Authorization": f"Bearer {WHATSAPP_TOKEN}"},
        timeout=60,
    )
    media_response.raise_for_status()

    return {
        "bytes": media_response.content,
        "mime_type": metadata.get('mime_type') or media_response.headers.get('Content-Type'),
        "sha256": metadata.get('sha256'),
    }


def store_whatsapp_media(phone, conversation_id, wa_id, raw_type, media_payload):
    """Download incoming WhatsApp media and upload it to Supabase storage."""
    media_id = media_payload.get('id')
    if not media_id:
        return None

    media_details = download_whatsapp_media(media_id)
    mime_type = media_payload.get('mime_type') or media_details.get('mime_type')
    suggested_filename = media_payload.get('filename')
    extension = mimetypes.guess_extension(mime_type or '') or ''
    if raw_type == 'audio' and extension == '.mp4':
        extension = '.m4a'
    if not suggested_filename:
        suggested_filename = f"{raw_type}_{wa_id or uuid.uuid4().hex}{extension}"

    safe_filename = suggested_filename.replace('\\', '_').replace('/', '_').replace(' ', '_')
    object_path = f"whatsapp/{phone}/{conversation_id}/{safe_filename}"

    return upload_bytes_to_supabase_storage(
        'chat_files',
        object_path,
        media_details['bytes'],
        mime_type or 'application/octet-stream',
    )


def build_whatsapp_payload(recipient_phone, message_text='', message_type='text', file_url=None, file_name=None):
    """Build a WhatsApp Cloud API payload for text or media."""
    normalized = normalize_message_type(message_type)
    text = (message_text or '').strip()

    if file_url and normalized == 'image':
        payload = {
            "messaging_product": "whatsapp",
            "to": recipient_phone,
            "type": "image",
            "image": {"link": file_url},
        }
        if text:
            payload["image"]["caption"] = text
        return payload

    if file_url and normalized == 'audio':
        return {
            "messaging_product": "whatsapp",
            "to": recipient_phone,
            "type": "audio",
            "audio": {"link": file_url},
        }

    if file_url and normalized == 'file':
        payload = {
            "messaging_product": "whatsapp",
            "to": recipient_phone,
            "type": "document",
            "document": {"link": file_url},
        }
        if file_name:
            payload["document"]["filename"] = file_name
        if text:
            payload["document"]["caption"] = text
        return payload

    return {
        "messaging_product": "whatsapp",
        "to": recipient_phone,
        "type": "text",
        "text": {"body": text},
    }

def get_admin_profile():
    """Return the admin profile that should own app and WhatsApp chats."""
    if not supabase:
        return None

    if ADMIN_ID:
        admin_by_id = supabase.table('profiles').select('*').eq('id', ADMIN_ID).limit(1).execute()
        if admin_by_id.data:
            return admin_by_id.data[0]
        print(f"Warning: ADMIN_ID {ADMIN_ID} was not found in profiles.")

    admin_profiles = (
        supabase.table('profiles')
        .select('*')
        .eq('role', 'admin')
        .order('created_at', desc=False)
        .limit(1)
        .execute()
    )
    if admin_profiles.data:
        return admin_profiles.data[0]

    return None

def send_fcm_notification(token, title, body, data=None):
    """Send FCM notification using Firebase Admin SDK v1 API"""
    if not firebase_initialized or not token:
        print("FCM not configured or no token provided")
        return
    
    try:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    sound="default",
                ),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default"),
                ),
            ),
            data={k: str(v) for k, v in (data or {}).items() if v is not None},
            token=token,
        )
        response = messaging.send(message)
        print(f"✅ FCM notification sent successfully. Message ID: {response}")
    except Exception as e:
        print(f"❌ FCM Error: {e}")

def upsert_profile_fcm_token(profile_id, fcm_token):
    """Persist the current device token for a profile."""
    if not supabase:
        raise ValueError("Supabase client not initialized.")

    if not profile_id:
        raise ValueError("profile_id is required.")

    supabase.table('profiles').update({
        'fcm_token': fcm_token,
        'updated_at': datetime.now(timezone.utc).isoformat()
    }).eq('id', profile_id).execute()

@app.route('/')
def home():
    return "Skin By Dr. Fizza G - Integrated Backend is Running!"

# --- WHATSAPP WEBHOOK ---

@app.route('/webhook', methods=['GET'])
def verify_webhook():
    """Meta Webhook Verification"""
    mode = request.args.get('hub.mode')
    token = request.args.get('hub.verify_token')
    challenge = request.args.get('hub.challenge')

    if mode == 'subscribe' and token == VERIFY_TOKEN:
        return challenge, 200
    return "Verification failed", 403

def _verify_webhook_signature(raw_body):
    """Verify Meta's X-Hub-Signature-256 HMAC over the raw request body.

    Returns True when the signature is valid. If WHATSAPP_APP_SECRET is not
    configured the check is skipped (logged as a warning) so existing
    deployments keep working until the secret is provisioned.
    """
    if not WHATSAPP_APP_SECRET:
        logger.warning("WHATSAPP_APP_SECRET not set — skipping webhook signature verification")
        return True
    signature = request.headers.get('X-Hub-Signature-256', '')
    if not signature.startswith('sha256='):
        return False
    expected = hmac.new(
        WHATSAPP_APP_SECRET.encode('utf-8'), raw_body, hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature[len('sha256='):])


def _whatsapp_message_already_stored(wa_id):
    """Return True if a message with this WhatsApp id is already persisted."""
    if not wa_id or not supabase:
        return False
    try:
        existing = (
            supabase.table('messages')
            .select('id')
            .eq('whatsapp_message_id', wa_id)
            .limit(1)
            .execute()
        )
        return bool(existing.data)
    except Exception as e:
        logger.warning(f"Dedup lookup failed for {wa_id}: {e}")
        return False


@app.route('/webhook', methods=['POST'])
def handle_webhook():
    """Handle incoming WhatsApp messages"""
    raw_body = request.get_data()
    if not _verify_webhook_signature(raw_body):
        logger.warning("Rejected webhook with invalid signature")
        return jsonify({"error": "Invalid signature"}), 403

    data = request.get_json(silent=True) or {}

    # Check if it's a message event
    if data.get('object') == 'whatsapp_business_account':
        for entry in data.get('entry', []):
            for change in entry.get('changes', []):
                value = change.get('value', {})
                if 'messages' in value:
                    for message in value['messages']:
                        sender_phone = message.get('from')
                        wa_message_id = message.get('id')
                        message_type = message.get('type', 'text')

                        # Meta retries deliveries until it receives a 200, which
                        # can replay the same message — skip ones we already stored.
                        if _whatsapp_message_already_stored(wa_message_id):
                            logger.info(f"Skipping duplicate WhatsApp message {wa_message_id}")
                            continue

                        logger.info(f"Processing {message_type} message (wa_id={wa_message_id})")
                        process_incoming_wa_message(sender_phone, message)

        return jsonify({"status": "received"}), 200

    return jsonify({"error": "Invalid object"}), 400

def process_incoming_wa_message(phone, message):
    """Business logic for incoming WhatsApp messages"""
    try:
        if not supabase:
            print("Error: Supabase client not initialized.")
            return

        text = message.get('text', {}).get('body', '').strip()
        wa_id = message.get('id')
        raw_type = message.get('type', 'text')
        normalized_type = normalize_message_type(raw_type)
        media_payload = message.get(raw_type, {}) if raw_type != 'text' else {}
        caption = media_payload.get('caption', '').strip() if isinstance(media_payload, dict) else ''

        # 1. Find or create user profile
        # WhatsApp phones come in international format (e.g. 923001234567). Match
        # by exact phone first, then fall back to a suffix match of the last 10
        # digits with the wildcard ONLY on the leading side, so e.g. 1234567890
        # does not match 21234567890. Anchored "%suffix" gives at most one false
        # positive when two profiles share the same trailing digits.
        clean_phone = ''.join(ch for ch in phone if ch.isdigit())
        suffix = clean_phone[-10:] if len(clean_phone) >= 10 else clean_phone

        user_res = supabase.table('profiles').select('*').eq('phone', phone).execute()
        if not user_res.data and suffix:
            user_res = (
                supabase.table('profiles')
                .select('*')
                .like('phone', f'%{suffix}')
                .execute()
            )

        new_profile_full_name = None
        if not user_res.data:
            print(f"Creating new profile for WA user: {phone}")
            # Create a new profile for the WhatsApp user
            new_user_id = str(uuid.uuid4())
            new_profile_full_name = f"WA User {phone}"
            new_user = {
                "id": new_user_id,
                "full_name": new_profile_full_name,
                "phone": phone,
                "role": "user",
                "status": "active"
            }
            supabase.table('profiles').insert(new_user).execute()
            user_id = new_user_id
        else:
            user_id = user_res.data[0]['id']

        admin_profile = get_admin_profile()
        actual_admin_id = admin_profile['id'] if admin_profile else None

        # 2. Find or create conversation (Find ANY human conversation, whether app or whatsapp)
        conv_res = supabase.table('conversations').select('*').eq('user_id', user_id).neq('platform', 'ai_agent').order('updated_at', desc=True).limit(1).execute()
        
        if not conv_res.data:
            print(f"Creating new WA conversation for user_id: {user_id}")
            if not actual_admin_id:
                print("CRITICAL ERROR: Admin not found.")
                return

            conv_data = {
                "user_id": user_id,
                "admin_id": actual_admin_id,
                "platform": "whatsapp",
            }
            new_conv = supabase.table('conversations').insert(conv_data).execute()
            conversation_id = new_conv.data[0]['id']
        else:
            conversation_id = conv_res.data[0]['id']
            conversation_updates = {
                'platform': 'whatsapp',
                'updated_at': datetime.now(timezone.utc).isoformat()
            }
            if actual_admin_id and conv_res.data[0].get('admin_id') != actual_admin_id:
                conversation_updates['admin_id'] = actual_admin_id
            supabase.table('conversations').update(conversation_updates).eq('id', conversation_id).execute()

        # 3. Store message
        print(f"Storing WA message in DB. Conversation: {conversation_id}")
        if user_res.data:
            sender_name = user_res.data[0].get('full_name') or f'WA User {phone}'
        else:
            sender_name = new_profile_full_name or f'WA User {phone}'
        file_url = None
        if raw_type != 'text':
            try:
                file_url = store_whatsapp_media(phone, conversation_id, wa_id, raw_type, media_payload)
            except Exception as media_error:
                print(f"Failed to store WhatsApp media {wa_id}: {media_error}")

        stored_text = text or caption or default_message_text(raw_type)
        msg_data = {
            "conversation_id": conversation_id,
            "sender_id": user_id,
            "sender_name": sender_name,
            "sender_role": "user",
            "text": stored_text,
            "message_type": normalized_type,
            "file_url": file_url,
            "platform": "whatsapp",
            "whatsapp_message_id": wa_id
        }
        supabase.table('messages').insert(msg_data).execute()
        print("Message stored successfully.")
        
        # 4. Send FCM notification to admin
        if admin_profile and admin_profile.get('fcm_token'):
            send_fcm_notification(
                admin_profile['fcm_token'],
                f"New message from {sender_name}",
                stored_text[:100] + "..." if len(stored_text) > 100 else stored_text,
                {
                    "type": "chat_message",
                    "conversation_id": conversation_id,
                    "sender_id": user_id,
                    "platform": "whatsapp",
                }
            )
        
    except Exception as e:
        print(f"Error processing WA message: {e}")

# --- ADMIN API (Used by Flutter) ---

@app.route('/register-fcm-token', methods=['POST'])
def register_fcm_token():
    """Save or update the latest FCM token for a profile."""
    data = request.json or {}
    profile_id = data.get('profile_id') or data.get('user_id')
    fcm_token = data.get('fcm_token')

    if not profile_id:
        return jsonify({"error": "profile_id is required"}), 400

    try:
        upsert_profile_fcm_token(profile_id, fcm_token)
        return jsonify({"status": "success"})
    except Exception as e:
        print(f"Error registering FCM token: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/send-message', methods=['POST'])
@admin_required
def send_message():
    """Endpoint for Admin to send a message to WhatsApp"""
    data = request.get_json(silent=True) or {}

    conversation_id = data.get('conversation_id')
    message_text = data.get('message', '')
    recipient_phone = data.get('phone')
    message_type = normalize_message_type(data.get('message_type', 'text'))
    file_url = data.get('file_url')
    file_name = data.get('file_name')
    
    if not conversation_id or not recipient_phone or (not message_text and not file_url):
        return jsonify({"error": "Missing parameters"}), 400

    try:
        # Get user_id from conversation
        conv = supabase.table('conversations').select('user_id').eq('id', conversation_id).execute()
        if not conv.data:
            return jsonify({"error": "Conversation not found"}), 404
        user_id = conv.data[0]['user_id']
        if not WHATSAPP_TOKEN or not WHATSAPP_PHONE_NUMBER_ID:
            print("Error: WhatsApp credentials missing in backend .env")
            return jsonify({"error": "Backend configuration incomplete"}), 500

        # 1. Send via WhatsApp API
        url = f"https://graph.facebook.com/v19.0/{WHATSAPP_PHONE_NUMBER_ID}/messages"
        headers = {
            "Authorization": f"Bearer {WHATSAPP_TOKEN}",
            "Content-Type": "application/json"
        }
        payload = build_whatsapp_payload(
            recipient_phone=recipient_phone,
            message_text=message_text,
            message_type=message_type,
            file_url=file_url,
            file_name=file_name,
        )
        
        response = http_session.post(url, headers=headers, json=payload, timeout=DEFAULT_TIMEOUT)
        res_data = response.json()
        
        if response.status_code == 200:
            wa_id = res_data.get('messages', [{}])[0].get('id')
            
            admin_profile = get_admin_profile()
            actual_admin_id = admin_profile['id'] if admin_profile else None

            # 2. Store in Supabase
            if not actual_admin_id:
                print("Error: ADMIN_ID missing. Cannot store message sender.")
                return jsonify({"error": "Admin missing on backend"}), 500

            supabase.table('conversations').update({
                'admin_id': actual_admin_id,
                'platform': 'whatsapp',
                'updated_at': datetime.now(timezone.utc).isoformat()
            }).eq('id', conversation_id).execute()

            msg_data = {
                "conversation_id": conversation_id,
                "sender_id": actual_admin_id,
                "sender_name": admin_profile.get('full_name', 'Admin') if admin_profile else "Admin",
                "sender_role": "admin",
                "text": message_text or default_message_text(message_type),
                "message_type": message_type,
                "file_url": file_url,
                "platform": "whatsapp",
                "whatsapp_message_id": wa_id
            }
            supabase.table('messages').insert(msg_data).execute()
            print("Admin reply stored in DB.")
            
            # 3. Send FCM notification to user
            user_profile = supabase.table('profiles').select('fcm_token').eq('id', user_id).execute()
            if user_profile.data and user_profile.data[0].get('fcm_token'):
                send_fcm_notification(
                    user_profile.data[0]['fcm_token'],
                    "New message from Dr. Fizza",
                    (message_text or default_message_text(message_type))[:100] + "..." if len(message_text or default_message_text(message_type)) > 100 else (message_text or default_message_text(message_type)),
                    {
                        "type": "chat_message",
                        "conversation_id": conversation_id,
                        "sender_id": actual_admin_id,
                        "platform": "whatsapp",
                    }
                )
            
            return jsonify({"status": "success", "wa_id": wa_id})
        else:
            print(f"Meta API Error: {res_data}")
            return jsonify({"error": "WhatsApp API error", "details": res_data}), response.status_code
            
    except Exception as e:
        print(f"Backend send_message exception: {e}")
        return jsonify({"error": str(e)}), 500

# --- ADMIN CREATE USER ROUTE ---

@app.route('/admin/create-user', methods=['POST'])
@admin_required
def admin_create_user():
    """Admin endpoint to create a new auth user without disturbing the admin's session.

    The Flutter client uses this instead of supabase.auth.signUp() when an admin
    is creating/registering a user, because signUp would replace the admin's
    current session with the new user's session and break subsequent admin
    operations (e.g. updating that user's password right after).
    """
    data = request.get_json(silent=True) or {}
    email = (data.get('email') or '').strip()
    password = data.get('password') or ''
    full_name = (data.get('full_name') or '').strip()
    phone = (data.get('phone') or '').strip()
    existing_profile_id = data.get('existing_profile_id')

    if not email or not password:
        return jsonify({"error": "Email and password are required"}), 400
    if len(password) < 6:
        return jsonify({"error": "Password must be at least 6 characters long"}), 400

    if not SUPABASE_URL or not SUPABASE_KEY:
        return jsonify({"error": "Supabase is not configured"}), 500

    try:
        clean_phone = ''.join(ch for ch in phone if ch.isdigit())

        url = f"{SUPABASE_URL}/auth/v1/admin/users"
        headers = {
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "apikey": SUPABASE_ANON_KEY or SUPABASE_KEY,
            "Content-Type": "application/json",
        }
        payload = {
            "email": email,
            "password": password,
            "email_confirm": True,
            "user_metadata": {
                "full_name": full_name,
                "phone": clean_phone,
            },
        }

        response = http_session.post(url, headers=headers, json=payload, timeout=30)
        if response.status_code not in (200, 201):
            try:
                error_data = response.json()
                msg = error_data.get('msg') or error_data.get('message') or response.text
            except Exception:
                msg = response.text
            print(f"admin_create_user error {response.status_code}: {msg}")
            return jsonify({"error": msg}), response.status_code

        new_user = response.json() or {}
        new_user_id = new_user.get('id') or new_user.get('user', {}).get('id')

        if supabase and new_user_id:
            # If a WhatsApp-only profile already exists for this person, fold
            # the WhatsApp conversations onto the new authenticated profile and
            # remove the orphan profile so there are no duplicates.
            if existing_profile_id and existing_profile_id != new_user_id:
                try:
                    supabase.table('conversations').update({
                        'user_id': new_user_id
                    }).eq('user_id', existing_profile_id).execute()
                    supabase.table('messages').update({
                        'sender_id': new_user_id
                    }).eq('sender_id', existing_profile_id).execute()
                    supabase.table('profiles').delete().eq('id', existing_profile_id).execute()
                except Exception as merge_err:
                    print(f"admin_create_user merge warning: {merge_err}")

            # Make sure the profile row carries the latest details. The
            # handle_new_user trigger should have created the row already.
            try:
                supabase.table('profiles').update({
                    'full_name': full_name or None,
                    'email': email,
                    'phone': clean_phone or None,
                }).eq('id', new_user_id).execute()
            except Exception as profile_err:
                print(f"admin_create_user profile update warning: {profile_err}")

        return jsonify({"status": "success", "user_id": new_user_id})
    except Exception as e:
        print(f"admin_create_user exception: {e}")
        return jsonify({"error": str(e)}), 500

# --- ADMIN PASSWORD UPDATE ROUTE ---

@app.route('/admin/update-password', methods=['POST'])
@admin_required
def admin_update_password():
    """Admin endpoint to update a user's password.

    The admin's identity is verified by @admin_required (validates the Supabase
    JWT and confirms role == 'admin') before reaching this body.
    """
    data = request.get_json(silent=True) or {}
    user_id = data.get('user_id')
    new_password = data.get('new_password')

    if not all([user_id, new_password]):
        return jsonify({"error": "Missing required parameters"}), 400

    if len(new_password) < 6:
        return jsonify({"error": "Password must be at least 6 characters long"}), 400

    try:
        if not SUPABASE_URL or not SUPABASE_KEY:
            return jsonify({"error": "SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY not configured"}), 500

        url = f"{SUPABASE_URL}/auth/v1/admin/users/{user_id}"
        headers = {
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Content-Type": "application/json",
            "apikey": SUPABASE_ANON_KEY or SUPABASE_KEY,
        }
        payload = {"password": new_password}

        response = http_session.put(url, headers=headers, json=payload, timeout=DEFAULT_TIMEOUT)

        if response.status_code == 200:
            logger.info(f"Password updated successfully for user: {user_id}")
            return jsonify({"status": "success"})

        try:
            error_data = response.json()
            logger.warning(f"Supabase Admin API error ({response.status_code})")
            return jsonify({"error": error_data.get('message', 'Failed to update password')}), response.status_code
        except Exception:
            return jsonify({"error": f"Failed to update password (HTTP {response.status_code})"}), response.status_code

    except Exception as e:
        logger.exception("Error updating password")
        return jsonify({"error": "Failed to update password."}), 500

# --- AI CONSULTANT ROUTE ---

def _get_hardcoded_agent_response(message: str):
    """Return a hard-coded response when the user's message requests basic business/contact info."""
    if not message:
        return None
    m = message.lower()
    triggers = [
        'skin by dr fizza', 'dr fizza', 'contact', 'phone', '+923', '+971',
        'instagram', 'facebook', 'linkedin', 'quick links', 'home', 'about us',
        'services', 'shop', 'contact us', 'locations', 'islamabad', 'lahore',
        'karachi', 'al wasl', 'jumeirah', 'hours', 'mon - fri', 'sat - sun', 'helpful links'
    ]
    for t in triggers:
        if t in m:
            return (
                "Skin by Dr Fizza offers personalized skincare treatments that enhance your natural beauty for a radiant glow.\n\n"
                "Pakistan Contact:\n"
                "Phone: +923212831844\n"
                "Email: writeme@skinbydrfizza.com\n"
                "Address: Islamabad, Lahore, Karachi\n\n"
                "UAE Contact:\n"
                "Phone: +971 56 100 6767\n"
                "Email: writeme@skinbydrfizza.com\n"
                "Address: Al Wasl Jumeirah, UAE\n\n"
                "Follow us:\n"
                "Instagram: @skinbydrfizza\n"
                "Facebook: @skinbydrfizza\n\n"
                "Map: https://maps.app.goo.gl/LZ7F4uN2EeJ9QKkx8\n\n"
                "Social: Instagram, Facebook, Linkedin\n\n"
                "Quick links:\n"
                "- Home\n"
                "- About Us\n"
                "- Services\n"
                "- Shop\n"
                "- Contact Us\n\n"
                "Our Services:\n"
                "Your satisfaction is our priority\n"
                "We are dedicated to delivering exceptional beauty and skincare services that leave you feeling confident and radiant.\n\n"
                "- Custom facials\n"
                "- 4D Face Nonsurgical\n"
                "- Enzymes Based Treatments\n"
                "- Acne Scars\n"
                "- Dark Circles\n"
                "- Mole Removal\n\n"
                "Locations:\n"
                "- Islamabad, Pak\n"
                "- Lahore, Pak\n"
                "- Karachi, Pak\n"
                "- Al Wasl Jumeirah, UAE\n\n"
                "Hours:\n"
                "Mon - Fri: Flexible Hours\n"
                "Sat - Sun: Flexible Hours"
            )
    return None


@app.route('/chat', methods=['POST'])
def chat():
    data = request.get_json(silent=True) or {}
    user_message = (data.get('message') or '').strip()
    user_name = (data.get('user_name') or '').strip()

    if not user_message:
        return jsonify({"error": "No message provided"}), 400

    # Check for our hard-coded informational responses first (doesn't require OpenAI)
    hard_resp = _get_hardcoded_agent_response(user_message)
    if hard_resp:
        return jsonify({"response": hard_resp})

    if not openai_client:
        return jsonify({"error": "AI consultant is not configured."}), 503

    try:
        # 1. Get AI Response
        identity_context = (
            f"The current patient's registered name is {user_name}."
            if user_name
            else "The current patient is signed in, but no display name was provided."
        )
        response = openai_client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are a helpful AI skin care consultant for "
                        "'Skin By Dr. Fizza G' clinic. Keep responses helpful "
                        f"and concise. {identity_context}"
                    ),
                },
                {"role": "user", "content": user_message},
            ],
        )
        ai_message = response.choices[0].message.content

        # Persistence note: the Flutter client persists AI conversations to the
        # dedicated `ai_conversations` / `ai_messages` tables. We intentionally
        # do NOT write to the `messages` table here because:
        #   1. `messages.sender_id` has a NOT NULL FK to `profiles.id`, so the
        #      AI cannot be a valid sender without a real profile row.
        #   2. Duplicating into `messages` would double-store every AI turn.

        return jsonify({"response": ai_message})
    except Exception as e:
        logger.exception("AI Chat Error")
        return jsonify({"error": "Failed to generate a response. Please try again."}), 500

if __name__ == '__main__':
    # Use PORT from environment (required for Render)
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)
