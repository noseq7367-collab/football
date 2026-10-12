cd "$1"
sed -i '/OFFSCREENCANVAS_SUPPORT/d' CMakeLists.txt
sed -i 's/-sASSERTIONS=1/-sASSERTIONS=1 --profiling-funcs/' CMakeLists.txt
python3 - <<'PYEOF'
p = "src/systems/graphics/rendering/opengl_renderer3d.cpp"
t = open(p, encoding="utf-8", errors="surrogateescape", newline="").read()

old1 = "    context = SDL_GL_CreateContext(window);\n"
new1 = """#ifdef __EMSCRIPTEN__
    {
      EmscriptenWebGLContextAttributes attrs;
      emscripten_webgl_init_context_attributes(&attrs);
      attrs.majorVersion = 2;
      attrs.minorVersion = 0;
      attrs.alpha = EM_FALSE;
      attrs.depth = EM_TRUE;
      attrs.stencil = EM_FALSE;
      attrs.antialias = EM_FALSE;
      attrs.preserveDrawingBuffer = EM_FALSE;
      attrs.enableExtensionsByDefault = EM_TRUE;
      attrs.explicitSwapControl = EM_TRUE;
      attrs.renderViaOffscreenBackBuffer = EM_TRUE;
      attrs.proxyContextToMainThread = EMSCRIPTEN_WEBGL_CONTEXT_PROXY_ALWAYS;
      EMSCRIPTEN_WEBGL_CONTEXT_HANDLE webglHandle = emscripten_webgl_create_context("#canvas", &attrs);
      if (webglHandle > 0) {
        emscripten_webgl_make_context_current(webglHandle);
        context = (SDL_GLContext)(intptr_t)webglHandle;
      } else {
        printf("emscripten_webgl_create_context fallo: %d\\n", (int)webglHandle);
        context = 0;
      }
    }
#else
    context = SDL_GL_CreateContext(window);
#endif
"""
assert t.count(old1) == 1, "no encontre SDL_GL_CreateContext"
t = t.replace(old1, new1)

old2 = "    SDL_GL_SwapWindow(window);\n#ifdef __EMSCRIPTEN__\n"
new2 = "#ifndef __EMSCRIPTEN__\n    SDL_GL_SwapWindow(window);\n#endif\n#ifdef __EMSCRIPTEN__\n"
assert t.count(old2) == 1, "no encontre SwapBuffers"
t = t.replace(old2, new2)

open(p, "w", encoding="utf-8", errors="surrogateescape", newline="").write(t)
print("parche del contexto WebGL aplicado")
PYEOF
grep -n -E 'OFFSCREEN|profiling' CMakeLists.txt
printf '"graphics3d_frametime_ms" "16"\n' > data/football.config
