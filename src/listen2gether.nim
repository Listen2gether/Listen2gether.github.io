import prologue
import prologue/middlewares/staticfile
import routes/urls

let settings = newSettings(appName = "Listen2gether", port = Port(8080))
var app = newApp(settings = settings)
app.use(staticFileMiddleware("src/templates"))
app.addRoute(urls.urlPatterns, "")
app.run()