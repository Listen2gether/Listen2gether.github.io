import
  pkg/prologue,
  views

const urlPatterns* = @[
  pattern("/", index),
  # pattern("/mirror/{service}/{username}", mirror),
]