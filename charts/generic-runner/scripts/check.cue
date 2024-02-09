package recipe

// the version of recipe
apiVersion?: string | *"v1"
// pipeline name
kind?: string | *"generic-runner"
// the meta data for the recipe
meta?: #meta
// must have at least one task
tasks!: [#task, ...#task]
