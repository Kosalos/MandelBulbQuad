#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"

using namespace metal;

#define MAX_ITERATIONS 40
#define NUM_CLOUD 8
#define JULIA_FORMULA 5
#define BOX_FORMULA 6

kernel void mapShader
(
 device Map3D &src [[buffer(0)]],
 constant Control &control [[buffer(1)]],
 uint3 pp [[thread_position_in_grid]])
{
    device unsigned char &d = src.data[pp.x][pp.y][pp.z];
    unsigned char iter = 0;
    
    if(control.hop > 1) {
        if(int(pp.x) % control.hop) { d = 0; return; }
        if(int(pp.y) % control.hop) { d = 0; return; }
        if(int(pp.z) % control.hop) { d = 0; return; }
    }
    
    // run 1,2 or 4 interleaved clouds to add more points render    
    float offset = float(control.cloudIndex) / float(NUM_CLOUD);
    float fpx = float(pp.x) + offset;
    float fpy = float(pp.y) + offset;
    float fpz = float(pp.z) + offset;

    // 5 Julia ---------------------------------------------------------------------------
    if (control.formula == JULIA_FORMULA) {
        float re,im,mult,zoom;
        
        float ratio = fpz / float(WIDTH-1);
        re = control.re1 + (control.re2 - control.re1) * ratio;
        im = control.im1 + (control.im2 - control.im1) * ratio;
        mult = control.mult1 + (control.mult2 - control.mult1) * ratio;
        zoom = control.zoom1 + (control.zoom2 - control.zoom1) * ratio;
        
        float newRe, newIm, oldRe, oldIm;
        
        if(zoom == 0) zoom = 1;
        
        newRe = control.basex + fpx / zoom;
        newIm = control.basey + fpy / zoom;
        
        for(;;) {
            oldRe = newRe;
            oldIm = newIm;
            newRe = oldRe * oldRe - oldIm * oldIm + re;
            newIm = mult * oldRe * oldIm + im;
            
            if((newRe * newRe + newIm * newIm) > 4) break;
            if(++iter == MAX_ITERATIONS) {
                iter = 255;
                break;
            }
        }
        
        if(iter == MAX_ITERATIONS) iter = 0;
        d = iter;
        return;
    }
    
    float3 w;
    w.x = control.basex + fpx * control.scale;
    w.y = control.basey + fpy * control.scale;
    w.z = control.basez + fpz * control.scale;
    
    int insideCount = 0;
    
    // 0 Bulb 1 --------------------------------------------------------------------------------
    if (control.formula == 0) { // https://github.com/jtauber/mandelbulb/blob/master/mandel8.py
        float r,theta,phi,pwr,ss,dist;
        
        for(;;) {
            if(++iter == MAX_ITERATIONS) break;
            
            r = sqrt(w.x * w.x + w.y * w.y + w.z * w.z);
            theta = atan2(sqrt(w.x * w.x + w.y * w.y), w.z);
            phi = atan2(w.y,w.x);
            pwr = pow(r,control.power );
            ss = sin(theta * control.power);
            
            w.x += pwr * ss * cos(phi * control.power);
            w.y += pwr * ss * sin(phi * control.power);
            w.z += pwr * cos(theta * control.power);

            dist = w.x * w.x + w.y * w.y + w.z * w.z;

            if(dist > 2) break;
            
            if(dist < 1) {
                if(++insideCount > MAX_ITERATIONS/2) break;
            }
            else insideCount = 0;
        }
        
        if(iter == MAX_ITERATIONS) iter = 0;
        d = iter;
        return;
    }
    
    // 1 Bulb 2 -----------------------------------------------------------------------------------
    if (control.formula == 1) { // alternate Bulb
        float m = dot(w,w);
        float dz = 1.0;
        
        for(;;) {
            if(++iter == MAX_ITERATIONS) break;
            
            float m2 = m*m;
            float m4 = m2*m2;
            dz = 8.0*sqrt(m4*m2*m)*dz + 1.0;
            
            float x = w.x; float x2 = x*x; float x4 = x2*x2;
            float y = w.y; float y2 = y*y; float y4 = y2*y2;
            float z = w.z; float z2 = z*z; float z4 = z2*z2;
            
            float k3 = x2 + z2;
            float k2s = sqrt(  pow(k3,control.power ));
            float k2 = 1;  if(k2s != 0) k2 = 1.0 / k2s;
            float k1 = x4 + y4 + z4 - 6.0*y2*z2 - 6.0*x2*y2 + 2.0*z2*x2;
            float k4 = x2 - y2 + z2;
            
            w.x +=  64.0*x*y*z*(x2-z2)*k4*(x4-6.0*x2*z2+z4)*k1*k2;
            w.y +=  -16.0*y2*k3*k4*k4 + k1*k1;
            w.z +=  -8.0*y*k4*(x4*x4 - 28.0*x4*x2*z2 + 70.0*x4*z4 - 28.0*x2*z2*z4 + z4*z4)*k1*k2;
            
            m = dot(w,w);
            if( m > 4.0 ) break;
        }
        
        if(iter == MAX_ITERATIONS) iter = 0;
        d = iter;
        return;
    }
    
    float magnitude, r, theta_power, r_power, phi, phi_sin, phi_cos, xxyy;
    
    // 2 Bulb 3 -----------------------------------------------------------------------
    if (control.formula == 2) {
        for(;;) {
            if(++iter == MAX_ITERATIONS) break;
            
            xxyy = w.x * w.x + w.y * w.y;
            magnitude = xxyy + w.z * w.z;
            r = sqrt(magnitude);
            if(r > 8) break;

            theta_power = atan2(w.y,w.x) * control.power;
            r_power = pow(r,control.power);
            
            phi = asin(w.z / r);
            phi_cos = cos(phi * control.power);
            w.x += r_power * cos(theta_power) * phi_cos;
            w.y += r_power * sin(theta_power) * phi_cos;
            w.z += r_power * sin(phi * control.power);
        }
        
        if(iter == MAX_ITERATIONS) iter = 0;
        d = iter;
        return;
    }
    
    // 3 Bulb 4 -----------------------------------------------------------------------
    if (control.formula == 3) {
        for(;;) {
            if(++iter == MAX_ITERATIONS) break;

            xxyy = w.x * w.x + w.y * w.y;
            magnitude = xxyy + w.z * w.z;
            r = sqrt(magnitude);
            if(r > 8) break;

            theta_power = atan2(w.y,w.x) * control.power;
            r_power = pow(r,control.power);
            
            phi = atan2(sqrt(xxyy), w.z);
            phi_sin = sin(phi * control.power);
            w.x += r_power * cos(theta_power) * phi_sin;
            w.y += r_power * sin(theta_power) * phi_sin;
            w.z += r_power * cos(phi * control.power);
        }
        
        if(iter == MAX_ITERATIONS) iter = 0;
        d = iter;
        return;
    }
    
    // 4 Bulb 5 -----------------------------------------------------------------------
    if (control.formula == 4) {
        for(;;) {
            if(++iter == MAX_ITERATIONS) break;
            
            xxyy = w.x * w.x + w.y * w.y;
            magnitude = xxyy + w.z * w.z;
            r = sqrt(magnitude);
            if(r > 8) break;
            
            theta_power = atan2(w.y,w.x) * control.power;
            r_power = pow(r,control.power);
            
            phi = acos(w.z / r);
            phi_cos = cos(phi * control.power);
            w.x += r_power * cos(theta_power) * phi_cos;
            w.y += r_power * sin(theta_power) * phi_cos;
            w.z += r_power * sin(phi*control.power);
        }
        
        if(iter == MAX_ITERATIONS) iter = 0;
        d = iter;
    }

    // 6 Box -----------------------------------------------------------------------
    if (control.formula == 6) {
        float fLimit  = control.re1;
        float fValue  = control.im1;
        float mRadius = control.mult1;
        float fRadius = control.zoom1;
        float scale   = control.re2;
        float mr2 = mRadius * mRadius;
        float fr2 = fRadius * fRadius;
        float ffmm = fr2 / mr2;
        
        for(;;) {
            if(++iter == MAX_ITERATIONS) break;
            
            if(w.x > fLimit) w.x = fValue - w.x; else if(w.x < -fLimit) w.x = -fValue - w.x;
            if(w.y > fLimit) w.y = fValue - w.y; else if(w.y < -fLimit) w.y = -fValue - w.y;
            if(w.z > fLimit) w.z = fValue - w.z; else if(w.z < -fLimit) w.z = -fValue - w.z;
            
            r = w.x * w.x + w.y * w.y +w.z * w.z;
            if(r > control.im2) break;
            
            if(r < mr2) {
                float num = ffmm * scale;
                w.x *= num;
                w.y *= num;
                w.z *= num;
            }
            else
                if(r < fr2) {
                    float den = fr2 * scale / r;
                    w.x *= den;
                    w.y *= den;
                    w.z *= den;
                }
        }
        
        if(iter < 2 || iter == MAX_ITERATIONS) iter = 0;
        d = iter;
    }
}
    
    /*
     The Mandelbox is a folding fractal, generated by doing box folds and sphere folds.
     It was discovered by Tom Lowe (Tglad or T’glad on various forums).
     The folds are actually rather simple, but surprisingly, produce very interesting results.
     The basic iterative algorithm is:
     
     if (point.x > fold_limit) point.x = fold_value – point.x
     else if (point.x < -fold_limit) point.x = -fold_value – point.x
     
     do those two lines for y and z components.
     
     length = point.x*point.x + point.y*point.y + point.z*point.z
     
     if (length < min_radius*min_radius) multiply point by fixed_radius*fixed_radius / (min_radius*min_radius)
     else if (length < fixed_radius*fixed_radius) multiply point by fixed_radius*fixed_radius / length
     
     multiply point by mandelbox_scale and add position (or constant) to get a new value of point
     
     Typically,
     fold_limit is 1,
     fold_value is 2,
     min_radius is 0.5,
     fixed_radius is 1,
     and mandelbox_scale can be thought of as a specification of the type of Mandelbox desired.
     A nice value for that is -1.5 (but it can be positive as well).
     */

//===================================================================================
// remove totally surrounded points from the cloud by marking them as '255' (not rendered)

kernel void adjacentShader
(
 device Map3D &src [[buffer(0)]],
 uint3 p [[thread_position_in_grid]])
{
    unsigned char M = 3;
    unsigned char d = src.data[p.x][p.y][p.z];
    if(d < M) { src.data[p.x][p.y][p.z] = 255; return; }
    
    int x1 = p.x - 1; if(x1 < 0) x1 = 1;
    int y1 = p.y - 1; if(y1 < 0) y1 = 1;
    int z1 = p.z - 1; if(z1 < 0) z1 = 1;
    
    int z2 = p.z + 1; if(z2 == WIDTH) z2 = WIDTH-2;
    
    d = src.data[x1][y1][z1];   if(d < M || d == 255) return;
    d = src.data[x1][y1][z2];   if(d < M || d == 255) return;
    
    int y2 = p.y + 1; if(y2 == WIDTH) y2 = WIDTH-2;
    
    d = src.data[x1][y2][z1];   if(d < M || d == 255) return;
    d = src.data[x1][y2][z2];   if(d < M || d == 255) return;
    
    int x2 = p.x + 1; if(x2 == WIDTH) x2 = WIDTH-2;
    
    d = src.data[x2][y1][z1];   if(d < M || d == 255) return;
    d = src.data[x2][y1][z2];   if(d < M || d == 255) return;
    d = src.data[x2][y2][z1];   if(d < M || d == 255) return;
    d = src.data[x2][y2][z2];   if(d < M || d == 255) return;
    
    src.data[p.x][p.y][p.z] = 255;      // generated zero
}

//===================================================================================
// set cloud point value to average of neighboring points

#define X 1
#define Y WIDTH
#define Z (WIDTH * WIDTH)

#define CONVOLUTION_COUNT 27
constant int offset[] = {     // 3x3x3
    -X-Y-Z, -Y-Z, +X-Y-Z,
    -X-Z, -Z, +X-Z,
    -X+Y-Z, +Y-Z, +X+Y-Z,

    -X-Y, -Y, +X-Y,
    -X, 0, +X,
    -X+Y, +Y, +X+Y,

    -X-Y+Z, -Y+Z, +X-Y+Z,
    -X+Z, +Z, +X+Z,
    -X+Y+Z, +Y+Z, +X+Y+Z,
};

//#define CONVOLUTION_COUNT 7
//constant int offset[] = {   // diamond
//    -X,+X, -Y,+Y, -Z,+Z, 0
//};

kernel void smoothingShader
(
 constant Map3D &src [[buffer(0)]],
 device Map3D &dst [[buffer(1)]],
 uint3 p [[thread_position_in_grid]])
{
    bool skip = false;
    if(p.x == 0 || p.x == WIDTH-1) skip = true; else
        if(p.y == 0 || p.y == WIDTH-1) skip = true; else
            if(p.z == 0 || p.z == WIDTH-1) skip = true;
    
    if(skip) {
        dst.data[p.x][p.y][p.z] = src.data[p.x][p.y][p.z];
    }
    else {
        int total = 0;
        int count = 0;
        constant unsigned char *ptr = &src.data[p.x][p.y][p.z];
        unsigned char ch;
        
        for(int i=0;i<CONVOLUTION_COUNT;++i) {
            ch = *(ptr + offset[i]);
            if(ch > 0 && ch < 255) { // only include rendered points
                total += int(ch);
                ++count;
            }
        }
        
        if(count > 0) total /= count;
        
        dst.data[p.x][p.y][p.z] = (unsigned char)(total);
    }
}

//===================================================================================

kernel void quantizeShader
(
 device Map3D &src [[buffer(0)]],
 constant Control &control [[buffer(1)]],
 uint3 p [[thread_position_in_grid]])
{
    device unsigned char &d = src.data[p.x][p.y][p.z];
    unsigned char mask = (unsigned char)control.unused1;
    
    if(d > 0 && d < 255) { // only include rendered points
        d = 1 + (d & mask);
    }
}

//===================================================================================
// histogram[256] = # points of each value in whole cloud

kernel void histogramShader
(
 constant Map3D &src [[buffer(0)]],
 device Histogram *dst [[buffer(1)]],
 uint3 p [[thread_position_in_grid]])
{
    int value = int(src.data[p.x][p.y][p.z]);
    
    if(value > 0 && value < 255) { // only include rendered points
        dst->count[value] += 1;
    }
}

//===================================================================================

kernel void verticeShader
(
 constant Map3D &src [[buffer(0)]],             // source point cloud
 device atomic_uint &counter[[buffer(1)]],      // global value = # vertices in output
 constant Control &control [[buffer(2)]],       // control params from Swift
 constant float3 *color [[buffer(3)]],          // color lookup table[256]
 device TVertex *vertices[[ buffer(4) ]],       // output list of vertices to render
 uint3 p [[thread_position_in_grid]])
{
    int cIndex = int(src.data[p.x][p.y][p.z]);
    if(cIndex == 0 || cIndex > 255) return;     // non-rendered point
    
    if(control.hop > 1) {       // 'fast calc' skips most coordinates
        if(int(p.x) % control.hop) return;
        if(int(p.y) % control.hop) return;
        if(int(p.z) % control.hop) return;
    }
    
    if(cIndex < control.center - control.spread) return;
    if(cIndex > control.center + control.spread) return;
    
    uint index = atomic_fetch_add_explicit(&counter, 0, memory_order_relaxed);
    if(index >= VMAX) return;
    index = atomic_fetch_add_explicit(&counter, 1, memory_order_relaxed);
    
    device TVertex &v = vertices[index];
    float offset = float(control.cloudIndex) / float(NUM_CLOUD);
    float center = float(WIDTH/2) + offset;

    v.pos.x = (float(p.x) - center) / 2;
    v.pos.y = (float(p.y) - center) / 2;
    v.pos.z = (float(p.z) - center) / 2;
    
    float diff = float(cIndex - control.center) * float(control.range) / float(1 + control.spread);
    cIndex = control.center + int(diff) + control.offset;
    
    cIndex &= 255;
    
    v.color = float4(color[cIndex],0.15);
}

//===================================================================================

struct Transfer {
    float4 position [[position]];
    float pointsize [[point_size]];
    float4 color;
};

vertex Transfer texturedVertexShader
(
 constant TVertex *data[[ buffer(0) ]],
 constant Uniforms &uniforms[[ buffer(1) ]],
 unsigned int vid [[ vertex_id ]])
{
    TVertex in = data[vid];
    Transfer out;
    
    out.pointsize = uniforms.pointSize;
    out.color = in.color;
    out.position = uniforms.mvp * float4(in.pos, 1.0);
    return out;
}

fragment float4 texturedFragmentShader
(
 Transfer in [[stage_in]],
 texture2d<float> tex2D [[texture(0)]],
 sampler sampler2D [[sampler(0)]])
{
    return in.color;
}

