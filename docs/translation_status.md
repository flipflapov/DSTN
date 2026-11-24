# Перевод документации на русский

DSTN переводит всю документацию исходного проекта на русский. Перевод идёт частями; этот файл показывает, что
уже переведено. Переведённый файл заменяет английский на том же месте, чтобы ссылки между документами не
ломались. Имена файлов, команд, опций, переменных окружения и заголовки, на которые ведут якорные ссылки
(`#...`), остаются как есть.

Правила перевода:

- имена инструкций, форматов, API и полей (`v_div_fixup_f64`, `D3D12XboxCreateDevice`, `MODE.FP_ROUND`) не
  переводятся;
- числа, хеши коммитов и измерения переносятся без изменений; в тексте используется пробел как разделитель
  тысяч (26 503), в коде и таблицах команд — как в оригинале;
- ссылки на обсуждения в исходном проекте пишутся как «Leonida#N» или полной ссылкой на
  `github.com/ItsNotRexed/Leonida`.

Всего файлов: 84, строк: 33308.

| Файл | Строк | Состояние |
|---|---|---|
| [`README.md`](../README.md) | 312 | ✅ переведён |
| [`docs/test_game.md`](test_game.md) | 159 | ✅ написан на русском (новый) |
| [`.github/pull_request_template.md`](../.github/pull_request_template.md) | 21 | ⏳ ожидает |
| [`AGENTS.md`](../AGENTS.md) | 101 | ⏳ ожидает |
| [`CONTRIBUTING.md`](../CONTRIBUTING.md) | 58 | ⏳ ожидает |
| [`docs/README.md`](README.md) | 94 | ⏳ ожидает |
| [`docs/animation.md`](animation.md) | 1258 | ⏳ ожидает |
| [`docs/audio.md`](audio.md) | 398 | ⏳ ожидает |
| [`docs/audio_config.md`](audio_config.md) | 266 | ⏳ ожидает |
| [`docs/awc_shorts.md`](awc_shorts.md) | 33 | ⏳ ожидает |
| [`docs/boot.md`](boot.md) | 156 | ⏳ ожидает |
| [`docs/buffer_bounds.md`](buffer_bounds.md) | 62 | ⏳ ожидает |
| [`docs/buffer_formats.md`](buffer_formats.md) | 177 | ⏳ ожидает |
| [`docs/bvh.md`](bvh.md) | 1164 | ⏳ ожидает |
| [`docs/character_models.md`](character_models.md) | 508 | ⏳ ожидает |
| [`docs/character_skeleton.md`](character_skeleton.md) | 538 | ⏳ ожидает |
| [`docs/coder.md`](coder.md) | 110 | ⏳ ожидает |
| [`docs/d3d12_command_objects.md`](d3d12_command_objects.md) | 960 | ⏳ ожидает |
| [`docs/d3d12_vulkan.md`](d3d12_vulkan.md) | 4093 | ⏳ ожидает |
| [`docs/d3d12_xs_surface.md`](d3d12_xs_surface.md) | 703 | ⏳ ожидает |
| [`docs/descriptor_lookup_ada.md`](descriptor_lookup_ada.md) | 70 | ⏳ ожидает |
| [`docs/descriptor_lookup_apple.md`](descriptor_lookup_apple.md) | 48 | ⏳ ожидает |
| [`docs/descriptor_lookup_intel.md`](descriptor_lookup_intel.md) | 39 | ⏳ ожидает |
| [`docs/design.md`](design.md) | 645 | ⏳ ожидает |
| [`docs/embedded_shaders.md`](embedded_shaders.md) | 222 | ⏳ ожидает |
| [`docs/first_light.md`](first_light.md) | 215 | ⏳ ожидает |
| [`docs/fspx.md`](fspx.md) | 253 | ⏳ ожидает |
| [`docs/fssm_crosscheck.md`](fssm_crosscheck.md) | 246 | ⏳ ожидает |
| [`docs/gamedata.md`](gamedata.md) | 1443 | ⏳ ожидает |
| [`docs/gamedata_graph.md`](gamedata_graph.md) | 157 | ⏳ ожидает |
| [`docs/gameinput.md`](gameinput.md) | 559 | ⏳ ожидает |
| [`docs/gbuffer.md`](gbuffer.md) | 141 | ⏳ ожидает |
| [`docs/isa_coverage.md`](isa_coverage.md) | 77 | ⏳ ожидает |
| [`docs/material_pass_replay.md`](material_pass_replay.md) | 32 | ⏳ ожидает |
| [`docs/mission_logic.md`](mission_logic.md) | 174 | ⏳ ожидает |
| [`docs/modding.md`](modding.md) | 140 | ⏳ ожидает |
| [`docs/models.md`](models.md) | 831 | ⏳ ожидает |
| [`docs/movies.md`](movies.md) | 475 | ⏳ ожидает |
| [`docs/multi_gpu_validation.md`](multi_gpu_validation.md) | 79 | ⏳ ожидает |
| [`docs/navmesh.md`](navmesh.md) | 564 | ⏳ ожидает |
| [`docs/page_directory.md`](page_directory.md) | 517 | ⏳ ожидает |
| [`docs/ped_catalogues.md`](ped_catalogues.md) | 172 | ⏳ ожидает |
| [`docs/pipeline_check.md`](pipeline_check.md) | 487 | ⏳ ожидает |
| [`docs/progress_dashboard.md`](progress_dashboard.md) | 64 | ⏳ ожидает |
| [`docs/psin.md`](psin.md) | 598 | ⏳ ожидает |
| [`docs/pso_cache.md`](pso_cache.md) | 242 | ⏳ ожидает |
| [`docs/radio_stations.md`](radio_stations.md) | 324 | ⏳ ожидает |
| [`docs/rbf0.md`](rbf0.md) | 536 | ⏳ ожидает |
| [`docs/related_projects.md`](related_projects.md) | 198 | ⏳ ожидает |
| [`docs/resource_names.md`](resource_names.md) | 69 | ⏳ ожидает |
| [`docs/restofworld.md`](restofworld.md) | 979 | ⏳ ожидает |
| [`docs/rpf.md`](rpf.md) | 206 | ⏳ ожидает |
| [`docs/rsc8_audio.md`](rsc8_audio.md) | 383 | ⏳ ожидает |
| [`docs/runtime_imports.md`](runtime_imports.md) | 492 | ⏳ ожидает |
| [`docs/sandbox.md`](sandbox.md) | 86 | ⏳ ожидает |
| [`docs/saves.md`](saves.md) | 175 | ⏳ ожидает |
| [`docs/sgd5_render_states.md`](sgd5_render_states.md) | 25 | ⏳ ожидает |
| [`docs/shader_inputs.md`](shader_inputs.md) | 304 | ⏳ ожидает |
| [`docs/shader_library.md`](shader_library.md) | 172 | ⏳ ожидает |
| [`docs/shader_validation.md`](shader_validation.md) | 2217 | ⏳ ожидает |
| [`docs/story.md`](story.md) | 614 | ⏳ ожидает |
| [`docs/strand_grooms.md`](strand_grooms.md) | 320 | ⏳ ожидает |
| [`docs/testing.md`](testing.md) | 608 | ⏳ ожидает |
| [`docs/text.md`](text.md) | 212 | ⏳ ожидает |
| [`docs/textures.md`](textures.md) | 1100 | ⏳ ожидает |
| [`docs/textures_arrays.md`](textures_arrays.md) | 269 | ⏳ ожидает |
| [`docs/weather.md`](weather.md) | 137 | ⏳ ожидает |
| [`docs/world.md`](world.md) | 931 | ⏳ ожидает |
| [`docs/world_census.md`](world_census.md) | 213 | ⏳ ожидает |
| [`docs/world_lights_paths.md`](world_lights_paths.md) | 129 | ⏳ ожидает |
| [`docs/world_names.md`](world_names.md) | 181 | ⏳ ожидает |
| [`docs/xbox_d3d12_xs.md`](xbox_d3d12_xs.md) | 895 | ⏳ ожидает |
| [`docs/xcl_compare.md`](xcl_compare.md) | 75 | ⏳ ожидает |
| [`docs/xdxr.md`](xdxr.md) | 120 | ⏳ ожидает |
| [`runtime/README.md`](../runtime/README.md) | 534 | ⏳ ожидает |
| [`runtime/test/bink_abi_test.md`](../runtime/test/bink_abi_test.md) | 44 | ⏳ ожидает |
| [`runtime/test/bink_audio_test.md`](../runtime/test/bink_audio_test.md) | 70 | ⏳ ожидает |
| [`runtime/test/bink_decode_test.md`](../runtime/test/bink_decode_test.md) | 47 | ⏳ ожидает |
| [`runtime/test/bink_play.md`](../runtime/test/bink_play.md) | 55 | ⏳ ожидает |
| [`tests/semantic/README.md`](../tests/semantic/README.md) | 170 | ⏳ ожидает |
| [`tools/bcpack_calibration/README.md`](../tools/bcpack_calibration/README.md) | 41 | ⏳ ожидает |
| [`tools/conformance/COMPARE.md`](../tools/conformance/COMPARE.md) | 406 | ⏳ ожидает |
| [`tools/conformance/README.md`](../tools/conformance/README.md) | 107 | ⏳ ожидает |
| [`tools/conformance/native/README.md`](../tools/conformance/native/README.md) | 362 | ⏳ ожидает |
