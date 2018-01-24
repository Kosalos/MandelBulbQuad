#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

#define WIDTH (32*9) // divisible by threadgroups (32)

#define VMAX  int((255000000 / sizeof(TVertex)) - 10000)

typedef struct {
    unsigned char data[WIDTH][WIDTH][WIDTH];
} Map3D;

typedef struct {
    float basex;
    float basey;
    float basez;
    float scale;
    float power;
    float re1;
    float im1;
    float mult1;
    float zoom1;
    float re2;
    float im2;
    float mult2;
    float zoom2;
    
    int formula;
    int hop;
    int center;
    int spread;
    int offset;
    int range;
    int unused1;
    int unused2;
    int unused3;
} Control;

typedef struct {
    int count;
} Counter;

typedef struct {
    int count[256];
} Histogram;

typedef struct {
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
    matrix_float4x4 mvp;
    vector_float3 light;
    float pointSize;
} Uniforms;

typedef struct {
    vector_float3 pos;
    vector_float4 color;
} TVertex;

#endif /* ShaderTypes_h */

