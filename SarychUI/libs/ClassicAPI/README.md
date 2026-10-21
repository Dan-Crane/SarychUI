# ClassicAPI

Embedded compatibility library for World of Warcraft 3.3.5 and Lua 5.1. It provides selected later-client globals and helpers, including C_Timer, mixins, callback registries, widget compatibility, pools, selected C_* namespaces, and optional UI templates.

This package is a library, not a standalone addon: it deliberately has no .toc. Vendor it through the wow-335-library-librarian installer so the __ADDON__ resource-path token is replaced with the target addon folder name.

Use the core loader for normal dependency support:

\`\`\`xml
<Include file="Libs\ClassicAPI\ClassicAPICore.xml" />
\`\`\`

Use the full loader only when the addon needs ClassicAPI's copied XML templates:

\`\`\`xml
<Include file="Libs\ClassicAPI\ClassicAPI.xml" />
\`\`\`

Load ClassicAPI before libraries that use its compatibility globals. The package bundles its required LibStub dependency. Include the full template loader only once across an installed addon set; the core loader is the preferred lightweight option.

The compatibility code and assets originate from the supplied !!!ClassicAPI version 1.29 package and retain its source comments and notices.
