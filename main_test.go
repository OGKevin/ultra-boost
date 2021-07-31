package main

import (
	"testing"
)

func Test_buildPrintStr(t *testing.T) {
	tests := []struct {
		name string
		want string
	}{
		{
			name: "1",
			// Change the string below to make `make unit-tests` fail.
			want: "Hello World",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := buildPrintStr(); got != tt.want {
				t.Errorf("buildPrintStr() = %v, want %v", got, tt.want)
			}
		})
	}
}