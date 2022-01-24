import
  pkg/prologue,
  views

const urlPatterns* = @[
  pattern("/", home),
  pattern("/mirror/{service}/{username}", mirror),
]