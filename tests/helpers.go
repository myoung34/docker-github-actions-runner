package main

import (
	"bufio"
	"context"
	"fmt"
	"github.com/testcontainers/testcontainers-go"
	"io"
	"os"
	"strings"
	"unicode"
)

type ghaRunnerontainer struct {
	testcontainers.Container
}

// Helper function to read from an io.Reader and return a slice of strings (one per line)
func readLines(reader io.Reader) ([]string, error) {
	var lines []string
	scanner := bufio.NewScanner(reader)
	for scanner.Scan() {
		lines = append(lines, scanner.Text())
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return lines, nil
}

func cleanString(b []byte) string {
	s := string(b)
	return strings.Map(func(r rune) rune {
		if unicode.IsPrint(r) {
			return r
		}
		return -1
	}, s)
}

func runAndReturnOutput(ctr testcontainers.Container, ctx context.Context, cmd []string) ([]string, error) {
	_, reader, err := ctr.Exec(ctx, cmd)
	if err != nil {
		return nil, err
	}
	lines, err := readLines(reader)
	if err != nil {
		fmt.Println("Error reading lines:", err)
	}

	fixedOutput := make([]string, len(lines))
	for i, line := range lines {
		fixedOutput[i] = cleanString([]byte(line))
	}
	return fixedOutput, nil

}

func setupGHRunner(ctx context.Context, envVars map[string]string) (*ghaRunnerontainer, error) {
	if os.Getenv("GH_RUNNER_IMAGE") == "" {
		return nil, fmt.Errorf("GH_RUNNER_IMAGE is not set")
	}
	req := testcontainers.ContainerRequest{
		Image:        os.Getenv("GH_RUNNER_IMAGE"),
		ExposedPorts: []string{},
		Entrypoint:   []string{"/usr/bin/sleep"},
		Cmd:          []string{"60"},
		Env:          envVars,
	}

	container, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
		ContainerRequest: req,
		Started:          true,
	})
	if err != nil {
		return nil, err
	}

	return &ghaRunnerontainer{Container: container}, nil
}

type outputTest struct {
	name        string
	cmd         []string
	output      []string
	statusCode  int
	expectation string
	envVars     map[string]string
}
