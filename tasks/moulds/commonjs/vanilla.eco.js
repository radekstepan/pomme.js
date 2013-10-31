(function() {
  <%- @modules.join('\n') %>

  // Expose the app.
  require.alias("<%- @package %>/<%- @main %>.js", "<%- @package %>/index.js");
})();