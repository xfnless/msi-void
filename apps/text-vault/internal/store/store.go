package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"time"

	_ "modernc.org/sqlite"
)

const schema = `
CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    applied_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS metadata (
    key TEXT PRIMARY KEY,
    value BLOB NOT NULL
);
CREATE TABLE IF NOT EXISTS objects (
    id TEXT PRIMARY KEY,
    kind TEXT NOT NULL,
    revision INTEGER NOT NULL,
    envelope BLOB NOT NULL,
    updated_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS object_versions (
    id TEXT NOT NULL,
    revision INTEGER NOT NULL,
    kind TEXT NOT NULL,
    envelope BLOB NOT NULL,
    generation INTEGER NOT NULL,
    PRIMARY KEY (id, revision)
);
INSERT OR IGNORE INTO schema_migrations(version, applied_at) VALUES (1, unixepoch());
INSERT OR IGNORE INTO metadata(key, value) VALUES ('generation', '0');
`

var objectIDPattern = regexp.MustCompile(`^[A-Za-z0-9_-]{16,80}$`)

var allowedKinds = map[string]bool{
	"entry": true, "workspace": true, "query": true, "view": true,
}

type Store struct {
	db *sql.DB
}

func Open(path string) (*Store, error) {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return nil, fmt.Errorf("create database directory: %w", err)
	}
	db, err := sql.Open("sqlite", path)
	if err != nil {
		return nil, fmt.Errorf("open sqlite: %w", err)
	}
	db.SetMaxOpenConns(1)
	db.SetMaxIdleConns(1)
	for _, pragma := range []string{
		"PRAGMA journal_mode=WAL",
		"PRAGMA foreign_keys=ON",
		"PRAGMA busy_timeout=5000",
		"PRAGMA synchronous=FULL",
	} {
		if _, err := db.Exec(pragma); err != nil {
			_ = db.Close()
			return nil, fmt.Errorf("configure sqlite: %w", err)
		}
	}
	if _, err := db.Exec(schema); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("migrate sqlite: %w", err)
	}
	return &Store{db: db}, nil
}

func (s *Store) Close() error {
	return s.db.Close()
}

// Backup writes a transactionally consistent standalone SQLite database.
// The destination must not exist, which prevents an accidental overwrite.
func (s *Store) Backup(ctx context.Context, destination string) error {
	abs, err := filepath.Abs(destination)
	if err != nil {
		return fmt.Errorf("resolve backup destination: %w", err)
	}
	if info, err := os.Stat(abs); err == nil {
		return fmt.Errorf("backup destination already exists: %s", info.Name())
	} else if !errors.Is(err, os.ErrNotExist) {
		return fmt.Errorf("inspect backup destination: %w", err)
	}
	if err := os.MkdirAll(filepath.Dir(abs), 0o700); err != nil {
		return fmt.Errorf("create backup directory: %w", err)
	}
	if _, err := s.db.ExecContext(ctx, `VACUUM INTO ?`, abs); err != nil {
		return fmt.Errorf("backup sqlite: %w", err)
	}
	if err := os.Chmod(abs, 0o600); err != nil {
		return fmt.Errorf("protect backup: %w", err)
	}
	return nil
}

func (s *Store) Snapshot(ctx context.Context) (Snapshot, error) {
	tx, err := s.db.BeginTx(ctx, &sql.TxOptions{ReadOnly: true})
	if err != nil {
		return Snapshot{}, fmt.Errorf("begin snapshot: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	generation, err := readGeneration(ctx, tx)
	if err != nil {
		return Snapshot{}, err
	}
	rows, err := tx.QueryContext(ctx, `SELECT id, kind, revision, envelope FROM objects ORDER BY id`)
	if err != nil {
		return Snapshot{}, fmt.Errorf("query objects: %w", err)
	}
	defer rows.Close()

	objects := make(map[string]CipherObject)
	refs := make(map[string]ObjectRef)
	for rows.Next() {
		var object CipherObject
		var revision int64
		if err := rows.Scan(&object.ID, &object.Kind, &revision, &object.Envelope); err != nil {
			return Snapshot{}, fmt.Errorf("scan object: %w", err)
		}
		object.Revision = uint64(revision)
		objects[object.ID] = object
		refs[object.ID] = ObjectRef{Kind: object.Kind, Revision: object.Revision}
	}
	if err := rows.Err(); err != nil {
		return Snapshot{}, fmt.Errorf("iterate objects: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return Snapshot{}, fmt.Errorf("finish snapshot: %w", err)
	}
	return Snapshot{
		Manifest: Manifest{SchemaVersion: 1, Generation: generation, Objects: refs},
		Objects:  objects,
	}, nil
}

func (s *Store) Commit(ctx context.Context, request CommitRequest) (Manifest, error) {
	if err := validateObjects(request.Objects); err != nil {
		return Manifest{}, err
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return Manifest{}, fmt.Errorf("begin commit: %w", err)
	}
	defer func() { _ = tx.Rollback() }()

	generation, err := readGeneration(ctx, tx)
	if err != nil {
		return Manifest{}, err
	}
	if generation != request.BaseGeneration {
		return Manifest{}, ErrConflict
	}

	for _, object := range request.Objects {
		var current int64
		err := tx.QueryRowContext(ctx, `SELECT revision FROM objects WHERE id = ?`, object.ID).Scan(&current)
		switch {
		case errors.Is(err, sql.ErrNoRows) && object.Revision != 1:
			return Manifest{}, ErrConflict
		case err == nil && object.Revision != uint64(current)+1:
			return Manifest{}, ErrConflict
		case err != nil && !errors.Is(err, sql.ErrNoRows):
			return Manifest{}, fmt.Errorf("read revision: %w", err)
		}
	}

	newGeneration := generation + 1
	now := time.Now().UnixMilli()
	for _, object := range request.Objects {
		if _, err := tx.ExecContext(ctx, `
            INSERT INTO object_versions(id, revision, kind, envelope, generation)
            VALUES (?, ?, ?, ?, ?)`, object.ID, object.Revision, object.Kind, []byte(object.Envelope), newGeneration); err != nil {
			return Manifest{}, fmt.Errorf("insert object version: %w", err)
		}
		if _, err := tx.ExecContext(ctx, `
            INSERT INTO objects(id, kind, revision, envelope, updated_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET kind=excluded.kind, revision=excluded.revision,
                envelope=excluded.envelope, updated_at=excluded.updated_at`,
			object.ID, object.Kind, object.Revision, []byte(object.Envelope), now); err != nil {
			return Manifest{}, fmt.Errorf("upsert object: %w", err)
		}
	}
	if _, err := tx.ExecContext(ctx, `UPDATE metadata SET value = ? WHERE key = 'generation'`, strconv.FormatUint(newGeneration, 10)); err != nil {
		return Manifest{}, fmt.Errorf("update generation: %w", err)
	}
	if err := tx.Commit(); err != nil {
		return Manifest{}, fmt.Errorf("commit objects: %w", err)
	}
	return s.currentManifest(ctx)
}

func (s *Store) CreateVaultHeader(ctx context.Context, header json.RawMessage) error {
	if len(header) == 0 || len(header) > 64<<10 || !json.Valid(header) {
		return fmt.Errorf("invalid vault header")
	}
	var value map[string]any
	if err := json.Unmarshal(header, &value); err != nil || value == nil {
		return fmt.Errorf("vault header must be an object")
	}
	_, err := s.db.ExecContext(ctx, `INSERT INTO metadata(key, value) VALUES ('vault_header', ?)`, []byte(header))
	if err != nil {
		if isConstraintError(err) {
			return ErrConflict
		}
		return fmt.Errorf("create vault header: %w", err)
	}
	return nil
}

func (s *Store) VaultHeader(ctx context.Context) (json.RawMessage, error) {
	var raw []byte
	if err := s.db.QueryRowContext(ctx, `SELECT value FROM metadata WHERE key = 'vault_header'`).Scan(&raw); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		}
		return nil, fmt.Errorf("read vault header: %w", err)
	}
	return json.RawMessage(raw), nil
}

func (s *Store) currentManifest(ctx context.Context) (Manifest, error) {
	snapshot, err := s.Snapshot(ctx)
	if err != nil {
		return Manifest{}, err
	}
	return snapshot.Manifest, nil
}

type rowQuerier interface {
	QueryRowContext(context.Context, string, ...any) *sql.Row
}

func readGeneration(ctx context.Context, q rowQuerier) (uint64, error) {
	var raw string
	if err := q.QueryRowContext(ctx, `SELECT CAST(value AS TEXT) FROM metadata WHERE key = 'generation'`).Scan(&raw); err != nil {
		return 0, fmt.Errorf("read generation: %w", err)
	}
	value, err := strconv.ParseUint(raw, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("parse generation: %w", err)
	}
	return value, nil
}

func validateObjects(objects []CipherObject) error {
	seen := make(map[string]bool, len(objects))
	for _, object := range objects {
		if !objectIDPattern.MatchString(object.ID) {
			return fmt.Errorf("invalid object id %q", object.ID)
		}
		if !allowedKinds[object.Kind] {
			return fmt.Errorf("invalid object kind %q", object.Kind)
		}
		if seen[object.ID] {
			return fmt.Errorf("duplicate object id %q", object.ID)
		}
		seen[object.ID] = true
		if object.Revision == 0 || len(object.Envelope) == 0 || !json.Valid(object.Envelope) {
			return fmt.Errorf("invalid object %q", object.ID)
		}
	}
	return nil
}

func isConstraintError(err error) bool {
	return regexp.MustCompile(`(?i)(constraint|unique)`).MatchString(err.Error())
}
