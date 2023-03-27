# Important References:
# (1) https://www.youtube.com/watch?v=MkFS6lw6aEs
# (2) "Real Shading in Unreal Engine" by Brian Karis, Epic Games
# (3) GAMES202 Lecture5 Slides

# Assume z+ is upward

import pathlib
import pickle
import taichi as ti
import numpy as np
import os
os.environ["OPENCV_IO_ENABLE_OPENEXR"]="1"
import cv2
from PIL import Image

vec4f = ti.types.vector(4, ti.f32)
vec3f = ti.types.vector(3, ti.f32)
vec2f = ti.types.vector(2, ti.f32)
PI = 3.14159265359
WIDTH = 512
HEIHGT = 512
current_dir = pathlib.Path(__file__).parent
ti.init(arch=ti.cuda)
pixels = ti.Vector.field(4, ti.f32, shape=(WIDTH, HEIHGT))
samples = ti.field(ti.i32, shape=(WIDTH, HEIHGT))


def main():
    gui = ti.GUI("Split Sum", (WIDTH, HEIHGT))
    n = 0
    clear()
    # Integrate
    while gui.running:
        precompute_brdf(n / (n + 1), 1 / (n + 1), n)
        if n % 360 == 0:
            gui.set_image(pixels)
            gui.show()
        n += 1
    # Post-processing
    # saturate_buffer()
    set_alpha()
    current_dir = pathlib.Path(__file__).parent
    # Save pickle
    output_file = current_dir / "precompute_brdf.pkl"
    pixel_np = pixels.to_numpy()
    print(pixel_np.min(), pixel_np.max())
    output_file.write_bytes(pickle.dumps(pixel_np))
    # Save PNG
    output_png = current_dir / "precompute_brdf.png"
    image = Image.fromarray(np.uint8(pixel_np * 255)).rotate(90)
    image.save(str(output_png))
    # Save OpenEXR
    cv2.imwrite("precompte_brdf.exr", cv2.cvtColor(cv2.rotate(pixel_np, cv2.ROTATE_90_COUNTERCLOCKWISE), cv2.COLOR_BGR2RGB))


@ti.kernel
def clear():
    for i, j in pixels:
        pixels[i, j] = [0, 0, 0, 0]
        samples[i, j] = 0


@ti.kernel
def saturate_buffer():
    for i, j in pixels:
        pixels[i, j] = ti.min(1, ti.max(0, pixels[i, j]))


@ti.kernel
def set_alpha():
    for i, j in pixels:
        pixels[i, j][3] = 1


@ti.kernel
def precompute_brdf(weight_1: ti.f32, weight_2: ti.f32, n: ti.i32):
    for i, j in pixels:
        # Input
        n_v = saturate(ti.cast(i, ti.f32) / WIDTH, 1e-6) + ti.random() / WIDTH
        roughness = ti.cast(j, ti.f32) / HEIHGT + ti.random() / HEIHGT

        # Sampling
        v = vec3f(ti.sqrt(1 - n_v * n_v), 0, n_v)
        h = sample_GGX_halfway(roughness)
        l = 2 * v.dot(h) * h - v

        # Integrate
        n_l = saturate(l[2])
        n_h = saturate(h[2])
        v_h = saturate(v.dot(h))
        if n_l > 0:
            A = G(l, v, roughness) * v_h / (n_h * n_v)
            B = ti.pow(1 - v_h, 5)
            integral1 = A * (1 - B)
            integral2 = A * B
            num_samples = ti.cast(samples[i, j], ti.f32)
            w_a = num_samples / (num_samples + 1)
            w_b = 1 / (num_samples + 1)
            pixels[i, j] = w_a * pixels[i, j] + w_b * vec4f([integral1, integral2, 0, 0])
            samples[i, j] = samples[i, j] + 1


@ti.func
def sample_GGX_halfway(roughness: ti.f32) -> vec3f:
    u = ti.random()
    v = ti.random()
    l = vec2f([0, 0])
    a = roughness * roughness
    l[0] = ti.acos(ti.sqrt((1 - u) / (u * (a * a - 1) + 1)))  # theta
    l[1] = 2 * PI * v
    return sphere2unit(l)


@ti.func
def sphere2unit(v: vec2f) -> vec3f:
    theta = v[0]
    phi = v[1]
    x = ti.sin(theta) * ti.cos(phi)
    y = ti.sin(theta) * ti.sin(phi)
    z = ti.cos(theta)
    return vec3f([x, y, z])


@ti.func
def G(l: vec3f, v: vec3f, roughness: ti.f32):
    return G1(l, roughness) * G1(v, roughness)


@ti.func
def G1(v: vec3f, roughness: ti.f32):
    k = roughness * roughness / 2  # ti.pow(roughness + 1, 2) / 8
    nv = v[2]
    return nv / (nv * (1 - k) + k)


@ti.func
def chi_p(f: ti.f32):
    result = 0
    if f > 0:
        result = 1
    return result


@ti.func
def saturate(f: ti.f32, low: ti.f32 = 0):
    result = f
    if f <= 0:
        result = low
    elif f > 1:
        result = 1
    return result


if __name__ == "__main__":
    main()
