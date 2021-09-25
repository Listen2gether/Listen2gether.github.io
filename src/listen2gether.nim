import pkg/prologue
import pkg/prologue/middlewares/staticfile
import routes/urls, models

let settings = newSettings(appName = "Listen2gether", port = Port(8080))
createTables()
var app = newApp(settings = settings)
app.use(staticFileMiddleware("src/templates"))
app.addRoute(urls.urlPatterns, "")
app.run()