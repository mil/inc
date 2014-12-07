page:
  contents: 
    - "_js/FancyZoom.js"
    - "_js/FancyZoomHTML.js"
    - "_js/onload.js"
    - "_js/sh_main.js"
    - "_js/zepto.fx.js"
    - "_js/zepto.min.js"
    - "_js/lang/sh_bash.js"
    - "_js/lang/sh_c.js"
    - "_js/lang/sh_ruby.js"

once_page_is_compiled: 
  prepends:  "/* Yo I'm javascripts */"
  postpends: "/* End ma javascripts */"
  scripts:
    - minify_js
