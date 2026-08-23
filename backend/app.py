from flask import Flask, request, jsonify, session
import pymysql
from dbutils.pooled_db import PooledDB
from flask_bcrypt import Bcrypt
from flask_cors import CORS
from prometheus_flask_exporter import PrometheusMetrics
from werkzeug.middleware.proxy_fix import ProxyFix
import os
import time
import datetime

app = Flask(__name__)

# CloudFront (Hop 1) + ALB (Hop 2) -> trace back to real client IP
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=2, x_proto=2, x_host=2)

# Initialize Prometheus Metrics (Exposes /metrics)
metrics = PrometheusMetrics(app)

# Allow credentials & cookies from frontend
CORS(app, supports_credentials=True)

# Shared secret key across all EC2 nodes
app.secret_key = os.getenv('SECRET_KEY', 'neurogrid_production_fallback_secret_key_12345')
bcrypt = Bcrypt(app)

# Cookie security settings for HTTPS behind CloudFront / ALB
is_production = os.getenv('FLASK_ENV') == 'production'
app.config.update(
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE='None' if is_production else 'Lax',
    SESSION_COOKIE_SECURE=True if is_production else False
)

# Global pool reference initialized lazily with retries and port parsing
db_pool = None

def get_db_pool():
    global db_pool
    if db_pool is None:
        raw_db_host = os.getenv('DB_HOST', 'db').strip()
        db_port = 3306

        # Strip protocol or port suffixes if passed accidentally
        if '://' in raw_db_host:
            raw_db_host = raw_db_host.split('://')[1]

        if ':' in raw_db_host:
            parts = raw_db_host.split(':')
            db_host = parts[0].strip()
            try:
                db_port = int(parts[1].strip())
            except (ValueError, IndexError):
                db_port = 3306
        else:
            db_host = raw_db_host

        if os.getenv('DB_PORT'):
            try:
                db_port = int(os.getenv('DB_PORT').strip())
            except ValueError:
                db_port = 3306

        db_user = os.getenv('DB_USER', 'root').strip()
        db_password = os.getenv('DB_PASSWORD', 'dev_password_123').strip()
        db_name = os.getenv('DB_NAME', 'neurogrid_db').strip()

        retries = 5
        while retries > 0:
            try:
                db_pool = PooledDB(
                    creator=pymysql,
                    maxconnections=10,
                    mincached=2,
                    maxcached=5,
                    blocking=True,
                    host=str(db_host),
                    port=int(db_port),
                    user=str(db_user),
                    password=str(db_password),
                    database=str(db_name),
                    cursorclass=pymysql.cursors.DictCursor,
                    connect_timeout=10,
                    autocommit=False
                )
                break
            except Exception as e:
                retries -= 1
                time.sleep(2)
                if retries == 0:
                    raise e
    return db_pool

def get_db_connection():
    """Fetches an active connection from the pool."""
    pool = get_db_pool()
    return pool.connection()

def init_db():
    """Automatically create required tables on startup if they do not exist."""
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            # Users table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    username VARCHAR(100) NOT NULL UNIQUE,
                    password VARCHAR(255) NOT NULL,
                    ip_address VARCHAR(45) NOT NULL,
                    failed_attempts INT DEFAULT 0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
            """)

            # Neural Assessments table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS neural_assessments (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    user_id INT NOT NULL,
                    synapse_speed_ms INT NOT NULL,
                    rejection_tolerance_pct INT NOT NULL,
                    cortex_voltage DECIMAL(5,2) NOT NULL,
                    nanite_count INT NOT NULL,
                    compatibility_score INT NOT NULL,
                    implant_tier VARCHAR(100) NOT NULL,
                    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                );
            """)
        conn.commit()
    except Exception as e:
        print(f"Warning: Database initialization failed during boot: {e}")
    finally:
        if conn:
            conn.close()

# Auto-initialize database tables on container start
try:
    init_db()
except Exception as e:
    print(f"Startup DB init error: {e}")

def get_client_ip():
    """Extract real client IP passed through CloudFront and ALB."""
    forwarded_for = request.headers.get('X-Forwarded-For')
    if forwarded_for:
        return forwarded_for.split(',')[0].strip()
    return request.headers.get('X-Real-IP', request.remote_addr)

# HEALTH & METRICS 

@app.route('/health', methods=['GET'])
def health():
    """ALB root health check endpoint."""
    return jsonify({"status": "healthy"}), 200

# AUTHENTICATION ENDPOINTS 

@app.route('/api/signup', methods=['POST'])
def signup():
    """Handles new user registration and enforces 1 account per IP."""
    data = request.get_json(silent=True) or {}
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"status": "error", "message": "Username and password are required."}), 400
    
    user_ip = get_client_ip()
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            # Enforce 1 account per IP
            cursor.execute("SELECT id FROM users WHERE ip_address = %s", (user_ip,))
            if cursor.fetchone():
                return jsonify({
                    "status": "error", 
                    "message": f"An account has already been created from this IP address ({user_ip})."
                }), 403
                
            # Enforce unique username
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

    except Exception as err:
        return jsonify({"status": "error", "message": f"Database Error: {str(err)}"}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/login', methods=['POST'])
def login():
    """Handles user authentication and enforces the 3-strike lockout rule."""
    data = request.get_json(silent=True) or {}
    username = data.get('username')
    password = data.get('password')

    if not username or not password:
        return jsonify({"status": "error", "message": "Username and password are required."}), 400
    
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
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

    except Exception as err:
        return jsonify({"status": "error", "message": f"Database Error: {str(err)}"}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/user', methods=['GET'])
def get_user():
    """Validates the active session for frontend page guards."""
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

    data = request.get_json(silent=True) or {}
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
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
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

    except Exception as err:
        return jsonify({"status": "error", "message": f"Database Error: {str(err)}"}), 500
    finally:
        if conn:
            conn.close()

@app.route('/api/eligibility/status', methods=['GET'])
def get_eligibility_status():
    """Retrieves the latest submitted assessment for the currently logged-in user."""
    if 'user' not in session:
        return jsonify({"status": "error", "message": "Unauthorized. Please sign in."}), 401

    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
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

    except Exception as err:
        return jsonify({"status": "error", "message": f"Database Error: {str(err)}"}), 500
    finally:
        if conn:
            conn.close()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)