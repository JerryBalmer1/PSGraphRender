@{
    # Provenance for every third-party file in this directory. DATA, read with
    # Import-PowerShellDataFile and never executed.
    #
    # A vendored blob with no provenance is worse than a CDN link: the link at
    # least says where it came from. Each entry records the exact URL the file
    # was fetched from, the version that URL pins, and the Subresource Integrity
    # hash it was verified against.
    #
    # To update this: fetch Url, compute
    #     'sha384-' + [Convert]::ToBase64String(
    #         [Security.Cryptography.SHA384]::Create().ComputeHash(
    #             [IO.File]::ReadAllBytes($path)))
    # and compare with Integrity BEFORE replacing the file. Then change Version,
    # Url and Integrity here in the same commit. tools/Update-Vendor.ps1 does all
    # three as one operation; tests/Vendor.Tests.ps1 verifies every file against
    # its recorded hash on every run, so a file replaced without updating this
    # manifest fails the build by name.
    #
    # The file is byte-identical to what the hash covers and is NEVER edited.

    Files = @(
        @{
            # ONE file, and three.js is inside it. Verified by inspection of the
            # built bundle, not assumed from the package name - the same
            # standard cytoscape-dagre's bundled dagre was held to, and for the
            # same reason: a package that DEPENDS on a library is not evidence
            # that its dist SHIPS one, and the cost of guessing wrong is a page
            # that loads and draws nothing.
            #
            # What the inspection found, in the bytes of this exact file:
            #   - `__THREE__`, the global three.js registers itself under, and
            #     the "Multiple instances of Three.js being imported" warning
            #     that only three.js's own source contains;
            #   - `WebGLRenderer`, `PerspectiveCamera`, `BufferGeometry`,
            #     `MeshLambertMaterial` and the `meshphong_vert` shader chunk;
            #   - a `https://github.com/mrdoob/three.js/issues/32012` reference
            #     inside a three.js code path;
            #   - zero `require(` calls and no import of anything.
            # So there is no second file here, and adding one would put a second
            # copy of three.js in the page - which is what that warning exists
            # to report.
            #
            # It also ends with no sourceMappingURL comment, so this backend does
            # not inherit the accepted limitation `0005-t4` carries for
            # cytoscape-dagre: the page's claim to need nothing survives a
            # developer-tools session here.
            Name      = '3d-force-graph.min.js'
            Package   = '3d-force-graph'
            Version   = '1.80.0'
            Url       = 'https://cdn.jsdelivr.net/npm/3d-force-graph@1.80.0/dist/3d-force-graph.min.js'
            Integrity = 'sha384-Y7bC2PBKu8ujxtvo5+Z61OeGdSVRzFsYWBK4i5dnL/U6aFDTodk61qOUkTfInaxS'
            License   = 'MIT'
        }
    )
}
