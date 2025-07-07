#define PI 3.141592
precision highp float;

#define SPHERE_SIZE 12

struct Ray {
    vec3 origin;
    vec3 direction;
};

struct Camera {
    vec3 position;
    vec3 p0;
    vec3 p1;
    vec3 p2;
};

struct Intersection {
    bool hit;
    float t;
    vec3 point;
    int type; // 0 = sphere, 1 = floor, 2 = plane
    int index;
};

struct Sphere {
    vec3 position;
    float radius;
};

varying highp vec2 v_Uv;

uniform Camera camera;
uniform Sphere sphere[SPHERE_SIZE];
uniform int sphereCount;

Intersection noIntersection() {
    return Intersection(false, 0.0, vec3(0.0), -1, -1);
}

vec3 getPoint(Ray ray, float t) {
    return ray.origin + (ray.direction * t);
}

Ray getRayForPixel(Camera camera, vec2 uv) {
    vec3 pixelLocation = camera.p0 + uv.x * (camera.p1 - camera.p0) + uv.y * (camera.p2 - camera.p0);
    vec3 direction = pixelLocation - camera.position;

    return Ray(camera.position, normalize(direction));
}

Intersection intersectsSphere(Ray ray, Sphere sphere, int index) {
    vec3 oc = ray.origin - sphere.position;

    float a = dot(ray.direction, ray.direction);
    float b = 2.0 * dot(ray.direction, oc);
    float c = dot(oc, oc) - sphere.radius * sphere.radius;

    float d = b * b - 4.0 * a * c;
    if (d < 0.0)
        return noIntersection();

    float t2 = (-b - sqrt(d)) / (2.0 * a);

    if (t2 < 0.001)
        return noIntersection();

    return Intersection(
        true,
        t2,
        getPoint(ray, t2),
        0,
        index
    );
}

void updateClosestIntersection(Intersection intersection, inout Intersection closestIntersection) {
    if (intersection.hit) {
        if (
            !closestIntersection.hit
            || intersection.t < closestIntersection.t
        ) {
            closestIntersection = intersection;
        }
    }
}

Intersection getClosestIntersection(Ray ray) {
    Intersection closestIntersection = noIntersection();

    // spheres
    for (int i = 0; i < SPHERE_SIZE; i++) {
        if (i >= sphereCount) break;
        Sphere sphere = sphere[i];

        Intersection intersection = intersectsSphere(ray, sphere, i);
        updateClosestIntersection(
            intersection,
            closestIntersection
        );
    }

    return closestIntersection;
}

vec3 traceRay(Ray ray) {
    Intersection intersection = getClosestIntersection(ray);

    if (!intersection.hit) {
        return vec3(0.0, 0.0, 0.0);
    }

    return vec3(1.0, 0.0, 0.0);
}

void main() {
    Ray ray = getRayForPixel(
        camera,
        v_Uv
    );

    vec3 color = traceRay(ray);
    gl_FragColor = vec4(color, 1.0);

    // gl_FragColor = vec4(sphere[0].position, 1.0);
    // gl_FragColor = vec4(ray.direction, 1.0);
}
