package httpapi

import (
	"encoding/json"
	"io"
	"io/fs"
	"net/http"
	"path"
	"strings"

	"github.com/xfn/text-vault/internal/auth"
	"github.com/xfn/text-vault/internal/store"
)

type Config struct {
	Frontend fs.FS
	Store    *store.Store
	Auth     *auth.Manager
}

func New(cfg Config) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]bool{"ok": true})
	})
	if cfg.Store != nil && cfg.Auth != nil {
		mux.HandleFunc("POST /api/login", func(w http.ResponseWriter, r *http.Request) {
			if !isJSON(r) {
				writeAPIError(w, http.StatusUnsupportedMediaType, "json_required")
				return
			}
			cfg.Auth.Login(w, r)
		})

		protected := http.NewServeMux()
		protected.HandleFunc("GET /api/vault", func(w http.ResponseWriter, r *http.Request) {
			header, err := cfg.Store.VaultHeader(r.Context())
			if err != nil {
				if err == store.ErrNotFound {
					writeAPIError(w, http.StatusNotFound, "vault_not_found")
					return
				}
				writeAPIError(w, http.StatusInternalServerError, "store_failed")
				return
			}
			writeJSON(w, http.StatusOK, header)
		})
		protected.HandleFunc("PUT /api/vault", requireCSRF(cfg.Auth, func(w http.ResponseWriter, r *http.Request) {
			if !isJSON(r) {
				writeAPIError(w, http.StatusUnsupportedMediaType, "json_required")
				return
			}
			body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 64<<10))
			if err != nil || !json.Valid(body) {
				writeAPIError(w, http.StatusBadRequest, "invalid_vault_header")
				return
			}
			if err := cfg.Store.CreateVaultHeader(r.Context(), body); err != nil {
				if err == store.ErrConflict {
					writeAPIError(w, http.StatusConflict, "conflict")
					return
				}
				writeAPIError(w, http.StatusBadRequest, "invalid_vault_header")
				return
			}
			w.WriteHeader(http.StatusNoContent)
		}))
		protected.HandleFunc("GET /api/snapshot", func(w http.ResponseWriter, r *http.Request) {
			snapshot, err := cfg.Store.Snapshot(r.Context())
			if err != nil {
				writeAPIError(w, http.StatusInternalServerError, "store_failed")
				return
			}
			writeJSON(w, http.StatusOK, snapshot)
		})
		protected.HandleFunc("POST /api/commit", requireCSRF(cfg.Auth, func(w http.ResponseWriter, r *http.Request) {
			if !isJSON(r) {
				writeAPIError(w, http.StatusUnsupportedMediaType, "json_required")
				return
			}
			decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<20))
			decoder.DisallowUnknownFields()
			var request store.CommitRequest
			if err := decoder.Decode(&request); err != nil {
				writeAPIError(w, http.StatusBadRequest, "invalid_commit")
				return
			}
			manifest, err := cfg.Store.Commit(r.Context(), request)
			if err != nil {
				if err == store.ErrConflict {
					writeAPIError(w, http.StatusConflict, "conflict")
					return
				}
				writeAPIError(w, http.StatusBadRequest, "invalid_commit")
				return
			}
			writeJSON(w, http.StatusOK, map[string]any{"manifest": manifest})
		}))
		protected.HandleFunc("POST /api/logout", requireCSRF(cfg.Auth, cfg.Auth.Logout))
		mux.Handle("/api/", cfg.Auth.Require(protected))
	}
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

func requireCSRF(manager *auth.Manager, next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if !manager.ValidCSRF(r) {
			writeAPIError(w, http.StatusForbidden, "csrf_failed")
			return
		}
		next(w, r)
	}
}

func isJSON(r *http.Request) bool {
	return strings.EqualFold(strings.TrimSpace(strings.Split(r.Header.Get("Content-Type"), ";")[0]), "application/json")
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func writeAPIError(w http.ResponseWriter, status int, code string) {
	writeJSON(w, status, map[string]string{"error": code})
}
