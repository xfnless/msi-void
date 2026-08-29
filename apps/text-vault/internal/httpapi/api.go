package httpapi

import (
	"encoding/json"
	"io/fs"
	"net/http"
	"path"
	"strings"
)

type Config struct {
	Frontend fs.FS
}

func New(cfg Config) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]bool{"ok": true})
	})
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		name := strings.TrimPrefix(path.Clean(r.URL.Path), "/")
		if name == "." || name == "" {
			name = "index.html"
		}
		if _, err := fs.Stat(cfg.Frontend, name); err != nil {
			name = "index.html"
		}
		if name == "index.html" {
			r.URL.Path = "/"
		} else {
			r.URL.Path = "/" + name
		}
		http.FileServerFS(cfg.Frontend).ServeHTTP(w, r)
	})
	return mux
}
