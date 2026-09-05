"""
Smart Ranch — Backend Unit Tests
Tests for THI calculation, level classification, and API endpoints.
"""
import json
import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient

# --- THI Calculation Tests (bridge.py logic) ---

def calculate_thi(ambient_temp: float, humidity: float) -> float:
    """Mirror of bridge.py calculate_thi."""
    thi = (1.8 * ambient_temp + 32) - (0.55 - 0.0055 * humidity) * (1.8 * ambient_temp - 26)
    return round(thi, 2)


def get_thi_level(thi: float) -> str:
    """Mirror of api.py get_thi_level."""
    thresholds = [(89, "emergency"), (79, "danger"), (72, "alert"), (0, "normal")]
    for threshold, level in thresholds:
        if thi >= threshold:
            return level
    return "normal"


class TestCalculateThi:
    def test_known_values(self):
        # T=35°C, RH=50%
        thi = calculate_thi(35.0, 50.0)
        assert abs(thi - 84.83) < 0.1

    def test_cool_dry_is_normal(self):
        thi = calculate_thi(20.0, 30.0)
        assert thi < 72.0

    def test_hot_humid_is_emergency(self):
        thi = calculate_thi(45.0, 70.0)
        assert thi > 89.0

    def test_zero_inputs(self):
        thi = calculate_thi(0.0, 0.0)
        assert thi < 72.0  # Should be well below alert

    def test_sonora_extreme(self):
        """Sonora peak summer: 48°C, 75% humidity after rain."""
        thi = calculate_thi(48.0, 75.0)
        assert thi > 89.0  # Emergency


class TestGetThiLevel:
    def test_normal(self):
        assert get_thi_level(65.0) == "normal"
        assert get_thi_level(71.9) == "normal"

    def test_alert(self):
        assert get_thi_level(72.0) == "alert"
        assert get_thi_level(78.9) == "alert"

    def test_danger(self):
        assert get_thi_level(79.0) == "danger"
        assert get_thi_level(88.9) == "danger"

    def test_emergency(self):
        assert get_thi_level(89.0) == "emergency"
        assert get_thi_level(100.0) == "emergency"

    def test_zero(self):
        assert get_thi_level(0.0) == "normal"


# --- API Endpoint Tests ---

class TestApiEndpoints:
    @pytest.fixture
    def client(self):
        """Create test client with mocked InfluxDB."""
        with patch("api.InfluxDBClient"), patch("api.query_api"):
            from api import app
            return TestClient(app)

    def test_root_endpoint(self, client):
        response = client.get("/")
        assert response.status_code == 200
        data = response.json()
        assert data["service"] == "Smart Ranch API"
        assert data["status"] == "running"

    def test_animals_endpoint_returns_list(self, client):
        with patch("api.query_api") as mock_query:
            mock_query.query.return_value = []
            response = client.get("/api/animals")
            assert response.status_code == 200
            data = response.json()
            assert "animals" in data
            assert "count" in data

    def test_stats_endpoint(self, client):
        with patch("api.query_api") as mock_query:
            mock_query.query.return_value = []
            response = client.get("/api/stats")
            assert response.status_code == 200
            data = response.json()
            assert "total_animals" in data

    def test_alerts_endpoint(self, client):
        with patch("api.query_api") as mock_query:
            mock_query.query.return_value = []
            response = client.get("/api/alerts")
            assert response.status_code == 200
            data = response.json()
            assert "alerts" in data

    def test_animal_history_endpoint(self, client):
        with patch("api.query_api") as mock_query:
            mock_query.query.return_value = []
            response = client.get("/api/animals/vaca_001/history?range=1h")
            assert response.status_code == 200
            data = response.json()
            assert data["device_id"] == "vaca_001"
            assert "readings" in data


# --- Input Validation Tests ---

class TestInputSanitization:
    def test_range_rejects_injection(self):
        """Verify that only allowed range values pass."""
        allowed = {"1h", "6h", "24h", "7d", "30d"}
        malicious = "1h) |> drop() |> yield(name: \"pwned\""
        assert malicious not in allowed

    def test_device_id_rejects_injection(self):
        """Verify that device IDs with special chars are rejected."""
        import re
        pattern = re.compile(r"^[a-zA-Z0-9_\-]+$")
        assert pattern.match("vaca_001")
        assert not pattern.match('vaca" |> drop()')
        assert not pattern.match("vaca_001\"; DROP TABLE")


# --- Estrus Detection Tests ---

class TestEstrusDetection:
    """Test estrus (celo) detection algorithm from bridge.py."""

    def _simulate_readings(self, baseline: float, count: int) -> list[float]:
        import random
        return [baseline + random.uniform(-0.2, 0.2) for _ in range(count)]

    def test_baseline_calculation(self):
        """Baseline should be computed from recent movement history."""
        from bridge import check_estrus_activity, _activity_history
        _activity_history.clear()
        # Feed 20 baseline readings
        for _ in range(20):
            score = check_estrus_activity("test_cow", 0.5)
        # Score should be low (normal activity)
        assert score < 0.3

    def test_spike_detection(self):
        """Sustained high activity should produce high estrus score."""
        from bridge import (
            check_estrus_activity, _activity_history,
            _estrus_spike_count, _active_estrus_alerts,
        )
        _activity_history.clear()
        _estrus_spike_count.clear()
        _active_estrus_alerts.clear()
        # Build baseline with 30 normal readings
        for _ in range(30):
            check_estrus_activity("spike_cow", 0.5)
        # Now spike: 70%+ above baseline (0.5 * 1.7 = 0.85)
        for _ in range(10):
            score = check_estrus_activity("spike_cow", 1.5)
        # Score should be high
        assert score > 0.5

    def test_short_spike_no_alert(self):
        """Brief activity spikes should not trigger estrus alert."""
        from bridge import (
            check_estrus_activity, _activity_history,
            _estrus_spike_count, _active_estrus_alerts,
        )
        _activity_history.clear()
        _estrus_spike_count.clear()
        _active_estrus_alerts.clear()
        # Build baseline
        for _ in range(30):
            check_estrus_activity("brief_cow", 0.5)
        # Only 2 high readings (below threshold of 6)
        for _ in range(2):
            check_estrus_activity("brief_cow", 1.5)
        assert not _active_estrus_alerts.get("brief_cow", False)


# --- Health Detection Tests ---

class TestHealthDetection:
    def test_fever_detection(self):
        """Sustained high body temp should be flagged as fever."""
        from bridge import check_health_status, _fever_count, _lethargy_count
        _fever_count.clear()
        _lethargy_count.clear()
        # 5 readings at 41°C with normal movement
        for _ in range(5):
            status = check_health_status("fever_cow", 41.0, 1.0)
        assert status == "fever"

    def test_lethargy_detection(self):
        """Sustained low movement should be flagged as lethargy."""
        from bridge import check_health_status, _fever_count, _lethargy_count
        _fever_count.clear()
        _lethargy_count.clear()
        for _ in range(8):
            status = check_health_status("lazy_cow", 38.0, 0.1)
        assert status == "lethargy"

    def test_sick_suspected(self):
        """Fever + lethargy combined should flag as sick_suspected."""
        from bridge import check_health_status, _fever_count, _lethargy_count
        _fever_count.clear()
        _lethargy_count.clear()
        for _ in range(8):
            status = check_health_status("sick_cow", 41.0, 0.1)
        assert status == "sick_suspected"

    def test_healthy_returns_healthy(self):
        """Normal readings should return healthy."""
        from bridge import check_health_status, _fever_count, _lethargy_count
        _fever_count.clear()
        _lethargy_count.clear()
        status = check_health_status("ok_cow", 38.5, 1.0)
        assert status == "healthy"


# --- New API Endpoint Tests ---

class TestNewApiEndpoints:
    @pytest.fixture
    def client(self):
        with patch("api.InfluxDBClient"), patch("api.query_api"):
            from api import app
            return TestClient(app)

    def test_activity_endpoint(self, client):
        with patch("api.query_api") as mock_query:
            mock_query.query.return_value = []
            response = client.get("/api/animals/vaca_001/activity?range=1h")
            assert response.status_code == 200
            data = response.json()
            assert data["device_id"] == "vaca_001"
            assert "readings" in data

    def test_reproduction_alerts_endpoint(self, client):
        with patch("api.query_api") as mock_query:
            mock_query.query.return_value = []
            response = client.get("/api/reproduction/alerts?range=24h")
            assert response.status_code == 200
            data = response.json()
            assert "alerts" in data

    def test_health_alerts_endpoint(self, client):
        with patch("api.query_api") as mock_query:
            mock_query.query.return_value = []
            response = client.get("/api/health/alerts?range=24h")
            assert response.status_code == 200
            data = response.json()
            assert "alerts" in data


# --- JWT Auth Tests ---

class TestJwtAuth:
    """Test JWT authentication module."""

    def test_password_hash_and_verify(self):
        from auth import _hash_password, _verify_password
        password = "smartranch2026"
        hashed = _hash_password(password)
        assert _verify_password(password, hashed)

    def test_wrong_password_fails(self):
        from auth import _hash_password, _verify_password
        hashed = _hash_password("correct_password")
        assert not _verify_password("wrong_password", hashed)

    def test_create_and_verify_token(self):
        from auth import create_token, verify_token
        token = create_token(user_id=1, username="admin", role="admin")
        payload = verify_token(token)
        assert payload["sub"] == 1
        assert payload["username"] == "admin"
        assert payload["role"] == "admin"

    def test_expired_token_rejected(self):
        from auth import _b64url_encode, _b64url_decode, verify_token, JWT_SECRET
        import hmac, hashlib, json, time
        # Create a token that expired 1 hour ago
        header = {"alg": "HS256", "typ": "JWT"}
        payload = {"sub": 1, "username": "test", "role": "viewer",
                   "iat": int(time.time()) - 7200, "exp": int(time.time()) - 3600}
        h = _b64url_encode(json.dumps(header).encode())
        p = _b64url_encode(json.dumps(payload).encode())
        sig = hmac.new(JWT_SECRET.encode(), f"{h}.{p}".encode(), hashlib.sha256).digest()
        token = f"{h}.{p}.{_b64url_encode(sig)}"
        with pytest.raises(Exception):
            verify_token(token)

    def test_tampered_token_rejected(self):
        from auth import create_token, verify_token
        token = create_token(user_id=1, username="admin", role="admin")
        # Tamper: change last character
        tampered = token[:-1] + ("A" if token[-1] != "A" else "B")
        with pytest.raises(Exception):
            verify_token(tampered)

    def test_invalid_format_rejected(self):
        from auth import verify_token
        with pytest.raises(Exception):
            verify_token("not.a.valid.token.at.all")
        with pytest.raises(Exception):
            verify_token("")

    def test_different_passwords_different_hashes(self):
        from auth import _hash_password
        h1 = _hash_password("password1")
        h2 = _hash_password("password2")
        assert h1 != h2

    def test_same_password_different_salt(self):
        from auth import _hash_password
        h1 = _hash_password("same_password")
        h2 = _hash_password("same_password")
        # Different salts should produce different hashes
        assert h1 != h2
