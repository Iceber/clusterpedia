package options

import (
	"github.com/spf13/pflag"
	genericoptions "k8s.io/apiserver/pkg/server/options"
)

type FeatureOptions struct {
	*genericoptions.FeatureOptions

	EnableRemainingItemCount bool
}

func NewFeatureOptions() *FeatureOptions {
	return &FeatureOptions{
		FeatureOptions:           genericoptions.NewFeatureOptions(),
		EnableRemainingItemCount: false,
	}
}

func (o *FeatureOptions) AddFlags(fs *pflag.FlagSet) {
	if o == nil {
		return
	}

	o.FeatureOptions.AddFlags(fs)
	fs.BoolVar(&o.EnableRemainingItemCount, "enable-remaining-item-count", o.EnableRemainingItemCount,
		"Enable profiling via web interface host:port/debug/pprof/",
	)
}
