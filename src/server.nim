import
  pkg/prologue,
  pkg/prologue/middlewares/staticfile,
  routes/urls,
  models

createTables()

let
  env = loadPrologueEnv(".env")
  settings = newSettings(
    appName = env.getOrDefault("appName", "Listen2gether"),
    debug = env.getOrDefault("debug", true),
    port = Port(env.getOrDefault("port", 8080))
  )

var app = newApp(settings = settings)

app.use(staticFileMiddleware(env.get("staticDir")))
app.addRoute(urls.urlPatterns, "")
app.run()