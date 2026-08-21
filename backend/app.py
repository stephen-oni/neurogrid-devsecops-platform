from flask import Flask, request, jsonify, session
import mysql.connector
from mysql.connector import pooling
from flask_bcrypt import Bcrypt
from flask_cors import CORS
from prometheus_flask_exporter import PrometheusMetrics
from werkzeug.middleware.proxy_fix import ProxyFix
import os
import datetime


app = Flask(__name__)

# Correctly handle headers (X-Forwarded-For, X-Forwarded-Proto) from ALB & CloudFront
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1)

# Initialize Prometheus Metrics (Exposes /metrics on port 5000)
metrics = PrometheusMetrics(app)

# Allow credentials & cookies from frontend.
CORS(app, supports_credentials=True)

# Shared secret key across all EC2 nodes (Required for multi-instance ASG sessions)
app.secret_key = os.getenv('SECRET_KEY', 'neurogrid_production_fallback_secret_key_12345')
bcrypt = Bcrypt(app)

# Cookie security settings for HTTPS behind CloudFront / ALB
is_production = os.getenv('FLASK_ENV') == 'production'
app.config.update(
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE='None' if is_production else 'Lax',
    SESSION_COOKIE_SECURE=True if is_production else False
)

# Database Connection Pool Configuration
db_pool = mysql.connector.pooling.MySQLConnectionPool(
    pool_name="neurogrid_pool",
    pool_size=10,
    pool_reset_session=True,
    host=os.getenv('DB_HOST', 'db'),
    user=os.getenv('DB_USER', 'root'),
    password=os.getenv('DB_PASSWORD', 'dev_password_123'),
    database=os.getenv('DB_NAME', 'neurogrid_db')
)

def get_db_connection():
    """Fetches an active connection from the pool."""
    return db_pool.get_connection()

def get_client_ip():
    """Extract real client IP passed through CloudFront and ALB."""
    if request.headers.get('X-Forwarded-For'):
        return request.headers.get('X-Forwarded-For').split(',')[0].strip()
    return request.headers.get('X-Real-IP', request.remote_addr)

#  HEALTH & METRICS 

@app.route('/health', methods=['GET'])
def health():
    """ALB root health check endpoint."""
    return jsonify({"status": "healthy"}), 200

#  AUTHENTICATION ENDPOINTS 

@app.route('/api/signup', methods=['POST'])
def signup():
    """Handles new user registration and enforces 1 account per IP."""
    data = request.get_json() or {}
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"status": "error", "message": "Username and password are required."}), 400
    
    user_ip = get_client_ip()
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        
        #  Enforce 1 account per IP
        cursor.execute("SELECT id FROM users WHERE ip_address = %s", (user_ip,))
        if cursor.fetchone():
            return jsonify({"status": "error", "message": "An account has already been created from this IP address."}), 403
            
        #  Enforce unique username
        cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
        if cursor.fetchone():
            return jsonify({"status": "error", "message": "Username is already taken."}), 409

        # Hash password securely
        hashed_password = bcrypt.generate_password_hash(password).decode('utf-8')
        
        cursor.execute(
            "INSERT INTO users (username, password, ip_address, failed_attempts) VALUES (%s, %s, %s, 0)", 
            (username, hashed_password, user_ip)
        )
        conn.commit()
        return jsonify({"status": "success", "message": "Account created successfully"}), 201

    except mysql.connector.Error as err:
        return jsonify({"status": "error", "message": f"Database Error: {err}"}), 500
    finally:
        if cursor:
            cursor.close()
        if conn and conn.is_connected():
            conn.close()

@app.route('/api/login', methods=['POST'])
def login():
    """Handles user authentication and enforces the 3-strike lockout rule."""
    data = request.get_json() or {}
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"status": "error", "message": "Username and password are required."}), 400
    
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM users WHERE username = %s", (username,))
        user = cursor.fetchone()
        
        if not user:
            return jsonify({"status": "error", "message": "Invalid credentials. Please try again."}), 401

        # Account lockout check
        if user['failed_attempts'] >= 3:
            return jsonify({"status": "error", "message": "Account locked due to too many failed login attempts."}), 403
            
        # Password Verification
        if bcrypt.check_password_hash(user['password'], password):
            cursor.execute("UPDATE users SET failed_attempts = 0 WHERE username = %s", (username,))
            conn.commit()
            session['user'] = username
            return jsonify({"status": "success", "message": "Logged in successfully"}), 200
        else:
            new_attempts = user['failed_attempts'] + 1
            cursor.execute("UPDATE users SET failed_attempts = %s WHERE username = %s", (new_attempts, username))
            conn.commit()
            
            if new_attempts >= 3:
                return jsonify({"status": "error", "message": "Account locked due to too many failed login attempts."}), 403
                
            return jsonify({"status": "error", "message": f"Invalid credentials. Failed attempts: {new_attempts}/3"}), 401

    except mysql.connector.Error as err:
        return jsonify({"status": "error", "message": f"Database Error: {err}"}), 500
    finally:
        if cursor:
            cursor.close()
        if conn and conn.is_connected():
            conn.close()

@app.route('/api/user', methods=['GET'])
def get_user():
    """Validates the active session for frontend page guards and ALB health probe."""
    if 'user' in session:
        return jsonify({"status": "success", "username": session['user']}), 200
    return jsonify({"status": "error", "message": "Not authenticated"}), 401

@app.route('/api/logout', methods=['POST'])
def logout():
    """Destroys the active session."""
    session.pop('user', None)
    return jsonify({"status": "success", "message": "Logged out successfully"}), 200

# ELIGIBILITY FORM ENDPOINTS 

@app.route('/api/eligibility/submit', methods=['POST'])
def submit_eligibility():
    """Calculates implant eligibility score and saves record to neural_assessments."""
    if 'user' not in session:
        return jsonify({"status": "error", "message": "Unauthorized. Please sign in."}), 401

    data = request.get_json() or {}
    synapse_speed = int(data.get('synapse_speed_ms', 0))
    rejection_tolerance = int(data.get('rejection_tolerance_pct', 0))
    cortex_voltage = float(data.get('cortex_voltage', 0.0))
    nanite_count = int(data.get('nanite_count', 0))

    # Scoring Algorithm
    score = 0
    if 1 <= synapse_speed <= 25:
        score += 30
    elif synapse_speed <= 50:
        score += 15

    if rejection_tolerance >= 80:
        score += 30
    elif rejection_tolerance >= 50:
        score += 15

    if 3.0 <= cortex_voltage <= 5.0:
        score += 20
    elif cortex_voltage > 1.0:
        score += 10

    if nanite_count >= 5000:
        score += 20
    elif nanite_count >= 2000:
        score += 10

    # Decision Tier Assignment
    if score >= 80:
        implant_tier = "CLASS-4 COMBAT READY"
    elif score >= 50:
        implant_tier = "CLASS-2 CIVILIAN GRADE"
    else:
        implant_tier = "INCOMPATIBLE / NEURAL REJECTION RISK"

    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)

        cursor.execute("SELECT id FROM users WHERE username = %s", (session['user'],))
        user_row = cursor.fetchone()
        if not user_row:
            return jsonify({"status": "error", "message": "User not found."}), 404

        user_id = user_row['id']

        cursor.execute("""
            INSERT INTO neural_assessments 
            (user_id, synapse_speed_ms, rejection_tolerance_pct, cortex_voltage, nanite_count, compatibility_score, implant_tier) 
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (user_id, synapse_speed, rejection_tolerance, cortex_voltage, nanite_count, score, implant_tier))
        conn.commit()

        return jsonify({
            "status": "success",
            "score": score,
            "implant_tier": implant_tier
        }), 201

    except mysql.connector.Error as err:
        return jsonify({"status": "error", "message": f"Database Error: {err}"}), 500
    finally:
        if cursor:
            cursor.close()
        if conn and conn.is_connected():
            conn.close()

@app.route('/api/eligibility/status', methods=['GET'])
def get_eligibility_status():
    """Retrieves the latest submitted assessment for the currently logged-in user."""
    if 'user' not in session:
        return jsonify({"status": "error", "message": "Unauthorized. Please sign in."}), 401

    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor(dictionary=True)
        cursor.execute("""
            SELECT na.* FROM neural_assessments na
            JOIN users u ON na.user_id = u.id
            WHERE u.username = %s
            ORDER BY na.id DESC LIMIT 1
        """, (session['user'],))
        record = cursor.fetchone()

        if not record:
            return jsonify({"status": "error", "message": "No assessment records found."}), 404

        if record.get('submitted_at') and isinstance(record['submitted_at'], (datetime.datetime, datetime.date)):
            record['submitted_at'] = record['submitted_at'].strftime('%Y-%m-%d %H:%M:%S')

        if record.get('cortex_voltage') is not None:
            record['cortex_voltage'] = float(record['cortex_voltage'])

        return jsonify({"status": "success", "data": record}), 200

    except mysql.connector.Error as err:
        return jsonify({"status": "error", "message": f"Database Error: {err}"}), 500
    finally:
        if cursor:
            cursor.close()
        if conn and conn.is_connected():
            conn.close()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)