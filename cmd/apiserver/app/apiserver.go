package app

import (
	"context"
	"net/http"
	_ "net/http/pprof"

	"github.com/spf13/cobra"
	utilfeature "k8s.io/apiserver/pkg/util/feature"
	cliflag "k8s.io/component-base/cli/flag"
	"k8s.io/component-base/cli/globalflag"
	"k8s.io/component-base/term"

	"github.com/clusterpedia-io/clusterpedia/cmd/apiserver/app/options"
	"github.com/clusterpedia-io/clusterpedia/pkg/version/verflag"
)

func NewClusterPediaServerCommand(ctx context.Context) *cobra.Command {
	opts := options.NewServerOptions()

	cmd := &cobra.Command{
		Use: "clusterpedia-apiserver",
		RunE: func(cmd *cobra.Command, args []string) error {
			verflag.PrintAndExitIfRequested()
			cliflag.PrintFlags(cmd.Flags())

			if err := opts.Complete(); err != nil {
				return err
			}
			if err := opts.Validate(args); err != nil {
				return err
			}

			config, err := opts.Config()
			if err != nil {
				return err
			}

			server, err := config.Complete().New()
			if err != nil {
				return err
			}

			go func() {
				http.ListenAndServe("0.0.0.0:6060", nil)
			}()

			if err := server.Run(ctx); err != nil {
				return err
			}
			return nil
		},
	}

	namedFlagSets := opts.Flags()
	verflag.AddFlags(namedFlagSets.FlagSet("global"))
	globalflag.AddGlobalFlags(namedFlagSets.FlagSet("global"), cmd.Name())
	utilfeature.DefaultMutableFeatureGate.AddFlag(namedFlagSets.FlagSet("mutable feature gate"))

	fs := cmd.Flags()
	for _, f := range namedFlagSets.FlagSets {
		fs.AddFlagSet(f)
	}

	cols, _, _ := term.TerminalSize(cmd.OutOrStdout())
	cliflag.SetUsageAndHelpFunc(cmd, namedFlagSets, cols)
	return cmd
}
