﻿Shader "Hidden/VideoPlayerEffects/VideoKeying"
{
    Properties
    {
        _MainTex("", 2D) = "white" {}
    }

    CGINCLUDE

    #include "UnityCG.cginc"

    sampler2D _MainTex;
    float4 _MainTex_TexelSize;

    fixed3 _Params; // (threshold, tolerance, spill removal)
    fixed2 _CgCo;
    fixed3 _Chroma;
    half2 _BlurDir;

    // Keying shader

    fixed3 RGB2YCgCo(fixed3 rgb)
    {
        return fixed3(
            dot(rgb, half3( 0.25, 0.5,  0.25)),
            dot(rgb, half3(-0.25, 0.5, -0.25)),
            dot(rgb, half3( 0.50, 0.0, -0.50)));
    }

    fixed3 YCgCo2RGB(fixed3 ycgco)
    {
        return fixed3(
            dot(ycgco, half3(1, -1,  1)),
            dot(ycgco, half3(1,  1,  0)),
            dot(ycgco, half3(1, -1, -1)));
    }

    fixed4 FragKeying(v2f_img i) : SV_Target
    {
        fixed3 src = tex2D(_MainTex, i.uv);
        fixed3 src_ycgco = RGB2YCgCo(src);

        // chroma-difference based alpha
        half dist = distance(src_ycgco.yz, _CgCo);
        half alpha = smoothstep(_Params.x, _Params.x + _Params.y, dist);

        // Spill removal
        half2 cgco = src_ycgco.yz - _CgCo * saturate(1 - dist * _Params.z);
        cgco *= saturate(dist * _Params.z * 0.5);
        src = YCgCo2RGB(half3(src_ycgco.x, clamp(cgco, -0.5, 0.5)));

        return fixed4(GammaToLinearSpace(src), alpha);
    }

    // Alpha dilate shader

    fixed4 FragDilate(v2f_img i) : SV_Target
    {
        fixed4 c0 = tex2D(_MainTex, i.uv);

        float3 d = float3(_MainTex_TexelSize.xy, 0);

        fixed a1 = tex2D(_MainTex, i.uv - d.xz).a;
        fixed a2 = tex2D(_MainTex, i.uv - d.zy).a;
        fixed a3 = tex2D(_MainTex, i.uv + d.xz).a;
        fixed a4 = tex2D(_MainTex, i.uv + d.zy).a;

        fixed a = min(min(min(min(c0.a, a1), a2), a3), a4);

        return fixed4(c0.rgb, a);
    }

    // Alpha blur shader

    fixed4 FragBlur(v2f_img i) : SV_Target
    {
        fixed4 c0 = tex2D(_MainTex, i.uv);

        float2 d = _MainTex_TexelSize.xy * _BlurDir;

        fixed a1 = tex2D(_MainTex, i.uv - d * 2).a;
        fixed a2 = tex2D(_MainTex, i.uv - d    ).a;
        fixed a3 = tex2D(_MainTex, i.uv + d    ).a;
        fixed a4 = tex2D(_MainTex, i.uv + d * 2).a;

        fixed a =
            0.38774 * c0.a +
            0.24477 * (a2 + a3) +
            0.06136 * (a1 + a4);

        return fixed4(c0.rgb, a);
    }

    // Debug shader

    v2f_img VertDebug(appdata_img v)
    {
        // a little bit messy way to fit the quad to the screen
        v.vertex.z -= 1;
        v2f_img o;
        o.pos = UnityViewToClipPos(v.vertex);
        o.pos.xy /= abs(o.pos.xy);
        o.uv = v.texcoord;
        return o;
    }

    fixed4 FragDebug(v2f_img i) : SV_Target
    {
        return tex2D(_MainTex, i.uv.xy);
    }

    ENDCG

    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment FragKeying
            ENDCG
        }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment FragDilate
            ENDCG
        }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment FragBlur
            ENDCG
        }
        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            CGPROGRAM
            #pragma vertex VertDebug
            #pragma fragment FragDebug
            ENDCG
        }
    }
}
