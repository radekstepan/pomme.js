<% spaces = (n, line) => %><%- (' ' for i in [0...n]).join('') + line %><% end %>
<%- ( spaces(@spaces, l) for l in @lines.split('\n') ).join('\n') %>