#ifndef VF_INCLUDE_COMMON
#define VF_INCLUDE_COMMON

/**
 * Rotates the UV clock-wise around the specified pivot point.
 */
float2 RotateUV(float2 uv, float2 pivot, float rotation)
{
    float cosA = cos(rotation);
    float sinA = sin(rotation);

    float2 origin = uv - pivot;                             // Move the pivot point back to the origin.
    float2 rotated = float2(
        ((cosA * origin.x) - (sinA * origin.y)),            // Rotate at origin.
        ((cosA * origin.y) + (sinA * origin.x)));

    return (rotated + pivot);                              // Move back to original position.
}

/**
 * Provides a random single output value for a single input value.
 * Returned value is on the range [0, 1].
 * Source: https://www.shadertoy.com/view/4djSRW
 */
float Hash11(float p)
{
    p = frac(p * 0.1031f);
    p *= p + 33.33f;
    p *= p + p;

    return frac(p);
}

// Visual examples: https://easings.net/

float EaseInQuadratic(float x)
{
    return x * x;
}

float EaseInCubic(float x)
{
    return (x * x * x);
}

#endif