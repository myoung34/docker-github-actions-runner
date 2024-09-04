package main

import (
	"context"
	"testing"
)

func TestIntegrationGHRunner(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping integration test")
	}

	ctx := context.Background()

	theTests := []outputTest{
		{
			name: "default behavior",
			envVars: map[string]string{
				"DEBUG_ONLY":  "true",
				"RUNNER_NAME": "test",
			},
			cmd:         []string{"/entrypoint.sh", "something"},
			expectation: "The default behavior should be set correctly",
			output: []string{
				"#REPO_URL required for repo runners",
				"Runner reusage is disabled",
				"�Disable automatic registration: false",
				"Random runner suffix: true",
				"Runner name: test",
				"Runner workdir: /_work/test",
				"Labels: default",
				"Runner Group: Default",
				"Github Host: github.com",
				"Run as root:true",
				"Start docker: false",
				"Running something",
			},
			statusCode: 0,
		},
		{
			name: "non default behavior",
			envVars: map[string]string{
				"DEBUG_ONLY":                       "true",
				"RUNNER_NAME":                      "huzzah",
				"REPO_URL":                         "https://github.com/myoung34/docker-github-actions-runner",
				"RUN_AS_ROOT":                      "true",
				"RUNNER_NAME_PREFIX":               "asdf",
				"ACCESS_TOKEN":                     "1234",
				"APP_ID":                           "5678",
				"APP_PRIVATE_KEY":                  "2345",
				"APP_LOGIN":                        "SOMETHING",
				"RUNNER_SCOPE":                     "org",
				"ORG_NAME":                         "myoung34",
				"ENTERPRISE_NAME":                  "emyoung34",
				"LABELS":                           "blue,green",
				"RUNNER_TOKEN":                     "3456",
				"RUNNER_WORKDIR":                   "/tmp/a",
				"RUNNER_GROUP":                     "wat",
				"GITHUB_HOST":                      "github.example.com",
				"DISABLE_AUTOMATIC_DEREGISTRATION": "true",
				"EPHEMERAL":                        "true",
				"DISABLE_AUTO_UPDATE":              "true",
			},
			cmd:         []string{"/entrypoint.sh", "something"},
			expectation: "The non default behavior should be set correctly",
			output: []string{
				"Runner reusage is disabled",
				"�Disable automatic registration: true",
				"Random runner suffix: true",
				"Runner name: huzzah",
				"Runner workdir: /tmp/a",
				"Labels: blue,green",
				"Runner Group: wat",
				"Github Host: github.example.com",
				"Run as root:true",
				"Start docker: false",
				"Running something",
			},
			statusCode: 0,
		},
		{
			name:        "gha softwrae installed",
			cmd:         []string{"ls", "./bin/Runner.Listener"},
			expectation: "The GHA software should be installed in the container",
			output: []string{
				"./bin/Runner.Listener",
			},
			statusCode: 0,
		},
	}
	t.Logf("%v", theTests)

	for _, theT := range theTests {

		t.Run(theT.name, func(t *testing.T) {
			ghaRunner, err := setupGHRunner(ctx, theT.envVars)
			if err != nil {
				t.Fatal(err)
			}
			// Clean up the container after the test is complete
			t.Cleanup(func() {
				if err := ghaRunner.Terminate(ctx); err != nil {
					t.Fatalf("failed to terminate container: %s", err)
				}
			})

			output, err := runAndReturnOutput(ghaRunner, ctx, theT.cmd)

			if err != nil {
				t.Fatal(err)
			}

			// loop through output and compare to test output
			for i, line := range output {
				if line != theT.output[i] {
					t.Errorf("Expected %s, got %s", theT.output[i], line)
				}
			}
		})
	}
}
