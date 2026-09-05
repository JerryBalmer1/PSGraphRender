    // Geometry, built from the vendored bundle's own constructors rather than
    // imported from anywhere.
    //
    // THE PROBLEM THIS FILE SOLVES. 3d-force-graph's UMD build exports exactly
    // one global - ForceGraph3D - and three.js is inside it without being
    // re-exported. So `new THREE.BoxGeometry(...)` is not available and never
    // will be: the usual answer is a second <script> for three.js, and that
    // puts a SECOND COPY of three.js in the page, which is what the bundle's
    // own "Multiple instances of Three.js being imported" warning exists to
    // report. See vendor/vendor.psd1.
    //
    // What is available is an OBJECT the library already made. The library
    // draws every item as a lit sphere, so once a payload has been handed over
    // there is a Mesh in the scene carrying a geometry, a material and a
    // position attribute - and a constructor is reachable from any instance.
    // Four of them are all this file needs:
    //
    //   Mesh                mesh.constructor
    //   MeshLambertMaterial mesh.material.constructor
    //   Color               mesh.material.color.constructor
    //   BufferGeometry      the prototype of the sphere geometry's constructor
    //   (its position attribute's constructor, for the vertex arrays)
    //
    // Everything below is built from those. Read out of the bundle and
    // confirmed in a browser before a line of it was written, because a
    // capability claim about this library has been wrong before - which is the
    // whole reason the requirement-direction gate exists.
    //
    // WHY EXPLICIT VERTICES rather than three.js's own geometry classes: the
    // bundle is tree-shaken. SphereGeometry, BoxGeometry, ConeGeometry and
    // CylinderGeometry survive because the library itself draws items and
    // arrowheads with them; OctahedronGeometry, TetrahedronGeometry,
    // IcosahedronGeometry and TorusGeometry are not in the file at all. Reading
    // a constructor off an instance only reaches the classes that survived, so
    // a mapping built that way could offer four shapes and no more. Vertices
    // reach all of them and depend on nothing that tree-shaking can remove.

    var THREE_CTOR = null;

    // Everything this file needs, taken off one Mesh the library made. Returns
    // false when there is nothing to take it from - an empty payload draws no
    // items - and the caller then leaves the library's own default alone, which
    // is the correct drawing for a graph with nothing in it.
    function harvestConstructors(scene) {
        if (THREE_CTOR) { return true; }
        var found = null;
        scene.traverse(function (obj) {
            if (!found && obj.__graphObjType === 'node' && obj.geometry && obj.material) { found = obj; }
        });
        if (!found) { return false; }

        try {
            var geometry = found.geometry;
            THREE_CTOR = {
                Mesh: found.constructor,
                Material: found.material.constructor,
                Color: found.material.color.constructor,
                BufferGeometry: Object.getPrototypeOf(geometry.constructor),
                Attribute: geometry.attributes.position.constructor,
                Sphere: geometry.constructor
            };
        }
        catch (err) {
            THREE_CTOR = null;
            return false;
        }
        return true;
    }

    // -- vertex helpers ----------------------------------------------------

    function pushTriangle(out, a, b, c) {
        out.push(a[0], a[1], a[2], b[0], b[1], b[2], c[0], c[1], c[2]);
    }

    // A face given as a fan of vertices, which is every flat face here.
    function pushFace(out, points) {
        for (var i = 1; i < points.length - 1; i++) {
            pushTriangle(out, points[0], points[i], points[i + 1]);
        }
    }

    function scalePoints(points, r) {
        var out = [];
        for (var i = 0; i < points.length; i++) {
            out.push([points[i][0] * r, points[i][1] * r, points[i][2] * r]);
        }
        return out;
    }

    // Non-indexed triangles and computed normals, which gives FLAT shading:
    // each face gets one normal, so an octahedron reads as eight facets rather
    // than as a lumpy ball. That is the whole reason to have shapes at all -
    // a smoothed polyhedron is a sphere with extra steps.
    function geometryFrom(positions) {
        var geometry = new THREE_CTOR.BufferGeometry();
        geometry.setAttribute('position', new THREE_CTOR.Attribute(new Float32Array(positions), 3));
        geometry.computeVertexNormals();
        return geometry;
    }

    // -- the shapes --------------------------------------------------------
    //
    // Each takes a radius and returns a geometry whose visual weight is close
    // to a sphere of that radius. Not its bounding radius: a cube drawn to the
    // sphere's radius looks much bigger than the sphere, because it fills the
    // corners the sphere leaves empty. The multipliers below are what makes a
    // mapping legible - four shapes that all read as the same SIZE, differing
    // only in silhouette, so shape carries classification and size stays free
    // for NodeSizeMetric.

    function buildBox(r) {
        var h = r * 0.82;
        var v = [
            [-h, -h, -h], [h, -h, -h], [h, h, -h], [-h, h, -h],
            [-h, -h, h], [h, -h, h], [h, h, h], [-h, h, h]
        ];
        var out = [];
        pushFace(out, [v[4], v[5], v[6], v[7]]);
        pushFace(out, [v[1], v[0], v[3], v[2]]);
        pushFace(out, [v[3], v[7], v[6], v[2]]);
        pushFace(out, [v[0], v[1], v[5], v[4]]);
        pushFace(out, [v[1], v[2], v[6], v[5]]);
        pushFace(out, [v[0], v[4], v[7], v[3]]);
        return geometryFrom(out);
    }

    function buildOctahedron(r) {
        var s = r * 1.18;
        var p = [[s, 0, 0], [-s, 0, 0], [0, s, 0], [0, -s, 0], [0, 0, s], [0, 0, -s]];
        var faces = [
            [0, 2, 4], [2, 1, 4], [1, 3, 4], [3, 0, 4],
            [2, 0, 5], [1, 2, 5], [3, 1, 5], [0, 3, 5]
        ];
        var out = [];
        for (var i = 0; i < faces.length; i++) {
            pushTriangle(out, p[faces[i][0]], p[faces[i][1]], p[faces[i][2]]);
        }
        return geometryFrom(out);
    }

    function buildTetrahedron(r) {
        var s = r * 1.32;
        var p = scalePoints([[1, 1, 1], [-1, -1, 1], [-1, 1, -1], [1, -1, -1]], s / Math.sqrt(3));
        var faces = [[0, 1, 2], [0, 3, 1], [0, 2, 3], [1, 3, 2]];
        var out = [];
        for (var i = 0; i < faces.length; i++) {
            pushTriangle(out, p[faces[i][0]], p[faces[i][1]], p[faces[i][2]]);
        }
        return geometryFrom(out);
    }

    function buildIcosahedron(r) {
        var t = (1 + Math.sqrt(5)) / 2;
        var raw = [
            [-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0],
            [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t],
            [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1]
        ];
        var p = scalePoints(raw, r / Math.sqrt(1 + t * t));
        var faces = [
            [0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
            [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
            [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
            [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]
        ];
        var out = [];
        for (var i = 0; i < faces.length; i++) {
            pushTriangle(out, p[faces[i][0]], p[faces[i][1]], p[faces[i][2]]);
        }
        return geometryFrom(out);
    }

    // Radially swept shapes. Enough segments to read as round at the sizes
    // this renderer draws and few enough that a 500-item payload is still a
    // few hundred thousand triangles rather than millions.
    var RADIAL_SEGMENTS = 18;

    function buildCone(r) {
        var radius = r * 1.15, height = r * 2.3, out = [];
        var apex = [0, height / 2, 0];
        for (var i = 0; i < RADIAL_SEGMENTS; i++) {
            var a = (i / RADIAL_SEGMENTS) * Math.PI * 2;
            var b = ((i + 1) / RADIAL_SEGMENTS) * Math.PI * 2;
            var p1 = [Math.cos(a) * radius, -height / 2, Math.sin(a) * radius];
            var p2 = [Math.cos(b) * radius, -height / 2, Math.sin(b) * radius];
            pushTriangle(out, apex, p1, p2);
            pushTriangle(out, [0, -height / 2, 0], p2, p1);
        }
        return geometryFrom(out);
    }

    function buildCylinder(r) {
        var radius = r * 0.95, height = r * 1.9, out = [];
        for (var i = 0; i < RADIAL_SEGMENTS; i++) {
            var a = (i / RADIAL_SEGMENTS) * Math.PI * 2;
            var b = ((i + 1) / RADIAL_SEGMENTS) * Math.PI * 2;
            var ca = Math.cos(a) * radius, sa = Math.sin(a) * radius;
            var cb = Math.cos(b) * radius, sb = Math.sin(b) * radius;
            var top1 = [ca, height / 2, sa], top2 = [cb, height / 2, sb];
            var bot1 = [ca, -height / 2, sa], bot2 = [cb, -height / 2, sb];
            pushTriangle(out, top1, bot1, bot2);
            pushTriangle(out, top1, bot2, top2);
            pushTriangle(out, [0, height / 2, 0], top2, top1);
            pushTriangle(out, [0, -height / 2, 0], bot1, bot2);
        }
        return geometryFrom(out);
    }

    function buildTorus(r) {
        var ring = r * 0.95, tube = r * 0.38, out = [];
        var major = RADIAL_SEGMENTS, minor = 10;
        function point(i, j) {
            var u = (i / major) * Math.PI * 2, v = (j / minor) * Math.PI * 2;
            return [
                (ring + tube * Math.cos(v)) * Math.cos(u),
                tube * Math.sin(v),
                (ring + tube * Math.cos(v)) * Math.sin(u)
            ];
        }
        for (var i = 0; i < major; i++) {
            for (var j = 0; j < minor; j++) {
                var a = point(i, j), b = point(i + 1, j), c = point(i + 1, j + 1), d = point(i, j + 1);
                pushTriangle(out, a, b, c);
                pushTriangle(out, a, c, d);
            }
        }
        return geometryFrom(out);
    }

    // The vocabulary, and the only place it is written down as buildable
    // geometry. settings.schema.psd1 lists the same names as the Values of
    // NodeShapeFallback and UnresolvedShape; a name in one and not the other
    // resolves to the fallback rather than throwing, because a producer's
    // classification must never be able to take the page down.
    var SHAPE_BUILDERS = {
        sphere: function (r) { return new THREE_CTOR.Sphere(r, 18, 12); },
        box: buildBox,
        octahedron: buildOctahedron,
        tetrahedron: buildTetrahedron,
        icosahedron: buildIcosahedron,
        cone: buildCone,
        cylinder: buildCylinder,
        torus: buildTorus
    };

    // Built geometries are CACHED by shape and radius, and that is not a
    // micro-optimisation. Every item gets its own Mesh and they share the
    // geometry behind it: a 532-item payload builds eight geometries rather
    // than 532, and three.js uploads each one to the GPU once.
    var GEOMETRY_CACHE = {};

    function geometryFor(shape, radius) {
        var name = SHAPE_BUILDERS[shape] ? shape : null;
        if (!name) { return null; }
        // Radius quantised, so items whose metric differs in the sixth decimal
        // do not each get a geometry of their own.
        var key = name + '@' + radius.toFixed(2);
        if (!GEOMETRY_CACHE[key]) { GEOMETRY_CACHE[key] = SHAPE_BUILDERS[name](radius); }
        return GEOMETRY_CACHE[key];
    }

    function isBuildableShape(name) {
        return Object.prototype.hasOwnProperty.call(SHAPE_BUILDERS, name);
    }

    // -- the mapping -------------------------------------------------------
    //
    // `kind=shape` pairs, separated by `;` or `,`. A String rather than a map
    // because there is no ShapeMap type and adding one is a module change; see
    // Config/settings.schema.psd1. The parsing is here rather than in
    // PowerShell for the same reason the shape names are: this is the only
    // layer that knows which geometries exist.
    //
    // Nothing here knows a classification. The keys are whatever the payload
    // carries and the map is whatever the theme names, exactly as colorFor
    // works - so a producer's vocabulary never reaches this file.
    function parseShapeMap(text) {
        var map = {};
        if (typeof text !== 'string' || !text) { return map; }
        var pairs = text.split(/[;,]/);
        for (var i = 0; i < pairs.length; i++) {
            var pair = pairs[i];
            var eq = pair.indexOf('=');
            if (eq < 0) { continue; }
            var kind = pair.slice(0, eq).trim();
            var shape = pair.slice(eq + 1).trim().toLowerCase();
            // An unbuildable name is DROPPED rather than kept, so the item
            // takes the declared fallback. A typo degrades one classification
            // and the rest of the page is unaffected.
            if (kind && isBuildableShape(shape)) { map[kind] = shape; }
        }
        return map;
    }
