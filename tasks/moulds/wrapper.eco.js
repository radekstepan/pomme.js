<% clean = (input) => %><%- input.replace(/\n\s*\n/g, '\n') %><% end %>
(function() {
    var root = this;

    <%- clean @content %>

    // Use our or outside require?
    root.require = (root.require) ? root.require : require;

    // Expose the app.
    require.alias("<%- @package %>/<%- @main %>.js", "<%- @package %>/index.js");
})();