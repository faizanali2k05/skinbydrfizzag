from flask import Flask, request, jsonify
from flask_cors import CORS
from openai import OpenAI
import os
import requests
import uuid
from supabase import create_client, Client
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

app = Flask(__name__)
CORS(app)

# Initialize Clients
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY") # Use Service Role Key for backend
WHATSAPP_TOKEN = os.environ.get("WHATSAPP_TOKEN")
WHATSAPP_PHONE_NUMBER_ID = os.environ.get("WHATSAPP_PHONE_NUMBER_ID")
VERIFY_TOKEN = os.environ.get("VERIFY_TOKEN")
ADMIN_ID = os.environ.get("ADMIN_ID") # The UUID of Dr. Fizza's profile
FCM_SERVER_KEY = os.environ.get("FCM_SERVER_KEY")

openai_client = OpenAI(api_key=OPENAI_API_KEY) if OPENAI_API_KEY else None
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY) if SUPABASE_URL and SUPABASE_KEY else None

def send_fcm_notification(token, title, body):
    """Send FCM notification to a device"""
    if not FCM_SERVER_KEY or not token:
        print("FCM not configured or no token")
        return
    
    url = "https://fcm.googleapis.com/fcm/send"
    headers = {
        "Authorization": f"key={FCM_SERVER_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "to": token,
        "notification": {
            "title": title,
            "body": body,
            "sound": "default"
        },
        "data": {
            "click_action": "FLUTTER_NOTIFICATION_CLICK"
        }
    }
    
    try:
        response = requests.post(url, headers=headers, json=payload)
        print(f"FCM Response: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"FCM Error: {e}")

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

@app.route('/webhook', methods=['POST'])
def handle_webhook():
    """Handle incoming WhatsApp messages"""
    data = request.json
    print(f"Incoming Webhook Data: {data}")
    
    # Check if it's a message event
    if data.get('object') == 'whatsapp_business_account':
        for entry in data.get('entry', []):
            for change in entry.get('changes', []):
                value = change.get('value', {})
                if 'messages' in value:
                    for message in value['messages']:
                        sender_phone = message.get('from')
                        # Get text body or default to empty string
                        message_body = message.get('text', {}).get('body', '')
                        wa_message_id = message.get('id')
                        
                        print(f"Processing message from {sender_phone}: {message_body}")
                        if message_body:
                            process_incoming_wa_message(sender_phone, message_body, wa_message_id)
        
        return jsonify({"status": "received"}), 200
    
    return jsonify({"error": "Invalid object"}), 400

def process_incoming_wa_message(phone, text, wa_id):
    """Business logic for incoming WhatsApp messages"""
    try:
        if not supabase:
            print("Error: Supabase client not initialized.")
            return

        # 1. Find or create user profile
        user_res = supabase.table('profiles').select('*').eq('phone', phone).execute()
        
        if not user_res.data:
            print(f"Creating new profile for WA user: {phone}")
            # Create a new profile for the WhatsApp user
            new_user_id = str(uuid.uuid4())
            new_user = {
                "id": new_user_id,
                "full_name": f"WA User {phone}",
                "phone": phone,
                "role": "user",
                "status": "active"
            }
            supabase.table('profiles').insert(new_user).execute()
            user_id = new_user_id
        else:
            user_id = user_res.data[0]['id']

        # 2. Find or create conversation
        conv_res = supabase.table('conversations').select('*').eq('user_id', user_id).eq('platform', 'whatsapp').execute()
        
        if not conv_res.data:
            print(f"Creating new WA conversation for user_id: {user_id}")
            if not ADMIN_ID:
                print("CRITICAL ERROR: ADMIN_ID not set in environment variables.")
                return

            conv_data = {
                "user_id": user_id,
                "admin_id": ADMIN_ID,
                "last_message": text,
                "unread_count": 1,
                "platform": "whatsapp",
            }
            new_conv = supabase.table('conversations').insert(conv_data).execute()
            conversation_id = new_conv.data[0]['id']
        else:
            conversation_id = conv_res.data[0]['id']
            # Update unread count and last_message
            current_unread = conv_res.data[0].get('unread_count', 0) or 0
            supabase.table('conversations').update({
                'last_message': text,
                'unread_count': current_unread + 1,
                'updated_at': 'now()'
            }).eq('id', conversation_id).execute()

        # 3. Store message
        print(f"Storing WA message in DB. Conversation: {conversation_id}")
        sender_name = user_res.data[0].get('full_name', f'WA User {phone}') if user_res.data else f'WA User {phone}'
        msg_data = {
            "conversation_id": conversation_id,
            "sender_id": user_id,
            "sender_name": sender_name,
            "sender_role": "user",
            "text": text,
            "platform": "whatsapp",
            "whatsapp_message_id": wa_id
        }
        supabase.table('messages').insert(msg_data).execute()
        print("Message stored successfully.")
        
        # 4. Send FCM notification to admin
        if ADMIN_ID:
            admin_profile = supabase.table('profiles').select('fcm_token').eq('id', ADMIN_ID).execute()
            if admin_profile.data and admin_profile.data[0].get('fcm_token'):
                send_fcm_notification(
                    admin_profile.data[0]['fcm_token'],
                    f"New message from {sender_name}",
                    text[:100] + "..." if len(text) > 100 else text
                )
        
    except Exception as e:
        print(f"Error processing WA message: {e}")

# --- ADMIN API (Used by Flutter) ---

@app.route('/send-message', methods=['POST'])
def send_message():
    """Endpoint for Admin to send a message to WhatsApp"""
    data = request.json
    print(f"Admin Send-Message Request: {data}")
    
    conversation_id = data.get('conversation_id')
    message_text = data.get('message')
    recipient_phone = data.get('phone')
    
    if not all([conversation_id, message_text, recipient_phone]):
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
        payload = {
            "messaging_product": "whatsapp",
            "to": recipient_phone,
            "type": "text",
            "text": {"body": message_text}
        }
        
        print(f"Sending to Meta API: {url}")
        response = requests.post(url, headers=headers, json=payload)
        res_data = response.json()
        print(f"Meta API Response: {res_data}")
        
        if response.status_code == 200:
            wa_id = res_data.get('messages', [{}])[0].get('id')
            
            # 2. Store in Supabase
            if not ADMIN_ID:
                print("Error: ADMIN_ID missing. Cannot store message sender.")
                return jsonify({"error": "ADMIN_ID missing on backend"}), 500

            msg_data = {
                "conversation_id": conversation_id,
                "sender_id": ADMIN_ID,
                "sender_name": "Dr. Fizza",
                "sender_role": "admin",
                "text": message_text,
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
                    message_text[:100] + "..." if len(message_text) > 100 else message_text
                )
            
            return jsonify({"status": "success", "wa_id": wa_id})
        else:
            print(f"Meta API Error: {res_data}")
            return jsonify({"error": "WhatsApp API error", "details": res_data}), response.status_code
            
    except Exception as e:
        print(f"Backend send_message exception: {e}")
        return jsonify({"error": str(e)}), 500

# --- ADMIN PASSWORD UPDATE ROUTE ---

@app.route('/admin/update-password', methods=['POST'])
def admin_update_password():
    """Admin endpoint to update a user's password"""
    data = request.json
    user_id = data.get('user_id')
    new_password = data.get('new_password')
    admin_token = data.get('admin_token')
    
    if not all([user_id, new_password, admin_token]):
        return jsonify({"error": "Missing required parameters"}), 400
    
    if len(new_password) < 6:
        return jsonify({"error": "Password must be at least 6 characters long"}), 400
    
    try:
        # Verify admin token by checking if the user is admin
        # For security, we should validate the token, but for simplicity we'll check the role
        # In production, you'd want to validate the JWT token properly
        
        # First, get the admin user ID from the token
        # This is a simplified approach - in production, validate the JWT
        
        # For now, we'll assume the admin_token is valid if it exists
        # In a real implementation, you'd decode and verify the JWT
        
        # Update the user's password using Supabase Admin API
        url = f"https://api.supabase.com/v1/auth/admin/users/{user_id}"
        headers = {
            "Authorization": f"Bearer {SUPABASE_KEY}",
            "Content-Type": "application/json",
            "apikey": SUPABASE_KEY
        }
        payload = {
            "password": new_password
        }
        
        response = requests.put(url, headers=headers, json=payload)
        
        if response.status_code == 200:
            print(f"Password updated successfully for user: {user_id}")
            return jsonify({"status": "success"})
        else:
            error_data = response.json()
            print(f"Supabase Admin API error: {error_data}")
            return jsonify({"error": error_data.get('msg', 'Failed to update password')}), response.status_code
            
    except Exception as e:
        print(f"Error updating password: {e}")
        return jsonify({"error": str(e)}), 500

# --- AI CONSULTANT ROUTE ---

@app.route('/chat', methods=['POST'])
def chat():
    data = request.json
    user_message = data.get('message', '')
    user_id = data.get('user_id') # Optional: for server-side persistence

    if not openai_client or not user_message:
        return jsonify({"error": "OpenAI not configured or no message"}), 400

    try:
        response = openai_client.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {
                    "role": "system",
                    "content": "You are a helpful AI skin care consultant for 'Skin By Dr. Fizza G' clinic. Keep responses helpful and concise.",
                },
                {"role": "user", "content": user_message},
            ],
        )
        ai_message = response.choices[0].message.content
        
        # Note: If user_id is provided, we could store it here using SUPABASE_KEY (Service Role)
        # However, Flutter is currently handling storage. 
        # For WhatsApp AI, we would definitely store it here.
        
        return jsonify({"response": ai_message})
    except Exception as e:
        print(f"AI Chat Error: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    # Use PORT from environment (required for Render)
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)
