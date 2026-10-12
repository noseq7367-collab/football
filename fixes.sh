set -e
cd "$1"
sed -i '/OFFSCREENCANVAS_SUPPORT/d' CMakeLists.txt
sed -i 's/-sASSERTIONS=1/-sASSERTIONS=1 --profiling-funcs/' CMakeLists.txt
python3 - <<'PYEOF'
p = "src/systems/graphics/rendering/opengl_renderer3d.cpp"
t = open(p, encoding="utf-8", errors="surrogateescape", newline="").read()

def patch(t, old, new, what):
    assert t.count(old) == 1, "no encontre: " + what
    return t.replace(old, new)

# --- 1) Contexto WebGL2 propio (proxy al hilo principal) ---
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
t = patch(t, old1, new1, "SDL_GL_CreateContext")

old2 = "    SDL_GL_SwapWindow(window);\n#ifdef __EMSCRIPTEN__\n"
new2 = "#ifndef __EMSCRIPTEN__\n    SDL_GL_SwapWindow(window);\n#endif\n#ifdef __EMSCRIPTEN__\n"
t = patch(t, old2, new2, "SwapBuffers")

# --- 2) Entrada (teclado/mouse): los callbacks del navegador llegan al hilo del renderer
#        como llamadas encoladas; hay que procesarlas a mano en cada vuelta del bucle ---
t = patch(t,
  "#ifdef __EMSCRIPTEN__\n#include <emscripten/html5.h>\n",
  "#ifdef __EMSCRIPTEN__\n#include <emscripten/html5.h>\n#include <emscripten/threading.h>\n",
  "include html5.h")

t = patch(t,
  "      while (SDL_PollEvent(&event)) {\n",
  "#ifdef __EMSCRIPTEN__\n      emscripten_current_thread_process_queued_calls();\n#endif\n      while (SDL_PollEvent(&event)) {\n",
  "SDL_PollEvent")

# Diagnostico: muestra en la consola los primeros eventos que llegan
t = patch(t,
  "        // context losing/gaining focus\n",
  """#ifdef __EMSCRIPTEN__
        {
          static int evtCount = 0;
          if (evtCount < 60 && event.type != SDL_MOUSEMOTION) {
            evtCount++;
            printf("[evt] type=0x%x activo=%d\\n", (unsigned)event.type, (int)contextIsActive);
          }
        }
#endif
        // context losing/gaining focus
""", "comentario focus")

# En el navegador no descartar eventos por 'perdida de foco' (el evento de foco llega poco fiable)
t = patch(t,
  "        if (contextIsActive) { // context must be active\n",
  """#ifdef __EMSCRIPTEN__
        if (true) {
#else
        if (contextIsActive) { // context must be active
#endif
""", "contextIsActive")

open(p, "w", encoding="utf-8", errors="surrogateescape", newline="").write(t)
print("parches del renderer aplicados")
PYEOF
# --- 3) Ruta de plantillas de animacion: con std::filesystem, 'dir / "/templates"' REEMPLAZA dir
#        (queda "/templates") y la carga del partido revienta ---
sed -i 's|directory / "/templates"|directory / "templates"|' src/onthepitch/player/humanoid/animcollection.cpp
grep -q 'directory / "templates"' src/onthepitch/player/humanoid/animcollection.cpp
grep -n -E 'OFFSCREEN|profiling' CMakeLists.txt
printf '"graphics3d_frametime_ms" "50"\n"context_x" "640"\n"context_y" "360"\n' > data/football.config
