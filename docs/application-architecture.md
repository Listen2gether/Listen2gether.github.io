# Application Architecture


## Source code structure:

```
├── public
│   ├── assets - includes svg icons for the deployment and documentation
│   └── fonts - includes the fonts used by the site
├── src
│   ├── app.nim - the main Karax application to be compiled to JS
│   ├── db.nim - the database module manages IndexedDB and the global data structures
│   ├── listen2gether.nim - a dummy module for docgen purposes
│   ├── sass
│   │   ├── general.sass - styles used across the whole application
│   │   ├── home.sass - the styles for the home view
│   │   ├── include
│   │   │   ├── _themes.sass - a dark / light theme mixin
│   │   │   └── _variables.sass - sets the variables for the colors and fonts
│   │   ├── index.sass - the main sass file to be compiled
│   │   └── mirror.sass - the styles for the mirror view
│   ├── server.nim - debug web server for development purposes
│   ├── sources
│   │   ├── lb.nim - the ListenBrainz service source module
│   │   ├── lfm.nim - the LastFM service source module
│   │   └── utils.nim - shared utilities between the service source modules
│   ├── types.nim - the types used across the application
│   └── views
│       ├── home.nim - the logic and view for the home page
│       ├── mirror.nim - the logic and view for the mirror
│       └── share.nim - the shared utilities between the view modules
└── tests - tests for each module
```
