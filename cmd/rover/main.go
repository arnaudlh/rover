package main

import (
	"context"
	"flag"
	"fmt"
	"os"

	"github.com/arnaudlh/rover/internal/rover"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Expected subcommand: init, plan, apply, destroy, show, validate")
		os.Exit(1)
	}

	ctx := context.Background()
	workingDir := getEnvVar("TF_VAR_tf_name", "")
	dataDir := getEnvVar("TF_DATA_DIR", "/tf/caf")
	level := getEnvVar("TF_VAR_level", "")
	workspace := getEnvVar("TF_VAR_workspace", "")
	subscriptionID := getEnvVar("TF_VAR_tfstate_subscription_id", "")

	if workingDir == "" || level == "" || workspace == "" || subscriptionID == "" {
		fmt.Println("Required environment variables not set:")
		fmt.Println("- TF_VAR_tf_name")
		fmt.Println("- TF_VAR_level")
		fmt.Println("- TF_VAR_workspace")
		fmt.Println("- TF_VAR_tfstate_subscription_id")
		os.Exit(1)
	}

	stateManager, err := rover.NewStateManager(ctx, subscriptionID, level, workspace, workingDir, dataDir)
	if err != nil {
		fmt.Printf("Error creating state manager: %v\n", err)
		os.Exit(1)
	}

	switch os.Args[1] {
	case "init":
		if err := stateManager.InitializeState(ctx); err != nil {
			fmt.Printf("Error initializing state: %v\n", err)
			os.Exit(1)
		}

	case "plan":
		destroy := false
		planCmd := flag.NewFlagSet("plan", flag.ExitOnError)
		planCmd.BoolVar(&destroy, "destroy", false, "Create a destroy plan")
		planCmd.Parse(os.Args[2:])

		if err := stateManager.Plan(ctx, destroy); err != nil {
			fmt.Printf("Error creating plan: %v\n", err)
			os.Exit(1)
		}

	case "apply":
		if err := stateManager.Apply(ctx); err != nil {
			fmt.Printf("Error applying changes: %v\n", err)
			os.Exit(1)
		}

	case "destroy":
		if err := stateManager.Destroy(ctx); err != nil {
			fmt.Printf("Error destroying resources: %v\n", err)
			os.Exit(1)
		}

	case "show":
		if err := stateManager.Show(ctx); err != nil {
			fmt.Printf("Error showing state: %v\n", err)
			os.Exit(1)
		}

	case "validate":
		if err := stateManager.Validate(ctx); err != nil {
			fmt.Printf("Error validating configuration: %v\n", err)
			os.Exit(1)
		}

	default:
		fmt.Printf("Unknown command: %s\n", os.Args[1])
		fmt.Println("Available commands: init, plan, apply, destroy, show, validate")
		os.Exit(1)
	}
}

func getEnvVar(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
