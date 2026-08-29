package main

import "testing"

func TestParseConfigRequiresAccessTokenAndAcceptsDatabase(t *testing.T) {
	_, err := parseConfig([]string{"-database", "/tmp/vault.db"}, func(string) string { return "" })
	if err == nil {
		t.Fatal("missing access token was accepted")
	}

	got, err := parseConfig([]string{"-listen", "127.0.0.1:9000", "-database", "/tmp/vault.db", "-secure-cookie=false"}, func(name string) string {
		if name == "TEXT_VAULT_ACCESS_TOKEN" {
			return "a-long-development-token"
		}
		return ""
	})
	if err != nil {
		t.Fatal(err)
	}
	if got.listen != "127.0.0.1:9000" || got.database != "/tmp/vault.db" || got.secureCookie {
		t.Fatalf("config = %#v", got)
	}
}
