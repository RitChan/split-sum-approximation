# Important References:
# (1) https://www.youtube.com/watch?v=MkFS6lw6aEs
# (2) "Real Shading in Unreal Engine" by Brian Karis, Epic Games
# (3) GAMES202 Lecture5 Slides

# Assume z+ is upward

import math
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
vec2i = ti.types.vector(2, ti.i32)
vec4i = ti.types.vector(4, ti.i32)
PI = 3.14159265359
HEIHGT = 2048
WIDTH = 2 * HEIHGT
current_dir = pathlib.Path(__file__).parent
ti.init(arch=ti.cuda)
samples = ti.field(ti.i32, shape=(WIDTH, HEIHGT))
exr_mipmap = ti.Vector.field(4, ti.f32, shape=(WIDTH, HEIHGT + HEIHGT // 2))
exr_mipmap_weights = ti.field(ti.f32, shape=(WIDTH, HEIHGT + HEIHGT // 2))
exr_original = ti.Vector.field(4, ti.f32, shape=(WIDTH, HEIHGT))
exr_padding = ti.Vector.field(4, ti.f32, shape=(WIDTH + 2 * WIDTH // 64, HEIHGT + 2 * HEIHGT // 64))
original_exr_name = "distribution_board_4k.exr"


def main():
    load_exr_original()
    padding_light()
    save_exr_padding()
    print("Done.")


def prefiltering():
    load_exr_original()
    clear(vec4f([0, 0, 0, 0]))
    copy_exr(exr_original, exr_mipmap, vec2i([0, 0]))
    mip_count = int(round(math.log2(WIDTH)))
    for i in range(1, mip_count + 1):
        print(f"Sampling {i}-th mipmap")
        for j in range(4096):
            (width, height), (x, y) = get_mipmap_size_origin(i)
            roughness = math.sqrt(i / mip_count)
            precompute_light(width, height, vec2i([x, y]), roughness)
            if j % 100 == 0:
                print(f"Iteration {j}") 
        # break
    for i in range(1, mip_count + 1):
        (width, height), (x, y) = get_mipmap_size_origin(i)
        apply_weights(width, height, vec2i([x, y]))
        # break
    save_exr_mipmap()
    print("Done.")


def load_exr_original():
    exr_path = current_dir / original_exr_name
    exr_original_np = cv2.imread(str(exr_path), cv2.IMREAD_ANYCOLOR | cv2.IMREAD_ANYDEPTH)
    exr_original_np = cv2.cvtColor(cv2.transpose(exr_original_np), cv2.COLOR_RGB2BGR)
    exr_original.from_numpy(exr_original_np)


def save_exr_mipmap():
    exr_mipmap_np = cv2.transpose(exr_mipmap.to_numpy())
    exr_mipmap_np = cv2.cvtColor(exr_mipmap_np, cv2.COLOR_BGR2RGB)
    original_exr_path = current_dir / original_exr_name
    output_exr_path = current_dir / (original_exr_path.with_suffix("").name + "_mipmap.exr")
    cv2.imwrite(str(output_exr_path), exr_mipmap_np)


def save_exr_padding():
    exr_padding_np = cv2.transpose(exr_padding.to_numpy())
    exr_padding_np = cv2.cvtColor(exr_padding_np, cv2.COLOR_BGR2RGB)
    original_exr_path = current_dir / original_exr_name
    output_exr_path = current_dir / (original_exr_path.with_suffix("").name + "_padding.exr")
    cv2.imwrite(str(output_exr_path), exr_padding_np)


def get_mipmap_size_origin(mip_level: int):
    if mip_level == 0:
        return (WIDTH, HEIHGT), (0, 0)
    denominator = 1 << mip_level  # 2 ^ mip_level
    width = max(WIDTH // denominator, 1)
    height = max(HEIHGT // denominator, 1)
    x = WIDTH - 2 * width
    y = HEIHGT
    return (width, height), (x, y)


@ti.kernel
def padding_light():
    for i, j in exr_padding:
        origin = vec2i(WIDTH // 64, HEIHGT // 64)
        sample_i = (i - origin[0]) % WIDTH
        sample_j = (j - origin[1]) % HEIHGT
        exr_padding[i, j] = exr_original[sample_i, sample_j]


@ti.kernel
def precompute_light(width: ti.i32, height: ti.i32, origin: vec2i, roughness: ti.f32):
    for k in range(width * height):
        # Find coordinates from k
        i: ti.i32 = k % width
        j: ti.i32 = k // width
        dst_i = i + origin[0]
        dst_j = j + origin[1]
        mipmap_u: ti.f32 = (ti.cast(i, ti.f32) + 0.5) / width
        mipmap_v: ti.f32 = (ti.cast(j, ti.f32) + 0.5) / height
        phi = mipmap_u * 2 * PI
        theta = mipmap_v * PI
        r = sphere2unit(vec2f(phi, theta))
        # Sample light
        v = r
        n = r
        h = sample_GGX_halfway(roughness, n)
        l = 2 * v.dot(h) * h - v
        n_l = saturate(n.dot(l))
        if n_l > 0:
            origin_angle = unit2sphere(l)
            origin_uv = origin_angle / vec2f([2 * PI, PI])
            origin_i = ti.cast(ti.floor(origin_uv[0] * WIDTH), ti.i32)
            origin_j = ti.cast(ti.floor(origin_uv[1] * HEIHGT), ti.i32)
            sample_col = exr_original[origin_i, origin_j]
            sample_weight = n_l
            exr_mipmap[dst_i, dst_j] += sample_col * sample_weight
            exr_mipmap_weights[dst_i, dst_j] += sample_weight


@ti.kernel
def apply_weights(width: ti.i32, height: ti.i32, origin: vec2i):
    for k in range(width * height):
        i: ti.i32 = k % width
        j: ti.i32 = k // width
        dst_i = i + origin[0]
        dst_j = j + origin[1]
        exr_mipmap[dst_i, dst_j] /= exr_mipmap_weights[dst_i, dst_j]


@ti.kernel
def clear(col: vec4f):
    for i, j in exr_mipmap:
        exr_mipmap[i, j] = col
        exr_mipmap_weights[i, j] = 0


@ti.kernel
def copy_exr(src: ti.template(), dst: ti.template(), dst_origin: vec2i):
    for i, j in src:
        dst_i = i + dst_origin[0]
        dst_j = j + dst_origin[1]
        if dst_i < dst.shape[0] and dst_j < dst.shape[1]:
            dst[dst_i, dst_j] = src[i, j]


@ti.func
def sample_GGX_halfway(roughness: ti.f32, n: vec3f = vec3f([0, 0, 1])) -> vec3f:
    k = sample_GGX_halfway_sphere(roughness)
    theta = k[0]
    phi = k[1]
    cos_theta = ti.cos(theta)
    sin_theta = ti.sin(theta)
    h = vec3f([sin_theta * ti.cos(phi), sin_theta * ti.sin(phi), cos_theta])
    up = vec3f([0, 0, 0])
    if abs(n.z) < 0.999:
        up = vec3f([0, 0, 1])
    else:
        up = vec3f([1, 0, 0])
    tangent_x = up.cross(n).normalized()
    tangent_y = n.cross(tangent_x).normalized()
    return tangent_x * h.x + tangent_y * h.y + n * h.z


@ti.func
def sample_GGX_halfway_sphere(roughness: ti.f32) -> vec2f:
    u = ti.random()
    v = ti.random()
    l = vec2f([0, 0])
    a = roughness * roughness
    l[0] = ti.acos(ti.sqrt((1 - u) / (u * (a * a - 1) + 1)))  # theta
    l[1] = 2 * PI * v
    return l



@ti.func
def sphere2unit(v: vec2f) -> vec3f:
    phi = v[0]
    theta = v[1]
    x = ti.sin(theta) * ti.cos(phi)
    y = ti.sin(theta) * ti.sin(phi)
    z = ti.cos(theta)
    return vec3f([x, y, z])


@ti.func
def unit2sphere(v: vec3f) -> vec2f:
    phi = ti.atan2(v[1], v[0])
    if phi < 0:
        phi += 2 * PI
    theta = ti.acos(v[2])
    return vec2f([phi, theta])


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
