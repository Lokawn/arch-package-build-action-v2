#!/bin/bash

## Contains shellcheck errors
if [ -z "$2" ]; then
  echo "Usage: $0 <root> <target>"
fi

for DIR in $(find "$2" ! -path "$2"/.git -prune -o -type d); do
  {
      echo -e '<html>\n<body>\n<h1>Directory listing</h1>\n<hr/>\n<pre>'
      ls -1pa -I .git -I .github "$DIR" | grep -v "^\./$" | grep -v "^index\.html$"  | awk '{ printf "<a href=\"%s\">%s</a>\n",$1,$1 }'
      echo -e '</pre>\n</body>\n</html>'
  } > "$1"/index.html
done
