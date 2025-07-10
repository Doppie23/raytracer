#version 300 es

#define PI 3.141592
precision highp float;

// either the hardware limit or 32
// because we only have 32 texture units available in openGL
#define MAX_TEXTURE_IMAGES (min(gl_MaxTextureImageUnits, 32) - 2) // minus 2 as we need to use two as render targets

#define IMAGE_SIZE (MAX_TEXTURE_IMAGES / 2)
// #define UV_SIZE (MAX_TEXTURE_IMAGES / 2)
#define SPHERE_SIZE 12
#define PLANE_SIZE 12
#define LIGHT_SIZE 12
#define MAX_MAX_RECURSION_DEPTH 10 // the max for the max...

struct Ray {
    vec3 origin;
    vec3 direction;
};

struct Camera {
    vec3 position;
    vec3 direction;
    float fov;
};

struct Texture {
    vec3 albedo;
    float specular;
    int shininess;
    float reflectivity;
    float roughness;
    bool hasImage;
    int textureIndex;
};

struct Intersection {
    bool hit;
    float t;
    vec3 point;
    // TODO: use enum, or just variables
    int type; // 0 = sphere, 1 = floor, 2 = plane
    int index;
};

struct Sphere {
    vec3 position;
    float radius;
    Texture texture;
};

struct Floor {
    vec3 position;
    float textureSize;
    Texture texture;
};

struct Light {
    vec3 position;
    vec3 color;
    float intensity;
};

struct Sky {
    Texture texture;
    vec3 color;
};

in vec2 v_Uv;

uniform sampler2D previousFrame;
uniform int numOfSamples;

uniform sampler2D textures[IMAGE_SIZE];

uniform float seed;

uniform int maxRecursionDepth;
uniform int width;
uniform int heigth;
uniform Camera camera;

uniform Floor floorPlane;
uniform bool shadeFloor;

uniform Sphere sphere[SPHERE_SIZE];
uniform int sphereCount;

uniform Light light[LIGHT_SIZE];
uniform int lightCount;

uniform Sky sky;
uniform float ambientIntensity;

Intersection noIntersection() {
    return Intersection(false, 0.0, vec3(0.0), -1, -1);
}

vec3 getTextureColor(int index, vec2 uv) {
    vec3 color;
    // TODO: get a version with dynamic indexing
    if (index == 0) color = texture(textures[0], uv).rgb;
    else if (index == 1) color = texture(textures[1], uv).rgb;
    else if (index == 2) color = texture(textures[2], uv).rgb;
    else if (index == 3) color = texture(textures[3], uv).rgb;
    else if (index == 4) color = texture(textures[4], uv).rgb;
    else if (index == 5) color = texture(textures[5], uv).rgb;
    // else if (index == 6) color = texture(textures[6], uv).rgb;
    // else if (index == 7) color = texture(textures[7], uv).rgb;
    return color;
}

// https://stackoverflow.com/questions/4200224/random-noise-functions-for-glsl
float rand(inout vec2 co) {
    float res = fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
    co += vec2(1.0); // update co reference value, so it can be reused
    return res;
}

vec3 randomDirection(inout vec2 co) {
    float x = rand(co) * 2.0 - 1.0;
    float y = rand(co) * 2.0 - 1.0;
    float z = rand(co) * 2.0 - 1.0;

    return vec3(x, y, z);
}

vec3 getPoint(Ray ray, float t) {
    return ray.origin + (ray.direction * t);
}

vec2 getSphereUv(vec3 normal) {
    float u = 0.5 + atan(normal.z, normal.x) / (2.0 * PI);
    float v = 0.5 + asin(normal.y) / PI;
    return vec2(u, v);
}

vec3 getSphereNormal(Sphere sphere, vec3 point, vec2 uv) {
    vec3 normal = normalize(point - sphere.position);
    // if (!sphere.texture.hasNormalMap)
        return normal;
    //
    // vec3 uvNormal = getNormalVectorFromMap(sphere.texture.normalMapIndex, uv);
    //
    // vec3 uvPlaneNormal = vec3(0, 1, 0);
    //
    // vec3 rotationAxis = normalize(cross(normal, uvPlaneNormal));
    //
    // float rotationAngle = acos(dot(uvPlaneNormal, normal));
    //
    // mat3 rotationMatrix = rotationMatrix(rotationAxis, rotationAngle);
    //
    // return normalize(uvNormal * rotationMatrix);
}

float getDistanceToViewPlane(float planeWidth, float planeHeight) {
    return sqrt((planeWidth * planeWidth) + (planeHeight * planeHeight)) / (2.0 * tan(radians(camera.fov / 2.0)));
}

Ray getRayForPixel(Camera camera, vec2 uv) {
    float planeWidth;
    float planeHeight;
    if (width >= heigth) {
        planeWidth = 1.0;
        planeHeight = 1.0 * float(heigth) / float(width);
    } else {
        planeWidth = 1.0 * float(width) / float(heigth);
        planeHeight = 1.0;
    }

    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), camera.direction));
    vec3 up = cross(camera.direction, right);

    vec3 centerPlane = camera.position + camera.direction * getDistanceToViewPlane(planeWidth, planeHeight);

    vec3 p0 = centerPlane + (planeHeight / 2.0) * up - (planeWidth / 2.0) * right;
    vec3 p1 = centerPlane + (planeHeight / 2.0) * up + (planeWidth / 2.0) * right;
    vec3 p2 = centerPlane - (planeHeight / 2.0) * up - (planeWidth / 2.0) * right;

    vec3 pixelLocation = p0 + uv.x * (p1 - p0) + uv.y * (p2 - p0);
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

Intersection intersectsFloor(Ray ray, Floor floorPlane) {
    if (ray.direction.y == 0.0) {
        return noIntersection();
    }

    float t = (floorPlane.position.y - ray.origin.y) / ray.direction.y;

    if (t < 0.001)
        return noIntersection();

    return Intersection(
        true,
        t,
        getPoint(ray, t),
        1,
        -1
    );
}

vec2 getFloorUv(Floor floorPlane, vec3 point) {
    float modU = mod(point.x, floorPlane.textureSize);
    float modV = mod(point.z, floorPlane.textureSize);

    if (modU < 0.0)
        modU += floorPlane.textureSize;
    if (modV < 0.0)
        modV += floorPlane.textureSize;

    float u = modU / floorPlane.textureSize;
    float v = modV / floorPlane.textureSize;

    return vec2(u, v);
}

vec3 getFloorNormal(Floor floorPlane, vec2 uv) {
    // if (!floorPlane.texture.hasNormalMap)
        return vec3(0.0, 1.0, 0.0);
    // return getNormalVectorFromMap(floorPlane.texture.normalMapIndex, uv);
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
    for (int i = 0; i < sphereCount; i++) {
        Sphere sphere = sphere[i];

        Intersection intersection = intersectsSphere(ray, sphere, i);
        updateClosestIntersection(
            intersection,
            closestIntersection
        );
    }

    // floor
    Intersection floorIntersection = intersectsFloor(ray, floorPlane);
    updateClosestIntersection(
        floorIntersection,
        closestIntersection
    );

    return closestIntersection;
}

bool isInShadow(Ray rayToLight, Light light) {
    Intersection closestIntersection = getClosestIntersection(rayToLight);

    if (closestIntersection.hit) {
        // the t value for the ray to get to the light source
        float tLight = (light.position.x - rayToLight.origin.x) / rayToLight.direction.x;

        if (closestIntersection.t < tLight) {
            return true;
        }
    }
    return false;
}

vec3 lightContribution(Light light, Intersection intersection) {
    vec3 eLight = light.intensity * light.color;
    float dist = distance(intersection.point, light.position);
    return eLight * (1.0 / (dist * dist));
}

vec3 diffuseColor(vec3 albedo, vec3 n, vec3 l) {
    return albedo * max(0.0, dot(n, l));
}

float specularIntensity(float specular, int shininess, vec3 v, vec3 r) {
    float ks = specular;
    float max2 = max(0.0, dot(v, r));
    return ks * pow(max2, float(shininess));
}

struct HitData {
    vec3 finalColor;
    vec3 albedo;
    Texture texture;
};

// recursion is not a thing in glsl
// which makes this function kinda messy
vec3 traceRay(Ray ray, inout vec2 co) {
    // keep track of all needed information for each hit
    // that we trace
    // so we can calculate the final color at the end
    HitData[MAX_MAX_RECURSION_DEPTH] hitData;
    int hitObjectsLength = 0;

    for (int bounces = 0; bounces <= MAX_MAX_RECURSION_DEPTH; bounces++) {
        if (bounces >= maxRecursionDepth) {
            return vec3(0.0);
        }

        Intersection intersection = getClosestIntersection(ray);

        // sky intersection
        if (!intersection.hit) {
            vec3 skyColor;
            if (sky.texture.textureIndex >= 0 && sky.texture.hasImage) {
                vec2 uv = getSphereUv(-ray.direction);
                skyColor = getTextureColor(sky.texture.textureIndex, uv);
            } else {
                skyColor = sky.texture.albedo;
            }

            if (bounces == 0) {
                return skyColor;
            } else {
                hitData[hitObjectsLength++] = HitData(
                    skyColor,
                    sky.texture.albedo,
                    sky.texture
                );
                break;
            }
        }

        // get texture and normal from hit object

        Texture texture;
        vec3 n;
        vec2 uv;

        if (intersection.type == 0) {
            Sphere sphere = sphere[intersection.index];
            vec3 normal = normalize(intersection.point - sphere.position);
            texture = sphere.texture;
            uv = getSphereUv(normal);
            n = getSphereNormal(sphere, intersection.point, uv);
        } else if (intersection.type == 1) {
            texture = floorPlane.texture;
            uv = getFloorUv(floorPlane, intersection.point);
            n = getFloorNormal(floorPlane, uv);
        // } else if (intersection.type == 2) {
        //     Plane plane = plane[intersection.index];
        //     texture = plane.texture;
        //     uv = getPlaneUv(plane, intersection.point);
        //     n = getPlaneNormal(plane, ray.origin, uv);
        } else {
            // unknown object
            return vec3(0.0);
        }

        vec3 albedo;
        if (texture.hasImage) {
            albedo = getTextureColor(texture.textureIndex, uv);
        } else {
            albedo = texture.albedo;
        }

        ////////////////////////////////////////////////////////////////////////////////
        // Shading
        ////////////////////////////////////////////////////////////////////////////////

        vec3 v = ray.direction;

        vec3 finalColor = vec3(0.0);
        for (int i = 0; i < lightCount; i++) {
            Light light = light[i];

            Ray rayToLight = Ray(intersection.point, normalize(light.position - intersection.point));

            if (
                // !isInLightCone(light, intersection.point) ||
                isInShadow(rayToLight, light)
            )
                continue;

            vec3 l = rayToLight.direction;
            vec3 r = reflect(l, n);

            vec3 lightContribution = lightContribution(light, intersection);

            vec3 diffuse;
            if (intersection.type == 1 && !shadeFloor) {
                // is floor and shade floor is not enabled
                diffuse = albedo / float(lightCount);
            } else {
                diffuse = lightContribution * diffuseColor(albedo, n, l);
            }
            // diffuse should be less important the more reflective the object is
            diffuse *= 1.0 - texture.reflectivity;

            float specularIntensity = specularIntensity(
                                        texture.specular,
                                        texture.shininess,
                                        v,
                                        r
                                    );
            vec3 specular = lightContribution * specularIntensity;

            finalColor += diffuse + specular;
        }

        vec3 ambient = albedo * (sky.color * ambientIntensity);
        // ambient = (1.0 - texture.reflectivity) * ambient;
        finalColor += ambient;

        if (texture.reflectivity > 0.0) {
            if (texture.roughness <= 0.0 && texture.reflectivity >= 1.0) {
                // perfect reflection
                hitData[hitObjectsLength++] = HitData(
                    albedo,
                    vec3(0.0),
                    texture
                );

                ray = Ray(
                    intersection.point,
                    reflect(ray.direction, n)
                );
            } else {
                // imperfect reflection on rough surface
                hitData[hitObjectsLength++] = HitData(
                    finalColor,
                    albedo,
                    texture
                );

                vec3 perfectReflection = reflect(v, n);
                float invRoughness = 1.0 - texture.roughness;

                vec3 randomDirection = normalize(n + randomDirection(co));

                vec3 direction = normalize(mix(randomDirection, perfectReflection, invRoughness));

                ray = Ray(
                    intersection.point,
                    direction
                );
            }

            continue; // go to next bounce
        } else {
            hitData[hitObjectsLength++] = HitData(
                finalColor,
                albedo,
                texture
            );

            if (bounces == 0) {
                return finalColor;
            }
            break; // dont trace reflection further as object was not reflective
        }
    }

    if (hitObjectsLength == 0) {
        return vec3(0.0);
    } else if (hitObjectsLength == 1) {
        return hitData[0].finalColor;
    }

    // last object we hit should be a normal diffuse color without reflectivity
    vec3 recursionColor =
        hitData[hitObjectsLength - 1].finalColor;

    // backtrace all the intersections
    for (int i = hitObjectsLength - 2; i >= 0; i--) {
        Texture texture = hitData[i].texture;

        if (texture.reflectivity >= 1.0 && texture.roughness <= 0.0) {
            recursionColor *= hitData[i].finalColor;
        } else {
            recursionColor =
                hitData[i].finalColor
                + (hitData[i].albedo * texture.reflectivity * recursionColor);
        }
    }

    return recursionColor;
}


out vec4 outputColor;

void main() {
    vec2 co = v_Uv * seed;

    Ray ray = getRayForPixel(
        camera,
        v_Uv
    );

    vec3 color = traceRay(ray, co);
    outputColor = vec4(color, 1.0);

    if (numOfSamples > 0) {
        vec4 previousColor = texture(previousFrame, vec2(v_Uv.x, 1.0 - v_Uv.y));
        float f_numOfSamples = float(numOfSamples);
        outputColor = (previousColor * f_numOfSamples + outputColor) / (f_numOfSamples + 1.0);
    }


    // outputColor = vec4(vec3(sphere[2].texture.roughness), 1.0);
    // outputColor = vec4(ambientIntensity, 0.0, 0.0, 1.0);
    // outputColor = vec4(1.0, 0.0, 0.0, 1.0);

    // gl_FragColor = vec4(sphere[0].position, 1.0);
    // gl_FragColor = vec4(ray.direction, 1.0);
}
