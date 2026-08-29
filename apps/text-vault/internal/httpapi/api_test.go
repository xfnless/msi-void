package httpapi

import (
	"io/fs"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"testing/fstest"
)

func TestHealthAndSPA(t *testing.T) {
	h := New(Config{Frontend: fstest.MapFS{
		"index.html": &fstest.MapFile{Data: []byte("<main>Text Vault</main>")},
	}})

	health := httptest.NewRecorder()
	h.ServeHTTP(health, httptest.NewRequest(http.MethodGet, "/api/health", nil))
	if health.Code != http.StatusOK || strings.TrimSpace(health.Body.String()) != `{"ok":true}` {
		t.Fatalf("health = %d %q", health.Code, health.Body.String())
	}

	page := httptest.NewRecorder()
	h.ServeHTTP(page, httptest.NewRequest(http.MethodGet, "/", nil))
	if page.Code != http.StatusOK || !strings.Contains(page.Body.String(), "Text Vault") {
		t.Fatalf("page = %d %q", page.Code, page.Body.String())
	}

	nested := httptest.NewRecorder()
	h.ServeHTTP(nested, httptest.NewRequest(http.MethodGet, "/anything", nil))
	if nested.Code != http.StatusOK || !strings.Contains(nested.Body.String(), "Text Vault") {
		t.Fatalf("spa fallback = %d %q", nested.Code, nested.Body.String())
	}
}

var _ fs.FS = fstest.MapFS{}
