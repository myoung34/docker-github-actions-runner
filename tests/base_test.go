package main

import (
	"context"
	"fmt"
	"testing"
)

func TestIntegrationGHRunnerBase(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test")
	}

	ctx := context.Background()

	ghaRunner, err := setupGHRunner(ctx, map[string]string{})
	if err != nil {
		t.Fatal(err)
	}

	// Clean up the container after the test is complete
	t.Cleanup(func() {
		if err := ghaRunner.Terminate(ctx); err != nil {
			t.Fatalf("failed to terminate container: %s", err)
		}
	})

	for _, theProgram := range []string{
		"curl",
		"docker",
		"docker-compose",
		"dumb-init",
		"gh",
		"git",
		"git-lfs",
		"gosu",
		"jq",
		"lsb_release",
		"make",
		"nodejs",
		"pwsh",
		"python3",
		"rsync",
		"ssh",
		"sudo",
		"tar",
		"unzip",
		"wget",
		"yq",
		"zip",
	} {

		t.Run(fmt.Sprintf("%sExists", theProgram), func(t *testing.T) {

			exitCode, _, err := ghaRunner.Exec(ctx, []string{"which", theProgram})
			if err != nil {
				t.Fatal(err)
			}

			if exitCode != 0 {
				t.Fatalf("expected %s to be installed", theProgram)
			}
		})
	}

	theTests := []outputTest{
		{
			name:        "ulimit set",
			cmd:         []string{"grep", "^\\s*# ulimit -Hn", "/etc/init.d/docker"},
			expectation: "expected ulimit to be set in /etc/init.d/docker\"",
			output:      []string{""},
			statusCode:  0,
		},
		{
			name:        "runner user id",
			cmd:         []string{"id", "-u", "runner"},
			expectation: "expected runner to exist with uid 1001",
			output:      []string{"1001"},
			statusCode:  0,
		},
		{
			name:        "runner group id",
			cmd:         []string{"id", "-g", "runner"},
			expectation: "expected runner to exist with gid 121",
			output:      []string{"121"},
			statusCode:  0,
		},
		{
			name:        "runner groups",
			cmd:         []string{"id", "-Gn", "runner"},
			expectation: "expected runner to exist with group names runner sudo docker",
			output:      []string{"runner sudo docker"},
			statusCode:  0,
		},
		{
			name:        "sudo no password for runner",
			cmd:         []string{"tail", "-n", "1", "/etc/sudoers"},
			expectation: "expected runner to have NOPASSWD line in sudoers",
			output:      []string{"%sudo ALL=(ALL) NOPASSWD: ALL"},
			statusCode:  0,
		},
		{
			name:        "suders defaults",
			cmd:         []string{"grep", "Defaults env_keep = \"HTTP_PROXY HTTPS_PROXY NO_PROXY FTP_PROXY http_proxy https_proxy no_proxy ftp_proxy\"", "/etc/sudoers"},
			expectation: "expected sudoers to have updated Defaults env_keep",
			output:      []string{""},
			statusCode:  0,
		},
		{
			name:        "locale set",
			cmd:         []string{"grep", "-v", "^#", "/etc/locale.gen"},
			expectation: "expected locale to be set in /etc/locale.gen",
			output:      []string{"en_US.UTF-8 UTF-8"},
			statusCode:  0,
		},
	}
	t.Logf("%v", theTests)

	for _, theT := range theTests {

		t.Run(theT.name, func(t *testing.T) {

			if theT.output[0] != "" {
				output, err := runAndReturnOutput(ghaRunner, ctx, theT.cmd)
				if err != nil {
					t.Fatal(err)
				}
				if output[0] != theT.output[0] {
					t.Fatalf("expected %s, got %s", theT.output, output[0])
				}
			}

			cmdExitCode, _, _ := ghaRunner.Exec(ctx, theT.cmd)
			if cmdExitCode != 0 {
				t.Fatalf(theT.expectation)
			}
		})
	}

	// os specific tests
	osDistro, err := runAndReturnOutput(ghaRunner, ctx, []string{"/usr/bin/awk", "-F=", "/^VERSION_CODENAME=/ {print $2}", "/etc/os-release"})
	if err != nil {
		t.Fatal(err)
	}

	// focal is the only one that does not have skopeo buildah podman
	if osDistro[0] != "focal" {
		for _, theProgram := range []string{
			"skopeo",
			"buildah",
			"podman",
		} {
			t.Run(fmt.Sprintf("%sExists", theProgram), func(t *testing.T) {

				exitCode, _, err := ghaRunner.Exec(ctx, []string{"which", theProgram})
				if err != nil {
					t.Fatal(err)
				}

				if exitCode != 0 {
					t.Fatalf("expected %s to be installed", theProgram)
				}

			})
		}
	}
}
