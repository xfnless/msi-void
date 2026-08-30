package auth

import (
	"crypto/sha256"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestLoginCreatesSessionWithCSRFProtection(t *testing.T) {
	credential := "derived-browser-credential"
	hash := sha256.Sum256([]byte(credential))
	manager, err := New(hash[:], false)
	if err != nil {
		t.Fatal(err)
	}
	login := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/api/login", strings.NewReader(`{"credential":"derived-browser-credential"}`))
	if !manager.Login(login, request) {
		t.Fatalf("login rejected: %d %s", login.Code, login.Body.String())
	}
	if login.Code != http.StatusOK || len(login.Result().Cookies()) != 1 {
		t.Fatalf("login response = %d cookies=%d", login.Code, len(login.Result().Cookies()))
	}
	csrf := login.Header().Get("X-CSRF-Token")
	if csrf == "" {
		t.Fatal("missing CSRF token")
	}

	called := false
	protected := manager.Require(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { called = true }))
	authorized := httptest.NewRequest(http.MethodGet, "/api/snapshot", nil)
	authorized.AddCookie(login.Result().Cookies()[0])
	protected.ServeHTTP(httptest.NewRecorder(), authorized)
	if !called {
		t.Fatal("valid session was rejected")
	}

	write := httptest.NewRequest(http.MethodPost, "/api/commit", nil)
	write.AddCookie(login.Result().Cookies()[0])
	write.Header.Set("X-CSRF-Token", csrf)
	if !manager.ValidCSRF(write) {
		t.Fatal("valid CSRF token was rejected")
	}
}

func TestLoginRejectsWrongToken(t *testing.T) {
	hash := sha256.Sum256([]byte("derived-browser-credential"))
	manager, err := New(hash[:], false)
	if err != nil {
		t.Fatal(err)
	}
	response := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodPost, "/api/login", strings.NewReader(`{"credential":"wrong"}`))
	if manager.Login(response, request) || response.Code != http.StatusUnauthorized {
		t.Fatalf("wrong login = %d %s", response.Code, response.Body.String())
	}
}

func TestUnconfiguredManagerRejectsLoginUntilCredentialIsInstalled(t *testing.T) {
	manager, err := New(nil, false)
	if err != nil {
		t.Fatal(err)
	}
	request := func() *http.Request {
		return httptest.NewRequest(http.MethodPost, "/api/login", strings.NewReader(`{"credential":"derived-browser-credential"}`))
	}
	if manager.Login(httptest.NewRecorder(), request()) {
		t.Fatal("unconfigured authentication accepted a login")
	}
	hash := sha256.Sum256([]byte("derived-browser-credential"))
	if err := manager.SetAuthHash(hash[:]); err != nil {
		t.Fatal(err)
	}
	if !manager.Login(httptest.NewRecorder(), request()) {
		t.Fatal("installed authentication hash rejected login")
	}
}
