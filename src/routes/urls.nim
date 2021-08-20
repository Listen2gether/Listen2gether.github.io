import prologue
import views

const urlPatterns* = @[
  pattern("/", home),
  pattern("/mirror", mirror),
]