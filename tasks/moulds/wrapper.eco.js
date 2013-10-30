<% clean = (input) => %><%- input.replace(/\n\s*\n/g, '\n') %><% end %>
(function() {
    <%- clean @content %>

    // Use our or outside require?
    this.require = (this.require) ? this.require : require;

    // Expose the app.
    require.alias("<%- @package %>/<%- @main %>.js", "<%- @package %>/index.js");
})();
