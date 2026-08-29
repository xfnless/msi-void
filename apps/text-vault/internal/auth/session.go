package auth

import (
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"sync"
	"time"
)

const cookieName = "text_vault_session"

type session struct {
	csrf      string
	expiresAt time.Time
}

type Manager struct {
	tokenHash    [32]byte
	secureCookie bool
	mu           sync.RWMutex
	sessions     map[[32]byte]session
}

func New(accessToken string, secureCookie bool) (*Manager, error) {
	if len(accessToken) < 16 {
		return nil, errors.New("access token must contain at least 16 characters")
	}
	return &Manager{
		tokenHash:    sha256.Sum256([]byte(accessToken)),
		secureCookie: secureCookie,
		sessions:     make(map[[32]byte]session),
	}, nil
}

func (m *Manager) Login(w http.ResponseWriter, r *http.Request) bool {
	defer r.Body.Close()
	decoder := json.NewDecoder(io.LimitReader(r.Body, 8<<10))
	decoder.DisallowUnknownFields()
	var input struct {
		Token string `json:"token"`
	}
	if decoder.Decode(&input) != nil {
		writeError(w, http.StatusBadRequest, "invalid_request")
		return false
	}
	candidate := sha256.Sum256([]byte(input.Token))
	if subtle.ConstantTimeCompare(candidate[:], m.tokenHash[:]) != 1 {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return false
	}
	sessionID, err := randomToken()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "random_failed")
		return false
	}
	csrf, err := randomToken()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "random_failed")
		return false
	}
	expires := time.Now().Add(24 * time.Hour)
	m.mu.Lock()
	m.sessions[sha256.Sum256([]byte(sessionID))] = session{csrf: csrf, expiresAt: expires}
	m.mu.Unlock()
	http.SetCookie(w, &http.Cookie{
		Name: cookieName, Value: sessionID, Path: "/", HttpOnly: true,
		Secure: m.secureCookie, SameSite: http.SameSiteStrictMode, Expires: expires,
	})
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("X-CSRF-Token", csrf)
	_ = json.NewEncoder(w).Encode(map[string]string{"csrfToken": csrf})
	return true
}

func (m *Manager) Require(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if _, ok := m.lookup(r); !ok {
			writeError(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (m *Manager) ValidCSRF(r *http.Request) bool {
	current, ok := m.lookup(r)
	if !ok {
		return false
	}
	want := []byte(current.csrf)
	got := []byte(r.Header.Get("X-CSRF-Token"))
	return len(want) == len(got) && subtle.ConstantTimeCompare(want, got) == 1
}

func (m *Manager) Logout(w http.ResponseWriter, r *http.Request) {
	if cookie, err := r.Cookie(cookieName); err == nil {
		m.mu.Lock()
		delete(m.sessions, sha256.Sum256([]byte(cookie.Value)))
		m.mu.Unlock()
	}
	http.SetCookie(w, &http.Cookie{
		Name: cookieName, Value: "", Path: "/", HttpOnly: true,
		Secure: m.secureCookie, SameSite: http.SameSiteStrictMode, MaxAge: -1,
	})
	w.WriteHeader(http.StatusNoContent)
}

func (m *Manager) lookup(r *http.Request) (session, bool) {
	cookie, err := r.Cookie(cookieName)
	if err != nil {
		return session{}, false
	}
	key := sha256.Sum256([]byte(cookie.Value))
	m.mu.RLock()
	current, ok := m.sessions[key]
	m.mu.RUnlock()
	if !ok || time.Now().After(current.expiresAt) {
		if ok {
			m.mu.Lock()
			delete(m.sessions, key)
			m.mu.Unlock()
		}
		return session{}, false
	}
	return current, true
}

func randomToken() (string, error) {
	value := make([]byte, 32)
	if _, err := rand.Read(value); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(value), nil
}

func writeError(w http.ResponseWriter, status int, code string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]string{"error": code})
}
