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

    // -- the environment ---------------------------------------------------
    //
    // The graph needed something to sit ON. Until v0.17.0 a fitted view put a
    // cloud of items in the middle of an unbroken rectangle, and a cloud with
    // no reference has no near and no far: fog said "this one is further" and
    // nothing said how much further, because there was nothing at a known
    // distance to compare it against. A ruled surface is what supplies that,
    // and it is the oldest trick in the drawing of three dimensions.
    //
    // QUADS RATHER THAN LINES, and that is forced rather than chosen. The
    // vendored bundle draws every link as a CYLINDER whenever EdgeWidth is
    // above zero, so at runtime there is no Line constructor anywhere in the
    // scene to harvest one from - traversed and confirmed, every
    // __graphObjType in the scene is a Mesh. Reading a constructor off an
    // instance only ever reaches the classes the library itself used, which is
    // the same tree-shaking limit that made the shape vocabulary explicit
    // vertices in the first place.
    //
    // ONE MESH FOR THE WHOLE ENVIRONMENT, built into a single geometry. A
    // `room` at sixteen divisions is 204 quads; as 204 objects that is 204
    // draw calls on every frame of a view whose whole job is to stay smooth
    // under a drag.

    function gridPoint(o, u, v, a, b) {
        return [
            o[0] + u[0] * a + v[0] * b,
            o[1] + u[1] * a + v[1] * b,
            o[2] + u[2] * a + v[2] * b
        ];
    }

    // One ruled line, as a quad lying IN the plane its two axes span.
    function pushGridLine(out, o, u, v, a0, a1, b0, b1) {
        pushFace(out, [
            gridPoint(o, u, v, a0, b0),
            gridPoint(o, u, v, a1, b0),
            gridPoint(o, u, v, a1, b1),
            gridPoint(o, u, v, a0, b1)
        ]);
    }

    // A ruled plane centred on `origin`, spanned by two unit axes.
    function pushGridPlane(out, origin, u, v, halfU, halfV, divisions, width) {
        var half = width / 2;
        var i, t;
        for (i = 0; i <= divisions; i++) {
            t = -halfU + 2 * halfU * (i / divisions);
            pushGridLine(out, origin, u, v, t - half, t + half, -halfV, halfV);
        }
        for (i = 0; i <= divisions; i++) {
            t = -halfV + 2 * halfV * (i / divisions);
            pushGridLine(out, origin, u, v, -halfU, halfU, t - half, t + half);
        }
    }

    var X = [1, 0, 0], Y = [0, 1, 0], Z = [0, 0, 1];

    // The vocabulary, and the only place it is written down as buildable
    // geometry - the same rule SHAPE_BUILDERS follows. settings.schema.psd1
    // lists these names as the Values of GridStyle; a name in one and not the
    // other draws nothing rather than throwing.
    //
    //   floor  one ruled plane under the graph. The classic, and the one that
    //          answers "how far down is that item" without adding anything
    //          the reader has to look past.
    //   room   floor, ceiling and four walls. Reads from EVERY angle, which a
    //          floor does not: rotate a floor-only scene to eye level and the
    //          reference disappears exactly when the parallax is best.
    var GRID_BUILDERS = {
        // A ground plane sits just under the LOWEST item rather than a whole
        // extent below the centre, which is where a floor is. Placed a full
        // reach down it reads as a separate object in the distance and stops
        // answering the question it is there for - how far down is that.
        floor: function (out, c, r, d, w, floorY) {
            pushGridPlane(out, [c[0], floorY, c[2]], X, Z, r, r, d, w);
        },
        // The enclosure is centred on the graph on all six sides, because the
        // whole point of it is that there is a reference whichever way the
        // reader turns.
        room: function (out, c, r, d, w) {
            pushGridPlane(out, [c[0], c[1] - r, c[2]], X, Z, r, r, d, w);
            pushGridPlane(out, [c[0], c[1] + r, c[2]], X, Z, r, r, d, w);
            pushGridPlane(out, [c[0], c[1], c[2] - r], X, Y, r, r, d, w);
            pushGridPlane(out, [c[0], c[1], c[2] + r], X, Y, r, r, d, w);
            pushGridPlane(out, [c[0] - r, c[1], c[2]], Z, Y, r, r, d, w);
            pushGridPlane(out, [c[0] + r, c[1], c[2]], Z, Y, r, r, d, w);
        }
    };

    function isBuildableGrid(name) {
        return Object.prototype.hasOwnProperty.call(GRID_BUILDERS, name);
    }

    // `centre` and `reach` come from the graph's own bounding box, so the
    // environment is the size of the thing it is drawn around rather than a
    // number that happened to suit one payload. A grid built to a constant is
    // a grid that is either inside a large graph or a speck under a small one.
    function buildGridGeometry(style, centre, reach, divisions, width, floorY) {
        if (!THREE_CTOR || !isBuildableGrid(style)) { return null; }
        var out = [];
        GRID_BUILDERS[style](out, centre, reach, divisions, width, floorY);
        if (!out.length) { return null; }
        return geometryFrom(out);
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
