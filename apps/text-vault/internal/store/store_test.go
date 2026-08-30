package store

import (
	"context"
	"encoding/json"
	"errors"
	"path/filepath"
	"testing"
)

func TestCommitPublishesBatchAndRejectsStaleBase(t *testing.T) {
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "text-vault.db")
	s, err := Open(path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = s.Close() })

	first, err := s.Commit(ctx, CommitRequest{
		BaseGeneration: 0,
		Objects: []CipherObject{
			{ID: "entry_1234567890", Kind: "entry", Revision: 1, Envelope: json.RawMessage(`{"ciphertext":"AA=="}`)},
			{ID: "workspace_main_01", Kind: "workspace", Revision: 1, Envelope: json.RawMessage(`{"ciphertext":"AQ=="}`)},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	if first.Generation != 1 || first.Objects["entry_1234567890"].Revision != 1 {
		t.Fatalf("manifest = %#v", first)
	}

	_, err = s.Commit(ctx, CommitRequest{
		BaseGeneration: 0,
		Objects: []CipherObject{
			{ID: "entry_stale_0001", Kind: "entry", Revision: 1, Envelope: json.RawMessage(`{"ciphertext":"Ag=="}`)},
		},
	})
	if !errors.Is(err, ErrConflict) {
		t.Fatalf("stale commit error = %v", err)
	}

	snapshot, err := s.Snapshot(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if snapshot.Manifest.Generation != 1 || len(snapshot.Objects) != 2 {
		t.Fatalf("snapshot = %#v", snapshot)
	}
	if _, exists := snapshot.Objects["entry_stale_0001"]; exists {
		t.Fatal("stale batch became visible")
	}
}

func TestCommitRollsBackWholeBatchOnInvalidRevision(t *testing.T) {
	ctx := context.Background()
	s, err := Open(filepath.Join(t.TempDir(), "text-vault.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = s.Close() })

	_, err = s.Commit(ctx, CommitRequest{BaseGeneration: 0, Objects: []CipherObject{
		{ID: "entry_valid_00001", Kind: "entry", Revision: 1, Envelope: json.RawMessage(`{"ciphertext":"AA=="}`)},
		{ID: "entry_invalid_001", Kind: "entry", Revision: 2, Envelope: json.RawMessage(`{"ciphertext":"AQ=="}`)},
	}})
	if !errors.Is(err, ErrConflict) {
		t.Fatalf("commit error = %v", err)
	}

	snapshot, err := s.Snapshot(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if snapshot.Manifest.Generation != 0 || len(snapshot.Objects) != 0 {
		t.Fatalf("partial batch visible: %#v", snapshot)
	}
}

func TestVaultHeaderIsCreateOnlyAndSurvivesReopen(t *testing.T) {
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "text-vault.db")
	s, err := Open(path)
	if err != nil {
		t.Fatal(err)
	}
	header := json.RawMessage(`{"schemaVersion":1,"wrappedKey":"AA=="}`)
	if err := s.CreateVaultHeader(ctx, header); err != nil {
		t.Fatal(err)
	}
	if err := s.CreateVaultHeader(ctx, header); !errors.Is(err, ErrConflict) {
		t.Fatalf("second create error = %v", err)
	}
	if err := s.Close(); err != nil {
		t.Fatal(err)
	}

	s, err = Open(path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = s.Close() })
	got, err := s.VaultHeader(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != string(header) {
		t.Fatalf("header = %s", got)
	}
}

func TestBackupCreatesAConsistentReopenableDatabase(t *testing.T) {
	ctx := context.Background()
	dir := t.TempDir()
	s, err := Open(filepath.Join(dir, "live.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = s.Close() })
	if _, err := s.Commit(ctx, CommitRequest{BaseGeneration: 0, Objects: []CipherObject{
		{ID: "entry_backup_0001", Kind: "entry", Revision: 1, Envelope: json.RawMessage(`{"ciphertext":"AA=="}`)},
	}}); err != nil {
		t.Fatal(err)
	}

	backupPath := filepath.Join(dir, "backup.db")
	if err := s.Backup(ctx, backupPath); err != nil {
		t.Fatal(err)
	}
	backup, err := Open(backupPath)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = backup.Close() })
	snapshot, err := backup.Snapshot(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if snapshot.Manifest.Generation != 1 || snapshot.Objects["entry_backup_0001"].Revision != 1 {
		t.Fatalf("backup snapshot = %#v", snapshot)
	}
}

func TestVaultSetupStoresHeaderAndAuthenticationHashAtomically(t *testing.T) {
	ctx := context.Background()
	s, err := Open(filepath.Join(t.TempDir(), "text-vault.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = s.Close() })

	header := json.RawMessage(`{"schemaVersion":1,"auth":{"salt":"AA=="}}`)
	authHash := []byte("01234567890123456789012345678901")
	if err := s.CreateVault(ctx, header, authHash); err != nil {
		t.Fatal(err)
	}
	gotHash, err := s.AuthHash(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if string(gotHash) != string(authHash) {
		t.Fatalf("auth hash = %x", gotHash)
	}
	if err := s.CreateVault(ctx, header, authHash); !errors.Is(err, ErrConflict) {
		t.Fatalf("second setup error = %v", err)
	}
}
